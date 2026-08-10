--[[
	All three world boards at once, with the local player's row highlighted.
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
	name = "Leaderboards",
	summary = "All three world boards at once, with the local player's row highlighted.",
	controls = {
		Device = UILabs.Choose({ "desktop", "tablet", "mobile" }, 1),
		GameView = UILabs.Boolean(true),
	},
}, function(props)
	return e(Harness.Screen, {
		component = UI.Screens.Leaderboards,
		device = props.controls.Device,
		gameView = props.controls.GameView,
	})
end)
