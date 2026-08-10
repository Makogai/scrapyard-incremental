--!strict
--[[
	DailyRewardService.luau
	The seven-day login calendar, with a streak.

	The whole point of this system is the STREAK, not the reward. A reward you get for logging in is
	pleasant; a streak you lose by not logging in is a reason to log in. So the streak is what the
	HUD shows and what the cash bonus scales with.

	SERVER DECIDES EVERYTHING. The client sends "claim" and nothing else -- no day index, no reward
	id, no amount. It used to be able to send a day (`actions.claimDaily(currentDay)`), which is
	exactly the shape of a request you must never trust; the day is now read from saved data.

	Day arithmetic goes through `DayClock` so "already claimed today" and "was yesterday" are
	integer comparisons rather than timestamp subtraction. See that module for why.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.RewardsConfig)
local DayClock = require(ReplicatedStorage.Shared.Utility.DayClock)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RemoteService = require(script.Parent.RemoteService)

local DailyRewardService = {}
local limiter = RateLimiter.new(4, Environment.RemoteRateLimitWindowSeconds)
local CALENDAR = RewardsConfig.Daily.Days
local CALENDAR_LENGTH = #CALENDAR

--[[
	Cash on the day's own reward, multiplied by the streak bonus.

	Only cash scales. Scaling item counts would hand a 30-day player thirty God Potions, and
	scaling spins would compound into the wheel, which already has a jackpot.
]]
local function scaledRewards(definition: { [string]: any }, streak: number): { [string]: any }
	local bonus = math.min(
		(streak - 1) * RewardsConfig.Daily.StreakBonusPerDay,
		RewardsConfig.Daily.MaximumStreakBonus
	)
	local rewards: { [string]: any } = {}
	if definition.Money then
		rewards.Money = math.floor(definition.Money * (1 + math.max(0, bonus)))
	end
	if definition.Items then
		rewards.Items = definition.Items
	end
	if definition.Spins then
		rewards.Spins = definition.Spins
	end
	if definition.Gears then
		rewards.Gears = definition.Gears
	end
	return rewards
end

--[[
	Claim today's reward.

	Returns `(claimed, message, dayIndex?, streak?)`. Refusing is normal, not an error: a player
	who opens the screen twice hits the "already claimed" path.
]]
function DailyRewardService.TryClaim(player: Player): (boolean, string, number?, number?)
	local state = PlayerStateService.GetRewardState(player)
	if state == nil then
		return false, "Your data is still loading"
	end

	local today = DayClock.today()
	local streak, allowed = DayClock.advanceStreak(
		state.DailyStreak,
		state.DailyLastClaimDay,
		today,
		RewardsConfig.Daily.StreakGraceDays
	)
	if not allowed then
		return false, "ALREADY CLAIMED TODAY"
	end

	--[[
		The calendar day advances independently of the streak. A player who breaks their streak
		still carries on through the calendar rather than being reset to day 1 twice over -- being
		punished in both currencies for one missed day is what makes people stop coming back.
	]]
	local dayIndex = math.clamp(state.DailyCalendarDay, 1, CALENDAR_LENGTH)
	local definition = CALENDAR[dayIndex]
	local rewards = scaledRewards(definition, streak)

	local committed = PlayerStateService.CommitDailyClaim(
		player,
		today,
		streak,
		(dayIndex % CALENDAR_LENGTH) + 1,
		rewards
	)
	if not committed then
		return false, "Could not save that -- try again"
	end
	return true, `DAY {dayIndex} CLAIMED -- {definition.Label}`, dayIndex, streak
end

function DailyRewardService.Start()
	local claim = RemoteService.GetEvent("ClaimDailyReward")
	local notify = RemoteService.GetEvent("Notify")

	claim.OnServerEvent:Connect(function(player: Player)
		if not limiter:Allow(tostring(player.UserId)) then
			return
		end
		local claimed, message, _dayIndex, streak = DailyRewardService.TryClaim(player)
		if claimed and streak then
			notify:FireClient(player, `{message}  (STREAK {streak})`)
		else
			notify:FireClient(player, message)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(tostring(player.UserId))
	end)
end

return table.freeze(DailyRewardService)
