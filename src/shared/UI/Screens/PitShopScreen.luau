--!nonstrict
--[[
	PitShopScreen.luau

	THE PIT shop. Opened by walking into Event Shop while the arena is live.
	Buys cost slag; the client sends an offer id and nothing else.

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
	local canAfford = props.slag >= offer.slagPrice

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
			e(P.Label, {
				key = "Detail",
				text = offer.description,
				textSize = Theme.TextSize.Body,
				color = Theme.Color.Gray,
				align = Enum.TextXAlignment.Left,
				size = UDim2.fromOffset(360, 36),
				position = UDim2.fromOffset(92, 44),
				zIndex = 3,
			}),
			e(Buttons.Button, {
				key = "Buy",
				text = "BUY",
				subtext = `{Format.comma(offer.slagPrice)} slag`,
				variant = "Purchase",
				disabled = not canAfford,
				size = UDim2.fromOffset(168, 52),
				position = UDim2.new(1, -20, 0.5, 0),
				anchorPoint = Vector2.new(1, 0.5),
				zIndex = 4,
				onClick = props.onBuy,
			})
		),
	})
end

local function PitShopScreen(props)
	local state = props.state
	local actions = props.actions
	local slag = state.eventTokens or 0

	local rows = {}
	for index, offer in ipairs(GameData.pitShop()) do
		rows[#rows + 1] = e(OfferRow, {
			key = offer.id,
			offer = offer,
			slag = slag,
			layoutOrder = index,
			onBuy = function()
				actions.confirm({
					Title = "Buy with slag?",
					Glyph = "crate",
					Lines = { offer.name, `{Format.comma(offer.slagPrice)} slag` },
					ConfirmText = "BUY",
					ConfirmVariant = "Purchase",
					ConfirmDisabled = slag < offer.slagPrice,
					OnConfirm = function()
						actions.buyPitItem(offer.id)
					end,
				})
			end,
		})
	end

	return e(Overlays.Modal, {
		key = props.key or "PitShopScreen",
		title = "Pit Shop",
		glyph = "crate",
		headerColor = Theme.Gradient.Gold,
		width = 860,
		contentHeight = 420,
		onClose = actions.closeScreen,
		headerRight = e(Indicators.CurrencyDisplay, {
			key = "Slag",
			glyph = "crate",
			gradient = Theme.Gradient.Gold,
			formatted = Format.comma(slag),
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

return PitShopScreen
