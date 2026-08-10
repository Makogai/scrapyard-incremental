--[[
	PlotScreen.luau

	CUSTOMIZE PLOT with GROUND / FENCE / CRUSHER / SIGN / THEME tabs.

	Every cosmetic carries its own action button, because the states differ per
	item: EQUIP when owned, SHOP when it is a paid cosmetic, PRESTIGE when it is
	gated on rebirths, LOCKED otherwise.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Mock = require(UI.Mock)
local P = require(UI.Primitives)
local Buttons = require(UI.Components.Buttons)
local Cards = require(UI.Components.Cards)
local Overlays = require(UI.Components.Overlays)

local e = React.createElement

local TABS = {
	{ id = "GROUND", text = "GROUND", glyph = "ground" },
	{ id = "FENCE", text = "FENCE", glyph = "fence" },
	{ id = "CRUSHER", text = "CRUSHER", glyph = "gear" },
	{ id = "SIGN", text = "SIGN", glyph = "sign" },
	{ id = "THEME", text = "THEME", glyph = "palette" },
}

local function PlotScreen(props)
	local state = props.state
	local actions = props.actions
	local tab, setTab = React.useState("GROUND")

	local entries = Mock.cosmetics[tab] or {}
	local equippedId = state.cosmetics[tab]

	local cards = {}
	for index, item in ipairs(entries) do
		local itemState = item.state or "owned"
		cards[#cards + 1] = e(Cards.CosmeticCard, {
			key = item.id,
			name = item.name,
			rarity = item.rarity,
			glyph = item.glyph,
			state = itemState,
			requirement = item.requirement,
			equipped = equippedId == item.id,
			layoutOrder = index,
			onEquip = function()
				if itemState == "shop" then
					actions.openScreen("shop")
				elseif itemState == "owned" then
					actions.setCosmetic(tab, item.id)
				end
			end,
		})
	end

	return e(Overlays.Modal, {
		key = props.key or "PlotScreen",
		title = "Customize Plot",
		glyph = "palette",
		headerColor = Theme.Gradient.Orange,
		size = UDim2.fromOffset(1060, 660),
		onClose = actions.closeScreen,
		tabs = e(Buttons.TabBar, {
			key = "Tabs",
			tabs = TABS,
			active = tab,
			tabSize = UDim2.new(0, 150, 1, 0),
			hAlign = Enum.HorizontalAlignment.Left,
			onSelect = setTab,
		}),
		children = {
			e(P.Scroller, {
				key = "CosmeticGrid",
				padding = { right = 10, bottom = 6 },
				layout = P.grid({
					cell = UDim2.fromOffset(176, 214),
					padding = UDim2.fromOffset(12, 12),
				}),
				children = cards,
			}),
		},
	})
end

return PlotScreen
