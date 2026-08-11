--[[
	Glyphs.luau
	Icon artwork built entirely from Frames.

	Every glyph is scale-based and resolution independent, so the same component
	works at 18px in a chip and at 120px in a details panel. Corner radii use the
	scale component of UDim, which Roblox resolves against the shorter edge --
	that is what keeps the pill ends and circles perfectly round at any size.

	These are production-usable placeholders: swap any of them for real art by
	passing `image` to Icon, and the rest of the layout stays identical.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)

local e = React.createElement

local CENTER = Vector2.new(0.5, 0.5)

--- A rounded bar. `rounding` is the UDim scale component: 0.5 = pill.
local function bar(
	key: string,
	x: number,
	y: number,
	w: number,
	h: number,
	opts: {
		color: Color3,
		rotation: number?,
		rounding: number?,
		zIndex: number?,
		transparency: number?,
	}
)
	return e("Frame", {
		key = key,
		BackgroundColor3 = opts.color,
		BackgroundTransparency = opts.transparency,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(w, h),
		Position = UDim2.fromScale(x, y),
		AnchorPoint = CENTER,
		Rotation = opts.rotation,
		ZIndex = opts.zIndex,
	}, {
		e("UICorner", {
			key = "Corner",
			CornerRadius = UDim.new(opts.rounding or 0.5, 0),
		}),
	})
end

local function disc(key: string, x: number, y: number, size: number, color: Color3, zIndex: number?)
	return bar(key, x, y, size, size, { color = color, rounding = 0.5, zIndex = zIndex })
end

local Glyphs = {}

--------------------------------------------------------------------------------
-- Marks: check, cross, plus, minus, arrow, sparkle
--------------------------------------------------------------------------------

function Glyphs.Check(props)
	local color = props.color or Theme.Color.White
	return e("Frame", { key = "Check", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		bar("Short", 0.3, 0.58, 0.2, 0.5, { color = color, rotation = -48 }),
		bar("Long", 0.58, 0.42, 0.2, 0.92, { color = color, rotation = 36 }),
	})
end

function Glyphs.Cross(props)
	local color = props.color or Theme.Color.White
	return e("Frame", { key = "Cross", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		bar("StrokeA", 0.5, 0.5, 0.2, 0.95, { color = color, rotation = 45 }),
		bar("StrokeB", 0.5, 0.5, 0.2, 0.95, { color = color, rotation = -45 }),
	})
end

function Glyphs.Plus(props)
	local color = props.color or Theme.Color.White
	return e("Frame", { key = "Plus", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		bar("Vertical", 0.5, 0.5, 0.26, 0.9, { color = color, rounding = 0.3 }),
		bar("Horizontal", 0.5, 0.5, 0.9, 0.26, { color = color, rounding = 0.3 }),
	})
end

function Glyphs.Minus(props)
	local color = props.color or Theme.Color.White
	return e("Frame", { key = "Minus", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		bar("Horizontal", 0.5, 0.5, 0.9, 0.26, { color = color, rounding = 0.3 }),
	})
end

function Glyphs.ArrowRight(props)
	local color = props.color or Theme.Color.White
	return e(
		"Frame",
		{ key = "ArrowRight", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
		{
			bar("Shaft", 0.44, 0.5, 0.78, 0.2, { color = color }),
			bar("HeadTop", 0.72, 0.35, 0.19, 0.44, { color = color, rotation = -52 }),
			bar("HeadBottom", 0.72, 0.65, 0.19, 0.44, { color = color, rotation = 52 }),
		}
	)
end

function Glyphs.ChevronRight(props)
	local color = props.color or Theme.Color.White
	return e(
		"Frame",
		{ key = "ChevronRight", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
		{
			bar("Top", 0.5, 0.31, 0.2, 0.56, { color = color, rotation = -40 }),
			bar("Bottom", 0.5, 0.69, 0.2, 0.56, { color = color, rotation = 40 }),
		}
	)
end

--- Eight-point sparkle. Reads as a star at small sizes and stays crisp.
function Glyphs.Star(props)
	local color = props.color or Theme.Color.Gold
	return e("Frame", { key = "Star", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		bar("PointV", 0.5, 0.5, 0.22, 1, { color = color, rounding = 0.5 }),
		bar("PointH", 0.5, 0.5, 1, 0.22, { color = color, rounding = 0.5 }),
		bar("PointA", 0.5, 0.5, 0.16, 0.8, { color = color, rounding = 0.5, rotation = 45 }),
		bar("PointB", 0.5, 0.5, 0.8, 0.16, { color = color, rounding = 0.5, rotation = 45 }),
	})
end

--------------------------------------------------------------------------------
-- Game objects
--------------------------------------------------------------------------------

--- Horseshoe magnet: red arch with two pale tips.
function Glyphs.Magnet(props)
	local body = props.color or Color3.fromHex("FF4A4A")
	local tip = props.accent or Color3.fromHex("DCE4EE")
	return e(
		"Frame",
		{ key = "Magnet", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
		{
			bar("Arch", 0.5, 0.28, 0.96, 0.5, { color = body, rounding = 0.42 }),
			bar("ArmLeft", 0.21, 0.55, 0.34, 0.5, { color = body, rounding = 0.12 }),
			bar("ArmRight", 0.79, 0.55, 0.34, 0.5, { color = body, rounding = 0.12 }),
			bar("TipLeft", 0.21, 0.86, 0.34, 0.24, { color = tip, rounding = 0.2 }),
			bar("TipRight", 0.79, 0.86, 0.34, 0.24, { color = tip, rounding = 0.2 }),
		}
	)
end

--- Gold coin with a dollar mark.
function Glyphs.Coin(props)
	local color = props.color or Theme.Color.Gold
	local accent = props.accent or Color3.fromHex("C98A00")
	return e("Frame", { key = "Coin", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		disc("Rim", 0.5, 0.5, 1, accent),
		disc("Face", 0.5, 0.47, 0.86, color, 2),
		e("TextLabel", {
			key = "Mark",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.86, 0.86),
			Position = UDim2.fromScale(0.5, 0.47),
			AnchorPoint = CENTER,
			Text = "$",
			FontFace = Theme.Font.Display,
			TextColor3 = accent,
			TextScaled = true,
			ZIndex = 3,
		}),
	})
end

--- Prestige gear.
function Glyphs.Gear(props)
	local color = props.color or Theme.Color.Gold
	local accent = props.accent or Color3.fromHex("B87A00")
	return e("Frame", { key = "Gear", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		bar("TeethA", 0.5, 0.5, 1, 0.42, { color = accent, rounding = 0.22 }),
		bar("TeethB", 0.5, 0.5, 1, 0.42, { color = accent, rounding = 0.22, rotation = 60 }),
		bar("TeethC", 0.5, 0.5, 1, 0.42, { color = accent, rounding = 0.22, rotation = 120 }),
		disc("Body", 0.5, 0.5, 0.76, color, 2),
		disc("Hub", 0.5, 0.5, 0.3, accent, 3),
	})
end

--- Potion flask. `accent` tints the liquid.
function Glyphs.Potion(props)
	local glass = props.color or Color3.fromHex("D7E4F2")
	local liquid = props.accent or Theme.Color.Green
	return e(
		"Frame",
		{ key = "Potion", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
		{
			bar(
				"Cork",
				0.5,
				0.08,
				0.34,
				0.16,
				{ color = Color3.fromHex("A9743E"), rounding = 0.28 }
			),
			bar("Neck", 0.5, 0.24, 0.24, 0.24, { color = glass, rounding = 0.15 }),
			disc("Body", 0.5, 0.66, 0.86, glass, 2),
			disc("Liquid", 0.5, 0.72, 0.66, liquid, 3),
			bar(
				"Shine",
				0.3,
				0.6,
				0.1,
				0.24,
				{ color = Theme.Color.White, rounding = 0.5, zIndex = 4, transparency = 0.45 }
			),
		}
	)
end

--- Padlock, used for every locked state in the kit.
function Glyphs.Lock(props)
	local body = props.color or Theme.Color.Gold
	local shackle = props.accent or Color3.fromHex("C0C9D6")
	return e("Frame", { key = "Lock", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		bar("ShackleTop", 0.5, 0.2, 0.52, 0.16, { color = shackle, rounding = 0.5 }),
		bar("ShackleLeft", 0.27, 0.33, 0.15, 0.34, { color = shackle, rounding = 0.4 }),
		bar("ShackleRight", 0.73, 0.33, 0.15, 0.34, { color = shackle, rounding = 0.4 }),
		bar("Body", 0.5, 0.7, 0.92, 0.56, { color = body, rounding = 0.22, zIndex = 2 }),
		disc("Keyhole", 0.5, 0.66, 0.2, Color3.fromHex("8A5B00"), 3),
		bar(
			"KeySlot",
			0.5,
			0.78,
			0.1,
			0.18,
			{ color = Color3.fromHex("8A5B00"), rounding = 0.4, zIndex = 3 }
		),
	})
end

--- Shopping basket for the shop button.
function Glyphs.Basket(props)
	local body = props.color or Theme.Color.Pink
	local accent = props.accent or Color3.fromHex("9E0F55")
	return e(
		"Frame",
		{ key = "Basket", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
		{
			bar("HandleTop", 0.5, 0.14, 0.44, 0.12, { color = accent, rounding = 0.5 }),
			bar("HandleLeft", 0.29, 0.26, 0.12, 0.3, { color = accent, rounding = 0.5 }),
			bar("HandleRight", 0.71, 0.26, 0.12, 0.3, { color = accent, rounding = 0.5 }),
			bar("Rim", 0.5, 0.44, 1, 0.16, { color = accent, rounding = 0.4, zIndex = 3 }),
			bar("Body", 0.5, 0.7, 0.86, 0.52, { color = body, rounding = 0.24, zIndex = 2 }),
			bar(
				"SlatLeft",
				0.34,
				0.72,
				0.08,
				0.34,
				{ color = accent, rounding = 0.5, zIndex = 4, transparency = 0.35 }
			),
			bar(
				"SlatRight",
				0.66,
				0.72,
				0.08,
				0.34,
				{ color = accent, rounding = 0.5, zIndex = 4, transparency = 0.35 }
			),
		}
	)
end

--- Lightning bolt for speed and boosts.
function Glyphs.Bolt(props)
	local color = props.color or Theme.Color.Yellow
	return e("Frame", { key = "Bolt", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		bar("Upper", 0.57, 0.29, 0.3, 0.6, { color = color, rounding = 0.15, rotation = 24 }),
		bar("Lower", 0.43, 0.71, 0.3, 0.6, { color = color, rounding = 0.15, rotation = 24 }),
		bar("Middle", 0.5, 0.5, 0.52, 0.2, { color = color, rounding = 0.2, rotation = -22 }),
	})
end

--- Clock for collection speed and timers.
function Glyphs.Clock(props)
	local face = props.color or Color3.fromHex("E4ECF6")
	local accent = props.accent or Theme.Color.PanelDark
	return e("Frame", { key = "Clock", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		disc("Rim", 0.5, 0.5, 1, accent),
		disc("Face", 0.5, 0.5, 0.82, face, 2),
		bar("HandHour", 0.5, 0.39, 0.11, 0.34, { color = accent, rounding = 0.4, zIndex = 3 }),
		bar("HandMinute", 0.61, 0.5, 0.32, 0.1, { color = accent, rounding = 0.4, zIndex = 3 }),
		disc("Pin", 0.5, 0.5, 0.14, accent, 4),
	})
end

--- Crate for storage upgrades.
function Glyphs.Crate(props)
	local body = props.color or Color3.fromHex("D08A3C")
	local accent = props.accent or Color3.fromHex("9A5E1E")
	return e("Frame", { key = "Crate", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		bar("Body", 0.5, 0.56, 1, 0.86, { color = body, rounding = 0.12 }),
		bar("Lid", 0.5, 0.16, 1, 0.24, { color = accent, rounding = 0.16, zIndex = 2 }),
		bar("BraceLeft", 0.22, 0.6, 0.14, 0.7, { color = accent, rounding = 0.3, zIndex = 2 }),
		bar("BraceRight", 0.78, 0.6, 0.14, 0.7, { color = accent, rounding = 0.3, zIndex = 2 }),
		bar("Band", 0.5, 0.62, 1, 0.13, { color = accent, rounding = 0.4, zIndex = 3 }),
	})
end

--- Circular arrow: prestige, rebirth and respawn rate.
function Glyphs.Recycle(props)
	local color = props.color or Theme.Color.Green
	local hole = props.accent or Theme.Color.PanelDark
	return e(
		"Frame",
		{ key = "Recycle", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
		{
			disc("Ring", 0.5, 0.5, 1, color),
			disc("Hole", 0.5, 0.5, 0.5, hole, 2),
			bar(
				"Gap",
				0.82,
				0.24,
				0.4,
				0.4,
				{ color = hole, rounding = 0.1, zIndex = 3, rotation = 20 }
			),
			bar(
				"HeadTop",
				0.72,
				0.14,
				0.16,
				0.4,
				{ color = color, rounding = 0.2, zIndex = 4, rotation = -50 }
			),
			bar(
				"HeadBottom",
				0.86,
				0.3,
				0.16,
				0.4,
				{ color = color, rounding = 0.2, zIndex = 4, rotation = 40 }
			),
		}
	)
end

--- Paw print for pets.
function Glyphs.Paw(props)
	local color = props.color or Color3.fromHex("FFB86B")
	return e("Frame", { key = "Paw", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		bar("Pad", 0.5, 0.72, 0.66, 0.46, { color = color, rounding = 0.45 }),
		disc("ToeOuterLeft", 0.13, 0.42, 0.26, color),
		disc("ToeLeft", 0.36, 0.24, 0.28, color),
		disc("ToeRight", 0.64, 0.24, 0.28, color),
		disc("ToeOuterRight", 0.87, 0.42, 0.26, color),
	})
end

--- Angular junk metal for scrap.
function Glyphs.Scrap(props)
	local color = props.color or Color3.fromHex("9AA6B4")
	local accent = props.accent or Color3.fromHex("6B7683")
	return e("Frame", { key = "Scrap", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		bar(
			"PlateBack",
			0.62,
			0.38,
			0.62,
			0.44,
			{ color = accent, rounding = 0.12, rotation = -18 }
		),
		bar(
			"PlateFront",
			0.4,
			0.58,
			0.7,
			0.48,
			{ color = color, rounding = 0.12, rotation = 14, zIndex = 2 }
		),
		bar(
			"Rod",
			0.68,
			0.72,
			0.5,
			0.14,
			{ color = accent, rounding = 0.5, zIndex = 3, rotation = -24 }
		),
		disc("Bolt", 0.34, 0.56, 0.16, accent, 4),
	})
end

--- Map pin for areas.
function Glyphs.Pin(props)
	local color = props.color or Theme.Color.Red
	local accent = props.accent or Theme.Color.White
	return e("Frame", { key = "Pin", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		bar("Point", 0.5, 0.72, 0.44, 0.44, { color = color, rounding = 0.14, rotation = 45 }),
		disc("Head", 0.5, 0.42, 0.86, color, 2),
		disc("Hole", 0.5, 0.42, 0.34, accent, 3),
	})
end

--- House for teleport-home.
function Glyphs.Home(props)
	local roof = props.color or Theme.Color.Red
	local body = props.accent or Color3.fromHex("F0E4D0")
	return e("Frame", { key = "Home", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		bar("Roof", 0.5, 0.34, 0.72, 0.72, { color = roof, rounding = 0.12, rotation = 45 }),
		bar("Body", 0.5, 0.72, 0.72, 0.46, { color = body, rounding = 0.1, zIndex = 2 }),
		bar("Door", 0.5, 0.82, 0.24, 0.3, { color = roof, rounding = 0.2, zIndex = 3 }),
	})
end

--- Robux token, drawn as the rounded square with a tilted inner cut.
function Glyphs.Robux(props)
	local color = props.color or Theme.Color.White
	local hole = props.accent or Theme.Color.PanelDark
	return e("Frame", { key = "Robux", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		bar("Token", 0.5, 0.5, 0.94, 0.94, { color = color, rounding = 0.18 }),
		bar(
			"Cut",
			0.5,
			0.5,
			0.44,
			0.44,
			{ color = hole, rounding = 0.12, rotation = 45, zIndex = 2 }
		),
	})
end

--- Trophy for leaderboards.
function Glyphs.Trophy(props)
	local color = props.color or Theme.Color.Gold
	local accent = props.accent or Color3.fromHex("C98A00")
	return e(
		"Frame",
		{ key = "Trophy", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
		{
			bar("HandleLeft", 0.14, 0.34, 0.24, 0.36, { color = accent, rounding = 0.5 }),
			bar("HandleRight", 0.86, 0.34, 0.24, 0.36, { color = accent, rounding = 0.5 }),
			bar("Cup", 0.5, 0.34, 0.62, 0.6, { color = color, rounding = 0.3, zIndex = 2 }),
			bar("Stem", 0.5, 0.72, 0.2, 0.3, { color = accent, rounding = 0.2, zIndex = 2 }),
			bar("Base", 0.5, 0.9, 0.62, 0.16, { color = color, rounding = 0.3, zIndex = 3 }),
		}
	)
end

--[[
	Prize wheel, for the spin button.

	Four coloured quadrant discs behind a white hub, which is the same read as the colour-wheel icon
	in the reference: unmistakably a wheel at 40px without needing radial fill, which Roblox has no
	way to draw. The discs overlap slightly so there are no seams between them.

	Deliberately not four rotated wedges. A wedge needs rotation, and a rotated GuiObject ignores its
	ancestors' `ClipsDescendants` -- fine here, but four of them would be four chances to get it
	wrong for no gain over discs.
]]
function Glyphs.Wheel(props)
	local hub = props.color or Theme.Color.White
	return e("Frame", { key = "Wheel", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		disc("QuadTop", 0.5, 0.28, 0.56, Theme.Color.Red, 1),
		disc("QuadRight", 0.72, 0.5, 0.56, Theme.Color.Yellow, 1),
		disc("QuadBottom", 0.5, 0.72, 0.56, Theme.Color.Green, 1),
		disc("QuadLeft", 0.28, 0.5, 0.56, Theme.Color.Purple, 1),
		disc("Hub", 0.5, 0.5, 0.3, hub, 3),
	})
end

--[[
	Two figures, for the friend boost.

	Drawn back to front so the near one overlaps the far one, which is what makes it read as "two
	people" rather than "one wide person": a head and shoulders each, the rear pair smaller, dimmer
	and offset left. Deliberately no faces or limbs -- at 38px anything finer turns to mush.
]]
function Glyphs.Friends(props)
	local color = props.color or Theme.Color.White
	local behind = color:Lerp(Theme.Color.Ink, 0.35)
	return e(
		"Frame",
		{ key = "Friends", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
		{
			disc("HeadBack", 0.32, 0.34, 0.3, behind, 1),
			bar(
				"BodyBack",
				0.32,
				0.76,
				0.46,
				0.36,
				{ color = behind, rounding = 0.45, zIndex = 1 }
			),
			disc("HeadFront", 0.64, 0.31, 0.36, color, 2),
			bar("BodyFront", 0.64, 0.78, 0.54, 0.4, { color = color, rounding = 0.45, zIndex = 2 }),
		}
	)
end

--- Music note for the audio settings section.
function Glyphs.Note(props)
	local color = props.color or Theme.Color.Cyan
	return e("Frame", { key = "Note", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		disc("Head", 0.34, 0.76, 0.42, color),
		bar("Stem", 0.56, 0.46, 0.12, 0.72, { color = color, rounding = 0.3 }),
		bar("Flag", 0.72, 0.16, 0.36, 0.16, { color = color, rounding = 0.4, rotation = 18 }),
	})
end

--- Sliders icon for the UI settings section.
function Glyphs.Sliders(props)
	local color = props.color or Theme.Color.White
	local accent = props.accent or Theme.Color.Blue
	return e(
		"Frame",
		{ key = "Sliders", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
		{
			bar(
				"TrackTop",
				0.5,
				0.28,
				0.94,
				0.16,
				{ color = color, rounding = 0.5, transparency = 0.4 }
			),
			bar(
				"TrackBottom",
				0.5,
				0.72,
				0.94,
				0.16,
				{ color = color, rounding = 0.5, transparency = 0.4 }
			),
			disc("KnobTop", 0.7, 0.28, 0.36, accent, 2),
			disc("KnobBottom", 0.34, 0.72, 0.36, accent, 2),
		}
	)
end

--- Ground tile for plot customisation.
function Glyphs.Ground(props)
	local color = props.color or Color3.fromHex("7A5B3A")
	local accent = props.accent or Color3.fromHex("5A4028")
	return e(
		"Frame",
		{ key = "Ground", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
		{
			bar("Tile", 0.5, 0.62, 1, 0.62, { color = color, rounding = 0.14 }),
			bar("Seam", 0.5, 0.62, 1, 0.1, { color = accent, rounding = 0.4, zIndex = 2 }),
			disc("PebbleLeft", 0.28, 0.4, 0.2, accent, 3),
			disc("PebbleRight", 0.7, 0.34, 0.16, accent, 3),
		}
	)
end

--- Fence for plot customisation.
function Glyphs.Fence(props)
	local color = props.color or Color3.fromHex("C08A52")
	local accent = props.accent or Color3.fromHex("8A5E30")
	return e("Frame", { key = "Fence", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		bar("PostLeft", 0.18, 0.52, 0.18, 0.9, { color = color, rounding = 0.2 }),
		bar("PostMiddle", 0.5, 0.46, 0.18, 1, { color = color, rounding = 0.2 }),
		bar("PostRight", 0.82, 0.52, 0.18, 0.9, { color = color, rounding = 0.2 }),
		bar("RailTop", 0.5, 0.36, 1, 0.14, { color = accent, rounding = 0.4, zIndex = 2 }),
		bar("RailBottom", 0.5, 0.72, 1, 0.14, { color = accent, rounding = 0.4, zIndex = 2 }),
	})
end

--- Yard sign for plot customisation.
function Glyphs.Sign(props)
	local color = props.color or Theme.Color.Blue
	local accent = props.accent or Color3.fromHex("8A5E30")
	return e("Frame", { key = "Sign", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		bar("Post", 0.5, 0.78, 0.14, 0.44, { color = accent, rounding = 0.2 }),
		bar("Board", 0.5, 0.36, 1, 0.56, { color = color, rounding = 0.16, zIndex = 2 }),
		bar(
			"LineTop",
			0.5,
			0.28,
			0.66,
			0.08,
			{ color = Theme.Color.White, rounding = 0.5, zIndex = 3 }
		),
		bar(
			"LineBottom",
			0.5,
			0.46,
			0.46,
			0.08,
			{ color = Theme.Color.White, rounding = 0.5, zIndex = 3 }
		),
	})
end

--- Paint palette for themes.
function Glyphs.Palette(props)
	local color = props.color or Color3.fromHex("EFE3D2")
	return e(
		"Frame",
		{ key = "Palette", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
		{
			disc("Board", 0.5, 0.5, 1, color),
			disc("Thumb", 0.68, 0.7, 0.28, Theme.Color.PanelDark, 2),
			disc("PaintRed", 0.3, 0.3, 0.22, Theme.Color.Red, 3),
			disc("PaintBlue", 0.62, 0.26, 0.22, Theme.Color.Blue, 3),
			disc("PaintGreen", 0.26, 0.62, 0.22, Theme.Color.Green, 3),
		}
	)
end

--- Calendar for daily rewards.
function Glyphs.Calendar(props)
	local color = props.color or Color3.fromHex("F2F6FB")
	local accent = props.accent or Theme.Color.Red
	return e(
		"Frame",
		{ key = "Calendar", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
		{
			bar("Page", 0.5, 0.56, 1, 0.84, { color = color, rounding = 0.14 }),
			bar("Header", 0.5, 0.24, 1, 0.28, { color = accent, rounding = 0.16, zIndex = 2 }),
			bar(
				"RingLeft",
				0.3,
				0.1,
				0.12,
				0.24,
				{ color = Theme.Color.GrayDark, rounding = 0.5, zIndex = 3 }
			),
			bar(
				"RingRight",
				0.7,
				0.1,
				0.12,
				0.24,
				{ color = Theme.Color.GrayDark, rounding = 0.5, zIndex = 3 }
			),
			disc("Dot", 0.5, 0.68, 0.26, accent, 3),
		}
	)
end

--- Open book for the collection index.
function Glyphs.Book(props)
	local color = props.color or Color3.fromHex("F2F6FB")
	local accent = props.accent or Theme.Color.Purple
	return e("Frame", { key = "Book", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		bar("Cover", 0.5, 0.5, 1, 0.86, { color = accent, rounding = 0.14 }),
		bar("PageLeft", 0.29, 0.52, 0.4, 0.66, { color = color, rounding = 0.1, zIndex = 2 }),
		bar("PageRight", 0.71, 0.52, 0.4, 0.66, { color = color, rounding = 0.1, zIndex = 2 }),
		bar("Spine", 0.5, 0.52, 0.1, 0.74, { color = accent, rounding = 0.3, zIndex = 3 }),
	})
end

--- Upward arrow for upgrades.
function Glyphs.Upgrade(props)
	local color = props.color or Theme.Color.Green
	return e(
		"Frame",
		{ key = "Upgrade", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
		{
			bar("Shaft", 0.5, 0.58, 0.26, 0.6, { color = color, rounding = 0.2 }),
			bar(
				"HeadLeft",
				0.33,
				0.28,
				0.2,
				0.44,
				{ color = color, rounding = 0.2, rotation = -50 }
			),
			bar(
				"HeadRight",
				0.67,
				0.28,
				0.2,
				0.44,
				{ color = color, rounding = 0.2, rotation = 50 }
			),
			bar("Base", 0.5, 0.92, 0.7, 0.16, { color = color, rounding = 0.4 }),
		}
	)
end

--- Backpack for the inventory button.
function Glyphs.Bag(props)
	local color = props.color or Theme.Color.Cyan
	local accent = props.accent or Color3.fromHex("0F6E96")
	return e("Frame", { key = "Bag", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		bar("HandleTop", 0.5, 0.18, 0.42, 0.14, { color = accent, rounding = 0.5 }),
		bar("HandleLeft", 0.3, 0.28, 0.13, 0.26, { color = accent, rounding = 0.5 }),
		bar("HandleRight", 0.7, 0.28, 0.13, 0.26, { color = accent, rounding = 0.5 }),
		bar("Body", 0.5, 0.68, 1, 0.62, { color = color, rounding = 0.2, zIndex = 2 }),
		bar("Pocket", 0.5, 0.8, 0.56, 0.3, { color = accent, rounding = 0.24, zIndex = 3 }),
	})
end

--- Simple ranking medal used in leaderboard rows.
function Glyphs.Medal(props)
	local color = props.color or Theme.Color.Gold
	local accent = props.accent or Color3.fromHex("C98A00")
	return e("Frame", { key = "Medal", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		bar(
			"RibbonLeft",
			0.34,
			0.22,
			0.2,
			0.44,
			{ color = accent, rounding = 0.15, rotation = 12 }
		),
		bar(
			"RibbonRight",
			0.66,
			0.22,
			0.2,
			0.44,
			{ color = accent, rounding = 0.15, rotation = -12 }
		),
		disc("Disc", 0.5, 0.66, 0.72, color, 2),
		disc("Inner", 0.5, 0.66, 0.42, accent, 3),
	})
end

--------------------------------------------------------------------------------
-- Registry
--------------------------------------------------------------------------------

Glyphs.byName = {
	check = Glyphs.Check,
	cross = Glyphs.Cross,
	plus = Glyphs.Plus,
	minus = Glyphs.Minus,
	arrow = Glyphs.ArrowRight,
	chevron = Glyphs.ChevronRight,
	star = Glyphs.Star,

	magnet = Glyphs.Magnet,
	coin = Glyphs.Coin,
	cash = Glyphs.Coin,
	gear = Glyphs.Gear,
	gears = Glyphs.Gear,
	potion = Glyphs.Potion,
	lock = Glyphs.Lock,
	basket = Glyphs.Basket,
	bolt = Glyphs.Bolt,
	clock = Glyphs.Clock,
	crate = Glyphs.Crate,
	storage = Glyphs.Crate,
	recycle = Glyphs.Recycle,
	prestige = Glyphs.Recycle,
	wheel = Glyphs.Wheel,
	spin = Glyphs.Wheel,
	friends = Glyphs.Friends,
	friend = Glyphs.Friends,
	paw = Glyphs.Paw,
	pet = Glyphs.Paw,
	scrap = Glyphs.Scrap,
	pin = Glyphs.Pin,
	area = Glyphs.Pin,
	home = Glyphs.Home,
	robux = Glyphs.Robux,
	trophy = Glyphs.Trophy,
	note = Glyphs.Note,
	sliders = Glyphs.Sliders,
	admin = Glyphs.Sliders,
	ground = Glyphs.Ground,
	fence = Glyphs.Fence,
	sign = Glyphs.Sign,
	palette = Glyphs.Palette,
	calendar = Glyphs.Calendar,
	book = Glyphs.Book,
	upgrade = Glyphs.Upgrade,
	bag = Glyphs.Bag,
	inventory = Glyphs.Bag,
	medal = Glyphs.Medal,
}

function Glyphs.get(name: string?)
	if not name then
		return nil
	end
	return Glyphs.byName[string.lower(name)]
end

return Glyphs
