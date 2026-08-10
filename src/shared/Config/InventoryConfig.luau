--!strict

local magnets = {
	MagnetBasic = table.freeze({
		Id = "MagnetBasic",
		DisplayName = "Basic Magnet",
		Description = "A dependable starter magnet.",
		BaseStrength = 4,
		BaseRange = 9,
		ModelName = "MagnetBasic",
		IconId = "rbxassetid://79829676084935",
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
