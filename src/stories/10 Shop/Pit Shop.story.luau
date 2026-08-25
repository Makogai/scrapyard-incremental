--[[
	THE PIT shop. Slag in, potions and cash out. Review this in UI Labs without
	launching Play -- mock mode seeds 1,250 slag.

	============================= WHERE TO TWEAK =============================

	  offer list and prices    src/shared/Config/PitShopConfig.luau
	  screen layout            src/shared/UI/Screens/PitShopScreen.luau

	==========================================================================
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
	name = "Pit Shop",
	summary = "The Pit's slag shop: potions, cash crates, a Secret ticket, a God Potion.",
	controls = {
		Device = UILabs.Choose({ "desktop", "tablet", "mobile" }, 1),
		GameView = UILabs.Boolean(true),
	},
}, function(props)
	return e(Harness.Screen, {
		component = UI.Screens.PitShop,
		screen = "pitshop",
		device = props.controls.Device,
		gameView = props.controls.GameView,
	})
end)
