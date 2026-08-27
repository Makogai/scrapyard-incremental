--[[
	THE GEAR SHOP. Gears in, persist-through-wipe ranks out. Review this in UI Labs
	without launching Play -- mock mode seeds 42 gears at rebirth 4, so Egg Fortune
	and the Secret ticket stay locked.

	============================= WHERE TO TWEAK =============================

	  offer list and prices    src/shared/Config/GearShopConfig.luau
	  screen layout            src/shared/UI/Screens/GearShopScreen.luau

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
	name = "Gear Shop",
	summary = "Rebirth Gear shop: head start, nest egg, bag floor, pet slot, scrap luck, egg fortune.",
	controls = {
		Device = UILabs.Choose({ "desktop", "tablet", "mobile" }, 1),
		GameView = UILabs.Boolean(true),
	},
}, function(props)
	return e(Harness.Screen, {
		component = UI.Screens.GearShop,
		screen = "gearshop",
		device = props.controls.Device,
		gameView = props.controls.GameView,
	})
end)
