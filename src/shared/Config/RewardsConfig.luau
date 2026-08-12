--!strict
--[[
	RewardsConfig.luau
	Everything that hands the player something for showing up rather than for playing well:
	the daily calendar, playtime milestones, the spin wheel, and the friend boost.

	One file because these four all answer the same question -- "why come back tomorrow" -- and
	they all grant through the same `PlayerStateService.GrantRewards` path, so a reward here has
	the same shape everywhere:

		{ Money = number?, Gears = number?, Items = { [itemId]: count }?, Spins = number? }

	See `docs/GAME_AUDIT.md` for why these exist and what they are measured against.
]]

--------------------------------------------------------------------------------
-- Daily rewards
--------------------------------------------------------------------------------

--[[
	A seven-day calendar that loops. Day 7 is deliberately the big one, and the STREAK is the
	part that does the work: a reward you lose by missing a day is what turns intent into habit.

	`StreakBonusPerDay` multiplies the cash on the day you claim, capped, so a long streak is
	worth protecting without making day 1 of a new streak feel worthless.
]]
local dailyDays = {
	table.freeze({ Day = 1, Money = 500, Glyph = "cash", Accent = "Green", Label = "$500" }),
	table.freeze({
		Day = 2,
		Items = table.freeze({ CashPotion = 1 }),
		Glyph = "potion",
		Accent = "Gold",
		Label = "Cash Potion",
	}),
	table.freeze({ Day = 3, Money = 2500, Glyph = "cash", Accent = "Green", Label = "$2,500" }),
	table.freeze({
		Day = 4,
		Items = table.freeze({ LuckPotion = 1 }),
		Glyph = "potion",
		Accent = "Purple",
		Label = "Luck Potion",
	}),
	table.freeze({ Day = 5, Money = 12000, Glyph = "cash", Accent = "Green", Label = "$12,000" }),
	--- `wheel`, not `star`: spins ARE the wheel, and the star glyph has no art behind it.
	table.freeze({ Day = 6, Spins = 3, Glyph = "wheel", Accent = "Cyan", Label = "3 Spins" }),
	--[[
		Day 7 is the hero card: it spans two rows on its own in the modal, so it carries the heaviest
		reward and the magnet glyph, which is the most recognisable object in the game.

		It does NOT grant a magnet. The calendar loops, so a magnet here would be worthless from the
		second week on. If you want the magnet itself as a day-7 prize it has to be conditional on not
		already owning it, with cash as the fallback -- worth doing, but it is a real branch rather
		than a config line.
	]]
	table.freeze({
		Day = 7,
		Money = 50000,
		Items = table.freeze({ GodPotion = 1 }),
		Spins = 2,
		Glyph = "magnet",
		Accent = "Gold",
		Label = "MEGA",
		Hero = true,
	}),
}

--------------------------------------------------------------------------------
-- Playtime rewards
--------------------------------------------------------------------------------

--[[
	Milestones inside a single day's play, resetting with the daily reset. Playtime was already
	being accumulated for the leaderboard and never rewarded -- this spends it.

	Front-loaded on purpose -- 5, 10 and 20 minutes are all inside a first session, because a reward a
	new player never reaches is a number in a config rather than a retention mechanic. The back half is
	spaced wider so the ladder still has somewhere to go for a player who stays all evening.
]]
local playtimeMilestones = {
	table.freeze({ Index = 1, Seconds = 300, Money = 1000, Label = "5 MIN", Accent = "Green" }),
	table.freeze({ Index = 2, Seconds = 600, Money = 2500, Label = "10 MIN", Accent = "Green" }),
	table.freeze({
		Index = 3,
		Seconds = 1200,
		Items = table.freeze({ CashPotion = 1 }),
		Label = "20 MIN",
		Accent = "Gold",
	}),
	table.freeze({ Index = 4, Seconds = 1800, Money = 8000, Label = "30 MIN", Accent = "Green" }),
	table.freeze({ Index = 5, Seconds = 2700, Spins = 1, Label = "45 MIN", Accent = "Cyan" }),
	table.freeze({
		Index = 6,
		Seconds = 3600,
		Items = table.freeze({ LuckPotion = 1 }),
		Label = "1 HR",
		Accent = "Purple",
	}),
	table.freeze({ Index = 7, Seconds = 4800, Money = 30000, Label = "1 HR 20", Accent = "Green" }),
	table.freeze({
		Index = 8,
		Seconds = 6000,
		Items = table.freeze({ StrengthPotion = 1 }),
		Label = "1 HR 40",
		Accent = "Cyan",
	}),
	--[[
		The two-hour prize is SPINS, not cash. Two hours in a day is a committed session, and a spin is
		worth more than its cash value because it might be the God Potion -- ending the ladder on a
		gamble is a better last step than ending it on a bigger number.
	]]
	table.freeze({
		Index = 9,
		Seconds = 7200,
		Money = 75000,
		Spins = 3,
		Label = "2 HR",
		Accent = "Gold",
		Best = true,
	}),
}

--------------------------------------------------------------------------------
-- Spin wheel
--------------------------------------------------------------------------------

--[[
	Weighted, and the weights are the balance. The server picks the winning segment and TELLS the
	client where to land -- the wheel animation is decoration over a decided result, never the
	other way round. A client that picks its own prize is a client that always wins.

	`Weight` is relative, not a percentage; the service sums them.
]]
local spinSegments = {
	table.freeze({
		Id = "SmallCash",
		Weight = 30,
		Money = 1500,
		Label = "$1.5K",
		Accent = "Green",
		Glyph = "cash",
	}),
	table.freeze({
		Id = "MediumCash",
		Weight = 22,
		Money = 6000,
		Label = "$6K",
		Accent = "Green",
		Glyph = "cash",
	}),
	table.freeze({
		Id = "LargeCash",
		Weight = 12,
		Money = 25000,
		Label = "$25K",
		Accent = "Gold",
		Glyph = "cash",
	}),
	table.freeze({
		Id = "CashPotion",
		Weight = 14,
		Items = table.freeze({ CashPotion = 1 }),
		Label = "2x Cash",
		Accent = "Gold",
		Glyph = "potion",
	}),
	table.freeze({
		Id = "LuckPotion",
		Weight = 10,
		Items = table.freeze({ LuckPotion = 1 }),
		Label = "Luck",
		Accent = "Purple",
		Glyph = "potion",
	}),
	table.freeze({
		Id = "StrengthPotion",
		Weight = 8,
		Items = table.freeze({ StrengthPotion = 1 }),
		Label = "Strength",
		Accent = "Cyan",
		Glyph = "potion",
	}),
	table.freeze({
		Id = "BonusSpin",
		Weight = 3,
		Spins = 2,
		Label = "+2 Spins",
		Accent = "Cyan",
		--[[
			The wheel, not a star. `star` draws a big gold eight-point sparkle, which at wedge size read as
			an orange splat rather than a prize -- and a wheel is what "+2 Spins" actually gets you.
		]]
		Glyph = "wheel",
	}),
	--[[
		THE BEST PRIZE. `Best` is a flag, not a hardcoded id in the UI: the wheel finds whichever
		segment carries it and gives that one the gold treatment, the crown, and the shine layer. Move
		the flag and the presentation follows -- which is the point of driving it from data.

		Only one segment should carry it. The wheel takes the first it finds.
	]]
	table.freeze({
		Id = "Jackpot",
		Weight = 1,
		Money = 250000,
		Items = table.freeze({ GodPotion = 1 }),
		Label = "GOD POTION",
		Accent = "Gold",
		Glyph = "potion",
		Best = true,
	}),
}

return table.freeze({
	Daily = table.freeze({
		Days = table.freeze(dailyDays),
		--- Cash multiplier added per consecutive day, on top of the day's own reward.
		StreakBonusPerDay = 0.05,
		MaximumStreakBonus = 1.0,
		--[[
			A streak survives one missed day. Forgiving on purpose: losing a 20-day streak to one
			bad evening is the kind of punishment that makes players quit rather than return.
		]]
		StreakGraceDays = 1,
	}),

	Playtime = table.freeze({
		Milestones = table.freeze(playtimeMilestones),
		--- How often the server banks session playtime into saved data.
		TickSeconds = 5,
	}),

	Spin = table.freeze({
		Segments = table.freeze(spinSegments),
		--- Free spins handed out each new day.
		DailyFreeSpins = 1,
		MaximumStored = 25,
		--- How long the client's wheel animation runs, so the server can rate-limit sanely.
		AnimationSeconds = 3.2,
		--[[
			How long the prize banner stays up before the wheel goes back to idle.

			There is no COLLECT button -- the reward was granted the instant the server resolved the spin,
			so a button claiming to collect it would be a lie. The banner announces and then clears itself,
			which is also what frees the wheel for another spin.
		]]
		RevealSeconds = 3.5,
	}),

	Friends = table.freeze({
		--[[
			Money boost per friend in the same server. This is the cheapest social mechanic there
			is: it costs nothing to build, it rewards bringing people, and the reward is visible
			to both sides. See `docs/GAME_AUDIT.md` -- social systems are the 3-5x retention lever
			and this is the smallest possible first step onto that ladder.
		]]
		BoostPerFriend = 0.10,
		--- Capped so a full server of friends cannot trivialise the economy.
		MaximumFriends = 10,
	}),
})
