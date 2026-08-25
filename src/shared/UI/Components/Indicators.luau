--[[
	Indicators.luau
	Read-only display components.

		ProgressBar     large colourful meter with an inline label
		RarityBadge     bright rarity tag
		QuantityBadge   "x12" corner pip for consumables
		TimerBadge      countdown pip with a clock glyph
		Badge           generic text pip (NEW!, BEST VALUE, EQUIPPED...)
		StatPill        the plain HUD readout: slab, icon on the left, value
		CurrencyDisplay HUD currency row: icon, value, optional + button
		StatRow         label / value pair used in details panels
		PriceTag        cash or Robux price with the matching glyph
		Checkmark       green tick used for equipped and claimed states
		LockOverlay     dim wash plus padlock for locked cards
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Assets = require(UI.Assets)
local Format = require(UI.Format)
local Motion = require(UI.Motion)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)
local Buttons = require(script.Parent.Buttons)

local e = React.createElement

local Indicators = {}

--------------------------------------------------------------------------------
-- ProgressBar
--------------------------------------------------------------------------------

--[[
	props:
		value, max     numbers
		gradient       ColorSequence?   fill colour
		text           string?          overrides the default "value / max"
		height         number?
		showFraction   boolean?         default true
		full           boolean?         forces the FULL styling
		fullText       string?          default "STORAGE FULL!"
]]
function Indicators.ProgressBar(props)
	local max = math.max(1, props.max or 1)
	local value = math.clamp(props.value or 0, 0, max)
	local ratio = value / max
	local isFull = props.full == true or ratio >= 1

	-- The fill springs to its target rather than snapping, which is what makes
	-- the storage meter feel like it is filling as scrap comes in.
	local fill = Motion.useSpring(ratio, Motion.Spring.Gentle)

	local height = props.height or 34
	local radius = props.radius or math.floor(height / 2.6)
	local fillGradient = if isFull
		then Theme.Gradient.Red
		else (props.gradient or Theme.Gradient.Green)

	local label = props.text
	if label == nil and props.showFraction ~= false then
		if isFull and props.fullText then
			label = props.fullText
		else
			label = Format.comma(value) .. " / " .. Format.comma(max)
		end
	end

	return e(
		"Frame",
		{
			key = props.key or "ProgressBar",
			BackgroundColor3 = props.trackColor or Theme.Color.PanelDark,
			BorderSizePixel = 0,
			Size = props.size or UDim2.new(1, 0, 0, height),
			Position = props.position,
			AnchorPoint = props.anchorPoint,
			LayoutOrder = props.layoutOrder,
			ZIndex = props.zIndex,
		},
		P.compact(
			P.corner(radius),
			P.stroke(Theme.Color.Outline, props.strokeThickness or Theme.Stroke.Card),
			-- Fill lives inside a clipping frame so its own rounding never pokes
			-- outside the track.
			e("Frame", {
				key = "Track",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ClipsDescendants = true,
				ZIndex = 2,
			}, {
				P.corner(radius, "TrackCorner"),
				e("Frame", {
					key = "Fill",
					BackgroundColor3 = Theme.Color.White,
					BorderSizePixel = 0,
					Size = Motion.fillX(fill),
				}, {
					P.corner(radius),
					P.gradient(fillGradient),
					e(P.Gloss, { key = "Gloss", radius = radius, strength = 0.62, height = 0.5 }),
				}),
			}),
			if label
				then e(P.Label, {
					key = "Value",
					text = label,
					textSize = props.textSize or math.floor(height * 0.5),
					zIndex = 3,
				})
				else nil,
			if props.icon
				then e(Icon, {
					key = "Icon",
					glyph = props.icon,
					plain = true,
					size = UDim2.fromOffset(height - 8, height - 8),
					position = UDim2.new(0, 6, 0.5, 0),
					anchorPoint = Vector2.new(0, 0.5),
					zIndex = 4,
				})
				else nil
		)
	)
end

--------------------------------------------------------------------------------
-- Badges
--------------------------------------------------------------------------------

function Indicators.Badge(props)
	local textSize = props.textSize or Theme.TextSize.Tiny
	return e(P.Chip, {
		key = props.key or "Badge",
		gradient = props.gradient or Theme.Gradient.Blue,
		color = props.color or Theme.Color.Blue,
		size = props.size or UDim2.fromOffset(0, textSize + 14),
		automaticSize = if props.size then nil else Enum.AutomaticSize.X,
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex or 6,
		radius = props.radius or Theme.Radius.Small,
		children = P.compact(
			P.padding({ x = 8 }, "Inset"),
			e(P.Label, {
				key = "Text",
				-- Above the chip it sits on: under ZIndexBehavior.Global a label at
				-- or below its container's ZIndex is hidden by it.
				zIndex = (props.zIndex or 6) + 1,
				text = props.text,
				textSize = textSize,
				color = props.textColor or Theme.Color.White,
				-- Dark label text drops the dark outline, or the two merge into a
				-- solid black smear on a bright chip.
				stroke = if props.stroke ~= nil
					then props.stroke
					elseif props.textColor and Theme.isDark(props.textColor) then false
					else nil,
				size = UDim2.fromScale(1, 1),
				automaticSize = if props.size then nil else Enum.AutomaticSize.X,
			})
		),
	})
end

function Indicators.RarityBadge(props)
	local style = Theme.rarity(props.rarity)
	return e(Indicators.Badge, {
		key = props.key or "Rarity",
		text = string.upper(props.text or style.label),
		gradient = style.gradient,
		color = style.color,
		textSize = props.textSize or Theme.TextSize.Tiny,
		size = props.size,
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex,
	})
end

function Indicators.QuantityBadge(props)
	return e(Indicators.Badge, {
		key = props.key or "Quantity",
		text = "x" .. Format.comma(props.count or 0),
		gradient = props.gradient or Theme.Gradient.PanelDeep,
		color = Theme.Color.PanelDark,
		textSize = props.textSize or Theme.TextSize.Small,
		position = props.position or UDim2.new(1, -6, 1, -6),
		anchorPoint = props.anchorPoint or Vector2.new(1, 1),
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex or 8,
	})
end

--[[
	Clock glyph plus a countdown.

	`bare` drops the chip behind it and leaves the glyph and the digits on their own. On a dark panel
	the chip gives the timer an edge to sit against; on a surface that is already fading out -- the
	event banner -- that edge is one more box on a strip whose whole point is not having any, so the
	bare form reads as part of the banner rather than as a control parked on it.

	Both forms share the format, which is the reason this is a flag rather than a second component:
	`Format.timer` should not have two callers that can disagree.
]]
function Indicators.TimerBadge(props)
	local textSize = props.textSize or Theme.TextSize.Small

	if props.bare then
		return e(P.Group, {
			key = props.key or "Timer",
			size = props.size or UDim2.fromOffset(96, textSize + 8),
			position = props.position,
			anchorPoint = props.anchorPoint,
			layoutOrder = props.layoutOrder,
			zIndex = props.zIndex,
			layout = P.list({
				direction = Enum.FillDirection.Horizontal,
				padding = 5,
				hAlign = Enum.HorizontalAlignment.Right,
				vAlign = Enum.VerticalAlignment.Center,
			}),
			children = {
				e(Icon, {
					key = "Icon",
					glyph = "clock",
					plain = true,
					size = UDim2.fromOffset(textSize + 4, textSize + 4),
					layoutOrder = 1,
				}),
				e(P.Label, {
					key = "Value",
					text = Format.timer(props.seconds or 0),
					textSize = textSize,
					color = props.textColor or Theme.Color.White,
					size = UDim2.fromOffset(0, textSize + 4),
					automaticSize = Enum.AutomaticSize.X,
					layoutOrder = 2,
				}),
			},
		})
	end

	return e(P.Chip, {
		key = props.key or "Timer",
		gradient = props.gradient or Theme.Gradient.PanelDeep,
		color = Theme.Color.PanelDark,
		size = props.size or UDim2.fromOffset(0, textSize + 16),
		automaticSize = if props.size then nil else Enum.AutomaticSize.X,
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex,
		radius = Theme.Radius.Small,
		-- Passed as `layout`, not as a child: see the note on P.Chip.
		layout = P.list({
			direction = Enum.FillDirection.Horizontal,
			padding = 5,
			hAlign = Enum.HorizontalAlignment.Center,
			vAlign = Enum.VerticalAlignment.Center,
		}),
		children = {
			P.padding({ x = 7 }, "Inset"),
			e(Icon, {
				key = "Icon",
				glyph = "clock",
				plain = true,
				size = UDim2.fromOffset(textSize + 2, textSize + 2),
				layoutOrder = 1,
			}),
			e(P.Label, {
				key = "Value",
				text = Format.timer(props.seconds or 0),
				textSize = textSize,
				color = props.textColor or Theme.Color.White,
				size = UDim2.fromOffset(0, textSize + 4),
				automaticSize = Enum.AutomaticSize.X,
				layoutOrder = 2,
			}),
		},
	})
end

--- Green tick, used for equipped items, claimed days and the current area.
function Indicators.Checkmark(props)
	local extent = props.extent or 30
	return e(P.Chip, {
		key = props.key or "Check",
		gradient = props.gradient or Theme.Gradient.Green,
		color = Theme.Color.GreenDeep,
		size = UDim2.fromOffset(extent, extent),
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex or 8,
		radius = props.radius or math.floor(extent / 3),
		children = {
			e(Icon, {
				key = "Glyph",
				glyph = "check",
				plain = true,
				size = UDim2.fromScale(0.62, 0.62),
				position = UDim2.fromScale(0.5, 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
				zIndex = 3,
			}),
		},
	})
end

--- Dim wash plus padlock. Sits over a card's whole face.
function Indicators.LockOverlay(props)
	return e(
		"Frame",
		{
			key = props.key or "LockOverlay",
			BackgroundColor3 = Theme.Color.PanelDark,
			BackgroundTransparency = props.transparency or 0.4,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = props.zIndex or 9,
		},
		P.compact(
			P.corner(props.radius or Theme.Radius.Card),
			e(Icon, {
				key = "Lock",
				glyph = "lock",
				plain = true,
				size = UDim2.fromOffset(props.extent or 46, props.extent or 46),
				position = UDim2.fromScale(0.5, if props.text then 0.42 else 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
				zIndex = 2,
			}),
			if props.text
				then e(P.Label, {
					key = "Requirement",
					text = props.text,
					textSize = Theme.TextSize.Small,
					font = Theme.Font.Bold,
					color = Theme.Color.White,
					wrapped = true,
					size = UDim2.new(1, -16, 0, 40),
					position = UDim2.fromScale(0.5, 0.78),
					anchorPoint = Vector2.new(0.5, 0.5),
					zIndex = 2,
				})
				else nil
		)
	)
end

--------------------------------------------------------------------------------
-- CurrencyDisplay
--------------------------------------------------------------------------------

--[[
	props:
		glyph      icon name ("coin", "gear", "star")
		value      number
		formatted  string?   overrides the formatted value
		gradient   ColorSequence?  icon plaque colour
		onAdd      function?  shows the small + button when provided
]]
function Indicators.CurrencyDisplay(props)
	local height = props.height or 46
	local iconExtent = height - 8

	return e(P.Panel, {
		key = props.key or "Currency",
		size = props.size or UDim2.fromOffset(props.width or 210, height),
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex,
		radius = Theme.Radius.Chip,
		color = Theme.Color.PanelDark,
		gradient = Theme.Gradient.PanelDeep,
		strokeThickness = Theme.Stroke.Card,
		studs = false,
		children = P.compact(
			e(Icon, {
				key = "Icon",
				glyph = props.glyph,
				gradient = props.gradient,
				size = UDim2.fromOffset(iconExtent, iconExtent),
				position = UDim2.new(0, 4, 0.5, 0),
				anchorPoint = Vector2.new(0, 0.5),
				radius = Theme.Radius.Small,
				zIndex = 3,
			}),
			e(P.Label, {
				key = "Value",
				text = props.formatted or Format.money(props.value or 0),
				textSize = props.textSize or Theme.TextSize.Value,
				align = Enum.TextXAlignment.Left,
				size = UDim2.new(
					1,
					-(iconExtent + 16 + (if props.onAdd then height - 10 else 0)),
					1,
					0
				),
				position = UDim2.fromOffset(iconExtent + 12, 0),
				truncate = Enum.TextTruncate.AtEnd,
				zIndex = 3,
			}),
			if props.onAdd
				then e(Buttons.IconButton, {
					key = "Add",
					glyph = "plus",
					variant = "Primary",
					extent = height - 14,
					glyphScale = 0.5,
					position = UDim2.new(1, -5, 0.5, 0),
					anchorPoint = Vector2.new(1, 0.5),
					zIndex = 4,
					onClick = props.onAdd,
				})
				else nil
		),
	})
end

--------------------------------------------------------------------------------
-- StatPill
--------------------------------------------------------------------------------

--[[
	The bottom-left readout, and deliberately the simplest component in the kit:
	a slab, an icon on the left, a value. The authored HUD's gears and rebirth
	rows were exactly this and nothing more, so this is what replaces them.

	Art comes from `Assets.Plates`; when that id is blank the drawn panel is used
	instead, so the pill still renders with nothing uploaded.

	props:
		glyph / image  icon, resolved through Assets like every other icon
		value          already-formatted string
		plate          Assets.Plates key, default "statPill"
		gradient       gradient applied to the *text* (money uses Gradient.Money)
		font, textSize, width, height, layoutOrder, zIndex
]]
function Indicators.StatPill(props)
	local height = props.height or 46
	local width = props.width or 216
	local iconExtent = math.floor(height * 0.8)
	local plate = Assets.plate(props.plate or "statPill")
	local textSize = props.textSize or Theme.TextSize.Value

	--[[
		The icon is optional. Rendering one with no glyph and no art falls through
		to `Icon`'s letter placeholder, which put a stray "?" in front of the cash
		readout -- so when there is nothing to draw, the value takes the whole pill.
	]]
	local hasIcon = props.glyph ~= nil or props.image ~= nil
	local textInset = if hasIcon then iconExtent + 12 else 12

	local content = P.compact(
		if hasIcon
			then e(Icon, {
				key = "Icon",
				glyph = props.glyph,
				image = props.image,
				-- The slab already supplies the tile; a second one would double up.
				plain = plate ~= nil,
				gradient = props.iconGradient,
				size = UDim2.fromOffset(iconExtent, iconExtent),
				position = UDim2.new(0, 5, 0.5, 0),
				anchorPoint = Vector2.new(0, 0.5),
				radius = Theme.Radius.Small,
				zIndex = 3,
			})
			else nil,
		e(P.Label, {
			key = "Value",
			text = props.value or "",
			font = props.font,
			textSize = textSize,
			gradient = props.gradient,
			align = Enum.TextXAlignment.Left,
			size = UDim2.new(1, -(textInset + 6), 1, 0),
			position = UDim2.fromOffset(textInset, 0),
			truncate = Enum.TextTruncate.AtEnd,
			zIndex = 3,
		})
	)

	local size = props.size or UDim2.fromOffset(width, height)

	if plate then
		return e("ImageLabel", {
			key = props.key or "StatPill",
			BackgroundTransparency = 1,
			Image = plate,
			Size = size,
			Position = props.position,
			AnchorPoint = props.anchorPoint,
			LayoutOrder = props.layoutOrder,
			ZIndex = props.zIndex,
		}, content)
	end

	return e(P.Panel, {
		key = props.key or "StatPill",
		size = size,
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex,
		radius = Theme.Radius.Chip,
		color = Theme.Color.PanelDark,
		gradient = Theme.Gradient.PanelDeep,
		strokeThickness = Theme.Stroke.Card,
		studs = false,
		children = content,
	})
end

--------------------------------------------------------------------------------
-- StatRow — used by every details panel
--------------------------------------------------------------------------------

function Indicators.StatRow(props)
	local compact = props.compact == true
	local iconSize = if compact then 18 else 26
	local textSize = if compact
		then Theme.TextSize.Tiny
		else (props.textSize or Theme.TextSize.Body)
	return e(P.Panel, {
		key = props.key or "Stat",
		size = props.size or UDim2.new(1, 0, 0, if compact then 38 else 44),
		layoutOrder = props.layoutOrder,
		radius = Theme.Radius.Small,
		color = Theme.Color.PanelDark,
		gradient = Theme.Gradient.PanelDeep,
		strokeThickness = Theme.Stroke.Chip,
		studs = false,
		children = P.compact(
			P.padding({ x = if compact then 6 else 10 }, "Inset"),
			if props.glyph
				then e(Icon, {
					key = "Icon",
					glyph = props.glyph,
					plain = true,
					size = UDim2.fromOffset(iconSize, iconSize),
					position = UDim2.new(0, 2, 0.5, 0),
					anchorPoint = Vector2.new(0, 0.5),
					zIndex = 3,
				})
				else nil,
			e(P.Label, {
				key = "Name",
				text = props.label,
				textSize = textSize,
				font = Theme.Font.Bold,
				color = Theme.Color.Gray,
				align = Enum.TextXAlignment.Left,
				truncate = Enum.TextTruncate.AtEnd,
				size = UDim2.new(0.55, if props.glyph then -(iconSize + 6) else 0, 1, 0),
				position = UDim2.fromOffset(if props.glyph then iconSize + 8 else 0, 0),
				zIndex = 3,
			}),
			e(P.Label, {
				key = "Value",
				text = props.value,
				textSize = textSize,
				color = props.valueColor or Theme.Color.White,
				align = Enum.TextXAlignment.Right,
				size = UDim2.fromScale(0.45, 1),
				position = UDim2.fromScale(0.55, 0),
				zIndex = 3,
			})
		),
	})
end

--------------------------------------------------------------------------------
-- PriceTag
--------------------------------------------------------------------------------

--[[
	props:
		cash    number?   renders "$1,234" with the coin glyph
		robux   number?   renders the Robux glyph plus the amount
		gears   number?
		align   Enum.TextXAlignment?
]]
function Indicators.PriceTag(props)
	local textSize = props.textSize or Theme.TextSize.Value

	local glyph, text, color
	if props.robux then
		glyph, text, color = "robux", Format.robux(props.robux), Theme.Color.White
	elseif props.gears then
		glyph, text, color = "gear", Format.comma(props.gears), Theme.Color.Gold
	else
		glyph, text, color =
			"coin", "$" .. Format.short(props.cash or 0), props.color or Theme.Color.Positive
	end

	return e(P.Group, {
		key = props.key or "Price",
		size = props.size or UDim2.fromOffset(0, textSize + 6),
		automaticSize = if props.size then nil else Enum.AutomaticSize.X,
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex,
		layout = P.list({
			direction = Enum.FillDirection.Horizontal,
			padding = 6,
			hAlign = props.hAlign or Enum.HorizontalAlignment.Center,
			vAlign = Enum.VerticalAlignment.Center,
		}),
		children = {
			e(Icon, {
				key = "Icon",
				glyph = glyph,
				plain = true,
				size = UDim2.fromOffset(textSize, textSize),
				layoutOrder = 1,
			}),
			e(P.Label, {
				key = "Amount",
				text = text,
				textSize = textSize,
				color = color,
				size = UDim2.fromOffset(0, textSize + 6),
				automaticSize = Enum.AutomaticSize.X,
				layoutOrder = 2,
			}),
		},
	})
end

--------------------------------------------------------------------------------
-- Section header — small caps label with a rule, used inside settings and
-- details panels.
--------------------------------------------------------------------------------

function Indicators.SectionHeader(props)
	return e(P.Group, {
		key = props.key or "Section",
		size = props.size or UDim2.new(1, 0, 0, 30),
		layoutOrder = props.layoutOrder,
		children = {
			e(P.Label, {
				key = "Title",
				text = string.upper(props.text),
				textSize = props.textSize or Theme.TextSize.Body,
				color = props.color or Theme.Color.Gold,
				align = Enum.TextXAlignment.Left,
				size = UDim2.fromScale(1, 1),
			}),
			e(P.Divider, {
				key = "Rule",
				size = UDim2.new(1, 0, 0, 3),
				position = UDim2.new(0, 0, 1, -1),
				anchorPoint = Vector2.new(0, 1),
			}),
		},
	})
end

return Indicators
