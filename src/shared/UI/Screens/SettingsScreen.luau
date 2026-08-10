--[[
	SettingsScreen.luau

	SETTINGS window: AUDIO / GAMEPLAY / UI sections, sliders for volume and
	explicit ON / OFF toggles for everything else. Toggles spell out their state
	because a bare switch is ambiguous at mobile sizes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local P = require(UI.Primitives)
local Buttons = require(UI.Components.Buttons)
local Indicators = require(UI.Components.Indicators)
local Inputs = require(UI.Components.Inputs)
local Overlays = require(UI.Components.Overlays)

local e = React.createElement

--[[
	Keys are the field names in `Shared/Types/PlayerData.PlayerSettings` -- the
	exact set the server persists and validates. The kit shipped six more rows
	(other players' effects, magnet range, notifications, reduced motion) which
	nothing behind the UI reads; a toggle that remembers nothing is worse than no
	toggle, so they are not rendered. Add the field to `PlayerSettings` first, then
	the row here.
]]
local TOGGLES = {
	{ section = "GAMEPLAY", key = "ParticlesEnabled", label = "Particles" },
	{ section = "GAMEPLAY", key = "ScreenEffectsEnabled", label = "Screen Effects" },
	{ section = "AUDIO", key = "SoundEnabled", label = "Sound Effects" },
	{ section = "AUDIO", key = "MusicEnabled", label = "Music" },
}

--[[
	Code redemption. The client sends the raw string and nothing else; CodeService
	validates it, and the CodeResult remote toasts success or failure through
	Bridge. There is deliberately no local success path.
]]
local function CodeCard(props)
	local text, setText = React.useState("")

	return e(P.Panel, {
		key = "CodeCard",
		size = UDim2.new(1, 0, 0, 96),
		layoutOrder = props.layoutOrder,
		radius = Theme.Radius.Small,
		color = Theme.Color.PanelDark,
		gradient = Theme.Gradient.PanelDeep,
		strokeThickness = Theme.Stroke.Chip,
		studs = false,
		children = {
			P.padding({ x = 12, y = 10 }, "Inset"),
			e(P.Label, {
				key = "Title",
				text = "REDEEM CODE",
				textSize = Theme.TextSize.Body,
				align = Enum.TextXAlignment.Left,
				size = UDim2.new(1, 0, 0, 24),
				zIndex = 3,
			}),
			e("TextBox", {
				key = "Entry",
				Text = text,
				PlaceholderText = "ENTER CODE",
				PlaceholderColor3 = Theme.Color.GrayDark,
				ClearTextOnFocus = false,
				FontFace = Theme.Font.Bold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Color.White,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundColor3 = Theme.Color.Slot,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -150, 0, 40),
				Position = UDim2.fromScale(0, 1),
				AnchorPoint = Vector2.new(0, 1),
				ZIndex = 3,

				[React.Event.FocusLost] = function(rbx)
					setText(rbx.Text)
				end,
			}, {
				P.corner(Theme.Radius.Small),
				-- Border mode: a contextual stroke outlines the glyphs and makes
				-- typed text unreadable.
				P.stroke(Theme.Color.Outline, Theme.Stroke.Chip),
				P.padding({ x = 10 }, "EntryInset"),
			}),
			e(Buttons.Button, {
				key = "Redeem",
				text = "REDEEM",
				variant = "Primary",
				textSize = Theme.TextSize.Small,
				size = UDim2.fromOffset(136, 40),
				position = UDim2.fromScale(1, 1),
				anchorPoint = Vector2.new(1, 1),
				lip = 4,
				zIndex = 4,
				onClick = function()
					local trimmed = string.upper((string.gsub(text, "%s", "")))
					if #trimmed == 0 then
						return
					end
					props.onRedeem(trimmed)
					setText("")
				end,
			}),
		},
	})
end

local function SettingsScreen(props)
	local state = props.state
	local actions = props.actions
	local settings = state.settings

	local rows = {}
	local order = 0

	local function push(child)
		order += 1
		rows[#rows + 1] = child
	end

	local function sliderRow(key: string, label: string)
		push(e(Inputs.SettingRow, {
			key = label,
			label = label,
			layoutOrder = order + 1,
			children = {
				e(Inputs.Slider, {
					key = "Control",
					value = settings[key],
					gradient = Theme.Gradient.Cyan,
					height = 30,
					knobExtent = 34,
					size = UDim2.new(1, -6, 0, 34),
					layoutOrder = 1,
					onChange = function(value)
						actions.setSetting(key, value)
					end,
				}),
			},
		}))
	end

	local function toggleRow(key: string, label: string)
		push(e(Inputs.SettingRow, {
			key = label,
			label = label,
			layoutOrder = order + 1,
			children = {
				e(Inputs.Toggle, {
					key = "Control",
					value = settings[key],
					layoutOrder = 1,
					onChange = function(value)
						actions.setSetting(key, value)
					end,
				}),
			},
		}))
	end

	push(
		e(
			Indicators.SectionHeader,
			{ key = "AudioHeader", text = "Audio", layoutOrder = order + 1 }
		)
	)
	for _, entry in ipairs(TOGGLES) do
		if entry.section == "AUDIO" then
			toggleRow(entry.key, entry.label)
		end
	end
	sliderRow("MusicVolume", "Music Volume")
	sliderRow("SoundVolume", "Sound Volume")

	push(
		e(
			Indicators.SectionHeader,
			{ key = "GameplayHeader", text = "Gameplay", layoutOrder = order + 1 }
		)
	)
	for _, entry in ipairs(TOGGLES) do
		if entry.section == "GAMEPLAY" then
			toggleRow(entry.key, entry.label)
		end
	end

	push(
		e(Indicators.SectionHeader, { key = "CodeHeader", text = "Codes", layoutOrder = order + 1 })
	)
	push(e(CodeCard, { key = "CodeCard", layoutOrder = order + 1, onRedeem = actions.redeemCode }))

	return e(Overlays.Modal, {
		key = props.key or "SettingsScreen",
		title = "Settings",
		glyph = "sliders",
		headerColor = Theme.Gradient.Blue,
		size = UDim2.fromOffset(680, 660),
		onClose = actions.closeScreen,
		footerHeight = 66,
		footer = e(P.Group, {
			key = "Actions",
			size = UDim2.fromScale(1, 1),
			layout = P.list({
				direction = Enum.FillDirection.Horizontal,
				padding = 12,
				hAlign = Enum.HorizontalAlignment.Center,
				vAlign = Enum.VerticalAlignment.Center,
			}),
			children = {
				e(Buttons.Button, {
					key = "Reset",
					text = "RESET SETTINGS",
					variant = "Neutral",
					textSize = Theme.TextSize.Body,
					size = UDim2.fromOffset(260, 52),
					layoutOrder = 1,
					onClick = actions.resetSettings,
				}),
				e(Buttons.Button, {
					key = "Close",
					text = "CLOSE",
					variant = "Danger",
					size = UDim2.fromOffset(200, 52),
					layoutOrder = 2,
					onClick = actions.closeScreen,
				}),
			},
		}),
		children = {
			e(P.Scroller, {
				key = "SettingsList",
				padding = { right = 10, bottom = 6 },
				layout = P.list({ padding = 8 }),
				children = rows,
			}),
		},
	})
end

return SettingsScreen
