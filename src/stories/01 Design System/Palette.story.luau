--[[
	Palette, gradients, rarity ramp and type scale.
	The reference sheet for the whole game.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)

local Harness = require(script.Parent.Parent.Harness)

local Theme = UI.Theme
local P = UI.Primitives

local e = React.createElement

local function Swatch(props)
	return e(P.Panel, {
		key = props.name,
		size = UDim2.fromOffset(150, 92),
		radius = Theme.Radius.Card,
		color = props.color,
		gradient = props.gradient,
		studs = false,
		strokeThickness = Theme.Stroke.Card,
		children = {
			e(P.Label, {
				key = "Name",
				text = props.name,
				textSize = Theme.TextSize.Small,
				size = UDim2.new(1, -8, 0, 20),
				position = UDim2.new(0.5, 0, 1, -8),
				anchorPoint = Vector2.new(0.5, 1),
				zIndex = 3,
			}),
		},
	})
end

local function TypeSample(props)
	return e(P.Panel, {
		key = props.name,
		size = UDim2.fromOffset(340, props.textSize + 40),
		radius = Theme.Radius.Card,
		color = Theme.Color.Panel,
		gradient = Theme.Gradient.Panel,
		studs = false,
		children = {
			e(P.Label, {
				key = "Sample",
				text = props.name .. " " .. props.textSize,
				textSize = props.textSize,
				font = props.font,
				size = UDim2.fromScale(1, 1),
				zIndex = 3,
			}),
		},
	})
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Palette",
	summary = "Colours, gradients, rarity ramp and the type scale.",
}, function()
	local colorItems = {}
	for _, name in ipairs({
		"Green",
		"Blue",
		"Yellow",
		"Purple",
		"Red",
		"Cyan",
		"Pink",
		"Orange",
		"Gold",
		"Positive",
		"Gray",
		"Panel",
		"PanelDark",
		"PanelLight",
		"Card",
		"CardBase",
		"Slot",
		"Outline",
	}) do
		colorItems[#colorItems + 1] =
			e(Swatch, { key = name, name = name, color = Theme.Color[name] })
	end

	local gradientItems = {}
	for _, name in ipairs({
		"Green",
		"Blue",
		"Yellow",
		"Purple",
		"Red",
		"Cyan",
		"Pink",
		"Orange",
		"Gold",
		"Gray",
		"Dead",
	}) do
		gradientItems[#gradientItems + 1] = e(
			Swatch,
			{ key = name, name = name, color = Theme.Color.White, gradient = Theme.Gradient[name] }
		)
	end

	local rarityItems = {}
	for _, name in ipairs(Theme.RarityOrder) do
		local style = Theme.rarity(name)
		rarityItems[#rarityItems + 1] =
			e(Swatch, { key = name, name = name, color = style.color, gradient = style.gradient })
	end
	for _, name in ipairs(Theme.PetRarityOrder) do
		local style = Theme.rarity(name)
		rarityItems[#rarityItems + 1] = e(
			Swatch,
			{ key = "Pet" .. name, name = name, color = style.color, gradient = style.gradient }
		)
	end

	local typeItems = {
		e(TypeSample, { key = "Hero", name = "Hero", textSize = Theme.TextSize.Hero }),
		e(TypeSample, { key = "Title", name = "Title", textSize = Theme.TextSize.Title }),
		e(TypeSample, { key = "Heading", name = "Heading", textSize = Theme.TextSize.Heading }),
		e(TypeSample, { key = "Button", name = "Button", textSize = Theme.TextSize.Button }),
		e(
			TypeSample,
			{ key = "Body", name = "Body", textSize = Theme.TextSize.Body, font = Theme.Font.Bold }
		),
		e(TypeSample, {
			key = "Small",
			name = "Small",
			textSize = Theme.TextSize.Small,
			font = Theme.Font.Bold,
		}),
		e(
			TypeSample,
			{ key = "Tiny", name = "Tiny", textSize = Theme.TextSize.Tiny, font = Theme.Font.Bold }
		),
	}

	local surfaceItems = {
		e(P.Panel, {
			key = "StudPanel",
			size = UDim2.fromOffset(300, 150),
			children = {
				e(P.Label, {
					key = "Label",
					text = "STUD PANEL",
					textSize = Theme.TextSize.Body,
					zIndex = 3,
				}),
			},
		}),
		e(P.Panel, {
			key = "GlossPanel",
			size = UDim2.fromOffset(300, 150),
			gloss = true,
			gradient = Theme.Gradient.Panel,
			children = {
				e(
					P.Label,
					{ key = "Label", text = "GLOSS", textSize = Theme.TextSize.Body, zIndex = 3 }
				),
			},
		}),
		e(P.Slot, {
			key = "Slot",
			size = UDim2.fromOffset(300, 150),
			children = {
				e(P.Label, {
					key = "Label",
					text = "SLOT WELL",
					textSize = Theme.TextSize.Body,
					zIndex = 3,
				}),
			},
		}),
		e(P.Panel, {
			key = "ShadowPanel",
			size = UDim2.fromOffset(300, 150),
			shadow = true,
			children = {
				e(
					P.Label,
					{ key = "Label", text = "SHADOW", textSize = Theme.TextSize.Body, zIndex = 3 }
				),
			},
		}),
	}

	return e(Harness.Gallery, {
		title = "Design tokens",
		sections = {
			{ title = "Core colours", items = colorItems, itemSize = UDim2.fromOffset(150, 92) },
			{
				title = "Header gradients",
				items = gradientItems,
				itemSize = UDim2.fromOffset(150, 92),
			},
			{ title = "Rarity ramp", items = rarityItems, itemSize = UDim2.fromOffset(150, 92) },
			{ title = "Surfaces", items = surfaceItems, itemSize = UDim2.fromOffset(300, 150) },
			{ title = "Type scale", items = typeItems, itemSize = UDim2.fromOffset(340, 90) },
		},
	})
end)
