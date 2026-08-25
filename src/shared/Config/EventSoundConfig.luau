--!strict
--[[
	EventSoundConfig.luau
	The sting that plays when a timed event STARTS.

	HOW TO ADD OR CHANGE A SOUND
		1. Use the event's `EventConfig` id as the key (`ScrapPit`, `ScrapRush`, …).
		2. Paste the Roblox audio asset id into `AssetId`.
		3. Volume / speed / loop are optional -- `Default` fills anything you leave out.
		4. Omit the event, or leave `AssetId` empty, for silence.

	Nothing else to edit. The client reads this table when `EventState.LiveId` changes.
	Joining mid-event does not replay the sting; only a start does.
]]

export type EventSound = {
	AssetId: string,
	Volume: number?,
	PlaybackSpeed: number?,
	Looped: boolean?,
}

local EventSoundConfig = {}

--- Used when an entry does not set Volume, PlaybackSpeed, or Looped.
EventSoundConfig.Default = table.freeze({
	Volume = 0.55,
	PlaybackSpeed = 1,
	Looped = false,
})

EventSoundConfig.ById = table.freeze({
	ScrapPit = table.freeze({
		AssetId = "93775470439672",
		Volume = 0.55,
		PlaybackSpeed = 1,
		Looped = false,
	}),
	-- ScrapRush = table.freeze({ AssetId = "", Volume = 0.5 }),
	-- LuckyHour = table.freeze({ AssetId = "", Volume = 0.5 }),
	-- ScrapStorm = table.freeze({ AssetId = "", Volume = 0.5 }),
})

return table.freeze(EventSoundConfig)
