--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AdminConfig = require(ReplicatedStorage.Shared.Config.AdminConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local PlayerStateService = require(script.Parent.PlayerStateService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local PlotService = require(script.Parent.PlotService)
local ScrapService = require(script.Parent.ScrapService)
local RemoteService = require(script.Parent.RemoteService)

local MonetizationService = {}

local function passFromMarketplaceId(marketplaceId: number)
	for passId, definition in MonetizationConfig.Passes do
		if definition.MarketplaceId > 0 and definition.MarketplaceId == marketplaceId then
			return passId
		end
	end
	return nil
end

local function productFromMarketplaceId(marketplaceId: number)
	for productId, definition in MonetizationConfig.Products do
		if definition.MarketplaceId > 0 and definition.MarketplaceId == marketplaceId then
			return productId
		end
	end
	return nil
end

local function notify(player: Player, success: boolean, message: string)
	RemoteService.GetEvent("MonetizationResult"):FireClient(player, success, message)
	RemoteService.GetEvent("Notify"):FireClient(player, message)
end

local function refreshOwnedPasses(player: Player)
	for _, passId in MonetizationConfig.PassOrder do
		local definition = MonetizationConfig.Passes[passId]
		if definition.MarketplaceId > 0 then
			local succeeded, owned = pcall(
				MarketplaceService.UserOwnsGamePassAsync,
				MarketplaceService,
				player.UserId,
				definition.MarketplaceId
			)
			if succeeded and owned then
				PlayerStateService.GrantEntitlement(player, passId)
			end
		end
	end
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		local productId = productFromMarketplaceId(receiptInfo.ProductId)
		if player == nil or productId == nil or not PlayerStateService.IsLoaded(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local purchaseId = tostring(receiptInfo.PurchaseId)
		local alreadyProcessed = PlayerStateService.HasProcessedReceipt(player, purchaseId)
		local granted = PlayerStateService.GrantDeveloperProduct(player, productId, purchaseId)
		if granted then
			if productId == "SkipRebirth" then
				PlotService.RefreshAppearance(player)
				ScrapService.RefreshPlayer(player)
			end
			if not alreadyProcessed then
				local configuredPrice = MonetizationConfig.Products[productId].DisplayPrice
				local actualPrice = if typeof(receiptInfo.CurrencySpent) == "number"
					then receiptInfo.CurrencySpent
					else configuredPrice
				LeaderboardService.RecordRobuxSpent(player, actualPrice)
			end
			notify(
				player,
				true,
				`✓ {MonetizationConfig.Products[productId].DisplayName} delivered!`
			)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player, marketplaceId, purchased)
			if not purchased then
				return
			end
			local passId = passFromMarketplaceId(marketplaceId)
			if passId then
				local granted, message = PlayerStateService.GrantEntitlement(player, passId)
				if granted then
					local definition = MonetizationConfig.Passes[passId]
					local price = definition.DisplayPrice
					local infoSucceeded, productInfo = pcall(
						MarketplaceService.GetProductInfo,
						MarketplaceService,
						marketplaceId,
						Enum.InfoType.GamePass
					)
					if
						infoSucceeded
						and typeof(productInfo) == "table"
						and typeof(productInfo.PriceInRobux) == "number"
					then
						price = productInfo.PriceInRobux
					end
					LeaderboardService.RecordRobuxSpent(player, price)
					notify(player, true, message)
				end
			end
		end
	)

	RemoteService.GetEvent("MonetizationPrompt").OnServerEvent
		:Connect(function(player, category, catalogId)
			if
				not RunService:IsStudio()
				or not AdminConfig.IsAdmin(player.UserId)
				or typeof(category) ~= "string"
				or typeof(catalogId) ~= "string"
			then
				return
			end
			if category == "Pass" and MonetizationConfig.Passes[catalogId] then
				local success, message = PlayerStateService.GrantEntitlement(player, catalogId)
				notify(player, success, `STUDIO TEST: {message}`)
			elseif category == "Product" and MonetizationConfig.Products[catalogId] then
				local purchaseId = `Studio-{player.UserId}-{catalogId}-{game
					:GetService("HttpService")
					:GenerateGUID(false)}`
				local success, message =
					PlayerStateService.GrantDeveloperProduct(player, catalogId, purchaseId)
				if success and catalogId == "SkipRebirth" then
					PlotService.RefreshAppearance(player)
					ScrapService.RefreshPlayer(player)
				end
				notify(player, success, `STUDIO TEST: {message}`)
			end
		end)

	local function onPlayer(player: Player)
		task.spawn(function()
			for _ = 1, 40 do
				if player.Parent ~= Players then
					return
				end
				if PlayerStateService.IsLoaded(player) then
					refreshOwnedPasses(player)
					return
				end
				task.wait(0.25)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return table.freeze(MonetizationService)
