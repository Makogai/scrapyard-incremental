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

	EVERY COPY IS ITS OWN CARD. The grid used to show one card per pet TYPE with a count on it, which made
	a collection of forty pets look like five things -- and made "pet storage is full" unexplainable,
	because the screen was not showing the forty. Storage caps total COPIES, so the grid now lists copies:
	what the number in the corner is counting is what you can see.

	The rail's slot count comes from `state.petSlots`, which the SERVER computes. It used to be recomputed
	here from `state.petSlotUpgradeLevel` -- a field the store does not expose -- so it silently fell back
	to the base two, and a purchased slot never appeared even though the server would happily equip into
	it.
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
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local Overlays = require(UI.Components.Overlays)

local e = React.createElement

--[[
	Rarity order for sorting and for picking "best".

	Taken from `Theme.PetRarityOrder` rather than written out again. The hand-written table this replaces
	listed Common/Rare/Epic/Legendary/Mythic -- but pets are Common/Uncommon/Rare/Epic/Legendary/SECRET, so
	Uncommon and Secret both ranked 0: EQUIP BEST would pass over a Secret to equip a Common.
]]
local function rarityRank(rarity: string): number
	local index = table.find(Theme.PetRarityOrder, rarity)
	return if index then index else 0
end

--- How the grid can be ordered. `id` is what the button carries; `label` is what it says.
local SORTS = {
	{ id = "RARITY", label = "RARITY" },
	{ id = "NAME", label = "NAME" },
	{ id = "COUNT", label = "MOST OWNED" },
}

local function PetsScreen(props)
	local state = props.state
	local actions = props.actions

	local sort, setSort = React.useState("RARITY")
	--[[
		An explicit SELECT mode rather than right-click or long-press.

		This game is played on phones as much as on desktop, and a right-click has no touch equivalent that
		is not a long-press timer -- which then has to fight the card's own tap. A mode button behaves
		identically on both, and it makes the destructive action something you opt into.
	]]
	local selecting, setSelecting = React.useState(false)
	--[[
		Selection lives here, not in the store: it is a property of this window being open, and a selection
		that survived closing the window would delete pets someone forgot they had ticked.

		Keyed by COPY -- `petId#n` -- so selecting one of three duplicates does not select all three.
	]]
	local selected, setSelected = React.useState({})

	local pets = GameData.pets(state.ownedPets)
	--- The server's number. See the note in the header about why this is not recomputed here.
	local slots = state.petSlots or PetConfig.BaseEquipSlots
	local nextSlotCost = GameData.nextPetSlotCost(state.petSlotUpgradeLevel or 0)

	local equippedSet = {}
	--- How many copies of each pet are equipped, so the right NUMBER of copies show as equipped.
	local equippedCounts = {}
	for _, id in ipairs(state.equippedPets) do
		equippedSet[id] = true
		equippedCounts[id] = (equippedCounts[id] or 0) + 1
	end

	--[[
		One entry per COPY owned, which is what the grid draws and what storage counts.

		`index` is that copy's position within its own pet, and the first N copies of a pet are the ones
		marked equipped -- the server tracks equipped copies as a count, not as identities, so any N of them
		is a faithful rendering.
	]]
	local copies = {}
	local typesOwned = 0
	for _, pet in ipairs(pets) do
		if pet.owned then
			typesOwned += 1
			for index = 1, pet.count do
				table.insert(copies, {
					key = `{pet.id}#{index}`,
					pet = pet,
					index = index,
					equipped = index <= (equippedCounts[pet.id] or 0),
				})
			end
		end
	end

	table.sort(copies, function(a, b)
		if sort == "NAME" then
			if a.pet.name ~= b.pet.name then
				return a.pet.name < b.pet.name
			end
		elseif sort == "COUNT" then
			if a.pet.count ~= b.pet.count then
				return a.pet.count > b.pet.count
			end
		else
			local rankA, rankB = rarityRank(a.pet.rarity), rarityRank(b.pet.rarity)
			if rankA ~= rankB then
				return rankA > rankB
			end
			if a.pet.name ~= b.pet.name then
				return a.pet.name < b.pet.name
			end
		end
		--- Copies of the same pet always run in order, whatever the sort.
		return a.index < b.index
	end)

	--- The label for the sort button: the order it is in, not the order it would switch to.
	local sortLabel = "RARITY"
	for _, entry in ipairs(SORTS) do
		if entry.id == sort then
			sortLabel = entry.label
		end
	end

	local storageUsed = #copies
	local storageCapacity = state.petStorageCapacity or storageUsed

	--- What is ticked, and how many copies of each pet that adds up to.
	local selectedCount = 0
	local selectedPerPet = {}
	for copyKey, isSelected in pairs(selected) do
		if isSelected then
			local petId = string.match(copyKey, "^(.+)#%d+$")
			if petId then
				selectedCount += 1
				selectedPerPet[petId] = (selectedPerPet[petId] or 0) + 1
			end
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
		Owned only, one card per COPY. A locked card here would duplicate the summon window and make the
		collection look emptier than it is.

		In selection mode a click TICKS the card instead of opening its details -- one gesture, two meanings,
		decided by the mode rather than by where on the card the press landed.
	]]
	local grid = {}
	for order, copy in ipairs(copies) do
		local copyKey = copy.key
		grid[order] = e(Cards.PetCard, {
			key = copyKey,
			name = copy.pet.name,
			rarity = copy.pet.rarity,
			bonus = copy.pet.bonus,
			image = copy.pet.image,
			model = copy.pet.id,
			equipped = copy.equipped,
			selected = selected[copyKey] == true,
			layoutOrder = order,
			onClick = function()
				if selecting then
					local nextSelection = table.clone(selected)
					nextSelection[copyKey] = if nextSelection[copyKey] then nil else true
					setSelected(nextSelection)
				else
					actions.openDetail("pet", copy.pet.id)
				end
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
					size = UDim2.new(0, 560, 1, 0),
					layout = P.list({
						direction = Enum.FillDirection.Horizontal,
						padding = 8,
						vAlign = Enum.VerticalAlignment.Center,
					}),
					children = P.compact(
						e(Indicators.Badge, {
							key = "Equipped",
							text = "EQUIPPED " .. Format.fraction(#state.equippedPets, slots),
							gradient = Theme.Gradient.Blue,
							textSize = Theme.TextSize.Small,
							layoutOrder = 1,
						}),
						--[[
							STORAGE, not "collected".

							This is the number the game refuses hatches over, so it is the one that has to be on
							screen: a player who reads "pet storage is full" should be able to look up and see
							49/50. Types collected is a collection stat and lives in the index.
						]]
						e(Indicators.Badge, {
							key = "Storage",
							text = "PETS " .. Format.fraction(storageUsed, storageCapacity),
							gradient = if storageUsed >= storageCapacity
								then Theme.Gradient.Red
								else Theme.Gradient.PanelDeep,
							textSize = Theme.TextSize.Small,
							layoutOrder = 2,
						}),
						e(Indicators.Badge, {
							key = "Types",
							text = "KINDS " .. Format.fraction(typesOwned, #pets),
							gradient = Theme.Gradient.PanelDeep,
							textSize = Theme.TextSize.Small,
							layoutOrder = 3,
						}),
						--- Only when they hold one: nobody needs to be told they have no tickets.
						if (state.secretTickets or 0) > 0
							then e(Indicators.Badge, {
								key = "Tickets",
								text = `SECRET TICKETS {state.secretTickets}`,
								gradient = Theme.Gradient.Gold,
								textSize = Theme.TextSize.Small,
								layoutOrder = 4,
							})
							else nil
					),
				}),
				e(P.Group, {
					key = "Actions",
					size = UDim2.new(0, 470, 1, 0),
					position = UDim2.fromScale(1, 0),
					anchorPoint = Vector2.new(1, 0),
					layout = P.list({
						direction = Enum.FillDirection.Horizontal,
						padding = 8,
						hAlign = Enum.HorizontalAlignment.Right,
						vAlign = Enum.VerticalAlignment.Center,
					}),
					children = P.compact(
						--[[
							SORT cycles rather than opening a menu. Three orders is not enough to justify a dropdown,
							and a button whose label is the CURRENT order answers "how is this sorted" without being
							pressed.
						]]
						e(Buttons.Button, {
							key = "Sort",
							text = sortLabel,
							glyph = "chevron",
							variant = "Neutral",
							textSize = Theme.TextSize.Small,
							size = UDim2.fromOffset(158, 40),
							lip = 4,
							layoutOrder = 1,
							onClick = function()
								local index = 1
								for position, entry in ipairs(SORTS) do
									if entry.id == sort then
										index = position
										break
									end
								end
								setSort(SORTS[index % #SORTS + 1].id)
							end,
						}),
						--[[
							SELECT, and in select mode it becomes the way out. The delete button appears beside it
							rather than replacing anything, so leaving the mode is always in the same place.
						]]
						e(Buttons.Button, {
							key = "Select",
							text = if selecting then "CANCEL" else "SELECT",
							variant = if selecting then "Danger" else "Neutral",
							textSize = Theme.TextSize.Small,
							size = UDim2.fromOffset(120, 40),
							lip = 4,
							layoutOrder = 2,
							onClick = function()
								setSelected({})
								setSelecting(not selecting)
							end,
						}),
						--[[
							Only while something is ticked. A DELETE (0) button is a button that does nothing, and
							the count in the label is what makes the confirmation unnecessary to read twice.
						]]
						if selecting and selectedCount > 0
							then e(Buttons.Button, {
								key = "DeleteSelected",
								text = `DELETE {selectedCount}`,
								glyph = "cross",
								variant = "Danger",
								textSize = Theme.TextSize.Small,
								size = UDim2.fromOffset(140, 40),
								lip = 4,
								layoutOrder = 3,
								onClick = function()
									actions.confirm({
										Title = `Delete {selectedCount} pet{if selectedCount
												== 1
											then ""
											else "s"}?`,
										--[[
											`Lines` and `ConfirmText`/`ConfirmVariant` are the fields the dialog
											actually forwards -- `Body` and `Danger` are not among them, so a
											confirmation written with those came up wordless and green.
										]]
										Lines = { "Deleted pets are gone for good." },
										ConfirmText = "DELETE",
										ConfirmVariant = "Danger",
										OnConfirm = function()
											--[[
												ONE CALL PER PET, carrying how many copies of it to drop -- not one call
												per copy. The remote is rate limited, and a player clearing thirty
												duplicates would trip it.
											]]
											for petId, amount in pairs(selectedPerPet) do
												actions.deletePet(petId, amount)
											end
											setSelected({})
											setSelecting(false)
										end,
									})
								end,
							})
							else nil,
						e(Buttons.Button, {
							key = "EquipBest",
							text = "EQUIP BEST",
							variant = "Primary",
							textSize = Theme.TextSize.Small,
							size = UDim2.fromOffset(150, 40),
							lip = 4,
							layoutOrder = 4,
							onClick = function()
								--[[
									No bulk equip server-side: one intent per slot.

									Ranked over COPIES, not types, so a player whose best two pets are two copies of
									the same Legendary gets both equipped -- the server allows that when the copies
									are owned, and the old per-type loop could not express it.
								]]
								local ranked = table.clone(copies)
								table.sort(ranked, function(a, b)
									local rankA = rarityRank(a.pet.rarity)
									local rankB = rarityRank(b.pet.rarity)
									if rankA ~= rankB then
										return rankA > rankB
									end
									return a.index < b.index
								end)
								for index = 1, math.min(slots, #ranked) do
									actions.equipPet(ranked[index].pet.id)
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
								layoutOrder = 5,
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
