--[[
	DailyRewardsScreen.luau

	THE REWARDS WINDOW: two tabs, DAILY and PLAYTIME.

	Both are "things you collect from" rather than things you spend at, so they share one window
	instead of taking two HUD entry points. Tabs rather than one long scroll, because each grid wants
	the full width.

	DAILY: a seven-day calendar that loops.

	Layout is two rows of three on the left, and day 7 as a tall HERO card on the right spanning both
	rows. Six small cards plus one big one, which is what makes the last day read as the thing worth
	keeping a streak for -- a seventh identical card in a row of seven does not.

	Days behind the current one carry a tick and a dim wash, today is ringed, and the hero keeps its
	gold.

	THE STREAK IS THE FEATURE, not the reward. A reward for logging in is pleasant; a streak you lose
	by not logging in is a reason to log in. So the streak is what the footer leads with, and the bonus
	it is worth is spelled out rather than left implicit.

	PLAYTIME: the same grid treatment. It used to be a thin HUD strip showing only the next milestone,
	which meant the other four were invisible -- a ladder you cannot see is not a ladder. All five are
	cards now, each claimable in place.

	CLAIMING TAKES NO ARGUMENT on the daily side. It used to pass the day it thought was claimable,
	which is exactly the value a server must never accept from a client; the server reads that from
	saved data. The playtime claim does take a milestone index, but only as a lookup key -- the server
	re-checks the banked seconds itself.
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
local Icon = require(UI.Icon)
local Overlays = require(UI.Components.Overlays)

local e = React.createElement

--- Small card in the 3x2 block, and the hero that spans both of its rows.
local CARD = Vector2.new(150, 158)
local HERO = Vector2.new(232, CARD.Y * 2 + 12)
local GAP = 12

--- Vertical room the tab bar takes at the top of the body.
local TAB_LANE = 54

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

--[[
	One playtime milestone, as a card in the grid.

	Three states, and they have to be distinguishable at a glance: claimed (ticked, dimmed), ready
	(accent fill and a CLAIM button), and locked (a countdown to it).
]]
local function PlaytimeCard(props)
	local claimed = props.claimed
	local ready = not claimed and props.seconds >= props.milestone.Seconds
	local accent = Theme.Gradient[props.milestone.Accent or "Green"] or Theme.Gradient.Green
	local remaining = math.max(0, props.milestone.Seconds - props.seconds)

	return e(P.Panel, {
		key = props.key,
		size = UDim2.fromOffset(CARD.X, CARD.Y),
		gradient = if claimed
			then Theme.Gradient.PanelDeep
			elseif ready then accent
			else Theme.Gradient.Slot,
		radius = Theme.Radius.Card,
		strokeThickness = if ready then 5 else Theme.Stroke.Card,
		studs = false,
		layoutOrder = props.milestone.Index,
		children = P.compact(
			e(P.Label, {
				key = "Time",
				text = props.milestone.Label,
				textSize = Theme.TextSize.Body,
				color = if claimed then Theme.Color.GrayDark else Theme.Color.White,
				position = UDim2.fromOffset(0, 10),
				size = UDim2.new(1, 0, 0, 22),
			}),
			e(Icon, {
				key = "Glyph",
				glyph = if props.milestone.Spins
					then "wheel"
					elseif props.milestone.Items then "potion"
					else "coin",
				plain = true,
				size = UDim2.fromOffset(52, 52),
				position = UDim2.new(0.5, 0, 0, 36),
				anchorPoint = Vector2.new(0.5, 0),
			}),
			e(P.Label, {
				key = "Reward",
				text = props.reward,
				textSize = Theme.TextSize.Tiny,
				font = Theme.Font.Bold,
				color = if claimed then Theme.Color.GrayDark else Theme.Color.White,
				wrapped = true,
				position = UDim2.fromOffset(0, 92),
				size = UDim2.new(1, -12, 0, 28),
			}),
			--- Claimed shows a tick; ready shows the button; locked shows how long is left.
			if claimed
				then e(Icon, {
					key = "Tick",
					glyph = "check",
					plain = true,
					size = UDim2.fromOffset(34, 34),
					position = UDim2.new(0.5, 0, 1, -10),
					anchorPoint = Vector2.new(0.5, 1),
				})
				elseif ready then e(Buttons.Button, {
					key = "Claim",
					text = "CLAIM",
					variant = "Primary",
					textSize = Theme.TextSize.Tiny,
					size = UDim2.fromOffset(CARD.X - 24, 32),
					position = UDim2.new(0.5, 0, 1, -10),
					anchorPoint = Vector2.new(0.5, 1),
					onClick = function()
						if props.onClaim then
							props.onClaim(props.milestone.Index)
						end
					end,
				})
				else e(P.Label, {
					key = "Remaining",
					text = Format.timer(remaining),
					textSize = Theme.TextSize.Small,
					color = Theme.Color.Gray,
					position = UDim2.new(0, 0, 1, -14),
					anchorPoint = Vector2.new(0, 1),
					size = UDim2.new(1, 0, 0, 22),
				})
		),
	})
end

local function DailyRewardsScreen(props)
	local state = props.state
	local actions = props.actions
	local tab, setTab = React.useState("daily")

	local days = state.dailyDays or {}
	local currentDay = state.dailyCalendarDay or 1
	local claimable = state.dailyClaimable == true
	local streak = state.dailyStreak or 0

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
	--- The server-derived figure from the store, not a second copy of the same arithmetic.
	local bonusPercent = state.dailyBoostPercent or 0

	--- Playtime milestones, same card size so the two tabs share a rhythm.
	local playtimeClaimed = state.playtimeClaimed or {}
	local playtimeCards = {}
	for _, milestone in ipairs(state.playtimeMilestones or {}) do
		playtimeCards[#playtimeCards + 1] = e(PlaytimeCard, {
			key = `Playtime{milestone.Index}`,
			milestone = milestone,
			reward = amountText(milestone),
			seconds = state.playtimeSeconds or 0,
			claimed = playtimeClaimed[milestone.Index] == true,
			onClaim = actions.claimPlaytime,
		})
	end

	return e(Overlays.Modal, {
		key = props.key or "DailyRewardsScreen",
		title = "Rewards",
		glyph = "calendar",
		headerColor = Theme.Gradient.Green,
		width = blockWidth + HERO.X + GAP + 56,
		--[[
			Tall enough for whichever tab is up: the calendar is two card rows plus the hero, the playtime
			grid is three. Sized to the taller so switching tabs does not resize the window under the
			player's cursor.
		]]
		contentHeight = math.max(HERO.Y, CARD.Y * 3 + GAP * 2) + TAB_LANE + 8,
		onClose = actions.closeScreen,
		footerHeight = 70,
		--[[
			The footer belongs to the daily tab: a streak line and a CLAIM button mean nothing next to a
			playtime grid whose cards each carry their own button. On the playtime tab it is replaced with
			the one number that matters there -- how long you have played today.
		]]
		footer = if tab ~= "daily"
			then e(P.Group, {
				key = "PlaytimeFooter",
				size = UDim2.fromScale(1, 1),
				children = {
					e(P.Label, {
						key = "Played",
						text = `PLAYED TODAY: {Format.timer(state.playtimeSeconds or 0)}`,
						textSize = Theme.TextSize.Body,
						font = Theme.Font.Bold,
						color = Theme.Color.Gold,
						align = Enum.TextXAlignment.Left,
						size = UDim2.new(0, 340, 1, 0),
					}),
					e(Indicators.Badge, {
						key = "Reset",
						text = `RESETS IN {Format.timer(state.dailyResetSeconds or 0)}`,
						gradient = Theme.Gradient.PanelDeep,
						textSize = Theme.TextSize.Small,
						position = UDim2.fromScale(1, 0.5),
						anchorPoint = Vector2.new(1, 0.5),
					}),
				},
			})
			else e(P.Group, {
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
						textSize = if claimable
							then Theme.TextSize.Heading
							else Theme.TextSize.Body,
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
			e(Buttons.TabBar, {
				key = "Tabs",
				tabs = {
					{ id = "daily", text = "DAILY", glyph = "calendar" },
					{ id = "playtime", text = "PLAYTIME", glyph = "clock" },
				},
				active = tab,
				size = UDim2.fromOffset(340, 42),
				position = UDim2.fromScale(0.5, 0),
				anchorPoint = Vector2.new(0.5, 0),
				onSelect = setTab,
			}),
			--[[
				One body group per tab, and only the active one is built. Rendering both and toggling
				`Visible` would keep two grids of cards alive for no reason -- and the playtime cards run
				their own countdown text.
			]]
			if tab == "daily"
				then e(P.Group, {
					key = "Calendar",
					size = UDim2.fromOffset(blockWidth + GAP + HERO.X, HERO.Y),
					position = UDim2.new(0.5, 0, 0, TAB_LANE),
					anchorPoint = Vector2.new(0.5, 0),
					children = P.compact(
						--[[
							The six small days as a 3-wide grid, which wraps to two rows on its own. A grid
							rather than two hand-built rows, so a calendar of a different length still lays
							out without touching this file.
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
				})
				--[[
					Nine milestones as a 3x3. Same card size as the calendar so the two tabs share a rhythm,
					and 3x3 is why there are nine rather than eight or ten -- a grid with a ragged last row
					reads as unfinished.
				]]
				else e(P.Group, {
					key = "Playtime",
					size = UDim2.fromOffset(CARD.X * 3 + GAP * 2, CARD.Y * 3 + GAP * 2),
					position = UDim2.new(0.5, 0, 0, TAB_LANE),
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

return DailyRewardsScreen
