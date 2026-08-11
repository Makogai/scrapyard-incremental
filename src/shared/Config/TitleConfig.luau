--!strict
--[[
	TitleConfig.luau
	Titles: the short line a player wears under their name and in front of their chat.

	A title is the cheapest status symbol a game can ship and one of the strongest. It costs no
	gameplay, it cannot be traded away, and it is visible to everyone else without either player doing
	anything -- which is exactly the property the audit's social section is short of (3.4). Someone
	standing next to you wearing [SCRAP BARON] is an advertisement for a goal you have not reached.

	WHERE THEY COME FROM: achievements, and nothing else. Every title is the reward of one achievement
	in `AchievementConfig`, so "how do I get that" always has an answer a player can read, and there is
	no second unlock path to keep in step. `Source` here is the achievement id, and `tests/` asserts the
	two files agree in both directions -- no title without an achievement, no achievement pointing at a
	title that does not exist.

	RARITY IS PRESENTATION, NOT POWER. It picks the card's colour and the order they sort in. Titles
	grant nothing, and that is deliberate: the moment a title carries a multiplier it stops being a
	badge and becomes an item you are punished for not wearing.
]]

local TitleConfig = {}

export type TitleDefinition = {
	Id: string,
	--- What everyone else reads, in brackets. Kept SHORT: it sits in a chat line and over a head.
	Text: string,
	Rarity: string,
	--- The achievement that awards it.
	Source: string,
}

--[[
	Rarity order and colour, lowest first.

	The keys are `Theme` accent names, resolved by the UI -- this file names a look, it does not import
	one, so it stays usable from the server where `Theme` has no business being required.
]]
local RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

local RARITY_ACCENT = table.freeze({
	Common = "Gray",
	Rare = "Blue",
	Epic = "Purple",
	Legendary = "Gold",
	Mythic = "Pink",
})

TitleConfig.RarityOrder = table.freeze(RARITY_ORDER)
TitleConfig.RarityAccent = RARITY_ACCENT

--[[
	The titles.

	Written to be read out loud by a stranger. Short, concrete, and about something the player DID --
	"SCRAP BARON" lands because it names a scale of hoarding; "ACHIEVEMENT 7" would not.

	The ladder is deliberately uneven. Early ones arrive quickly so a new player learns titles exist at
	all; the top of each track takes a long time so the rare ones stay rare. Nobody should be able to
	collect the set in an evening.
]]
local titles: { TitleDefinition } = {
	--- The first hour.
	table.freeze({ Id = "Newcomer", Text = "NEWCOMER", Rarity = "Common", Source = "FirstSteps" }),
	table.freeze({
		Id = "Collector",
		Text = "COLLECTOR",
		Rarity = "Common",
		Source = "ScrapHundred",
	}),
	table.freeze({
		Id = "Hauler",
		Text = "SCRAP HAULER",
		Rarity = "Common",
		Source = "ScrapThousand",
	}),

	--- The first week.
	table.freeze({
		Id = "Scrapper",
		Text = "SCRAPPER",
		Rarity = "Rare",
		Source = "ScrapTenThousand",
	}),
	table.freeze({ Id = "Reborn", Text = "REBORN", Rarity = "Rare", Source = "FirstRebirth" }),
	table.freeze({ Id = "PetKeeper", Text = "PET KEEPER", Rarity = "Rare", Source = "PetsTen" }),
	table.freeze({ Id = "Regular", Text = "REGULAR", Rarity = "Rare", Source = "StreakSeven" }),
	table.freeze({ Id = "Wanderer", Text = "WANDERER", Rarity = "Rare", Source = "AllAreas" }),

	--- The long haul.
	table.freeze({ Id = "Baron", Text = "SCRAP BARON", Rarity = "Epic", Source = "ScrapMillion" }),
	table.freeze({
		Id = "Archivist",
		Text = "ARCHIVIST",
		Rarity = "Epic",
		Source = "IndexComplete",
	}),
	table.freeze({ Id = "Tycoon", Text = "TYCOON", Rarity = "Epic", Source = "MoneyMillion" }),
	table.freeze({ Id = "Ascended", Text = "ASCENDED", Rarity = "Epic", Source = "RebirthTen" }),
	table.freeze({
		Id = "Devoted",
		Text = "DEVOTED",
		Rarity = "Legendary",
		Source = "StreakThirty",
	}),
	table.freeze({
		Id = "Maxed",
		Text = "FULLY LOADED",
		Rarity = "Legendary",
		Source = "UpgradesMaxed",
	}),

	--[[
		The ceiling. One title nobody has for a long time is worth more to the players who do not have it
		than five they can all reach.
	]]
	table.freeze({
		Id = "Legend",
		Text = "SCRAPYARD LEGEND",
		Rarity = "Mythic",
		Source = "RebirthFifty",
	}),
}

TitleConfig.Titles = table.freeze(titles)

local byId: { [string]: TitleDefinition } = {}
for _, definition in titles do
	byId[definition.Id] = definition
end
TitleConfig.ById = table.freeze(byId)

--- The title a player wears, or nil. Unknown ids resolve to nil so a retired title cannot break a save.
function TitleConfig.resolve(titleId: string?): TitleDefinition?
	if titleId == nil or titleId == "" then
		return nil
	end
	return byId[titleId]
end

--[[
	How a title reads in chat and over a head: `[SCRAP BARON]`.

	One function so the two surfaces cannot format it differently -- the brackets are part of the
	identity, not decoration either caller adds.
]]
function TitleConfig.tag(titleId: string?): string
	local definition = TitleConfig.resolve(titleId)
	if definition == nil then
		return ""
	end
	return `[{definition.Text}]`
end

--- Sort index, so a title list reads worst-to-best rather than in table order.
function TitleConfig.rarityRank(rarity: string): number
	local index = table.find(RARITY_ORDER, rarity)
	return if index then index else 0
end

return table.freeze(TitleConfig)
