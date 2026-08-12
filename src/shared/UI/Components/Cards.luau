--[[
	Cards.luau
	Grid cells: everything that appears inside an ItemGrid.

		ItemCard        base inventory cell -- handles normal, locked, equipped
		                and consumable-quantity states
		MagnetCard      ItemCard preset for magnets
		PotionCard      ItemCard preset for potions (always shows owned count)
		PetCard         taller cell with a bonus line
		CosmeticCard    plot customisation cell with an inline action button
		CollectionCell  index cell with a discovered / undiscovered state
		EmptySlot       dashed placeholder for unfilled pet slots

	Layer order inside every card matches the design hierarchy:
		ItemCard > Face > RarityStripe / Artwork > Icon / Name / Rarity / Badges
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Format = require(UI.Format)
local Motion = require(UI.Motion)
local Sound = require(UI.Sound)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)
local ModelView = require(script.Parent.ModelView)
local SecretVFX = require(script.Parent.SecretVFX)
local Buttons = require(script.Parent.Buttons)
local Indicators = require(script.Parent.Indicators)

local e = React.createElement

local Cards = {}

--------------------------------------------------------------------------------
-- Shared card shell.
--
-- Grid cards use a FLAT SOLID face -- no gradient, no stud texture. They sit on
-- top of a studded window, so repeating that texture inside them made the cards
-- dissolve into their own background. A solid face plus the dark outline reads as
-- a separate physical tile, which is the point.
--
-- Same two-layer build as a button: solid darker Base underneath (the visible
-- bottom strip is colour, not an outline) and a Face with no stroke of its own.
--------------------------------------------------------------------------------

local function CardShell(props)
	local size = props.size or UDim2.fromOffset(152, 186)
	local radius = props.radius or Theme.Radius.Card
	local lip = props.lip or Theme.Lip.Card
	local accent: Color3? = props.accentColor
	local interactive = props.onClick ~= nil

	local press = Motion.usePressable({
		disabled = not interactive,
		hoverScale = Theme.Hover.CardScale,
		pressScale = 0.985,
		onHover = function()
			Sound.play("hover")
		end,
		onClick = function()
			Sound.play("tap")
			if props.onClick then
				props.onClick()
			end
		end,
	})

	local faceChildren = P.compact(
		P.corner(radius),
		if props.gradient then P.gradient(props.gradient) else nil,
		e(P.Highlight, {
			key = "Highlight",
			radius = radius,
			strength = props.highlight or 0.82,
			height = 0.3,
			zIndex = 2,
		}),
		if press.hovered
			then e("Frame", {
				key = "Hover",
				BackgroundColor3 = Theme.Color.White,
				BackgroundTransparency = 0.9,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 3,
			}, { P.corner(radius) })
			else nil
	)

	P.append(faceChildren, props.children)

	local rootProps = {
		key = props.key or "ItemCard",
		BackgroundTransparency = 1,
		Size = size,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}

	if interactive then
		rootProps.Text = ""
		rootProps.AutoButtonColor = false
		for event, handler in pairs(press.events) do
			rootProps[event] = handler
		end
	end

	return e(if interactive then "TextButton" else "Frame", rootProps, {
		e("Frame", {
			key = "Visual",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
		}, {
			e("UIScale", { key = "Scale", Scale = press.scale }),
			e("Frame", {
				key = "Base",
				BackgroundColor3 = props.baseColor or Theme.Color.CardBase,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
			}, {
				P.corner(radius),
				P.stroke(
					if props.selected then (accent or Theme.Color.Gold) else Theme.Color.Outline,
					if props.selected then 4 else Theme.Stroke.Card
				),
			}),
			e("Frame", {
				key = "Face",
				BackgroundColor3 = props.color or Theme.Color.Card,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 1, -lip),
				Position = press.sink:map(function(value)
					return UDim2.fromOffset(0, value * lip)
				end),
				ZIndex = 2,
			}, faceChildren),
		}),
	})
end

--------------------------------------------------------------------------------
-- ItemCard
--------------------------------------------------------------------------------

--[[
	props:
		name        string
		rarity      string       key into Theme.Rarity
		glyph       string?      procedural icon
		image       string?      real artwork
		quantity    number?      shows an "x12" pip
		equipped    boolean?     shows the green tick and an equipped tint
		locked      boolean?     dims the card and shows the padlock
		lockText    string?      "Unlock at Prestige 5"
		selected    boolean?     bright accent outline
		onClick     function?
		size        UDim2?
]]
function Cards.ItemCard(props)
	local style = Theme.rarity(props.rarity)
	local size = props.size or UDim2.fromOffset(152, 190)
	local artHeight = props.artHeight or 96

	local children = P.compact(
		-- Rarity stripe across the top: the fastest possible rarity read.
		e("Frame", {
			key = "RarityStripe",
			BackgroundColor3 = style.color,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -16, 0, 6),
			Position = UDim2.fromOffset(8, 8),
			ZIndex = 3,
		}, {
			P.corner(3),
			P.gradient(style.gradient, { rotation = 0 }),
		}),
		e(P.Slot, {
			key = "Artwork",
			size = UDim2.new(1, -16, 0, artHeight),
			position = UDim2.fromOffset(8, 20),
			zIndex = 3,
			children = {
				e(Icon, {
					key = "Icon",
					glyph = props.glyph,
					image = props.image,
					plain = true,
					size = UDim2.fromScale(0.62, 0.62),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					glyphColor = props.glyphColor,
					glyphAccent = props.glyphAccent,
					zIndex = 6,
				}),
			},
		}),
		e(P.Label, {
			key = "Name",
			text = props.name,
			textSize = props.nameSize or Theme.TextSize.Small,
			size = UDim2.new(1, -12, 0, 22),
			position = UDim2.fromOffset(6, artHeight + 26),
			truncate = Enum.TextTruncate.AtEnd,
			zIndex = 4,
		}),
		e(Indicators.RarityBadge, {
			key = "Rarity",
			rarity = props.rarity,
			position = UDim2.new(0.5, 0, 0, artHeight + 52),
			anchorPoint = Vector2.new(0.5, 0),
			zIndex = 4,
		}),
		if props.equipped
			then e(Indicators.Checkmark, {
				key = "Equipped",
				extent = 30,
				position = UDim2.new(1, -6, 0, 16),
				anchorPoint = Vector2.new(1, 0),
				zIndex = 8,
			})
			else nil,
		if props.quantity and props.quantity > 0
			then e(Indicators.QuantityBadge, {
				key = "Quantity",
				count = props.quantity,
				position = UDim2.fromOffset(14, artHeight + 4),
				anchorPoint = Vector2.new(0, 1),
				zIndex = 8,
			})
			else nil,
		if props.badge
			then e(Indicators.Badge, {
				key = "Badge",
				text = props.badge,
				gradient = props.badgeGradient or Theme.Gradient.Red,
				position = UDim2.fromOffset(6, 16),
				anchorPoint = Vector2.new(0, 0),
				zIndex = 8,
			})
			else nil,
		if props.locked
			then e(Indicators.LockOverlay, {
				key = "LockOverlay",
				text = props.lockText,
				radius = Theme.Radius.Card,
				zIndex = 10,
			})
			else nil
	)

	return e(CardShell, {
		key = props.key or "ItemCard",
		size = size,
		layoutOrder = props.layoutOrder,
		position = props.position,
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex,
		selected = props.selected or props.equipped,
		accentColor = if props.equipped then Theme.Color.Positive else style.color,
		locked = props.locked,
		onClick = props.onClick,
		gradient = props.gradient,
		children = children,
	})
end

--- Magnets always show their range so the grid is comparable at a glance.
function Cards.MagnetCard(props)
	return e(Cards.ItemCard, {
		key = props.key or props.name,
		name = props.name,
		rarity = props.rarity,
		glyph = props.glyph or "magnet",
		glyphColor = Theme.rarity(props.rarity).color,
		image = props.image,
		equipped = props.equipped,
		locked = props.locked,
		lockText = props.lockText,
		selected = props.selected,
		layoutOrder = props.layoutOrder,
		size = props.size,
		onClick = props.onClick,
	})
end

--- Potions are consumables, so the owned count is never optional.
function Cards.PotionCard(props)
	return e(Cards.ItemCard, {
		key = props.key or props.name,
		name = props.name,
		rarity = props.rarity,
		glyph = props.glyph or "potion",
		glyphAccent = props.tint,
		quantity = props.owned or 0,
		locked = props.locked or (props.owned or 0) <= 0,
		lockText = if (props.owned or 0) <= 0 then "NONE OWNED" else props.lockText,
		selected = props.selected,
		layoutOrder = props.layoutOrder,
		size = props.size,
		onClick = props.onClick,
	})
end

--------------------------------------------------------------------------------
-- PetCard
--------------------------------------------------------------------------------

--[[
	props: name, rarity, bonus ("+12% Scrap Value"), glyph, equipped, locked,
	       lockText, onClick
]]
--[[
	A pet in the collection.

	Shows the real model rather than a glyph -- the Pets window used to render the
	same paw for every entry, which made a collection of seven pets look like seven
	copies of nothing. The preview takes most of the card, and the labels underneath
	are sized to fit exactly what is left.

	Legendary and Secret carry the animated VFX layer, so the two top rarities stand
	out from a grid at a glance.
]]
local VFX_RARITIES = { Legendary = "Gold", Secret = "Secret" }

function Cards.PetCard(props)
	local style = Theme.rarity(props.rarity)
	local size = props.size or UDim2.fromOffset(158, 196)
	local artHeight = 130
	local vfxPalette = VFX_RARITIES[props.rarity]

	local children = P.compact(
		e("Frame", {
			key = "RarityStripe",
			BackgroundColor3 = style.color,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -16, 0, 6),
			Position = UDim2.fromOffset(8, 8),
			ZIndex = 3,
		}, {
			P.corner(3),
			P.gradient(style.gradient, { rotation = 0 }),
		}),
		-- Behind the preview, inside the card: only for the two top rarities.
		if vfxPalette
			then e(SecretVFX.Layer, {
				key = "VFX",
				palette = vfxPalette,
				size = UDim2.new(1, -10, 0, artHeight + 4),
				position = UDim2.new(0.5, 0, 0, 13),
				anchorPoint = Vector2.new(0.5, 0),
				zIndex = 2,
			})
			else nil,
		e(ModelView.View, {
			key = "Preview",
			kind = "pet",
			model = props.model,
			silhouette = props.locked == true,
			glyph = if props.model then nil else (props.glyph or "paw"),
			size = UDim2.new(1, -10, 0, artHeight),
			position = UDim2.new(0.5, 0, 0, 15),
			anchorPoint = Vector2.new(0.5, 0),
			zIndex = 5,
		}),
		e(P.Label, {
			key = "Name",
			text = props.name,
			textSize = Theme.TextSize.Small,
			size = UDim2.new(1, -12, 0, 20),
			position = UDim2.fromOffset(6, artHeight + 12),
			truncate = Enum.TextTruncate.AtEnd,
			zIndex = 4,
		}),
		--[[
			Rarity as small coloured text rather than a badge chip. The chip was 30px
			tall and boxed, which cost the preview a third of its height to say
			something the colour already says.
		]]
		e(P.Label, {
			key = "Rarity",
			text = string.upper(props.rarity or ""),
			textSize = Theme.TextSize.Micro,
			color = style.color,
			size = UDim2.new(1, -12, 0, 16),
			position = UDim2.fromOffset(6, artHeight + 31),
			zIndex = 4,
		}),
		e(P.Label, {
			key = "Bonus",
			text = props.bonus,
			textSize = Theme.TextSize.Small,
			font = Theme.Font.Bold,
			color = Theme.Color.Positive,
			size = UDim2.new(1, -12, 0, 20),
			position = UDim2.fromOffset(6, artHeight + 47),
			truncate = Enum.TextTruncate.AtEnd,
			zIndex = 4,
		}),
		if props.equipped
			then e(Indicators.Checkmark, {
				key = "Equipped",
				extent = 30,
				position = UDim2.new(1, -6, 0, 16),
				anchorPoint = Vector2.new(1, 0),
				zIndex = 8,
			})
			else nil,
		if props.locked
			then e(Indicators.LockOverlay, {
				key = "LockOverlay",
				text = props.lockText,
				radius = Theme.Radius.Card,
				zIndex = 10,
			})
			else nil
	)

	return e(CardShell, {
		key = props.key or props.name,
		size = size,
		layoutOrder = props.layoutOrder,
		selected = props.selected or props.equipped,
		accentColor = if props.equipped then Theme.Color.Positive else style.color,
		locked = props.locked,
		onClick = props.onClick,
		children = children,
	})
end

--------------------------------------------------------------------------------
-- EmptySlot — an unfilled pet slot.
--------------------------------------------------------------------------------

function Cards.EmptySlot(props)
	return e(P.Slot, {
		key = props.key or "EmptySlot",
		size = props.size or UDim2.fromOffset(158, 212),
		layoutOrder = props.layoutOrder,
		strokeColor = Theme.Color.PanelLight,
		children = {
			e(Icon, {
				key = "Icon",
				glyph = props.glyph or "plus",
				plain = true,
				glyphColor = Theme.Color.PanelLight,
				size = UDim2.fromOffset(44, 44),
				position = UDim2.fromScale(0.5, 0.42),
				anchorPoint = Vector2.new(0.5, 0.5),
				zIndex = 3,
			}),
			e(P.Label, {
				key = "Hint",
				text = props.text or "EMPTY SLOT",
				textSize = Theme.TextSize.Tiny,
				-- Wraps: callers pass two lines here (what it does, then the price).
				wrapped = true,
				color = Theme.Color.GrayDark,
				size = UDim2.new(1, -16, 0, 40),
				position = UDim2.fromScale(0.5, 0.68),
				anchorPoint = Vector2.new(0.5, 0.5),
				zIndex = 6,
			}),
		},
	})
end

--------------------------------------------------------------------------------
-- CosmeticCard — plot customisation, with the action button inside the card.
--------------------------------------------------------------------------------

--[[
	props: name, rarity, glyph, equipped, state ("owned" | "locked" | "shop" |
	       "prestige"), requirement, onEquip
]]
function Cards.CosmeticCard(props)
	local style = Theme.rarity(props.rarity)
	local size = props.size or UDim2.fromOffset(176, 214)
	local state = props.state or "owned"

	local buttonText, buttonVariant, buttonDisabled
	if props.equipped then
		buttonText, buttonVariant, buttonDisabled = "EQUIPPED", "Neutral", true
	elseif state == "shop" then
		buttonText, buttonVariant = "SHOP", "Purchase"
	elseif state == "prestige" then
		buttonText, buttonVariant, buttonDisabled = "PRESTIGE", "Premium", true
	elseif state == "locked" then
		buttonText, buttonVariant, buttonDisabled = "LOCKED", "Disabled", true
	else
		buttonText, buttonVariant = "EQUIP", "Primary"
	end

	local children = P.compact(
		e(P.Slot, {
			key = "Preview",
			size = UDim2.new(1, -16, 0, 92),
			position = UDim2.fromOffset(8, 10),
			zIndex = 3,
			children = {
				e(Icon, {
					key = "Icon",
					glyph = props.glyph,
					image = props.image,
					plain = true,
					size = UDim2.fromScale(0.6, 0.6),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					zIndex = 6,
				}),
			},
		}),
		e(P.Label, {
			key = "Name",
			text = props.name,
			textSize = Theme.TextSize.Small,
			size = UDim2.new(1, -12, 0, 22),
			position = UDim2.fromOffset(6, 108),
			truncate = Enum.TextTruncate.AtEnd,
			zIndex = 4,
		}),
		e(Indicators.RarityBadge, {
			key = "Rarity",
			rarity = props.rarity,
			position = UDim2.new(0.5, 0, 0, 132),
			anchorPoint = Vector2.new(0.5, 0),
			zIndex = 4,
		}),
		e(Buttons.Button, {
			key = "Button",
			text = buttonText,
			variant = buttonVariant,
			disabled = buttonDisabled,
			textSize = Theme.TextSize.Small,
			size = UDim2.new(1, -20, 0, 40),
			position = UDim2.new(0.5, 0, 1, -10),
			anchorPoint = Vector2.new(0.5, 1),
			lip = 4,
			zIndex = 6,
			onClick = props.onEquip,
		}),
		if props.equipped
			then e(Indicators.Checkmark, {
				key = "Equipped",
				extent = 28,
				position = UDim2.new(1, -6, 0, 6),
				anchorPoint = Vector2.new(1, 0),
				zIndex = 8,
			})
			else nil,
		if props.requirement
			then e(Indicators.Badge, {
				key = "Requirement",
				text = props.requirement,
				gradient = Theme.Gradient.PanelDeep,
				position = UDim2.fromOffset(6, 6),
				zIndex = 8,
			})
			else nil
	)

	return e(CardShell, {
		key = props.key or props.name,
		size = size,
		layoutOrder = props.layoutOrder,
		selected = props.equipped,
		accentColor = if props.equipped then Theme.Color.Positive else style.color,
		children = children,
	})
end

--------------------------------------------------------------------------------
-- CollectionCell — index entry, discovered or not.
--------------------------------------------------------------------------------

--[[
	props: name, rarity, glyph, discovered, best (highest value seen),
	       collected (amount collected)
	       model    optional 3D preview id, or a list of candidates. Drawn in a
	                ViewportFrame; the glyph is only used when none of them resolve.
]]
function Cards.CollectionCell(props)
	local discovered = props.discovered == true
	local style = Theme.rarity(props.rarity)
	local size = props.size or UDim2.fromOffset(146, 168)

	local children
	if discovered then
		children = P.compact(
			e("Frame", {
				key = "RarityStripe",
				BackgroundColor3 = style.color,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -16, 0, 5),
				Position = UDim2.fromOffset(8, 8),
				ZIndex = 3,
			}, {
				P.corner(3),
				P.gradient(style.gradient, { rotation = 0 }),
			}),
			e(P.Slot, {
				key = "Artwork",
				size = UDim2.new(1, -16, 0, 76),
				position = UDim2.fromOffset(8, 18),
				zIndex = 3,
				children = {
					--[[
						The real model when one is published, the glyph when not.
						`ModelView` decides that itself and draws the glyph as its own
						fallback, so there is one code path rather than a branch here.
					]]
					if props.model
						then e(ModelView.View, {
							key = "Model",
							kind = "scrap",
							model = props.model,
							glyph = props.glyph or "scrap",
							zoom = 1.05,
							size = UDim2.fromScale(1, 1),
							zIndex = 6,
						})
						else e(Icon, {
							key = "Icon",
							glyph = props.glyph or "scrap",
							plain = true,
							size = UDim2.fromScale(0.62, 0.62),
							position = UDim2.fromScale(0.5, 0.5),
							anchorPoint = Vector2.new(0.5, 0.5),
							glyphColor = style.color,
							zIndex = 6,
						}),
				},
			}),
			e(P.Label, {
				key = "Name",
				text = props.name,
				textSize = Theme.TextSize.Tiny,
				size = UDim2.new(1, -10, 0, 20),
				position = UDim2.fromOffset(5, 98),
				truncate = Enum.TextTruncate.AtEnd,
				zIndex = 4,
			}),
			e(P.Label, {
				key = "Best",
				text = "BEST " .. Format.money(props.best or 0),
				textSize = Theme.TextSize.Tiny,
				font = Theme.Font.Bold,
				color = Theme.Color.Gold,
				size = UDim2.new(1, -10, 0, 18),
				position = UDim2.fromOffset(5, 118),
				zIndex = 4,
			}),
			e(P.Label, {
				key = "Collected",
				text = "COLLECTED " .. Format.short(props.collected or 0),
				textSize = Theme.TextSize.Tiny,
				font = Theme.Font.Bold,
				color = Theme.Color.Gray,
				size = UDim2.new(1, -10, 0, 18),
				position = UDim2.fromOffset(5, 136),
				zIndex = 4,
			})
		)
	else
		children = {
			e(P.Slot, {
				key = "Artwork",
				size = UDim2.new(1, -16, 0, 76),
				position = UDim2.fromOffset(8, 18),
				zIndex = 3,
				children = {
					--[[
						The real shape, blacked out. Better than a silhouetted glyph: it says
						what you are missing, which is the whole reason the grid shows
						undiscovered entries at all.
					]]
					if props.model
						then e(ModelView.View, {
							key = "Silhouette",
							kind = "scrap",
							model = props.model,
							silhouette = true,
							glyph = props.glyph or "scrap",
							zoom = 1.05,
							size = UDim2.fromScale(1, 1),
							zIndex = 6,
						})
						else e(Icon, {
							key = "Silhouette",
							glyph = props.glyph or "scrap",
							plain = true,
							size = UDim2.fromScale(0.62, 0.62),
							position = UDim2.fromScale(0.5, 0.5),
							anchorPoint = Vector2.new(0.5, 0.5),
							glyphColor = Color3.fromHex("11213D"),
							glyphAccent = Color3.fromHex("0D1A31"),
							zIndex = 6,
						}),
				},
			}),
			e(P.Label, {
				key = "Name",
				text = "???",
				textSize = Theme.TextSize.Heading,
				color = Theme.Color.GrayDark,
				size = UDim2.new(1, -10, 0, 28),
				position = UDim2.fromOffset(5, 100),
				zIndex = 4,
			}),
			--[[
				`hint` says WHERE an undiscovered thing comes from -- the scrap index passes the area name.
				"UNDISCOVERED" is the fallback for grids with nowhere to point at.
			]]
			e(P.Label, {
				key = "Hint",
				text = props.hint or "UNDISCOVERED",
				textSize = Theme.TextSize.Tiny,
				font = Theme.Font.Bold,
				color = if props.dimmed then Theme.Color.Gray else Theme.Color.GrayDark,
				size = UDim2.new(1, -10, 0, 18),
				position = UDim2.fromOffset(5, 130),
				truncate = Enum.TextTruncate.AtEnd,
				zIndex = 4,
			}),
		}
	end

	return e(CardShell, {
		key = props.key or props.name,
		size = size,
		layoutOrder = props.layoutOrder,
		color = if discovered then Theme.Color.Card else Theme.Color.PanelDark,
		baseColor = if discovered then Theme.Color.CardBase else Theme.Color.Slot,
		highlight = if discovered then 0.82 else 0.92,
		accentColor = style.color,
		onClick = props.onClick,
		children = children,
	})
end

Cards.CardShell = CardShell

return Cards
