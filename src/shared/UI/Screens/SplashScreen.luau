--!nonstrict
--[[
	SplashScreen.luau
	What a player sees between joining and the game being ready.

	It covers everything, shows the game icon, and runs a loading bar across the
	bottom. It leaves when the client has what it needs -- see
	`client/Controllers/SplashController` for what "ready" means -- rather than after
	a fixed wait, so a fast join is a fast splash.

	==========================================================================
	  THE GAME ICON GOES IN `Assets.Icons.gameLogo`
	  (src/shared/UI/Assets.luau -- paste the id as "rbxassetid://0000000000")
	==========================================================================

	Until an id is there this draws a lettered placeholder, so the flow works with
	nothing uploaded.

	The bar reports real progress, not a timer: the controller counts the things it
	is waiting on and reports a fraction. A fake bar that finishes before the game
	does is worse than none, because the player then waits at 100%.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Assets = require(UI.Assets)
local Motion = require(UI.Motion)
local P = require(UI.Primitives)

local e = React.createElement

--[[
	=========================== TWEAK THE SPLASH HERE ===========================
	Design pixels on the 1920x1080 canvas. The logo box is deliberately WIDE, not
	square: `ScaleType.Fit` keeps a logo's own aspect ratio inside it, so a wide
	banner fills the width and a square mark still centres, and neither is cropped
	or squashed.

	The image id lives in `Assets.Icons.gameLogo` (src/shared/UI/Assets.luau).
	What counts as "loaded" lives in `client/Controllers/SplashController`.
	Preview all of it in the "Splash" story.
	=============================================================================
]]
local LOGO_WIDTH = 680
local LOGO_HEIGHT = 260
local LOGO_Y = 0.36
local TITLE_Y = 0.64
local BAR_WIDTH = 620
local BAR_HEIGHT = 26

--[[
	props:
		progress    0..1
		status      "Loading pets..." and so on
		title       game name, defaults to SCRAPYARD
		logoWidth / logoHeight / logoY / titleY
		            overrides for the constants above, so the story can
		            find a value live before you commit it
]]
local function SplashScreen(props)
	local progress = math.clamp(props.progress or 0, 0, 1)

	-- Springs, so a jump from 0.2 to 0.8 sweeps instead of snapping.
	local fill = Motion.useSpring(progress, Motion.Spring.Gentle)
	local logo = Assets.icon("gameLogo")

	return e(P.Group, {
		key = props.key or "Splash",
		size = UDim2.fromScale(1, 1),
		-- Above every other layer, including announcements: nothing should be
		-- visible behind a loading screen.
		zIndex = Theme.Layer.Announcement + 100,
		children = P.compact(
			-- Opaque, not a dim wash: this hides the game, it does not veil it.
			e("Frame", {
				key = "Backdrop",
				BackgroundColor3 = Theme.Color.PanelDark,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
			}, {
				P.gradient(
					ColorSequence.new(Theme.Color.Panel, Theme.Color.Ink),
					{ rotation = 90 }
				),
			}),
			-- The studded plate, so the loading screen looks like the game's own UI.
			e("Frame", {
				key = "Texture",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ClipsDescendants = true,
				ZIndex = 2,
			}, {
				e(P.Studs, { key = "Studs", area = Vector2.new(1920, 1080) }),
			}),

			if logo
				then e("ImageLabel", {
					key = "Logo",
					BackgroundTransparency = 1,
					Image = logo.id,
					ScaleType = Enum.ScaleType.Fit,
					-- Fit, never Stretch: a wide logo must not be squeezed square.
					Size = UDim2.fromOffset(
						props.logoWidth or LOGO_WIDTH,
						props.logoHeight or LOGO_HEIGHT
					),
					Position = UDim2.fromScale(0.5, props.logoY or LOGO_Y),
					AnchorPoint = Vector2.new(0.5, 0),
					ZIndex = 5,
				})
				else --[[
					Placeholder until an id is pasted into `Assets.Icons.gameLogo`. It is
					deliberately plain so nobody mistakes it for the real logo.
				]] e(P.Panel, {
					key = "LogoPlaceholder",
					size = UDim2.fromOffset(
						props.logoWidth or LOGO_WIDTH,
						props.logoHeight or LOGO_HEIGHT
					),
					position = UDim2.fromScale(0.5, props.logoY or LOGO_Y),
					anchorPoint = Vector2.new(0.5, 0.5),
					radius = Theme.Radius.Panel,
					color = Theme.Color.Slot,
					gradient = Theme.Gradient.PanelDeep,
					strokeThickness = Theme.Stroke.Panel,
					zIndex = 5,
					children = {
						e(P.Label, {
							key = "Mark",
							-- Names what is missing rather than pretending to be art.
							text = "LOGO",
							textSize = 88,
							size = UDim2.fromScale(1, 1),
							zIndex = 6,
						}),
					},
				}),

			e(P.Label, {
				key = "Title",
				text = props.title or "SCRAPYARD",
				textSize = Theme.TextSize.Hero,
				gradient = Theme.Gradient.Gold,
				size = UDim2.new(1, 0, 0, 64),
				position = UDim2.fromScale(0.5, props.titleY or TITLE_Y),
				anchorPoint = Vector2.new(0.5, 0.6),
				zIndex = 6,
			}),

			-- The bar, bottom centre, in the same slab style as the storage meter.
			e(P.Panel, {
				key = "BarTrack",
				size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT),
				position = UDim2.new(0.5, 0, 1, -110),
				anchorPoint = Vector2.new(0.5, 1),
				radius = Theme.Radius.Chip,
				color = Theme.Color.Slot,
				gradient = Theme.Gradient.Slot,
				strokeThickness = Theme.Stroke.Card,
				studs = false,
				zIndex = 6,
				children = {
					e("Frame", {
						key = "Fill",
						BackgroundColor3 = Theme.Color.Green,
						BorderSizePixel = 0,
						-- Bound to the spring, so it never re-renders to animate.
						Size = fill:map(function(value: number)
							return UDim2.fromScale(math.clamp(value, 0, 1), 1)
						end),
						ZIndex = 7,
					}, {
						P.corner(Theme.Radius.Chip),
						P.gradient(Theme.Gradient.Green),
					}),
				},
			}),
			e(P.Label, {
				key = "Status",
				text = props.status or "Loading...",
				textSize = Theme.TextSize.Body,
				color = Theme.Color.Gray,
				size = UDim2.new(1, 0, 0, 26),
				position = UDim2.new(0.5, 0, 1, -74),
				anchorPoint = Vector2.new(0.5, 1),
				zIndex = 6,
			}),
			e(P.Label, {
				key = "Percent",
				text = string.format("%d%%", math.floor(progress * 100 + 0.5)),
				textSize = Theme.TextSize.Small,
				color = Theme.Color.GrayDark,
				size = UDim2.new(1, 0, 0, 22),
				position = UDim2.new(0.5, 0, 1, -50),
				anchorPoint = Vector2.new(0.5, 1),
				zIndex = 6,
			})
		),
	})
end

return SplashScreen
