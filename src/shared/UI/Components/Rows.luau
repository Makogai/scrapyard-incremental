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
--[[
	The two fixed columns of an upgrade row: the icon-and-name block on the left, and the buttons on the
	right. Everything between them is the current->next readout, sized from these rather than guessed.
]]
local NAME_COLUMN = 420
local BUTTON_COLUMN = 250

function Rows.UpgradeCard(props)
	local maxed = props.maxLevel ~= nil and props.level >= props.maxLevel
	local affordable = props.affordable ~= false and not maxed
	--[[
		TWO ROWS WHEN THERE IS A ROBUX OPTION: cash on top, Robux underneath.

		The card grows rather than the buttons shrinking -- a 48px call to action is the smallest that still
		reads as pressable on a phone, and squeezing two into 104px produced two that read as neither.
	]]
	local hasRobux = props.robuxPrice ~= nil and props.onBuyRobux ~= nil
	--[[
		Taller than it was, on purpose. The row now carries the PRICE ON THE BUTTON rather than floating it
		above, which needs a button big enough for two lines of text -- and the Robux option under it needs
		to be a real button rather than a caption, or nobody reads the price on it.
	]]
	local height = props.height or (if hasRobux then 176 else 118)

	local children = P.compact(
		e(Icon, {
			key = "Icon",
			glyph = props.glyph,
			gradient = props.accent or Theme.Gradient.Blue,
			size = UDim2.fromOffset(78, 78),
			position = UDim2.new(0, 16, 0.5, 0),
			anchorPoint = Vector2.new(0, 0.5),
			radius = Theme.Radius.Card,
			zIndex = 3,
		}),
		e(P.Label, {
			key = "Name",
			text = string.upper(props.name),
			textSize = Theme.TextSize.Title,
			align = Enum.TextXAlignment.Left,
			size = UDim2.fromOffset(300, 38),
			position = UDim2.fromOffset(108, 20),
			zIndex = 3,
		}),
		e(Indicators.Badge, {
			key = "Level",
			text = if maxed then "MAX LEVEL" else ("LEVEL " .. Format.comma(props.level)),
			gradient = if maxed then Theme.Gradient.Gold else Theme.Gradient.PanelDeep,
			textColor = if maxed then Theme.Color.Ink else Theme.Color.Gray,
			textSize = Theme.TextSize.Tiny,
			position = UDim2.fromOffset(108, 62),
			zIndex = 3,
		}),

		--[[
			Current -> Next, filling the gap BETWEEN the name column and the buttons rather than centred on
			a guessed fraction of the row.

			It used to sit at 0.56 of the width, which was fine against a 176px button and overlaps a 210px
			one. Anchored to the left edge of the gap with a width derived from both columns, it cannot
			collide however wide the buttons get -- and the horizontal list inside still centres its content
			in whatever space is left.
		]]
		e(P.Group, {
			key = "Change",
			size = UDim2.new(1, -(NAME_COLUMN + BUTTON_COLUMN), 0, 40),
			position = UDim2.new(0, NAME_COLUMN, 0.5, 0),
			anchorPoint = Vector2.new(0, 0.5),
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

		--[[
			THE PRICE IS THE BUTTON.

			It used to sit as a separate tag above, which left the button saying "UPGRADE" -- a word the
			player already knows from the window they are standing in -- while the number they actually
			decide on floated somewhere else. Now the cost is the headline and the verb is the caption, so
			one glance at the button answers "can I afford this".

			`moneyExact` rather than `money`: this is a spend, and "$1,250" is a decision where "$1.2K" is a
			guess. Same reasoning as the confirmation modal.
		]]
		e(Buttons.Button, {
			key = "Button",
			text = if maxed then "MAXED" else Format.moneyExact(props.price),
			subtext = if maxed then nil else (props.amount or "UPGRADE"),
			subtextSize = Theme.TextSize.Tiny,
			variant = if maxed then "Neutral" else "Primary",
			disabled = maxed or not affordable,
			textSize = Theme.TextSize.Button,
			size = UDim2.fromOffset(210, 58),
			position = UDim2.new(1, -20, 1, if hasRobux then -76 else -16),
			anchorPoint = Vector2.new(1, 1),
			zIndex = 4,
			onClick = props.onBuy,
		}),
		--[[
			THE ROBUX ROW.

			`iconSize` is pinned rather than left to derive from the text size: the Robux mark defaults to
			`textSize + 8` and grew with the label, which is what made it look like it was floating in the
			corner at its own scale. Fixed at 16 it sits centred on the price it belongs to.
		]]
		if hasRobux
			then e(Buttons.Button, {
				key = "RobuxButton",
				--- Price as the headline, "+1 LEVEL" as the caption -- the reverse of how this started.
				text = Format.robux(props.robuxPrice),
				subtext = "+1 LEVEL",
				subtextSize = Theme.TextSize.Tiny,
				glyph = "robux",
				--[[
					20, up from 16. The mark is pinned rather than derived from the text size -- it used to
					grow with the label and drift around the corner at its own scale -- but 16 next to a
					22px price read as an afterthought.
				]]
				iconSize = 20,
				variant = "Premium",
				disabled = maxed,
				textSize = Theme.TextSize.Button,
				size = UDim2.fromOffset(176, 44),
				position = UDim2.new(1, -20, 1, -14),
				anchorPoint = Vector2.new(1, 1),
				zIndex = 4,
				onClick = props.onBuyRobux,
			})
			else nil
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

	--[[
		THE CARD LAYS ITSELF OUT FROM ITS OWN HEIGHT, which the hero card is the reason for.

		Every offset used to be a constant tuned for a 158px card: the art well at y=42, the amount at
		126, the label at 150. Hand the same component a 328px hero card and it draws a small card's
		worth of content in the top half and leaves the bottom half blank -- which is exactly the empty
		space in the daily modal.

		So the well takes whatever is between the header and the two text lines, and the text is measured
		up from the BOTTOM. A card of any height then fills itself.
	]]
	local height = if size.Y.Offset > 0 then size.Y.Offset else 158
	local HEADER = 34
	local LABEL_LANE = 18
	local AMOUNT_LANE = 24
	local wellTop = HEADER + 8
	local wellHeight = math.max(48, height - wellTop - AMOUNT_LANE - LABEL_LANE - 12)

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
			size = UDim2.new(1, -16, 0, wellHeight),
			position = UDim2.fromOffset(8, wellTop),
			zIndex = 3,
			children = {
				--[[
					Filling most of the well rather than a bit over half. The reward art is the only thing on
					the card a player actually reads at a glance, and at 0.56 the potions were small enough
					to be unidentifiable.
				]]
				e(Icon, {
					key = "Icon",
					glyph = props.glyph,
					--- Item art when the reward is an item; `Icon` prefers `image` over `glyph`.
					image = props.image,
					plain = true,
					size = UDim2.fromScale(0.86, 0.86),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					zIndex = 6,
				}),
			},
		}),
		e(P.Label, {
			key = "Amount",
			text = props.amount,
			textSize = if props.premium then Theme.TextSize.Body else Theme.TextSize.Small,
			color = if props.premium then Theme.Color.Purple else Theme.Color.Gold,
			--- Wrapped, because a hero's reward line is a sentence ("$50K + 1x GOD + 2 SPINS").
			wrapped = props.premium,
			size = UDim2.new(1, -10, 0, AMOUNT_LANE),
			position = UDim2.fromOffset(5, height - LABEL_LANE - AMOUNT_LANE - 6),
			zIndex = 4,
		}),
		e(P.Label, {
			key = "Label",
			text = string.upper(props.label or ""),
			textSize = Theme.TextSize.Tiny,
			font = Theme.Font.Bold,
			color = Theme.Color.Gray,
			size = UDim2.new(1, -10, 0, LABEL_LANE),
			position = UDim2.fromOffset(5, height - LABEL_LANE - 4),
			zIndex = 4,
		}),
		--[[
			CENTRED on the card, not tucked in a corner, and big. A claimed day is a state the eye should
			resolve without reading anything, and the tick is the whole message.
		]]
		if isClaimed
			then e(Indicators.Checkmark, {
				key = "Claimed",
				extent = 58,
				position = UDim2.fromScale(0.5, 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
				zIndex = 9,
			})
			else nil,
		--[[
			Ink at 0.22, not PanelDark at 0.5. The old wash barely dimmed the card, so a claimed day and a
			live one read almost the same -- which is exactly the confusion the tick is there to prevent.
		]]
		if isClaimed
			then e("Frame", {
				key = "ClaimedWash",
				BackgroundColor3 = Theme.Color.Ink,
				BackgroundTransparency = 0.22,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 8,
			}, { P.corner(Theme.Radius.Card) })
			else nil,
		--[[
			LOCKED, TWO WAYS.

			A day whose wait is KNOWABLE shows the wait. A padlock answers "can I have this" with "no",
			which the player already worked out from the greyed card; a countdown answers "when", which is
			the only thing they actually wanted. So the pointer day -- the one unlocking at the next reset
			-- gets a timer, and days further out, whose wait depends on claims not yet made, keep the lock.
		]]
		if state == "locked" and props.timer
			then e("Frame", {
				key = "WaitWash",
				BackgroundColor3 = Theme.Color.Ink,
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 8,
			}, {
				P.corner(Theme.Radius.Card),
				e(P.Chip, {
					key = "Wait",
					size = UDim2.fromOffset(96, 30),
					gradient = Theme.Gradient.PanelDeep,
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					zIndex = 3,
					children = {
						e(P.Label, {
							key = "Time",
							text = props.timer,
							textSize = Theme.TextSize.Small,
							color = Theme.Color.White,
							size = UDim2.fromScale(1, 1),
							zIndex = 3,
						}),
					},
				}),
			}) --[[
				A locked day that is not next in line keeps a padlock, but a SMALL one in the corner rather
				than `LockOverlay`'s centred 40px badge. Centred, it landed squarely on top of the prize art
				-- so the one thing a player wants to see on a future day, what it is, was the one thing
				covered up.
			]]

			elseif state == "locked" then e("Frame", {
				key = "LockedWash",
				BackgroundColor3 = Theme.Color.PanelDark,
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 8,
			}, {
				P.corner(Theme.Radius.Card),
				e(Icon, {
					key = "Lock",
					glyph = "lock",
					plain = true,
					size = UDim2.fromOffset(22, 22),
					position = UDim2.new(1, -8, 0, 8),
					anchorPoint = Vector2.new(1, 0),
					zIndex = 2,
				}),
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
