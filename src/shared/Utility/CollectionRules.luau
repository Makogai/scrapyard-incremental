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

function CollectionRules.sellAward(
	storedValue: number,
	valueMultiplier: number,
	gearMultiplier: number,
	maximumMoney: number
): number
	if
		storedValue <= 0
		or valueMultiplier < 0
		or gearMultiplier < 0
		or storedValue ~= storedValue
		or valueMultiplier ~= valueMultiplier
		or gearMultiplier ~= gearMultiplier
	then
		return 0
	end
	return math.floor(math.clamp(storedValue * valueMultiplier * gearMultiplier, 0, maximumMoney))
end

return table.freeze(CollectionRules)
