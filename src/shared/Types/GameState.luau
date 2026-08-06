--!strict

local GameTypes = require(script.Parent.GameTypes)

export type DerivedStats = {
	MagnetStrength: number,
	MagnetRange: number,
	StorageCapacity: number,
	MovementSpeed: number,
	ScrapValue: number,
	CollectionSpeed: number,
}

export type PublicPlayerState = {
	Money: number,
	Gears: number,
	StoredWeight: number,
	StoredValue: number,
	UpgradeLevels: { [GameTypes.UpgradeId]: number },
	UnlockedAreas: { [GameTypes.AreaId]: boolean },
	DerivedStats: DerivedStats,
}

return table.freeze({})
