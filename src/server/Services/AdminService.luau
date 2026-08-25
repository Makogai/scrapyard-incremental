--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MessagingService = game:GetService("MessagingService")

local AdminConfig = require(ReplicatedStorage.Shared.Config.AdminConfig)
local AdminCatalogue = require(ReplicatedStorage.Shared.Config.AdminCatalogue)
local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local EventService = require(script.Parent.EventService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local PlotThemeService = require(script.Parent.PlotThemeService)
local PlotService = require(script.Parent.PlotService)
local InboxService = require(script.Parent.InboxService)
local ServerRestartService = require(script.Parent.ServerRestartService)
local RemoteService = require(script.Parent.RemoteService)
local ScrapService = require(script.Parent.ScrapService)
local WreckService = require(script.Parent.WreckService)

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
	WHICH ADMIN COMMANDS ARE GIFTS.

	These four map cleanly onto the shared `{ Money?, Gears?, Items?, Spins? }` reward shape, so they are
	MAILED rather than applied: the player sees who sent it, what it was, and claims it themselves. That is
	the whole point of the inbox -- a silent grant left nobody able to answer "did you get it?".

	Everything else -- rebirth counts, daily streaks, pets, boosts, profile wipes -- is a state change
	rather than a gift and is still applied directly. Mailing a rebirth count would mean a claim button
	that rewrites someone's progression, and there is no honest way to present that as a present.
]]
local GIFT_REWARDS: { [string]: (number, string?) -> { [string]: any } } = {
	AddMoney = function(amount)
		return { Money = amount }
	end,
	AddGears = function(amount)
		return { Gears = amount }
	end,
	AddSlag = function(amount)
		return { Slag = amount }
	end,
	AddSpins = function(amount)
		return { Spins = amount }
	end,
	GrantConsumable = function(amount, itemId)
		return { Items = { [itemId or ""] = math.max(1, amount) } }
	end,
}

local GIFT_TITLES: { [string]: string } = {
	AddMoney = "A gift of scrap cash",
	AddGears = "A gift of gears",
	AddSlag = "A gift of slag",
	AddSpins = "Free spins",
	GrantConsumable = "A gift from the team",
}

--[[
	Mail a gift to everyone in `targets`. Returns how many mailboxes took it.

	`senderName` rather than a Player, because this path is also reached from the cross-server receiver
	where the admin is on another machine and only their name travelled.
]]
local function mailGift(
	targets: { Player },
	command: string,
	amount: number?,
	itemId: string?,
	senderName: string,
	senderUserId: number,
	senderRole: string
): number
	local rewards = GIFT_REWARDS[command](math.floor(amount or 0), itemId)
	local sent = 0
	for _, target in targets do
		local id = InboxService.Send(target, {
			Kind = "Staff",
			Title = GIFT_TITLES[command] or "A gift from the team",
			Body = `Sent to you by {senderName}. Hit claim to collect it.`,
			FromName = senderName,
			FromUserId = senderUserId,
			FromRole = senderRole,
			Rewards = rewards,
		})
		if id ~= nil then
			sent += 1
		end
	end
	return sent
end

--[[
	Applies one command to a list of players and refreshes what depends on it.

	Shared by the local path and the broadcast receiver, so a command cannot behave differently
	depending on which server the admin happened to be standing on.
]]
local function applyToTargets(
	targets: { Player },
	command: string,
	amount: number?,
	itemId: string?,
	senderName: string?,
	senderUserId: number?
): number
	--- Gifts are mailed, never applied. See `GIFT_REWARDS`.
	if GIFT_REWARDS[command] ~= nil then
		return mailGift(
			targets,
			command,
			amount,
			itemId,
			senderName or "the team",
			senderUserId or 0,
			--[[
				Resolved from the id rather than passed in, so a gift mailed from another server is labelled by
				what that account actually is now rather than by what the sending server believed.
			]]
			if senderUserId ~= nil and AdminConfig.IsOwner(senderUserId) then "OWNER" else "ADMIN"
		)
	end

	local applied = 0
	for _, target in targets do
		if PlayerStateService.AdminMutate(target, command, amount, itemId) then
			applied += 1
			PlotService.RefreshAppearance(target)
			--[[
				A WIPE OR FULL AREA UNLOCK HAS TO REBUILD THE PLOT, not just refresh it.

				Reset puts `ActivePlotTheme` back to the Front Yard in DATA; UnlockAllAreas puts it
				on the last area. Without `Rebuild` the yard standing in the world stays whatever it
				was. `Rebuild` swaps the geometry and calls `ActivateScrap` itself, which is why the
				scrap refresh below is skipped for these two.
			]]
			local plot = if command == "ResetProfile" or command == "UnlockAllAreas"
				then PlotService.GetPlot(target)
				else nil
			if plot ~= nil then
				PlotThemeService.Rebuild(target, plot)
			else
				ScrapService.RefreshPlayer(target)
			end
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
				--- So a gift mailed on another server still says who sent it.
				FromName = admin.DisplayName,
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
		and command ~= "AddSlag"
		and command ~= "GrantPet"
		and command ~= "GrantConsumable"
		and command ~= "AddUpgradeLevels"
		and command ~= "AddSpins"
		and command ~= "SetDailyStreak"
		and command ~= "AddRebirths"
		and command ~= "GrantSecretTicket"
		and command ~= "ActivateBoost"
		and command ~= "StartEvent"
		and command ~= "SetWreckHp"
	then
		return nil
	end
	if typeof(value) ~= "number" or value ~= value then
		return nil
	end
	--[[
		`ActivateBoost` and `StartEvent` take MINUTES, and their ceilings are far lower than a grant's.
		`SetWreckHp` takes hit points. Everything else here hands something to one player; these change
		the rules for everybody, so the clamp is the difference between a test and a stuck server.
	]]
	local maximum = if command == "AddMoney"
		then AdminConfig.MaximumGrantMoney
		elseif command == "AddGears" then AdminConfig.MaximumGrantGears
		elseif command == "ActivateBoost" then AdminConfig.MaximumServerBoostMinutes
		elseif command == "StartEvent" then AdminConfig.MaximumEventMinutes
		elseif command == "SetWreckHp" then AdminConfig.MaximumWreckHp
		else 9999
	local minimum = if command == "SetWreckHp" then 1 else 0
	return math.floor(math.clamp(value, minimum, maximum))
end

--[[
	Commands that change the SERVER rather than a player, and so never touch `AdminMutate`.

	`AdminMutate` edits one player's saved data; an event is not in anybody's save. Keeping these apart
	means the target mode still decides REACH -- this server or every server -- without pretending an
	event is something each player owns a copy of.
]]
local SERVER_COMMANDS = {
	StartEvent = true,
	StopEvent = true,
	SetWreckHp = true,
}

--[[
	Apply a server-level command here. Returns a line for the admin, or nil if it did nothing.

	The event override lives in `EventConfig` because that is what every reader of "what event is live"
	already calls -- see the comment there. `EventService.Republish` then pushes the change out so the HUD
	banner, the world billboard and the announcement all move at once instead of waiting for the poll.
]]
local function applyServerCommand(command: string, minutes: number?, itemId: string?): string?
	if command == "CancelRestart" then
		if ServerRestartService.Cancel() then
			return "restart cancelled"
		end
		return nil
	end
	if command == "StopEvent" then
		EventConfig.setOverride(nil, 0)
		EventService.Republish()
		return "event stopped -- back on the schedule"
	end
	if command == "StartEvent" then
		if itemId == nil then
			return nil
		end
		local length = math.clamp(math.floor(minutes or 0), 1, AdminConfig.MaximumEventMinutes)
		if not EventConfig.setOverride(itemId, length * 60) then
			return nil
		end
		EventService.Republish()
		local definition = EventConfig.ById[itemId]
		return `{if definition then definition.Title else itemId} started for {length} min`
	end
	if command == "SetWreckHp" then
		if minutes == nil then
			return nil
		end
		return WreckService.SetIntegrity(minutes)
	end
	return nil
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
					Never across a server boundary. `ResetProfile` wipes a save, and a broadcast version of it
					is a way to wipe everyone's in the whole experience at once.
				]]
				if payload.Command == "ResetProfile" or payload.Command == "GrantTestItems" then
					return
				end
				--[[
					OWNER-ONLY COMMANDS ARE RE-CHECKED HERE TOO. The sending server checked, but a
					subscription payload is data rather than proof: the only thing saying an owner sent it
					is a user id inside the message. Trusting that would make the tier a client-side
					suggestion with extra steps.
				]]
				if
					AdminCatalogue.isOwnerOnlyCommand(payload.Command)
					and not AdminConfig.IsOwner(payload.FromUserId)
				then
					return
				end
				--- Server-level commands act once per server, not once per player.
				if SERVER_COMMANDS[payload.Command] then
					applyServerCommand(
						payload.Command,
						boundedAmount(payload.Command, payload.Amount),
						if typeof(payload.ItemId) == "string" then payload.ItemId else nil
					)
					return
				end
				local amount = boundedAmount(payload.Command, payload.Amount)
				local itemId = if typeof(payload.ItemId) == "string" then payload.ItemId else nil
				applyToTargets(
					Players:GetPlayers(),
					payload.Command,
					amount,
					itemId,
					if typeof(payload.FromName) == "string" then payload.FromName else nil,
					if typeof(payload.FromUserId) == "number" then payload.FromUserId else nil
				)
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
				or (command == "GrantTestItems" and (not RunService:IsStudio() or targetMode ~= "Self"))
				or not limiter:Allow(tostring(admin.UserId))
			then
				return
			end

			--[[
				A WIPE REACHES ONE PERSON AT A TIME.

				`ResetProfile` deletes a save with no undo, so the two broad targets are refused outright
				rather than left to a confirmation dialog: EVERYONE HERE next to RESET PROFILE is one mis-tap
				away from clearing a full server, and the panel puts those two controls in the same window.
				Yourself or a named player only.

				It is NOT Studio-only any more -- that restriction, plus a target check for `Self`, is why
				resetting somebody appeared to do nothing at all on a live server.
			]]
			--[[
				BROADCAST AND RESTART ARE SERVER-WIDE, so they run once here rather than per target, and both
				need the admin's identity -- the name and the verified tick are the whole point of a
				broadcast. `itemId` carries the message text: it is already a validated string on this
				remote, so this needs no widening of the signature for one command.
			]]
			if command == "Broadcast" then
				local text = if typeof(itemId) == "string"
					then string.sub(itemId, 1, AdminConfig.MaximumBroadcastLength)
					else ""
				if #text == 0 then
					RemoteService.GetEvent("Notify")
						:FireClient(admin, "ADMIN: type a message first")
					return
				end
				RemoteService.GetEvent("AdminBroadcast"):FireAllClients({
					Message = text,
					FromName = admin.DisplayName,
					--- For the avatar. The client builds an `rbxthumb://` URL from it -- no web call needed.
					FromUserId = admin.UserId,
					--[[
						OWNER or ADMIN. Read from `AdminConfig` here rather than sent by the client for the same
						reason `Verified` is: a rank a client could name is a rank anybody could claim.
					]]
					Role = if AdminConfig.IsOwner(admin.UserId) then "OWNER" else "ADMIN",
					--- Only the server ever sets this, which is what makes the tick worth trusting.
					Verified = true,
				})
				RemoteService.GetEvent("Notify"):FireClient(admin, "ADMIN: broadcast sent")
				return
			end
			if command == "RestartServer" then
				local seconds = math.clamp(
					math.floor(amount or 60),
					AdminConfig.MinimumRestartSeconds,
					AdminConfig.MaximumRestartSeconds
				)
				local started, message = ServerRestartService.Start(seconds, admin.DisplayName)
				RemoteService.GetEvent("Notify"):FireClient(
					admin,
					`ADMIN: {if started then message else "could not start restart"}`
				)
				return
			end

			if command == "ResetProfile" and targetMode ~= "Self" and targetMode ~= "Player" then
				RemoteService.GetEvent("Notify")
					:FireClient(admin, "ADMIN: reset one player at a time, not everyone")
				return
			end

			--[[
				THE TIER CHECK, and the only one that counts.

				`AdminScreen` hides owner-only entries from an admin, which is a courtesy -- the remote is
				reachable regardless of what the panel drew. Two separate things are gated: the COMMAND
				(granting a paid entitlement, wiping a save) and the REACH (`AllServers`), because
				"everyone in this server" and "everyone in the game" are different amounts of damage.
			]]
			local isOwner = AdminConfig.IsOwner(admin.UserId)
			if not isOwner then
				local refusal = if AdminCatalogue.isOwnerOnlyCommand(command)
					then `ADMIN: {command} is owner-only`
					elseif
						AdminCatalogue.isOwnerOnlyTarget(targetMode)
					then "ADMIN: every-server commands are owner-only"
					else nil
				if refusal ~= nil then
					RemoteService.GetEvent("Notify"):FireClient(admin, refusal)
					return
				end
			end
			local safeAmount = boundedAmount(command, amount)
			if
				(
					command == "AddMoney"
					or command == "AddGears"
					or command == "AddSlag"
					or command == "AddSpins"
					or command == "SetDailyStreak"
					or command == "AddRebirths"
					or command == "GrantPet"
					or command == "GrantConsumable"
					or command == "AddUpgradeLevels"
					or command == "SetWreckHp"
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

			--[[
				Server-level commands stop here: there is nothing per-player to apply. The target mode still
				decided reach a moment ago, so "every server" already went out over the topic.
			]]
			if SERVER_COMMANDS[command] then
				local outcome = applyServerCommand(command, safeAmount, itemId)
				RemoteService.GetEvent("Notify"):FireClient(
					admin,
					if outcome ~= nil
						then `ADMIN: {outcome}`
						else `ADMIN: {command} did nothing -- check the id`
				)
				return
			end

			local targets = if targetMode == "All" or targetMode == "AllServers"
				then Players:GetPlayers()
				elseif selectedPlayer then { selectedPlayer }
				else { admin }
			local applied = applyToTargets(
				targets,
				command,
				safeAmount,
				itemId,
				admin.DisplayName,
				admin.UserId
			)
			RemoteService.GetEvent("Notify"):FireClient(
				admin,
				if targetMode == "AllServers"
					then `ADMIN: {command} sent to every server ({applied} here)`
					else `ADMIN: {command} applied to {applied} player(s)`
			)
		end)
end

return table.freeze(AdminService)
