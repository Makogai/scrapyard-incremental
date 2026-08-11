--[[
	The event banner on its own, at several widths and in both of its states.

	Isolated because it is the one HUD block whose contents used to be placed by
	absolute offsets computed against its width -- so a width it was not tuned for
	pushed things outside it. It is now a clipped panel with an auto-layout, and
	this story is the proof: drag the Width control and nothing should ever cross
	the outline.

	The other thing to look at here is LIVE versus UPCOMING. The banner used to
	invent its own content when given no props, which is how every player ended up
	permanently seeing a 3x event that did not exist. It now renders only what it is
	given, and the HUD renders it only when the schedule has something -- so the two
	states below are the only two that can reach a player.

	Every row is built from the real `EventConfig` entries, so adding an event to the
	schedule shows it here with no edit to this story.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)

local Harness = require(script.Parent.Parent.Harness)

local Theme = UI.Theme
local P = UI.Primitives
local Parts = UI.Screens.HudParts

local e = React.createElement

--- A dashed frame around the banner, so anything escaping is obvious.
local function Bounded(props)
	return e("Frame", {
		key = props.key,
		BackgroundColor3 = Theme.Color.PanelDark,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(props.width + 24, (props.height or 56) + 24),
	}, {
		P.corner(6),
		P.stroke(Theme.Color.Gold, 1, { transparency = 0.5 }),
		e(Parts.EventBanner, {
			key = "Banner",
			width = props.width,
			height = props.height,
			title = props.title,
			detail = props.detail,
			glyph = props.glyph,
			accent = props.accent,
			live = props.live,
			variant = props.variant,
			seconds = props.seconds,
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
		}),
	})
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Event Banner",
	summary = "The banner at desktop, mobile and deliberately awkward widths.",
	controls = {
		Width = UILabs.Slider(520, 200, 900, 10),
		Height = UILabs.Slider(56, 38, 80, 2),
		Title = UILabs.String("SCRAP RUSH"),
		Detail = UILabs.String("2x scrap value all weekend"),
		Live = UILabs.Boolean(true),
		--[[
			Overrides `Theme.Variant.EventBanner` for this story. "fade" is what ships -- the spin-reward
			treatment with no outline -- and "panel" is the outlined slab it replaced, kept switchable so
			the choice stays a choice.
		]]
		Variant = UILabs.Choose({ "fade", "panel" }, 1),
	},
}, function(props)
	local controls = props.controls

	local sizes = {}
	for _, width in ipairs({ 520, 366, 280, 220 }) do
		sizes[#sizes + 1] = e(Bounded, {
			key = "W" .. width,
			width = width,
			height = if width < 400 then 44 else 56,
			seconds = 2734,
		})
	end

	--[[
		One row per scheduled event, live, then the same list as it looks when the event is still to
		come. If a new event lands in `EventConfig` with a glyph or accent that does not read against
		the panel, this is where it shows up.
	]]
	local liveStates = {}
	local upcomingStates = {}
	for index, definition in ipairs(EventConfig.Events) do
		liveStates[index] = e(Bounded, {
			key = `Live{definition.Id}`,
			width = 520,
			height = 56,
			title = definition.Title,
			detail = definition.Detail,
			glyph = definition.Glyph,
			accent = definition.Accent,
			live = true,
			variant = controls.Variant,
			seconds = 5_400,
		})
		upcomingStates[index] = e(Bounded, {
			key = `Next{definition.Id}`,
			width = 520,
			height = 56,
			title = definition.Title,
			detail = `Next event: {definition.Detail}`,
			glyph = definition.Glyph,
			accent = definition.Accent,
			live = false,
			variant = controls.Variant,
			seconds = 176_400,
		})
	end

	return e(Harness.Gallery, {
		title = "Event banner",
		sections = {
			{
				title = "Playground",
				items = {
					e(Bounded, {
						key = "Playground",
						width = controls.Width,
						height = controls.Height,
						title = controls.Title,
						detail = controls.Detail,
						seconds = 2734,
					}),
				},
				itemSize = UDim2.fromOffset(controls.Width + 30, controls.Height + 30),
			},
			{
				title = "No icon — the text closes the gap rather than leaving a hole",
				items = {
					e(Bounded, {
						key = "NoIcon",
						width = 520,
						height = 56,
						title = "SCRAP RUSH",
						detail = "2x scrap value all weekend",
						accent = "Gold",
						live = true,
						variant = controls.Variant,
						seconds = 5_400,
					}),
				},
				itemSize = UDim2.fromOffset(560, 92),
			},
			{
				title = "Live — every event in the schedule",
				items = liveStates,
				itemSize = UDim2.fromOffset(560, 92),
			},
			{
				title = "Upcoming — the muted state, counting down to the start",
				items = upcomingStates,
				itemSize = UDim2.fromOffset(560, 92),
			},
			{
				title = "Desktop 520 / mobile 366 / narrow 280 / very narrow 220",
				items = sizes,
				itemSize = UDim2.fromOffset(560, 92),
			},
		},
	})
end)
