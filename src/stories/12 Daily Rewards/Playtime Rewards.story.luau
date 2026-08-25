--[[
	The playtime ladder as its own window.

	The seconds slider is what to review: locked cards counting down, a READY card
	with CLAIM, and claimed ticks. The live game interpolates seconds while this
	window stays open; the slider is the story stand-in for that clock.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)
local Atoms = require(ReplicatedStorage.Shared.UI.State.Atoms)

local Harness = require(script.Parent.Parent.Harness)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Playtime Rewards",
	summary = "Playtime ladder: locked countdowns, a claimable card, and claimed ticks.",
	controls = {
		Device = UILabs.Choose({ "desktop", "tablet", "mobile" }, 1),
		GameView = UILabs.Boolean(true),
		PlaytimeSeconds = UILabs.Slider(1100, 0, 7200, 10),
		ClaimedMilestones = UILabs.Slider(2, 0, 9, 1),
	},
}, function(props)
	local controls = props.controls

	Atoms.playtimeSeconds(controls.PlaytimeSeconds)
	Atoms.playtimeSyncedAt(0)
	local claimed = {}
	for index = 1, controls.ClaimedMilestones do
		claimed[index] = true
	end
	Atoms.playtimeClaimed(claimed)

	return e(Harness.Screen, {
		component = UI.Screens.PlaytimeRewards,
		device = controls.Device,
		gameView = controls.GameView,
	})
end)
