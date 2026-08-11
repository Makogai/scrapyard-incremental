--!nonstrict
--[[
	RewardToast.luau
	"You got this" -- the banner that announces a single reward.

	Built for the spin wheel, which needed somewhere to say what you won once the COLLECT button was
	removed, but it is deliberately generic: anything that hands the player one thing can use it.
	Daily claims and playtime milestones are the obvious next callers.

	THE SHAPE. A wide pill with the accent gradient fading out to BOTH edges and a solid readable
	middle, an icon well on the left, and the reward in two lines: what it is, and what it does. The
	symmetrical fade is what makes it read as a banner rather than a card -- a card has edges, a banner
	arrives.

	The fade is two mirrored `UIGradient` transparency ramps rather than one: a single gradient can only
	go light-to-dark in one direction, so a symmetrical fall-off needs a pair. Both are horizontal, and
	neither rotates a frame, so nothing here can escape a clipping parent.

	WHY NOT A `Toast`. `Overlays.Toast` is the small stacking notification feed in the corner, capped at
	four and driven by the `Notify` remote. This is a single centred moment tied to an animation, and
	putting it in that queue would let a magnet warning push a jackpot off the screen.
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

local RewardToast = {}

--[[
	Which glyph fronts a reward bundle.

	Money is the common case and gets the coin; spins get the wheel; anything with items gets the
	potion, because every consumable in the game is one. An explicit `glyph` always wins, so a caller
	with better information is never fighting this.
]]
function RewardToast.glyphFor(reward: { [string]: any }): string
	if reward.Glyph then
		return reward.Glyph
	end
	if reward.Spins then
		return "wheel"
	end
	if reward.Items then
		return "potion"
	end
	if reward.Gears then
		return "gear"
	end
	return "coin"
end

--[[
	props:
		title     "GOD POTION"        what you got
		detail    "+ $250,000"        optional second line
		glyph     icon name
		accent    Theme.Gradient key, default Gold
		best      boolean?            adds the shine layer
		width     number?
]]
function RewardToast.Banner(props)
	local accentName = props.accent or "Gold"
	local accent = Theme.Gradient[accentName] or Theme.Gradient.Gold
	local width = props.width or 460
	local height = props.height or 92
	local wellExtent = height - 22

	--- Springs in from slightly small, so it lands rather than appears.
	local entrance = Motion.useEntrance(Motion.Spring.Bouncy)

	--[[
		A transparency ramp that is opaque in the middle and clear at both ends. Applied to the fill, so
		the fade is a property of the gradient rather than a stack of frames -- and a `UIGradient` is not
		a GuiObject, so its rotation cannot break clipping the way a rotated frame would.
	]]
	local fade = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.22, 0.15),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.78, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})

	return e(P.Group, {
		key = props.key or "RewardToast",
		size = UDim2.fromOffset(width, height),
		position = props.position,
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex,
		children = {
			e("UIScale", { key = "Entrance", Scale = entrance }),
			--[[
				The banner body. No stroke and no corner ink: an outline would give it the edges the fade
				exists to remove.
			]]
			e("Frame", {
				key = "Body",
				BackgroundColor3 = Theme.Color[accentName] or Theme.Color.Gold,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
			}, {
				e("UIGradient", {
					key = "Fade",
					Color = accent,
					Transparency = fade,
					Rotation = 0,
				}),
			}),
			--- A darker inner band so white text stays readable over a pale accent.
			e("Frame", {
				key = "Ink",
				BackgroundColor3 = Theme.Color.Ink,
				BackgroundTransparency = 0.45,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, height - 26),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 2,
			}, {
				e("UIGradient", {
					key = "Fade",
					Transparency = fade,
					Rotation = 0,
				}),
			}),
			if props.best
				then e(Shine.Layer, {
					key = "Shine",
					glow = true,
					sparkles = true,
					color = Theme.Color[accentName] or Theme.Color.Gold,
					zIndex = 3,
				})
				else nil,
			--- The icon well: a solid disc so the art reads against the fade behind it.
			e(P.Panel, {
				key = "Well",
				size = UDim2.fromOffset(wellExtent, wellExtent),
				position = UDim2.new(0.5, -width / 2 + wellExtent / 2 + 26, 0.5, 0),
				anchorPoint = Vector2.new(0.5, 0.5),
				gradient = Theme.Gradient.Slot,
				radius = wellExtent / 2,
				strokeThickness = 4,
				studs = false,
				zIndex = 4,
				children = {
					e(Icon, {
						key = "Glyph",
						glyph = props.glyph or "coin",
						plain = true,
						size = UDim2.fromOffset(wellExtent - 18, wellExtent - 18),
						position = UDim2.fromScale(0.5, 0.5),
						anchorPoint = Vector2.new(0.5, 0.5),
					}),
				},
			}),
			e(P.Group, {
				key = "Text",
				size = UDim2.fromOffset(width - wellExtent - 80, height - 26),
				position = UDim2.new(0, wellExtent + 46, 0.5, 0),
				anchorPoint = Vector2.new(0, 0.5),
				zIndex = 4,
				layout = P.list({ padding = 2, vAlign = Enum.VerticalAlignment.Center }),
				children = P.compact(
					e(P.Label, {
						key = "Title",
						text = string.upper(tostring(props.title or "")),
						textSize = Theme.TextSize.Heading,
						color = Theme.Color.White,
						align = Enum.TextXAlignment.Left,
						size = UDim2.new(1, 0, 0, 30),
						layoutOrder = 1,
					}),
					if props.detail
						then e(P.Label, {
							key = "Detail",
							text = props.detail,
							textSize = Theme.TextSize.Body,
							font = Theme.Font.Bold,
							color = Theme.Color.Positive,
							align = Enum.TextXAlignment.Left,
							size = UDim2.new(1, 0, 0, 24),
							layoutOrder = 2,
						})
						else nil
				),
			}),
		},
	})
end

return RewardToast
