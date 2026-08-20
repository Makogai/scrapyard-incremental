--[[
	INVENTORY with MAGNETS / POTIONS / TITLES / SKINS tabs.

	OWNED ITEMS ONLY. The mock player owns 4 of the 8 magnets and 3 potion types, so the magnet grid
	shows four cards over a "4/8" footer bar -- not eight cards with BUY plates on half of them. The
	footer still counts the whole set, because collection progress is worth knowing; the grid does not,
	because buying belongs in the Shop.

	A tab with nothing in it renders a line pointing at the Shop instead of an empty panel. To see that,
	set a mock potion's `owned` to 0 in `Mock.luau`.

	SKINS IS THE TAB WORTH POKING AT. `Own lava skin` seeds the entitlement the real server would send,
	and pressing EQUIP actually swaps it -- the mock writes `Atoms.plotSkin` rather than being a no-op --
	so the interesting behaviour is the one you can try here:

		- with the skin owned, EQUIP on Lava then EQUIP on Standard Yard. Both must be reachable: a
		  cosmetic you cannot take back off is a cosmetic people regret buying.
		- turn `Own lava skin` off and the tab drops to the standard yard alone, with the footer still
		  reading 1/2, because that is collection progress rather than a sales pitch.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)
local PlotSkinConfig = require(ReplicatedStorage.Shared.Config.PlotSkinConfig)

local Harness = require(script.Parent.Parent.Harness)

local e = React.createElement

--[[
	The entitlement and the worn skin are seeded from the controls, the way a snapshot would arrive from
	the server. Written in an effect rather than inline so toggling a control re-seeds instead of
	fighting whatever the last press left behind.
]]
local function Scene(props)
	local controls = props.controls

	React.useEffect(function()
		local Atoms = UI.Atoms
		Atoms.entitlements(if controls.OwnSkin then { [PlotSkinConfig.Pass] = true } else {})
		--- Taking ownership away has to take the skin off too, or the plot wears something unowned.
		if not controls.OwnSkin then
			Atoms.plotSkin("")
		end
	end, { controls.OwnSkin })

	return e(Harness.Screen, {
		component = UI.Screens.Inventory,
		device = controls.Device,
		gameView = controls.GameView,
	})
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Inventory",
	summary = "INVENTORY: owned magnets, potions, titles and plot skins. Buying lives in the Shop.",
	controls = {
		Device = UILabs.Choose({ "desktop", "tablet", "mobile" }, 1),
		GameView = UILabs.Boolean(true),
		OwnSkin = UILabs.Boolean(true),
	},
}, function(props)
	return e(Scene, { controls = props.controls })
end)
