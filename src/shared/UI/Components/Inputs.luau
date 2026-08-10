--[[
	Inputs.luau
	Slider and Toggle -- the only two interactive controls outside buttons.

	Both are built from plain Frames with a solid darker slab behind them, so they
	match the chunky button language and convert cleanly to Roblox GUI.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Motion = require(UI.Motion)
local Sound = require(UI.Sound)
local P = require(UI.Primitives)

local e = React.createElement

local Inputs = {}

--------------------------------------------------------------------------------
-- Slider
--------------------------------------------------------------------------------

--[[
	props:
		value      0..1 (or min..max when both are given)
		min, max   numbers? default 0..1
		step       number?
		onChange   function(value)
		gradient   ColorSequence?
		height     number?
		showValue  boolean?  default true, prints a percentage

	Geometry: the track spans the full width, and the knob's CENTRE travels from
	`knobExtent / 2` to `width - knobExtent / 2`. The fill's right edge is pinned
	to that centre, so the bar reaches the very ends of the track and there is no
	dead gap on either side.

	Input: the track handles InputBegan/InputChanged itself -- which is what makes
	it draggable in Studio's edit mode, where UserInputService is not delivered --
	and UserInputService continues the drag once the pointer leaves the track.
]]
function Inputs.Slider(props)
	local min = props.min or 0
	local max = props.max or 1
	local height = props.height or 34
	local knobExtent = props.knobExtent or height + 6

	local trackRef = React.useRef(nil :: any)
	local dragging, setDragging = React.useState(false)

	local value = math.clamp(props.value or min, min, max)
	local ratio = (value - min) / math.max(max - min, 1e-6)
	local eased = Motion.useSpring(ratio, Motion.Spring.Snappy)

	--- Maps a screen-space X onto a value.
	local function commit(x: number)
		local track = trackRef.current
		if not track then
			return
		end

		-- The layout is authored in design pixels but AbsoluteSize is post-UIScale.
		-- The track's local height is known, so it gives us the scale factor.
		local scale = track.AbsoluteSize.Y / math.max(height, 1)
		local knob = knobExtent * scale
		local span = math.max(track.AbsoluteSize.X - knob, 1)
		local left = track.AbsolutePosition.X + knob / 2

		local newRatio = math.clamp((x - left) / span, 0, 1)
		local newValue = min + newRatio * (max - min)
		if props.step and props.step > 0 then
			newValue = math.clamp(math.floor(newValue / props.step + 0.5) * props.step, min, max)
		end

		if props.onChange then
			props.onChange(newValue)
		end
	end

	-- Continue tracking after the pointer leaves the track, and catch the release
	-- wherever it happens.
	React.useEffect(function()
		if not dragging then
			return
		end

		local moved = UserInputService.InputChanged:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				commit(input.Position.X)
			end
		end)

		local ended = UserInputService.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				setDragging(false)
			end
		end)

		return function()
			moved:Disconnect()
			ended:Disconnect()
		end
	end, { dragging })

	local radius = math.floor(height / 2.6)

	--- Knob centre, in the track's own coordinate space.
	local function centre(current: number): UDim
		local clamped = math.clamp(current, 0, 1)
		return UDim.new(clamped, (0.5 - clamped) * knobExtent)
	end

	return e(P.Group, {
		key = props.key or "Slider",
		size = props.size or UDim2.new(1, 0, 0, knobExtent),
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex,
		children = {
			e(
				"TextButton",
				{
					key = "Track",
					ref = trackRef,
					Text = "",
					AutoButtonColor = false,
					BackgroundColor3 = Theme.Color.PanelDark,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, height),
					Position = UDim2.fromScale(0, 0.5),
					AnchorPoint = Vector2.new(0, 0.5),

					[React.Event.InputBegan] = function(_, input)
						if
							input.UserInputType == Enum.UserInputType.MouseButton1
							or input.UserInputType == Enum.UserInputType.Touch
						then
							setDragging(true)
							Sound.play("tap")
							commit(input.Position.X)
						end
					end,
					[React.Event.InputChanged] = function(_, input)
						if
							dragging
							and (
								input.UserInputType == Enum.UserInputType.MouseMovement
								or input.UserInputType == Enum.UserInputType.Touch
							)
						then
							commit(input.Position.X)
						end
					end,
					[React.Event.InputEnded] = function(_, input)
						if
							input.UserInputType == Enum.UserInputType.MouseButton1
							or input.UserInputType == Enum.UserInputType.Touch
						then
							setDragging(false)
						end
					end,
				},
				P.compact(
					P.corner(radius),
					P.stroke(Theme.Color.Outline, Theme.Stroke.Card),
					e("Frame", {
						key = "Fill",
						BackgroundColor3 = Theme.Color.White,
						BorderSizePixel = 0,
						-- Right edge sits under the knob's centre at every value.
						Size = eased:map(function(current)
							local edge = centre(current)
							return UDim2.new(edge.Scale, edge.Offset, 1, 0)
						end),
						ZIndex = 2,
					}, {
						P.corner(radius),
						P.gradient(props.gradient or Theme.Gradient.Cyan),
						e(
							P.Highlight,
							{ key = "Highlight", radius = radius, strength = 0.7, height = 0.42 }
						),
					}),
					if props.showValue ~= false
						then e(P.Label, {
							key = "Value",
							text = props.valueText or (math.floor(ratio * 100 + 0.5) .. "%"),
							textSize = props.textSize or math.floor(height * 0.48),
							zIndex = 4,
						})
						else nil
				)
			),
			e("Frame", {
				key = "Knob",
				BackgroundColor3 = Theme.Color.White,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(knobExtent, knobExtent),
				Position = eased:map(function(current)
					local edge = centre(current)
					return UDim2.new(edge.Scale, edge.Offset, 0.5, 0)
				end),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 5,
			}, {
				P.corner(math.floor(knobExtent / 3)),
				P.stroke(Theme.Color.Outline, Theme.Stroke.Button),
				P.gradient(ColorSequence.new(Theme.Color.White, Color3.fromHex("C9D4E2"))),
				e("Frame", {
					key = "Grip",
					BackgroundColor3 = Theme.Color.PanelLight,
					BackgroundTransparency = 0.4,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(4, math.floor(knobExtent * 0.44)),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					ZIndex = 2,
				}, { P.corner(2) }),
			}),
		},
	})
end

--------------------------------------------------------------------------------
-- Toggle — ON / OFF switch with the state spelled out, because a bare switch is
-- ambiguous on mobile.
--------------------------------------------------------------------------------

function Inputs.Toggle(props)
	local on = props.value == true
	local slide = Motion.useSpring(if on then 1 else 0, Motion.Spring.Snappy)

	local width = props.width or 108
	local height = props.height or 40
	local radius = math.floor(height / 2.6)
	local knobWidth = math.floor(width * 0.44)
	local travel = width - knobWidth - 8

	return e("TextButton", {
		key = props.key or "Toggle",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if on then Theme.Color.GreenDeep else Color3.fromHex("46536B"),
		BorderSizePixel = 0,
		Size = props.size or UDim2.fromOffset(width, height),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,

		[React.Event.Activated] = function()
			Sound.play("toggle")
			if props.onChange then
				props.onChange(not on)
			end
		end,
	}, {
		P.corner(radius),
		P.stroke(Theme.Color.Outline, Theme.Stroke.Button),
		P.gradient(if on then Theme.Gradient.Green else Theme.Gradient.Gray),
		-- Label sits opposite the knob: ON reads on the left, OFF on the right.
		e(P.Label, {
			key = "State",
			text = if on then "ON" else "OFF",
			textSize = props.textSize or Theme.TextSize.Small,
			color = Theme.Color.White,
			size = UDim2.new(0, width - knobWidth - 8, 1, 0),
			position = slide:map(function(current)
				return UDim2.fromOffset(4 + (1 - current) * (knobWidth + 4), 0)
			end),
			zIndex = 3,
		}),
		e("Frame", {
			key = "Knob",
			BackgroundColor3 = Theme.Color.White,
			BorderSizePixel = 0,
			Size = UDim2.new(0, knobWidth, 1, -8),
			-- Slides between the ends. AnchorPoint stays put: switching anchors
			-- mid-animation is what dropped the knob below the track.
			Position = slide:map(function(current)
				return UDim2.new(0, 4 + current * travel, 0.5, 0)
			end),
			AnchorPoint = Vector2.new(0, 0.5),
			ZIndex = 4,
		}, {
			P.corner(radius - 2),
			P.stroke(Theme.Color.Outline, Theme.Stroke.Chip),
			P.gradient(ColorSequence.new(Theme.Color.White, Color3.fromHex("C9D4E2"))),
		}),
	})
end

--------------------------------------------------------------------------------
-- SettingRow — label on the left, control on the right. Shared by the audio,
-- gameplay and UI sections of the settings window.
--------------------------------------------------------------------------------

function Inputs.SettingRow(props)
	return e(P.Panel, {
		key = props.key or "SettingRow",
		size = props.size or UDim2.new(1, 0, 0, 56),
		layoutOrder = props.layoutOrder,
		radius = Theme.Radius.Small,
		color = Theme.Color.PanelDark,
		gradient = Theme.Gradient.PanelDeep,
		strokeThickness = Theme.Stroke.Chip,
		studs = false,
		children = {
			P.padding({ x = 12 }, "Inset"),
			e(P.Label, {
				key = "Name",
				text = props.label,
				textSize = props.textSize or Theme.TextSize.Body,
				align = Enum.TextXAlignment.Left,
				size = UDim2.fromScale(0.42, 1),
				zIndex = 3,
			}),
			e(P.Group, {
				key = "Control",
				size = UDim2.fromScale(0.58, 1),
				position = UDim2.fromScale(0.42, 0),
				zIndex = 3,
				layout = P.list({
					direction = Enum.FillDirection.Horizontal,
					hAlign = Enum.HorizontalAlignment.Right,
					vAlign = Enum.VerticalAlignment.Center,
				}),
				children = props.children,
			}),
		},
	})
end

return Inputs
