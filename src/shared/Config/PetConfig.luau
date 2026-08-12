--!strict

local GameTypes = require(script.Parent.Parent.Types.GameTypes)

local rarityEffects = {
	Common = { MagnetStrength = 1.03 },
	Uncommon = { MagnetRange = 1.05, MovementSpeed = 1.02 },
	Rare = { Storage = 1.08, CollectionSpeed = 1.06, MagnetStrength = 1.06 },
	Epic = { MagnetStrength = 1.1, MagnetRange = 1.1, RespawnRate = 1.08, RarityLuck = 1.08 },
	Legendary = {
		MagnetStrength = 1.16,
		MagnetRange = 1.15,
		Storage = 1.18,
		CollectionSpeed = 1.14,
		RespawnRate = 1.14,
		RarityLuck = 1.18,
	},
	Secret = {
		MagnetStrength = 1.3,
		MagnetRange = 1.25,
		Storage = 1.35,
		MovementSpeed = 1.1,
		CollectionSpeed = 1.3,
		RespawnRate = 1.3,
		RarityLuck = 1.4,
	},
}

local function pet(definition: any): GameTypes.PetDefinition
	local effects = table.clone(rarityEffects[definition.Rarity] or {})
	effects.Cash = definition.MoneyMultiplier
	definition.Effects = table.freeze(effects)
	definition.Description = definition.Description
		or `{definition.DisplayName} boosts cash and {definition.Rarity:lower()}-tier utility stats.`
	return table.freeze(definition :: GameTypes.PetDefinition)
end

local rarityColors = table.freeze({
	Common = Color3.fromRGB(174, 188, 202),
	Uncommon = Color3.fromRGB(91, 214, 126),
	Rare = Color3.fromRGB(71, 154, 255),
	Epic = Color3.fromRGB(178, 91, 246),
	Legendary = Color3.fromRGB(255, 183, 48),
	Secret = Color3.fromRGB(255, 75, 148),
})

--[[
	Pet ids match the model names authored under `Workspace.Pets/<Egg DisplayName>/`,
	so `PetService.publishPetModels` finds each one by `ModelName`. Renaming a pet
	here without renaming the model leaves it with no model to render.
]]
local pets = {
	-- Junkyard Egg: Common through Secret, in roll order.
	Pup = pet({
		Id = "Pup",
		DisplayName = "Pup",
		EggId = "JunkyardEgg",
		Rarity = "Common",
		RollWeight = 5500,
		MoneyMultiplier = 1.08,
		ModelName = "Pup",
		IconAssetId = "",
		FallbackColor = rarityColors.Common,
	}),
	Zebra = pet({
		Id = "Zebra",
		DisplayName = "Zebra",
		EggId = "JunkyardEgg",
		Rarity = "Uncommon",
		RollWeight = 2500,
		MoneyMultiplier = 1.16,
		ModelName = "Zebra",
		IconAssetId = "",
		FallbackColor = rarityColors.Uncommon,
	}),
	QueenKitty = pet({
		Id = "QueenKitty",
		DisplayName = "Queen Kitty",
		EggId = "JunkyardEgg",
		Rarity = "Rare",
		RollWeight = 1200,
		MoneyMultiplier = 1.28,
		ModelName = "Queen Kitty",
		IconAssetId = "",
		FallbackColor = rarityColors.Rare,
	}),
	PastelAngel = pet({
		Id = "PastelAngel",
		DisplayName = "Pastel Angel",
		EggId = "JunkyardEgg",
		Rarity = "Epic",
		RollWeight = 600,
		MoneyMultiplier = 1.5,
		ModelName = "Pastel Angel",
		IconAssetId = "",
		FallbackColor = rarityColors.Epic,
	}),
	AutumnDragon = pet({
		Id = "AutumnDragon",
		DisplayName = "Autumn Dragon",
		EggId = "JunkyardEgg",
		Rarity = "Legendary",
		RollWeight = 180,
		MoneyMultiplier = 2,
		ModelName = "Autumn Dragon",
		IconAssetId = "",
		FallbackColor = rarityColors.Legendary,
	}),
	MythicAutumnDragon = pet({
		Id = "MythicAutumnDragon",
		DisplayName = "Mythic Autumn Dragon",
		EggId = "JunkyardEgg",
		Rarity = "Secret",
		RollWeight = 20,
		MoneyMultiplier = 4,
		ModelName = "Mythic Autumn Dragon",
		IconAssetId = "",
		FallbackColor = rarityColors.Secret,
	}),
	-- Workshop Egg
	WrenchMouse = pet({
		Id = "WrenchMouse",
		DisplayName = "Wrench Mouse",
		EggId = "WorkshopEgg",
		Rarity = "Common",
		RollWeight = 5500,
		MoneyMultiplier = 1.22,
		ModelName = "WrenchMouse",
		IconAssetId = "",
		FallbackColor = rarityColors.Common,
	}),
	SpringFrog = pet({
		Id = "SpringFrog",
		DisplayName = "Spring Frog",
		EggId = "WorkshopEgg",
		Rarity = "Uncommon",
		RollWeight = 2500,
		MoneyMultiplier = 1.38,
		ModelName = "SpringFrog",
		IconAssetId = "",
		FallbackColor = rarityColors.Uncommon,
	}),
	WelderBear = pet({
		Id = "WelderBear",
		DisplayName = "Welder Bear",
		EggId = "WorkshopEgg",
		Rarity = "Rare",
		RollWeight = 1200,
		MoneyMultiplier = 1.65,
		ModelName = "WelderBear",
		IconAssetId = "",
		FallbackColor = rarityColors.Rare,
	}),
	MotorMole = pet({
		Id = "MotorMole",
		DisplayName = "Motor Mole",
		EggId = "WorkshopEgg",
		Rarity = "Epic",
		RollWeight = 600,
		MoneyMultiplier = 2.1,
		ModelName = "MotorMole",
		IconAssetId = "",
		FallbackColor = rarityColors.Epic,
	}),
	ChromeWolf = pet({
		Id = "ChromeWolf",
		DisplayName = "Chrome Wolf",
		EggId = "WorkshopEgg",
		Rarity = "Legendary",
		RollWeight = 180,
		MoneyMultiplier = 3,
		ModelName = "ChromeWolf",
		IconAssetId = "",
		FallbackColor = rarityColors.Legendary,
	}),
	CoreDragon = pet({
		Id = "CoreDragon",
		DisplayName = "Core Dragon",
		EggId = "WorkshopEgg",
		Rarity = "Secret",
		RollWeight = 20,
		MoneyMultiplier = 6,
		ModelName = "CoreDragon",
		IconAssetId = "",
		FallbackColor = rarityColors.Secret,
	}),
	-- Quantum Egg
	NeonCrab = pet({
		Id = "NeonCrab",
		DisplayName = "Neon Crab",
		EggId = "QuantumEgg",
		Rarity = "Common",
		RollWeight = 5500,
		MoneyMultiplier = 1.65,
		ModelName = "NeonCrab",
		IconAssetId = "",
		FallbackColor = rarityColors.Common,
	}),
	CircuitOwl = pet({
		Id = "CircuitOwl",
		DisplayName = "Circuit Owl",
		EggId = "QuantumEgg",
		Rarity = "Uncommon",
		RollWeight = 2500,
		MoneyMultiplier = 2,
		ModelName = "CircuitOwl",
		IconAssetId = "",
		FallbackColor = rarityColors.Uncommon,
	}),
	PlasmaPanda = pet({
		Id = "PlasmaPanda",
		DisplayName = "Plasma Panda",
		EggId = "QuantumEgg",
		Rarity = "Rare",
		RollWeight = 1200,
		MoneyMultiplier = 2.6,
		ModelName = "PlasmaPanda",
		IconAssetId = "",
		FallbackColor = rarityColors.Rare,
	}),
	MagnetManta = pet({
		Id = "MagnetManta",
		DisplayName = "Magnet Manta",
		EggId = "QuantumEgg",
		Rarity = "Epic",
		RollWeight = 600,
		MoneyMultiplier = 3.5,
		ModelName = "MagnetManta",
		IconAssetId = "",
		FallbackColor = rarityColors.Epic,
	}),
	NovaLion = pet({
		Id = "NovaLion",
		DisplayName = "Nova Lion",
		EggId = "QuantumEgg",
		Rarity = "Legendary",
		RollWeight = 180,
		MoneyMultiplier = 5,
		ModelName = "NovaLion",
		IconAssetId = "",
		FallbackColor = rarityColors.Legendary,
	}),
	Singularity = pet({
		Id = "Singularity",
		DisplayName = "Singularity",
		EggId = "Premium",
		Rarity = "Secret",
		RollWeight = 0,
		MoneyMultiplier = 1,
		Premium = true,
		Ability = "CopyStrongestPet",
		AbilityPower = 2,
		Description = "Copies twice the bonus effects of your strongest equipped non-premium pet.",
		ModelName = "Singularity",
		IconAssetId = "",
		FallbackColor = rarityColors.Secret,
	}),
	NebulaLeviathan = pet({
		Id = "NebulaLeviathan",
		DisplayName = "Nebula Leviathan",
		EggId = "QuantumEgg",
		Rarity = "Secret",
		RollWeight = 20,
		MoneyMultiplier = 8,
		ModelName = "NebulaLeviathan",
		IconAssetId = "",
		FallbackColor = rarityColors.Secret,
	}),
	DemonicGhost = pet({
		Id = "DemonicGhost",
		DisplayName = "Demonic Ghost",
		EggId = "Premium",
		Rarity = "Secret",
		RollWeight = 0,
		MoneyMultiplier = 2.5,
		Premium = true,
		Ability = "AmplifyPetBonuses",
		AbilityPower = 1.35,
		Description = "Boosts all combined pet bonuses by 35%, with powerful cash and rarity effects.",
		ModelName = "DemonicGhost",
		IconAssetId = "",
		FallbackColor = Color3.fromRGB(255, 70, 92),
	}),
	SinisterLord = pet({
		Id = "SinisterLord",
		DisplayName = "Sinister Lord",
		EggId = "Premium",
		Rarity = "Secret",
		RollWeight = 0,
		MoneyMultiplier = 3,
		Premium = true,
		Ability = "AmplifyPetBonuses",
		AbilityPower = 2,
		Description = "The ultimate pet: doubles every combined pet bonus while equipped.",
		ModelName = "SinisterLord",
		IconAssetId = "",
		FallbackColor = Color3.fromRGB(174, 45, 255),
	}),
}

local eggs = {
	JunkyardEgg = table.freeze({
		Id = "JunkyardEgg",
		DisplayName = "Junkyard Egg",
		Price = 4000,
		RequiredArea = "FrontYard",
		ModelName = "JunkyardEgg",
		IconAssetId = "",
		PetIds = table.freeze({
			"Pup",
			"Zebra",
			"QueenKitty",
			"PastelAngel",
			"AutumnDragon",
			"MythicAutumnDragon",
		}),
	}),
	WorkshopEgg = table.freeze({
		Id = "WorkshopEgg",
		DisplayName = "Workshop Egg",
		Price = 35000,
		RequiredArea = "WorkshopYard",
		ModelName = "WorkshopEgg",
		IconAssetId = "",
		PetIds = table.freeze({
			"WrenchMouse",
			"SpringFrog",
			"WelderBear",
			"MotorMole",
			"ChromeWolf",
			"CoreDragon",
		}),
	}),
	QuantumEgg = table.freeze({
		Id = "QuantumEgg",
		DisplayName = "Quantum Egg",
		Price = 220000,
		RequiredArea = "VehicleGraveyard",
		ModelName = "QuantumEgg",
		IconAssetId = "",
		PetIds = table.freeze({
			"NeonCrab",
			"CircuitOwl",
			"PlasmaPanda",
			"MagnetManta",
			"NovaLion",
			"NebulaLeviathan",
		}),
	}),
}

--[[
	How many eggs one press may open, and which entitlement unlocks each count.

	Ordered largest-first so a player who owns both passes gets the bigger one offered. The count is
	also the COST multiplier -- see `TryOpenEgg` -- so nothing here is a discount.
]]
local hatchBatches = {
	table.freeze({ Count = 5, Entitlement = "PentaHatch" }),
	table.freeze({ Count = 3, Entitlement = "TripleHatch" }),
}

return table.freeze({
	HatchBatches = table.freeze(hatchBatches),
	Pets = table.freeze(pets),
	Eggs = table.freeze(eggs),
	EggOrder = table.freeze({ "JunkyardEgg", "WorkshopEgg", "QuantumEgg" }),
	PremiumOrder = table.freeze({ "Singularity", "DemonicGhost", "SinisterLord" }),
	RarityColors = rarityColors,
	RollTotal = 10000,
	--[[
		THREE from the start, up from two; upgrades and the pass add to this.

		Three is the number the pet bonuses are balanced around -- the design's tiers assume three equipped
		free pets when it caps the combined cash bonus at +100%. At two, a player could never reach the
		ceiling the economy was tuned against.
	]]
	BaseEquipSlots = 3,

	--[[
		How big a pet stands in the world, in studs along its longest axis. This is
		the one number to turn if followers feel too big or too small overall.
	]]
	FollowerLongestAxis = 2.4,

	--[[
		Per-pet multipliers on that, for models whose proportions make the shared
		number wrong -- a long dragon reads as huge at the same longest-axis size a
		compact pup reads as fine. 1 means "use the shared value"; anything absent is
		treated as 1.
	]]
	FollowerScale = table.freeze({
		Pup = 1,
		Zebra = 1,
		QueenKitty = 1,
		PastelAngel = 0.9,
		AutumnDragon = 0.85,
		MythicAutumnDragon = 0.85,
	}),
	BaseStorageCapacity = 50,
	SlotUpgradeCosts = table.freeze({ 25000, 175000 }),
	MaximumSlotUpgradeLevel = 2,
	PassBonusSlots = 2,
	MaximumOwnedPerPet = 999,
	LegendaryPityRolls = 50,
	SecretPityRolls = 500,
})
