--[[
	The lava skin offer, in every area and in both of its sizes.

	THIS STORY EXISTS BECAUSE THE HUD IS WHERE RENDER ERRORS REACH PLAYERS. Three separate crashes have
	shipped from HUD blocks that no story rendered -- a bad `Theme` key, a nil in a plain children array,
	a method call on a free function -- and each one unmounted the whole HUD rather than one card. Every
	prop combination that can reach a player is drawn below, so any of those mistakes fails here first.

	WHAT TO LOOK AT

		NO PANEL AND NO WORDS. The offer is the skin turning in its own light, with the price UNDER it as
		bare gradient-lit text -- no plate, tilted a few degrees clockwise, nudging itself every few
		seconds. If something here needs a caption to make sense, the ART is what needs fixing, not the card.

		THE ART DOES NOT MOVE, on purpose. Only the light behind it turns. A breathing icon read as a
		wobble on the one object the player is trying to look at.

		The rays ROTATE, which means they ignore any clipping ancestor -- see `Shine.buildRays`. The boxes
		below are drawn deliberately tight so that if the wheel ever grows past its own footprint, it
		crosses a visible line here rather than painting over somebody's HUD.

		Owned, and unauthored. Both render nothing at all: the card is an offer, and an offer for something
		you own is dead chrome over the play area. Those outlined boxes should be EMPTY.

		The art is the pass thumbnail via `rbxthumb://`, so it only appears once Roblox has moderated the
		pass image. An empty middle means moderation, not a broken layout.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)
local PlotSkinConfig = require(ReplicatedStorage.Shared.Config.PlotSkinConfig)

local Harness = require(script.Parent.Parent.Harness)

local Theme = UI.Theme
local P = UI.Primitives
local Parts = UI.Screens.HudParts

local e = React.createElement

--- An outline the card sits inside, so "renders nothing" is visibly nothing rather than ambiguous.
local function Bounded(props)
	return e("Frame", {
		key = props.key,
		BackgroundColor3 = Theme.Color.PanelDark,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(props.width or 210, props.height or 250),
	}, {
		P.corner(6),
		P.stroke(Theme.Color.Gold, 1, { transparency = 0.5 }),
		e(Parts.PlotSkinOffer, {
			key = "Offer",
			compact = props.compact,
			plotTheme = props.plotTheme,
			entitlements = props.entitlements,
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			onBuy = function()
				print(`[story] buy {PlotSkinConfig.Pass} while on {props.plotTheme}`)
			end,
		}),
	})
end

local AREAS = {}
for areaId in PlotSkinConfig.ByArea do
	table.insert(AREAS, areaId)
end
table.sort(AREAS)

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Plot Skin Offer",
	summary = "The right-edge lava skin card: one pass, one model per area.",
	controls = {
		Area = UILabs.Choose(AREAS, 1),
		Owned = UILabs.Boolean(false),
		Compact = UILabs.Boolean(false),
	},
}, function(props)
	local controls = props.controls
	local owned = if controls.Owned then { [PlotSkinConfig.Pass] = true } else {}

	local everyArea = {}
	local everyAreaCompact = {}
	for index, areaId in AREAS do
		everyArea[index] = e(Bounded, {
			key = areaId,
			plotTheme = areaId,
			entitlements = {},
		})
		everyAreaCompact[index] = e(Bounded, {
			key = `Compact{areaId}`,
			compact = true,
			plotTheme = areaId,
			entitlements = {},
			width = 176,
			height = 118,
		})
	end

	return e(Harness.Gallery, {
		title = "Plot skin offer",
		sections = {
			{
				title = "Playground",
				items = {
					e(Bounded, {
						key = "Playground",
						compact = controls.Compact,
						plotTheme = controls.Area,
						entitlements = owned,
					}),
				},
				itemSize = UDim2.fromOffset(210, 250),
			},
			{
				title = "Every area — identical by design: one pass, and the art is the whole message",
				items = everyArea,
				itemSize = UDim2.fromOffset(210, 250),
			},
			{
				title = "Compact — the phone size, under the boost lane",
				items = everyAreaCompact,
				itemSize = UDim2.fromOffset(160, 190),
			},
			{
				title = "Owned — empty, because an offer you have taken is not an offer",
				items = {
					e(Bounded, {
						key = "Owned",
						plotTheme = AREAS[1],
						entitlements = { [PlotSkinConfig.Pass] = true },
					}),
				},
				itemSize = UDim2.fromOffset(210, 250),
			},
			{
				title = "An area with no lava model — empty, rather than selling a change that cannot happen",
				items = {
					e(Bounded, {
						key = "Unauthored",
						plotTheme = "ScrapCanyon",
						entitlements = {},
					}),
				},
				itemSize = UDim2.fromOffset(210, 250),
			},
		},
	})
end)
