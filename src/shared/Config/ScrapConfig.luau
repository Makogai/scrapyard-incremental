--!strict

local GameTypes = require(script.Parent.Parent.Types.GameTypes)

--[[
	VALUES WERE REBASED ~5-15x IN THE ECONOMY PASS. See `plan/ECONOMY_REBALANCE.md`.

	The old table ran $2-$1,250, which meant the Front Yard paid in single digits and every price in the
	game had to be tiny to match. It now runs $45-$1,750, tuned so the weighted average of each area comes
	out near $90 / $464 / $1,146 a scrap once the rarity roll is applied -- which, at the ~52 pieces a
	minute a travelling player actually collects, puts Workshop at ~16 minutes, the Graveyard at ~35 and
	the first rebirth at ~68.

	The spread narrowed a lot doing this: cheapest to dearest went from 625x to 39x. That is deliberate in
	the design it came from -- every scrap type can roll every rarity, so the RARITY is meant to carry the
	excitement rather than the type -- but it does mean a Graveyard player picking up a CarDoor earns only
	19x what a beginner gets from a MetalCan.

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
		BaseValue = 45,
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
		BaseValue = 55,
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
		BaseValue = 70,
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
		BaseValue = 85,
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
		BaseValue = 100,
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
		BaseValue = 120,
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
		BaseValue = 200,
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
		BaseValue = 240,
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
		BaseValue = 290,
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
		BaseValue = 350,
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
		BaseValue = 430,
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
		BaseValue = 610,
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
		BaseValue = 700,
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
		BaseValue = 850,
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
		BaseValue = 1000,
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
		BaseValue = 1150,
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
		BaseValue = 1350,
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
		BaseValue = 1750,
		RequiredMagnetStrength = 45,
		AreaIds = { "VehicleGraveyard" },
		SpawnWeight = 5,
		RespawnSeconds = 12,
		ModelName = "ScrapCar",
	}),
	--[[
		THE PIT'S OWN SCRAP. Never on a plot: `AreaIds` is empty and `PitOnly` is the flag
		`ScrapService` / the validator both read. Strength is the ticket -- you can SEE a Robot
		Arm on the floor with a starter magnet, and the reject flash is the reason to come back
		next Friday with a better one.
	]]
	Drone = scrap({
		Id = "Drone",
		DisplayName = "Drone",
		Weight = 8,
		BaseValue = 420,
		RequiredMagnetStrength = 8,
		AreaIds = {},
		SpawnWeight = 40,
		RespawnSeconds = 5,
		ModelName = "Drone",
		PitOnly = true,
		SlagValue = 2,
	}),
	Submarine = scrap({
		Id = "Submarine",
		DisplayName = "Submarine",
		Weight = 32,
		BaseValue = 1600,
		RequiredMagnetStrength = 16,
		AreaIds = {},
		SpawnWeight = 28,
		RespawnSeconds = 7,
		ModelName = "Submarine",
		PitOnly = true,
		SlagValue = 5,
	}),
	LavaCoreScrap = scrap({
		Id = "LavaCoreScrap",
		DisplayName = "Lava Core",
		Weight = 55,
		BaseValue = 3400,
		RequiredMagnetStrength = 28,
		AreaIds = {},
		SpawnWeight = 18,
		RespawnSeconds = 9,
		ModelName = "LavaCoreScrap",
		PitOnly = true,
		SlagValue = 10,
	}),
	RobotArm = scrap({
		Id = "RobotArm",
		DisplayName = "Robot Arm",
		Weight = 95,
		BaseValue = 9000,
		RequiredMagnetStrength = 50,
		AreaIds = {},
		SpawnWeight = 8,
		RespawnSeconds = 12,
		--[[
			Studio name has a space. `ScrapVariants` and `ServerStorage.ScrapModels` both look
			up `ModelName` exactly, so this must match the authored instance.
		]]
		ModelName = "Robot Arm",
		PitOnly = true,
		SlagValue = 25,
	}),
}

--[[
	Rarity odds are weights out of VariantRollTotal (100,000), so the percentages below are exact.

	Normal 93.825% / Rare 5% / Epic 1% / Legendary 0.15% / Nebula 0.025%.
	Payouts: ×1 / ×2 / ×4 / ×8 / ×25.

	Luck does not change Normal's weight. It raises every other tier by luck^LuckExponent and then the
	roll is re-normalised, so invested luck shrinks Normal's share rather than minting extra pieces.
]]
local variantById: { [GameTypes.VariantId]: GameTypes.VariantDefinition } = {
	Normal = table.freeze({
		Id = "Normal",
		DisplayName = "Normal",
		ValueMultiplier = 1,
		SpawnWeight = 93825,
		LuckExponent = 0,
		Color = Color3.fromRGB(155, 165, 170),
	}),
	Rare = table.freeze({
		Id = "Rare",
		DisplayName = "Rare",
		ValueMultiplier = 2,
		SpawnWeight = 5000,
		LuckExponent = 1,
		Color = Color3.fromRGB(73, 157, 255),
		EffectName = "RareShimmer",
	}),
	Epic = table.freeze({
		Id = "Epic",
		DisplayName = "Epic",
		ValueMultiplier = 4,
		SpawnWeight = 1000,
		LuckExponent = 1.5,
		Color = Color3.fromRGB(185, 83, 255),
		EffectName = "EpicPulse",
	}),
	Legendary = table.freeze({
		Id = "Legendary",
		DisplayName = "Legendary",
		ValueMultiplier = 8,
		SpawnWeight = 150,
		LuckExponent = 2,
		Color = Color3.fromRGB(255, 188, 46),
		EffectName = "LegendaryBurst",
	}),
	Nebula = table.freeze({
		Id = "Nebula",
		DisplayName = "Nebula",
		ValueMultiplier = 25,
		SpawnWeight = 25,
		LuckExponent = 2.6,
		Color = Color3.fromRGB(90, 255, 225),
		EffectName = "NebulaAura",
	}),
}

return table.freeze({
	--[[
		How far Spawn Rate may compress a respawn, as a fraction of the scrap's own interval.

		A proportional floor rather than an absolute one -- see `ScrapService.reserve`. At 0.42 a fully
		invested player roughly halves every timer and the ordering between cheap and expensive scrap
		survives.
	]]
	--[[
		HOW MUCH STORAGE ONE PIECE OF SCRAP TAKES. One slot, whatever it is and whatever rarity it rolled.

		Storage used to be measured in WEIGHT, and `Weight` still exists per scrap -- it ran 0.5 for a bolt
		to 160 for a scrap car. That made a lucky drop a PUNISHMENT: finding a Nebula scrap car filled a
		third of your bag, so the best moment in the game was also the one that sent you back to the
		crusher. Weight also made "storage full" unpredictable, because the same 25 pickups could fill a
		bag or barely touch it.

		One slot each means the counter on the HUD is the number of things you are carrying, which is what
		a player assumes it means anyway.

		`Weight` is kept in the config. It is no longer read for storage, but it is real data about the
		scrap and the obvious input for anything later that wants to care -- a vehicle, a conveyor, a
		carry-speed penalty.
	]]
	SlotsPerScrap = 1,
	MinimumRespawnFraction = 0.42,
	--[[
		How long an uncollected piece may sit before it despawns and a new random one takes its
		place. Collection respawn is unchanged -- this is only so a pile you walk past does not
		stay the same cans forever. Spread is a fraction of the wait, so a whole pile does not
		pop at once. Arena scrap is not refreshed this way.

		80 seconds, not ~20: the first pass left pieces vanishing while you were still walking
		across the yard.
	]]
	IdleRefreshSeconds = 80,
	IdleRefreshSpread = 0.2,
	--[[
		The highest total luck multiplier that may feed the rarity exponents.

		Rarity weights are `weight x luck ^ exponent` with 2.6 on Nebula, so luck compounds much faster
		than it reads. Every source multiplies -- upgrade, potion, event, pets, rebirths -- and no single
		one of them looks unreasonable, which is exactly why the ceiling belongs on the product rather
		than on any of them.

		At the cap of 6, Nebula is about 1 in 66 from a 0.025% base. That is still a jackpot a heavily
		invested player sees a few times an hour.
	]]
	MaximumLuckMultiplier = 6,
	--[[
		Pit-only ids, in strength order. The collection index appends this after the plot
		areas so a Drone is not listed as Front Yard scrap, and achievements that ask
		"have they found every Pit piece" walk this list rather than guessing.
	]]
	PitOrder = table.freeze({ "Drone", "Submarine", "LavaCoreScrap", "RobotArm" }),
	ById = table.freeze(scrapById),
	Variants = table.freeze(variantById),
	VariantOrder = table.freeze({ "Normal", "Rare", "Epic", "Legendary", "Nebula" }),
	VariantRollTotal = 100000,
})
