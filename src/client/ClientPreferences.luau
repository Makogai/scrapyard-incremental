--!strict

local ClientPreferences = {}
local settings: { [string]: any } = {
	ParticlesEnabled = true,
	ScreenEffectsEnabled = true,
	SoundEnabled = true,
	MusicEnabled = true,
	SoundVolume = 0.8,
	MusicVolume = 0.55,
}

function ClientPreferences.Update(newSettings: { [string]: any })
	for key, value in newSettings do
		if settings[key] ~= nil and (typeof(value) == "boolean" or typeof(value) == "number") then
			settings[key] = value
		end
	end
end

function ClientPreferences.GetVolume(key: string): number
	local value = settings[key]
	return if typeof(value) == "number" then math.clamp(value, 0, 1) else 1
end

function ClientPreferences.Get(key: string): boolean
	return settings[key] == true
end

return table.freeze(ClientPreferences)
