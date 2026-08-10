--[[
	Feel: hover scale, press sink, spring meters, and the audio cues.

	Sound is muted in Studio's edit mode so browsing stories stays quiet -- flip
	the Audio control on to hear the cues here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)

local Harness = require(script.Parent.Parent.Harness)

local Theme = UI.Theme
local Motion = UI.Motion
local Sound = UI.Sound
local P = UI.Primitives
local Buttons = UI.Buttons
local Indicators = UI.Indicators

local e = React.createElement

local CUES = {
	"hover",
	"click",
	"tap",
	"toggle",
	"open",
	"close",
	"equip",
	"sell",
	"purchase",
	"claim",
	"prestige",
	"notify",
	"error",
}

--- Storage meter that fills on its own, to show the spring settling.
local function LiveMeter()
	local value, setValue = React.useState(320)

	return e(P.Group, {
		key = "LiveMeter",
		size = UDim2.fromOffset(440, 84),
		layout = P.list({ padding = 8 }),
		children = {
			e(Indicators.ProgressBar, {
				key = "Bar",
				value = value,
				max = 1000,
				gradient = Theme.Gradient.Cyan,
				fullText = "STORAGE FULL!",
				size = UDim2.fromOffset(440, 34),
				layoutOrder = 1,
			}),
			e(P.Group, {
				key = "Controls",
				size = UDim2.fromOffset(440, 34),
				layoutOrder = 2,
				layout = P.list({ direction = Enum.FillDirection.Horizontal, padding = 8 }),
				children = {
					e(Buttons.Button, {
						key = "Add",
						text = "+250",
						variant = "Primary",
						textSize = Theme.TextSize.Small,
						size = UDim2.fromOffset(100, 34),
						lip = 4,
						layoutOrder = 1,
						onClick = function()
							setValue(math.min(1000, value + 250))
						end,
					}),
					e(Buttons.Button, {
						key = "Empty",
						text = "EMPTY",
						variant = "Danger",
						textSize = Theme.TextSize.Small,
						size = UDim2.fromOffset(100, 34),
						lip = 4,
						layoutOrder = 2,
						onClick = function()
							setValue(0)
						end,
					}),
					e(Buttons.Button, {
						key = "Fill",
						text = "FULL",
						variant = "Purchase",
						textSize = Theme.TextSize.Small,
						size = UDim2.fromOffset(100, 34),
						lip = 4,
						layoutOrder = 3,
						onClick = function()
							setValue(1000)
						end,
					}),
				},
			}),
		},
	})
end

--- A square that springs between two sizes, to show the presets side by side.
local function SpringSample(props)
	local big, setBig = React.useState(false)
	local scale, motion = Motion.useMotion(1)

	React.useEffect(function()
		motion:spring(if big then 1.35 else 1, props.options)
	end, { big })

	return e("TextButton", {
		key = props.name,
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(150, 110),

		[React.Event.Activated] = function()
			setBig(not big)
		end,
	}, {
		e(P.Panel, {
			key = "Box",
			size = UDim2.fromOffset(96, 66),
			position = UDim2.fromScale(0.5, 0.42),
			anchorPoint = Vector2.new(0.5, 0.5),
			radius = Theme.Radius.Card,
			color = Theme.Color.Card,
			gloss = 0.84,
			studs = false,
			children = {
				e("UIScale", { key = "Scale", Scale = scale }),
				e(
					P.Label,
					{ key = "Name", text = props.name, textSize = Theme.TextSize.Small, zIndex = 3 }
				),
			},
		}),
		e(P.Label, {
			key = "Hint",
			text = "tap to spring",
			textSize = Theme.TextSize.Tiny,
			font = Theme.Font.Bold,
			color = Theme.Color.Gray,
			size = UDim2.new(1, 0, 0, 18),
			position = UDim2.fromScale(0.5, 0.88),
			anchorPoint = Vector2.new(0.5, 0.5),
		}),
	})
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Motion & Sound",
	summary = "Hover scale, press sink, spring presets, spring-driven meters and every audio cue.",
	controls = {
		Audio = UILabs.Boolean(false),
	},
}, function(props)
	React.useEffect(function()
		Sound.setEnabled(props.controls.Audio)
	end, { props.controls.Audio })

	local pressables = {
		e(Buttons.Button, {
			key = "Primary",
			text = "HOVER ME",
			variant = "Primary",
			size = UDim2.fromOffset(190, 58),
		}),
		e(Buttons.Button, {
			key = "Purchase",
			text = "BUY",
			variant = "Purchase",
			glyph = "coin",
			size = UDim2.fromOffset(160, 58),
		}),
		e(Buttons.IconButton, { key = "Icon", glyph = "plus", variant = "Secondary", extent = 52 }),
		e(
			Buttons.MenuButton,
			{ key = "Tile", text = "PETS", glyph = "paw", accent = Theme.Gradient.Pink }
		),
		e(Buttons.MenuButton, {
			key = "Glow",
			text = "SHOP",
			glyph = "basket",
			accent = Theme.Gradient.Pink,
			glow = true,
		}),
		e(Buttons.Button, {
			key = "Disabled",
			text = "DISABLED",
			disabled = true,
			size = UDim2.fromOffset(170, 58),
		}),
	}

	local springs = {
		e(SpringSample, { key = "Snappy", name = "Snappy", options = Motion.Spring.Snappy }),
		e(SpringSample, { key = "Gentle", name = "Gentle", options = Motion.Spring.Gentle }),
		e(SpringSample, { key = "Bouncy", name = "Bouncy", options = Motion.Spring.Bouncy }),
		e(SpringSample, { key = "Slow", name = "Slow", options = Motion.Spring.Slow }),
	}

	local cueButtons = {}
	for index, cue in ipairs(CUES) do
		cueButtons[#cueButtons + 1] = e(Buttons.Button, {
			key = cue,
			text = string.upper(cue),
			variant = "Secondary",
			textSize = Theme.TextSize.Tiny,
			size = UDim2.fromOffset(112, 36),
			lip = 4,
			silent = true,
			layoutOrder = index,
			onClick = function()
				Sound.setEnabled(true)
				Sound.play(cue)
				Sound.setEnabled(props.controls.Audio)
			end,
		})
	end

	return e(Harness.Gallery, {
		title = "Motion & sound",
		sections = {
			{
				title = "Hover and press (all springs)",
				items = pressables,
				itemSize = UDim2.fromOffset(196, 116),
			},
			{ title = "Spring presets", items = springs, itemSize = UDim2.fromOffset(156, 116) },
			{
				title = "Spring-driven meter",
				items = { e(LiveMeter, { key = "Meter" }) },
				itemSize = UDim2.fromOffset(446, 90),
			},
			{
				title = "Audio cues (click to hear)",
				items = cueButtons,
				itemSize = UDim2.fromOffset(114, 40),
				gap = 6,
			},
		},
	})
end)
