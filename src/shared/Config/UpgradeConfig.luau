--!strict

local GameTypes = require(script.Parent.Parent.Types.GameTypes)

local function upgrade(definition: GameTypes.UpgradeDefinition): GameTypes.UpgradeDefinition
	return table.freeze(definition)
end

local order: { GameTypes.UpgradeId } = {
	"MagnetStrength",
	"MagnetRange",
	"StorageCapacity",
	"MovementSpeed",
	"ScrapValue",
	"CollectionSpeed",
}

local byId: { [GameTypes.UpgradeId]: GameTypes.UpgradeDefinition } = {
	MagnetStrength = upgrade({
		Id = "MagnetStrength",
		DisplayName = "Magnet Strength",
		MaximumLevel = 20,
		BaseCost = 45,
		GrowthRate = 1.52,
		BaseEffect = 4,
		EffectPerLevel = 2.5,
		EffectCap = 54,
		EffectUnit = " strength",
	}),
	MagnetRange = upgrade({
		Id = "MagnetRange",
		DisplayName = "Magnet Range",
		MaximumLevel = 20,
		BaseCost = 60,
		GrowthRate = 1.48,
		BaseEffect = 18,
		EffectPerLevel = 1.5,
		EffectCap = 48,
		EffectUnit = " studs",
	}),
	StorageCapacity = upgrade({
		Id = "StorageCapacity",
		DisplayName = "Storage Capacity",
		MaximumLevel = 25,
		BaseCost = 40,
		GrowthRate = 1.5,
		BaseEffect = 20,
		EffectPerLevel = 8,
		EffectCap = 220,
		EffectUnit = " weight",
	}),
	MovementSpeed = upgrade({
		Id = "MovementSpeed",
		DisplayName = "Movement Speed",
		MaximumLevel = 10,
		BaseCost = 125,
		GrowthRate = 1.72,
		BaseEffect = 16,
		EffectPerLevel = 0.8,
		EffectCap = 24,
		EffectUnit = " speed",
	}),
	ScrapValue = upgrade({
		Id = "ScrapValue",
		DisplayName = "Scrap Value",
		MaximumLevel = 20,
		BaseCost = 180,
		GrowthRate = 1.62,
		BaseEffect = 1,
		EffectPerLevel = 0.12,
		EffectCap = 3.4,
		EffectUnit = "x",
	}),
	CollectionSpeed = upgrade({
		Id = "CollectionSpeed",
		DisplayName = "Collection Speed",
		MaximumLevel = 15,
		BaseCost = 90,
		GrowthRate = 1.55,
		BaseEffect = 24,
		EffectPerLevel = 2.4,
		EffectCap = 60,
		EffectUnit = " studs/sec",
	}),
}

return table.freeze({ ById = table.freeze(byId), Order = table.freeze(order) })
