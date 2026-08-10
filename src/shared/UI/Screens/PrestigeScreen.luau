--[[
	PrestigeScreen.luau

	PRESTIGE window. The whole job of this screen is to make an irreversible
	reset feel safe, so the LOSE and KEEP columns sit side by side at equal
	weight and the button spells out the shortfall when the player is not there
	yet ("NEED $7.6M MORE") rather than just greying out.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Format = require(UI.Format)
local GameData = require(UI.GameData)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)
local Buttons = require(UI.Components.Buttons)
local Indicators = require(UI.Components.Indicators)
local Overlays = require(UI.Components.Overlays)

local e = React.createElement

--- One of the LOSE / KEEP columns.
local function OutcomeColumn(props)
	local rows = {}
	for index, item in ipairs(props.items) do
		rows[#rows + 1] = e(P.Group, {
			key = item,
			size = UDim2.new(1, 0, 0, 30),
			layoutOrder = index,
			children = {
				e(Icon, {
					key = "Mark",
					glyph = props.glyph,
					plain = true,
					glyphColor = props.color,
					size = UDim2.fromOffset(20, 20),
					position = UDim2.fromScale(0, 0.5),
					anchorPoint = Vector2.new(0, 0.5),
				}),
				e(P.Label, {
					key = "Name",
					text = item,
					textSize = Theme.TextSize.Body,
					font = Theme.Font.Bold,
					align = Enum.TextXAlignment.Left,
					size = UDim2.new(1, -30, 1, 0),
					position = UDim2.fromOffset(30, 0),
				}),
			},
		})
	end

	return e(P.Panel, {
		key = props.key,
		size = props.size,
		layoutOrder = props.layoutOrder,
		radius = Theme.Radius.Card,
		color = Theme.Color.PanelDark,
		gradient = Theme.Gradient.PanelDeep,
		strokeColor = props.color,
		strokeThickness = Theme.Stroke.Card,
		studs = false,
		children = {
			P.padding({ x = 14, y = 12 }, "Inset"),
			e(P.Label, {
				key = "Title",
				text = props.title,
				textSize = Theme.TextSize.Heading,
				color = props.color,
				align = Enum.TextXAlignment.Left,
				size = UDim2.new(1, 0, 0, 30),
			}),
			e(P.Group, {
				key = "Items",
				size = UDim2.new(1, 0, 1, -40),
				position = UDim2.fromOffset(0, 38),
				layout = P.list({ padding = 2 }),
				children = rows,
			}),
		},
	})
end

local function PrestigeScreen(props)
	local state = props.state
	local actions = props.actions

	-- Requirement, reward and permanent multiplier all come from the server's
	-- own GameMath/PrestigeConfig, so the number shown is the number enforced.
	local view = GameData.prestige(state.cash, state.gears, state.prestige)
	local requirement = view.requirement
	local ready = view.ready
	local shortfall = view.shortfall

	return e(Overlays.Modal, {
		key = props.key or "PrestigeScreen",
		title = "Prestige",
		glyph = "recycle",
		headerColor = Theme.Gradient.Purple,
		width = 900,
		-- Summary 98 + progress 34 + outcome 224 + actions 70, three 10px gaps.
		contentHeight = 456,
		subtitle = "PRESTIGE " .. state.prestige,
		onClose = actions.closeScreen,
		children = {
			e(P.Group, {
				key = "Body",
				size = UDim2.fromScale(1, 1),
				layout = P.list({ padding = 10 }),
				children = {
					-- Headline numbers
					e(P.Group, {
						key = "Summary",
						size = UDim2.new(1, 0, 0, 98),
						layoutOrder = 1,
						-- Two columns of two: wraps so the four headline stats
						-- form a block rather than one overflowing row.
						layout = P.list({
							direction = Enum.FillDirection.Horizontal,
							padding = 10,
							wraps = true,
						}),
						children = {
							e(Indicators.StatRow, {
								key = "CurrentCash",
								label = "Current Cash",
								value = Format.money(state.cash),
								glyph = "coin",
								valueColor = Theme.Color.Positive,
								size = UDim2.new(0.5, -5, 0, 44),
								layoutOrder = 1,
							}),
							e(Indicators.StatRow, {
								key = "Requirement",
								label = "Requirement",
								value = Format.money(requirement),
								glyph = "upgrade",
								valueColor = if ready
									then Theme.Color.Positive
									else Theme.Color.Red,
								size = UDim2.new(0.5, -5, 0, 44),
								layoutOrder = 2,
							}),
							e(Indicators.StatRow, {
								key = "Reward",
								label = "You Receive",
								value = "+" .. Format.comma(view.gearsReward) .. " Gears",
								glyph = "gear",
								valueColor = Theme.Color.Gold,
								size = UDim2.new(0.5, -5, 0, 44),
								layoutOrder = 3,
							}),
							e(Indicators.StatRow, {
								key = "Bonus",
								label = "Permanent Bonus",
								value = view.permanentBonus,
								glyph = "star",
								valueColor = Theme.Color.Purple,
								size = UDim2.new(0.5, -5, 0, 44),
								layoutOrder = 4,
							}),
						},
					}),

					-- Progress toward the requirement
					e(Indicators.ProgressBar, {
						key = "Progress",
						value = math.min(state.cash, requirement),
						max = requirement,
						gradient = Theme.Gradient.Purple,
						height = 34,
						size = UDim2.new(1, 0, 0, 34),
						text = Format.money(state.cash) .. "  /  " .. Format.money(requirement),
						layoutOrder = 2,
					}),

					-- Lose / keep
					e(P.Group, {
						key = "Outcome",
						size = UDim2.new(1, 0, 0, 224),
						layoutOrder = 3,
						layout = P.list({
							direction = Enum.FillDirection.Horizontal,
							padding = 12,
						}),
						children = {
							e(OutcomeColumn, {
								key = "Lose",
								title = "YOU WILL LOSE",
								items = view.lose,
								glyph = "cross",
								color = Theme.Color.Red,
								size = UDim2.new(0.5, -6, 1, 0),
								layoutOrder = 1,
							}),
							e(OutcomeColumn, {
								key = "Keep",
								title = "YOU KEEP",
								items = view.keep,
								glyph = "check",
								color = Theme.Color.Positive,
								size = UDim2.new(0.5, -6, 1, 0),
								layoutOrder = 2,
							}),
						},
					}),

					-- Actions
					e(P.Group, {
						key = "Actions",
						size = UDim2.new(1, 0, 0, 70),
						layoutOrder = 4,
						layout = P.list({
							direction = Enum.FillDirection.Horizontal,
							padding = 12,
							hAlign = Enum.HorizontalAlignment.Center,
						}),
						children = {
							e(Buttons.Button, {
								key = "Prestige",
								text = if ready
									then "PRESTIGE"
									else ("NEED " .. Format.money(shortfall) .. " MORE"),
								glyph = if ready then "recycle" else nil,
								variant = "Premium",
								disabled = not ready,
								textSize = if ready
									then Theme.TextSize.Heading
									else Theme.TextSize.Body,
								size = UDim2.fromOffset(400, 62),
								layoutOrder = 1,
								onClick = function()
									actions.confirm({
										Title = "Prestige?",
										Glyph = "recycle",
										HeaderColor = Theme.Gradient.Purple,
										Lines = {
											"This cannot be undone.",
											"You keep magnets, pets, potions, gears and cosmetics.",
										},
										ConfirmText = "PRESTIGE",
										ConfirmVariant = "Premium",
										OnConfirm = actions.prestige,
									})
								end,
							}),
							e(Buttons.Button, {
								key = "SkipRebirth",
								text = "SKIP REBIRTH",
								glyph = "recycle",
								variant = "Purchase",
								subtext = nil,
								size = UDim2.fromOffset(260, 62),
								layoutOrder = 2,
								onClick = function()
									actions.purchase("SkipRebirth", "Product")
								end,
							}),
						},
					}),
				},
			}),
		},
	})
end

return PrestigeScreen
