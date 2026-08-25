--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local PlotService = require(script.Parent.PlotService)
local PlotThemeService = require(script.Parent.PlotThemeService)
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
			--[[
				Unlocking an area rebuilds the plot as that theme. `RefreshAppearance` only moves
				gates; the yard itself is the variant, so without `Rebuild` they would keep walking
				a Front Yard they just paid to leave. `Rebuild` stands scrap back up, which is why
				the scrap refresh is the fallback when there is no plot yet.
			]]
			local plot = PlotService.GetPlot(player)
			if plot ~= nil then
				PlotThemeService.Rebuild(player, plot)
			else
				PlotService.RefreshAppearance(player)
				ScrapService.RefreshPlayer(player)
			end
		end
	end)
end

return table.freeze(AreaService)
