--[[
	Title and achievement cards.

	Both are WIDE cards, which is the thing to judge here: they hold a line of text that has to be
	readable at the size it will be worn, a sentence, and a progress bar. The failure mode is a card
	that truncates the one thing it exists to show, so every row below is built from the real configs --
	the longest title in `TitleConfig` and the longest description in `AchievementConfig` appear here
	whether or not I remembered they were long.

	WHAT TO LOOK FOR:

		- a locked title still READS. Its text is the goal; hiding it behind ??? removes the point.
		- the equipped ring is unmistakable without reading the button.
		- an achievement at 999/1000 and one at 0/1000 are told apart at a glance by the bar alone.
		- sparkles appear on Legendary and Mythic ONLY, and only when owned.

	The controls sweep the states rather than showing one of each, because the interesting bugs are in
	the transitions: a card that changes height when it completes makes a list of them jump.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)
local TitleConfig = require(ReplicatedStorage.Shared.Config.TitleConfig)
local AchievementConfig = require(ReplicatedStorage.Shared.Config.AchievementConfig)

local Harness = require(script.Parent.Parent.Harness)

local Progression = UI.Progression

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Titles And Achievements",
	summary = "Wide progression cards: every title, and every achievement at a chosen progress.",
	controls = {
		--- Sweeps every achievement from untouched to complete, so the bar and the ring are both covered.
		Progress = UILabs.Slider(0.35, 0, 1, 0.05),
		--- Which titles read as owned. The rest show their unlock condition instead.
		OwnedTitles = UILabs.Boolean(true),
		--- The one being worn, by index into the rarity-sorted list.
		EquippedIndex = UILabs.Slider(3, 0, #TitleConfig.Titles, 1),
	},
}, function(props)
	local controls = props.controls

	--- Sorted the way the store sorts them, so this story shows the shipped order.
	local titles = table.clone(TitleConfig.Titles)
	table.sort(titles, function(a, b)
		local rankA, rankB = TitleConfig.rarityRank(a.Rarity), TitleConfig.rarityRank(b.Rarity)
		if rankA ~= rankB then
			return rankA < rankB
		end
		return a.Text < b.Text
	end)

	local titleCards = {}
	for index, definition in ipairs(titles) do
		local source = AchievementConfig.ById[definition.Source]
		titleCards[index] = e(Progression.TitleCard, {
			key = definition.Id,
			id = definition.Id,
			text = definition.Text,
			rarity = definition.Rarity,
			accent = TitleConfig.RarityAccent[definition.Rarity],
			owned = controls.OwnedTitles,
			equipped = controls.OwnedTitles and index == controls.EquippedIndex,
			sourceName = if source then source.Name else definition.Source,
			sourceDetail = if source then source.Description else "",
			layoutOrder = index,
			onEquip = function() end,
		})
	end

	local achievementCards = {}
	for index, definition in ipairs(AchievementConfig.Definitions) do
		--[[
			A shared fraction across every card rather than each one's real value: the point of this row is
			the CARD at a given fill, and one slider sweeping all of them finds the bar that breaks at 100%
			far faster than clicking through twenty different games' worth of save state.
		]]
		local value = math.floor(definition.Threshold * controls.Progress)
		achievementCards[index] = e(Progression.AchievementCard, {
			key = definition.Id,
			id = definition.Id,
			name = definition.Name,
			description = definition.Description,
			glyph = definition.Glyph,
			accent = definition.Accent,
			value = value,
			threshold = definition.Threshold,
			complete = value >= definition.Threshold,
			reward = definition.Reward,
			titleText = if definition.Reward.TitleId
				then TitleConfig.ById[definition.Reward.TitleId].Text
				else nil,
			layoutOrder = index,
		})
	end

	return e(Harness.Gallery, {
		title = "Progression",
		sections = {
			{
				title = `Titles -- every one in the config, rarity order ({#titles})`,
				items = titleCards,
				itemSize = UDim2.fromOffset(
					Progression.TITLE_CARD.X + 8,
					Progression.TITLE_CARD.Y + 8
				),
			},
			{
				title = `Achievements -- all {AchievementConfig.Count}, at the slider fill`,
				items = achievementCards,
				itemSize = UDim2.fromOffset(
					Progression.ACHIEVEMENT_CARD.X + 8,
					Progression.ACHIEVEMENT_CARD.Y + 8
				),
			},
		},
	})
end)
