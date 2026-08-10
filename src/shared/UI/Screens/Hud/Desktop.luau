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
local Parts = require(script.Parent.Parts)

local e = React.createElement

local MARGIN = 24

--- Vertical room the bottom-right friend widget occupies, so boosts stack above it.
local FRIEND_LANE = 82

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
				--[[
					Lifted above the friend icon rather than sharing the corner. Boost tiles come and
					go, so overlapping them with a permanent widget means the corner reflows every
					time a potion expires.
				]]
				position = UDim2.new(1, -MARGIN, 1, -(MARGIN + bottomLift + FRIEND_LANE)),
				anchorPoint = Vector2.new(1, 1),
			}),
			--[[
				BOTTOM RIGHT, as asked. It is a permanent fixture rather than a notification: the
				point of the friend boost is that it is always visible, so a player who has none
				knows there is something to get.
			]]
			e(Parts.FriendBoost, {
				key = "FriendBoost",
				count = state.friendCount,
				boost = state.friendBoost,
				position = UDim2.new(1, -MARGIN, 1, -(MARGIN + bottomLift)),
				anchorPoint = Vector2.new(1, 1),
				onClick = function()
					actions.openScreen("spin")
				end,
			}),
			--- Above the storage meter, which is the other thing that fills as you play.
			e(Parts.PlaytimeTrack, {
				key = "PlaytimeTrack",
				milestones = state.playtimeMilestones,
				claimed = state.playtimeClaimed,
				seconds = state.playtimeSeconds,
				position = UDim2.new(0.5, 0, 1, -(MARGIN + bottomLift + 74)),
				anchorPoint = Vector2.new(0.5, 1),
				onClaim = actions.claimPlaytime,
			}),
			--[[
				Centred under the travel bar, where the player is already looking, and only while the
				chain is unfinished -- `TutorialCaption` renders nothing once `step` is nil.
			]]
			e(Parts.TutorialCaption, {
				key = "Tutorial",
				step = state.tutorialStep,
				total = state.tutorialTotal,
				position = UDim2.new(0.5, 0, 0, travelTop + travelHeight + 74),
				anchorPoint = Vector2.new(0.5, 0),
				onSkip = actions.skipTutorial,
			}),
		},
	})
end

return HudDesktop
