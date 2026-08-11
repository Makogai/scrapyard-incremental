--[[
	SpinScreen.luau

	THE DAILY SPIN WHEEL, as a full-screen takeover rather than a window.

	Not a modal. A modal is a thing you read; this is a thing you watch. So the world blurs, the wheel
	takes the middle of the screen, and there is no header, no panel and no chrome competing with it --
	the same reasoning `EggRollOverlay` uses for the hatch.

	THE WHEEL IS DECORATION OVER A DECIDED RESULT. The server picked the segment, granted the reward,
	and sent back an index; this turns the wheel so that segment stops under the pointer. It never picks
	anything. That ordering is the entire security model of a prize wheel -- a client that spins and then
	reports where it landed lands on the jackpot every time.

	THREE STATES, and the transitions are what sell it:

		idle       drifting slowly on its own, so it reads as alive before you touch it
		spinning   six full turns into its landing angle, over three seconds
		revealed   stopped, with a `RewardToast` banner naming the prize

	There is no COLLECT button. The reward was granted the moment the server resolved the spin, so a
	button claiming to collect it would be a lie -- the banner announces, and the wheel is immediately
	ready to go again.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Hooks = require(UI.Hooks)
local Motion = require(UI.Motion)
local P = require(UI.Primitives)
local Buttons = require(UI.Components.Buttons)
local Indicators = require(UI.Components.Indicators)
local Overlays = require(UI.Components.Overlays)
local Wheel = require(UI.Components.Wheel)
local RewardToast = require(UI.Components.RewardToast)

local e = React.createElement

--[[
	Whole turns before it settles, and how long that takes.

	Six turns over three seconds: the old version did one short spring and was over before the eye
	caught it. A whole number of turns on purpose -- the landing angle is then exactly the segment's own
	centre, where a fractional turn leaves the pointer sitting off the wedge it claims to have picked.
]]
local FULL_TURNS = 6
local SPIN_SPRING = { tension = 24, friction = 26 }

--- How fast it drifts while nobody has pressed anything.
local IDLE_DEGREES_PER_SECOND = 7

local function SpinScreen(props)
	local state = props.state
	local actions = props.actions

	local segments = state.spinSegments or {}
	local spins = state.spinsAvailable or 0
	local roll = state.spinRoll
	local phase = if roll then roll.Phase else nil
	local spinning = phase == "spinning"
	local revealed = phase == "revealed"
	local active = spinning or revealed

	--[[
		The wheel is sized to the screen, not to a constant. A 520px wheel is right on desktop and taller
		than the whole canvas on a 750x361 landscape phone, so it takes whatever the shorter axis can
		spare after the button row and the banner.
	]]
	local viewport = Hooks.useViewport()
	local scale = Hooks.useScale()
	local available = math.min(viewport.X, viewport.Y) / math.max(scale, 0.01)
	local extent = math.clamp(math.floor(available - 190), 240, 560)

	local count = math.max(#segments, 1)
	local step = 360 / count

	--[[
		Where it has to stop.

		`Components/Wheel` lays segment i centred at `(i - 0.5) * step` clockwise from up, so bringing it
		under the pointer means turning back by exactly that, plus whole turns. Negative because a
		positive `Rotation` turns clockwise and the segment has to come round to the top.

		This is the one piece of maths the screen and the wheel component must agree on.
	]]
	local targetIndex = if roll then roll.Index else 1
	local landing = -((targetIndex - 0.5) * step) - FULL_TURNS * 360

	--[[
		Two rotation sources, and only one is live at a time: a slow idle drift, and the spring that
		throws it to its landing angle. Swapping between them rather than adding them means the landing
		angle is exact -- an idle offset still ticking underneath would leave the pointer a degree or two
		off whichever wedge won.
	]]
	local idle = Motion.useSpin(IDLE_DEGREES_PER_SECOND, not active)
	local landed = Motion.useSpring(if active then landing else 0, SPIN_SPRING)
	local rotation = if active then landed else idle

	local buttonText
	if spinning then
		buttonText = "SPINNING..."
	elseif spins > 0 then
		buttonText = `SPIN  ({spins})`
	else
		buttonText = "NO SPINS LEFT"
	end

	--- The prize banner, built from the segment the server actually landed on.
	local won = nil
	if revealed then
		for _, segment in ipairs(segments) do
			if segment.Id == roll.SegmentId then
				won = segment
				break
			end
		end
	end

	return e(P.Group, {
		key = props.key or "SpinScreen",
		size = UDim2.fromScale(1, 1),
		zIndex = Theme.Layer.Screen,
		children = P.compact(
			--[[
				Blurred, and clicking it closes -- but only while nothing is turning. Letting a stray click
				dismiss a spin in progress would throw away the animation for a reward already granted.
			]]
			e(Overlays.Backdrop, {
				key = "Backdrop",
				transparency = 0.35,
				blur = true,
				blurSize = 20,
				modal = true,
				zIndex = 1,
				onClick = if spinning then nil else actions.closeScreen,
			}),
			e(Buttons.CloseButton, {
				key = "Close",
				position = UDim2.new(1, -28, 0, 28),
				anchorPoint = Vector2.new(1, 0),
				zIndex = 8,
				onClick = actions.closeScreen,
			}),
			e(Wheel.Wheel, {
				key = "Wheel",
				segments = segments,
				rotation = rotation,
				extent = extent,
				position = UDim2.new(0.5, 0, 0.5, -30),
				anchorPoint = Vector2.new(0.5, 0.5),
				zIndex = 3,
			}),
			--[[
				The banner sits over the wheel's lower half rather than under the button row, so the prize
				lands where the eye already is once the wheel stops.
			]]
			if won
				then e(RewardToast.Banner, {
					key = "Won",
					title = won.Label,
					detail = "ADDED TO YOUR ACCOUNT",
					glyph = RewardToast.glyphFor(won),
					accent = won.Accent,
					best = won.Best == true,
					width = math.min(460, extent + 60),
					position = UDim2.new(0.5, 0, 0.5, extent / 2 - 40),
					anchorPoint = Vector2.new(0.5, 0.5),
					zIndex = 9,
				})
				else nil,
			e(P.Group, {
				key = "Controls",
				size = UDim2.fromOffset(340, 96),
				position = UDim2.new(0.5, 0, 1, -28),
				anchorPoint = Vector2.new(0.5, 1),
				zIndex = 6,
				layout = P.list({ padding = 10, hAlign = Enum.HorizontalAlignment.Center }),
				children = {
					e(Buttons.Button, {
						key = "SpinButton",
						text = buttonText,
						variant = if spinning or spins <= 0 then "Neutral" else "Premium",
						disabled = spinning or spins <= 0,
						textSize = Theme.TextSize.Heading,
						size = UDim2.fromOffset(300, 62),
						layoutOrder = 1,
						onClick = actions.spinWheel,
					}),
					e(Indicators.Badge, {
						key = "Spins",
						text = `SPINS: {spins}`,
						gradient = if spins > 0
							then Theme.Gradient.Cyan
							else Theme.Gradient.PanelDeep,
						textSize = Theme.TextSize.Small,
						layoutOrder = 2,
					}),
				},
			})
		),
	})
end

return SpinScreen
