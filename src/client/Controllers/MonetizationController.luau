--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)

local MonetizationController = {}

function MonetizationController.Start()
	local player = Players.LocalPlayer
	local safeArea =
		player:WaitForChild("PlayerGui"):WaitForChild("ScrapyardUI"):WaitForChild("SafeArea")
	local navigation = safeArea:WaitForChild("Navigation")
	local menus = safeArea:WaitForChild("Menus")
	navigation:WaitForChild("ExclusiveShopButton")
	local menu = menus:WaitForChild("ExclusiveShopMenu") :: GuiObject
	menu:WaitForChild("CloseButton")
	local status = menu:WaitForChild("Status") :: TextLabel
	local promptRemote = ReplicatedStorage.Remotes:WaitForChild("MonetizationPrompt") :: RemoteEvent
	local resultRemote = ReplicatedStorage.Remotes:WaitForChild("MonetizationResult") :: RemoteEvent
	local currentState = nil
	local passPrices = {}
	for _, passId in MonetizationConfig.PassOrder do
		passPrices[passId] = MonetizationConfig.Passes[passId].DisplayPrice
	end

	local function refresh()
		if currentState == nil then
			return
		end
		for _, passId in MonetizationConfig.PassOrder do
			local card = menu:FindFirstChild(`PassCard_{passId}`, true)
			if card then
				local buy = card:FindFirstChild("BuyButton")
				if buy and buy:IsA("TextButton") then
					local owned = currentState.Entitlements[passId] == true
					buy.Text = if owned then "OWNED" else `R$ {passPrices[passId]}`
					buy.Active = not owned
					buy.AutoButtonColor = not owned
				end
			end
		end
	end

	for _, passId in MonetizationConfig.PassOrder do
		local definition = MonetizationConfig.Passes[passId]
		local card = menu:WaitForChild(`PassCard_{passId}`, true)
		local button = card:WaitForChild("BuyButton") :: GuiButton
		if definition.MarketplaceId > 0 then
			task.spawn(function()
				local succeeded, info = pcall(
					MarketplaceService.GetProductInfo,
					MarketplaceService,
					definition.MarketplaceId,
					Enum.InfoType.GamePass
				)
				if succeeded and info and info.PriceInRobux then
					passPrices[passId] = info.PriceInRobux
					refresh()
				end
			end)
		end
		button.Activated:Connect(function()
			if currentState and currentState.Entitlements[passId] then
				return
			end
			if definition.MarketplaceId > 0 then
				MarketplaceService:PromptGamePassPurchase(player, definition.MarketplaceId)
			elseif RunService:IsStudio() then
				promptRemote:FireServer("Pass", passId)
			else
				status.Text = "THIS PASS NEEDS A MARKETPLACE ID"
			end
		end)
	end

	for _, productId in MonetizationConfig.ProductOrder do
		local definition = MonetizationConfig.Products[productId]
		local card = menu:WaitForChild(`ProductCard_{productId}`, true)
		local button = card:WaitForChild("BuyButton") :: GuiButton
		button.Text = `R$ {definition.DisplayPrice}`
		if definition.MarketplaceId > 0 then
			task.spawn(function()
				local succeeded, info = pcall(
					MarketplaceService.GetProductInfo,
					MarketplaceService,
					definition.MarketplaceId,
					Enum.InfoType.Product
				)
				if succeeded and info and info.PriceInRobux then
					button.Text = `R$ {info.PriceInRobux}`
				end
			end)
		end
		button.Activated:Connect(function()
			if definition.MarketplaceId > 0 then
				MarketplaceService:PromptProductPurchase(player, definition.MarketplaceId)
			elseif RunService:IsStudio() then
				promptRemote:FireServer("Product", productId)
			else
				status.Text = "THIS PRODUCT NEEDS A MARKETPLACE ID"
			end
		end)
	end

	resultRemote.OnClientEvent:Connect(function(success, message)
		status.Text = message
		status.TextColor3 = if success
			then Color3.fromRGB(53, 190, 112)
			else Color3.fromRGB(222, 76, 86)
	end)
	ReplicatedStorage.Remotes.StateChanged.OnClientEvent:Connect(function(state)
		currentState = state
		refresh()
	end)
	currentState = ReplicatedStorage.Remotes.RequestInitialState:InvokeServer()
	refresh()
end

return table.freeze(MonetizationController)
