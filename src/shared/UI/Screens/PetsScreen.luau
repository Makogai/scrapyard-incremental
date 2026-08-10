--!nonstrict
--[[
	PetsScreen.luau

	PETS window: the equipped rail and the pets you own.

	Two sections, not three. The egg hatchery row was removed: eggs are summoned at
	the podium (see `EggSummonScreen`), and offering them here as well meant two
	places to open the same egg with two different presentations.

	The inventory shows **only pets the player owns**. What can still be rolled --
	locked pets, silhouettes, drop chances -- belongs to the summon window; this is
	the "what do I have" screen.

	Migrated to live data. Slot count is derived the same way PetService derives
	it (base + purchased upgrades + pass bonus), and every button sends an intent:
	EquipPet / UnequipPet / DeletePet / BuyPetSlot.

	There is no bulk equip on the server, so EQUIP BEST is a client loop of
	EquipPet intents -- each one still validated individually server-side.
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
local Cards = require(UI.Components.Cards)
local Overlays = require(UI.Components.Overlays)

local e = React.createElement

--- Rarity order used to pick "best" when auto-equipping.
local RARITY_RANK = {
	Common = 1,
	Rare = 2,
	Epic = 3,
	Legendary = 4,
	Mythic = 5,
}

local function PetsScreen(props)
	local state = props.state
	local actions = props.actions

	local pets = GameData.pets(state.ownedPets)
	local slots = GameData.petSlots(state.petSlotUpgradeLevel or 0, state.entitlements)
	local nextSlotCost = GameData.nextPetSlotCost(state.petSlotUpgradeLevel or 0)

	local equippedSet = {}
	for _, id in ipairs(state.equippedPets) do
		equippedSet[id] = true
	end

	local ownedCount = 0
	for _, pet in ipairs(pets) do
		if pet.owned then
			ownedCount += 1
		end
	end

	-- Equipped rail: one card per available slot, empties included.
	local rail = {}
	for index = 1, slots do
		local petId = state.equippedPets[index]
		local pet = if petId then nil else nil
		if petId then
			for _, entry in ipairs(pets) do
				if entry.id == petId then
					pet = entry
					break
				end
			end
		end

		if pet then
			rail[#rail + 1] = e(Cards.PetCard, {
				key = "Slot" .. index,
				name = pet.name,
				rarity = pet.rarity,
				bonus = pet.bonus,
				image = pet.image,
				model = pet.id,
				equipped = true,
				size = UDim2.fromOffset(158, 196),
				layoutOrder = index,
				onClick = function()
					actions.openDetail("pet", pet.id)
				end,
			})
		else
			rail[#rail + 1] = e(Cards.EmptySlot, {
				key = "Slot" .. index,
				size = UDim2.fromOffset(158, 196),
				text = "EMPTY SLOT",
				layoutOrder = index,
			})
		end
	end

	-- One locked slot advertising the next upgrade or the pass.
	if nextSlotCost then
		rail[#rail + 1] = e(Cards.EmptySlot, {
			key = "NextSlot",
			size = UDim2.fromOffset(158, 196),
			glyph = "plus",
			-- Says what it is *for*, not just what it costs.
			text = "UPGRADE FOR MORE " .. Format.money(nextSlotCost),
			layoutOrder = slots + 1,
		})
	end

	--[[
		Owned only. A locked card here would duplicate the summon window and make the
		collection look emptier than it is.
	]]
	local grid = {}
	for _, pet in ipairs(pets) do
		if not pet.owned then
			continue
		end
		grid[#grid + 1] = e(Cards.PetCard, {
			key = pet.id,
			name = pet.name,
			rarity = pet.rarity,
			bonus = pet.bonus,
			image = pet.image,
			model = pet.id,
			equipped = equippedSet[pet.id],
			layoutOrder = #grid + 1,
			onClick = function()
				actions.openDetail("pet", pet.id)
			end,
		})
	end

	return e(Overlays.Modal, {
		key = props.key or "PetsScreen",
		title = "Pets",
		glyph = "paw",
		headerColor = Theme.Gradient.Pink,
		width = 1080,
		contentHeight = 640,
		onClose = actions.closeScreen,
		tabsHeight = 46,
		tabs = e(P.Group, {
			key = "Summary",
			size = UDim2.fromScale(1, 1),
			children = {
				e(P.Group, {
					key = "Counters",
					size = UDim2.new(0, 420, 1, 0),
					layout = P.list({
						direction = Enum.FillDirection.Horizontal,
						padding = 8,
						vAlign = Enum.VerticalAlignment.Center,
					}),
					children = {
						e(Indicators.Badge, {
							key = "Equipped",
							text = "EQUIPPED " .. Format.fraction(#state.equippedPets, slots),
							gradient = Theme.Gradient.Blue,
							textSize = Theme.TextSize.Small,
							layoutOrder = 1,
						}),
						e(Indicators.Badge, {
							key = "Owned",
							text = "COLLECTED " .. Format.fraction(ownedCount, #pets),
							gradient = Theme.Gradient.PanelDeep,
							textSize = Theme.TextSize.Small,
							layoutOrder = 2,
						}),
					},
				}),
				e(P.Group, {
					key = "Actions",
					size = UDim2.new(0, 360, 1, 0),
					position = UDim2.fromScale(1, 0),
					anchorPoint = Vector2.new(1, 0),
					layout = P.list({
						direction = Enum.FillDirection.Horizontal,
						padding = 8,
						hAlign = Enum.HorizontalAlignment.Right,
						vAlign = Enum.VerticalAlignment.Center,
					}),
					children = P.compact(
						e(Buttons.Button, {
							key = "EquipBest",
							text = "EQUIP BEST",
							variant = "Primary",
							textSize = Theme.TextSize.Small,
							size = UDim2.fromOffset(150, 40),
							lip = 4,
							layoutOrder = 1,
							onClick = function()
								-- No bulk equip server-side: send one intent per slot.
								local ranked = {}
								for _, pet in ipairs(pets) do
									if pet.owned then
										table.insert(ranked, pet)
									end
								end
								table.sort(ranked, function(a, b)
									return (RARITY_RANK[a.rarity] or 0)
										> (RARITY_RANK[b.rarity] or 0)
								end)
								for index = 1, math.min(slots, #ranked) do
									actions.equipPet(ranked[index].id)
								end
							end,
						}),
						if nextSlotCost
							then e(Buttons.Button, {
								key = "BuySlot",
								text = "BUY SLOT",
								variant = "Purchase",
								textSize = Theme.TextSize.Small,
								disabled = state.cash < nextSlotCost,
								size = UDim2.fromOffset(150, 40),
								lip = 4,
								layoutOrder = 2,
								onClick = function()
									actions.confirm({
										Title = "Buy Pet Slot?",
										Glyph = "paw",
										Lines = { "One more equipped pet slot." },
										Price = nextSlotCost,
										ConfirmText = "BUY",
										ConfirmVariant = "Purchase",
										OnConfirm = actions.buyPetSlot,
									})
								end,
							})
							else nil
					),
				}),
			},
		}),
		children = {
			e(Indicators.SectionHeader, {
				key = "EquippedHeader",
				text = "Equipped",
				size = UDim2.new(1, 0, 0, 26),
			}),
			e(P.Group, {
				key = "EquippedRail",
				size = UDim2.new(1, 0, 0, 196),
				position = UDim2.fromOffset(0, 28),
				layout = P.list({ direction = Enum.FillDirection.Horizontal, padding = 10 }),
				children = rail,
			}),
			--[[
				Tight under the rail. There used to be a 44px gap here, left over from
				when an egg row sat between the two sections.
			]]
			e(Indicators.SectionHeader, {
				key = "AllHeader",
				text = "Your Pets",
				size = UDim2.new(1, 0, 0, 26),
				position = UDim2.fromOffset(0, 232),
			}),
			e(P.Scroller, {
				key = "PetGrid",
				size = UDim2.new(1, 0, 1, -262),
				position = UDim2.fromOffset(0, 262),
				padding = { right = 10, bottom = 6 },
				layout = P.grid({
					cell = UDim2.fromOffset(158, 196),
					padding = UDim2.fromOffset(12, 12),
				}),
				children = grid,
			}),
		},
	})
end

return PetsScreen
