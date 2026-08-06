--!strict

export type ScrapId =
	"MetalCan"
	| "LooseBolt"
	| "SmallMetalPlate"
	| "Tire"
	| "BrokenAppliance"
	| "EnginePart"
	| "CarDoor"
	| "ScrapCar"

export type VariantId = "Normal" | "Silver" | "Gold" | "Rainbow"
export type AreaId = "FrontYard" | "WorkshopYard" | "VehicleGraveyard"
export type UpgradeId =
	"MagnetStrength"
	| "MagnetRange"
	| "StorageCapacity"
	| "MovementSpeed"
	| "ScrapValue"
	| "CollectionSpeed"

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic"

export type ScrapDefinition = {
	Id: ScrapId,
	DisplayName: string,
	Weight: number,
	BaseValue: number,
	RequiredMagnetStrength: number,
	AreaIds: { AreaId },
	SpawnWeight: number,
	RespawnSeconds: number,
	Size: { number },
	Rarity: Rarity,
	ModelName: string,
}

export type VariantDefinition = {
	Id: VariantId,
	DisplayName: string,
	ValueMultiplier: number,
	SpawnWeight: number,
	Color: Color3,
	EffectName: string?,
}

export type UpgradeDefinition = {
	Id: UpgradeId,
	DisplayName: string,
	MaximumLevel: number,
	BaseCost: number,
	GrowthRate: number,
	BaseEffect: number,
	EffectPerLevel: number,
	EffectCap: number,
	EffectUnit: string,
}

export type AreaDefinition = {
	Id: AreaId,
	DisplayName: string,
	Order: number,
	UnlockPrice: number,
	ScrapIds: { ScrapId },
	GateModelName: string?,
}

return table.freeze({})
