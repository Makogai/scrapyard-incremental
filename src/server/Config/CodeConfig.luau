--!strict

-- Code text is normalized to uppercase. Keep this server-only so active codes
-- and their rewards are not replicated to clients.
return table.freeze({
	STUDIOKIT = table.freeze({
		Id = "StudioKit_2026",
		Enabled = true,
		StudioOnly = true,
		StartsAt = 0,
		ExpiresAt = 0,
		Rewards = table.freeze({
			Magnets = table.freeze({ "AdvancedMagnet" }),
			Items = table.freeze({ CashPotion = 2, StrengthPotion = 2 }),
			Money = 0,
			Gears = 0,
		}),
	}),
})
