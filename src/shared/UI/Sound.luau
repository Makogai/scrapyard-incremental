--[[
	Sound.luau
	UI audio: clicks, hovers, purchases, errors.

		Sound.play("click")
		Sound.setVolume(0.8)      -- driven by the SFX slider in Settings
		Sound.setEnabled(true)

	Every cue is built from ONE verified built-in sample --
	`rbxasset://sounds/volume_slider.ogg`, the soft tick Roblox uses on its own
	volume slider -- re-pitched per cue, and played as a short arpeggio for the
	celebratory ones. A single sample at 1.0 / 1.26 / 1.5 is a major chord, which
	is why `claim` reads as a jingle rather than three clicks.

	That is a deliberate choice over shipping invented `rbxassetid://` numbers,
	which would point at whatever happens to live at those ids. To use your own
	audio, replace the `id` fields in Sound.Library -- one line per cue, and
	nothing else in the kit changes.

	Silent in Studio's edit mode by default, so browsing UI Labs stories does not
	click at you. Call Sound.setEnabled(true) to hear it there, or use the SOUND
	toggle in the in-game dev panel.
]]

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Sound = {}

local CLICK = "rbxasset://sounds/volume_slider.ogg"

--[[
	pitch    playback speed for a single hit
	volume   0..1, scaled by the master SFX volume
	chord    play the sample once per entry, at these pitches, `stagger` apart
]]
Sound.Library = {
	-- `throttle` is a minimum gap in seconds. Hover would otherwise machine-gun
	-- when the pointer sweeps across a grid of cards.
	hover = { id = CLICK, pitch = 1.8, volume = 0.16, throttle = 0.06 },
	click = { id = CLICK, pitch = 1.15, volume = 0.5 },
	tap = { id = CLICK, pitch = 1.35, volume = 0.3 },
	toggle = { id = CLICK, pitch = 1.25, volume = 0.4 },

	open = { id = CLICK, pitch = 0.9, volume = 0.5 },
	close = { id = CLICK, pitch = 0.7, volume = 0.42 },

	equip = { id = CLICK, pitch = 1.5, volume = 0.42 },
	sell = { id = CLICK, pitch = 1.1, volume = 0.5, chord = { 1.1, 1.45 }, stagger = 0.05 },
	purchase = { id = CLICK, pitch = 1, volume = 0.55, chord = { 1, 1.5 }, stagger = 0.07 },
	claim = { id = CLICK, pitch = 1, volume = 0.55, chord = { 1, 1.26, 1.5 }, stagger = 0.07 },
	--[[
		A BROADCAST ARRIVING. Two notes rather than a chord, so it reads as an alert rather than a reward --
		and loud enough to pull your eyes up from the yard, which is the whole point of a broadcast.

		Deliberately not `prestige`: that fanfare means "you achieved something", and staff talking is not
		the player's achievement.
	]]
	broadcast = { id = CLICK, pitch = 1.3, volume = 0.62, chord = { 1.3, 1.75 }, stagger = 0.11 },

	prestige = {
		id = CLICK,
		pitch = 0.8,
		volume = 0.6,
		chord = { 0.8, 1, 1.2, 1.6 },
		stagger = 0.08,
	},
	notify = { id = CLICK, pitch = 1.6, volume = 0.38, chord = { 1.6, 2 }, stagger = 0.06 },

	-- Egg hatching. `shake` fires repeatedly, so it is quiet and throttled; `poof`
	-- and `secret` fire once each and can afford to be chords.
	shake = { id = CLICK, pitch = 0.75, volume = 0.22, throttle = 0.05 },
	poof = { id = CLICK, pitch = 1.2, volume = 0.55, chord = { 1.2, 1.6, 2 }, stagger = 0.04 },
	secret = {
		id = CLICK,
		pitch = 0.7,
		volume = 0.6,
		chord = { 0.7, 1.05, 1.4, 1.75, 2.1 },
		stagger = 0.08,
	},

	error = { id = CLICK, pitch = 0.6, volume = 0.5, chord = { 0.6, 0.5 }, stagger = 0.08 },
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local POOL_SIZE = 10

--[[
	`RunService:IsEdit()` carries Plugin security: it answers in a plugin (UI Labs)
	but THROWS in a LocalScript, which took the whole require chain down with it.
	pcall it and treat "cannot ask" as "we are running", which is the safe default
	-- audio on in game, silent while browsing stories.
]]
local function isEditMode(): boolean
	local ok, result = pcall(function()
		return RunService:IsEdit()
	end)
	return ok and result == true
end

local enabled = not isEditMode()
local masterVolume = 1

local group: SoundGroup? = nil
local pool: { Sound } = {}
local nextIndex = 1
local lastPlayed: { [string]: number } = {}

local function ensurePool()
	if group then
		return
	end

	local soundGroup = Instance.new("SoundGroup")
	soundGroup.Name = "ScrapyardUI"
	soundGroup.Volume = masterVolume
	soundGroup.Parent = SoundService
	group = soundGroup

	-- A pool lets cues overlap: a rapid click while a purchase jingle is still
	-- ringing gets its own voice instead of cutting the jingle off.
	for index = 1, POOL_SIZE do
		local sound = Instance.new("Sound")
		sound.Name = "Voice" .. index
		sound.SoundGroup = soundGroup
		sound.Parent = soundGroup
		pool[index] = sound
	end
end

local function emit(id: string, pitch: number, volume: number)
	ensurePool()

	local sound = pool[nextIndex]
	nextIndex = nextIndex % POOL_SIZE + 1
	if not sound then
		return
	end

	sound.SoundId = id
	sound.PlaybackSpeed = pitch
	sound.Volume = volume
	sound.TimePosition = 0
	sound:Play()
end

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

--- Plays a named cue. Unknown names and blank ids are ignored, so a stripped
--- Library never errors at a call site.
function Sound.play(name: string)
	if not enabled then
		return
	end

	local cue = Sound.Library[name]
	if not cue or cue.id == nil or cue.id == "" then
		return
	end

	if cue.throttle then
		local now = os.clock()
		if now - (lastPlayed[name] or -math.huge) < cue.throttle then
			return
		end
		lastPlayed[name] = now
	end

	if cue.chord then
		local stagger = cue.stagger or 0.07
		for index, pitch in ipairs(cue.chord) do
			if index == 1 then
				emit(cue.id, pitch, cue.volume or 0.5)
			else
				task.delay((index - 1) * stagger, function()
					if enabled then
						emit(cue.id, pitch, cue.volume or 0.5)
					end
				end)
			end
		end
	else
		emit(cue.id, cue.pitch or 1, cue.volume or 0.5)
	end
end

--- Master SFX volume, 0..1. Wired to the Settings slider through the store.
function Sound.setVolume(volume: number)
	masterVolume = math.clamp(volume, 0, 1)
	if group then
		group.Volume = masterVolume
	end
end

function Sound.getVolume(): number
	return masterVolume
end

function Sound.setEnabled(value: boolean)
	enabled = value
end

function Sound.isEnabled(): boolean
	return enabled
end

--- Overrides ids or tuning without replacing the whole table:
---   Sound.configure({ click = { id = "rbxassetid://123", volume = 0.6 } })
function Sound.configure(overrides: { [string]: any })
	for name, patch in pairs(overrides) do
		local cue = Sound.Library[name]
		if cue then
			for key, value in pairs(patch) do
				cue[key] = value
			end
		else
			Sound.Library[name] = patch
		end
	end
end

return Sound
