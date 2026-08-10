--[[
	The three confirmation modals, from one reusable component.

	Destructive confirms keep CANCEL on the left in red and the action on the
	right, so the muscle memory is the same everywhere in the game.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)

local Theme = UI.Theme
local P = UI.Primitives
local Overlays = UI.Overlays
local Stage = UI.Stage

local e = React.createElement

local CASES = {
	{
		label = "Purchase upgrade",
		props = {
			title = "Purchase Upgrade?",
			glyph = "pin",
			glyphGradient = Theme.Gradient.Cyan,
			lines = { "Magnet Range", "25 studs  ->  28 studs" },
			price = 42_500,
			confirmText = "BUY",
			confirmVariant = "Primary",
		},
	},
	{
		label = "Prestige",
		props = {
			title = "Prestige?",
			glyph = "recycle",
			glyphGradient = Theme.Gradient.Purple,
			headerColor = Theme.Gradient.Purple,
			lines = {
				"This cannot be undone.",
				"You keep magnets, pets, potions, gears and cosmetics.",
			},
			confirmText = "PRESTIGE",
			confirmVariant = "Premium",
		},
	},
	{
		label = "Use potion",
		props = {
			title = "Use Potion?",
			glyph = "potion",
			glyphGradient = Theme.Gradient.Gold,
			headerColor = Theme.Gradient.Green,
			lines = { "Cash Potion", "2x Cash for 15 minutes" },
			confirmText = "USE",
			confirmVariant = "Primary",
		},
	},
	{
		label = "Cannot afford",
		props = {
			title = "Unlock Area?",
			glyph = "pin",
			glyphGradient = Theme.Gradient.Cyan,
			lines = { "Scrap Harbor", "Best scrap: Ship Anchor" },
			price = 240_000_000,
			confirmText = "UNLOCK",
			confirmVariant = "Purchase",
			confirmDisabled = true,
		},
	},
}

local LABELS = {}
for index, case in ipairs(CASES) do
	LABELS[index] = case.label
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Confirmation Modals",
	summary = "Purchase, prestige, use-potion and a blocked confirm.",
	controls = {
		Case = UILabs.Choose(LABELS, 1),
		Backdrop = UILabs.Boolean(true),
	},
}, function(props)
	local selected = CASES[1]
	for _, case in ipairs(CASES) do
		if case.label == props.controls.Case then
			selected = case
			break
		end
	end

	local modalProps = table.clone(selected.props)
	modalProps.key = "Confirm"

	return e(Stage, {
		key = "Stage",
		device = "desktop",
		children = P.compact(
			if props.controls.Backdrop
				then e(Overlays.Backdrop, { key = "Backdrop", transparency = 0.5 })
				else nil,
			e(Overlays.ConfirmModal, modalProps)
		),
	})
end)
