--[[
	Every pressable surface in the kit, plus a live playground driven by UI Labs
	controls so variants can be checked without editing code.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)

local Harness = require(script.Parent.Parent.Harness)

local Theme = UI.Theme
local Buttons = UI.Buttons

local e = React.createElement

local VARIANTS = {
	"Primary",
	"Secondary",
	"Purchase",
	"Danger",
	"Premium",
	"Event",
	"Shop",
	"Neutral",
	"Disabled",
}

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Buttons",
	summary = "Button variants, icon buttons, menu tiles, tabs and the buy-amount stepper.",
	controls = {
		Text = UILabs.String("UPGRADE"),
		Variant = UILabs.Choose(VARIANTS, 1),
		Glyph = UILabs.Choose(
			{ "none", "coin", "magnet", "bolt", "check", "basket", "recycle" },
			1
		),
		Disabled = UILabs.Boolean(false),
		Width = UILabs.Slider(240, 120, 460, 10),
		Height = UILabs.Slider(56, 34, 90, 2),
		-- Menu-tile switches; the HUD ships FlatIcon on.
		FlatIcon = UILabs.Boolean(true),
		NewFlag = UILabs.Boolean(false),
		Wiggle = UILabs.Boolean(false),
	},
}, function(props)
	local controls = props.controls

	local playground = {
		e(Buttons.Button, {
			key = "Playground",
			text = controls.Text,
			variant = controls.Variant,
			glyph = if controls.Glyph == "none" then nil else controls.Glyph,
			disabled = controls.Disabled,
			size = UDim2.fromOffset(controls.Width, controls.Height),
		}),
	}

	local variantItems = {}
	for _, variant in ipairs(VARIANTS) do
		variantItems[#variantItems + 1] = e(Buttons.Button, {
			key = variant,
			text = string.upper(variant),
			variant = variant,
			size = UDim2.fromOffset(200, 56),
		})
	end

	local withIcons = {
		e(Buttons.Button, {
			key = "Buy",
			text = "BUY",
			glyph = "coin",
			variant = "Purchase",
			size = UDim2.fromOffset(180, 56),
		}),
		e(Buttons.Button, {
			key = "Equip",
			text = "EQUIP",
			glyph = "check",
			variant = "Primary",
			size = UDim2.fromOffset(180, 56),
		}),
		e(Buttons.Button, {
			key = "Prestige",
			text = "PRESTIGE",
			glyph = "recycle",
			variant = "Premium",
			size = UDim2.fromOffset(200, 56),
		}),
		e(Buttons.Button, {
			key = "BuyMax",
			text = "UPGRADE",
			subtext = "MAX",
			variant = "Primary",
			size = UDim2.fromOffset(180, 62),
		}),
		e(Buttons.Button, {
			key = "Skip",
			text = "SKIP REBIRTH",
			subtext = "R$ 199",
			glyph = "recycle",
			variant = "Purchase",
			size = UDim2.fromOffset(240, 62),
		}),
	}

	local iconButtons = {
		e(Buttons.IconButton, { key = "Plus", glyph = "plus", variant = "Primary" }),
		e(Buttons.IconButton, { key = "Sliders", glyph = "sliders", variant = "Neutral" }),
		e(Buttons.IconButton, { key = "Book", glyph = "book", variant = "Premium" }),
		e(Buttons.IconButton, { key = "Trophy", glyph = "trophy", variant = "Purchase" }),
		e(Buttons.IconButton, { key = "Close", glyph = "cross", variant = "Danger", extent = 46 }),
		e(Buttons.IconButton, { key = "Locked", glyph = "lock", disabled = true }),
	}

	--[[
		The real HUD list, with `flatIcon` on, which is how the game ships them: no
		gradient tile behind the art, larger icon. Turn `FlatIcon` off in the
		controls to compare against the tiled variant.
	]]
	local menuTiles = {}
	for _, item in ipairs(UI.Screens.HudParts.MENU_ITEMS) do
		menuTiles[#menuTiles + 1] = e(Buttons.MenuButton, {
			key = item.id,
			text = item.text,
			glyph = item.glyph,
			accent = Theme.Gradient[item.accent],
			badge = item.badge,
			flatIcon = controls.FlatIcon,
			iconSize = if controls.FlatIcon then 60 else nil,
			isNew = controls.NewFlag,
			wiggle = controls.Wiggle,
		})
	end

	--[[
		`isNew` draws the corner flag and `wiggle` is the occasional attention
		nudge. Both are switched on the shipped SHOP slab through `Parts.SHOP`.
	]]
	local wide = {
		e(Buttons.WideMenuButton, {
			key = "Shop",
			text = UI.Screens.HudParts.SHOP.text,
			glyph = "basket",
			accent = Theme.Gradient.Pink,
			gradient = ColorSequence.new(Color3.fromHex("2B3E5E"), Color3.fromHex("16273F")),
			flatIcon = controls.FlatIcon,
			isNew = controls.NewFlag,
			newText = UI.Screens.HudParts.SHOP.newText,
			wiggle = controls.Wiggle,
			size = UDim2.fromOffset(218, 68),
		}),
		e(Buttons.WideMenuButton, {
			key = "Plain",
			text = "NO FLAG",
			glyph = "bag",
			accent = Theme.Gradient.Blue,
			flatIcon = controls.FlatIcon,
			size = UDim2.fromOffset(218, 68),
		}),
	}

	local tabs = {
		e(Buttons.TabButton, { key = "Active", text = "MAGNETS", glyph = "magnet", active = true }),
		e(
			Buttons.TabButton,
			{ key = "Inactive", text = "SKINS", glyph = "palette", active = false }
		),
		e(Buttons.TabBar, {
			key = "Bar",
			tabs = {
				{ id = "PASSES", text = "GAME PASSES" },
				{ id = "CASH", text = "CASH" },
				{ id = "BOOSTERS", text = "BOOSTERS" },
			},
			active = "CASH",
			size = UDim2.fromOffset(500, 44),
			hAlign = Enum.HorizontalAlignment.Left,
		}),
	}

	local steppers = {
		e(Buttons.Stepper, { key = "One", active = "x1", size = UDim2.fromOffset(200, 34) }),
		e(Buttons.Stepper, { key = "Max", active = "MAX", size = UDim2.fromOffset(200, 34) }),
	}

	return e(Harness.Gallery, {
		title = "Buttons",
		sections = {
			{
				title = "Playground (use the controls panel)",
				items = playground,
				itemSize = UDim2.fromOffset(controls.Width, controls.Height + 6),
			},
			{ title = "Variants", items = variantItems, itemSize = UDim2.fromOffset(200, 62) },
			{
				title = "With icons and subtext",
				items = withIcons,
				itemSize = UDim2.fromOffset(250, 68),
			},
			{ title = "Icon buttons", items = iconButtons, itemSize = UDim2.fromOffset(52, 52) },
			{
				title = "Menu tiles (the real HUD list)",
				items = menuTiles,
				itemSize = UDim2.fromOffset(118, 118),
			},
			{ title = "Wide menu button", items = wide, itemSize = UDim2.fromOffset(230, 82) },
			{ title = "Tabs", items = tabs, itemSize = UDim2.fromOffset(510, 50) },
			{
				title = "Buy amount stepper",
				items = steppers,
				itemSize = UDim2.fromOffset(210, 40),
			},
		},
	})
end)
