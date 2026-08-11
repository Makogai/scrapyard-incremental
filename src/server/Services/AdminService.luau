--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MessagingService = game:GetService("MessagingService")

local AdminConfig = require(ReplicatedStorage.Shared.Config.AdminConfig)
local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local PlotService = require(script.Parent.PlotService)
local RemoteService = require(script.Parent.RemoteService)
local ScrapService = require(script.Parent.ScrapService)

local AdminService = {}

--- The topic every server listens on for cross-server admin commands.
local BROADCAST_TOPIC = "ScrapyardAdminBroadcast"

local VALID_TARGETS = {
	Self = true,
	Player = true,
	All = true,
	AllServers = true,
}

--[[
	Applies one command to a list of players and refreshes what depends on it.

	Shared by the local path and the broadcast receiver, so a command cannot behave differently
	depending on which server the admin happened to be standing on.
]]
local function applyToTargets(
	targets: { Player },
	command: string,
	amount: number?,
	itemId: string?
): number
	local applied = 0
	for _, target in targets do
		if PlayerStateService.AdminMutate(target, command, amount, itemId) then
			applied += 1
			PlotService.RefreshAppearance(target)
			ScrapService.RefreshPlayer(target)
		end
	end
	return applied
end

--- Fire-and-forget: a failed publish must not break the local half of the command.
local function broadcast(admin: Player, command: string, amount: number?, itemId: string?)
	task.spawn(function()
		local succeeded, err = pcall(function()
			MessagingService:PublishAsync(BROADCAST_TOPIC, {
				Command = command,
				Amount = amount,
				ItemId = itemId,
				FromUserId = admin.UserId,
			})
		end)
		if not succeeded then
			warn(`[AdminService] broadcast failed: {err}`)
		end
	end)
end
local limiter = RateLimiter.new(
	Environment.MaximumRemoteRequestsPerWindow,
	Environment.RemoteRateLimitWindowSeconds
)

local function boundedAmount(command: string, value: any): number?
	if
		command ~= "AddMoney"
		and command ~= "AddGears"
		and command ~= "GrantPet"
		and command ~= "GrantConsumable"
		and command ~= "AddUpgradeLevels"
	then
		return nil
	end
	if typeof(value) ~= "number" or value ~= value then
		return nil
	end
	local maximum = if command == "AddMoney"
		then AdminConfig.MaximumGrantMoney
		elseif command == "AddGears" then AdminConfig.MaximumGrantGears
		else 9999
	return math.floor(math.clamp(value, 0, maximum))
end

function AdminService.Start()
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(tostring(player.UserId))
	end)

	--[[
		Inbound broadcasts from other servers.

		RE-VETTED on arrival even though the sender vetted it. A subscription is a trust boundary like any
		other: the payload arrives as plain data, and the only thing proving it came from an admin is a
		user id inside it, which is exactly the kind of claim that must be checked rather than believed.

		`SubscribeAsync` yields and throws when MessagingService is unavailable -- it is disabled in some
		Studio configurations and has a per-server quota -- so it is spawned and wrapped. A server without
		it simply loses cross-server admin, which is the right way to degrade.
	]]
	task.spawn(function()
		local succeeded, err = pcall(function()
			MessagingService:SubscribeAsync(BROADCAST_TOPIC, function(message)
				local payload = message.Data
				if
					typeof(payload) ~= "table"
					or typeof(payload.Command) ~= "string"
					or typeof(payload.FromUserId) ~= "number"
					or not AdminConfig.IsAdmin(payload.FromUserId)
				then
					return
				end
				--[[
					Studio-only commands never cross a server boundary. `ResetTestProfile` wipes a save, and
					a broadcast version of it is a way to wipe everyone's.
				]]
				if payload.Command == "ResetTestProfile" or payload.Command == "GrantTestItems" then
					return
				end
				local amount = boundedAmount(payload.Command, payload.Amount)
				local itemId = if typeof(payload.ItemId) == "string" then payload.ItemId else nil
				applyToTargets(Players:GetPlayers(), payload.Command, amount, itemId)
			end)
		end)
		if not succeeded then
			warn(`[AdminService] cross-server admin unavailable: {err}`)
		end
	end)
	RemoteService.GetEvent("AdminCommand").OnServerEvent
		:Connect(function(admin, command, amount, targetMode, targetUserId, itemId)
			if
				not AdminConfig.IsAdmin(admin.UserId)
				or typeof(command) ~= "string"
				or not VALID_TARGETS[targetMode]
				or (targetMode == "Player" and typeof(targetUserId) ~= "number")
				or (itemId ~= nil and typeof(itemId) ~= "string")
				or ((command == "ResetTestProfile" or command == "GrantTestItems") and (not RunService:IsStudio() or targetMode ~= "Self"))
				or not limiter:Allow(tostring(admin.UserId))
			then
				return
			end
			local safeAmount = boundedAmount(command, amount)
			if
				(
					command == "AddMoney"
					or command == "AddGears"
					or command == "GrantPet"
					or command == "GrantConsumable"
					or command == "AddUpgradeLevels"
				) and safeAmount == nil
			then
				return
			end
			local selectedPlayer = if targetMode == "Player"
				then Players:GetPlayerByUserId(math.floor(targetUserId :: number))
				else nil
			if targetMode == "Player" and selectedPlayer == nil then
				RemoteService.GetEvent("Notify")
					:FireClient(admin, "ADMIN: Selected player left the server")
				return
			end
			--[[
				EVERY SERVER goes out over `MessagingService` and also runs here, so the admin sees it land
				on their own server immediately rather than waiting for their own broadcast to come back.

				Published only AFTER the admin check, the command validation and the amount clamp above --
				so a receiving server is handling a message that has already been vetted once. It re-vets
				anyway; see the subscription.
			]]
			if targetMode == "AllServers" then
				broadcast(admin, command, safeAmount, itemId)
			end

			local targets = if targetMode == "All" or targetMode == "AllServers"
				then Players:GetPlayers()
				elseif selectedPlayer then { selectedPlayer }
				else { admin }
			local applied = applyToTargets(targets, command, safeAmount, itemId)
			RemoteService.GetEvent("Notify"):FireClient(
				admin,
				if targetMode == "AllServers"
					then `ADMIN: {command} sent to every server ({applied} here)`
					else `ADMIN: {command} applied to {applied} player(s)`
			)
		end)
end

return table.freeze(AdminService)
