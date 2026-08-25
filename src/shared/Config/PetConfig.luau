--!strict

local GameTypes = require(script.Parent.Parent.Types.GameTypes)

local defaultRarityEffects = {
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
		RarityLuck = 1.10,
	},
	Secret = {
		MagnetStrength = 1.3,
		MagnetRange = 1.25,
		Storage = 1.35,
		MovementSpeed = 1.1,
		CollectionSpeed = 1.3,
		RespawnRate = 1.3,
		RarityLuck = 1.12,
	},
}

--[[
	Workshop: efficiency, storage, collection, respawn.
	Quantum (Vehicle Graveyard): heavy scrap, magnet power, late-game earnings.
	Junkyard keeps `defaultRarityEffects` until that egg is retuned the same way.

	Hatchable RarityLuck stays under Scrap Crimson Knight's +20%. That premium is
	the paid luck pet; a Secret you can hatch must not beat the shop line on the
	stat the shop is selling. Ladder: Rare +6%, Epic +8%, Legendary +10%,
	Junkyard Secret +12%, Workshop Secret +14%, Quantum Secret +16%, Knight +20%.
]]
local eggRarityEffects = {
	WorkshopEgg = {
		Common = { Storage = 1.08, CollectionSpeed = 1.05 },
		Uncommon = { MagnetStrength = 1.10, MagnetRange = 1.07 },
		Rare = { Storage = 1.14, CollectionSpeed = 1.10, RespawnRate = 1.08 },
		Epic = {
			CollectionSpeed = 1.16,
			RespawnRate = 1.14,
			MagnetRange = 1.10,
			RarityLuck = 1.08,
		},
		Legendary = {
			MagnetStrength = 1.24,
			MagnetRange = 1.20,
			CollectionSpeed = 1.22,
			Storage = 1.18,
			RarityLuck = 1.10,
			RespawnRate = 1.14,
		},
		Secret = {
			MagnetStrength = 1.60,
			MagnetRange = 1.35,
			CollectionSpeed = 1.40,
			Storage = 1.40,
			RarityLuck = 1.14,
			RespawnRate = 1.30,
		},
	},
	QuantumEgg = {
		Common = { MagnetStrength = 1.12, Storage = 1.08 },
		Uncommon = { MagnetRange = 1.12, CollectionSpeed = 1.10 },
		Rare = { MagnetStrength = 1.18, Storage = 1.15, RarityLuck = 1.06 },
		Epic = {
			MagnetStrength = 1.22,
			MagnetRange = 1.18,
			CollectionSpeed = 1.18,
			RespawnRate = 1.14,
			RarityLuck = 1.08,
		},
		Legendary = {
			MagnetStrength = 1.35,
			MagnetRange = 1.28,
			CollectionSpeed = 1.28,
			Storage = 1.24,
			RarityLuck = 1.10,
			RespawnRate = 1.20,
		},
		Secret = {
			MagnetStrength = 2.10,
			MagnetRange = 1.50,
			CollectionSpeed = 1.55,
			Storage = 1.55,
			RarityLuck = 1.16,
			RespawnRate = 1.40,
		},
	},
}

local function pet(definition: any): GameTypes.PetDefinition
	local effects
	if type(definition.Effects) == "table" then
		effects = table.clone(definition.Effects)
	elseif definition.Premium == true then
		effects = {}
	else
		local bank = eggRarityEffects[definition.EggId] or defaultRarityEffects
		effects = table.clone(bank[definition.Rarity] or {})
	end
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
	Pet ids stay stable for saves. `ModelName` / `DisplayName` follow the Studio
	model under `Workspace.Pets/<egg folder>/`. Renaming a pet in Studio without
	updating those two fields still works: `PetService` binds leftover models to
	the egg's `PetIds` in roster order. Two models sharing a name (two `Decore`s)
	cannot be told apart by lookup, so they must not share a name.

	Hatchable scrap-value is a contribution toward the +100% team cap, not a
	personal payout. Three equipped egg pets are meant to reach that ceiling
	together; a single Secret must not fill it. Later eggs pay a bit more at the
	same rarity. Premium cash still adds after the cap.

		Common / Uncommon / Rare / Epic / Legendary / Secret
		Junkyard   +8  / +12 / +16 / +22 / +30 / +40
		Workshop   +10 / +14 / +18 / +26 / +34 / +44
		Quantum    +12 / +16 / +20 / +28 / +38 / +50
]]
local pets = {
	-- Front Yard Egg (id stays JunkyardEgg): Common through Secret, in roll order.
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
		MoneyMultiplier = 1.12,
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
		MoneyMultiplier = 1.16,
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
		MoneyMultiplier = 1.22,
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
		MoneyMultiplier = 1.30,
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
		MoneyMultiplier = 1.40,
		ModelName = "Mythic Autumn Dragon",
		IconAssetId = "",
		FallbackColor = rarityColors.Secret,
	}),
	-- Workshop Egg
	WrenchMouse = pet({
		Id = "WrenchMouse",
		DisplayName = "Yin Yang",
		EggId = "WorkshopEgg",
		Rarity = "Common",
		RollWeight = 5500,
		MoneyMultiplier = 1.10,
		ModelName = "Yin Yang",
		IconAssetId = "",
		FallbackColor = rarityColors.Common,
	}),
	SpringFrog = pet({
		Id = "SpringFrog",
		DisplayName = "Skull Reaper",
		EggId = "WorkshopEgg",
		Rarity = "Uncommon",
		RollWeight = 2500,
		MoneyMultiplier = 1.14,
		ModelName = "Skull Reaper",
		IconAssetId = "",
		FallbackColor = rarityColors.Uncommon,
	}),
	WelderBear = pet({
		Id = "WelderBear",
		DisplayName = "Advocate",
		EggId = "WorkshopEgg",
		Rarity = "Rare",
		RollWeight = 1200,
		MoneyMultiplier = 1.18,
		ModelName = "Advocate",
		IconAssetId = "",
		FallbackColor = rarityColors.Rare,
	}),
	MotorMole = pet({
		Id = "MotorMole",
		DisplayName = "Glitch",
		EggId = "WorkshopEgg",
		Rarity = "Epic",
		RollWeight = 600,
		MoneyMultiplier = 1.26,
		ModelName = "Glitch",
		IconAssetId = "",
		FallbackColor = rarityColors.Epic,
	}),
	ChromeWolf = pet({
		Id = "ChromeWolf",
		DisplayName = "Rainbow Shock",
		EggId = "WorkshopEgg",
		Rarity = "Legendary",
		RollWeight = 180,
		MoneyMultiplier = 1.34,
		ModelName = "Rainbow Shock",
		IconAssetId = "",
		FallbackColor = rarityColors.Legendary,
	}),
	CoreDragon = pet({
		Id = "CoreDragon",
		DisplayName = "Luminance",
		EggId = "WorkshopEgg",
		Rarity = "Secret",
		RollWeight = 20,
		MoneyMultiplier = 1.44,
		ModelName = "Luminance",
		IconAssetId = "",
		FallbackColor = rarityColors.Secret,
	}),
	-- Quantum Egg (Vehicle Graveyard)
	NeonCrab = pet({
		Id = "NeonCrab",
		DisplayName = "Fracture",
		EggId = "QuantumEgg",
		Rarity = "Common",
		RollWeight = 5500,
		MoneyMultiplier = 1.12,
		ModelName = "Fracture",
		IconAssetId = "",
		FallbackColor = rarityColors.Common,
	}),
	CircuitOwl = pet({
		Id = "CircuitOwl",
		DisplayName = "Decore",
		EggId = "QuantumEgg",
		Rarity = "Uncommon",
		RollWeight = 2500,
		MoneyMultiplier = 1.16,
		ModelName = "Decore",
		IconAssetId = "",
		FallbackColor = rarityColors.Uncommon,
	}),
	PlasmaPanda = pet({
		Id = "PlasmaPanda",
		DisplayName = "Immortal One",
		EggId = "QuantumEgg",
		Rarity = "Rare",
		RollWeight = 1200,
		MoneyMultiplier = 1.20,
		ModelName = "Immortal One",
		IconAssetId = "",
		FallbackColor = rarityColors.Rare,
	}),
	MagnetManta = pet({
		Id = "MagnetManta",
		DisplayName = "Radiance",
		EggId = "QuantumEgg",
		Rarity = "Epic",
		RollWeight = 600,
		MoneyMultiplier = 1.28,
		ModelName = "Radiance",
		IconAssetId = "",
		FallbackColor = rarityColors.Epic,
	}),
	NovaLion = pet({
		Id = "NovaLion",
		DisplayName = "Nova Lion",
		EggId = "QuantumEgg",
		Rarity = "Legendary",
		RollWeight = 180,
		MoneyMultiplier = 1.38,
		ModelName = "Nova Lion",
		IconAssetId = "",
		FallbackColor = rarityColors.Legendary,
	}),
	--[[
		Premium ladder, 499 / 699 / 999. Each pet sells a different job so a player
		who buys two is not paying twice for the same stat.

		Singularity is the limited cash + pull pet. It does not have luck, storage,
		respawn, or walk speed -- those belong to Knight and Lord. Cash is ×8, not
		×20, so equipping it with Lord does not print another ×20 on top.

		Scrap Crimson Knight is the yard-quality pet: luck, respawn, storage.

		Sinister Lord is the permanent flagship. Best magnet of the three, real cash
		that is still under Singularity's ×8, plus walk speed which neither other
		premium has. Luck stays a ribbon under Knight's +20%.
	]]
	Singularity = pet({
		Id = "Singularity",
		DisplayName = "Singularity",
		EggId = "Premium",
		Rarity = "Secret",
		RollWeight = 0,
		MoneyMultiplier = 8,
		Premium = true,
		Effects = {
			MagnetStrength = 4,
			CollectionSpeed = 1.20,
			MagnetRange = 1.15,
		},
		Description = "×8 scrap value, +300% magnet strength, +20% collection speed, +15% range.",
		ModelName = "Singularity",
		IconAssetId = "",
		FallbackColor = rarityColors.Secret,
	}),
	NebulaLeviathan = pet({
		Id = "NebulaLeviathan",
		DisplayName = "The OwOlord",
		EggId = "QuantumEgg",
		Rarity = "Secret",
		RollWeight = 20,
		MoneyMultiplier = 1.50,
		ModelName = "The OwOlord",
		IconAssetId = "",
		FallbackColor = rarityColors.Secret,
	}),
	DemonicGhost = pet({
		Id = "DemonicGhost",
		DisplayName = "Scrap Crimson Knight",
		EggId = "Premium",
		Rarity = "Secret",
		RollWeight = 0,
		MoneyMultiplier = 1.40,
		Premium = true,
		Effects = {
			RarityLuck = 1.20,
			RespawnRate = 1.30,
			Storage = 1.20,
			CollectionSpeed = 1.10,
		},
		Description = "+40% scrap value, +20% luck, +30% respawn speed, +20% storage, +10% collection speed.",
		--- Studio instance on FeaturedPodium is spelled Chrimson; the display name is not.
		ModelName = "Scrap Chrimson Knight",
		IconAssetId = "",
		FallbackColor = Color3.fromRGB(255, 70, 92),
	}),
	SinisterLord = pet({
		Id = "SinisterLord",
		DisplayName = "Sinister Lord",
		EggId = "Premium",
		Rarity = "Secret",
		RollWeight = 0,
		MoneyMultiplier = 5,
		Premium = true,
		Effects = {
			MagnetStrength = 5,
			CollectionSpeed = 1.30,
			MagnetRange = 1.30,
			MovementSpeed = 1.18,
			RarityLuck = 1.08,
		},
		Description = "×5 scrap value, +400% magnet strength, +30% collection speed, +30% range, +18% walk speed, +8% luck.",
		--- Studio instance on FeaturedPodium is all-caps; the display name is not.
		ModelName = "SINISTER LORD",
		IconAssetId = "",
		FallbackColor = Color3.fromRGB(174, 45, 255),
	}),
}

local eggs = {
	JunkyardEgg = table.freeze({
		Id = "JunkyardEgg",
		DisplayName = "Front Yard Egg",
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
		DisplayName = "Vehicle Graveyard Egg",
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
		number wrong. A compact pet like Pup fills the longest-axis box in every
		direction, so at 1 it reads bigger than a long zebra or dragon. Dragons
		go the other way. Anything absent is treated as 1.
	]]
	FollowerScale = table.freeze({
		Pup = 0.7,
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
