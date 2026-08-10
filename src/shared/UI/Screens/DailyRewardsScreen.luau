--[[
	DailyRewardsScreen.luau

	DAILY REWARDS: a seven-day calendar that loops.

	LAYOUT: two rows of three on the left, and day 7 as a tall HERO card on the right spanning both
	rows. Six small cards plus one big one, which is what makes the last day read as the thing worth
	keeping a streak for -- a seventh identical card in a row of seven does not.

	Days behind the current one carry a tick and a dim wash, today is ringed, and the hero keeps its
	gold.

	THE STREAK IS THE FEATURE, not the reward. A reward for logging in is pleasant; a streak you lose
	by not logging in is a reason to log in. So the streak is what the footer leads with, and the bonus
	it is worth is spelled out rather than left implicit.

	CLAIMING TAKES NO ARGUMENT. It used to pass the day it thought was claimable, which is exactly the
	value a server must never accept from a client. The server reads that from saved data.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Format = require(UI.Format)
local P = require(UI.Primitives)
local Buttons = require(UI.Components.Buttons)
local Indicators = require(UI.Components.Indicators)
local Rows = require(UI.Components.Rows)
local Overlays = require(UI.Components.Overlays)

local e = React.createElement

--- Small card in the 3x2 block, and the hero that spans both of its rows.
local CARD = Vector2.new(150, 158)
local HERO = Vector2.new(232, CARD.Y * 2 + 12)
local GAP = 12

--[[
	The reward line on a card. Derived from the reward itself rather than authored twice, so a config
	change cannot leave the card lying about what it gives.
]]
local function amountText(day: { [string]: any }): string
	local parts = {}
	if day.Money then
		table.insert(parts, Format.money(day.Money))
	end
	if day.Items then
		for itemId, count in day.Items do
			table.insert(parts, `{count}x {string.upper(string.gsub(itemId, "Potion", ""))}`)
		end
	end
	if day.Spins then
		table.insert(parts, `{day.Spins} SPINS`)
	end
	return if #parts == 0 then day.Label else table.concat(parts, " + ")
end

local function DailyRewardsScreen(props)
	local state = props.state
	local actions = props.actions

	local days = state.dailyDays or {}
	local currentDay = state.dailyCalendarDay or 1
	local claimable = state.dailyClaimable == true
	local streak = state.dailyStreak or 0

	--[[
		"claimed" means behind the current day in the calendar, NOT claimed today. Those are different
		questions, and conflating them is what makes a looping calendar confusing: on day 3 you want
		days 1 and 2 dimmed whether or not today's claim is still pending.
	]]
	local function stateFor(dayNumber: number): string
		if dayNumber < currentDay then
			return "claimed"
		elseif dayNumber == currentDay then
			return if claimable then "current" else "claimed"
		end
		return "locked"
	end

	--[[
		The hero is whichever day carries `Hero` in config, falling back to the last day. Data-driven so
		moving the big reward moves the big card with it.
	]]
	local heroIndex = #days
	for index, day in ipairs(days) do
		if day.Hero then
			heroIndex = index
			break
		end
	end

	local smallCards = {}
	local heroCard = nil
	for index, day in ipairs(days) do
		local card = e(Rows.RewardCard, {
			key = "Day" .. day.Day,
			day = day.Day,
			label = day.Label,
			amount = amountText(day),
			glyph = day.Glyph,
			premium = index == heroIndex,
			state = stateFor(day.Day),
			size = if index == heroIndex
				then UDim2.fromOffset(HERO.X, HERO.Y)
				else UDim2.fromOffset(CARD.X, CARD.Y),
			layoutOrder = index,
		})
		if index == heroIndex then
			heroCard = card
		else
			smallCards[#smallCards + 1] = card
		end
	end

	local blockWidth = CARD.X * 3 + GAP * 2
	local bonusPercent = math.floor(math.min(math.max(0, streak - 1) * 5, 100))

	return e(Overlays.Modal, {
		key = props.key or "DailyRewardsScreen",
		title = "Daily Rewards",
		glyph = "calendar",
		headerColor = Theme.Gradient.Green,
		width = blockWidth + HERO.X + GAP + 56,
		contentHeight = HERO.Y + 8,
		onClose = actions.closeScreen,
		footerHeight = 70,
		footer = e(P.Group, {
			key = "Claim",
			size = UDim2.fromScale(1, 1),
			children = {
				e(P.Label, {
					key = "Streak",
					text = if bonusPercent > 0
						then `STREAK {streak} DAYS  ·  +{bonusPercent}% CASH`
						else `STREAK {streak} DAYS`,
					textSize = Theme.TextSize.Body,
					font = Theme.Font.Bold,
					color = if streak > 0 then Theme.Color.Gold else Theme.Color.Gray,
					align = Enum.TextXAlignment.Left,
					size = UDim2.new(0, 300, 1, 0),
				}),
				e(Buttons.Button, {
					key = "ClaimButton",
					text = if claimable then "CLAIM" else "COME BACK TOMORROW",
					glyph = if claimable then "check" else nil,
					variant = if claimable then "Primary" else "Neutral",
					disabled = not claimable,
					textSize = if claimable then Theme.TextSize.Heading else Theme.TextSize.Body,
					size = UDim2.fromOffset(300, 56),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					-- No argument: the server decides what is claimable.
					onClick = actions.claimDaily,
				}),
				e(Indicators.Badge, {
					key = "Next",
					text = `RESETS IN {Format.timer(state.dailyResetSeconds or 0)}`,
					gradient = Theme.Gradient.PanelDeep,
					textSize = Theme.TextSize.Small,
					position = UDim2.fromScale(1, 0.5),
					anchorPoint = Vector2.new(1, 0.5),
				}),
			},
		}),
		children = {
			e(P.Group, {
				key = "Calendar",
				size = UDim2.fromOffset(blockWidth + GAP + HERO.X, HERO.Y),
				position = UDim2.fromScale(0.5, 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
				children = P.compact(
					--[[
						The six small days as a 3-wide grid, which wraps to two rows on its own. A grid
						rather than two hand-built rows so a calendar of a different length still lays out
						without touching this file.
					]]
					e(P.Group, {
						key = "Block",
						size = UDim2.fromOffset(blockWidth, HERO.Y),
						layout = P.grid({
							cell = UDim2.fromOffset(CARD.X, CARD.Y),
							padding = UDim2.fromOffset(GAP, GAP),
							maxCells = 3,
						}),
						children = smallCards,
					}),
					--- The hero, pinned right and spanning the full height of the block.
					if heroCard
						then e(P.Group, {
							key = "HeroSlot",
							size = UDim2.fromOffset(HERO.X, HERO.Y),
							position = UDim2.fromScale(1, 0.5),
							anchorPoint = Vector2.new(1, 0.5),
							children = { heroCard },
						})
						else nil
				),
			}),
		},
	})
end

return DailyRewardsScreen
