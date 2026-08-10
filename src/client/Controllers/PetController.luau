--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)

local PetController = {}

local function formatNumber(value: number): string
	if value >= 1e6 then
		return string.format("%.1fM", value / 1e6)
	elseif value >= 1e3 then
		return string.format("%.1fK", value / 1e3)
	end
	return tostring(math.floor(value))
end

function PetController.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local safeArea = playerGui:WaitForChild("ScrapyardUI"):WaitForChild("SafeArea")
	local menus = safeArea:WaitForChild("Menus")
	local menu = menus:FindFirstChild("PetsMenu") :: GuiObject?
	local toggle = safeArea:FindFirstChild("PetsButton", true) :: GuiButton?
	if menu == nil or toggle == nil then
		warn("[Pets] Authored PetsMenu or PetsButton is missing")
		return
	end
	local state: any = nil
	local selectedPetId: string? = nil
	local petAction = ReplicatedStorage.Remotes.PetAction :: RemoteEvent
	local grid = menu:FindFirstChild("PetGrid", true) :: ScrollingFrame
	assert(grid, "Authored PetGrid is missing")
	local template = grid:WaitForChild("PetCardTemplate") :: GuiButton
	local detail = menu:FindFirstChild("PetDetail", true)
	assert(detail, "Authored PetDetail is missing")
	local equipButton = detail:WaitForChild("EquipButton") :: TextButton
	local slotButton = menu:FindFirstChild("SlotUpgradeButton", true) :: TextButton
	assert(slotButton, "Authored SlotUpgradeButton is missing")

	local function closeOtherMenus()
		for _, other in menus:GetChildren() do
			if other:IsA("GuiObject") then
				other.Visible = other == menu
			end
		end
	end

	local function render(current)
		state = current
		for _, child in grid:GetChildren() do
			if child:IsA("GuiButton") and child ~= template then
				child:Destroy()
			end
		end
		for petId, amount in state.OwnedPets do
			if amount > 0 and PetConfig.Pets[petId] then
				local definition = PetConfig.Pets[petId]
				local card = template:Clone()
				card.Name = `PetCard_{petId}`
				card.Visible = true
				card.LayoutOrder = -math.floor((definition.MoneyMultiplier or 1) * 100)
				card.BackgroundColor3 = definition.FallbackColor
				card.NameLabel.Text = definition.DisplayName
				card.Rarity.Text = string.upper(definition.Rarity)
				card.Amount.Text = `x{amount}`
				card.Icon.Image = definition.IconAssetId
				card.Activated:Connect(function()
					selectedPetId = petId
					detail.PetName.Text = definition.DisplayName
					detail.Rarity.Text = string.upper(definition.Rarity)
					detail.Bonus.Text =
						`+{math.floor((definition.MoneyMultiplier - 1) * 100)}% CASH`
					detail.Icon.Image = definition.IconAssetId
					local equippedCopies = 0
					for _, equippedId in state.EquippedPets do
						if equippedId == petId then
							equippedCopies += 1
						end
					end
					equipButton.Text = if equippedCopies < amount
							and #state.EquippedPets < state.MaximumEquippedPets
						then "EQUIP COPY"
						elseif equippedCopies > 0 then "UNEQUIP ONE"
						else "SLOTS FULL"
				end)
				card.Parent = grid
			end
		end
		menu.SlotsLabel.Text = `EQUIPPED {#state.EquippedPets} / {state.MaximumEquippedPets}`
		local nextSlot = state.PetSlotUpgradeLevel + 1
		if nextSlot <= PetConfig.MaximumSlotUpgradeLevel then
			local price = PetConfig.SlotUpgradeCosts[nextSlot]
			slotButton.Text = `+1 PET SLOT  $ {formatNumber(price)}`
			slotButton.Active = state.Money >= price
		else
			slotButton.Text = "CASH SLOTS MAXED"
			slotButton.Active = false
		end
		for _, eggId in PetConfig.EggOrder do
			local egg = PetConfig.Eggs[eggId]
			local card = menu:FindFirstChild(`EggCard_{eggId}`, true)
			if card then
				card.Price.Text = `$ {formatNumber(egg.Price)}`
				card.OpenButton.Active = state.UnlockedAreas[egg.RequiredArea]
					and state.Money >= egg.Price
				card.OpenButton.Text = if not state.UnlockedAreas[egg.RequiredArea]
					then "AREA LOCKED"
					elseif state.Money < egg.Price then "NEED CASH"
					else "HATCH"
			end
		end
	end

	toggle.Activated:Connect(function()
		closeOtherMenus()
		menu.Visible = true
	end)
	menu.CloseButton.Activated:Connect(function()
		menu.Visible = false
	end)
	equipButton.Activated:Connect(function()
		if selectedPetId and state then
			local equippedCopies = 0
			for _, equippedId in state.EquippedPets do
				if equippedId == selectedPetId then
					equippedCopies += 1
				end
			end
			local canEquip = equippedCopies < (state.OwnedPets[selectedPetId] or 0)
				and #state.EquippedPets < state.MaximumEquippedPets
			local action = if canEquip then "EquipPet" else "UnequipPet"
			petAction:FireServer(action, selectedPetId)
		end
	end)
	slotButton.Activated:Connect(function()
		petAction:FireServer("BuyPetSlot", "slot")
	end)
	for _, eggId in PetConfig.EggOrder do
		local card = menu:FindFirstChild(`EggCard_{eggId}`, true)
		if card then
			card.OpenButton.Activated:Connect(function()
				if card.OpenButton.Active then
					petAction:FireServer("OpenEgg", eggId)
				end
			end)
		end
	end
	ReplicatedStorage.Remotes.StateChanged.OnClientEvent:Connect(render)
	ReplicatedStorage.Remotes.PetResult.OnClientEvent:Connect(function(success, _, petId)
		if success and petId and PetConfig.Pets[petId] then
			selectedPetId = petId
		end
	end)
	ReplicatedStorage.Remotes.OpenPetShop.OnClientEvent:Connect(function()
		closeOtherMenus()
		menu.Visible = true
	end)
	local initial = ReplicatedStorage.Remotes.RequestInitialState:InvokeServer()
	if initial then
		render(initial)
	end
end

return table.freeze(PetController)
