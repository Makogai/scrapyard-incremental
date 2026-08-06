--!strict

local GameMath = {}

function GameMath.isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

function GameMath.clampFinite(
	value: number,
	minimum: number,
	maximum: number,
	fallback: number
): number
	assert(minimum <= maximum, "Minimum cannot exceed maximum")
	if not GameMath.isFinite(value) then
		return math.clamp(fallback, minimum, maximum)
	end
	return math.clamp(value, minimum, maximum)
end

function GameMath.upgradeCost(
	baseCost: number,
	growthRate: number,
	currentLevel: number,
	maximumCurrency: number
): number
	if
		not GameMath.isFinite(baseCost)
		or not GameMath.isFinite(growthRate)
		or not GameMath.isFinite(currentLevel)
		or baseCost < 0
		or growthRate < 1
		or currentLevel < 0
	then
		return maximumCurrency
	end
	local cost = baseCost * growthRate ^ math.floor(currentLevel)
	return math.floor(GameMath.clampFinite(cost, 0, maximumCurrency, maximumCurrency))
end

function GameMath.upgradeEffect(
	baseEffect: number,
	effectPerLevel: number,
	currentLevel: number,
	effectCap: number
): number
	if currentLevel < 0 or not GameMath.isFinite(currentLevel) then
		return math.min(baseEffect, effectCap)
	end
	local effect = baseEffect + effectPerLevel * math.floor(currentLevel)
	return GameMath.clampFinite(effect, 0, effectCap, 0)
end

function GameMath.scrapValue(
	baseValue: number,
	variantMultiplier: number,
	valueMultiplier: number,
	maximumValue: number
): number
	if baseValue < 0 or variantMultiplier < 0 or valueMultiplier < 0 then
		return 0
	end
	local value = baseValue * variantMultiplier * valueMultiplier
	return math.floor(GameMath.clampFinite(value, 0, maximumValue, 0))
end

function GameMath.canStore(currentWeight: number, capacity: number, scrapWeight: number): boolean
	if
		not GameMath.isFinite(currentWeight)
		or not GameMath.isFinite(capacity)
		or not GameMath.isFinite(scrapWeight)
		or currentWeight < 0
		or capacity < 0
		or scrapWeight <= 0
	then
		return false
	end
	return currentWeight + scrapWeight <= capacity + 1e-6
end

function GameMath.prestigeGearReward(
	money: number,
	requirement: number,
	maximumReward: number
): number
	if
		not GameMath.isFinite(money)
		or not GameMath.isFinite(requirement)
		or money < requirement
		or requirement <= 0
	then
		return 0
	end
	local reward = math.floor(money / requirement)
	return math.floor(GameMath.clampFinite(reward, 0, maximumReward, 0))
end

function GameMath.gearValueMultiplier(
	gears: number,
	bonusPerGear: number,
	maximumMultiplier: number
): number
	if gears < 0 or bonusPerGear < 0 then
		return 1
	end
	local multiplier = 1 + gears * bonusPerGear
	return GameMath.clampFinite(multiplier, 1, maximumMultiplier, 1)
end

return table.freeze(GameMath)
