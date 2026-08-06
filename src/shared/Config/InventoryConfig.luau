--!strict

local magnets = {
	MagnetBasic = table.freeze({
		Id = "MagnetBasic",
		DisplayName = "Basic Magnet",
		Description = "A dependable starter magnet.",
		BaseStrength = 4,
		BaseRange = 18,
		ModelName = "MagnetBasic",
	}),
	AdvancedMagnet = table.freeze({
		Id = "AdvancedMagnet",
		DisplayName = "Advanced Magnet",
		Description = "A tuned magnet with stronger pull and wider reach.",
		BaseStrength = 12,
		BaseRange = 24,
		ModelName = "AdvancedMagnet",
		ShopPrice = 5000,
	}),
	QuantumMagnet = table.freeze({
		Id = "QuantumMagnet",
		DisplayName = "Quantum Magnet",
		Description = "An exclusive premium magnet charged with quantum energy.",
		BaseStrength = 25,
		BaseRange = 32,
		ModelName = "QuantumMagnet",
		Premium = true,
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
	}),
	StrengthPotion = table.freeze({
		Id = "StrengthPotion",
		DisplayName = "Strength Boost Potion",
		Description = "+15 magnet strength for 10 minutes.",
		BoostId = "StrengthBoost",
		Amount = 15,
		DurationSeconds = 600,
	}),
}

return table.freeze({
	Magnets = table.freeze(magnets),
	MagnetOrder = table.freeze({ "MagnetBasic", "AdvancedMagnet", "QuantumMagnet" }),
	Consumables = table.freeze(consumables),
	ConsumableOrder = table.freeze({ "CashPotion", "StrengthPotion" }),
})
