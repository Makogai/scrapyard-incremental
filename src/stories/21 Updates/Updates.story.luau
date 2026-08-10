--[[
	The UPDATES window, opened in game by the far-left TopbarPlus icon.

	Content is `Shared/Config/ChangelogConfig` verbatim -- this story reads the
	real table, so what you see here is what players see. Add a release there and
	it appears here with no story change.

	The thing to check when editing an entry: a long change wraps and the card
	grows to fit it rather than clipping. The v0.3.0 rows are long enough to show
	that; if you shorten them, lengthen one temporarily to re-check.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)

local Harness = require(script.Parent.Parent.Harness)

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Updates",
	summary = "Changelog window, rendered from Shared/Config/ChangelogConfig.",
	controls = {
		Device = UILabs.Choose({ "desktop", "tablet", "mobile" }, 1),
		GameView = UILabs.Boolean(true),
	},
}, function(props)
	return e(Harness.Screen, {
		component = UI.Screens.Changelog,
		device = props.controls.Device,
		gameView = props.controls.GameView,
	})
end)
