--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local PitShopConfig = require(ReplicatedStorage.Shared.Config.PitShopConfig)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local ArenaService = require(script.Parent.ArenaService)
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

local function bindWalkIn(target: Instance, callback: (Player) -> ()): boolean
	if target:IsA("BasePart") then
		connectWalkIn(target, callback)
		return true
	end
	local chs = target:FindFirstChild("CHS_Shop", true)
	if chs and chs:IsA("BasePart") then
		connectWalkIn(chs, callback)
		return true
	end
	if target:IsA("Model") then
		local part = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
		if part and part:IsA("BasePart") then
			connectWalkIn(part, callback)
			return true
		end
	end
	return false
end

local function bindPitShop()
	local area = workspace:FindFirstChild("Event Area")
		or workspace:FindFirstChild("Event Area", true)
	if area == nil then
		warn("[ShopService] Event Area missing -- Pit shop walk-in is off")
		return
	end

	local function openShop(player: Player)
		if ArenaService.IsOpen() then
			RemoteService.GetEvent("OpenPitShop"):FireClient(player)
		end
	end

	--[[
		Do not put a shop prompt on PitSpawn. The shop is Event Shop's walk-in, same
		pattern as Magnet Shop / Area Shop (`CHS_Shop` under the booth).
	]]
	for _, descendant in area:GetDescendants() do
		if descendant.Name == "PitShopPrompt" and descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		end
	end

	local bound = false
	for _, name in PitShopConfig.ZoneNames do
		local booth = area:FindFirstChild(name, true)
		if booth and bindWalkIn(booth, openShop) then
			bound = true
		end
	end

	if not bound then
		local booth = workspace:FindFirstChild("Event Shop", true)
			or workspace:FindFirstChild("EventShop", true)
		if booth and bindWalkIn(booth, openShop) then
			bound = true
		end
	end

	if not bound then
		warn(
			"[ShopService] No Event Shop / CHS_Shop under Event Area -- Pit shop walk-in is off"
		)
	end
end

function ShopService.Start()
	local map = workspace:FindFirstChild("NewMap")
	if map == nil then
		warn(
			"[ShopService] Authored NewMap missing -- walk-in shops are off, remote buys still work"
		)
	else
		--[[
			Names as authored. `Magnet Shop` used to be the lookup; the map now has `MagnetShop`.
			An assert here used to abort the entire server bootstrap, which is why pets stopped
			loading and ENTER THE PIT did nothing -- everything after ShopService.Start never ran.
		]]
		bindZone(
			childNamed(map, { "Magnet Shop", "MagnetShop" }),
			"CHS_Shop",
			"Magnet Shop",
			function(player)
				RemoteService.GetEvent("OpenMagnetShop"):FireClient(player)
			end
		)
		bindZone(
			childNamed(map, { "AreaShop", "Area Shop" }),
			"CHS_Shop",
			"Area shop",
			function(player)
				RemoteService.GetEvent("OpenAreaShop"):FireClient(player)
			end
		)
		bindZone(
			childNamed(map, { "Shop", "Exclusive Shop" }),
			"CHS_Shop",
			"Exclusive shop",
			function(player)
				RemoteService.GetEvent("OpenExclusiveShop"):FireClient(player)
			end
		)
		bindZone(
			childNamed(map, { "GearShop", "Gear Shop" }),
			"CHS_Shop",
			"Gear shop",
			function(player)
				RemoteService.GetEvent("OpenGearShop"):FireClient(player)
			end
		)
	end

	bindPitShop()

	RemoteService.GetEvent("ShopAction").OnServerEvent:Connect(function(player, action, itemId)
		if typeof(action) ~= "string" or typeof(itemId) ~= "string" then
			return
		end
		if not limiter:Allow(tostring(player.UserId)) then
			return
		end
		if action == "BuyMagnet" then
			local _, message = PlayerStateService.TryBuyMagnet(player, itemId)
			RemoteService.GetEvent("Notify"):FireClient(player, message)
			return
		end
		if action == "BuyMagnetSkin" then
			local _, message = PlayerStateService.TryBuyMagnetSkin(player, itemId)
			RemoteService.GetEvent("Notify"):FireClient(player, message)
			return
		end
		if action == "BuyPitItem" then
			if not ArenaService.IsOpen() or not ArenaService.PlayerIsInside(player) then
				RemoteService.GetEvent("Notify"):FireClient(player, "Go to The Pit to shop")
				return
			end
			local _, message = PlayerStateService.TryBuyPitOffer(player, itemId)
			RemoteService.GetEvent("Notify"):FireClient(player, message)
			return
		end
		if action == "BuyGearItem" then
			local _, message = PlayerStateService.TryBuyGearOffer(player, itemId)
			RemoteService.GetEvent("Notify"):FireClient(player, message)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(tostring(player.UserId))
	end)
end

return table.freeze(ShopService)
