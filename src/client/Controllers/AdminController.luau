--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminConfig = require(ReplicatedStorage.Shared.Config.AdminConfig)
local InventoryConfig = require(ReplicatedStorage.Shared.Config.InventoryConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)

local AdminController = {}

function AdminController.Start()
	local player = Players.LocalPlayer
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("AdminUI") :: ScreenGui
	if not AdminConfig.IsAdmin(player.UserId) then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	local toggle = gui:WaitForChild("AdminToggle") :: TextButton
	local panel = gui:WaitForChild("AdminPanel") :: Frame
	local close = panel.Header:WaitForChild("CloseButton") :: TextButton
	local targetButton = panel:WaitForChild("TargetButton") :: TextButton
	local playerButton = panel:WaitForChild("PlayerButton") :: TextButton
	local playerList = panel:WaitForChild("PlayerList") :: ScrollingFrame
	local playerTemplate = playerList:WaitForChild("PlayerTemplate") :: TextButton
	local amountBox = panel:WaitForChild("AmountBox") :: TextBox
	local itemBox = panel:WaitForChild("ItemBox") :: TextBox
	local itemPickerButton = panel:WaitForChild("ItemPickerButton") :: TextButton
	local itemList = panel:WaitForChild("ItemList") :: ScrollingFrame
	local itemTemplate = itemList:WaitForChild("ItemTemplate") :: TextButton
	local statusLabel = panel:WaitForChild("StatusLabel") :: TextLabel
	local remote = ReplicatedStorage.Remotes:WaitForChild("AdminCommand") :: RemoteEvent
	local targetMode = "Self"
	local selectedTargetUserId = player.UserId
	local hasSelectedPlayer = false
	panel.Visible = false

	local function setStatus(message: string, isDanger: boolean?)
		statusLabel.Text = message
		statusLabel.TextColor3 = if isDanger
			then Color3.fromRGB(255, 118, 128)
			else Color3.fromRGB(128, 218, 157)
	end

	local function refreshPlayerList()
		for _, child in playerList:GetChildren() do
			if child:IsA("TextButton") and child ~= playerTemplate then
				child:Destroy()
			end
		end
		for _, targetPlayer in Players:GetPlayers() do
			local row = playerTemplate:Clone()
			row.Name = string.format("Player_%010d", targetPlayer.UserId)
			row.Text = `{targetPlayer.DisplayName}  (@{targetPlayer.Name})`
			row.Visible = true
			row.Activated:Connect(function()
				selectedTargetUserId = targetPlayer.UserId
				hasSelectedPlayer = true
				playerButton.Text = `PLAYER: {string.upper(targetPlayer.DisplayName)}`
				playerList.Visible = false
				setStatus(`Selected {targetPlayer.DisplayName}.`)
			end)
			row.Parent = playerList
		end
	end

	local function addItemChoice(
		itemId: string,
		displayName: string,
		category: string,
		order: number
	)
		local row = itemTemplate:Clone()
		row.Name = `Item_{category}_{itemId}`
		row.LayoutOrder = order
		row.Text = `[{category}]  {displayName}  —  {itemId}`
		row.Visible = true
		row.Activated:Connect(function()
			itemBox.Text = itemId
			itemList.Visible = false
			setStatus(`Selected {itemId}.`)
		end)
		row.Parent = itemList
	end

	local function populateItemList()
		for _, child in itemList:GetChildren() do
			if child:IsA("TextButton") and child ~= itemTemplate then
				child:Destroy()
			end
		end
		local order = 0
		for _, eggId in PetConfig.EggOrder do
			for _, petId in PetConfig.Eggs[eggId].PetIds do
				order += 1
				addItemChoice(petId, PetConfig.Pets[petId].DisplayName, "PET", order)
			end
		end
		for _, petId in PetConfig.PremiumOrder do
			order += 1
			addItemChoice(petId, PetConfig.Pets[petId].DisplayName, "PREMIUM PET", order)
		end
		for _, magnetId in InventoryConfig.MagnetOrder do
			order += 1
			addItemChoice(magnetId, InventoryConfig.Magnets[magnetId].DisplayName, "MAGNET", order)
		end
		for _, consumableId in InventoryConfig.ConsumableOrder do
			order += 1
			addItemChoice(
				consumableId,
				InventoryConfig.Consumables[consumableId].DisplayName,
				"CONSUMABLE",
				order
			)
		end
		for _, upgradeId in UpgradeConfig.Order do
			order += 1
			addItemChoice(upgradeId, UpgradeConfig.ById[upgradeId].DisplayName, "UPGRADE", order)
		end
	end

	local function send(command: string, useAmount: boolean, useItem: boolean)
		if targetMode == "Player" and not hasSelectedPlayer then
			setStatus("Select a connected player first.", true)
			return
		end
		local amount = if useAmount then tonumber(amountBox.Text) else nil
		if useAmount and amount == nil then
			setStatus("Enter a valid number first.", true)
			return
		end
		local itemId = if useItem then string.gsub(itemBox.Text, "%s+", "") else nil
		if useItem and itemId == "" then
			setStatus("Enter an exact item ID first.", true)
			return
		end
		if command == "GrantTestItems" and targetMode ~= "Self" then
			setStatus("Test-potion bundle is Studio Self-only.", true)
			return
		end
		remote:FireServer(command, amount, targetMode, selectedTargetUserId, itemId)
		setStatus(`Sent {command} to {string.upper(targetMode)}.`)
	end

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	close.Activated:Connect(function()
		panel.Visible = false
		playerList.Visible = false
		itemList.Visible = false
	end)
	targetButton.Activated:Connect(function()
		targetMode = if targetMode == "Self"
			then "Player"
			elseif targetMode == "Player" then "All"
			else "Self"
		targetButton.Text = `TARGET: {string.upper(targetMode)}`
		targetButton.BackgroundColor3 = if targetMode == "All"
			then Color3.fromRGB(190, 92, 42)
			elseif targetMode == "Player" then Color3.fromRGB(119, 78, 190)
			else Color3.fromRGB(55, 112, 196)
		playerButton.Visible = targetMode == "Player"
		playerList.Visible = false
		setStatus(
			if targetMode == "All"
				then "Commands will affect this entire server."
				elseif targetMode == "Player" then "Choose a connected player below."
				else "Commands will affect only you.",
			targetMode == "All"
		)
	end)
	playerButton.Activated:Connect(function()
		refreshPlayerList()
		itemList.Visible = false
		playerList.Visible = not playerList.Visible
	end)
	itemPickerButton.Activated:Connect(function()
		playerList.Visible = false
		itemList.Visible = not itemList.Visible
	end)
	Players.PlayerAdded:Connect(refreshPlayerList)
	Players.PlayerRemoving:Connect(function(leavingPlayer)
		if leavingPlayer.UserId == selectedTargetUserId then
			selectedTargetUserId = player.UserId
			hasSelectedPlayer = false
			playerButton.Text = "SELECT PLAYER"
		end
		refreshPlayerList()
	end)
	refreshPlayerList()
	populateItemList()

	local commands = {
		AddMoneyButton = { "AddMoney", true, false },
		AddGearsButton = { "AddGears", true, false },
		UnlockAreasButton = { "UnlockAllAreas", false, false },
		MaxUpgradesButton = { "MaxUpgrades", false, false },
		ClearStorageButton = { "ClearStorage", false, false },
		GrantTestItemsButton = { "GrantTestItems", false, false },
		GrantPetButton = { "GrantPet", true, true },
		GrantMagnetButton = { "GrantMagnet", false, true },
		GrantConsumableButton = { "GrantConsumable", true, true },
		AddUpgradeLevelsButton = { "AddUpgradeLevels", true, true },
	}
	for buttonName, definition in commands do
		local button = panel:WaitForChild(buttonName) :: TextButton
		button.Activated:Connect(function()
			send(definition[1] :: string, definition[2] :: boolean, definition[3] :: boolean)
		end)
	end

	local reset = panel:WaitForChild("ResetTestProfileButton") :: TextButton
	reset.Activated:Connect(function()
		if reset:GetAttribute("ConfirmArmed") == true then
			reset:SetAttribute("ConfirmArmed", false)
			reset.Text = "RESET TEST PROFILE"
			remote:FireServer("ResetProfile", nil, "Self", player.UserId, nil)
			setStatus("Development profile reset requested.")
			return
		end
		reset:SetAttribute("ConfirmArmed", true)
		reset.Text = "CLICK AGAIN TO CONFIRM RESET"
		setStatus("This resets your Studio development save.", true)
		task.delay(5, function()
			if reset.Parent and reset:GetAttribute("ConfirmArmed") == true then
				reset:SetAttribute("ConfirmArmed", false)
				reset.Text = "RESET TEST PROFILE"
				setStatus("Reset cancelled.")
			end
		end)
	end)
end

return table.freeze(AdminController)
