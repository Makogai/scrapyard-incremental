--[[
	DevPanel.luau
	In-game test panel. Collapsed to a single small tab until you open it.

	Hitting Play gives you the HUD, which can reach every window on its own -- but
	not every *state*. This panel exists so you can drive the awkward ones from a
	live session: force the mobile layout on a desktop, empty the storage or fill
	it to see STORAGE FULL, push a toast, hand yourself enough cash to afford the
	prestige, or open a window directly.

	Toggle with F2, or the DEV tab on the right edge.

	Not shipped to players: App only renders it when `dev` is true, and the client
	bootstrap only passes that in Studio.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Format = require(UI.Format)
local Sound = require(UI.Sound)
local Mock = require(UI.Mock)
local P = require(UI.Primitives)
local Buttons = require(UI.Components.Buttons)
local Indicators = require(UI.Components.Indicators)

local e = React.createElement

local SCREEN_BUTTONS = {
	{ id = "upgrades", text = "UPGRADES" },
	{ id = "inventory", text = "INVENTORY" },
	{ id = "pets", text = "PETS" },
	{ id = "areas", text = "AREAS" },
	{ id = "prestige", text = "PRESTIGE" },
	{ id = "shop", text = "SHOP" },
	{ id = "settings", text = "SETTINGS" },
	{ id = "daily", text = "DAILY" },
	{ id = "collection", text = "COLLECTION" },
	{ id = "plot", text = "PLOT" },
	{ id = "leaderboards", text = "BOARDS" },
}

local DETAIL_BUTTONS = {
	{ text = "MAGNET", kind = "magnet", id = "advanced" },
	{ text = "LOCKED MAGNET", kind = "magnet", id = "blood" },
	{ text = "POTION", kind = "potion", id = "cash" },
	{ text = "PET", kind = "pet", id = "gear_bot" },
}

local WIDTH = 250

local function DevPanel(props)
	local state = props.state
	local actions = props.actions
	local open, setOpen = React.useState(false)
	local toastIndex, setToastIndex = React.useState(1)
	-- Audio is off in Studio's edit mode so UI Labs stays quiet; this exposes it
	-- so you can hear the cues while play-testing either way.
	local audio, setAudio = React.useState(Sound.isEnabled())

	-- F2 toggles the panel. Bound on the client only; harmless in a story.
	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == Enum.KeyCode.F2 then
				setOpen(function(previous)
					return not previous
				end)
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	if not open then
		return e(Buttons.Button, {
			key = "DevTab",
			text = "DEV",
			variant = "Neutral",
			textSize = Theme.TextSize.Tiny,
			size = UDim2.fromOffset(58, 34),
			position = UDim2.new(1, -6, 0.5, 0),
			anchorPoint = Vector2.new(1, 0.5),
			lip = 3,
			inset = 4,
			zIndex = Theme.Layer.Tooltip,
			onClick = function()
				setOpen(true)
			end,
		})
	end

	local rows = {}
	local function push(child)
		rows[#rows + 1] = child
		return #rows
	end

	local function section(title: string)
		push(e(Indicators.SectionHeader, {
			key = title,
			text = title,
			textSize = Theme.TextSize.Small,
			size = UDim2.new(1, 0, 0, 24),
			layoutOrder = #rows + 1,
		}))
	end

	--- A row of small buttons that wraps.
	local function buttonRow(key: string, items: { any })
		local children = {}
		for index, item in ipairs(items) do
			children[#children + 1] = e(Buttons.Button, {
				key = item.text,
				text = item.text,
				variant = item.variant or "Secondary",
				textSize = Theme.TextSize.Micro,
				size = UDim2.fromOffset(item.width or 76, 30),
				lip = 3,
				inset = 3,
				layoutOrder = index,
				onClick = item.onClick,
			})
		end

		local perRow = math.max(1, math.floor(WIDTH / ((items[1] and items[1].width or 76) + 5)))
		local lines = math.ceil(#items / perRow)

		push(e(P.Group, {
			key = key,
			size = UDim2.new(1, 0, 0, lines * 30 + (lines - 1) * 5),
			layoutOrder = #rows + 1,
			layout = P.list({
				direction = Enum.FillDirection.Horizontal,
				padding = 5,
				wraps = true,
			}),
			children = children,
		}))
	end

	--------------------------------------------------------------- layout mode
	section("Layout & audio")
	buttonRow("AudioRow", {
		{
			text = if audio then "SOUND ON" else "SOUND OFF",
			width = 118,
			variant = if audio then "Primary" else "Neutral",
			onClick = function()
				Sound.setEnabled(not audio)
				setAudio(not audio)
				Sound.play("toggle")
			end,
		},
		{
			text = "TEST CUES",
			width = 118,
			variant = "Event",
			onClick = function()
				for index, cue in ipairs({ "click", "equip", "purchase", "claim", "error" }) do
					task.delay((index - 1) * 0.45, function()
						Sound.play(cue)
					end)
				end
			end,
		},
	})
	buttonRow("DeviceRow", {
		{
			text = "AUTO",
			width = 76,
			variant = if props.deviceOverride == nil then "Primary" else "Neutral",
			onClick = function()
				props.setDeviceOverride(nil)
			end,
		},
		{
			text = "DESKTOP",
			width = 76,
			variant = if props.deviceOverride == "desktop" then "Primary" else "Neutral",
			onClick = function()
				props.setDeviceOverride("desktop")
			end,
		},
		{
			text = "MOBILE",
			width = 76,
			variant = if props.deviceOverride == "mobile" then "Primary" else "Neutral",
			onClick = function()
				props.setDeviceOverride("mobile")
			end,
		},
	})

	------------------------------------------------------------------- screens
	section("Open screen")
	local screenItems = {}
	for _, entry in ipairs(SCREEN_BUTTONS) do
		screenItems[#screenItems + 1] = {
			text = entry.text,
			width = 118,
			variant = if state.screen == entry.id then "Primary" else "Secondary",
			onClick = function()
				if state.screen == entry.id then
					actions.closeScreen()
				else
					actions.openScreen(entry.id)
				end
			end,
		}
	end
	buttonRow("ScreenRow", screenItems)

	------------------------------------------------------------------- details
	section("Item details")
	local detailItems = {}
	for _, entry in ipairs(DETAIL_BUTTONS) do
		detailItems[#detailItems + 1] = {
			text = entry.text,
			width = 118,
			variant = "Premium",
			onClick = function()
				actions.openDetail(entry.kind, entry.id)
			end,
		}
	end
	buttonRow("DetailRow", detailItems)

	-------------------------------------------------------------------- states
	section("State")
	buttonRow("StateRow", {
		{
			text = "+$50M",
			width = 76,
			variant = "Purchase",
			onClick = function()
				actions.grant(50_000_000)
			end,
		},
		{
			text = "FILL",
			width = 76,
			variant = "Purchase",
			onClick = function()
				actions.collect(state.capacity)
			end,
		},
		{
			text = "SELL",
			width = 76,
			variant = "Primary",
			onClick = actions.sell,
		},
		{
			text = "TOAST",
			width = 76,
			variant = "Event",
			onClick = function()
				actions.notify(Mock.notifications[toastIndex])
				setToastIndex(toastIndex % #Mock.notifications + 1)
			end,
		},
		{
			text = "POTION",
			width = 76,
			variant = "Event",
			onClick = function()
				actions.usePotion("cash")
			end,
		},
		{
			text = "RESET",
			width = 76,
			variant = "Danger",
			onClick = actions.reset,
		},
	})

	------------------------------------------------------------------- readout
	section("Now")
	push(e(Indicators.StatRow, {
		key = "Cash",
		label = "CASH",
		value = Format.money(state.cash),
		valueColor = Theme.Color.Positive,
		textSize = Theme.TextSize.Small,
		size = UDim2.new(1, 0, 0, 32),
		layoutOrder = #rows + 1,
	}))
	push(e(Indicators.StatRow, {
		key = "Storage",
		label = "STORAGE",
		value = Format.fraction(state.storage, state.capacity),
		valueColor = Theme.Color.Cyan,
		textSize = Theme.TextSize.Small,
		size = UDim2.new(1, 0, 0, 32),
		layoutOrder = #rows + 1,
	}))
	push(e(Indicators.StatRow, {
		key = "Prestige",
		label = "PRESTIGE",
		value = tostring(state.prestige) .. "  /  " .. Format.comma(state.gears) .. " gears",
		valueColor = Theme.Color.Gold,
		textSize = Theme.TextSize.Small,
		size = UDim2.new(1, 0, 0, 32),
		layoutOrder = #rows + 1,
	}))

	return e(P.Panel, {
		key = props.key or "DevPanel",
		size = UDim2.fromOffset(WIDTH + 24, 560),
		position = UDim2.new(1, -6, 0.5, 0),
		anchorPoint = Vector2.new(1, 0.5),
		zIndex = Theme.Layer.Tooltip,
		radius = Theme.Radius.Card,
		color = Theme.Color.PanelDark,
		gradient = Theme.Gradient.PanelDeep,
		strokeColor = Theme.Color.Gold,
		strokeThickness = Theme.Stroke.Card,
		studs = false,
		shadow = true,
		children = {
			e(P.Label, {
				key = "Title",
				text = "DEV PANEL   F2",
				textSize = Theme.TextSize.Small,
				color = Theme.Color.Gold,
				align = Enum.TextXAlignment.Left,
				size = UDim2.new(1, -60, 0, 28),
				position = UDim2.fromOffset(12, 8),
				zIndex = 4,
			}),
			e(Buttons.IconButton, {
				key = "Close",
				glyph = "cross",
				variant = "Danger",
				extent = 28,
				glyphScale = 0.44,
				position = UDim2.new(1, -10, 0, 8),
				anchorPoint = Vector2.new(1, 0),
				zIndex = 5,
				onClick = function()
					setOpen(false)
				end,
			}),
			e(P.Scroller, {
				key = "Content",
				size = UDim2.new(1, -24, 1, -50),
				position = UDim2.fromOffset(12, 42),
				padding = { right = 8, bottom = 6 },
				layout = P.list({ padding = 6 }),
				children = rows,
				zIndex = 4,
			}),
		},
	})
end

return DevPanel
