--[[
	The loading screen you see when you join.

	In game this is mounted by `client/Controllers/SplashController` into its own
	ScreenGui above everything, and it lifts once the client is actually ready. Here
	you can drive it by hand and find the numbers you want before committing them.

	=============================== WHERE TO TWEAK ===============================

	  the game icon        src/shared/UI/Assets.luau  ->  Assets.Icons.gameLogo
	                       paste it as "rbxassetid://0000000000"

	  logo box / positions src/shared/UI/Screens/SplashScreen.luau, the constants
	                       at the top: LOGO_WIDTH, LOGO_HEIGHT, LOGO_Y, TITLE_Y,
	                       BAR_WIDTH, BAR_HEIGHT

	  what counts as       src/client/Controllers/SplashController.luau ->
	  "loaded"             readinessSteps(); each entry is one segment of the bar

	  colours / fonts      src/shared/UI/Theme.luau, as everywhere else

	==============================================================================

	The `LogoWidth` / `LogoHeight` / `LogoY` / `TitleY` controls here map onto those
	constants, so whatever looks right in this story is the number to paste in.

	Two things worth knowing:

	1. The logo box is **wide, not square**, and uses `ScaleType.Fit`. A wide banner
	   fills the width; a square mark still centres. Neither is cropped or squashed.
	2. With no id in `Assets.Icons.gameLogo` this draws a plain "LOGO" placeholder.
	   If you have pasted an id and still see the placeholder in Studio, it is the
	   module cache -- reload the place.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)

local Stage = UI.Stage

local e = React.createElement

--- The bar's own captions, so the story can preview each stage.
local STATUSES = {
	"Connecting...",
	"Loading your yard...",
	"Loading pets...",
	"Waiting for your save...",
	"Almost there...",
	"Ready!",
}

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Splash",
	summary = "Join loading screen: game icon, title and progress bar.",
	controls = {
		Progress = UILabs.Slider(0.45, 0, 1, 0.01),
		Status = UILabs.Choose(STATUSES, 2),
		Title = UILabs.String("SCRAPYARD"),
		LogoWidth = UILabs.Slider(680, 200, 1200, 20),
		LogoHeight = UILabs.Slider(260, 120, 500, 10),
		LogoY = UILabs.Slider(0.36, 0.15, 0.6, 0.01),
		TitleY = UILabs.Slider(0.64, 0.4, 0.85, 0.01),
	},
}, function(props)
	local controls = props.controls

	return e(Stage, {
		key = "Stage",
		device = "desktop",
		-- No game view: this screen exists to cover it.
		gameView = false,
		children = {
			e(UI.Screens.Splash, {
				key = "Splash",
				progress = controls.Progress,
				status = controls.Status,
				title = controls.Title,
				logoWidth = controls.LogoWidth,
				logoHeight = controls.LogoHeight,
				logoY = controls.LogoY,
				titleY = controls.TitleY,
			}),
		},
	})
end)
