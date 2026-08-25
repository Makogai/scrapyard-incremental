--!strict
--[[
	PitShopConfig.luau
	THE PIT shop: slag in, potions / cash / secret tickets out.

	Slag is earned only inside the Pit while the event is live, and it BANKS across
	weeks so a Friday you miss still leaves last week's currency. The shop lives in
	the Event Area; the server refuses a buy from anyone who is not standing there
	while the arena is open.

	THE CLIENT SENDS AN OFFER ID AND NOTHING ELSE. Prices and grants are read here,
	the same way every other shop in this game works. There is no event pet in this
	list on purpose: titles come from achievements, and a Pit pet stronger than
	Sinister Lord is disallowed. A cosmetic Pit pet can be added later as another
	row the moment the model exists.
]]

export type PitOffer = {
	Id: string,
	DisplayName: string,
	Description: string,
	Glyph: string,
	SlagPrice: number,
	Rewards: {
		Items: { [string]: number }?,
		Money: number?,
		SecretTickets: number?,
	},
}

local function offer(definition: PitOffer): PitOffer
	if definition.Rewards.Items then
		table.freeze(definition.Rewards.Items)
	end
	table.freeze(definition.Rewards)
	return table.freeze(definition)
end

local order = table.freeze({
	"LuckPotion",
	"StrengthPotion",
	"CashPotion",
	"CashSmall",
	"CashBig",
	"SecretTicket",
	"GodPotion",
})

local byId: { [string]: PitOffer } = {
	LuckPotion = offer({
		Id = "LuckPotion",
		DisplayName = "Luck Potion",
		Description = "+30% rare scrap luck for 5 minutes.",
		Glyph = "potion",
		SlagPrice = 40,
		Rewards = { Items = { LuckPotion = 1 } },
	}),
	StrengthPotion = offer({
		Id = "StrengthPotion",
		DisplayName = "Strength Potion",
		Description = "+25% collection speed and +10% range for 5 minutes.",
		Glyph = "potion",
		SlagPrice = 50,
		Rewards = { Items = { StrengthPotion = 1 } },
	}),
	CashPotion = offer({
		Id = "CashPotion",
		DisplayName = "Cash Potion",
		Description = "+20% scrap sale value for 5 minutes.",
		Glyph = "potion",
		SlagPrice = 35,
		Rewards = { Items = { CashPotion = 1 } },
	}),
	CashSmall = offer({
		Id = "CashSmall",
		DisplayName = "Scrap Stash",
		Description = "A crate of scrap cash, paid now.",
		Glyph = "cash",
		SlagPrice = 60,
		Rewards = { Money = 25000 },
	}),
	CashBig = offer({
		Id = "CashBig",
		DisplayName = "Scrap Haul",
		Description = "A much bigger crate of scrap cash.",
		Glyph = "cash",
		SlagPrice = 200,
		Rewards = { Money = 150000 },
	}),
	SecretTicket = offer({
		Id = "SecretTicket",
		DisplayName = "Secret Ticket",
		Description = "One guaranteed Secret roll the next time you hatch.",
		Glyph = "star",
		SlagPrice = 2500,
		Rewards = { SecretTickets = 1 },
	}),
	GodPotion = offer({
		Id = "GodPotion",
		DisplayName = "God Potion",
		Description = "The full burst: cash, luck, strength and spawn.",
		Glyph = "potion",
		SlagPrice = 6000,
		Rewards = { Items = { GodPotion = 1 } },
	}),
}

return table.freeze({
	ById = table.freeze(byId),
	Order = order,
	--- Booth names under `Workspace.Event Area`. Same pattern as Magnet Shop: the
	--- booth model, then its `CHS_Shop` walk-in part. Spawn is not a shop.
	ZoneNames = table.freeze({ "Event Shop", "EventShop", "PitShop", "Pit Shop" }),
	PromptText = "PIT SHOP",
})
