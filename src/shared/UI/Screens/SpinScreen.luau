--[[
	SpinScreen.luau

	THE DAILY SPIN WHEEL.

	The wheel is DECORATION OVER A DECIDED RESULT. The server picked the segment, granted the
	reward, and sent back an index; this screen turns the wheel so it stops on that index. It never
	picks anything. That ordering is the entire security model of a prize wheel -- a client that
	spins and then reports where it landed lands on the jackpot every time.

	So the three states this renders are:

		idle       spins available, button live
		spinning   turning toward the index the server sent
		revealed   stopped, prize called out, button becomes CLOSE

	SEGMENTS ARE DRAWN AS A COLUMN, NOT A PIE. Roblox has no radial fill, and faking wedges means
	rotated GuiObjects -- which ignore an ancestor's `ClipsDescendants` and paint over the whole
	screen (AGENTS.md rule 11). A vertical reel that slides to its stop reads just as well, clips
	properly, and animates with one position tween instead of trigonometry.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Motion = require(UI.Motion)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)
local Buttons = require(UI.Components.Buttons)
local Indicators = require(UI.Components.Indicators)
local Overlays = require(UI.Components.Overlays)

local e = React.createElement

local ROW_HEIGHT = 64
local VISIBLE_ROWS = 5
local REEL_HEIGHT = ROW_HEIGHT * VISIBLE_ROWS

--- One prize on the reel.
local function SegmentRow(props)
	local accent = Theme.Gradient[props.accent or "Green"] or Theme.Gradient.Green
	return e(P.Panel, {
		key = props.key,
		size = UDim2.new(1, 0, 0, ROW_HEIGHT - 6),
		gradient = if props.highlighted then accent else Theme.Gradient.PanelDeep,
		radius = Theme.Radius.Card,
		stroke = Theme.Stroke.Card,
		studs = false,
		layoutOrder = props.layoutOrder,
		children = {
			e(Icon, {
				key = "Glyph",
				glyph = props.glyph or "star",
				gradient = accent,
				size = UDim2.fromOffset(38, 38),
				position = UDim2.new(0, 14, 0.5, 0),
				anchorPoint = Vector2.new(0, 0.5),
				radius = Theme.Radius.Small,
			}),
			e(P.Label, {
				key = "Label",
				text = props.label,
				textSize = Theme.TextSize.Heading,
				color = Theme.Color.White,
				align = Enum.TextXAlignment.Left,
				position = UDim2.new(0, 64, 0.5, 0),
				anchorPoint = Vector2.new(0, 0.5),
				size = UDim2.new(1, -78, 0, 30),
			}),
		},
	})
end

local function SpinScreen(props)
	local state = props.state
	local actions = props.actions

	local segments = state.spinSegments or {}
	local spins = state.spinsAvailable or 0
	local roll = state.spinRoll
	local phase = if roll then roll.Phase else nil
	local spinning = phase == "spinning"
	local revealed = phase == "revealed"

	--[[
		Where the reel sits. Landing the winning row in the middle of the window means offsetting by
		its index minus the half-window, so the maths is the same whichever row wins and there is no
		special case for the ends.
	]]
	local targetIndex = if roll then roll.Index else 1
	local centreOffset = -((targetIndex - 1) - math.floor(VISIBLE_ROWS / 2)) * ROW_HEIGHT

	--[[
		Springs to the stop rather than easing. A spring overshoots slightly and settles, which is
		what makes a wheel feel like it has weight -- an ease-out arrives politely and reads as a
		list scrolling, not a prize being won.
	]]
	local reelPosition = Motion.useSpring(
		if roll then centreOffset else 0,
		if spinning then Motion.Spring.Slow else Motion.Spring.Bouncy
	)

	local rows = {}
	for index, segment in ipairs(segments) do
		rows[#rows + 1] = e(SegmentRow, {
			key = segment.Id,
			label = segment.Label,
			glyph = segment.Glyph,
			accent = segment.Accent,
			layoutOrder = index,
			--- Only lit once it has stopped, so nothing is spoiled mid-spin.
			highlighted = revealed and index == targetIndex,
		})
	end

	local buttonText
	if revealed then
		buttonText = "COLLECT"
	elseif spinning then
		buttonText = "SPINNING..."
	elseif spins > 0 then
		buttonText = `SPIN  ({spins})`
	else
		buttonText = "NO SPINS LEFT"
	end

	return e(Overlays.Modal, {
		key = props.key or "SpinScreen",
		title = "Daily Spin",
		glyph = "star",
		headerColor = Theme.Gradient.Purple,
		width = 620,
		contentHeight = REEL_HEIGHT + 24,
		onClose = actions.closeScreen,
		footerHeight = 76,
		footer = e(P.Group, {
			key = "Footer",
			size = UDim2.fromScale(1, 1),
			children = {
				e(Indicators.Badge, {
					key = "Spins",
					text = `SPINS: {spins}`,
					gradient = if spins > 0 then Theme.Gradient.Cyan else Theme.Gradient.PanelDeep,
					textSize = Theme.TextSize.Small,
					position = UDim2.fromScale(0, 0.5),
					anchorPoint = Vector2.new(0, 0.5),
				}),
				e(Buttons.Button, {
					key = "SpinButton",
					text = buttonText,
					variant = if revealed
						then "Primary"
						elseif spinning or spins <= 0 then "Neutral"
						else "Premium",
					disabled = spinning or (spins <= 0 and not revealed),
					textSize = Theme.TextSize.Heading,
					size = UDim2.fromOffset(300, 58),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					onClick = if revealed then actions.closeSpin else actions.spinWheel,
				}),
				e(P.Label, {
					key = "Result",
					text = if revealed then `YOU WON {roll.Label}!` else "",
					textSize = Theme.TextSize.Body,
					color = Theme.Color.Gold,
					align = Enum.TextXAlignment.Right,
					position = UDim2.fromScale(1, 0.5),
					anchorPoint = Vector2.new(1, 0.5),
					size = UDim2.fromOffset(200, 26),
				}),
			},
		}),
		children = {
			--[[
				The reel window clips, and the pointer sits on top of it. `ClipsDescendants` is doing
				real work here: without it the whole segment list paints down the screen.
			]]
			e(P.Panel, {
				key = "Window",
				size = UDim2.new(1, -40, 0, REEL_HEIGHT),
				position = UDim2.fromScale(0.5, 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
				gradient = Theme.Gradient.Slot,
				radius = Theme.Radius.Panel,
				stroke = Theme.Stroke.Panel,
				studs = false,
				clip = true,
				children = {
					e(P.Group, {
						key = "Reel",
						size = UDim2.new(1, -16, 0, ROW_HEIGHT * math.max(#segments, 1)),
						position = UDim2.new(0.5, 0, 0, reelPosition),
						anchorPoint = Vector2.new(0.5, 0),
						layout = P.list({ padding = 6 }),
						children = rows,
					}),
					--[[
						The stop line: two gold bars framing the centre row, rather than a panel drawn
						over it. A filled panel would cover the winning prize; bars leave it readable
						and still say unmistakably "this row is the one".
					]]
					e(P.Panel, {
						key = "PointerTop",
						size = UDim2.new(1, 8, 0, 4),
						position = UDim2.new(0.5, 0, 0.5, -ROW_HEIGHT / 2),
						anchorPoint = Vector2.new(0.5, 0.5),
						gradient = Theme.Gradient.Gold,
						radius = Theme.Radius.Small,
						stroke = 0,
						studs = false,
					}),
					e(P.Panel, {
						key = "PointerBottom",
						size = UDim2.new(1, 8, 0, 4),
						position = UDim2.new(0.5, 0, 0.5, ROW_HEIGHT / 2),
						anchorPoint = Vector2.new(0.5, 0.5),
						gradient = Theme.Gradient.Gold,
						radius = Theme.Radius.Small,
						stroke = 0,
						studs = false,
					}),
				},
			}),
		},
	})
end

return SpinScreen
