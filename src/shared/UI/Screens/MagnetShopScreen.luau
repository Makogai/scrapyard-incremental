--!nonstrict
--[[
	MagnetShopScreen.luau

	The world Magnet Shop booth, opened by its proximity prompt.

	The server fires `OpenMagnetShop`, which Bridge routes to screen id
	"magnetshop". Cash magnets buy through ShopService (`actions.buyMagnet`);
	a magnet with no shop price is a game-pass item and prompts Marketplace
	instead.

	This screen did not exist in the kit -- it is specific to this game's world
	booth, and is the reference for adding a game-specific screen: a Modal, cards
	built from GameData, and actions only.
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

local function MagnetRow(props)
	local magnet = props.magnet
	local owned = props.owned
	local equipped = props.equipped

	local buttonText, buttonVariant, disabled, subtext
	if equipped then
		buttonText, buttonVariant, disabled = "EQUIPPED", "Neutral", true
	elseif owned then
		buttonText, buttonVariant = "EQUIP", "Primary"
	elseif magnet.shopPrice then
		buttonText, buttonVariant = "BUY", "Purchase"
		subtext = Format.money(magnet.shopPrice)
		disabled = props.cash < magnet.shopPrice
	else
		buttonText, buttonVariant = "GET PASS", "Premium"
	end

	local style = Theme.rarity(magnet.rarity)

	return e(P.Panel, {
		key = magnet.id,
		size = UDim2.new(1, 0, 0, 104),
		layoutOrder = props.layoutOrder,
		radius = Theme.Radius.Card,
		color = Theme.Color.Card,
		gloss = 0.84,
		glossHeight = 0.24,
		studs = false,
		strokeThickness = Theme.Stroke.Card,
		strokeColor = if equipped then Theme.Color.Positive else Theme.Color.Outline,
		children = P.compact(
			e(Icon, {
				key = "Icon",
				glyph = "magnet",
				image = magnet.image,
				gradient = style.gradient,
				size = UDim2.fromOffset(70, 70),
				position = UDim2.new(0, 14, 0.5, 0),
				anchorPoint = Vector2.new(0, 0.5),
				radius = Theme.Radius.Card,
				zIndex = 3,
			}),
			e(P.Label, {
				key = "Name",
				text = magnet.name,
				textSize = Theme.TextSize.Heading,
				align = Enum.TextXAlignment.Left,
				size = UDim2.fromOffset(300, 30),
				position = UDim2.fromOffset(98, 18),
				zIndex = 3,
			}),
			e(Indicators.RarityBadge, {
				key = "Rarity",
				rarity = magnet.rarity,
				position = UDim2.fromOffset(98, 54),
				zIndex = 3,
			}),
			e(P.Label, {
				key = "Stats",
				text = string.format(
					"%d strength  -  %s",
					magnet.strength,
					Format.studs(magnet.range)
				),
				textSize = Theme.TextSize.Body,
				font = Theme.Font.Bold,
				color = Theme.Color.Gray,
				align = Enum.TextXAlignment.Left,
				size = UDim2.fromOffset(300, 26),
				position = UDim2.new(0.52, 0, 0.5, -13),
				zIndex = 3,
			}),
			e(Buttons.Button, {
				key = "Action",
				text = buttonText,
				subtext = subtext,
				variant = buttonVariant,
				disabled = disabled,
				size = UDim2.fromOffset(180, 52),
				position = UDim2.new(1, -20, 0.5, 0),
				anchorPoint = Vector2.new(1, 0.5),
				zIndex = 4,
				onClick = props.onAction,
			})
		),
	})
end

local function MagnetShopScreen(props)
	local state = props.state
	local actions = props.actions

	local rows = {}
	for index, magnet in ipairs(GameData.magnets()) do
		local owned = state.ownedMagnets[magnet.id] == true
		local equipped = state.equippedMagnet == magnet.id

		rows[#rows + 1] = e(MagnetRow, {
			key = magnet.id,
			magnet = magnet,
			owned = owned,
			equipped = equipped,
			cash = state.cash,
			layoutOrder = index,
			onAction = function()
				if equipped then
					return
				end
				if owned then
					actions.equipMagnet(magnet.id)
				elseif magnet.shopPrice then
					actions.confirm({
						Title = "Buy Magnet?",
						Glyph = "magnet",
						Lines = { magnet.name, magnet.description },
						Price = magnet.shopPrice,
						ConfirmText = "BUY",
						ConfirmVariant = "Purchase",
						ConfirmDisabled = state.cash < magnet.shopPrice,
						OnConfirm = function()
							actions.buyMagnet(magnet.id)
						end,
					})
				else
					actions.purchase(magnet.id, "Pass")
				end
			end,
		})
	end

	return e(Overlays.Modal, {
		key = props.key or "MagnetShopScreen",
		title = "Magnet Shop",
		glyph = "magnet",
		headerColor = Theme.Gradient.Cyan,
		width = 900,
		contentHeight = 360,
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
		children = {
			e(P.Scroller, {
				key = "MagnetList",
				padding = { right = 10, bottom = 6 },
				layout = P.list({ padding = 10 }),
				children = rows,
			}),
		},
	})
end

return MagnetShopScreen
