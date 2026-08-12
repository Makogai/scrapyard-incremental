--[[
	Parts.luau
	The HUD is assembled from these blocks, shared by the desktop and mobile
	layouts so both stay visually identical and only the arrangement changes.

		MenuGrid        2-column menu tiles + the full-width Shop button
		UtilityRow      small icon buttons (settings, index, plot, leaderboard)
		CurrencyStack   cash / gears / event tokens
		StorageMeter    SCRAP STORAGE bar with estimated value and FULL state
		BoostTimers     active potion timers
		EventBanner     temporary event strip
		ContextActions  teleport home / sell / auto-collect status
		StatusCluster   bottom-right trio: daily login boost, friend boost, spin wheel
		TutorialSpotlight darkens the screen and leaves one control lit
		TutorialCaption the current onboarding objective
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent.Parent
local Theme = require(UI.Theme)
local Format = require(UI.Format)
local Motion = require(UI.Motion)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)
local Buttons = require(UI.Components.Buttons)
local Indicators = require(UI.Components.Indicators)
local Overlays = require(UI.Components.Overlays)
local FadeBanner = require(UI.Components.FadeBanner)

local e = React.createElement

local Parts = {}

--------------------------------------------------------------------------------
-- Menu definitions. Six tiles fill the 2x3 grid cleanly, then Shop spans the
-- full width underneath and is the only tile with a glow.
--------------------------------------------------------------------------------

--[[
	Four tiles: INDEX and SETTINGS moved to the TopbarPlus row in the
	top-right (see `client/Controllers/TopbarController`), which is where players
	expect chrome to live. Adding a sixth here would fill the 2x3 grid neatly, but
	only by putting a window back in two places at once.
]]
Parts.MENU_ITEMS = {
	-- Add `isNew = true` to flag a tile, `wiggle = true` to make it nudge.
	{ id = "upgrades", text = "UPGRADE", glyph = "upgrade", accent = "Green" },
	{ id = "inventory", text = "INVENTORY", glyph = "bag", accent = "Blue" },
	{ id = "pets", text = "PETS", glyph = "paw", accent = "Pink" },
	{ id = "prestige", text = "REBIRTH", glyph = "recycle", accent = "Purple" },
}

Parts.UTILITY_ITEMS = {
	{ id = "settings", glyph = "sliders", variant = "Neutral" },
	{ id = "collection", glyph = "book", variant = "Premium" },
	--[[
		Daily rewards lives here rather than in `MENU_ITEMS` because the 2x3 menu grid is for things you
		spend at -- upgrades, pets, rebirth -- and this is something you collect from.

		The spin wheel is deliberately NOT here: it is in the bottom-left status cluster, and a window
		reachable from two places in the same HUD is the mistake rule 9 exists to stop.
	]]
	{ id = "daily", glyph = "calendar", variant = "Primary" },
}

--------------------------------------------------------------------------------
-- MenuGrid
--------------------------------------------------------------------------------

--[[
	props:
		tile      number?   tile edge length, default 104
		gap       number?
		onOpen    function(screenId)
		compact   boolean?  smaller labels for the mobile drawer
]]
function Parts.MenuGrid(props)
	local tile = props.tile or 104
	local gap = props.gap or 10
	local width = tile * 2 + gap
	local shopHeight = props.shopHeight or 68

	local children = {
		P.grid({
			key = "Grid",
			cell = UDim2.fromOffset(tile, tile),
			padding = UDim2.fromOffset(gap, gap),
			maxCells = 2,
		}),
	}

	for index, item in ipairs(Parts.MENU_ITEMS) do
		children[#children + 1] = e(Buttons.MenuButton, {
			key = item.text,
			text = item.text,
			glyph = item.glyph,
			isNew = item.isNew,
			wiggle = item.wiggle,
			accent = Theme.Gradient[item.accent],
			size = UDim2.fromOffset(tile, tile),
			flatIcon = true,
			iconSize = math.floor(tile * 0.58),
			textSize = if props.compact then Theme.TextSize.Tiny else Theme.TextSize.Small,
			badge = item.badge,
			layoutOrder = index,
			onClick = function()
				if props.onOpen then
					props.onOpen(item.id)
				end
			end,
		})
	end

	local rows = math.ceil(#Parts.MENU_ITEMS / 2)
	local gridHeight = rows * tile + (rows - 1) * gap

	return e(P.Group, {
		key = props.key or "Menu",
		size = UDim2.fromOffset(width, gridHeight + gap + shopHeight),
		position = props.position,
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex,
		children = {
			e(P.Group, {
				key = "MenuGrid",
				size = UDim2.new(1, 0, 0, gridHeight),
				children = children,
			}),
			e(Buttons.WideMenuButton, {
				key = "ShopButton",
				text = Parts.SHOP.text,
				glyph = "basket",
				accent = Theme.Gradient.Pink,
				gradient = ColorSequence.new(Color3.fromHex("2B3E5E"), Color3.fromHex("16273F")),
				-- No `glow`: the gold ring it draws sat outside the slab's own
				-- outline and read as a second, mismatched border.
				isNew = Parts.SHOP.isNew,
				newText = Parts.SHOP.newText,
				wiggle = Parts.SHOP.wiggle,
				-- Offset, not scale: `WideMenuButton` reads `size.X.Offset` to work
				-- out how many studs fit, and a scale width reports 0 -- which is
				-- why this slab showed a single column of studs on its left edge.
				size = UDim2.fromOffset(width, shopHeight),
				position = UDim2.fromScale(0, 1),
				anchorPoint = Vector2.new(0, 1),
				flatIcon = true,
				iconSize = math.floor(shopHeight * 0.78),
				textSize = if props.compact then Theme.TextSize.Body else Theme.TextSize.Heading,
				onClick = function()
					if props.onOpen then
						props.onOpen("shop")
					end
				end,
			}),
		},
	})
end

--------------------------------------------------------------------------------
-- UtilityRow
--------------------------------------------------------------------------------

function Parts.UtilityRow(props)
	local extent = props.extent or 46
	local children = {
		P.list({
			direction = props.direction or Enum.FillDirection.Horizontal,
			padding = props.gap or 8,
		}),
	}

	for index, item in ipairs(Parts.UTILITY_ITEMS) do
		children[#children + 1] = e(Buttons.IconButton, {
			key = item.id,
			glyph = item.glyph,
			variant = item.variant,
			extent = extent,
			glyphScale = 0.5,
			layoutOrder = index,
			onClick = function()
				if props.onOpen then
					props.onOpen(item.id)
				end
			end,
		})
	end

	local count = #Parts.UTILITY_ITEMS
	local span = count * extent + (count - 1) * (props.gap or 8)
	local horizontal = (props.direction or Enum.FillDirection.Horizontal)
		== Enum.FillDirection.Horizontal

	return e(P.Group, {
		key = props.key or "Utility",
		size = if horizontal
			then UDim2.fromOffset(span, extent)
			else UDim2.fromOffset(extent, span),
		position = props.position,
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex,
		children = children,
	})
end

--------------------------------------------------------------------------------
-- CurrencyStack
--------------------------------------------------------------------------------

--[[
	The bottom-left readout, in the order the authored HUD had it: gears, then
	rebirths, then cash as the big greenish number nearest the corner.

	Cash keeps its original look exactly -- `Theme.Font.Money` and
	`Theme.Gradient.Money` were both lifted off the authored `MoneyValue` label.

	props: cash, gears, prestige, width, compact
]]
function Parts.CurrencyStack(props)
	local width = props.width or 216
	local height = props.height or 46
	local compact = props.compact == true
	local horizontal = props.direction == Enum.FillDirection.Horizontal
	-- Cash is the big number, except in a horizontal row where three different
	-- heights would leave the chips ragged.
	local cashHeight = if compact or horizontal then height else 62

	local rows = {
		e(Indicators.StatPill, {
			key = "Gears",
			glyph = "gear",
			value = Format.comma(props.gears or 0),
			iconGradient = Theme.Gradient.Gold,
			width = width,
			height = height,
			textSize = if compact then Theme.TextSize.Body else Theme.TextSize.Value,
			layoutOrder = 1,
		}),
		e(Indicators.StatPill, {
			key = "Rebirths",
			glyph = "recycle",
			value = Format.comma(props.prestige or 0),
			iconGradient = Theme.Gradient.Purple,
			width = width,
			height = height,
			textSize = if compact then Theme.TextSize.Body else Theme.TextSize.Value,
			layoutOrder = 2,
		}),
		e(Indicators.StatPill, {
			key = "Cash",
			-- No icon: the authored HUD's cash readout was the number alone, and
			-- the gradient is what identifies it.
			value = Format.money(props.cash or 0),
			gradient = Theme.Gradient.Money,
			font = Theme.Font.Money,
			width = width,
			height = cashHeight,
			textSize = if cashHeight < 62 then Theme.TextSize.Heading else Theme.TextSize.Hero,
			layoutOrder = 3,
		}),
	}

	local gap = props.gap or 8
	local count = #rows

	return e(P.Group, {
		key = props.key or "Currencies",
		size = if horizontal
			then UDim2.fromOffset(count * width + (count - 1) * gap, height)
			else UDim2.fromOffset(width, height * 2 + cashHeight + gap * 2),
		position = props.position,
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex,
		layout = P.list({
			direction = props.direction or Enum.FillDirection.Vertical,
			padding = gap,
		}),
		children = rows,
	})
end

--------------------------------------------------------------------------------
-- Shop slab
--------------------------------------------------------------------------------

--[[
	The wide SHOP slab. Everything you are likely to want to flip on it lives
	here rather than buried in `MenuGrid` below:

		isNew   shows the red NEW! flag on the corner -- set false when it is not
		wiggle  occasional attention nudge; a table overrides the timing, e.g.
		        `{ every = 4, angle = 6 }` for faster and wider
]]
Parts.SHOP = {
	text = "SHOP",
	isNew = true,
	newText = "NEW!",
	wiggle = { every = 7, angle = 4 },
}

--[[
	Named looks for the potion tiles. All of them run **top to bottom**:
	`P.gradient` rotates 90 degrees, so keypoint 0 is the top edge and keypoint 1
	is the bottom.

		Fade    the default -- half opacity along the top edge fading to **fully
		        invisible** at the bottom, so the tile reads as shading over the
		        game rather than a panel sitting on top of it. No outline: a border
		        around a slab that fades out only draws attention to the box that
		        is supposed to be disappearing.
		Solid   a flat two-tone wash, opaque, outlined like the rest of the kit
		Glass   a wider light-to-dark sweep at a fixed transparency

	There is deliberately no plate-art variant. `Assets.Plates.statPill` -- what the
	cash and gears readouts wear -- is a **wide** pill, and stretching it into a
	square tile turns its left-to-right shading into a dark centre fading out both
	ways. It looked wrong twice before being removed; do not add it back here.
]]
Parts.BOOST_VARIANTS = {
	Fade = {
		color = Theme.Color.PanelDark,
		gradient = Theme.Gradient.PanelDeep,
		--[[
			Top edge sits at half opacity, not near-solid: the tile is shading over
			the game view, so even its strongest point should let the scene read
			through. Keypoint 0 is the top because `P.gradient` rotates 90 degrees.
		]]
		gradientTransparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		}),
		--- `stroke`, not `strokeThickness`: this is a variant table BoostTile reads as `look.stroke`.
		stroke = 0,
	},
	Solid = {
		color = Theme.Color.PanelDark,
		gradient = Theme.Gradient.PanelDeep,
		transparency = 0,
	},
	Glass = {
		color = Theme.Color.PanelDark,
		gradient = Theme.Gradient.Glass,
		transparency = 0.18,
	},
}

--- Tile defaults. `variant` indexes `BOOST_VARIANTS`.
Parts.BOOSTS = {
	extent = 62,
	variant = "Fade",
}

--------------------------------------------------------------------------------
-- StorageMeter
--------------------------------------------------------------------------------

--[[
	THREE SIZES OF THE SAME READOUT. `variant`:

		Panel     the original: a studded window with a title line, an estimate and a fat bar
		Compact   the same window, tighter -- what mobile used via the old `compact` flag
		Slim      one bar and nothing else. No panel, no separate title line.

	`Slim` exists because the HUD is drawn 25% larger than it is authored (`Theme.ScaleBoost`), and at
	that size the panel version is a slab: 560x96 authored is 700x120 real pixels across the bottom of
	the screen, for two numbers. Slim folds the title, the fraction and the estimate INTO the bar and
	drops the chrome, so the same information takes a third of the room.

	`compact = true` is still honoured and maps to `Compact`, because callers outside this file pass it.

	props: storage, capacity, value (estimated cash), onSell (adds an inline sell button, used on
	mobile), variant, compact
]]
Parts.STORAGE_VARIANTS = table.freeze({ "Panel", "Compact", "Slim" })

function Parts.StorageMeter(props)
	local storage = props.storage or 0
	local capacity = props.capacity or 1
	local full = storage >= capacity
	local variant = props.variant or (if props.compact == true then "Compact" else "Panel")
	local compact = variant == "Compact"

	if variant == "Slim" then
		--[[
			ONE BAR, LABELLED INSIDE ITSELF.

			The bar already draws its own value text, so the fraction comes free; the caption goes to its
			left and the cash estimate to its right, both inside the same track. Nothing here is a panel,
			which is the point -- a bar reads as a gauge, and a gauge does not need a box around it to be
			understood.
		]]
		local height = props.height or 30
		return e(P.Group, {
			key = props.key or "Storage",
			size = props.size or UDim2.fromOffset(360, height),
			position = props.position,
			anchorPoint = props.anchorPoint,
			zIndex = props.zIndex,
			children = {
				e(Indicators.ProgressBar, {
					key = "Bar",
					value = storage,
					max = capacity,
					height = height,
					gradient = if full then Theme.Gradient.Red else Theme.Gradient.Cyan,
					fullText = "FULL",
					size = UDim2.fromScale(1, 1),
					zIndex = 2,
				}),
				--- Over the track, not beside it: the label is part of the gauge.
				e(P.Label, {
					key = "Caption",
					text = if full then "FULL" else "SCRAP",
					textSize = Theme.TextSize.Tiny,
					font = Theme.Font.Bold,
					color = if full then Theme.Color.White else Theme.Color.Gray,
					align = Enum.TextXAlignment.Left,
					size = UDim2.new(0.4, -12, 1, 0),
					position = UDim2.fromOffset(12, 0),
					zIndex = 4,
				}),
				e(P.Label, {
					key = "Estimate",
					text = Format.money(props.value or 0),
					textSize = Theme.TextSize.Tiny,
					font = Theme.Font.Bold,
					color = Theme.Color.Gold,
					align = Enum.TextXAlignment.Right,
					size = UDim2.new(0.4, -12, 1, 0),
					position = UDim2.new(1, -12, 0, 0),
					anchorPoint = Vector2.new(1, 0),
					zIndex = 4,
				}),
			},
		})
	end

	local barHeight = if compact then 26 else 34
	local hasSell = props.onSell ~= nil
	local sellWidth = if hasSell then 108 else 0

	local children = P.compact(
		P.padding({ x = 14, y = if compact then 8 else 10 }, "Inset"),
		e(P.Label, {
			key = "Title",
			text = if full then "STORAGE FULL!" else "SCRAP STORAGE",
			textSize = if compact then Theme.TextSize.Small else Theme.TextSize.Body,
			color = if full then Theme.Color.Red else Theme.Color.White,
			align = Enum.TextXAlignment.Left,
			size = UDim2.new(1, -sellWidth, 0, if compact then 18 else 22),
			zIndex = 3,
		}),
		e(P.Label, {
			key = "Estimate",
			text = "EST. VALUE " .. Format.moneyExact(props.value or 0),
			textSize = if compact then Theme.TextSize.Tiny else Theme.TextSize.Small,
			font = Theme.Font.Bold,
			color = Theme.Color.Gold,
			align = Enum.TextXAlignment.Right,
			size = UDim2.new(0.6, -sellWidth, 0, if compact then 18 else 22),
			position = UDim2.new(1, -sellWidth, 0, 0),
			anchorPoint = Vector2.new(1, 0),
			zIndex = 3,
		}),
		e(Indicators.ProgressBar, {
			key = "Bar",
			value = storage,
			max = capacity,
			height = barHeight,
			gradient = Theme.Gradient.Cyan,
			fullText = "FULL",
			size = UDim2.new(1, -sellWidth, 0, barHeight),
			position = UDim2.fromScale(0, 1),
			anchorPoint = Vector2.new(0, 1),
			zIndex = 3,
		}),
		if hasSell
			then e(Buttons.Button, {
				key = "SellButton",
				text = "SELL",
				variant = if full then "Purchase" else "Primary",
				textSize = Theme.TextSize.Small,
				size = UDim2.new(0, sellWidth - 12, 1, -4),
				position = UDim2.fromScale(1, 0.5),
				anchorPoint = Vector2.new(1, 0.5),
				zIndex = 4,
				onClick = props.onSell,
			})
			else nil
	)

	return e(P.Panel, {
		key = props.key or "Storage",
		size = props.size or UDim2.fromOffset(560, if compact then 78 else 96),
		position = props.position,
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex,
		radius = Theme.Radius.Card,
		color = Theme.Color.Panel,
		gradient = Theme.Gradient.Panel,
		strokeColor = if full then Theme.Color.Red else Theme.Color.Outline,
		strokeThickness = Theme.Stroke.Card,
		studSpacing = 26,
		children = children,
	})
end

--------------------------------------------------------------------------------
-- BoostTimers
--------------------------------------------------------------------------------

--[[
	One active potion: bottle on a top-to-bottom scrim, with the time left directly
	underneath. Hovering names the potion
	and says what it does, because an icon and a countdown alone never do.

	props:
		label, description, image, seconds   what the tile shows
		variant          key into `Parts.BOOST_VARIANTS`, default `BOOSTS.variant`
		color / gradient / transparency      override the variant piecemeal
		tooltipVisible   holds the tooltip open; UI Labs cannot hover, so the story
		                 uses this to style it
		extent, layoutOrder
]]
local function BoostTile(props)
	local extent = props.extent or Parts.BOOSTS.extent
	local look = Parts.BOOST_VARIANTS[props.variant or Parts.BOOSTS.variant]
		or Parts.BOOST_VARIANTS.Fade

	--[[
		Bottle, then timer directly beneath it with no gap. The timer used to be
		pinned to the tile's bottom edge, which left a dead band under the bottle;
		the tile is now exactly as tall as its contents.
	]]
	local bottleExtent = extent - 14
	local timerHeight = 18
	local tileHeight = 4 + bottleExtent + timerHeight
	--[[
		A TextButton, not a Frame with MouseEnter: Roblox only routes hover to a
		Frame when nothing interactive sits above it, and the panel's own highlight
		and gloss layers do. `usePressable` is the same hover path every other
		button in the kit uses, so this behaves identically.
	]]
	local press = Motion.usePressable({ hoverScale = 1.06, pressScale = 1 })

	local rootProps = {
		key = props.key,
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(extent, tileHeight),
		LayoutOrder = props.layoutOrder,
	}
	for event, handler in pairs(press.events) do
		rootProps[event] = handler
	end

	local slabProps = {
		key = "Slab",
		size = UDim2.fromScale(1, 1),
		radius = Theme.Radius.Chip,
		color = props.color or look.color,
		gradient = props.gradient or look.gradient,
		gradientTransparency = look.gradientTransparency,
		-- `or` would swallow a deliberate 0, so test for nil.
		transparency = if props.transparency ~= nil then props.transparency else look.transparency,
		-- A variant can drop the outline; `or` would swallow a deliberate 0.
		strokeThickness = if look.stroke ~= nil then look.stroke else Theme.Stroke.Chip,
		studs = false,
	}

	local slabChildren = P.compact(
		e("UIScale", { key = "Scale", Scale = press.scale }),
		e(Icon, {
			key = "Bottle",
			glyph = "potion",
			image = props.image,
			plain = props.image ~= nil,
			size = UDim2.fromOffset(bottleExtent, bottleExtent),
			position = UDim2.new(0.5, 0, 0, 4),
			anchorPoint = Vector2.new(0.5, 0),
			zIndex = 3,
		}),
		e(P.Label, {
			key = "Timer",
			text = Format.timer(props.seconds),
			textSize = Theme.TextSize.Small,
			color = Theme.Color.Gold,
			size = UDim2.new(1, -6, 0, timerHeight),
			-- Straight under the bottle, not pinned to the bottom edge.
			position = UDim2.fromOffset(3, 4 + bottleExtent),
			zIndex = 3,
		}),
		-- Opens upward: the row sits in the bottom-right corner, so a
		-- tooltip growing down or right would run off the screen. Anchored
		-- on its right edge for the same reason.
		if press.hovered or props.tooltipVisible
			then e(Overlays.Tooltip, {
				key = "Tip",
				title = props.label,
				body = props.description,
				-- The tile's own fill, so a translucent tile cannot end up with a
				-- near-solid tooltip hanging off it.
				look = look,
				width = 280,
				position = UDim2.new(1, 0, 0, -10),
				anchorPoint = Vector2.new(1, 1),
				zIndex = Theme.Layer.Tooltip,
			})
			else nil
	)

	slabProps.children = slabChildren

	return e("TextButton", rootProps, { e(P.Panel, slabProps) })
end

Parts.BoostTile = BoostTile

--[[
	The active-potion row. Renders nothing at all when no boost is running, so it
	costs no space in the corner it shares with the topbar.

	props: boosts, extent, gap, position, anchorPoint
]]
function Parts.BoostTimers(props)
	local boosts = props.boosts or {}
	if #boosts == 0 then
		return nil
	end

	local extent = props.extent or Parts.BOOSTS.extent
	local gap = props.gap or 8

	local tiles = {}
	for index, boost in ipairs(boosts) do
		tiles[#tiles + 1] = e(BoostTile, {
			key = boost.id,
			label = boost.label,
			description = boost.description,
			image = boost.image,
			seconds = boost.seconds,
			extent = extent,
			variant = props.variant,
			transparency = props.transparency,
			tooltipVisible = props.tooltipVisible and index == 1,
			layoutOrder = index,
		})
	end

	return e(P.Group, {
		key = props.key or "Boosts",
		size = UDim2.fromOffset(#tiles * extent + (#tiles - 1) * gap, 4 + (extent - 14) + 18),
		position = props.position,
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex,
		layout = P.list({
			direction = Enum.FillDirection.Horizontal,
			padding = gap,
			hAlign = Enum.HorizontalAlignment.Right,
		}),
		children = tiles,
	})
end

--------------------------------------------------------------------------------
-- EventBanner
--------------------------------------------------------------------------------

--[[
	props:
		title, detail, glyph, accent   the event, resolved by the store from EventConfig
		seconds                        time left if live, time until start if not
		live                           false renders the muted "next event" state

	NO DEFAULTS FOR THE CONTENT. This component used to fall back to "SCRAP RUSH EVENT -- 3x scrap
	value in every area" with an invented countdown, and it was rendered with no props at all, so every
	player permanently saw an event that did not exist (audit 3.3). A banner with nothing to say must
	not be rendered at all, and the callers now decide that.
]]
function Parts.EventBanner(props)
	--[[
		LONGER THAN IT LOOKS LIKE IT NEEDS TO BE, on purpose.

		The fade eats both ends -- the outer fifth of the strip is nearly transparent -- so a banner sized
		to its text has almost no readable middle left. At 700 the title and the countdown both sit in the
		opaque part with room between them, which is what the extra width buys.
	]]
	local width = props.width or 700
	local height = props.height or 56
	local iconExtent = height - 14
	local timerWidth = 104
	--[[
		LIVE VERSUS UPCOMING, in one component.

		A banner that appears only during an event teaches nobody the cadence, and the cadence is the
		whole point of a schedule (audit 3.7). So an upcoming event still shows, in the muted grey
		treatment, counting down to when it opens -- and the live one takes the event's own accent so
		there is no mistaking which state you are looking at.
	]]
	local live = props.live ~= false
	local accentName = props.accent or "Cyan"
	local accent = if live then (Theme.Color[accentName] or Theme.Color.Cyan) else Theme.Color.Gray
	local accentGradient = if live
		then (Theme.Gradient[accentName] or Theme.Gradient.Cyan)
		else Theme.Gradient.Gray

	--[[
		TWO LOOKS, ONE SWITCH. `Theme.Variant.EventBanner` picks the default; `props.variant` overrides
		it for a single instance, which is what the story uses to show both at once.

			"fade"   the spin-reward treatment -- accent dissolving to both edges, no outline
			"panel"  the outlined dark slab the rest of the HUD uses

		The countdown badge goes in the fade banner's right slot either way, so the two differ only in
		their surface.
	]]
	--[[
		The countdown, and in the fade variant it is BARE: a clock glyph and the digits, no pill.

		A chip behind the timer gives it an edge to sit against, which is what you want on a dark card and
		exactly what you do not want on a strip whose whole idea is not having edges. The panel variant
		keeps the pill, because there it is sitting on a bordered slab and needs the separation.
	]]
	local fadeVariant = (props.variant or Theme.Variant.EventBanner) == "fade"
	local timer = e(Indicators.TimerBadge, {
		key = "Timer",
		seconds = props.seconds or 0,
		bare = fadeVariant,
		gradient = accentGradient,
		textSize = Theme.TextSize.Body,
		textColor = if live then Theme.Color.White else Theme.Color.Gray,
		size = if fadeVariant then UDim2.fromOffset(timerWidth, 26) else nil,
		position = UDim2.fromScale(1, 0.5),
		anchorPoint = Vector2.new(1, 0.5),
		zIndex = 4,
	})

	if fadeVariant then
		return e(FadeBanner.Banner, {
			key = props.key or "EventBanner",
			title = props.title,
			detail = props.detail,
			glyph = props.glyph,
			accent = if live then accentName else "Gray",
			--- Smaller than a reward banner's: this sits in the HUD all day, not for three seconds.
			titleSize = if height < 50 then Theme.TextSize.Small else Theme.TextSize.Body,
			detailColor = Theme.Color.Gray,
			width = width,
			height = height,
			right = timer,
			rightWidth = timerWidth,
			position = props.position,
			anchorPoint = props.anchorPoint,
			zIndex = props.zIndex,
		})
	end

	--[[
		Laid out, not hand-positioned. Every child used to be placed by absolute
		offsets computed against `width`, and any one of them could end up outside
		the panel when the width changed. Now: one horizontal auto-layout owns the
		icon and the text column, the timer is pinned to the right, and the panel
		clips -- so nothing can escape the banner no matter what size it is given.
	]]
	return e(P.Panel, {
		key = props.key or "EventBanner",
		size = UDim2.fromOffset(width, height),
		position = props.position,
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex,
		radius = Theme.Radius.Card,
		color = Theme.Color.PanelDark,
		gradient = Theme.Gradient.PanelDeep,
		-- strokeColor = accent,
		-- strokeThickness = Theme.Stroke.Card,
		studs = false,
		clip = true,
		children = {
			e(P.Group, {
				key = "Content",
				size = UDim2.new(1, -(timerWidth + 18), 1, 0),
				position = UDim2.fromOffset(7, 0),
				zIndex = 3,
				layout = P.list({
					direction = Enum.FillDirection.Horizontal,
					padding = 8,
					vAlign = Enum.VerticalAlignment.Center,
				}),
				children = {
					e(Icon, {
						key = "Icon",
						glyph = props.glyph or "star",
						gradient = accentGradient,
						size = UDim2.fromOffset(iconExtent, iconExtent),
						radius = Theme.Radius.Small,
						layoutOrder = 1,
						zIndex = 6,
					}),
					e(P.Group, {
						key = "Text",
						-- Fills whatever the icon leaves, so the labels can never be
						-- sized to a negative width.
						size = UDim2.new(1, -(iconExtent + 8), 1, -10),
						layoutOrder = 2,
						zIndex = 6,
						layout = P.list({ padding = 1, vAlign = Enum.VerticalAlignment.Center }),
						children = {
							e(P.Label, {
								key = "Title",
								zIndex = 7,
								text = props.title or "",
								textSize = if height < 50
									then Theme.TextSize.Small
									else Theme.TextSize.Body,
								color = accent,
								align = Enum.TextXAlignment.Left,
								size = UDim2.new(1, 0, 0, if height < 50 then 18 else 22),
								truncate = Enum.TextTruncate.AtEnd,
								layoutOrder = 1,
							}),
							e(P.Label, {
								key = "Detail",
								zIndex = 7,
								text = props.detail or "",
								textSize = if height < 50
									then Theme.TextSize.Tiny
									else Theme.TextSize.Small,
								font = Theme.Font.Bold,
								color = Theme.Color.Gray,
								align = Enum.TextXAlignment.Left,
								size = UDim2.new(1, 0, 0, if height < 50 then 16 else 20),
								truncate = Enum.TextTruncate.AtEnd,
								layoutOrder = 2,
							}),
						},
					}),
				},
			}),
			e(P.Group, {
				key = "TimerSlot",
				size = UDim2.fromOffset(timerWidth, height),
				position = UDim2.new(1, -10, 0.5, 0),
				anchorPoint = Vector2.new(1, 0.5),
				zIndex = 4,
				children = { timer },
			}),
		},
	})
end

--------------------------------------------------------------------------------
-- ContextActions
--------------------------------------------------------------------------------

--[[
	props: onHome, onSell, autoCollect (boolean or nil to hide), onToggleAuto,
	       full (storage full -> the sell button gets loud)
]]
function Parts.ContextActions(props)
	local width = props.width or 176
	local height = props.height or 50
	local gap = 8

	local rows = P.compact(
		if props.autoCollect ~= nil
			then e(P.Panel, {
				key = "AutoCollect",
				size = UDim2.fromOffset(width, 38),
				layoutOrder = 1,
				radius = Theme.Radius.Chip,
				color = Theme.Color.PanelDark,
				gradient = Theme.Gradient.PanelDeep,
				strokeThickness = Theme.Stroke.Chip,
				strokeColor = if props.autoCollect
					then Theme.Color.Positive
					else Theme.Color.Outline,
				studs = false,
				children = {
					e(Icon, {
						key = "Icon",
						glyph = "bolt",
						plain = true,
						glyphColor = if props.autoCollect
							then Theme.Color.Positive
							else Theme.Color.GrayDark,
						size = UDim2.fromOffset(22, 22),
						position = UDim2.new(0, 8, 0.5, 0),
						anchorPoint = Vector2.new(0, 0.5),
						zIndex = 3,
					}),
					e(P.Label, {
						key = "State",
						text = if props.autoCollect then "AUTO COLLECT ON" else "AUTO COLLECT OFF",
						textSize = Theme.TextSize.Tiny,
						color = if props.autoCollect
							then Theme.Color.Positive
							else Theme.Color.Gray,
						align = Enum.TextXAlignment.Left,
						size = UDim2.new(1, -40, 1, 0),
						position = UDim2.fromOffset(36, 0),
						zIndex = 3,
					}),
				},
			})
			else nil,
		e(Buttons.Button, {
			key = "SellButton",
			text = "SELL",
			glyph = "coin",
			variant = if props.full then "Purchase" else "Primary",
			size = UDim2.fromOffset(width, height),
			layoutOrder = 2,
			onClick = props.onSell,
		}),
		e(Buttons.Button, {
			key = "HomeButton",
			text = "HOME",
			glyph = "home",
			variant = "Secondary",
			size = UDim2.fromOffset(width, height),
			layoutOrder = 3,
			onClick = props.onHome,
		})
	)

	local total = 0
	for _, _ in ipairs(rows) do
		total += 1
	end

	return e(P.Group, {
		key = props.key or "ContextActions",
		size = UDim2.fromOffset(
			width,
			height * 2 + gap * (total - 1) + (if props.autoCollect ~= nil then 38 else 0)
		),
		position = props.position,
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex,
		layout = P.list({
			padding = gap,
			hAlign = Enum.HorizontalAlignment.Right,
			vAlign = Enum.VerticalAlignment.Bottom,
		}),
		children = rows,
	})
end

--------------------------------------------------------------------------------
-- StatusIcon: FriendBoost and SpinWheel
--------------------------------------------------------------------------------

--[[
	The bottom-right status cluster: a plain OUTLINED GLYPH with a small value under it, and a popup
	on hover. No button slab behind it -- the reference has bare icons sitting on the world, and a
	panel around them makes the corner look like a toolbar.

	The hover popup is the same `Overlays.Tooltip` the potion tiles use, so these read as the same
	class of thing: a passive status readout you can interrogate, not a menu entry.

	A `TextButton` root, not a Frame with MouseEnter. Roblox only routes hover to a Frame when nothing
	interactive sits above it, and `usePressable` is the hover path every other pressable in the kit
	uses -- see `BoostTile`, which learned this the hard way.
]]
local function StatusIcon(props)
	local extent = props.extent or 46
	local valueHeight = 16
	--[[
		`onClick` goes THROUGH `usePressable`, which wires `Activated` itself and gates it on
		`disabled`. Wiring `Activated` separately on the root would double-fire on some input paths.
	]]
	local press = Motion.usePressable({
		hoverScale = 1.08,
		pressScale = 0.96,
		onClick = props.onClick,
	})

	local rootProps = {
		key = props.key,
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(extent, extent + valueHeight),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}
	for event, handler in pairs(press.events) do
		rootProps[event] = handler
	end

	return e(
		"TextButton",
		rootProps,
		P.compact(
			e("UIScale", { key = "Scale", Scale = press.scale }),
			--[[
				`plain` draws the glyph with no tile behind it. The glyph art already carries the heavy
				dark outline the house style wants, so it reads as an outlined icon on its own.
			]]
			e(Icon, {
				key = "Glyph",
				glyph = props.glyph,
				plain = true,
				size = UDim2.fromOffset(extent, extent),
				zIndex = 2,
			}),
			--[[
				The value sits DIRECTLY under the glyph, not pinned to the root's bottom edge -- "at the
				bottom but not too far", which is what the reference does. The root is exactly as tall as
				glyph plus value, so there is no dead band to fall through.
			]]
			e(P.Label, {
				key = "Value",
				text = props.value,
				textSize = Theme.TextSize.Small,
				color = props.valueColor or Theme.Color.White,
				position = UDim2.fromOffset(0, extent - 2),
				size = UDim2.new(1, 0, 0, valueHeight),
				zIndex = 3,
			}),
			--[[
				A WARNING DOT, NOT A COUNT.

				This was `Indicators.Badge` with text in it, which made the icon look like a message inbox
				with three unread items -- and the number was never useful: the spin icon already prints its
				count underneath, and "1" on the daily icon says nothing that the icon lighting up does not.

				What a player needs from the corner of an icon is one bit: something here needs you. So it
				is a red disc with an exclamation and nothing else, and any caller that has a real count
				puts it in `value`, under the icon, where the spin count already lives.
			]]
			if props.attention
				then e(P.Panel, {
					key = "Attention",
					size = UDim2.fromOffset(18, 18),
					position = UDim2.new(1, 3, 0, -3),
					anchorPoint = Vector2.new(1, 0),
					gradient = Theme.Gradient.Red,
					radius = 9,
					strokeThickness = 2.5,
					studs = false,
					zIndex = 5,
					children = {
						e(P.Label, {
							key = "Mark",
							text = "!",
							textSize = Theme.TextSize.Micro,
							color = Theme.Color.White,
							--- The disc is 18px: a text outline at this size fills it in and loses the mark.
							stroke = false,
							size = UDim2.fromScale(1, 1),
							zIndex = 2,
						}),
					},
				})
				else nil,
			--[[
				Opens UP and to the LEFT. The cluster lives in the bottom-right corner, so a tooltip
				growing down or right runs off the screen -- the same reasoning `BoostTile` uses, which
				shares that corner.
			]]
			if press.hovered or props.tooltipVisible
				then e(Overlays.Tooltip, {
					key = "Tip",
					title = props.tipTitle,
					body = props.tipBody,
					width = 260,
					position = UDim2.new(1, 6, 0, -10),
					anchorPoint = Vector2.new(1, 1),
					zIndex = Theme.Layer.Tooltip,
				})
				else nil
		)
	)
end

Parts.StatusIcon = StatusIcon

--[[
	Friend boost. +10% money per friend in this server.

	Shown at zero friends too, deliberately: "+0%" beside a friend icon is an invitation. Hiding it
	until you already have friends means the player who most needs the nudge never sees it -- and the
	hover popup is where the mechanic gets explained, which is why it exists at zero.
]]
function Parts.FriendBoost(props)
	local count = props.count or 0
	local boost = props.boost or 0
	local percent = math.floor(boost * 100 + 0.5)
	local active = count > 0

	return e(StatusIcon, {
		key = props.key or "FriendBoost",
		glyph = props.glyph or "friends",
		extent = props.extent,
		value = `+{percent}%`,
		valueColor = if active then Theme.Color.Cash else Theme.Color.GrayDark,
		--[[
			No dot here at all. A friend boost is not something to act on -- it is a readout of who is
			already in the server -- and the percentage under the glyph is the fact worth showing.
		]]
		tipTitle = "FRIEND BOOST",
		tipBody = if active
			then `+{percent}% money from {count} friend{if count == 1 then "" else "s"} in this server. Bring more and it climbs.`
			else "Play with friends in the same server for +10% money each. Nobody here yet.",
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex,
		tooltipVisible = props.tooltipVisible,
		onClick = props.onClick,
	})
end

--[[
	Spin wheel.

	The banked count is the number that matters and it sits UNDER the glyph, where every other status
	icon puts its value. It used to be repeated in a red corner dot as well, which is the same figure
	twice and made a full stash look like an error.
]]
function Parts.SpinWheel(props)
	local spins = props.spins or 0
	local ready = spins > 0

	return e(StatusIcon, {
		key = props.key or "SpinWheel",
		glyph = props.glyph or "wheel",
		extent = props.extent,
		value = if ready then `{spins}` else "-",
		valueColor = if ready then Theme.Color.Gold else Theme.Color.GrayDark,
		tipTitle = "DAILY SPIN",
		tipBody = if ready
			then `{spins} spin{if spins == 1 then "" else "s"} ready. Top prize is the God Potion.`
			else "No spins left. One free spin every day, and the calendar hands out more.",
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex,
		tooltipVisible = props.tooltipVisible,
		onClick = props.onClick,
	})
end

--[[
	Daily login reward, and the LOGIN BOOST it is worth.

	The streak's cash bonus is the value under the glyph, which is the point: the calendar is not just
	a free gift, it is a standing multiplier you keep by turning up. Showing "+15%" states that where a
	calendar icon on its own says nothing about why you should care.

	The dot is a bare "!" rather than a number, because the interesting fact is binary -- there is
	something to claim, or there is not.
]]
function Parts.DailyBoost(props)
	local streak = props.streak or 0
	local percent = props.boostPercent or 0
	local claimable = props.claimable == true

	--[[
		THE VALUE LINE ANSWERS "WHEN", NOT "WHAT".

		It used to read `+12%`, which is the streak bonus -- true, but the tooltip already says it, and it
		tells a player nothing they can act on. When the reward is waiting the line says so; when it is
		not, it says how long until the next one. The percent stays in the tooltip.
	]]
	return e(StatusIcon, {
		key = props.key or "DailyBoost",
		glyph = props.glyph or "calendar",
		extent = props.extent,
		value = if claimable then "READY" else Format.timer(props.resetSeconds or 0),
		valueColor = if claimable then Theme.Color.Positive else Theme.Color.Gray,
		--- One bit: the reward is waiting. The value line already says how long until the next one.
		attention = claimable,
		tipTitle = "DAILY LOGIN",
		tipBody = if claimable
			then `Reward ready to claim. Streak {streak} day{if streak == 1 then "" else "s"}, worth +{percent}% cash -- keep it going and it climbs.`
			else `Streak {streak} day{if streak == 1 then "" else "s"}, worth +{percent}% cash. Come back tomorrow to keep it.`,
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex,
		tooltipVisible = props.tooltipVisible,
		onClick = props.onClick,
	})
end

--[[
	The three of them as one cluster, laid out rather than hand-positioned so a fourth status icon
	costs one entry instead of four offsets.

	Order is deliberate: DAILY first because it is the one with something to claim, then the friend
	boost, then the wheel. Reading left to right that is "what can I collect, what am I earning, what
	can I gamble".
]]
function Parts.StatusCluster(props)
	local extent = props.extent or 46
	local gap = props.gap or 10

	return e(P.Group, {
		key = props.key or "StatusCluster",
		size = UDim2.fromOffset(extent * 3 + gap * 2, extent + 16),
		position = props.position,
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex,
		layout = P.list({
			direction = Enum.FillDirection.Horizontal,
			padding = gap,
			hAlign = Enum.HorizontalAlignment.Left,
			vAlign = Enum.VerticalAlignment.Bottom,
		}),
		children = {
			e(Parts.DailyBoost, {
				key = "DailyBoost",
				streak = props.dailyStreak,
				boostPercent = props.dailyBoostPercent,
				claimable = props.dailyClaimable,
				resetSeconds = props.dailyResetSeconds,
				extent = extent,
				layoutOrder = 1,
				onClick = props.onOpenDaily,
			}),
			--[[
				NO `onClick`. The friend boost is a status readout whose interaction is the hover popup --
				wiring it to open some other window would be a lie about what the icon is.

				The obvious thing to put here is `SocialService:PromptGameInvite`, which is exactly the
				action the boost is asking for. It is left unwired because that API yields and needs a
				`CanSendGameInviteAsync` check, and this pass could not be Play-tested.
			]]
			e(Parts.FriendBoost, {
				key = "FriendBoost",
				count = props.friendCount,
				boost = props.friendBoost,
				extent = extent,
				layoutOrder = 2,
			}),
			e(Parts.SpinWheel, {
				key = "SpinWheel",
				spins = props.spinsAvailable,
				extent = extent,
				layoutOrder = 3,
				onClick = props.onOpenSpin,
			}),
		},
	})
end

--------------------------------------------------------------------------------
-- Tutorial: spotlight and caption
--------------------------------------------------------------------------------

--[[
	Darkens the screen and leaves ONE rectangle lit.

	FOUR PANELS AROUND A HOLE, not one panel with a hole in it. Roblox has no way to punch a hole in a
	frame -- no masking, no inverse clipping -- and the rotated-frame tricks that fake it break
	`ClipsDescendants` (rule 11). Four solid rectangles butted against the target's edges leave it
	untouched and are pixel-exact, which is what "highlight that one" needs.

	The lit control stays fully interactive because nothing is drawn over it. That matters: the step is
	completed by pressing the thing, so covering it with even a transparent panel would break the
	objective it is pointing at.

	`rect` is in design pixels: { x, y, width, height }.
]]
function Parts.TutorialSpotlight(props)
	local rect = props.rect
	if rect == nil then
		return nil
	end

	local x, y, width, height = rect[1], rect[2], rect[3], rect[4]
	local dim = props.transparency or 0.62
	local pad = props.padding or 8

	--- Panels are inset by the padding so the lit hole is slightly larger than the control itself.
	local left = x - pad
	local top = y - pad
	local right = x + width + pad
	local bottom = y + height + pad

	local function shade(key: string, position: UDim2, size: UDim2)
		return e("Frame", {
			key = key,
			BackgroundColor3 = Theme.Color.Ink,
			BackgroundTransparency = dim,
			BorderSizePixel = 0,
			Position = position,
			Size = size,
			ZIndex = 1,
		})
	end

	return e(P.Group, {
		key = props.key or "TutorialSpotlight",
		size = UDim2.fromScale(1, 1),
		zIndex = props.zIndex,
		children = {
			shade("Top", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, math.max(0, top))),
			shade("Bottom", UDim2.fromOffset(0, bottom), UDim2.new(1, 0, 1, -bottom)),
			shade(
				"Left",
				UDim2.fromOffset(0, top),
				UDim2.fromOffset(math.max(0, left), bottom - top)
			),
			shade("Right", UDim2.fromOffset(right, top), UDim2.new(1, -right, 0, bottom - top)),
			--[[
				A ring around the hole, so the lit area reads as chosen rather than as a gap in the dark.
				Background-transparent with a stroke, and non-interactive -- `Active = false` keeps it out
				of the input path so it cannot swallow the press it is advertising.
			]]
			e("Frame", {
				key = "Ring",
				BackgroundTransparency = 1,
				Active = false,
				Position = UDim2.fromOffset(left, top),
				Size = UDim2.fromOffset(right - left, bottom - top),
				ZIndex = 2,
			}, {
				e("UICorner", { key = "Corner", CornerRadius = UDim.new(0, Theme.Radius.Panel) }),
				e("UIStroke", {
					key = "Glow",
					Thickness = 4,
					Color = Theme.Color.Gold,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
			}),
		},
	})
end

--[[
	The onboarding objective: a caption, a progress chip, and SKIP.

	NOT A TUTORIAL DIALOG. Nothing blocks play and there is nothing to acknowledge. Complex onboarding
	backfires on Roblox, and at least one team raised retention by deleting theirs outright -- see
	`TutorialConfig`.

	Sized and placed to sit directly above the storage meter, which is where a player's eyes already
	are: they are watching that bar fill. It is deliberately large -- this is the one piece of text a
	new player has to read, and the previous version was a 420px strip lost under the travel bar.
]]
function Parts.TutorialCaption(props)
	local step = props.step
	local pulse = Motion.useWiggle({ every = 1.6, angle = 4, shakes = 2 })
	--[[
		Hooks run before the early return, always. Bailing above `useWiggle` on the frame the tutorial
		finishes would change the hook count between renders, which React treats as a different
		component and throws on.
	]]
	if step == nil then
		return nil
	end

	local width = props.width or 560
	local height = props.height or 104

	return e(P.Panel, {
		key = props.key or "TutorialCaption",
		size = UDim2.fromOffset(width, height),
		position = props.position,
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex,
		gradient = Theme.Gradient.Panel,
		radius = Theme.Radius.Panel,
		strokeThickness = Theme.Stroke.Panel,
		studs = true,
		children = P.compact(
			--[[
				The step chip doubles as the pointer: it nudges on a period so the caption has one moving
				element. Position only -- rotating it would let it escape a clipping ancestor (rule 11).
			]]
			e(P.Group, {
				key = "Step",
				size = UDim2.fromOffset(64, 64),
				position = pulse:map(function(offset: number)
					return UDim2.new(0, 16, 0.5, offset)
				end),
				anchorPoint = Vector2.new(0, 0.5),
				zIndex = 4,
				children = {
					e(P.Panel, {
						key = "Chip",
						size = UDim2.fromScale(1, 1),
						gradient = Theme.Gradient.Gold,
						radius = Theme.Radius.Card,
						strokeThickness = Theme.Stroke.Card,
						studs = false,
						children = {
							e(P.Label, {
								key = "Number",
								text = `{step.Index}/{props.total or 4}`,
								textSize = Theme.TextSize.Body,
								color = Theme.Color.Ink,
								position = UDim2.fromScale(0.5, 0.5),
								anchorPoint = Vector2.new(0.5, 0.5),
								size = UDim2.fromScale(1, 0.5),
							}),
						},
					}),
				},
			}),
			e(P.Label, {
				key = "Title",
				text = step.Title,
				textSize = Theme.TextSize.Heading,
				color = Theme.Color.White,
				align = Enum.TextXAlignment.Left,
				position = UDim2.fromOffset(94, 16),
				size = UDim2.fromOffset(width - 200, 30),
				zIndex = 4,
			}),
			e(P.Label, {
				key = "Detail",
				text = step.Detail,
				textSize = Theme.TextSize.Body,
				font = Theme.Font.Body,
				color = Theme.Color.Gray,
				align = Enum.TextXAlignment.Left,
				wrapped = true,
				position = UDim2.fromOffset(94, 48),
				size = UDim2.fromOffset(width - 210, 44),
				zIndex = 4,
			}),
			e(Buttons.Button, {
				key = "Skip",
				text = "SKIP",
				variant = "Neutral",
				textSize = Theme.TextSize.Tiny,
				size = UDim2.fromOffset(74, 30),
				position = UDim2.new(1, -14, 1, -12),
				anchorPoint = Vector2.new(1, 1),
				zIndex = 5,
				onClick = props.onSkip,
			})
		),
	})
end

return Parts
