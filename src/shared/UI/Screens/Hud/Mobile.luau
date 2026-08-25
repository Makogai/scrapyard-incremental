--[[
	Mobile.luau
	Main gameplay HUD for phones, authored at 390x844.

	Roblox owns three regions on a touch device, and none of them are used here:

		top-left      its menu button, chat and leaderboard toggles
		bottom-left   the movement thumbstick
		bottom-right  the jump button

	So the layout works inward from those:

		top strip     our native-styled topbar row, on the right
		+4            currency chips, side by side, below the topbar strip
		+46           event banner, full width
		+100          boost timers, right (hidden while the drawer is open)
		right rail    stacked UP from the storage meter: the menu drawer, and the
		              MENU toggle at thumb height. Settings, collection, plot and
		              leaderboards live in the topbar row, so nothing is doubled up
		bottom        storage meter with an inline SELL button, lifted clear of
		              the thumbstick and jump button

	The drawer starts closed so first-time players see the game, not the UI.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent.Parent
local Theme = require(UI.Theme)
local Hooks = require(UI.Hooks)
local P = require(UI.Primitives)
local Buttons = require(UI.Components.Buttons)
local Parts = require(script.Parent.Parts)
local PlotSkinConfig = require(ReplicatedStorage.Shared.Config.PlotSkinConfig)

local e = React.createElement

local MARGIN = 12
local WIDTH = 390

-- The right rail is stacked upward from the storage meter rather than measured
-- down from the top, so the layout holds on any screen height instead of only on
-- a 844px one.
local STORAGE_HEIGHT = 76
local STORAGE_TOP = Theme.Safe.BottomBand + STORAGE_HEIGHT
local TOGGLE_BOTTOM = STORAGE_TOP + 12
local TOGGLE_HEIGHT = 78
local RAIL_BOTTOM = TOGGLE_BOTTOM + TOGGLE_HEIGHT + 12
local DRAWER_HEIGHT = 336

local function HudMobile(props)
	local state = props.state
	local actions = props.actions
	local open, setOpen = React.useState(props.startOpen == true)
	local safe = Hooks.useSafeArea()

	-- Phones have no room beside Roblox's buttons, so our topbar row takes the
	-- first band under the strip and the rest of the HUD stacks below it.
	local topRow = safe.top + 44

	local pitOffset = if state.event and state.event.arena then 52 else 0
	--- 32-tall tiles plus their 8 gap, so the skin card lands under whatever boosts are actually drawn.
	local boostLane = #(state.boosts or {}) * 40

	--[[
		Canvas height in design pixels, for the tutorial spotlight -- which needs an absolute rect and
		this file otherwise only ever positions things relative to an edge. There is deliberately no
		HEIGHT constant here: the layout stacks up from the bottom so it holds on any screen height, and
		this is the one thing that has to know the number.
	]]
	local viewport = Hooks.useViewport()
	local scale = Hooks.useScale()
	local canvasHeight = viewport.Y / math.max(scale, 0.01)

	local children = P.compact(
		-- Currencies run side by side rather than stacked: two chips fit the width
		-- and leave the whole strip below them free.
		e(Parts.CurrencyStack, {
			key = "Currencies",
			cash = state.cash,
			gears = state.gears,
			prestige = state.prestige,
			direction = Enum.FillDirection.Horizontal,
			width = 116,
			height = 36,
			gap = 6,
			compact = true,
			position = UDim2.fromOffset(MARGIN, topRow),
		}),

		--- Only when there is an event to name; see the note in `Desktop`.
		if state.event
			then e(Parts.EventBanner, {
				key = "EventBanner",
				title = state.event.title,
				detail = state.event.detail,
				glyph = state.event.glyph,
				accent = state.event.accent,
				seconds = state.event.seconds,
				live = state.event.live,
				width = WIDTH - MARGIN * 2,
				height = 44,
				position = UDim2.new(0.5, 0, 0, topRow + 42),
				anchorPoint = Vector2.new(0.5, 0),
			})
			else nil,

		if state.event and state.event.arena
			then e(Buttons.Button, {
				key = "EnterPit",
				text = "ENTER THE PIT",
				glyph = "crate",
				variant = "Danger",
				textSize = Theme.TextSize.Tiny,
				size = UDim2.fromOffset(WIDTH - MARGIN * 2, 40),
				lip = 4,
				position = UDim2.new(0.5, 0, 0, topRow + 90),
				anchorPoint = Vector2.new(0.5, 0),
				onClick = function()
					actions.teleport("Pit")
				end,
			})
			else nil,

		-- Boosts share the right edge with the drawer, so they step aside for it.
		if not open
			then e(Parts.BoostTimers, {
				key = "Boosts",
				boosts = state.boosts,
				width = 138,
				height = 32,
				position = UDim2.new(1, -MARGIN, 0, topRow + 96 + pitOffset),
				anchorPoint = Vector2.new(1, 0),
			})
			else nil,

		--[[
			The lava skin offer, under the boost lane on the same edge, in its compact size.

			Measured DOWN from the boosts rather than up from the status cluster: stacking it above that
			cluster would put its top ~430px off the bottom edge, which is off-screen entirely on the
			750x361 landscape phone this layout is checked against. The lane below the boosts is the only
			right-edge room that exists on every phone.

			`boostLane` counts the timers that are actually drawn -- `BoostTimers` renders nothing for an
			empty list, so reserving its height unconditionally would leave a hole most of the time.
		]]
		if not open
			then e(Parts.PlotSkinOffer, {
				key = "PlotSkin",
				compact = true,
				plotTheme = state.plotTheme,
				entitlements = state.entitlements,
				position = UDim2.new(1, -MARGIN, 0, topRow + 96 + pitOffset + boostLane),
				anchorPoint = Vector2.new(1, 0),
				onBuy = function()
					actions.purchase(PlotSkinConfig.Pass, "Pass")
				end,
			})
			else nil,

		-- Storage sits above the touch-control band so the thumbstick and jump
		-- button never overlap it.
		e(Parts.StorageMeter, {
			key = "Storage",
			storage = state.storage,
			capacity = state.capacity,
			value = state.storageValue,
			compact = true,
			size = UDim2.fromOffset(WIDTH - MARGIN * 2, STORAGE_HEIGHT),
			position = UDim2.new(0.5, 0, 1, -Theme.Safe.BottomBand),
			anchorPoint = Vector2.new(0.5, 1),
			onSell = actions.sell,
		}),

		if open
			then e(P.Group, {
				key = "MenuDrawer",
				size = UDim2.fromOffset(178, DRAWER_HEIGHT),
				position = UDim2.new(1, -MARGIN, 1, -RAIL_BOTTOM),
				anchorPoint = Vector2.new(1, 1),
				zIndex = 11,
				children = {
					e(Parts.MenuGrid, {
						key = "Menu",
						tile = 84,
						gap = 8,
						shopHeight = 56,
						compact = true,
						onOpen = function(id)
							setOpen(false)
							actions.openScreen(id)
						end,
					}),
				},
			})
			else nil,

		--[[
			BOTTOM RIGHT status cluster, matching desktop -- but stacked ABOVE the menu toggle rather
			than beside it. The right edge at thumb height belongs to the toggle, and a 750x361 landscape
			phone has no room for four things in one corner. Hidden while the drawer is open, like the
			boosts.
		]]
		if not open
			then e(Parts.StatusCluster, {
				key = "StatusCluster",
				dailyStreak = state.dailyStreak,
				dailyBoostPercent = state.dailyBoostPercent,
				dailyClaimable = state.dailyClaimable,
				dailyResetSeconds = state.dailyResetSeconds,
				playtimeClaimable = state.playtimeClaimable,
				playtimeNextRemaining = state.playtimeNextRemaining,
				friendCount = state.friendCount,
				friendBoost = state.friendBoost,
				spinsAvailable = state.spinsAvailable,
				extent = 38,
				gap = 6,
				position = UDim2.new(1, -MARGIN, 1, -(TOGGLE_BOTTOM + TOGGLE_HEIGHT + 8)),
				anchorPoint = Vector2.new(1, 1),
				zIndex = 11,
				onOpenDaily = function()
					actions.openScreen("daily")
				end,
				onOpenPlaytime = function()
					actions.openScreen("playtime")
				end,
				onOpenSpin = function()
					actions.openScreen("spin")
				end,
			})
			else nil,

		--[[
			Spotlight on the menu TOGGLE rather than the upgrade tile: on mobile the tiles live inside a
			drawer that is closed by default, so the thing the player has to press first is the toggle
			that opens it.
		]]
		if state.tutorialStep
				and state.tutorialStep.Target == "upgrades"
				and not open
			then e(Parts.TutorialSpotlight, {
				key = "Spotlight",
				rect = {
					WIDTH - MARGIN - TOGGLE_HEIGHT,
					canvasHeight - TOGGLE_BOTTOM - TOGGLE_HEIGHT,
					TOGGLE_HEIGHT,
					TOGGLE_HEIGHT,
				},
				zIndex = 18,
			})
			else nil,

		--[[
			Above the storage meter, same as desktop. Narrower and shorter, because at 750x361 a 560px
			caption would span most of the screen.
		]]
		e(Parts.TutorialCaption, {
			key = "Tutorial",
			step = state.tutorialStep,
			total = state.tutorialTotal,
			width = WIDTH - MARGIN * 2 - 120,
			height = 88,
			position = UDim2.new(0.5, 0, 1, -(Theme.Safe.BottomBand + STORAGE_HEIGHT + 12)),
			anchorPoint = Vector2.new(0.5, 1),
			zIndex = 19,
			onSkip = actions.skipTutorial,
		}),

		-- Toggle sits at thumb height on the right edge, clear of the thumbstick
		-- and the jump button.
		e(Buttons.MenuButton, {
			key = "MenuToggle",
			text = if open then "CLOSE" else "MENU",
			glyph = if open then "cross" else "sliders",
			accent = if open then Theme.Gradient.Red else Theme.Gradient.Yellow,
			glow = not open,
			iconSize = 36,
			textSize = Theme.TextSize.Tiny,
			size = UDim2.fromOffset(TOGGLE_HEIGHT, TOGGLE_HEIGHT),
			position = UDim2.new(1, -MARGIN, 1, -TOGGLE_BOTTOM),
			anchorPoint = Vector2.new(1, 1),
			zIndex = 12,
			onClick = function()
				setOpen(not open)
			end,
		})
	)

	return e(P.Group, {
		key = props.key or "HudMobile",
		size = UDim2.fromScale(1, 1),
		zIndex = props.zIndex,
		children = children,
	})
end

return HudMobile
