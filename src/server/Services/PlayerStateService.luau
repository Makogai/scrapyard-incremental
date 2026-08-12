--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local InventoryConfig = require(ReplicatedStorage.Shared.Config.InventoryConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local AreaConfig = require(ReplicatedStorage.Shared.Config.AreaConfig)
local InboxConfig = require(ReplicatedStorage.Shared.Config.InboxConfig)
local SocialConfig = require(ReplicatedStorage.Shared.Config.SocialConfig)
local AreaRules = require(ReplicatedStorage.Shared.Utility.AreaRules)
local CollectionRules = require(ReplicatedStorage.Shared.Utility.CollectionRules)
local GameMath = require(ReplicatedStorage.Shared.Utility.GameMath)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PrestigeConfig = require(ReplicatedStorage.Shared.Config.PrestigeConfig)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.RewardsConfig)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local TitleConfig = require(ReplicatedStorage.Shared.Config.TitleConfig)
local AdminConfig = require(ReplicatedStorage.Shared.Config.AdminConfig)
local ScrapConfig = require(ReplicatedStorage.Shared.Config.ScrapConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local PlayerDataSchema = require(ReplicatedStorage.Shared.Utility.PlayerDataSchema)
local DayClock = require(ReplicatedStorage.Shared.Utility.DayClock)
local DataService = require(script.Parent.DataService)
--[[
	One-way on purpose: `LeaderstatsService.Publish` is handed the data it needs, so it requires nothing
	back from here and the two cannot form a require cycle.
]]
local LeaderstatsService = require(script.Parent.LeaderstatsService)
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

--[[
	WHEN EACH PLAYER LAST DID SOMETHING, for the playtime clock.

	`os.clock()` rather than `os.time()`: this is a duration between two server-side moments, never a
	timestamp anybody saves or compares across sessions, so monotonic time is the correct clock and cannot
	be skewed by the system clock changing under it.

	Cleared on leave with the rest of the per-player tables.
]]
local lastActiveAt: { [Player]: number } = {}
local stateChanged: RemoteEvent?
local notifyRemote: RemoteEvent?
local gameplayEffect: RemoteEvent?
local initialStateLimiter = RateLimiter.new(4, Environment.RemoteRateLimitWindowSeconds)
local pushState: (Player, { [string]: any }) -> ()
--- Defined with the rest of the title code, called from the load path above it.
local grantStaffTitles: (Player, { [string]: any }) -> ()
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
	--[[
		The Magnet Potion moved from "+15 flat strength" to a smaller strength bump plus multipliers on
		collection speed and range, because a flat strength number stops mattering the moment upgrades
		outgrow it -- at +15 it was decisive at level 1 and irrelevant by the Graveyard. Multipliers scale
		with the player, so the potion is worth the same fraction all game.
	]]
	local magnetPotion = data.ActiveBoosts.StrengthBoostEndsAt > os.time()
	if magnetPotion then
		strength += InventoryConfig.Consumables.StrengthPotion.Amount
		range *= InventoryConfig.Consumables.StrengthPotion.RangeMultiplier
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
	--[[
		THE PERMANENT REBIRTH BONUS, which is the entire reason to rebirth.

		Money, areas and upgrades all reset, so without this a prestige is a pure loss. +25% value per
		rebirth compounds against the x1.75 cost growth -- the growth has to be the faster of the two or
		each rebirth gets easier than the last, which is why those two numbers live next to each other in
		`PrestigeConfig` with a comment saying so.

		This is now the ONLY thing a rebirth pays. Gears used to multiply income on top of it and no longer
		do -- they are rebirth currency with no passive effect. See `PrestigeConfig`.

		Through `GameMath.prestigeValueMultiplier` rather than inline, because three readouts quote this
		number back to the player and none of them may disagree with what is applied here.
	]]
	scrapValue *= GameMath.prestigeValueMultiplier(
		data.PrestigeCount or 0,
		PrestigeConfig.ValuePerPrestige
	)
	--[[
		The live server-wide event, read from the schedule rather than from a service.

		`EventConfig` is pure arithmetic over `os.time()`, so this needs no state, no dependency and no
		ordering guarantee -- and it cannot drift out of step with what the HUD banner is claiming,
		because the banner is computed from the same function.
	]]
	local now = os.time()
	scrapValue *= EventConfig.multiplierAt("ScrapValue", now)
	local storageCapacity = effect("StorageCapacity")
	storageCapacity *= petEffects.Storage
	if data.Entitlements.StoragePlus == true then
		storageCapacity *= 1.5
	end
	local collectionSpeed = effect("CollectionSpeed")
	local respawnMultiplier = effect("ScrapFlow")
	collectionSpeed *= petEffects.CollectionSpeed
	respawnMultiplier *= petEffects.RespawnRate
	collectionSpeed *= EventConfig.multiplierAt("CollectionSpeed", now)
	respawnMultiplier *= EventConfig.multiplierAt("RespawnRate", now)
	if magnetPotion then
		collectionSpeed *= InventoryConfig.Consumables.StrengthPotion.CollectionMultiplier
	end
	--[[
		The Spawn Potion. `RespawnMultiplier` is a DIVISOR of time -- lower is faster -- so a potion that
		speeds respawn up multiplies by less than one. Reads the wrong way round the first time you see it.
	]]
	if data.ActiveBoosts.SpawnBoostEndsAt > os.time() then
		respawnMultiplier *= InventoryConfig.Consumables.SpawnPotion.RespawnMultiplier
	end
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
		--[[
			The 2x speed pass multiplies here, alongside pets. Applied to the upgrade's OWN effect rather
			than to a capped result, so the pass is not eaten by a cap the player has already reached.
		]]
		MovementSpeed = effect("MovementSpeed")
			* petEffects.MovementSpeed
			* (if data.Entitlements.PermanentSpeed == true then 2 else 1),
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
	--- Lucky Hour, from the same schedule the scrap-value events come from.
	multiplier *= EventConfig.multiplierAt("Luck", os.time())
	--- Permanent per-rebirth luck, the other half of what prestige buys.
	local prestigeCount = math.max(0, math.floor(session.Data.PrestigeCount or 0))
	multiplier *= 1 + prestigeCount * PrestigeConfig.LuckPerPrestige

	--[[
		THE CEILING ON TOTAL LUCK, and it is not decoration.

		Rarity weights scale as `weight x luck ^ exponent`, and Nebula's exponent is 2.6 -- so luck
		compounds super-linearly and every source multiplies: the Rarity upgrade, a potion, Lucky Hour, the
		God Potion, and now rebirths. Uncapped, a stacked player reaches a 4.5% Nebula rate, which at ~50
		pieces a minute is a server-wide announcement every twenty seconds.

		Capped here rather than on each source, because the problem is the PRODUCT, and any individual
		source looks reasonable on its own.
	]]
	return math.min(multiplier, ScrapConfig.MaximumLuckMultiplier)
end

--[[
	The event payload: which event is live and when it ends, or which is next and when it starts.

	Both cases are sent because a banner that only exists during an event teaches nobody the cadence,
	and the cadence is the reason the system exists (audit 3.7).
]]
local function activeEventPayload(): { [string]: any }
	local now = os.time()
	local definition, remaining = EventConfig.activeAt(now)
	if definition then
		return { Id = definition.Id, EndsAt = now + remaining, Live = true }
	end
	local upcoming, wait = EventConfig.nextAt(now)
	if upcoming then
		return { Id = upcoming.Id, StartsAt = now + wait, Live = false }
	end
	return { Live = false }
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
		--[[
			THE MAILBOX RIDES THE NORMAL SNAPSHOT rather than a remote of its own. That is deliberate: a
			claim pays money AND marks the message, and if those arrived on two channels the player could
			see one without the other. One snapshot, one truth.
		]]
		Inbox = data.Inbox,
		SocialClaims = data.SocialClaims,
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
		--[[
			THE LIVE EVENT, from the server's clock.

			Identity and end time come from here rather than being recomputed on the client, because a
			player with a wrong system clock would otherwise see a banner that disagrees with the
			multipliers they are actually getting -- which is the exact failure the fake banner was.

			The client looks the title, glyph and accent up from `EventConfig` by id and ticks the
			countdown itself, the same way boost timers already work.
		]]
		ActiveEvent = activeEventPayload(),
		--- Achievements and titles: which are paid, which are held, which is worn.
		UnlockedAchievements = table.clone(data.UnlockedAchievements),
		UnlockedTitles = table.clone(data.UnlockedTitles),
		EquippedTitle = data.EquippedTitle,
		MaximumEquippedPets = PetConfig.BaseEquipSlots
			+ data.PetSlotUpgradeLevel
			+ (if data.Entitlements.ExtraPetSlots == true then PetConfig.PassBonusSlots else 0),
		PetStorageCapacity = PetConfig.BaseStorageCapacity,
		--- Guaranteed-Secret rolls in hand, so the pets window can say so rather than surprising anyone.
		SecretTickets = data.SecretTickets,

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
	--[[
		THE PLOT THEME GOES BACK WITH THE UNLOCKS.

		Without this a rebirth left `ActivePlotTheme` on whatever the player had converted to, so they kept
		a Vehicle Graveyard yard while owning only the Front Yard unlock -- and `ScrapService` reads this
		field to decide which scrap to spawn, so they also kept spawning Graveyard scrap they could no
		longer sell the area for. Resetting the unlocks without resetting the theme is only half a rebirth.

		`PrestigeService` has to rebuild the plot geometry afterwards; changing the field alone leaves the
		old yard standing in the world. `AdminService` learned the same lesson on profile wipes.
	]]
	data.ActivePlotTheme = "FrontYard"
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

--[[
	Grant one upgrade level, ignoring the cash price.

	Used by the Robux "+1" products. Still bounded by the prestige level cap -- Robux skips the COST, not the
	progression -- so a maxed upgrade refuses and the receipt is reported as unfulfilled rather than
	silently swallowed.
]]
local function grantUpgradeLevel(data: { [string]: any }, upgradeId: string): boolean
	local definition = UpgradeConfig.ById[upgradeId]
	if definition == nil then
		return false
	end
	local current = data.UpgradeLevels[upgradeId] or 0
	local maximum = GameMath.upgradeMaximumLevel(
		definition.BaseMaximumLevel,
		definition.LevelsPerPrestige,
		data.PrestigeCount
	)
	if current >= maximum then
		return false
	end
	data.UpgradeLevels[upgradeId] = current + 1
	return true
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
	--[[
		A Robux upgrade product raises one level. Handled before the receipt bookkeeping below so a refused
		grant -- a maxed upgrade -- leaves the receipt unprocessed and Roblox retries rather than charging
		for nothing.
	]]
	local upgradeId = (definition :: any).UpgradeId
	if typeof(upgradeId) == "string" and data.ProcessedReceipts[purchaseId] ~= true then
		if not grantUpgradeLevel(data, upgradeId) then
			return false, "That upgrade is already at its cap"
		end
	end
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

	--[[
		A title in the bundle. Recorded as HELD, never auto-worn -- except when the player has none, where
		putting the first one on is obviously what they want. Silently replacing a title someone chose
		would be the annoying version of this.
	]]
	if typeof(rewards.TitleId) == "string" and TitleConfig.ById[rewards.TitleId] ~= nil then
		data.UnlockedTitles[rewards.TitleId] = true
		if data.EquippedTitle == "" then
			data.EquippedTitle = rewards.TitleId
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
--[[
	Put a message in a player's mailbox. Called by `InboxService`, which owns the message shape.

	Newest last. When the mailbox is full the oldest CLAIMED message is dropped -- never an unclaimed one,
	because that would silently delete a reward the player was owed. A mailbox full of unclaimed mail
	refuses new mail instead, which is visible and therefore fixable.
]]
function PlayerStateService.AddInboxMessage(player: Player, message: { [string]: any }): boolean
	local session = sessions[player]
	if session == nil then
		return false
	end
	local data = session.Data
	if typeof(data.Inbox) ~= "table" then
		data.Inbox = {}
	end

	while #data.Inbox >= InboxConfig.MaximumMessages do
		local dropped = nil
		for index, existing in data.Inbox do
			if existing.Claimed == true then
				dropped = index
				break
			end
		end
		if dropped == nil then
			return false
		end
		table.remove(data.Inbox, dropped)
	end

	table.insert(data.Inbox, message)
	pushState(player, data)
	return true
end

--[[
	Claim one message: pay what it carries, then mark it.

	The reward is read from the SAVE, never from the client -- the remote carries an id and nothing else.
	Marking happens only if the payment succeeded, so a failed grant leaves the message claimable rather
	than consuming it.
]]
function PlayerStateService.ClaimInboxMessage(player: Player, messageId: string): (boolean, string)
	local session = sessions[player]
	if session == nil then
		return false, "NOT READY"
	end
	local data = session.Data
	if typeof(data.Inbox) ~= "table" then
		return false, "NOTHING TO CLAIM"
	end

	for _, message in data.Inbox do
		if message.Id == messageId then
			if message.Claimed == true then
				return false, "ALREADY CLAIMED"
			end
			if message.Rewards ~= nil then
				if not PlayerStateService.GrantRewards(player, message.Rewards) then
					return false, "COULD NOT CLAIM THAT"
				end
			end
			message.Claimed = true
			pushState(player, data)
			return true, `CLAIMED: {message.Title}`
		end
	end
	return false, "MESSAGE NOT FOUND"
end

--- Sweep up everything claimable. Returns how many were paid.
function PlayerStateService.ClaimAllInboxMessages(player: Player): (number, string)
	local session = sessions[player]
	if session == nil then
		return 0, "NOT READY"
	end
	local claimed = 0
	for _, message in session.Data.Inbox do
		if message.Claimed ~= true then
			local paid = message.Rewards == nil
				or PlayerStateService.GrantRewards(player, message.Rewards)
			if paid then
				message.Claimed = true
				claimed += 1
			end
		end
	end
	if claimed > 0 then
		pushState(player, session.Data)
	end
	return claimed, `CLAIMED {claimed} MESSAGE{if claimed == 1 then "" else "S"}`
end

--[[
	Take a one-off social reward (the like, the group).

	The eligibility CHECK lives in `SocialRewardService` -- group membership is a web call and does not
	belong in the state layer. This owns the "only once" half, which is the half that has to be in the save.
]]
function PlayerStateService.ClaimSocialReward(player: Player, rewardId: string): (boolean, string)
	local session = sessions[player]
	if session == nil then
		return false, "NOT READY"
	end
	local definition = SocialConfig.Rewards[rewardId]
	if definition == nil then
		return false, "UNKNOWN REWARD"
	end
	local data = session.Data
	if typeof(data.SocialClaims) ~= "table" then
		data.SocialClaims = {}
	end
	if data.SocialClaims[rewardId] == true then
		return false, "ALREADY CLAIMED"
	end
	if not PlayerStateService.GrantRewards(player, definition.Rewards) then
		return false, "COULD NOT CLAIM THAT"
	end
	data.SocialClaims[rewardId] = true
	pushState(player, data)
	return true, `CLAIMED: {definition.Label}`
end

--[[
	Take the next friend milestone the live friend count has earned.

	The SERVER picks which milestone, from `FriendBoostCount`. A client that could name its own milestone
	could claim the top rung on its first join, which is why the remote carries no index.
]]
function PlayerStateService.ClaimInviteMilestone(player: Player): (boolean, string)
	local session = sessions[player]
	if session == nil then
		return false, "NOT READY"
	end
	local data = session.Data
	if typeof(data.SocialClaims) ~= "table" then
		data.SocialClaims = {}
	end
	local ready = SocialConfig.claimableInvites(data.FriendBoostCount or 0, data.SocialClaims)
	if #ready == 0 then
		return false, "BRING A FRIEND TO CLAIM MORE"
	end
	local index = ready[1]
	local milestone = SocialConfig.Invite.Milestones[index]
	if not PlayerStateService.GrantRewards(player, milestone.Rewards) then
		return false, "COULD NOT CLAIM THAT"
	end
	data.SocialClaims[`Invite{index}`] = true
	pushState(player, data)
	return true, `CLAIMED: {milestone.Friends} FRIEND REWARD`
end

--[[
	Save one player right now.

	Exists for the restart countdown, which has to flush before the server goes away. A thin wrapper on the
	private `saveSession` rather than exposing that, so callers cannot pass the flags it takes.
]]
function PlayerStateService.SaveNow(player: Player): boolean
	if sessions[player] == nil then
		return false
	end
	return saveSession(player, false)
end

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
	--[[
		Roblox's own player list, updated from the same funnel as everything else.

		Here rather than on a timer because this is already the one place every money and prestige change
		passes through, so the Tab columns cannot lag behind the HUD.
	]]
	LeaderstatsService.Publish(player, data)
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
	--[[
		Publish the Tab columns HERE as well as from `pushState`.

		This function deliberately does not push state -- the client pulls a snapshot over the Bridge
		handshake instead -- so a player who joins and stands still never triggers a push, and their row
		in the player list would stay blank until they next earned or spent something. Measured: sixteen
		seconds after joining with storage full, `leaderstats` did not exist.
	]]
	LeaderstatsService.Publish(player, data)
	grantStaffTitles(player, data)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.WalkSpeed = derivedStats(data).MovementSpeed
	end
end

local function onPlayerRemoving(player: Player)
	lastActiveAt[player] = nil
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

--[[
	Re-push every loaded player's snapshot.

	For state that changes without any player doing anything -- a scheduled event opening or closing.
	`EventService` owns the "when"; this is the only thing it needs from here, which keeps the two
	services from knowing anything else about each other.
]]
--[[
	Publish the worn title as an attribute on the Player.

	ATTRIBUTES, NOT A REMOTE, because the audience is every OTHER client: the nameplate over a head and
	the prefix on a chat line are drawn by everyone in the server, not by the player who owns the title.
	Attributes replicate to all clients and arrive with the Player instance, so a late joiner sees the
	titles of people already here with no request and no cache to invalidate.

	The TEXT is published rather than the id so the two readers need no config lookup, and the id is
	published too so the UI can mark the equipped card without matching on display text.
]]
local function publishTitle(player: Player, data: { [string]: any })
	local definition = TitleConfig.resolve(data.EquippedTitle)
	player:SetAttribute("TitleId", if definition then definition.Id else "")
	player:SetAttribute("TitleTag", TitleConfig.tag(data.EquippedTitle))
end

--[[
	Staff titles, granted from WHO SOMEONE IS rather than what they did.

	Checked on every load rather than once, because the answer can change without the player doing
	anything -- an id added to `AdminConfig` should take effect on their next join with no migration and
	no grant script. Revoking works the same way in reverse: the title is dropped from the held set, and
	taken off if they were wearing it.

	NOT auto-worn on grant. Someone who has picked SCRAPYARD LEGEND should keep it; the staff title is
	there to be chosen. The exception is the usual one -- if they are wearing nothing, the best thing they
	hold goes on, and for staff that is the staff title.
]]
grantStaffTitles = function(player: Player, data: { [string]: any })
	local entitled = {
		Admin = AdminConfig.IsAdmin(player.UserId),
		Owner = AdminConfig.IsOwner(player.UserId),
	}
	local changed = false
	for titleId, allowed in entitled do
		if allowed and data.UnlockedTitles[titleId] ~= true then
			data.UnlockedTitles[titleId] = true
			changed = true
			if data.EquippedTitle == "" then
				data.EquippedTitle = titleId
			end
		elseif not allowed and data.UnlockedTitles[titleId] == true then
			--- No longer staff: the title goes, and comes off if it was being worn.
			data.UnlockedTitles[titleId] = nil
			changed = true
			if data.EquippedTitle == titleId then
				data.EquippedTitle = ""
			end
		end
	end
	if changed then
		publishTitle(player, data)
	end
end

--[[
	Wear a title, or take it off with "".

	Refuses a title the player does not hold -- the client sends an id and ids are guessable, so this is
	the check that stops anyone wearing the one title nobody has earned yet.
]]
function PlayerStateService.TryEquipTitle(player: Player, titleId: string): (boolean, string)
	local session = sessions[player]
	if session == nil then
		return false, "Your data is still loading"
	end
	local data = session.Data
	if titleId == "" then
		data.EquippedTitle = ""
		publishTitle(player, data)
		pushState(player, data)
		return true, "Title removed"
	end
	local definition = TitleConfig.resolve(titleId)
	if definition == nil then
		return false, "No such title"
	end
	if data.UnlockedTitles[titleId] ~= true then
		return false, "You have not earned that title"
	end
	data.EquippedTitle = titleId
	publishTitle(player, data)
	pushState(player, data)
	return true, `Now wearing {definition.Text}`
end

--- Re-publish the title attributes, for callers that changed the data behind our back.
function PlayerStateService.RefreshTitle(player: Player)
	local session = sessions[player]
	if session then
		publishTitle(player, session.Data)
	end
end

function PlayerStateService.PushAll()
	for player, session in sessions do
		if not session.Released then
			pushState(player, session.Data)
		end
	end
end

--[[
	Note that this player just did something. Cheap enough to call from any gameplay path.

	Called from collection, selling, buying an upgrade and buying an area -- the four things that mean
	somebody is playing rather than parked. Movement is deliberately NOT one of them: a character wedged
	against a wall by a stuck input jitters forever, and that is the exact case AFK detection exists to
	catch.
]]
function PlayerStateService.MarkActive(player: Player)
	lastActiveAt[player] = os.clock()
end

--[[
	Has this player done anything recently enough to be counted as playing?

	True for a player who has only just joined and not yet touched anything -- they are at their keyboard,
	and starting the clock at zero would mean the first minute of a session never counts.
]]
function PlayerStateService.IsActive(player: Player): boolean
	local at = lastActiveAt[player]
	if at == nil then
		return true
	end
	return os.clock() - at <= RewardsConfig.Playtime.ActivityWindowSeconds
end

function PlayerStateService.GetPublicState(player: Player): { [string]: any }?
	local session = sessions[player]
	return if session then publicSnapshot(session.Data) else nil
end

--- `ignoreAreaLock`: see `CanCollect`. The two must agree or a piece passes the check and fails the take.
function PlayerStateService.TryCollect(
	player: Player,
	scrapId: string,
	variantId: string,
	areaId: string,
	ignoreAreaLock: boolean?
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
	--[[
		ONE SLOT PER PIECE, not its weight. See `ScrapConfig.SlotsPerScrap`.

		`StoredWeight` is now a COUNT of carried pieces despite the name. The field is kept because renaming
		it means a schema migration plus every client readout, and it is listed as a follow-up in
		`plan/ECONOMY_REBALANCE.md`. The HUD already reads as a count, so what a player sees is right.
	]]
	local allowed, reason = CollectionRules.canCollect(
		stats.MagnetStrength,
		scrap.RequiredMagnetStrength,
		data.StoredWeight,
		stats.StorageCapacity,
		ScrapConfig.SlotsPerScrap,
		ignoreAreaLock == true or data.UnlockedAreas[areaId] == true,
		true
	)
	if not allowed then
		return false, reason
	end

	PlayerStateService.MarkActive(player)
	data.StoredWeight += ScrapConfig.SlotsPerScrap
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

--[[
	`ignoreAreaLock` is for THE PIT and nothing else.

	Arena scrap is not on anybody's plot and is deliberately not gated by area progression -- a new player
	standing in the Pit can pull a scrap car, and that is the whole draw. Magnet strength and storage still
	apply, so the upgrade tree keeps its meaning; see `ArenaConfig`.

	An explicit argument rather than spawning arena pieces with `AreaId = "FrontYard"`, which would have
	worked (everyone has it) and would have quietly filed a scrap car as a Front Yard discovery.
]]
function PlayerStateService.CanCollect(
	player: Player,
	scrapId: string,
	areaId: string,
	ignoreAreaLock: boolean?
): (boolean, string)
	local session = sessions[player]
	local scrap = ScrapConfig.ById[scrapId]
	if session == nil or scrap == nil or AreaConfig.ById[areaId] == nil then
		return false, "Invalid"
	end
	local data = session.Data
	local stats = derivedStats(data)
	--- Must ask exactly what `TryCollect` asks, or a piece passes the check and fails the take.
	return CollectionRules.canCollect(
		stats.MagnetStrength,
		scrap.RequiredMagnetStrength,
		data.StoredWeight,
		stats.StorageCapacity,
		ScrapConfig.SlotsPerScrap,
		ignoreAreaLock == true or data.UnlockedAreas[areaId] == true,
		true
	)
end

function PlayerStateService.TrySell(player: Player): (boolean, number)
	local session = sessions[player]
	if session == nil or session.Data.StoredValue <= 0 then
		return false, 0
	end
	PlayerStateService.MarkActive(player)
	local data = session.Data
	local stats = derivedStats(data)
	local award =
		CollectionRules.sellAward(data.StoredValue, stats.ScrapValue, Environment.MaximumMoney)
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
	PlayerStateService.MarkActive(player)
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
	--- Computed ONCE and used for both the check and the charge, so they cannot disagree.
	local price = AreaRules.unlockPrice(definition.UnlockPrice, data.PrestigeCount)
	local allowed, reason = AreaRules.canUnlock(
		data.UnlockedAreas[areaId] == true,
		previousId ~= nil and data.UnlockedAreas[previousId] == true,
		data.Money,
		price
	)
	if not allowed then
		return false, reason
	end

	PlayerStateService.MarkActive(player)
	data.Money -= price
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
	elseif command == "ResetProfile" then
		--[[
			BACK TO A BRAND-NEW PROFILE. Everything: money, gears, upgrades, areas, pets, titles,
			achievements, entitlements, discoveries, streaks, storage, rebirths.

			`createDefault` is the same function a genuine first join uses, so there is no separate list of
			"things to clear" to fall out of step with the schema. A new field added to a save is blank here
			for free; a hand-written reset would keep whatever the wipe forgot about, which is exactly the
			bug that makes a reset look like it did nothing.

			THEN THE JOIN STEPS ARE RE-RUN, because "as if they just joined" is more than the data:
			`onPlayerAdded` also grants staff titles, publishes the worn title, writes the Tab columns and
			sets walk speed. Missing those left a wiped player wearing their old title, walking at their old
			upgraded speed, with stale numbers in the player list.
		]]
		session.Data = PlayerDataSchema.createDefault(os.time())
		data = session.Data
		--[[
			Staff titles come back, and that is correct. They are granted from WHO SOMEONE IS rather than
			from anything they earned, so a real rejoin would hand them straight back -- see
			`grantStaffTitles`.
		]]
		grantStaffTitles(player, data)
		--- The fresh profile wears nothing of its own, so the nameplate has to be told.
		publishTitle(player, data)
		LeaderstatsService.Publish(player, data)
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			humanoid.WalkSpeed = derivedStats(data).MovementSpeed
		end
		--[[
			Saved straight away rather than at the next autosave.

			A wipe that lives only in memory is undone by a crash or a quick rejoin, and the person who
			asked for it has already moved on believing it happened. `saveSession` is the same path a normal
			save takes, so the write is bounded and sanitised like any other.
		]]
		saveSession(player, false)
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
	elseif command == "GrantSecretTicket" then
		--[[
			Tickets, not a forced pet. Handing the pet over directly would skip the roll -- and the roll is
			the thing worth testing: the reveal, the batch, and the server-wide announcement all hang off it.
		]]
		local grant = math.floor(math.clamp(amount or 1, 1, 100))
		data.SecretTickets = math.min(100, (data.SecretTickets or 0) + grant)
	elseif command == "GrantEntitlement" then
		local definition = if itemId then MonetizationConfig.Passes[itemId] else nil
		if definition == nil then
			return false, "Unknown pass ID"
		end
		--[[
			The same flag a receipt sets. Deliberately NOT routed through `GrantEntitlement`, which also
			records a receipt id -- an admin grant is not a purchase, and writing a fake receipt would make
			the player's purchase history a lie.
		]]
		data.Entitlements[definition.Id] = true
	elseif command == "GrantTitle" then
		local definition = if itemId then TitleConfig.resolve(itemId) else nil
		if definition == nil then
			return false, "Unknown title ID"
		end
		--- Granted AND worn: see the note in `AdminCatalogue` for why this one equips itself.
		data.UnlockedTitles[definition.Id] = true
		data.EquippedTitle = definition.Id
		publishTitle(player, data)
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
	elseif command == "ActivateBoost" then
		--[[
			TURN A POTION ON WITHOUT HANDING OVER THE POTION.

			`GrantConsumable` puts a bottle in the player's bag and leaves them to drink it, which is the
			wrong tool for "everyone gets double cash for the next half hour" -- half the server never
			opens their inventory. This writes the boost's expiry directly, exactly as
			`TryUseConsumable` does, so there is one representation of an active boost and the HUD timers,
			`derivedStats` and the save all keep working with no special case.

			`itemId` may be a COMMA-SEPARATED LIST, which is how the panel activates several at once: one
			remote call, one rate-limit slot, and every effect starting on the same second rather than
			staggered across four round trips.

			`amount` is MINUTES, clamped -- see `AdminConfig.MaximumServerBoostMinutes`. Boosts EXTEND
			rather than replace, the same as drinking a second potion.
		]]
		if itemId == nil then
			return false, "No boost specified"
		end
		local minutes =
			math.clamp(math.floor(amount or 0), 1, AdminConfig.MaximumServerBoostMinutes)
		local seconds = minutes * 60
		local applied = {}
		for id in string.gmatch(itemId, "[^,]+") do
			local definition = InventoryConfig.Consumables[id]
			if definition ~= nil then
				local key = `{definition.BoostId}EndsAt`
				local startAt = math.max(os.time(), data.ActiveBoosts[key] or 0)
				data.ActiveBoosts[key] = startAt + seconds
				table.insert(applied, definition.DisplayName)
			end
		end
		if #applied == 0 then
			return false, "No known boost in that list"
		end
	else
		return false, "Unknown admin command"
	end
	pushState(player, data)
	return true, `{command} applied to {player.DisplayName}`
end

--[[
	How many eggs this player may open at once, and whether a requested count is allowed.

	The entitlement is checked here rather than trusted from the client, because the count arrives over
	a remote and "open five" is worth lying about.
]]
local function batchAllowed(data: { [string]: any }, count: number): boolean
	if count == 1 then
		return true
	end
	for _, batch in PetConfig.HatchBatches do
		if batch.Count == count then
			return data.Entitlements[batch.Entitlement] == true
		end
	end
	return false
end

function PlayerStateService.TryOpenEgg(
	player: Player,
	eggId: string,
	count: number?
): (boolean, string, { string }?)
	local session = sessions[player]
	local egg = PetConfig.Eggs[eggId]
	if session == nil or egg == nil then
		return false, "Egg unavailable", nil
	end
	local data = session.Data
	local batch = math.floor(count or 1)
	if not batchAllowed(data, batch) then
		return false, "You do not own that multi-hatch", nil
	end

	local ownedCount = 0
	for _, amount in data.OwnedPets do
		ownedCount += amount
	end

	--[[
		EVERY CHECK IS FOR THE WHOLE BATCH, and it is all-or-nothing.

		Opening three when there is room for two, or cash for two, would leave the player having paid for
		something they did not get. So the batch is rejected outright and the message says which limit
		bit -- a partial hatch is a support ticket.
	]]
	local space = PetConfig.BaseStorageCapacity - ownedCount
	if space < batch then
		return false,
			if space <= 0
				then "Pet storage is full"
				else `Only room for {space} more pet{if space == 1 then "" else "s"}`,
			nil
	end
	if data.UnlockedAreas[egg.RequiredArea] ~= true then
		return false, "Unlock this egg's area first", nil
	end
	local totalPrice = egg.Price * batch
	if data.Money < totalPrice then
		return false, "Not enough Scrap Cash", nil
	end

	--[[
		Rolled one at a time so the PITY COUNTERS advance across the batch exactly as they would across
		that many single presses. A batch that rolled once and multiplied the result would hand out three
		identical pets and quietly break both pity rules.
	]]
	data.Money -= totalPrice
	local wonPetIds = {}
	for _ = 1, batch do
		local nextOpenCount = (data.EggOpenCounts[eggId] or 0) + 1
		local wonPetId
		--[[
			A TICKET BEATS EVERY OTHER RULE, including both pity counters: it is granted precisely so its
			holder can see a Secret on demand, and a ticket that lost to a weight roll would be worthless.

			Spent per ROLL, not per press, so a x5 with two tickets is two guaranteed Secrets and three
			normal rolls. The pity counter still advances underneath, because the ticket is extra rather
			than instead.
		]]
		if (data.SecretTickets or 0) > 0 then
			data.SecretTickets -= 1
			wonPetId = egg.PetIds[6]
		elseif nextOpenCount % PetConfig.SecretPityRolls == 0 then
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
		table.insert(wonPetIds, wonPetId)
	end

	pushState(player, data)
	local message = if batch == 1
		then `{PetConfig.Pets[wonPetIds[1]].DisplayName} hatched!`
		else `{batch} pets hatched!`
	return true, message, wonPetIds
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

--[[
	Delete pets. `count` copies of one pet, defaulting to one.

	A count rather than a list of ids because the remote carries one target: the screen's bulk delete
	sends one call per SELECTED PET with how many of that pet to drop, which is a handful of calls
	instead of one per copy -- and the rate limiter counts calls.
]]
function PlayerStateService.TryDeletePet(
	player: Player,
	petId: string,
	count: number?
): (boolean, string)
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

	--- Never more than are owned, and never fewer than one: a count of zero would be a silent no-op.
	local removing = math.clamp(math.floor(count or 1), 1, owned)

	--[[
		Unequip as many copies as are being deleted, newest first.

		A pet can be equipped more than once when several copies are owned, so deleting two copies has to
		free two slots. Iterating backwards means the indices behind the one being removed stay valid.
	]]
	local toUnequip = removing
	for index = #data.EquippedPets, 1, -1 do
		if toUnequip <= 0 then
			break
		end
		if data.EquippedPets[index] == petId then
			table.remove(data.EquippedPets, index)
			toUnequip -= 1
		end
	end

	if owned - removing <= 0 then
		data.OwnedPets[petId] = nil
	else
		data.OwnedPets[petId] = owned - removing
	end
	pushState(player, data)
	local message = if removing == 1
		then `{definition.DisplayName} deleted`
		else `{removing}x {definition.DisplayName} deleted`
	return true, message
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
	--[[
		A magnet may require an area to have been REACHED. Checked against `DiscoveredScrap` rather than
		`UnlockedAreas`, because unlocks reset on rebirth and a magnet does not: "you have been to the
		Graveyard" has to stay true forever once it is, or a rebirth would lock the shop behind content the
		player has already beaten.
	]]
	local requiredArea = (definition :: any).RequiredArea
	if typeof(requiredArea) == "string" then
		local reached = false
		local area = AreaConfig.ById[requiredArea]
		if area ~= nil then
			for _, scrapId in area.ScrapIds do
				local record = data.DiscoveredScrap[scrapId]
				if type(record) == "table" and record.Discovered == true then
					reached = true
					break
				end
			end
		end
		if not reached then
			return false,
				`REACH THE {string.upper(area and area.DisplayName or requiredArea)} FIRST`
		end
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

--[[
	The live save table for a loaded player, or nil.

	MUTABLE ON PURPOSE, and the only caller is `AchievementService`, which marks an achievement paid in
	the same table it read the progress from. Everything else goes through the Try* functions, which
	validate and push -- a service reaching in here to change a number would skip both.
]]
function PlayerStateService.GetSaveData(player: Player): { [string]: any }?
	local session = sessions[player]
	return if session then session.Data else nil
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
