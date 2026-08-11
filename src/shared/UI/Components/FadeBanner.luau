--!nonstrict
--[[
	FadeBanner.luau
	The banner look from the spin reward: accent gradient fading out to both edges, no outline.

	Extracted from `RewardToast` because it turned out to be the treatment we want for announcements
	generally -- the spin prize, the event strip, and notifications -- rather than one screen's idea.
	`RewardToast.Banner` is now a thin caller of this, so the prize banner and the event banner cannot
	drift apart.

	THE SHAPE. A wide bar with the accent gradient opaque in the middle and transparent at both ends,
	an optional icon well on the left, and two lines of text: what it is, and what it does. The
	symmetrical fade is what makes it read as a banner rather than a card -- a card has edges, a banner
	arrives.

	NO OUTLINE, EVER. Not an oversight and not a prop: an outline draws exactly the edges the fade
	exists to dissolve, and the two together look like a mistake. A surface that wants an outline wants
	`P.Panel`, which is what the "panel" variants elsewhere use.

	The fade is two mirrored ramps inside one `NumberSequence` rather than a stack of frames. A
	`UIGradient` is not a GuiObject, so unlike a rotated frame it cannot escape a clipping parent
	(AGENTS.md rule 11) -- which is why the event banner can keep `clip = true` and still fade.

	WITH AND WITHOUT AN ICON. Pass `glyph` or `image` and the text starts after the well; pass neither
	and it starts at the left inset instead. Nothing else changes, so a caller can decide per instance.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Motion = require(UI.Motion)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)
local Shine = require(UI.Components.Shine)

local e = React.createElement

local FadeBanner = {}

--[[
	Opaque in the middle, clear at both ends.

	One sequence with five keypoints, not two gradients: a single ramp can only fall off in one
	direction, and a symmetrical fade needs the mirror written explicitly.
]]
local FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.22, 0.15),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.78, 0.15),
	NumberSequenceKeypoint.new(1, 1),
})

--- Left inset when there is no icon, and the gap between the well and the text when there is.
local INSET = 22

--[[
	props:
		title        string            upper-cased for you
		detail       string?           second line
		glyph        string?           icon name; omit for a text-only banner
		image        string?           real art, which beats the glyph
		accent       string?           Theme key, default "Gold"
		shine        boolean?          sparkles and a glow, for the rare moments
		width        number?
		height       number?
		titleSize    number?           default Heading; toasts want something smaller
		detailColor  Color3?           default Positive
		entrance     boolean?          false to skip the spring, for things already animated
		wrap         boolean?          wrap and grow the text instead of truncating it
		textRef      ref?              attached to the text column, for callers that measure it
		right        element?          pinned to the right edge -- the event banner's timer lives here
		rightWidth   number?           how much room `right` takes, so the text stops short of it
		children     { element }?      extra layers, e.g. a measuring ref
]]
function FadeBanner.Banner(props)
	local accentName = props.accent or "Gold"
	local accentGradient = Theme.Gradient[accentName] or Theme.Gradient.Gold
	local accentColor = Theme.Color[accentName] or Theme.Color.Gold
	local width = props.width or 460
	local height = props.height or 92
	local hasIcon = props.glyph ~= nil or props.image ~= nil
	local wellExtent = math.min(height - 22, 70)
	local rightWidth = if props.right then (props.rightWidth or 110) else 0
	local wrap = props.wrap == true

	--- Springs in from slightly small, so it lands rather than appears.
	local entrance = Motion.useEntrance(Motion.Spring.Bouncy)

	--- Where the text starts, and how much room it has once the icon and the right slot are counted.
	local textLeft = if hasIcon then INSET + wellExtent + 16 else INSET
	local textWidth = math.max(40, width - textLeft - rightWidth - 12)

	local body = P.compact(
		--[[
			The bar itself. `BackgroundColor3` carries the accent and the gradient carries both the
			colour ramp and the transparency, so the fade is a property of the fill rather than a stack of
			overlays.
		]]
		e("Frame", {
			key = "Body",
			BackgroundColor3 = accentColor,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
		}, {
			e(
				"UIGradient",
				{ key = "Fade", Color = accentGradient, Transparency = FADE, Rotation = 0 }
			),
		}),
		--- A darker inner band, so white text stays readable over a pale accent.
		e("Frame", {
			key = "Ink",
			BackgroundColor3 = Theme.Color.Ink,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, math.max(20, height - 26)),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 2,
		}, {
			e("UIGradient", { key = "Fade", Transparency = FADE, Rotation = 0 }),
		}),
		if props.shine
			then e(Shine.Layer, {
				key = "Shine",
				glow = true,
				sparkles = true,
				color = accentColor,
				zIndex = 3,
			})
			else nil,
		--- The icon well: a solid disc so the art reads against the fade behind it.
		if hasIcon
			then e(P.Panel, {
				key = "Well",
				size = UDim2.fromOffset(wellExtent, wellExtent),
				position = UDim2.new(0, INSET, 0.5, 0),
				anchorPoint = Vector2.new(0, 0.5),
				gradient = Theme.Gradient.Slot,
				radius = wellExtent / 2,
				strokeThickness = 4,
				studs = false,
				zIndex = 4,
				children = {
					e(Icon, {
						key = "Glyph",
						glyph = props.glyph,
						image = props.image,
						plain = true,
						size = UDim2.fromOffset(wellExtent - 16, wellExtent - 16),
						position = UDim2.fromScale(0.5, 0.5),
						anchorPoint = Vector2.new(0.5, 0.5),
					}),
				},
			})
			else nil,
		--[[
			The text column.

			A raw `Frame` rather than `P.Group` so a `ref` can be attached: the toast feed measures its
			own text to decide how tall the card is, and that measurement has to see the labels this
			banner actually rendered.

			WRAP OR TRUNCATE, and the caller decides which. A one-line strip in the HUD wants truncation
			-- an event title that wraps would shove the countdown around every time it changed. A
			notification wants wrapping, because the server sends whole sentences as a title ("Magnet
			storage full, visit your crusher") and truncating one loses the instruction.
		]]
		e("Frame", {
			key = "Text",
			ref = props.textRef,
			BackgroundTransparency = 1,
			Size = if wrap
				then UDim2.fromOffset(textWidth, 0)
				else UDim2.fromOffset(textWidth, math.max(20, height - 22)),
			AutomaticSize = if wrap then Enum.AutomaticSize.Y else nil,
			Position = UDim2.new(0, textLeft, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			ZIndex = 4,
		}, {
			P.list({
				padding = 2,
				vAlign = if wrap then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Center,
			}),
			e(P.Label, {
				key = "Title",
				text = string.upper(tostring(props.title or "")),
				textSize = props.titleSize or Theme.TextSize.Heading,
				color = Theme.Color.White,
				align = Enum.TextXAlignment.Left,
				vAlign = if wrap then Enum.TextYAlignment.Top else nil,
				wrapped = wrap,
				truncate = if wrap then nil else Enum.TextTruncate.AtEnd,
				automaticSize = if wrap then Enum.AutomaticSize.Y else nil,
				size = if wrap
					then UDim2.fromScale(1, 0)
					else UDim2.new(
						1,
						0,
						0,
						if props.titleSize then props.titleSize + 6 else 30
					),
				layoutOrder = 1,
			}),
			if props.detail
				then e(P.Label, {
					key = "Detail",
					text = props.detail,
					textSize = Theme.TextSize.Body,
					font = Theme.Font.Bold,
					color = props.detailColor or Theme.Color.Positive,
					align = Enum.TextXAlignment.Left,
					vAlign = if wrap then Enum.TextYAlignment.Top else nil,
					wrapped = wrap,
					truncate = if wrap then nil else Enum.TextTruncate.AtEnd,
					automaticSize = if wrap then Enum.AutomaticSize.Y else nil,
					size = if wrap then UDim2.fromScale(1, 0) else UDim2.new(1, 0, 0, 24),
					layoutOrder = 2,
				})
				else nil,
		}),
		--- Whatever the caller pinned right: the event banner's countdown badge, for instance.
		if props.right
			then e(P.Group, {
				key = "Right",
				size = UDim2.fromOffset(rightWidth, height),
				position = UDim2.new(1, -10, 0.5, 0),
				anchorPoint = Vector2.new(1, 0.5),
				zIndex = 5,
				children = { props.right },
			})
			else nil
	)

	if props.children then
		for _, child in ipairs(props.children) do
			body[#body + 1] = child
		end
	end

	--[[
		The entrance scale goes on a child, never on this group: a `UIScale` here would fight any layout
		measuring this banner, and the toast feed measures every card it stacks.
	]]
	if props.entrance ~= false then
		table.insert(body, 1, e("UIScale", { key = "Entrance", Scale = entrance }))
	end

	return e(P.Group, {
		key = props.key or "FadeBanner",
		size = UDim2.fromOffset(width, height),
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex,
		children = body,
	})
end

return FadeBanner
