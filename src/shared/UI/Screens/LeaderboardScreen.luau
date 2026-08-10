--[[
	LeaderboardScreen.luau

	Three world boards side by side: MOST CASH / MOST PRESTIGES / MOST SCRAP.

	Showing all three at once instead of tabbing between them means a player who
	is nowhere near the top of one board can still see where they place on
	another. The local player's row is tinted and outlined in gold.

	LeaderboardPanel is exported on its own so a single board can be parented to
	a SurfaceGui on an in-world podium.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Mock = require(UI.Mock)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)
local Rows = require(UI.Components.Rows)
local Overlays = require(UI.Components.Overlays)

local e = React.createElement

--------------------------------------------------------------------------------
-- LeaderboardPanel — one board, usable standalone
--------------------------------------------------------------------------------

local function LeaderboardPanel(props)
	local accent = Theme.Gradient[props.accent or "Green"]

	local rows = {}
	for index, entry in ipairs(props.rows) do
		rows[#rows + 1] = e(Rows.LeaderboardRow, {
			key = "Row" .. index,
			rank = index,
			player = entry.player,
			value = entry.value,
			highlight = entry.highlight,
			layoutOrder = index,
		})
	end

	return e(P.Panel, {
		key = props.key or props.title,
		size = props.size or UDim2.fromOffset(330, 520),
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		radius = Theme.Radius.Card,
		color = Theme.Color.Panel,
		gradient = Theme.Gradient.Panel,
		strokeThickness = Theme.Stroke.Card,
		studSpacing = 26,
		area = Vector2.new(340, 560),
		children = {
			e(P.Panel, {
				key = "Header",
				size = UDim2.new(1, 0, 0, 52),
				radius = Theme.Radius.Card,
				studs = false,
				zIndex = 4,
				children = {
					P.gradient(accent),
					e(P.Gloss, {
						key = "Gloss",
						radius = Theme.Radius.Card,
						strength = 0.68,
						height = 0.55,
					}),
					e(Icon, {
						key = "Icon",
						glyph = props.glyph,
						plain = true,
						size = UDim2.fromOffset(30, 30),
						position = UDim2.new(0, 12, 0.5, 0),
						anchorPoint = Vector2.new(0, 0.5),
						zIndex = 4,
					}),
					e(P.Label, {
						key = "Title",
						text = string.upper(props.title),
						textSize = Theme.TextSize.Body,
						align = Enum.TextXAlignment.Left,
						size = UDim2.new(1, -56, 1, 0),
						position = UDim2.fromOffset(50, 0),
						zIndex = 4,
					}),
				},
			}),
			e(P.Scroller, {
				key = "Rows",
				size = UDim2.new(1, -16, 1, -68),
				position = UDim2.fromOffset(8, 60),
				padding = { right = 6, bottom = 4 },
				layout = P.list({ padding = 6 }),
				children = rows,
				zIndex = 3,
			}),
		},
	})
end

--------------------------------------------------------------------------------
-- Screen
--------------------------------------------------------------------------------

local function LeaderboardScreen(props)
	local actions = props.actions

	local panels = {}
	for index, board in ipairs(Mock.leaderboards) do
		panels[#panels + 1] = e(LeaderboardPanel, {
			key = board.id,
			title = board.title,
			glyph = board.glyph,
			accent = board.accent,
			rows = board.rows,
			size = UDim2.new(0, 330, 1, 0),
			layoutOrder = index,
		})
	end

	return e(Overlays.Modal, {
		key = props.key or "LeaderboardScreen",
		title = "Leaderboards",
		glyph = "trophy",
		headerColor = Theme.Gradient.Gold,
		size = UDim2.fromOffset(1080, 640),
		onClose = actions.closeScreen,
		children = {
			e(P.Group, {
				key = "Boards",
				size = UDim2.fromScale(1, 1),
				layout = P.list({
					direction = Enum.FillDirection.Horizontal,
					padding = 14,
					hAlign = Enum.HorizontalAlignment.Center,
				}),
				children = panels,
			}),
		},
	})
end

return {
	LeaderboardScreen = LeaderboardScreen,
	LeaderboardPanel = LeaderboardPanel,
}
