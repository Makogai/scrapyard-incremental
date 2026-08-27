--!strict
--[[
	GearShopConfig.luau
	THE GEAR SHOP: rebirth currency in, persist-through-wipe power out.

	Gears have no passive income. They are earned on prestige, they survive prestige,
	and they are spent here. Every row is either a permanent rank (it is still there
	after the next wipe) or a one-shot grant. Nothing here multiplies scrap cash, and
	nothing skips a rebirth -- Skip Rebirth is a Robux product.

	THE CLIENT SENDS AN OFFER ID AND NOTHING ELSE. Prices, ranks and effects are
	read here, the same way Magnet Shop and the Pit shop work.
]]

export type GearOfferKind = "Upgrade" | "Consumable"

export type GearOffer = {
	Id: string,
	DisplayName: string,
	Description: string,
	Glyph: string,
	Kind: GearOfferKind,
	RequiredPrestige: number,
	MaxLevel: number?,
	Costs: { number }?,
	GearPrice: number?,
	Rewards: {
		SecretTickets: number?,
	}?,
}

local function offer(definition: GearOffer): GearOffer
	if definition.Costs then
		table.freeze(definition.Costs)
	end
	if definition.Rewards then
		table.freeze(definition.Rewards)
	end
	return table.freeze(definition)
end

local order = table.freeze({
	"HeadStart",
	"NestEgg",
	"DeepPockets",
	"PetSlot",
	"ScrapSense",
	"HatchLuck",
	"SecretTicket",
})

local byId: { [string]: GearOffer } = {
	HeadStart = offer({
		Id = "HeadStart",
		DisplayName = "Head Start",
		Description = "+1 upgrade start after rebirth",
		Glyph = "upgrade",
		Kind = "Upgrade",
		RequiredPrestige = 1,
		MaxLevel = 5,
		Costs = { 1, 2, 4, 7, 12 },
	}),
	NestEgg = offer({
		Id = "NestEgg",
		DisplayName = "Nest Egg",
		Description = "+$2.5K / $15K / $75K start cash",
		Glyph = "coin",
		Kind = "Upgrade",
		RequiredPrestige = 1,
		MaxLevel = 3,
		Costs = { 2, 5, 10 },
	}),
	DeepPockets = offer({
		Id = "DeepPockets",
		DisplayName = "Deep Pockets",
		Description = "+8 scrap storage",
		Glyph = "bag",
		Kind = "Upgrade",
		RequiredPrestige = 2,
		MaxLevel = 3,
		Costs = { 3, 6, 12 },
	}),
	PetSlot = offer({
		Id = "PetSlot",
		DisplayName = "Companion Bay",
		Description = "+1 pet slot",
		Glyph = "paw",
		Kind = "Upgrade",
		RequiredPrestige = 2,
		MaxLevel = 1,
		Costs = { 8 },
	}),
	ScrapSense = offer({
		Id = "ScrapSense",
		DisplayName = "Scrap Sense",
		Description = "+8% scrap luck",
		Glyph = "star",
		Kind = "Upgrade",
		RequiredPrestige = 4,
		MaxLevel = 3,
		Costs = { 8, 16, 28 },
	}),
	HatchLuck = offer({
		Id = "HatchLuck",
		DisplayName = "Egg Fortune",
		Description = "+rare egg luck",
		Glyph = "pet",
		Kind = "Upgrade",
		RequiredPrestige = 5,
		MaxLevel = 4,
		Costs = { 12, 22, 36, 55 },
	}),
	SecretTicket = offer({
		Id = "SecretTicket",
		DisplayName = "Secret Ticket",
		Description = "1 guaranteed Secret",
		Glyph = "star",
		Kind = "Consumable",
		RequiredPrestige = 5,
		--[[
			THE JACKPOT ROW. A ticket skips Secret pity (500 rolls). It has to cost more than
			maxing Egg Fortune, or players buy Secrets instead of the luck tree. A rebirth at
			this unlock still pays a handful of Gears unless they overfarm, so 80 is many
			rebirths of saving -- or one fat overdrive at a high rebirth.
		]]
		GearPrice = 80,
		Rewards = { SecretTickets = 1 },
	}),
}

local StartingCashByLevel = table.freeze({ 2500, 15000, 75000 })

local GearShopConfig = {
	ById = table.freeze(byId),
	Order = order,
	PromptText = "GEAR SHOP",
	StorageSlotsPerLevel = 8,
	ScrapSenseLuckPerLevel = 0.08,
	HatchLuckSkipPerLevel = 800,
	StartingCashByLevel = StartingCashByLevel,
}

function GearShopConfig.nextPrice(definition: GearOffer, currentLevel: number): number?
	if definition.Kind == "Consumable" then
		return definition.GearPrice
	end
	local costs = definition.Costs
	local maximum = definition.MaxLevel or 0
	if costs == nil or currentLevel < 0 or currentLevel >= maximum then
		return nil
	end
	return costs[currentLevel + 1]
end

function GearShopConfig.isUnlocked(definition: GearOffer, prestigeCount: number): boolean
	return math.max(0, math.floor(prestigeCount)) >= definition.RequiredPrestige
end

function GearShopConfig.rank(levels: { [string]: number }?, offerId: string): number
	local tableLevels = levels or {}
	local definition = byId[offerId]
	local raw = math.max(0, math.floor(tableLevels[offerId] or 0))
	if definition == nil or definition.Kind ~= "Upgrade" then
		return raw
	end
	return math.min(raw, definition.MaxLevel or 0)
end

function GearShopConfig.startingCash(level: number): number
	local rank = math.max(0, math.floor(level))
	if rank <= 0 then
		return 0
	end
	return StartingCashByLevel[math.min(rank, #StartingCashByLevel)] or 0
end

return table.freeze(GearShopConfig)
