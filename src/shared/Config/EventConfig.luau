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
	--[[
		Opens THE PIT for as long as the window lasts. See `ArenaConfig`.

		The only event flag that does something other than multiply a number. `ArenaService` watches for
		it; nothing else in the event system cares, so a second arena event would work by setting this
		and nothing else.
	]]
	Arena: boolean?,
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
	--[[
		THE PIT. The one event that changes WHERE you play rather than what the numbers are.

		Its multipliers are small on purpose: the draw is a shared hoard with late-game scrap in it and
		other players racing you for it, and stacking a big multiplier on top would make the Pit the only
		correct place to be for two hours rather than somewhere you choose to go. Scrap value is left
		alone entirely -- the arena already pays better simply because it holds scrap cars.

		FRIDAY EVENING, and the slot is not a free choice. Windows may not overlap -- `tests/` asserts it,
		because two live multipliers stack into numbers the economy was never balanced for -- and Scrap
		Rush already owns all of Saturday and Sunday. Friday 18:00 is the busiest hour left, which matters
		more for this event than for any other: a shared arena with nobody else in it is just a worse plot.
	]]
	table.freeze({
		Id = "ScrapPit",
		Title = "THE PIT",
		Detail = "A shared arena outside -- race everyone for it",
		Glyph = "crate",
		Accent = "Red",
		Effects = table.freeze({ CollectionSpeed = 1.25 }),
		--- Friday 18:00-22:00 UTC, in the gap before Scrap Rush opens at Saturday midnight.
		StartDay = 6,
		StartHour = 18,
		DurationHours = 4,
		Arena = true,
	}),
}

EventConfig.Events = table.freeze(events)

--[[
	The same events keyed by id.

	Added because three separate places were walking `Events` with a `for` loop to answer "which event is
	this id" -- the store, the world billboard, and now the override below. A linear scan over three
	entries costs nothing; three copies of the same scan is how one of them ends up subtly different.
]]
local eventsById: { [string]: EventDefinition } = {}
for _, definition in events do
	eventsById[definition.Id] = definition
end
EventConfig.ById = table.freeze(eventsById)

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
	AN EVENT AN ADMIN STARTED BY HAND, which outranks the schedule while it lasts.

	SERVER-SIDE RUNTIME STATE living in a config module, which wants justifying. Everything that asks
	"what event is live" already goes through `activeAt` -- `derivedStats` for the multipliers, the player
	snapshot for the HUD banner, `EventService` for the world billboard and the announcement. Putting the
	override anywhere else would mean editing all of those call sites, or having two answers to one
	question -- and two answers is exactly how a banner ends up claiming 3x while the payouts disagree.

	Only the server ever sets it. The client computes nothing about events: it is handed the live one in
	its snapshot and looks the title and colour up by id, so there is nothing to replicate.

	It expires by time rather than by being cleared, so a server that stops running its poll still falls
	back to the schedule on its own.
]]
local override: { Id: string, EndsAt: number }? = nil

--[[
	Start an event by hand, or stop one. `seconds <= 0` clears it.

	Returns false for an unknown id, so nobody can start an event with no definition behind it -- which
	would show a banner promising effects that do not exist.
]]
function EventConfig.setOverride(eventId: string?, seconds: number): boolean
	if eventId == nil or seconds <= 0 then
		override = nil
		return true
	end
	if EventConfig.ById[eventId] == nil then
		return false
	end
	override = { Id = eventId, EndsAt = os.time() + seconds }
	return true
end

--- The hand-started event and its remaining seconds, or nil. An expired override clears itself here.
function EventConfig.overrideAt(now: number): (EventDefinition?, number)
	local current = override
	if current == nil then
		return nil, 0
	end
	if now >= current.EndsAt then
		override = nil
		return nil, 0
	end
	return EventConfig.ById[current.Id], current.EndsAt - now
end

--[[
	The live event, and how long is left of it.

	Returns `(definition, secondsRemaining)` or `nil`. Windows are half-open -- `[start, start+duration)`
	-- so an event that ends exactly as another begins hands over cleanly with no frame where both are
	live and no frame where neither is.

	A hand-started event is checked FIRST and wins outright. An admin who starts one during a scheduled
	window expects to see the one they started, not to be told the schedule had other ideas.
]]
function EventConfig.activeAt(now: number): (EventDefinition?, number)
	local forced, forcedRemaining = EventConfig.overrideAt(now)
	if forced ~= nil then
		return forced, forcedRemaining
	end

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
