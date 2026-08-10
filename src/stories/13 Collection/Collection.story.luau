--[[
	COLLECTION index. Undiscovered entries keep their silhouette and footprint.

	SCRAP cells draw the real 3D model in a ViewportFrame, silhouetted to solid black
	until the scrap has been found -- so the grid shows the shape of what is missing.
	A discovered entry shows the highest rarity it has been found at, which is what makes
	a Nebula find worth looking at afterwards.

	============================= WHERE TO TWEAK =============================

	  what a cell draws        src/shared/UI/Components/Cards.luau -> Cards.CollectionCell
	                          (`model` prop, and the ViewportFrame `zoom`)

	  which model it asks for  src/shared/UI/GameData.luau -> GameData.scrapIndex,
	                          the `model` candidate list. Names must agree with
	                          `ScrapVariants.PreviewName` on the server.

	  the models themselves    Workspace.Scraps in Studio -- see docs/STUDIO_SETUP.md

	==========================================================================

	IN THIS STORY the cells fall back to their glyph, and that is correct rather than
	broken: the models are published to `ReplicatedStorage.ScrapPreviews` by the server
	at runtime, and a story has no server. `ModelView` degrades to the glyph whenever a
	model is not published, which is the same thing you see for pets in Edit mode. Check
	the real thing in Play if you are reviewing the 3D framing.
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
	name = "Collection",
	summary = "COLLECTION index. Undiscovered entries keep their silhouette and footprint.",
	controls = {
		Device = UILabs.Choose({ "desktop", "tablet", "mobile" }, 1),
		GameView = UILabs.Boolean(true),
	},
}, function(props)
	return e(Harness.Screen, {
		component = UI.Screens.Collection,
		device = props.controls.Device,
		gameView = props.controls.GameView,
	})
end)
