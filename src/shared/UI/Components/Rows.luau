--[[
	Rows.luau
	Wide list entries.

		UpgradeCard     icon / name / level / current -> next / price / BUY
		AreaCard        large progression zone card
		LeaderboardRow  rank, avatar, player, value, with the top three lit up
		RewardCard      one day of the daily reward track
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Format = require(UI.Format)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)
local Buttons = require(script.Parent.Buttons)
local Indicators = require(script.Parent.Indicators)

local e = React.createElement

local Rows = {}

--------------------------------------------------------------------------------
-- UpgradeCard
--------------------------------------------------------------------------------

--[[
	props:
		name        "MAGNET RANGE"
		glyph       icon name
		level       number
		maxLevel    number?
		current     "25 studs"
		next        "28 studs"      omitted when maxed
		price       number
		affordable  boolean?        default true
		amount      string?         "x1" / "x5" / "MAX" shown on the button
		accent      ColorSequence?  icon plaque colour
		onBuy       function
]]
function Rows.UpgradeCard(props)
	local maxed = props.maxLevel ~= nil and props.level >= props.maxLevel
	local affordable = props.affordable ~= false and not maxed
	local height = props.height or 104

	local children = P.compact(
		e(Icon, {
			key = "Icon",
			glyph = props.glyph,
			gradient = props.accent or Theme.Gradient.Blue,
			size = UDim2.fromOffset(70, 70),
			position = UDim2.new(0, 14, 0.5, 0),
			anchorPoint = Vector2.new(0, 0.5),
			radius = Theme.Radius.Card,
			zIndex = 3,
		}),
		e(P.Label, {
			key = "Name",
			text = string.upper(props.name),
			textSize = Theme.TextSize.Heading,
			align = Enum.TextXAlignment.Left,
			size = UDim2.fromOffset(260, 30),
			position = UDim2.fromOffset(98, 20),
			zIndex = 3,
		}),
		e(Indicators.Badge, {
			key = "Level",
			text = if maxed then "MAX LEVEL" else ("LEVEL " .. Format.comma(props.level)),
			gradient = if maxed then Theme.Gradient.Gold else Theme.Gradient.PanelDeep,
			textColor = if maxed then Theme.Color.Ink else Theme.Color.Gray,
			textSize = Theme.TextSize.Tiny,
			position = UDim2.fromOffset(98, 54),
			zIndex = 3,
		}),

		-- Current -> Next block, centred in the row.
		e(P.Group, {
			key = "Change",
			size = UDim2.fromOffset(260, 40),
			position = UDim2.fromScale(0.56, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			zIndex = 3,
			layout = P.list({
				direction = Enum.FillDirection.Horizontal,
				padding = Theme.Space.M,
				hAlign = Enum.HorizontalAlignment.Center,
				vAlign = Enum.VerticalAlignment.Center,
			}),
			children = P.compact(
				e(P.Label, {
					key = "Current",
					text = props.current,
					textSize = Theme.TextSize.Body,
					color = Theme.Color.Gray,
					size = UDim2.fromOffset(0, 26),
					automaticSize = Enum.AutomaticSize.X,
					layoutOrder = 1,
				}),
				if not maxed
					then e(Icon, {
						key = "Arrow",
						glyph = "arrow",
						plain = true,
						glyphColor = Theme.Color.Positive,
						size = UDim2.fromOffset(26, 26),
						layoutOrder = 2,
					})
					else nil,
				if not maxed
					then e(P.Label, {
						key = "Next",
						text = props.next,
						textSize = Theme.TextSize.Heading,
						color = Theme.Color.Positive,
						size = UDim2.fromOffset(0, 30),
						automaticSize = Enum.AutomaticSize.X,
						layoutOrder = 3,
					})
					else nil
			),
		}),

		-- Price above the buy button, right aligned.
		if not maxed
			then e(Indicators.PriceTag, {
				key = "Price",
				cash = props.price,
				textSize = Theme.TextSize.Value,
				color = if affordable then Theme.Color.Positive else Theme.Color.Red,
				position = UDim2.new(1, -20, 0, 16),
				anchorPoint = Vector2.new(1, 0),
				zIndex = 3,
			})
			else nil,
		e(Buttons.Button, {
			key = "Button",
			text = if maxed then "MAXED" else "UPGRADE",
			subtext = if maxed or not props.amount then nil else props.amount,
			variant = if maxed then "Neutral" else "Primary",
			disabled = maxed or not affordable,
			size = UDim2.fromOffset(176, 48),
			position = UDim2.new(1, -20, 1, -14),
			anchorPoint = Vector2.new(1, 1),
			zIndex = 4,
			onClick = props.onBuy,
		})
	)

	return e(P.Panel, {
		key = props.key or props.name,
		size = props.size or UDim2.new(1, 0, 0, height),
		layoutOrder = props.layoutOrder,
		radius = Theme.Radius.Card,
		-- Solid face, no studs: these sit inside a studded window, and repeating
		-- the texture inside them made the cards vanish into their background.
		color = Theme.Color.Card,
		gloss = 0.84,
		studs = false,
		strokeThickness = Theme.Stroke.Card,
		strokeColor = if maxed then Theme.Color.Gold else Theme.Color.Outline,
		children = children,
	})
end

--------------------------------------------------------------------------------
-- AreaCard
--------------------------------------------------------------------------------

--[[
	props:
		name        "Vehicle Graveyard"
		glyph       icon name
		cost        number       unlock price
		unlocked    boolean
		current     boolean      the player is standing here
		bestScrap   "Engine Block"
		bestValue   number
		affordable  boolean?
		onTeleport / onUnlock
]]
function Rows.AreaCard(props)
	local size = props.size or UDim2.fromOffset(268, 320)
	local unlocked = props.unlocked == true
	local artHeight = 132

	local children = P.compact(
		e(P.Slot, {
			key = "Preview",
			size = UDim2.new(1, -18, 0, artHeight),
			position = UDim2.fromOffset(9, 10),
			zIndex = 3,
			children = P.compact(
				e(Icon, {
					key = "Icon",
					glyph = props.glyph or "pin",
					image = props.image,
					plain = true,
					size = UDim2.fromOffset(74, 74),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					zIndex = 6,
				}),
				e(Indicators.Badge, {
					key = "Tier",
					text = "AREA " .. tostring(props.tier or 1),
					gradient = Theme.Gradient.PanelDeep,
					position = UDim2.fromOffset(8, 8),
					zIndex = 5,
				})
			),
		}),
		e(P.Label, {
			key = "Name",
			text = props.name,
			textSize = Theme.TextSize.Heading,
			size = UDim2.new(1, -18, 0, 30),
			position = UDim2.fromOffset(9, artHeight + 18),
			truncate = Enum.TextTruncate.AtEnd,
			zIndex = 4,
		}),
		e(P.Group, {
			key = "Stats",
			size = UDim2.new(1, -18, 0, 74),
			position = UDim2.fromOffset(9, artHeight + 52),
			zIndex = 4,
			layout = P.list({ padding = 6 }),
			children = {
				e(Indicators.StatRow, {
					key = "BestScrap",
					label = "BEST SCRAP",
					value = props.bestScrap or "-",
					textSize = Theme.TextSize.Small,
					size = UDim2.new(1, 0, 0, 34),
					layoutOrder = 1,
				}),
				e(Indicators.StatRow, {
					key = "Value",
					label = "VALUE",
					value = Format.money(props.bestValue or 0),
					valueColor = Theme.Color.Gold,
					textSize = Theme.TextSize.Small,
					size = UDim2.new(1, 0, 0, 34),
					layoutOrder = 2,
				}),
			},
		}),
		e(Buttons.Button, {
			key = "Button",
			-- Without an onTeleport handler an unlocked area has nowhere to send
			-- the player, so the card states the fact instead of offering a dead
			-- button. Pass onTeleport once the map grows per-area destinations.
			text = if not unlocked
				then "UNLOCK"
				elseif props.onTeleport then "TELEPORT"
				else "UNLOCKED",
			subtext = if unlocked then nil else Format.money(props.cost or 0),
			variant = if unlocked then "Secondary" else "Purchase",
			disabled = if unlocked then props.onTeleport == nil else props.affordable == false,
			size = UDim2.new(1, -18, 0, 50),
			position = UDim2.new(0.5, 0, 1, -10),
			anchorPoint = Vector2.new(0.5, 1),
			zIndex = 6,
			onClick = if unlocked then props.onTeleport else props.onUnlock,
		}),
		if props.current
			then e(Indicators.Checkmark, {
				key = "Current",
				extent = 34,
				position = UDim2.new(1, -6, 0, 6),
				anchorPoint = Vector2.new(1, 0),
				zIndex = 8,
			})
			else nil,
		if not unlocked
			then e(Indicators.LockOverlay, {
				key = "LockOverlay",
				transparency = 0.55,
				radius = Theme.Radius.Card,
				extent = 54,
				zIndex = 5,
			})
			else nil
	)

	return e(P.Panel, {
		key = props.key or props.name,
		size = size,
		layoutOrder = props.layoutOrder,
		radius = Theme.Radius.Card,
		-- Solid face, no studs: these sit inside a studded window, and repeating
		-- the texture inside them made the cards vanish into their background.
		color = Theme.Color.Card,
		gloss = 0.84,
		glossHeight = 0.16,
		studs = false,
		strokeThickness = Theme.Stroke.Card,
		strokeColor = if props.current then Theme.Color.Positive else Theme.Color.Outline,
		children = children,
	})
end

--------------------------------------------------------------------------------
-- LeaderboardRow
--------------------------------------------------------------------------------

local RANK_STYLE = {
	[1] = { gradient = Theme.Gradient.Gold, color = Theme.Color.Gold },
	[2] = {
		gradient = ColorSequence.new(Color3.fromHex("E8EEF6"), Color3.fromHex("A8B4C4")),
		color = Color3.fromHex("D8E0EA"),
	},
	[3] = {
		gradient = ColorSequence.new(Color3.fromHex("FFA968"), Color3.fromHex("C86A22")),
		color = Color3.fromHex("E8873C"),
	},
}

function Rows.LeaderboardRow(props)
	local rank = props.rank or 1
	local style = RANK_STYLE[rank]
	local height = props.height or 58
	local isTop = style ~= nil

	local children = P.compact(
		-- Rank plate
		e(P.Chip, {
			key = "Rank",
			gradient = if style then style.gradient else Theme.Gradient.PanelDeep,
			color = Theme.Color.PanelDark,
			size = UDim2.fromOffset(52, height - 16),
			position = UDim2.new(0, 8, 0.5, 0),
			anchorPoint = Vector2.new(0, 0.5),
			radius = Theme.Radius.Small,
			zIndex = 3,
			children = {
				e(P.Label, {
					key = "Value",
					text = "#" .. tostring(rank),
					textSize = Theme.TextSize.Body,
					color = if isTop then Theme.Color.Ink else Theme.Color.White,
					stroke = if isTop then 0 else nil,
				}),
			},
		}),
		-- Avatar placeholder: a headshot ImageLabel drops straight in here.
		e(P.Slot, {
			key = "Avatar",
			size = UDim2.fromOffset(height - 16, height - 16),
			position = UDim2.new(0, 68, 0.5, 0),
			anchorPoint = Vector2.new(0, 0.5),
			radius = Theme.Radius.Small,
			zIndex = 3,
			children = P.compact(if props.avatar
				then e("ImageLabel", {
					key = "Image",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Image = props.avatar,
					ZIndex = 6,
				})
				else e(Icon, {
					key = "Placeholder",
					glyph = "medal",
					plain = true,
					size = UDim2.fromScale(0.6, 0.6),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					glyphColor = if style then style.color else Theme.Color.PanelLight,
					zIndex = 6,
				})),
		}),
		e(P.Label, {
			key = "Player",
			text = props.player,
			textSize = Theme.TextSize.Body,
			align = Enum.TextXAlignment.Left,
			size = UDim2.new(1, -(height + 200), 1, 0),
			position = UDim2.fromOffset(height + 62, 0),
			truncate = Enum.TextTruncate.AtEnd,
			zIndex = 3,
		}),
		e(P.Label, {
			key = "Value",
			text = props.value,
			textSize = Theme.TextSize.Body,
			color = props.valueColor or (if isTop then style.color else Theme.Color.Gold),
			align = Enum.TextXAlignment.Right,
			size = UDim2.new(0, 170, 1, 0),
			position = UDim2.new(1, -14, 0, 0),
			anchorPoint = Vector2.new(1, 0),
			zIndex = 3,
		})
	)

	return e(P.Panel, {
		key = props.key or ("Rank" .. rank),
		size = props.size or UDim2.new(1, 0, 0, height),
		layoutOrder = props.layoutOrder or rank,
		radius = Theme.Radius.Small,
		color = if props.highlight then Theme.Color.PanelLight else Theme.Color.Card,
		gloss = 0.86,
		glossHeight = 0.4,
		strokeThickness = Theme.Stroke.Chip,
		strokeColor = if isTop then style.color else Theme.Color.Outline,
		studs = false,
		children = children,
	})
end

--------------------------------------------------------------------------------
-- RewardCard — one day of the daily reward track
--------------------------------------------------------------------------------

--[[
	props:
		day        number
		label      "CASH" / "POTION" / "PET"
		amount     "$25K"
		glyph      icon name
		state      "claimed" | "current" | "locked"
		premium    boolean?   day 7 styling
]]
function Rows.RewardCard(props)
	local state = props.state or "locked"
	local isCurrent = state == "current"
	local isClaimed = state == "claimed"
	local size = props.size or UDim2.fromOffset(140, 178)

	local headerGradient
	if props.premium then
		headerGradient = Theme.Gradient.Purple
	elseif isCurrent then
		headerGradient = Theme.Gradient.Green
	elseif isClaimed then
		headerGradient = Theme.Gradient.PanelDeep
	else
		headerGradient = Theme.Gradient.Gray
	end

	local children = P.compact(
		e(P.Panel, {
			key = "Header",
			size = UDim2.new(1, 0, 0, 34),
			radius = Theme.Radius.Card,
			studs = false,
			strokeThickness = Theme.Stroke.Chip,
			zIndex = 4,
			children = {
				P.gradient(headerGradient),
				e(
					P.Gloss,
					{ key = "Gloss", radius = Theme.Radius.Card, strength = 0.72, height = 0.55 }
				),
				e(P.Label, {
					key = "Day",
					text = "DAY " .. tostring(props.day),
					textSize = Theme.TextSize.Small,
					zIndex = 4,
				}),
			},
		}),
		e(P.Slot, {
			key = "Reward",
			size = UDim2.new(1, -16, 0, 78),
			position = UDim2.fromOffset(8, 42),
			zIndex = 3,
			children = {
				e(Icon, {
					key = "Icon",
					glyph = props.glyph,
					plain = true,
					size = UDim2.fromScale(0.56, 0.56),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					zIndex = 6,
				}),
			},
		}),
		e(P.Label, {
			key = "Amount",
			text = props.amount,
			textSize = Theme.TextSize.Body,
			color = if props.premium then Theme.Color.Purple else Theme.Color.Gold,
			size = UDim2.new(1, -10, 0, 24),
			position = UDim2.fromOffset(5, 126),
			zIndex = 4,
		}),
		e(P.Label, {
			key = "Label",
			text = string.upper(props.label or ""),
			textSize = Theme.TextSize.Tiny,
			font = Theme.Font.Bold,
			color = Theme.Color.Gray,
			size = UDim2.new(1, -10, 0, 18),
			position = UDim2.fromOffset(5, 150),
			zIndex = 4,
		}),
		if isClaimed
			then e(Indicators.Checkmark, {
				key = "Claimed",
				extent = 34,
				position = UDim2.new(1, -6, 0, 40),
				anchorPoint = Vector2.new(1, 0),
				zIndex = 9,
			})
			else nil,
		if isClaimed
			then e("Frame", {
				key = "ClaimedWash",
				BackgroundColor3 = Theme.Color.PanelDark,
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 8,
			}, { P.corner(Theme.Radius.Card) })
			else nil,
		if state == "locked"
			then e(Indicators.LockOverlay, {
				key = "LockOverlay",
				transparency = 0.6,
				extent = 40,
				radius = Theme.Radius.Card,
				zIndex = 8,
			})
			else nil
	)

	return e(P.Panel, {
		key = props.key or ("Day" .. tostring(props.day)),
		size = size,
		layoutOrder = props.layoutOrder or props.day,
		radius = Theme.Radius.Card,
		-- Solid face, no studs: see the note in Cards.CardShell.
		color = if props.premium then Theme.Color.PanelLight else Theme.Color.Card,
		gloss = 0.84,
		studs = false,
		strokeThickness = if isCurrent then 4 else Theme.Stroke.Card,
		-- The claimable day is ringed in green; day 7 keeps its premium purple.
		strokeColor = if isCurrent
			then Theme.Color.Positive
			else (if props.premium then Theme.Color.Purple else Theme.Color.Outline),
		children = children,
	})
end

return Rows
