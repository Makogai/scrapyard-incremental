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
		BaseCost = 650,
		GrowthRate = 1.30,
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
		--[[
			Starter magnet is 5 studs. +0.4 studs a level, so the first prestige cap
			(level 10) is +4 and rebirth 6 (level 22) is +8.8. The hard ceiling on
			derived reach is Environment.MaximumMagnetRange -- this EffectCap is only
			the upgrade's own contribution (BaseEffect + 8).
		]]
		BaseCost = 500,
		GrowthRate = 1.35,
		BaseEffect = 5,
		EffectPerLevel = 0.4,
		EffectCurve = "Power",
		CurvePower = 1,
		EffectCap = 13,
		EffectUnit = " studs",
	}),
	StorageCapacity = upgrade({
		Id = "StorageCapacity",
		DisplayName = "Storage Capacity",
		BaseMaximumLevel = 10,
		LevelsPerPrestige = 2,
		BaseCost = 800,
		GrowthRate = 1.30,
		--[[
			25 slots at level zero, about +5 a level. Storage is a COUNT of pieces now, not weight.

			The old 20/+6 was in weight units against scrap weighing 0.5 to 160, so the same number meant
			seventy bolts or one scrap car. In slots it means the same thing every time.
		]]
		BaseEffect = 25,
		EffectPerLevel = 5,
		EffectCurve = "Power",
		--- Linear: a slot is a slot. A 1.02 curve left fractional slots that the HUD rounded up, so 51 on
		--- the bar was 50.81 in the check and the last space could never be filled.
		CurvePower = 1,
		EffectCap = 1e9,
		EffectUnit = " slots",
	}),
	MovementSpeed = upgrade({
		Id = "MovementSpeed",
		DisplayName = "Movement Speed",
		BaseMaximumLevel = 10,
		LevelsPerPrestige = 2,
		BaseCost = 1200,
		GrowthRate = 1.34,
		BaseEffect = 16,
		--[[
			+3 walk speed a level, from Roblox's default 16 up to 46 at the base cap (almost 3x).
			The 2x Walk Speed pass multiplies AFTER this, so a maxed upgrade plus the pass is 92.

			28 felt like a walk, not an upgrade. Prestige raising the level ceiling can still climb
			toward 64; past that the plot is a blur.
		]]
		EffectPerLevel = 3,
		EffectCurve = "Power",
		CurvePower = 1,
		EffectCap = 64,
		EffectUnit = " speed",
	}),
	ScrapValue = upgrade({
		Id = "ScrapValue",
		DisplayName = "Scrap Value",
		BaseMaximumLevel = 10,
		LevelsPerPrestige = 2,
		BaseCost = 1500,
		GrowthRate = 1.40,
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
		BaseCost = 900,
		GrowthRate = 1.34,
		BaseEffect = 24,
		EffectPerLevel = 1.8,
		EffectCurve = "Power",
		CurvePower = 1.08,
		EffectCap = 10000,
		EffectUnit = " studs/sec",
	}),
	ScrapFlow = upgrade({
		Id = "ScrapFlow",
		DisplayName = "Spawn Rate",
		BaseMaximumLevel = 10,
		LevelsPerPrestige = 2,
		BaseCost = 2200,
		GrowthRate = 1.42,
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
		BaseCost = 3000,
		GrowthRate = 1.45,
		BaseEffect = 1,
		EffectPerLevel = 0.12,
		EffectCurve = "Power",
		CurvePower = 1.08,
		EffectCap = 8,
		EffectUnit = "x rarity luck",
	}),
}

return table.freeze({ ById = table.freeze(byId), Order = table.freeze(order) })
