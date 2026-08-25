--!strict

local AreaConfig = require(script.Parent.Parent.Config.AreaConfig)
local Environment = require(script.Parent.Parent.Config.Environment)
local PrestigeConfig = require(script.Parent.Parent.Config.PrestigeConfig)
local MonetizationConfig = require(script.Parent.Parent.Config.MonetizationConfig)
local PlotConfig = require(script.Parent.Parent.Config.PlotConfig)
local ScrapConfig = require(script.Parent.Parent.Config.ScrapConfig)
local ArenaConfig = require(script.Parent.Parent.Config.ArenaConfig)
local PitShopConfig = require(script.Parent.Parent.Config.PitShopConfig)
local AdminConfig = require(script.Parent.Parent.Config.AdminConfig)
local InventoryConfig = require(script.Parent.Parent.Config.InventoryConfig)
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
		assert(#scrap.ModelName > 0, `{scrapId}.ModelName must not be empty`)
		if scrap.PitOnly == true then
			assert(#scrap.AreaIds == 0, `{scrapId} is Pit-only and must not belong to a plot area`)
			positive(scrap.SlagValue or 0, `{scrapId}.SlagValue`)
		else
			assert(#scrap.AreaIds > 0, `{scrapId} must belong to an area`)
			assert(
				scrap.SlagValue == nil or scrap.SlagValue == 0,
				`{scrapId} is plot scrap and pays no slag`
			)
			for _, areaId in scrap.AreaIds do
				assert(AreaConfig.ById[areaId] ~= nil, `{scrapId} references unknown area {areaId}`)
			end
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
	for petId, pet in PetConfig.Pets do
		positive(pet.MoneyMultiplier, `{petId}.MoneyMultiplier`)
		if pet.Premium ~= true then
			local bonus = math.max(0, pet.MoneyMultiplier - 1)
			assert(
				bonus < GameMath.MAXIMUM_PET_CASH_BONUS,
				`{petId} hatchable cash must leave room for teammates under the team cap`
			)
		end
	end

	positive(PrestigeConfig.BaseMoneyRequirement, "Prestige.BaseMoneyRequirement")
	positive(PrestigeConfig.RequirementGrowth, "Prestige.RequirementGrowth")
	--[[
		EVERY PASS AND PRODUCT IS IN ITS ORDER LIST, and every marketplace id is real.

		The shop renders `PassOrder` / `ProductOrder`, not the definition tables, so an item missing from an
		order list exists, is priced, is buyable from its own Roblox page -- and is invisible in game.
		`PermanentSpeed` and `AutoSell` were both missing exactly that way for a while.

		Checked here rather than in `tests/run.luau` because `MonetizationConfig` uses `Color3`, which does
		not exist under Lune. This runs at server boot instead, which is early enough to catch it before a
		player can miss the item.
	]]
	for passId, definition in MonetizationConfig.Passes do
		assert(
			table.find(MonetizationConfig.PassOrder, passId) ~= nil,
			`{passId} is missing from MonetizationConfig.PassOrder`
		)
		positive(definition.MarketplaceId, `{passId}.MarketplaceId`)
	end
	for _, passId in MonetizationConfig.PassOrder do
		assert(MonetizationConfig.Passes[passId] ~= nil, `PassOrder names unknown pass {passId}`)
	end
	--[[
		PRODUCTS ARE NOT REQUIRED TO BE IN `ProductOrder`, and asserting that they were is what took the
		whole server down for a while.

		`ProductOrder` drives the SHOP GRID. The eight `RobuxUpgrade*` products are sold from the row on
		their own upgrade card instead, so they are deliberately absent from it -- an assert demanding
		otherwise fails at boot, and a validator that refuses to start the game is worse than the gap it
		was looking for.

		What IS worth asserting is the direction that can only ever be a mistake: an id in the list with no
		definition behind it, and a definition with no marketplace id.
	]]
	for productId, definition in MonetizationConfig.Products do
		positive(definition.MarketplaceId, `{productId}.MarketplaceId`)
	end
	for _, productId in MonetizationConfig.ProductOrder do
		assert(
			MonetizationConfig.Products[productId] ~= nil,
			`ProductOrder names unknown product {productId}`
		)
	end

	positive(PrestigeConfig.MaximumGearsPerPrestige, "Prestige.MaximumGearsPerPrestige")
	positive(PrestigeConfig.ValuePerPrestige, "Prestige.ValuePerPrestige")
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

	local pitWeightTotal = 0
	local strongestPit = 0
	local strongestPitId = ""
	for scrapId, weight in ArenaConfig.ScrapWeights do
		local definition = ScrapConfig.ById[scrapId]
		assert(definition ~= nil, `ArenaConfig.ScrapWeights names unknown scrap {scrapId}`)
		assert(definition.PitOnly == true, `{scrapId} in the Pit roster must be Pit-only`)
		positive(weight, `ArenaConfig.ScrapWeights.{scrapId}`)
		pitWeightTotal += weight
		if definition.RequiredMagnetStrength >= strongestPit then
			strongestPit = definition.RequiredMagnetStrength
			strongestPitId = scrapId
		end
	end
	assert(pitWeightTotal > 0, "ArenaConfig.ScrapWeights must not be empty")
	assert(strongestPitId == "RobotArm", "Robot Arm must be the strongest Pit scrap")
	local armFit = ArenaConfig.FitLongestStuds.RobotArm
	positive(armFit, "ArenaConfig.FitLongestStuds.RobotArm")
	for scrapId, longest in ArenaConfig.FitLongestStuds do
		positive(longest, `ArenaConfig.FitLongestStuds.{scrapId}`)
		assert(ScrapConfig.ById[scrapId] ~= nil, `FitLongestStuds names unknown scrap {scrapId}`)
		assert(longest <= armFit, `{scrapId} must not out-size the Robot Arm in the Pit`)
	end

	for _, scrapId in ScrapConfig.PitOrder do
		local definition = ScrapConfig.ById[scrapId]
		assert(
			definition ~= nil and definition.PitOnly == true,
			`{scrapId} in PitOrder must be Pit-only`
		)
	end

	local wreck = ArenaConfig.Wreck
	positive(wreck.Integrity, "ArenaConfig.Wreck.Integrity")
	assert(wreck.Integrity >= 1000, "the wreck must take minutes, not seconds")
	positive(wreck.ChipPerSecond, "ArenaConfig.Wreck.ChipPerSecond")
	positive(ArenaConfig.MagnetRangeCap, "ArenaConfig.MagnetRangeCap")
	positive(wreck.ChunkCount, "ArenaConfig.Wreck.ChunkCount")
	positive(wreck.FitLongestStuds, "ArenaConfig.Wreck.FitLongestStuds")
	assert(
		wreck.FitLongestStuds > armFit,
		"the wreck must out-size Pit scrap so it reads as the landmark"
	)
	positive(wreck.BarHeightStuds, "ArenaConfig.Wreck.BarHeightStuds")
	positive(wreck.BarWidthStuds, "ArenaConfig.Wreck.BarWidthStuds")
	positive(wreck.BreakdownSeconds, "ArenaConfig.Wreck.BreakdownSeconds")
	positive(wreck.ShieldEveryIntegrity, "ArenaConfig.Wreck.ShieldEveryIntegrity")
	assert(
		wreck.ShieldEveryIntegrity < wreck.Integrity,
		"wreck shield must be a slice of integrity, not the whole fight"
	)
	assert(wreck.ShieldCooldownSeconds >= 0, "ArenaConfig.Wreck.ShieldCooldownSeconds")
	assert(wreck.ShieldSkipBelow >= 0, "ArenaConfig.Wreck.ShieldSkipBelow")
	positive(wreck.NodeMinStuds, "ArenaConfig.Wreck.NodeMinStuds")
	positive(wreck.NodeMaxStuds, "ArenaConfig.Wreck.NodeMaxStuds")
	assert(
		wreck.NodeMinStuds < wreck.NodeMaxStuds,
		"overload node min distance must be inside the max"
	)
	positive(wreck.NodeRelocateSeconds, "ArenaConfig.Wreck.NodeRelocateSeconds")
	positive(wreck.ShieldBurstCount, "ArenaConfig.Wreck.ShieldBurstCount")
	positive(wreck.NodeBurstCount, "ArenaConfig.Wreck.NodeBurstCount")
	assert(#wreck.ModelNames == 1, "the wreck uses only the RobotWreck model")
	assert(wreck.ModelNames[1] == "RobotWreck", "RobotWreck is the wreck template")
	positive(AdminConfig.MaximumWreckHp, "AdminConfig.MaximumWreckHp")
	assert(
		AdminConfig.MaximumWreckHp >= wreck.Integrity,
		"admin wreck HP ceiling must reach the live wreck"
	)
	for _, name in wreck.ModelNames do
		assert(ScrapConfig.ById[name] == nil, `{name} is Pit scrap and must not be the wreck`)
	end

	for _, offerId in PitShopConfig.Order do
		local offer = PitShopConfig.ById[offerId]
		assert(offer ~= nil, `PitShopConfig.Order names unknown offer {offerId}`)
		assert(offer.Id == offerId, `Pit shop key mismatch for {offerId}`)
		positive(offer.SlagPrice, `{offerId}.SlagPrice`)
		local rewards = offer.Rewards
		local hasReward = false
		if rewards.Items then
			for itemId, amount in rewards.Items do
				assert(
					InventoryConfig.Consumables[itemId] ~= nil,
					`{offerId} grants unknown item {itemId}`
				)
				positive(amount, `{offerId}.Items.{itemId}`)
				hasReward = true
			end
		end
		if rewards.Money then
			positive(rewards.Money, `{offerId}.Money`)
			hasReward = true
		end
		if rewards.SecretTickets then
			positive(rewards.SecretTickets, `{offerId}.SecretTickets`)
			hasReward = true
		end
		assert(hasReward, `{offerId} must grant something`)
	end
end

return table.freeze(FoundationValidator)
