--[[
	The admin panel.

	Worth reviewing here rather than only in game because the thing most likely to be wrong is the
	right column's LENGTH: the sections are built from the real configs, so the pets list is however
	many pets exist and it has to scroll cleanly rather than overflow the window.

	`Section` walks the catalogue so every list can be checked without clicking through in game. If a
	new magnet or pet has been added and this story shows it without any edit to the story, the dynamic
	half is working.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)
local AdminCatalogue = require(ReplicatedStorage.Shared.Config.AdminCatalogue)

local Harness = require(script.Parent.Parent.Harness)

local e = React.createElement

local SECTIONS = AdminCatalogue.build()
local SECTION_IDS = {}
for _, section in ipairs(SECTIONS) do
	table.insert(SECTION_IDS, `{section.Label} ({#section.Entries})`)
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Admin",
	summary = "Two-column admin panel, with sections built from the game's own configs.",
	controls = {
		Device = UILabs.Choose({ "desktop", "tablet", "mobile" }, 1),
		GameView = UILabs.Boolean(true),
		--[[
			Informational: which sections the catalogue produced and how many entries each holds. Nothing
			reads this -- it is here so the counts are visible in the controls panel without opening the
			panel and clicking every tab.
		]]
		Sections = UILabs.Choose(SECTION_IDS, 1),
	},
}, function(props)
	return e(Harness.Screen, {
		component = UI.Screens.Admin,
		device = props.controls.Device,
		gameView = props.controls.GameView,
	})
end)
