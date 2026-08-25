--[[
	DailyRewardsScreen.luau
	The seven-day login calendar.

	Playtime is its own window (`PlaytimeRewardsScreen`) and its own HUD icon. These used
	to share tabs; two claim paths under one title meant one of them was always hidden.

	Layout is two rows of three on the left, and day 7 as a tall HERO card on the right
	spanning both rows.

	CLAIMING TAKES NO ARGUMENT. The server reads what is claimable from saved data.
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
local RewardToast = require(UI.Components.RewardToast)
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
	--- Seconds to the next day boundary, refreshed by the store's own ticker.
	local resetSeconds = state.dailyResetSeconds or 0

	--[[
		`DailyCalendarDay` IS THE DAY ON OFFER NEXT, not the one you last took.

		The server advances it the moment you claim, so straight after a claim `currentDay` already
		points at tomorrow. Treating `day == currentDay` as claimed-when-not-claimable therefore put the
		tick on TOMORROW'S card -- the bug where you claim one and the next one shows a tick.

		So the only card that can be claimed-looking is one strictly behind the pointer. The card the
		pointer is on is either live now, or locked until the reset.
	]]
	local function stateFor(dayNumber: number): string
		if dayNumber < currentDay then
			return "claimed"
		elseif dayNumber == currentDay then
			return if claimable then "current" else "locked"
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
			image = RewardToast.imageFor(day),
			premium = index == heroIndex,
			state = stateFor(day.Day),
			--[[
				Only the pointer day, and only while it is not claimable. Every other locked day's wait
				depends on claims that have not happened yet, so a countdown on those would be a guess.
			]]
			timer = if day.Day == currentDay and not claimable
				then Format.timer(resetSeconds)
				else nil,
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
	--- The server-derived figure from the store, not a second copy of the same arithmetic.
	local bonusPercent = state.dailyBoostPercent or 0

	return e(Overlays.Modal, {
		key = props.key or "DailyRewardsScreen",
		title = "Daily Rewards",
		glyph = "calendar",
		headerColor = Theme.Gradient.Green,
		width = blockWidth + HERO.X + GAP + 56,
		contentHeight = HERO.Y,
		onClose = actions.closeScreen,
		footerHeight = 64,
		footer = e(P.Group, {
			key = "Claim",
			size = UDim2.fromScale(1, 1),
			children = {
				--[[
						The streak as a chip, and no prose. The old footer had a sentence on the left and a
						RESETS IN badge on the right, both saying what the cards already show -- two redundant
						strings flanking the button is what made this read as filler.
					]]
				e(Indicators.Badge, {
					key = "Streak",
					text = if bonusPercent > 0
						then `STREAK {streak}  ·  +{bonusPercent}% CASH`
						else `STREAK {streak}`,
					gradient = if streak > 0 then Theme.Gradient.Gold else Theme.Gradient.PanelDeep,
					textSize = Theme.TextSize.Small,
					position = UDim2.fromScale(0, 0.5),
					anchorPoint = Vector2.new(0, 0.5),
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
			},
		}),
		children = {
			e(P.Group, {
				key = "Calendar",
				size = UDim2.fromOffset(blockWidth + GAP + HERO.X, HERO.Y),
				position = UDim2.fromScale(0.5, 0),
				anchorPoint = Vector2.new(0.5, 0),
				children = P.compact(
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
