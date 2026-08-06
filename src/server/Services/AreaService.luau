--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local PlotService = require(script.Parent.PlotService)
local RemoteService = require(script.Parent.RemoteService)
local ScrapService = require(script.Parent.ScrapService)

local AreaService = {}
local limiter = RateLimiter.new(
	Environment.MaximumRemoteRequestsPerWindow,
	Environment.RemoteRateLimitWindowSeconds
)

function AreaService.Start()
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(tostring(player.UserId))
	end)
	RemoteService.GetEvent("RequestAreaUnlock").OnServerEvent:Connect(function(player, areaId)
		if typeof(areaId) ~= "string" or not limiter:Allow(tostring(player.UserId)) then
			return
		end
		local succeeded, message = PlayerStateService.TryUnlockArea(player, areaId)
		RemoteService.GetEvent("Notify"):FireClient(player, message)
		if succeeded then
			PlotService.RefreshAppearance(player)
			ScrapService.RefreshPlayer(player)
		end
	end)
end

return table.freeze(AreaService)
