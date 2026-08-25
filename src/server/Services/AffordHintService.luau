--!strict
--[[
	AffordHintService.luau
	One toast the first time a player can afford the next magnet or yard.

	Evaluated from saved state, same shape as `TutorialService`: the client never
	reports affordance, and firing is marked on the save so a rejoin cannot repeat
	it. Already owning the thing skips the toast without marking, so a player who
	bought before this shipped is not nagged.

	One hint per tick. Crossing both prices in one sell should not dump two cards
	on the same frame.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaConfig = require(ReplicatedStorage.Shared.Config.AreaConfig)
local HintConfig = require(ReplicatedStorage.Shared.Config.HintConfig)
local InventoryConfig = require(ReplicatedStorage.Shared.Config.InventoryConfig)
local AreaRules = require(ReplicatedStorage.Shared.Utility.AreaRules)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RemoteService = require(script.Parent.RemoteService)

local AffordHintService = {}

local function previousAreaUnlocked(unlocked: { [string]: boolean }, areaId: string): boolean
	for index, id in AreaConfig.Order do
		if id == areaId then
			if index <= 1 then
				return true
			end
			return unlocked[AreaConfig.Order[index - 1]] == true
		end
	end
	return false
end

local function isReady(hint: HintConfig.AffordHint, state: { [string]: any }): boolean
	if hint.Kind == "Area" then
		local definition = AreaConfig.ById[hint.TargetId]
		if definition == nil then
			return false
		end
		local unlocked = state.UnlockedAreas
		if unlocked[hint.TargetId] == true then
			return false
		end
		if not previousAreaUnlocked(unlocked, hint.TargetId) then
			return false
		end
		local price = AreaRules.unlockPrice(definition.UnlockPrice, state.PrestigeCount)
		return state.Money >= price
	end

	local magnet = InventoryConfig.Magnets[hint.TargetId]
	if magnet == nil or typeof(magnet.ShopPrice) ~= "number" then
		return false
	end
	if state.OwnedMagnets[hint.TargetId] == true then
		return false
	end
	return state.Money >= magnet.ShopPrice
end

function AffordHintService.Evaluate(player: Player)
	local state = PlayerStateService.GetRewardState(player)
	if state == nil then
		return
	end

	local hinted = state.AffordHints
	for _, hint in HintConfig.Hints do
		if hinted[hint.Id] == true then
			continue
		end
		if not isReady(hint, state) then
			continue
		end
		if not PlayerStateService.MarkAffordHint(player, hint.Id) then
			return
		end
		RemoteService.GetEvent("Notify"):FireClient(player, hint.Message)
		return
	end
end

function AffordHintService.Start()
	task.spawn(function()
		while true do
			task.wait(HintConfig.CheckIntervalSeconds)
			for _, player in Players:GetPlayers() do
				AffordHintService.Evaluate(player)
			end
		end
	end)
end

return table.freeze(AffordHintService)
