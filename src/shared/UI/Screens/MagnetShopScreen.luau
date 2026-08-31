--!nonstrict
--[[
	MagnetShopScreen.luau

	The world Magnet Shop booth, opened by its proximity prompt.

	The server fires `OpenMagnetShop`, which Bridge routes to screen id
	"magnetshop". Two tabs:

		MAGNETS  cash / pass magnets. Stats. `actions.buyMagnet` / Marketplace.
		SKINS    cosmetic horseshoes. Same pull as the magnet you already hold.
		         Cards show the real 3D model; buy sends a skin id only.

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
local ModelView = require(UI.Components.ModelView)

local e = React.createElement

local TABS = {
	{ id = "MAGNETS", text = "MAGNETS", glyph = "magnet" },
	{ id = "SKINS", text = "SKINS", glyph = "star" },
}

local SKIN_CELL = UDim2.fromOffset(276, 332)

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
				text = string.format("%d strength  -  %s", magnet.strength, Format.studs(magnet.range)),
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

local function SkinCard(props)
	local skin = props.skin
	local owned = props.owned
	local equipped = props.equipped
	local style = Theme.rarity(skin.rarity)

	local buttonText, buttonVariant, disabled, subtext
	if equipped then
		buttonText, buttonVariant, disabled = "EQUIPPED", "Neutral", true
	elseif owned then
		buttonText, buttonVariant = "EQUIP", "Primary"
	else
		buttonText, buttonVariant = "BUY", "Purchase"
		subtext = Format.money(skin.shopPrice)
		disabled = props.cash < skin.shopPrice
	end

	return e(P.Panel, {
		key = skin.id,
		size = UDim2.fromScale(1, 1),
		layoutOrder = props.layoutOrder,
		radius = Theme.Radius.Card,
		color = Theme.Color.Card,
		gloss = 0.84,
		glossHeight = 0.2,
		studs = false,
		strokeThickness = Theme.Stroke.Card,
		strokeColor = if equipped then Theme.Color.Positive else style.color,
		children = P.compact(
			e("Frame", {
				key = "Wash",
				BackgroundColor3 = style.color,
				BackgroundTransparency = 0.86,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
			}, {
				P.corner(Theme.Radius.Card),
				P.gradient(style.gradient, { rotation = 90 }),
			}),
			e(P.Slot, {
				key = "Preview",
				size = UDim2.new(1, -20, 0, 168),
				position = UDim2.fromOffset(10, 10),
				zIndex = 3,
				children = {
					if skin.id ~= nil and skin.id ~= ""
						then e(ModelView.View, {
							key = "Model",
							kind = "magnetSkin",
							model = skin.id,
							spin = 18,
							zoom = 0.88,
							lift = 0.18,
							yaw = 22,
							glyph = skin.glyph or "magnet",
							size = UDim2.fromScale(1, 1),
							zIndex = 6,
						})
						else e(Icon, {
							key = "Icon",
							glyph = skin.glyph or "magnet",
							plain = true,
							size = UDim2.fromScale(0.55, 0.55),
							position = UDim2.fromScale(0.5, 0.5),
							anchorPoint = Vector2.new(0.5, 0.5),
							zIndex = 6,
						}),
				},
			}),
			e(P.Label, {
				key = "Name",
				text = skin.name,
				textSize = Theme.TextSize.Body,
				font = Theme.Font.Bold,
				size = UDim2.new(1, -16, 0, 24),
				position = UDim2.fromOffset(8, 184),
				truncate = Enum.TextTruncate.AtEnd,
				zIndex = 4,
			}),
			e(Indicators.RarityBadge, {
				key = "Rarity",
				rarity = skin.rarity,
				position = UDim2.new(0.5, 0, 0, 210),
				anchorPoint = Vector2.new(0.5, 0),
				zIndex = 4,
			}),
			e(P.Label, {
				key = "Note",
				text = if skin.id == "" then "YOUR MAGNET" else "LOOKS ONLY",
				textSize = Theme.TextSize.Tiny,
				font = Theme.Font.Bold,
				color = Theme.Color.Gray,
				size = UDim2.new(1, -16, 0, 16),
				position = UDim2.fromOffset(8, 238),
				zIndex = 4,
			}),
			e(Buttons.Button, {
				key = "Action",
				text = buttonText,
				subtext = subtext,
				variant = buttonVariant,
				disabled = disabled,
				textSize = Theme.TextSize.Small,
				size = UDim2.new(1, -24, 0, 48),
				position = UDim2.new(0.5, 0, 1, -12),
				anchorPoint = Vector2.new(0.5, 1),
				zIndex = 5,
				onClick = props.onAction,
			})
		),
	})
end

local function MagnetShopScreen(props)
	local state = props.state
	local actions = props.actions
	local tab, setTab = React.useState("MAGNETS")

	local body
	if tab == "SKINS" then
		local cards = {}
		local wearingSkin = type(state.activeMagnetSkin) == "string" and state.activeMagnetSkin ~= ""
		cards[1] = e(SkinCard, {
			key = "DefaultLook",
			skin = {
				id = "",
				name = "Default Look",
				rarity = "Common",
				glyph = "magnet",
				shopPrice = 0,
			},
			owned = true,
			equipped = not wearingSkin,
			cash = state.cash,
			layoutOrder = 0,
			onAction = function()
				if not wearingSkin then
					return
				end
				actions.equipMagnetSkin("")
			end,
		})
		for index, skin in ipairs(GameData.magnetSkins()) do
			local owned = (state.ownedMagnetSkins or {})[skin.id] == true
			local equipped = state.activeMagnetSkin == skin.id
			cards[#cards + 1] = e(SkinCard, {
				key = skin.id,
				skin = skin,
				owned = owned,
				equipped = equipped,
				cash = state.cash,
				layoutOrder = index,
				onAction = function()
					if equipped then
						return
					end
					if owned then
						actions.equipMagnetSkin(skin.id)
						return
					end
					actions.confirm({
						Title = "Buy Magnet Skin?",
						Glyph = skin.glyph or "magnet",
						Lines = { skin.name, "Cosmetic only -- same strength and range." },
						Price = skin.shopPrice,
						ConfirmText = "BUY",
						ConfirmVariant = "Purchase",
						ConfirmDisabled = state.cash < skin.shopPrice,
						OnConfirm = function()
							actions.buyMagnetSkin(skin.id)
						end,
					})
				end,
			})
		end
		body = e(P.Scroller, {
			key = "SkinGrid",
			padding = { right = 10, bottom = 6 },
			layout = P.grid({
				cell = SKIN_CELL,
				padding = UDim2.fromOffset(12, 12),
				maxCells = 3,
			}),
			children = cards,
		})
	else
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
		body = e(P.Scroller, {
			key = "MagnetList",
			padding = { right = 10, bottom = 6 },
			layout = P.list({ padding = 10 }),
			children = rows,
		})
	end

	return e(Overlays.Modal, {
		key = props.key or "MagnetShopScreen",
		title = "Magnet Shop",
		glyph = "magnet",
		headerColor = Theme.Gradient.Cyan,
		width = 960,
		contentHeight = 560,
		onClose = actions.closeScreen,
		tabs = e(Buttons.TabBar, {
			key = "Tabs",
			tabs = TABS,
			active = tab,
			variant = "Primary",
			size = UDim2.fromScale(1, 1),
			hAlign = Enum.HorizontalAlignment.Left,
			onSelect = setTab,
		}),
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
		children = { body },
	})
end

return MagnetShopScreen
