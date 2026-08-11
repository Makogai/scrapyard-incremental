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
	Rim and pointer, pulled out because they are the two things that make it read as a wheel rather
	than a pie chart: a thick warm rim with bolts, and a red pointer biting into the top of it.
]]
local RIM_COLOR = Color3.fromHex("E2A24B")
local RIM_INNER = Color3.fromHex("C98436")
local POINTER_COLOR = Color3.fromHex("E33B3B")

--- Vertical room above the wheel for the pointer to sit in.
local POINTER_LANE = 30

--- Bolt studs around the rim.
local BOLT_COUNT = 12

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
		Layout inside the wedge, matching how a painted prize wheel reads: the NAME hugs the outer edge
		where there is room for it, and the icon sits big in the middle of the wedge.

		Both are rotated to the wedge's own mid-angle so they sit square within it. Text on the left half
		comes out upside-down; physical wheels do that too, and flipping half the labels reads worse than
		one consistent rule.
	]]
	local mid = from + span / 2
	local labelRadians = math.rad(mid)

	local function radial(distance: number): (number, number)
		return math.sin(labelRadians) * distance, -math.cos(labelRadians) * distance
	end

	--- Out near the rim, where the wedge is widest.
	local labelX, labelY = radial(radius * 0.78)
	parts[#parts + 1] = e(P.Label, {
		key = "Name",
		text = props.label,
		textSize = if props.best then Theme.TextSize.Body else Theme.TextSize.Small,
		color = Theme.Color.White,
		wrapped = true,
		position = UDim2.new(0.5, labelX, 0.5, labelY),
		anchorPoint = Vector2.new(0.5, 0.5),
		rotation = mid,
		size = UDim2.fromOffset(math.floor(radius * 0.62), 40),
		zIndex = 6,
	})

	--- Big, in the body of the wedge. This is what the eye actually lands on.
	local iconExtent = math.floor(radius * 0.30)
	local iconX, iconY = radial(radius * 0.46)
	parts[#parts + 1] = e(Icon, {
		key = "Glyph",
		glyph = props.glyph or "star",
		plain = true,
		size = UDim2.fromOffset(iconExtent, iconExtent),
		position = UDim2.new(0.5, iconX, 0.5, iconY),
		anchorPoint = Vector2.new(0.5, 0.5),
		rotation = mid,
		zIndex = 6,
	})

	--[[
		The best prize gets the shine on a transparent overlay covering its own wedge, not on the bars:
		the bars are 9 separate frames and putting a glow on each would be nine glows.
	]]
	if props.best then
		parts[#parts + 1] = e(P.Group, {
			key = "Shine",
			size = UDim2.fromOffset(radius * 0.7, radius * 0.7),
			position = UDim2.new(0.5, iconX, 0.5, iconY),
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

	local rimWidth = math.max(18, math.floor(extent * 0.055))

	--[[
		Bolt studs, laid out by angle like the wedges but on the OUTER frame, so they do not turn with
		the wheel.
	]]
	local bolts = {}
	for index = 1, BOLT_COUNT do
		local angle = math.rad((index - 1) * (360 / BOLT_COUNT) + 15)
		local boltRadius = radius + rimWidth * 0.1
		bolts[#bolts + 1] = e("Frame", {
			key = `Bolt{index}`,
			BackgroundColor3 = RIM_INNER,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(9, 9),
			Position = UDim2.new(
				0.5,
				math.sin(angle) * boltRadius,
				0.5,
				-math.cos(angle) * boltRadius
			),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 9,
		}, {
			e("UICorner", { key = "Round", CornerRadius = UDim.new(0.5, 0) }),
		})
	end

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
		size = UDim2.fromOffset(extent + rimWidth * 2 + 8, extent + POINTER_LANE + rimWidth + 8),
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
				position = UDim2.new(0.5, 0, 0, POINTER_LANE),
				anchorPoint = Vector2.new(0.5, 0),
				rotation = props.rotation,
				zIndex = 2,
				children = wedges,
			}),
			--[[
				THE RIM. A thick warm ring over the wedges with bolt studs around it -- which is what makes a
				drawn wheel read as a physical object rather than a pie chart. Rings are
				background-transparent frames with a fat `UIStroke`, so they cover the fill bars'
				overshooting corners without covering the wedges themselves.
			]]
			e("Frame", {
				key = "Rim",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(extent + rimWidth, extent + rimWidth),
				Position = UDim2.new(0.5, 0, 0, POINTER_LANE + extent / 2),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 7,
			}, {
				e("UICorner", { key = "Round", CornerRadius = UDim.new(0.5, 0) }),
				e("UIStroke", {
					key = "Ring",
					Thickness = rimWidth,
					Color = RIM_COLOR,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
			}),
			--- Ink outline outside the rim: the same heavy edge every other surface in the kit carries.
			e("Frame", {
				key = "RimInk",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(extent + rimWidth * 2 + 6, extent + rimWidth * 2 + 6),
				Position = UDim2.new(0.5, 0, 0, POINTER_LANE + extent / 2),
				AnchorPoint = Vector2.new(0.5, 0.5),
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
			--[[
				Bolt studs. Outside the turntable so they stay still while the wheel turns -- bolts that
				spun with the wedges would read as part of the prize art rather than as hardware.
			]]
			e(P.Group, {
				key = "Bolts",
				size = UDim2.fromOffset(extent, extent),
				position = UDim2.new(0.5, 0, 0, POINTER_LANE),
				anchorPoint = Vector2.new(0.5, 0),
				zIndex = 8,
				children = bolts,
			}),
			--- Hub, outside the turntable so its star stays upright while the wheel spins.
			e(P.Panel, {
				key = "Hub",
				size = UDim2.fromOffset(hub, hub),
				position = UDim2.new(0.5, 0, 0, POINTER_LANE + radius),
				anchorPoint = Vector2.new(0.5, 0.5),
				gradient = Theme.Gradient.Gold,
				radius = hub / 2,
				strokeThickness = 5,
				studs = false,
				zIndex = 9,
				children = {
					e(P.Panel, {
						key = "HubInner",
						size = UDim2.fromOffset(hub - 18, hub - 18),
						position = UDim2.fromScale(0.5, 0.5),
						anchorPoint = Vector2.new(0.5, 0.5),
						gradient = Theme.Gradient.Orange,
						radius = (hub - 18) / 2,
						strokeThickness = 3,
						studs = false,
						children = {
							e(Icon, {
								key = "Star",
								glyph = "star",
								plain = true,
								size = UDim2.fromOffset(hub - 42, hub - 42),
								position = UDim2.fromScale(0.5, 0.5),
								anchorPoint = Vector2.new(0.5, 0.5),
							}),
						},
					}),
				},
			}),
			--[[
				THE POINTER: a red triangle at the top pointing DOWN into the wheel, sitting above the rim
				rather than beside it, as in the reference.

				A triangle needs a rotated square, and rotation is safe here because nothing is being
				clipped. Positioned so its lower corner meets the rim.
			]]
			e("Frame", {
				key = "Pointer",
				BackgroundColor3 = POINTER_COLOR,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(30, 30),
				Position = UDim2.new(0.5, 0, 0, POINTER_LANE - 2),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = 45,
				ZIndex = 11,
			}, {
				e("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 6) }),
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
