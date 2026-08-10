--!nonstrict
--[[
	ShopScreen.luau
	The storefront: one long scrolling page, no tabs.

		FEATURED     the headline offer, full width
		GAME PASSES  permanent upgrades, from MonetizationConfig.Passes
		SKINS        cosmetics; magnets today, plot and crate skins later
		RESOURCES    one-off packs, from MonetizationConfig.Products

	One page rather than tabs on purpose: a player scrolls past everything you sell
	instead of having to guess which tab is worth opening. Sections are separated by
	`Shop.SectionHeader`, so the break is legible without a heavy panel doing it.

	THREE COLUMNS, MIXED SHAPES. The grid is three columns wide and a card may span
	two of them, so a shelf can read as "one flagship plus one" instead of a row of
	identical tiles. Which shape a product gets is data, not layout code: `layout`,
	`span` and `pattern` come off `GameData`'s style maps, and this file only packs
	whatever it is handed. Rows differ in height, cards inside a row match.

	The screen names no product. Colour identity, tier, badge, featured flag, the
	backdrop pattern and the short selling copy all live in those style maps, so a
	new product is a config entry plus a style row and this file does not change. A
	new section is one entry in `SECTIONS`.

	Purchases go through `actions.purchase`, which sends nothing but an id -- the
	server owns every price. A product whose `MarketplaceId` is still 0 shows
	COMING SOON rather than a dead button.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local GameData = require(UI.GameData)
local P = require(UI.Primitives)
local Overlays = require(UI.Components.Overlays)
local ShopCards = require(UI.Components.Shop)

local e = React.createElement

local COLUMN = ShopCards.COLUMN_WIDTH
local HEIGHTS = ShopCards.HEIGHTS
local SPANS = ShopCards.SPANS
local GAP = 16
--- Three across. The window is sized from this, so widening one widens both.
local COLUMNS = 3
local BANNER_HEIGHT = 300

--[[
	The page, in order. `accent` tints that section's divider; `source` says where
	its products come from.

	Adding BOOSTERS, LIMITED or BUNDLES later is one row here plus a `source`.
]]
local SECTIONS = {
	{ id = "PASSES", title = "Game Passes", accent = "Gold", source = "passes" },
	{ id = "SKINS", title = "Skins", accent = "Cyan", source = "skins" },
	{ id = "RESOURCES", title = "Resources", accent = "Green", source = "products" },
}

--- Passes, normalised to what `ProductCard` wants.
local function passItems(state): { any }
	local list = {}
	for _, pass in ipairs(GameData.passes()) do
		table.insert(list, {
			id = pass.id,
			kind = "Pass",
			title = pass.name,
			benefit = pass.benefit,
			glyph = pass.glyph,
			image = pass.image,
			accent = pass.accent,
			tier = pass.tier,
			badge = pass.badge,
			featured = pass.featured,
			layout = pass.layout,
			span = pass.span,
			pattern = pass.pattern,
			features = pass.features,
			robux = pass.robux,
			marketplaceId = pass.marketplaceId,
			owned = state.entitlements[pass.id] == true,
		})
	end
	return list
end

--- One-off products. Consumables are always buyable; there is nothing to own.
local function productItems(): { any }
	local list = {}
	for _, product in ipairs(GameData.products("all")) do
		table.insert(list, {
			id = product.id,
			kind = "Product",
			title = product.name,
			benefit = product.benefit,
			glyph = product.glyph,
			accent = product.accent,
			tier = product.tier,
			badge = product.badge,
			featured = product.featured,
			layout = product.layout,
			span = product.span,
			pattern = product.pattern,
			features = product.features,
			robux = product.robux,
			marketplaceId = product.marketplaceId,
			owned = false,
		})
	end
	return list
end

--[[
	Cosmetics. Magnets are what exists today and they cost cash rather than Robux,
	which the card handles because the button takes either. Rarity is the colour
	identity a cosmetic already has, so it is reused as the accent.
]]
local function skinItems(state): { any }
	local list = {}
	for _, magnet in ipairs(GameData.magnets()) do
		if magnet.shopPrice == nil then
			continue
		end
		local owned = state.ownedMagnets[magnet.id] == true
		table.insert(list, {
			id = magnet.id,
			kind = "Magnet",
			title = magnet.name,
			benefit = magnet.description,
			glyph = "magnet",
			image = magnet.image,
			accent = magnet.rarity,
			tier = if magnet.rarity == "Radioactive" or magnet.rarity == "Diamond" then 3 else 2,
			badge = if magnet.rarity == "Radioactive" then "Exclusive" else nil,
			pattern = "rings",
			cash = magnet.shopPrice,
			owned = owned,
			equipped = state.equippedMagnet == magnet.id,
		})
	end
	return list
end

--- How many columns an entry occupies, clamped so nothing can overflow a row.
local function spanOf(entry): number
	local layout = entry.layout or "vertical"
	local span = entry.span or SPANS[layout] or 1
	return math.clamp(span, 1, COLUMNS)
end

local function widthOf(span: number): number
	return COLUMN * span + GAP * (span - 1)
end

local function ShopScreen(props)
	local state = props.state
	local actions = props.actions

	local sources = {
		passes = passItems(state),
		products = productItems(),
		skins = skinItems(state),
	}

	--[[
		The headline offer, chosen across the whole shop rather than per section: with
		one page there is one top slot, and it should hold the single best thing on
		sale. A product can claim it; otherwise the loudest tier wins, so the slot is
		never empty just because nobody set a flag.
	]]
	local featured = nil
	local loudest = nil
	for _, source in ipairs({ "passes", "products", "skins" }) do
		for _, entry in ipairs(sources[source]) do
			if entry.featured and featured == nil then
				featured = entry
			end
			if loudest == nil or (entry.tier or 1) > (loudest.tier or 1) then
				loudest = entry
			end
		end
	end
	-- Two passes, not one: a flagged product has to beat a merely loud one, and a
	-- single loop that assigned as it went let whichever card came first win.
	featured = featured or loudest

	--- Which button state an entry is in. One place, so nothing can disagree.
	local function stateFor(entry): string
		if entry.equipped then
			return "Equipped"
		elseif entry.owned then
			return if entry.kind == "Magnet" then "Equip" else "Owned"
		elseif entry.kind ~= "Magnet" and entry.marketplaceId == 0 then
			return "Soon"
		end
		return "Buy"
	end

	local function activate(entry)
		return function()
			if entry.kind == "Magnet" then
				if entry.owned then
					actions.equipMagnet(entry.id)
				else
					actions.buyMagnet(entry.id)
				end
				return
			end

			if entry.marketplaceId == 0 then
				actions.notify({
					title = "Not available yet",
					body = entry.title .. " is not on sale.",
					glyph = "clock",
					accent = "Yellow",
				})
				return
			end
			actions.purchase(entry.id, entry.kind)
		end
	end

	--[[
		The page is packed as plain data first, then rendered. Two steps because a
		card has to be told its row's height, and a row's height is not known until
		every card in it has been placed -- building elements as we went would mean
		guessing, or rewriting them afterwards.
	]]
	local blocks = {}

	blocks[#blocks + 1] = { kind = "header", id = "Featured", text = "Featured", accent = "Pink" }
	if featured then
		blocks[#blocks + 1] = { kind = "banner", entry = featured }
	end

	for _, section in ipairs(SECTIONS) do
		local items = sources[section.source]
		if #items == 0 then
			continue
		end

		blocks[#blocks + 1] = {
			kind = "header",
			id = section.id,
			text = section.title,
			accent = section.accent,
		}

		--[[
			Pack into rows of `COLUMNS` worth of span. A card that will not fit in the
			columns left closes the row and starts the next one, so a two-wide flagship
			is never split, never dropped, and never overflows the shelf.
		]]
		local row, used, tallest, rowIndex = {}, 0, HEIGHTS.vertical, 0

		local function flush()
			if #row == 0 then
				return
			end
			rowIndex += 1
			blocks[#blocks + 1] = {
				kind = "row",
				id = section.id .. "Row" .. rowIndex,
				height = tallest,
				items = row,
			}
			row, used, tallest = {}, 0, HEIGHTS.vertical
		end

		for index, entry in ipairs(items) do
			local span = spanOf(entry)
			if used + span > COLUMNS then
				flush()
			end

			local layout = entry.layout or "vertical"
			-- Cards in a row share the row's height, so the row reads as one shelf.
			tallest = math.max(tallest, HEIGHTS[layout] or HEIGHTS.vertical)
			used += span
			row[#row + 1] = { entry = entry, span = span, layout = layout, index = index }

			if used >= COLUMNS then
				flush()
			end
		end
		flush()
	end

	local page = {}
	for order, block in ipairs(blocks) do
		if block.kind == "header" then
			page[#page + 1] = e(ShopCards.SectionHeader, {
				key = block.id .. "Header",
				text = block.text,
				accent = Theme.Gradient[block.accent],
				layoutOrder = order,
			})
		elseif block.kind == "banner" then
			local entry = block.entry
			page[#page + 1] = e(ShopCards.FeaturedBanner, {
				key = "Featured",
				title = entry.title,
				benefit = entry.benefit,
				glyph = entry.glyph,
				image = entry.image,
				accent = entry.accent,
				badge = entry.badge or "Popular",
				features = entry.features,
				pattern = entry.pattern,
				robux = entry.robux,
				cash = entry.cash,
				state = stateFor(entry),
				height = BANNER_HEIGHT,
				layoutOrder = order,
				onClick = activate(entry),
			})
		else
			local cards = {}
			for slot, item in ipairs(block.items) do
				local entry = item.entry
				cards[slot] = e(ShopCards.ProductCard, {
					key = entry.id,
					title = entry.title,
					benefit = entry.benefit,
					glyph = entry.glyph,
					image = entry.image,
					accent = entry.accent,
					tier = entry.tier,
					badge = entry.badge,
					layout = item.layout,
					pattern = entry.pattern,
					features = entry.features,
					width = widthOf(item.span),
					height = block.height,
					robux = entry.robux,
					cash = entry.cash,
					state = stateFor(entry),
					-- Staggered, so a page of cards does not sweep in unison.
					delay = (item.index % 5) * 0.5,
					layoutOrder = item.index,
					onClick = activate(entry),
				})
			end
			page[#page + 1] = e(P.Group, {
				key = block.id,
				size = UDim2.new(1, 0, 0, block.height),
				layoutOrder = order,
				layout = P.list({
					direction = Enum.FillDirection.Horizontal,
					padding = GAP,
					hAlign = Enum.HorizontalAlignment.Center,
				}),
				children = cards,
			})
		end
	end

	return e(Overlays.Modal, {
		key = props.key or "ShopScreen",
		title = "Shop",
		glyph = "basket",
		headerColor = Theme.Gradient.Pink,
		-- Sized to three cards across, plus the scroller's own inset.
		width = COLUMN * COLUMNS + GAP * (COLUMNS - 1) + 88,
		contentHeight = 660,
		onClose = actions.closeScreen,
		children = {
			e(P.Scroller, {
				key = "Page",
				size = UDim2.fromScale(1, 1),
				padding = { right = 12, bottom = 10, top = 2 },
				layout = P.list({
					direction = Enum.FillDirection.Vertical,
					padding = GAP,
					hAlign = Enum.HorizontalAlignment.Center,
				}),
				children = page,
			}),
		},
	})
end

return ShopScreen
