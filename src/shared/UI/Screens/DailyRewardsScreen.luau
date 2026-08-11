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
local RewardToast = require(UI.Components.RewardToast)
local Icon = require(UI.Icon)
local Shine = require(UI.Components.Shine)
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

	THREE STATES, and they have to resolve at a glance without reading anything:

		claimed       ticked and washed out
		ready         accent fill, a thick gold ring, a CLAIM button and a SHINE layer
		not yet       greyed right down with a countdown

	The shine is the point. This is a kids' game and a grid of nine identical dim squares is the
	dullest thing in the UI -- so the one card you can act on glows, sparkles and sweeps, and the eight
	you cannot recede. Only the actionable card animates, which is what makes it read as the answer to
	"what do I press" rather than as decoration.
]]
local function PlaytimeCard(props)
	local claimed = props.claimed
	local ready = not claimed and props.seconds >= props.milestone.Seconds
	local locked = not claimed and not ready
	local accentName = props.milestone.Accent or "Green"
	local accent = Theme.Gradient[accentName] or Theme.Gradient.Green
	local remaining = math.max(0, props.milestone.Seconds - props.seconds)

	--[[
		Locked cards have to RECEDE, and the obvious choice was wrong.

		`Theme.Gradient.Dead` is the kit's disabled fill, but at 62708A it is LIGHTER than the recessed
		Slot fill -- so a "greyed" milestone came out more prominent than an available one, which is the
		opposite of the point. Locked cards use the deep Slot fill plus an ink wash and a grey glyph
		instead, so they read as recessed holes rather than as lit cards.
	]]
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
			--- Only on the card you can act on. See the note above.
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
			--- Big art in a well, matching the calendar cards so the two tabs share a rhythm.
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
						--- Real item art where the milestone grants one, same as the calendar and the wheel.
						image = RewardToast.imageFor(props.milestone),
						plain = true,
						--- Tinted grey while locked, so the art recedes with the card rather than staying vivid.
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
			--- Claimed: centred tick over a heavy ink wash, exactly as the calendar cards do it.
			if claimed
				then e(Indicators.Checkmark, {
					key = "Claimed",
					extent = 54,
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					zIndex = 9,
				})
				else nil,
			--- The same ink wash claimed cards get, so a locked card is unmistakably not lit.
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

local function DailyRewardsScreen(props)
	local state = props.state
	local actions = props.actions
	local tab, setTab = React.useState("daily")

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
			Sized to the ACTIVE tab, not the taller of the two.

			Sizing to the taller left a 170px dead band under the calendar, because the daily tab is two
			card rows plus a hero (328) while the playtime grid is three rows (498). The window resizing
			when you switch tabs is the lesser evil by a distance -- a modal with a third of its body empty
			reads as broken, a modal that resizes reads as fitting its contents.
		]]
		contentHeight = (if tab == "daily" then HERO.Y else CARD.Y * 3 + GAP * 2) + TAB_LANE,
		onClose = actions.closeScreen,
		footerHeight = 64,
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
					e(Indicators.Badge, {
						key = "Played",
						text = `PLAYED TODAY  {Format.timer(state.playtimeSeconds or 0)}`,
						gradient = Theme.Gradient.Gold,
						textSize = Theme.TextSize.Small,
						position = UDim2.fromScale(0.5, 0.5),
						anchorPoint = Vector2.new(0.5, 0.5),
					}),
				},
			})
			else e(P.Group, {
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
						gradient = if streak > 0
							then Theme.Gradient.Gold
							else Theme.Gradient.PanelDeep,
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
						textSize = if claimable
							then Theme.TextSize.Heading
							else Theme.TextSize.Body,
						size = UDim2.fromOffset(300, 56),
						position = UDim2.fromScale(0.5, 0.5),
						anchorPoint = Vector2.new(0.5, 0.5),
						-- No argument: the server decides what is claimable.
						onClick = actions.claimDaily,
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
