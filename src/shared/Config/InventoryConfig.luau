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
		BaseRange = 9,
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
		BaseRange = 15,
		ModelName = "AdvancedMagnet",
		ShopPrice = 60000,
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
	QuantumMagnet = table.freeze({
		Id = "QuantumMagnet",
		DisplayName = "Quantum Magnet",
		Description = "An exclusive premium magnet charged with quantum energy.",
		BaseStrength = 25,
		BaseRange = 22,
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
	CashPotion = table.freeze({
		Id = "CashPotion",
		DisplayName = "Cash Boost Potion",
		Description = "2x scrap sale value for 10 minutes.",
		BoostId = "CashBoost",
		Multiplier = 2,
		DurationSeconds = 600,
		IconId = "rbxassetid://82464105206823",
	}),
	StrengthPotion = table.freeze({
		Id = "StrengthPotion",
		DisplayName = "Magnet Strength Potion",
		Description = "+15 magnet strength for 10 minutes.",
		BoostId = "StrengthBoost",
		Amount = 15,
		DurationSeconds = 600,
		IconId = "rbxassetid://138710304318277",
	}),
	LuckPotion = table.freeze({
		Id = "LuckPotion",
		DisplayName = "Luck Potion",
		Description = "3x rare scrap variant luck for 10 minutes.",
		BoostId = "LuckBoost",
		LuckMultiplier = 3,
		DurationSeconds = 600,
		IconId = "rbxassetid://130250104193544",
	}),
	GodPotion = table.freeze({
		Id = "GodPotion",
		DisplayName = "God Potion",
		Description = "Overwhelming cash, magnet, speed, respawn, and luck power for 10 minutes.",
		BoostId = "GodBoost",
		CashMultiplier = 5,
		StrengthAmount = 100,
		RangeAmount = 15,
		CollectionMultiplier = 3,
		RespawnMultiplier = 0.4,
		LuckMultiplier = 5,
		DurationSeconds = 600,
		IconId = "rbxassetid://73856251621754",
	}),
}

return table.freeze({
	Magnets = table.freeze(magnets),
	MagnetOrder = table.freeze({ "MagnetBasic", "AdvancedMagnet", "QuantumMagnet" }),
	Consumables = table.freeze(consumables),
	ConsumableOrder = table.freeze({ "CashPotion", "StrengthPotion", "LuckPotion", "GodPotion" }),
})
