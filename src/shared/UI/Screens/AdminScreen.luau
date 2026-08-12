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

	THAT APPLIES TO THE OWNER TIER TOO. Entries and targets flagged `Owner` are filtered out for an admin
	here, and `AdminService` refuses them regardless of what this file drew -- see `AdminConfig` for where
	the line sits and why. Filtering is so an admin is not shown buttons that will only tell them no.

	TWO KINDS OF SECTION. Most are a button per entry: pick a target, tap a thing, it happens. A section
	flagged `Mode = "MultiSelect"` is a tick list with one action button instead, for decisions that are
	only made together -- "double cash and triple luck for half an hour" is one announcement, not four
	commands.

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
--[[
	WIDE ENOUGH FOR THE TAB STRIP, and COMPUTED from it rather than typed.

	At 620 the last tab hung off the edge of the column, so the column was widened to fit six. Then
	TITLES made it seven and it overflowed again -- which is the whole argument for deriving the number:
	the strip's width is a fact about how many sections `AdminCatalogue` produces, and hardcoding it
	means every new section is a silent layout bug waiting for someone to notice.

	A panel whose own navigation does not fit is broken in the most visible way possible.
]]
local TAB_WIDTH = 104
local TAB_GAP = 6

--- Sized to whatever the catalogue produced, with room for the amount box under it.
local function rightWidth(sectionCount: number): number
	local strip = sectionCount * TAB_WIDTH + math.max(0, sectionCount - 1) * TAB_GAP
	return math.max(620, strip + 8)
end
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

--[[
	One line of a multi-select list: a tick box and a label, as one wide button.

	Deliberately the same `Buttons.Button` the single-shot rows use, in a different variant. A bespoke
	checkbox row would drift from the rest of the panel's metrics, and the tick is carried by the glyph
	and the variant rather than by a separate control.
]]
local function SelectRow(props)
	return e(Buttons.Button, {
		key = props.entry.Id,
		text = props.entry.Label,
		glyph = if props.selected then "check" else props.entry.Glyph,
		variant = if props.selected then "Primary" else "Neutral",
		textSize = Theme.TextSize.Small,
		size = UDim2.new(1, 0, 0, ENTRY_HEIGHT),
		layoutOrder = props.layoutOrder,
		onClick = function()
			props.onToggle(props.entry.Id)
		end,
	})
end

local function AdminScreen(props)
	local state = props.state
	local actions = props.actions

	--[[
		The catalogue, filtered to this player's tier.

		Rebuilt when `isOwner` changes rather than once, because the panel is shared code and a story or a
		dev-panel preview can render it as either tier.
	]]
	--- `props.isOwner` is the story override; live, the tier comes from the store.
	local isOwner = if props.isOwner ~= nil then props.isOwner == true else state.isOwner == true
	local sections = React.useMemo(function()
		local built = AdminCatalogue.build()
		if isOwner then
			return built
		end
		local allowed = {}
		for _, section in ipairs(built) do
			if section.Owner ~= true then
				local entries = {}
				for _, entry in ipairs(section.Entries) do
					if entry.Owner ~= true then
						table.insert(entries, entry)
					end
				end
				--- A section whose every entry was owner-only has nothing left to show.
				if #entries > 0 then
					local copy = table.clone(section)
					copy.Entries = entries
					table.insert(allowed, copy)
				end
			end
		end
		return allowed
	end, { isOwner })

	local target, setTarget = React.useState("Self")
	local pickedUserId, setPickedUserId = React.useState(nil :: number?)
	local amountText, setAmountText = React.useState("1000")
	local activeSection, setActiveSection = React.useState(sections[1] and sections[1].Id or "")
	--- Which dangerous entry is one tap from firing, cleared on any other interaction.
	local armed, setArmed = React.useState(nil :: string?)
	--- Ticked entries in the active multi-select section, keyed by entry id.
	local selected, setSelected = React.useState({} :: { [string]: boolean })

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
		--- Every-server is owner-only; an admin never sees the button rather than being refused by it.
		if mode.Owner == true and not isOwner then
			continue
		end
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
	local RIGHT_WIDTH = rightWidth(#sections)

	local sectionTabs = {}
	for index, section in ipairs(sections) do
		sectionTabs[#sectionTabs + 1] = e(Buttons.TabButton, {
			key = section.Id,
			text = section.Label,
			glyph = section.Glyph,
			active = activeSection == section.Id,
			size = UDim2.fromOffset(TAB_WIDTH, 38),
			layoutOrder = index,
			textSize = Theme.TextSize.Tiny,
			onClick = function()
				setArmed(nil)
				--- A tick list belongs to its section; carrying ticks across tabs would fire the wrong thing.
				setSelected({})
				setActiveSection(section.Id)
			end,
		})
	end

	local entryRows = {}
	for _, section in ipairs(sections) do
		if section.Id ~= activeSection then
			continue
		end
		if section.Mode == "MultiSelect" then
			local count = 0
			for _, on in pairs(selected) do
				if on then
					count += 1
				end
			end
			for index, entry in ipairs(section.Entries) do
				entryRows[#entryRows + 1] = e(SelectRow, {
					key = entry.Id,
					entry = entry,
					selected = selected[entry.Id] == true,
					layoutOrder = index,
					onToggle = function(id)
						local next = table.clone(selected)
						next[id] = not next[id]
						setSelected(next)
					end,
				})
			end
			--[[
				ONE COMMAND FOR THE WHOLE SELECTION, with the ids comma-joined.

				Not one call per tick: separate calls would stagger the start times by a round trip each
				and spend a rate-limit slot apiece. The server splits the list -- see `ActivateBoost` in
				`AdminMutate`.
			]]
			entryRows[#entryRows + 1] = e(Buttons.Button, {
				key = "MultiAction",
				text = if count == 0
					then "PICK SOMETHING FIRST"
					else `{section.ActionLabel} ({count})`,
				glyph = "check",
				variant = if count == 0 then "Neutral" else "Purchase",
				textSize = Theme.TextSize.Small,
				size = UDim2.new(1, 0, 0, ENTRY_HEIGHT + 8),
				layoutOrder = #section.Entries + 1,
				onClick = function()
					if count == 0 then
						return
					end
					local ids = {}
					for _, entry in ipairs(section.Entries) do
						if selected[entry.Id] then
							table.insert(ids, entry.ItemId or entry.Id)
						end
					end
					actions.adminCommand(
						section.Command,
						amount,
						target,
						pickedUserId,
						table.concat(ids, ",")
					)
					setSelected({})
				end,
			})
			continue
		end
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
		--- The tier is in the title, because which buttons exist depends on it.
		title = if isOwner then "Admin - Owner" else "Admin",
		glyph = "sliders",
		headerColor = if isOwner then Theme.Gradient.Purple else Theme.Gradient.Red,
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
							padding = TAB_GAP,
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
