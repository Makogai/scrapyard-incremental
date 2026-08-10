--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local AdminConfig = require(ReplicatedStorage.Shared.Config.AdminConfig)
local AreaConfig = require(ReplicatedStorage.Shared.Config.AreaConfig)
local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)
local InventoryConfig = require(ReplicatedStorage.Shared.Config.InventoryConfig)
local ItemIconConfig = require(ReplicatedStorage.Shared.Config.ItemIconConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local PrestigeConfig = require(ReplicatedStorage.Shared.Config.PrestigeConfig)
local ScrapConfig = require(ReplicatedStorage.Shared.Config.ScrapConfig)
local GameMath = require(ReplicatedStorage.Shared.Utility.GameMath)
local ClientPreferences = require(script.Parent.Parent.ClientPreferences)

local UIController = {}

local function formatNumber(value: number): string
	if value >= 1e12 then
		return string.format("%.2fT", value / 1e12)
	elseif value >= 1e9 then
		return string.format("%.2fB", value / 1e9)
	elseif value >= 1e6 then
		return string.format("%.2fM", value / 1e6)
	elseif value >= 1e3 then
		return string.format("%.1fK", value / 1e3)
	end
	return tostring(math.floor(value))
end

local function requireChild(parent: Instance, name: string): Instance
	return assert(parent:FindFirstChild(name), `{parent:GetFullName()}.{name} is missing`)
end

function UIController.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = assert(
		playerGui:WaitForChild("ScrapyardUI", 15),
		"Studio-authored ScrapyardUI did not replicate"
	) :: ScreenGui
	local safeArea = requireChild(gui, "SafeArea")
	local loadingPanel = requireChild(safeArea, "LoadingPanel") :: GuiObject
	local topBar = requireChild(safeArea, "TopBar")
	local moneyPanel = requireChild(topBar, "MoneyPanel")
	local gearsPanel = requireChild(topBar, "GearsPanel") :: GuiObject
	local storagePanel = requireChild(safeArea, "StoragePanel")
	local storageBar = requireChild(storagePanel, "StorageBar")
	local storageForeground = requireChild(storageBar, "Foreground")
	local storageFill = requireChild(storageForeground, "Fill") :: GuiObject
	local navigation = requireChild(safeArea, "Navigation")
	local menus = requireChild(safeArea, "Menus")
	local notification = requireChild(safeArea, "Notification") :: GuiObject
	local modalDimmer = safeArea:FindFirstChild("ModalDimmer") :: GuiObject?
	local notificationMessage = requireChild(notification, "Message") :: TextLabel
	local adminToggle = safeArea:FindFirstChild("AdminToggle") :: GuiObject?
	local function responsiveScale(target: Instance, scale: number)
		local scaler = target:FindFirstChild("ReworkResponsiveScale")
		if scaler and scaler:IsA("UIScale") then
			scaler.Scale = scale
		end
	end
	local function refreshResponsiveLayout()
		local camera = workspace.CurrentCamera
		local compact = camera ~= nil and camera.ViewportSize.Y < 500
		responsiveScale(topBar, if compact then 0.78 else 1)
		responsiveScale(navigation, if compact then 0.72 else 1)
		for _, menu in menus:GetChildren() do
			if menu:IsA("GuiObject") then
				responsiveScale(menu, if compact then 0.58 else 1)
			end
		end
		for _, overlayName in { "AdminPanel", "CodeRewardPopup" } do
			local overlay = safeArea:FindFirstChild(overlayName)
			if overlay then
				responsiveScale(overlay, if compact then 0.82 else 1)
			end
		end
		storagePanel.Size = if compact then UDim2.fromOffset(350, 64) else UDim2.fromOffset(430, 72)
		storagePanel.Position = if compact
			then UDim2.new(0.5, 0, 1, -58)
			else UDim2.new(0.5, 0, 1, -24)
	end
	refreshResponsiveLayout()
	if workspace.CurrentCamera then
		workspace.CurrentCamera
			:GetPropertyChangedSignal("ViewportSize")
			:Connect(refreshResponsiveLayout)
	end
	local function anyMenuVisible(): boolean
		for _, child in menus:GetChildren() do
			if child:IsA("GuiObject") and child.Visible then
				return true
			end
		end
		for _, overlayName in { "AdminPanel", "CodeRewardPopup" } do
			local overlay = safeArea:FindFirstChild(overlayName)
			if overlay and overlay:IsA("GuiObject") and overlay.Visible then
				return true
			end
		end
		return false
	end
	local function refreshOverlayVisibility()
		local menuOpen = anyMenuVisible()
		if modalDimmer then
			modalDimmer.Visible = menuOpen
		end
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, not menuOpen)
		end)
		if adminToggle then
			adminToggle.Visible = AdminConfig.IsAdmin(Players.LocalPlayer.UserId) and not menuOpen
		end
		if menuOpen then
			notification.Visible = false
		end
	end
	local moneyValue = requireChild(moneyPanel, "Value") :: TextLabel
	for _, overlayName in { "AdminPanel", "CodeRewardPopup" } do
		local overlay = safeArea:FindFirstChild(overlayName)
		if overlay and overlay:IsA("GuiObject") then
			overlay:GetPropertyChangedSignal("Visible"):Connect(refreshOverlayVisibility)
		end
	end
	local gearsValue = requireChild(gearsPanel, "Value") :: TextLabel
	local storageValue = requireChild(storagePanel, "Value") :: TextLabel
	local upgradesMenu = requireChild(menus, "UpgradesMenu") :: GuiObject
	local upgradesContent = assert(
		upgradesMenu:FindFirstChildWhichIsA("ScrollingFrame"),
		"UpgradesMenu.ScrollingFrame is missing"
	)
	local requestUpgrade = ReplicatedStorage.Remotes:WaitForChild("RequestUpgrade") :: RemoteEvent
	local areasMenu = requireChild(menus, "AreasMenu") :: GuiObject
	local areasContent = areasMenu:FindFirstChildWhichIsA("ScrollingFrame")
	local requestAreaUnlock =
		ReplicatedStorage.Remotes:WaitForChild("RequestAreaUnlock") :: RemoteEvent
	local inventoryAction = ReplicatedStorage.Remotes:WaitForChild("InventoryAction") :: RemoteEvent
	local redeemCode = ReplicatedStorage.Remotes:WaitForChild("RedeemCode") :: RemoteEvent
	local codeResult = ReplicatedStorage.Remotes:WaitForChild("CodeResult") :: RemoteEvent
	local currentState: any = nil
	local selectedInventoryId = "MagnetBasic"
	local selectedInventoryKind = "Magnet"
	local previousMoney: number? = nil
	local previousWeight: number? = nil
	local function pulse(target: Instance)
		if not ClientPreferences.Get("ScreenEffectsEnabled") then
			return
		end
		local scale = target:FindFirstChild("FeedbackScale")
		if scale and scale:IsA("UIScale") then
			scale.Scale = 1.1
			TweenService:Create(
				scale,
				TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end
	end

	local function renderState(state: any)
		currentState = state
		ClientPreferences.Update(state.Settings)
		local character = Players.LocalPlayer.Character
		local heldMagnet = if character then character:FindFirstChild("EquippedMagnet") else nil
		if heldMagnet then
			for _, effect in heldMagnet:GetDescendants() do
				if effect:IsA("ParticleEmitter") then
					effect.Enabled = state.Settings.ParticlesEnabled
				elseif effect:IsA("PointLight") or effect:IsA("Highlight") then
					effect.Enabled = state.Settings.ScreenEffectsEnabled
				end
			end
		end
		local audioFolder = SoundService:FindFirstChild("ScrapyardAudio")
		local music = if audioFolder then audioFolder:FindFirstChild("MusicLoop") else nil
		if music and music:IsA("Sound") then
			music.Volume = AudioConfig.MusicLoop.Volume * state.Settings.MusicVolume
			if state.Settings.MusicEnabled and music.SoundId ~= "" and not music.IsPlaying then
				music:Play()
			elseif not state.Settings.MusicEnabled and music.IsPlaying then
				music:Stop()
			end
		end
		moneyValue.Text = `$ {formatNumber(state.Money)}`
		gearsValue.Text = formatNumber(state.Gears)
		gearsPanel.Visible = state.Gears > 0
		local capacity = state.DerivedStats.StorageCapacity
		local storedWeight = state.StoredWeight
		storageValue.Text = `{formatNumber(storedWeight)} / {formatNumber(capacity)}`
		storageFill.Size =
			UDim2.fromScale(math.clamp(storedWeight / math.max(capacity, 1), 0, 1), 1)
		if previousMoney ~= nil and state.Money > previousMoney then
			pulse(moneyPanel)
		end
		if previousWeight ~= nil and storedWeight > previousWeight then
			pulse(storagePanel)
		end
		previousMoney = state.Money
		previousWeight = storedWeight
		for _, upgradeId in UpgradeConfig.Order do
			local definition = UpgradeConfig.ById[upgradeId]
			local row = requireChild(upgradesContent, `UpgradeRow_{upgradeId}`)
			local levelLabel = requireChild(row, "Level") :: TextLabel
			local effectLabel = requireChild(row, "Effect") :: TextLabel
			local priceLabel = requireChild(row, "Price") :: TextLabel
			local buyButton = requireChild(row, "BuyButton") :: GuiButton
			local level = state.UpgradeLevels[upgradeId]
			local maximumLevel = state.UpgradeMaximumLevels[upgradeId]
			local isMaximum = level >= maximumLevel
			local currentEffect = GameMath.incrementalUpgradeEffect(
				definition.BaseEffect,
				definition.EffectPerLevel,
				level,
				definition.EffectCurve,
				definition.CurvePower,
				definition.EffectCap
			)
			local nextEffect = GameMath.incrementalUpgradeEffect(
				definition.BaseEffect,
				definition.EffectPerLevel,
				level + 1,
				definition.EffectCurve,
				definition.CurvePower,
				definition.EffectCap
			)
			local price = GameMath.incrementalUpgradeCost(
				definition.BaseCost,
				definition.GrowthRate,
				definition.CostPower,
				level,
				Environment.MaximumMoney
			)
			levelLabel.Text = `LV. {level} / {maximumLevel}`
			effectLabel.Text = if isMaximum
				then `CAP REACHED - PRESTIGE TO EXPAND`
				else `{string.format("%.2f", currentEffect)}  >  {string.format(
					"%.2f",
					nextEffect
				)}{definition.EffectUnit}`
			priceLabel.Text = if isMaximum then "PRESTIGE" else `$ {formatNumber(price)}`
			buyButton.Active = not isMaximum
			buyButton.AutoButtonColor = not isMaximum
			local affordable = not isMaximum and state.Money >= price
			buyButton:SetAttribute("Affordable", affordable)
			local accentColor = buyButton:GetAttribute("AccentColor")
			buyButton.BackgroundColor3 = if affordable and typeof(accentColor) == "Color3"
				then accentColor
				else Color3.fromRGB(148, 157, 166)
			priceLabel.TextColor3 = if affordable
				then Color3.fromRGB(27, 42, 57)
				else Color3.fromRGB(214, 67, 76)
		end
		if areasContent then
			for _, areaId in AreaConfig.Order do
				local definition = AreaConfig.ById[areaId]
				local row = areasContent:FindFirstChild(`AreaRow_{areaId}`)
				if row then
					local status = requireChild(row, "Status") :: TextLabel
					local price = requireChild(row, "Price") :: TextLabel
					local unlockButton = requireChild(row, "UnlockButton") :: GuiButton
					local unlocked = state.UnlockedAreas[areaId] == true
					local affordable = not unlocked and state.Money >= definition.UnlockPrice
					status.Text = if unlocked then "OWNED" else "LOCKED"
					status.TextColor3 = if unlocked
						then Color3.fromRGB(73, 177, 86)
						else Color3.fromRGB(214, 67, 76)
					price.Text = if unlocked
						then "UNLOCKED"
						else `$ {formatNumber(definition.UnlockPrice)}`
					unlockButton.Active = not unlocked
					unlockButton.AutoButtonColor = not unlocked
					unlockButton:SetAttribute("Affordable", affordable)
					local accentColor = unlockButton:GetAttribute("AccentColor")
					unlockButton.BackgroundColor3 = if affordable
							and typeof(accentColor) == "Color3"
						then accentColor
						else Color3.fromRGB(148, 157, 166)
				end
			end
		end
		local settingsMenu = menus:FindFirstChild("SettingsMenu")
		local settingsContent = if settingsMenu
			then settingsMenu:FindFirstChildWhichIsA("ScrollingFrame")
			else nil
		if settingsContent then
			for settingId, value in state.Settings do
				local row = settingsContent:FindFirstChild(`SettingRow_{settingId}`)
				if row then
					local stateLabel = requireChild(row, "State") :: TextLabel
					local toggleButton = requireChild(row, "ToggleButton") :: GuiButton
					stateLabel.Text = if value then "ON" else "OFF"
					stateLabel.TextColor3 = if value
						then Color3.fromRGB(27, 42, 57)
						else Color3.fromRGB(214, 67, 76)
					toggleButton.BackgroundColor3 = if value
						then Color3.fromRGB(115, 207, 76)
						else Color3.fromRGB(148, 157, 166)
				end
			end
			for _, volumeId in { "SoundVolume", "MusicVolume" } do
				local row = settingsContent:FindFirstChild(`VolumeRow_{volumeId}`)
				if row then
					local track = requireChild(row, "Track")
					local fill = requireChild(track, "Fill") :: GuiObject
					local knob = requireChild(track, "Knob") :: GuiObject
					local valueLabel = requireChild(row, "Value") :: TextLabel
					local value = state.Settings[volumeId]
					fill.Size = UDim2.fromScale(value, 1)
					knob.Position = UDim2.fromScale(value, 0.5)
					valueLabel.Text = `{math.floor(value * 100 + 0.5)}%`
				end
			end
		end
		local collectionMenu = menus:FindFirstChild("CollectionMenu")
		local collectionContent = if collectionMenu
			then collectionMenu:FindFirstChildWhichIsA("ScrollingFrame")
			else nil
		if collectionContent then
			for scrapId, definition in ScrapConfig.ById do
				local row = collectionContent:FindFirstChild(`CollectionRow_{scrapId}`)
				local discovery = state.DiscoveredScrap[scrapId]
				if row and discovery then
					local nameLabel = requireChild(row, "DisplayName") :: TextLabel
					local variantLabel = requireChild(row, "Variant") :: TextLabel
					local countLabel = requireChild(row, "Count") :: TextLabel
					local icon = requireChild(row, "Icon") :: GuiObject
					local glyph = icon:FindFirstChild("Glyph")
					nameLabel.Text = if discovery.Discovered
						then definition.DisplayName
						else "?????"
					variantLabel.Text = if discovery.Discovered
						then `BEST: {string.upper(discovery.HighestVariant)}`
						else "UNDISCOVERED"
					countLabel.Text = if discovery.Discovered
						then `{formatNumber(discovery.TotalCollected)} COLLECTED`
						else "FIND THIS SCRAP TO REVEAL IT"
					icon.BackgroundColor3 = if discovery.Discovered
						then ScrapConfig.Variants[discovery.HighestVariant].Color
						else Color3.fromRGB(71, 81, 92)
					if glyph and glyph:IsA("TextLabel") then
						glyph.Text = if discovery.Discovered
							then string.upper(string.sub(definition.DisplayName, 1, 1))
							else "?"
					end
				end
			end
		end
		local inventoryMenu = menus:FindFirstChild("InventoryMenu")
		local inventoryGrid = if inventoryMenu
			then inventoryMenu:FindFirstChild("ItemGrid")
			else nil
		local inventoryDetail = if inventoryMenu
			then inventoryMenu:FindFirstChild("DetailPanel")
			else nil
		if inventoryGrid and inventoryDetail then
			for _, magnetId in InventoryConfig.MagnetOrder do
				local card = inventoryGrid:FindFirstChild(`InventoryCard_{magnetId}`)
				if card and card:IsA("GuiButton") then
					local iconDefinition = ItemIconConfig[magnetId]
					local plate = requireChild(card, "IconPlate")
					local icon = requireChild(plate, "Icon") :: ImageLabel
					local glyph = requireChild(plate, "Glyph") :: TextLabel
					icon.Image = if iconDefinition.AssetId ~= ""
						then `rbxassetid://{iconDefinition.AssetId}`
						else ""
					glyph.Visible = icon.Image == ""
					local owned = state.OwnedMagnets[magnetId] == true
					local equipped = state.EquippedMagnet == magnetId
					local meta = requireChild(card, "Meta") :: TextLabel
					local selected = requireChild(card, "Selected") :: UIStroke
					meta.Text = if equipped then "EQUIPPED" elseif owned then "OWNED" else "LOCKED"
					meta.TextColor3 = if equipped
						then Color3.fromRGB(55, 175, 103)
						else Color3.fromRGB(139, 84, 246)
					selected.Enabled = selectedInventoryId == magnetId
				end
			end
			for _, itemId in InventoryConfig.ConsumableOrder do
				local card = inventoryGrid:FindFirstChild(`InventoryCard_{itemId}`)
				if card and card:IsA("GuiButton") then
					local iconDefinition = ItemIconConfig[itemId]
					local plate = requireChild(card, "IconPlate")
					local icon = requireChild(plate, "Icon") :: ImageLabel
					local glyph = requireChild(plate, "Glyph") :: TextLabel
					icon.Image = if iconDefinition.AssetId ~= ""
						then `rbxassetid://{iconDefinition.AssetId}`
						else ""
					glyph.Visible = icon.Image == ""
					local count = state.Inventory[itemId] or 0
					local meta = requireChild(card, "Meta") :: TextLabel
					local selected = requireChild(card, "Selected") :: UIStroke
					meta.Text = `x{count}`
					selected.Enabled = selectedInventoryId == itemId
				end
			end
			local detailName = requireChild(inventoryDetail, "DetailName") :: TextLabel
			local detailDescription =
				requireChild(inventoryDetail, "DetailDescription") :: TextLabel
			local detailStats = requireChild(inventoryDetail, "DetailStats") :: TextLabel
			local detailStatus = requireChild(inventoryDetail, "DetailStatus") :: TextLabel
			local detailGlyph = requireChild(inventoryDetail, "DetailGlyph") :: TextLabel
			local detailIcon = requireChild(inventoryDetail, "DetailIcon") :: ImageLabel
			local detailHero = requireChild(inventoryDetail, "DetailHero") :: GuiObject
			local detailAction = requireChild(inventoryDetail, "DetailAction") :: TextButton
			if selectedInventoryKind == "Magnet" then
				local definition = InventoryConfig.Magnets[selectedInventoryId]
				local iconDefinition = ItemIconConfig[selectedInventoryId]
				detailIcon.Image = if iconDefinition.AssetId ~= ""
					then `rbxassetid://{iconDefinition.AssetId}`
					else ""
				detailGlyph.Visible = detailIcon.Image == ""
				local owned = state.OwnedMagnets[selectedInventoryId] == true
				local equipped = state.EquippedMagnet == selectedInventoryId
				detailName.Text = definition.DisplayName
				detailDescription.Text = definition.Description
				detailStats.Text =
					`BASE STRENGTH  {definition.BaseStrength}\nBASE RANGE  {definition.BaseRange}`
				detailStatus.Text = if equipped
					then "CURRENTLY EQUIPPED"
					elseif owned then "PERMANENT ITEM"
					else "NOT OWNED"
				detailGlyph.Text = if selectedInventoryId == "AdvancedMagnet" then "A" else "U"
				detailHero.BackgroundColor3 = if selectedInventoryId == "AdvancedMagnet"
					then Color3.fromRGB(42, 199, 214)
					else Color3.fromRGB(239, 74, 74)
				detailAction.Text = if equipped
					then "EQUIPPED"
					elseif owned then "EQUIP MAGNET"
					else "LOCKED"
				detailAction.Active = owned and not equipped
			else
				local definition = InventoryConfig.Consumables[selectedInventoryId]
				local iconDefinition = ItemIconConfig[selectedInventoryId]
				detailIcon.Image = if iconDefinition.AssetId ~= ""
					then `rbxassetid://{iconDefinition.AssetId}`
					else ""
				detailGlyph.Visible = detailIcon.Image == ""
				local count = state.Inventory[selectedInventoryId] or 0
				local endsAt = state.ActiveBoosts[`{definition.BoostId}EndsAt`] or 0
				local remaining = math.max(0, endsAt - os.time())
				detailName.Text = definition.DisplayName
				detailDescription.Text = definition.Description
				detailStats.Text = if definition.Multiplier
					then `{definition.Multiplier}x CASH VALUE`
					else `+{definition.Amount} MAGNET STRENGTH`
				detailStatus.Text = if remaining > 0
					then `ACTIVE • {math.ceil(remaining / 60)} MIN LEFT`
					else `OWNED  x{count}`
				detailGlyph.Text = if selectedInventoryId == "CashPotion" then "$" else "+"
				detailHero.BackgroundColor3 = if selectedInventoryId == "CashPotion"
					then Color3.fromRGB(255, 180, 42)
					else Color3.fromRGB(139, 84, 246)
				detailAction.Text = if count > 0 then "USE POTION" else "NONE OWNED"
				detailAction.Active = count > 0
			end
			detailAction.BackgroundColor3 = if detailAction.Active
				then Color3.fromRGB(139, 84, 246)
				else Color3.fromRGB(148, 157, 166)
		end
		local prestigeMenu = menus:FindFirstChild("PrestigeMenu")
		if prestigeMenu and prestigeMenu:IsA("GuiObject") then
			local prestigeContent = requireChild(prestigeMenu, "PrestigeContent")
			local progress = requireChild(prestigeContent, "MoneyProgress") :: TextLabel
			local rewardLabel = requireChild(prestigeContent, "Reward") :: TextLabel
			local currentMultiplier =
				requireChild(prestigeContent, "CurrentMultiplier") :: TextLabel
			local nextMultiplier = requireChild(prestigeContent, "NextMultiplier") :: TextLabel
			local action = requireChild(prestigeMenu, "PrestigeAction") :: TextButton
			local prestigeRequirement = GameMath.prestigeRequirement(
				PrestigeConfig.BaseMoneyRequirement,
				PrestigeConfig.RequirementGrowth,
				state.PrestigeCount,
				Environment.MaximumMoney
			)
			local reward = GameMath.scaledPrestigeGearReward(
				state.Money,
				prestigeRequirement,
				state.PrestigeCount,
				PrestigeConfig.MaximumGearsPerPrestige
			)
			local current = GameMath.gearValueMultiplier(
				state.Gears,
				PrestigeConfig.GearPower,
				PrestigeConfig.MaximumGearValueMultiplier
			)
			local nextValue = GameMath.gearValueMultiplier(
				state.Gears + math.max(reward, 1),
				PrestigeConfig.GearPower,
				PrestigeConfig.MaximumGearValueMultiplier
			)
			local valueCapReached = current >= PrestigeConfig.MaximumGearValueMultiplier
			progress.Text = `$ {formatNumber(state.Money)} / $ {formatNumber(prestigeRequirement)}`
			rewardLabel.Text = if reward > 0 then `REWARD: +{reward} GEARS` else "REWARD: LOCKED"
			currentMultiplier.Text = if valueCapReached
				then `CURRENT VALUE: {string.format("%.1f", current)}x (MAX)`
				else `CURRENT VALUE: {string.format("%.1f", current)}x`
			nextMultiplier.Text = if valueCapReached
				then "AFTER PRESTIGE: VALUE CAP REACHED"
				else `AFTER PRESTIGE: {string.format("%.1f", nextValue)}x`
			action.Active = reward > 0
			action.AutoButtonColor = reward > 0
			action.BackgroundColor3 = if reward > 0
				then Color3.fromRGB(255, 210, 52)
				else Color3.fromRGB(148, 157, 166)
			if reward <= 0 then
				action.Text = "REQUIREMENT NOT MET"
				action:SetAttribute("ConfirmArmed", false)
			elseif action:GetAttribute("ConfirmArmed") ~= true then
				action.Text = "PRESTIGE FOR GEARS"
			end
		end
	end

	for _, upgradeId in UpgradeConfig.Order do
		local row = requireChild(upgradesContent, `UpgradeRow_{upgradeId}`)
		local buyButton = requireChild(row, "BuyButton") :: GuiButton
		buyButton.Activated:Connect(function()
			if currentState ~= nil and buyButton.Active then
				requestUpgrade:FireServer(upgradeId)
			end
		end)
	end
	if areasContent then
		for _, areaId in AreaConfig.Order do
			local row = areasContent:FindFirstChild(`AreaRow_{areaId}`)
			if row then
				local unlockButton = requireChild(row, "UnlockButton") :: GuiButton
				unlockButton.Activated:Connect(function()
					if currentState ~= nil and unlockButton.Active then
						requestAreaUnlock:FireServer(areaId)
					end
				end)
			end
		end
	end
	local settingsMenu = menus:FindFirstChild("SettingsMenu")
	local settingsContent = if settingsMenu
		then settingsMenu:FindFirstChildWhichIsA("ScrollingFrame")
		else nil
	if settingsContent then
		for _, settingId in
			{
				"ParticlesEnabled",
				"ScreenEffectsEnabled",
				"SoundEnabled",
				"MusicEnabled",
			}
		do
			local row = settingsContent:FindFirstChild(`SettingRow_{settingId}`)
			if row then
				local toggleButton = requireChild(row, "ToggleButton") :: GuiButton
				toggleButton.Activated:Connect(function()
					if currentState ~= nil then
						local value = currentState.Settings[settingId] == true
						local update =
							ReplicatedStorage.Remotes:WaitForChild("UpdateSettings") :: RemoteEvent
						update:FireServer(settingId, not value)
					end
				end)
			end
		end
		local codeRow = settingsContent:FindFirstChild("CodesEntry")
		if codeRow then
			local codeBox = requireChild(codeRow, "CodeBox") :: TextBox
			local redeemButton = requireChild(codeRow, "RedeemButton") :: GuiButton
			redeemButton.Activated:Connect(function()
				if codeBox.Text ~= "" then
					redeemCode:FireServer(codeBox.Text)
					codeBox.Text = ""
				end
			end)
			local codeStatus = requireChild(codeRow, "CodeStatus") :: TextLabel
			codeResult.OnClientEvent:Connect(function(success: boolean, message: string, rewards)
				codeStatus.Text = message
				codeStatus.TextColor3 = if success
					then Color3.fromRGB(55, 175, 103)
					else Color3.fromRGB(214, 67, 76)
				if success and typeof(rewards) == "table" then
					local popup = requireChild(safeArea, "CodeRewardPopup") :: GuiObject
					local rewardGrid = requireChild(popup, "RewardGrid")
					for index = 1, 6 do
						local slot = requireChild(rewardGrid, `RewardSlot{index}`) :: GuiObject
						local reward = rewards[index]
						slot.Visible = reward ~= nil
						if reward then
							local iconDefinition = ItemIconConfig[reward.Id]
							local imageLabel = requireChild(slot, "Icon") :: ImageLabel
							local glyph = requireChild(slot, "Glyph") :: TextLabel
							local nameLabel = requireChild(slot, "ItemName") :: TextLabel
							local amountLabel = requireChild(slot, "Amount") :: TextLabel
							imageLabel.Image = if iconDefinition
									and iconDefinition.AssetId ~= ""
								then `rbxassetid://{iconDefinition.AssetId}`
								else ""
							glyph.Visible = imageLabel.Image == ""
							glyph.Text = if iconDefinition then iconDefinition.Glyph else "?"
							slot.BackgroundColor3 = if iconDefinition
								then iconDefinition.Color
								else Color3.fromRGB(139, 84, 246)
							local itemDefinition = InventoryConfig.Magnets[reward.Id]
								or InventoryConfig.Consumables[reward.Id]
							nameLabel.Text = if itemDefinition
								then itemDefinition.DisplayName
								else reward.Id
							amountLabel.Text = `x{reward.Amount}`
						end
					end
					popup.Visible = true
				end
			end)
		end
		local updateSettings =
			ReplicatedStorage.Remotes:WaitForChild("UpdateSettings") :: RemoteEvent
		for _, volumeId in { "SoundVolume", "MusicVolume" } do
			local row = settingsContent:FindFirstChild(`VolumeRow_{volumeId}`)
			if row then
				local track = requireChild(row, "Track") :: GuiObject
				local fill = requireChild(track, "Fill") :: GuiObject
				local knob = requireChild(track, "Knob") :: GuiObject
				local valueLabel = requireChild(row, "Value") :: TextLabel
				local dragging = false
				local value = 0
				local function preview(screenX: number)
					value = math.clamp(
						(screenX - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1),
						0,
						1
					)
					fill.Size = UDim2.fromScale(value, 1)
					knob.Position = UDim2.fromScale(value, 0.5)
					valueLabel.Text = `{math.floor(value * 100 + 0.5)}%`
				end
				track.InputBegan:Connect(function(input)
					if
						input.UserInputType == Enum.UserInputType.MouseButton1
						or input.UserInputType == Enum.UserInputType.Touch
					then
						dragging = true
						preview(input.Position.X)
					end
				end)
				UserInputService.InputChanged:Connect(function(input)
					if
						dragging
						and (
							input.UserInputType == Enum.UserInputType.MouseMovement
							or input.UserInputType == Enum.UserInputType.Touch
						)
					then
						preview(input.Position.X)
					end
				end)
				UserInputService.InputEnded:Connect(function(input)
					if
						dragging
						and (
							input.UserInputType == Enum.UserInputType.MouseButton1
							or input.UserInputType == Enum.UserInputType.Touch
						)
					then
						dragging = false
						updateSettings:FireServer(volumeId, value)
					end
				end)
			end
		end
	end
	local prestigeMenu = menus:FindFirstChild("PrestigeMenu")
	if prestigeMenu then
		local prestigeAction = requireChild(prestigeMenu, "PrestigeAction") :: TextButton
		local requestPrestige =
			ReplicatedStorage.Remotes:WaitForChild("RequestPrestige") :: RemoteEvent
		local armSerial = 0
		prestigeAction.Activated:Connect(function()
			if not prestigeAction.Active then
				return
			end
			if prestigeAction:GetAttribute("ConfirmArmed") == true then
				prestigeAction:SetAttribute("ConfirmArmed", false)
				requestPrestige:FireServer()
				return
			end
			armSerial += 1
			local serial = armSerial
			prestigeAction:SetAttribute("ConfirmArmed", true)
			prestigeAction.Text = "CONFIRM: RESET NORMAL PROGRESS"
			task.delay(5, function()
				if armSerial == serial and prestigeAction.Parent then
					prestigeAction:SetAttribute("ConfirmArmed", false)
					prestigeAction.Text = "PRESTIGE FOR GEARS"
				end
			end)
		end)
	end
	local inventoryMenu = menus:FindFirstChild("InventoryMenu")
	local inventoryGrid = if inventoryMenu then inventoryMenu:FindFirstChild("ItemGrid") else nil
	local inventoryDetail = if inventoryMenu
		then inventoryMenu:FindFirstChild("DetailPanel")
		else nil
	if inventoryGrid and inventoryDetail then
		for _, magnetId in InventoryConfig.MagnetOrder do
			local card = inventoryGrid:FindFirstChild(`InventoryCard_{magnetId}`)
			if card and card:IsA("GuiButton") then
				card.Activated:Connect(function()
					selectedInventoryId = magnetId
					selectedInventoryKind = "Magnet"
					if currentState then
						renderState(currentState)
					end
				end)
			end
		end
		for _, itemId in InventoryConfig.ConsumableOrder do
			local card = inventoryGrid:FindFirstChild(`InventoryCard_{itemId}`)
			if card and card:IsA("GuiButton") then
				card.Activated:Connect(function()
					selectedInventoryId = itemId
					selectedInventoryKind = "Consumable"
					if currentState then
						renderState(currentState)
					end
				end)
			end
		end
		local detailAction = requireChild(inventoryDetail, "DetailAction") :: GuiButton
		detailAction.Activated:Connect(function()
			if not detailAction.Active then
				return
			end
			inventoryAction:FireServer(
				if selectedInventoryKind == "Magnet" then "EquipMagnet" else "UseConsumable",
				selectedInventoryId
			)
		end)
		local comingSoon = requireChild(inventoryMenu, "ComingSoon") :: GuiObject
		local function showInventoryTab(tab: string)
			comingSoon.Visible = tab == "Skins"
			inventoryGrid.Visible = tab ~= "Skins"
			inventoryDetail.Visible = tab ~= "Skins"
			for _, magnetId in InventoryConfig.MagnetOrder do
				local card = inventoryGrid:FindFirstChild(`InventoryCard_{magnetId}`)
				if card and card:IsA("GuiObject") then
					card.Visible = tab == "Magnets"
				end
			end
			for _, itemId in InventoryConfig.ConsumableOrder do
				local card = inventoryGrid:FindFirstChild(`InventoryCard_{itemId}`)
				if card and card:IsA("GuiObject") then
					card.Visible = tab == "Consumables"
				end
			end
			if tab == "Magnets" then
				selectedInventoryId = InventoryConfig.MagnetOrder[1]
				selectedInventoryKind = "Magnet"
			elseif tab == "Consumables" then
				selectedInventoryId = InventoryConfig.ConsumableOrder[1]
				selectedInventoryKind = "Consumable"
			end
			for _, name in { "Magnets", "Consumables", "Skins" } do
				local button = requireChild(inventoryMenu, `{name}Tab`) :: TextButton
				button.BackgroundColor3 = if name == tab
					then Color3.fromRGB(255, 188, 47)
					else Color3.fromRGB(93, 80, 145)
			end
			if currentState and tab ~= "Skins" then
				renderState(currentState)
			end
		end
		for _, name in { "Magnets", "Consumables", "Skins" } do
			local button = requireChild(inventoryMenu, `{name}Tab`) :: GuiButton
			button.Activated:Connect(function()
				showInventoryTab(name)
			end)
		end
		showInventoryTab("Magnets")
	end

	local collapseButton = navigation:FindFirstChild("CollapseButton")
	if collapseButton and collapseButton:IsA("GuiButton") then
		local collapsed = false
		local labels = {
			UpgradesButton = "UPGRADES",
			AreasButton = "AREAS",
			CollectionButton = "COLLECTION",
			SettingsButton = "SETTINGS",
			PrestigeButton = "PRESTIGE",
			InventoryButton = "INVENTORY",
			ExclusiveShopButton = "EXCLUSIVE",
		}
		collapseButton.Activated:Connect(function()
			collapsed = not collapsed
			for buttonName, text in labels do
				local button = requireChild(navigation, buttonName) :: TextButton
				button.Text = if collapsed then "" else text
				button.Size = UDim2.fromOffset(if collapsed then 52 else 116, 46)
				local divider = button:FindFirstChild("Divider")
				if divider and divider:IsA("GuiObject") then
					divider.Visible = not collapsed
				end
				local icon = button:FindFirstChild("Icon")
				if icon and icon:IsA("GuiObject") then
					icon.Position = if collapsed
						then UDim2.fromScale(0.5, 0.5)
						else UDim2.new(0, 10, 0.5, 0)
					icon.AnchorPoint = if collapsed
						then Vector2.new(0.5, 0.5)
						else Vector2.new(0, 0.5)
				end
			end
			collapseButton.Rotation = if collapsed then 180 else 0
		end)
	end

	local menuBindings = {
		UpgradesButton = "UpgradesMenu",
		AreasButton = "AreasMenu",
		CollectionButton = "CollectionMenu",
		SettingsButton = "SettingsMenu",
		PrestigeButton = "PrestigeMenu",
		InventoryButton = "InventoryMenu",
		ExclusiveShopButton = "ExclusiveShopMenu",
	}
	for _, child in menus:GetChildren() do
		if child:IsA("GuiObject") then
			child:GetPropertyChangedSignal("Visible"):Connect(refreshOverlayVisibility)
		end
	end
	local codeRewardPopup = safeArea:FindFirstChild("CodeRewardPopup")
	if codeRewardPopup and codeRewardPopup:IsA("GuiObject") then
		local close = requireChild(codeRewardPopup, "CloseButton") :: GuiButton
		close.Activated:Connect(function()
			codeRewardPopup.Visible = false
		end)
	end
	for buttonName, menuName in menuBindings do
		local button = requireChild(navigation, buttonName) :: GuiButton
		local menu = requireChild(menus, menuName) :: GuiObject
		button.Activated:Connect(function()
			for _, child in menus:GetChildren() do
				if child:IsA("GuiObject") then
					child.Visible = child == menu and not menu.Visible
				end
			end
			refreshOverlayVisibility()
		end)
		local closeButton = requireChild(menu, "CloseButton") :: GuiButton
		closeButton.Activated:Connect(function()
			menu.Visible = false
			refreshOverlayVisibility()
		end)
	end

	local requestInitialState =
		ReplicatedStorage.Remotes:WaitForChild("RequestInitialState") :: RemoteFunction
	local state: any = nil
	local deadline = os.clock() + 30
	repeat
		local succeeded, result = pcall(function()
			return requestInitialState:InvokeServer()
		end)
		if succeeded then
			state = result
		end
		if state == nil then
			task.wait(0.5)
		end
	until state ~= nil or os.clock() >= deadline

	if state == nil then
		local status = requireChild(loadingPanel, "Status") :: TextLabel
		status.Text = "Still waiting for a safe data session..."
		return
	end

	renderState(state)
	local stateChanged = ReplicatedStorage.Remotes:WaitForChild("StateChanged") :: RemoteEvent
	stateChanged.OnClientEvent:Connect(renderState)
	local notify = ReplicatedStorage.Remotes:WaitForChild("Notify") :: RemoteEvent
	local noticeSerial = 0
	notify.OnClientEvent:Connect(function(message: string)
		noticeSerial += 1
		local serial = noticeSerial
		notificationMessage.Text = message
		if not anyMenuVisible() then
			notification.Visible = true
			pulse(notification)
		end
		task.delay(2.5, function()
			if noticeSerial == serial then
				notification.Visible = false
			end
		end)
	end)
	loadingPanel.Visible = false
end

return table.freeze(UIController)
