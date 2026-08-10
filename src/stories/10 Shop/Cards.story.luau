--[[
	Every shop card shape and backdrop, side by side.

	This is the story to open when a card looks wrong or you want to try a different
	shape for a product -- the whole point of it is that you can compare the three
	layouts and the three patterns without scrolling the real storefront or owning
	the right things.

	============================= WHERE TO TWEAK =============================

	  which shape a product     src/shared/UI/GameData.luau
	  gets, and its backdrop    -> PASS_STYLE / PRODUCT_STYLE, the `layout`,
	                               `span`, `pattern` and `features` fields.
	                               Nothing in the screen or the component needs
	                               touching to rearrange the shelf.

	    layout   "vertical" compact, three to a row; span 1
	             "hero"     big art left, title + copy right; span 2
	             "feature"  art left, feature list right; span 2
	    span     1 or 2 of the 3 columns; the layout supplies the default
	    pattern  "sunburst" | "rings" | "dots" | nil
	    features { { glyph, title, note } } -- what "feature" lists

	  card geometry             src/shared/UI/Components/Shop.luau
	                            -> COLUMN_WIDTH, HEIGHTS (per layout), SPANS,
	                               TIERS (art size + which effects a tier gets)

	  the backdrops themselves  src/shared/UI/Components/Shop.luau
	                            -> Shop.Pattern: PATTERN_RAYS, RING_SCALES,
	                               DOT_COLUMNS/DOT_ROWS

	  row packing, columns      src/shared/UI/Screens/ShopScreen.luau
	                            -> COLUMNS, GAP, BANNER_HEIGHT

	==========================================================================

	One rule worth knowing before you add a pattern: `sunburst` is built from rotated
	frames, and a rotated GuiObject escapes every ancestor's `ClipsDescendants`. It
	is contained only because it is centred in a square box at under 1.0 scale. Give
	it a wide box and it will paint across the screen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)

local Harness = require(script.Parent.Parent.Harness)

local Shop = UI.Components.Shop
local e = React.createElement

local FEATURES = {
	{ glyph = "coin", title = "Double Sale Value", note = "Every scrap sale pays out twice." },
	{ glyph = "upgrade", title = "Permanent", note = "Never expires and never runs out." },
	{ glyph = "recycle", title = "Survives Rebirth", note = "Keeps paying after every reset." },
}

--- One card, with everything the controls can vary folded in.
local function card(key: string, overrides)
	local props = {
		key = key,
		title = "2x Cash Forever",
		benefit = "Double all scrap sale earnings, permanently.",
		glyph = "coin",
		accent = "Gold",
		tier = 3,
		state = "Buy",
		robux = 299,
		onClick = function() end,
	}
	for name, value in pairs(overrides) do
		props[name] = value
	end
	return e(Shop.ProductCard, props)
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Shop cards",
	summary = "Every card layout, backdrop pattern and tier, side by side.",
	controls = {
		Tier = UILabs.Slider(3, 1, 3, 1),
		Badge = UILabs.Choose(
			{ "none", "Popular", "BestValue", "Premium", "Limited", "New", "Exclusive" },
			2
		),
		State = UILabs.Choose({ "Buy", "Owned", "Soon", "Equip", "Equipped" }, 1),
	},
}, function(props)
	local controls = props.controls
	local tier = math.floor(controls.Tier)
	local badge = if controls.Badge == "none" then nil else controls.Badge

	local common = { tier = tier, badge = badge, state = controls.State }

	local function with(extra)
		local merged = table.clone(common)
		for name, value in pairs(extra) do
			merged[name] = value
		end
		return merged
	end

	local width = Shop.COLUMN_WIDTH
	local wide = width * 2 + 16

	return e(Harness.Gallery, {
		sections = {
			{
				title = "vertical -- the workhorse, three to a row",
				itemSize = UDim2.fromOffset(width, Shop.HEIGHTS.vertical),
				items = {
					card("Plain", with({ layout = "vertical", pattern = nil })),
					card(
						"Sunburst",
						with({
							layout = "vertical",
							pattern = "sunburst",
							accent = "Pink",
							title = "Quantum Magnet",
							glyph = "magnet",
						})
					),
					card(
						"Rings",
						with({
							layout = "vertical",
							pattern = "rings",
							accent = "Blue",
							title = "Turbo Collector",
							glyph = "bolt",
						})
					),
					card(
						"Dots",
						with({
							layout = "vertical",
							pattern = "dots",
							accent = "Cyan",
							title = "Mega Storage",
							glyph = "crate",
						})
					),
				},
			},
			{
				title = "hero -- two columns: big art left, title and copy right",
				itemSize = UDim2.fromOffset(wide, Shop.HEIGHTS.hero),
				items = {
					card(
						"HeroSun",
						with({
							layout = "hero",
							pattern = "sunburst",
							accent = "Pink",
							title = "Quantum Magnet",
							benefit = "The strongest magnet in the yard. Never upgrade again.",
							glyph = "magnet",
							features = FEATURES,
							width = wide,
						})
					),
					card(
						"HeroDots",
						with({
							layout = "hero",
							pattern = "dots",
							accent = "Orange",
							title = "Mega Starter Bundle",
							benefit = "Everything at once, for far less than buying it apart.",
							glyph = "star",
							width = wide,
						})
					),
				},
			},
			{
				title = "feature -- two columns, sells a list instead of a line",
				itemSize = UDim2.fromOffset(wide, Shop.HEIGHTS.feature),
				items = {
					card(
						"FeatureList",
						with({
							layout = "feature",
							pattern = "sunburst",
							features = FEATURES,
							width = wide,
						})
					),
					--[[
						The same layout with no `features` written for it. Worth keeping in
						the gallery: a flagship card must degrade to its benefit line rather
						than rendering as a big empty box.
					]]
					card(
						"FeatureBare",
						with({
							layout = "feature",
							pattern = "rings",
							accent = "Blue",
							title = "Instant Rebirth",
							benefit = "Jump a whole rebirth without the grind.",
							glyph = "recycle",
							width = wide,
						})
					),
				},
			},
			{
				title = "featured banner -- full width, above the shelves",
				itemSize = UDim2.fromOffset(wide + width + 16, 300),
				items = {
					e(Shop.FeaturedBanner, {
						key = "Banner",
						title = "Quantum Magnet",
						benefit = "The strongest magnet in the yard. Never upgrade again.",
						glyph = "magnet",
						accent = "Pink",
						badge = badge or "Premium",
						features = FEATURES,
						pattern = "sunburst",
						robux = 399,
						state = controls.State,
						height = 300,
						onClick = function() end,
					}),
				},
			},
		},
	})
end)
