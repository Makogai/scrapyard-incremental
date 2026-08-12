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
			--[[
				A REBIRTH HAS TO REBUILD THE PLOT, not just refresh it.

				`RefreshAppearance` moves the gates and the stage visibility, but the yard geometry standing
				in the world is whatever the player last converted to. A rebirth takes the area unlocks away,
				so without the rebuild they walked out of the rebirth still standing in a Vehicle Graveyard.

				`Rebuild` swaps the geometry and calls `ActivateScrap` itself, which is why the scrap refresh
				is the fallback rather than an extra step -- running both would spawn the yard twice. Same
				shape as the profile wipe in `AdminService`.
			]]
			local plot = PlotService.GetPlot(player)
			if plot ~= nil then
				PlotThemeService.Rebuild(player, plot)
			else
				ScrapService.RefreshPlayer(player)
			end
		end
	end)
end

return table.freeze(PrestigeService)
