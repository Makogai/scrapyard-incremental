--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local InventoryConfig = require(ReplicatedStorage.Shared.Config.InventoryConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local AreaConfig = require(ReplicatedStorage.Shared.Config.AreaConfig)
local AreaRules = require(ReplicatedStorage.Shared.Utility.AreaRules)
local CollectionRules = require(ReplicatedStorage.Shared.Utility.CollectionRules)
local GameMath = require(ReplicatedStorage.Shared.Utility.GameMath)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PrestigeConfig = require(ReplicatedStorage.Shared.Config.PrestigeConfig)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.RewardsConfig)
local ScrapConfig = require(ReplicatedStorage.Shared.Config.ScrapConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local PlayerDataSchema = require(ReplicatedStorage.Shared.Utility.PlayerDataSchema)
local DayClock = require(ReplicatedStorage.Shared.Utility.DayClock)
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

local VARIANT_RANK = { Normal = 1, Rare = 2, Epic = 3, Legendary = 4, Nebula = 5 }

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
		return GameMath.incrementalUpgradeEffect(
			definition.BaseEffect,
			definition.EffectPerLevel,
			levels[upgradeId],
			definition.EffectCurve,
			definition.CurvePower,
			definition.EffectCap
		)
	end
	local strengthUpgrade = UpgradeConfig.ById.MagnetStrength
	local rangeUpgrade = UpgradeConfig.ById.MagnetRange
	local petEffects =
		GameMath.petEffectMultipliers(data.EquippedPets, data.OwnedPets, PetConfig.Pets)
	local strength = (magnet.BaseStrength + (effect("MagnetStrength") - strengthUpgrade.BaseEffect))
		* petEffects.MagnetStrength
	local range = (magnet.BaseRange + (effect("MagnetRange") - rangeUpgrade.BaseEffect))
		* petEffects.MagnetRange
	local godActive = data.ActiveBoosts.GodBoostEndsAt > os.time()
	if data.ActiveBoosts.StrengthBoostEndsAt > os.time() then
		strength += InventoryConfig.Consumables.StrengthPotion.Amount
	end
	if godActive then
		strength += InventoryConfig.Consumables.GodPotion.StrengthAmount
		range += InventoryConfig.Consumables.GodPotion.RangeAmount
	end
	local scrapValue = effect("ScrapValue")
	local petMoneyMultiplier = petEffects.Cash
	scrapValue *= petMoneyMultiplier
	if data.ActiveBoosts.CashBoostEndsAt > os.time() then
		scrapValue *= InventoryConfig.Consumables.CashPotion.Multiplier
	end
	if godActive then
		scrapValue *= InventoryConfig.Consumables.GodPotion.CashMultiplier
	end
	if data.Entitlements.DoubleCash == true then
		scrapValue *= 2
	end
	--[[
		Friend boost: +10% money per friend in this server, capped.

		Applied to `ScrapValue` rather than to the sale, so it shows up in the stat readout the
		player can already see -- a boost you cannot find is a boost that does not motivate anyone
		to bring a friend.
	]]
	local friendBoost = 1 + (data.FriendBoostCount or 0) * RewardsConfig.Friends.BoostPerFriend
	scrapValue *= friendBoost
	local storageCapacity = effect("StorageCapacity")
	storageCapacity *= petEffects.Storage
	if data.Entitlements.StoragePlus == true then
		storageCapacity *= 1.5
	end
	local collectionSpeed = effect("CollectionSpeed")
	local respawnMultiplier = effect("ScrapFlow")
	collectionSpeed *= petEffects.CollectionSpeed
	respawnMultiplier *= petEffects.RespawnRate
	if godActive then
		collectionSpeed *= InventoryConfig.Consumables.GodPotion.CollectionMultiplier
		respawnMultiplier *= InventoryConfig.Consumables.GodPotion.RespawnMultiplier
	end
	if data.Entitlements.FastCollector == true then
		collectionSpeed *= 2
	end
	return {
		MagnetStrength = strength,
		MagnetRange = range,
		StorageCapacity = storageCapacity,
		MovementSpeed = effect("MovementSpeed") * petEffects.MovementSpeed,
		ScrapValue = scrapValue,
		CollectionSpeed = collectionSpeed,
		RespawnMultiplier = respawnMultiplier,
		RarityLuck = effect("Rarity") * petEffects.RarityLuck,
		PetMoneyMultiplier = petMoneyMultiplier,
		PetEffects = petEffects,
		FriendBoostMultiplier = friendBoost,
	}
end

function PlayerStateService.GetLuckMultiplier(player: Player): number
	local session = sessions[player]
	if session == nil then
		return 1
	end
	local boosts = session.Data.ActiveBoosts
	local multiplier = derivedStats(session.Data).RarityLuck
	if boosts.LuckBoostEndsAt > os.time() then
		multiplier *= InventoryConfig.Consumables.LuckPotion.LuckMultiplier
	end
	if boosts.GodBoostEndsAt > os.time() then
		multiplier *= InventoryConfig.Consumables.GodPotion.LuckMultiplier
	end
	return multiplier
end

local function publicSnapshot(data: { [string]: any })
	local discoveries = {}
	for scrapId, discovery in data.DiscoveredScrap do
		discoveries[scrapId] = table.clone(discovery)
	end
	local upgradeMaximumLevels = {}
	for upgradeId, definition in UpgradeConfig.ById do
		upgradeMaximumLevels[upgradeId] = GameMath.upgradeMaximumLevel(
			definition.BaseMaximumLevel,
			definition.LevelsPerPrestige,
			data.PrestigeCount
		)
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
		UpgradeMaximumLevels = upgradeMaximumLevels,
		OwnedPets = table.clone(data.OwnedPets),
		EquippedPets = table.clone(data.EquippedPets),
		PetSlotUpgradeLevel = data.PetSlotUpgradeLevel,
		EggOpenCounts = table.clone(data.EggOpenCounts),
		MaximumEquippedPets = PetConfig.BaseEquipSlots
			+ data.PetSlotUpgradeLevel
			+ (if data.Entitlements.ExtraPetSlots == true then PetConfig.PassBonusSlots else 0),
		PetStorageCapacity = PetConfig.BaseStorageCapacity,

		--[[
			Return-to-play state. The client renders these; it never decides them. `DailyClaimable`
			and the like are computed server-side and sent as answers rather than as raw
			timestamps, so the client has nothing to get wrong and nothing to lie about.
		]]
		DailyStreak = data.DailyStreak,
		DailyCalendarDay = data.DailyCalendarDay,
		DailyClaimable = data.DailyLastClaimDay ~= DayClock.today(),
		PlaytimeSecondsToday = data.PlaytimeSecondsToday,
		PlaytimeClaimed = table.clone(data.PlaytimeClaimed),
		SpinsAvailable = data.SpinsAvailable,
		TutorialStep = data.TutorialStep,
		TutorialComplete = data.TutorialComplete,
		FriendBoostCount = data.FriendBoostCount or 0,
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
	local premiumPetByPass = {
		SingularityPet = "Singularity",
		DemonicGhostPet = "DemonicGhost",
		SinisterLordPet = "SinisterLord",
	}
	local premiumPetId = premiumPetByPass[entitlementId]
	if premiumPetId then
		data.OwnedPets[premiumPetId] = math.max(1, data.OwnedPets[premiumPetId] or 0)
	end
	pushState(player, data)
	return true, `{definition.DisplayName} unlocked!`
end

local function completePrestige(player: Player, data: { [string]: any }, reward: number)
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
		RustyPipe = true,
		CrushedBucket = true,
		CopperWire = true,
		Tire = true,
	}
	data.UnlockedMachines = { Crusher = true }
	data.CrusherLevel = 1
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.WalkSpeed = derivedStats(data).MovementSpeed
	end
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
	--[[
		Spins, for the wheel packs. Clamped to the same stored maximum every other spin grant uses, so a
		product cannot push a player past a cap the rest of the game respects.
	]]
	if typeof(rewards.Spins) == "number" then
		data.SpinsAvailable = math.clamp(
			data.SpinsAvailable + math.floor(rewards.Spins),
			0,
			RewardsConfig.Spin.MaximumStored
		)
	end
	for itemId, amount in rewards.Items or {} do
		if InventoryConfig.Consumables[itemId] and typeof(amount) == "number" then
			data.Inventory[itemId] =
				math.min(9999, (data.Inventory[itemId] or 0) + math.max(0, math.floor(amount)))
		end
	end
	if rewards.SpecialAction == "SkipPrestige" then
		local requirement = GameMath.prestigeRequirement(
			PrestigeConfig.BaseMoneyRequirement,
			PrestigeConfig.RequirementGrowth,
			data.PrestigeCount,
			Environment.MaximumMoney
		)
		local reward = GameMath.scaledPrestigeGearReward(
			requirement,
			requirement,
			data.PrestigeCount,
			PrestigeConfig.MaximumGearsPerPrestige
		)
		completePrestige(player, data, math.max(1, reward))
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

function PlayerStateService.TryUnequipMagnet(player: Player, magnetId: string): (boolean, string)
	local session = sessions[player]
	if session == nil or session.Data.EquippedMagnet ~= magnetId or magnetId == "MagnetBasic" then
		return false, "Magnet cannot be unequipped"
	end
	session.Data.EquippedMagnet = "MagnetBasic"
	pushState(player, session.Data)
	return true, "Basic Magnet equipped"
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

--[[
	The one path that hands a player a reward bundle.

	`{ Money?, Gears?, Items?, Spins? }` -- the same shape codes, developer products, the daily
	calendar, playtime milestones and the spin wheel all use, so a reward written in config works
	everywhere with no per-system granter. Clamping happens here rather than at the call sites,
	because the call sites are exactly the code most likely to be handed a bad number.

	Returns false only when there is no session. An empty bundle is a successful no-op.
]]
function PlayerStateService.GrantRewards(player: Player, rewards: { [string]: any }?): boolean
	local session = sessions[player]
	if session == nil or typeof(rewards) ~= "table" then
		return false
	end
	local data = session.Data

	for itemId, amount in rewards.Items or {} do
		if InventoryConfig.Consumables[itemId] and typeof(amount) == "number" then
			data.Inventory[itemId] = math.min(
				9999,
				(data.Inventory[itemId] or 0) + math.clamp(math.floor(amount), 0, 9999)
			)
		end
	end
	if typeof(rewards.Money) == "number" then
		data.Money = math.min(
			Environment.MaximumMoney,
			data.Money + math.clamp(math.floor(rewards.Money), 0, Environment.MaximumMoney)
		)
	end
	if typeof(rewards.Gears) == "number" then
		data.Gears = math.min(
			Environment.MaximumGears,
			data.Gears + math.clamp(math.floor(rewards.Gears), 0, Environment.MaximumGears)
		)
	end
	if typeof(rewards.Spins) == "number" then
		data.SpinsAvailable = math.clamp(
			data.SpinsAvailable + math.floor(rewards.Spins),
			0,
			RewardsConfig.Spin.MaximumStored
		)
	end

	pushState(player, data)
	return true
end

--[[
	How many friends the player currently shares this server with, which is a money boost.

	Transient by design -- it describes the room, not the player -- so it is written onto `data`
	for `derivedStats` to read, and the schema resets it to 0 on every load.
]]
function PlayerStateService.SetFriendCount(player: Player, count: number): boolean
	local session = sessions[player]
	if session == nil then
		return false
	end
	local clamped = math.clamp(math.floor(count), 0, RewardsConfig.Friends.MaximumFriends)
	if session.Data.FriendBoostCount == clamped then
		return false
	end
	session.Data.FriendBoostCount = clamped
	pushState(player, session.Data)
	return true
end

--------------------------------------------------------------------------------
-- Return-to-play state
--------------------------------------------------------------------------------

--[[
	The reward-system fields, read-only.

	Every mutation below is a named commit rather than a generic setter, so the rules for each
	system live in one place and a caller cannot half-apply one -- claiming a daily reward without
	stamping the day is a duplicate claim, and stamping the day without granting is a lost reward.
	Both halves happen here or neither does.
]]
function PlayerStateService.GetRewardState(player: Player): { [string]: any }?
	local session = sessions[player]
	if session == nil then
		return nil
	end
	local data = session.Data
	return {
		DailyStreak = data.DailyStreak,
		DailyLastClaimDay = data.DailyLastClaimDay,
		DailyCalendarDay = data.DailyCalendarDay,
		PlaytimeSecondsToday = data.PlaytimeSecondsToday,
		PlaytimeDay = data.PlaytimeDay,
		PlaytimeClaimed = table.clone(data.PlaytimeClaimed),
		SpinsAvailable = data.SpinsAvailable,
		SpinLastGrantDay = data.SpinLastGrantDay,
		TutorialStep = data.TutorialStep,
		TutorialComplete = data.TutorialComplete,
		Money = data.Money,
		TotalScrapCollected = data.TotalScrapCollected,
		UpgradeLevels = table.clone(data.UpgradeLevels),
	}
end

--- Stamp today, move the streak and calendar on, and grant. All four or none.
function PlayerStateService.CommitDailyClaim(
	player: Player,
	today: number,
	streak: number,
	nextCalendarDay: number,
	rewards: { [string]: any }
): boolean
	local session = sessions[player]
	if session == nil then
		return false
	end
	local data = session.Data
	data.DailyLastClaimDay = today
	data.DailyStreak = streak
	data.DailyCalendarDay = nextCalendarDay
	PlayerStateService.GrantRewards(player, rewards)
	--[[
		Saved immediately, not on the autosave tick. A crash between granting and saving would give
		the reward back for free on the next join, which is the one duplication that matters here.
	]]
	saveSession(player, false)
	return true
end

--[[
	Bank session playtime, rolling the counter over on a new day.

	Called on a tick, so it must be cheap and must not push state every time -- the caller decides
	how often. Returns the banked total so the caller can check milestones without a second read.
]]
function PlayerStateService.AddPlaytimeSeconds(
	player: Player,
	seconds: number,
	today: number
): number?
	local session = sessions[player]
	if session == nil then
		return nil
	end
	local data = session.Data
	if data.PlaytimeDay ~= today then
		data.PlaytimeDay = today
		data.PlaytimeSecondsToday = 0
		data.PlaytimeClaimed = {}
	end
	data.PlaytimeSecondsToday = math.min(86400, data.PlaytimeSecondsToday + math.max(0, seconds))
	return data.PlaytimeSecondsToday
end

function PlayerStateService.CommitPlaytimeClaim(
	player: Player,
	milestoneIndex: number,
	rewards: { [string]: any }
): boolean
	local session = sessions[player]
	if session == nil then
		return false
	end
	session.Data.PlaytimeClaimed[milestoneIndex] = true
	PlayerStateService.GrantRewards(player, rewards)
	saveSession(player, false)
	return true
end

--- Spend one spin. False when there are none, which is the client being out of date, not an error.
function PlayerStateService.ConsumeSpin(player: Player): boolean
	local session = sessions[player]
	if session == nil or session.Data.SpinsAvailable <= 0 then
		return false
	end
	session.Data.SpinsAvailable -= 1
	pushState(player, session.Data)
	return true
end

--- The daily free spins, stamped so they cannot be collected twice in one day.
function PlayerStateService.GrantDailySpins(player: Player, today: number, count: number): boolean
	local session = sessions[player]
	if session == nil or session.Data.SpinLastGrantDay == today then
		return false
	end
	session.Data.SpinLastGrantDay = today
	PlayerStateService.GrantRewards(player, { Spins = count })
	return true
end

function PlayerStateService.SetTutorialProgress(
	player: Player,
	step: number,
	complete: boolean
): boolean
	local session = sessions[player]
	if session == nil then
		return false
	end
	local data = session.Data
	if data.TutorialStep == step and data.TutorialComplete == complete then
		return false
	end
	data.TutorialStep = step
	data.TutorialComplete = complete
	pushState(player, data)
	return true
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
	player:SetAttribute("EquippedPets", HttpService:JSONEncode(data.EquippedPets))
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
	player:SetAttribute("EquippedPets", HttpService:JSONEncode(data.EquippedPets))
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
		PrestigeConfig.GearPower,
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
	local maximumLevel = GameMath.upgradeMaximumLevel(
		definition.BaseMaximumLevel,
		definition.LevelsPerPrestige,
		data.PrestigeCount
	)
	if currentLevel >= maximumLevel then
		return false, "Prestige to raise this upgrade cap"
	end
	local price = GameMath.incrementalUpgradeCost(
		definition.BaseCost,
		definition.GrowthRate,
		definition.CostPower,
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
	amount: number?,
	itemId: string?
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
	elseif command == "AddSpins" then
		--[[
			Clamped to the same `MaximumStored` the schema sanitiser enforces. Granting past it would be
			silently trimmed on the next load, so the panel would report a success the save then undid.
		]]
		local grant = math.floor(math.clamp(amount or 0, 0, RewardsConfig.Spin.MaximumStored))
		data.SpinsAvailable =
			math.min(RewardsConfig.Spin.MaximumStored, data.SpinsAvailable + grant)
	elseif command == "SetDailyStreak" then
		--- Set, not add: the point of testing a streak is landing on a specific day of the calendar.
		data.DailyStreak = math.floor(math.clamp(amount or 0, 0, 3650))
		data.DailyCalendarDay = (data.DailyStreak % #RewardsConfig.Daily.Days) + 1
	elseif command == "AddRebirths" then
		data.PrestigeCount = math.floor(math.clamp(data.PrestigeCount + (amount or 0), 0, 9999))
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
			data.UpgradeLevels[upgradeId] = GameMath.upgradeMaximumLevel(
				definition.BaseMaximumLevel,
				definition.LevelsPerPrestige,
				data.PrestigeCount
			)
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
		for _, consumableId in InventoryConfig.ConsumableOrder do
			data.Inventory[consumableId] = math.min(9999, (data.Inventory[consumableId] or 0) + 3)
		end
	elseif command == "GrantPet" then
		local definition = if itemId then PetConfig.Pets[itemId] else nil
		if definition == nil then
			return false, "Unknown pet ID"
		end
		local totalOwned = 0
		for _, ownedAmount in data.OwnedPets do
			totalOwned += ownedAmount
		end
		local available = math.max(0, PetConfig.BaseStorageCapacity - totalOwned)
		local grant = math.min(math.max(1, amount or 1), available)
		if grant <= 0 then
			return false, "Pet storage is full"
		end
		data.OwnedPets[itemId] =
			math.min(PetConfig.MaximumOwnedPerPet, (data.OwnedPets[itemId] or 0) + grant)
	elseif command == "GrantMagnet" then
		local definition = if itemId then InventoryConfig.Magnets[itemId] else nil
		if definition == nil then
			return false, "Unknown magnet ID"
		end
		data.OwnedMagnets[itemId] = true
	elseif command == "GrantConsumable" then
		local definition = if itemId then InventoryConfig.Consumables[itemId] else nil
		if definition == nil then
			return false, "Unknown consumable ID"
		end
		data.Inventory[itemId] =
			math.min(9999, (data.Inventory[itemId] or 0) + math.max(1, amount or 1))
	elseif command == "AddUpgradeLevels" then
		local definition = if itemId then UpgradeConfig.ById[itemId] else nil
		if definition == nil then
			return false, "Unknown upgrade ID"
		end
		local maximum = GameMath.upgradeMaximumLevel(
			definition.BaseMaximumLevel,
			definition.LevelsPerPrestige,
			data.PrestigeCount
		)
		data.UpgradeLevels[itemId] =
			math.min(maximum, (data.UpgradeLevels[itemId] or 0) + math.max(1, amount or 1))
	else
		return false, "Unknown admin command"
	end
	pushState(player, data)
	return true, `{command} applied to {player.DisplayName}`
end

function PlayerStateService.TryOpenEgg(player: Player, eggId: string): (boolean, string, string?)
	local session = sessions[player]
	local egg = PetConfig.Eggs[eggId]
	if session == nil or egg == nil then
		return false, "Egg unavailable", nil
	end
	local data = session.Data
	local ownedCount = 0
	for _, amount in data.OwnedPets do
		ownedCount += amount
	end
	if ownedCount >= PetConfig.BaseStorageCapacity then
		return false, "Pet storage is full", nil
	end
	if data.UnlockedAreas[egg.RequiredArea] ~= true then
		return false, "Unlock this egg's area first", nil
	end
	if data.Money < egg.Price then
		return false, "Not enough Scrap Cash", nil
	end
	data.Money -= egg.Price
	local nextOpenCount = (data.EggOpenCounts[eggId] or 0) + 1
	local wonPetId
	if nextOpenCount % PetConfig.SecretPityRolls == 0 then
		wonPetId = egg.PetIds[6]
	elseif nextOpenCount % PetConfig.LegendaryPityRolls == 0 then
		wonPetId = if math.random(1, 10) == 1 then egg.PetIds[6] else egg.PetIds[5]
	else
		local roll = math.random(1, PetConfig.RollTotal)
		local cursor = 0
		wonPetId = egg.PetIds[1]
		for _, petId in egg.PetIds do
			cursor += PetConfig.Pets[petId].RollWeight
			if roll <= cursor then
				wonPetId = petId
				break
			end
		end
	end
	data.OwnedPets[wonPetId] =
		math.min(PetConfig.MaximumOwnedPerPet, (data.OwnedPets[wonPetId] or 0) + 1)
	data.EggOpenCounts[eggId] = nextOpenCount
	pushState(player, data)
	return true, `{PetConfig.Pets[wonPetId].DisplayName} hatched!`, wonPetId
end

function PlayerStateService.TryEquipPet(player: Player, petId: string): (boolean, string)
	local session = sessions[player]
	local definition = PetConfig.Pets[petId]
	if session == nil or definition == nil or (session.Data.OwnedPets[petId] or 0) <= 0 then
		return false, "Pet is not owned"
	end
	local data = session.Data
	local equippedCopies = 0
	for _, equippedId in data.EquippedPets do
		if equippedId == petId then
			equippedCopies += 1
		end
	end
	if equippedCopies >= data.OwnedPets[petId] then
		return false, "All owned copies are equipped"
	end
	local maximumEquipped = PetConfig.BaseEquipSlots
		+ data.PetSlotUpgradeLevel
		+ (if data.Entitlements.ExtraPetSlots == true then PetConfig.PassBonusSlots else 0)
	if #data.EquippedPets >= maximumEquipped then
		return false, "No free pet slots"
	end
	table.insert(data.EquippedPets, petId)
	pushState(player, data)
	return true, `{definition.DisplayName} equipped!`
end

function PlayerStateService.TryUnequipPet(player: Player, petId: string): (boolean, string)
	local session = sessions[player]
	if session == nil then
		return false, "Player data is not loaded"
	end
	for index, equippedId in session.Data.EquippedPets do
		if equippedId == petId then
			table.remove(session.Data.EquippedPets, index)
			pushState(player, session.Data)
			return true, "Pet unequipped"
		end
	end
	return false, "Pet is not equipped"
end

function PlayerStateService.TryDeletePet(player: Player, petId: string): (boolean, string)
	local session = sessions[player]
	local definition = PetConfig.Pets[petId]
	if session == nil or definition == nil then
		return false, "Pet is unavailable"
	end
	local data = session.Data
	local owned = data.OwnedPets[petId] or 0
	if owned <= 0 then
		return false, "Pet is not owned"
	end
	local equippedIndex: number? = nil
	for index = #data.EquippedPets, 1, -1 do
		if data.EquippedPets[index] == petId then
			equippedIndex = index
			break
		end
	end
	if equippedIndex then
		table.remove(data.EquippedPets, equippedIndex)
	end
	if owned == 1 then
		data.OwnedPets[petId] = nil
	else
		data.OwnedPets[petId] = owned - 1
	end
	pushState(player, data)
	return true, `{definition.DisplayName} deleted`
end

function PlayerStateService.TryBuyPetSlot(player: Player): (boolean, string)
	local session = sessions[player]
	if session == nil then
		return false, "Player data is not loaded"
	end
	local data = session.Data
	if data.PetSlotUpgradeLevel >= PetConfig.MaximumSlotUpgradeLevel then
		return false, "Cash pet slots are maxed"
	end
	local price = PetConfig.SlotUpgradeCosts[data.PetSlotUpgradeLevel + 1]
	if data.Money < price then
		return false, "Not enough Scrap Cash"
	end
	data.Money -= price
	data.PetSlotUpgradeLevel += 1
	pushState(player, data)
	return true, `Pet slot {data.PetSlotUpgradeLevel + PetConfig.BaseEquipSlots} unlocked!`
end

--[[
	Record which theme a player's plot is built as. See docs/PLOT_UPGRADES.md.

	Validation of *whether* they may have it -- ownership, unlock -- belongs to
	`PlotThemeService`; this only writes what it is told and pushes the change.
]]
function PlayerStateService.SetActivePlotTheme(player: Player, areaId: string): boolean
	local session = sessions[player]
	if session == nil or typeof(areaId) ~= "string" then
		return false
	end
	session.Data.ActivePlotTheme = areaId
	pushState(player, session.Data)
	return true
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
	local requirement = GameMath.prestigeRequirement(
		PrestigeConfig.BaseMoneyRequirement,
		PrestigeConfig.RequirementGrowth,
		data.PrestigeCount,
		Environment.MaximumMoney
	)
	local reward = GameMath.scaledPrestigeGearReward(
		data.Money,
		requirement,
		data.PrestigeCount,
		PrestigeConfig.MaximumGearsPerPrestige
	)
	if reward <= 0 then
		return false, "Prestige requirement not met"
	end

	completePrestige(player, data, reward)
	pushState(player, data)
	return true, `PRESTIGED FOR {reward} GEARS!`
end

function PlayerStateService.IsLoaded(player: Player): boolean
	return sessions[player] ~= nil
end

function PlayerStateService.HasProcessedReceipt(player: Player, purchaseId: string): boolean
	local session = sessions[player]
	return session ~= nil and session.Data.ProcessedReceipts[purchaseId] == true
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
		--- Which theme the plot is built as; see docs/PLOT_UPGRADES.md.
		ActivePlotTheme = data.ActivePlotTheme or "FrontYard",
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
		-- Shown on the plot's owner sign, which anyone can walk up to and read.
		Money = data.Money,
	}
end

return table.freeze(PlayerStateService)
