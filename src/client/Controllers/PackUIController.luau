--!strict

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local GameMath = require(ReplicatedStorage.Shared.Utility.GameMath)
local InventoryConfig = require(ReplicatedStorage.Shared.Config.InventoryConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PrestigeConfig = require(ReplicatedStorage.Shared.Config.PrestigeConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)

local PackUIController = {}

local UPGRADE_ACCENTS = {
	MagnetStrength = Color3.fromRGB(255, 103, 68),
	MagnetRange = Color3.fromRGB(35, 214, 255),
	StorageCapacity = Color3.fromRGB(174, 105, 255),
	MovementSpeed = Color3.fromRGB(105, 232, 92),
	ScrapValue = Color3.fromRGB(255, 193, 46),
	CollectionSpeed = Color3.fromRGB(255, 91, 184),
	ScrapFlow = Color3.fromRGB(65, 139, 255),
	Rarity = Color3.fromRGB(126, 90, 255),
}

local function setAccent(label: TextLabel, accent: Color3)
	label.TextColor3 = accent
	local gradient = label:FindFirstChildWhichIsA("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(accent:Lerp(Color3.new(1, 1, 1), 0.35), accent)
	end
end

local function compact(value: number): string
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

local function durationText(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(whole / 60), whole % 60)
end

local PET_EFFECT_LABELS = {
	Cash = "CASH",
	MagnetStrength = "STRENGTH",
	MagnetRange = "RANGE",
	Storage = "STORAGE",
	MovementSpeed = "WALK SPEED",
	CollectionSpeed = "COLLECT SPEED",
	RespawnRate = "SPAWN RATE",
	RarityLuck = "RARITY LUCK",
}

local PET_EFFECT_ORDER = {
	"Cash",
	"MagnetStrength",
	"MagnetRange",
	"Storage",
	"MovementSpeed",
	"CollectionSpeed",
	"RespawnRate",
	"RarityLuck",
}

local function petEffectText(definition): string
	local effects = {}
	for _, effectId in PET_EFFECT_ORDER do
		local multiplier = definition.Effects[effectId] or 1
		if multiplier > 1.001 then
			table.insert(
				effects,
				`+{math.floor((multiplier - 1) * 100 + 0.5)}% {PET_EFFECT_LABELS[effectId]}`
			)
		end
	end
	local lines = {}
	for index = 1, #effects, 2 do
		local right = effects[index + 1]
		table.insert(lines, if right then `{effects[index]}  •  {right}` else effects[index])
	end
	if definition.Ability == "CopyStrongestPet" then
		table.insert(lines, `COPIES BEST PET x{definition.AbilityPower}`)
	elseif definition.Ability == "AmplifyPetBonuses" then
		table.insert(lines, `ALL PET BONUSES x{definition.AbilityPower}`)
	end
	return table.concat(lines, "\n")
end

local function descendant(parent: Instance, name: string): Instance
	local result = parent:FindFirstChild(name, true)
	assert(result, `{parent:GetFullName()}.{name} is missing`)
	return result
end

function PackUIController.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild("PackGameplayUI") :: ScreenGui
	local root = gui:WaitForChild("Background")
	local hud = root:WaitForChild("HUD")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local state: any = nil
	local updateSettings = remotes:WaitForChild("UpdateSettings") :: RemoteEvent
	local inventoryAction = remotes:WaitForChild("InventoryAction") :: RemoteEvent
	local shopAction = remotes:WaitForChild("ShopAction") :: RemoteEvent
	local petAction = remotes:WaitForChild("PetAction") :: RemoteEvent
	local monetizationPrompt = remotes:WaitForChild("MonetizationPrompt") :: RemoteEvent
	local requestTeleport = remotes:WaitForChild("RequestTeleport") :: RemoteEvent
	local redeemCode = remotes:WaitForChild("RedeemCode") :: RemoteEvent
	local codeResult = remotes:WaitForChild("CodeResult") :: RemoteEvent
	local infoPopup = gui:WaitForChild("InfoPopup") :: GuiObject
	local infoMessage = descendant(infoPopup, "Message") :: TextLabel
	local infoIcon = descendant(infoPopup, "Icon") :: TextLabel
	local infoAccent = descendant(infoPopup, "Accent") :: UIStroke
	local noticeSerial = 0
	local recentCodeMessage = ""
	local recentCodeMessageAt = 0

	local function showInfo(message: string, success: boolean?)
		noticeSerial += 1
		local serial = noticeSerial
		local token = `{os.clock()}:{serial}`
		infoPopup:SetAttribute("NoticeToken", token)
		local positive = success ~= false
		local accent = if positive
			then Color3.fromRGB(55, 213, 255)
			else Color3.fromRGB(255, 83, 101)
		infoMessage.Text = message
		infoIcon.Text = if positive then "i" else "!"
		infoIcon.TextColor3 = accent
		infoAccent.Color = accent
		infoPopup.Position = UDim2.new(0.5, 0, 0, 62)
		infoPopup.Visible = true
		TweenService:Create(
			infoPopup,
			TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0.5, 0, 0, 82) }
		):Play()
		task.delay(3.25, function()
			if serial == noticeSerial and infoPopup:GetAttribute("NoticeToken") == token then
				infoPopup.Visible = false
			end
		end)
	end

	local screens = {}
	local inventoryShopMode = false
	local renderInventoryMode: () -> () = function() end
	local renderPetsMode: () -> () = function() end
	for _, child in gui:GetChildren() do
		if child:IsA("Frame") and string.match(child.Name, "Screen$") then
			screens[child.Name] = child
			local close = child:FindFirstChild("CloseButton", true)
			if close and close:IsA("GuiButton") then
				close.Activated:Connect(function()
					child.Visible = false
				end)
			end
		end
	end
	for _, screen in screens do
		screen.Visible = false
	end

	local function open(screenName: string)
		for name, screen in screens do
			screen.Visible = name == screenName
		end
	end

	for _, button in gui:GetDescendants() do
		if button:IsA("GuiButton") then
			local screenName = button:GetAttribute("PackScreen")
			if typeof(screenName) == "string" and screens[screenName] then
				button.Activated:Connect(function()
					if screenName == "InventoryScreen" then
						inventoryShopMode = false
						renderInventoryMode()
					end
					if screenName == "PetsScreen" then
						renderPetsMode()
					end
					open(screenName)
				end)
			end
		end
	end
	local animatedShopButton = hud:FindFirstChild("ShopButton", true)
	if animatedShopButton and animatedShopButton:IsA("ImageButton") then
		local attentionScale = animatedShopButton:FindFirstChild("AttentionScale") :: UIScale?
		local sparkles = {}
		for _, sparkleName in { "Sparkle1", "Sparkle2", "Sparkle3" } do
			local sparkle = animatedShopButton:FindFirstChild(sparkleName)
			if sparkle and sparkle:IsA("TextLabel") then
				table.insert(sparkles, sparkle)
			end
		end
		task.spawn(function()
			while animatedShopButton.Parent do
				task.wait(math.random(55, 90) / 10)
				if state and state.Settings.ScreenEffectsEnabled == false then
					continue
				end
				for index, sparkle in sparkles do
					task.delay((index - 1) * 0.09, function()
						if sparkle.Parent == nil then
							return
						end
						local baseSize = sparkle.Size
						sparkle.Rotation = -20
						TweenService:Create(
							sparkle,
							TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
							{
								TextTransparency = 0,
								TextStrokeTransparency = 0.3,
								Rotation = 18,
								Size = UDim2.new(
									baseSize.X.Scale,
									math.floor(baseSize.X.Offset * 1.3),
									baseSize.Y.Scale,
									math.floor(baseSize.Y.Offset * 1.3)
								),
							}
						):Play()
						task.wait(0.28)
						TweenService:Create(
							sparkle,
							TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
							{
								TextTransparency = 1,
								TextStrokeTransparency = 1,
								Rotation = 45,
								Size = baseSize,
							}
						):Play()
					end)
				end
				if attentionScale then
					TweenService:Create(
						attentionScale,
						TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ Scale = 1.025 }
					):Play()
				end
				for _, angle in { -2, 2, -1.2, 1.2, 0 } do
					local shake = TweenService:Create(
						animatedShopButton,
						TweenInfo.new(0.065, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{ Rotation = angle }
					)
					shake:Play()
					shake.Completed:Wait()
				end
				if attentionScale then
					TweenService:Create(
						attentionScale,
						TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
						{ Scale = 1 }
					):Play()
				end
			end
		end)
	end
	local teleportButtons = root:FindFirstChild("TeleportButtons")
	if teleportButtons then
		for _, destinationId in { "Leaderboards", "Shop", "MyPlot" } do
			local button = teleportButtons:FindFirstChild(destinationId)
			if button and button:IsA("GuiButton") then
				button.Activated:Connect(function()
					requestTeleport:FireServer(destinationId)
				end)
			end
		end
	end

	local moneyValue = descendant(hud, "MoneyValue") :: TextLabel
	local gearsValue = descendant(descendant(hud, "GearsStat"), "Value") :: TextLabel
	local prestigeValue = descendant(descendant(hud, "PrestigeStat"), "Value") :: TextBox
	local scrapStorage = descendant(hud, "ScrapStorage") :: GuiObject
	local storageValue = scrapStorage:FindFirstChildWhichIsA("TextLabel", true)
	assert(storageValue, "ScrapStorage requires a TextLabel")
	local storageFill = descendant(scrapStorage, "progress") :: GuiObject
	local upgradeScreen = gui:WaitForChild("UpgradesScreen")
	local prestigeScreen = gui:WaitForChild("PrestigeScreen")
	local prestigeWindow = descendant(prestigeScreen, "Window")
	local currentPrestigeCard = descendant(prestigeWindow, "Rebirth 20")
	local nextPrestigeCard = descendant(prestigeWindow, "Rebirth 21")
	local currentPrestigeLabel = descendant(currentPrestigeCard, "Rebirth 20") :: TextLabel
	local nextPrestigeLabel = descendant(nextPrestigeCard, "Rebirth 21") :: TextLabel
	local currentMultiplierLabel = descendant(currentPrestigeCard, "11x Money") :: TextLabel
	local nextMultiplierLabel = descendant(nextPrestigeCard, "11.25x Money") :: TextLabel
	local prestigeProgressPanel = descendant(prestigeWindow, "Progress")
	local prestigeDescription =
		descendant(prestigeProgressPanel, "Rebirth resets your speed level") :: TextLabel
	local prestigeProgressBar = descendant(prestigeProgressPanel, "Progress Bar")
	local prestigeProgressFill = descendant(prestigeProgressBar, "progress") :: GuiObject
	local prestigeProgressText = descendant(prestigeProgressBar, "Speed 248/240") :: TextLabel
	local prestigeButton: ImageButton? = nil
	local skipPrestigeButton: ImageButton? = nil
	for _, child in prestigeWindow:GetChildren() do
		if child:IsA("ImageButton") and child.Name == "Rebirth" then
			prestigeButton = child
		elseif child:IsA("ImageButton") and child.Name == "Skip Rebirth" then
			skipPrestigeButton = child
		end
	end
	assert(prestigeButton, "PrestigeScreen.Window Rebirth button missing")
	local prestigeButtonText = descendant(prestigeButton, "Rebirth") :: TextLabel
	local skipPrestigePrice = if skipPrestigeButton
		then descendant(skipPrestigeButton, "Price") :: TextLabel
		else nil
	local activeBoostHud = gui:WaitForChild("ActiveBoostHUD")
	local settingsScreen = gui:WaitForChild("SettingsScreen")
	local settingsContent = descendant(settingsScreen, "content")
	local codeEntry = descendant(settingsContent, "CODES")
	local codeBox = descendant(codeEntry, "CodeBox") :: TextBox
	local redeemButton = descendant(codeEntry, "RedeemButton") :: GuiButton
	local codeStatus = codeEntry:FindFirstChild("CodeStatus") :: TextLabel?
	local function setCodeStatus(message: string, color: Color3)
		if codeStatus then
			codeStatus.Text = message
			codeStatus.TextColor3 = color
		end
	end

	local inventoryScreen = gui:WaitForChild("InventoryScreen")
	local inventoryWindow = descendant(inventoryScreen, "Window")
	local inventoryTitle = descendant(inventoryWindow, "Index") :: TextLabel
	local inventoryContent = descendant(inventoryWindow, "content")
	local inventoryTabs = descendant(inventoryWindow, "Tabs")
	local itemPopover = descendant(inventoryWindow, "ItemPopover") :: GuiObject
	local popoverClose = descendant(itemPopover, "PopoverClose") :: GuiButton
	local popoverAction = descendant(itemPopover, "ActionButton") :: GuiButton
	local selectedInventoryCategory = "Magnets"
	local selectedInventoryItem: string? = nil
	local inventoryCards = {}

	renderInventoryMode = function()
		inventoryTitle.Text = if inventoryShopMode then "MAGNET SHOP" else "INVENTORY"
		inventoryTabs.Visible = not inventoryShopMode
		for _, card in inventoryContent:GetChildren() do
			local price = card:FindFirstChild("Price")
			if price and price:IsA("GuiObject") then
				price.Visible = inventoryShopMode
			end
		end
	end

	local function cardAccent(card: Instance): Color3
		return Color3.new(
			card:GetAttribute("AccentR") or 1,
			card:GetAttribute("AccentG") or 1,
			card:GetAttribute("AccentB") or 1
		)
	end

	local function setInventoryCategory(category: string)
		selectedInventoryCategory = category
		selectedInventoryItem = nil
		itemPopover.Visible = false
		for _, tabName in { "MagnetsTab", "PotionsTab", "SkinsTab" } do
			local tab = inventoryTabs:FindFirstChild(tabName)
			if tab and tab:IsA("ImageButton") then
				tab.Image = if tab:GetAttribute("Category") == category
					then tab:GetAttribute("ActiveImage")
					else tab:GetAttribute("InactiveImage")
			end
		end
		for _, card in inventoryCards do
			card.Visible = card:GetAttribute("Category") == category
		end
	end

	local function renderInventoryPopover()
		if state == nil or selectedInventoryItem == nil then
			itemPopover.Visible = false
			return
		end
		local card = inventoryCards[selectedInventoryItem]
		if card == nil then
			itemPopover.Visible = false
			return
		end
		local accent = cardAccent(card)
		local nameLabel = descendant(itemPopover, "ItemName") :: TextLabel
		local rarityLabel = descendant(itemPopover, "Rarity") :: TextLabel
		local descriptionLabel = descendant(itemPopover, "Description") :: TextLabel
		local statsLabel = descendant(itemPopover, "Stats") :: TextLabel
		local icon = descendant(itemPopover, "Icon") :: ImageLabel
		local glyph = descendant(itemPopover, "Glyph") :: TextLabel
		local sourceIcon = descendant(card, "Icon") :: ImageLabel
		local sourceGlyph = descendant(card, "Glyph") :: TextLabel
		local selectedStroke = descendant(itemPopover, "AccentStroke") :: UIStroke
		nameLabel.Text = (descendant(card, "DisplayName") :: TextLabel).Text
		rarityLabel.Text = (descendant(card, "Rarity") :: TextLabel).Text
		rarityLabel.TextColor3 = accent
		selectedStroke.Color = accent
		icon.Image = sourceIcon.Image
		icon.Visible = sourceIcon.Image ~= ""
		glyph.Text = sourceGlyph.Text
		glyph.TextColor3 = accent
		glyph.Visible = sourceIcon.Image == ""
		local magnet = InventoryConfig.Magnets[selectedInventoryItem]
		local potion = InventoryConfig.Consumables[selectedInventoryItem]
		if magnet then
			local owned = state.OwnedMagnets[selectedInventoryItem] == true
			local equipped = state.EquippedMagnet == selectedInventoryItem
			descriptionLabel.Text = magnet.Description
			local priceLine = ""
			if inventoryShopMode and not owned then
				priceLine = if magnet.Premium
					then `\nPRICE  {Format.robuxSymbol(
						MonetizationConfig.Passes.QuantumMagnet.DisplayPrice
					)}`
					else `\nPRICE  ${compact(magnet.ShopPrice or 0)}`
			end
			statsLabel.Text =
				`STRENGTH  {magnet.BaseStrength}\nRANGE  {magnet.BaseRange}{priceLine}`
			if not owned then
				if inventoryShopMode and (magnet.Premium or magnet.ShopPrice) then
					popoverAction.Text = if magnet.Premium
						then `BUY  {Format.robuxSymbol(
							MonetizationConfig.Passes.QuantumMagnet.DisplayPrice
						)}`
						else `BUY  ${compact(magnet.ShopPrice)}`
					popoverAction.Active = true
					popoverAction.Interactable = true
				else
					popoverAction.Text = "NOT OWNED"
					popoverAction.Active = false
					popoverAction.Interactable = false
				end
			elseif equipped and selectedInventoryItem == "MagnetBasic" then
				popoverAction.Text = "EQUIPPED"
				popoverAction.Active = false
				popoverAction.Interactable = false
			elseif equipped then
				popoverAction.Text = "UNEQUIP"
				popoverAction.Active = true
				popoverAction.Interactable = true
			else
				popoverAction.Text = "EQUIP"
				popoverAction.Active = true
				popoverAction.Interactable = true
			end
		elseif potion then
			local amount = state.Inventory[selectedInventoryItem] or 0
			descriptionLabel.Text = potion.Description
			statsLabel.Text =
				`OWNED  x{amount}\nDURATION  {math.floor(potion.DurationSeconds / 60)} MIN`
			popoverAction.Text = if amount > 0 then "USE" else "EMPTY"
			popoverAction.Active = amount > 0
			popoverAction.Interactable = amount > 0
		else
			descriptionLabel.Text = "More inventory customization is coming soon."
			statsLabel.Text = "COMING SOON"
			popoverAction.Text = "COMING SOON"
			popoverAction.Active = false
			popoverAction.Interactable = false
		end
		popoverAction.BackgroundColor3 = if popoverAction.Active
			then if inventoryShopMode then Color3.fromRGB(47, 166, 102) else accent
			else Color3.fromRGB(78, 84, 98)
		local actionStroke = popoverAction:FindFirstChildOfClass("UIStroke")
		if actionStroke then
			actionStroke.Transparency = if inventoryShopMode then 1 else 0.35
		end
		itemPopover.Visible = true
	end

	local function renderInventory()
		if state == nil then
			return
		end
		for itemId, card in inventoryCards do
			local category = card:GetAttribute("Category")
			local selectedStroke = card:FindFirstChild("SelectedStroke")
			local equippedTick = descendant(card, "EquippedTick") :: ImageLabel
			local countLabel = descendant(card, "Count") :: TextLabel
			if category == "Magnets" then
				local owned = state.OwnedMagnets[itemId] == true
				local equipped = state.EquippedMagnet == itemId
				local price = card:FindFirstChild("Price") :: TextLabel?
				card.ImageTransparency = if owned then 0 else 0.38
				equippedTick.Visible = equipped
				countLabel.Visible = false
				if price then
					local magnet = InventoryConfig.Magnets[itemId]
					price.Visible = inventoryShopMode
					price.Text = if owned
						then "OWNED"
						elseif magnet.Premium then `{Format.robuxSymbol(
							MonetizationConfig.Passes.QuantumMagnet.DisplayPrice
						)}`
						elseif magnet.ShopPrice then `$ {compact(magnet.ShopPrice)}`
						else "FREE"
					price.BackgroundColor3 = if owned
						then Color3.fromRGB(37, 129, 83)
						else Color3.fromRGB(25, 31, 45)
				end
				if selectedStroke and selectedStroke:IsA("UIStroke") then
					selectedStroke.Transparency = if equipped then 0 else 1
				end
			elseif category == "Potions" then
				local amount = state.Inventory[itemId] or 0
				card.ImageTransparency = if amount > 0 then 0 else 0.28
				equippedTick.Visible = false
				countLabel.Visible = true
				countLabel.Text = `x{amount}`
				if selectedStroke and selectedStroke:IsA("UIStroke") then
					selectedStroke.Transparency = 1
				end
			else
				card.ImageTransparency = 0
				equippedTick.Visible = false
				countLabel.Visible = false
			end
			card.Visible = category == selectedInventoryCategory
		end
		renderInventoryPopover()
	end

	for _, child in inventoryContent:GetChildren() do
		if child:IsA("ImageLabel") and child:GetAttribute("ItemId") then
			local itemId = child:GetAttribute("ItemId")
			if typeof(itemId) == "string" then
				inventoryCards[itemId] = child
				local hitArea = descendant(child, "HitArea") :: GuiButton
				hitArea.Activated:Connect(function()
					selectedInventoryItem = itemId
					renderInventoryPopover()
				end)
			end
		end
	end
	for _, tabName in { "MagnetsTab", "PotionsTab", "SkinsTab" } do
		local tab = inventoryTabs:FindFirstChild(tabName)
		if tab and tab:IsA("GuiButton") then
			tab.Activated:Connect(function()
				setInventoryCategory(tab:GetAttribute("Category"))
			end)
		end
	end

	local magnetShopScreen = gui:WaitForChild("MagnetShopScreen")
	local magnetShopWindow = descendant(magnetShopScreen, "Window")
	local magnetShopContent = descendant(magnetShopWindow, "content")
	local magnetShopPopover = descendant(magnetShopWindow, "ItemPopover") :: GuiObject
	local magnetShopAction = descendant(magnetShopPopover, "ActionButton") :: GuiButton
	local magnetShopClose = descendant(magnetShopPopover, "PopoverClose") :: GuiButton
	local selectedShopMagnet: string? = "AdvancedMagnet"
	local magnetShopCards = {}

	local function renderMagnetShopPopover()
		if state == nil or selectedShopMagnet == nil then
			magnetShopPopover.Visible = false
			return
		end
		local magnet = InventoryConfig.Magnets[selectedShopMagnet]
		local card = magnetShopCards[selectedShopMagnet]
		if magnet == nil or card == nil then
			magnetShopPopover.Visible = false
			return
		end
		local accent = cardAccent(card)
		local owned = state.OwnedMagnets[selectedShopMagnet] == true
		local equipped = state.EquippedMagnet == selectedShopMagnet
		local icon = descendant(magnetShopPopover, "Icon") :: ImageLabel
		local glyph = descendant(magnetShopPopover, "Glyph") :: TextLabel
		local sourceIcon = descendant(card, "Icon") :: ImageLabel
		local sourceGlyph = descendant(card, "Glyph") :: TextLabel
		local nameLabel = descendant(magnetShopPopover, "ItemName") :: TextLabel
		local rarityLabel = descendant(magnetShopPopover, "Rarity") :: TextLabel
		local descriptionLabel = descendant(magnetShopPopover, "Description") :: TextLabel
		local statsLabel = descendant(magnetShopPopover, "Stats") :: TextLabel
		nameLabel.Text = magnet.DisplayName:upper()
		rarityLabel.Text = (descendant(card, "Rarity") :: TextLabel).Text
		descriptionLabel.Text = magnet.Description
		local priceText = if owned
			then "OWNED"
			elseif magnet.Premium then `{Format.robuxSymbol(
				MonetizationConfig.Passes.QuantumMagnet.DisplayPrice
			)}`
			elseif magnet.ShopPrice then `$ {compact(magnet.ShopPrice)}`
			else "FREE"
		statsLabel.Text = `STRENGTH  {magnet.BaseStrength}\nRANGE  {magnet.BaseRange}`
		icon.Image = sourceIcon.Image
		icon.Visible = sourceIcon.Image ~= ""
		glyph.Text = sourceGlyph.Text
		glyph.TextColor3 = accent
		glyph.Visible = sourceIcon.Image == ""
		if not owned then
			magnetShopAction.Text = `BUY  {priceText}`
			magnetShopAction.Active = true
			magnetShopAction.Interactable = true
		elseif equipped then
			magnetShopAction.Text = "EQUIPPED"
			magnetShopAction.Active = false
			magnetShopAction.Interactable = false
		else
			magnetShopAction.Text = "EQUIP"
			magnetShopAction.Active = true
			magnetShopAction.Interactable = true
		end
		magnetShopAction.BackgroundColor3 = if magnetShopAction.Active
			then Color3.fromRGB(47, 166, 102)
			else Color3.fromRGB(78, 84, 98)
		local actionStroke = magnetShopAction:FindFirstChildOfClass("UIStroke")
		if actionStroke then
			actionStroke.Transparency = 1
		end
		magnetShopPopover.Visible = true
	end

	local function renderMagnetShop()
		if state == nil then
			return
		end
		for itemId, card in magnetShopCards do
			local magnet = InventoryConfig.Magnets[itemId]
			local owned = state.OwnedMagnets[itemId] == true
			local equipped = state.EquippedMagnet == itemId
			local price = card:FindFirstChild("Price") :: TextLabel?
			card.ImageTransparency = if owned then 0 else 0.16
			local equippedTick = descendant(card, "EquippedTick") :: ImageLabel
			equippedTick.Visible = equipped
			if price then
				price.Visible = true
				price.Text = if owned
					then "OWNED"
					elseif magnet.Premium then `{Format.robuxSymbol(
						MonetizationConfig.Passes.QuantumMagnet.DisplayPrice
					)}`
					elseif magnet.ShopPrice then `$ {compact(magnet.ShopPrice)}`
					else "FREE"
				price.BackgroundColor3 = if owned
					then Color3.fromRGB(37, 129, 83)
					else Color3.fromRGB(25, 31, 45)
			end
		end
		renderMagnetShopPopover()
	end

	for _, card in magnetShopContent:GetChildren() do
		local itemId = card:GetAttribute("ItemId")
		if card:IsA("ImageLabel") and typeof(itemId) == "string" then
			magnetShopCards[itemId] = card
			local hitArea = descendant(card, "HitArea") :: GuiButton
			hitArea.Activated:Connect(function()
				selectedShopMagnet = itemId
				renderMagnetShopPopover()
			end)
		end
	end
	magnetShopClose.Activated:Connect(function()
		selectedShopMagnet = nil
		magnetShopPopover.Visible = false
	end)
	magnetShopAction.Activated:Connect(function()
		if state == nil or selectedShopMagnet == nil or not magnetShopAction.Active then
			return
		end
		local magnet = InventoryConfig.Magnets[selectedShopMagnet]
		local owned = state.OwnedMagnets[selectedShopMagnet] == true
		if owned then
			inventoryAction:FireServer("EquipMagnet", selectedShopMagnet)
		elseif magnet.Premium then
			local pass = MonetizationConfig.Passes.QuantumMagnet
			if pass.MarketplaceId > 0 then
				MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.MarketplaceId)
			elseif RunService:IsStudio() then
				monetizationPrompt:FireServer("Pass", "QuantumMagnet")
			else
				showInfo("Quantum Magnet needs a Marketplace ID.", false)
			end
		else
			shopAction:FireServer("BuyMagnet", selectedShopMagnet)
		end
	end)

	local openMagnetShop = remotes:WaitForChild("OpenMagnetShop") :: RemoteEvent
	local openAreaShop = remotes:WaitForChild("OpenAreaShop") :: RemoteEvent
	local openExclusiveShop = remotes:WaitForChild("OpenExclusiveShop") :: RemoteEvent
	openMagnetShop.OnClientEvent:Connect(function()
		selectedShopMagnet = "AdvancedMagnet"
		renderMagnetShop()
		open("MagnetShopScreen")
	end)
	openAreaShop.OnClientEvent:Connect(function()
		open("AreasScreen")
	end)
	openExclusiveShop.OnClientEvent:Connect(function()
		open("ShopScreen")
	end)
	popoverClose.Activated:Connect(function()
		selectedInventoryItem = nil
		itemPopover.Visible = false
	end)
	popoverAction.Activated:Connect(function()
		if state == nil or selectedInventoryItem == nil or not popoverAction.Active then
			return
		end
		if InventoryConfig.Magnets[selectedInventoryItem] then
			local magnet = InventoryConfig.Magnets[selectedInventoryItem]
			local owned = state.OwnedMagnets[selectedInventoryItem] == true
			if inventoryShopMode and not owned then
				if magnet.Premium then
					local pass = MonetizationConfig.Passes.QuantumMagnet
					if pass.MarketplaceId > 0 then
						MarketplaceService:PromptGamePassPurchase(
							Players.LocalPlayer,
							pass.MarketplaceId
						)
					elseif RunService:IsStudio() then
						monetizationPrompt:FireServer("Pass", "QuantumMagnet")
					else
						showInfo("Quantum Magnet needs a Marketplace ID.", false)
					end
				else
					shopAction:FireServer("BuyMagnet", selectedInventoryItem)
				end
			else
				inventoryAction:FireServer(
					if state.EquippedMagnet == selectedInventoryItem
						then "UnequipMagnet"
						else "EquipMagnet",
					selectedInventoryItem
				)
			end
		elseif InventoryConfig.Consumables[selectedInventoryItem] then
			inventoryAction:FireServer("UseConsumable", selectedInventoryItem)
		end
	end)
	setInventoryCategory("Magnets")
	renderInventoryMode()

	local toggleRows = {}
	for _, rowName in { "SOUNDEFFECTS", "SCREENEFFECTS", "MUSIC" } do
		local row = settingsContent:FindFirstChild(rowName)
		if row then
			local hitArea = descendant(row, "ToggleHitArea") :: GuiButton
			local settingId = hitArea:GetAttribute("SettingId")
			if typeof(settingId) == "string" then
				toggleRows[settingId] = row
				hitArea.Activated:Connect(function()
					if state then
						local nextValue = state.Settings[settingId] ~= true
						updateSettings:FireServer(settingId, nextValue)
						if settingId == "ScreenEffectsEnabled" then
							updateSettings:FireServer("ParticlesEnabled", nextValue)
						end
					end
				end)
			end
		end
	end

	local volumeRows = {}
	for _, rowName in { "SOUNDVOLUME", "MUSICVOLUME" } do
		local row = settingsContent:FindFirstChild(rowName)
		if row then
			local track = descendant(row, "Track") :: GuiObject
			local hitArea = descendant(track, "SliderHitArea") :: GuiButton
			local settingId = track:GetAttribute("SettingId")
			if typeof(settingId) == "string" then
				volumeRows[settingId] = row
				local dragging = false
				local pendingValue = 0
				local function inputX(input): number
					return if input.UserInputType == Enum.UserInputType.Touch
						then input.Position.X
						else UserInputService:GetMouseLocation().X
				end
				local function preview(screenX: number)
					pendingValue = math.clamp(
						(screenX - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1),
						0,
						1
					)
					local fill = descendant(track, "Fill") :: GuiObject
					local knob = descendant(track, "Knob") :: GuiObject
					local valueLabel = descendant(row, "Value") :: TextLabel
					fill.Size = UDim2.fromScale(pendingValue, 1)
					knob.Position = UDim2.fromScale(pendingValue, 0.5)
					valueLabel.Text = `{math.floor(pendingValue * 100 + 0.5)}%`
				end
				hitArea.InputBegan:Connect(function(input)
					if
						input.UserInputType == Enum.UserInputType.MouseButton1
						or input.UserInputType == Enum.UserInputType.Touch
					then
						dragging = true
						preview(inputX(input))
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
						preview(inputX(input))
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
						updateSettings:FireServer(settingId, pendingValue)
					end
				end)
			end
		end
	end

	local petsScreen = gui:WaitForChild("PetsScreen") :: GuiObject
	local petsWindow = petsScreen:WaitForChild("Window")
	local petGrid = descendant(petsWindow, "PetGrid") :: ScrollingFrame
	local petTemplate = petGrid:WaitForChild("PetCardTemplate") :: ImageButton
	local petDetail = descendant(petsWindow, "PetDetail") :: GuiObject
	local petEquipButton = descendant(petDetail, "EquipButton") :: TextButton
	local petDeleteButton = descendant(petDetail, "DeleteButton") :: TextButton
	local petPopoverClose = descendant(petDetail, "PopoverClose") :: GuiButton
	local petSlotButton = descendant(petsWindow, "SlotUpgradeButton") :: TextButton
	local deleteConfirm = descendant(petsWindow, "DeleteConfirm") :: GuiObject
	local confirmDeleteButton = descendant(deleteConfirm, "ConfirmButton") :: TextButton
	local cancelDeleteButton = descendant(deleteConfirm, "CancelButton") :: TextButton
	local selectedPetId: string? = nil
	local petOrder = {}
	for _, eggId in PetConfig.EggOrder do
		for _, petId in PetConfig.Eggs[eggId].PetIds do
			table.insert(petOrder, petId)
		end
	end
	for _, petId in PetConfig.PremiumOrder do
		table.insert(petOrder, petId)
	end

	local function equippedPetCopies(petId: string): number
		local count = 0
		if state then
			for _, equippedId in state.EquippedPets do
				if equippedId == petId then
					count += 1
				end
			end
		end
		return count
	end

	local function renderPetDetail()
		local petId = selectedPetId
		local definition = if petId then PetConfig.Pets[petId] else nil
		local owned = if definition and state and petId then state.OwnedPets[petId] or 0 else 0
		local equippedCopies = if selectedPetId then equippedPetCopies(selectedPetId) else 0
		local icon = descendant(petDetail, "Icon") :: ImageLabel
		local fallback = descendant(petDetail, "FallbackIcon") :: TextLabel
		local detailName = descendant(petDetail, "PetName") :: TextLabel
		local detailRarity = descendant(petDetail, "Rarity") :: TextLabel
		local detailBonus = descendant(petDetail, "Bonus") :: TextLabel
		local detailOwned = descendant(petDetail, "Owned") :: TextLabel
		local detailDescription = descendant(petDetail, "Description") :: TextLabel
		if definition == nil then
			detailName.Text = "SELECT A PET"
			detailRarity.Text = "-"
			detailBonus.Text = "OWN A PET TO SEE ITS EFFECTS"
			detailOwned.Text = "OWNED 0  /  EQUIPPED 0"
			detailDescription.Text = "CLICK A PET TO VIEW ITS DETAILS"
			icon.Image = ""
			fallback.Text = "?"
			petEquipButton.Text = "SELECT A PET"
			petEquipButton.Active = false
			petDeleteButton.Active = false
			return
		end
		detailName.Text = string.upper(definition.DisplayName)
		local rarityLabel = descendant(petDetail, "Rarity") :: TextLabel
		rarityLabel.Text = string.upper(definition.Rarity)
		rarityLabel.TextColor3 = definition.FallbackColor
		detailBonus.Text = petEffectText(definition)
		detailOwned.Text = `OWNED {owned}  /  EQUIPPED {equippedCopies}`
		detailDescription.Text = definition.Description
		icon.Image = definition.IconAssetId
		fallback.Text = string.sub(definition.DisplayName, 1, 1)
		fallback.Visible = definition.IconAssetId == ""
		local canEquip = state
			and owned > equippedCopies
			and #state.EquippedPets < state.MaximumEquippedPets
		petEquipButton.Text = if canEquip
			then "EQUIP COPY"
			elseif equippedCopies > 0 then "UNEQUIP ONE"
			elseif owned <= 0 then "NOT OWNED"
			else "EQUIP SLOTS FULL"
		petEquipButton.Active = canEquip == true or equippedCopies > 0
		petEquipButton.Interactable = petEquipButton.Active
		petEquipButton.BackgroundColor3 = if petEquipButton.Active
			then Color3.fromRGB(44, 196, 112)
			else Color3.fromRGB(85, 91, 111)
		petDeleteButton.Active = owned > 0
		petDeleteButton.Interactable = owned > 0
		petDeleteButton.BackgroundColor3 = if owned > 0
			then Color3.fromRGB(220, 62, 83)
			else Color3.fromRGB(85, 91, 111)
	end

	local function renderPets()
		if state == nil then
			return
		end
		for _, child in petGrid:GetChildren() do
			if
				child:GetAttribute("PetPreview") == true or string.match(child.Name, "^PetCard_")
			then
				child:Destroy()
			end
		end
		local totalOwned = 0
		for _, amount in state.OwnedPets do
			totalOwned += amount
		end
		local capacityLabel = descendant(petsWindow, "CapacityLabel") :: TextLabel
		local equippedLabel = descendant(petsWindow, "EquippedLabel") :: TextLabel
		capacityLabel.Text =
			`STORAGE  {totalOwned} / {state.PetStorageCapacity or PetConfig.BaseStorageCapacity}`
		equippedLabel.Text = `EQUIPPED  {#state.EquippedPets} / {state.MaximumEquippedPets}`
		if selectedPetId == nil then
			for _, petId in petOrder do
				if (state.OwnedPets[petId] or 0) > 0 then
					selectedPetId = petId
					break
				end
			end
		end
		for order, petId in petOrder do
			local definition = PetConfig.Pets[petId]
			local amount = state.OwnedPets[petId] or 0
			if amount <= 0 then
				continue
			end
			local equippedCopies = equippedPetCopies(petId)
			local card = petTemplate:Clone()
			card.Name = `PetCard_{petId}`
			card.Visible = true
			card.LayoutOrder = order
			card:SetAttribute("PetId", petId)
			local cardName = descendant(card, "PetName") :: TextLabel
			cardName.Text = string.upper(definition.DisplayName)
			local rarity = descendant(card, "Rarity") :: TextLabel
			rarity.Text = string.upper(definition.Rarity)
			rarity.TextColor3 = definition.FallbackColor
			local amountLabel = descendant(card, "Amount") :: TextLabel
			local rarityAccent = descendant(card, "RarityAccent") :: GuiObject
			local iconBackground = descendant(card, "IconBackground") :: GuiObject
			amountLabel.Text = `x{amount}`
			rarityAccent.BackgroundColor3 = definition.FallbackColor
			iconBackground.BackgroundColor3 =
				definition.FallbackColor:Lerp(Color3.fromRGB(25, 29, 47), 0.6)
			local icon = descendant(card, "Icon") :: ImageLabel
			icon.Image = definition.IconAssetId
			local fallback = descendant(card, "FallbackIcon") :: TextLabel
			fallback.Text = string.sub(definition.DisplayName, 1, 1)
			fallback.Visible = definition.IconAssetId == ""
			local badge = descendant(card, "EquippedBadge") :: TextLabel
			badge.Visible = equippedCopies > 0
			badge.Text = if equippedCopies > 1 then `EQUIPPED x{equippedCopies}` else "EQUIPPED"
			local lockedOverlay = descendant(card, "LockedOverlay") :: GuiObject
			lockedOverlay.Visible = false
			local selection = descendant(card, "SelectionStroke") :: UIStroke
			selection.Color = if selectedPetId == petId
				then Color3.fromRGB(255, 235, 91)
				else definition.FallbackColor
			selection.Thickness = if selectedPetId == petId then 4 else 2
			card.Activated:Connect(function()
				selectedPetId = petId
				petDetail.Visible = true
				renderPets()
			end)
			card.Parent = petGrid
		end
		local nextSlot = state.PetSlotUpgradeLevel + 1
		if nextSlot <= PetConfig.MaximumSlotUpgradeLevel then
			local price = PetConfig.SlotUpgradeCosts[nextSlot]
			petSlotButton.Text = `+1 EQUIP SLOT   $ {compact(price)}`
			petSlotButton.Active = state.Money >= price
			petSlotButton.Interactable = true
		else
			petSlotButton.Text = "CASH EQUIP SLOTS MAXED"
			petSlotButton.Active = false
			petSlotButton.Interactable = false
		end
		renderPetDetail()
	end
	renderPetsMode = renderPets

	petEquipButton.Activated:Connect(function()
		if state == nil or selectedPetId == nil or not petEquipButton.Active then
			return
		end
		local owned = state.OwnedPets[selectedPetId] or 0
		local equippedCopies = equippedPetCopies(selectedPetId)
		local canEquip = owned > equippedCopies and #state.EquippedPets < state.MaximumEquippedPets
		petAction:FireServer(if canEquip then "EquipPet" else "UnequipPet", selectedPetId)
	end)
	petDeleteButton.Activated:Connect(function()
		if selectedPetId and state and (state.OwnedPets[selectedPetId] or 0) > 0 then
			local definition = PetConfig.Pets[selectedPetId]
			local message = descendant(deleteConfirm, "Message") :: TextLabel
			message.Text = `Delete one {definition.DisplayName}? This cannot be undone.`
			deleteConfirm.Visible = true
		end
	end)
	petPopoverClose.Activated:Connect(function()
		petDetail.Visible = false
	end)
	confirmDeleteButton.Activated:Connect(function()
		deleteConfirm.Visible = false
		if selectedPetId then
			petAction:FireServer("DeletePet", selectedPetId)
		end
	end)
	cancelDeleteButton.Activated:Connect(function()
		deleteConfirm.Visible = false
	end)
	petSlotButton.Activated:Connect(function()
		if petSlotButton.Active then
			petAction:FireServer("BuyPetSlot", "slot")
		end
	end)

	local function updateBoostHud()
		if state == nil then
			return
		end
		local now = workspace:GetServerTimeNow()
		local activeCount = 0
		for _, itemId in InventoryConfig.ConsumableOrder do
			local definition = InventoryConfig.Consumables[itemId]
			local row = activeBoostHud:FindFirstChild(`Boost_{itemId}`)
			if row and row:IsA("GuiObject") then
				local seconds = (state.ActiveBoosts[`{definition.BoostId}EndsAt`] or 0) - now
				row.Visible = seconds > 0
				if seconds > 0 then
					activeCount += 1
					(descendant(row, "Time") :: TextLabel).Text = durationText(seconds)
				end
			end
		end
		activeBoostHud.Visible = activeCount > 0
	end

	local function render(nextState)
		state = nextState
		moneyValue.Text = `$ {compact(state.Money)}`
		gearsValue.Text = compact(state.Gears)
		prestigeValue.Text = compact(state.PrestigeCount)
		local prestigeRequirement = GameMath.prestigeRequirement(
			PrestigeConfig.BaseMoneyRequirement,
			PrestigeConfig.RequirementGrowth,
			state.PrestigeCount,
			Environment.MaximumMoney
		)
		local projectedGearReward = GameMath.scaledPrestigeGearReward(
			state.Money,
			prestigeRequirement,
			state.PrestigeCount,
			PrestigeConfig.MaximumGearsPerPrestige
		)
		--- The rebirth bonus, not a gear curve. See `GameMath.prestigeValueMultiplier`.
		local currentMultiplier =
			GameMath.prestigeValueMultiplier(state.PrestigeCount, PrestigeConfig.ValuePerPrestige)
		local nextMultiplier = GameMath.prestigeValueMultiplier(
			state.PrestigeCount + 1,
			PrestigeConfig.ValuePerPrestige
		)
		local prestigeRatio = math.clamp(state.Money / math.max(prestigeRequirement, 1), 0, 1)
		currentPrestigeLabel.Text = `REBIRTH {state.PrestigeCount}`
		nextPrestigeLabel.Text = `REBIRTH {state.PrestigeCount + 1}`
		currentMultiplierLabel.Text = string.format("%.2fx MONEY", currentMultiplier)
		nextMultiplierLabel.Text = string.format("%.2fx MONEY", nextMultiplier)
		prestigeDescription.Text = "REBIRTH RESETS CASH, AREAS AND UPGRADES"
		prestigeProgressText.Text = `$ {compact(state.Money)} / $ {compact(prestigeRequirement)}`
		prestigeProgressFill.Size = UDim2.fromScale(prestigeRatio, 1)
		prestigeProgressFill.Position = UDim2.fromScale(prestigeRatio / 2, 0.5)
		local readyToPrestige = projectedGearReward > 0
		prestigeButton.Active = readyToPrestige
		prestigeButton.Interactable = readyToPrestige
		prestigeButtonText.Text = if readyToPrestige
			then `REBIRTH  +{projectedGearReward} GEARS`
			else `NEED $ {compact(prestigeRequirement)}`
		prestigeButton.ImageColor3 = if readyToPrestige
			then Color3.new(1, 1, 1)
			else Color3.fromRGB(132, 132, 142)
		storageValue.Text = `SCRAP STORAGE  {compact(state.StoredWeight)} / {compact(
			state.DerivedStats.StorageCapacity
		)}`
		storageFill.Size = UDim2.fromScale(
			math.clamp(state.StoredWeight / math.max(state.DerivedStats.StorageCapacity, 1), 0, 1),
			1
		)
		for settingId, row in toggleRows do
			local enabled = state.Settings[settingId] == true
			local track = descendant(row, "SwitchTrack") :: Frame
			local knob = descendant(track, "Knob") :: Frame
			local hitArea = descendant(track, "ToggleHitArea")
			local accent = Color3.new(
				hitArea:GetAttribute("AccentR") or 0.33,
				hitArea:GetAttribute("AccentG") or 0.87,
				hitArea:GetAttribute("AccentB") or 0.46
			)
			track.BackgroundColor3 = if enabled then accent else Color3.fromRGB(59, 65, 78)
			knob.Position = if enabled then UDim2.new(1, -20, 0.5, 0) else UDim2.new(0, 20, 0.5, 0)
		end
		for settingId, row in volumeRows do
			local value = math.clamp(state.Settings[settingId] or 0, 0, 1)
			local track = descendant(row, "Track")
			local fill = descendant(track, "Fill") :: GuiObject
			local knob = descendant(track, "Knob") :: GuiObject
			local valueLabel = descendant(row, "Value") :: TextLabel
			fill.Size = UDim2.fromScale(value, 1)
			knob.Position = UDim2.fromScale(value, 0.5)
			valueLabel.Text = `{math.floor(value * 100 + 0.5)}%`
		end
		updateBoostHud()
		renderInventory()
		renderMagnetShop()
		renderPets()
		for _, upgradeId in UpgradeConfig.Order do
			local definition = UpgradeConfig.ById[upgradeId]
			local row = descendant(upgradeScreen, `UpgradeRow_{upgradeId}`)
			local level = state.UpgradeLevels[upgradeId]
			local maximum = state.UpgradeMaximumLevels[upgradeId]
			local current = GameMath.incrementalUpgradeEffect(
				definition.BaseEffect,
				definition.EffectPerLevel,
				level,
				definition.EffectCurve,
				definition.CurvePower,
				definition.EffectCap
			)
			local future = GameMath.incrementalUpgradeEffect(
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
			local displayName = descendant(row, "DisplayName") :: TextLabel
			local increaseLabel = descendant(row, "Increase") :: TextLabel
			local increaseBadge = descendant(row, "IncreaseBadge") :: TextLabel
			local currentLabel = descendant(row, "CurrentValue") :: TextLabel
			local nextLabel = descendant(row, "NextValue") :: TextLabel
			local priceLabel = descendant(row, "Price") :: TextLabel
			local buyButton = descendant(row, "BuyButton") :: GuiButton
			local secondaryButton = descendant(row, "SecondaryButton") :: GuiButton
			local currentBox = descendant(row, "CurrentBox") :: GuiObject
			local nextBox = descendant(row, "NextBox") :: GuiObject
			local arrow = descendant(row, "Arrow") :: GuiObject
			local capInfo = descendant(row, "CapInfo") :: GuiObject
			local isCapped = level >= maximum
			local accent = UPGRADE_ACCENTS[upgradeId]
			local increaseText = if definition.EffectCurve == "Reduction"
				then `+{string.format(
					"%.1f",
					math.max(0, (1 - future / math.max(current, 0.001)) * 100)
				)}%`
				else `+{string.format("%.1f", math.max(0, future - current))}`
			displayName.Text = string.upper(definition.DisplayName)
			increaseLabel.Text = increaseText
			increaseBadge.Text = increaseText
			setAccent(displayName, accent)
			setAccent(increaseLabel, accent)
			setAccent(increaseBadge, accent)
			setAccent(descendant(capInfo, "Message") :: TextLabel, accent)
			displayName.Visible = not isCapped
			increaseLabel.Visible = not isCapped
			currentLabel.Text = string.format("%.1f", current)
			nextLabel.Text = if isCapped then "MAX" else string.format("%.1f", future)
			priceLabel.Text = if isCapped then "PRESTIGE" else `$ {compact(price)}`
			currentBox.Visible = not isCapped
			nextBox.Visible = not isCapped
			arrow.Visible = not isCapped
			capInfo.Visible = isCapped
			buyButton.Visible = not isCapped
			secondaryButton.Visible = not isCapped
			buyButton.Active = not isCapped
			buyButton.Interactable = not isCapped
			buyButton.AutoButtonColor = not isCapped
			buyButton:SetAttribute("Affordable", not isCapped and state.Money >= price)
			secondaryButton.Active = false
			secondaryButton.Interactable = false
		end
	end

	local function submitCode()
		local submitted = string.gsub(codeBox.Text, "%s+", "")
		if submitted == "" then
			setCodeStatus("ENTER A CODE FIRST", Color3.fromRGB(255, 101, 113))
			return
		end
		setCodeStatus("CHECKING...", Color3.fromRGB(218, 190, 255))
		redeemCode:FireServer(submitted)
	end
	redeemButton.Activated:Connect(submitCode)
	codeBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submitCode()
		end
	end)
	codeResult.OnClientEvent:Connect(function(success: boolean, message: string, rewards)
		recentCodeMessage = message
		recentCodeMessageAt = os.clock()
		setCodeStatus(
			message,
			if success then Color3.fromRGB(83, 223, 116) else Color3.fromRGB(255, 91, 103)
		)
		if success then
			codeBox.Text = ""
		end
		local rewardText = ""
		if success and typeof(rewards) == "table" and #rewards > 0 then
			local pieces = {}
			for _, reward in rewards do
				table.insert(pieces, `{reward.Id} x{reward.Amount}`)
			end
			rewardText = `  •  {table.concat(pieces, "  •  ")}`
		end
		showInfo(message .. rewardText, success)
	end)
	local notifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent
	notifyRemote.OnClientEvent:Connect(function(message: string)
		if message == recentCodeMessage and os.clock() - recentCodeMessageAt < 1 then
			return
		end
		showInfo(message, not string.find(string.upper(message), "NOT ", 1, true))
	end)

	task.spawn(function()
		while gui.Parent do
			updateBoostHud()
			task.wait(0.25)
		end
	end)

	for _, upgradeId in UpgradeConfig.Order do
		local row = descendant(upgradeScreen, `UpgradeRow_{upgradeId}`)
		local buy = descendant(row, "BuyButton") :: GuiButton
		buy.Activated:Connect(function()
			if state and state.UpgradeLevels[upgradeId] < state.UpgradeMaximumLevels[upgradeId] then
				(remotes.RequestUpgrade :: RemoteEvent):FireServer(upgradeId)
			end
		end)
	end

	prestigeButton.Activated:Connect(function()
		if prestigeButton.Active then
			(remotes.RequestPrestige :: RemoteEvent):FireServer()
		end
	end)
	if skipPrestigeButton then
		local skipProduct = MonetizationConfig.Products.SkipRebirth
		skipPrestigeButton.Visible = true
		skipPrestigeButton.Active = true
		skipPrestigeButton.Interactable = true
		if skipPrestigePrice then
			skipPrestigePrice.Text = `{Format.robuxSymbol(skipProduct.DisplayPrice)}`
		end
		if skipProduct.MarketplaceId > 0 and skipPrestigePrice then
			task.spawn(function()
				local succeeded, info = pcall(
					MarketplaceService.GetProductInfo,
					MarketplaceService,
					skipProduct.MarketplaceId,
					Enum.InfoType.Product
				)
				if succeeded and info and typeof(info.PriceInRobux) == "number" then
					skipPrestigePrice.Text = `{Format.robuxSymbol(info.PriceInRobux)}`
				end
			end)
		end
		skipPrestigeButton.Activated:Connect(function()
			if skipProduct.MarketplaceId > 0 then
				MarketplaceService:PromptProductPurchase(
					Players.LocalPlayer,
					skipProduct.MarketplaceId
				)
			elseif RunService:IsStudio() then
				monetizationPrompt:FireServer("Product", "SkipRebirth")
			else
				showInfo("Instant Rebirth needs a Marketplace ID.", false)
			end
		end)
	end

	(remotes.StateChanged :: RemoteEvent).OnClientEvent:Connect(render)
	local initial = (remotes.RequestInitialState :: RemoteFunction):InvokeServer()
	if initial then
		render(initial)
	else
		task.spawn(function()
			for _ = 1, 10 do
				task.wait(2)
				local retryState = (remotes.RequestInitialState :: RemoteFunction):InvokeServer()
				if retryState then
					render(retryState)
					return
				end
			end
		end)
	end
end

return table.freeze(PackUIController)
