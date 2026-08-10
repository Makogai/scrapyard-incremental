--[[
	Seven-day calendar: two rows of three on the left, day 7 as a tall hero card on the right.

	The controls walk the calendar position and the streak, which is what actually needs reviewing --
	whether the dimmed / ringed / locked states read correctly at every point in the loop, and whether
	the hero still dominates once the small cards around it are ticked off.
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
	name = "Daily Rewards",
	summary = "Seven-day calendar, 3+3 plus a hero card for day 7.",
	controls = {
		Device = UILabs.Choose({ "desktop", "tablet", "mobile" }, 1),
		GameView = UILabs.Boolean(true),
		CalendarDay = UILabs.Slider(4, 1, 7, 1),
		Streak = UILabs.Slider(3, 0, 30, 1),
		Claimable = UILabs.Boolean(true),
	},
}, function(props)
	local controls = props.controls

	--[[
		Written on every render rather than in an effect: a story re-renders when a control moves and
		nothing else, so this is the cheapest way to keep the atoms in step with the sliders.
	]]
	Atoms.dailyCalendarDay(controls.CalendarDay)
	Atoms.dailyStreak(controls.Streak)
	Atoms.dailyClaimable(controls.Claimable)

	return e(Harness.Screen, {
		component = UI.Screens.DailyRewards,
		device = controls.Device,
		gameView = controls.GameView,
	})
end)
