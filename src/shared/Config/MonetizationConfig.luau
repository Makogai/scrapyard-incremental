--!strict

-- Replace every MarketplaceId = 0 with the numeric ID created in Creator Dashboard.
-- DisplayPrice is presentation only; Roblox owns and confirms the actual purchase price.
local passes = {
	DoubleCash = table.freeze({
		Id = "DoubleCash",
		MarketplaceId = 0,
		DisplayName = "2x Cash Forever",
		Description = "Doubles every scrap sale permanently.",
		DisplayPrice = 299,
		Color = Color3.fromRGB(255, 174, 42),
	}),
	StoragePlus = table.freeze({
		Id = "StoragePlus",
		MarketplaceId = 0,
		DisplayName = "Mega Storage",
		Description = "Permanently increases magnet storage by 50%.",
		DisplayPrice = 199,
		Color = Color3.fromRGB(40, 204, 218),
	}),
	FastCollector = table.freeze({
		Id = "FastCollector",
		MarketplaceId = 0,
		DisplayName = "Turbo Collector",
		Description = "Permanently doubles collection speed.",
		DisplayPrice = 249,
		Color = Color3.fromRGB(139, 84, 246),
	}),
	QuantumMagnet = table.freeze({
		Id = "QuantumMagnet",
		MarketplaceId = 0,
		DisplayName = "Quantum Magnet",
		Description = "Exclusive 25 strength, 32 range premium magnet.",
		DisplayPrice = 399,
		Color = Color3.fromRGB(255, 76, 167),
	}),
}

local products = {
	CashSmall = table.freeze({
		Id = "CashSmall",
		MarketplaceId = 0,
		DisplayName = "Cash Crate",
		Description = "$25,000 Scrap Cash.",
		DisplayPrice = 49,
		Rewards = table.freeze({ Money = 25000 }),
		Color = Color3.fromRGB(255, 174, 42),
	}),
	CashMedium = table.freeze({
		Id = "CashMedium",
		MarketplaceId = 0,
		DisplayName = "Cash Vault",
		Description = "$150,000 Scrap Cash.",
		DisplayPrice = 149,
		Rewards = table.freeze({ Money = 150000 }),
		Color = Color3.fromRGB(255, 139, 45),
	}),
	CashLarge = table.freeze({
		Id = "CashLarge",
		MarketplaceId = 0,
		DisplayName = "Cash Mountain",
		Description = "$750,000 Scrap Cash.",
		DisplayPrice = 399,
		Rewards = table.freeze({ Money = 750000 }),
		Color = Color3.fromRGB(255, 92, 80),
	}),
	BoosterPair = table.freeze({
		Id = "BoosterPair",
		MarketplaceId = 0,
		DisplayName = "Booster Pair",
		Description = "2 Cash Potions and 2 Strength Potions.",
		DisplayPrice = 79,
		Rewards = table.freeze({ Items = table.freeze({ CashPotion = 2, StrengthPotion = 2 }) }),
		Color = Color3.fromRGB(139, 84, 246),
	}),
	BoosterBundle = table.freeze({
		Id = "BoosterBundle",
		MarketplaceId = 0,
		DisplayName = "Booster Bundle",
		Description = "6 Cash Potions and 6 Strength Potions.",
		DisplayPrice = 199,
		Rewards = table.freeze({ Items = table.freeze({ CashPotion = 6, StrengthPotion = 6 }) }),
		Color = Color3.fromRGB(91, 105, 246),
	}),
	MegaBundle = table.freeze({
		Id = "MegaBundle",
		MarketplaceId = 0,
		DisplayName = "Mega Starter Bundle",
		Description = "$100,000 plus 10 of each potion.",
		DisplayPrice = 299,
		Rewards = table.freeze({
			Money = 100000,
			Items = table.freeze({ CashPotion = 10, StrengthPotion = 10 }),
		}),
		Color = Color3.fromRGB(255, 76, 167),
	}),
}

return table.freeze({
	Passes = table.freeze(passes),
	PassOrder = table.freeze({ "DoubleCash", "StoragePlus", "FastCollector", "QuantumMagnet" }),
	Products = table.freeze(products),
	ProductOrder = table.freeze({
		"CashSmall",
		"CashMedium",
		"CashLarge",
		"BoosterPair",
		"BoosterBundle",
		"MegaBundle",
	}),
})
