--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RemoteService = require(script.Parent.RemoteService)

local SettingsService = {}
local limiter = RateLimiter.new(
	Environment.MaximumRemoteRequestsPerWindow,
	Environment.RemoteRateLimitWindowSeconds
)

function SettingsService.Start()
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(tostring(player.UserId))
	end)
	RemoteService.GetEvent("UpdateSettings").OnServerEvent
		:Connect(function(player, settingId, value)
			if
				typeof(settingId) ~= "string"
				or (typeof(value) ~= "boolean" and typeof(value) ~= "number")
				or not limiter:Allow(tostring(player.UserId))
			then
				return
			end
			PlayerStateService.TryUpdateSetting(player, settingId, value)
		end)
end

return table.freeze(SettingsService)
