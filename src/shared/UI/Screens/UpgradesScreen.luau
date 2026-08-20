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
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
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
			--[[
				The Robux "+1 level" product for this upgrade, if one exists.

				Offered even before the dashboard id is filled in, because `MonetizationService` refuses a
				product with an id of 0 with a readable message -- a visible button that says "not available
				yet" beats a button that appears the week someone remembers to wire it up.
			]]
			local robuxProduct = MonetizationConfig.Products[`RobuxUpgrade{upgradeId}`]
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
				--- The Robux alternative. `nil` when the product has no dashboard id yet, so no row appears.
				robuxPrice = robuxProduct and robuxProduct.DisplayPrice or nil,
				onBuyRobux = if robuxProduct
					then function()
						actions.purchase(robuxProduct.Id, "Product")
					end
					else nil,
				layoutOrder = index,
				--[[
					NO CONFIRMATION. An upgrade is the most repeated purchase in the game and the price is
					already on the button, so a modal asking "are you sure" between the number and the click
					is a second click for information the player just read.

					It stays unconfirmed even for MAX. The spend can be large, but it is bounded by what you
					can afford and it buys levels you cannot lose -- unlike a rebirth or a profile wipe,
					which keep their confirmations because they destroy something.

					ONE INTENT FOR THE WHOLE PURCHASE. This used to fire one event per level, which the
					server's remote limiter (12 per 5 seconds) quietly truncated -- so MAX bought twelve
					levels at best, and fewer if you had clicked anything recently. The server prices every
					level itself and stops when money or the cap runs out, so the count is a request rather
					than something to be trusted.
				]]
				onBuy = function()
					actions.buyUpgrade(upgradeId, math.max(1, gained))
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
