--!strict
--[[
	Theme.luau
	SCRAPYARD design tokens.

	One source of truth for colour, gradient, typography, radius, stroke and
	spacing. Every component reads from here, so a palette change propagates
	through the whole UI.

	Style rules encoded here:
		- chunky toy-like panels, square-ish with a small corner radius
		- thick dark outlines on every major surface
		- bold white text with a heavy dark outline
		- simple two-stop gradients only (top -> bottom)
		- dark navy stud-textured panels
]]

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

local Theme = {}

--------------------------------------------------------------------------------
-- Reference canvases. Everything is authored in these pixel spaces and scaled
-- at runtime with a single UIScale, which is what the Figma -> Roblox pipeline
-- expects.
--------------------------------------------------------------------------------

Theme.Reference = Vector2.new(1920, 1080)
Theme.ReferenceMobile = Vector2.new(390, 844)

-- Canvas sizes the preview Stage offers.
--[[
	Preview canvases for `Stage`. All landscape: the experience is locked to it,
	so a portrait canvas would preview a layout that cannot ship.
]]
Theme.Devices = {
	desktop = Vector2.new(1920, 1080),
	tablet = Vector2.new(1375, 1032), -- iPad Pro, landscape
	mobile = Vector2.new(750, 361), -- iPhone, landscape
}

--------------------------------------------------------------------------------
-- Core palette
--------------------------------------------------------------------------------

Theme.Color = {
	--[[
		`White` and `Ink` are literal colours and never change. `Text`,
		`TextMuted` and `TextOutline` are the semantic ones a label should use:
		they flip with the palette, which is what makes a light theme possible
		without every component knowing which theme it is in.
	]]
	White = hex("FFFFFF"),
	Gray = hex("C2CEDF"),
	GrayDark = hex("8C9BB2"),
	Ink = hex("10131A"),

	Text = hex("FFFFFF"),
	TextMuted = hex("C2CEDF"),
	TextOutline = hex("10131A"),

	-- Surfaces. Lighter and friendlier than a true dark theme: this is a
	-- cartoony game for kids, so the navy is a bright toy navy, not charcoal.
	-- Ordering, darkest to lightest: Slot < PanelDark < Panel < Card < PanelLight.
	Outline = hex("10131A"),
	Panel = hex("2C4A78"), -- main window body (studded)
	PanelDark = hex("1F3760"), -- recessed strips, headers behind content
	PanelLight = hex("3F66A0"),
	PanelRaised = hex("4E7BBA"),
	Stud = hex("6C9BD8"), -- stud dots, lighter than their panel
	Slot = hex("1A3058"), -- art wells

	-- Cards get a flat, solid face so they read as separate objects sitting on
	-- the studded window rather than blending into it.
	Card = hex("3E66A2"),
	CardBase = hex("22406E"), -- the solid lip beneath a card
	CardHover = hex("4B76B4"),

	-- accents
	Green = hex("72F000"),
	GreenDeep = hex("36C900"),
	Blue = hex("25B9FF"),
	BlueDeep = hex("167BE8"),
	Yellow = hex("FFE539"),
	YellowDeep = hex("FFB600"),
	Purple = hex("B530FF"),
	PurpleDeep = hex("711CE8"),
	Red = hex("FF5757"),
	RedDeep = hex("E62C37"),
	Cyan = hex("21E5F5"),
	CyanDeep = hex("159ED9"),
	Pink = hex("FF5CC8"),
	PinkDeep = hex("E6237F"),
	Orange = hex("FF9A2B"),

	-- semantic
	Positive = hex("69EF28"),
	Negative = hex("FF5757"),
	Gold = hex("FFD21C"),
	Cash = hex("69EF28"),
	Gears = hex("FFD21C"),
	Event = hex("21E5F5"),
	Locked = hex("5A6472"),
}

--------------------------------------------------------------------------------
-- Gradients. Always two stops, always vertical unless a component says
-- otherwise. Anything more complex will not survive the trip into Roblox.
--------------------------------------------------------------------------------

Theme.Gradient = {
	Green = ColorSequence.new(hex("72F000"), hex("36C900")),
	Blue = ColorSequence.new(hex("25B9FF"), hex("167BE8")),
	Yellow = ColorSequence.new(hex("FFE539"), hex("FFB600")),
	Purple = ColorSequence.new(hex("B530FF"), hex("711CE8")),
	Red = ColorSequence.new(hex("FF5757"), hex("E62C37")),
	Cyan = ColorSequence.new(hex("21E5F5"), hex("159ED9")),
	Pink = ColorSequence.new(hex("FF5CC8"), hex("E6237F")),
	Orange = ColorSequence.new(hex("FFB03A"), hex("FF7A00")),
	Gold = ColorSequence.new(hex("FFE97A"), hex("FFB300")),
	-- Lifted verbatim off the authored HUD's MoneyValue gradient so the cash
	-- readout keeps the exact look it had before the React migration.
	Money = ColorSequence.new(hex("E1FF00"), hex("00CE07")),
	Gray = ColorSequence.new(hex("8C9BB2"), hex("5F6E85")),
	Dead = ColorSequence.new(hex("62708A"), hex("4A576D")),

	Panel = ColorSequence.new(hex("35578C"), hex("264269")),
	PanelDeep = ColorSequence.new(hex("2A4874"), hex("1C3358")),
	Slot = ColorSequence.new(hex("223D68"), hex("162A4C")),
	-- Reads as glass rather than a painted slab: a wide light-to-dark sweep,
	-- meant to be paired with a little background transparency.
	Glass = ColorSequence.new(hex("5C89CC"), hex("101F38")),
	Card = ColorSequence.new(hex("4A72AF"), hex("375C93")),
}

--------------------------------------------------------------------------------
-- Button variants. `base` is the darker "lip" underneath the face, which is
-- what gives the buttons their chunky pressable look.
--------------------------------------------------------------------------------

export type ButtonVariant = {
	gradient: ColorSequence,
	base: Color3,
	text: Color3,
	stroke: Color3,
}

Theme.Button = {
	Primary = {
		gradient = Theme.Gradient.Green,
		base = hex("299B00"),
		text = Theme.Color.White,
		stroke = Theme.Color.Outline,
	},
	Secondary = {
		gradient = Theme.Gradient.Blue,
		base = hex("0F5FBE"),
		text = Theme.Color.White,
		stroke = Theme.Color.Outline,
	},
	Purchase = {
		gradient = Theme.Gradient.Yellow,
		base = hex("D98A00"),
		text = Theme.Color.White,
		stroke = Theme.Color.Outline,
	},
	Danger = {
		gradient = Theme.Gradient.Red,
		base = hex("B81C28"),
		text = Theme.Color.White,
		stroke = Theme.Color.Outline,
	},
	Premium = {
		gradient = Theme.Gradient.Purple,
		base = hex("5A14BE"),
		text = Theme.Color.White,
		stroke = Theme.Color.Outline,
	},
	Event = {
		gradient = Theme.Gradient.Cyan,
		base = hex("0E82B4"),
		text = Theme.Color.White,
		stroke = Theme.Color.Outline,
	},
	Shop = {
		gradient = Theme.Gradient.Pink,
		base = hex("B81368"),
		text = Theme.Color.White,
		stroke = Theme.Color.Outline,
	},
	Neutral = {
		gradient = Theme.Gradient.Gray,
		base = hex("42536B"),
		text = Theme.Color.White,
		stroke = Theme.Color.Outline,
	},
	Disabled = {
		gradient = Theme.Gradient.Dead,
		base = hex("3A4557"),
		text = hex("909AA7"),
		stroke = Theme.Color.Outline,
	},
} :: { [string]: ButtonVariant }

--------------------------------------------------------------------------------
-- Rarities. Scrap, magnets and skins share the eight-tier scale; pets use the
-- classic five-tier scale. Both live here so the whole game reads as one set.
--------------------------------------------------------------------------------

export type RarityStyle = {
	color: Color3,
	gradient: ColorSequence,
	label: string,
}

local function rarity(label: string, top: string, bottom: string): RarityStyle
	return {
		label = label,
		color = hex(top),
		gradient = ColorSequence.new(hex(top), hex(bottom)),
	}
end

Theme.Rarity = {
	-- scrap / magnets / skins
	Normal = rarity("Normal", "C3CAD4", "8A929E"),
	Gold = rarity("Gold", "FFE066", "FFB600"),
	Diamond = rarity("Diamond", "6FE8FF", "159ED9"),
	Emerald = rarity("Emerald", "8CFF52", "36C900"),
	Blood = rarity("Blood", "FF6E6E", "C41320"),
	Electric = rarity("Electric", "C86BFF", "711CE8"),
	Admin = rarity("Admin", "FF7ADA", "E6237F"),
	Radioactive = rarity("Radioactive", "DBFF3D", "8FC400"),

	-- pets: the six in PetConfig, in ascending order
	Common = rarity("Common", "C3CAD4", "8A929E"),
	Uncommon = rarity("Uncommon", "8CFF52", "36C900"),
	Rare = rarity("Rare", "6FBBFF", "167BE8"),
	Epic = rarity("Epic", "C86BFF", "711CE8"),
	Legendary = rarity("Legendary", "FFE066", "FFA000"),
	Secret = rarity("Secret", "FF7ADA", "E6237F"),
	-- Kept for older data; PetConfig no longer uses it.
	Mythic = rarity("Mythic", "FF7ADA", "E6237F"),
} :: { [string]: RarityStyle }

Theme.RarityOrder = {
	"Normal",
	"Gold",
	"Diamond",
	"Emerald",
	"Blood",
	"Electric",
	"Admin",
	"Radioactive",
}

Theme.PetRarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Secret" }

function Theme.rarity(name: string): RarityStyle
	return Theme.Rarity[name] or Theme.Rarity.Normal
end

--[[
	Perceived lightness, 0..1. Used to decide whether text needs the usual dark
	outline: dark text with a dark outline collapses into an unreadable blob,
	which is what a gold badge with ink-coloured text used to look like.
]]
function Theme.luminance(color: Color3): number
	return 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
end

function Theme.isDark(color: Color3): boolean
	return Theme.luminance(color) < 0.45
end

--------------------------------------------------------------------------------
-- Typography. Fredoka One carries every game-facing label; Nunito ExtraBold
-- handles the small descriptive copy where Fredoka gets hard to read.
--------------------------------------------------------------------------------

-- Families are read back out of the Font enum rather than hardcoding
-- "rbxasset://fonts/families/..." paths, so a family that Roblox renames or
-- relocates cannot silently fall back to Legacy at render time.
local function weighted(fontEnum: Enum.Font, weight: Enum.FontWeight): Font
	return Font.new(Font.fromEnum(fontEnum).Family, weight)
end

Theme.Font = {
	Display = Font.fromEnum(Enum.Font.FredokaOne),
	-- The authored HUD's money readout. Not in the Font enum -- it is an uploaded
	-- family -- so it is referenced by asset id, which is why this one line does
	-- not go through `weighted`.
	Money = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy),
	Heavy = weighted(Enum.Font.Nunito, Enum.FontWeight.Heavy),
	Bold = weighted(Enum.Font.Nunito, Enum.FontWeight.ExtraBold),
	Body = weighted(Enum.Font.Nunito, Enum.FontWeight.Bold),
}

Theme.TextSize = {
	Hero = 48,
	Title = 34,
	Heading = 26,
	Button = 22,
	Value = 22,
	Body = 18,
	Small = 15,
	Tiny = 13,
	Micro = 11,
}

-- Text outline thickness paired to a text size, so labels never look spindly
-- or over-inked.
function Theme.strokeFor(textSize: number): number
	if textSize >= 40 then
		return 4
	elseif textSize >= 24 then
		return 3
	elseif textSize >= 16 then
		return 2.5
	end
	return 2
end

--------------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------------

Theme.Radius = {
	Panel = 14,
	Card = 10,
	Button = 10,
	Chip = 8,
	Slot = 8,
	Small = 6,
}

Theme.Stroke = {
	Panel = 4,
	Card = 3,
	Button = 3,
	Chip = 2,
	Thin = 2,
}

Theme.Space = {
	XS = 4,
	S = 8,
	M = 12,
	L = 16,
	XL = 24,
	XXL = 32,
}

-- Depth of the solid darker lip under pressable surfaces.
Theme.Lip = {
	Button = 6,
	Small = 4,
	Card = 5,
}

--[[
	The top sheen. Solid, not a gradient: a uniform band of white at a fixed
	alpha reads as moulded plastic, where a fade reads as glass -- and glass is
	explicitly not the look.

	`Inset` keeps the band off the outline so the two never touch.
]]
Theme.Highlight = {
	Transparency = 0.76,
	Height = 0.42,
	Inset = 3,
}

--[[
	Screen regions Roblox owns.

	`TopPixels` is in REAL screen pixels, because the Roblox topbar does not scale
	with our UIScale -- at scale 0.55 a 44 design-pixel inset is only 24 real
	pixels, which slides the HUD straight under it. Hooks.useSafeArea converts it
	into design space with the live scale, preferring GuiService.TopbarInset when
	the engine reports it.

	Roblox's CoreGui also renders ABOVE every player GUI, so anything drawn inside
	the top strip is simply covered. Nothing of ours goes in there -- our own
	topbar row sits just below it.
]]
Theme.Safe = {
	TopPixels = 40, -- fallback topbar height, real pixels
	TopLeftPixels = 340, -- width Roblox's own buttons occupy in that strip
	Top = 44, -- design-space fallback for components without the hook
	BottomBand = 190, -- thumbstick / jump button band on touch, design pixels
}

--- How much a pressable surface grows on hover / shrinks on press.
Theme.Hover = {
	Scale = 1.045,
	PressScale = 0.975,
	CardScale = 1.035,
	Wash = 0.88,
}

--------------------------------------------------------------------------------
-- Stud texture
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Palettes
--------------------------------------------------------------------------------

--[[
	NOT WIRED UP. Dark is the shipped skin and nothing calls `setPalette`, so these
	tables are inert -- kept because they work and the switch is cheap to restore.

	To bring the light theme back: call `Theme.setPalette("Light")` from `App` (it
	must run before descendants render, so a parent is the right place), and give the
	subtree a key that changes with the palette name, because mutating a table is
	invisible to React. A persisted `LightTheme` boolean on `PlayerSettings` plus a
	toggle row in `SettingsScreen` is what drove it before.

	Light and dark are the same design in two skins.

	Only surfaces and text move. Rarity colours, accents and gradients for buttons
	stay exactly as they are, because those are the game's identity and they read
	fine on either background -- and because a rarity that changed colour with the
	theme would be a different rarity.

	`setPalette` writes into `Theme.Color` and `Theme.Gradient` **in place**, which
	is deliberate: 41 files read `Theme.Color.X` inside their render functions, so an
	in-place swap reaches all of them with no change to any of them. The only reads
	captured at module scope are `TextSize`, `Safe` and `Devices`, none of which
	differ between palettes -- verified before choosing this approach.

	Re-rendering is the caller's job: `App` remounts its subtree when the palette
	changes, because mutating a table is invisible to React.
]]
local PALETTES = {
	Dark = {
		Text = hex("FFFFFF"),
		TextMuted = hex("C2CEDF"),
		TextOutline = hex("10131A"),
		Gray = hex("C2CEDF"),
		GrayDark = hex("8C9BB2"),

		Outline = hex("10131A"),
		Panel = hex("2C4A78"),
		PanelDark = hex("1F3760"),
		PanelLight = hex("3F66A0"),
		PanelRaised = hex("4E7BBA"),
		Stud = hex("6C9BD8"),
		Slot = hex("1A3058"),
		Card = hex("3E66A2"),
		CardBase = hex("22406E"),
		CardHover = hex("4B76B4"),

		Gradient = {
			Panel = { "35578C", "264269" },
			PanelDeep = { "2A4874", "1C3358" },
			Slot = { "223D68", "162A4C" },
			Card = { "4A72AF", "375C93" },
			Glass = { "5C89CC", "101F38" },
		},
		StudTransparency = 0.9,
	},

	Light = {
		--[[
			Dark text on light surfaces, with a white outline instead of a black one --
			black-outlined white text on a pale panel is illegible, and that pairing is
			the single thing most likely to break when a theme flips.
		]]
		Text = hex("16233A"),
		TextMuted = hex("4A5B77"),
		TextOutline = hex("FFFFFF"),
		Gray = hex("4A5B77"),
		GrayDark = hex("6B7C96"),

		-- Kept dark: the thick outline is the style's backbone in both themes.
		Outline = hex("1B2740"),
		Panel = hex("DCE6F5"),
		PanelDark = hex("C4D3EA"),
		PanelLight = hex("EDF3FC"),
		PanelRaised = hex("FFFFFF"),
		Stud = hex("A8BEDD"),
		Slot = hex("B4C6E2"),
		Card = hex("EAF1FB"),
		CardBase = hex("B9C9E4"),
		CardHover = hex("F6FAFF"),

		Gradient = {
			Panel = { "E8F0FC", "CFDDF2" },
			PanelDeep = { "D6E3F6", "BCCEE9" },
			Slot = { "C2D2EB", "AABEDD" },
			Card = { "F4F8FE", "DCE7F7" },
			Glass = { "FFFFFF", "AFC4E2" },
		},
		-- Studs need more presence on a pale panel to read at all.
		StudTransparency = 0.72,
	},
}

Theme.PaletteNames = { "Dark", "Light" }

--- Which palette is live. Read it; do not assign it.
Theme.palette = "Dark"

--[[
	Swaps the palette in place. Idempotent, so calling it every render costs nothing
	once it is already applied.
]]
function Theme.setPalette(name: string): boolean
	local palette = PALETTES[name]
	if palette == nil or Theme.palette == name then
		return false
	end

	for key, value in palette do
		if key ~= "Gradient" and key ~= "StudTransparency" then
			Theme.Color[key] = value
		end
	end
	for key, pair in palette.Gradient do
		Theme.Gradient[key] = ColorSequence.new(hex(pair[1]), hex(pair[2]))
	end

	-- Captured at load from `Theme.Color.Stud`, so it needs updating by hand.
	Theme.Studs.Color = palette.Stud
	Theme.Studs.Transparency = palette.StudTransparency

	Theme.palette = name
	return true
end

Theme.Studs = {
	Spacing = 30,
	Size = 14,
	Transparency = 0.9,
	Color = Theme.Color.Stud,
	-- Drop a tiled stud image id here to swap the procedural grid for a single
	-- ImageLabel. Leave nil to keep the zero-asset procedural version.
	Image = nil :: string?,
}

--------------------------------------------------------------------------------
-- Z layers, so overlays never fight each other
--------------------------------------------------------------------------------

Theme.Layer = {
	Hud = 10,
	HudOverlay = 20,
	Screen = 100,
	Modal = 200,
	Tooltip = 300,
	Toast = 400,
	-- Above everything: a server-wide announcement outranks the player's own
	-- windows and their own notification feed.
	Announcement = 500,
}

--------------------------------------------------------------------------------
-- Surface variants — the one place the announcement look is chosen
--------------------------------------------------------------------------------

--[[
	Two surfaces can be drawn either way, and this is the switch.

		"fade"   the spin-reward look: accent gradient dissolving to both edges, no outline.
		         `Components/FadeBanner`.
		"panel"  the outlined dark slab the rest of the HUD uses. `P.Panel`.

	Change a value here and every instance follows -- that is the point of it living in one table
	rather than at each call site. Individual callers can still pass `variant` to override, which is
	what the stories do so both looks stay reviewable side by side.
]]
Theme.Variant = {
	--- The HUD event strip.
	EventBanner = "fade",
	--- The corner notification feed.
	Toast = "fade",
}

return Theme
