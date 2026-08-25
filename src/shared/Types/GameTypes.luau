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
	| "RustyPipe"
	| "CrushedBucket"
	| "CopperWire"
	| "ToolBox"
	| "BrakeDisc"
	| "Radiator"
	| "MotorCoil"
	| "ExhaustPipe"
	| "Axle"
	| "FuelTank"

export type VariantId = "Normal" | "Rare" | "Epic" | "Legendary" | "Nebula"
export type AreaId = "FrontYard" | "WorkshopYard" | "VehicleGraveyard"
export type UpgradeId =
	"MagnetStrength"
	| "MagnetRange"
	| "StorageCapacity"
	| "MovementSpeed"
	| "ScrapValue"
	| "CollectionSpeed"
	| "ScrapFlow"
	| "Rarity"

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
	--[[
		The name of the model to clone, and the ONLY thing this config says about how a piece of
		scrap looks. Size and rotation come from the model itself, exactly as saved in Studio -- see
		`ScrapService.placeOnMarker`. There is deliberately no size or rotation field here to disagree
		with the art.
	]]
	ModelName: string,
}

export type VariantDefinition = {
	Id: VariantId,
	DisplayName: string,
	ValueMultiplier: number,
	SpawnWeight: number,
	LuckExponent: number,
	Color: Color3,
	EffectName: string?,
}

export type UpgradeDefinition = {
	Id: UpgradeId,
	DisplayName: string,
	BaseMaximumLevel: number,
	LevelsPerPrestige: number,
	BaseCost: number,
	GrowthRate: number,
	BaseEffect: number,
	EffectPerLevel: number,
	EffectCurve: "Power" | "Diminishing" | "Exponential" | "Reduction",
	CurvePower: number,
	EffectCap: number,
	EffectUnit: string,
}

export type PetRarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Secret"

export type PetDefinition = {
	Id: string,
	DisplayName: string,
	EggId: string,
	Rarity: PetRarity,
	RollWeight: number,
	MoneyMultiplier: number,
	Effects: { [string]: number },
	Premium: boolean?,
	Ability: string?,
	AbilityPower: number?,
	Description: string,
	ModelName: string,
	IconAssetId: string,
	FallbackColor: Color3,
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
