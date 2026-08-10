--!strict

local GameMath = {}

function GameMath.upgradeMaximumLevel(
	baseMaximumLevel: number,
	levelsPerPrestige: number,
	prestigeCount: number
): number
	return math.max(0, math.floor(baseMaximumLevel + levelsPerPrestige * prestigeCount))
end

function GameMath.petMoneyMultiplier(
	equippedPetIds: { string },
	ownedPets: { [string]: number },
	petDefinitions: { [string]: any }
): number
	local bonus = 0
	for _, petId in equippedPetIds do
		local definition = petDefinitions[petId]
		if definition and (ownedPets[petId] or 0) > 0 then
			bonus += math.max(0, definition.MoneyMultiplier - 1)
		end
	end
	return 1 + bonus
end

local PET_EFFECT_KEYS = {
	"Cash",
	"MagnetStrength",
	"MagnetRange",
	"Storage",
	"MovementSpeed",
	"CollectionSpeed",
	"RespawnRate",
	"RarityLuck",
}

-- Pet effects are expressed as multipliers. Their bonuses stack additively, while
-- premium abilities amplify the final bonus instead of compounding each pet.
function GameMath.petEffectMultipliers(
	equippedPetIds: { string },
	ownedPets: { [string]: number },
	petDefinitions: { [string]: any }
): { [string]: number }
	local bonuses = {}
	local strongestEffects = nil
	local strongestScore = -1
	local bonusAmplifier = 1
	local copyPower = 0
	for _, key in PET_EFFECT_KEYS do
		bonuses[key] = 0
	end
	for _, petId in equippedPetIds do
		local definition = petDefinitions[petId]
		if definition and (ownedPets[petId] or 0) > 0 then
			local effects = definition.Effects or { Cash = definition.MoneyMultiplier or 1 }
			local score = 0
			for _, key in PET_EFFECT_KEYS do
				local bonus = math.max(0, (effects[key] or 1) - 1)
				bonuses[key] += bonus
				score += bonus
			end
			if definition.Premium ~= true and score > strongestScore then
				strongestScore = score
				strongestEffects = effects
			end
			if definition.Ability == "AmplifyPetBonuses" then
				bonusAmplifier *= math.max(1, definition.AbilityPower or 1)
			elseif definition.Ability == "CopyStrongestPet" then
				copyPower += math.max(0, definition.AbilityPower or 1)
			end
		end
	end
	if strongestEffects and copyPower > 0 then
		for _, key in PET_EFFECT_KEYS do
			bonuses[key] += math.max(0, (strongestEffects[key] or 1) - 1) * copyPower
		end
	end
	local result = {}
	for _, key in PET_EFFECT_KEYS do
		result[key] = 1 + bonuses[key] * bonusAmplifier
	end
	return result
end

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

function GameMath.incrementalUpgradeCost(
	baseCost: number,
	growthRate: number,
	costPower: number,
	currentLevel: number,
	maximumCurrency: number
): number
	if
		not GameMath.isFinite(baseCost)
		or not GameMath.isFinite(growthRate)
		or not GameMath.isFinite(costPower)
		or not GameMath.isFinite(currentLevel)
		or baseCost <= 0
		or growthRate < 1
		or costPower <= 0
		or currentLevel < 0
	then
		return maximumCurrency
	end
	local level = math.floor(currentLevel)
	local cost = baseCost * (level + 1) ^ costPower * growthRate ^ math.sqrt(level)
	return math.max(1, math.floor(GameMath.clampFinite(cost, 1, maximumCurrency, maximumCurrency)))
end

function GameMath.incrementalUpgradeEffect(
	baseEffect: number,
	effectPerLevel: number,
	currentLevel: number,
	effectCurve: string,
	curvePower: number,
	effectCap: number
): number
	if
		not GameMath.isFinite(baseEffect)
		or not GameMath.isFinite(effectPerLevel)
		or not GameMath.isFinite(currentLevel)
		or not GameMath.isFinite(curvePower)
		or currentLevel < 0
		or curvePower <= 0
	then
		return baseEffect
	end
	local level = math.floor(currentLevel)
	local effect
	if effectCurve == "Power" then
		effect = baseEffect + effectPerLevel * level ^ curvePower
	elseif effectCurve == "Diminishing" then
		effect = effectCap - (effectCap - baseEffect) * math.exp(-effectPerLevel * level)
	elseif effectCurve == "Exponential" then
		effect = baseEffect * (1 + effectPerLevel) ^ level
	elseif effectCurve == "Reduction" then
		effect = baseEffect / (1 + effectPerLevel * level) ^ curvePower
		return GameMath.clampFinite(effect, effectCap, baseEffect, baseEffect)
	else
		return baseEffect
	end
	return GameMath.clampFinite(effect, 0, effectCap, baseEffect)
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

function GameMath.prestigeRequirement(
	baseRequirement: number,
	growthRate: number,
	prestigeCount: number,
	maximumCurrency: number
): number
	if
		baseRequirement <= 0
		or growthRate < 1
		or prestigeCount < 0
		or not GameMath.isFinite(prestigeCount)
	then
		return maximumCurrency
	end
	local requirement = baseRequirement * growthRate ^ math.floor(prestigeCount)
	return math.floor(
		GameMath.clampFinite(requirement, baseRequirement, maximumCurrency, maximumCurrency)
	)
end

function GameMath.scaledPrestigeGearReward(
	money: number,
	requirement: number,
	prestigeCount: number,
	maximumReward: number
): number
	if money < requirement or requirement <= 0 or prestigeCount < 0 then
		return 0
	end
	local overdrive = math.sqrt(money / requirement)
	local veteranBonus = 1 + math.floor(prestigeCount) * 0.15
	return math.max(
		1,
		math.floor(GameMath.clampFinite(overdrive * veteranBonus, 0, maximumReward, 0))
	)
end

function GameMath.gearValueMultiplier(
	gears: number,
	gearPower: number,
	maximumMultiplier: number
): number
	if gears < 0 or gearPower <= 0 then
		return 1
	end
	local multiplier = (1 + gears) ^ gearPower
	return GameMath.clampFinite(multiplier, 1, maximumMultiplier, 1)
end

return table.freeze(GameMath)
