--!nonstrict
--[[
	AreasScreen.luau

	AREAS window: the three configured yard sections as large cards.

	Migrated to live data. Unlock state comes from the server snapshot, prices and
	best-scrap come from AreaConfig/ScrapConfig via GameData. Unlocking sends an
	area id; the server owns order enforcement, price and the gate rebuild.

	Areas must be bought in order, so a later locked area shows its price but its
	button stays disabled until the one before it is owned -- the same rule the
	server enforces, surfaced instead of hidden behind a rejection.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Format = require(UI.Format)
local GameData = require(UI.GameData)
local P = require(UI.Primitives)
local Indicators = require(UI.Components.Indicators)
local Rows = require(UI.Components.Rows)
local Overlays = require(UI.Components.Overlays)

local e = React.createElement

local function AreasScreen(props)
	local state = props.state
	local actions = props.actions

	local areas = GameData.areas()
	local cards = {}
	local unlockedCount = 0
	local previousUnlocked = true

	for index, area in ipairs(areas) do
		local unlocked = state.unlockedAreas[area.id] == true
		if unlocked then
			unlockedCount += 1
		end

		-- Only the next area in sequence is purchasable.
		local purchasable = not unlocked and previousUnlocked
		local affordable = purchasable and state.cash >= area.cost

		cards[#cards + 1] = e(Rows.AreaCard, {
			key = area.id,
			name = area.name,
			tier = area.tier,
			glyph = area.glyph,
			cost = area.cost,
			unlocked = unlocked,
			bestScrap = area.bestScrap,
			bestValue = area.bestValue,
			affordable = affordable,
			layoutOrder = index,
			-- No onTeleport: TeleportService has no per-area destination and the
			-- map has no per-area geometry, so the card shows UNLOCKED instead.
			onUnlock = function()
				if not purchasable then
					return
				end
				actions.confirm({
					Title = "Unlock Area?",
					Glyph = area.glyph,
					Lines = { area.name, "Best scrap: " .. area.bestScrap },
					Price = area.cost,
					ConfirmText = "UNLOCK",
					ConfirmVariant = "Purchase",
					ConfirmDisabled = not affordable,
					OnConfirm = function()
						actions.unlockArea(area.id)
					end,
				})
			end,
		})

		previousUnlocked = unlocked
	end

	return e(Overlays.Modal, {
		key = props.key or "AreasScreen",
		title = "Areas",
		glyph = "pin",
		headerColor = Theme.Gradient.Cyan,
		width = 1120,
		contentHeight = 348,
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
		footerHeight = 50,
		footer = e(P.Group, {
			key = "Progress",
			size = UDim2.fromScale(1, 1),
			children = {
				e(P.Label, {
					key = "Label",
					text = "AREAS UNLOCKED",
					textSize = Theme.TextSize.Small,
					font = Theme.Font.Bold,
					color = Theme.Color.Gray,
					align = Enum.TextXAlignment.Left,
					size = UDim2.new(0, 220, 1, 0),
				}),
				e(Indicators.ProgressBar, {
					key = "Bar",
					value = unlockedCount,
					max = #areas,
					gradient = Theme.Gradient.Cyan,
					height = 28,
					size = UDim2.new(1, -240, 0, 28),
					position = UDim2.fromScale(1, 0.5),
					anchorPoint = Vector2.new(1, 0.5),
					text = Format.fraction(unlockedCount, #areas),
				}),
			},
		}),
		children = {
			e(P.Scroller, {
				key = "AreaList",
				direction = Enum.ScrollingDirection.X,
				axis = Enum.AutomaticSize.X,
				padding = { bottom = 12, right = 8 },
				layout = P.list({
					direction = Enum.FillDirection.Horizontal,
					padding = 12,
				}),
				children = cards,
			}),
		},
	})
end

return AreasScreen
