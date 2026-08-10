--[[
	CollectionScreen.luau

	COLLECTION index with SCRAP / MAGNETS / PETS tabs.

	Undiscovered entries keep their silhouette and footprint so the grid shows
	the shape of what is missing -- that gap is the reason players keep digging.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Format = require(UI.Format)
local GameData = require(UI.GameData)
local P = require(UI.Primitives)
local Buttons = require(UI.Components.Buttons)
local Indicators = require(UI.Components.Indicators)
local Cards = require(UI.Components.Cards)
local Overlays = require(UI.Components.Overlays)

local e = React.createElement

local TABS = {
	{ id = "SCRAP", text = "SCRAP", glyph = "scrap" },
	{ id = "MAGNETS", text = "MAGNETS", glyph = "magnet" },
	{ id = "PETS", text = "PETS", glyph = "paw" },
}

local function CollectionScreen(props)
	local state = props.state
	local actions = props.actions
	local tab, setTab = React.useState("SCRAP")

	local cells = {}
	local found, total = 0, 0

	if tab == "SCRAP" then
		for index, entry in ipairs(GameData.scrapIndex(state.discoveredScrap)) do
			total += 1
			if entry.discovered then
				found += 1
			end
			cells[#cells + 1] = e(Cards.CollectionCell, {
				key = entry.id,
				name = entry.name,
				rarity = entry.rarity,
				glyph = "scrap",
				model = entry.model,
				discovered = entry.discovered,
				best = entry.best,
				collected = entry.collected,
				layoutOrder = index,
			})
		end
	elseif tab == "MAGNETS" then
		for index, magnet in ipairs(GameData.magnets()) do
			total += 1
			local owned = state.ownedMagnets[magnet.id] == true
			if owned then
				found += 1
			end
			cells[#cells + 1] = e(Cards.CollectionCell, {
				key = magnet.id,
				name = magnet.name,
				rarity = magnet.rarity,
				glyph = "magnet",
				discovered = owned,
				best = magnet.range,
				collected = magnet.strength,
				layoutOrder = index,
			})
		end
	else
		for index, pet in ipairs(GameData.pets(state.ownedPets)) do
			total += 1
			if pet.owned then
				found += 1
			end
			cells[#cells + 1] = e(Cards.CollectionCell, {
				key = pet.id,
				name = pet.name,
				rarity = pet.rarity,
				glyph = "paw",
				discovered = pet.owned,
				best = 0,
				collected = pet.count,
				layoutOrder = index,
			})
		end
	end

	return e(Overlays.Modal, {
		key = props.key or "CollectionScreen",
		title = "Collection",
		glyph = "book",
		headerColor = Theme.Gradient.Purple,
		size = UDim2.fromOffset(1060, 700),
		onClose = actions.closeScreen,
		tabs = e(Buttons.TabBar, {
			key = "Tabs",
			tabs = TABS,
			active = tab,
			variant = "Premium",
			size = UDim2.fromScale(1, 1),
			hAlign = Enum.HorizontalAlignment.Left,
			onSelect = setTab,
		}),
		footerHeight = 54,
		footer = e(P.Group, {
			key = "Progress",
			size = UDim2.fromScale(1, 1),
			children = {
				e(P.Label, {
					key = "Label",
					text = "COLLECTION",
					textSize = Theme.TextSize.Small,
					font = Theme.Font.Bold,
					color = Theme.Color.Gray,
					align = Enum.TextXAlignment.Left,
					size = UDim2.new(0, 160, 1, 0),
				}),
				e(Indicators.ProgressBar, {
					key = "Bar",
					value = found,
					max = total,
					gradient = Theme.Gradient.Purple,
					height = 30,
					size = UDim2.new(1, -180, 0, 30),
					position = UDim2.fromScale(1, 0.5),
					anchorPoint = Vector2.new(1, 0.5),
					text = Format.fraction(found, total),
				}),
			},
		}),
		children = {
			e(P.Scroller, {
				key = "IndexGrid",
				padding = { right = 10, bottom = 6 },
				layout = P.grid({
					cell = UDim2.fromOffset(146, 168),
					padding = UDim2.fromOffset(12, 12),
				}),
				children = cells,
			}),
		},
	})
end

return CollectionScreen
