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
	Inventory: { [string]: number },
	ActiveBoosts: { [string]: number },
	RedeemedCodes: { [string]: boolean },
	Entitlements: { [string]: boolean },
	ProcessedReceipts: { [string]: boolean },
}

return table.freeze({})
