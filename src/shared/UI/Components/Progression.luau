--!nonstrict
--[[
	Progression.luau
	The two card types behind titles and achievements.

	Both are WIDE cards rather than the square tiles the rest of the game uses, and that is a
	consequence of what they hold: a title has to be shown at the size it will be worn, and an
	achievement needs a sentence plus a progress bar. Squeezing either into a 152px magnet tile would
	mean truncating the one thing the card exists to show.

		TitleCard        the title as it will appear, its rarity, and how it was earned
		AchievementCard  what to do, how far along, and what it pays

	THE TITLE CARD SHOWS THE REAL THING. The tag is drawn in the same brackets and the same rarity
	colour the nameplate and the chat prefix use, at a readable size -- so choosing a title is choosing
	something you have already seen, not a name in a list that turns out to look different in the world.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Format = require(UI.Format)
local Motion = require(UI.Motion)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)
local Buttons = require(UI.Components.Buttons)
local Indicators = require(UI.Components.Indicators)
local Shine = require(UI.Components.Shine)

local e = React.createElement

local Progression = {}

--- Card sizes, exported so the screens' grids and these cards cannot disagree.
Progression.TITLE_CARD = Vector2.new(492, 104)
Progression.ACHIEVEMENT_CARD = Vector2.new(492, 116)

--[[
	One title.

	Three states, and each answers a different question:

		equipped  "this is what you are wearing"     -- ringed, and the button says so
		owned     "you could wear this"              -- lit, with an EQUIP button
		locked    "here is how you get it"           -- dimmed, and the source is named instead

	A locked title still shows its TEXT rather than hiding it behind question marks. A title you cannot
	read is not a goal, and the whole point of the list is wanting one.
]]
function Progression.TitleCard(props)
	local owned = props.owned == true
	local equipped = props.equipped == true
	local accentName = props.accent or "Gray"
	local accent = Theme.Color[accentName] or Theme.Color.Gray
	local size = props.size or UDim2.fromOffset(Progression.TITLE_CARD.X, Progression.TITLE_CARD.Y)

	return e(P.Panel, {
		key = props.key or props.id,
		size = size,
		layoutOrder = props.layoutOrder,
		radius = Theme.Radius.Card,
		color = if owned then Theme.Color.Card else Theme.Color.PanelDark,
		gradient = if owned then nil else Theme.Gradient.Slot,
		gloss = if owned then 0.86 else false,
		studs = false,
		--- The equipped card is ringed in its own rarity colour: the ring IS the "this one" signal.
		strokeThickness = if equipped then 4 else Theme.Stroke.Card,
		strokeColor = if equipped then accent else nil,
		children = P.compact(
			--[[
				A sparkle layer only on the rarest tiers, and only when owned. Everything sparkling is the
				same as nothing sparkling, and a locked card that glitters is a lie about what you have.
			]]
			if owned and (props.rarity == "Legendary" or props.rarity == "Mythic")
				then e(Shine.Layer, { key = "Shine", sparkles = true, color = accent, zIndex = 2 })
				else nil,
			--[[
				THE TAG, at the size it is worn. Bracketed here rather than by the caller so this cannot
				drift from `TitleConfig.tag`, which is what the nameplate and chat use.
			]]
			e(P.Label, {
				key = "Tag",
				text = `[{props.text}]`,
				textSize = Theme.TextSize.Heading,
				color = if owned then accent else Theme.Color.GrayDark,
				align = Enum.TextXAlignment.Left,
				truncate = Enum.TextTruncate.AtEnd,
				position = UDim2.fromOffset(18, 14),
				size = UDim2.new(1, -150, 0, 32),
				zIndex = 4,
			}),
			--- Rarity, small and above the tag, so the eye reads colour first and the word only if it asks.
			e(P.Label, {
				key = "Rarity",
				text = string.upper(props.rarity or ""),
				textSize = Theme.TextSize.Tiny,
				font = Theme.Font.Bold,
				color = if owned then accent else Theme.Color.GrayDark,
				align = Enum.TextXAlignment.Left,
				position = UDim2.fromOffset(18, 50),
				size = UDim2.fromOffset(120, 18),
				zIndex = 4,
			}),
			--- Where it came from. For a locked title this is the only actionable line on the card.
			e(P.Label, {
				key = "Source",
				text = if owned
					then `Earned: {props.sourceName}`
					else `Locked: {props.sourceDetail ~= "" and props.sourceDetail or props.sourceName}`,
				textSize = Theme.TextSize.Small,
				font = Theme.Font.Bold,
				color = Theme.Color.Gray,
				align = Enum.TextXAlignment.Left,
				truncate = Enum.TextTruncate.AtEnd,
				position = UDim2.fromOffset(18, 70),
				size = UDim2.new(1, -170, 0, 22),
				zIndex = 4,
			}),
			--[[
				The button, or a lock. An owned-but-not-worn title gets EQUIP; the worn one gets a REMOVE
				that is deliberately quiet, because taking a title off is not the action the card is for.
			]]
			if owned
				then e(Buttons.Button, {
					key = "Action",
					text = if equipped then "WEARING" else "EQUIP",
					glyph = if equipped then "check" else nil,
					variant = if equipped then "Neutral" else "Primary",
					textSize = Theme.TextSize.Small,
					size = UDim2.fromOffset(124, 48),
					position = UDim2.new(1, -16, 0.5, 0),
					anchorPoint = Vector2.new(1, 0.5),
					zIndex = 5,
					onClick = function()
						if props.onEquip then
							--- Wearing it already? The button takes it off. One button, both directions.
							props.onEquip(if equipped then "" else props.id)
						end
					end,
				})
				else e(Icon, {
					key = "Lock",
					glyph = "lock",
					plain = true,
					size = UDim2.fromOffset(34, 34),
					position = UDim2.new(1, -30, 0.5, 0),
					anchorPoint = Vector2.new(1, 0.5),
					zIndex = 5,
				})
		),
	})
end

--[[
	One achievement.

	`complete` comes from the live numbers and `paid` from the save, and they are shown differently on
	purpose: a card can be complete for the few seconds before the server's next pass pays it, and
	saying DONE at that moment is honest. Saying nothing would look broken.
]]
function Progression.AchievementCard(props)
	local complete = props.complete == true
	local accentName = props.accent or "Cyan"
	local accent = Theme.Color[accentName] or Theme.Color.Cyan
	local gradient = Theme.Gradient[accentName] or Theme.Gradient.Cyan
	local size = props.size
		or UDim2.fromOffset(Progression.ACHIEVEMENT_CARD.X, Progression.ACHIEVEMENT_CARD.Y)

	--- Reward line: only the parts that exist, so nothing reads "+0 gears".
	local rewardParts = {}
	local reward = props.reward or {}
	if reward.Money then
		table.insert(rewardParts, Format.money(reward.Money))
	end
	if reward.Gears then
		table.insert(rewardParts, `{reward.Gears} gears`)
	end
	if reward.Spins then
		table.insert(rewardParts, `{reward.Spins} spin{if reward.Spins == 1 then "" else "s"}`)
	end
	if props.titleText then
		table.insert(rewardParts, `title "{props.titleText}"`)
	end

	--- A finished card breathes once rather than sparkling forever; it is a record, not a prize.
	local pulse = Motion.useSpin(60, complete)

	return e(P.Panel, {
		key = props.key or props.id,
		size = size,
		layoutOrder = props.layoutOrder,
		radius = Theme.Radius.Card,
		color = if complete then Theme.Color.Card else Theme.Color.PanelDark,
		gradient = if complete then nil else Theme.Gradient.Slot,
		gloss = if complete then 0.86 else false,
		studs = false,
		strokeThickness = if complete then 4 else Theme.Stroke.Card,
		strokeColor = if complete then accent else nil,
		children = P.compact(
			--[[
				The art well, dimmed until earned. Greying the ICON rather than hiding it keeps the card's
				shape identical in both states, so a list of them does not jump around as they complete.
			]]
			e(P.Slot, {
				key = "Art",
				size = UDim2.fromOffset(72, 72),
				position = UDim2.new(0, 16, 0.5, 0),
				anchorPoint = Vector2.new(0, 0.5),
				zIndex = 3,
				children = {
					e(Icon, {
						key = "Glyph",
						glyph = props.glyph,
						plain = true,
						glyphColor = if complete then nil else Theme.Color.GrayDark,
						imageColor = if complete then nil else Theme.Color.GrayDark,
						size = UDim2.fromScale(0.78, 0.78),
						position = UDim2.fromScale(0.5, 0.5),
						anchorPoint = Vector2.new(0.5, 0.5),
					}),
				},
			}),
			e(P.Label, {
				key = "Name",
				text = string.upper(props.name or ""),
				textSize = Theme.TextSize.Body,
				color = if complete then Theme.Color.White else Theme.Color.Gray,
				align = Enum.TextXAlignment.Left,
				truncate = Enum.TextTruncate.AtEnd,
				position = UDim2.fromOffset(102, 12),
				size = UDim2.new(1, -220, 0, 24),
				zIndex = 4,
			}),
			e(P.Label, {
				key = "Description",
				text = props.description,
				textSize = Theme.TextSize.Small,
				font = Theme.Font.Bold,
				color = Theme.Color.Gray,
				align = Enum.TextXAlignment.Left,
				truncate = Enum.TextTruncate.AtEnd,
				position = UDim2.fromOffset(102, 36),
				size = UDim2.new(1, -220, 0, 20),
				zIndex = 4,
			}),
			--[[
				The bar carries the numbers inside it rather than beside it. A separate "412 / 1,000" label
				is a second thing to place and a second thing to keep aligned, and the bar already has the
				room.
			]]
			e(Indicators.ProgressBar, {
				key = "Bar",
				value = props.value or 0,
				max = math.max(1, props.threshold or 1),
				gradient = if complete then gradient else Theme.Gradient.PanelDeep,
				height = 24,
				size = UDim2.new(1, -222, 0, 24),
				position = UDim2.fromOffset(102, 62),
				text = if complete
					then "COMPLETE"
					else Format.fraction(props.value or 0, props.threshold or 1),
				zIndex = 4,
			}),
			--- What it pays, under the bar, quiet. Nobody chases the cash on an achievement.
			if #rewardParts > 0
				then e(P.Label, {
					key = "Reward",
					text = `Reward: {table.concat(rewardParts, ", ")}`,
					textSize = Theme.TextSize.Tiny,
					font = Theme.Font.Bold,
					color = if complete then Theme.Color.Positive else Theme.Color.GrayDark,
					align = Enum.TextXAlignment.Left,
					truncate = Enum.TextTruncate.AtEnd,
					position = UDim2.fromOffset(102, 90),
					size = UDim2.new(1, -220, 0, 18),
					zIndex = 4,
				})
				else nil,
			--- Done marker, right-hand side, replacing nothing: the space is empty while incomplete.
			if complete
				then e(P.Group, {
					key = "Done",
					size = UDim2.fromOffset(92, 92),
					position = UDim2.new(1, -14, 0.5, 0),
					anchorPoint = Vector2.new(1, 0.5),
					zIndex = 5,
					children = {
						e("UIScale", {
							key = "Breathe",
							Scale = pulse:map(function(angle: number)
								return 1 + math.sin(math.rad(angle)) * 0.04
							end),
						}),
						e(Indicators.Checkmark, {
							key = "Tick",
							extent = 52,
							position = UDim2.fromScale(0.5, 0.5),
							anchorPoint = Vector2.new(0.5, 0.5),
						}),
					},
				})
				else nil
		),
	})
end

return Progression
