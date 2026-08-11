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
local Motion = require(UI.Motion)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)
local Shine = require(UI.Components.Shine)
local RewardToast = require(UI.Components.RewardToast)

local e = React.createElement

local Wheel = {}

--- Angular width of one fill bar. Smaller is smoother and costs more frames.
local SLICE_DEGREES = 5

--[[
	Rim and pointer, pulled out because they are the two things that make it read as a wheel rather
	than a pie chart: a thick warm rim with bolts, and a red pointer biting into the top of it.
]]
local RIM_COLOR = Color3.fromHex("E2A24B")
local RIM_LIGHT = Color3.fromHex("FFCF86")
local RIM_SHADOW = Color3.fromHex("8A5520")
local POINTER_COLOR = Color3.fromHex("E33B3B")
local POINTER_RAMP = ColorSequence.new(
	POINTER_COLOR:Lerp(Color3.new(1, 1, 1), 0.32),
	POINTER_COLOR:Lerp(Color3.new(0, 0, 0), 0.28)
)

--- The pin: a rounded body with one square tip rotated under it.
local POINTER_TIP = 34
local POINTER_BODY = Vector2.new(30, 30)

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

	--[[
		THE FILL IS A RADIAL RAMP, WHICH IS THE OTHER HALF OF THE DEPTH.

		Each bar's local Y axis runs along the radius -- top edge at the rim, bottom edge at the hub --
		because the bar is `radius` tall and pushed half a radius outward along its own mid-angle. A
		`UIGradient` at 90 degrees therefore runs rim-to-hub, and since the gradient lives inside the bar
		it rotates with it, so all the bars in all the wedges ramp along the same radial direction.

		Dark at the rim, light at the hub. That is the way a lit dome reads, and it stops eight flat
		wedges looking like a pie chart.
	]]
	--[[
		ALTERNATE WEDGES ARE SHADED, because the prize list does not alternate colours.

		Two Green cash segments sit next to each other in the config, and two Cyan ones -- so at equal
		tone they merged into one big wedge and the wheel read as six slices instead of eight. Every
		other wedge is knocked back, which guarantees neighbours differ whatever the accents are.
	]]
	local base = if props.shade then props.color:Lerp(Color3.new(0, 0, 0), 0.22) else props.color
	local inner = base:Lerp(Color3.new(1, 1, 1), 0.42)
	local outer = base:Lerp(Color3.new(0, 0, 0), 0.22)
	local fillRamp = ColorSequence.new({
		ColorSequenceKeypoint.new(0, outer),
		ColorSequenceKeypoint.new(0.55, base),
		ColorSequenceKeypoint.new(1, inner),
	})

	local parts = {}
	for index = 0, sliceCount - 1 do
		local mid = from + sliceSpan * (index + 0.5)
		local radians = math.rad(mid)
		local offsetX = math.sin(radians) * radius / 2
		local offsetY = -math.cos(radians) * radius / 2
		parts[#parts + 1] = e("Frame", {
			key = `Slice{index}`,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(math.ceil(barWidth), radius),
			Position = UDim2.new(0.5, offsetX, 0.5, offsetY),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = mid,
			ZIndex = 2,
		}, {
			e("UIGradient", { key = "Ramp", Color = fillRamp, Rotation = 90 }),
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

	--[[
		THE NAME, AND ITS ODDS UNDER IT.

		The chance used to live in a separate ODDS panel behind a button, which is one click and one
		window for a number that belongs to the wedge it describes. Printed under the name it needs no
		chrome at all, and a player can read the whole prize table by looking at the wheel.

		The odds line is deliberately small and grey: it is reference, not a headline. The name is not --
		it is the thing being read at a glance, so it sits a step up in size from before.
	]]
	local labelX, labelY = radial(radius * 0.87)
	parts[#parts + 1] = e(P.Label, {
		key = "Name",
		text = props.label,
		--[[
			ONE SIZE FOR EVERY NAME, including the jackpot's.

			At title size "GOD POTION" wrapped to two lines and the second one clipped, so the best prize
			on the wheel read as "GOD". The jackpot is already marked by its gold wedge and its sparkles --
			it does not need a bigger typeface, and it cannot have one that breaks its own name.
		]]
		textSize = Theme.TextSize.Body,
		color = Theme.Color.White,
		wrapped = true,
		position = UDim2.new(0.5, labelX, 0.5, labelY),
		anchorPoint = Vector2.new(0.5, 0.5),
		rotation = mid,
		size = UDim2.fromOffset(math.floor(radius * 0.62), 44),
		zIndex = 6,
	})

	if props.chance then
		--- Just inside the name, so name and odds read as one block turning with the wedge.
		local oddsX, oddsY = radial(radius * 0.72)
		parts[#parts + 1] = e(P.Label, {
			key = "Odds",
			text = props.chance,
			textSize = Theme.TextSize.Small,
			color = Theme.Color.White,
			textTransparency = 0.25,
			position = UDim2.new(0.5, oddsX, 0.5, oddsY),
			anchorPoint = Vector2.new(0.5, 0.5),
			rotation = mid,
			size = UDim2.fromOffset(math.floor(radius * 0.42), 18),
			zIndex = 6,
		})
	end

	--[[
		AS BIG AS THE WEDGE CAN ACTUALLY HOLD.

		The limit is geometric, not taste: at distance d from the centre a wedge is only
		`2 * d * sin(span/2)` wide, so an icon bigger than that hangs over its neighbours -- which is
		exactly what a flat `radius * 0.46` did on an eight-segment wheel. Taking the smaller of the two
		means the art grows on a four-segment wheel and shrinks on a twelve without any per-count tuning.
	]]
	local iconDistance = radius * 0.44
	local chord = 2 * iconDistance * math.sin(math.rad(span / 2))
	local iconExtent = math.floor(math.min(radius * 0.36, chord * 0.88))
	local iconX, iconY = radial(iconDistance)
	parts[#parts + 1] = e(Icon, {
		key = "Glyph",
		glyph = props.glyph or "star",
		plain = true,
		--[[
			ITEM ART WHEN THERE IS ANY, which is what keeps four potions apart.

			Half the prize list is potions, and on the generic `potion` glyph they were four identical
			green flasks -- the wheel showed the same picture in four of its eight wedges. `Icon` prefers
			`image` over `glyph`, so a segment with a real `IconId` gets its own art and everything else
			falls through unchanged.

			TINTING WAS THE WRONG LEVER AND WAS TRIED FIRST. `glyphAccent` only reaches PROCEDURAL glyphs,
			so it did nothing for the image-backed potions -- and `Glyphs.Coin` paints its rim AND its "$"
			from the accent, so a Gold cash segment came out as a blank pale disc.
		]]
		image = props.image,
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
	--[[
		THE WINNING WEDGE, once the wheel has stopped. A pulsing white wash over the wedge's own bars --
		on an overlay for the same reason the shine is: the fill is a dozen separate frames and tinting
		each of them would be a dozen tweens.
	]]
	if props.flash then
		local flashParts = {}
		for index = 0, sliceCount - 1 do
			local flashMid = from + sliceSpan * (index + 0.5)
			local flashRadians = math.rad(flashMid)
			flashParts[#flashParts + 1] = e("Frame", {
				key = `Flash{index}`,
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = props.flashTransparency or 0.6,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(math.ceil(barWidth), radius),
				Position = UDim2.new(
					0.5,
					math.sin(flashRadians) * radius / 2,
					0.5,
					-math.cos(flashRadians) * radius / 2
				),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = flashMid,
				ZIndex = 4,
			})
		end
		parts[#parts + 1] = e(P.Group, {
			key = "Flash",
			size = UDim2.fromScale(1, 1),
			zIndex = 4,
			children = flashParts,
		})
	end

	if props.best then
		parts[#parts + 1] = e(P.Group, {
			key = "Shine",
			--- Sized to the icon, not the wedge: at `radius * 0.7` the sparkles landed in the next slice.
			size = UDim2.fromOffset(iconExtent * 1.15, iconExtent * 1.15),
			position = UDim2.new(0.5, iconX, 0.5, iconY),
			anchorPoint = Vector2.new(0.5, 0.5),
			zIndex = 5,
			children = {
				--[[
					SPARKLES ONLY. `glow` draws a soft radial blob, and on a wedge -- which is a shape it
					cannot follow -- it read as an orange smear laid across the neighbouring slice rather
					than as light on the prize.
				]]
				e(Shine.Layer, {
					key = "Layer",
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
		TWO ANIMATIONS, BOTH OFF ONE CHEAP HOOK.

		`useSpin` climbs an angle forever while enabled, so feeding it through sin gives an endless loop
		without a spring that settles. The pointer uses it to bounce while the wheel turns -- a pointer
		that sits dead still through a spin is the single biggest tell that a wheel is a picture of a
		wheel -- and the winning wedge uses a slower one to pulse once it has stopped.

		`math.abs` on the pointer, so it only ever kicks one way: outward, as if a peg were shoving it.
	]]
	local tick = Motion.useSpin(1440, props.spinning == true)
	local pulse = Motion.useSpin(150, props.winner ~= nil)
	local pointerLift = tick:map(function(angle: number)
		return -math.abs(math.sin(math.rad(angle))) * 7
	end)
	local flashTransparency = pulse:map(function(angle: number)
		return 0.55 + math.sin(math.rad(angle)) * 0.25
	end)

	--[[
		Bolt studs, laid out by angle like the wedges but on the OUTER frame, so they do not turn with
		the wheel.
	]]
	--- Scaled off the rim: a fixed 9px bolt vanishes on a 560px wheel and crowds a 240px one.
	local boltExtent = math.max(8, math.floor(rimWidth * 0.42))

	local bolts = {}
	for index = 1, BOLT_COUNT do
		local angle = math.rad((index - 1) * (360 / BOLT_COUNT) + 15)
		local boltRadius = radius + rimWidth * 0.1
		bolts[#bolts + 1] = e("Frame", {
			key = `Bolt{index}`,
			BackgroundColor3 = RIM_SHADOW,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(boltExtent, boltExtent),
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
			--- Lit on top, dark underneath: a flat disc reads as a dot, a shaded one as a dome.
			e("UIGradient", {
				key = "Dome",
				Color = ColorSequence.new(RIM_LIGHT, RIM_SHADOW),
				Rotation = 90,
			}),
		})
	end

	--[[
		WEDGE SEPARATORS. One thin dark bar on each boundary, laid over the fill.

		Adjacent wedges are different colours, so in principle a seam is visible without help -- but two
		similar accents (Green next to Cyan) blur into one shape, and the eye needs the wheel's divisions
		to be countable. Drawn inside the turntable so they turn with the wedges they divide.
	]]
	local separators = {}
	for index = 1, count do
		local angle = math.rad((index - 1) * step)
		separators[#separators + 1] = e("Frame", {
			key = `Seam{index}`,
			BackgroundColor3 = Theme.Color.Outline,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(math.max(4, math.floor(extent * 0.012)), radius),
			Position = UDim2.new(
				0.5,
				math.sin(angle) * radius / 2,
				0.5,
				-math.cos(angle) * radius / 2
			),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = math.deg(angle),
			ZIndex = 5,
		})
	end

	--[[
		Chances, from the segments' own `Weight` values -- the same numbers `SpinService` sums to pick a
		winner. Computed here rather than authored anywhere, so a weight change in config moves the
		printed odds with it and the wheel cannot advertise a rate the server does not roll.
	]]
	local totalWeight = 0
	for _, segment in ipairs(segments) do
		totalWeight += segment.Weight or 0
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
			--- Two decimals at the rare end: a 1-in-100 jackpot printed as "0%" reads as impossible.
			chance = if totalWeight > 0 and segment.Weight
				then (if segment.Weight / totalWeight * 100 < 1
					then string.format("%.2f%%", segment.Weight / totalWeight * 100)
					else string.format("%.0f%%", segment.Weight / totalWeight * 100))
				else nil,
			glyph = segment.Glyph,
			image = RewardToast.imageFor(segment),
			best = segment.Best == true,
			shade = index % 2 == 0,
			--- Only after it has stopped: a flash chasing the pointer mid-spin would just look like strobing.
			flash = props.winner == index,
			flashTransparency = flashTransparency,
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
			--[[
				THE RIM, IN THREE RINGS -- which is where the depth comes from.

				One flat stroke reads as a drawn circle; three concentric rings of different tone read as a
				bevelled physical edge. Outer is the dark lip, middle is the lit face, inner is the shadow
				where the rim meets the wedges. Cheap: three background-transparent frames with strokes.
			]]
			e("Frame", {
				key = "RimLip",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(extent + rimWidth * 1.8, extent + rimWidth * 1.8),
				Position = UDim2.new(0.5, 0, 0, POINTER_LANE + extent / 2),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 6,
			}, {
				e("UICorner", { key = "Round", CornerRadius = UDim.new(0.5, 0) }),
				e("UIStroke", {
					key = "Ring",
					Thickness = math.max(6, rimWidth * 0.42),
					Color = RIM_SHADOW,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
			}),
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
				--[[
					A vertical light-to-dark ramp across the stroke, which is what turns a flat band into a
					lit surface. `UIGradient` applies to the stroke as well as the fill, and the fill here is
					transparent, so this only shades the ring.
				]]
				e("UIGradient", {
					key = "Bevel",
					Color = ColorSequence.new(RIM_LIGHT, RIM_SHADOW),
					Rotation = 90,
				}),
			}),
			--- Inner shadow ring: the rim casting onto the wedges, which seats the wheel inside its frame.
			e("Frame", {
				key = "RimInner",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(extent - 4, extent - 4),
				Position = UDim2.new(0.5, 0, 0, POINTER_LANE + extent / 2),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 8,
			}, {
				e("UICorner", { key = "Round", CornerRadius = UDim.new(0.5, 0) }),
				e("UIStroke", {
					key = "Ring",
					Thickness = 5,
					Color = RIM_SHADOW,
					Transparency = 0.35,
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
			--[[
				THE HUB IS DARK, and that is the point of it.

				It was gold on orange, which is the same family as the rim and the jackpot wedge -- three
				bright warm things fighting in one image, with the busiest of them dead centre. A dark cap
				with a gold ring reads as the hardware the wheel turns on, and gives the middle of the
				composition somewhere to rest. The glowing star is the only warm thing left inside it.

				Outside the turntable, so the star stays upright while the wheel spins.
			]]
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
						key = "HubCap",
						size = UDim2.fromOffset(hub - 14, hub - 14),
						position = UDim2.fromScale(0.5, 0.5),
						anchorPoint = Vector2.new(0.5, 0.5),
						gradient = Theme.Gradient.PanelDeep,
						radius = (hub - 14) / 2,
						strokeThickness = 3,
						strokeColor = RIM_SHADOW,
						studs = false,
						children = {
							--- Glow under the glyph, not on it: the art already carries its own outline.
							e(Shine.Layer, {
								key = "Glow",
								glow = true,
								color = Theme.Color.Gold,
								zIndex = 2,
							}),
							e(Icon, {
								key = "Star",
								glyph = "star",
								plain = true,
								size = UDim2.fromOffset(hub - 40, hub - 40),
								position = UDim2.fromScale(0.5, 0.5),
								anchorPoint = Vector2.new(0.5, 0.5),
								zIndex = 3,
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
			--[[
				THE POINTER, as a chunky pin rather than a diamond.

				A rotated square shows all four of its corners, so on its own it reads as a diamond floating
				over the rim -- which is what it looked like. A pin needs a body with ONE point coming out of
				the bottom, and the way to get that from rectangles is to cover the tip's other three corners
				with the body.

				OUTLINED BY A DARK COPY BEHIND, not by strokes. Two overlapping stroked shapes show the seam
				where they meet; a slightly larger dark silhouette underneath gives one clean outline around
				the whole assembly, which is the same trick the kit's buttons use for their lip.
			]]
			e(P.Group, {
				key = "Pointer",
				size = UDim2.fromOffset(POINTER_BODY.X + 16, 74),
				position = UDim2.new(0.5, 0, 0, POINTER_LANE - 6),
				anchorPoint = Vector2.new(0.5, 0.5),
				zIndex = 11,
				children = {
					e(P.Group, {
						key = "Kick",
						size = UDim2.fromScale(1, 1),
						position = pointerLift:map(function(lift: number)
							return UDim2.new(0.5, 0, 0.5, lift)
						end),
						anchorPoint = Vector2.new(0.5, 0.5),
						children = {
							--- Silhouette: the same two shapes, fatter, in ink.
							e("Frame", {
								key = "TipInk",
								BackgroundColor3 = Theme.Color.Outline,
								BorderSizePixel = 0,
								Size = UDim2.fromOffset(POINTER_TIP + 8, POINTER_TIP + 8),
								Position = UDim2.fromScale(0.5, 0.66),
								AnchorPoint = Vector2.new(0.5, 0.5),
								Rotation = 45,
								ZIndex = 1,
							}, {
								e("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 5) }),
							}),
							e("Frame", {
								key = "BodyInk",
								BackgroundColor3 = Theme.Color.Outline,
								BorderSizePixel = 0,
								Size = UDim2.fromOffset(POINTER_BODY.X + 8, POINTER_BODY.Y + 8),
								Position = UDim2.fromScale(0.5, 0.3),
								AnchorPoint = Vector2.new(0.5, 0.5),
								ZIndex = 2,
							}, {
								e("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 10) }),
							}),
							e("Frame", {
								key = "Tip",
								BackgroundColor3 = POINTER_COLOR,
								BorderSizePixel = 0,
								Size = UDim2.fromOffset(POINTER_TIP, POINTER_TIP),
								Position = UDim2.fromScale(0.5, 0.66),
								AnchorPoint = Vector2.new(0.5, 0.5),
								Rotation = 45,
								ZIndex = 3,
							}, {
								e("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 3) }),
								e("UIGradient", {
									key = "Bevel",
									Color = POINTER_RAMP,
									Rotation = 45,
								}),
							}),
							e("Frame", {
								key = "Body",
								BackgroundColor3 = POINTER_COLOR,
								BorderSizePixel = 0,
								Size = UDim2.fromOffset(POINTER_BODY.X, POINTER_BODY.Y),
								Position = UDim2.fromScale(0.5, 0.3),
								AnchorPoint = Vector2.new(0.5, 0.5),
								ZIndex = 4,
							}, {
								e("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 8) }),
								e(
									"UIGradient",
									{ key = "Bevel", Color = POINTER_RAMP, Rotation = 90 }
								),
								--- A bright cap on the body, the same gloss every raised surface here carries.
								e(
									P.Gloss,
									{ key = "Gloss", radius = 8, strength = 0.75, height = 0.5 }
								),
							}),
						},
					}),
				},
			}),
		},
	})
end

return Wheel
