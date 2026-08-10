--[[
	The storefront: one scrolling page of FEATURED / GAME PASSES / SKINS / RESOURCES.

	Three columns, and a card may span two of them. That is deliberate: a shelf of
	identically shaped tiles reads as a table however good the individual tile is, so
	each section mixes a wide flagship, an asymmetric hero and compact cards. Which
	shape a product gets is data -- `layout`, `span`, `pattern` and `features` on
	`GameData`'s style maps -- so rearranging the shop never touches layout code.

	============================= WHERE TO TWEAK =============================

	  product copy, colour,   src/shared/UI/GameData.luau
	  tier, badge, featured,  -> PASS_STYLE and PRODUCT_STYLE. This is the file to
	  card shape, backdrop       open first for almost any shop change.

	                             layout   "vertical" (span 1) | "hero" (span 2)
	                                      | "feature" (span 2)
	                             span     override the layout's default
	                             pattern  "sunburst" | "rings" | "dots" | nil
	                             features { { glyph, title, note } }

	                             Every layout is CARD_HEIGHT tall and divides its
	                             plate exactly, so a card can never leave a gap
	                             above its button.

	  every shape and         src/stories/10 Shop/Cards.story.luau
	  backdrop, side by side     Compare layouts and patterns without scrolling the
	                             real storefront, or owning the right things.

	  card / banner internals src/shared/UI/Components/Shop.luau
	                          -> COLUMN_WIDTH and HEIGHTS are the grid geometry;
	                             TIERS controls art size and which effects a tier
	                             gets; Shop.Pattern is the backdrops; BADGES is the
	                             badge set; BUY_STATES the button states

	  the animations          src/shared/UI/Components/Shine.luau
	                          -> sweep / glow / sparkles, all TweenService. Read the
	                             clipping rule at the top before adding an effect:
	                             a rotated frame escapes its card entirely.

	  sections, row packing   src/shared/UI/Screens/ShopScreen.luau
	                          -> SECTIONS, COLUMNS, GAP, BANNER_HEIGHT, and the
	                             *Items() sources

	  prices                  src/shared/Config/MonetizationConfig.luau
	                          -> DisplayPrice is what the card shows; MarketplaceId
	                             is what Roblox charges. While an id is 0 the button
	                             reads COMING SOON, which is why every Robux item
	                             shows that today.

	  card titles             Shop.Title splits a lead token ("2X", "+2", "MEGA")
	                          and renders it large; tune leadSize / restSize there

	  pass icons              docs/ICON_PROMPTS.md -- generation prompts, and the
	                          Assets.Art["pass:<Id>"] keys the ids go into

	==========================================================================

	Note the SKINS section is thin right now: magnets are the only cosmetics that
	exist, and only the ones with a `ShopPrice` appear. Plot skins, crate skins and UI
	themes slot into `skinItems` the same way.
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
	name = "Shop",
	summary = "Storefront: one scrolling page of featured, passes, skins and resources.",
	controls = {
		Device = UILabs.Choose({ "desktop", "tablet", "mobile" }, 1),
		GameView = UILabs.Boolean(true),
	},
}, function(props)
	return e(Harness.Screen, {
		component = UI.Screens.Shop,
		device = props.controls.Device,
		gameView = props.controls.GameView,
	})
end)
