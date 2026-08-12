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
		                          flag one `isNew`), `SHOP` the wide slab's flag
		                          and wiggle. The centre travel buttons are NOT
		                          here -- they are TopbarPlus icons, in
		                          `client/Controllers/TopbarController`.
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

	--[[
		Where the event banner hangs, just under the topbar strip.

		These two numbers used to position the travel row that lived here; the row is now three
		TopbarPlus icons (see `TopbarController`), so all that is left is the height to clear. Kept as
		named numbers rather than folded into one, because what the banner is dodging is the strip
		TopbarPlus draws in, and that is worth saying.
	]]
	local topbarStripTop = 6
	local topbarStripHeight = 44

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
		--[[
			`P.compact`, NOT a table literal. Two entries in here are conditional -- the admin icon and the
			tutorial spotlight -- and both sit mid-list. A nil there leaves a hole, `ipairs` stops at it,
			and every child after it is dropped: with a literal, a NON-ADMIN player lost the teleport bar,
			the currencies, the status cluster, the storage meter and the boosts, because the admin icon
			resolved to nil ahead of them.

			AGENTS.md rule 17. This file is the reason it is not optional.
		]]
		children = P.compact(
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
				dailyResetSeconds = state.dailyResetSeconds,
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
			--[[
				The slim gauge, sitting LOWER than the panel version did.

				Two changes for one complaint. The panel version is 560x96 authored, which at the HUD's 1.25
				scale is 700x120 real pixels of studded window across the bottom of the screen -- for two
				numbers. It also sat a full `MARGIN` up from the edge, so it read as a slab floating in the
				play area rather than as chrome. `Slim` folds its labels into the bar, and half the margin
				puts it where a status readout belongs.

				`bottomLift` is still respected: on touch, Roblox draws its own controls over that corner.
			]]
			--[[
				Server-wide notices, centred under the top bar: subtle, and out of the way of the travel
				row. Returns nil when there is nothing to say, so it costs no space in the common case.
			]]
			e(Parts.ServerNotice, {
				key = "ServerNotice",
				broadcast = state.broadcast,
				restart = state.restart,
				position = UDim2.new(0.5, 0, 0, Theme.Safe.Top + 74),
				anchorPoint = Vector2.new(0.5, 0),
			}),
			--- Social rewards down the right edge; disappears as they are claimed.
			e(Parts.SocialColumn, {
				key = "Social",
				socialClaims = state.socialClaims,
				friendCount = state.friendCount,
				onClaim = actions.claimSocial,
				onClaimInvite = actions.claimInvite,
				position = UDim2.new(1, -MARGIN, 0.42, 0),
				anchorPoint = Vector2.new(1, 0.5),
			}),
			e(Parts.StorageMeter, {
				key = "Storage",
				variant = "Slim",
				storage = state.storage,
				capacity = state.capacity,
				value = state.storageValue,
				position = UDim2.new(0.5, 0, 1, -(math.floor(MARGIN / 2) + bottomLift)),
				anchorPoint = Vector2.new(0.5, 1),
			}),
			--[[
				Only when there is an event to name. Rendered unconditionally, this component fell back to
				its own hardcoded "SCRAP RUSH EVENT -- 3x scrap value" and lied to every player forever
				(audit 3.3). `state.event` is nil when the schedule has nothing, and nil is safe here
				because this list goes through `P.compact`.
			]]
			if state.event
				then e(Parts.EventBanner, {
					key = "EventBanner",
					title = state.event.title,
					detail = state.event.detail,
					glyph = state.event.glyph,
					accent = state.event.accent,
					seconds = state.event.seconds,
					live = state.event.live,
					position = UDim2.new(0.5, 0, 0, topbarStripTop + topbarStripHeight + 8),
					anchorPoint = Vector2.new(0.5, 0),
				})
				else nil,
			--[[
				THE WAY INTO THE PIT, and the only one.

				Directly under the event banner that announced it, because that banner is where the player
				just read the words "a shared arena outside" -- and an arena you are told about but cannot
				find is worse than no arena.

				It exists ONLY while an arena event is live: `state.event` is nil when nothing is on, and
				`arena` is false for the events that are just multipliers. The server refuses the teleport
				when the Pit is shut anyway (see `TeleportService`), so this is the honest half of a check
				that is enforced on both sides.
			]]
			if state.event and state.event.arena
				then e(Buttons.Button, {
					key = "EnterPit",
					text = "ENTER THE PIT",
					glyph = "crate",
					variant = "Danger",
					textSize = Theme.TextSize.Small,
					size = UDim2.fromOffset(210, 46),
					lip = 5,
					wiggle = { every = 5, angle = 3 },
					position = UDim2.new(0.5, 0, 0, topbarStripTop + topbarStripHeight + 78),
					anchorPoint = Vector2.new(0.5, 0),
					onClick = function()
						actions.teleport("Pit")
					end,
				})
				else nil,
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
			})
		),
	})
end

return HudDesktop
