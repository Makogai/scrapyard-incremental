--!nonstrict
--[[
	InventoryScreen.luau

	INVENTORY window: MAGNETS / POTIONS / TITLES tabs over the player's real inventory.

	Migrated to live data. Ownership comes from `state.ownedMagnets`, counts from
	`state.potionCounts`, and the catalogue from InventoryConfig via GameData.
	Clicking a card opens the details modal; equipping and using go through
	`actions`, which send bare intents.

	SKINS is back. It was removed while the game had no skin system -- a tab that
	only ever says COMING SOON teaches players to ignore tabs -- and it returned
	with plot skins, which are a real thing to own and, more to the point, a real
	thing to take back OFF. See `PlotSkinConfig.Catalogue`.
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
local PlotSkinConfig = require(ReplicatedStorage.Shared.Config.PlotSkinConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)

local e = React.createElement

local TABS = {
	{ id = "MAGNETS", text = "MAGNETS", glyph = "magnet" },
	{ id = "POTIONS", text = "POTIONS", glyph = "potion" },
	{ id = "TITLES", text = "TITLES", glyph = "trophy" },
	{ id = "SKINS", text = "SKINS", glyph = "area" },
}

--[[
	The grid changes shape per tab, and TITLES is why.

	Magnets and potions are square art tiles; a title is a line of text that has to be shown at the
	size it will be worn, plus how it was earned, plus a button. That does not fit a 152px tile, so the
	titles tab lays out two wide cards per row instead -- see `Progression.TITLE_CARD`.
]]
local ITEM_CELL = UDim2.fromOffset(152, 190)
local TITLE_CELL = UDim2.fromOffset(Progression.TITLE_CARD.X, Progression.TITLE_CARD.Y)
--- `Cards.CosmeticCard` is 176x214 and carries its own button, so it needs more room than an item tile.
local SKIN_CELL = UDim2.fromOffset(190, 228)

local function InventoryScreen(props)
	local state = props.state
	local actions = props.actions

	local tab, setTab = React.useState("MAGNETS")

	local grid = {}
	local ownedCount, totalCount = 0, 0

	--[[
		OWNED ONLY, IN BOTH ITEM TABS.

		This window used to list every magnet and every potion in the game, with the unowned ones wearing a
		"BUY 25,000" or "GAME PASS" plate that opened a purchase -- so the inventory was a second shop, and
		the answer to "what do I actually have" was buried among things the player does not. Buying lives in
		the Shop and the magnet shop; this window answers ownership.

		The footer bar still counts against the FULL set, because "3 of 8 magnets" is collection progress
		rather than a sales pitch, and it is the one thing here worth knowing about what you do not own.
	]]
	if tab == "MAGNETS" then
		for index, magnet in ipairs(GameData.magnets()) do
			totalCount += 1
			if state.ownedMagnets[magnet.id] == true then
				ownedCount += 1
				grid[#grid + 1] = e(Cards.MagnetCard, {
					key = magnet.id,
					name = magnet.name,
					rarity = magnet.rarity,
					image = magnet.image,
					equipped = state.equippedMagnet == magnet.id,
					layoutOrder = index,
					onClick = function()
						actions.openDetail("magnet", magnet.id)
					end,
				})
			end
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
	end

	--[[
		PLOT SKINS: the standard build first, then anything owned.

		OWNED ONLY, like the magnet and potion tabs -- this window answers "what do I have", and listing the
		unowned ones with a SHOP plate is what turned the inventory into a second shop the last time. The
		footer still counts against every skin, because that is collection progress rather than a sales pitch.

		The standard yard is always listed and always owned: it is how a skin comes off.
	]]
	if tab == "SKINS" then
		local worn = state.plotSkin or ""
		for index, entry in PlotSkinConfig.Catalogue do
			local standard = entry.Id == ""
			local owned = standard or (state.entitlements or {})[entry.Id] == true
			totalCount += 1
			if owned then
				ownedCount += 1
				local pass = MonetizationConfig.Passes[entry.Id]
				grid[#grid + 1] = e(Cards.CosmeticCard, {
					key = if standard then "Standard" else entry.Id,
					name = entry.Name,
					rarity = entry.Rarity,
					glyph = entry.Glyph,
					--[[
						The pass thumbnail, so the card wears the same art as the offer and the purchase
						prompt. The standard yard has no pass and falls back to its glyph.
					]]
					image = if pass ~= nil and pass.MarketplaceId > 0
						then `rbxthumb://type=GamePass&id={pass.MarketplaceId}&w=150&h=150`
						else nil,
					equipped = worn == entry.Id,
					state = "owned",
					size = SKIN_CELL,
					layoutOrder = index,
					onEquip = function()
						actions.equipSkin(entry.Id)
					end,
				})
			end
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

	--[[
		An empty grid has to say something. Filtering to owned items means a new player opens POTIONS to
		nothing at all, and a blank panel reads as a bug rather than as "you have none yet".
	]]
	if #grid == 0 then
		grid[1] = e(P.Label, {
			key = "Empty",
			text = if tab == "MAGNETS"
				then "NO MAGNETS YET -- BUY ONE FROM THE MAGNET SHOP"
				elseif tab == "POTIONS" then "NO POTIONS YET -- BUY THEM IN THE SHOP"
				elseif tab == "SKINS" then "NO SKINS YET -- THE LAVA SKIN IS IN THE SHOP"
				else "NO TITLES YET",
			textSize = Theme.TextSize.Small,
			font = Theme.Font.Bold,
			color = Theme.Color.GrayDark,
			size = UDim2.new(1, 0, 0, 120),
		})
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
						elseif tab == "SKINS" then "PLOT SKINS OWNED"
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
					cell = if titlesTab
						then TITLE_CELL
						elseif tab == "SKINS" then SKIN_CELL
						else ITEM_CELL,
					padding = UDim2.fromOffset(12, 12),
				}),
				children = grid,
			}),
		},
	})
end

return InventoryScreen
