--!strict
--[[
	DayClock.luau
	One definition of "what day is it", shared by the daily calendar, playtime milestones and the
	spin wheel.

	WHY A DAY NUMBER AND NOT A TIMESTAMP. Every one of those systems has to answer two questions:
	"have they already claimed today" and "was their last claim yesterday". With raw timestamps
	both are awkward and both have an off-by-one that hands out a second free reward -- `now - last
	>= 86400` lets someone claim at 23:59 and again at 00:01, and `>= 86400` with a clock skew
	misses a legitimate day. Comparing integer day numbers makes both questions exact.

	It is UTC, deliberately: the day rolls at the same instant for every player, which is what
	makes a server-wide daily reset and a leaderboard reset agree with each other. A player's local
	midnight is not knowable server-side anyway.

	Pure functions, no `os.time()` inside the comparisons, so the test suite can drive them.
]]

local DayClock = {}

DayClock.SecondsPerDay = 86400

--- The UTC day number for a unix timestamp. Day 0 is 1970-01-01.
function DayClock.dayNumber(timestamp: number): number
	return math.floor(timestamp / DayClock.SecondsPerDay)
end

--- Today, from the server clock.
function DayClock.today(): number
	return DayClock.dayNumber(os.time())
end

--- Seconds until the next day rolls over, for a countdown.
function DayClock.secondsUntilNextDay(timestamp: number): number
	local elapsed = timestamp % DayClock.SecondsPerDay
	return DayClock.SecondsPerDay - elapsed
end

--[[
	What a claim on `today` does to a streak that last claimed on `lastClaimDay`.

	Returns the new streak and whether the claim is allowed at all:

		already claimed today        -> (streak, false)
		first ever claim             -> (1, true)
		consecutive, or inside grace -> (streak + 1, true)
		beyond grace                 -> (1, true), streak reset

	`graceDays` of 1 means one missed day is forgiven. That is deliberate generosity: losing a
	30-day streak to a single busy evening is the kind of punishment that makes players stop
	returning rather than return harder.
]]
function DayClock.advanceStreak(
	streak: number,
	lastClaimDay: number,
	today: number,
	graceDays: number
): (number, boolean)
	if lastClaimDay == today then
		return streak, false
	end
	if lastClaimDay <= 0 then
		return 1, true
	end
	local missed = today - lastClaimDay - 1
	if missed <= graceDays then
		return streak + 1, true
	end
	return 1, true
end

return table.freeze(DayClock)
