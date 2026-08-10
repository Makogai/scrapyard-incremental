--!nonstrict
--[[
	Shine.luau
	Lightweight animated accents for cards that need to feel alive.

	Three effects, all opt-in per card so a grid of twenty products does not have to
	pay for effects it does not use:

		sweep     a diagonal highlight that travels across the card, on a loop
		glow      a soft pulsing halo behind the card's art
		sparkles  a few small points swelling and fading on staggered timers

	CLIPPING RULE, learned the hard way: Roblox ignores an ancestor's
	`ClipsDescendants` for any GuiObject whose `Rotation` is non-zero. A rotated
	child opts itself out of clipping and paints across the whole screen, however
	many clipping parents sit above it.

	So nothing in here is ever rotated. The diagonal look of the sweep comes from a
	rotated *UIGradient* instead, which is a property of the fill and not of the
	object, and therefore clips normally. Sparkles are rounded squares rather than
	45-degree diamonds. The old rotating starburst had to go entirely: rotation was
	the whole effect, and there is no way to have it and stay inside the card.

	Built imperatively into one host Frame and animated entirely by looping
	`TweenService` tweens -- `RepeatCount = -1`, `Reverses`, staggered by `DelayTime`
	-- which the engine runs with no Lua per frame. Nothing here touches
	RenderStepped or Heartbeat. Tweens are cancelled and children destroyed on
	unmount, so a shop that is opened and closed repeatedly cannot stack duplicates.

	This is the same approach as `SecretVFX`, generalised: that one is a fixed pink
	pet-reveal treatment, this one takes a colour and a set of effects.

	Deliberately restrained. Flashy and enticing, not cheap casino spam: effects sit
	*behind* the content, stay inside the card, and never touch the text.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local P = require(UI.Primitives)

local e = React.createElement

local Shine = {}

--- Small counts on purpose: this runs on phones, in a grid.
local SPARKLE_COUNT = 4

--[[
	The travelling highlight. One thin bright bar sweeping left to right on a long
	loop with a pause between passes.

	The pause is what keeps a wall of cards from looking like a strobe: the tween
	takes 1.1s and then waits, so most cards are idle at any moment.
]]
local function buildSweep(host: Frame, color: Color3, delay: number): { Tween }
	local bar = Instance.new("Frame")
	bar.Name = "Sweep"
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(-0.35, 0.5)
	bar.Size = UDim2.fromScale(0.3, 1.4)
	-- Never rotated; see the clipping rule at the top of this file.
	bar.BackgroundColor3 = color
	bar.BackgroundTransparency = 0.72
	bar.BorderSizePixel = 0
	bar.ZIndex = 4
	bar.Parent = host

	--[[
		Feathered, so the bar reads as light rather than a moving rectangle -- and
		angled, which is where the diagonal comes from now that the frame itself
		cannot be rotated. A gradient's rotation is a property of the fill, so it
		still clips.
	]]
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 22
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = bar

	local tween = TweenService:Create(
		bar,
		TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, delay),
		{ Position = UDim2.fromScale(1.35, 0.5) }
	)
	tween:Play()
	return { tween }
end

--- A soft halo behind the art. Two stacked discs, since Roblox has no radial fill.
local function buildGlow(host: Frame, color: Color3): { Tween }
	local tweens = {}
	for index, spec in ipairs({ { scale = 0.62, alpha = 0.5 }, { scale = 0.86, alpha = 0.78 } }) do
		local disc = Instance.new("Frame")
		disc.Name = "Glow" .. index
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.Position = UDim2.fromScale(0.5, 0.42)
		disc.Size = UDim2.fromScale(spec.scale, spec.scale)
		disc.BackgroundColor3 = color
		disc.BackgroundTransparency = spec.alpha
		disc.BorderSizePixel = 0
		disc.ZIndex = 1
		disc.Parent = host

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = disc

		local tween = TweenService:Create(
			disc,
			TweenInfo.new(
				2 + index * 0.4,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut,
				-1,
				true,
				index * 0.3
			),
			{
				Size = UDim2.fromScale(spec.scale * 1.14, spec.scale * 1.14),
				BackgroundTransparency = math.min(spec.alpha + 0.12, 1),
			}
		)
		tween:Play()
		table.insert(tweens, tween)
	end
	return tweens
end

--- A few stars, placed by hand so none of them lands over the title or the button.
local function buildSparkles(host: Frame, color: Color3): { Tween }
	local spots = {
		{ x = 0.14, y = 0.2, size = 0.08 },
		{ x = 0.86, y = 0.26, size = 0.07 },
		{ x = 0.78, y = 0.12, size = 0.06 },
		{ x = 0.2, y = 0.42, size = 0.05 },
	}

	local tweens = {}
	for index = 1, math.min(SPARKLE_COUNT, #spots) do
		local spot = spots[index]
		local star = Instance.new("Frame")
		star.Name = "Sparkle" .. index
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(spot.x, spot.y)
		star.Size = UDim2.fromScale(spot.size * 0.3, spot.size * 0.3)
		-- A rounded square, not a rotated diamond: rotation would escape the clip.
		star.BackgroundColor3 = color
		star.BackgroundTransparency = 1
		star.BorderSizePixel = 0
		star.ZIndex = 3
		star.Parent = host

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.45, 0)
		corner.Parent = star

		local tween = TweenService:Create(
			star,
			TweenInfo.new(
				1.4,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.InOut,
				-1,
				true,
				index * 0.45
			),
			{ Size = UDim2.fromScale(spot.size, spot.size), BackgroundTransparency = 0.15 }
		)
		tween:Play()
		table.insert(tweens, tween)
	end
	return tweens
end

--[[
	props:
		color     accent for every effect, usually the card's own
		sweep     boolean
		glow      boolean
		sparkles  boolean
		delay     stagger for the sweep, so a grid does not pulse in unison
		size, position, anchorPoint, zIndex
]]
function Shine.Layer(props)
	local hostRef = React.useRef(nil :: any)
	local color = props.color or Color3.fromRGB(255, 255, 255)

	React.useEffect(function()
		local host = hostRef.current
		if host == nil then
			return
		end

		local tweens = {}
		local function add(group)
			for _, tween in ipairs(group) do
				table.insert(tweens, tween)
			end
		end

		if props.glow then
			add(buildGlow(host, color))
		end
		if props.sparkles then
			add(buildSparkles(host, Color3.new(1, 1, 1)))
		end
		if props.sweep then
			add(buildSweep(host, Color3.new(1, 1, 1), props.delay or 0))
		end

		--[[
			Cancel then destroy. Destroying the instances alone would leave the tweens
			holding references, and a shop opened and closed repeatedly would stack
			them.
		]]
		return function()
			for _, tween in ipairs(tweens) do
				tween:Cancel()
			end
			for _, child in ipairs(host:GetChildren()) do
				child:Destroy()
			end
		end
	end, { color, props.sweep, props.glow, props.sparkles, props.delay })

	return e(P.Group, {
		key = props.key or "Shine",
		size = props.size or UDim2.fromScale(1, 1),
		position = props.position or UDim2.fromScale(0.5, 0.5),
		anchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
		zIndex = props.zIndex or 2,
		children = {
			e("Frame", {
				key = "Host",
				ref = hostRef,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				-- Clipped. Only works because nothing inside is rotated.
				ClipsDescendants = true,
			}),
		},
	})
end

return Shine
