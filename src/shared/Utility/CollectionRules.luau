--!strict

local CollectionRules = {}

function CollectionRules.canCollect(
	magnetStrength: number,
	requiredStrength: number,
	currentWeight: number,
	capacity: number,
	scrapWeight: number,
	areaUnlocked: boolean,
	available: boolean
): (boolean, string)
	if not available then
		return false, "Unavailable"
	end
	if not areaUnlocked then
		return false, "AreaLocked"
	end
	if magnetStrength < requiredStrength then
		return false, "TooHeavy"
	end
	if currentWeight + scrapWeight > capacity + 1e-6 then
		return false, "StorageFull"
	end
	return true, "Collected"
end

--[[
	What a load of scrap pays out.

	`valueMultiplier` is the whole stack -- upgrades, pets, potions, events, friend boost and the permanent
	rebirth bonus -- already combined by `derivedStats`. The gear multiplier that used to be a third
	argument here is gone; see `PrestigeConfig`.

	The multipliers apply at SELL rather than at pickup, which is why `StoredValue` alone is not what a
	player is paid. Anything quoting an expected payout has to run through this function -- the HUD does.
]]
function CollectionRules.sellAward(
	storedValue: number,
	valueMultiplier: number,
	maximumMoney: number
): number
	if
		storedValue <= 0
		or valueMultiplier < 0
		or storedValue ~= storedValue
		or valueMultiplier ~= valueMultiplier
	then
		return 0
	end
	return math.floor(math.clamp(storedValue * valueMultiplier, 0, maximumMoney))
end

return table.freeze(CollectionRules)
