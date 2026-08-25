--!strict
--[[
	EventSoundController.luau
	Plays the cue from `EventSoundConfig` when a timed event starts.

	Reads `ReplicatedStorage.EventState.LiveId`, the same attribute `EventService` writes for
	the world billboard. No extra remote: a start is "LiveId changed to a real event id".

	The first value we see is treated as already-live -- a player who joins during THE PIT
	must not hear the open sting, same rule as the announcement popup.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local ClientPreferences = require(script.Parent.Parent.ClientPreferences)
local EventSoundConfig = require(ReplicatedStorage.Shared.Config.EventSoundConfig)

local EventSoundController = {}

local playing: Sound? = nil
local seenInitial = false

local function stopLooped()
	local sound = playing
	if sound ~= nil and sound.Looped then
		sound:Stop()
		sound:Destroy()
		playing = nil
	end
end

local function play(eventId: string)
	local entry = EventSoundConfig.ById[eventId]
	if entry == nil or entry.AssetId == "" then
		return
	end
	if not ClientPreferences.Get("SoundEnabled") then
		return
	end

	local previous = playing
	if previous then
		previous:Stop()
		previous:Destroy()
		playing = nil
	end

	local defaults = EventSoundConfig.Default
	local sound = Instance.new("Sound")
	sound.Name = `Event_{eventId}`
	sound.SoundId = `rbxassetid://{entry.AssetId}`
	sound.Volume = (entry.Volume or defaults.Volume) * ClientPreferences.GetVolume("SoundVolume")
	sound.PlaybackSpeed = entry.PlaybackSpeed or defaults.PlaybackSpeed
	sound.Looped = if entry.Looped ~= nil then entry.Looped else defaults.Looped
	sound.Parent = SoundService
	sound:Play()
	playing = sound
	if not sound.Looped then
		sound.Ended:Connect(function()
			if playing == sound then
				sound:Destroy()
				playing = nil
			end
		end)
	end
end

local function onLiveId(liveId: unknown)
	local id = if typeof(liveId) == "string" then liveId else ""
	if not seenInitial then
		seenInitial = true
		return
	end
	if id == "" then
		stopLooped()
		return
	end
	play(id)
end

function EventSoundController.Start()
	local folder = ReplicatedStorage:WaitForChild("EventState", 20)
	if folder == nil then
		warn("[EventSound] EventState never replicated -- event start cues will not play")
		return
	end
	onLiveId(folder:GetAttribute("LiveId"))
	folder:GetAttributeChangedSignal("LiveId"):Connect(function()
		onLiveId(folder:GetAttribute("LiveId"))
	end)
end

return table.freeze(EventSoundController)
