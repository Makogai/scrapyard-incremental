--!strict
--[[
	InboxService.luau
	Delivery and claiming for the player mailbox.

	Thin on purpose: the mailbox lives in saved data, so `PlayerStateService` owns every write to it and
	this service is the wiring -- one remote in, one notification out, plus a `Send` other services call.

	WHAT CHANGED FOR ADMINS. Admin grants used to mutate a player's save directly and say nothing. Now
	`AdminService` routes gifts through `Send`, so the player sees who sent it, what it was, and has to
	claim it. A grant that a player never claims is still visible -- to them and to us -- which is exactly
	what was missing when a "did you get it?" question had no answer.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local InboxConfig = require(ReplicatedStorage.Shared.Config.InboxConfig)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RemoteService = require(script.Parent.RemoteService)

local InboxService = {}

--[[
	Ids have to be unique per mailbox and are compared by the client, so they are generated here rather
	than by the caller. Monotonic counter plus the send time: unique within a server, and readable in a
	log, which a GUID is not.
]]
local sequence = 0

local function nextId(): string
	sequence += 1
	return `msg_{os.time()}_{sequence}`
end

local function clip(text: string, limit: number): string
	if #text <= limit then
		return text
	end
	return string.sub(text, 1, limit)
end

--[[
	Put a message in a player's mailbox.

	`rewards` is the shared `{ Money?, Gears?, Items?, Spins? }` shape and is NOT paid out here -- it is
	stored, and paid when the player claims. That ordering is the point of the inbox: nothing lands in a
	save without the player having seen it.

	Returns the message id, or nil if the player has no session (they left mid-command).
]]
function InboxService.Send(
	player: Player,
	details: {
		Kind: string?,
		Title: string,
		Body: string,
		FromName: string?,
		FromUserId: number?,
		FromRole: string?,
		Rewards: { [string]: any }?,
	}
): string?
	local kind = InboxConfig.kind(details.Kind or InboxConfig.DefaultKind)
	local message = {
		Id = nextId(),
		Kind = kind.Id,
		Title = clip(details.Title, InboxConfig.MaximumTitleLength),
		Body = clip(details.Body, InboxConfig.MaximumBodyLength),
		FromName = details.FromName or "",
		FromUserId = details.FromUserId or 0,
		--- "OWNER" or "ADMIN" for staff mail; empty for anything the game itself sends.
		FromRole = details.FromRole or "",
		SentAt = os.time(),
		Rewards = details.Rewards,
		Claimed = false,
	}

	if not PlayerStateService.AddInboxMessage(player, message) then
		return nil
	end

	--[[
		Tell them it arrived, IN THE MIDDLE OF THE SCREEN.

		Deliberately not `Notify`: that is the right-hand toast stack, which is where "sold for $400" goes.
		A staff gift arriving in the same place as routine income is a gift nobody notices, and the mailbox
		is a place you otherwise have to think to check.

		Reuses the `AdminBroadcast` remote, fired to ONE client, because the centre notice is already the
		thing that renders it -- `Kind` is what makes it read as a present rather than as an announcement.
	]]
	RemoteService.GetEvent("AdminBroadcast"):FireClient(player, {
		Kind = "Gift",
		Message = message.Title,
		FromName = message.FromName,
		FromUserId = message.FromUserId,
		Role = message.FromRole,
		Verified = kind.Verified,
	})
	return message.Id
end

function InboxService.Start()
	local limiter = RateLimiter.new(
		Environment.MaximumRemoteRequestsPerWindow,
		Environment.RemoteRateLimitWindowSeconds
	)
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(tostring(player.UserId))
	end)

	RemoteService.GetEvent("InboxAction").OnServerEvent
		:Connect(function(player: Player, action: unknown, messageId: unknown)
			if not limiter:Allow(tostring(player.UserId)) then
				return
			end
			if typeof(action) ~= "string" then
				return
			end

			if action == "Claim" then
				if typeof(messageId) ~= "string" or #messageId > 60 then
					return
				end
				local _, message = PlayerStateService.ClaimInboxMessage(player, messageId)
				RemoteService.GetEvent("Notify"):FireClient(player, message)
			elseif action == "ClaimAll" then
				local claimed, message = PlayerStateService.ClaimAllInboxMessages(player)
				if claimed > 0 then
					RemoteService.GetEvent("Notify"):FireClient(player, message)
				else
					RemoteService.GetEvent("Notify"):FireClient(player, "NOTHING TO CLAIM")
				end
			end
		end)
end

return table.freeze(InboxService)
