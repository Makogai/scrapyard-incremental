--!strict
--[[
	InventoryConfig.luau
	Magnets and consumables.

	`RangeRing` is how each magnet draws its reach on the ground, and it escalates deliberately:

		Basic       one hairline ring, one slow pulse drawn inward
		Advanced    two rings, a faint disc, a quicker pulse
		Quantum     two rings, a disc, two pulses, and a sweep travelling round the edge

	So an upgrade is visible before you read a stat, and the starter magnet is the quietest thing on the
	floor rather than a glowing dinner plate.

	THE PULSES TRAVEL INWARD, and that direction is the whole point. A ring expanding outward reads as
	radar -- something being emitted, looking for things. A ring collapsing toward the player reads as
	attraction, which is what a magnet actually does, and it is the cheapest way to say "everything in here
	comes to me" without a single extra glowing surface. `PulseSeconds` is how long one takes to fall in;
	`PulseRings` is how many are in flight at once, staggered evenly.

	`Accent` names a `Theme.Color` rather than carrying a `Color3`, the same way `TitleConfig.accent` does.
	The palette belongs to the theme; a gameplay config that hardcodes a colour is a second place for the
	game's colours to live and drift.

	A magnet with no `RangeRing` still draws one -- `MagnetRangeController` falls back to the Basic look --
	so adding a magnet cannot produce an invisible reach indicator.
]]

local magnets = {
	MagnetBasic = table.freeze({
		Id = "MagnetBasic",
		DisplayName = "Basic Magnet",
		Description = "A dependable starter magnet.",
		BaseStrength = 4,
		BaseRange = 5,
		ModelName = "MagnetBasic",
		IconId = "rbxassetid://79829676084935",
		--- The quietest of the three: a single thin line, nothing inside it, one unhurried pulse.
		RangeRing = table.freeze({
			Accent = "Cyan",
			Fill = 0,
			Rim = 0.16,
			SecondRim = 0,
			Sweep = false,
			PulseSeconds = 2.6,
			PulseRings = 1,
		}),
	}),
	AdvancedMagnet = table.freeze({
		Id = "AdvancedMagnet",
		DisplayName = "Advanced Magnet",
		Description = "A tuned magnet with stronger pull and wider reach.",
		BaseStrength = 12,
		BaseRange = 7,
		ModelName = "AdvancedMagnet",
		--[[
			$250,000, up from $60,000.

			Priced so buying it is a REAL decision rather than an obvious one: at this price it costs about
			a fifth of the Graveyard unlock, so taking it delays the next area noticeably. Magnets survive
			rebirth, which is what makes paying that worthwhile.
		]]
		ShopPrice = 250000,
		IconId = "",
		--- A double line, the first hint of a fill, and a pull that visibly works faster.
		RangeRing = table.freeze({
			Accent = "Green",
			Fill = 0.05,
			Rim = 0.2,
			SecondRim = 0.1,
			Sweep = false,
			PulseSeconds = 2,
			PulseRings = 1,
		}),
	}),
	--[[
		THE TOP CASH MAGNET, and it exists to create one decision.

		The economy design wanted a $3,000,000 magnet priced ABOVE the $2,000,000 rebirth, so a player
		reaching that point has a real choice: prestige now, or grind another million for something that
		survives the prestige. Magnets are permanent through rebirth, which is the whole reason the choice
		is interesting rather than obvious.

		It was going to be the Quantum, but the Quantum is a Robux game pass and stays one -- Robux should
		still buy the strongest magnet in the game. So this sits between them: clearly better than the
		Advanced, clearly weaker than the Quantum, and reachable without spending.

		`RequiredArea` gates it on having DISCOVERED the Vehicle Graveyard, not on currently owning it --
		area unlocks reset on rebirth and this does not, so the requirement is "you have been there".
	]]
	SalvageMagnet = table.freeze({
		Id = "SalvageMagnet",
		DisplayName = "Salvage Magnet",
		Description = "Industrial-grade coil. The strongest magnet scrap cash can buy.",
		BaseStrength = 20,
		BaseRange = 8,
		ModelName = "SalvageMagnet",
		ShopPrice = 3000000,
		RequiredArea = "VehicleGraveyard",
		IconId = "",
	}),
	QuantumMagnet = table.freeze({
		Id = "QuantumMagnet",
		DisplayName = "Quantum Magnet",
		Description = "An exclusive premium magnet charged with quantum energy.",
		BaseStrength = 25,
		BaseRange = 9,
		ModelName = "QuantumMagnet",
		Premium = true,
		IconId = "",
		--[[
			The premium one, and the only one that moves.

			A sweep rather than a brighter ring: brightness is what makes an indicator imposing, and this
			has to stay quiet while still being obviously the good magnet. Motion reads as "powered" at an
			opacity where more glow would just be in the way.
		]]
		RangeRing = table.freeze({
			Accent = "Purple",
			Fill = 0.07,
			Rim = 0.22,
			SecondRim = 0.12,
			Sweep = true,
			PulseSeconds = 1.6,
			PulseRings = 2,
		}),
	}),
}

local consumables = {
	--[[
		POTIONS ARE SHORTER AND WEAKER THAN THEY WERE, on purpose.

		They used to be 10 minutes at 2x-5x, which is long and strong enough that being potioned is the
		normal state and being un-potioned is the punishment. At 5 minutes and +20-30% they are a burst you
		spend deliberately, and the playtime ladder can hand several out without becoming the economy.

		Same-type potions extend DURATION rather than multiplying (see `TryUseConsumable`); different types
		multiply. That is what makes stacking a Cash, Luck and Spawn potion together the interesting move.
	]]
	CashPotion = table.freeze({
		Id = "CashPotion",
		DisplayName = "Cash Boost Potion",
		Description = "+20% scrap sale value for 5 minutes.",
		BoostId = "CashBoost",
		Multiplier = 1.2,
		DurationSeconds = 300,
		IconId = "rbxassetid://82464105206823",
	}),
	StrengthPotion = table.freeze({
		Id = "StrengthPotion",
		DisplayName = "Magnet Strength Potion",
		Description = "+25% collection speed and +10% range for 5 minutes.",
		BoostId = "StrengthBoost",
		Amount = 6,
		CollectionMultiplier = 1.25,
		RangeMultiplier = 1.1,
		DurationSeconds = 300,
		IconId = "rbxassetid://138710304318277",
	}),
	LuckPotion = table.freeze({
		Id = "LuckPotion",
		DisplayName = "Luck Potion",
		Description = "+30% rare scrap luck for 5 minutes.",
		BoostId = "LuckBoost",
		LuckMultiplier = 1.3,
		DurationSeconds = 300,
		IconId = "rbxassetid://130250104193544",
	}),
	--[[
		NEW. The proposal wanted a Spawn Rate potion because it is the one that multiplies the value of the
		others: more spawns is more rarity rolls, so Spawn plus Luck is worth more than either alone. That
		combination is the reason to hold potions for a moment rather than drinking them on pickup.
	]]
	SpawnPotion = table.freeze({
		Id = "SpawnPotion",
		DisplayName = "Spawn Potion",
		Description = "+20% scrap respawn rate for 5 minutes.",
		BoostId = "SpawnBoost",
		RespawnMultiplier = 0.8,
		DurationSeconds = 300,
		IconId = "",
	}),
	GodPotion = table.freeze({
		Id = "GodPotion",
		DisplayName = "God Potion",
		Description = "Everything at once for 10 minutes.",
		BoostId = "GodBoost",
		CashMultiplier = 1.75,
		StrengthAmount = 25,
		RangeAmount = 2,
		CollectionMultiplier = 1.5,
		RespawnMultiplier = 0.7,
		LuckMultiplier = 2,
		DurationSeconds = 600,
		IconId = "rbxassetid://73856251621754",
	}),
}

return table.freeze({
	Magnets = table.freeze(magnets),
	MagnetOrder = table.freeze({
		"MagnetBasic",
		"AdvancedMagnet",
		"SalvageMagnet",
		"QuantumMagnet",
	}),
	Consumables = table.freeze(consumables),
	ConsumableOrder = table.freeze({
		"CashPotion",
		"StrengthPotion",
		"LuckPotion",
		"SpawnPotion",
		"GodPotion",
	}),
})
