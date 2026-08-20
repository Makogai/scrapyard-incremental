--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AdminConfig = require(ReplicatedStorage.Shared.Config.AdminConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local PlotSkinConfig = require(ReplicatedStorage.Shared.Config.PlotSkinConfig)
local PlayerStateService = require(script.Parent.PlayerStateService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local PlotService = require(script.Parent.PlotService)
local PlotThemeService = require(script.Parent.PlotThemeService)
local PassPadService = require(script.Parent.PassPadService)
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

--[[
	EVERYTHING THAT FOLLOWS FROM OWNING A PASS, in one place.

	Called from three directions -- the join sweep, a completed purchase, and a prompt the player closed
	because they already owned the thing -- so it must be safe to run repeatedly.
]]
local function applyOwnedPass(player: Player, passId: string)
	PlayerStateService.GrantEntitlement(player, passId)
	--[[
		A pad for a pass you now own has to go, and this is the path that catches it for a player who
		bought it in a previous session -- `OnAppearanceRefreshed` fires before the ownership check has
		finished, so the plot is built while the entitlement is still unknown.
	]]
	PassPadService.RefreshPlayer(player)
	if passId ~= PlotSkinConfig.Pass then
		return
	end
	--[[
		A plot skin only exists as a rebuilt plot, so coming to own one has to rebuild. Without this the
		player pays and their yard looks identical until something else happens to refresh it.

		WORN ON PURCHASE, but only when nothing is worn. This runs on every rejoin too, and it must not
		overwrite somebody who has deliberately taken the skin off.
	]]
	local plotState = PlayerStateService.GetPlotState(player)
	if plotState ~= nil and (plotState.ActivePlotSkin or "") == "" then
		PlayerStateService.SetActivePlotSkin(player, passId)
	end
	local skinPlot = PlotService.GetPlot(player)
	if skinPlot ~= nil then
		PlotThemeService.Rebuild(player, skinPlot)
	end
end

--- Does Roblox say this player owns it? Wrapped because the web call can throw.
local function ownsPass(player: Player, marketplaceId: number): boolean
	local succeeded, owned = pcall(
		MarketplaceService.UserOwnsGamePassAsync,
		MarketplaceService,
		player.UserId,
		marketplaceId
	)
	return succeeded and owned == true
end

local function refreshOwnedPasses(player: Player)
	for _, passId in MonetizationConfig.PassOrder do
		local definition = MonetizationConfig.Passes[passId]
		if definition.MarketplaceId > 0 and ownsPass(player, definition.MarketplaceId) then
			applyOwnedPass(player, passId)
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
				--[[
					Skip Rebirth performs a real rebirth, so it needs the plot REBUILT for the same reason
					`PrestigeService` does: the area unlocks are gone and the old yard is still standing.
				]]
				PlotService.RefreshAppearance(player)
				local plot = PlotService.GetPlot(player)
				if plot ~= nil then
					PlotThemeService.Rebuild(player, plot)
				else
					ScrapService.RefreshPlayer(player)
				end
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
				--[[
					CLOSED WITHOUT BUYING -- which is also what Roblox reports when the dialog said "you already
					own this item". So this is where our save re-syncs with the truth rather than the one case we
					cannot otherwise reach: a player whose entitlement is missing while Roblox says they own it
					sees the offer, presses it, is refused, and is stuck in that loop until they rejoin. Wiping a
					profile puts them there instantly, and so does any grant that never happened locally.
				]]
				local ownedId = passFromMarketplaceId(marketplaceId)
				if
					ownedId ~= nil
					and PlayerStateService.IsLoaded(player)
					and ownsPass(player, marketplaceId)
				then
					applyOwnedPass(player, ownedId)
				end
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
					local plot = PlotService.GetPlot(player)
					if plot ~= nil then
						PlotThemeService.Rebuild(player, plot)
					else
						ScrapService.RefreshPlayer(player)
					end
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
