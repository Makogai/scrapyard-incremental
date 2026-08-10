--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)
local ClientPreferences = require(script.Parent.Parent.ClientPreferences)

local AudioController = {}

local function playHook(name: string)
	if not ClientPreferences.Get("SoundEnabled") then
		return
	end
	local folder = SoundService:FindFirstChild("ScrapyardAudio")
	local sound = if folder then folder:FindFirstChild(name) else nil
	if sound and sound:IsA("Sound") and sound.SoundId ~= "" then
		sound.Volume = AudioConfig[name].Volume * ClientPreferences.GetVolume("SoundVolume")
		sound:Play()
	end
end

function AudioController.Start()
	local audioFolder = SoundService:WaitForChild("ScrapyardAudio")
	for hookName, definition in AudioConfig do
		local sound = audioFolder:FindFirstChild(hookName)
		if sound and sound:IsA("Sound") then
			sound.SoundId = `rbxassetid://{definition.AssetId}`
			sound.Volume = definition.Volume
			sound.PlaybackSpeed = definition.PlaybackSpeed
			sound.Looped = hookName == "MusicLoop"
		end
	end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local gameplayEffect = remotes:WaitForChild("GameplayEffect") :: RemoteEvent
	gameplayEffect.OnClientEvent:Connect(function(effectName: string)
		if effectName == "Collected" then
			playHook("CollectSound")
		end
	end)
	local notify = remotes:WaitForChild("Notify") :: RemoteEvent
	notify.OnClientEvent:Connect(function(message: unknown)
		-- `Notify` is a plain string by contract, but a producer sending the wrong shape must not
		-- take the audio controller down with it -- this connection dying silently kills every
		-- later sound hook, which is far harder to trace back than a missing sell chime.
		if typeof(message) ~= "string" then
			warn(`[AudioController] Notify expected a string, got {typeof(message)}`)
			return
		end
		if string.find(message, "SOLD", 1, true) then
			playHook("SellSound")
		else
			playHook("ConfirmSound")
		end
	end)
	local stateChanged = remotes:WaitForChild("StateChanged") :: RemoteEvent
	stateChanged.OnClientEvent:Connect(function(state)
		ClientPreferences.Update(state.Settings)
		local folder = SoundService:FindFirstChild("ScrapyardAudio")
		if folder then
			for hookName, definition in AudioConfig do
				local sound = folder:FindFirstChild(hookName)
				if sound and sound:IsA("Sound") then
					sound.Volume = definition.Volume
						* ClientPreferences.GetVolume(
							if hookName == "MusicLoop" then "MusicVolume" else "SoundVolume"
						)
				end
			end
		end
		local music = if folder then folder:FindFirstChild("MusicLoop") else nil
		if music and music:IsA("Sound") then
			if
				ClientPreferences.Get("MusicEnabled")
				and music.SoundId ~= ""
				and not music.IsPlaying
			then
				music:Play()
			elseif not ClientPreferences.Get("MusicEnabled") and music.IsPlaying then
				music:Stop()
			end
		end
	end)
end

return table.freeze(AudioController)
