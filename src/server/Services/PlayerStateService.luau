--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local InventoryConfig = require(ReplicatedStorage.Shared.Config.InventoryConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local AreaConfig = require(ReplicatedStorage.Shared.Config.AreaConfig)
local AreaRules = require(ReplicatedStorage.Shared.Utility.AreaRules)
local CollectionRules = require(ReplicatedStorage.Shared.Utility.CollectionRules)
local GameMath = require(ReplicatedStorage.Shared.Utility.GameMath)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PrestigeConfig = require(ReplicatedStorage.Shared.Config.PrestigeConfig)
local ScrapConfig = require(ReplicatedStorage.Shared.Config.ScrapConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local PlayerDataSchema = require(ReplicatedStorage.Shared.Utility.PlayerDataSchema)
local DataService = require(script.Parent.DataService)
local RemoteService = require(script.Parent.RemoteService)

type Session = {
	Data: { [string]: any },
	NextAutoSaveAt: number,
	Saving: boolean,
	Released: boolean,
}

local PlayerStateService = {}
local sessions: { [Player]: Session } = {}
local shuttingDown = false
local stateChanged: RemoteEvent?
local notifyRemote: RemoteEvent?
local gameplayEffect: RemoteEvent?
local initialStateLimiter = RateLimiter.new(4, Environment.RemoteRateLimitWindowSeconds)
local pushState: (Player, { [string]: any }) -> ()
local saveSession: (Player, boolean) -> boolean

local VARIANT_RANK = { Normal = 1, Silver = 2, Gold = 3, Rainbow = 4 }

local function nextAutoSaveTime(): number
	local jitter = Environment.AutoSaveJitterFraction
	local multiplier = 1 + ((math.random() * 2 - 1) * jitter)
	return os.clock() + Environment.AutoSaveIntervalSeconds * multiplier
end

local function derivedStats(data: { [string]: any })
	local levels = data.UpgradeLevels
	local magnet = InventoryConfig.Magnets[data.EquippedMagnet]
		or InventoryConfig.Magnets.MagnetBasic
	local function effect(upgradeId: string): number
		local definition = UpgradeConfig.ById[upgradeId]
		return GameMath.upgradeEffect(
			definition.BaseEffect,
			definition.EffectPerLevel,
			levels[upgradeId],
			definition.EffectCap
		)
	end
	local strengthUpgrade = UpgradeConfig.ById.MagnetStrength
	local rangeUpgrade = UpgradeConfig.ById.MagnetRange
	local strength = magnet.BaseStrength + (effect("MagnetStrength") - strengthUpgrade.BaseEffect)
	local range = magnet.BaseRange + (effect("MagnetRange") - rangeUpgrade.BaseEffect)
	if data.ActiveBoosts.StrengthBoostEndsAt > os.time() then
		strength += InventoryConfig.Consumables.StrengthPotion.Amount
	end
	local scrapValue = effect("ScrapValue")
	if data.ActiveBoosts.CashBoostEndsAt > os.time() then
		scrapValue *= InventoryConfig.Consumables.CashPotion.Multiplier
	end
	if data.Entitlements.DoubleCash == true then
		scrapValue *= 2
	end
	local storageCapacity = effect("StorageCapacity")
	if data.Entitlements.StoragePlus == true then
		storageCapacity *= 1.5
	end
	local collectionSpeed = effect("CollectionSpeed")
	if data.Entitlements.FastCollector == true then
		collectionSpeed *= 2
	end
	return {
		MagnetStrength = strength,
		MagnetRange = range,
		StorageCapacity = storageCapacity,
		MovementSpeed = effect("MovementSpeed"),
		ScrapValue = scrapValue,
		CollectionSpeed = collectionSpeed,
	}
end

local function publicSnapshot(data: { [string]: any })
	local discoveries = {}
	for scrapId, discovery in data.DiscoveredScrap do
		discoveries[scrapId] = table.clone(discovery)
	end
	return {
		Money = data.Money,
		Gears = data.Gears,
		StoredWeight = data.StoredWeight,
		StoredValue = data.StoredValue,
		UpgradeLevels = table.clone(data.UpgradeLevels),
		UnlockedAreas = table.clone(data.UnlockedAreas),
		DerivedStats = derivedStats(data),
		TotalScrapCollected = data.TotalScrapCollected,
		PlotStage = data.PlotStage,
		PrestigeCount = data.PrestigeCount,
		CrusherLevel = data.CrusherLevel,
		Settings = table.clone(data.Settings),
		DiscoveredScrap = discoveries,
		OwnedMagnets = table.clone(data.OwnedMagnets),
		EquippedMagnet = data.EquippedMagnet,
		Inventory = table.clone(data.Inventory),
		ActiveBoosts = table.clone(data.ActiveBoosts),
		Entitlements = table.clone(data.Entitlements),
	}
end

function PlayerStateService.GrantEntitlement(
	player: Player,
	entitlementId: string
): (boolean, string)
	local session = sessions[player]
	local definition = MonetizationConfig.Passes[entitlementId]
	if session == nil or definition == nil then
		return false, "Entitlement unavailable"
	end
	local data = session.Data
	data.Entitlements[entitlementId] = true
	if entitlementId == "QuantumMagnet" then
		data.OwnedMagnets.QuantumMagnet = true
	end
	pushState(player, data)
	return true, `{definition.DisplayName} unlocked!`
end

function PlayerStateService.GrantDeveloperProduct(
	player: Player,
	productId: string,
	purchaseId: string
): (boolean, string)
	local session = sessions[player]
	local definition = MonetizationConfig.Products[productId]
	if session == nil or definition == nil or #purchaseId > 80 then
		return false, "Product unavailable"
	end
	local data = session.Data
	if data.ProcessedReceipts[purchaseId] == true then
		return true, "Purchase already granted"
	end
	local rewards = definition.Rewards
	data.Money =
		math.min(Environment.MaximumMoney, data.Money + math.max(0, math.floor(rewards.Money or 0)))
	for itemId, amount in rewards.Items or {} do
		if InventoryConfig.Consumables[itemId] and typeof(amount) == "number" then
			data.Inventory[itemId] =
				math.min(9999, (data.Inventory[itemId] or 0) + math.max(0, math.floor(amount)))
		end
	end
	data.ProcessedReceipts[purchaseId] = true
	pushState(player, data)
	if not saveSession(player, false) then
		data.ProcessedReceipts[purchaseId] = nil
		return false, "Purchase save pending"
	end
	return true, `{definition.DisplayName} delivered!`
end

function PlayerStateService.TryEquipMagnet(player: Player, magnetId: string): (boolean, string)
	local session = sessions[player]
	local definition = InventoryConfig.Magnets[magnetId]
	if session == nil or definition == nil or session.Data.OwnedMagnets[magnetId] ~= true then
		return false, "Magnet is not owned"
	end
	session.Data.EquippedMagnet = magnetId
	pushState(player, session.Data)
	return true, `{definition.DisplayName} equipped`
end

function PlayerStateService.TryUseConsumable(player: Player, itemId: string): (boolean, string)
	local session = sessions[player]
	local definition = InventoryConfig.Consumables[itemId]
	if session == nil or definition == nil or (session.Data.Inventory[itemId] or 0) <= 0 then
		return false, "Item is unavailable"
	end
	session.Data.Inventory[itemId] -= 1
	local key = `{definition.BoostId}EndsAt`
	local startAt = math.max(os.time(), session.Data.ActiveBoosts[key] or 0)
	session.Data.ActiveBoosts[key] = startAt + definition.DurationSeconds
	pushState(player, session.Data)
	return true, `{definition.DisplayName} activated`
end

function PlayerStateService.TryApplyCodeRewards(
	player: Player,
	codeId: string,
	rewards: { [string]: any }
): (boolean, string)
	local session = sessions[player]
	if session == nil then
		return false, "Player data is not loaded"
	end
	local data = session.Data
	if data.RedeemedCodes[codeId] == true then
		return false, "CODE ALREADY REDEEMED"
	end
	for _, magnetId in rewards.Magnets or {} do
		if InventoryConfig.Magnets[magnetId] then
			data.OwnedMagnets[magnetId] = true
		end
	end
	for itemId, amount in rewards.Items or {} do
		if InventoryConfig.Consumables[itemId] and typeof(amount) == "number" then
			data.Inventory[itemId] = math.min(
				9999,
				(data.Inventory[itemId] or 0) + math.clamp(math.floor(amount), 0, 9999)
			)
		end
	end
	data.Money = math.min(
		Environment.MaximumMoney,
		data.Money + math.clamp(math.floor(rewards.Money or 0), 0, Environment.MaximumMoney)
	)
	data.Gears = math.min(
		Environment.MaximumGears,
		data.Gears + math.clamp(math.floor(rewards.Gears or 0), 0, Environment.MaximumGears)
	)
	data.RedeemedCodes[codeId] = true
	pushState(player, data)
	return true, "CODE REDEEMED! REWARDS ADDED"
end

pushState = function(player: Player, data: { [string]: any })
	if stateChanged then
		stateChanged:FireClient(player, publicSnapshot(data))
	end
end

saveSession = function(player: Player, releaseSession: boolean): boolean
	local session = sessions[player]
	if session == nil then
		return false
	end
	if session.Released then
		return true
	end
	if session.Saving then
		local deadline = os.clock() + 10
		repeat
			task.wait(0.1)
		until not session.Saving or session.Released or os.clock() >= deadline
		if session.Released then
			return true
		end
		if session.Saving then
			warn(`[PlayerStateService] Timed out waiting for save lock for {player.UserId}`)
			return false
		end
	end
	session.Saving = true
	local succeeded, saveError = DataService.Save(player.UserId, session.Data, releaseSession)
	session.Saving = false
	if not succeeded then
		warn(`[PlayerStateService] Save failed for {player.UserId}: {saveError or "unknown error"}`)
		return false
	end
	if releaseSession then
		session.Released = true
	end
	session.NextAutoSaveAt = nextAutoSaveTime()
	return true
end

local function onPlayerAdded(player: Player)
	local succeeded, data, loadError = DataService.Load(player.UserId)
	if not succeeded or data == nil then
		warn(
			`[PlayerStateService] Load rejected for {player.UserId}: {loadError or "unknown error"}`
		)
		player:Kick("Your data could not be loaded safely. Please rejoin in a moment.")
		return
	end
	if player.Parent ~= Players or shuttingDown then
		DataService.Save(player.UserId, data, true)
		return
	end
	sessions[player] = {
		Data = data,
		NextAutoSaveAt = nextAutoSaveTime(),
		Saving = false,
		Released = false,
	}
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.WalkSpeed = derivedStats(data).MovementSpeed
	end
end

local function onPlayerRemoving(player: Player)
	if sessions[player] == nil then
		return
	end
	saveSession(player, true)
	sessions[player] = nil
end

function PlayerStateService.Start()
	stateChanged = RemoteService.GetEvent("StateChanged")
	notifyRemote = RemoteService.GetEvent("Notify")
	gameplayEffect = RemoteService.GetEvent("GameplayEffect")
	RemoteService.GetFunction("RequestInitialState").OnServerInvoke = function(player: Player)
		if not initialStateLimiter:Allow(tostring(player.UserId)) then
			return nil
		end
		local session = sessions[player]
		if session == nil then
			return nil
		end
		return publicSnapshot(session.Data)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		initialStateLimiter:Remove(tostring(player.UserId))
		onPlayerRemoving(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while not shuttingDown do
			task.wait(5)
			local now = os.clock()
			for player, session in sessions do
				if now >= session.NextAutoSaveAt then
					task.spawn(saveSession, player, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		shuttingDown = true
		for player in sessions do
			saveSession(player, true)
		end
	end)
end

function PlayerStateService.GetPublicState(player: Player): { [string]: any }?
	local session = sessions[player]
	return if session then publicSnapshot(session.Data) else nil
end

function PlayerStateService.TryCollect(
	player: Player,
	scrapId: string,
	variantId: string,
	areaId: string
): (boolean, string)
	local session = sessions[player]
	local scrap = ScrapConfig.ById[scrapId]
	local variant = ScrapConfig.Variants[variantId]
	local area = AreaConfig.ById[areaId]
	if session == nil or scrap == nil or variant == nil or area == nil then
		return false, "Invalid"
	end

	local data = session.Data
	local stats = derivedStats(data)
	local allowed, reason = CollectionRules.canCollect(
		stats.MagnetStrength,
		scrap.RequiredMagnetStrength,
		data.StoredWeight,
		stats.StorageCapacity,
		scrap.Weight,
		data.UnlockedAreas[areaId] == true,
		true
	)
	if not allowed then
		return false, reason
	end

	data.StoredWeight += scrap.Weight
	data.StoredValue += GameMath.scrapValue(
		scrap.BaseValue,
		variant.ValueMultiplier,
		1,
		Environment.MaximumStoredValue
	)
	data.TotalScrapCollected += 1
	local discovery = data.DiscoveredScrap[scrapId]
	local wasDiscovered = discovery.Discovered
	local previousVariant = discovery.HighestVariant
	discovery.Discovered = true
	discovery.TotalCollected += 1
	if VARIANT_RANK[variantId] > VARIANT_RANK[discovery.HighestVariant] then
		discovery.HighestVariant = variantId
	end
	pushState(player, data)
	if notifyRemote and not wasDiscovered then
		notifyRemote:FireClient(player, `NEW DISCOVERY: {scrap.DisplayName}`)
	elseif notifyRemote and previousVariant ~= discovery.HighestVariant then
		notifyRemote:FireClient(
			player,
			`NEW {string.upper(discovery.HighestVariant)} VARIANT: {scrap.DisplayName}`
		)
	end
	return true, "Collected"
end

function PlayerStateService.CanCollect(
	player: Player,
	scrapId: string,
	areaId: string
): (boolean, string)
	local session = sessions[player]
	local scrap = ScrapConfig.ById[scrapId]
	if session == nil or scrap == nil or AreaConfig.ById[areaId] == nil then
		return false, "Invalid"
	end
	local data = session.Data
	local stats = derivedStats(data)
	return CollectionRules.canCollect(
		stats.MagnetStrength,
		scrap.RequiredMagnetStrength,
		data.StoredWeight,
		stats.StorageCapacity,
		scrap.Weight,
		data.UnlockedAreas[areaId] == true,
		true
	)
end

function PlayerStateService.TrySell(player: Player): (boolean, number)
	local session = sessions[player]
	if session == nil or session.Data.StoredValue <= 0 then
		return false, 0
	end
	local data = session.Data
	local stats = derivedStats(data)
	local gearMultiplier = GameMath.gearValueMultiplier(
		data.Gears,
		PrestigeConfig.ValueBonusPerGear,
		PrestigeConfig.MaximumGearValueMultiplier
	)
	local award = CollectionRules.sellAward(
		data.StoredValue,
		stats.ScrapValue,
		gearMultiplier,
		Environment.MaximumMoney
	)
	if award <= 0 then
		return false, 0
	end
	data.StoredWeight = 0
	data.StoredValue = 0
	data.Money = math.min(Environment.MaximumMoney, data.Money + award)
	pushState(player, data)
	if notifyRemote then
		notifyRemote:FireClient(player, `SOLD FOR $ {award}`)
	end
	if gameplayEffect then
		gameplayEffect:FireClient(player, "Sold", award)
	end
	return true, award
end

function PlayerStateService.TryPurchaseUpgrade(player: Player, upgradeId: string): (boolean, string)
	local session = sessions[player]
	local definition = UpgradeConfig.ById[upgradeId]
	if session == nil or definition == nil then
		return false, "Invalid upgrade"
	end

	local data = session.Data
	local currentLevel = data.UpgradeLevels[upgradeId]
	if currentLevel >= definition.MaximumLevel then
		return false, "Already max level"
	end
	local price = GameMath.upgradeCost(
		definition.BaseCost,
		definition.GrowthRate,
		currentLevel,
		Environment.MaximumMoney
	)
	if price <= 0 or data.Money < price then
		return false, "Not enough Scrap Cash"
	end

	data.Money -= price
	data.UpgradeLevels[upgradeId] = currentLevel + 1
	if upgradeId == "MovementSpeed" then
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			humanoid.WalkSpeed = derivedStats(data).MovementSpeed
		end
	end
	pushState(player, data)
	return true, `{definition.DisplayName} upgraded!`
end

function PlayerStateService.TryUnlockArea(player: Player, areaId: string): (boolean, string)
	local session = sessions[player]
	local definition = AreaConfig.ById[areaId]
	if session == nil or definition == nil or areaId == "FrontYard" then
		return false, "Invalid area"
	end

	local data = session.Data
	local previousId = AreaConfig.Order[definition.Order - 1]
	local allowed, reason = AreaRules.canUnlock(
		data.UnlockedAreas[areaId] == true,
		previousId ~= nil and data.UnlockedAreas[previousId] == true,
		data.Money,
		definition.UnlockPrice
	)
	if not allowed then
		return false, reason
	end

	data.Money -= definition.UnlockPrice
	data.UnlockedAreas[areaId] = true
	for _, scrapId in definition.ScrapIds do
		data.UnlockedScrapTypes[scrapId] = true
	end
	data.PlotStage = math.max(data.PlotStage, definition.Order)
	pushState(player, data)
	return true, `{definition.DisplayName} unlocked!`
end

function PlayerStateService.AdminMutate(
	player: Player,
	command: string,
	amount: number?
): (boolean, string)
	local session = sessions[player]
	if session == nil then
		return false, "Player data is not loaded"
	end
	local data = session.Data
	if command == "AddMoney" then
		local grant = math.floor(math.clamp(amount or 0, 0, Environment.MaximumMoney))
		data.Money = math.min(Environment.MaximumMoney, data.Money + grant)
	elseif command == "AddGears" then
		local grant = math.floor(math.clamp(amount or 0, 0, Environment.MaximumGears))
		data.Gears = math.min(Environment.MaximumGears, data.Gears + grant)
	elseif command == "UnlockAllAreas" then
		for _, areaId in AreaConfig.Order do
			data.UnlockedAreas[areaId] = true
			for _, scrapId in AreaConfig.ById[areaId].ScrapIds do
				data.UnlockedScrapTypes[scrapId] = true
			end
		end
		data.PlotStage = math.max(data.PlotStage, #AreaConfig.Order)
	elseif command == "MaxUpgrades" then
		for upgradeId, definition in UpgradeConfig.ById do
			data.UpgradeLevels[upgradeId] = definition.MaximumLevel
		end
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			humanoid.WalkSpeed = derivedStats(data).MovementSpeed
		end
	elseif command == "ClearStorage" then
		data.StoredWeight = 0
		data.StoredValue = 0
	elseif command == "ResetTestProfile" then
		session.Data = PlayerDataSchema.createDefault(os.time())
		data = session.Data
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			humanoid.WalkSpeed = derivedStats(data).MovementSpeed
		end
	elseif command == "GrantTestItems" then
		data.Inventory.CashPotion = math.min(9999, data.Inventory.CashPotion + 3)
		data.Inventory.StrengthPotion = math.min(9999, data.Inventory.StrengthPotion + 3)
	else
		return false, "Unknown admin command"
	end
	pushState(player, data)
	return true, `{command} applied to {player.DisplayName}`
end

function PlayerStateService.TryUpdateSetting(player: Player, settingId: string, value: any): boolean
	local session = sessions[player]
	if session == nil or session.Data.Settings[settingId] == nil then
		return false
	end
	local current = session.Data.Settings[settingId]
	if typeof(current) == "boolean" and typeof(value) == "boolean" then
		session.Data.Settings[settingId] = value
	elseif typeof(current) == "number" and typeof(value) == "number" and value == value then
		session.Data.Settings[settingId] = math.clamp(value, 0, 1)
	else
		return false
	end
	pushState(player, session.Data)
	return true
end

function PlayerStateService.TryBuyMagnet(player: Player, magnetId: string): (boolean, string)
	local session = sessions[player]
	local definition = InventoryConfig.Magnets[magnetId]
	if session == nil or definition == nil or typeof(definition.ShopPrice) ~= "number" then
		return false, "MAGNET IS NOT FOR SALE"
	end
	local data = session.Data
	if data.OwnedMagnets[magnetId] == true then
		return false, "MAGNET ALREADY OWNED"
	end
	if data.Money < definition.ShopPrice then
		return false, "NOT ENOUGH SCRAP CASH"
	end
	data.Money -= definition.ShopPrice
	data.OwnedMagnets[magnetId] = true
	pushState(player, data)
	return true, `{definition.DisplayName} purchased!`
end

function PlayerStateService.TryPrestige(player: Player): (boolean, string)
	local session = sessions[player]
	if session == nil then
		return false, "Player data is not loaded"
	end
	local data = session.Data
	local reward = GameMath.prestigeGearReward(
		data.Money,
		PrestigeConfig.MoneyRequirement,
		PrestigeConfig.MaximumGearsPerPrestige
	)
	if reward <= 0 then
		return false, "Prestige requirement not met"
	end

	data.Gears = math.min(Environment.MaximumGears, data.Gears + reward)
	data.PrestigeCount += 1
	data.Money = 0
	data.StoredWeight = 0
	data.StoredValue = 0
	for upgradeId in data.UpgradeLevels do
		data.UpgradeLevels[upgradeId] = 0
	end
	for _, areaId in AreaConfig.Order do
		data.UnlockedAreas[areaId] = areaId == "FrontYard"
	end
	data.PlotStage = 1
	data.PlotUpgradeLevels = {}
	data.UnlockedScrapTypes = {
		MetalCan = true,
		LooseBolt = true,
		SmallMetalPlate = true,
		Tire = true,
	}
	data.UnlockedMachines = { Crusher = true }
	data.CrusherLevel = 1
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.WalkSpeed = derivedStats(data).MovementSpeed
	end
	pushState(player, data)
	return true, `PRESTIGED FOR {reward} GEARS!`
end

function PlayerStateService.IsLoaded(player: Player): boolean
	return sessions[player] ~= nil
end

function PlayerStateService.GetDerivedStats(player: Player): { [string]: number }?
	local session = sessions[player]
	return if session then derivedStats(session.Data) else nil
end

function PlayerStateService.IsAreaUnlocked(player: Player, areaId: string): boolean
	local session = sessions[player]
	return session ~= nil and session.Data.UnlockedAreas[areaId] == true
end

function PlayerStateService.GetPlotState(player: Player): { [string]: any }?
	local session = sessions[player]
	if session == nil then
		return nil
	end
	local data = session.Data
	return {
		PlotStage = data.PlotStage,
		UpgradeLevels = table.clone(data.UpgradeLevels),
		UnlockedAreas = table.clone(data.UnlockedAreas),
		PlotUpgradeLevels = table.clone(data.PlotUpgradeLevels),
		UnlockedScrapTypes = table.clone(data.UnlockedScrapTypes),
		UnlockedMachines = table.clone(data.UnlockedMachines),
		CrusherLevel = data.CrusherLevel,
		PlotTheme = data.PlotTheme,
		PlotCustomization = table.clone(data.PlotCustomization),
		DisplayedTrophies = table.clone(data.DisplayedTrophies),
		PrestigeCount = data.PrestigeCount,
		TotalScrapCollected = data.TotalScrapCollected,
	}
end

return table.freeze(PlayerStateService)
