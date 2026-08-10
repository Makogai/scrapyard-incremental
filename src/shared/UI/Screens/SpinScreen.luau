--[[
	SpinScreen.luau

	THE DAILY SPIN WHEEL.

	The wheel is DECORATION OVER A DECIDED RESULT. The server picked the segment, granted the reward,
	and sent back an index; this screen turns the wheel so that segment stops under the pointer. It
	never picks anything. That ordering is the entire security model of a prize wheel -- a client that
	spins and then reports where it landed lands on the jackpot every time.

	Three states: idle (spins banked, button live), spinning (turning), revealed (stopped, prize
	called out, button becomes COLLECT).

	The wedge drawing lives in `Components/Wheel` -- see that file for why a pie wedge in Roblox has to
	be a fan of rotated bars rather than a clipped rotation.

	THE BEST PRIZE IS DATA-DRIVEN. Whichever segment carries `Best = true` in `RewardsConfig` gets the
	gold wedge and a `Shine` layer. Move the flag and the presentation follows; nothing here knows the
	God Potion by name.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Motion = require(UI.Motion)
local P = require(UI.Primitives)
local Buttons = require(UI.Components.Buttons)
local Indicators = require(UI.Components.Indicators)
local Overlays = require(UI.Components.Overlays)
local Wheel = require(UI.Components.Wheel)

local e = React.createElement

local WHEEL_EXTENT = 392

--[[
	Whole turns before it settles.

	A whole number on purpose: the landing angle is then exactly the segment's own centre, where a
	fractional turn would leave the pointer sitting slightly off the wedge it claims to have picked.
]]
local FULL_TURNS = 4

local function SpinScreen(props)
	local state = props.state
	local actions = props.actions

	local segments = state.spinSegments or {}
	local spins = state.spinsAvailable or 0
	local roll = state.spinRoll
	local phase = if roll then roll.Phase else nil
	local spinning = phase == "spinning"
	local revealed = phase == "revealed"

	local count = math.max(#segments, 1)
	local step = 360 / count

	--[[
		Where the wheel has to stop.

		`Components/Wheel` lays segment i centred at `(i - 0.5) * step` clockwise from up, so bringing it
		under the pointer means turning back by exactly that, plus whole turns. Negative because a
		positive `Rotation` turns clockwise and the segment has to come round to the top.

		This is the one piece of maths the screen and the wheel component must agree on.
	]]
	local targetIndex = if roll then roll.Index else 1
	local landing = -((targetIndex - 0.5) * step) - FULL_TURNS * 360

	--[[
		A spring, not a tween: it overshoots slightly and settles, which is what gives the wheel weight.
		`Slow` for the long travel, `Bouncy` once revealed so any correction snaps. Idle returns to 0, so
		reopening the window does not start from a strange angle.
	]]
	local rotation = Motion.useSpring(
		if roll then landing else 0,
		if spinning then Motion.Spring.Slow else Motion.Spring.Bouncy
	)

	local bestLabel = nil
	for _, segment in ipairs(segments) do
		if segment.Best then
			bestLabel = segment.Label
			break
		end
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
		glyph = "wheel",
		headerColor = Theme.Gradient.Purple,
		width = WHEEL_EXTENT + 130,
		contentHeight = WHEEL_EXTENT + 40,
		onClose = actions.closeScreen,
		footerHeight = 78,
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
					size = UDim2.fromOffset(268, 60),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					onClick = if revealed then actions.closeSpin else actions.spinWheel,
				}),
				--[[
					Says what the top prize is while idle and what you actually won once it stops. The idle
					line is the whole reason to press the button, so it should never be a blank gap.
				]]
				e(P.Label, {
					key = "Result",
					text = if revealed
						then `YOU WON {roll.Label}!`
						elseif bestLabel then `TOP PRIZE: {bestLabel}`
						else "",
					textSize = Theme.TextSize.Small,
					color = if revealed then Theme.Color.Positive else Theme.Color.Gold,
					align = Enum.TextXAlignment.Right,
					position = UDim2.fromScale(1, 0.5),
					anchorPoint = Vector2.new(1, 0.5),
					size = UDim2.fromOffset(200, 26),
				}),
			},
		}),
		children = {
			e(Wheel.Wheel, {
				key = "Wheel",
				segments = segments,
				rotation = rotation,
				extent = WHEEL_EXTENT,
				position = UDim2.fromScale(0.5, 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
			}),
		},
	})
end

return SpinScreen
