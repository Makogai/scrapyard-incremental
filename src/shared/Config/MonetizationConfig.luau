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
	--[[
		PERMANENT DOUBLE WALK SPEED, applied in `derivedStats` alongside the MovementSpeed upgrade.

		A multiplier rather than a flat bonus, so it keeps mattering as the upgrade climbs -- and it is
		applied BEFORE the upgrade's `EffectCap`, which is what stops the pass from being silently eaten by
		a cap the player has already reached.
	]]
	PermanentSpeed = table.freeze({
		Id = "PermanentSpeed",
		MarketplaceId = 0,
		DisplayName = "2x Walk Speed",
		Description = "Move twice as fast, permanently. Stacks with your speed upgrade.",
		DisplayPrice = 199,
		Color = Color3.fromRGB(105, 232, 92),
	}),
	ExtraPetSlots = table.freeze({
		Id = "ExtraPetSlots",
		MarketplaceId = 0,
		DisplayName = "+2 Pet Slots",
		Description = "Equip two additional pets permanently (maximum five).",
		DisplayPrice = 249,
		Color = Color3.fromRGB(91, 214, 246),
	}),
	--[[
		MULTI-HATCH. Sold as passes rather than products because the value is permanent convenience --
		a consumable "open three times" would be a worse deal for the player AND a worse business: this
		is bought once and then used on every egg for the life of the account.

		Priced under the pet passes on purpose. These buy TIME, not power: three hatches cost three
		times the cash either way, so a player who buys this still pays full price for every pet. That
		is what makes it fair to sell at all.
	]]
	TripleHatch = table.freeze({
		Id = "TripleHatch",
		MarketplaceId = 0,
		DisplayName = "Triple Hatch",
		Description = "Open three eggs at once, forever. Costs three eggs' cash.",
		DisplayPrice = 199,
		Color = Color3.fromRGB(91, 214, 246),
	}),
	PentaHatch = table.freeze({
		Id = "PentaHatch",
		MarketplaceId = 0,
		DisplayName = "Penta Hatch",
		Description = "Open five eggs at once, forever. Costs five eggs' cash.",
		DisplayPrice = 349,
		Color = Color3.fromRGB(139, 84, 246),
	}),
	SingularityPet = table.freeze({
		Id = "SingularityPet",
		MarketplaceId = 0,
		DisplayName = "Singularity Pet",
		Description = "Copies twice the effects of your strongest equipped normal pet.",
		DisplayPrice = 499,
		Color = Color3.fromRGB(49, 224, 255),
		--[[
			LIMITED TO 500 COPIES, GLOBALLY.

			`LimitedStockService` owns the count -- a DataStore `UpdateAsync`, because a per-server counter
			would sell the last copy on every server at once. The reserve happens BEFORE the grant, and a
			failed reserve refuses the sale: overselling a limited item cannot be undone, while a refused
			purchase is retried by Roblox and costs the player nothing.
		]]
		StockLimit = 500,
	}),
	DemonicGhostPet = table.freeze({
		Id = "DemonicGhostPet",
		MarketplaceId = 0,
		DisplayName = "Demonic Ghost Pet",
		Description = "Increases every combined pet bonus by 35%.",
		DisplayPrice = 699,
		Color = Color3.fromRGB(255, 65, 88),
	}),
	SinisterLordPet = table.freeze({
		Id = "SinisterLordPet",
		MarketplaceId = 0,
		DisplayName = "Sinister Lord Pet",
		Description = "Ultimate premium pet that doubles all combined pet bonuses.",
		DisplayPrice = 999,
		Color = Color3.fromRGB(171, 54, 255),
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
	--[[
		Spin packs. Prices set from the reference: one spin at 59 R$, three at 120 R$ -- the three-pack is
		deliberately better per spin, because a pack that saves nothing is a pack nobody buys.

		`MarketplaceId` is still 0, like every other entry: see `docs/STORE_SETUP.md`. The wheel shows
		these buttons and they will prompt correctly the moment the ids land.
	]]
	SpinOne = table.freeze({
		Id = "SpinOne",
		MarketplaceId = 0,
		DisplayName = "1 Spin",
		Description = "One extra spin of the lucky wheel.",
		DisplayPrice = 59,
		Color = Color3.fromRGB(181, 48, 255),
		Rewards = table.freeze({ Spins = 1 }),
	}),
	SpinThree = table.freeze({
		Id = "SpinThree",
		MarketplaceId = 0,
		DisplayName = "3 Spins",
		Description = "Three extra spins of the lucky wheel.",
		DisplayPrice = 120,
		Color = Color3.fromRGB(181, 48, 255),
		Rewards = table.freeze({ Spins = 3 }),
	}),
	SkipRebirth = table.freeze({
		Id = "SkipRebirth",
		MarketplaceId = 0,
		DisplayName = "Instant Rebirth",
		Description = "Completes one rebirth immediately without the cash requirement.",
		DisplayPrice = 149,
		Rewards = table.freeze({ SpecialAction = "SkipPrestige" }),
		Color = Color3.fromRGB(255, 91, 184),
	}),
}

return table.freeze({
	Passes = table.freeze(passes),
	PassOrder = table.freeze({
		"DoubleCash",
		"StoragePlus",
		"FastCollector",
		"QuantumMagnet",
		"ExtraPetSlots",
		"TripleHatch",
		"PentaHatch",
		"SingularityPet",
		"DemonicGhostPet",
		"SinisterLordPet",
	}),
	Products = table.freeze(products),
	ProductOrder = table.freeze({
		"CashSmall",
		"CashMedium",
		"CashLarge",
		"BoosterPair",
		"BoosterBundle",
		"MegaBundle",
		"SpinOne",
		"SpinThree",
		"SkipRebirth",
	}),
})
