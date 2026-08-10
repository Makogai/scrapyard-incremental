--[[
	The three HUD pieces the return-to-play systems added, in isolation:

		StatusCluster    bottom-right trio: daily login boost, friend boost, spin wheel
		TutorialCaption  the current onboarding objective

	Isolated rather than reviewed inside the full HUD because each has states that are awkward to
	reach in situ -- a friend count of nine, a milestone exactly ready, the last tutorial step. The
	full-HUD stories cover how they sit together; this one covers whether each is right.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.RewardsConfig)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)

local Harness = require(script.Parent.Parent.Harness)

local Parts = UI.Screens.HudParts
local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "HUD Widgets",
	summary = "Bottom-right status cluster and the tutorial caption.",
	controls = {
		Friends = UILabs.Slider(2, 0, 10, 1),
		Spins = UILabs.Slider(2, 0, 9, 1),
		--- Forces the hover popup open, since a story cannot hold a mouse still.
		ShowTooltip = UILabs.Boolean(false),
		DailyStreak = UILabs.Slider(3, 0, 30, 1),
		DailyClaimable = UILabs.Boolean(true),
		TutorialStep = UILabs.Slider(1, 0, #TutorialConfig.Steps, 1),
	},
}, function(props)
	local controls = props.controls

	--[[
		Zero means "finished", which is the state that renders nothing -- worth being able to select,
		because "does it disappear cleanly" is exactly the kind of thing that ships broken.
	]]
	local step = if controls.TutorialStep == 0
		then nil
		else TutorialConfig.Steps[controls.TutorialStep]

	local friendStates = {}
	for _, count in { 0, 1, 3, 10 } do
		friendStates[#friendStates + 1] = e(Parts.FriendBoost, {
			key = `Friends{count}`,
			count = count,
			boost = count * RewardsConfig.Friends.BoostPerFriend,
			tooltipVisible = controls.ShowTooltip,
		})
	end

	local spinStates = {}
	for _, spins in { 0, 1, 5 } do
		spinStates[#spinStates + 1] = e(Parts.SpinWheel, {
			key = `Spins{spins}`,
			spins = spins,
			tooltipVisible = controls.ShowTooltip,
		})
	end

	return e(Harness.Gallery, {
		title = "Return to play — HUD widgets",
		sections = {
			{
				--[[
					The shipped bottom-left cluster. Reviewed as one unit because the two icons have to
					read as a matched pair -- same glyph weight, same value line, same popup behaviour.
				]]
				title = "Status cluster (the real bottom-left corner)",
				items = {
					e(Parts.StatusCluster, {
						key = "Cluster",
						dailyStreak = controls.DailyStreak,
						dailyBoostPercent = math.floor(
							math.min(math.max(0, controls.DailyStreak - 1) * 5, 100)
						),
						dailyClaimable = controls.DailyClaimable,
						friendCount = controls.Friends,
						friendBoost = controls.Friends * RewardsConfig.Friends.BoostPerFriend,
						spinsAvailable = controls.Spins,
					}),
				},
				itemSize = UDim2.fromOffset(190, 90),
			},
			{
				title = "Friend boost — 0, 1, 3 and 10 friends",
				items = friendStates,
				itemSize = UDim2.fromOffset(80, 110),
			},
			{
				title = "Spin wheel — 0, 1 and 5 spins",
				items = spinStates,
				itemSize = UDim2.fromOffset(80, 110),
			},
			{
				title = "Tutorial caption (playground — step 0 hides it)",
				items = {
					e(Parts.TutorialCaption, {
						key = "Tutorial",
						step = step,
						total = #TutorialConfig.Steps,
					}),
				},
				itemSize = UDim2.fromOffset(432, 92),
			},
		},
	})
end)
