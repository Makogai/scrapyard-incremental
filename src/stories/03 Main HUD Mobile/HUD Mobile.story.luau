--[[
	The phone HUD -- which is the desktop HUD.

	The experience is locked to landscape, so there is no separate portrait
	layout: `App` always renders `HudDesktop` and the canvas scale shrinks it.
	This story is that case, at an iPhone landscape canvas (750x361), with the
	touch offsets forced on so you can see what a player actually gets.

	`Touch` is what drives the two differences from a mouse:

		on   menu column hangs from the top with smaller tiles, so it clears the
		     thumbstick; cash, storage and the potion tiles lift above the
		     touch-control band
		off  menu column centres on the left edge and the bottom row sits at the
		     screen edge

	`Screens/Hud/Mobile.luau` is the old portrait layout. It is no longer routed
	to by the app; story 02 covers the desktop canvas of this same component.
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
	name = "HUD Phone (landscape)",
	summary = "The shipped HUD at an iPhone landscape canvas, with the touch-control offsets on.",
	controls = {
		-- 3 = mobile, which is now 750x361 landscape.
		Device = UILabs.Choose({ "desktop", "tablet", "mobile" }, 3),
		Touch = UILabs.Boolean(true),
		GameView = UILabs.Boolean(true),
	},
}, function(props)
	return e(Harness.Screen, {
		-- The same component the client mounts. There is no phone-specific HUD.
		component = UI.Screens.HudDesktop,
		device = props.controls.Device,
		touch = props.controls.Touch,
		gameView = props.controls.GameView,
	})
end)
