--[[
	DailyRewardsScreen.luau

	DAILY REWARDS: a seven-day track that loops. Days behind you carry a tick and a dim wash, today
	is ringed in green, day 7 keeps its premium purple.

	THE STREAK IS THE FEATURE, not the reward. A reward for logging in is pleasant; a streak you
	lose by not logging in is a reason to log in. So the streak is what the footer leads with, and
	the bonus it is worth is spelled out rather than left implicit.

	Reads real config and real server state now. It used to render `Mock.dailyRewards` against a
	`claimedDays` that was always zero, and its claim button called an empty function -- the screen
	existed and the feature did not.

	CLAIMING TAKES NO ARGUMENT. It used to pass the day it thought was claimable, which is exactly
	the value a server must never accept from a client. The server reads that from saved data.
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

--[[
	The reward line on a card. Derived from the reward itself rather than authored twice, so a
	config change cannot leave the card lying about what it gives.
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

	local cards = {}
	for index, day in ipairs(days) do
		--[[
			"claimed" means behind the current day in the calendar, NOT claimed today. Those are
			different questions and conflating them is what makes a looping calendar confusing: on
			day 3 you want days 1 and 2 dimmed whether or not today's claim is still pending.
		]]
		local dayState
		if day.Day < currentDay then
			dayState = "claimed"
		elseif day.Day == currentDay then
			dayState = if claimable then "current" else "claimed"
		else
			dayState = "locked"
		end

		cards[#cards + 1] = e(Rows.RewardCard, {
			key = "Day" .. day.Day,
			day = day.Day,
			label = day.Label,
			amount = amountText(day),
			glyph = day.Glyph,
			premium = day.Day == #days,
			state = dayState,
			layoutOrder = index,
		})
	end

	local bonusPercent = math.floor(math.min(math.max(0, streak - 1) * 5, 100))

	return e(Overlays.Modal, {
		key = props.key or "DailyRewardsScreen",
		title = "Daily Rewards",
		glyph = "calendar",
		headerColor = Theme.Gradient.Green,
		width = 1080,
		-- A single row of 178px day cards.
		contentHeight = 200,
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
					size = UDim2.new(0, 320, 1, 0),
				}),
				e(Buttons.Button, {
					key = "ClaimButton",
					text = if claimable then "CLAIM" else "COME BACK TOMORROW",
					glyph = if claimable then "check" else nil,
					variant = if claimable then "Primary" else "Neutral",
					disabled = not claimable,
					textSize = if claimable then Theme.TextSize.Heading else Theme.TextSize.Body,
					size = UDim2.fromOffset(320, 56),
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
				key = "RewardTrack",
				size = UDim2.fromScale(1, 1),
				layout = P.list({
					direction = Enum.FillDirection.Horizontal,
					padding = 10,
					hAlign = Enum.HorizontalAlignment.Center,
					vAlign = Enum.VerticalAlignment.Center,
				}),
				children = cards,
			}),
		},
	})
end

return DailyRewardsScreen
