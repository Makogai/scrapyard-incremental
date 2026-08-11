--!strict
--[[
	EventConfig.luau
	Timed server-wide events, and the schedule that decides which one is live.

	THE SCHEDULE IS A PURE FUNCTION OF UTC TIME. That is the whole design, and it is what makes this
	system cheap enough to actually ship:

		- No database, no admin action, no cron. `activeAt(os.time())` answers "what is on right now"
		  from arithmetic alone.
		- Every server agrees, because they all read the same clock and run the same maths. Two servers
		  cannot disagree about whether Scrap Rush is on.
		- It is testable without a running game. The schedule is the thing most likely to be wrong -- off
		  by an hour, overlapping windows, a window that never opens -- and all of that is provable in
		  `tests/`.
		- A player can learn the cadence. "Double scrap all weekend" is a promise the game keeps by
		  construction; there is no forgetting to turn it on.

	The cost is that events cannot be triggered on a whim. That is the right trade for a cadence
	(audit 3.7): predictability is the feature. Pet Simulator 99 updates every Saturday at 5pm GMT and
	the predictability IS the retention mechanic. A one-off surprise event wants a different tool --
	`Announce` plus a manual multiplier -- and can be added later without touching this.

	ONE EVENT AT A TIME. Windows must not overlap; `tests/` asserts it. Two simultaneous multipliers
	would stack into numbers the economy was never balanced for, and the banner can only show one
	thing anyway.

	ALL TIMES ARE UTC. Roblox servers run UTC and `os.date("!*t")` reads it explicitly. Never use the
	local-time variant here: it would make the schedule depend on where the server happens to be.
]]

local EventConfig = {}

export type EventEffects = {
	ScrapValue: number?,
	Luck: number?,
	RespawnRate: number?,
	CollectionSpeed: number?,
}

export type EventDefinition = {
	Id: string,
	Title: string,
	Detail: string,
	Glyph: string,
	Accent: string,
	Effects: EventEffects,
	--- Day of week (1 = Sunday, matching `os.date`'s `wday`) and hour the window opens, UTC.
	StartDay: number,
	StartHour: number,
	DurationHours: number,
}

local SECONDS_PER_HOUR = 3600
local SECONDS_PER_DAY = 86400
local SECONDS_PER_WEEK = SECONDS_PER_DAY * 7

--[[
	The week's events.

	`StartDay` uses `os.date`'s `wday`: 1 = Sunday, 7 = Saturday. `DurationHours` may cross midnight
	and may cross the end of the week -- the maths below wraps, so a Saturday window that runs 48
	hours correctly covers Sunday.

	Multipliers are deliberately modest. These stack on top of potions, pets, passes and the friend
	boost, all of which are multiplicative already, so a "3x weekend" is nothing like 3x in practice.
	The old fake banner promised 3x scrap value; 2x is what the economy can absorb.
]]
local events: { EventDefinition } = {
	table.freeze({
		Id = "ScrapRush",
		Title = "SCRAP RUSH",
		Detail = "2x scrap value all weekend",
		Glyph = "coin",
		Accent = "Gold",
		Effects = table.freeze({ ScrapValue = 2 }),
		--- Saturday 00:00 UTC through Monday 00:00 UTC.
		StartDay = 7,
		StartHour = 0,
		DurationHours = 48,
	}),
	table.freeze({
		Id = "LuckyHour",
		Title = "LUCKY HOUR",
		Detail = "2x rare scrap luck",
		Glyph = "star",
		Accent = "Purple",
		Effects = table.freeze({ Luck = 2 }),
		--- Wednesday 18:00-20:00 UTC: a midweek reason to log in that is not the weekend.
		StartDay = 4,
		StartHour = 18,
		DurationHours = 2,
	}),
	table.freeze({
		Id = "ScrapStorm",
		Title = "SCRAP STORM",
		Detail = "Scrap respawns twice as fast",
		Glyph = "magnet",
		Accent = "Cyan",
		Effects = table.freeze({ RespawnRate = 2, CollectionSpeed = 1.5 }),
		--- Tuesday 18:00-20:00 UTC.
		StartDay = 3,
		StartHour = 18,
		DurationHours = 2,
	}),
}

EventConfig.Events = table.freeze(events)

--- Seconds from the start of the UTC week (Sunday 00:00) that this event's window opens.
local function windowStart(definition: EventDefinition): number
	return (definition.StartDay - 1) * SECONDS_PER_DAY + definition.StartHour * SECONDS_PER_HOUR
end

--- Where `now` sits within the UTC week, in seconds from Sunday 00:00.
local function weekOffset(now: number): number
	local parts = os.date("!*t", now)
	return (parts.wday - 1) * SECONDS_PER_DAY
		+ parts.hour * SECONDS_PER_HOUR
		+ parts.min * 60
		+ parts.sec
end

--[[
	The live event, and how long is left of it.

	Returns `(definition, secondsRemaining)` or `nil`. Windows are half-open -- `[start, start+duration)`
	-- so an event that ends exactly as another begins hands over cleanly with no frame where both are
	live and no frame where neither is.
]]
function EventConfig.activeAt(now: number): (EventDefinition?, number)
	local offset = weekOffset(now)
	for _, definition in events do
		local start = windowStart(definition)
		local duration = definition.DurationHours * SECONDS_PER_HOUR
		--[[
			Tested at two offsets: `offset` itself, and `offset + a week`. A window that runs past
			Saturday midnight starts in one week and ends in the next, so the wrapped position is the
			only one that lands inside it.
		]]
		for _, position in { offset, offset + SECONDS_PER_WEEK } do
			if position >= start and position < start + duration then
				return definition, start + duration - position
			end
		end
	end
	return nil, 0
end

--[[
	The next event to open, and how long until it does. Never returns nil while `Events` is non-empty:
	the schedule repeats weekly, so something is always coming.

	Used for the "next event" line when nothing is live -- a banner that only appears during an event
	teaches nobody the cadence, and the cadence is the point.
]]
function EventConfig.nextAt(now: number): (EventDefinition?, number)
	local offset = weekOffset(now)
	local bestDefinition: EventDefinition? = nil
	local bestWait: number? = nil
	for _, definition in events do
		local start = windowStart(definition)
		--- Wrap into the future: an event earlier in the week is next week's.
		local wait = (start - offset) % SECONDS_PER_WEEK
		if bestWait == nil or wait < bestWait then
			bestWait = wait
			bestDefinition = definition
		end
	end
	return bestDefinition, bestWait or 0
end

--[[
	The multiplier the live event applies to one stat, or 1 when nothing applies.

	This is the function the gameplay reads. Everything goes through it rather than through a service,
	which is why there is no `EventService` dependency anywhere in `PlayerStateService`: the schedule
	is arithmetic, so any code that needs it can just ask.
]]
function EventConfig.multiplierAt(effect: string, now: number): number
	local definition = EventConfig.activeAt(now)
	if definition == nil then
		return 1
	end
	return (definition.Effects :: { [string]: number? })[effect] or 1
end

return table.freeze(EventConfig)
