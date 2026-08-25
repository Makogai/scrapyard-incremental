--!nonstrict
--[[
	DetailsModal.luau

	One modal shape, three payloads:

		magnet   art, rarity, description, Range / Strength, and EQUIP, or BUY
		         when it is purchasable, or LOCKED when it is a pass item
		potion   effect summary, duration, owned count, USE and USE x5
		pet      preview, rarity, cash bonus, owned count, EQUIP / UNEQUIP

	Migrated to live data: every definition comes from GameData, every ownership
	fact from `state`, and every button sends an intent through `actions`.

	Sharing one frame keeps the game feeling like a single product -- each item is
	inspected the same way, wherever you opened it from.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Format = require(UI.Format)
local GameData = require(UI.GameData)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)
local ModelView = require(UI.Components.ModelView)
local Buttons = require(UI.Components.Buttons)
local Indicators = require(UI.Components.Indicators)
local Overlays = require(UI.Components.Overlays)

local e = React.createElement

--- Height of the artwork well. Tall enough for a spinning pet model to read.
local ART_HEIGHT = 228
--- Pets list many stats; a shorter well leaves room for a two-column grid.
local PET_ART_HEIGHT = 168
local STAT_ROW_HEIGHT = 44
local STAT_TILE_HEIGHT = 38
--- Visible stats area. Taller lists scroll instead of pushing the modal off the screen.
local STATS_VIEWPORT = 168

local function findById(list, id)
	for _, entry in ipairs(list) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Shared frame
--------------------------------------------------------------------------------

local function DetailsFrame(props)
	local style = Theme.rarity(props.rarity)
	local columns = math.max(1, props.statColumns or 1)
	local compact = props.compactStats == true
	local rowHeight = if compact then STAT_TILE_HEIGHT else STAT_ROW_HEIGHT
	local artHeight = props.artHeight or ART_HEIGHT

	local statRows = {}
	for index, stat in ipairs(props.stats or {}) do
		statRows[#statRows + 1] = e(Indicators.StatRow, {
			key = stat.label,
			label = string.upper(stat.label),
			value = stat.value,
			glyph = stat.glyph,
			valueColor = stat.color or (if compact then Theme.Color.Positive else nil),
			compact = compact,
			size = UDim2.new(1, 0, 0, rowHeight),
			layoutOrder = index,
		})
	end

	local statRowCount = math.ceil(#statRows / columns)
	local statsHeight = if #statRows > 0
		then statRowCount * rowHeight + math.max(0, statRowCount - 1) * 6
		else 0
	local statsViewport = if statsHeight > 0 then math.min(statsHeight, STATS_VIEWPORT) else 0
	local descriptionHeight = if props.description then (if compact then 40 else 48) else 0
	local noteText = props.note
	local noteHeight = 0
	if type(noteText) == "string" and noteText ~= "" then
		noteHeight = if #noteText > 42 then 64 else 46
	end

	return e(Overlays.Modal, {
		key = props.key or "DetailsModal",
		title = props.title,
		glyph = props.glyph,
		headerColor = style.gradient,
		width = 560,
		--[[
			`ART_HEIGHT` rather than a literal: the artwork well is the tallest thing in
			here and it grew, so the window has to grow with it or the stat rows get
			pushed out of the bottom.
		]]
		contentHeight = 30 + artHeight + descriptionHeight + statsViewport + (if noteHeight > 0
			then noteHeight + 10
			else 0) + (if props.badges then 40 else 0) + 24,
		onClose = props.onClose,
		footerHeight = 66,
		footer = e(P.Group, {
			key = "Actions",
			size = UDim2.fromScale(1, 1),
			layout = P.list({
				direction = Enum.FillDirection.Horizontal,
				padding = Theme.Space.M,
				hAlign = Enum.HorizontalAlignment.Center,
				vAlign = Enum.VerticalAlignment.Center,
			}),
			children = props.actions,
		}),
		children = {
			e(P.Group, {
				key = "Body",
				size = UDim2.fromScale(1, 1),
				layout = P.list({ padding = 10, hAlign = Enum.HorizontalAlignment.Center }),
				children = P.compact(
					e(P.Slot, {
						key = "Artwork",
						size = UDim2.new(1, 0, 0, artHeight),
						strokeColor = style.color,
						strokeThickness = 3,
						layoutOrder = 1,
						zIndex = 3,
						children = {
							--[[
								A pet shows its actual model, turning slowly. Clicking a pet
								used to open a window with no picture of it at all, because
								`Icon` only draws a glyph or a flat image and pets have
								neither. `model` is passed by the pet branch below; anything
								else still falls back to its glyph.
							]]
							if props.model
								then e(ModelView.View, {
									key = "Model",
									kind = props.modelKind or "pet",
									model = props.model,
									spin = 35,
									size = UDim2.fromOffset(artHeight - 34, artHeight - 34),
									position = UDim2.fromScale(0.5, 0.46),
									anchorPoint = Vector2.new(0.5, 0.5),
									zIndex = 6,
								})
								else e(Icon, {
									key = "Icon",
									glyph = props.glyph,
									image = props.image,
									plain = true,
									size = UDim2.fromOffset(120, 120),
									position = UDim2.fromScale(0.5, 0.5),
									anchorPoint = Vector2.new(0.5, 0.5),
									glyphColor = props.glyphColor,
									glyphAccent = props.glyphAccent,
									zIndex = 6,
								}),
							e(Indicators.RarityBadge, {
								key = "Rarity",
								rarity = props.rarity,
								textSize = Theme.TextSize.Small,
								position = UDim2.new(0.5, 0, 1, -10),
								anchorPoint = Vector2.new(0.5, 1),
								zIndex = 8,
							}),
						},
					}),
					if props.badges
						then e(P.Group, {
							key = "Badges",
							size = UDim2.new(1, 0, 0, 30),
							layoutOrder = 2,
							layout = P.list({
								direction = Enum.FillDirection.Horizontal,
								padding = 8,
								hAlign = Enum.HorizontalAlignment.Center,
							}),
							children = props.badges,
						})
						else nil,
					if props.description
						then e(P.Label, {
							key = "Description",
							text = props.description,
							textSize = Theme.TextSize.Body,
							font = Theme.Font.Bold,
							color = Theme.Color.Gray,
							wrapped = true,
							size = UDim2.new(1, -8, 0, descriptionHeight),
							layoutOrder = 3,
						})
						else nil,
					if #statRows > 0
						then e(P.Scroller, {
							key = "Stats",
							size = UDim2.new(1, 0, 0, statsViewport),
							layoutOrder = 4,
							padding = 2,
							scrollBarThickness = 6,
							layout = if columns > 1
								then P.grid({
									cell = UDim2.new(0.5, -6, 0, rowHeight),
									padding = UDim2.fromOffset(8, 6),
									maxCells = 2,
								})
								else P.list({ padding = 6 }),
							children = statRows,
						})
						else nil,
					if noteHeight > 0
						then e(P.Panel, {
							key = "Note",
							size = UDim2.new(1, 0, 0, noteHeight),
							layoutOrder = 5,
							radius = Theme.Radius.Small,
							color = Theme.Color.PanelDark,
							gradient = Theme.Gradient.PanelDeep,
							strokeColor = Theme.Color.Gold,
							strokeThickness = Theme.Stroke.Chip,
							studs = false,
							children = {
								e(Icon, {
									key = "Icon",
									glyph = props.noteGlyph or "lock",
									plain = true,
									size = UDim2.fromOffset(26, 26),
									position = UDim2.new(0, 12, 0.5, 0),
									anchorPoint = Vector2.new(0, 0.5),
									zIndex = 3,
								}),
								e(P.Label, {
									key = "Text",
									text = noteText,
									textSize = Theme.TextSize.Body,
									color = Theme.Color.Gold,
									align = Enum.TextXAlignment.Left,
									wrapped = true,
									size = UDim2.new(1, -52, 1, 0),
									position = UDim2.fromOffset(48, 0),
									zIndex = 3,
								}),
							},
						})
						else nil
				),
			}),
		},
	})
end

--------------------------------------------------------------------------------
-- Magnet
--------------------------------------------------------------------------------

local function MagnetDetails(props)
	local magnet = findById(GameData.magnets(), props.id)
	if not magnet then
		return nil
	end

	local state = props.state
	local actions = props.actions
	local owned = state.ownedMagnets[magnet.id] == true
	local equipped = state.equippedMagnet == magnet.id
	local style = Theme.rarity(magnet.rarity)

	local buttons
	if equipped then
		buttons = {
			e(Buttons.Button, {
				key = "Equipped",
				text = "EQUIPPED",
				variant = "Neutral",
				glyph = "check",
				disabled = true,
				size = UDim2.fromOffset(300, 54),
				layoutOrder = 1,
			}),
		}
	elseif owned then
		buttons = {
			e(Buttons.Button, {
				key = "Equip",
				text = "EQUIP",
				variant = "Primary",
				size = UDim2.fromOffset(300, 54),
				layoutOrder = 1,
				onClick = function()
					actions.equipMagnet(magnet.id)
					actions.closeDetail()
				end,
			}),
		}
	elseif magnet.shopPrice then
		local affordable = state.cash >= magnet.shopPrice
		buttons = {
			e(Buttons.Button, {
				key = "Buy",
				text = "BUY",
				subtext = Format.money(magnet.shopPrice),
				variant = "Purchase",
				disabled = not affordable,
				size = UDim2.fromOffset(300, 54),
				layoutOrder = 1,
				onClick = function()
					actions.confirm({
						Title = "Buy Magnet?",
						Glyph = "magnet",
						Lines = { magnet.name, magnet.description },
						Price = magnet.shopPrice,
						ConfirmText = "BUY",
						ConfirmVariant = "Purchase",
						ConfirmDisabled = not affordable,
						OnConfirm = function()
							actions.buyMagnet(magnet.id)
						end,
					})
				end,
			}),
		}
	else
		-- No shop price and not owned: it is a game-pass magnet.
		buttons = {
			e(Buttons.Button, {
				key = "Pass",
				text = "GET PASS",
				variant = "Premium",
				glyph = "robux",
				size = UDim2.fromOffset(300, 54),
				layoutOrder = 1,
				onClick = function()
					actions.purchase(magnet.id, "Pass")
				end,
			}),
		}
	end

	return e(DetailsFrame, {
		key = "MagnetDetails",
		title = magnet.name,
		rarity = magnet.rarity,
		glyph = "magnet",
		image = magnet.image,
		glyphColor = style.color,
		description = magnet.description,
		stats = {
			{ label = "Range", value = Format.studs(magnet.range), glyph = "pin" },
			{ label = "Strength", value = tostring(magnet.strength), glyph = "magnet" },
		},
		note = if owned or magnet.shopPrice then nil else "Unlocked by game pass",
		actions = buttons,
		onClose = actions.closeDetail,
	})
end

--------------------------------------------------------------------------------
-- Potion
--------------------------------------------------------------------------------

local function PotionDetails(props)
	local potion = findById(GameData.consumables(), props.id)
	if not potion then
		return nil
	end

	local state = props.state
	local actions = props.actions
	local owned = state.potionCounts[potion.id] or 0

	local function use(count: number)
		actions.confirm({
			Title = "Use Potion?",
			Glyph = "potion",
			Lines = { potion.name, potion.description },
			ConfirmText = "USE",
			OnConfirm = function()
				for _ = 1, count do
					actions.usePotion(potion.id)
				end
			end,
		})
	end

	return e(DetailsFrame, {
		key = "PotionDetails",
		title = potion.name,
		rarity = potion.rarity,
		glyph = "potion",
		image = potion.image,
		description = potion.description,
		badges = {
			e(Indicators.Badge, {
				key = "Owned",
				text = "OWNED " .. Format.comma(owned),
				gradient = Theme.Gradient.PanelDeep,
				textSize = Theme.TextSize.Small,
				layoutOrder = 1,
			}),
		},
		stats = {
			{
				label = "Duration",
				value = Format.duration(potion.duration),
				glyph = "clock",
			},
			{
				label = "Owned",
				value = Format.comma(owned),
				glyph = "potion",
				color = Theme.Color.Gold,
			},
		},
		actions = {
			e(Buttons.Button, {
				key = "Use",
				text = "USE",
				variant = "Primary",
				disabled = owned <= 0,
				size = UDim2.fromOffset(220, 54),
				layoutOrder = 1,
				onClick = function()
					use(1)
				end,
			}),
			e(Buttons.Button, {
				key = "UseMultiple",
				text = "USE x5",
				variant = "Secondary",
				disabled = owned < 5,
				size = UDim2.fromOffset(160, 54),
				layoutOrder = 2,
				onClick = function()
					use(5)
				end,
			}),
		},
		onClose = actions.closeDetail,
	})
end

--------------------------------------------------------------------------------
-- Pet
--------------------------------------------------------------------------------

local function PetDetails(props)
	local state = props.state
	local actions = props.actions

	local pet = findById(GameData.pets(state.ownedPets), props.id)
	if not pet then
		return nil
	end

	local style = Theme.rarity(pet.rarity)

	--[[
		COPIES, NOT IDENTITY.

		The server tracks equipped pets as a COUNT per id, and the grid draws one card per copy owned. This
		used to set a single `equipped` boolean if ANY copy was equipped, which disabled EQUIP -- so owning
		two of the same pet and equipping one left the second copy offering only UNEQUIP. "Equip best" did
		the right thing, which is what made it look like a UI bug rather than a logic one.

		Both actions can be live at once now, and that is correct: with two copies and one equipped there is
		genuinely a copy to equip AND a copy to take off.
	]]
	local equippedCopies = 0
	for _, id in ipairs(state.equippedPets) do
		if id == pet.id then
			equippedCopies += 1
		end
	end
	local ownedCopies = pet.count or 0
	local canEquipAnother = equippedCopies < ownedCopies
	local canUnequip = equippedCopies > 0

	local equipped = false
	for _, id in ipairs(state.equippedPets) do
		if id == pet.id then
			equipped = true
			break
		end
	end

	local buttons
	if not pet.owned then
		buttons = {
			e(Buttons.Button, {
				key = "Locked",
				text = "NOT OWNED",
				glyph = "lock",
				disabled = true,
				size = UDim2.fromOffset(300, 54),
				layoutOrder = 1,
			}),
		}
	else
		buttons = {
			e(Buttons.Button, {
				key = "Equip",
				text = "EQUIP",
				variant = "Primary",
				disabled = not canEquipAnother,
				size = UDim2.fromOffset(180, 54),
				layoutOrder = 1,
				onClick = function()
					actions.equipPet(pet.id)
				end,
			}),
			e(Buttons.Button, {
				key = "Unequip",
				text = "UNEQUIP",
				variant = "Secondary",
				disabled = not canUnequip,
				size = UDim2.fromOffset(180, 54),
				layoutOrder = 2,
				onClick = function()
					actions.unequipPet(pet.id)
				end,
			}),
			e(Buttons.Button, {
				key = "Delete",
				text = "DELETE",
				variant = "Danger",
				disabled = equipped,
				size = UDim2.fromOffset(140, 54),
				layoutOrder = 3,
				onClick = function()
					actions.confirm({
						Title = "Delete Pet?",
						Glyph = "paw",
						Lines = { pet.name, "This cannot be undone." },
						ConfirmText = "DELETE",
						ConfirmVariant = "Danger",
						OnConfirm = function()
							actions.deletePet(pet.id)
							actions.closeDetail()
						end,
					})
				end,
			}),
		}
	end

	return e(DetailsFrame, {
		key = "PetDetails",
		title = pet.name,
		rarity = pet.rarity,
		-- Renders the real pet rather than a glyph.
		model = pet.id,
		modelKind = "pet",
		glyph = "paw",
		image = pet.image,
		glyphColor = style.color,
		artHeight = PET_ART_HEIGHT,
		compactStats = true,
		statColumns = 2,
		description = pet.description,
		badges = P.compact(
			e(Indicators.Badge, {
				key = "Bonus",
				text = string.upper(pet.bonus),
				gradient = Theme.Gradient.Green,
				textSize = Theme.TextSize.Small,
				layoutOrder = 1,
			}),
			if pet.count > 0
				then e(Indicators.Badge, {
					key = "Owned",
					text = "OWNED x" .. Format.comma(pet.count),
					gradient = Theme.Gradient.PanelDeep,
					textSize = Theme.TextSize.Small,
					layoutOrder = 2,
				})
				else nil
		),
		stats = pet.effects or {},
		note = if pet.cashCapNote and not pet.owned
			then "Hatch this pet from an egg. " .. pet.cashCapNote
			elseif pet.cashCapNote then pet.cashCapNote
			elseif pet.owned then nil
			else "Hatch this pet from an egg",
		noteGlyph = if pet.cashCapNote then "note" else "lock",
		actions = buttons,
		onClose = actions.closeDetail,
	})
end

--------------------------------------------------------------------------------
-- Router
--------------------------------------------------------------------------------

local function DetailsModal(props)
	local detail = props.state.detail
	if not detail then
		return nil
	end

	if detail.kind == "magnet" then
		return e(MagnetDetails, { id = detail.id, state = props.state, actions = props.actions })
	elseif detail.kind == "potion" then
		return e(PotionDetails, { id = detail.id, state = props.state, actions = props.actions })
	elseif detail.kind == "pet" then
		return e(PetDetails, { id = detail.id, state = props.state, actions = props.actions })
	end

	return nil
end

return {
	DetailsModal = DetailsModal,
	DetailsFrame = DetailsFrame,
	MagnetDetails = MagnetDetails,
	PotionDetails = PotionDetails,
	PetDetails = PetDetails,
}
