--[[
	App/init.luau
	The whole client UI in one component.

		Root      Store provider + App, the single thing the client mounts
		App       HUD (desktop or mobile) + the active screen + toasts + confirm

	Only one screen is open at a time and the window never fills the viewport, so
	the game stays visible behind it -- which is the point of a simulator HUD.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent
local Theme = require(UI.Theme)
local Hooks = require(UI.Hooks)
local P = require(UI.Primitives)
local Overlays = require(UI.Components.Overlays)

local Store = require(script.Store)
local DevPanel = require(script.DevPanel)

local HudDesktop = require(UI.Screens.Hud.Desktop)
local UpgradesScreen = require(UI.Screens.UpgradesScreen)
local InventoryScreen = require(UI.Screens.InventoryScreen)
local PetsScreen = require(UI.Screens.PetsScreen)
local AreasScreen = require(UI.Screens.AreasScreen)
local PrestigeScreen = require(UI.Screens.PrestigeScreen)
local ShopScreen = require(UI.Screens.ShopScreen)
local SettingsScreen = require(UI.Screens.SettingsScreen)
local CollectionScreen = require(UI.Screens.CollectionScreen)
local MagnetShopScreen = require(UI.Screens.MagnetShopScreen)
local ChangelogScreen = require(UI.Screens.ChangelogScreen)
local DailyRewardsScreen = require(UI.Screens.DailyRewardsScreen)
local SpinScreen = require(UI.Screens.SpinScreen)
local AdminScreen = require(UI.Screens.AdminScreen)
local EggSummonScreen = require(UI.Screens.EggSummonScreen)
local EggRollOverlay = require(UI.Screens.EggRollOverlay)
local Announcement = require(UI.Components.Announcement)
local GameData = require(UI.GameData)
local NotificationStack = require(UI.Screens.NotificationStack)
local Details = require(UI.Screens.DetailsModal)

local e = React.createElement

--[[
	Screens that own the whole display. Keyed by the same id as `SCREENS`.

	`spin` is here because the wheel is something you watch rather than something you read: it blurs
	the world, fills the middle of the screen, and has nothing else to compete with.
]]
local TAKEOVER_SCREENS = {
	spin = true,
}

local SCREENS = {
	upgrades = UpgradesScreen,
	inventory = InventoryScreen,
	pets = PetsScreen,
	areas = AreasScreen,
	prestige = PrestigeScreen,
	shop = ShopScreen,
	settings = SettingsScreen,
	collection = CollectionScreen,
	-- Opened by the world booth's proximity prompt via OpenMagnetShop.
	magnetshop = MagnetShopScreen,
	-- Opened by the far-left TopbarPlus icon.
	changelog = ChangelogScreen,
	--[[
		Both of these have real servers behind them now -- `DailyRewardService` and `SpinService`.
		`daily` used to be in the "deliberately absent" list below because the game had no
		daily-reward system and a window with nothing behind it is worse than no window. It does now.
	]]
	daily = DailyRewardsScreen,
	spin = SpinScreen,
	--- Offered only to admins by the HUD; `AdminService` re-checks every command regardless.
	admin = AdminScreen,
}

--[[
	Deliberately absent:
	  plot           the kit ships this; this game has no plot cosmetic system, and a
	                 window with nothing behind it is worse than no window
	  leaderboards   LeaderboardService writes in-world SurfaceGui boards and
	                 exposes no client feed, so a menu version would be inventing
	                 data
]]

--------------------------------------------------------------------------------
-- App
--------------------------------------------------------------------------------

--[[
	props:
		device         "desktop" | "mobile" | nil  -- nil autodetects from the viewport
		scale          number?  -- overrides the computed UIScale (stories pass 1)
		dev            boolean? -- show the in-game test panel (F2)
		initialScreen  string?  -- open straight onto a window
]]
local function App(props)
	local state, actions = Store.use()

	local autoMobile = Hooks.useIsMobile()
	local computedScale = Hooks.useScale()
	local safe = Hooks.useSafeArea()

	-- The dev panel can force a layout; an explicit prop (stories) still wins.
	local deviceOverride, setDeviceOverride = React.useState(nil :: string?)

	local device = props.device or deviceOverride or (if autoMobile then "mobile" else "desktop")
	local isMobile = device == "mobile"
	local scale = props.scale or (if props.device then 1 else computedScale)

	-- Lets a story (or a deep link) open straight onto a window.
	React.useEffect(function()
		if props.initialScreen then
			actions.openScreen(props.initialScreen)
		else
			actions.closeScreen()
		end
	end, { props.initialScreen or "" })

	local ScreenComponent = if state.screen then SCREENS[state.screen] else nil

	--[[
		The hatch is a takeover: while it runs the HUD and any open window come down.
		Nothing should compete with the reveal, and there is nothing to misclick.
	]]
	local rolling = state.eggRoll ~= nil

	--[[
		Screens that take over the whole display rather than opening a window on top of it.

		A takeover hides the HUD and skips the shared dim wash, because it brings its own backdrop --
		the spin wheel blurs the world, and stacking App's flat wash on top of that just muddies it.
		The rule is the same one the egg hatch follows: nothing should compete with the thing the
		player is watching, and there is nothing to misclick.
	]]
	local takeoverScreen = TAKEOVER_SCREENS[state.screen or ""] == true
	local hudHidden = rolling or takeoverScreen

	--[[
		The pets being revealed, resolved from the ids the server sent.

		`PetIds` is the list a multi-hatch produced; `PetId` is the first of it and is what a single hatch
		has always used. Both are resolved here rather than in the overlay, because the lookup needs the
		egg's contents and `GameData.eggRoll` is a screen-level concern.

		A DUPLICATE IN THE BATCH IS ITS OWN ENTRY -- three of the same pet is three cards, because that is
		what happened. Deduplicating would hide the outcome the player is looking at.
	]]
	local revealPet = nil
	local revealPets = nil
	if rolling and (state.eggRoll.PetId or state.eggRoll.PetIds) then
		local egg = GameData.eggRoll(state.eggRoll.EggId, state.ownedPets)
		if egg then
			local byId = {}
			for _, pet in ipairs(egg.pets) do
				byId[pet.id] = pet
			end
			revealPet = byId[state.eggRoll.PetId]
			if type(state.eggRoll.PetIds) == "table" then
				revealPets = {}
				for _, petId in ipairs(state.eggRoll.PetIds) do
					local pet = byId[petId]
					if pet then
						table.insert(revealPets, pet)
					end
				end
			end
		end
	end

	local children = P.compact(
		e("UIScale", { key = "Scale", Scale = scale }),

		--[[
			Always the desktop HUD. The game is locked to landscape, so a phone gets
			the same arrangement scaled down rather than a separate portrait layout;
			`HudDesktop` handles the touch-control offsets itself. `Hud/Mobile.luau`
			is the portrait layout; it is still in the tree for its story but is no
			longer required here.
		]]
		if hudHidden
			then nil
			else e(HudDesktop, {
				key = "Hud",
				state = state,
				actions = actions,
				touch = props.touch,
				zIndex = Theme.Layer.Hud,
			}),

		--[[
			Dim wash behind an open window. Skipped for a takeover, which supplies its own -- see
			`TAKEOVER_SCREENS`.

			IT DOES NOT CLOSE THE WINDOW, and that is deliberate. Every backdrop here used to pass
			`onClick = actions.close*`, so any tap that missed a control dismissed what the player was
			reading -- a misjudged tap on the edge of a card, a drag that started inside the window and
			ended outside it, a click meant for a button that had already moved. A window closes from its
			own X button or from an action designed to close it, and nothing else.

			The `TextButton` stays, unclicked: it still has to swallow input so taps do not fall through
			to the world and the buttons behind it.
		]]
		if ScreenComponent
				and not rolling
				and not takeoverScreen
			then e(Overlays.Backdrop, {
				key = "Backdrop",
				transparency = 0.42,
				zIndex = Theme.Layer.Screen,
			})
			else nil,

		if ScreenComponent and not rolling
			then e(ScreenComponent, {
				key = "Screen",
				state = state,
				actions = actions,
			})
			else nil,

		--[[
			The egg podium's window. Not in `SCREENS`: it is opened by a world prompt
			with an egg id rather than by a menu button, so it has its own atom and can
			sit over whatever window was already open.
		]]
		if state.eggSummon and not rolling
			then e(Overlays.Backdrop, {
				key = "EggBackdrop",
				transparency = 0.42,
				zIndex = Theme.Layer.Screen + 20,
			})
			else nil,
		if state.eggSummon and not rolling
			then e(P.Group, {
				key = "EggSummon",
				size = UDim2.fromScale(1, 1),
				zIndex = Theme.Layer.Screen + 21,
				children = {
					e(EggSummonScreen, { key = "Window", state = state, actions = actions }),
				},
			})
			else nil,

		if rolling
			then e(EggRollOverlay, {
				key = "EggRoll",
				roll = state.eggRoll,
				pet = revealPet,
				pets = revealPets,
				onDismiss = actions.dismissEggRoll,
			})
			else nil,

		-- Item details sits above its parent window.
		if state.detail
			then e(Overlays.Backdrop, {
				key = "DetailBackdrop",
				transparency = 0.4,
				zIndex = Theme.Layer.Modal + 4,
			})
			else nil,
		if state.detail
			then e(P.Group, {
				key = "Details",
				size = UDim2.fromScale(1, 1),
				zIndex = Theme.Layer.Modal + 5,
				children = {
					e(
						Details.DetailsModal,
						{ key = "DetailsModal", state = state, actions = actions }
					),
				},
			})
			else nil,

		-- Confirmations sit above everything except toasts.
		if state.confirm
			then e(Overlays.Backdrop, {
				key = "ConfirmBackdrop",
				transparency = 0.5,
				zIndex = Theme.Layer.Modal + 8,
			})
			else nil,
		if state.confirm
			then e(Overlays.ConfirmModal, {
				key = "Confirm",
				-- Confirm specs use PascalCase keys, matching the rest of the
				-- game's shared data shapes.
				title = state.confirm.Title,
				glyph = state.confirm.Glyph,
				glyphGradient = state.confirm.GlyphGradient,
				headerColor = state.confirm.HeaderColor,
				lines = state.confirm.Lines,
				price = state.confirm.Price,
				robux = state.confirm.Robux,
				confirmText = state.confirm.ConfirmText,
				confirmVariant = state.confirm.ConfirmVariant,
				confirmDisabled = state.confirm.ConfirmDisabled,
				cancelText = state.confirm.CancelText,
				zIndex = Theme.Layer.Modal + 9,
				onCancel = actions.closeConfirm,
				onConfirm = function()
					local onConfirm = state.confirm.OnConfirm
					actions.closeConfirm()
					if onConfirm then
						onConfirm()
					end
				end,
			})
			else nil,

		if props.dev
			then e(DevPanel, {
				key = "DevPanel",
				state = state,
				actions = actions,
				deviceOverride = deviceOverride,
				setDeviceOverride = setDeviceOverride,
			})
			else nil,

		--[[
			Server-wide news, above everything including the takeover: a Secret hatch
			that happened to land while this player was mid-roll is still news.
		]]
		if state.announce
			then e(Announcement.Banner, {
				key = "Announce",
				title = if state.announce.Kind == "SecretPet"
					then "Secret Hatch!"
					else (state.announce.Title or "Announcement"),
				body = if state.announce.Kind == "SecretPet"
					then string.format(
						"%s hatched %s",
						tostring(state.announce.PlayerName),
						tostring(state.announce.PetName)
					)
					else state.announce.Body,
				accent = Theme.rarity(state.announce.Rarity or "Secret").gradient,
				model = state.announce.PetId,
				modelKind = "pet",
				glyph = "star",
				--[[
					A Secret hatch gets the chord and the sparkles; anything else arrives quietly.

					This is the only server-wide interruption in the game, and it was silent -- so unless a
					player happened to be looking at the top of their screen when it dropped, the rarest event
					in the game passed them by.
				]]
				sound = if state.announce.Kind == "SecretPet" then "secret" else nil,
				celebrate = state.announce.Kind == "SecretPet",
				top = safe.top,
			})
			else nil,

		e(NotificationStack, {
			key = "Notifications",
			toasts = state.toasts,
			--[[
				Top-right on every device. The potion tiles used to sit here and
				pushed toasts down; they now live in the bottom-right corner, so
				this band is free. `safe.top` is measured live, so it holds at any
				UIScale and never rides under Roblox's own strip.
			]]
			position = UDim2.new(1, -24, 0, safe.top + 8),
			anchorPoint = Vector2.new(1, 0),
			width = if isMobile then 280 else 320,
		})
	)

	--[[
		The UIScale above shrinks this frame as well as its contents, so a plain
		`fromScale(1, 1)` canvas ends up covering only `scale` of the screen and
		everything anchored to a bottom or right edge lands short. Pre-divide so
		the canvas measures the full viewport *after* scaling. With scale = 1
		(stories, which are sized by Stage) this is exactly `fromScale(1, 1)`.
	]]
	return e("Frame", {
		key = props.key or "ScrapyardUI",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1 / scale, 1 / scale),
	}, children)
end

--------------------------------------------------------------------------------
-- Root
--------------------------------------------------------------------------------

local function Root(props)
	props = props or {}
	return e(Store.Provider, {
		key = "Store",
		mock = props.mock,
		children = e(App, {
			key = "App",
			device = props.device,
			scale = props.scale,
			dev = props.dev,
			initialScreen = props.initialScreen,
		}),
	})
end

return {
	Root = Root,
	App = App,
	Store = Store,
	screens = SCREENS,
}
