--!strict

local GameMath = require("../src/shared/Utility/GameMath")
local RateLimiter = require("../src/shared/Utility/RateLimiter")
local PlayerDataSchema = require("../src/shared/Utility/PlayerDataSchema")
local CollectionRules = require("../src/shared/Utility/CollectionRules")
local PlotRules = require("../src/shared/Utility/PlotRules")
local AreaRules = require("../src/shared/Utility/AreaRules")
local AdminConfig = require("../src/shared/Config/AdminConfig")

local passed = 0

local function expectEqual(actual: any, expected: any, label: string)
	if actual ~= expected then
		error(`{label}: expected {tostring(expected)}, received {tostring(actual)}`, 2)
	end
	passed += 1
end

local function expectNear(actual: number, expected: number, epsilon: number, label: string)
	if math.abs(actual - expected) > epsilon then
		error(`{label}: expected {expected}, received {actual}`, 2)
	end
	passed += 1
end

expectEqual(GameMath.isFinite(10), true, "finite number")
expectEqual(GameMath.isFinite(math.huge), false, "infinity")
expectEqual(GameMath.isFinite(0 / 0), false, "NaN")
expectEqual(GameMath.clampFinite(math.huge, 0, 100, 12), 12, "nonfinite fallback")

expectEqual(GameMath.upgradeCost(45, 1.52, 0, 1e15), 45, "initial upgrade cost")
expectEqual(GameMath.upgradeCost(45, 1.52, 2, 1e15), 103, "grown upgrade cost")
expectEqual(GameMath.upgradeCost(-1, 1.5, 0, 1e15), 1e15, "invalid upgrade cost")
expectNear(GameMath.upgradeEffect(4, 2.5, 3, 54), 11.5, 1e-6, "upgrade effect")
expectEqual(GameMath.upgradeEffect(4, 2.5, 100, 54), 54, "effect cap")

expectEqual(GameMath.scrapValue(100, 15, 3.4, 1e12), 5100, "scrap multipliers")
expectEqual(GameMath.scrapValue(-1, 15, 3.4, 1e12), 0, "negative scrap value")
expectEqual(GameMath.canStore(14, 20, 6), true, "exact capacity")
expectEqual(GameMath.canStore(15, 20, 6), false, "over capacity")
expectEqual(GameMath.canStore(0, 20, 0 / 0), false, "invalid scrap weight")

expectEqual(GameMath.prestigeGearReward(749999, 750000, 100), 0, "prestige below requirement")
expectEqual(GameMath.prestigeGearReward(750000, 750000, 100), 1, "first prestige reward")
expectEqual(GameMath.prestigeGearReward(1000000000, 750000, 100), 100, "prestige reward cap")
expectNear(GameMath.gearValueMultiplier(4, 0.1, 10), 1.4, 1e-6, "gear multiplier")
expectEqual(GameMath.gearValueMultiplier(1000, 0.1, 10), 10, "gear multiplier cap")

local limiter = RateLimiter.new(2, 5)
expectEqual(limiter:Allow("player", 0), true, "rate limit first request")
expectEqual(limiter:Allow("player", 1), true, "rate limit second request")
expectEqual(limiter:Allow("player", 2), false, "rate limit rejection")
expectEqual(limiter:Allow("player", 5), true, "rate limit window reset")

local defaultData = PlayerDataSchema.createDefault(1000)
expectEqual(defaultData.SchemaVersion, 6, "default schema version")
expectEqual(defaultData.EquippedMagnet, "MagnetBasic", "default equipped magnet")
expectEqual(defaultData.OwnedMagnets.MagnetBasic, true, "default owned magnet")
expectEqual(defaultData.Inventory.CashPotion, 0, "default cash potion count")
expectEqual(defaultData.RedeemedCodes.STUDIOKIT, nil, "default redeemed codes empty")
expectEqual(defaultData.Entitlements.DoubleCash, nil, "default monetization entitlement empty")
expectEqual(defaultData.ProcessedReceipts.Test, nil, "default receipt history empty")
expectEqual(defaultData.UnlockedAreas.FrontYard, true, "default starting area")
expectEqual(defaultData.UnlockedAreas.WorkshopYard, false, "default locked area")
expectEqual(defaultData.Settings.ParticlesEnabled, true, "default particle setting")
expectNear(defaultData.Settings.SoundVolume, 0.8, 1e-6, "default sound volume")
expectNear(defaultData.Settings.MusicVolume, 0.55, 1e-6, "default music volume")
expectEqual(defaultData.CreatedTimestamp, 1000, "default creation timestamp")

local migratedOk, migrated = PlayerDataSchema.validate({
	SchemaVersion = 1,
	Money = 125,
	UpgradeLevels = { MagnetStrength = 3 },
	UnlockedAreas = { WorkshopYard = true },
	DiscoveredScrap = {
		MetalCan = { Discovered = true, HighestVariant = "Gold", TotalCollected = 9 },
	},
	Settings = { SoundEnabled = false },
	LastLoginTimestamp = 800,
}, 1000)
expectEqual(migratedOk, true, "version one migration")
expectEqual(migrated.SchemaVersion, 6, "migrated schema version")
expectEqual(migrated.Money, 125, "migrated money")
expectEqual(migrated.UpgradeLevels.MagnetStrength, 3, "migrated upgrade")
expectEqual(migrated.UpgradeLevels.MagnetRange, 0, "repaired missing upgrade")
expectEqual(migrated.UnlockedAreas.WorkshopYard, true, "migrated area")
expectEqual(migrated.DiscoveredScrap.MetalCan.HighestVariant, "Gold", "migrated discovery")
expectEqual(migrated.Settings.SoundEnabled, false, "migrated setting")
expectEqual(migrated.Settings.MusicEnabled, true, "repaired missing setting")
expectEqual(migrated.CreatedTimestamp, 800, "migrated creation timestamp")
expectEqual(migrated.PlotStage, 1, "migrated plot stage")
expectEqual(migrated.UnlockedScrapTypes.MetalCan, true, "migrated starter scrap")
expectEqual(migrated.CrusherLevel, 1, "migrated crusher level")

local repairedOk, repaired = PlayerDataSchema.validate({
	SchemaVersion = 2,
	Money = math.huge,
	StoredWeight = -12,
	UpgradeLevels = { StorageCapacity = 999 },
	UnlockedAreas = { FrontYard = false },
	DiscoveredScrap = { Tire = { HighestVariant = "Invalid", TotalCollected = -4 } },
}, 2000)
expectEqual(repairedOk, true, "invalid fields repair")
expectEqual(repaired.Money, 0, "nonfinite money repair")
expectEqual(repaired.StoredWeight, 0, "negative storage repair")
expectEqual(repaired.UpgradeLevels.StorageCapacity, 25, "upgrade level clamp")
expectEqual(repaired.UnlockedAreas.FrontYard, true, "starting area invariant")
expectEqual(repaired.DiscoveredScrap.Tire.HighestVariant, "Normal", "variant repair")
expectEqual(repaired.PlotStage, 1, "plot stage repair")
expectEqual(repaired.UnlockedMachines.Crusher, true, "crusher invariant")

local invalidRootOk = PlayerDataSchema.validate("corrupt", 2000)
expectEqual(invalidRootOk, false, "corrupt root rejection")

local futureOk = PlayerDataSchema.validate({ SchemaVersion = 999 }, 2000)
expectEqual(futureOk, false, "future schema rejection")

expectEqual(
	CollectionRules.canCollect(4, 3, 17, 20, 3, true, true),
	true,
	"collection exact capacity"
)
local weakAllowed, weakReason = CollectionRules.canCollect(2, 3, 0, 20, 3, true, true)
expectEqual(weakAllowed, false, "weak magnet rejection")
expectEqual(weakReason, "TooHeavy", "weak magnet reason")
local fullAllowed, fullReason = CollectionRules.canCollect(4, 3, 18, 20, 3, true, true)
expectEqual(fullAllowed, false, "full storage rejection")
expectEqual(fullReason, "StorageFull", "full storage reason")
local lockedAllowed, lockedReason = CollectionRules.canCollect(4, 3, 0, 20, 3, false, true)
expectEqual(lockedAllowed, false, "locked area rejection")
expectEqual(lockedReason, "AreaLocked", "locked area reason")
expectEqual(CollectionRules.sellAward(20, 1.5, 1.2, 1000), 36, "sell award")
expectEqual(CollectionRules.sellAward(0, 10, 10, 1000), 0, "empty sale")
expectEqual(PlotRules.isOwner(42, 42, "Plot01", "Plot01"), true, "plot owner allowed")
expectEqual(PlotRules.isOwner(42, 7, "Plot02", "Plot01"), false, "visitor rejected")
expectEqual(PlotRules.isOwner(42, 42, "Plot02", "Plot01"), false, "wrong assignment rejected")
expectEqual(PlotRules.isOwner(0, 42, "Plot01", "Plot01"), false, "unowned plot rejected")

local areaAllowed, areaReason = AreaRules.canUnlock(false, true, 6500, 6500)
expectEqual(areaAllowed, true, "area exact-price unlock")
expectEqual(areaReason, "Unlocked", "area unlock reason")
local orderAllowed, orderReason = AreaRules.canUnlock(false, false, 90000, 90000)
expectEqual(orderAllowed, false, "area sequential unlock")
expectEqual(orderReason, "Unlock the previous area first", "area sequence reason")
local fundsAllowed, fundsReason = AreaRules.canUnlock(false, true, 6499, 6500)
expectEqual(fundsAllowed, false, "area affordability")
expectEqual(fundsReason, "Not enough Scrap Cash", "area affordability reason")
local duplicateAllowed = AreaRules.canUnlock(true, true, 90000, 6500)
expectEqual(duplicateAllowed, false, "area duplicate rejection")
expectEqual(AdminConfig.IsAdmin(1113999731), true, "configured owner admin")
expectEqual(AdminConfig.IsAdmin(1), false, "unknown user is not admin")

print(`Scrapyard foundation and data tests passed: {passed}`)
