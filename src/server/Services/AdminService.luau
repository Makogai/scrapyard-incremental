--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AdminConfig = require(ReplicatedStorage.Shared.Config.AdminConfig)
local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local PlotService = require(script.Parent.PlotService)
local RemoteService = require(script.Parent.RemoteService)
local ScrapService = require(script.Parent.ScrapService)

local AdminService = {}
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
	RemoteService.GetEvent("AdminCommand").OnServerEvent
		:Connect(function(admin, command, amount, targetMode, targetUserId, itemId)
			if
				not AdminConfig.IsAdmin(admin.UserId)
				or typeof(command) ~= "string"
				or (targetMode ~= "Self" and targetMode ~= "All" and targetMode ~= "Player")
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
			local targets = if targetMode == "All"
				then Players:GetPlayers()
				elseif selectedPlayer then { selectedPlayer }
				else { admin }
			local applied = 0
			for _, target in targets do
				local succeeded =
					PlayerStateService.AdminMutate(target, command, safeAmount, itemId)
				if succeeded then
					applied += 1
					PlotService.RefreshAppearance(target)
					ScrapService.RefreshPlayer(target)
				end
			end
			RemoteService.GetEvent("Notify")
				:FireClient(admin, `ADMIN: {command} applied to {applied} player(s)`)
		end)
end

return table.freeze(AdminService)
