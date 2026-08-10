--[[
	The whole client UI, and the place of truth for it.

	Same component the client mounts: HUD, every window, toasts and confirms,
	backed by the mock store. Buy an upgrade and the cash drops. Prestige and
	everything resets.

	The experience is locked to landscape, so every Device canvas here is
	landscape and all of them render the same `HudDesktop` -- `Device` changes the
	canvas, `Touch` changes the layout:

		Touch on   menu column hangs from the top with smaller tiles to clear the
		           thumbstick; cash, storage and the potion tiles lift above the
		           touch-control band
		Touch off  menu column centres on the left edge, bottom row at the edge

	Two things the mock store cannot show, because no server backs it here:
	live potion timers in the bottom right, and Robux prices.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)

local Stage = UI.Stage
local Store = UI.Store

local e = React.createElement

--[[
	Every id in `App`'s SCREENS table, and nothing else. `daily`, `plot` and
	`leaderboards` used to be listed here and silently opened nothing -- no server
	system backs them, so they are not routed.
]]
local SCREEN_OPTIONS = {
	"none",
	"upgrades",
	"inventory",
	"pets",
	"areas",
	"prestige",
	"shop",
	"settings",
	"collection",
	"magnetshop",
	"changelog",
}

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Full App",
	summary = "The complete interactive client: HUD plus every window, wired to the live store.",
	controls = {
		Device = UILabs.Choose({ "desktop", "tablet", "mobile" }, 1),
		OpenScreen = UILabs.Choose(SCREEN_OPTIONS, 1),
		Touch = UILabs.Boolean(false),
	},
}, function(props)
	local controls = props.controls

	return e(Stage, {
		key = "Stage",
		device = controls.Device,
		children = {
			e(Store.Provider, {
				-- Stories have no server: always mock, never live remotes.
				key = "Store",
				mock = true,
				children = e(UI.App, {
					key = "App",
					-- Stage already fits the canvas, so the app renders 1:1.
					device = controls.Device,
					scale = 1,
					touch = controls.Touch,
					initialScreen = if controls.OpenScreen == "none"
						then nil
						else controls.OpenScreen,
				}),
			}),
		},
	})
end)
