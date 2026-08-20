--!strict

-- Replace every MarketplaceId = 0 with the numeric ID created in Creator Dashboard.
-- DisplayPrice is presentation only; Roblox owns and confirms the actual purchase price.
local passes = {
	DoubleCash = table.freeze({
		Id = "DoubleCash",
		MarketplaceId = 1947940451,
		DisplayName = "2x Cash Forever",
		Description = "Doubles every scrap sale permanently.",
		DisplayPrice = 299,
		Color = Color3.fromRGB(255, 174, 42),
	}),
	StoragePlus = table.freeze({
		Id = "StoragePlus",
		MarketplaceId = 1954030419,
		DisplayName = "Mega Storage",
		Description = "Permanently increases magnet storage by 50%.",
		DisplayPrice = 199,
		Color = Color3.fromRGB(40, 204, 218),
	}),
	FastCollector = table.freeze({
		Id = "FastCollector",
		MarketplaceId = 1947958385,
		DisplayName = "Turbo Collector",
		Description = "Permanently doubles collection speed.",
		DisplayPrice = 249,
		Color = Color3.fromRGB(139, 84, 246),
	}),
	QuantumMagnet = table.freeze({
		Id = "QuantumMagnet",
		MarketplaceId = 1949650433,
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
		MarketplaceId = 1947910351,
		DisplayName = "2x Walk Speed",
		Description = "Move twice as fast, permanently. Stacks with your speed upgrade.",
		DisplayPrice = 199,
		Color = Color3.fromRGB(105, 232, 92),
	}),
	--[[
		AUTO SELL, sold from a pad on the plot.

		Sells the load the moment storage fills, so the walk to the crusher stops being mandatory. Priced
		at the top of the convenience passes because it removes a whole loop rather than speeding one up.

		Note what it does NOT do: it does not raise income. A player with this earns the same per piece as
		one without -- they just stop walking. That is what keeps it a convenience purchase rather than a
		pay-to-win one.
	]]
	AutoSell = table.freeze({
		Id = "AutoSell",
		MarketplaceId = 1948420346,
		DisplayName = "Auto Sell",
		Description = "Your scrap sells itself the moment your storage fills. No more trips to the crusher.",
		DisplayPrice = 299,
		Color = Color3.fromRGB(105, 232, 92),
	}),
	--[[
		LAVA PLOT SKIN, one pass for every area.

		ONE PURCHASE, THREE MODELS. `Workspace.PlotSkins` holds a lava build of each area, and owning this
		pass makes the plot wear whichever one matches the area you have converted to. Selling it per-area
		would have charged three times for one cosmetic idea and left a player who rebirths back to the Front
		Yard looking at a plot they had already paid to reskin.

		Purely cosmetic: the plot is rebuilt from a different model and nothing about income, capacity or rate
		changes. Premium-cosmetic tier -- a skin you look at for hours is worth more than a convenience that
		saves you a walk, and less than a pass that changes the numbers.
	]]
	LavaSkin = table.freeze({
		Id = "LavaSkin",
		MarketplaceId = 1948606430,
		DisplayName = "Lava Skin",
		Description = "Reskin your plot as cracked volcanic rock with molten lava running through it. Applies to every area you unlock.",
		DisplayPrice = 399,
		Color = Color3.fromRGB(255, 116, 46),
	}),
	ExtraPetSlots = table.freeze({
		Id = "ExtraPetSlots",
		MarketplaceId = 1951701001,
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
		MarketplaceId = 1951012380,
		DisplayName = "Triple Hatch",
		Description = "Open three eggs at once, forever. Costs three eggs' cash.",
		DisplayPrice = 199,
		Color = Color3.fromRGB(91, 214, 246),
	}),
	PentaHatch = table.freeze({
		Id = "PentaHatch",
		MarketplaceId = 1948108474,
		DisplayName = "Penta Hatch",
		Description = "Open five eggs at once, forever. Costs five eggs' cash.",
		DisplayPrice = 349,
		Color = Color3.fromRGB(139, 84, 246),
	}),
	SingularityPet = table.freeze({
		Id = "SingularityPet",
		MarketplaceId = 1949722487,
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
		MarketplaceId = 1952894699,
		DisplayName = "Demonic Ghost Pet",
		Description = "Increases every combined pet bonus by 35%.",
		DisplayPrice = 699,
		Color = Color3.fromRGB(255, 65, 88),
	}),
	SinisterLordPet = table.freeze({
		Id = "SinisterLordPet",
		MarketplaceId = 1952486693,
		DisplayName = "Sinister Lord Pet",
		Description = "Ultimate premium pet that doubles all combined pet bonuses.",
		DisplayPrice = 999,
		Color = Color3.fromRGB(171, 54, 255),
	}),
}

local products = {
	--[[
		BUY A LEVEL WITH ROBUX -- one product per upgrade.

		It has to be one product each, because a developer product carries no parameters: the thing bought IS
		the id. `UpgradeId` maps back to which upgrade a receipt raises, so `GrantDeveloperProduct` needs no
		second lookup table to fall out of step with this one.

		`MarketplaceId = 0` on all of them until they are created in the Creator Dashboard. A product with an
		id of 0 cannot be prompted, so the button refuses politely rather than erroring -- see
		`MonetizationService`.

		The level is granted FREE OF CASH COST but still respects the level cap: Robux buys you a level you
		could have bought, not a level the cap says does not exist yet.
	]]
	RobuxUpgradeMagnetStrength = table.freeze({
		Id = "RobuxUpgradeMagnetStrength",
		MarketplaceId = 3709007431,
		DisplayName = "Magnet Strength +1",
		Description = "Instantly add one level of Magnet Strength, no scrap cash needed.",
		DisplayPrice = 29,
		--- Which upgrade a purchase of this product raises. Read by `GrantDeveloperProduct`.
		UpgradeId = "MagnetStrength",
	}),
	RobuxUpgradeMagnetRange = table.freeze({
		Id = "RobuxUpgradeMagnetRange",
		MarketplaceId = 3709007781,
		DisplayName = "Magnet Range +1",
		Description = "Instantly add one level of Magnet Range, no scrap cash needed.",
		DisplayPrice = 29,
		--- Which upgrade a purchase of this product raises. Read by `GrantDeveloperProduct`.
		UpgradeId = "MagnetRange",
	}),
	RobuxUpgradeStorageCapacity = table.freeze({
		Id = "RobuxUpgradeStorageCapacity",
		MarketplaceId = 3709007999,
		DisplayName = "Storage Capacity +1",
		Description = "Instantly add one level of Storage Capacity, no scrap cash needed.",
		DisplayPrice = 29,
		--- Which upgrade a purchase of this product raises. Read by `GrantDeveloperProduct`.
		UpgradeId = "StorageCapacity",
	}),
	RobuxUpgradeMovementSpeed = table.freeze({
		Id = "RobuxUpgradeMovementSpeed",
		MarketplaceId = 3709008682,
		DisplayName = "Walk Speed +1",
		Description = "Instantly add one level of Walk Speed, no scrap cash needed.",
		DisplayPrice = 29,
		--- Which upgrade a purchase of this product raises. Read by `GrantDeveloperProduct`.
		UpgradeId = "MovementSpeed",
	}),
	RobuxUpgradeScrapValue = table.freeze({
		Id = "RobuxUpgradeScrapValue",
		MarketplaceId = 3709008341,
		DisplayName = "Scrap Value +1",
		Description = "Instantly add one level of Scrap Value, no scrap cash needed.",
		DisplayPrice = 29,
		--- Which upgrade a purchase of this product raises. Read by `GrantDeveloperProduct`.
		UpgradeId = "ScrapValue",
	}),
	RobuxUpgradeCollectionSpeed = table.freeze({
		Id = "RobuxUpgradeCollectionSpeed",
		MarketplaceId = 3709008390,
		DisplayName = "Collection Speed +1",
		Description = "Instantly add one level of Collection Speed, no scrap cash needed.",
		DisplayPrice = 29,
		--- Which upgrade a purchase of this product raises. Read by `GrantDeveloperProduct`.
		UpgradeId = "CollectionSpeed",
	}),
	RobuxUpgradeScrapFlow = table.freeze({
		Id = "RobuxUpgradeScrapFlow",
		MarketplaceId = 3709008986,
		DisplayName = "Scrap Flow +1",
		Description = "Instantly add one level of Scrap Flow, no scrap cash needed.",
		DisplayPrice = 29,
		--- Which upgrade a purchase of this product raises. Read by `GrantDeveloperProduct`.
		UpgradeId = "ScrapFlow",
	}),
	RobuxUpgradeRarity = table.freeze({
		Id = "RobuxUpgradeRarity",
		MarketplaceId = 3709010272,
		DisplayName = "Rarity Luck +1",
		Description = "Instantly add one level of Rarity Luck, no scrap cash needed.",
		DisplayPrice = 29,
		--- Which upgrade a purchase of this product raises. Read by `GrantDeveloperProduct`.
		UpgradeId = "Rarity",
	}),

	CashSmall = table.freeze({
		Id = "CashSmall",
		MarketplaceId = 3709010369,
		DisplayName = "Cash Crate",
		Description = "$25,000 Scrap Cash.",
		DisplayPrice = 49,
		Rewards = table.freeze({ Money = 25000 }),
		Color = Color3.fromRGB(255, 174, 42),
	}),
	CashMedium = table.freeze({
		Id = "CashMedium",
		MarketplaceId = 3709010483,
		DisplayName = "Cash Vault",
		Description = "$150,000 Scrap Cash.",
		DisplayPrice = 149,
		Rewards = table.freeze({ Money = 150000 }),
		Color = Color3.fromRGB(255, 139, 45),
	}),
	CashLarge = table.freeze({
		Id = "CashLarge",
		MarketplaceId = 3709010648,
		DisplayName = "Cash Mountain",
		Description = "$750,000 Scrap Cash.",
		DisplayPrice = 399,
		Rewards = table.freeze({ Money = 750000 }),
		Color = Color3.fromRGB(255, 92, 80),
	}),
	BoosterPair = table.freeze({
		Id = "BoosterPair",
		MarketplaceId = 3709010725,
		DisplayName = "Booster Pair",
		Description = "2 Cash Potions and 2 Strength Potions.",
		DisplayPrice = 79,
		Rewards = table.freeze({ Items = table.freeze({ CashPotion = 2, StrengthPotion = 2 }) }),
		Color = Color3.fromRGB(139, 84, 246),
	}),
	BoosterBundle = table.freeze({
		Id = "BoosterBundle",
		MarketplaceId = 3709010787,
		DisplayName = "Booster Bundle",
		Description = "6 Cash Potions and 6 Strength Potions.",
		DisplayPrice = 199,
		Rewards = table.freeze({ Items = table.freeze({ CashPotion = 6, StrengthPotion = 6 }) }),
		Color = Color3.fromRGB(91, 105, 246),
	}),
	MegaBundle = table.freeze({
		Id = "MegaBundle",
		MarketplaceId = 3709010852,
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
		MarketplaceId = 3709010920,
		DisplayName = "1 Spin",
		Description = "One extra spin of the lucky wheel.",
		DisplayPrice = 59,
		Color = Color3.fromRGB(181, 48, 255),
		Rewards = table.freeze({ Spins = 1 }),
	}),
	SpinThree = table.freeze({
		Id = "SpinThree",
		MarketplaceId = 3709011127,
		DisplayName = "3 Spins",
		Description = "Three extra spins of the lucky wheel.",
		DisplayPrice = 120,
		Color = Color3.fromRGB(181, 48, 255),
		Rewards = table.freeze({ Spins = 3 }),
	}),
	SkipRebirth = table.freeze({
		Id = "SkipRebirth",
		MarketplaceId = 3709011192,
		DisplayName = "Instant Rebirth",
		Description = "Completes one rebirth immediately without the cash requirement.",
		DisplayPrice = 149,
		Rewards = table.freeze({ SpecialAction = "SkipPrestige" }),
		Color = Color3.fromRGB(255, 91, 184),
	}),
}

return table.freeze({
	Passes = table.freeze(passes),
	--[[
		THE SHOP RENDERS THIS LIST, not `Passes`. A pass missing from here exists, is priced, is buyable
		from its own Roblox page -- and is invisible in game. `PermanentSpeed` and `AutoSell` were both
		missing exactly that way, which is why `tests/run.luau` now asserts the two agree.
	]]
	PassOrder = table.freeze({
		"DoubleCash",
		"StoragePlus",
		"FastCollector",
		"QuantumMagnet",
		"PermanentSpeed",
		"AutoSell",
		"LavaSkin",
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
