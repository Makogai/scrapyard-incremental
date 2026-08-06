--!strict

local PlayerDataSchema = {}

PlayerDataSchema.CurrentVersion = 6

local UPGRADE_MAXIMUMS = {
	MagnetStrength = 20,
	MagnetRange = 20,
	StorageCapacity = 25,
	MovementSpeed = 10,
	ScrapValue = 20,
	CollectionSpeed = 15,
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
}
local VARIANT_IDS = { Normal = true, Silver = true, Gold = true, Rainbow = true }

local MAXIMUM_MONEY = 1e15
local MAXIMUM_GEARS = 1000000
local MAXIMUM_STORED_WEIGHT = 1e9
local MAXIMUM_STORED_VALUE = 1e12
local MAXIMUM_COLLECTED = 1e15
local MAXIMUM_TIMESTAMP = 32503680000
local MAXIMUM_PLOT_STAGE = 4
local MAXIMUM_CRUSHER_LEVEL = 100

local function finite(value: any): boolean
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
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
		PlotStage = 1,
		PlotUpgradeLevels = {},
		UnlockedScrapTypes = {
			MetalCan = true,
			LooseBolt = true,
			SmallMetalPlate = true,
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
		Inventory = { CashPotion = 0, StrengthPotion = 0 },
		ActiveBoosts = { CashBoostEndsAt = 0, StrengthBoostEndsAt = 0 },
		RedeemedCodes = {},
		Entitlements = {},
		ProcessedReceipts = {},
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
	}
	local boosts = if typeof(raw.ActiveBoosts) == "table" then raw.ActiveBoosts else {}
	clean.ActiveBoosts = {
		CashBoostEndsAt = boundedInteger(boosts.CashBoostEndsAt, 0, 0, MAXIMUM_TIMESTAMP),
		StrengthBoostEndsAt = boundedInteger(boosts.StrengthBoostEndsAt, 0, 0, MAXIMUM_TIMESTAMP),
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
	clean.PlotTheme = if typeof(raw.PlotTheme) == "string" and #raw.PlotTheme <= 40
		then raw.PlotTheme
		else "ToyScrapyard"
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

	return true, clean, nil
end

return table.freeze(PlayerDataSchema)
