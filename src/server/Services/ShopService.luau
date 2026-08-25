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

local function childNamed(parent: Instance, names: { string }): Instance?
	for _, name in names do
		local found = parent:FindFirstChild(name)
		if found then
			return found
		end
	end
	return nil
end

local function bindZone(root: Instance?, zoneName: string, label: string, callback: (Player) -> ())
	if root == nil then
		warn(`[ShopService] {label} is missing under NewMap -- walk-in for it is off`)
		return
	end
	local zone = root:FindFirstChild(zoneName, true)
	if zone == nil or not zone:IsA("BasePart") then
		warn(`[ShopService] {label} has no {zoneName} part -- walk-in for it is off`)
		return
	end
	connectWalkIn(zone, callback)
end

function ShopService.Start()
	local map = workspace:FindFirstChild("NewMap")
	if map == nil then
		warn("[ShopService] Authored NewMap missing -- walk-in shops are off, remote buys still work")
	else
		--[[
			Names as authored. `Magnet Shop` used to be the lookup; the map now has `MagnetShop`.
			An assert here used to abort the entire server bootstrap, which is why pets stopped
			loading and ENTER THE PIT did nothing -- everything after ShopService.Start never ran.
		]]
		bindZone(childNamed(map, { "Magnet Shop", "MagnetShop" }), "CHS_Shop", "Magnet Shop", function(player)
			RemoteService.GetEvent("OpenMagnetShop"):FireClient(player)
		end)
		bindZone(childNamed(map, { "AreaShop", "Area Shop" }), "CHS_Shop", "Area shop", function(player)
			RemoteService.GetEvent("OpenAreaShop"):FireClient(player)
		end)
		bindZone(childNamed(map, { "Shop", "Exclusive Shop" }), "CHS_Shop", "Exclusive shop", function(player)
			RemoteService.GetEvent("OpenExclusiveShop"):FireClient(player)
		end)
	end

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
