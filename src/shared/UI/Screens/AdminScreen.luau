--[[
	AdminScreen.luau
	Full control, in two columns.

	LEFT: who it lands on. Four target modes, then the player list when "picked player" is selected.
	RIGHT: what to give, in sections, with an amount box for the entries that take a number.

	THE SECTIONS ARE NOT WRITTEN HERE. They come from `AdminCatalogue.build()`, which walks
	`InventoryConfig`, `UpgradeConfig` and `PetConfig` -- so a new magnet or pet appears in this panel
	with no edit to this file. A hand-maintained grantables list drifts from the real content within a
	week, and an admin panel that lies about what exists is worse than no panel.

	NOTHING HERE IS SECURITY. Every button sends a command, a target and an item id; the server checks
	`AdminConfig.IsAdmin`, re-validates the command, clamps the amount and refuses `ResetTestProfile`
	outside Studio. Hiding the entry point from non-admins is a courtesy, not a lock.

	The one thing the UI does enforce is a CONFIRM on anything flagged `Danger`, because a mis-tap that
	wipes a save is not recoverable from in-game.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Format = require(UI.Format)
local P = require(UI.Primitives)
local Buttons = require(UI.Components.Buttons)
local Indicators = require(UI.Components.Indicators)
local Overlays = require(UI.Components.Overlays)
local AdminCatalogue = require(ReplicatedStorage.Shared.Config.AdminCatalogue)

local e = React.createElement

local LEFT_WIDTH = 300
local RIGHT_WIDTH = 620
local GAP = 16
local ENTRY_HEIGHT = 42

--- One grantable. Wide, flat and label-led, because this is a list to scan rather than a shop.
local function EntryRow(props)
	local entry = props.entry
	local armed = props.armed

	return e(Buttons.Button, {
		key = entry.Id,
		text = if armed then "TAP AGAIN TO CONFIRM" else entry.Label,
		glyph = entry.Glyph,
		variant = if entry.Danger then "Danger" elseif armed then "Purchase" else "Secondary",
		textSize = Theme.TextSize.Small,
		size = UDim2.new(1, 0, 0, ENTRY_HEIGHT),
		layoutOrder = props.layoutOrder,
		--- The amount box only applies to entries that take one; the rest say so.
		subtext = if entry.Amount then `x{props.amount}` else nil,
		subtextSize = Theme.TextSize.Micro,
		onClick = function()
			props.onFire(entry)
		end,
	})
end

local function AdminScreen(props)
	local state = props.state
	local actions = props.actions

	local sections = React.useMemo(function()
		return AdminCatalogue.build()
	end, {})

	local target, setTarget = React.useState("Self")
	local pickedUserId, setPickedUserId = React.useState(nil :: number?)
	local amountText, setAmountText = React.useState("1000")
	local activeSection, setActiveSection = React.useState(sections[1] and sections[1].Id or "")
	--- Which dangerous entry is one tap from firing, cleared on any other interaction.
	local armed, setArmed = React.useState(nil :: string?)

	local players = state.players or {}
	local amount = tonumber(amountText) or 0

	local function fire(entry)
		if entry.Danger and armed ~= entry.Id then
			setArmed(entry.Id)
			return
		end
		setArmed(nil)
		actions.adminCommand(
			entry.Command,
			if entry.Amount then amount else nil,
			target,
			pickedUserId,
			entry.ItemId
		)
	end

	--- Target buttons, straight from the catalogue so a new mode needs no edit here.
	local targetButtons = {}
	for index, mode in ipairs(AdminCatalogue.Targets) do
		targetButtons[#targetButtons + 1] = e(Buttons.Button, {
			key = mode.Id,
			text = mode.Label,
			glyph = mode.Glyph,
			--- The every-server option is styled as the serious one it is.
			variant = if target == mode.Id
				then (if mode.Wide then "Danger" else "Primary")
				else "Neutral",
			textSize = Theme.TextSize.Small,
			size = UDim2.new(1, 0, 0, 40),
			layoutOrder = index,
			onClick = function()
				setArmed(nil)
				setTarget(mode.Id)
			end,
		})
	end

	--[[
		The player list, only while "picked player" is the mode. Rendered from `state.players`, which the
		store refreshes on a ticker -- a list that goes stale as people join is worse than no list.
	]]
	local playerRows = {}
	if target == "Player" then
		for index, player in ipairs(players) do
			playerRows[#playerRows + 1] = e(Buttons.Button, {
				key = tostring(player.userId),
				text = player.name,
				variant = if pickedUserId == player.userId then "Primary" else "Neutral",
				textSize = Theme.TextSize.Tiny,
				size = UDim2.new(1, 0, 0, 34),
				layoutOrder = index,
				onClick = function()
					setPickedUserId(player.userId)
				end,
			})
		end
		if #playerRows == 0 then
			playerRows[1] = e(P.Label, {
				key = "Empty",
				text = "NOBODY ELSE HERE",
				textSize = Theme.TextSize.Tiny,
				color = Theme.Color.GrayDark,
				size = UDim2.new(1, 0, 0, 34),
			})
		end
	end

	--- Section tabs down the right column.
	local sectionTabs = {}
	for index, section in ipairs(sections) do
		sectionTabs[#sectionTabs + 1] = e(Buttons.TabButton, {
			key = section.Id,
			text = section.Label,
			glyph = section.Glyph,
			active = activeSection == section.Id,
			size = UDim2.fromOffset(122, 38),
			layoutOrder = index,
			textSize = Theme.TextSize.Tiny,
			onClick = function()
				setArmed(nil)
				setActiveSection(section.Id)
			end,
		})
	end

	local entryRows = {}
	for _, section in ipairs(sections) do
		if section.Id == activeSection then
			for index, entry in ipairs(section.Entries) do
				entryRows[#entryRows + 1] = e(EntryRow, {
					key = entry.Id,
					entry = entry,
					amount = Format.comma(amount),
					armed = armed == entry.Id,
					layoutOrder = index,
					onFire = fire,
				})
			end
		end
	end

	local targetLabel = target
	if target == "Player" then
		local name = "NOBODY"
		for _, player in ipairs(players) do
			if player.userId == pickedUserId then
				name = player.name
			end
		end
		targetLabel = name
	end

	return e(Overlays.Modal, {
		key = props.key or "AdminScreen",
		title = "Admin",
		glyph = "sliders",
		headerColor = Theme.Gradient.Red,
		width = LEFT_WIDTH + RIGHT_WIDTH + GAP + 56,
		contentHeight = 470,
		onClose = actions.closeScreen,
		headerRight = e(Indicators.Badge, {
			key = "Target",
			text = `-> {targetLabel}`,
			gradient = if target == "AllServers"
				then Theme.Gradient.Red
				else Theme.Gradient.PanelDeep,
			textSize = Theme.TextSize.Small,
		}),
		children = {
			--------------------------------------------------------------------
			-- Left: who
			--------------------------------------------------------------------
			e(P.Panel, {
				key = "Targets",
				size = UDim2.fromOffset(LEFT_WIDTH, 470),
				position = UDim2.fromScale(0, 0),
				gradient = Theme.Gradient.PanelDeep,
				radius = Theme.Radius.Panel,
				strokeThickness = Theme.Stroke.Card,
				studs = false,
				children = {
					e(P.Label, {
						key = "Heading",
						text = "WHO",
						textSize = Theme.TextSize.Small,
						color = Theme.Color.Gray,
						align = Enum.TextXAlignment.Left,
						position = UDim2.fromOffset(14, 10),
						size = UDim2.new(1, -28, 0, 20),
					}),
					e(P.Group, {
						key = "Modes",
						size = UDim2.new(1, -28, 0, 4 * 40 + 3 * 8),
						position = UDim2.fromOffset(14, 34),
						layout = P.list({ padding = 8 }),
						children = targetButtons,
					}),
					--- Only takes space when it has something to show.
					if target == "Player"
						then e(P.Scroller, {
							key = "Players",
							size = UDim2.new(1, -28, 1, -(34 + 4 * 40 + 3 * 8 + 24)),
							position = UDim2.fromOffset(14, 34 + 4 * 40 + 3 * 8 + 12),
							layout = P.list({ padding = 6 }),
							children = playerRows,
						})
						else nil,
				},
			}),
			--------------------------------------------------------------------
			-- Right: what
			--------------------------------------------------------------------
			e(P.Group, {
				key = "Grants",
				size = UDim2.fromOffset(RIGHT_WIDTH, 470),
				position = UDim2.fromScale(1, 0),
				anchorPoint = Vector2.new(1, 0),
				children = {
					e(P.Group, {
						key = "SectionTabs",
						size = UDim2.new(1, 0, 0, 38),
						layout = P.list({
							direction = Enum.FillDirection.Horizontal,
							padding = 6,
							hAlign = Enum.HorizontalAlignment.Left,
						}),
						children = sectionTabs,
					}),
					--[[
						The amount box sits with the grants, not with the targets: it modifies WHAT is given, and
						parking it in the left column made it read as part of choosing a player.
					]]
					e(P.Group, {
						key = "AmountRow",
						size = UDim2.new(1, 0, 0, 44),
						position = UDim2.fromOffset(0, 46),
						children = {
							e(P.Label, {
								key = "AmountLabel",
								text = "AMOUNT",
								textSize = Theme.TextSize.Tiny,
								color = Theme.Color.Gray,
								align = Enum.TextXAlignment.Left,
								size = UDim2.fromOffset(90, 44),
							}),
							--[[
								A raw TextBox, matching `SettingsScreen`'s code entry -- the kit has no text-field
								component, and one built for a single admin box would be a component with one
								caller. `FocusLost` rather than a per-keystroke handler, so a half-typed number
								never reaches the amount.
							]]
							e("TextBox", {
								key = "Amount",
								Text = amountText,
								PlaceholderText = "1000",
								PlaceholderColor3 = Theme.Color.GrayDark,
								ClearTextOnFocus = false,
								FontFace = Theme.Font.Bold,
								TextSize = Theme.TextSize.Body,
								TextColor3 = Theme.Color.White,
								BackgroundColor3 = Theme.Color.Slot,
								BorderSizePixel = 0,
								Size = UDim2.fromOffset(200, 40),
								Position = UDim2.fromOffset(94, 2),

								[React.Event.FocusLost] = function(rbx)
									setAmountText(rbx.Text)
								end,
							}, {
								P.corner(Theme.Radius.Small),
								-- Border mode: a contextual stroke outlines the glyphs and makes typed
								-- text unreadable.
								P.stroke(Theme.Color.Outline, Theme.Stroke.Chip),
								P.padding({ x = 10 }, "EntryInset"),
							}),
							e(P.Label, {
								key = "Hint",
								text = "APPLIES TO CASH, GEARS, POTIONS, UPGRADES AND PETS",
								textSize = Theme.TextSize.Micro,
								font = Theme.Font.Body,
								color = Theme.Color.GrayDark,
								align = Enum.TextXAlignment.Left,
								position = UDim2.fromOffset(306, 0),
								size = UDim2.new(1, -306, 1, 0),
							}),
						},
					}),
					e(P.Scroller, {
						key = "Entries",
						size = UDim2.new(1, 0, 1, -100),
						position = UDim2.fromOffset(0, 100),
						layout = P.list({ padding = 6 }),
						children = entryRows,
					}),
				},
			}),
		},
	})
end

return AdminScreen
