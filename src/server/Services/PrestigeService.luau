--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local PlotService = require(script.Parent.PlotService)
local RemoteService = require(script.Parent.RemoteService)
local ScrapService = require(script.Parent.ScrapService)

local PrestigeService = {}
local limiter = RateLimiter.new(2, Environment.RemoteRateLimitWindowSeconds)

function PrestigeService.Start()
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(tostring(player.UserId))
	end)
	RemoteService.GetEvent("RequestPrestige").OnServerEvent:Connect(function(player)
		if not limiter:Allow(tostring(player.UserId)) then
			return
		end
		local succeeded, message = PlayerStateService.TryPrestige(player)
		RemoteService.GetEvent("Notify"):FireClient(player, message)
		if succeeded then
			PlotService.RefreshAppearance(player)
			ScrapService.RefreshPlayer(player)
		end
	end)
end

return table.freeze(PrestigeService)
