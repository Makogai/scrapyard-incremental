--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RemoteService = require(script.Parent.RemoteService)

local ShopService = {}
local limiter = RateLimiter.new(6, Environment.RemoteRateLimitWindowSeconds)

local function connectWalkIn(zone: BasePart, callback: (Player) -> ())
	local recent: { [Player]: number } = {}
	zone.CanTouch = true
	zone.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = if character then Players:GetPlayerFromCharacter(character) else nil
		if player == nil then
			return
		end
		local now = os.clock()
		if now - (recent[player] or 0) < 1.5 then
			return
		end
		recent[player] = now
		callback(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		recent[player] = nil
	end)
end

function ShopService.Start()
	local map = assert(workspace:FindFirstChild("NewMap"), "Authored NewMap missing")
	local magnetShop = assert(map:FindFirstChild("Magnet Shop"), "Magnet Shop missing")
	local areaShop = assert(map:FindFirstChild("AreaShop"), "AreaShop missing")
	local exclusiveShop = assert(map:FindFirstChild("Shop"), "Generic Shop missing")
	local magnetZone =
		assert(magnetShop:FindFirstChild("CHS_Shop", true), "Magnet CHS_Shop missing") :: BasePart
	local areaZone =
		assert(areaShop:FindFirstChild("CHS_Shop", true), "Area CHS_Shop missing") :: BasePart
	local exclusiveZone =
		assert(exclusiveShop:FindFirstChild("CHS_Shop", true), "Shop CHS_Shop missing") :: BasePart
	connectWalkIn(magnetZone, function(player)
		RemoteService.GetEvent("OpenMagnetShop"):FireClient(player)
	end)
	connectWalkIn(areaZone, function(player)
		RemoteService.GetEvent("OpenAreaShop"):FireClient(player)
	end)
	connectWalkIn(exclusiveZone, function(player)
		RemoteService.GetEvent("OpenExclusiveShop"):FireClient(player)
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
