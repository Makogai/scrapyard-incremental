--!nonstrict
--[[
	SecretVFX.luau
	The animated layer behind the Secret pet: glow, sparkles, motes.

	Built imperatively into one host Frame rather than as React elements, for two
	reasons. React would re-render forty nodes whenever anything above it changed,
	and every animation here is a plain looping TweenService tween -- `RepeatCount =
	-1` with `Reverses`, staggered by `DelayTime` -- which the engine runs without a
	line of Lua per frame. Nothing here touches RenderStepped or Heartbeat.

	Everything is parented to the host, so unmounting destroys the whole layer; the
	tweens are cancelled explicitly as well so a closing window leaves nothing
	running. Opening and closing repeatedly cannot stack duplicates.

	Deliberately restrained: it sits *behind* the pet, stays inside the card, and
	never touches the text. A rare pet should feel special, not strobe.

	CLIPPING RULE, learned the hard way: Roblox ignores an ancestor's
	`ClipsDescendants` for any GuiObject whose `Rotation` is non-zero. A rotated
	child opts itself out of clipping and paints across the whole screen, however
	many clipping parents sit above it.

	So nothing in here is ever rotated. The diagonal look of the sweep comes from a
	rotated *UIGradient* instead, which is a property of the fill and not of the
	object, and therefore clips normally. Sparkles are rounded squares rather than
	45-degree diamonds. The old rotating starburst had to go entirely: rotation was
	the whole effect, and there is no way to have it and stay inside the card.

]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local P = require(UI.Primitives)

local e = React.createElement

local SecretVFX = {}

--[[
	Palettes. `Secret` is the hot pink of the Secret rarity; `Gold` is the same layer
	tuned to Legendary, so the two top rarities both read as special without reading
	as the same thing.
]]
local PALETTES = {
	Secret = {
		primary = Color3.fromRGB(255, 92, 200),
		secondary = Color3.fromRGB(255, 150, 220),
		deep = Color3.fromRGB(181, 48, 255),
		star = Color3.fromRGB(255, 226, 120),
	},
	Gold = {
		primary = Color3.fromRGB(255, 186, 56),
		secondary = Color3.fromRGB(255, 226, 130),
		deep = Color3.fromRGB(226, 122, 20),
		star = Color3.fromRGB(255, 250, 210),
	},
}

--- Counts kept small on purpose: this runs on phones.
local SPARKLE_COUNT = 7
local MOTE_COUNT = 5

local function circle(parent: Instance, name: string, color: Color3, transparency: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame
	return frame
end

--[[
	Concentric discs, each fainter and wider than the last. Roblox has no radial
	gradient, so the falloff is faked by stacking -- three is enough to read as a
	soft glow and cheap enough to not care about.
]]
local function buildGlow(host: Frame, palette): { Tween }
	local tweens = {}
	local rings = {
		{ scale = 0.62, color = palette.primary, transparency = 0.55 },
		{ scale = 0.82, color = palette.secondary, transparency = 0.78 },
		{ scale = 1.02, color = palette.deep, transparency = 0.88 },
	}

	for index, ring in ipairs(rings) do
		local disc = circle(host, "Glow" .. index, ring.color, ring.transparency)
		disc.Size = UDim2.fromScale(ring.scale, ring.scale)
		disc.ZIndex = 1

		-- Breathes: slow, reversing, and offset per ring so they never pulse as one.
		local tween = TweenService:Create(
			disc,
			TweenInfo.new(
				2.2 + index * 0.35,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut,
				-1,
				true,
				index * 0.3
			),
			{
				Size = UDim2.fromScale(ring.scale * 1.12, ring.scale * 1.12),
				BackgroundTransparency = math.min(ring.transparency + 0.12, 1),
			}
		)
		tween:Play()
		table.insert(tweens, tween)
	end

	return tweens
end

--[[
	Sparkles: small four-point stars that swell and fade on their own schedules, and
	a couple of larger gold ones that flash less often.
]]
local function buildSparkles(host: Frame, palette): { Tween }
	local tweens = {}
	-- Hand-placed rather than random, so nothing lands over the pet's face or the
	-- card's text, and so the layout is the same every time it opens.
	local spots = {
		{ x = 0.16, y = 0.22, size = 0.09, big = false },
		{ x = 0.84, y = 0.28, size = 0.08, big = false },
		{ x = 0.24, y = 0.74, size = 0.07, big = false },
		{ x = 0.78, y = 0.68, size = 0.1, big = false },
		{ x = 0.5, y = 0.12, size = 0.12, big = true },
		{ x = 0.09, y = 0.52, size = 0.13, big = true },
		{ x = 0.92, y = 0.5, size = 0.08, big = false },
	}

	for index = 1, math.min(SPARKLE_COUNT, #spots) do
		local spot = spots[index]
		local star = Instance.new("Frame")
		star.Name = "Sparkle" .. index
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(spot.x, spot.y)
		star.Size = UDim2.fromScale(spot.size * 0.3, spot.size * 0.3)
		-- Rounded square, not a rotated diamond: rotation would escape the clip.
		star.BackgroundColor3 = if spot.big then palette.star else Color3.new(1, 1, 1)
		star.BackgroundTransparency = 1
		star.BorderSizePixel = 0
		star.ZIndex = 3
		star.Parent = host

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.45, 0)
		corner.Parent = star

		local period = if spot.big then 2.6 else 1.3
		local tween = TweenService:Create(
			star,
			TweenInfo.new(
				period,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.InOut,
				-1,
				true,
				index * 0.42
			),
			{
				Size = UDim2.fromScale(spot.size, spot.size),
				BackgroundTransparency = if spot.big then 0.05 else 0.25,
			}
		)
		tween:Play()
		table.insert(tweens, tween)
	end

	return tweens
end

--- Tiny motes drifting upward, low count and low contrast.
local function buildMotes(host: Frame, palette): { Tween }
	local tweens = {}
	for index = 1, MOTE_COUNT do
		local mote = circle(
			host,
			"Mote" .. index,
			if index % 2 == 0 then palette.secondary else palette.deep,
			0.4
		)
		local x = 0.18 + (index - 1) * 0.16
		mote.Size = UDim2.fromScale(0.026, 0.026)
		mote.Position = UDim2.fromScale(x, 0.82)
		mote.ZIndex = 3

		local tween = TweenService:Create(
			mote,
			TweenInfo.new(
				3.4 + index * 0.4,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut,
				-1,
				true,
				index * 0.55
			),
			{ Position = UDim2.fromScale(x + 0.03, 0.24), BackgroundTransparency = 0.95 }
		)
		tween:Play()
		table.insert(tweens, tween)
	end
	return tweens
end

--[[
	props: palette ("Secret" | "Gold"), size, position, anchorPoint, zIndex

	Sits behind whatever renders it; the caller keeps the pet on a higher ZIndex.
]]
function SecretVFX.Layer(props)
	local hostRef = React.useRef(nil :: any)

	React.useEffect(function()
		local host = hostRef.current
		if host == nil then
			return
		end

		local palette = PALETTES[props.palette or "Secret"] or PALETTES.Secret
		local tweens = {}
		for _, group in ipairs({
			buildGlow(host, palette),
			buildSparkles(host, palette),
			buildMotes(host, palette),
		}) do
			for _, tween in ipairs(group) do
				table.insert(tweens, tween)
			end
		end

		--[[
			Cancel then destroy. Destroying the instances alone would leave the tweens
			holding references until the next collection, and a window opened and
			closed repeatedly would stack them.
		]]
		return function()
			for _, tween in ipairs(tweens) do
				tween:Cancel()
			end
			for _, child in ipairs(host:GetChildren()) do
				child:Destroy()
			end
		end
	end, { props.palette })

	return e(P.Group, {
		key = props.key or "SecretVFX",
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
				-- Clipped so nothing can escape the card, however it is sized.
				ClipsDescendants = true,
			}),
		},
	})
end

--- The rarity accent this layer is tuned for, so callers do not restate it.
SecretVFX.Accent = Theme.Gradient.Pink

return SecretVFX
