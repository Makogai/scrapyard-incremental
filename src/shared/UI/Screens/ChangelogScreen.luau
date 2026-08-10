--!nonstrict
--[[
	ChangelogScreen.luau

	UPDATES window, opened from the far-left TopbarPlus icon.

	Content comes from `Shared/Config/ChangelogConfig`, newest first, and the list
	is rendered in file order -- see that module's note on why it is not sorted here.

	One entry per release: a version pill, the date, a title, then one row per
	change tagged New / Fix / Balance. Every row auto-sizes its own height, so a
	long change wraps instead of being clipped, and the card grows to fit.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)
local Indicators = require(UI.Components.Indicators)
local Overlays = require(UI.Components.Overlays)

local ChangelogConfig = require(ReplicatedStorage.Shared.Config.ChangelogConfig)

local e = React.createElement

--- Tag colour and glyph per change kind. An unknown kind still renders, in grey.
local KIND = {
	New = { gradient = Theme.Gradient.Green, glyph = "star", label = "NEW" },
	Fix = { gradient = Theme.Gradient.Cyan, glyph = "check", label = "FIX" },
	Balance = { gradient = Theme.Gradient.Orange, glyph = "sliders", label = "BALANCE" },
}
local FALLBACK_KIND = { gradient = Theme.Gradient.Gray, glyph = "note", label = "CHANGE" }

local ROW_TEXT_SIZE = Theme.TextSize.Body
local TAG_WIDTH = 96
local ROW_PADDING = 8

--- One change line: a coloured tag on the left, wrapped text on the right.
local function ChangeRow(props)
	local kind = KIND[props.kind] or FALLBACK_KIND

	return e(P.Group, {
		key = props.key,
		size = UDim2.fromScale(1, 0),
		-- Y only: the row spans the card's width and grows to fit its text.
		automaticSize = Enum.AutomaticSize.Y,
		layoutOrder = props.layoutOrder,
		children = {
			e(Indicators.Badge, {
				key = "Tag",
				text = kind.label,
				gradient = kind.gradient,
				textSize = Theme.TextSize.Micro,
				size = UDim2.fromOffset(TAG_WIDTH - 10, 22),
				position = UDim2.fromOffset(0, 2),
				zIndex = 3,
			}),
			e(P.Label, {
				key = "Text",
				text = props.text,
				textSize = ROW_TEXT_SIZE,
				color = Theme.Color.Gray,
				align = Enum.TextXAlignment.Left,
				vAlign = Enum.TextYAlignment.Top,
				wrapped = true,
				size = UDim2.new(1, -TAG_WIDTH, 0, 0),
				position = UDim2.fromOffset(TAG_WIDTH, 0),
				automaticSize = Enum.AutomaticSize.Y,
				zIndex = 3,
			}),
		},
	})
end

--[[
	One release card.

	props: version, date, title, changes, latest, layoutOrder
]]
local function ChangelogEntry(props)
	local rows = {
		P.list({ direction = Enum.FillDirection.Vertical, padding = ROW_PADDING }),
	}
	for index, change in ipairs(props.changes) do
		rows[#rows + 1] = e(ChangeRow, {
			key = "Change" .. index,
			kind = change.Kind,
			text = change.Text,
			layoutOrder = index,
		})
	end

	return e(P.Panel, {
		key = props.key,
		size = UDim2.fromScale(1, 0),
		automaticSize = Enum.AutomaticSize.Y,
		layoutOrder = props.layoutOrder,
		radius = Theme.Radius.Card,
		color = Theme.Color.Card,
		gradient = Theme.Gradient.Card,
		strokeThickness = Theme.Stroke.Card,
		studs = false,
		children = {
			P.padding({ x = 14, y = 12 }, "Inset"),
			e(P.Group, {
				key = "Stack",
				size = UDim2.fromScale(1, 0),
				automaticSize = Enum.AutomaticSize.Y,
				layout = P.list({ direction = Enum.FillDirection.Vertical, padding = 10 }),
				children = {
					-- Header: version pill, date, title, and a NEW pip on the newest.
					e(P.Group, {
						key = "Header",
						size = UDim2.new(1, 0, 0, 34),
						layoutOrder = 1,
						children = P.compact(
							e(Icon, {
								key = "Mark",
								glyph = "note",
								gradient = if props.latest
									then Theme.Gradient.Gold
									else Theme.Gradient.PanelDeep,
								size = UDim2.fromOffset(34, 34),
								radius = Theme.Radius.Small,
								zIndex = 3,
							}),
							e(P.Label, {
								key = "Version",
								text = "v" .. props.version .. "  " .. props.title,
								textSize = Theme.TextSize.Heading,
								align = Enum.TextXAlignment.Left,
								size = UDim2.new(1, -250, 1, 0),
								position = UDim2.fromOffset(44, 0),
								truncate = Enum.TextTruncate.AtEnd,
								zIndex = 3,
							}),
							e(P.Label, {
								key = "Date",
								text = props.date,
								textSize = Theme.TextSize.Small,
								color = Theme.Color.GrayDark,
								align = Enum.TextXAlignment.Right,
								size = UDim2.fromOffset(120, 34),
								position = UDim2.fromScale(1, 0),
								anchorPoint = Vector2.new(1, 0),
								zIndex = 3,
							}),
							if props.latest
								then e(Indicators.Badge, {
									key = "Latest",
									text = "LATEST",
									gradient = Theme.Gradient.Gold,
									textSize = Theme.TextSize.Micro,
									size = UDim2.fromOffset(74, 22),
									position = UDim2.new(1, -128, 0.5, 0),
									anchorPoint = Vector2.new(1, 0.5),
									zIndex = 4,
								})
								else nil
						),
					}),
					e(P.Group, {
						key = "Changes",
						size = UDim2.fromScale(1, 0),
						automaticSize = Enum.AutomaticSize.Y,
						layoutOrder = 2,
						children = rows,
					}),
				},
			}),
		},
	})
end

local function ChangelogScreen(props)
	local actions = props.actions
	local entries = ChangelogConfig.Entries

	local cards = {}
	for index, entry in ipairs(entries) do
		cards[#cards + 1] = e(ChangelogEntry, {
			key = entry.Version,
			version = entry.Version,
			date = entry.Date,
			title = entry.Title,
			changes = entry.Changes,
			latest = index == 1,
			layoutOrder = index,
		})
	end

	return e(Overlays.Modal, {
		key = props.key or "ChangelogScreen",
		title = "Updates",
		glyph = "note",
		headerColor = Theme.Gradient.Cyan,
		width = 760,
		contentHeight = 560,
		onClose = actions.closeScreen,
		children = {
			e(P.Scroller, {
				key = "Entries",
				size = UDim2.fromScale(1, 1),
				padding = { right = 10, bottom = 6 },
				layout = P.list({ direction = Enum.FillDirection.Vertical, padding = 12 }),
				children = cards,
			}),
		},
	})
end

return ChangelogScreen
