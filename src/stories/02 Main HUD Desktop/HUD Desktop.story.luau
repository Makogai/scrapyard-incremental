--[[
	Full gameplay HUD at 1920x1080: menu grid, currencies, storage meter, boosts and contextual actions.

	THE TOP OF THE SCREEN IS EMPTY HERE, AND THAT IS CORRECT. Six things live in that strip in game --
	UPDATES on the left, SHOP / MY PLOT / LEADERBOARD in the centre, INDEX and SETTINGS on the right --
	and all six are TopbarPlus icons registered by `client/Controllers/TopbarController`. A story has no
	client controllers, so none of them render. The travel three used to be a React row visible here;
	they moved so they would stop competing for a strip TopbarPlus already arranges, and so that phones
	get them too. Review that strip in Play, not here.

	This story is still the place of truth for everything else: the left menu grid, the currency stack,
	the storage meter, the boost tiles, the status cluster, and where the event banner hangs under the
	strip.
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
	name = "HUD Desktop",
	summary = "Full gameplay HUD at 1920x1080: menu grid, currencies, storage meter, boosts and contextual actions.",
	controls = {
		Device = UILabs.Choose({ "desktop", "tablet", "mobile" }, 1),
		GameView = UILabs.Boolean(true),
		WreckHp = UILabs.Slider(2400, 0, 3600, 50),
		Shielded = UILabs.Boolean(false),
	},
}, function(props)
	local hp = props.controls.WreckHp
	Atoms.wreckIntegrity(hp)
	Atoms.wreckIntegrityMax(if hp > 0 then 3600 else 0)
	Atoms.wreckShielded(props.controls.Shielded == true)

	return e(Harness.Screen, {
		component = UI.Screens.HudDesktop,
		device = props.controls.Device,
		gameView = props.controls.GameView,
	})
end)
