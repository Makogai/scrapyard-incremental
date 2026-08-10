--!strict
--[[
	PlaytimeRewardService.luau
	Milestone rewards for time played inside a single day.

	Playtime was already being accumulated for the leaderboard and never spent on anything. This
	spends it: five milestones from 5 minutes to 2 hours, resetting with the daily reset.

	The 5-minute one is the important one. A milestone a first-session player never reaches is not a
	retention mechanic, it is a number in a config -- so the first reward lands well inside the
	first session and is worth having.

	TIME IS COUNTED SERVER-SIDE, from a wall clock the client cannot touch. The client sends
	"claim milestone N" and the server checks the banked seconds itself.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.RewardsConfig)
local DayClock = require(ReplicatedStorage.Shared.Utility.DayClock)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RemoteService = require(script.Parent.RemoteService)

local PlaytimeRewardService = {}
local limiter = RateLimiter.new(8, Environment.RemoteRateLimitWindowSeconds)
local MILESTONES = RewardsConfig.Playtime.Milestones

--- Last time each player's seconds were banked, so a tick banks elapsed time rather than a guess.
local lastBankedAt: { [Player]: number } = {}

local function milestoneAt(index: number)
	for _, milestone in MILESTONES do
		if milestone.Index == index then
			return milestone
		end
	end
	return nil
end

function PlaytimeRewardService.TryClaim(player: Player, milestoneIndex: any): (boolean, string)
	if typeof(milestoneIndex) ~= "number" then
		return false, "Unknown reward"
	end
	local milestone = milestoneAt(math.floor(milestoneIndex))
	if milestone == nil then
		return false, "Unknown reward"
	end
	local state = PlayerStateService.GetRewardState(player)
	if state == nil then
		return false, "Your data is still loading"
	end
	if state.PlaytimeClaimed[milestone.Index] == true then
		return false, "ALREADY CLAIMED"
	end
	if state.PlaytimeSecondsToday < milestone.Seconds then
		local remaining = milestone.Seconds - state.PlaytimeSecondsToday
		return false, `KEEP PLAYING -- {math.ceil(remaining / 60)} MIN TO GO`
	end

	local rewards: { [string]: any } = {
		Money = milestone.Money,
		Items = milestone.Items,
		Spins = milestone.Spins,
	}
	if not PlayerStateService.CommitPlaytimeClaim(player, milestone.Index, rewards) then
		return false, "Could not save that -- try again"
	end
	return true, `{milestone.Label} REWARD CLAIMED`
end

function PlaytimeRewardService.Start()
	local claim = RemoteService.GetEvent("ClaimPlaytimeReward")
	local notify = RemoteService.GetEvent("Notify")

	claim.OnServerEvent:Connect(function(player: Player, milestoneIndex: any)
		if not limiter:Allow(tostring(player.UserId)) then
			return
		end
		local _claimed, message = PlaytimeRewardService.TryClaim(player, milestoneIndex)
		notify:FireClient(player, message)
	end)

	Players.PlayerAdded:Connect(function(player)
		lastBankedAt[player] = os.clock()
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastBankedAt[player] = nil
		limiter:Remove(tostring(player.UserId))
	end)
	for _, player in Players:GetPlayers() do
		lastBankedAt[player] = os.clock()
	end

	--[[
		One loop for every player rather than a per-player thread. Banking elapsed wall time rather
		than adding a fixed amount per tick means a hitching server does not shortchange the player,
		and a tick that runs late still credits the right number of seconds.
	]]
	task.spawn(function()
		while true do
			task.wait(RewardsConfig.Playtime.TickSeconds)
			local now = os.clock()
			local today = DayClock.today()
			for _, player in Players:GetPlayers() do
				local previous = lastBankedAt[player]
				lastBankedAt[player] = now
				if previous ~= nil then
					PlayerStateService.AddPlaytimeSeconds(player, now - previous, today)
				end
			end
		end
	end)
end

return table.freeze(PlaytimeRewardService)
