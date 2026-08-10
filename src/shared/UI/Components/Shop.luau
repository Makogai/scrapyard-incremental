--!nonstrict
--[[
	Shop.luau
	The storefront's reusable parts. Everything the shop draws comes from here, so a
	new product is a data entry rather than a new layout.

		Shop.Badge          BEST VALUE / PREMIUM / POPULAR / LIMITED / NEW / EXCLUSIVE
		Shop.Price          Robux or cash, with an optional "was" strike-through
		Shop.BuyButton      the CTA, with every purchase state
		Shop.ProductCard    the workhorse card, in three tiers
		Shop.FeaturedBanner the wide promo at the top of a tab

	Design intent: these are promo cards, not table rows. Every card leads with a
	large icon on a coloured well, then a bold title, then one short benefit line,
	then the price and the button. That order is the reading order, and it is the
	same on every card so a player can scan a grid without re-learning it.

	Colour comes from the product, not the component: each entry carries an accent
	and the card tints its well, its border, its glow and its badge from that one
	value. That is what lets a grid look varied without any card being bespoke.

	Animation is opt-in per tier and lives in `Shine`, which uses looping
	TweenService tweens with no per-frame Lua. Higher tiers get more: a standard card
	just breathes, a premium one sweeps, the loudest adds sparkles.

	Every effect stays inside its card, and the rule that makes that true lives in
	`Shine`: nothing animated is ever rotated, because Roblox lets a rotated
	GuiObject ignore an ancestor's `ClipsDescendants` and paint over the screen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Motion = require(UI.Motion)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)
local Buttons = require(script.Parent.Buttons)
local Shine = require(script.Parent.Shine)

local e = React.createElement

local Shop = {}

--------------------------------------------------------------------------------
-- The skin
--------------------------------------------------------------------------------

--[[
	A card IS its colour. The old cards were dark slabs wearing a thin bright accent
	border, which is why they all read the same: the only thing that varied was a 3px
	outline and a small coloured square. Now the accent fills the whole card, the
	border is thick and near-black like every other chunky outline in the game, and a
	lighter plate sits inside it holding the content. Colour arrives as an area, not
	as a hairline.

	Two knock-on rules fall out of that, and both were real bugs in the dark version:

	  * Text cannot use the accent gradient any more -- a gold "2X" on a gold card is
	    invisible. Titles are white with a heavy dark outline, or dark with a light
	    one on the pale accents.
	  * The buy button cannot be yellow, for the same reason. It is green now, which
	    is also what every shop in the genre uses for "buy".
]]

--- Accents pale enough that dark text on them beats white text.
local LIGHT_ACCENTS = {
	Gold = true,
	Yellow = true,
	Green = true,
	Cyan = true,
}

--- Card and plate geometry. Chunky on purpose: thin borders were the complaint.
local CARD_RADIUS = 18
local CARD_STROKE = 5
local PLATE_INSET = 10

--[[
	The inner plate's fill: the same accent pulled toward white. Derived rather than
	authored so a new accent needs no second colour, and read off the ColorSequence's
	own endpoints so it always agrees with the card behind it.
]]
local function lighten(sequence: ColorSequence, amount: number): ColorSequence
	local points = sequence.Keypoints
	local white = Color3.new(1, 1, 1)
	return ColorSequence.new(
		points[1].Value:Lerp(white, amount),
		points[#points].Value:Lerp(white, amount)
	)
end

--[[
	Everything a layout needs to know about one accent, in one place so the card, the
	title, the copy and the feature rows cannot disagree about it.
]]
local function skinFor(accentName: string)
	local accent = Theme.Gradient[accentName] or Theme.Gradient.Blue
	local ink = LIGHT_ACCENTS[accentName] == true
	return {
		accent = accent,
		color = Theme.Color[accentName] or Theme.Color.Blue,
		plate = lighten(accent, if ink then 0.34 else 0.2),
		-- Pale card: dark text with a light outline. Deep card: the reverse.
		ink = ink,
		text = if ink then Theme.Color.Ink else Theme.Color.White,
		textOutline = if ink then Theme.Color.White else Theme.Color.Ink,
		--[[
			The lead token wants to contrast with the card, not match it. Gold reads as
			"the number that matters" on a deep card; on a pale one it disappears, so
			there the size alone does the work.
		]]
		lead = if ink then nil else Theme.Gradient.Gold,
	}
end

Shop.skinFor = skinFor

--------------------------------------------------------------------------------
-- Badges
--------------------------------------------------------------------------------

--[[
	The label set, so a product only has to name one. Keeping them here rather than
	letting each product supply text and colour is what stops the shop drifting into
	fifteen slightly different "BEST DEAL" ribbons.
]]
Shop.BADGES = {
	BestValue = { text = "BEST VALUE", gradient = "Gold", shimmer = true },
	Premium = { text = "PREMIUM", gradient = "Purple", shimmer = true },
	Popular = { text = "POPULAR", gradient = "Orange" },
	Limited = { text = "LIMITED", gradient = "Red", shimmer = true },
	New = { text = "NEW!", gradient = "Green" },
	Exclusive = { text = "EXCLUSIVE", gradient = "Pink", shimmer = true },
}

--[[
	props: badge (a key of Shop.BADGES), position, anchorPoint, zIndex

	Sits INSIDE the card. It used to overhang the corner like a stuck-on label, which
	meant the card could not clip its own contents -- and that is what let the
	animated effects escape onto the rest of the screen. Everything is inside the
	border now, so a card is a sealed box.
]]
function Shop.Badge(props)
	local spec = Shop.BADGES[props.badge]
	if spec == nil then
		return nil
	end

	local gradient = Theme.Gradient[spec.gradient] or Theme.Gradient.Gold

	return e(P.Chip, {
		key = props.key or "Badge",
		gradient = gradient,
		color = Theme.Color.White,
		size = props.size or UDim2.fromOffset(if #spec.text > 8 then 106 else 84, 24),
		position = props.position or UDim2.new(1, -8, 0, 8),
		anchorPoint = props.anchorPoint or Vector2.new(1, 0),
		radius = Theme.Radius.Small,
		zIndex = props.zIndex or 20,
		children = P.compact(
			-- Only the loud badges shimmer; POPULAR and NEW stay still so the ones
			-- that matter keep their advantage.
			if spec.shimmer
				then e(Shine.Layer, {
					key = "Shimmer",
					color = Theme.Color.White,
					sweep = true,
					delay = 1.4,
					zIndex = 1,
				})
				else nil,
			e(P.Label, {
				key = "Text",
				text = spec.text,
				textSize = Theme.TextSize.Micro,
				size = UDim2.fromScale(1, 1),
				zIndex = 4,
			})
		),
	})
end

--------------------------------------------------------------------------------
-- Title
--------------------------------------------------------------------------------

--[[
	A product title with its lead token blown up.

	"2x Cash Forever" reads as a big 2X over "CASH FOREVER": the number is the hook,
	so it gets the size and the accent gradient while the words stay legible beneath.
	Same for "+2 Pet Slots" and "Mega Storage".

	Two labels rather than RichText, because RichText cannot give the two halves
	different stroke weights and the chunky outline is the whole look here.

	The split is by pattern, so it works for products that do not exist yet:
	"2x ...", "+2 ...", or otherwise the first word when it is short.
]]
local LEAD_PATTERNS = { "^(%d+[xX])%s+(.+)$", "^([%+%-]%d+)%s+(.+)$" }

local function splitTitle(text: string): (string?, string)
	for _, pattern in LEAD_PATTERNS do
		local lead, rest = string.match(text, pattern)
		if lead then
			return string.upper(lead), rest
		end
	end

	--[[
		Otherwise the first word leads and the remainder follows: "MEGA / STORAGE",
		"SINGULARITY / PET". Every multi-word title gets the treatment, not just the
		ones with a short first word -- gating on length left "Quantum Magnet" and the
		three premium pets rendering at full size in a 161px card, where they simply
		truncated to "QUANTUM...".
	]]
	local first, rest = string.match(text, "^(%S+)%s+(.+)$")
	if first and rest then
		return string.upper(first), rest
	end
	return nil, text
end

--[[
	A long lead word cannot have the full display size, or it runs off the card. Shrink
	it toward the body size as it gets longer, using roughly six characters as the width
	the full size fits. Cheap and stable: no measuring, no re-layout, same answer every
	render.
]]
local function leadTextSize(lead: string, leadSize: number, floorSize: number): number
	if #lead <= 6 then
		return leadSize
	end
	return math.max(floorSize, math.floor(leadSize * 6 / #lead))
end

--- props: text, skin, leadSize, restSize, align, wrap, size, position
function Shop.Title(props)
	local lead, rest = splitTitle(props.text or "")
	local skin = props.skin or skinFor("Gold")
	local leadSize = props.leadSize or Theme.TextSize.Title
	local restSize = props.restSize or Theme.TextSize.Small
	local fitted = if lead then leadTextSize(lead, leadSize, restSize + 2) else leadSize
	--[[
		`wrap` lets the tail run to a second and third line instead of truncating.
		Narrow columns need it -- "MEGA STARTER BUNDLE" in a 150px column is not a
		truncation problem to tune away, it is a title that has to wrap.
	]]
	local wrap = props.wrap == true
	local boxHeight = if props.size then props.size.Y.Offset else 0
	local restHeight = if lead then fitted + 2 else 0
	local restBox = math.max(boxHeight - restHeight - 2, (if lead then restSize else fitted) + 4)

	return e(P.Group, {
		key = props.key or "Title",
		size = props.size or UDim2.new(1, -14, 0, leadSize + restSize + 6),
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex or 6,
		layout = P.list({
			padding = -2,
			hAlign = props.align or Enum.HorizontalAlignment.Center,
		}),
		children = P.compact(
			if lead
				then e(P.Label, {
					key = "Lead",
					text = lead,
					textSize = fitted,
					color = skin.text,
					gradient = skin.lead,
					strokeColor = skin.textOutline,
					-- Heavier outline than body text: this is the hook.
					stroke = math.max(4, math.floor(fitted / 7)),
					size = UDim2.new(1, 0, 0, fitted + 2),
					layoutOrder = 1,
				})
				else nil,
			e(P.Label, {
				key = "Rest",
				text = string.upper(rest),
				textSize = if lead then restSize else fitted,
				color = skin.text,
				strokeColor = skin.textOutline,
				stroke = math.max(3, math.floor((if lead then restSize else fitted) / 8)),
				wrapped = wrap,
				vAlign = if wrap then Enum.TextYAlignment.Top else nil,
				size = UDim2.new(
					1,
					0,
					0,
					if wrap then restBox else (if lead then restSize else fitted) + 4
				),
				truncate = if wrap then nil else Enum.TextTruncate.AtEnd,
				layoutOrder = 2,
			})
		),
	})
end

--------------------------------------------------------------------------------
-- Section divider
--------------------------------------------------------------------------------

--[[
	A heading for the single-page shop: a fading rule either side of the label, so
	the eye registers a break without a heavy panel doing it.

	props: text, accent, layoutOrder
]]
function Shop.SectionHeader(props)
	local accent = props.accent or Theme.Gradient.Pink

	local function rule(key: string, position: UDim2, anchor: Vector2, flip: boolean)
		return e("Frame", {
			key = key,
			BackgroundColor3 = Theme.Color.White,
			BorderSizePixel = 0,
			Size = UDim2.new(0.5, -140, 0, 5),
			Position = position,
			AnchorPoint = anchor,
			ZIndex = 3,
		}, {
			P.corner(3),
			P.gradient(accent, { rotation = 0 }),
			-- Fades toward the label, so a rule never ends on a hard edge.
			e("UIGradient", {
				key = "Fade",
				Rotation = 0,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, if flip then 0.9 else 0.15),
					NumberSequenceKeypoint.new(1, if flip then 0.15 else 0.9),
				}),
			}),
		})
	end

	return e(P.Group, {
		key = props.key or "Section",
		size = UDim2.new(1, 0, 0, 52),
		layoutOrder = props.layoutOrder,
		children = {
			rule("Left", UDim2.fromScale(0, 0.5), Vector2.new(0, 0.5), false),
			rule("Right", UDim2.fromScale(1, 0.5), Vector2.new(1, 0.5), true),
			e(P.Label, {
				key = "Text",
				text = string.upper(props.text or ""),
				textSize = Theme.TextSize.Heading,
				gradient = accent,
				stroke = 3,
				size = UDim2.fromOffset(266, 42),
				position = UDim2.fromScale(0.5, 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
				zIndex = 6,
			}),
		},
	})
end

--------------------------------------------------------------------------------
-- Price
--------------------------------------------------------------------------------

--[[
	props: robux, cash, was (original price, struck through), align, textSize

	Robux and cash are visually distinct on purpose: a player should never have to
	read the number to know which currency they are about to spend.
]]
function Shop.Price(props)
	--[[
		Nothing to show is better than a wrong number: a product with neither price
		renders no price row at all, and its button already says COMING SOON.
	]]
	if props.robux == nil and props.cash == nil then
		return nil
	end

	local isRobux = props.robux ~= nil
	local textSize = props.textSize or Theme.TextSize.Heading
	local Format = require(UI.Format)

	local amount = if isRobux then Format.comma(props.robux) else Format.money(props.cash or 0)

	return e(P.Group, {
		key = props.key or "Price",
		size = props.size or UDim2.new(1, 0, 0, textSize + 8),
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex,
		layout = P.list({
			direction = Enum.FillDirection.Horizontal,
			padding = 5,
			hAlign = props.align or Enum.HorizontalAlignment.Center,
			vAlign = Enum.VerticalAlignment.Center,
		}),
		children = P.compact(
			e(Icon, {
				key = "Currency",
				glyph = if isRobux then "robux" else "coin",
				plain = true,
				size = UDim2.fromOffset(textSize, textSize),
				layoutOrder = 1,
			}),
			e(P.Label, {
				key = "Amount",
				text = amount,
				textSize = textSize,
				color = if isRobux then Theme.Color.White else Theme.Color.Cash,
				automaticSize = Enum.AutomaticSize.X,
				size = UDim2.fromOffset(0, textSize + 6),
				layoutOrder = 2,
			}),
			-- A struck-through original, for anything on offer.
			if props.was
				then e(P.Label, {
					key = "Was",
					text = Format.comma(props.was),
					textSize = Theme.TextSize.Small,
					color = Theme.Color.GrayDark,
					automaticSize = Enum.AutomaticSize.X,
					size = UDim2.fromOffset(0, 20),
					layoutOrder = 3,
					children = {
						-- Roblox has no strike-through, so it is a hairline frame.
						e("Frame", {
							key = "Strike",
							BackgroundColor3 = Theme.Color.GrayDark,
							BorderSizePixel = 0,
							Size = UDim2.new(1, 4, 0, 2),
							Position = UDim2.fromScale(0.5, 0.55),
							AnchorPoint = Vector2.new(0.5, 0.5),
							ZIndex = 4,
						}),
					},
				})
				else nil
		),
	})
end

--------------------------------------------------------------------------------
-- Buy button
--------------------------------------------------------------------------------

--[[
	Purchase states. Text and variant per state, so a card only passes a state name
	and cannot invent an inconsistent one.

	`enabled = false` states are still drawn boldly rather than greyed to nothing:
	OWNED is good news and should look like it.
]]
local BUY_STATES = {
	--[[
		Green, not the yellow `Purchase` variant. On a Gold or Yellow card a yellow
		button vanished into the fill, and green is what the whole genre uses for buy.
	]]
	Buy = { text = "BUY", variant = "Primary", enabled = true },
	Owned = { text = "OWNED", variant = "Primary", enabled = false },
	Equipped = { text = "EQUIPPED", variant = "Primary", enabled = false },
	Equip = { text = "EQUIP", variant = "Secondary", enabled = true },
	Limited = { text = "LIMITED", variant = "Danger", enabled = true },
	Soon = { text = "COMING SOON", variant = "Disabled", enabled = false },
	Unavailable = { text = "UNAVAILABLE", variant = "Disabled", enabled = false },
}

Shop.BUY_STATES = BUY_STATES

--[[
	props: state (a key of BUY_STATES), size, textSize, onClick, layoutOrder

	The strongest anchor on the card. Hover and press feedback come from
	`Buttons.Button`, which every button in the game already uses, so the shop feels
	like the rest of the UI rather than a separate app.
]]
function Shop.BuyButton(props)
	local spec = BUY_STATES[props.state or "Buy"] or BUY_STATES.Buy

	--[[
		The price lives IN the button. A separate price row made the player read two
		things to answer one question; together they are a single offer, and the Robux
		glyph says which currency without a word.

		Only a live offer shows a price: OWNED has nothing to cost.
	]]
	local Format = require(UI.Format)
	local showPrice = spec.enabled and (props.robux ~= nil or props.cash ~= nil)
	local priceText = if props.robux ~= nil
		then Format.comma(props.robux)
		else (if props.cash ~= nil then Format.money(props.cash) else nil)

	return e(Buttons.Button, {
		key = props.key or "Buy",
		text = props.text or spec.text,
		subtext = if showPrice then priceText else props.subtext,
		subtextSize = props.subtextSize or Theme.TextSize.Heading,
		subtextFont = props.subtextFont or Theme.Font.Display,
		glyph = if showPrice then (if props.robux ~= nil then "robux" else "coin") else nil,
		iconSize = props.iconSize or 34,
		variant = spec.variant,
		disabled = not spec.enabled,
		textSize = props.textSize or Theme.TextSize.Button,
		size = props.size or UDim2.new(1, -20, 0, 64),
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		lip = props.lip or 6,
		zIndex = props.zIndex or 10,
		onClick = if spec.enabled then props.onClick else nil,
		--[[
			A highlight travelling across the face. `Buttons.Button` appends `children`
			into its own face, so this rides along with the press and hover animation
			rather than fighting it. Buyable offers only -- a shine on OWNED would be
			advertising something already bought.
		]]
		children = if spec.enabled
			then {
				e(Shine.Layer, {
					key = "Shine",
					color = Theme.Color.White,
					sweep = true,
					delay = props.delay or 0.4,
					zIndex = 4,
				}),
			}
			else nil,
	})
end

--------------------------------------------------------------------------------
-- Decoration
--------------------------------------------------------------------------------

--[[
	Static backdrops, the cheapest way to stop a shelf of cards reading as a
	spreadsheet. Three kinds:

		sunburst  rays from a centre point; for the loudest offers
		rings     concentric discs; calmer, good behind a single icon
		dots      a tiled grid; texture rather than focus

	Plain elements with no tweens. Decoration should cost nothing per frame -- a
	card already spends its animation budget on `Shine`.

	The rays ARE rotated, which normally means escaping the card's clip (see the
	rule at the top of `Shine.luau`). It is safe *here* only because they are
	anchored at the centre of a square box at under 1.0 scale, so a ray stays inside
	the circle inscribed in that box whatever its angle. Hand `sunburst` a
	non-square box and it will spill across the screen.

	props: kind, color, transparency, size, position, anchorPoint, zIndex
]]
local PATTERN_RAYS = 12
local RING_SCALES = { 0.46, 0.7, 0.94 }
local DOT_COLUMNS, DOT_ROWS = 4, 6

function Shop.Pattern(props)
	local kind = props.kind
	if kind == nil or kind == "none" then
		return nil
	end

	local color = props.color or Theme.Color.White
	local alpha = props.transparency or 0.88
	local parts = {}

	if kind == "sunburst" then
		for index = 1, PATTERN_RAYS do
			parts[#parts + 1] = e("Frame", {
				key = "Ray" .. index,
				BackgroundColor3 = color,
				BackgroundTransparency = alpha,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(0.055, 0.94),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = (index - 1) * (180 / PATTERN_RAYS),
			})
		end
	elseif kind == "rings" then
		for index, scale in ipairs(RING_SCALES) do
			parts[#parts + 1] = e("Frame", {
				key = "Ring" .. index,
				BackgroundColor3 = color,
				BackgroundTransparency = math.min(alpha + 0.03 * index, 1),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(scale, scale),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
			}, {
				e("UICorner", { key = "Round", CornerRadius = UDim.new(1, 0) }),
			})
		end
	elseif kind == "dots" then
		-- Nothing rotated, so this one may safely cover a whole card.
		for row = 1, DOT_ROWS do
			for column = 1, DOT_COLUMNS do
				parts[#parts + 1] = e("Frame", {
					key = "Dot" .. row .. "x" .. column,
					BackgroundColor3 = color,
					BackgroundTransparency = alpha,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(14, 14),
					Position = UDim2.fromScale(
						(column - 0.5) / DOT_COLUMNS,
						(row - 0.5) / DOT_ROWS
					),
					AnchorPoint = Vector2.new(0.5, 0.5),
				}, {
					e("UICorner", { key = "Round", CornerRadius = UDim.new(0.32, 0) }),
				})
			end
		end
	end

	return e("Frame", {
		key = props.key or "Pattern",
		BackgroundTransparency = 1,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
		ZIndex = props.zIndex or 2,
	}, parts)
end

--------------------------------------------------------------------------------
-- Feature row
--------------------------------------------------------------------------------

--[[
	One line of an offer's contents: glyph, bold claim, quiet detail.

	This is what lets the widest card sell three things instead of one, and it is
	the reason a big card is worth being big -- scaling a one-line card up just
	makes the empty space larger.

	The glyph has no chip behind it. On a dark card a chip gave the icon somewhere to
	sit, but on a card that is already a solid colour it is one rounded rectangle
	inside another, and the reference art gets the same job done with a bare icon.

	props: glyph, title, note, skin, layoutOrder
]]
function Shop.FeatureRow(props)
	local skin = props.skin or skinFor("Blue")

	return e(P.Group, {
		key = props.key or "Feature",
		size = UDim2.new(1, 0, 0, 46),
		layoutOrder = props.layoutOrder,
		children = {
			e(Icon, {
				key = "Glyph",
				glyph = props.glyph or "star",
				plain = true,
				size = UDim2.fromOffset(38, 38),
				position = UDim2.fromScale(0, 0.5),
				anchorPoint = Vector2.new(0, 0.5),
				zIndex = 5,
			}),
			e(P.Label, {
				key = "Claim",
				text = props.title,
				textSize = Theme.TextSize.Body,
				color = skin.text,
				strokeColor = skin.textOutline,
				stroke = 3,
				align = Enum.TextXAlignment.Left,
				size = UDim2.new(1, -50, 0, 23),
				position = UDim2.fromOffset(50, 1),
				truncate = Enum.TextTruncate.AtEnd,
				zIndex = 4,
			}),
			e(P.Label, {
				key = "Note",
				text = props.note,
				textSize = Theme.TextSize.Small,
				font = Theme.Font.Bold,
				color = skin.text,
				strokeColor = skin.textOutline,
				stroke = 2,
				-- Slightly faded rather than grey: grey on a coloured card looks dirty.
				textTransparency = 0.18,
				align = Enum.TextXAlignment.Left,
				size = UDim2.new(1, -50, 0, 21),
				position = UDim2.fromOffset(50, 24),
				truncate = Enum.TextTruncate.AtEnd,
				zIndex = 4,
			}),
		},
	})
end

--------------------------------------------------------------------------------
-- Product card
--------------------------------------------------------------------------------

--[[
	Tiers. The value ladder: a higher tier is a busier card, which is what makes
	"more expensive" read as "more valuable" before the price is even read. Tier no
	longer sets the art height -- the layout does, by division -- so this is purely
	which effects a card earns.
]]
local TIERS = {
	[1] = { glow = false, sweep = false, sparkles = false },
	[2] = { glow = true, sweep = true, sparkles = false },
	[3] = { glow = true, sweep = true, sparkles = true },
}

--[[
	GEOMETRY. Every layout divides the plate's inner box exactly, with the artwork
	taking whatever is left over. That rule is the fix for the dead space: before,
	blocks were positioned with fixed offsets measured from the CARD while actually
	being parented to the PLATE, which is 20px smaller each way -- so a short card
	overlapped its own button by 16px and a tall one left 24-52px of nothing.

	One height for every layout, too. A card used to be stretched to match the
	tallest layout in its row, and that extra height had nowhere to go but into a
	gap. Rows still differ in *shape*; they no longer differ in height.
]]
local COLUMN_WIDTH = 300
local CARD_HEIGHT = 336

--- Inside the plate. Small, because the plate inset is already generous.
local PAD = 10
local GAP = 5

local HEIGHTS = {
	vertical = CARD_HEIGHT,
	hero = CARD_HEIGHT,
	feature = CARD_HEIGHT,
}

--[[
	How many columns each layout wants. `hero` and `feature` are both two-wide: a
	side-by-side composition needs landscape. At one column the title column beside a
	124px icon came out 116px wide, which is what made those cards look both cramped
	and empty at the same time.
]]
local SPANS = {
	vertical = 1,
	hero = 2,
	feature = 2,
}

Shop.COLUMN_WIDTH = COLUMN_WIDTH
Shop.CARD_HEIGHT = CARD_HEIGHT
Shop.HEIGHTS = HEIGHTS
Shop.SPANS = SPANS
Shop.CARD_SIZE = Vector2.new(COLUMN_WIDTH, CARD_HEIGHT)

--[[
	props:
		title       "2x Cash Forever"
		benefit     one short selling line
		glyph/image the art
		accent      Theme.Gradient key -- the card's whole colour, not just its border
		tier        1..3; higher tiers are more animated
		layout      "vertical" | "hero" | "feature"
		pattern     "sunburst" | "rings" | "dots" | nil, the backdrop
		features    { { glyph, title, note } } -- the list hero and feature can show
		badge       key of Shop.BADGES
		robux/cash  price
		state       key of BUY_STATES
		width       card width in pixels; ShopScreen computes it from the span
		height      card height; defaults to CARD_HEIGHT
		onClick, layoutOrder, delay (stagger for the sweep)
]]
function Shop.ProductCard(props)
	local tier = TIERS[props.tier or 1] or TIERS[1]
	local skin = skinFor(props.accent or "Blue")

	local layout = props.layout or "vertical"
	local width = props.width or COLUMN_WIDTH
	local height = props.height or CARD_HEIGHT

	--- The box the content actually lives in. Everything below measures from this.
	local innerW = width - PLATE_INSET * 2
	local innerH = height - PLATE_INSET * 2

	local press = Motion.usePressable({ hoverScale = 1.03, pressScale = 0.985 })

	--[[
		The artwork, sitting straight on the plate -- no coloured slab under it. On a
		dark card that slab was how colour got onto the card at all; on a card that IS
		the colour it was a bright rectangle inside a bright rectangle.

		The icon is sized as a square from the box's short edge rather than by scale, so
		a landscape or portrait art box cannot stretch it.
	]]
	local function artwork(box: Vector2, position: UDim2)
		local short = math.min(box.X, box.Y)
		return e(P.Group, {
			key = "Art",
			size = UDim2.fromOffset(box.X, box.Y),
			position = position,
			zIndex = 4,
			children = P.compact(
				--[[
					A square box for the pattern, centred: `sunburst` is only safe inside
					one. White, because it has to read against the accent behind it.
				]]
				e(Shop.Pattern, {
					key = "Pattern",
					kind = if props.pattern == "dots" then nil else props.pattern,
					color = Theme.Color.White,
					size = UDim2.fromOffset(short, short),
					transparency = 0.8,
					zIndex = 2,
				}),
				if tier.glow
						or tier.sweep
						or tier.sparkles
					then e(Shine.Layer, {
						key = "Shine",
						color = Theme.Color.White,
						glow = tier.glow,
						sweep = tier.sweep,
						sparkles = tier.sparkles,
						delay = props.delay or 0,
						size = UDim2.fromOffset(short, short),
						zIndex = 3,
					})
					else nil,
				e(Icon, {
					key = "Glyph",
					glyph = props.glyph,
					image = props.image,
					plain = true,
					-- Big: the icon is the card's subject, not a decoration on it.
					size = UDim2.fromOffset(short * 0.92, short * 0.92),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					zIndex = 6,
				})
			),
		})
	end

	--- Copy in the card's own ink. Grey on a coloured card just looks dirty.
	local function copy(size: UDim2, position: UDim2, textSize: number, align)
		return e(P.Label, {
			key = "Benefit",
			text = props.benefit,
			textSize = textSize,
			font = Theme.Font.Bold,
			color = skin.text,
			strokeColor = skin.textOutline,
			stroke = 3,
			textTransparency = 0.12,
			align = align,
			vAlign = Enum.TextYAlignment.Top,
			wrapped = true,
			size = size,
			position = position,
			zIndex = 6,
		})
	end

	local function buy(size: UDim2, position: UDim2, anchor: Vector2)
		return e(Shop.BuyButton, {
			key = "Buy",
			state = props.state,
			robux = props.robux,
			cash = props.cash,
			delay = props.delay,
			size = size,
			position = position,
			anchorPoint = anchor,
			onClick = props.onClick,
			zIndex = 10,
		})
	end

	--- The selling list, centred in whatever column height it is given.
	local function featureList(size: UDim2, position: UDim2)
		local rows = {}
		for index, feature in ipairs(props.features or {}) do
			rows[#rows + 1] = e(Shop.FeatureRow, {
				key = "Feature" .. index,
				glyph = feature.glyph,
				title = feature.title,
				note = feature.note,
				skin = skin,
				layoutOrder = index,
			})
		end
		if #rows == 0 then
			return nil
		end
		return e(P.Group, {
			key = "Features",
			size = size,
			position = position,
			zIndex = 6,
			-- Centred, so two rows in a three-row column read as balanced, not as a
			-- list that ran out.
			layout = P.list({ padding = 4, vAlign = Enum.VerticalAlignment.Center }),
			children = rows,
		})
	end

	local contents
	if layout == "feature" then
		--[[
			The flagship. Art fills the left column down to the button; title and the
			selling list take the right. Every band below is subtracted from `innerH`,
			so the card cannot leave a gap at any height.
		]]
		local buttonH = 66
		local side = innerH - PAD * 2 - buttonH - GAP
		local column = PAD + side + 20
		local columnW = innerW - column - PAD
		local titleH = 88
		local titleY = if props.badge then PAD + 24 else PAD

		contents = P.compact(
			artwork(Vector2.new(side, side), UDim2.fromOffset(PAD, PAD)),
			e(Shop.Title, {
				key = "Title",
				text = props.title,
				skin = skin,
				leadSize = Theme.TextSize.Hero,
				restSize = Theme.TextSize.Heading,
				align = Enum.HorizontalAlignment.Left,
				wrap = true,
				size = UDim2.fromOffset(columnW, titleH),
				position = UDim2.fromOffset(column, titleY),
				zIndex = 6,
			}),
			--[[
				The list, or the benefit line when a product has no features written for
				it. A flagship must never render as a big empty box just because nobody
				filled in the copy.
			]]
			featureList(
				UDim2.fromOffset(columnW, innerH - titleY - titleH - GAP - PAD),
				UDim2.fromOffset(column, titleY + titleH + GAP)
			)
				or copy(
					UDim2.fromOffset(columnW, innerH - titleY - titleH - GAP - PAD),
					UDim2.fromOffset(column, titleY + titleH + GAP),
					Theme.TextSize.Body,
					Enum.TextXAlignment.Left
				),
			buy(
				UDim2.fromOffset(side, buttonH),
				UDim2.fromOffset(PAD, PAD + side + GAP),
				Vector2.zero
			)
		)
	elseif layout == "hero" then
		--[[
			Landscape and asymmetric: big art left, big wrapped title right, copy under
			it, button bottom-right. This is the shape that breaks up a shelf of
			verticals, and it needs two columns to work -- at one column the title got
			116px and looked cramped and empty at once.
		]]
		local buttonH = 74
		local side = innerH - PAD * 2
		local column = PAD + side + 20
		local columnW = innerW - column - PAD
		local titleH = 116
		local titleY = if props.badge then PAD + 24 else PAD
		local copyTop = titleY + titleH + GAP
		local copyH = innerH - PAD - buttonH - GAP - copyTop

		contents = P.compact(
			artwork(Vector2.new(side, side), UDim2.fromOffset(PAD, PAD)),
			e(Shop.Title, {
				key = "Title",
				text = props.title,
				skin = skin,
				leadSize = Theme.TextSize.Hero,
				restSize = Theme.TextSize.Heading,
				align = Enum.HorizontalAlignment.Left,
				wrap = true,
				size = UDim2.fromOffset(columnW, titleH),
				--[[
					Pushed down when a badge is present. The badge sits top-right and the
					title runs to the right edge, so without this they overlap -- which is
					exactly what QUANTUM did on top of PREMIUM.
				]]
				position = UDim2.fromOffset(column, titleY),
				zIndex = 6,
			}),
			--[[
				A hero shows its feature list when it has one, and its benefit line when
				it does not. Same column either way, so the band arithmetic is unchanged.
			]]
			featureList(UDim2.fromOffset(columnW, copyH), UDim2.fromOffset(column, copyTop))
				or copy(
					UDim2.fromOffset(columnW, copyH),
					UDim2.fromOffset(column, copyTop),
					Theme.TextSize.Body,
					Enum.TextXAlignment.Left
				),
			--[[
				Button at the foot of the TEXT column, not the card's bottom-right corner.
				The art fills the left column to full height, so a corner-anchored button
				overlapped it by 20px.
			]]
			buy(
				UDim2.fromOffset(columnW, buttonH),
				UDim2.fromOffset(column, innerH - PAD - buttonH),
				Vector2.zero
			)
		)
	else
		--[[
			The workhorse. Art across the top, copy under it, button along the bottom --
			and the art takes whatever the text and the button do not, so the card fills
			itself exactly rather than leaving a hole above the button.
		]]
		local buttonH = 66
		local titleH = 52
		local benefitH = 42
		local artH = innerH - PAD * 2 - titleH - benefitH - buttonH - GAP * 3
		local titleY = PAD + artH + GAP

		contents = P.compact(
			artwork(Vector2.new(innerW - PAD * 2, artH), UDim2.fromOffset(PAD, PAD)),
			e(Shop.Title, {
				key = "Title",
				text = props.title,
				skin = skin,
				leadSize = Theme.TextSize.Title,
				restSize = Theme.TextSize.Small,
				size = UDim2.fromOffset(innerW - PAD * 2, titleH),
				position = UDim2.fromOffset(PAD, titleY),
				zIndex = 6,
			}),
			copy(
				UDim2.fromOffset(innerW - PAD * 2, benefitH),
				UDim2.fromOffset(PAD, titleY + titleH + GAP),
				Theme.TextSize.Small,
				Enum.TextXAlignment.Center
			),
			buy(
				UDim2.fromOffset(innerW - PAD * 2, buttonH),
				UDim2.fromOffset(PAD, innerH - PAD - buttonH),
				Vector2.zero
			)
		)
	end

	return e(P.Group, {
		key = props.key or "Product",
		size = UDim2.fromOffset(width, height),
		layoutOrder = props.layoutOrder,
		children = {
			e("Frame", {
				key = "Hover",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
			}, {
				-- Whole card lifts on hover, so the grid responds to the cursor.
				e("UIScale", { key = "Scale", Scale = press.scale }),
				e(P.Panel, {
					key = "Body",
					size = UDim2.fromScale(1, 1),
					radius = CARD_RADIUS,
					-- The accent fills the card. This is the whole change.
					color = skin.color,
					gradient = skin.accent,
					--[[
						Thick and near-black, like every other outline in the game. The old
						card wore a thin bright accent border on a dark slab, which is the
						border that does not go with the card -- it was the only coloured
						thing on an otherwise grey tile.
					]]
					strokeThickness = CARD_STROKE,
					strokeColor = Theme.Color.Ink,
					studs = false,
					--[[
						Hard clip. The effects are already clipped to their own host, but a
						card clipping too means nothing inside it -- a sweep, a pattern, a
						badge -- can paint outside the border, whatever it is given.
					]]
					clip = true,
					children = P.compact(
						--[[
							The inner plate: the same accent pulled toward white, inset all
							round. It gives the card a lit face instead of one flat wash, and
							it is the box every layout above divides up.
						]]
						e(P.Panel, {
							key = "Plate",
							size = UDim2.fromOffset(innerW, innerH),
							position = UDim2.fromOffset(PLATE_INSET, PLATE_INSET),
							radius = CARD_RADIUS - 6,
							color = skin.color,
							gradient = skin.plate,
							strokeThickness = 0,
							studs = false,
							clip = true,
							zIndex = 2,
							children = P.compact(
								--[[
									`dots` dresses the whole plate rather than sitting behind the
									art, which is what makes a compact card read as decorated
									rather than plain.
								]]
								if props.pattern == "dots"
									then e(Shop.Pattern, {
										key = "Texture",
										kind = "dots",
										color = Theme.Color.White,
										transparency = 0.88,
										zIndex = 1,
									})
									else nil,
								contents
							),
						}),
						--[[
							Badge above the plate rather than inside it, so it reads as a
							sticker on the card's own border and cannot be clipped by the
							plate's rounding.
						]]
						if props.badge
							then e(Shop.Badge, {
								key = "Badge",
								badge = props.badge,
								zIndex = 20,
							})
							else nil
					),
				}),
			}),
		},
	})
end

--------------------------------------------------------------------------------
-- Featured banner
--------------------------------------------------------------------------------

--[[
	The full-width promo above the shelves: best seller, premium pass, limited bundle.

	Same skin as a card -- accent fill, thick dark border, lighter plate -- but a
	shape nothing in the grid has, so a player registers "this is the offer" from the
	silhouette alone. When the entry has `features` they render here too: the widest
	thing in the shop should be the thing that explains most.

	Bands are divided the same way a card's are, so it cannot leave a hole either.

	props: title, benefit, glyph/image, accent, badge, robux/cash, state, features,
	       pattern, onClick, height
]]
function Shop.FeaturedBanner(props)
	local skin = skinFor(props.accent or "Purple")
	local height = props.height or 300
	local innerH = height - PLATE_INSET * 2
	local side = innerH - PAD * 2

	local rows = {}
	for index, feature in ipairs(props.features or {}) do
		rows[#rows + 1] = e(Shop.FeatureRow, {
			key = "Feature" .. index,
			glyph = feature.glyph,
			title = feature.title,
			note = feature.note,
			skin = skin,
			layoutOrder = index,
		})
	end

	local buttonW = 244
	local titleH = 96

	return e(P.Panel, {
		key = props.key or "Featured",
		size = UDim2.new(1, 0, 0, height),
		layoutOrder = props.layoutOrder,
		radius = CARD_RADIUS + 2,
		color = skin.color,
		gradient = skin.accent,
		strokeThickness = CARD_STROKE,
		strokeColor = Theme.Color.Ink,
		studs = false,
		-- Nothing escapes the banner either.
		clip = true,
		children = P.compact(
			e(P.Panel, {
				key = "Plate",
				size = UDim2.new(1, -PLATE_INSET * 2, 1, -PLATE_INSET * 2),
				position = UDim2.fromOffset(PLATE_INSET, PLATE_INSET),
				radius = CARD_RADIUS - 4,
				color = skin.color,
				gradient = skin.plate,
				strokeThickness = 0,
				studs = false,
				clip = true,
				zIndex = 2,
				children = P.compact(
					--[[
						Effects across the whole banner rather than only behind the art: this
						is the one place in the shop that gets to be loud.
					]]
					e(Shine.Layer, {
						key = "Shine",
						color = Theme.Color.White,
						glow = true,
						sweep = true,
						sparkles = true,
						zIndex = 2,
					}),
					-- Art on the left, so the eye starts there and travels right.
					e(P.Group, {
						key = "Art",
						size = UDim2.fromOffset(side, side),
						position = UDim2.fromOffset(PAD, PAD),
						zIndex = 5,
						children = P.compact(
							e(Shop.Pattern, {
								key = "Pattern",
								kind = props.pattern or "sunburst",
								color = Theme.Color.White,
								size = UDim2.fromOffset(side, side),
								transparency = 0.78,
								zIndex = 2,
							}),
							e(Icon, {
								key = "Glyph",
								glyph = props.glyph,
								image = props.image,
								plain = true,
								size = UDim2.fromOffset(side * 0.9, side * 0.9),
								position = UDim2.fromScale(0.5, 0.5),
								anchorPoint = Vector2.new(0.5, 0.5),
								zIndex = 7,
							})
						),
					}),
					e(P.Group, {
						key = "Copy",
						-- Between the art and the button column.
						size = UDim2.new(
							1,
							-(PAD + side + 24 + buttonW + PAD * 2),
							0,
							innerH - PAD * 2
						),
						position = UDim2.fromOffset(PAD + side + 24, PAD),
						zIndex = 6,
						children = P.compact(
							e(Shop.Title, {
								key = "Title",
								text = props.title,
								skin = skin,
								-- The banner gets the biggest type in the shop.
								leadSize = Theme.TextSize.Hero,
								restSize = Theme.TextSize.Heading,
								align = Enum.HorizontalAlignment.Left,
								wrap = true,
								size = UDim2.new(1, 0, 0, titleH),
								zIndex = 6,
							}),
							if #rows > 0
								then e(P.Group, {
									key = "Features",
									size = UDim2.new(1, 0, 0, innerH - PAD * 2 - titleH - GAP),
									position = UDim2.fromOffset(0, titleH + GAP),
									layout = P.list({
										padding = 4,
										vAlign = Enum.VerticalAlignment.Center,
									}),
									zIndex = 6,
									children = rows,
								})
								else e(P.Label, {
									key = "Benefit",
									text = props.benefit,
									textSize = Theme.TextSize.Body,
									font = Theme.Font.Bold,
									color = skin.text,
									strokeColor = skin.textOutline,
									stroke = 3,
									textTransparency = 0.12,
									align = Enum.TextXAlignment.Left,
									vAlign = Enum.TextYAlignment.Top,
									wrapped = true,
									size = UDim2.new(1, 0, 0, innerH - PAD * 2 - titleH - GAP),
									position = UDim2.fromOffset(0, titleH + GAP),
									zIndex = 6,
								})
						),
					}),
					-- Price and CTA on the right, the way a real storefront does it.
					e(Shop.BuyButton, {
						key = "Buy",
						state = props.state,
						robux = props.robux,
						cash = props.cash,
						textSize = Theme.TextSize.Title,
						subtextSize = Theme.TextSize.Title,
						iconSize = 44,
						size = UDim2.fromOffset(buttonW, 104),
						position = UDim2.new(1, -PAD, 0.5, 0),
						anchorPoint = Vector2.new(1, 0.5),
						lip = 8,
						zIndex = 8,
						onClick = props.onClick,
					})
				),
			}),
			if props.badge
				then e(Shop.Badge, { key = "Badge", badge = props.badge, zIndex = 20 })
				else nil
		),
	})
end

return Shop
