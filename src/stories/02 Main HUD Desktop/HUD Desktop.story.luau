--[[
	Full gameplay HUD at 1920x1080: menu grid, currencies, storage meter, boosts and contextual actions.
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
	name = "HUD Desktop",
	summary = "Full gameplay HUD at 1920x1080: menu grid, currencies, storage meter, boosts and contextual actions.",
	controls = {
		Device = UILabs.Choose({ "desktop", "tablet", "mobile" }, 1),
		GameView = UILabs.Boolean(true),
	},
}, function(props)
	return e(Harness.Screen, {
		component = UI.Screens.HudDesktop,
		device = props.controls.Device,
		gameView = props.controls.GameView,
	})
end)
