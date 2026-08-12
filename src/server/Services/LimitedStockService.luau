--!strict
--[[
	LimitedStockService.luau
	Global purchase limits for limited items -- the Singularity pet, for now.

	THE HARD PART IS THAT "LIMITED" IS GLOBAL. A per-server counter would sell the last one on every
	server at once, so the count has to live in a DataStore and every server has to agree on it. That
	makes `UpdateAsync` the only correct primitive here: it re-reads and re-applies under contention, so
	two servers claiming the last unit produce one winner and one refusal rather than two winners.

	RESERVE BEFORE YOU GRANT. `TryReserve` increments the global count and only then does the caller hand
	the item over. The other order -- grant, then count -- oversells under any race at all, and an
	oversold limited item cannot be taken back from the player who paid Robux for it.

	A FAILED RESERVE REFUSES THE SALE. If the DataStore is down we cannot know the count, and the safe
	answer for a limited item is "not right now": refunding a Robux purchase is possible, un-selling the
	1001st copy of a 1000-copy item is not.

	Roblox's own `ProcessReceipt` contract means a refused purchase must still be granted-or-not
	deterministically; `MonetizationService` treats a failed reserve as "do not process", so Roblox
	retries and the player is not charged for nothing.
]]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)

local LimitedStockService = {}

local STORE_NAME = if Environment.UseDevelopmentDataStore
	then `{Environment.DevelopmentDataStoreName}_LimitedStock`
	else `{Environment.DataStoreName}_LimitedStock`

local store: DataStore? = nil
local function limitedStore(): DataStore?
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		if ok then
			store = result
		end
	end
	return store
end

--[[
	Cached counts, so the shop can show "412 / 1000 left" without a DataStore read per frame.

	Deliberately allowed to be stale: this feeds a LABEL. Every actual sale goes through `TryReserve`,
	which reads the authoritative value, so a stale display can never oversell -- it can only be briefly
	wrong about how many are left, which is the acceptable half of that trade.
]]
local cached: { [string]: number } = {}

local function limitFor(passId: string): number?
	local definition = MonetizationConfig.Passes[passId] or MonetizationConfig.Products[passId]
	if definition == nil then
		return nil
	end
	local limit = (definition :: any).StockLimit
	if typeof(limit) ~= "number" or limit <= 0 then
		return nil
	end
	return math.floor(limit)
end

--- How many of a limited item are gone. Cached; refreshed by `Refresh` and by every reserve.
function LimitedStockService.Sold(passId: string): number
	return cached[passId] or 0
end

--- How many are left, or nil when the item is not limited.
function LimitedStockService.Remaining(passId: string): number?
	local limit = limitFor(passId)
	if limit == nil then
		return nil
	end
	return math.max(0, limit - LimitedStockService.Sold(passId))
end

--- Read the live count into the cache. Safe to call on a timer; failures leave the cache alone.
function LimitedStockService.Refresh(passId: string)
	local dataStore = limitedStore()
	if dataStore == nil or limitFor(passId) == nil then
		return
	end
	local ok, value = pcall(function()
		return dataStore:GetAsync(passId)
	end)
	if ok and typeof(value) == "number" then
		cached[passId] = value
	end
end

--[[
	Claim one unit. Returns whether it was reserved, and how many remain afterwards.

	`false` means DO NOT GRANT -- either sold out, or we could not establish the count. Both are refusals
	on purpose; see the note at the top about which mistakes are reversible.
]]
function LimitedStockService.TryReserve(passId: string): (boolean, number?)
	local limit = limitFor(passId)
	if limit == nil then
		--- Not a limited item: unlimited stock, nothing to reserve.
		return true, nil
	end

	--[[
		Studio has no shared DataStore worth contending over, and blocking test purchases behind a
		network call makes the limited item untestable. Counted locally so the flow can be exercised.
	]]
	if RunService:IsStudio() and not Environment.UseDevelopmentDataStore then
		local sold = (cached[passId] or 0) + 1
		if sold > limit then
			return false, 0
		end
		cached[passId] = sold
		return true, limit - sold
	end

	local dataStore = limitedStore()
	if dataStore == nil then
		return false, nil
	end

	local reserved = false
	local remaining: number? = nil
	local ok = pcall(function()
		dataStore:UpdateAsync(passId, function(current)
			local sold = if typeof(current) == "number" then current else 0
			if sold >= limit then
				reserved = false
				remaining = 0
				--- Returning nil aborts the write, which is what "no change" has to mean here.
				return nil
			end
			sold += 1
			reserved = true
			remaining = limit - sold
			cached[passId] = sold
			return sold
		end)
	end)

	if not ok then
		return false, nil
	end
	return reserved, remaining
end

--- Warm the cache for every limited item, and keep it warm.
function LimitedStockService.Start()
	local limited = {}
	for passId in MonetizationConfig.Passes do
		if limitFor(passId) ~= nil then
			table.insert(limited, passId)
		end
	end
	for productId in MonetizationConfig.Products do
		if limitFor(productId) ~= nil then
			table.insert(limited, productId)
		end
	end
	if #limited == 0 then
		return
	end

	task.spawn(function()
		while true do
			for _, passId in limited do
				LimitedStockService.Refresh(passId)
			end
			--- Slow: this is a label, and DataStore budget is shared with player saves.
			task.wait(60)
		end
	end)
end

return table.freeze(LimitedStockService)
