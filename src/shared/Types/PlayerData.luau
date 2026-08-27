--!strict

local GameTypes = require(script.Parent.GameTypes)

export type UpgradeLevels = { [GameTypes.UpgradeId]: number }

export type ScrapDiscovery = {
	Discovered: boolean,
	HighestVariant: GameTypes.VariantId,
	TotalCollected: number,
}

export type PlayerSettings = {
	ParticlesEnabled: boolean,
	ScreenEffectsEnabled: boolean,
	SoundEnabled: boolean,
	MusicEnabled: boolean,
	SoundVolume: number,
	MusicVolume: number,
}

export type PlayerData = {
	SchemaVersion: number,
	Money: number,
	Gears: number,
	--[[
		THE PIT's event currency. Earned only from Pit pickups and wrecks, spent only at the Pit
		shop, and it BANKS across weeks -- a Friday you skip still leaves last week's slag.
	]]
	Slag: number,
	TotalScrapCollected: number,
	StoredWeight: number,
	StoredValue: number,
	UpgradeLevels: UpgradeLevels,
	UnlockedAreas: { [GameTypes.AreaId]: boolean },
	DiscoveredScrap: { [GameTypes.ScrapId]: ScrapDiscovery },
	Settings: PlayerSettings,
	CreatedTimestamp: number,
	LastLoginTimestamp: number,
	LastSaveTimestamp: number,
	PlotStage: number,
	--- Area id the plot is built as; see docs/PLOT_UPGRADES.md.
	ActivePlotTheme: string,
	--- Pass id of the cosmetic skin worn over that theme, or "" for the standard build.
	ActivePlotSkin: string,
	Inbox: { { [string]: any } },
	SocialClaims: { [string]: boolean },
	PlotUpgradeLevels: { [string]: number },
	UnlockedScrapTypes: { [GameTypes.ScrapId]: boolean },
	UnlockedMachines: { [string]: boolean },
	CrusherLevel: number,
	PlotTheme: string,
	PlotCustomization: { [string]: string },
	DisplayedTrophies: { string },
	PrestigeCount: number,
	OwnedMagnets: { [string]: boolean },
	EquippedMagnet: string,
	--- Cosmetic magnet skins. `ActiveMagnetSkin` is "" for the equipped magnet's own look.
	OwnedMagnetSkins: { [string]: boolean },
	ActiveMagnetSkin: string,
	Inventory: { [string]: number },
	ActiveBoosts: { [string]: number },
	RedeemedCodes: { [string]: boolean },
	Entitlements: { [string]: boolean },
	ProcessedReceipts: { [string]: boolean },
	OwnedPets: { [string]: number },
	EquippedPets: { string },
	PetSlotUpgradeLevel: number,
	--[[
		Permanent Gear Shop ranks. Survive prestige. Keys are offer ids from
		`GearShopConfig`; unknown keys are dropped on load.
	]]
	GearUpgrades: { [string]: number },
	EggOpenCounts: { [string]: number },
}

return table.freeze({})
