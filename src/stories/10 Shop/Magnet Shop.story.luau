--[[
	THE MAGNET SHOP. Cash magnets on MAGNETS, cosmetic horseshoes on SKINS.
	Review the skins tab in UI Labs -- mock mode owns Yard Paint and has enough
	cash to buy the rest, and EQUIP / BUY mutate locally.

	============================= WHERE TO TWEAK =============================

	  skin models              src/shared/Utility/MagnetSkinBuilder.luau
	  prices and copy          src/shared/Config/MagnetSkinConfig.luau
	  screen layout            src/shared/UI/Screens/MagnetShopScreen.luau

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
	name = "Magnet Shop",
	summary = "Magnet booth: MAGNETS for stats, SKINS for cosmetic horseshoes with a 3D preview.",
	controls = {
		Device = UILabs.Choose({ "desktop", "tablet", "mobile" }, 1),
		GameView = UILabs.Boolean(true),
	},
}, function(props)
	return e(Harness.Screen, {
		component = UI.Screens.MagnetShop,
		screen = "magnetshop",
		device = props.controls.Device,
		gameView = props.controls.GameView,
	})
end)
