--[[
	Bars, badges, currency rows, stat pills, inputs, tooltips and toasts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)

local Harness = require(script.Parent.Parent.Harness)

local Theme = UI.Theme
local Indicators = UI.Indicators
local Inputs = UI.Inputs
local Overlays = UI.Overlays

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Bars, Badges & Inputs",
	summary = "Progress bars, badges, currency rows, HUD stat pills, sliders, toggles, tooltips and toasts.",
	controls = {
		Storage = UILabs.Slider(650, 0, 1000, 10),
		Volume = UILabs.Slider(0.7, 0, 1, 0.05),
		ToggleOn = UILabs.Boolean(true),
	},
}, function(props)
	local controls = props.controls
	local volume, setVolume = React.useState(controls.Volume)
	local toggle, setToggle = React.useState(controls.ToggleOn)

	local bars = {
		e(Indicators.ProgressBar, {
			key = "Storage",
			value = controls.Storage,
			max = 1000,
			gradient = Theme.Gradient.Cyan,
			fullText = "STORAGE FULL!",
			size = UDim2.fromOffset(420, 34),
		}),
		e(Indicators.ProgressBar, {
			key = "Full",
			value = 1000,
			max = 1000,
			fullText = "STORAGE FULL!",
			size = UDim2.fromOffset(420, 34),
		}),
		e(Indicators.ProgressBar, {
			key = "Collection",
			value = 82,
			max = 154,
			gradient = Theme.Gradient.Purple,
			size = UDim2.fromOffset(420, 30),
		}),
	}

	local badges = {
		e(Indicators.RarityBadge, { key = "Normal", rarity = "Normal" }),
		e(Indicators.RarityBadge, { key = "Gold", rarity = "Gold" }),
		e(Indicators.RarityBadge, { key = "Diamond", rarity = "Diamond" }),
		e(Indicators.RarityBadge, { key = "Radioactive", rarity = "Radioactive" }),
		e(Indicators.RarityBadge, { key = "Admin", rarity = "Admin" }),
		e(
			Indicators.QuantityBadge,
			{ key = "Quantity", count = 12, position = nil, anchorPoint = nil }
		),
		e(Indicators.TimerBadge, { key = "Timer", seconds = 522 }),
		e(Indicators.Badge, { key = "New", text = "NEW!", gradient = Theme.Gradient.Red }),
		e(Indicators.Badge, {
			key = "BestValue",
			text = "BEST VALUE",
			gradient = Theme.Gradient.Green,
			textSize = Theme.TextSize.Small,
		}),
		e(Indicators.Checkmark, { key = "Check" }),
	}

	local currencies = {
		e(Indicators.CurrencyDisplay, {
			key = "Cash",
			glyph = "coin",
			gradient = Theme.Gradient.Green,
			formatted = UI.Format.money(337_800_000),
			onAdd = function() end,
		}),
		e(Indicators.CurrencyDisplay, {
			key = "Gears",
			glyph = "gear",
			gradient = Theme.Gradient.Gold,
			formatted = UI.Format.comma(42),
			onAdd = function() end,
		}),
		e(Indicators.CurrencyDisplay, {
			key = "Event",
			glyph = "star",
			gradient = Theme.Gradient.Cyan,
			formatted = UI.Format.comma(1250),
		}),
	}

	--[[
		`StatPill` is what the HUD readouts are built from now -- a slab, an icon on
		the left, a value. `CurrencyDisplay` above is the older row with the inline
		+ button, still used by nothing on the HUD.
	]]
	local pills = {
		e(Indicators.StatPill, {
			key = "PillCash",
			value = UI.Format.money(1_284_500),
			gradient = Theme.Gradient.Money,
			font = Theme.Font.Money,
			textSize = Theme.TextSize.Hero,
			width = 240,
			height = 62,
		}),
		e(Indicators.StatPill, {
			key = "PillCashRound",
			value = UI.Format.money(100_000),
			gradient = Theme.Gradient.Money,
			font = Theme.Font.Money,
			textSize = Theme.TextSize.Hero,
			width = 240,
			height = 62,
		}),
		e(Indicators.StatPill, {
			key = "PillGears",
			glyph = "gear",
			value = UI.Format.comma(42),
			iconGradient = Theme.Gradient.Gold,
			width = 240,
		}),
		e(Indicators.StatPill, {
			key = "PillRebirth",
			glyph = "recycle",
			value = UI.Format.comma(3),
			iconGradient = Theme.Gradient.Purple,
			width = 240,
		}),
	}

	local inputs = {
		e(Inputs.Slider, {
			key = "Volume",
			value = volume,
			gradient = Theme.Gradient.Cyan,
			size = UDim2.fromOffset(300, 40),
			onChange = setVolume,
		}),
		e(Inputs.Toggle, {
			key = "Toggle",
			value = toggle,
			onChange = setToggle,
		}),
		e(Indicators.StatRow, {
			key = "Stat",
			label = "RANGE",
			value = "20 studs",
			glyph = "pin",
			size = UDim2.fromOffset(300, 44),
		}),
		e(Indicators.PriceTag, { key = "Price", cash = 42500, textSize = Theme.TextSize.Title }),
	}

	local floating = {
		e(Overlays.Tooltip, {
			key = "Tooltip",
			title = "Golden Magnet",
			body = "Pulls scrap that others walk past.",
			hint = "Unlock at Prestige 5",
			width = 280,
		}),
		e(Overlays.Toast, {
			key = "Toast",
			title = "Rare Scrap!",
			body = "Golden Engine",
			reward = "+ $4,250",
			glyph = "coin",
			accent = Theme.Gradient.Gold,
		}),
		e(Overlays.Toast, {
			key = "Toast2",
			title = "Area Unlocked!",
			body = "Vehicle Graveyard",
			glyph = "pin",
			accent = Theme.Gradient.Green,
		}),
	}

	return e(Harness.Gallery, {
		title = "Bars, badges and inputs",
		sections = {
			{ title = "Progress bars", items = bars, itemSize = UDim2.fromOffset(430, 40) },
			{ title = "Badges", items = badges, itemSize = UDim2.fromOffset(150, 40) },
			{
				title = "Currency displays",
				items = currencies,
				itemSize = UDim2.fromOffset(220, 52),
			},
			{
				title = "Stat pills (the HUD readouts)",
				items = pills,
				itemSize = UDim2.fromOffset(250, 70),
			},
			{ title = "Inputs and stats", items = inputs, itemSize = UDim2.fromOffset(310, 48) },
			{
				title = "Tooltip and toasts",
				items = floating,
				itemSize = UDim2.fromOffset(340, 130),
			},
		},
	})
end)
