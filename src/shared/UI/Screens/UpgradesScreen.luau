--!nonstrict
--[[
	UpgradesScreen.luau

	UPGRADES window: one row per configured upgrade, an x1 / x5 / MAX amount
	selector, and a live cash chip.

	Migrated to live data. Levels, maximums and affordability come from the
	server's snapshot; prices and effect values come from GameData, which uses the
	same GameMath functions UpgradeService charges with. The client submits an
	upgrade id and nothing else -- never a price, a level or an effect.

	Bulk purchase sends one intent per level. The server re-prices every one of
	them, so a MAX that the client mis-costs simply stops early server-side.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Format = require(UI.Format)
local GameData = require(UI.GameData)
local P = require(UI.Primitives)
local Buttons = require(UI.Components.Buttons)
local Indicators = require(UI.Components.Indicators)
local Rows = require(UI.Components.Rows)
local Overlays = require(UI.Components.Overlays)

local e = React.createElement

local function UpgradesScreen(props)
	local state = props.state
	local actions = props.actions

	local cards = {}
	for index, upgradeId in ipairs(GameData.upgradeOrder()) do
		local level = state.upgradeLevels[upgradeId] or 0
		local view = GameData.upgradeView(upgradeId, level, state.prestige)

		if view then
			local cost, gained =
				GameData.bulkUpgrade(upgradeId, level, state.buyAmount, state.cash, state.prestige)
			local price = if state.buyAmount == "x1" then view.price else cost
			local affordable = gained > 0 and price <= state.cash

			cards[#cards + 1] = e(Rows.UpgradeCard, {
				key = upgradeId,
				name = view.name,
				glyph = view.glyph,
				accent = Theme.Gradient[view.accent],
				level = view.level,
				maxLevel = view.maxLevel,
				current = view.current,
				next = view.next,
				price = price,
				amount = if state.buyAmount == "x1" then nil else state.buyAmount,
				affordable = affordable,
				layoutOrder = index,
				onBuy = function()
					actions.confirm({
						Title = "Purchase Upgrade?",
						Glyph = view.glyph,
						Lines = {
							view.name,
							view.current .. "  ->  " .. (view.next or view.current),
						},
						Price = price,
						ConfirmText = "BUY",
						OnConfirm = function()
							-- One intent per level; the server prices each.
							for _ = 1, math.max(1, gained) do
								actions.buyUpgrade(upgradeId)
							end
						end,
					})
				end,
			})
		end
	end

	return e(Overlays.Modal, {
		key = props.key or "UpgradesScreen",
		title = "Upgrades",
		glyph = "upgrade",
		headerColor = Theme.Gradient.Yellow,
		width = 1000,
		contentHeight = 560,
		onClose = actions.closeScreen,
		headerRight = e(Indicators.CurrencyDisplay, {
			key = "Cash",
			glyph = "coin",
			gradient = Theme.Gradient.Green,
			formatted = Format.money(state.cash),
			width = 200,
			height = 42,
			textSize = Theme.TextSize.Body,
			layoutOrder = 1,
		}),
		tabs = e(P.Group, {
			key = "AmountRow",
			size = UDim2.fromScale(1, 1),
			children = {
				e(P.Label, {
					key = "Hint",
					text = "BUY AMOUNT",
					textSize = Theme.TextSize.Small,
					font = Theme.Font.Bold,
					color = Theme.Color.Gray,
					align = Enum.TextXAlignment.Left,
					size = UDim2.new(0, 200, 1, 0),
					position = UDim2.fromOffset(4, 0),
				}),
				e(Buttons.Stepper, {
					key = "Amount",
					active = state.buyAmount,
					optionSize = UDim2.fromOffset(72, 38),
					size = UDim2.fromOffset(232, 38),
					position = UDim2.fromScale(1, 0.5),
					anchorPoint = Vector2.new(1, 0.5),
					onSelect = actions.setBuyAmount,
				}),
			},
		}),
		children = {
			e(P.Scroller, {
				key = "UpgradeList",
				padding = { right = 10, bottom = 4 },
				layout = P.list({ padding = 10 }),
				children = cards,
			}),
		},
	})
end

return UpgradesScreen
