--[[
	The whole icon set, tiled and plain.

	Every glyph is drawn from Frames, so the kit ships with no image assets and
	nothing to upload. Pass `image` to Icon to swap any of them for real art.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)

local Harness = require(script.Parent.Parent.Harness)

local Theme = UI.Theme
local Icon = UI.Icon
local P = UI.Primitives

local e = React.createElement

local NAMES = {
	"magnet",
	"coin",
	"gear",
	"potion",
	"lock",
	"basket",
	"bolt",
	"clock",
	"crate",
	"recycle",
	"paw",
	"scrap",
	"pin",
	"home",
	"robux",
	"trophy",
	"note",
	"sliders",
	"ground",
	"fence",
	"sign",
	"palette",
	"calendar",
	"book",
	"upgrade",
	"bag",
	"medal",
	"star",
	"check",
	"cross",
	"plus",
	"minus",
	"arrow",
	"chevron",
}

local GRADIENTS = { "Green", "Blue", "Yellow", "Purple", "Red", "Cyan", "Pink", "Orange", "Gold" }

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Glyphs",
	summary = "Procedural icon set: tiled, plain, and at three sizes.",
	controls = {
		Size = UILabs.Slider(64, 24, 128, 4),
	},
}, function(props)
	local extent = props.controls.Size

	local function labelled(name: string, element)
		return e(P.Group, {
			key = name,
			size = UDim2.fromOffset(extent + 16, extent + 34),
			children = {
				e(P.Group, {
					key = "Art",
					size = UDim2.fromOffset(extent, extent),
					position = UDim2.fromScale(0.5, 0),
					anchorPoint = Vector2.new(0.5, 0),
					children = { element },
				}),
				e(P.Label, {
					key = "Name",
					text = name,
					textSize = Theme.TextSize.Tiny,
					font = Theme.Font.Bold,
					color = Theme.Color.Gray,
					size = UDim2.new(1, 0, 0, 18),
					position = UDim2.fromScale(0, 1),
					anchorPoint = Vector2.new(0, 1),
				}),
			},
		})
	end

	local tiles = {}
	for index, name in ipairs(NAMES) do
		tiles[#tiles + 1] = labelled(
			name,
			e(Icon, {
				key = "Icon",
				glyph = name,
				gradient = Theme.Gradient[GRADIENTS[(index - 1) % #GRADIENTS + 1]],
				size = UDim2.fromScale(1, 1),
				radius = Theme.Radius.Chip,
			})
		)
	end

	local plain = {}
	for _, name in ipairs(NAMES) do
		plain[#plain + 1] = labelled(
			name .. " ",
			e(Icon, {
				key = "Icon",
				glyph = name,
				plain = true,
				size = UDim2.fromScale(1, 1),
			})
		)
	end

	local sizes = {}
	for _, size in ipairs({ 24, 36, 48, 72, 110 }) do
		sizes[#sizes + 1] = e(P.Group, {
			key = "Size" .. size,
			size = UDim2.fromOffset(120, 120),
			children = {
				e(Icon, {
					key = "Icon",
					glyph = "magnet",
					gradient = Theme.Gradient.Red,
					size = UDim2.fromOffset(size, size),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
				}),
			},
		})
	end

	return e(Harness.Gallery, {
		title = "Glyphs",
		sections = {
			{
				title = "Tiled",
				items = tiles,
				itemSize = UDim2.fromOffset(extent + 16, extent + 34),
				gap = 8,
			},
			{
				title = "Plain",
				items = plain,
				itemSize = UDim2.fromOffset(extent + 16, extent + 34),
				gap = 8,
			},
			{
				title = "Scaling (same component, 24 to 110 px)",
				items = sizes,
				itemSize = UDim2.fromOffset(120, 120),
			},
		},
	})
end)
