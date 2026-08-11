--[[
	Desktop.luau
	Main gameplay HUD, authored at 1920x1080.

	Layout intent -- the middle of the screen stays empty, and the top-left corner
	is left entirely to Roblox:

		top strip     Roblox's own chrome on the LEFT, TopbarPlus icons on the
		              right (INDEX, SETTINGS) and far left (UPDATES)
		left          2-column menu grid, Shop spanning both columns, centred
		              vertically on the screen edge
		bottom-left   gears / rebirths / cash
		bottom-centre scrap storage meter
		              (both lift clear of the touch controls on a phone)
		top-centre    travel row in the topbar strip, event banner directly under it
		bottom-right  active potion tiles, hover for what each one does

	INDEX and SETTINGS are not here: they are TopbarPlus icons, registered by
	`client/Controllers/TopbarController`.

	WHERE TO CHANGE THINGS

		this file                 where each cluster sits: margins, anchors, the
		                          order they stack. Nothing here draws anything --
		                          it only places `Parts`.
		Hud/Parts.luau            what is in each cluster. `MENU_ITEMS` is the
		                          left-hand grid (add/remove/reorder a tile, or
		                          flag one `isNew`), `TELEPORT_ITEMS` the travel
		                          row, `SHOP` the wide slab's flag and wiggle.
		Hud/Mobile.luau           the portrait layout. Not routed to: the game is
		                          landscape-locked, so phones use this file scaled.
		../../Theme.luau          every colour, gradient, font, text size, corner
		                          radius, outline width and safe-area inset.
		../../Assets.luau         every image id: `Icons` by glyph name, `Plates`
		                          for chrome art, `Art` per entity.
		../../Components/         the reusable pieces themselves -- `Buttons`
		                          (MenuButton, WideMenuButton), `Indicators`
		                          (StatPill, ProgressBar), `Overlays` (Modal).
		../../Motion.luau         spring presets and the wiggle timing.
		client/Controllers/TopbarController.luau
		                          the TopbarPlus icons and what they open.

	Rule of thumb: position -> this file, content -> Parts, look -> Theme,
	pictures -> Assets.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent.Parent
local Theme = require(UI.Theme)
local Hooks = require(UI.Hooks)
local P = require(UI.Primitives)
local Buttons = require(UI.Components.Buttons)
local Parts = require(script.Parent.Parts)

local e = React.createElement

local MARGIN = 24

--- Vertical room the bottom-left status cluster occupies, so the currencies sit above it.
local STATUS_LANE = 74

local function HudDesktop(props)
	local state = props.state
	local actions = props.actions
	local safe = Hooks.useSafeArea()
	-- Detected normally; `props.touch` forces it, which is how the dev panel and
	-- the device-matrix checks exercise the touch offsets on a desktop Studio.
	local detectedTouch = Hooks.useIsTouch()
	local touch = if props.touch ~= nil then props.touch else detectedTouch

	--[[
		Touch adjustments. Roblox draws its thumbstick over the bottom-left and a
		jump button over the bottom-right, and the distinction that matters is
		whether one of our clusters would *steal the touch*:

		  menu column   buttons, so it must genuinely clear the thumbstick. On
		                touch it hangs from the top and uses smaller tiles, which
		                is the only arrangement change between pointer and touch.
		  cash / storage  plain frames with no input, so they cannot block
		                movement. They still lift by the touch band so the stick
		                does not draw straight through the numbers.

		Everything else keeps its desktop position.
	]]
	local bottomLift = if touch then Theme.Safe.BottomBand else 0

	-- The travel row sits *inside* the topbar strip. Roblox's chrome only takes
	-- the left of that strip, so the middle is ours and the bar can hug the top
	-- edge. The event banner then hangs directly beneath it.
	local travelTop = 6
	local travelHeight = 44

	--[[
		The UPGRADE tile's rectangle, for the tutorial spotlight.

		Derived from the SAME numbers that position `MenuGrid` two lines below rather than measured off
		the instance: measuring would mean threading a ref out of a shared component purely so one
		optional overlay can find it. The cost is that these have to move together -- if the menu is
		repositioned, this follows.

		UPGRADE is the first cell of the grid, so it is the top-left tile.
	]]
	local viewport = Hooks.useViewport()
	local scale = Hooks.useScale()
	local canvasHeight = viewport.Y / math.max(scale, 0.01)
	local tile = if touch then 92 else 104
	local menuTop = if touch then (safe.top + 8) else (canvasHeight / 2 - (tile * 2 + 10 + 68) / 2)
	local upgradeRect = { MARGIN, menuTop, tile, tile }

	return e(P.Group, {
		key = props.key or "HudDesktop",
		size = UDim2.fromScale(1, 1),
		zIndex = props.zIndex,
		children = {
			e(Parts.MenuGrid, {
				key = "Menu",
				-- Centred on the left edge, so the column stays balanced as tiles
				-- are added or removed; on touch it hangs from the top and shrinks,
				-- to stay out of the thumbstick's reach.
				position = if touch
					then UDim2.fromOffset(MARGIN, safe.top + 8)
					else UDim2.new(0, MARGIN, 0.5, 0),
				anchorPoint = if touch then Vector2.zero else Vector2.new(0, 0.5),
				tile = if touch then 92 else nil,
				shopHeight = if touch then 58 else nil,
				onOpen = actions.openScreen,
			}),
			--[[
				ADMIN ENTRY POINT. Deliberately quiet: an unlabelled icon tucked under the topbar strip on the
				right, no ADMIN text, at 34px against the 46px utility buttons, and only drawn for admins. It
				is a tool, not a feature, and a loud button for it in a kids' game invites everyone else to
				ask what it is.

				Hiding it is a courtesy, not a lock -- `AdminService` checks `IsAdmin` on every command.
			]]
			if state.isAdmin
				then e(Buttons.IconButton, {
					key = "Admin",
					glyph = "admin",
					variant = "Neutral",
					extent = 34,
					glyphScale = 0.62,
					position = UDim2.new(1, -MARGIN, 0, safe.top + 6),
					anchorPoint = Vector2.new(1, 0),
					zIndex = 12,
					onClick = function()
						actions.openScreen("admin")
					end,
				})
				else nil,
			e(Parts.TeleportBar, {
				key = "Travel",
				height = travelHeight,
				position = UDim2.new(0.5, 0, 0, travelTop),
				anchorPoint = Vector2.new(0.5, 0),
				onTeleport = actions.teleport,
			}),
			e(Parts.CurrencyStack, {
				key = "Currencies",
				cash = state.cash,
				gears = state.gears,
				prestige = state.prestige,
				position = UDim2.new(0, MARGIN, 1, -(MARGIN + bottomLift)),
				anchorPoint = Vector2.new(0, 1),
			}),
			--[[
				BOTTOM RIGHT: daily login boost, friend boost, spin wheel. Bare outlined glyphs with their
				value underneath and a popup on hover -- the same class of readout as the potion tiles,
				which is why they share this corner and the boosts sit directly above them.
			]]
			e(Parts.StatusCluster, {
				key = "StatusCluster",
				dailyStreak = state.dailyStreak,
				dailyBoostPercent = state.dailyBoostPercent,
				dailyClaimable = state.dailyClaimable,
				friendCount = state.friendCount,
				friendBoost = state.friendBoost,
				spinsAvailable = state.spinsAvailable,
				position = UDim2.new(1, -MARGIN, 1, -(MARGIN + bottomLift)),
				anchorPoint = Vector2.new(1, 1),
				onOpenDaily = function()
					actions.openScreen("daily")
				end,
				onOpenSpin = function()
					actions.openScreen("spin")
				end,
			}),
			e(Parts.StorageMeter, {
				key = "Storage",
				storage = state.storage,
				capacity = state.capacity,
				value = math.floor(state.storage * 19.15),
				position = UDim2.new(0.5, 0, 1, -(MARGIN + bottomLift)),
				anchorPoint = Vector2.new(0.5, 1),
			}),
			e(Parts.EventBanner, {
				key = "EventBanner",
				position = UDim2.new(0.5, 0, 0, travelTop + travelHeight + 8),
				anchorPoint = Vector2.new(0.5, 0),
			}),
			e(Parts.BoostTimers, {
				key = "Boosts",
				boosts = state.boosts,
				--- Stacked above the status cluster, which owns the corner itself.
				position = UDim2.new(1, -MARGIN, 1, -(MARGIN + bottomLift + STATUS_LANE)),
				anchorPoint = Vector2.new(1, 1),
			}),
			--[[
				The spotlight, only on a step that names a SCREEN target. World steps get the 3D arrow from
				`TutorialArrowController` instead, and putting a dark wash over the screen while the player
				is meant to be walking around their yard would be actively unhelpful.

				Under the caption in z-order so the instructions stay readable through the dim.
			]]
			if state.tutorialStep and state.tutorialStep.Target == "upgrades"
				then e(Parts.TutorialSpotlight, {
					key = "Spotlight",
					rect = upgradeRect,
					zIndex = 18,
				})
				else nil,
			--[[
				Directly above the storage meter, which is where the player's eyes already are -- they are
				watching that bar fill. Renders nothing once the chain is finished.
			]]
			e(Parts.TutorialCaption, {
				key = "Tutorial",
				step = state.tutorialStep,
				total = state.tutorialTotal,
				position = UDim2.new(0.5, 0, 1, -(MARGIN + bottomLift + 92)),
				anchorPoint = Vector2.new(0.5, 1),
				zIndex = 19,
				onSkip = actions.skipTutorial,
			}),
		},
	})
end

return HudDesktop
