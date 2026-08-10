--[[
	SpinScreen.luau

	THE DAILY SPIN WHEEL — an actual wheel.

	The wheel is DECORATION OVER A DECIDED RESULT. The server picked the segment, granted the reward,
	and sent back an index; this screen turns the wheel so it stops with that segment under the
	pointer. It never picks anything. That ordering is the entire security model of a prize wheel -- a
	client that spins and then reports where it landed lands on the jackpot every time.

	Three states: idle (spins banked, button live), spinning (turning), revealed (stopped, prize
	called out, button becomes COLLECT).

	HOW A WHEEL IS DRAWN WITHOUT RADIAL FILL. Roblox cannot draw a pie wedge -- there is no radial
	gradient and no arc primitive. So the wheel is a hub plus one SPOKE per prize, each spoke a
	rounded bar laid along its own radius and rotated to its angle. That reads unmistakably as a prize
	wheel, needs no art, and scales to however many segments the config has.

	ROTATION IS SAFE HERE, and it is worth saying why given AGENTS.md rule 11. The rule is that a
	rotated GuiObject ignores its ancestors' `ClipsDescendants`. Nothing in this wheel relies on being
	clipped: the wheel is sized to fit inside the modal body with margin, so there is nothing to clip
	against. What you must not do is put a rotated thing inside a scrolling or clipped container.

	THE BEST PRIZE IS DATA-DRIVEN. Whichever segment carries `Best = true` in `RewardsConfig` gets the
	wide gold spoke, the crown, and a `Shine` layer with glow and sparkles. Move the flag and the
	presentation follows; nothing here knows the God Potion by name.
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
local Shine = require(UI.Components.Shine)

local e = React.createElement

local WHEEL_EXTENT = 344
local HUB_EXTENT = 74
local SPOKE_WIDTH = 58
local BEST_SPOKE_WIDTH = 74

--[[
	How many full turns the wheel makes before settling.

	Enough that it reads as a spin rather than a nudge, and it is a whole number so the landing angle
	is exactly the segment's own angle -- a fractional turn would leave the pointer slightly off the
	spoke it claims to have picked.
]]
local FULL_TURNS = 4

--[[
	One prize, as a spoke.

	`angle` is degrees clockwise from straight up, which is where the pointer is. The spoke is
	positioned along that radius and rotated to match, so its long axis runs outward from the hub.

	The label rides the spoke and therefore rotates with it. That is what a real wheel does, and the
	labels are short enough to stay readable upside-down at the bottom of the turn.
]]
local function Spoke(props)
	local accent = Theme.Gradient[props.accent or "Green"] or Theme.Gradient.Green
	local width = if props.best then BEST_SPOKE_WIDTH else SPOKE_WIDTH
	local length = (WHEEL_EXTENT - HUB_EXTENT) / 2 - 8

	--- Centre of the spoke: half its length out from the hub edge, along its own radius.
	local radius = HUB_EXTENT / 2 + length / 2
	local radians = math.rad(props.angle)
	local offsetX = math.sin(radians) * radius
	local offsetY = -math.cos(radians) * radius

	return e(P.Panel, {
		key = props.key,
		size = UDim2.fromOffset(width, length),
		position = UDim2.new(0.5, offsetX, 0.5, offsetY),
		anchorPoint = Vector2.new(0.5, 0.5),
		rotation = props.angle,
		gradient = if props.best then Theme.Gradient.Gold else accent,
		radius = Theme.Radius.Card,
		strokeThickness = if props.best then 5 else Theme.Stroke.Card,
		studs = false,
		zIndex = if props.best then 3 else 2,
		children = P.compact(
			--[[
				The glow and sparkle layer, on the best prize only. Sparkles are rounded squares and the
				sweep's diagonal comes from a rotated gradient rather than a rotated frame -- see
				`Shine` itself, which is built that way precisely so it cannot escape its card.
			]]
			if props.best
				then e(Shine.Layer, {
					key = "Shine",
					glow = true,
					sparkles = true,
					sweep = true,
					color = Theme.Color.Gold,
					zIndex = 6,
				})
				else nil,
			e(Icon, {
				key = "Glyph",
				glyph = props.glyph or "star",
				plain = true,
				size = UDim2.fromOffset(width - 20, width - 20),
				position = UDim2.new(0.5, 0, 0, 10),
				anchorPoint = Vector2.new(0.5, 0),
				zIndex = 4,
			}),
			e(P.Label, {
				key = "Label",
				text = props.label,
				textSize = if props.best then Theme.TextSize.Small else Theme.TextSize.Tiny,
				color = Theme.Color.Ink,
				wrapped = true,
				position = UDim2.new(0.5, 0, 0, width - 4),
				anchorPoint = Vector2.new(0.5, 0),
				size = UDim2.new(1, -8, 0, 34),
				zIndex = 4,
			})
		),
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

	local count = math.max(#segments, 1)
	local step = 360 / count

	--[[
		Where the wheel has to stop.

		Segment i sits centred at `(i - 0.5) * step` clockwise from up, so bringing it under the
		pointer means rotating the wheel back by exactly that, plus whole turns for the drama. Negative
		because a positive `Rotation` in Roblox turns clockwise and we want the segment to come round to
		the top.
	]]
	local targetIndex = if roll then roll.Index else 1
	local landing = -((targetIndex - 0.5) * step) - FULL_TURNS * 360

	--[[
		A spring, not a tween. A spring overshoots slightly and settles, which is what gives the wheel
		weight; an ease-out arrives politely and reads as a list scrolling to a stop.

		`Slow` while spinning so the long travel takes time; `Bouncy` once revealed so any correction
		snaps. Idle sits at 0 rather than holding the last landing, so opening the window twice does not
		start from a strange angle.
	]]
	local rotation = Motion.useSpring(
		if roll then landing else 0,
		if spinning then Motion.Spring.Slow else Motion.Spring.Bouncy
	)

	--- The best prize, found by flag rather than by id.
	local bestIndex = nil
	for index, segment in ipairs(segments) do
		if segment.Best then
			bestIndex = index
			break
		end
	end

	local spokes = {}
	for index, segment in ipairs(segments) do
		spokes[#spokes + 1] = e(Spoke, {
			key = segment.Id,
			angle = (index - 0.5) * step,
			label = segment.Label,
			glyph = segment.Glyph,
			accent = segment.Accent,
			best = index == bestIndex,
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

	local bestLabel = if bestIndex then segments[bestIndex].Label else nil

	return e(Overlays.Modal, {
		key = props.key or "SpinScreen",
		title = "Daily Spin",
		glyph = "wheel",
		headerColor = Theme.Gradient.Purple,
		width = WHEEL_EXTENT + 120,
		contentHeight = WHEEL_EXTENT + 28,
		onClose = actions.closeScreen,
		footerHeight = 76,
		footer = e(P.Group, {
			key = "Footer",
			size = UDim2.fromScale(1, 1),
			children = P.compact(
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
					size = UDim2.fromOffset(260, 58),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					onClick = if revealed then actions.closeSpin else actions.spinWheel,
				}),
				--[[
					Says what the top prize is when idle, and what you actually won once it stops. The
					idle line is the whole reason to spin, so it should not be a blank gap.
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
					size = UDim2.fromOffset(190, 26),
				})
			),
		}),
		children = {
			e(P.Group, {
				key = "WheelArea",
				size = UDim2.fromOffset(WHEEL_EXTENT, WHEEL_EXTENT + 18),
				position = UDim2.fromScale(0.5, 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
				children = {
					--- The rim: a plain disc behind the spokes so the wheel has an edge.
					e(P.Panel, {
						key = "Rim",
						size = UDim2.fromOffset(WHEEL_EXTENT, WHEEL_EXTENT),
						position = UDim2.new(0.5, 0, 0, 18),
						anchorPoint = Vector2.new(0.5, 0),
						gradient = Theme.Gradient.PanelDeep,
						radius = WHEEL_EXTENT / 2,
						strokeThickness = Theme.Stroke.Panel,
						studs = false,
						zIndex = 1,
					}),
					--[[
						The turning part. Everything inside rotates with it, which is why the spokes can be
						laid out in fixed positions and still end up wherever the wheel points.
					]]
					e(P.Group, {
						key = "Wheel",
						size = UDim2.fromOffset(WHEEL_EXTENT, WHEEL_EXTENT),
						position = UDim2.new(0.5, 0, 0, 18),
						anchorPoint = Vector2.new(0.5, 0),
						rotation = rotation,
						zIndex = 2,
						children = spokes,
					}),
					--- Hub, on top of the spokes and NOT rotating, so its glyph stays upright.
					e(P.Panel, {
						key = "Hub",
						size = UDim2.fromOffset(HUB_EXTENT, HUB_EXTENT),
						position = UDim2.new(0.5, 0, 0, 18 + WHEEL_EXTENT / 2),
						anchorPoint = Vector2.new(0.5, 0.5),
						gradient = Theme.Gradient.Panel,
						radius = HUB_EXTENT / 2,
						strokeThickness = Theme.Stroke.Panel,
						studs = false,
						zIndex = 5,
						children = {
							e(Icon, {
								key = "HubGlyph",
								glyph = "wheel",
								plain = true,
								size = UDim2.fromOffset(HUB_EXTENT - 26, HUB_EXTENT - 26),
								position = UDim2.fromScale(0.5, 0.5),
								anchorPoint = Vector2.new(0.5, 0.5),
							}),
						},
					}),
					--[[
						The pointer, at the top, outside the rotating group so it stays put. Two stacked
						bars form a downward wedge without needing a rotated triangle.
					]]
					e(P.Panel, {
						key = "PointerWide",
						size = UDim2.fromOffset(34, 12),
						position = UDim2.new(0.5, 0, 0, 4),
						anchorPoint = Vector2.new(0.5, 0),
						gradient = Theme.Gradient.Gold,
						radius = Theme.Radius.Small,
						strokeThickness = Theme.Stroke.Chip,
						studs = false,
						zIndex = 8,
					}),
					e(P.Panel, {
						key = "PointerTip",
						size = UDim2.fromOffset(16, 14),
						position = UDim2.new(0.5, 0, 0, 14),
						anchorPoint = Vector2.new(0.5, 0),
						gradient = Theme.Gradient.Gold,
						radius = Theme.Radius.Small,
						strokeThickness = Theme.Stroke.Chip,
						studs = false,
						zIndex = 7,
					}),
				},
			}),
		},
	})
end

return SpinScreen
