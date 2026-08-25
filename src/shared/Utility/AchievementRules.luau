--!strict
--[[
	AchievementRules.luau
	Reading achievement progress off a save. Pure functions, no services, no Roblox instances.

	This is the whole of the achievement logic. `AchievementService` decides WHEN to look and hands out
	the rewards; everything about whether a thing is earned lives here, where a test can drive it with a
	plain table and no game running.

	THE METRIC TABLE IS THE CONTRACT. An achievement names a metric string, and exactly one function
	here knows how to read it. A definition naming a metric that does not exist is a test failure rather
	than an achievement that silently never completes -- which is the failure mode this design exists to
	remove.

	Everything is derived from state the save already keeps. Nothing here counts events, so an
	achievement added next month is immediately correct for a player who did the thing last month.
]]

local AchievementRules = {}

--[[
	How to read each metric from a player's data table.

	Every reader tolerates missing fields: this runs against saves written by older schema versions, and
	a nil count is zero rather than an error.
]]
local METRICS: { [string]: (data: { [string]: any }) -> number } = {
	TotalScrapCollected = function(data)
		return tonumber(data.TotalScrapCollected) or 0
	end,

	Money = function(data)
		return tonumber(data.Money) or 0
	end,

	PrestigeCount = function(data)
		return tonumber(data.PrestigeCount) or 0
	end,

	DailyStreak = function(data)
		return tonumber(data.DailyStreak) or 0
	end,

	--- Every upgrade level added together, which is the closest thing to "how built out is this player".
	UpgradeLevelTotal = function(data)
		local total = 0
		if type(data.UpgradeLevels) == "table" then
			for _, level in pairs(data.UpgradeLevels) do
				total += tonumber(level) or 0
			end
		end
		return total
	end,

	--- Pets HELD, not hatched: a player who deletes their pets loses this, which is the honest reading.
	PetsOwned = function(data)
		local total = 0
		if type(data.OwnedPets) == "table" then
			for _, count in pairs(data.OwnedPets) do
				total += tonumber(count) or 0
			end
		end
		return total
	end,

	EggsOpened = function(data)
		local total = 0
		if type(data.EggOpenCounts) == "table" then
			for _, count in pairs(data.EggOpenCounts) do
				total += tonumber(count) or 0
			end
		end
		return total
	end,

	AreasUnlocked = function(data)
		local total = 0
		if type(data.UnlockedAreas) == "table" then
			for _, unlocked in pairs(data.UnlockedAreas) do
				if unlocked == true then
					total += 1
				end
			end
		end
		return total
	end,

	MagnetsOwned = function(data)
		local total = 0
		if type(data.OwnedMagnets) == "table" then
			for _, owned in pairs(data.OwnedMagnets) do
				if owned == true then
					total += 1
				end
			end
		end
		return total
	end,

	--[[
		Distinct scrap types seen.

		COUNTS `Discovered == true`, NOT the number of keys. This used to count keys, on the stated
		assumption that a record existing at all meant the scrap had been found -- and
		`PlayerDataSchema.createDefault` pre-creates a record for every scrap id with `Discovered = false`.
		So a brand-new profile reported 18 discovered against a threshold of 17.

		The result: every fresh save instantly completed `IndexComplete` and was paid $1,500,000, 200 gears
		and the Archivist title. It made RESET PROFILE look broken -- you started rich, geared, and wearing
		a title you had not earned.

		Two reasonable pieces, wrong together. The schema pre-seeds records so the index can list
		undiscovered scrap without special-casing nil; this metric is the one that has to be specific about
		what "discovered" means.
	]]
	--[[
		Distinct plot scrap types seen. Pit-only pieces have their own achievement
		(`PitDiver`) so finding a Drone cannot complete Archivist.
	]]
	ScrapDiscovered = function(data)
		local total = 0
		if type(data.DiscoveredScrap) == "table" then
			for scrapId, record in pairs(data.DiscoveredScrap) do
				if
					type(record) == "table"
					and record.Discovered == true
					and scrapId ~= "Drone"
					and scrapId ~= "Submarine"
					and scrapId ~= "LavaCoreScrap"
					and scrapId ~= "RobotArm"
				then
					total += 1
				end
			end
		end
		return total
	end,

	--[[
		The four Pit-only types. Listed here rather than read from `ScrapConfig` because
		this module runs under Lune, and ScrapConfig uses Color3.
	]]
	PitScrapDiscovered = function(data)
		local total = 0
		if type(data.DiscoveredScrap) == "table" then
			for _, scrapId in { "Drone", "Submarine", "LavaCoreScrap", "RobotArm" } do
				local record = data.DiscoveredScrap[scrapId]
				if type(record) == "table" and record.Discovered == true then
					total += 1
				end
			end
		end
		return total
	end,
}

--- Every metric name a definition may use. Exposed so tests can assert the config only names these.
function AchievementRules.metricNames(): { string }
	local names = {}
	for name in pairs(METRICS) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

--- The raw value of one metric, or nil when the metric is unknown.
function AchievementRules.metric(data: { [string]: any }, name: string): number?
	local reader = METRICS[name]
	if reader == nil then
		return nil
	end
	return reader(data)
end

--[[
	Progress toward one achievement: `(value, threshold, complete)`.

	`value` is clamped to the threshold so a bar cannot overfill and a readout cannot say 4,000/1,000 --
	past the line the only interesting fact is that it is done.
]]
function AchievementRules.progress(
	data: { [string]: any },
	definition: { [string]: any }
): (number, number, boolean)
	local threshold = math.max(1, tonumber(definition.Threshold) or 1)
	local value = AchievementRules.metric(data, definition.Metric)
	if value == nil then
		return 0, threshold, false
	end
	return math.min(value, threshold), threshold, value >= threshold
end

--[[
	Which achievements a player has earned but not yet been paid for.

	Returns definition ids in the order they appear in the config, so the notifications a player gets on
	a single evaluation arrive in a sensible order rather than a hash-random one.
]]
function AchievementRules.newlyEarned(
	data: { [string]: any },
	definitions: { { [string]: any } },
	unlocked: { [string]: any }
): { string }
	local earned = {}
	for _, definition in ipairs(definitions) do
		if unlocked[definition.Id] ~= true then
			local _, _, complete = AchievementRules.progress(data, definition)
			if complete then
				table.insert(earned, definition.Id)
			end
		end
	end
	return earned
end

--- How many of `definitions` are already unlocked, for a "12 / 19" readout.
function AchievementRules.unlockedCount(
	definitions: { { [string]: any } },
	unlocked: { [string]: any }
): number
	local total = 0
	for _, definition in ipairs(definitions) do
		if unlocked[definition.Id] == true then
			total += 1
		end
	end
	return total
end

return table.freeze(AchievementRules)
