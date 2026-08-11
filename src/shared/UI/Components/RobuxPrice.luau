--!nonstrict
--[[
	RobuxPrice.luau
	The one place a Robux price is drawn.

	EVERY Robux price in the game goes through this, so the treatment is consistent by construction
	rather than by remembering: gold gradient text, an ink outline, and the Robux icon from
	`Assets.Icons.robux`. Nothing else should be building its own Robux label.

	TWO VARIANTS, because a price does two different jobs:

		"corner"  a rotated tag pinned to a surface's lower-right, wiggling and pulsing so it catches
		          the eye on an otherwise static card. This is the attention-getter.
		"inline"  a flat pill that sits in a row with other content and stays still. This is the one
		          for lists, where six wiggling tags would be noise rather than emphasis.

	ROTATION IS ONLY SAFE ON `corner` BECAUSE OF WHERE IT GOES. A rotated GuiObject ignores its
	ancestors' `ClipsDescendants` (AGENTS.md rule 11), so the corner tag must only be used on a surface
	that is not clipped -- a card face, not a scrolling list row. `inline` is unrotated precisely so it
	is safe everywhere.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Format = require(UI.Format)
local Motion = require(UI.Motion)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)

local e = React.createElement

local RobuxPrice = {}

--- The house treatment for a Robux figure: gold gradient on an ink outline.
local GOLD = Theme.Gradient.Gold

--[[
	props:
		amount    number       Robux
		variant   "corner" | "inline"
		height    number?
]]
function RobuxPrice.Tag(props)
	local amount = props.amount or 0
	local corner = (props.variant or "inline") == "corner"
	local height = props.height or (if corner then 30 else 26)
	local iconExtent = height - 8

	--[[
		The corner tag pulses and wiggles; the inline pill does neither.

		Both hooks run unconditionally -- calling one conditionally would change the hook count between
		renders, which React treats as a different component and throws on. The inline variant simply
		ignores the values.
	]]
	local wiggle = Motion.useWiggle({ every = 2.4, angle = 7, shakes = 2 })
	local pulse = Motion.useSpin(40, corner)

	local children = P.compact(
		e(Icon, {
			key = "Robux",
			glyph = "robux",
			plain = true,
			size = UDim2.fromOffset(iconExtent, iconExtent),
			position = UDim2.new(0, 6, 0.5, 0),
			anchorPoint = Vector2.new(0, 0.5),
			zIndex = 3,
		}),
		e(P.Label, {
			key = "Amount",
			text = Format.comma(amount),
			textSize = if corner then Theme.TextSize.Body else Theme.TextSize.Small,
			--- Gold gradient over the glyphs, with the kit's ink outline underneath.
			gradient = GOLD,
			color = Theme.Color.White,
			align = Enum.TextXAlignment.Left,
			position = UDim2.new(0, iconExtent + 10, 0.5, 0),
			anchorPoint = Vector2.new(0, 1 / 2),
			size = UDim2.new(1, -(iconExtent + 16), 1, 0),
			zIndex = 3,
		})
	)

	--- Width tracks the digits, so 59 and 1,200 both sit snugly rather than in a fixed box.
	local width = iconExtent + 18 + #Format.comma(amount) * (if corner then 13 else 11)

	if not corner then
		return e(P.Panel, {
			key = props.key or "RobuxPrice",
			size = UDim2.fromOffset(width, height),
			position = props.position,
			anchorPoint = props.anchorPoint,
			layoutOrder = props.layoutOrder,
			zIndex = props.zIndex,
			gradient = Theme.Gradient.PanelDeep,
			radius = Theme.Radius.Chip,
			strokeThickness = Theme.Stroke.Chip,
			studs = false,
			children = children,
		})
	end

	--[[
		The corner tag. Rotation, wiggle and a slow scale breath, hung off the lower-right of whatever
		it is placed on -- so it reads as a sticker slapped on the card rather than part of its layout.
	]]
	return e(P.Group, {
		key = props.key or "RobuxPrice",
		size = UDim2.fromOffset(width, height),
		position = props.position or UDim2.new(1, 6, 1, 6),
		anchorPoint = props.anchorPoint or Vector2.new(1, 1),
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex or 6,
		rotation = wiggle:map(function(offset: number)
			return -8 + offset
		end),
		children = {
			--[[
				A sine off the spin hook rather than a second spring: `useSpin` climbs forever, so feeding it
				through sin gives a loop that never settles, which is what "grows a bit and goes back" needs.
			]]
			e("UIScale", {
				key = "Breath",
				Scale = pulse:map(function(angle: number)
					return 1 + math.sin(math.rad(angle)) * 0.06
				end),
			}),
			e(P.Panel, {
				key = "Slab",
				size = UDim2.fromScale(1, 1),
				gradient = Theme.Gradient.Purple,
				radius = Theme.Radius.Chip,
				strokeThickness = Theme.Stroke.Card,
				studs = false,
				children = children,
			}),
		},
	})
end

return RobuxPrice
