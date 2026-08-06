--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local PlotService = require(script.Parent.PlotService)
local RemoteService = require(script.Parent.RemoteService)

local UpgradeService = {}
local limiter = RateLimiter.new(
	Environment.MaximumRemoteRequestsPerWindow,
	Environment.RemoteRateLimitWindowSeconds
)

function UpgradeService.Start()
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(tostring(player.UserId))
	end)
	RemoteService.GetEvent("RequestUpgrade").OnServerEvent:Connect(function(player, upgradeId)
		if typeof(upgradeId) ~= "string" then
			return
		end
		if not limiter:Allow(tostring(player.UserId)) then
			return
		end
		local succeeded, message = PlayerStateService.TryPurchaseUpgrade(player, upgradeId)
		RemoteService.GetEvent("Notify"):FireClient(player, message)
		if succeeded then
			PlotService.RefreshAppearance(player)
		end
	end)
end

return table.freeze(UpgradeService)
