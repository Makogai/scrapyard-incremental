--!strict

local AreaConfig = require(script.Parent.Parent.Config.AreaConfig)
local Environment = require(script.Parent.Parent.Config.Environment)
local PrestigeConfig = require(script.Parent.Parent.Config.PrestigeConfig)
local PlotConfig = require(script.Parent.Parent.Config.PlotConfig)
local ScrapConfig = require(script.Parent.Parent.Config.ScrapConfig)
local UpgradeConfig = require(script.Parent.Parent.Config.UpgradeConfig)
local PetConfig = require(script.Parent.Parent.Config.PetConfig)
local GameMath = require(script.Parent.GameMath)

local FoundationValidator = {}

local function positive(value: number, label: string)
	assert(GameMath.isFinite(value) and value > 0, `{label} must be finite and positive`)
end

local function nonnegative(value: number, label: string)
	assert(GameMath.isFinite(value) and value >= 0, `{label} must be finite and nonnegative`)
end

function FoundationValidator.validate()
	local variantWeightTotal = 0
	for variantId, variant in ScrapConfig.Variants do
		assert(variant.Id == variantId, `Variant key mismatch for {variantId}`)
		positive(variant.ValueMultiplier, `{variantId}.ValueMultiplier`)
		positive(variant.SpawnWeight, `{variantId}.SpawnWeight`)
		variantWeightTotal += variant.SpawnWeight
	end
	assert(
		variantWeightTotal == ScrapConfig.VariantRollTotal,
		"Variant weights must match roll total"
	)

	for scrapId, scrap in ScrapConfig.ById do
		assert(scrap.Id == scrapId, `Scrap key mismatch for {scrapId}`)
		positive(scrap.Weight, `{scrapId}.Weight`)
		positive(scrap.BaseValue, `{scrapId}.BaseValue`)
		positive(scrap.RequiredMagnetStrength, `{scrapId}.RequiredMagnetStrength`)
		positive(scrap.SpawnWeight, `{scrapId}.SpawnWeight`)
		positive(scrap.RespawnSeconds, `{scrapId}.RespawnSeconds`)
		assert(#scrap.AreaIds > 0, `{scrapId} must belong to an area`)
		--[[
			There is no size or rotation to validate here: both come from the model in Studio now. What
			is still worth asserting is that a model is named at all, because a blank name spawns
			nothing and the failure shows up as an empty yard rather than as an error.
		]]
		assert(#scrap.ModelName > 0, `{scrapId}.ModelName must not be empty`)
		for _, areaId in scrap.AreaIds do
			assert(AreaConfig.ById[areaId] ~= nil, `{scrapId} references unknown area {areaId}`)
		end
	end

	local seenOrder: { [number]: boolean } = {}
	for areaId, area in AreaConfig.ById do
		assert(area.Id == areaId, `Area key mismatch for {areaId}`)
		positive(area.Order, `{areaId}.Order`)
		nonnegative(area.UnlockPrice, `{areaId}.UnlockPrice`)
		assert(not seenOrder[area.Order], `Area order {area.Order} is duplicated`)
		seenOrder[area.Order] = true
		for _, scrapId in area.ScrapIds do
			assert(ScrapConfig.ById[scrapId] ~= nil, `{areaId} references unknown scrap {scrapId}`)
		end
	end

	for upgradeId, upgrade in UpgradeConfig.ById do
		assert(upgrade.Id == upgradeId, `Upgrade key mismatch for {upgradeId}`)
		positive(upgrade.BaseMaximumLevel, `{upgradeId}.BaseMaximumLevel`)
		positive(upgrade.LevelsPerPrestige, `{upgradeId}.LevelsPerPrestige`)
		positive(upgrade.BaseCost, `{upgradeId}.BaseCost`)
		positive(upgrade.CostPower, `{upgradeId}.CostPower`)
		assert(
			upgrade.GrowthRate >= 1 and GameMath.isFinite(upgrade.GrowthRate),
			`{upgradeId}.GrowthRate must be at least one`
		)
		nonnegative(upgrade.BaseEffect, `{upgradeId}.BaseEffect`)
		nonnegative(upgrade.EffectPerLevel, `{upgradeId}.EffectPerLevel`)
		positive(upgrade.CurvePower, `{upgradeId}.CurvePower`)
		if upgrade.EffectCurve == "Reduction" then
			positive(upgrade.EffectCap, `{upgradeId}.EffectCap`)
			assert(
				upgrade.EffectCap <= upgrade.BaseEffect,
				`{upgradeId}.EffectCap must be a lower reduction floor`
			)
		else
			assert(
				upgrade.EffectCap >= upgrade.BaseEffect,
				`{upgradeId}.EffectCap is below its base effect`
			)
		end
	end
	for eggId, egg in PetConfig.Eggs do
		positive(egg.Price, `{eggId}.Price`)
		assert(AreaConfig.ById[egg.RequiredArea] ~= nil, `{eggId} references an unknown area`)
		assert(#egg.PetIds == 6, `{eggId} must contain exactly six pets`)
		local totalWeight = 0
		for _, petId in egg.PetIds do
			local pet = PetConfig.Pets[petId]
			assert(pet ~= nil and pet.EggId == eggId, `{eggId} has an invalid pet {petId}`)
			totalWeight += pet.RollWeight
		end
		assert(totalWeight == PetConfig.RollTotal, `{eggId} roll weights must match RollTotal`)
	end

	positive(PrestigeConfig.BaseMoneyRequirement, "Prestige.BaseMoneyRequirement")
	positive(PrestigeConfig.RequirementGrowth, "Prestige.RequirementGrowth")
	positive(PrestigeConfig.MaximumGearsPerPrestige, "Prestige.MaximumGearsPerPrestige")
	positive(PrestigeConfig.GearPower, "Prestige.GearPower")
	assert(
		PrestigeConfig.MaximumGearValueMultiplier >= 1,
		"Prestige multiplier cap must be at least one"
	)
	assert(PlotConfig.PlotCount == Environment.MaximumPlayers, "Plot count must match server size")
	assert(
		PlotConfig.StreetCount * PlotConfig.PlotsPerStreet == PlotConfig.PlotCount,
		"Street layout must account for every plot"
	)
	positive(PlotConfig.Width, "Plot.Width")
	positive(PlotConfig.Depth, "Plot.Depth")
	positive(PlotConfig.MinimumGap, "Plot.MinimumGap")
	positive(PlotConfig.DistrictRadius, "Plot.DistrictRadius")
	positive(PlotConfig.CornerClearance, "Plot.CornerClearance")
	positive(PlotConfig.CentralPlazaDiameter, "Plot.CentralPlazaDiameter")
	positive(PlotConfig.StreetWidth, "Plot.StreetWidth")
	positive(PlotConfig.IslandDiameter, "Plot.IslandDiameter")
	assert(
		PlotConfig.CrusherLocalZ < PlotConfig.BackBoundaryLocalZ,
		"Crusher must leave back expansion clearance"
	)
	assert(PlotConfig.EntranceLocalZ < 0, "Plot entrance must remain on the front side")
end

return table.freeze(FoundationValidator)
