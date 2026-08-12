--[[
	INVENTORY with MAGNETS / POTIONS / TITLES tabs.

	OWNED ITEMS ONLY. The mock player owns 4 of the 8 magnets and 3 potion types, so the magnet grid
	shows four cards over a "4/8" footer bar -- not eight cards with BUY plates on half of them. The
	footer still counts the whole set, because collection progress is worth knowing; the grid does not,
	because buying belongs in the Shop.

	A tab with nothing in it renders a line pointing at the Shop instead of an empty panel. To see that,
	set a mock potion's `owned` to 0 in `Mock.luau`.
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
	name = "Inventory",
	summary = "INVENTORY: owned magnets, potions and titles. Buying lives in the Shop.",
	controls = {
		Device = UILabs.Choose({ "desktop", "tablet", "mobile" }, 1),
		GameView = UILabs.Boolean(true),
	},
}, function(props)
	return e(Harness.Screen, {
		component = UI.Screens.Inventory,
		device = props.controls.Device,
		gameView = props.controls.GameView,
	})
end)
