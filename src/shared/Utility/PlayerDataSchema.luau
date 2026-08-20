--!strict

local PlayerDataSchema = {}

PlayerDataSchema.CurrentVersion = 18

--[[
	The one cosmetic plot-skin pass, mirroring `PlotSkinConfig.Pass`.

	A LITERAL, like `PET_IDS` and `AREA_IDS` below, and for the same reason: this module requires nothing.
	The Lune test runner loads it directly, and it cannot load a config that uses Roblox datatypes -- and
	`MonetizationConfig` is full of `Color3`. So the id is repeated here and the two are kept in step by
	`tests/run.luau`, which asserts they agree.
]]
local SKIN_PASS = "LavaSkin"

local PET_IDS = {
	"Pup",
	"Zebra",
	"QueenKitty",
	"PastelAngel",
	"AutumnDragon",
	"MythicAutumnDragon",
	"WrenchMouse",
	"SpringFrog",
	"WelderBear",
	"MotorMole",
	"ChromeWolf",
	"CoreDragon",
	"NeonCrab",
	"CircuitOwl",
	"PlasmaPanda",
	"MagnetManta",
	"NovaLion",
	"Singularity",
	"NebulaLeviathan",
	"DemonicGhost",
	"SinisterLord",
}
local EGG_IDS = { "JunkyardEgg", "WorkshopEgg", "QuantumEgg" }
local MAXIMUM_OWNED_PER_PET = 999
local MAXIMUM_PET_SLOT_UPGRADES = 2
local BASE_PET_SLOTS = 1
local PASS_PET_SLOTS = 2

local UPGRADE_MAXIMUMS = {
	MagnetStrength = 1000000,
	MagnetRange = 1000000,
	StorageCapacity = 1000000,
	MovementSpeed = 1000000,
	ScrapValue = 1000000,
	CollectionSpeed = 1000000,
	ScrapFlow = 1000000,
	Rarity = 1000000,
}

local AREA_IDS = { "FrontYard", "WorkshopYard", "VehicleGraveyard" }
local SCRAP_IDS = {
	"MetalCan",
	"LooseBolt",
	"SmallMetalPlate",
	"Tire",
	"BrokenAppliance",
	"EnginePart",
	"CarDoor",
	"ScrapCar",
	"RustyPipe",
	"CrushedBucket",
	"CopperWire",
	"ToolBox",
	"BrakeDisc",
	"Radiator",
	"MotorCoil",
	"ExhaustPipe",
	"Axle",
	"FuelTank",
}
local VARIANT_IDS = { Normal = true, Rare = true, Epic = true, Legendary = true, Nebula = true }

local MAXIMUM_MONEY = 1e15
local MAXIMUM_GEARS = 1000000
local MAXIMUM_STORED_WEIGHT = 1e9
local MAXIMUM_STORED_VALUE = 1e12
local MAXIMUM_COLLECTED = 1e15
--- Mirrors `InboxConfig.MaximumMessages`. Duplicated rather than required: this module stays
--- dependency-free so it can be driven by a plain table under Lune.
local INBOX_MAXIMUM = 40
local MAXIMUM_TIMESTAMP = 32503680000
local MAXIMUM_PLOT_STAGE = 4
local MAXIMUM_CRUSHER_LEVEL = 100

--[[
	Bounds for the return-to-play systems.

	DUPLICATED FROM `RewardsConfig` AND `TutorialConfig` ON PURPOSE. This module requires nothing --
	it is loaded by the Lune test runner, which has no `ReplicatedStorage` -- so every table in
	here (pets, eggs, upgrades, scrap) is a literal that mirrors a config. Keep them in step; the
	test suite asserts the ones that matter.

	These are all "free value on a timer", which makes an unbounded one a direct exploit: an
	uncapped `SpinsAvailable` is unlimited jackpots, an uncapped `DailyStreak` is an uncapped cash
	multiplier.
]]
local MAXIMUM_DAY_NUMBER = 400000 -- ~1095 years of day numbers
local MAXIMUM_DAILY_STREAK = 3650
local DAILY_CALENDAR_LENGTH = 7
local MAXIMUM_PLAYTIME_SECONDS = 86400
local PLAYTIME_MILESTONE_COUNT = 9
local MAXIMUM_STORED_SPINS = 25

--[[
	A ceiling on guaranteed-Secret tickets.

	Bounded like everything else, and low on purpose: an edited save claiming a million of these would be
	a million guaranteed Secrets, which is the single most valuable thing in the game to forge.
]]
local MAXIMUM_SECRET_TICKETS = 100

--- Bounds for config-keyed sets (achievements, titles) the schema cannot validate by name.
local MAXIMUM_ID_LENGTH = 64
local MAXIMUM_ID_SET_ENTRIES = 256
local TUTORIAL_STEP_COUNT = 4

local function finite(value: any): boolean
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

--[[
	An id-keyed set of `true`, bounded in both key length and count.

	For sets whose valid keys live in a config this module cannot require. Anything that is not a
	sensible id mapped to `true` is dropped, and the count cap is what stops an edited save from growing
	without limit -- the reason to sanitise a set like this at all.
]]
local function boundedIdSet(value: any): { [string]: boolean }
	local clean = {}
	if typeof(value) ~= "table" then
		return clean
	end
	local kept = 0
	for id, flag in value do
		if
			typeof(id) == "string"
			and #id > 0
			and #id <= MAXIMUM_ID_LENGTH
			and flag == true
			and kept < MAXIMUM_ID_SET_ENTRIES
		then
			clean[id] = true
			kept += 1
		end
	end
	return clean
end

local function boundedNumber(value: any, fallback: number, minimum: number, maximum: number): number
	if not finite(value) then
		return fallback
	end
	return math.clamp(value, minimum, maximum)
end

local function boundedInteger(
	value: any,
	fallback: number,
	minimum: number,
	maximum: number
): number
	return math.floor(boundedNumber(value, fallback, minimum, maximum))
end

local function boolean(value: any, fallback: boolean): boolean
	if typeof(value) == "boolean" then
		return value
	end
	return fallback
end

local function defaultSettings()
	return {
		ParticlesEnabled = true,
		ScreenEffectsEnabled = true,
		SoundEnabled = true,
		MusicEnabled = true,
		SoundVolume = 0.8,
		MusicVolume = 0.55,
	}
end

function PlayerDataSchema.createDefault(nowTimestamp: number): { [string]: any }
	local timestamp = boundedInteger(nowTimestamp, 0, 0, MAXIMUM_TIMESTAMP)
	local upgrades = {}
	for upgradeId in UPGRADE_MAXIMUMS do
		upgrades[upgradeId] = 0
	end

	local areas = {}
	for _, areaId in AREA_IDS do
		areas[areaId] = areaId == "FrontYard"
	end

	local discoveries = {}
	for _, scrapId in SCRAP_IDS do
		discoveries[scrapId] = {
			Discovered = false,
			HighestVariant = "Normal",
			TotalCollected = 0,
		}
	end

	return {
		SchemaVersion = PlayerDataSchema.CurrentVersion,
		Money = 0,
		Gears = 0,
		TotalScrapCollected = 0,
		StoredWeight = 0,
		StoredValue = 0,
		UpgradeLevels = upgrades,
		UnlockedAreas = areas,
		DiscoveredScrap = discoveries,
		Settings = defaultSettings(),
		CreatedTimestamp = timestamp,
		LastLoginTimestamp = timestamp,
		LastSaveTimestamp = 0,
		--[[
			THE MAILBOX, newest last: arrival order, which is the order that makes sense in a save. The
			inbox screen sorts unclaimed-first for display.

			No migration function is needed for this or `SocialClaims`. `validate` rebuilds every save from
			`createDefault` and copies fields across defensively, so a v14 save simply arrives with an empty
			mailbox -- the same way 15 and 16 added fields.
		]]
		Inbox = {},
		--- Which one-off social rewards have been taken: `Like`, `Community`, `Invite1`..`Invite4`.
		SocialClaims = {},
		PlotStage = 1,
		--[[
			Which area theme the plot is currently built as. Unlocking an area no longer opens
			a region inside the plot; it lets the player convert the whole plot to that theme.
			See docs/PLOT_UPGRADES.md.
		]]
		ActivePlotTheme = "FrontYard",
		--[[
			The cosmetic skin worn over that theme. "" is the standard build, and the default, because a
			skin has to be BOUGHT and then CHOSEN -- owning the pass does not force the look on anybody.
		]]
		ActivePlotSkin = "",
		PlotUpgradeLevels = {},
		UnlockedScrapTypes = {
			MetalCan = true,
			LooseBolt = true,
			SmallMetalPlate = true,
			RustyPipe = true,
			CrushedBucket = true,
			CopperWire = true,
			Tire = true,
		},
		UnlockedMachines = { Crusher = true },
		CrusherLevel = 1,
		PlotTheme = "ToyScrapyard",
		PlotCustomization = {},
		DisplayedTrophies = {},
		PrestigeCount = 0,
		OwnedMagnets = { MagnetBasic = true },
		EquippedMagnet = "MagnetBasic",
		Inventory = { CashPotion = 0, StrengthPotion = 0, LuckPotion = 0, GodPotion = 0 },
		ActiveBoosts = {
			CashBoostEndsAt = 0,
			StrengthBoostEndsAt = 0,
			LuckBoostEndsAt = 0,
			SpawnBoostEndsAt = 0,
			GodBoostEndsAt = 0,
		},
		RedeemedCodes = {},
		Entitlements = {},
		ProcessedReceipts = {},
		OwnedPets = {},
		EquippedPets = {},
		PetSlotUpgradeLevel = 0,
		EggOpenCounts = {},

		--[[
			Return-to-play systems. See `RewardsConfig` and `docs/GAME_AUDIT.md`.

			Days are stored as a DAY NUMBER (`os.time() // 86400`), never a timestamp. Comparing
			day numbers is what makes "have they claimed today" and "was that yesterday" trivial;
			comparing raw timestamps is how a daily reward ends up claimable twice in one evening.
		]]
		DailyStreak = 0,
		DailyLastClaimDay = 0,
		--- Which of the seven calendar days they are offered next, 1-based.
		DailyCalendarDay = 1,

		PlaytimeSecondsToday = 0,
		PlaytimeDay = 0,
		PlaytimeClaimed = {},

		SpinsAvailable = 0,
		SpinLastGrantDay = 0,

		--- 0 = not started. N = step N is the current objective. Past the last step = finished.
		TutorialStep = 0,
		TutorialComplete = false,

		--[[
			Transient: it describes the room, not the player, so it resets to 0 on load. Stored in
			`data` rather than beside it purely so `derivedStats` can read it without a second
			lookup keyed by Player.
		]]
		FriendBoostCount = 0,

		--[[
			Achievements and titles.

			`UnlockedAchievements` records only that a reward has been PAID, not that the goal was reached
			-- progress itself is read live off the other fields by `AchievementRules`. That is what makes
			an achievement added later immediately correct for a player who already did the thing.

			`EquippedTitle` is an id, never the display text. Text belongs to `TitleConfig`, so rewording a
			title updates every player who wears it instead of leaving stale strings in saves.
		]]
		--[[
			Guaranteed Secret rolls, as a COUNT of tickets rather than a flag.

			A count is what makes it testable and grantable in bulk: five tickets is five rolls that must
			come up Secret, whatever egg they are spent on. Consumed one per roll inside `TryOpenEgg`.
		]]
		SecretTickets = 0,

		UnlockedAchievements = {},
		UnlockedTitles = {},
		EquippedTitle = "",
	}
end

local function migrateVersionOne(raw: { [string]: any }, nowTimestamp: number)
	if raw.CreatedTimestamp == nil then
		raw.CreatedTimestamp = raw.LastLoginTimestamp or nowTimestamp
	end
	if raw.LastSaveTimestamp == nil then
		raw.LastSaveTimestamp = 0
	end
	raw.SchemaVersion = 2
end

local function migrateVersionTwo(raw: { [string]: any })
	raw.PlotStage = raw.PlotStage or 1
	raw.PlotUpgradeLevels = raw.PlotUpgradeLevels or {}
	raw.UnlockedScrapTypes = raw.UnlockedScrapTypes
		or { MetalCan = true, LooseBolt = true, SmallMetalPlate = true, Tire = true }
	raw.UnlockedMachines = raw.UnlockedMachines or { Crusher = true }
	raw.CrusherLevel = raw.CrusherLevel or 1
	raw.PlotTheme = raw.PlotTheme or "ToyScrapyard"
	raw.PlotCustomization = raw.PlotCustomization or {}
	raw.DisplayedTrophies = raw.DisplayedTrophies or {}
	raw.PrestigeCount = raw.PrestigeCount or 0
	raw.SchemaVersion = 3
end

local function migrateVersionThree(raw: { [string]: any })
	raw.OwnedMagnets = raw.OwnedMagnets or { MagnetBasic = true }
	raw.EquippedMagnet = raw.EquippedMagnet or "MagnetBasic"
	raw.Inventory = raw.Inventory or { CashPotion = 0, StrengthPotion = 0 }
	raw.ActiveBoosts = raw.ActiveBoosts or { CashBoostEndsAt = 0, StrengthBoostEndsAt = 0 }
	raw.SchemaVersion = 4
end

local function migrateVersionFour(raw: { [string]: any })
	raw.RedeemedCodes = raw.RedeemedCodes or {}
	raw.SchemaVersion = 5
end

local function migrateVersionFive(raw: { [string]: any })
	raw.Entitlements = raw.Entitlements or {}
	raw.ProcessedReceipts = raw.ProcessedReceipts or {}
	raw.SchemaVersion = 6
end

local function migrateVersionSix(raw: { [string]: any })
	raw.UpgradeLevels = raw.UpgradeLevels or {}
	raw.UpgradeLevels.ScrapFlow = raw.UpgradeLevels.ScrapFlow or 0
	raw.SchemaVersion = 7
end

local function migrateVersionSeven(raw: { [string]: any })
	raw.OwnedPets = raw.OwnedPets or {}
	raw.EquippedPets = raw.EquippedPets or {}
	raw.PetSlotUpgradeLevel = raw.PetSlotUpgradeLevel or 0
	raw.EggOpenCounts = raw.EggOpenCounts or {}
	raw.SchemaVersion = 8
end

local function migrateVersionEight(raw: { [string]: any })
	raw.Inventory = raw.Inventory or {}
	raw.ActiveBoosts = raw.ActiveBoosts or {}
	raw.Inventory.LuckPotion = raw.Inventory.LuckPotion or 0
	raw.Inventory.GodPotion = raw.Inventory.GodPotion or 0
	raw.ActiveBoosts.LuckBoostEndsAt = raw.ActiveBoosts.LuckBoostEndsAt or 0
	raw.ActiveBoosts.GodBoostEndsAt = raw.ActiveBoosts.GodBoostEndsAt or 0
	--- The Spawn Potion is newer than the rest, so an older save has no key for it.
	raw.ActiveBoosts.SpawnBoostEndsAt = raw.ActiveBoosts.SpawnBoostEndsAt or 0
	raw.SchemaVersion = 9
end

local function migrateVersionNine(raw: { [string]: any })
	raw.UpgradeLevels = raw.UpgradeLevels or {}
	raw.UpgradeLevels.Rarity = raw.UpgradeLevels.Rarity or 0
	if typeof(raw.DiscoveredScrap) == "table" then
		local legacyVariants = { Silver = "Rare", Gold = "Epic", Rainbow = "Legendary" }
		for _, discovery in raw.DiscoveredScrap do
			if typeof(discovery) == "table" and legacyVariants[discovery.HighestVariant] then
				discovery.HighestVariant = legacyVariants[discovery.HighestVariant]
			end
		end
	end
	raw.SchemaVersion = 10
end

--[[
	The six Junkyard pets were renamed to match the models authored under
	`Workspace.Pets/Junkyard Egg/`. Carry owned counts across rather than dropping
	them: a rename is not a reason to take a player's pets away.
]]
local JUNKYARD_RENAMES = {
	TinPup = "Pup",
	BoltBunny = "Zebra",
	CanCat = "QueenKitty",
	GearFox = "PastelAngel",
	GoldenRaccoon = "AutumnDragon",
	TrashTitan = "MythicAutumnDragon",
}

local function migrateVersionTen(raw: { [string]: any })
	if typeof(raw.OwnedPets) == "table" then
		for oldId, newId in JUNKYARD_RENAMES do
			local owned = raw.OwnedPets[oldId]
			if typeof(owned) == "number" and owned > 0 then
				raw.OwnedPets[newId] = (raw.OwnedPets[newId] or 0) + owned
			end
			raw.OwnedPets[oldId] = nil
		end
	end
	if typeof(raw.EquippedPets) == "table" then
		for index, petId in raw.EquippedPets do
			if JUNKYARD_RENAMES[petId] then
				raw.EquippedPets[index] = JUNKYARD_RENAMES[petId]
			end
		end
	end
	raw.SchemaVersion = 11
end

--[[
	Version 12 briefly carried a `LightTheme` setting. It was removed again before
	release, and the version stays at 12 rather than dropping back to 11: saves were
	already written at 12, and a server that claims to be older would reject them as
	"newer than this server". A stray field in an old save is simply ignored by
	validation, so there is nothing to clean up.
]]
local function migrateVersionEleven(raw: { [string]: any })
	raw.SchemaVersion = 12
end

--- Everyone starts on the theme they already had: the scrapyard.
local function migrateVersionTwelve(raw: { [string]: any })
	raw.ActivePlotTheme = raw.ActivePlotTheme or "FrontYard"
	raw.SchemaVersion = 13
end

--[[
	Return-to-play systems arrive.

	Cheap: every field is a default, and the sanitiser fills anything left nil. Existing players
	start on day 1 of the calendar with no streak, which is right -- a streak they never earned
	would hand them the day-7 multiplier for free.

	`TutorialStep = 0` means "not started", and `TutorialService` decides on join whether an
	established player should be offered the chain at all (they should not).
]]
local function migrateVersionThirteen(raw: { [string]: any })
	raw.DailyStreak = raw.DailyStreak or 0
	raw.DailyLastClaimDay = raw.DailyLastClaimDay or 0
	raw.DailyCalendarDay = raw.DailyCalendarDay or 1
	raw.PlaytimeSecondsToday = raw.PlaytimeSecondsToday or 0
	raw.PlaytimeDay = raw.PlaytimeDay or 0
	raw.PlaytimeClaimed = raw.PlaytimeClaimed or {}
	raw.SpinsAvailable = raw.SpinsAvailable or 0
	raw.SpinLastGrantDay = raw.SpinLastGrantDay or 0
	raw.TutorialStep = raw.TutorialStep or 0
	raw.TutorialComplete = raw.TutorialComplete or false
	raw.FriendBoostCount = 0
	raw.SchemaVersion = 14
end

function PlayerDataSchema.migrate(
	rawValue: any,
	nowTimestamp: number
): (boolean, { [string]: any }?, string?)
	if rawValue == nil then
		return true, PlayerDataSchema.createDefault(nowTimestamp), nil
	end
	if typeof(rawValue) ~= "table" then
		return false, nil, "stored value is not a table"
	end

	local raw = table.clone(rawValue)
	local version = boundedInteger(raw.SchemaVersion, 1, 1, PlayerDataSchema.CurrentVersion + 1)
	if version > PlayerDataSchema.CurrentVersion then
		return false, nil, "stored schema is newer than this server"
	end
	if version == 1 then
		migrateVersionOne(raw, nowTimestamp)
	end
	if raw.SchemaVersion == 2 then
		migrateVersionTwo(raw)
	end
	if raw.SchemaVersion == 3 then
		migrateVersionThree(raw)
	end
	if raw.SchemaVersion == 4 then
		migrateVersionFour(raw)
	end
	if raw.SchemaVersion == 5 then
		migrateVersionFive(raw)
	end
	if raw.SchemaVersion == 6 then
		migrateVersionSix(raw)
	end
	if raw.SchemaVersion == 7 then
		migrateVersionSeven(raw)
	end
	if raw.SchemaVersion == 8 then
		migrateVersionEight(raw)
	end
	if raw.SchemaVersion == 9 then
		migrateVersionNine(raw)
	end
	if raw.SchemaVersion == 10 then
		migrateVersionTen(raw)
	end
	if raw.SchemaVersion == 11 then
		migrateVersionEleven(raw)
	end
	if raw.SchemaVersion == 12 then
		migrateVersionTwelve(raw)
	end
	if raw.SchemaVersion == 13 then
		migrateVersionThirteen(raw)
	end
	return true, raw, nil
end

function PlayerDataSchema.validate(
	rawValue: any,
	nowTimestamp: number
): (boolean, { [string]: any }?, string?)
	local migrated, raw, migrationError = PlayerDataSchema.migrate(rawValue, nowTimestamp)
	if not migrated or raw == nil then
		return false, nil, migrationError
	end

	local defaults = PlayerDataSchema.createDefault(nowTimestamp)
	local upgrades = if typeof(raw.UpgradeLevels) == "table" then raw.UpgradeLevels else {}
	local areas = if typeof(raw.UnlockedAreas) == "table" then raw.UnlockedAreas else {}
	local discoveries = if typeof(raw.DiscoveredScrap) == "table" then raw.DiscoveredScrap else {}
	local settings = if typeof(raw.Settings) == "table" then raw.Settings else {}

	local clean = PlayerDataSchema.createDefault(nowTimestamp)
	clean.Money = boundedInteger(raw.Money, defaults.Money, 0, MAXIMUM_MONEY)
	clean.Gears = boundedInteger(raw.Gears, defaults.Gears, 0, MAXIMUM_GEARS)
	clean.TotalScrapCollected = boundedInteger(raw.TotalScrapCollected, 0, 0, MAXIMUM_COLLECTED)
	clean.StoredWeight = boundedNumber(raw.StoredWeight, 0, 0, MAXIMUM_STORED_WEIGHT)
	clean.StoredValue = boundedInteger(raw.StoredValue, 0, 0, MAXIMUM_STORED_VALUE)

	for upgradeId, maximumLevel in UPGRADE_MAXIMUMS do
		clean.UpgradeLevels[upgradeId] = boundedInteger(upgrades[upgradeId], 0, 0, maximumLevel)
	end
	for _, areaId in AREA_IDS do
		clean.UnlockedAreas[areaId] = if areaId == "FrontYard"
			then true
			else boolean(areas[areaId], false)
	end
	for _, scrapId in SCRAP_IDS do
		local source = if typeof(discoveries[scrapId]) == "table" then discoveries[scrapId] else {}
		local highestVariant = if VARIANT_IDS[source.HighestVariant]
			then source.HighestVariant
			else "Normal"
		clean.DiscoveredScrap[scrapId] = {
			Discovered = boolean(source.Discovered, false),
			HighestVariant = highestVariant,
			TotalCollected = boundedInteger(source.TotalCollected, 0, 0, MAXIMUM_COLLECTED),
		}
	end
	clean.Settings = {
		ParticlesEnabled = boolean(settings.ParticlesEnabled, true),
		ScreenEffectsEnabled = boolean(settings.ScreenEffectsEnabled, true),
		SoundEnabled = boolean(settings.SoundEnabled, true),
		MusicEnabled = boolean(settings.MusicEnabled, true),
		SoundVolume = boundedNumber(settings.SoundVolume, 0.8, 0, 1),
		MusicVolume = boundedNumber(settings.MusicVolume, 0.55, 0, 1),
	}
	clean.CreatedTimestamp =
		boundedInteger(raw.CreatedTimestamp, defaults.CreatedTimestamp, 0, MAXIMUM_TIMESTAMP)
	clean.LastLoginTimestamp =
		boundedInteger(raw.LastLoginTimestamp, defaults.LastLoginTimestamp, 0, MAXIMUM_TIMESTAMP)
	clean.LastSaveTimestamp = boundedInteger(raw.LastSaveTimestamp, 0, 0, MAXIMUM_TIMESTAMP)
	clean.SchemaVersion = PlayerDataSchema.CurrentVersion
	clean.PlotStage = boundedInteger(raw.PlotStage, 1, 1, MAXIMUM_PLOT_STAGE)
	clean.CrusherLevel = boundedInteger(raw.CrusherLevel, 1, 1, MAXIMUM_CRUSHER_LEVEL)
	clean.PrestigeCount = boundedInteger(raw.PrestigeCount, 0, 0, MAXIMUM_COLLECTED)
	clean.OwnedMagnets = { MagnetBasic = true, AdvancedMagnet = false, QuantumMagnet = false }
	if typeof(raw.OwnedMagnets) == "table" then
		clean.OwnedMagnets.MagnetBasic = boolean(raw.OwnedMagnets.MagnetBasic, true)
		clean.OwnedMagnets.AdvancedMagnet = boolean(raw.OwnedMagnets.AdvancedMagnet, false)
		clean.OwnedMagnets.QuantumMagnet = boolean(raw.OwnedMagnets.QuantumMagnet, false)
	end
	clean.EquippedMagnet = if (
			raw.EquippedMagnet == "AdvancedMagnet" or raw.EquippedMagnet == "QuantumMagnet"
		) and clean.OwnedMagnets[raw.EquippedMagnet]
		then raw.EquippedMagnet
		else "MagnetBasic"
	local inventory = if typeof(raw.Inventory) == "table" then raw.Inventory else {}
	clean.Inventory = {
		CashPotion = boundedInteger(inventory.CashPotion, 0, 0, 9999),
		StrengthPotion = boundedInteger(inventory.StrengthPotion, 0, 0, 9999),
		LuckPotion = boundedInteger(inventory.LuckPotion, 0, 0, 9999),
		GodPotion = boundedInteger(inventory.GodPotion, 0, 0, 9999),
	}
	local boosts = if typeof(raw.ActiveBoosts) == "table" then raw.ActiveBoosts else {}
	clean.ActiveBoosts = {
		CashBoostEndsAt = boundedInteger(boosts.CashBoostEndsAt, 0, 0, MAXIMUM_TIMESTAMP),
		StrengthBoostEndsAt = boundedInteger(boosts.StrengthBoostEndsAt, 0, 0, MAXIMUM_TIMESTAMP),
		LuckBoostEndsAt = boundedInteger(boosts.LuckBoostEndsAt, 0, 0, MAXIMUM_TIMESTAMP),
		SpawnBoostEndsAt = boundedInteger(boosts.SpawnBoostEndsAt, 0, 0, MAXIMUM_TIMESTAMP),
		GodBoostEndsAt = boundedInteger(boosts.GodBoostEndsAt, 0, 0, MAXIMUM_TIMESTAMP),
	}
	clean.RedeemedCodes = {}
	if typeof(raw.RedeemedCodes) == "table" then
		for codeId, redeemed in raw.RedeemedCodes do
			if typeof(codeId) == "string" and #codeId <= 40 and redeemed == true then
				clean.RedeemedCodes[codeId] = true
			end
		end
	end
	clean.Entitlements = {}
	if typeof(raw.Entitlements) == "table" then
		for entitlementId, owned in raw.Entitlements do
			if typeof(entitlementId) == "string" and #entitlementId <= 40 and owned == true then
				clean.Entitlements[entitlementId] = true
			end
		end
	end
	clean.ProcessedReceipts = {}
	if typeof(raw.ProcessedReceipts) == "table" then
		local retained = 0
		for purchaseId, processed in raw.ProcessedReceipts do
			if
				typeof(purchaseId) == "string"
				and #purchaseId <= 80
				and processed == true
				and retained < 100
			then
				clean.ProcessedReceipts[purchaseId] = true
				retained += 1
			end
		end
	end
	clean.OwnedPets = {}
	local ownedPets = if typeof(raw.OwnedPets) == "table" then raw.OwnedPets else {}
	for _, petId in PET_IDS do
		clean.OwnedPets[petId] = boundedInteger(ownedPets[petId], 0, 0, MAXIMUM_OWNED_PER_PET)
	end
	clean.PetSlotUpgradeLevel =
		boundedInteger(raw.PetSlotUpgradeLevel, 0, 0, MAXIMUM_PET_SLOT_UPGRADES)
	local entitlementPetSlots = if clean.Entitlements.ExtraPetSlots == true
		then PASS_PET_SLOTS
		else 0
	local maximumEquipped = BASE_PET_SLOTS + clean.PetSlotUpgradeLevel + entitlementPetSlots
	clean.EquippedPets = {}
	local equippedCounts = {}
	if typeof(raw.EquippedPets) == "table" then
		for _, petId in raw.EquippedPets do
			if
				typeof(petId) == "string"
				and clean.OwnedPets[petId] ~= nil
				and clean.OwnedPets[petId] > 0
				and (equippedCounts[petId] or 0) < clean.OwnedPets[petId]
				and #clean.EquippedPets < maximumEquipped
			then
				equippedCounts[petId] = (equippedCounts[petId] or 0) + 1
				table.insert(clean.EquippedPets, petId)
			end
		end
	end
	clean.EggOpenCounts = {}
	local eggOpenCounts = if typeof(raw.EggOpenCounts) == "table" then raw.EggOpenCounts else {}
	for _, eggId in EGG_IDS do
		clean.EggOpenCounts[eggId] = boundedInteger(eggOpenCounts[eggId], 0, 0, MAXIMUM_COLLECTED)
	end
	clean.PlotTheme = if typeof(raw.PlotTheme) == "string" and #raw.PlotTheme <= 40
		then raw.PlotTheme
		else "ToyScrapyard"
	--[[
		WAS NEVER SANITISED, so it was never loaded: `createDefault` set it and the migration set
		it, but nothing copied it out of `raw`, which meant every player came back as `FrontYard`
		however many times they had converted their plot. Validated against the real area list so a
		theme that no longer exists falls back rather than producing a plot nobody can build.
	]]
	local savedTheme = raw.ActivePlotTheme
	clean.ActivePlotTheme = "FrontYard"
	for _, areaId in AREA_IDS do
		if savedTheme == areaId then
			clean.ActivePlotTheme = areaId
			break
		end
	end
	--[[
		THE CHOSEN SKIN, validated against the pass list rather than trusted.

		Not checked against ENTITLEMENTS here, deliberately: this function sanitises a save without knowing
		what the player owns, and clearing the choice for an unowned pass would erase it for anyone whose
		entitlements had not loaded yet. `PlotThemeService` asks about ownership at build time instead, so a
		skin the player no longer owns simply stops being drawn.
	]]
	clean.ActivePlotSkin = ""
	if raw.ActivePlotSkin == SKIN_PASS then
		clean.ActivePlotSkin = raw.ActivePlotSkin
	end
	--[[
		THE MAILBOX, sanitised message by message.

		Anything malformed is dropped rather than repaired: a message is a display object with a reward
		attached, and a half-readable one is worse than none. Rewards go through the same bounds the rest of
		the save uses, so a tampered save cannot mail itself a billion dollars.
	]]
	clean.Inbox = {}
	if typeof(raw.Inbox) == "table" then
		for _, entry in raw.Inbox do
			if #clean.Inbox >= INBOX_MAXIMUM then
				break
			end
			if
				typeof(entry) == "table"
				and typeof(entry.Id) == "string"
				and #entry.Id <= 60
				and typeof(entry.Title) == "string"
				and typeof(entry.Body) == "string"
			then
				local rewards = nil
				if typeof(entry.Rewards) == "table" then
					rewards = {}
					rewards.Money = boundedInteger(entry.Rewards.Money, 0, 0, MAXIMUM_MONEY)
					rewards.Gears = boundedInteger(entry.Rewards.Gears, 0, 0, MAXIMUM_GEARS)
					rewards.Spins = boundedInteger(entry.Rewards.Spins, 0, 0, 1000)
					if typeof(entry.Rewards.Items) == "table" then
						rewards.Items = {}
						for itemId, count in entry.Rewards.Items do
							if typeof(itemId) == "string" and #itemId <= 40 then
								rewards.Items[itemId] = boundedInteger(count, 0, 0, 9999)
							end
						end
					end
				end
				table.insert(clean.Inbox, {
					Id = entry.Id,
					Kind = if entry.Kind == "Staff" then "Staff" else "System",
					Title = string.sub(entry.Title, 1, 60),
					Body = string.sub(entry.Body, 1, 280),
					FromName = if typeof(entry.FromName) == "string"
						then string.sub(entry.FromName, 1, 40)
						else "",
					FromUserId = boundedInteger(entry.FromUserId, 0, 0, 1e12),
					--- Only the two staff ranks are kept; anything else becomes no rank at all.
					FromRole = if entry.FromRole == "OWNER" or entry.FromRole == "ADMIN"
						then entry.FromRole
						else "",
					SentAt = boundedInteger(entry.SentAt, 0, 0, 1e12),
					Rewards = rewards,
					Claimed = boolean(entry.Claimed, false),
				})
			end
		end
	end
	clean.SocialClaims = {}
	if typeof(raw.SocialClaims) == "table" then
		for key, value in raw.SocialClaims do
			if typeof(key) == "string" and #key <= 40 then
				clean.SocialClaims[key] = boolean(value, false)
			end
		end
	end
	clean.PlotUpgradeLevels = {}
	if typeof(raw.PlotUpgradeLevels) == "table" then
		for key, value in raw.PlotUpgradeLevels do
			if typeof(key) == "string" and #key <= 40 then
				clean.PlotUpgradeLevels[key] = boundedInteger(value, 0, 0, 100)
			end
		end
	end
	clean.UnlockedScrapTypes = {}
	local unlockedScrap = if typeof(raw.UnlockedScrapTypes) == "table"
		then raw.UnlockedScrapTypes
		else defaults.UnlockedScrapTypes
	for _, scrapId in SCRAP_IDS do
		clean.UnlockedScrapTypes[scrapId] = boolean(unlockedScrap[scrapId], false)
	end
	clean.UnlockedScrapTypes.MetalCan = true
	clean.UnlockedScrapTypes.LooseBolt = true
	clean.UnlockedScrapTypes.SmallMetalPlate = true
	clean.UnlockedScrapTypes.RustyPipe = true
	clean.UnlockedScrapTypes.CrushedBucket = true
	clean.UnlockedScrapTypes.CopperWire = true
	clean.UnlockedScrapTypes.Tire = true
	clean.UnlockedMachines = { Crusher = true }
	if typeof(raw.UnlockedMachines) == "table" then
		for key, value in raw.UnlockedMachines do
			if typeof(key) == "string" and #key <= 40 then
				clean.UnlockedMachines[key] = boolean(value, false)
			end
		end
	end
	clean.PlotCustomization = {}
	if typeof(raw.PlotCustomization) == "table" then
		for key, value in raw.PlotCustomization do
			if
				typeof(key) == "string"
				and typeof(value) == "string"
				and #key <= 40
				and #value <= 80
			then
				clean.PlotCustomization[key] = value
			end
		end
	end
	clean.DisplayedTrophies = {}
	if typeof(raw.DisplayedTrophies) == "table" then
		for _, trophyId in raw.DisplayedTrophies do
			if
				typeof(trophyId) == "string"
				and #trophyId <= 40
				and #clean.DisplayedTrophies < 12
			then
				table.insert(clean.DisplayedTrophies, trophyId)
			end
		end
	end

	--[[
		Return-to-play systems.

		Every one of these is bounded, because they are all "free money on a timer" and a corrupt
		or edited value is a direct exploit: an unbounded `SpinsAvailable` is unlimited jackpots,
		and an unbounded `DailyStreak` is an unbounded cash multiplier.
	]]
	clean.DailyStreak = boundedInteger(raw.DailyStreak, 0, 0, MAXIMUM_DAILY_STREAK)
	clean.DailyLastClaimDay = boundedInteger(raw.DailyLastClaimDay, 0, 0, MAXIMUM_DAY_NUMBER)
	clean.DailyCalendarDay = boundedInteger(raw.DailyCalendarDay, 1, 1, DAILY_CALENDAR_LENGTH)

	clean.PlaytimeSecondsToday =
		boundedInteger(raw.PlaytimeSecondsToday, 0, 0, MAXIMUM_PLAYTIME_SECONDS)
	clean.PlaytimeDay = boundedInteger(raw.PlaytimeDay, 0, 0, MAXIMUM_DAY_NUMBER)
	clean.PlaytimeClaimed = {}
	if typeof(raw.PlaytimeClaimed) == "table" then
		for index, claimed in raw.PlaytimeClaimed do
			-- keys survive a JSON round-trip as strings, so accept either
			local milestoneIndex = if typeof(index) == "number" then index else tonumber(index)
			if
				milestoneIndex ~= nil
				and milestoneIndex >= 1
				and milestoneIndex <= PLAYTIME_MILESTONE_COUNT
				and claimed == true
			then
				clean.PlaytimeClaimed[math.floor(milestoneIndex)] = true
			end
		end
	end

	clean.SpinsAvailable = boundedInteger(raw.SpinsAvailable, 0, 0, MAXIMUM_STORED_SPINS)
	clean.SpinLastGrantDay = boundedInteger(raw.SpinLastGrantDay, 0, 0, MAXIMUM_DAY_NUMBER)

	clean.TutorialStep = boundedInteger(raw.TutorialStep, 0, 0, TUTORIAL_STEP_COUNT + 1)
	clean.TutorialComplete = boolean(raw.TutorialComplete, false)

	--- Always zero on load: it describes the server the player is in, not the player.
	clean.FriendBoostCount = 0

	--[[
		Achievements and titles.

		VALIDATED STRUCTURALLY, NOT AGAINST THE CONFIG. This module deliberately requires nothing -- it is
		the one piece of game logic that has to run under Lune with no Roblox and no DataModel, which is
		why the pet and egg id lists above are hardcoded rather than read from `PetConfig`.

		Copying that pattern here would mean every new achievement needed editing in two files, and the
		one that got forgotten would silently refuse to save. So the sanitiser enforces what a sanitiser
		is for -- right types, bounded size, no unbounded growth -- and the CONFIG stays the authority on
		which ids mean anything: `AchievementConfig.ById` and `TitleConfig.resolve` both return nil for an
		unknown id, so a stale key is inert everywhere it is read.
	]]
	clean.SecretTickets = boundedInteger(raw.SecretTickets, 0, 0, MAXIMUM_SECRET_TICKETS)
	clean.UnlockedAchievements = boundedIdSet(raw.UnlockedAchievements)
	clean.UnlockedTitles = boundedIdSet(raw.UnlockedTitles)

	--- Only a title the player actually holds can be worn; anything else falls back to none.
	clean.EquippedTitle = ""
	if
		typeof(raw.EquippedTitle) == "string"
		and #raw.EquippedTitle <= MAXIMUM_ID_LENGTH
		and clean.UnlockedTitles[raw.EquippedTitle] == true
	then
		clean.EquippedTitle = raw.EquippedTitle
	end

	return true, clean, nil
end

return table.freeze(PlayerDataSchema)
