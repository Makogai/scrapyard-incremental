--!strict

local GameMath = require("../src/shared/Utility/GameMath")
local RateLimiter = require("../src/shared/Utility/RateLimiter")
local PlayerDataSchema = require("../src/shared/Utility/PlayerDataSchema")
local CollectionRules = require("../src/shared/Utility/CollectionRules")
local PlotRules = require("../src/shared/Utility/PlotRules")
local AreaRules = require("../src/shared/Utility/AreaRules")
local AdminConfig = require("../src/shared/Config/AdminConfig")
local DayClock = require("../src/shared/Utility/DayClock")
local EventConfig = require("../src/shared/Config/EventConfig")
local TitleConfig = require("../src/shared/Config/TitleConfig")
local AchievementConfig = require("../src/shared/Config/AchievementConfig")
local AchievementRules = require("../src/shared/Utility/AchievementRules")
local PrestigeConfig = require("../src/shared/Config/PrestigeConfig")
local SocialConfig = require("../src/shared/Config/SocialConfig")
local InboxConfig = require("../src/shared/Config/InboxConfig")
local PlotSkinConfig = require("../src/shared/Config/PlotSkinConfig")

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
--[[
	The rebirth bonus replaced the gears->value curve. Linear and unbounded by gears, so a rebirth pays
	once. Asserted against `PrestigeConfig.ValuePerPrestige` as well as literals, so retuning the config
	cannot silently leave the readouts quoting an old number.
]]
expectNear(GameMath.prestigeValueMultiplier(0, 0.25), 1.0, 0.0001, "no rebirth is no bonus")
expectNear(GameMath.prestigeValueMultiplier(1, 0.25), 1.25, 0.0001, "first rebirth bonus")
expectNear(GameMath.prestigeValueMultiplier(4, 0.25), 2.0, 0.0001, "fourth rebirth bonus")
expectNear(GameMath.prestigeValueMultiplier(-3, 0.25), 1.0, 0.0001, "negative rebirth guard")
expectNear(
	GameMath.prestigeValueMultiplier(2, PrestigeConfig.ValuePerPrestige),
	1 + 2 * PrestigeConfig.ValuePerPrestige,
	0.0001,
	"rebirth bonus follows config"
)
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
expectEqual(defaultData.SchemaVersion, 18, "default schema version")

--[[
	PLOT SKINS. `PlayerDataSchema` requires nothing -- the Lune runner cannot load a config built out of
	Roblox datatypes -- so the pass id is a literal in there. This is what keeps that literal honest.
]]
expectEqual(defaultData.ActivePlotSkin, "", "no skin worn by default")
expectEqual(PlotSkinConfig.Pass, "LavaSkin", "skin pass id matches the schema literal")
expectEqual(PlotSkinConfig.forArea("FrontYard") ~= nil, true, "front yard has a skin model")
expectEqual(PlotSkinConfig.forArea("Nowhere"), nil, "unknown area has no skin")
expectEqual(PlotSkinConfig.owned({ LavaSkin = true }), true, "skin owned")
expectEqual(PlotSkinConfig.owned({}), false, "skin not owned")
expectEqual(PlotSkinConfig.activeSkinFor("FrontYard", {}), nil, "unowned skin is not active")
expectEqual(
	PlotSkinConfig.activeSkinFor("FrontYard", { LavaSkin = true }) ~= nil,
	true,
	"owned skin is active on an authored area"
)
expectEqual(
	PlotSkinConfig.activeSkinFor("Nowhere", { LavaSkin = true }),
	nil,
	"owned skin is not active on an unauthored area"
)

--- A chosen skin survives a round trip, and anything else is cleared rather than trusted.
local skinOk, skinClean = PlayerDataSchema.validate({ ActivePlotSkin = "LavaSkin" }, 1000)
expectEqual(skinOk, true, "profile wearing a skin validates")
expectEqual(skinClean and skinClean.ActivePlotSkin, "LavaSkin", "chosen skin survives validation")
local _, bogusSkin = PlayerDataSchema.validate({ ActivePlotSkin = "NotAPass" }, 1000)
expectEqual(bogusSkin and bogusSkin.ActivePlotSkin, "", "unknown skin id is cleared")
local _, numericSkin = PlayerDataSchema.validate({ ActivePlotSkin = 7 }, 1000)
expectEqual(numericSkin and numericSkin.ActivePlotSkin, "", "non-string skin id is cleared")
--[[
	THE MAILBOX STARTS EMPTY AND SURVIVES A ROUND TRIP.

	Asserted because the inbox is the one place a reward can sit UNPAID in a save: a sanitiser that dropped
	messages would silently delete things players are owed, and a sanitiser that let anything through would
	let a tampered save mail itself money.
]]
expectEqual(#defaultData.Inbox, 0, "a new profile has no mail")
expectEqual(
	next(defaultData.SocialClaims) == nil,
	true,
	"a new profile has claimed no social rewards"
)

local mailProfile = PlayerDataSchema.createDefault(1000)
mailProfile.Inbox = {
	{
		Id = "keep",
		Kind = "Staff",
		Title = "A gift",
		Body = "Enjoy",
		FromName = "Makogai",
		FromUserId = 7,
		SentAt = 900,
		Rewards = { Money = 5000, Spins = 2 },
		Claimed = false,
	},
	--- Malformed: no Id. Dropped rather than repaired.
	{ Kind = "Staff", Title = "Broken", Body = "no id" },
	--- A tampered reward, clamped by the same bounds the rest of the save uses.
	{
		Id = "greedy",
		Kind = "Staff",
		Title = "Too much",
		Body = "nice try",
		FromName = "x",
		FromUserId = 1,
		SentAt = 900,
		Rewards = { Money = -5, Spins = 99999 },
		Claimed = false,
	},
}
mailProfile.SocialClaims = { Like = true, Community = false }

local mailOk, mailClean = PlayerDataSchema.validate(mailProfile, 1000)
expectEqual(mailOk, true, "a save with mail validates")
expectEqual(#mailClean.Inbox, 2, "malformed mail is dropped")
expectEqual(mailClean.Inbox[1].Id, "keep", "well-formed mail survives")
expectEqual(mailClean.Inbox[1].Rewards.Money, 5000, "mail rewards survive")
expectEqual(mailClean.Inbox[2].Rewards.Money, 0, "a negative mail reward is floored at zero")
expectEqual(mailClean.Inbox[2].Rewards.Spins, 1000, "an absurd mail reward is clamped")
expectEqual(mailClean.SocialClaims.Like, true, "a taken social reward survives")

--[[
	The invite ladder only offers rungs the friend count has actually earned, and never twice.
]]
expectEqual(#SocialConfig.claimableInvites(0, {}), 0, "no friends, no invite rewards")
expectEqual(#SocialConfig.claimableInvites(1, {}), 1, "one friend earns the first rung")
expectEqual(#SocialConfig.claimableInvites(2, {}), 2, "two friends earn two rungs")
expectEqual(
	#SocialConfig.claimableInvites(2, { Invite1 = true }),
	1,
	"a claimed rung is not offered again"
)
expectEqual(#SocialConfig.claimableInvites(99, {}), 4, "every rung is reachable")
expectEqual(SocialConfig.canClaim("Like", {}), true, "an unclaimed social reward is claimable")
expectEqual(SocialConfig.canClaim("Like", { Like = true }), false, "a claimed one is not")
expectEqual(SocialConfig.canClaim("Nonsense", {}), false, "an unknown reward is never claimable")

--[[
	NO SOCIAL REWARD MAY PAY GEARS -- same rule as achievements. Gears are rebirth currency.
]]
for _, rewardId in SocialConfig.RewardOrder do
	expectEqual(
		SocialConfig.Rewards[rewardId].Rewards.Gears == nil,
		true,
		`social reward {rewardId} must not pay gears`
	)
end
for index, milestone in SocialConfig.Invite.Milestones do
	expectEqual(milestone.Rewards.Gears == nil, true, `invite milestone {index} must not pay gears`)
end

--- The unclaimed count drives the topbar pip, so it has to match the list it describes.
expectEqual(InboxConfig.unclaimedCount(nil), 0, "no mailbox is no unread mail")
expectEqual(InboxConfig.unclaimedCount({}), 0, "an empty mailbox is no unread mail")
expectEqual(
	InboxConfig.unclaimedCount({ { Claimed = false }, { Claimed = true }, { Claimed = false } }),
	2,
	"only unclaimed mail is counted"
)
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
expectEqual(migrated.SchemaVersion, 18, "migrated schema version")
--- An ancient save arrives with an empty mailbox rather than a nil one, so the screen never sees nil.
expectEqual(#migrated.Inbox, 0, "a migrated save has an empty mailbox")
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
expectEqual(CollectionRules.sellAward(20, 1.5, 1000), 30, "sell award")
expectEqual(CollectionRules.sellAward(0, 10, 1000), 0, "empty sale")
expectEqual(CollectionRules.sellAward(500, 4, 1000), 1000, "sell award clamped to maximum")
--[[
	NO ACHIEVEMENT MAY PAY GEARS. Gears are rebirth currency, and the gear curve that used to make them an
	income multiplier is gone -- but the reward shape still carries the field for codes and the admin panel,
	so nothing but a test stops one being added back. "Hold $1,000" once paid 5 gears, which was a permanent
	x2.67 on all income inside the first minute of play.
]]
for _, definition in ipairs(AchievementConfig.Definitions) do
	expectEqual(
		definition.Reward.Gears == nil,
		true,
		`achievement {definition.Id} must not pay gears`
	)
end
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

--[[
	AREA PRICES RISE WITH REBIRTHS, because unlocks reset on prestige and a Graveyard that still cost
	$450,000 on your tenth run would be a formality you walk past.

	Asserted at several rebirth counts rather than just one: the bug this catches is an off-by-one on the
	exponent, which looks correct at rebirth 0 and is wrong everywhere else.
]]
expectEqual(
	AreaRules.unlockPrice(450000, 0),
	450000,
	"area price at rebirth zero is the base price"
)
expectEqual(AreaRules.unlockPrice(450000, 1), 652500, "area price after one rebirth")
expectEqual(AreaRules.unlockPrice(75000, 2), 157687, "workshop price after two rebirths")
--- 2,884,380 rather than the design doc's rounded "$2.88M" -- assert what the formula does, not the table.
expectEqual(AreaRules.unlockPrice(450000, 5), 2884380, "graveyard price after five rebirths")
--- Negative or malformed input must not produce a negative price the player could be paid to unlock.
expectEqual(AreaRules.unlockPrice(450000, -3), 450000, "negative rebirth count is floored to zero")
expectEqual(AreaRules.unlockPrice(-1, 2), 0, "a negative base price yields zero")
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
expectEqual(thirteen.SchemaVersion, 18, "migrated to eighteen from thirteen")
expectEqual(thirteen.DailyStreak, 0, "migrated player has no streak")
expectEqual(thirteen.DailyCalendarDay, 1, "migrated player starts on calendar day one")
expectEqual(thirteen.TutorialStep, 0, "migrated player tutorial not started")
expectEqual(thirteen.ActivePlotTheme, "WorkshopYard", "migration preserves the plot theme")

--[[
	The event schedule.

	Worth testing hard and cheap to test at all, because it is pure arithmetic over UTC time and every
	way it can be wrong is invisible in game until the wrong week: an off-by-one weekday, a window that
	never opens, two events live at once, or a window that fails to wrap past Saturday midnight.

	Reference instants are built with `os.time` against an explicit UTC table so the expectations do
	not depend on where the test runs. 2024-01-07 was a Sunday, which anchors the whole week.
]]
local function utc(day: number, hour: number, minute: number?): number
	--- 2024-01-07 is a Sunday, so `day` 7..13 walks Sunday through Saturday.
	return os.time({
		year = 2024,
		month = 1,
		day = day,
		hour = hour,
		min = minute or 0,
		sec = 0,
	} :: any)
end

local sundayNoon = utc(7, 12)
local tuesdayEvening = utc(9, 18, 30)
local wednesdayEvening = utc(10, 19)
local fridayNoon = utc(12, 12)
local saturdayOneAm = utc(13, 1)

--[[
	Saturday 00:00 to Monday 00:00 is Scrap Rush, and the Sunday half of that window is the wrap case:
	the window opens in one week and closes in the next, so a naive comparison misses it entirely.
]]
local sundayEvent = EventConfig.activeAt(sundayNoon)
expectEqual(sundayEvent ~= nil, true, "sunday is inside the weekend window")
expectEqual(if sundayEvent then sundayEvent.Id else "", "ScrapRush", "sunday runs scrap rush")

local saturdayEvent = EventConfig.activeAt(saturdayOneAm)
expectEqual(if saturdayEvent then saturdayEvent.Id else "", "ScrapRush", "saturday runs scrap rush")

expectEqual(EventConfig.activeAt(fridayNoon), nil, "friday has no event")

local tuesdayEvent = EventConfig.activeAt(tuesdayEvening)
expectEqual(if tuesdayEvent then tuesdayEvent.Id else "", "ScrapStorm", "tuesday evening storm")

local wednesdayEvent = EventConfig.activeAt(wednesdayEvening)
expectEqual(if wednesdayEvent then wednesdayEvent.Id else "", "LuckyHour", "wednesday evening luck")

--- Half-open windows: the closing instant belongs to nobody, so events cannot double up on the edge.
expectEqual(EventConfig.activeAt(utc(9, 20)), nil, "storm window is half-open at its end")
expectEqual(
	if EventConfig.activeAt(utc(9, 18)) then EventConfig.activeAt(utc(9, 18)).Id else "",
	"ScrapStorm",
	"storm window includes its opening instant"
)

--- Remaining time, so the banner's countdown is the real one.
local _, stormRemaining = EventConfig.activeAt(utc(9, 19))
expectEqual(stormRemaining, 3600, "one hour left of a two hour window")
local _, rushRemaining = EventConfig.activeAt(utc(13, 0))
expectEqual(rushRemaining, 48 * 3600, "full weekend remaining at its start")

--- The multiplier the gameplay actually reads.
expectEqual(EventConfig.multiplierAt("ScrapValue", sundayNoon), 2, "weekend doubles scrap value")
expectEqual(EventConfig.multiplierAt("Luck", sundayNoon), 1, "weekend does not touch luck")
expectEqual(EventConfig.multiplierAt("ScrapValue", fridayNoon), 1, "no event means no multiplier")
expectEqual(EventConfig.multiplierAt("Luck", wednesdayEvening), 2, "lucky hour doubles luck")

--[[
	What is next, which is what the banner shows when nothing is live.

	Friday noon used to look twelve hours ahead to Scrap Rush at Saturday midnight. THE PIT now opens at
	Friday 18:00, so the nearest window is six hours out -- which is the assertion doing its job: it
	catches a new event landing between "now" and whatever the banner used to promise.
]]
local nextDefinition, nextWait = EventConfig.nextAt(fridayNoon)
expectEqual(
	if nextDefinition then nextDefinition.Id else "",
	"ScrapPit",
	"friday noon looks ahead to the evening's arena"
)
expectEqual(nextWait, 6 * 3600, "six hours from friday noon to the pit")

--- The arena flag, since `ArenaService` keys the whole feature off it.
expectEqual(EventConfig.ById.ScrapPit.Arena, true, "the pit is flagged as an arena event")
expectEqual(EventConfig.ById.ScrapRush.Arena, nil, "an ordinary event is not")

--[[
	NO TWO WINDOWS MAY OVERLAP, swept at hourly resolution across a whole week.

	Deliberately does NOT use `activeAt`, which returns the first match and so could never report an
	overlap -- that version of this test passed while proving nothing. Containment is recomputed here
	from the definitions, which makes it an independent check of the config rather than a restatement
	of the code under test.

	One event at a time is the assumption both the stacked multipliers and the single banner rest on,
	and the only way to keep it true as events are added is to check every hour rather than the few
	instants I happened to think of.
]]
local WEEK_SECONDS = 24 * 3600 * 7
local function containsHour(definition: any, weekSecond: number): boolean
	local start = (definition.StartDay - 1) * 24 * 3600 + definition.StartHour * 3600
	local duration = definition.DurationHours * 3600
	for _, position in { weekSecond, weekSecond + WEEK_SECONDS } do
		if position >= start and position < start + duration then
			return true
		end
	end
	return false
end

local weekStart = utc(7, 0)
for hour = 0, 24 * 7 - 1 do
	local weekSecond = hour * 3600
	local live = {}
	for _, definition in ipairs(EventConfig.Events) do
		if containsHour(definition, weekSecond) then
			table.insert(live, definition.Id)
		end
	end
	if #live > 1 then
		error(`overlapping events at hour {hour}: {table.concat(live, ", ")}`, 2)
	end
	--- And the sweep must agree with `activeAt`, which is the function the game actually calls.
	local active = EventConfig.activeAt(weekStart + weekSecond)
	local expected = if #live == 1 then live[1] else nil
	if (if active then active.Id else nil) ~= expected then
		error(`activeAt disagrees with the schedule at hour {hour}`, 2)
	end
end
passed += 1

--[[
	And every event must actually open at some point in the week. A window with a bad weekday or a zero
	duration would silently never fire, which is the failure nobody notices until someone asks why the
	event never happened.
]]
for _, definition in ipairs(EventConfig.Events) do
	local seen = false
	for hour = 0, 24 * 7 - 1 do
		local candidate = EventConfig.activeAt(weekStart + hour * 3600)
		if candidate and candidate.Id == definition.Id then
			seen = true
			break
		end
	end
	expectEqual(seen, true, `{definition.Id} opens at some point in the week`)
end

--[[
	Titles and achievements.

	The two configs reference each other by id -- a title names the achievement that awards it, an
	achievement names the title it grants -- and nothing at runtime would complain if one side were
	misspelled: the player would simply never receive a title that appears in the list. So the agreement
	is asserted in BOTH directions here, which is the only place it can be checked cheaply.
]]
for _, title in ipairs(TitleConfig.Titles) do
	--[[
		EARNED OR STAFF, never neither.

		A title with no achievement and no staff flag is unreachable: it would sit in the list forever with
		nothing that grants it, and nothing at runtime would complain. Staff titles are the one legitimate
		exception -- they come from `AdminConfig`, not from play.
	]]
	if title.Staff == true then
		expectEqual(title.Source, nil, `staff title {title.Id} names no achievement`)
	else
		expectEqual(
			AchievementConfig.ById[title.Source] ~= nil,
			true,
			`title {title.Id} names a real achievement`
		)
	end
	expectEqual(
		TitleConfig.rarityRank(title.Rarity) > 0,
		true,
		`title {title.Id} has a known rarity`
	)
	--- Long enough for the decorated staff titles, short enough to sit over a head.
	expectEqual(#title.Text <= 24, true, `title {title.Id} is short enough to wear`)
	--- Whatever the accent resolves to must be a name the UI can turn into a colour.
	local accent = TitleConfig.accent(title)
	expectEqual(
		typeof(accent) == "string" and #accent > 0,
		true,
		`title {title.Id} resolves an accent`
	)
end

--- Every title is awarded by exactly one achievement, so none is unreachable or double-sourced.
local awardedBy: { [string]: string } = {}
for _, definition in ipairs(AchievementConfig.Definitions) do
	local titleId = definition.Reward.TitleId
	if titleId ~= nil then
		expectEqual(
			TitleConfig.ById[titleId] ~= nil,
			true,
			`achievement {definition.Id} grants a real title`
		)
		expectEqual(awardedBy[titleId], nil, `title {titleId} is granted by only one achievement`)
		awardedBy[titleId] = definition.Id
	end
end
for _, title in ipairs(TitleConfig.Titles) do
	if title.Staff == true then
		--- Nothing in the achievement list may hand out a staff title.
		expectEqual(awardedBy[title.Id], nil, `staff title {title.Id} is not an achievement reward`)
	else
		expectEqual(awardedBy[title.Id], title.Source, `title {title.Id} agrees with its source`)
	end
end

--[[
	The staff titles exist and are spelled the way the granting code expects.

	`PlayerStateService.grantStaffTitles` looks them up by the literal ids "Admin" and "Owner". Renaming
	one in the config without renaming it there would silently grant nothing -- the kind of break that
	only shows up when an admin joins and has no title.
]]
for _, staffId in { "Admin", "Owner" } do
	local definition = TitleConfig.ById[staffId]
	expectEqual(definition ~= nil, true, `staff title {staffId} exists`)
	expectEqual(definition.Staff, true, `staff title {staffId} is flagged staff`)
end

--[[
	Every achievement must name a metric `AchievementRules` can actually read. A typo here is an
	achievement that can never complete, and nothing in game would ever say so.
]]
local knownMetrics: { [string]: boolean } = {}
for _, name in ipairs(AchievementRules.metricNames()) do
	knownMetrics[name] = true
end
for _, definition in ipairs(AchievementConfig.Definitions) do
	expectEqual(
		knownMetrics[definition.Metric],
		true,
		`achievement {definition.Id} uses a known metric`
	)
	expectEqual(definition.Threshold >= 1, true, `achievement {definition.Id} has a real threshold`)
	expectEqual(
		table.find(AchievementConfig.Tracks, definition.Track) ~= nil,
		true,
		`achievement {definition.Id} is on a known track`
	)
end

--- Progress reading, against a hand-built save rather than a running game.
local sample = {
	TotalScrapCollected = 250,
	Money = 4_000,
	PrestigeCount = 0,
	DailyStreak = 3,
	UpgradeLevels = { MagnetStrength = 12, StorageCapacity = 8 },
	OwnedPets = { Pup = 2, Zebra = 1 },
	EggOpenCounts = { JunkyardEgg = 4 },
	UnlockedAreas = { FrontYard = true, WorkshopYard = true },
	OwnedMagnets = { MagnetBasic = true, MagnetIron = true },
	--[[
		Records carry `Discovered = true` because that is what counts now.

		This fixture used to be three EMPTY tables, which passed when `ScrapDiscovered` counted keys. That
		is the bug: the schema pre-seeds a record for every scrap with `Discovered = false`, so counting keys
		meant a fresh profile had "discovered" all of them. The fixture was encoding the defect.

		The fourth entry is deliberately undiscovered, so this asserts the metric distinguishes them rather
		than just counting a smaller table.
	]]
	DiscoveredScrap = {
		Can = { Discovered = true },
		Tire = { Discovered = true },
		LooseBolt = { Discovered = true },
		ScrapCar = { Discovered = false },
	},
}

expectEqual(AchievementRules.metric(sample, "UpgradeLevelTotal"), 20, "upgrade levels sum")
expectEqual(AchievementRules.metric(sample, "PetsOwned"), 3, "pets owned sum")
expectEqual(AchievementRules.metric(sample, "EggsOpened"), 4, "eggs opened sum")
expectEqual(AchievementRules.metric(sample, "AreasUnlocked"), 2, "areas unlocked count")
expectEqual(AchievementRules.metric(sample, "MagnetsOwned"), 2, "magnets owned count")
expectEqual(AchievementRules.metric(sample, "ScrapDiscovered"), 3, "scrap discovered count")
expectEqual(AchievementRules.metric(sample, "NotAMetric"), nil, "unknown metric reads nil")

--- Missing fields are zero, not an error: this runs against saves from older schema versions.
expectEqual(AchievementRules.metric({}, "PetsOwned"), 0, "absent field reads zero")

local hundredValue, hundredThreshold, hundredDone =
	AchievementRules.progress(sample, AchievementConfig.ById.ScrapHundred)
expectEqual(hundredDone, true, "250 scrap clears the 100 threshold")
expectEqual(hundredValue, hundredThreshold, "progress is clamped to the threshold")

local millionValue, _, millionDone =
	AchievementRules.progress(sample, AchievementConfig.ById.ScrapMillion)
expectEqual(millionDone, false, "250 scrap does not clear a million")
expectEqual(millionValue, 250, "partial progress reports the real value")

--[[
	The paid-out set is what stops a reward repeating. `newlyEarned` must return an achievement exactly
	once: the first call sees it, and once recorded the second call must not.
]]
local earned = AchievementRules.newlyEarned(sample, AchievementConfig.Definitions, {})
expectEqual(table.find(earned, "FirstSteps") ~= nil, true, "first steps is earned")
expectEqual(table.find(earned, "ScrapMillion"), nil, "unearned achievements are not returned")

local alreadyPaid = {}
for _, id in ipairs(earned) do
	alreadyPaid[id] = true
end
expectEqual(
	#AchievementRules.newlyEarned(sample, AchievementConfig.Definitions, alreadyPaid),
	0,
	"nothing is earned twice"
)
expectEqual(
	AchievementRules.unlockedCount(AchievementConfig.Definitions, alreadyPaid),
	#earned,
	"unlocked count matches what was paid"
)

--[[
	A BRAND-NEW PROFILE MUST EARN NOTHING. This is the invariant, and it was broken.

	`createDefault` pre-creates a `DiscoveredScrap` record for every scrap so the index can list
	undiscovered types without special-casing nil, and `ScrapDiscovered` counted KEYS -- so a fresh save
	reported 18 discovered against a threshold of 17, instantly completing `IndexComplete` and paying
	$1,500,000, 200 gears and the Archivist title. Reset Profile appeared to hand out a fortune.

	Asserted over EVERY definition rather than that one metric, because the same mistake is available to any
	future achievement that reads a pre-seeded table.
]]
local blankProfile = PlayerDataSchema.createDefault(1000)
expectEqual(
	#AchievementRules.newlyEarned(blankProfile, AchievementConfig.Definitions, {}),
	0,
	"a brand new profile earns no achievements"
)
expectEqual(
	AchievementRules.metric(blankProfile, "ScrapDiscovered"),
	0,
	"a brand new profile has discovered no scrap"
)

--- Tag formatting, which two different surfaces render and must not disagree about.
expectEqual(TitleConfig.tag("Baron"), "[SCRAP BARON]", "title tag formatting")
expectEqual(TitleConfig.tag("NotATitle"), "", "unknown title has no tag")
expectEqual(TitleConfig.tag(nil), "", "no title has no tag")

--- Schema round trip for the new fields.
local titleOk, titleData = PlayerDataSchema.validate({
	SchemaVersion = 15,
	UnlockedTitles = { Baron = true, NotReal = true },
	EquippedTitle = "Baron",
	UnlockedAchievements = { ScrapMillion = true },
}, 4000)
expectEqual(titleOk, true, "version fifteen validates")
expectEqual(titleData.UnlockedTitles.Baron, true, "a held title survives")
expectEqual(titleData.EquippedTitle, "Baron", "a held title can be worn")
expectEqual(titleData.UnlockedAchievements.ScrapMillion, true, "a paid achievement survives")

--- A title the player does not hold cannot be worn, however the save was edited.
local cheatOk, cheatData = PlayerDataSchema.validate({
	SchemaVersion = 15,
	UnlockedTitles = {},
	EquippedTitle = "Legend",
}, 4000)
expectEqual(cheatOk, true, "unheld title validates")
expectEqual(cheatData.EquippedTitle, "", "an unheld title is not worn")

--- Migration from 14 keeps everything and adds the new fields empty.
local fourteenOk, fourteen = PlayerDataSchema.validate({
	SchemaVersion = 14,
	Money = 5_000,
	DailyStreak = 4,
}, 4000)
expectEqual(fourteenOk, true, "version fourteen migration")
expectEqual(fourteen.SchemaVersion, 18, "migrated to eighteen")
expectEqual(fourteen.DailyStreak, 4, "migration preserves the streak")
expectEqual(fourteen.EquippedTitle, "", "migrated player wears no title")
expectEqual(next(fourteen.UnlockedTitles), nil, "migrated player holds no titles")

--[[
	Secret tickets. The most valuable forgeable number in the save, so the bound matters more than the
	default: an edited profile claiming a million guaranteed Secrets must come back clamped.
]]
local ticketOk, ticketData = PlayerDataSchema.validate({
	SchemaVersion = 16,
	SecretTickets = 1e9,
}, 5000)
expectEqual(ticketOk, true, "secret tickets validate")
expectEqual(ticketData.SecretTickets, 100, "secret tickets are clamped")

local negativeOk, negativeData = PlayerDataSchema.validate({
	SchemaVersion = 16,
	SecretTickets = -12,
}, 5000)
expectEqual(negativeOk, true, "negative tickets validate")
expectEqual(negativeData.SecretTickets, 0, "negative tickets floor at zero")

--- A save written before the field existed reads as none, not nil.
local fifteenOk, fifteen = PlayerDataSchema.validate({
	SchemaVersion = 15,
	Money = 400,
}, 5000)
expectEqual(fifteenOk, true, "version fifteen migration")
expectEqual(fifteen.SchemaVersion, 18, "migrated fifteen to eighteen")
expectEqual(fifteen.SecretTickets, 0, "migrated player holds no tickets")

--[[
	THE SNAPSHOT CONTRACT: every field the client reads is a field the server actually sends.

	A SOURCE-LEVEL CHECK, and the only kind available for this. `Atoms` and `PlayerStateService` cannot be
	required here -- one needs Charm, the other needs DataStores -- so this reads them as text: every
	`snapshot.Something` the client pulls must appear as a key in `publicSnapshot`'s return table.

	It exists because that gap is silent and expensive. `ActivePlotTheme` and `ActivePlotSkin` were both
	read by the client and sent by nobody, so the plot theme stayed pinned to the Front Yard and the
	inventory's EQUIP button looked broken -- the server swapped the skin, saved it and rebuilt the plot,
	and the card that was pressed never changed. Nothing in stylua, selene, the type checker or a render
	probe can see a missing table key: a nil field is valid Luau that simply does nothing.

	Keys are matched loosely (`Name = `), so this is a canary rather than a proof -- it catches a field
	nobody wired up, which is the failure that actually happens.
]]
local fs = require("@lune/fs")
local atomsSource = fs.readFile("src/shared/UI/State/Atoms.luau")
local stateSource = fs.readFile("src/server/Services/PlayerStateService.luau")
local snapshotStart = string.find(stateSource, "local function publicSnapshot", 1, true)
expectEqual(snapshotStart ~= nil, true, "publicSnapshot found in PlayerStateService")
local returnStart = string.find(stateSource, "return {", snapshotStart, true)
--- The newline is built rather than escaped, so this file stays free of escape noise.
local newline = string.char(10)
local returnEnd = string.find(stateSource, newline .. "end", returnStart, true)
local sentKeys = string.sub(stateSource, returnStart, returnEnd)
local checked = {}
for key in string.gmatch(atomsSource, "snapshot%.([%a_][%w_]*)") do
	if not checked[key] then
		checked[key] = true
		expectEqual(
			string.find(sentKeys, key .. " = ", 1, true) ~= nil,
			true,
			`publicSnapshot sends {key}`
		)
	end
end

print(`Scrapyard foundation and data tests passed: {passed}`)
