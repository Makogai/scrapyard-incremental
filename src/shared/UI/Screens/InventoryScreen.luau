--!nonstrict
--[[
	InventoryScreen.luau

	INVENTORY window: MAGNETS / POTIONS / TITLES tabs over the player's real inventory.

	Migrated to live data. Ownership comes from `state.ownedMagnets`, counts from
	`state.potionCounts`, and the catalogue from InventoryConfig via GameData.
	Clicking a card opens the details modal; equipping and using go through
	`actions`, which send bare intents.

	The kit's SKINS tab is gone: the game has no skin system, and a tab that only
	ever says COMING SOON is a tab that teaches players to ignore tabs.
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
local Progression = require(UI.Components.Progression)

local e = React.createElement

local TABS = {
	{ id = "MAGNETS", text = "MAGNETS", glyph = "magnet" },
	{ id = "POTIONS", text = "POTIONS", glyph = "potion" },
	{ id = "TITLES", text = "TITLES", glyph = "trophy" },
}

--[[
	The grid changes shape per tab, and TITLES is why.

	Magnets and potions are square art tiles; a title is a line of text that has to be shown at the
	size it will be worn, plus how it was earned, plus a button. That does not fit a 152px tile, so the
	titles tab lays out two wide cards per row instead -- see `Progression.TITLE_CARD`.
]]
local ITEM_CELL = UDim2.fromOffset(152, 190)
local TITLE_CELL = UDim2.fromOffset(Progression.TITLE_CARD.X, Progression.TITLE_CARD.Y)

local function InventoryScreen(props)
	local state = props.state
	local actions = props.actions

	local tab, setTab = React.useState("MAGNETS")

	local grid = {}
	local ownedCount, totalCount = 0, 0

	if tab == "MAGNETS" then
		for index, magnet in ipairs(GameData.magnets()) do
			local owned = state.ownedMagnets[magnet.id] == true
			totalCount += 1
			if owned then
				ownedCount += 1
			end

			-- An unowned magnet with a shop price is buyable, not a dead end.
			local lockText = if magnet.shopPrice
				then ("BUY " .. Format.money(magnet.shopPrice))
				else "GAME PASS"

			grid[#grid + 1] = e(Cards.MagnetCard, {
				key = magnet.id,
				name = magnet.name,
				rarity = magnet.rarity,
				image = magnet.image,
				equipped = state.equippedMagnet == magnet.id,
				locked = not owned,
				lockText = if owned then nil else lockText,
				layoutOrder = index,
				onClick = function()
					actions.openDetail("magnet", magnet.id)
				end,
			})
		end
	--[[
		`elseif`, not `else`. With a third tab in play an open `else` meant the potion list was also built
		for TITLES, so the titles grid came up with a column of "NONE OWNED" potion cards beside it.
	]]
	elseif tab == "POTIONS" then
		for index, potion in ipairs(GameData.consumables()) do
			local count = state.potionCounts[potion.id] or 0
			totalCount += 1
			if count > 0 then
				ownedCount += 1
			end

			grid[#grid + 1] = e(Cards.PotionCard, {
				key = potion.id,
				name = potion.name,
				rarity = potion.rarity,
				image = potion.image,
				owned = count,
				layoutOrder = index,
				onClick = function()
					actions.openDetail("potion", potion.id)
				end,
			})
		end
	end

	if tab == "TITLES" then
		--[[
			Every title, owned or not, sorted worst-to-best by the store. Locked ones stay in the list with
			their source named: a title nobody can see is not something anyone wants.
		]]
		for index, title in ipairs(state.titles or {}) do
			totalCount += 1
			if title.owned then
				ownedCount += 1
			end
			grid[#grid + 1] = e(Progression.TitleCard, {
				key = title.id,
				id = title.id,
				text = title.text,
				rarity = title.rarity,
				accent = title.accent,
				owned = title.owned,
				equipped = title.equipped,
				sourceName = title.sourceName,
				sourceDetail = title.sourceDetail,
				layoutOrder = index,
				onEquip = actions.equipTitle,
			})
		end
	end

	local titlesTab = tab == "TITLES"

	return e(Overlays.Modal, {
		key = props.key or "InventoryScreen",
		title = "Inventory",
		glyph = "bag",
		headerColor = Theme.Gradient.Blue,
		width = 1060,
		contentHeight = 470,
		onClose = actions.closeScreen,
		tabs = e(Buttons.TabBar, {
			key = "Tabs",
			tabs = TABS,
			active = tab,
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
					text = if tab == "MAGNETS"
						then "MAGNETS OWNED"
						elseif titlesTab then "TITLES EARNED"
						else "POTION TYPES HELD",
					textSize = Theme.TextSize.Small,
					font = Theme.Font.Bold,
					color = Theme.Color.Gray,
					align = Enum.TextXAlignment.Left,
					size = UDim2.new(0, 240, 1, 0),
				}),
				e(Indicators.ProgressBar, {
					key = "Bar",
					value = ownedCount,
					max = math.max(1, totalCount),
					gradient = if titlesTab then Theme.Gradient.Purple else Theme.Gradient.Blue,
					height = 30,
					size = UDim2.new(1, -260, 0, 30),
					position = UDim2.fromScale(1, 0.5),
					anchorPoint = Vector2.new(1, 0.5),
					text = Format.fraction(ownedCount, totalCount),
				}),
			},
		}),
		children = {
			e(P.Scroller, {
				key = "ItemGrid",
				padding = { right = 10, bottom = 6 },
				layout = P.grid({
					cell = if titlesTab then TITLE_CELL else ITEM_CELL,
					padding = UDim2.fromOffset(12, 12),
				}),
				children = grid,
			}),
		},
	})
end

return InventoryScreen
