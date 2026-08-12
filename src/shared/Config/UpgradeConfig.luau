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
	"ScrapFlow",
	"Rarity",
}

local byId: { [GameTypes.UpgradeId]: GameTypes.UpgradeDefinition } = {
	MagnetStrength = upgrade({
		Id = "MagnetStrength",
		DisplayName = "Magnet Strength",
		BaseMaximumLevel = 10,
		LevelsPerPrestige = 2,
		BaseCost = 35,
		GrowthRate = 1.3,
		CostPower = 1.55,
		BaseEffect = 4,
		EffectPerLevel = 1.35,
		EffectCurve = "Power",
		CurvePower = 1.12,
		EffectCap = 1e9,
		EffectUnit = " strength",
	}),
	MagnetRange = upgrade({
		Id = "MagnetRange",
		DisplayName = "Magnet Range",
		BaseMaximumLevel = 10,
		LevelsPerPrestige = 2,
		BaseCost = 38,
		GrowthRate = 1.32,
		CostPower = 1.7,
		BaseEffect = 9,
		EffectPerLevel = 0.75,
		EffectCurve = "Power",
		CurvePower = 1,
		EffectCap = 42,
		EffectUnit = " studs",
	}),
	StorageCapacity = upgrade({
		Id = "StorageCapacity",
		DisplayName = "Storage Capacity",
		BaseMaximumLevel = 10,
		LevelsPerPrestige = 2,
		BaseCost = 42,
		GrowthRate = 1.3,
		CostPower = 1.55,
		--[[
			25 slots at level zero, about +5 a level. Storage is a COUNT of pieces now, not weight.

			The old 20/+6 was in weight units against scrap weighing 0.5 to 160, so the same number meant
			seventy bolts or one scrap car. In slots it means the same thing every time.
		]]
		BaseEffect = 25,
		EffectPerLevel = 5,
		EffectCurve = "Power",
		--- Nearly linear on purpose: a slot is a slot, so there is nothing for a curve to express.
		CurvePower = 1.02,
		EffectCap = 1e9,
		EffectUnit = " slots",
	}),
	MovementSpeed = upgrade({
		Id = "MovementSpeed",
		DisplayName = "Movement Speed",
		BaseMaximumLevel = 10,
		LevelsPerPrestige = 2,
		BaseCost = 39,
		GrowthRate = 1.34,
		CostPower = 1.9,
		BaseEffect = 16,
		--[[
			Movement tops out at 26, down from 28.

			A soft cap rather than a curve change: past about 26 walk speed the plot stops feeling like a
			place you move through and starts feeling like a menu, and the collection loop is built around
			walking between piles.
		]]
		EffectPerLevel = 0.07,
		EffectCurve = "Diminishing",
		CurvePower = 1,
		EffectCap = 26,
		EffectUnit = " speed",
	}),
	ScrapValue = upgrade({
		Id = "ScrapValue",
		DisplayName = "Scrap Value",
		BaseMaximumLevel = 10,
		LevelsPerPrestige = 2,
		BaseCost = 95,
		GrowthRate = 1.38,
		CostPower = 1.72,
		BaseEffect = 1,
		EffectPerLevel = 0.085,
		EffectCurve = "Exponential",
		CurvePower = 1,
		EffectCap = 1e9,
		EffectUnit = "x",
	}),
	CollectionSpeed = upgrade({
		Id = "CollectionSpeed",
		DisplayName = "Collection Speed",
		BaseMaximumLevel = 10,
		LevelsPerPrestige = 2,
		BaseCost = 60,
		GrowthRate = 1.34,
		CostPower = 1.65,
		BaseEffect = 24,
		EffectPerLevel = 1.8,
		EffectCurve = "Power",
		CurvePower = 1.08,
		EffectCap = 10000,
		EffectUnit = " studs/sec",
	}),
	ScrapFlow = upgrade({
		Id = "ScrapFlow",
		DisplayName = "Scrap Flow",
		BaseMaximumLevel = 10,
		LevelsPerPrestige = 2,
		BaseCost = 100,
		GrowthRate = 1.4,
		CostPower = 1.8,
		BaseEffect = 1,
		EffectPerLevel = 0.055,
		EffectCurve = "Reduction",
		CurvePower = 0.82,
		EffectCap = 0.18,
		EffectUnit = "x respawn",
	}),
	Rarity = upgrade({
		Id = "Rarity",
		DisplayName = "Rarity Luck",
		BaseMaximumLevel = 10,
		LevelsPerPrestige = 2,
		BaseCost = 135,
		GrowthRate = 1.42,
		CostPower = 1.85,
		BaseEffect = 1,
		EffectPerLevel = 0.12,
		EffectCurve = "Power",
		CurvePower = 1.08,
		EffectCap = 8,
		EffectUnit = "x rarity luck",
	}),
}

return table.freeze({ ById = table.freeze(byId), Order = table.freeze(order) })
