--!strict
--[[
	SocialRewardService.luau
	Pays the like / group / invite-a-friend rewards.

	THE VERIFICATION STORY, because it is the only interesting thing here. Roblox gives a server no way to
	ask "has this player liked this game", so the like reward is self-reported and priced as a thank-you.
	Group membership CAN be checked, so it is -- `IsInGroup` when `SocialConfig.GroupId` is set, and
	self-reported while it is still 0, which means the button works before the group exists and tightens
	the moment an id is filled in without touching this file.

	Friends are counted, not claimed: `FriendBoostCount` is maintained from who is actually in the server,
	so the milestones pay for friends who really turned up. That count already existed for the friend
	boost; this reuses it rather than keeping a second one that could disagree.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local SocialConfig = require(ReplicatedStorage.Shared.Config.SocialConfig)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RemoteService = require(script.Parent.RemoteService)

local SocialRewardService = {}

--[[
	Is this player in the community group?

	`pcall` because `IsInGroup` is a web call that fails in Studio and during an outage. A failed check
	returns false rather than true: a reward that pays on a network error is a reward that pays to
	everybody the moment Roblox has a bad minute.
]]
local function isInGroup(player: Player): boolean
	if SocialConfig.GroupId <= 0 then
		--- Not configured: nothing to verify against, so this is self-reported by design.
		return true
	end
	local ok, result = pcall(function()
		return player:IsInGroup(SocialConfig.GroupId)
	end)
	return ok and result == true
end

function SocialRewardService.Start()
	local limiter = RateLimiter.new(
		Environment.MaximumRemoteRequestsPerWindow,
		Environment.RemoteRateLimitWindowSeconds
	)
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(tostring(player.UserId))
	end)

	RemoteService.GetEvent("SocialAction").OnServerEvent
		:Connect(function(player: Player, action: unknown, rewardId: unknown)
			if not limiter:Allow(tostring(player.UserId)) then
				return
			end
			local notify = RemoteService.GetEvent("Notify")

			if action == "ClaimReward" then
				if typeof(rewardId) ~= "string" then
					return
				end
				local definition = SocialConfig.Rewards[rewardId]
				if definition == nil then
					return
				end
				if definition.RequiresGroup and not isInGroup(player) then
					notify:FireClient(player, "JOIN THE GROUP FIRST")
					return
				end
				local succeeded, message = PlayerStateService.ClaimSocialReward(player, rewardId)
				notify:FireClient(player, message)
				if not succeeded then
					return
				end
			elseif action == "ClaimInvite" then
				--[[
					The milestone index is chosen by the SERVER from the live friend count, not taken from
					the client. A client that could name its own milestone could claim the top one on its
					first join.
				]]
				local _, message = PlayerStateService.ClaimInviteMilestone(player)
				notify:FireClient(player, message)
			end
		end)
end

return table.freeze(SocialRewardService)
