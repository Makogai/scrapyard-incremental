--[[
	The event banner on its own, at several widths.

	Isolated because it is the one HUD block whose contents used to be placed by
	absolute offsets computed against its width -- so a width it was not tuned for
	pushed things outside it. It is now a clipped panel with an auto-layout, and
	this story is the proof: drag the Width control and nothing should ever cross
	the outline.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)

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
		Title = UILabs.String("SCRAP RUSH EVENT"),
		Detail = UILabs.String("3x scrap value in every area"),
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
				title = "Desktop 520 / mobile 366 / narrow 280 / very narrow 220",
				items = sizes,
				itemSize = UDim2.fromOffset(560, 92),
			},
		},
	})
end)
