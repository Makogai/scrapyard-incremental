--!nonstrict
--[[
	GearShopScreen.luau

	The world Gear Shop booth, opened by walking into Workspace.NewMap.GearShop.
	Buys cost Gears; the client sends an offer id and nothing else.

	Stories run in mock mode, so they never need a server.
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

local function OfferRow(props)
	local offer = props.offer
	local gears = props.gears

	local buttonText, buttonVariant, disabled, subtext
	if offer.locked then
		buttonText, buttonVariant, disabled = "LOCKED", "Neutral", true
		subtext = `Rebirth {offer.requiredPrestige}`
	elseif offer.maxed then
		buttonText, buttonVariant, disabled = "MAXED", "Neutral", true
	else
		buttonText, buttonVariant = "BUY", "Purchase"
		subtext = `{Format.comma(offer.price or 0)} gears`
		disabled = gears < (offer.price or 0)
	end

	local rankText = if offer.maxLevel > 0 then `{offer.level} / {offer.maxLevel}` else nil

	return e(P.Panel, {
		key = offer.id,
		size = UDim2.new(1, 0, 0, 96),
		layoutOrder = props.layoutOrder,
		radius = Theme.Radius.Card,
		color = Theme.Color.Card,
		gloss = 0.84,
		glossHeight = 0.24,
		studs = false,
		strokeThickness = Theme.Stroke.Card,
		strokeColor = Theme.Color.Outline,
		children = P.compact(
			e(Icon, {
				key = "Icon",
				glyph = offer.glyph,
				size = UDim2.fromOffset(64, 64),
				position = UDim2.new(0, 14, 0.5, 0),
				anchorPoint = Vector2.new(0, 0.5),
				radius = Theme.Radius.Card,
				zIndex = 3,
			}),
			e(P.Label, {
				key = "Name",
				text = offer.name,
				textSize = Theme.TextSize.Heading,
				align = Enum.TextXAlignment.Left,
				size = UDim2.fromOffset(320, 28),
				position = UDim2.fromOffset(92, 14),
				zIndex = 3,
			}),
			rankText and e(P.Label, {
				key = "Rank",
				text = rankText,
				textSize = Theme.TextSize.Small,
				font = Theme.Font.Bold,
				color = Theme.Color.Gold,
				align = Enum.TextXAlignment.Left,
				size = UDim2.fromOffset(80, 28),
				position = UDim2.fromOffset(420, 14),
				zIndex = 3,
			}),
			e(P.Label, {
				key = "Detail",
				text = offer.description,
				textSize = Theme.TextSize.Body,
				color = Theme.Color.Gray,
				align = Enum.TextXAlignment.Left,
				size = UDim2.fromOffset(400, 26),
				position = UDim2.fromOffset(92, 48),
				zIndex = 3,
			}),
			e(Buttons.Button, {
				key = "Buy",
				text = buttonText,
				subtext = subtext,
				variant = buttonVariant,
				disabled = disabled,
				size = UDim2.fromOffset(168, 52),
				position = UDim2.new(1, -20, 0.5, 0),
				anchorPoint = Vector2.new(1, 0.5),
				zIndex = 4,
				onClick = props.onBuy,
			})
		),
	})
end

local function GearShopScreen(props)
	local state = props.state
	local actions = props.actions
	local gears = state.gears or 0
	local prestige = state.prestige or 0

	local rows = {}
	for index, offer in ipairs(GameData.gearShop(prestige, state.gearUpgrades)) do
		rows[#rows + 1] = e(OfferRow, {
			key = offer.id,
			offer = offer,
			gears = gears,
			layoutOrder = index,
			onBuy = function()
				if offer.locked or offer.maxed then
					return
				end
				actions.confirm({
					Title = "Buy with Gears?",
					Glyph = "gear",
					Lines = { offer.name, `{Format.comma(offer.price or 0)} gears` },
					ConfirmText = "BUY",
					ConfirmVariant = "Purchase",
					ConfirmDisabled = gears < (offer.price or 0),
					OnConfirm = function()
						actions.buyGearItem(offer.id)
					end,
				})
			end,
		})
	end

	return e(Overlays.Modal, {
		key = props.key or "GearShopScreen",
		title = "Gear Shop",
		glyph = "gear",
		headerColor = Theme.Gradient.Gold,
		width = 900,
		contentHeight = 460,
		onClose = actions.closeScreen,
		headerRight = e(Indicators.CurrencyDisplay, {
			key = "Gears",
			glyph = "gear",
			gradient = Theme.Gradient.Gold,
			formatted = Format.comma(gears),
			width = 180,
			height = 42,
			textSize = Theme.TextSize.Body,
			layoutOrder = 1,
		}),
		children = {
			e(P.Scroller, {
				key = "Offers",
				padding = { right = 10, bottom = 6 },
				layout = P.list({ padding = 10 }),
				children = rows,
			}),
		},
	})
end

return GearShopScreen
