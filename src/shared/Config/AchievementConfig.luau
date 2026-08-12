--!strict
--[[
	AchievementConfig.luau
	Achievements: the long-term goal list, and where every title comes from.

	WHY THE GAME NEEDED THESE. The audit's read (3.6) is that there is no visible long-term goal beyond
	the next upgrade -- rebirth exists but nothing in the HUD builds toward it, and a player who has
	unlocked every area has nothing left to aim at. An achievement list is the cheapest possible answer:
	it turns things players are ALREADY doing into named milestones, and it costs no new gameplay.

	EVERY ACHIEVEMENT IS MEASURED, NEVER FLAGGED. A definition names a `Metric` and a `Threshold`, and
	`AchievementRules` reads the metric straight off the save. Nothing is stored per achievement except
	whether it has been paid out, which means:

		- progress bars come for free, and are always right
		- a player who did the thing before the achievement existed already has it
		- there is no "did you see the event that awards this" bug class at all

	The cost is that an achievement can only exist for something the save already counts. That is a
	feature: it keeps this list honest about what the game actually tracks, and adding a metric is a
	deliberate act with a schema change behind it rather than an afterthought.

	REWARDS ARE SMALL. Cash, gears, a spin, and for the notable ones a title. An achievement list that
	pays well becomes a checklist to grind rather than a record of what you did -- and the titles are
	the real prize, which is the point of them being the only thing you cannot buy.
]]

local AchievementConfig = {}

export type AchievementReward = {
	Money: number?,
	--[[
		Still part of the reward shape -- codes, products and the admin panel grant through it -- but NO
		achievement may use it. Gears are rebirth currency: the only thing that grants them is a rebirth.
		An achievement paying gears used to be a permanent income multiplier, which is why none do now.
	]]
	Gears: number?,
	Spins: number?,
	TitleId: string?,
}

export type AchievementDefinition = {
	Id: string,
	Name: string,
	Description: string,
	Glyph: string,
	Accent: string,
	--- A key `AchievementRules.metric` knows how to read. See that file for the list.
	Metric: string,
	Threshold: number,
	--- Grouping for the UI, and the order tracks appear in.
	Track: string,
	Reward: AchievementReward,
	--- Hidden until earned, for the ones that would spoil something.
	Secret: boolean?,
}

--- Tracks, in display order.
AchievementConfig.Tracks =
	table.freeze({ "Scrap", "Wealth", "Rebirth", "Pets", "Loyalty", "World" })

--[[
	The list.

	Thresholds are set from where the game's own curves put a player, not from round numbers that feel
	tidy: 100 scrap is the first ten minutes, 1,000 is the first session, a million is weeks. The gaps
	widen on purpose so the list keeps producing a "next one" for a very long time.
]]
local achievements: { AchievementDefinition } = {
	--------------------------------------------------------------------------------
	-- Scrap: the core loop
	--------------------------------------------------------------------------------
	table.freeze({
		Id = "FirstSteps",
		Name = "First Steps",
		Description = "Collect your first piece of scrap",
		Glyph = "scrap",
		Accent = "Cyan",
		Metric = "TotalScrapCollected",
		Threshold = 1,
		Track = "Scrap",
		Reward = table.freeze({ Money = 250, TitleId = "Newcomer" }),
	}),
	table.freeze({
		Id = "ScrapHundred",
		Name = "Getting Started",
		Description = "Collect 100 scrap",
		Glyph = "scrap",
		Accent = "Cyan",
		Metric = "TotalScrapCollected",
		Threshold = 100,
		Track = "Scrap",
		Reward = table.freeze({ Money = 2_500, TitleId = "Collector" }),
	}),
	table.freeze({
		Id = "ScrapThousand",
		Name = "Hauling",
		Description = "Collect 1,000 scrap",
		Glyph = "scrap",
		Accent = "Blue",
		Metric = "TotalScrapCollected",
		Threshold = 1_000,
		Track = "Scrap",
		Reward = table.freeze({ Money = 15_000, Spins = 1, TitleId = "Hauler" }),
	}),
	table.freeze({
		Id = "ScrapTenThousand",
		Name = "Yard Veteran",
		Description = "Collect 10,000 scrap",
		Glyph = "scrap",
		Accent = "Purple",
		Metric = "TotalScrapCollected",
		Threshold = 10_000,
		Track = "Scrap",
		Reward = table.freeze({ Money = 120_000, Spins = 2, TitleId = "Scrapper" }),
	}),
	table.freeze({
		Id = "ScrapMillion",
		Name = "Scrap Baron",
		Description = "Collect 1,000,000 scrap",
		Glyph = "scrap",
		Accent = "Gold",
		Metric = "TotalScrapCollected",
		Threshold = 1_000_000,
		Track = "Scrap",
		Reward = table.freeze({ Money = 5_000_000, Spins = 5, TitleId = "Baron" }),
	}),

	--------------------------------------------------------------------------------
	-- Wealth
	--------------------------------------------------------------------------------
	table.freeze({
		Id = "MoneyThousand",
		Name = "Pocket Change",
		Description = "Hold $1,000 at once",
		Glyph = "cash",
		Accent = "Green",
		Metric = "Money",
		Threshold = 1_000,
		Track = "Wealth",
		Reward = table.freeze({ Spins = 1 }),
	}),
	table.freeze({
		Id = "MoneyMillion",
		Name = "Tycoon",
		Description = "Hold $1,000,000 at once",
		Glyph = "cash",
		Accent = "Gold",
		Metric = "Money",
		Threshold = 1_000_000,
		Track = "Wealth",
		Reward = table.freeze({ Spins = 3, TitleId = "Tycoon" }),
	}),
	table.freeze({
		Id = "UpgradesMaxed",
		Name = "Fully Loaded",
		Description = "Reach 150 total upgrade levels",
		Glyph = "upgrade",
		Accent = "Gold",
		Metric = "UpgradeLevelTotal",
		Threshold = 150,
		Track = "Wealth",
		Reward = table.freeze({ Money = 2_000_000, TitleId = "Maxed" }),
	}),

	--------------------------------------------------------------------------------
	-- Rebirth: the prestige ladder the HUD never built toward
	--------------------------------------------------------------------------------
	table.freeze({
		Id = "FirstRebirth",
		Name = "Born Again",
		Description = "Rebirth for the first time",
		Glyph = "prestige",
		Accent = "Pink",
		Metric = "PrestigeCount",
		Threshold = 1,
		Track = "Rebirth",
		Reward = table.freeze({ Money = 50_000, Spins = 2, TitleId = "Reborn" }),
	}),
	table.freeze({
		Id = "RebirthTen",
		Name = "Ascended",
		Description = "Rebirth 10 times",
		Glyph = "prestige",
		Accent = "Purple",
		Metric = "PrestigeCount",
		Threshold = 10,
		Track = "Rebirth",
		Reward = table.freeze({ Money = 1_000_000, Spins = 3, TitleId = "Ascended" }),
	}),
	table.freeze({
		Id = "RebirthFifty",
		Name = "Scrapyard Legend",
		Description = "Rebirth 50 times",
		Glyph = "prestige",
		Accent = "Gold",
		Metric = "PrestigeCount",
		Threshold = 50,
		Track = "Rebirth",
		Reward = table.freeze({ Money = 25_000_000, Spins = 10, TitleId = "Legend" }),
	}),

	--------------------------------------------------------------------------------
	-- Pets
	--------------------------------------------------------------------------------
	table.freeze({
		Id = "FirstPet",
		Name = "Best Friend",
		Description = "Hatch your first pet",
		Glyph = "paw",
		Accent = "Cyan",
		Metric = "PetsOwned",
		Threshold = 1,
		Track = "Pets",
		Reward = table.freeze({ Money = 5_000 }),
	}),
	table.freeze({
		Id = "PetsTen",
		Name = "Pet Keeper",
		Description = "Own 10 pets at once",
		Glyph = "paw",
		Accent = "Blue",
		Metric = "PetsOwned",
		Threshold = 10,
		Track = "Pets",
		Reward = table.freeze({ Money = 75_000, Spins = 1, TitleId = "PetKeeper" }),
	}),
	table.freeze({
		Id = "EggsFifty",
		Name = "Shell Shocked",
		Description = "Open 50 eggs",
		Glyph = "crate",
		Accent = "Purple",
		Metric = "EggsOpened",
		Threshold = 50,
		Track = "Pets",
		Reward = table.freeze({ Money = 250_000 }),
	}),

	--------------------------------------------------------------------------------
	-- Loyalty: the return-to-play systems, given something to build toward
	--------------------------------------------------------------------------------
	table.freeze({
		Id = "StreakSeven",
		Name = "Regular",
		Description = "Reach a 7 day login streak",
		Glyph = "calendar",
		Accent = "Green",
		Metric = "DailyStreak",
		Threshold = 7,
		Track = "Loyalty",
		Reward = table.freeze({ Money = 100_000, Spins = 3, TitleId = "Regular" }),
	}),
	table.freeze({
		Id = "StreakThirty",
		Name = "Devoted",
		Description = "Reach a 30 day login streak",
		Glyph = "calendar",
		Accent = "Gold",
		Metric = "DailyStreak",
		Threshold = 30,
		Track = "Loyalty",
		Reward = table.freeze({ Money = 2_500_000, Spins = 10, TitleId = "Devoted" }),
	}),

	--------------------------------------------------------------------------------
	-- World: everything that is about seeing the game rather than beating it
	--------------------------------------------------------------------------------
	table.freeze({
		Id = "AllAreas",
		Name = "Wanderer",
		Description = "Unlock every area",
		Glyph = "pin",
		Accent = "Cyan",
		Metric = "AreasUnlocked",
		Threshold = 3,
		Track = "World",
		Reward = table.freeze({ Money = 500_000, Spins = 2, TitleId = "Wanderer" }),
	}),
	table.freeze({
		Id = "MagnetsFive",
		Name = "Well Equipped",
		Description = "Own 5 magnets",
		Glyph = "magnet",
		Accent = "Blue",
		Metric = "MagnetsOwned",
		Threshold = 5,
		Track = "World",
		Reward = table.freeze({ Money = 150_000 }),
	}),
	table.freeze({
		Id = "IndexComplete",
		Name = "Archivist",
		Description = "Discover every type of scrap",
		Glyph = "book",
		Accent = "Gold",
		Metric = "ScrapDiscovered",
		--- Set from `AreaConfig`'s scrap list; `tests/` fails if the two drift apart.
		Threshold = 17,
		Track = "World",
		Reward = table.freeze({ Money = 1_500_000, TitleId = "Archivist" }),
	}),
}

AchievementConfig.Definitions = table.freeze(achievements)

local byId: { [string]: AchievementDefinition } = {}
for _, definition in achievements do
	byId[definition.Id] = definition
end
AchievementConfig.ById = table.freeze(byId)

--- How many there are, for "12 / 19" readouts.
AchievementConfig.Count = #achievements

return table.freeze(AchievementConfig)
