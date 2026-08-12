--[[
	The admin panel, at either tier.

	Worth reviewing here rather than only in game because the thing most likely to be wrong is the right
	column's LENGTH: the sections are built from the real configs, so the pets list is however many pets
	exist and it has to scroll cleanly rather than overflow the window.

	THE TIER CONTROL IS THE POINT OF THIS STORY NOW. Owner and admin see different panels -- different
	tabs, different entries, different target buttons, different header colour -- and a live session can
	only ever show you the tier you happen to be. Flip it here and check that nothing collapses: an admin
	loses the PASSES tab entirely and the EVERY SERVER target button, so the tab strip has to re-fit and
	the target column has to close its gap.

	Also here: the BOOSTS tab, which is the panel's only multi-select. Tick several and the action button
	should count them; switching tabs should clear the ticks, because a selection belongs to its section.

	None of the lists are written in this story -- it walks the catalogue. If a new magnet or pet has been
	added and it appears here with no edit to this file, the dynamic half is working.
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
		--- Which tier to draw. See the note at the top; this is the control worth moving.
		Tier = UILabs.Choose({ "admin", "owner" }, 1),
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
		isOwner = props.controls.Tier == "owner",
	})
end)
