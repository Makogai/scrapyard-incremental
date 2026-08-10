--!strict

local GameMath = require("../src/shared/Utility/GameMath")
local RateLimiter = require("../src/shared/Utility/RateLimiter")
local PlayerDataSchema = require("../src/shared/Utility/PlayerDataSchema")
local CollectionRules = require("../src/shared/Utility/CollectionRules")
local PlotRules = require("../src/shared/Utility/PlotRules")
local AreaRules = require("../src/shared/Utility/AreaRules")
local AdminConfig = require("../src/shared/Config/AdminConfig")
local DayClock = require("../src/shared/Utility/DayClock")

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
expectEqual(GameMath.incrementalUpgradeCost(75, 1.1, 1.55, 0, 1e15), 75, "long-form initial cost")
expectEqual(
	GameMath.incrementalUpgradeCost(75, 1.1, 1.55, 100, 1e15) > 100000,
	true,
	"long-form level 100 cost"
)
expectNear(
	GameMath.incrementalUpgradeEffect(18, 0.055, 100, "Diminishing", 1, 60),
	59.828,
	0.01,
	"range soft cap"
)
expectNear(
	GameMath.incrementalUpgradeEffect(1, 0.055, 100, "Reduction", 0.82, 0.18),
	0.216,
	0.01,
	"respawn reduction curve"
)
expectEqual(GameMath.upgradeMaximumLevel(8, 4, 0), 8, "starting prestige cap")
expectEqual(GameMath.upgradeMaximumLevel(8, 4, 3), 20, "expanded prestige cap")
expectNear(
	GameMath.petMoneyMultiplier(
		{ "TinPup", "TinPup", "GearFox" },
		{ TinPup = 2, GearFox = 1 },
		{ TinPup = { MoneyMultiplier = 1.08 }, GearFox = { MoneyMultiplier = 1.5 } }
	),
	1.66,
	1e-6,
	"additive duplicate pet bonuses"
)

expectEqual(GameMath.scrapValue(100, 15, 3.4, 1e12), 5100, "scrap multipliers")
expectEqual(GameMath.scrapValue(-1, 15, 3.4, 1e12), 0, "negative scrap value")
expectEqual(GameMath.canStore(14, 20, 6), true, "exact capacity")
expectEqual(GameMath.canStore(15, 20, 6), false, "over capacity")
expectEqual(GameMath.canStore(0, 20, 0 / 0), false, "invalid scrap weight")

expectEqual(GameMath.prestigeGearReward(749999, 750000, 100), 0, "prestige below requirement")
expectEqual(GameMath.prestigeGearReward(750000, 750000, 100), 1, "first prestige reward")
expectEqual(GameMath.prestigeGearReward(1000000000, 750000, 100), 100, "prestige reward cap")
expectNear(GameMath.gearValueMultiplier(4, 0.55, 1000000), 2.423, 0.01, "gear multiplier")
expectNear(
	GameMath.prestigeRequirement(25000000, 2.2, 3, 1e15),
	266200000,
	1,
	"scaled prestige requirement"
)
expectEqual(
	GameMath.scaledPrestigeGearReward(25000000, 25000000, 0, 10000),
	1,
	"scaled first prestige reward"
)

local limiter = RateLimiter.new(2, 5)
expectEqual(limiter:Allow("player", 0), true, "rate limit first request")
expectEqual(limiter:Allow("player", 1), true, "rate limit second request")
expectEqual(limiter:Allow("player", 2), false, "rate limit rejection")
expectEqual(limiter:Allow("player", 5), true, "rate limit window reset")

local defaultData = PlayerDataSchema.createDefault(1000)
expectEqual(defaultData.SchemaVersion, 14, "default schema version")
expectEqual(defaultData.ActivePlotTheme, "FrontYard", "default plot theme")
expectEqual(defaultData.PetSlotUpgradeLevel, 0, "default pet slot upgrade")
expectEqual(#defaultData.EquippedPets, 0, "default equipped pets")
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
expectEqual(migrated.SchemaVersion, 14, "migrated schema version")
expectEqual(migrated.ActivePlotTheme, "FrontYard", "migrated plot theme defaults to the scrapyard")
expectEqual(migrated.Money, 125, "migrated money")
expectEqual(migrated.UpgradeLevels.MagnetStrength, 3, "migrated upgrade")
expectEqual(migrated.UpgradeLevels.MagnetRange, 0, "repaired missing upgrade")
expectEqual(migrated.UnlockedAreas.WorkshopYard, true, "migrated area")
expectEqual(migrated.DiscoveredScrap.MetalCan.HighestVariant, "Epic", "migrated discovery")
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
expectEqual(repaired.UpgradeLevels.StorageCapacity, 999, "infinite upgrade level preserved")
expectEqual(repaired.UnlockedAreas.FrontYard, true, "starting area invariant")
expectEqual(repaired.DiscoveredScrap.Tire.HighestVariant, "Normal", "variant repair")
expectEqual(repaired.PlotStage, 1, "plot stage repair")
expectEqual(repaired.UnlockedMachines.Crusher, true, "crusher invariant")

local invalidRootOk = PlayerDataSchema.validate("corrupt", 2000)
expectEqual(invalidRootOk, false, "corrupt root rejection")

--[[
	Version 11 renamed the six Junkyard pets to match their authored models. A save
	written before that must carry its owned counts and equipped slots across, not
	quietly lose them.
]]
local renamedOk, renamed = PlayerDataSchema.validate({
	SchemaVersion = 10,
	-- Pup is already present, so the merge has to add rather than overwrite.
	OwnedPets = { TinPup = 3, GearFox = 1, Pup = 2, TrashTitan = 1 },
	EquippedPets = { "TrashTitan" },
}, 1000)
expectEqual(renamedOk, true, "pet rename migration")
expectEqual(renamed.OwnedPets.Pup, 5, "renamed pet counts merge with existing")
expectEqual(renamed.OwnedPets.PastelAngel, 1, "renamed pet carried across")
expectEqual(renamed.OwnedPets.MythicAutumnDragon, 1, "renamed secret carried across")
expectEqual(renamed.OwnedPets.TinPup, nil, "old pet id dropped")
expectEqual(renamed.EquippedPets[1], "MythicAutumnDragon", "renamed equipped pet")

--[[
	Egg/pet invariants (six pets per egg, weights summing to RollTotal, a Secret in
	the sixth slot) are asserted in Studio instead: `PetConfig` reaches for `script`,
	which Lune has no equivalent for. See `docs/STUDIO_SETUP.md`.
]]

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

--------------------------------------------------------------------------------
-- Return-to-play systems
--------------------------------------------------------------------------------

-- Day numbers, not timestamps: two claims either side of midnight must be different days.
expectEqual(DayClock.dayNumber(0), 0, "day number epoch")
expectEqual(DayClock.dayNumber(86399), 0, "day number just before rollover")
expectEqual(DayClock.dayNumber(86400), 1, "day number after rollover")
expectEqual(DayClock.secondsUntilNextDay(86400 - 10), 10, "seconds until next day")

--[[
	The streak rules, which ARE the daily reward system. Every case below is a bug that would
	otherwise reach a player: claiming twice, losing a streak unfairly, or keeping one forever.
]]
local sameDayStreak, sameDayAllowed = DayClock.advanceStreak(5, 100, 100, 1)
expectEqual(sameDayAllowed, false, "cannot claim twice in one day")
expectEqual(sameDayStreak, 5, "streak untouched by a rejected claim")

local firstStreak, firstAllowed = DayClock.advanceStreak(0, 0, 100, 1)
expectEqual(firstAllowed, true, "first ever claim allowed")
expectEqual(firstStreak, 1, "first claim starts the streak at one")

local nextDayStreak, nextDayAllowed = DayClock.advanceStreak(3, 100, 101, 1)
expectEqual(nextDayAllowed, true, "consecutive day allowed")
expectEqual(nextDayStreak, 4, "consecutive day extends the streak")

local graceStreak, graceAllowed = DayClock.advanceStreak(3, 100, 102, 1)
expectEqual(graceAllowed, true, "one missed day is forgiven")
expectEqual(graceStreak, 4, "grace day keeps the streak")

local brokenStreak, brokenAllowed = DayClock.advanceStreak(30, 100, 104, 1)
expectEqual(brokenAllowed, true, "claim allowed after breaking the streak")
expectEqual(brokenStreak, 1, "streak resets past the grace window")

--[[
	Schema bounds on the reward fields. These are all "free value on a timer", which makes an
	unbounded one a direct exploit: an edited `SpinsAvailable` would be unlimited jackpots.
]]
expectEqual(defaultData.DailyStreak, 0, "default daily streak")
expectEqual(defaultData.DailyCalendarDay, 1, "default calendar day")
expectEqual(defaultData.SpinsAvailable, 0, "default spins")
expectEqual(defaultData.TutorialStep, 0, "default tutorial step")
expectEqual(defaultData.TutorialComplete, false, "default tutorial incomplete")
expectEqual(defaultData.FriendBoostCount, 0, "default friend count")

local rewardOk, rewardClean = PlayerDataSchema.validate({
	SchemaVersion = 14,
	DailyStreak = 1e9,
	DailyCalendarDay = 99,
	SpinsAvailable = 9999,
	PlaytimeSecondsToday = -50,
	PlaytimeClaimed = { ["2"] = true, ["77"] = true, ["3"] = "nope" },
	TutorialStep = 500,
	FriendBoostCount = 50,
}, 2000)
expectEqual(rewardOk, true, "reward field sanitisation")
expectEqual(rewardClean.DailyStreak, 3650, "daily streak clamped")
expectEqual(rewardClean.DailyCalendarDay, 7, "calendar day clamped to the calendar length")
expectEqual(rewardClean.SpinsAvailable, 25, "spins clamped to the stored maximum")
expectEqual(rewardClean.PlaytimeSecondsToday, 0, "negative playtime floored")
expectEqual(rewardClean.PlaytimeClaimed[2], true, "string milestone key accepted")
expectEqual(rewardClean.PlaytimeClaimed[77], nil, "out of range milestone dropped")
expectEqual(rewardClean.PlaytimeClaimed[3], nil, "non-true milestone value dropped")
expectEqual(rewardClean.TutorialStep, 5, "tutorial step clamped past the last step")
-- Transient: it describes the server, not the player, so it never survives a load.
expectEqual(rewardClean.FriendBoostCount, 0, "friend count reset on load")

--[[
	Migration from 13. Existing players start with no streak on purpose: a streak they never earned
	would hand them the day-7 multiplier for free.
]]
local thirteenOk, thirteen = PlayerDataSchema.validate({
	SchemaVersion = 13,
	Money = 900,
	ActivePlotTheme = "WorkshopYard",
}, 3000)
expectEqual(thirteenOk, true, "version thirteen migration")
expectEqual(thirteen.SchemaVersion, 14, "migrated to fourteen")
expectEqual(thirteen.DailyStreak, 0, "migrated player has no streak")
expectEqual(thirteen.DailyCalendarDay, 1, "migrated player starts on calendar day one")
expectEqual(thirteen.TutorialStep, 0, "migrated player tutorial not started")
expectEqual(thirteen.ActivePlotTheme, "WorkshopYard", "migration preserves the plot theme")

print(`Scrapyard foundation and data tests passed: {passed}`)
