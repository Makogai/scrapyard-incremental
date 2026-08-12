--!strict

local GameTypes = require(script.Parent.Parent.Types.GameTypes)

--[[
	NOTHING HERE DECIDES HOW BIG A PIECE OF SCRAP IS, OR WHICH WAY IT FACES. That is the model's own
	business: `ScrapService` clones the template and stands it on its marker at the size and rotation it
	was saved at in Studio, so scaling or rotating a model there is all it takes.

	There used to be `Size`, `ModelScale` and `ModelRotation` fields doing that job, and they are gone
	rather than deprecated. Two numbers that both claim to control the same thing is how art ends up
	the wrong size with no obvious culprit, and tuning by editing a number and restarting is a much
	worse loop than dragging a handle and looking at it.

	What is left is gameplay: value, weight, how often it spawns, how strong a magnet it needs.
]]
local function scrap(definition: GameTypes.ScrapDefinition): GameTypes.ScrapDefinition
	table.freeze(definition.AreaIds)
	return table.freeze(definition)
end

local scrapById: { [GameTypes.ScrapId]: GameTypes.ScrapDefinition } = {
	MetalCan = scrap({
		Id = "MetalCan",
		DisplayName = "Metal Can",
		Weight = 1,
		BaseValue = 3,
		RequiredMagnetStrength = 1,
		AreaIds = { "FrontYard" },
		SpawnWeight = 30,
		RespawnSeconds = 2.5,
		ModelName = "MetalCan",
	}),
	LooseBolt = scrap({
		Id = "LooseBolt",
		DisplayName = "Loose Bolt",
		Weight = 0.5,
		BaseValue = 2,
		RequiredMagnetStrength = 1,
		AreaIds = { "FrontYard" },
		SpawnWeight = 26,
		RespawnSeconds = 2,
		ModelName = "LooseBolt",
	}),
	SmallMetalPlate = scrap({
		Id = "SmallMetalPlate",
		DisplayName = "Small Metal Plate",
		Weight = 3,
		BaseValue = 9,
		RequiredMagnetStrength = 3,
		AreaIds = { "FrontYard" },
		SpawnWeight = 20,
		RespawnSeconds = 3,
		--[[
			The art is a sheet standing on its EDGE: measured 0.23 x 4.05 x 3.25, so its thin axis is X
			while this declaration says a plate lying down (thin on Y). Ninety degrees about Z brings X
			up to vertical and the sheet lies flat, which is what a dropped plate does.
		]]
		ModelName = "SmallMetalPlate",
	}),
	RustyPipe = scrap({
		Id = "RustyPipe",
		DisplayName = "Rusty Pipe",
		Weight = 2,
		BaseValue = 7,
		RequiredMagnetStrength = 2,
		AreaIds = { "FrontYard" },
		SpawnWeight = 22,
		RespawnSeconds = 3,
		ModelName = "RustyPipe",
	}),
	CrushedBucket = scrap({
		Id = "CrushedBucket",
		DisplayName = "Crushed Bucket",
		Weight = 4,
		BaseValue = 13,
		RequiredMagnetStrength = 4,
		AreaIds = { "FrontYard" },
		SpawnWeight = 16,
		RespawnSeconds = 3.5,
		ModelName = "CrushedBucket",
	}),
	CopperWire = scrap({
		Id = "CopperWire",
		DisplayName = "Copper Wire Coil",
		Weight = 3.5,
		BaseValue = 18,
		RequiredMagnetStrength = 5,
		AreaIds = { "FrontYard" },
		SpawnWeight = 12,
		RespawnSeconds = 4,
		ModelName = "CopperWire",
	}),
	Tire = scrap({
		Id = "Tire",
		DisplayName = "Tire",
		Weight = 6,
		BaseValue = 20,
		RequiredMagnetStrength = 6,
		AreaIds = { "FrontYard", "WorkshopYard" },
		SpawnWeight = 10,
		RespawnSeconds = 5,
		--[[
			Measured 1.03 x 3.00 x 3.01: thin on X, so the tyre is balanced on its rim like a wheel about
			to roll. Ninety degrees about Y lays it down with the hole facing up, matching this
			declaration's thin Z.
		]]
		ModelName = "Tire",
	}),
	BrokenAppliance = scrap({
		Id = "BrokenAppliance",
		DisplayName = "Broken Appliance",
		Weight = 14,
		BaseValue = 55,
		RequiredMagnetStrength = 10,
		AreaIds = { "WorkshopYard" },
		SpawnWeight = 26,
		RespawnSeconds = 5,
		ModelName = "BrokenAppliance",
	}),
	ToolBox = scrap({
		Id = "ToolBox",
		DisplayName = "Busted Tool Box",
		Weight = 10,
		BaseValue = 42,
		RequiredMagnetStrength = 9,
		AreaIds = { "WorkshopYard" },
		SpawnWeight = 24,
		RespawnSeconds = 4.5,
		ModelName = "ToolBox",
	}),
	BrakeDisc = scrap({
		Id = "BrakeDisc",
		DisplayName = "Brake Disc",
		Weight = 12,
		BaseValue = 64,
		RequiredMagnetStrength = 12,
		AreaIds = { "WorkshopYard" },
		SpawnWeight = 20,
		RespawnSeconds = 5.5,
		ModelName = "BrakeDisc",
	}),
	Radiator = scrap({
		Id = "Radiator",
		DisplayName = "Cracked Radiator",
		Weight = 20,
		BaseValue = 105,
		RequiredMagnetStrength = 15,
		AreaIds = { "WorkshopYard" },
		SpawnWeight = 16,
		RespawnSeconds = 6.5,
		ModelName = "Radiator",
	}),
	MotorCoil = scrap({
		Id = "MotorCoil",
		DisplayName = "Motor Coil",
		Weight = 18,
		BaseValue = 118,
		RequiredMagnetStrength = 16,
		AreaIds = { "WorkshopYard" },
		SpawnWeight = 13,
		RespawnSeconds = 7,
		ModelName = "MotorCoil",
	}),
	EnginePart = scrap({
		Id = "EnginePart",
		DisplayName = "Engine Part",
		Weight = 28,
		BaseValue = 135,
		RequiredMagnetStrength = 16,
		AreaIds = { "WorkshopYard", "VehicleGraveyard" },
		SpawnWeight = 18,
		RespawnSeconds = 7,
		ModelName = "EnginePart",
	}),
	CarDoor = scrap({
		Id = "CarDoor",
		DisplayName = "Car Door",
		Weight = 42,
		BaseValue = 240,
		RequiredMagnetStrength = 24,
		AreaIds = { "WorkshopYard", "VehicleGraveyard" },
		SpawnWeight = 9,
		RespawnSeconds = 8,
		ModelName = "CarDoor",
	}),
	ExhaustPipe = scrap({
		Id = "ExhaustPipe",
		DisplayName = "Exhaust Assembly",
		Weight = 35,
		BaseValue = 205,
		RequiredMagnetStrength = 21,
		AreaIds = { "VehicleGraveyard" },
		SpawnWeight = 22,
		RespawnSeconds = 7.5,
		ModelName = "ExhaustPipe",
	}),
	Axle = scrap({
		Id = "Axle",
		DisplayName = "Heavy Axle",
		Weight = 58,
		BaseValue = 360,
		RequiredMagnetStrength = 29,
		AreaIds = { "VehicleGraveyard" },
		SpawnWeight = 16,
		RespawnSeconds = 9,
		ModelName = "Axle",
	}),
	FuelTank = scrap({
		Id = "FuelTank",
		DisplayName = "Dented Fuel Tank",
		Weight = 74,
		BaseValue = 520,
		RequiredMagnetStrength = 35,
		AreaIds = { "VehicleGraveyard" },
		SpawnWeight = 11,
		RespawnSeconds = 10,
		ModelName = "FuelTank",
	}),
	ScrapCar = scrap({
		Id = "ScrapCar",
		DisplayName = "Scrap Car",
		Weight = 160,
		BaseValue = 1250,
		RequiredMagnetStrength = 45,
		AreaIds = { "VehicleGraveyard" },
		SpawnWeight = 5,
		RespawnSeconds = 12,
		ModelName = "ScrapCar",
	}),
}

local variantById: { [GameTypes.VariantId]: GameTypes.VariantDefinition } = {
	Normal = table.freeze({
		Id = "Normal",
		DisplayName = "Normal",
		ValueMultiplier = 1,
		SpawnWeight = 9600,
		LuckExponent = 0,
		Color = Color3.fromRGB(155, 165, 170),
	}),
	Rare = table.freeze({
		Id = "Rare",
		DisplayName = "Rare",
		ValueMultiplier = 2,
		SpawnWeight = 300,
		LuckExponent = 1,
		Color = Color3.fromRGB(73, 157, 255),
		EffectName = "RareShimmer",
	}),
	Epic = table.freeze({
		Id = "Epic",
		DisplayName = "Epic",
		ValueMultiplier = 5,
		SpawnWeight = 80,
		LuckExponent = 1.5,
		Color = Color3.fromRGB(185, 83, 255),
		EffectName = "EpicPulse",
	}),
	Legendary = table.freeze({
		Id = "Legendary",
		DisplayName = "Legendary",
		ValueMultiplier = 15,
		SpawnWeight = 18,
		LuckExponent = 2,
		Color = Color3.fromRGB(255, 188, 46),
		EffectName = "LegendaryBurst",
	}),
	Nebula = table.freeze({
		Id = "Nebula",
		DisplayName = "Nebula",
		ValueMultiplier = 75,
		SpawnWeight = 2,
		LuckExponent = 2.6,
		Color = Color3.fromRGB(90, 255, 225),
		EffectName = "NebulaAura",
	}),
}

return table.freeze({
	ById = table.freeze(scrapById),
	Variants = table.freeze(variantById),
	VariantOrder = table.freeze({ "Normal", "Rare", "Epic", "Legendary", "Nebula" }),
	VariantRollTotal = 10000,
})
