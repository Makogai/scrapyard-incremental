--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RemoteService = require(script.Parent.RemoteService)

local ShopService = {}
local limiter = RateLimiter.new(6, Environment.RemoteRateLimitWindowSeconds)

function ShopService.Start()
	local shop =
		assert(workspace.SharedHub:FindFirstChild("MagnetShop"), "Authored MagnetShop missing")
	local prompt =
		assert(shop:FindFirstChild("ShopPrompt", true), "MagnetShop prompt missing") :: ProximityPrompt
	prompt.Triggered:Connect(function(player)
		RemoteService.GetEvent("OpenMagnetShop"):FireClient(player)
	end)
	RemoteService.GetEvent("ShopAction").OnServerEvent:Connect(function(player, action, magnetId)
		if
			action ~= "BuyMagnet"
			or typeof(magnetId) ~= "string"
			or not limiter:Allow(tostring(player.UserId))
		then
			return
		end
		local _, message = PlayerStateService.TryBuyMagnet(player, magnetId)
		RemoteService.GetEvent("Notify"):FireClient(player, message)
	end)
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(tostring(player.UserId))
	end)
end

return table.freeze(ShopService)
