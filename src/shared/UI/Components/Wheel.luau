--!nonstrict
--[[
	Wheel.luau
	A real pie-wedge prize wheel, built from frames.

	HOW YOU DRAW A PIE WEDGE IN ROBLOX, given the engine gives you nothing to do it with.

	There is no radial gradient, no arc, and no wedge primitive. The technique everyone reaches for
	first -- a rotated half-plane inside a circular `ClipsDescendants` frame -- DOES NOT WORK, and
	that is the whole content of AGENTS.md rule 11: a GuiObject with non-zero `Rotation` ignores its
	ancestors' clipping. So you cannot clip a rotated rectangle into a wedge shape.

	What does work is filling each wedge with a fan of thin rotated bars. Every bar is rotated (fine,
	nothing is being clipped) and each covers a few degrees; together they tile the wedge with no
	visible seams because adjacent bars overlap. A rim ring drawn on top hides the fact that the bars'
	outer corners overshoot the circle by a fraction of a pixel.

	`SLICE_DEGREES` is the resolution knob. At 5 degrees an eight-segment wheel is 72 bars, which is
	nothing for a window that is only open while someone is spinning it. Lower it for smoother edges,
	raise it if a wheel ever needs to live on the HUD.

	The alternative is one uploaded wheel image plus rotation, which is cheaper and sharper -- if a
	wheel PNG ever lands in `Assets`, this component is the thing to replace.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)
local Shine = require(UI.Components.Shine)

local e = React.createElement

local Wheel = {}

--- Angular width of one fill bar. Smaller is smoother and costs more frames.
local SLICE_DEGREES = 5

--[[
	One wedge, as a fan of bars plus its label.

	`from` and `to` are degrees clockwise from straight up, which is where the pointer sits.
]]
local function Wedge(props)
	local radius = props.radius
	local from, to = props.from, props.to
	local span = to - from
	local sliceCount = math.max(2, math.ceil(span / SLICE_DEGREES))
	local sliceSpan = span / sliceCount

	--[[
		Bar width is the chord of one slice, plus a hair of overlap so neighbours cannot show a seam
		between them. Height is the full radius, and the bar is centred half a radius out so its inner
		end lands on the hub.
	]]
	local barWidth = 2 * radius * math.sin(math.rad(sliceSpan / 2)) + 1.5

	local parts = {}
	for index = 0, sliceCount - 1 do
		local mid = from + sliceSpan * (index + 0.5)
		local radians = math.rad(mid)
		local offsetX = math.sin(radians) * radius / 2
		local offsetY = -math.cos(radians) * radius / 2
		parts[#parts + 1] = e("Frame", {
			key = `Slice{index}`,
			BackgroundColor3 = props.color,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(math.ceil(barWidth), radius),
			Position = UDim2.new(0.5, offsetX, 0.5, offsetY),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = mid,
			ZIndex = 2,
		})
	end

	--[[
		The label rides the wedge's own mid-radius, rotated to run OUTWARD along it -- which is how the
		reference wheel reads, and how a physical prize wheel is painted. Text on the left half comes
		out upside-down; real wheels do that too, and fixing it would mean flipping half the labels,
		which reads worse than leaving it consistent.
	]]
	local mid = from + span / 2
	local labelRadians = math.rad(mid)
	local labelRadius = radius * 0.60
	local labelX = math.sin(labelRadians) * labelRadius
	local labelY = -math.cos(labelRadians) * labelRadius

	parts[#parts + 1] = e(P.Group, {
		key = "Content",
		size = UDim2.fromOffset(radius * 0.82, 74),
		position = UDim2.new(0.5, labelX, 0.5, labelY),
		anchorPoint = Vector2.new(0.5, 0.5),
		rotation = mid + 90,
		zIndex = 6,
		children = P.compact(
			e(Icon, {
				key = "Glyph",
				glyph = props.glyph or "star",
				plain = true,
				size = UDim2.fromOffset(40, 40),
				position = UDim2.new(0, 2, 0.5, 0),
				anchorPoint = Vector2.new(0, 0.5),
			}),
			e(P.Label, {
				key = "Label",
				text = props.label,
				textSize = if props.best then Theme.TextSize.Body else Theme.TextSize.Small,
				color = Theme.Color.White,
				align = Enum.TextXAlignment.Left,
				wrapped = true,
				position = UDim2.new(0, 46, 0.5, 0),
				anchorPoint = Vector2.new(0, 0.5),
				size = UDim2.new(1, -52, 0, 60),
			})
		),
	})

	--[[
		The best prize gets the shine on a transparent overlay covering its own wedge, not on the bars:
		the bars are 9 separate frames and putting a glow on each would be nine glows.
	]]
	if props.best then
		parts[#parts + 1] = e(P.Group, {
			key = "Shine",
			size = UDim2.fromOffset(radius * 0.9, radius * 0.9),
			position = UDim2.new(0.5, labelX, 0.5, labelY),
			anchorPoint = Vector2.new(0.5, 0.5),
			zIndex = 5,
			children = {
				e(Shine.Layer, {
					key = "Layer",
					glow = true,
					sparkles = true,
					color = Theme.Color.Gold,
					zIndex = 5,
				}),
			},
		})
	end

	return e(P.Group, {
		key = props.key,
		size = UDim2.fromScale(1, 1),
		zIndex = if props.best then 3 else 2,
		children = parts,
	})
end

--[[
	The wheel.

	props:
		segments   { { Id, Label, Glyph, Accent, Best? } }
		rotation   number | binding    degrees; the caller owns the spin animation
		extent     number?             overall diameter
]]
function Wheel.Wheel(props)
	local extent = props.extent or 380
	local radius = extent / 2
	local hub = props.hubExtent or 86
	local segments = props.segments or {}
	local count = math.max(#segments, 1)
	local step = 360 / count

	local wedges = {}
	for index, segment in ipairs(segments) do
		--[[
			Segment i occupies `[(i-1)*step, i*step)` clockwise from up, so its CENTRE is at
			`(i-0.5)*step`. That is the angle the caller has to rotate to in order to land it under the
			pointer, and it is the one piece of maths this component and the screen must agree on.
		]]
		local accentName = segment.Accent or "Green"
		local accent = Theme.Color[accentName] or Theme.Color.Green
		wedges[#wedges + 1] = e(Wedge, {
			key = segment.Id or `Wedge{index}`,
			from = (index - 1) * step,
			to = index * step,
			radius = radius,
			color = if segment.Best then Theme.Color.Gold else accent,
			label = segment.Label,
			glyph = segment.Glyph,
			best = segment.Best == true,
		})
	end

	return e(P.Group, {
		key = props.key or "Wheel",
		size = UDim2.fromOffset(extent, extent + 26),
		position = props.position,
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex,
		children = {
			--[[
				The turning part. The wedges are laid out at fixed angles inside it, so spinning the wheel
				is one `Rotation` on this group rather than recomputing every wedge.
			]]
			e(P.Group, {
				key = "Turntable",
				size = UDim2.fromOffset(extent, extent),
				position = UDim2.new(0.5, 0, 0, 26),
				anchorPoint = Vector2.new(0.5, 0),
				rotation = props.rotation,
				zIndex = 2,
				children = wedges,
			}),
			--[[
				The rim, drawn OVER the wedges. It is a ring rather than a disc -- a transparent middle
				with a thick stroke -- so it hides the bars' overshooting corners and gives the wheel a
				hard edge without covering anything.
			]]
			e("Frame", {
				key = "Rim",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(extent, extent),
				Position = UDim2.new(0.5, 0, 0, 26),
				AnchorPoint = Vector2.new(0.5, 0),
				ZIndex = 7,
			}, {
				e("UICorner", { key = "Round", CornerRadius = UDim.new(0.5, 0) }),
				e("UIStroke", {
					key = "Ring",
					Thickness = 10,
					Color = Theme.Color.GrayDark,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
			}),
			e("Frame", {
				key = "RimInk",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(extent + 18, extent + 18),
				Position = UDim2.new(0.5, 0, 0, 26 - 9),
				AnchorPoint = Vector2.new(0.5, 0),
				ZIndex = 6,
			}, {
				e("UICorner", { key = "Round", CornerRadius = UDim.new(0.5, 0) }),
				e("UIStroke", {
					key = "Ring",
					Thickness = 4,
					Color = Theme.Color.Outline,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
			}),
			--- Hub, outside the turntable so its glyph stays upright while the wheel spins.
			e(P.Panel, {
				key = "Hub",
				size = UDim2.fromOffset(hub, hub),
				position = UDim2.new(0.5, 0, 0, 26 + radius),
				anchorPoint = Vector2.new(0.5, 0.5),
				gradient = Theme.Gradient.Panel,
				radius = hub / 2,
				strokeThickness = 5,
				studs = false,
				zIndex = 9,
				children = {
					e(Icon, {
						key = "HubGlyph",
						glyph = "wheel",
						plain = true,
						size = UDim2.fromOffset(hub - 30, hub - 30),
						position = UDim2.fromScale(0.5, 0.5),
						anchorPoint = Vector2.new(0.5, 0.5),
					}),
				},
			}),
			--[[
				The pointer: a downward triangle at the top, outside the turntable so it stays put.

				A real triangle needs a rotated square, and rotation here is safe because nothing is being
				clipped -- but a rotated square's bounding box is bigger than the square, so it is sized
				and positioned to keep its lower corner exactly on the rim.
			]]
			e("Frame", {
				key = "Pointer",
				BackgroundColor3 = Theme.Color.White,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(26, 26),
				Position = UDim2.new(0.5, 0, 0, 16),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = 45,
				ZIndex = 10,
			}, {
				e("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 5) }),
				e("UIStroke", {
					key = "Ink",
					Thickness = 3,
					Color = Theme.Color.Outline,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
			}),
		},
	})
end

return Wheel
