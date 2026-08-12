--!strict

local GameTypes = require(script.Parent.GameTypes)

export type DerivedStats = {
	MagnetStrength: number,
	MagnetRange: number,
	StorageCapacity: number,
	MovementSpeed: number,
	ScrapValue: number,
	CollectionSpeed: number,
	RespawnMultiplier: number,
	RarityLuck: number,
	PetMoneyMultiplier: number,
}

export type PublicPlayerState = {
	Money: number,
	Gears: number,
	StoredWeight: number,
	StoredValue: number,
	Inbox: { { [string]: any } },
	SocialClaims: { [string]: boolean },
	UpgradeLevels: { [GameTypes.UpgradeId]: number },
	UnlockedAreas: { [GameTypes.AreaId]: boolean },
	DerivedStats: DerivedStats,
	UpgradeMaximumLevels: { [GameTypes.UpgradeId]: number },
}

return table.freeze({})
