--[[
	PlaytimeRewardsScreen.luau
	Today's playtime ladder, as its own window.

	Used to share a tab with the daily calendar. Two systems with two claim paths
	do not belong under one title -- the HUD now has a clock icon that opens this.

	The seconds on screen are the store's live figure, which ticks every second while
	this window is open. The server still banks on its own interval and still decides
	every claim; the client only counts so the cards do not freeze between banks.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Format = require(UI.Format)
local P = require(UI.Primitives)
local Buttons = require(UI.Components.Buttons)
local Indicators = require(UI.Components.Indicators)
local RewardToast = require(UI.Components.RewardToast)
local Icon = require(UI.Icon)
local Shine = require(UI.Components.Shine)
local Overlays = require(UI.Components.Overlays)

local e = React.createElement

local CARD = Vector2.new(150, 158)
local GAP = 12

local function amountText(reward: { [string]: any }): string
	local parts = {}
	if reward.Money then
		table.insert(parts, Format.money(reward.Money))
	end
	if reward.Items then
		for itemId, count in reward.Items do
			table.insert(parts, `{count}x {string.upper(string.gsub(itemId, "Potion", ""))}`)
		end
	end
	if reward.Spins then
		table.insert(parts, `{reward.Spins} SPINS`)
	end
	return if #parts == 0 then reward.Label else table.concat(parts, " + ")
end

--[[
	One playtime milestone, as a card in the grid.

	THREE STATES, and they have to resolve at a glance without reading anything:

		claimed       ticked and washed out
		ready         accent fill, a thick gold ring, a CLAIM button and a SHINE layer
		not yet       greyed right down with a countdown
]]
local function PlaytimeCard(props)
	local claimed = props.claimed
	local ready = not claimed and props.seconds >= props.milestone.Seconds
	local locked = not claimed and not ready
	local accentName = props.milestone.Accent or "Green"
	local accent = Theme.Gradient[accentName] or Theme.Gradient.Green
	local remaining = math.max(0, props.milestone.Seconds - props.seconds)

	local fill
	if claimed then
		fill = Theme.Gradient.PanelDeep
	elseif ready then
		fill = accent
	else
		fill = Theme.Gradient.Slot
	end

	return e(P.Panel, {
		key = props.key,
		size = UDim2.fromOffset(CARD.X, CARD.Y),
		gradient = fill,
		radius = Theme.Radius.Card,
		strokeThickness = if ready then 5 else Theme.Stroke.Card,
		strokeColor = if ready then Theme.Color.Gold else Theme.Color.Outline,
		gloss = 0.84,
		studs = false,
		layoutOrder = props.milestone.Index,
		children = P.compact(
			if ready
				then e(Shine.Layer, {
					key = "Shine",
					glow = true,
					sparkles = true,
					sweep = true,
					color = Theme.Color.Gold,
					zIndex = 7,
				})
				else nil,
			e(P.Label, {
				key = "Time",
				text = props.milestone.Label,
				textSize = Theme.TextSize.Body,
				color = if locked then Theme.Color.GrayDark else Theme.Color.White,
				position = UDim2.fromOffset(0, 10),
				size = UDim2.new(1, 0, 0, 22),
				zIndex = 4,
			}),
			e(P.Slot, {
				key = "Well",
				size = UDim2.new(1, -22, 0, 60),
				position = UDim2.fromOffset(11, 34),
				zIndex = 3,
				children = {
					e(Icon, {
						key = "Glyph",
						glyph = if props.milestone.Spins
							then "wheel"
							elseif props.milestone.Items then "potion"
							else "coin",
						image = RewardToast.imageFor(props.milestone),
						plain = true,
						imageColor = if locked then Theme.Color.GrayDark else nil,
						glyphColor = if locked then Theme.Color.GrayDark else nil,
						size = UDim2.fromScale(0.82, 0.82),
						position = UDim2.fromScale(0.5, 0.5),
						anchorPoint = Vector2.new(0.5, 0.5),
						zIndex = 5,
					}),
				},
			}),
			e(P.Label, {
				key = "Reward",
				text = props.reward,
				textSize = Theme.TextSize.Tiny,
				font = Theme.Font.Bold,
				color = if locked then Theme.Color.GrayDark else Theme.Color.White,
				wrapped = true,
				position = UDim2.fromOffset(6, 98),
				size = UDim2.new(1, -12, 0, 24),
				zIndex = 4,
			}),
			if ready
				then e(Buttons.Button, {
					key = "Claim",
					text = "CLAIM",
					variant = "Primary",
					textSize = Theme.TextSize.Tiny,
					size = UDim2.fromOffset(CARD.X - 24, 30),
					position = UDim2.new(0.5, 0, 1, -8),
					anchorPoint = Vector2.new(0.5, 1),
					zIndex = 8,
					onClick = function()
						if props.onClaim then
							props.onClaim(props.milestone.Index)
						end
					end,
				})
				elseif locked then e(P.Label, {
					key = "Remaining",
					text = Format.timer(remaining),
					textSize = Theme.TextSize.Small,
					color = Theme.Color.GrayDark,
					position = UDim2.new(0, 0, 1, -10),
					anchorPoint = Vector2.new(0, 1),
					size = UDim2.new(1, 0, 0, 22),
					zIndex = 4,
				})
				else nil,
			if claimed
				then e(Indicators.Checkmark, {
					key = "Claimed",
					extent = 54,
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					zIndex = 9,
				})
				else nil,
			if locked
				then e("Frame", {
					key = "LockedWash",
					BackgroundColor3 = Theme.Color.Ink,
					BackgroundTransparency = 0.45,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 6,
				}, { P.corner(Theme.Radius.Card) })
				else nil,
			if claimed
				then e("Frame", {
					key = "ClaimedWash",
					BackgroundColor3 = Theme.Color.Ink,
					BackgroundTransparency = 0.22,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 8,
				}, { P.corner(Theme.Radius.Card) })
				else nil
		),
	})
end

local function PlaytimeRewardsScreen(props)
	local state = props.state
	local actions = props.actions
	local playtimeClaimed = state.playtimeClaimed or {}
	local seconds = state.playtimeSeconds or 0
	local playtimeCards = {}
	for _, milestone in ipairs(state.playtimeMilestones or {}) do
		playtimeCards[#playtimeCards + 1] = e(PlaytimeCard, {
			key = `Playtime{milestone.Index}`,
			milestone = milestone,
			reward = amountText(milestone),
			seconds = seconds,
			claimed = playtimeClaimed[milestone.Index] == true,
			onClaim = actions.claimPlaytime,
		})
	end

	local gridWidth = CARD.X * 3 + GAP * 2
	local gridHeight = CARD.Y * 3 + GAP * 2

	return e(Overlays.Modal, {
		key = props.key or "PlaytimeRewardsScreen",
		title = "Playtime",
		glyph = "clock",
		headerColor = Theme.Gradient.Gold,
		width = gridWidth + 56,
		contentHeight = gridHeight,
		onClose = actions.closeScreen,
		footerHeight = 64,
		footer = e(P.Group, {
			key = "PlaytimeFooter",
			size = UDim2.fromScale(1, 1),
			children = {
				e(Indicators.Badge, {
					key = "Played",
					text = `PLAYED TODAY  {Format.timer(seconds)}`,
					gradient = Theme.Gradient.Gold,
					textSize = Theme.TextSize.Small,
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
				}),
			},
		}),
		children = {
			e(P.Group, {
				key = "Playtime",
				size = UDim2.fromOffset(gridWidth, gridHeight),
				position = UDim2.fromScale(0.5, 0),
				anchorPoint = Vector2.new(0.5, 0),
				layout = P.grid({
					cell = UDim2.fromOffset(CARD.X, CARD.Y),
					padding = UDim2.fromOffset(GAP, GAP),
					maxCells = 3,
					hAlign = Enum.HorizontalAlignment.Center,
				}),
				children = playtimeCards,
			}),
		},
	})
end

return PlaytimeRewardsScreen
