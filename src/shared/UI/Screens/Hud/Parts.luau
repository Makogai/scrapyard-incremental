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
		FriendBoost     bottom-right friend icon: +10% money per friend in the server
		PlaytimeTrack   progress to the next playtime reward, with an inline claim
		TutorialCaption the current onboarding objective, with a bouncing arrow
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
-- TeleportBar
--------------------------------------------------------------------------------

--[[
	The three places `TeleportService.destinationFor` will actually send you. Ids
	are passed to the server verbatim, so they must match that function -- adding
	an entry here without adding a destination there is a button that does nothing.
]]
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

Parts.TELEPORT_ITEMS = {
	{ id = "Shop", text = "SHOP", glyph = "basket", variant = "Purchase" },
	{ id = "MyPlot", text = "MY PLOT", glyph = "home", variant = "Primary" },
	{ id = "Leaderboards", text = "LEADERBOARD", glyph = "trophy", variant = "Secondary" },
}

--[[
	One travel button. Deliberately a plain kit button rather than the authored
	plate art: those plates carry their own baked-in label and outline, which
	fights everything else on the HUD.
]]
local function TeleportButton(props)
	return e(Buttons.Button, {
		key = props.key,
		text = props.text,
		glyph = props.glyph,
		variant = props.variant or "Secondary",
		textSize = Theme.TextSize.Small,
		size = UDim2.fromOffset(props.width, props.height),
		lip = 4,
		layoutOrder = props.layoutOrder,
		onClick = props.onClick,
	})
end

Parts.TeleportButton = TeleportButton

--[[
	Top-centre travel row. It deliberately sits *in* the topbar strip rather than
	below it: Roblox's own chrome only occupies the left of that strip, the middle
	is free, and the event banner then hangs directly underneath.

	props: onTeleport(destinationId), width, height, gap
]]
function Parts.TeleportBar(props)
	local width = props.width or 150
	local height = props.height or 44
	local gap = props.gap or 8
	local items = props.items or Parts.TELEPORT_ITEMS

	local children = {
		P.list({
			direction = Enum.FillDirection.Horizontal,
			padding = gap,
			hAlign = Enum.HorizontalAlignment.Center,
			vAlign = Enum.VerticalAlignment.Center,
		}),
	}

	for index, item in ipairs(items) do
		children[#children + 1] = e(TeleportButton, {
			key = item.id,
			text = item.text,
			glyph = item.glyph,
			variant = item.variant,
			width = width,
			height = height,
			layoutOrder = index,
			onClick = function()
				if props.onTeleport then
					props.onTeleport(item.id)
				end
			end,
		})
	end

	return e(P.Group, {
		key = props.key or "TeleportBar",
		size = UDim2.fromOffset(#items * width + (#items - 1) * gap, height),
		position = props.position,
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex,
		children = children,
	})
end

--------------------------------------------------------------------------------
-- StorageMeter
--------------------------------------------------------------------------------

--[[
	props: storage, capacity, value (estimated cash), onSell (adds an inline
	sell button, used on mobile), compact
]]
function Parts.StorageMeter(props)
	local storage = props.storage or 0
	local capacity = props.capacity or 1
	local full = storage >= capacity
	local compact = props.compact == true

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

function Parts.EventBanner(props)
	local width = props.width or 520
	local height = props.height or 56
	local iconExtent = height - 14
	local timerWidth = 110

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
		strokeColor = Theme.Color.Cyan,
		strokeThickness = Theme.Stroke.Card,
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
						glyph = "star",
						gradient = Theme.Gradient.Cyan,
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
								text = props.title or "SCRAP RUSH EVENT",
								textSize = if height < 50
									then Theme.TextSize.Small
									else Theme.TextSize.Body,
								color = Theme.Color.Cyan,
								align = Enum.TextXAlignment.Left,
								size = UDim2.new(1, 0, 0, if height < 50 then 18 else 22),
								truncate = Enum.TextTruncate.AtEnd,
								layoutOrder = 1,
							}),
							e(P.Label, {
								key = "Detail",
								zIndex = 7,
								text = props.detail or "3x scrap value in every area",
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
			e(Indicators.TimerBadge, {
				key = "Timer",
				seconds = props.seconds or 2_734,
				gradient = Theme.Gradient.Cyan,
				position = UDim2.new(1, -10, 0.5, 0),
				anchorPoint = Vector2.new(1, 0.5),
				zIndex = 4,
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
	The bottom-left status cluster: a plain OUTLINED GLYPH with a small value under it, and a popup
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
			--- Count pip, top-right, only when there is something to count.
			if props.badge
				then e(Indicators.Badge, {
					key = "Badge",
					text = props.badge,
					gradient = props.badgeGradient or Theme.Gradient.Red,
					textSize = Theme.TextSize.Micro,
					position = UDim2.new(1, 4, 0, -2),
					anchorPoint = Vector2.new(1, 0),
					zIndex = 5,
				})
				else nil,
			--[[
				Opens UP and to the RIGHT: this cluster is in the bottom-left corner, so a tooltip
				growing down or left runs off the screen. The mirror of what `BoostTile` does in the
				bottom-right.
			]]
			if press.hovered or props.tooltipVisible
				then e(Overlays.Tooltip, {
					key = "Tip",
					title = props.tipTitle,
					body = props.tipBody,
					width = 260,
					position = UDim2.fromOffset(-6, -10),
					anchorPoint = Vector2.new(0, 1),
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
		badge = if active then tostring(count) else nil,
		badgeGradient = Theme.Gradient.Cyan,
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
	Spin wheel. The count of spins banked is the number that matters, so it is both the value under
	the glyph and the badge.
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
		badge = if ready then tostring(spins) else nil,
		badgeGradient = Theme.Gradient.Red,
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
	The two of them as one bottom-left cluster, laid out rather than hand-positioned so adding a third
	status icon later costs one entry instead of three offsets.
]]
function Parts.StatusCluster(props)
	local extent = props.extent or 46
	local gap = props.gap or 10

	return e(P.Group, {
		key = props.key or "StatusCluster",
		size = UDim2.fromOffset(extent * 2 + gap, extent + 16),
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
				layoutOrder = 1,
			}),
			e(Parts.SpinWheel, {
				key = "SpinWheel",
				spins = props.spinsAvailable,
				extent = extent,
				layoutOrder = 2,
				onClick = props.onOpenSpin,
			}),
		},
	})
end

--------------------------------------------------------------------------------
-- PlaytimeTrack
--------------------------------------------------------------------------------

--[[
	Progress toward the next playtime reward, with the claim button on the strip itself.

	ON THE HUD RATHER THAN IN A MENU, because playtime rewards are earned by doing nothing in
	particular: a milestone the player has to go looking for is one they never claim. The bar
	filling while they play IS the mechanic.

	Renders nothing once every milestone is claimed, rather than sitting there full forever.
]]
function Parts.PlaytimeTrack(props)
	local milestones = props.milestones or {}
	local claimed = props.claimed or {}
	local seconds = props.seconds or 0

	--- Only the first unclaimed milestone is worth showing.
	local target = nil
	for _, milestone in ipairs(milestones) do
		if claimed[milestone.Index] ~= true then
			target = milestone
			break
		end
	end
	if target == nil then
		return nil
	end

	local ready = seconds >= target.Seconds
	local progress = math.clamp(seconds / math.max(1, target.Seconds), 0, 1)
	local width = props.width or 250

	return e(P.Panel, {
		key = props.key or "PlaytimeTrack",
		size = UDim2.fromOffset(width, 46),
		position = props.position,
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex,
		gradient = Theme.Gradient.PanelDeep,
		radius = Theme.Radius.Card,
		strokeThickness = Theme.Stroke.Card,
		studs = false,
		children = {
			e(P.Label, {
				key = "Title",
				text = `PLAYTIME {target.Label}`,
				textSize = Theme.TextSize.Tiny,
				color = Theme.Color.Gray,
				align = Enum.TextXAlignment.Left,
				position = UDim2.fromOffset(10, 6),
				size = UDim2.fromOffset(140, 14),
			}),
			e(Indicators.ProgressBar, {
				key = "Bar",
				value = progress,
				max = 1,
				gradient = if ready then Theme.Gradient.Green else Theme.Gradient.Cyan,
				size = UDim2.new(1, -96, 0, 14),
				position = UDim2.fromOffset(10, 24),
			}),
			--[[
				Claim and countdown occupy the same reserved space, so the strip never changes width.
				A HUD element that resizes itself every few minutes is worse than one with a small gap.
			]]
			if ready
				then e(Buttons.Button, {
					key = "Claim",
					text = "CLAIM",
					variant = "Primary",
					textSize = Theme.TextSize.Tiny,
					size = UDim2.fromOffset(72, 30),
					position = UDim2.new(1, -8, 0.5, 0),
					anchorPoint = Vector2.new(1, 0.5),
					onClick = function()
						if props.onClaim then
							props.onClaim(target.Index)
						end
					end,
				})
				else e(P.Label, {
					key = "Remaining",
					text = Format.timer(target.Seconds - seconds),
					textSize = Theme.TextSize.Small,
					color = Theme.Color.Gray,
					align = Enum.TextXAlignment.Right,
					position = UDim2.new(1, -10, 0.5, 0),
					anchorPoint = Vector2.new(1, 0.5),
					size = UDim2.fromOffset(74, 20),
				}),
		},
	})
end

--------------------------------------------------------------------------------
-- TutorialCaption
--------------------------------------------------------------------------------

--[[
	The onboarding objective: one caption, one bouncing arrow, one SKIP.

	NOT A TUTORIAL DIALOG. Nothing blocks play, there is nothing to acknowledge, and the arrow
	points rather than explains. Complex onboarding backfires on Roblox, and at least one team
	raised retention by deleting theirs outright -- see `TutorialConfig`.

	The arrow bounces on POSITION only. Rotating it would be the obvious choice and is the wrong
	one: a rotated GuiObject ignores its ancestors' `ClipsDescendants` and can paint over the entire
	screen (AGENTS.md rule 11).
]]
function Parts.TutorialCaption(props)
	local step = props.step
	--[[
		`useWiggle` swings a number back to zero on a period. Used here as a vertical bob rather than
		a rotation, with a short period so the arrow is always moving -- an arrow that sits still for
		six seconds between hops reads as broken.
	]]
	local bounce = Motion.useWiggle({ every = 1.1, angle = 7, shakes = 2 })
	--[[
		Hooks run before the early return, always. Returning above `useWiggle` on the frame the
		tutorial finishes would change the hook count between renders, which React treats as a
		different component and throws on.
	]]
	if step == nil then
		return nil
	end

	local width = props.width or 420

	return e(P.Panel, {
		key = props.key or "TutorialCaption",
		size = UDim2.fromOffset(width, 78),
		position = props.position,
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex,
		gradient = Theme.Gradient.Panel,
		radius = Theme.Radius.Panel,
		strokeThickness = Theme.Stroke.Panel,
		studs = false,
		children = {
			--- Points down at the caption, and is the only moving thing on the strip.
			e(P.Label, {
				key = "Arrow",
				text = "▼",
				textSize = Theme.TextSize.Title,
				color = Theme.Color.Gold,
				position = bounce:map(function(offset: number)
					return UDim2.fromOffset(32, -26 + offset)
				end),
				anchorPoint = Vector2.new(0.5, 0),
				size = UDim2.fromOffset(40, 34),
				zIndex = 3,
			}),
			e(Indicators.Badge, {
				key = "Progress",
				text = `{step.Index}/{props.total or 4}`,
				gradient = Theme.Gradient.Gold,
				textSize = Theme.TextSize.Tiny,
				position = UDim2.fromOffset(10, 8),
				anchorPoint = Vector2.new(0, 0),
			}),
			e(P.Label, {
				key = "Title",
				text = step.Title,
				textSize = Theme.TextSize.Body,
				color = Theme.Color.White,
				align = Enum.TextXAlignment.Left,
				position = UDim2.fromOffset(62, 10),
				size = UDim2.fromOffset(width - 150, 22),
			}),
			e(P.Label, {
				key = "Detail",
				text = step.Detail,
				textSize = Theme.TextSize.Small,
				font = Theme.Font.Body,
				color = Theme.Color.Gray,
				align = Enum.TextXAlignment.Left,
				wrapped = true,
				position = UDim2.fromOffset(14, 36),
				size = UDim2.fromOffset(width - 100, 34),
			}),
			e(Buttons.Button, {
				key = "Skip",
				text = "SKIP",
				variant = "Neutral",
				textSize = Theme.TextSize.Tiny,
				size = UDim2.fromOffset(62, 26),
				position = UDim2.new(1, -10, 1, -8),
				anchorPoint = Vector2.new(1, 1),
				onClick = props.onSkip,
			}),
		},
	})
end

return Parts
