--[[
	SCRAPYARD UI
	A complete Roblox React UI system for an incremental scrapyard simulator.

	Everything is exported from here so screens, stories and gameplay code have a
	single import:

		local UI = require(ReplicatedStorage.Shared.UI)
		local button = UI.Buttons.Button
		local theme = UI.Theme

	Layer map
		Theme / Format / Glyphs / Icon / Primitives   design tokens and atoms
		Components.*                                  the reusable kit
		Screens.*                                     assembled windows and HUD
		App.Root                                      the mountable application
		Mock                                          sample data
		Stage                                         fixed-size preview harness
]]

local Components = script.Components
local Screens = script.Screens

local Details = require(Screens.DetailsModal)
local Leaderboards = require(Screens.LeaderboardScreen)
local App = require(script.App)

return {
	-- foundations
	Theme = require(script.Theme),
	Format = require(script.Format),
	Glyphs = require(script.Glyphs),
	Assets = require(script.Assets),
	Icon = require(script.Icon),
	Primitives = require(script.Primitives),
	Motion = require(script.Motion),
	Sound = require(script.Sound),
	Hooks = require(script.Hooks),
	Stage = require(script.Stage),
	Mock = require(script.Mock),

	-- Game integration: config adapter and the server state layer.
	GameData = require(script.GameData),
	Atoms = require(script.State.Atoms),
	Bridge = require(script.State.Bridge),

	-- component kit
	Buttons = require(Components.Buttons),
	Indicators = require(Components.Indicators),
	Inputs = require(Components.Inputs),
	Overlays = require(Components.Overlays),
	Cards = require(Components.Cards),
	Rows = require(Components.Rows),
	ModelView = require(Components.ModelView),
	Announcement = require(Components.Announcement),
	Shop = require(Components.Shop),
	--- The pie-wedge prize wheel. See the module for why wedges are a fan of rotated bars.
	Wheel = require(Components.Wheel).Wheel,
	--- Reward announcement banner: symmetric gradient fade, icon well, item or money.
	RewardToast = require(Components.RewardToast),
	--- The look behind the reward banner, the event strip and the fade toasts.
	FadeBanner = require(Components.FadeBanner),
	--- Wide cards for titles and achievements.
	Progression = require(Components.Progression),

	-- screens
	Screens = {
		HudDesktop = require(Screens.Hud.Desktop),
		HudMobile = require(Screens.Hud.Mobile),
		HudParts = require(Screens.Hud.Parts),
		HudTopBar = require(Screens.Hud.TopBar).TopBar,
		Upgrades = require(Screens.UpgradesScreen),
		Inventory = require(Screens.InventoryScreen),
		Pets = require(Screens.PetsScreen),
		Areas = require(Screens.AreasScreen),
		Prestige = require(Screens.PrestigeScreen),
		Shop = require(Screens.ShopScreen),
		Settings = require(Screens.SettingsScreen),
		DailyRewards = require(Screens.DailyRewardsScreen),
		Spin = require(Screens.SpinScreen),
		Admin = require(Screens.AdminScreen),
		Collection = require(Screens.CollectionScreen),
		Changelog = require(Screens.ChangelogScreen),
		Splash = require(Screens.SplashScreen),
		EggSummon = require(Screens.EggSummonScreen),
		EggRoll = require(Screens.EggRollOverlay),
		MagnetShop = require(Screens.MagnetShopScreen),
		Notifications = require(Screens.NotificationStack),

		DetailsModal = Details.DetailsModal,
		DetailsFrame = Details.DetailsFrame,
		MagnetDetails = Details.MagnetDetails,
		PotionDetails = Details.PotionDetails,
		PetDetails = Details.PetDetails,

		Leaderboards = Leaderboards.LeaderboardScreen,
		LeaderboardPanel = Leaderboards.LeaderboardPanel,
	},

	-- application
	App = App.App,
	Root = App.Root,
	Store = App.Store,
}
