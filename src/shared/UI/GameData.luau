--!nonstrict
--[[
	GameData.luau
	Adapts the game's authoritative configuration into the shapes the UI kit's
	screens already expect.

	This is the seam that replaced `Mock.luau`. Screens keep taking the same
	props; the values behind them now come from Shared/Config and are computed
	with the same Shared/Utility/GameMath the server uses -- so a price shown in
	the UI is the price the server will charge, from the same formula, and cannot
	drift out of sync.

	Nothing here is authoritative. It reads configuration and derives display
	values from state the server already sent. Every purchase still goes through
	Bridge as a bare intent.

	Rarity mapping: the game's five scrap variants are mapped onto the kit's
	rarity ramp so one colour system covers scrap, magnets and pets.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaConfig = require(ReplicatedStorage.Shared.Config.AreaConfig)
local GameMath = require(ReplicatedStorage.Shared.Utility.GameMath)
local InventoryConfig = require(ReplicatedStorage.Shared.Config.InventoryConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PrestigeConfig = require(ReplicatedStorage.Shared.Config.PrestigeConfig)
local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local ScrapConfig = require(ReplicatedStorage.Shared.Config.ScrapConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Assets = require(ReplicatedStorage.Shared.UI.Assets)

local GameData = {}

--------------------------------------------------------------------------------
-- Rarity mapping
--------------------------------------------------------------------------------

--- Scrap variant -> kit rarity.
GameData.variantRarity = {
	Normal = "Normal",
	Rare = "Diamond",
	Epic = "Electric",
	Legendary = "Gold",
	Nebula = "Admin",
}

--- Magnet id -> kit rarity, so a magnet card is coloured by its tier.
GameData.magnetRarity = {
	MagnetBasic = "Normal",
	AdvancedMagnet = "Diamond",
	QuantumMagnet = "Radioactive",
}

--- Consumable id -> kit rarity and the glyph tint used on its potion icon.
GameData.consumableRarity = {
	CashPotion = "Gold",
	StrengthPotion = "Blood",
	LuckPotion = "Emerald",
	GodPotion = "Radioactive",
}

--[[
	There is deliberately no pet-rarity translation table any more.

	`Theme.Rarity` used to be missing `Uncommon` and `Secret`, so a map folded them
	onto `Common` and `Mythic`. Once those two styles were added the map became a
	silent lie: the Pets window called Zebra "COMMON" while the egg window, which
	reads `PetConfig` directly, correctly called it "UNCOMMON". Pass the rarity
	straight through and there is only one answer.
]]

--------------------------------------------------------------------------------
-- Upgrades
--------------------------------------------------------------------------------

--- Icon and accent per upgrade, matched to the kit's glyph set.
local UPGRADE_STYLE = {
	MagnetStrength = { glyph = "magnet", accent = "Red" },
	MagnetRange = { glyph = "pin", accent = "Cyan" },
	StorageCapacity = { glyph = "crate", accent = "Orange" },
	MovementSpeed = { glyph = "bolt", accent = "Yellow" },
	ScrapValue = { glyph = "coin", accent = "Gold" },
	CollectionSpeed = { glyph = "clock", accent = "Purple" },
	ScrapFlow = { glyph = "recycle", accent = "Green" },
	Rarity = { glyph = "star", accent = "Pink" },
}

local function formatEffect(definition, value: number): string
	local unit = definition.EffectUnit or ""
	if unit == "x" or string.find(unit, "multiplier") then
		return string.format("%.2fx", value)
	end
	if math.abs(value - math.floor(value)) < 0.005 then
		return string.format("%d%s", math.floor(value + 0.5), unit)
	end
	return string.format("%.2f%s", value, unit)
end

--[[
	One upgrade row, ready for Rows.UpgradeCard.

	Cost and effect come from GameMath -- the same functions UpgradeService uses
	to charge the player -- so the displayed price is the real price.
]]
local function effectAt(definition, level: number): number
	return GameMath.incrementalUpgradeEffect(
		definition.BaseEffect,
		definition.EffectPerLevel,
		level,
		definition.EffectCurve,
		definition.CurvePower,
		definition.EffectCap
	)
end

local function costAt(definition, level: number): number
	return GameMath.incrementalUpgradeCost(
		definition.BaseCost,
		definition.GrowthRate,
		definition.CostPower,
		level,
		Environment.MaximumMoney
	)
end

local function maximumFor(definition, prestigeCount: number): number
	return GameMath.upgradeMaximumLevel(
		definition.BaseMaximumLevel,
		definition.LevelsPerPrestige,
		prestigeCount
	)
end

function GameData.upgradeView(upgradeId: string, level: number, prestigeCount: number)
	local definition = UpgradeConfig.ById[upgradeId]
	if not definition then
		return nil
	end

	local maximum = maximumFor(definition, prestigeCount)
	local maxed = level >= maximum
	local style = UPGRADE_STYLE[upgradeId] or { glyph = "upgrade", accent = "Green" }

	return {
		id = upgradeId,
		name = definition.DisplayName,
		glyph = style.glyph,
		accent = style.accent,
		level = level,
		maxLevel = maximum,
		maxed = maxed,
		current = formatEffect(definition, effectAt(definition, level)),
		next = if maxed then nil else formatEffect(definition, effectAt(definition, level + 1)),
		price = if maxed then 0 else costAt(definition, level),
	}
end

--- Total cost and levels gained for a bulk purchase, using the real curve.
function GameData.bulkUpgrade(
	upgradeId: string,
	level: number,
	amount: string,
	money: number,
	prestigeCount: number
)
	local definition = UpgradeConfig.ById[upgradeId]
	if not definition then
		return 0, 0
	end

	local maximum = maximumFor(definition, prestigeCount)
	local requested = if amount == "x5" then 5 elseif amount == "MAX" then math.huge else 1

	local total, gained, current = 0, 0, level
	while gained < requested and current < maximum do
		local price = costAt(definition, current)
		if amount == "MAX" and total + price > money then
			break
		end
		total += price
		gained += 1
		current += 1
	end

	return total, gained
end

function GameData.upgradeOrder(): { string }
	return UpgradeConfig.Order
end

--------------------------------------------------------------------------------
-- Areas
--------------------------------------------------------------------------------

local AREA_STYLE = {
	FrontYard = { glyph = "ground", tier = 1 },
	WorkshopYard = { glyph = "gear", tier = 2 },
	VehicleGraveyard = { glyph = "scrap", tier = 3 },
}

function GameData.areas(): { any }
	local list = {}
	for _, areaId in ipairs(AreaConfig.Order) do
		local definition = AreaConfig.ById[areaId]
		local style = AREA_STYLE[areaId] or { glyph = "pin", tier = 1 }

		-- Headline the highest-value scrap the area can drop.
		local bestName, bestValue = "-", 0
		for _, scrapId in ipairs(definition.ScrapIds) do
			local scrap = ScrapConfig.ById[scrapId]
			if scrap and scrap.BaseValue > bestValue then
				bestValue = scrap.BaseValue
				bestName = scrap.DisplayName
			end
		end

		table.insert(list, {
			id = areaId,
			name = definition.DisplayName,
			tier = style.tier,
			glyph = style.glyph,
			cost = definition.UnlockPrice,
			bestScrap = bestName,
			bestValue = bestValue,
		})
	end
	return list
end

--------------------------------------------------------------------------------
-- Magnets and consumables
--------------------------------------------------------------------------------

function GameData.magnets(): { any }
	local list = {}
	for _, magnetId in ipairs(InventoryConfig.MagnetOrder) do
		local definition = InventoryConfig.Magnets[magnetId]
		table.insert(list, {
			id = magnetId,
			name = definition.DisplayName,
			rarity = GameData.magnetRarity[magnetId] or "Normal",
			description = definition.Description or "",
			range = definition.BaseRange,
			strength = definition.BaseStrength,
			shopPrice = definition.ShopPrice,
			image = definition.IconId,
		})
	end
	return list
end

function GameData.consumables(): { any }
	local list = {}
	for _, itemId in ipairs(InventoryConfig.ConsumableOrder) do
		local definition = InventoryConfig.Consumables[itemId]
		table.insert(list, {
			id = itemId,
			name = definition.DisplayName,
			rarity = GameData.consumableRarity[itemId] or "Gold",
			description = definition.Description or "",
			duration = definition.DurationSeconds,
			image = definition.IconId,
		})
	end
	return list
end

--[[
	Consumables indexed by the boost they grant. `activeBoosts` arrives from the
	server keyed by `BoostId` ("CashBoost"), but everything a player recognises --
	the name, the description, the bottle art -- lives on the consumable that
	granted it, so the HUD needs the mapping back.
]]
local boostToConsumable: { [string]: any } = {}
for _, itemId in ipairs(InventoryConfig.ConsumableOrder) do
	local definition = InventoryConfig.Consumables[itemId]
	if definition and definition.BoostId then
		boostToConsumable[definition.BoostId] = definition
	end
end

--[[
	`PlayerData.ActiveBoosts` is keyed by expiry field -- "CashBoostEndsAt" -- while
	the consumable declares `BoostId = "CashBoost"`. Accept either spelling so the
	caller can pass the raw snapshot key.
]]
function GameData.boostId(key: string): string
	return (string.gsub(key, "EndsAt$", ""))
end

--- The potion behind an active boost, or nil for a boost no consumable grants
--- (an event or admin effect), which the caller should render by id.
function GameData.boost(boostId: string): any?
	local definition = boostToConsumable[GameData.boostId(boostId)]
	if not definition then
		return nil
	end
	return {
		id = boostId,
		itemId = definition.Id,
		name = definition.DisplayName,
		description = definition.Description or "",
		image = definition.IconId,
	}
end

--------------------------------------------------------------------------------
-- Pets
--------------------------------------------------------------------------------

--- Every configured pet, with the owned count folded in.
function GameData.pets(owned: { [string]: number }): { any }
	local list = {}

	local function push(petId: string)
		local definition = PetConfig.Pets[petId]
		if not definition then
			return
		end
		local count = owned[petId] or 0
		table.insert(list, {
			id = petId,
			name = definition.DisplayName,
			rarity = definition.Rarity,
			bonus = string.format(
				"+%d%% Cash",
				math.floor((definition.MoneyMultiplier - 1) * 100 + 0.5)
			),
			description = definition.Description,
			eggId = definition.EggId,
			premium = definition.Premium == true,
			owned = count > 0,
			count = count,
			image = definition.IconAssetId,
		})
	end

	-- Egg order first, then the premium pets, so the grid reads as progression.
	for _, eggId in ipairs(PetConfig.EggOrder) do
		for _, petId in ipairs(PetConfig.Eggs[eggId].PetIds) do
			push(petId)
		end
	end
	for _, petId in ipairs(PetConfig.PremiumOrder) do
		push(petId)
	end

	return list
end

function GameData.eggs(unlockedAreas: { [string]: boolean }): { any }
	local list = {}
	for _, eggId in ipairs(PetConfig.EggOrder) do
		local definition = PetConfig.Eggs[eggId]
		table.insert(list, {
			id = eggId,
			name = definition.DisplayName,
			price = definition.Price,
			requiredArea = definition.RequiredArea,
			unlocked = unlockedAreas[definition.RequiredArea] == true,
			petCount = #definition.PetIds,
			image = definition.IconAssetId,
		})
	end
	return list
end

--[[
	Everything the summon window needs about one egg: its six pets in roll order,
	each with the chance of getting it, whether the player owns one already, and the
	model id to render.

	The Secret is reported with `hidden = true` rather than its real chance. Showing
	"0.20%" tells a player the pet is not worth waiting for; "?%" is the whole point
	of a secret.
]]
function GameData.eggRoll(eggId: string, ownedPets: { [string]: number }?): any?
	local definition = PetConfig.Eggs[eggId]
	if definition == nil then
		return nil
	end

	local owned = ownedPets or {}
	local pets = {}
	for index, petId in ipairs(definition.PetIds) do
		local pet = PetConfig.Pets[petId]
		local secret = pet.Rarity == "Secret"
		table.insert(pets, {
			id = petId,
			name = pet.DisplayName,
			rarity = pet.Rarity,
			-- Model ids match `ReplicatedStorage.PetModels`, published by PetService.
			model = petId,
			owned = (owned[petId] or 0) > 0,
			count = owned[petId] or 0,
			chance = pet.RollWeight / PetConfig.RollTotal,
			hidden = secret,
			secret = secret,
			slot = index,
		})
	end

	return {
		id = eggId,
		name = definition.DisplayName,
		price = definition.Price,
		requiredArea = definition.RequiredArea,
		model = eggId,
		pets = pets,
	}
end

--[[
	Equip slots available right now: the base slot, plus purchased upgrades, plus
	the pass bonus. Mirrors PetService's own calculation.
]]
function GameData.petSlots(slotUpgradeLevel: number, entitlements: { [string]: boolean }): number
	local slots = PetConfig.BaseEquipSlots + math.max(0, math.floor(slotUpgradeLevel))
	if entitlements.ExtraPetSlots then
		slots += PetConfig.PassBonusSlots
	end
	return slots
end

--- Price of the next slot upgrade, or nil when they are all bought.
function GameData.nextPetSlotCost(slotUpgradeLevel: number): number?
	local nextLevel = math.max(0, math.floor(slotUpgradeLevel)) + 1
	if nextLevel > PetConfig.MaximumSlotUpgradeLevel then
		return nil
	end
	return PetConfig.SlotUpgradeCosts[nextLevel]
end

function GameData.petStorageCapacity(): number
	return PetConfig.BaseStorageCapacity
end

--------------------------------------------------------------------------------
-- Monetisation
--------------------------------------------------------------------------------

--[[
	Storefront presentation for each pass.

	`benefit` is deliberately separate from the config's `Description`: that one is
	written to be accurate, this one is written to sell, and it has to fit two short
	lines on a card. `accent` is the card's colour identity, `tier` how loud it is
	(1 plain, 3 animated), and `badge` a key of `Shop.BADGES`.

	Adding a pass means adding a row here. Nothing in the shop layout changes.
]]
local PASS_STYLE = {
	--[[
		The flagship: two columns wide, with a list of what you get instead of one
		line. `features` is what earns the width -- a wide card carrying a single
		sentence is just a card with more empty space in it.
	]]
	DoubleCash = {
		glyph = "coin",
		accent = "Gold",
		tier = 3,
		badge = "Popular",
		layout = "feature",
		span = 2,
		pattern = "sunburst",
		benefit = "Double all scrap sale earnings, permanently.",
		features = {
			{
				glyph = "coin",
				title = "Double Sale Value",
				note = "Every scrap sale pays out twice.",
			},
			{
				glyph = "upgrade",
				title = "Permanent",
				note = "Never expires and never runs out.",
			},
			{
				glyph = "recycle",
				title = "Survives Rebirth",
				note = "Keeps paying after every reset.",
			},
		},
	},
	StoragePlus = {
		glyph = "crate",
		accent = "Cyan",
		tier = 2,
		pattern = "dots",
		benefit = "Carry 50% more scrap before you have to sell.",
	},
	FastCollector = {
		glyph = "bolt",
		accent = "Blue",
		tier = 2,
		pattern = "rings",
		benefit = "Pull in scrap much faster, forever.",
	},
	--[[
		Sits beside the flagship in the top row, so it gets the asymmetric shape --
		art left, title beside it. Two different silhouettes in one row is the whole
		reason the shelf does not read as a table.
	]]
	QuantumMagnet = {
		glyph = "magnet",
		accent = "Pink",
		tier = 3,
		premium = true,
		badge = "Premium",
		featured = true,
		layout = "hero",
		pattern = "sunburst",
		benefit = "The strongest magnet in the yard. Never upgrade again.",
		features = {
			{
				glyph = "magnet",
				title = "25 Strength, 32 Range",
				note = "Beats every magnet you can craft.",
			},
			{
				glyph = "lock",
				title = "Pass Exclusive",
				note = "Not obtainable any other way.",
			},
		},
	},
	ExtraPetSlots = {
		glyph = "paw",
		accent = "Yellow",
		tier = 2,
		pattern = "sunburst",
		benefit = "Equip two extra pets at the same time.",
	},
	--[[
		The three premium pets. Tier 3 because they are the top of the price ladder
		and the card should say so before the price is read; accents follow each
		definition's own `Color`, so the shop agrees with the rest of the game.
	]]
	--[[
		Three different glyphs rather than `paw` on all three: `Assets.Icons.paw` is
		crown artwork, so sharing it put four identical crowns in one row. These are
		placeholders that read as distinct until the real icons land -- prompts in
		`docs/ICON_PROMPTS.md`.
	]]
	SingularityPet = {
		glyph = "star",
		accent = "Cyan",
		tier = 3,
		premium = true,
		badge = "Premium",
		pattern = "rings",
		benefit = "Doubles whatever your best pet already does.",
	},
	DemonicGhostPet = {
		glyph = "pet",
		accent = "Red",
		tier = 3,
		premium = true,
		badge = "Premium",
		pattern = "dots",
		benefit = "Every pet bonus you own, 35% stronger.",
	},
	--[[
		The most expensive thing in the shop, so it closes the passes shelf as a wide
		hero rather than one more tile in a row of three.
	]]
	SinisterLordPet = {
		glyph = "trophy",
		accent = "Purple",
		tier = 3,
		premium = true,
		badge = "Exclusive",
		layout = "hero",
		pattern = "sunburst",
		benefit = "The best pet in the game. Doubles every pet bonus.",
		features = {
			{
				glyph = "paw",
				title = "Doubles Every Pet Bonus",
				note = "Applies to your whole equipped team.",
			},
			{
				glyph = "trophy",
				title = "The Strongest Pet",
				note = "Nothing else in the game beats it.",
			},
		},
	},
}

function GameData.passes(): { any }
	local list = {}
	for _, passId in ipairs(MonetizationConfig.PassOrder) do
		local definition = MonetizationConfig.Passes[passId]
		local style = PASS_STYLE[passId] or { glyph = "star", accent = "Blue" }
		table.insert(list, {
			id = passId,
			name = definition.DisplayName,
			description = definition.Description or "",
			glyph = style.glyph,
			--[[
				Real art the moment one is uploaded, glyph until then. Prompts for the
				eight icons and the ids they map to are in `docs/ICON_PROMPTS.md`.
			]]
			image = Assets.imageId("pass", passId),
			accent = style.accent,
			premium = style.premium,
			-- Selling copy, falling back to the config's own wording.
			benefit = style.benefit or definition.Description or "",
			tier = style.tier or 1,
			badge = style.badge,
			featured = style.featured,
			--[[
				Card shape. `ShopScreen` packs three columns and only reads these -- which
				means the shelf is rearranged from here, not from layout code.
			]]
			layout = style.layout,
			span = style.span,
			pattern = style.pattern,
			features = style.features,
			--[[
				Presentation only: Roblox owns and confirms what is actually charged.
				Shown so a card is not priceless while the MarketplaceIds are still 0.
			]]
			robux = definition.DisplayPrice,
			marketplaceId = definition.MarketplaceId,
		})
	end
	return list
end

--[[
	Same idea for one-off products. The tier ladder is doing real work here: a bigger
	cash pack is a brighter, busier card, so "more expensive" reads as "more
	valuable" before the price is even read.
]]
local PRODUCT_STYLE = {
	CashSmall = {
		glyph = "crate",
		accent = "Green",
		tier = 1,
		pattern = "dots",
		benefit = "A quick top-up to get moving again.",
	},
	CashMedium = {
		glyph = "crate",
		accent = "Cyan",
		tier = 2,
		bestValue = true,
		badge = "BestValue",
		pattern = "rings",
		benefit = "The sweet spot. Far more cash per Robux.",
	},
	CashLarge = {
		glyph = "coin",
		accent = "Gold",
		tier = 3,
		badge = "Popular",
		featured = true,
		pattern = "sunburst",
		benefit = "A mountain of cash. Skip straight to the good upgrades.",
	},
	BoosterPair = {
		glyph = "potion",
		accent = "Purple",
		tier = 1,
		pattern = "dots",
		benefit = "Two potions of your choosing.",
	},
	BoosterBundle = {
		glyph = "potion",
		accent = "Pink",
		tier = 2,
		pattern = "rings",
		benefit = "A full set of boosts, ready to drink.",
	},
	MegaBundle = {
		glyph = "star",
		accent = "Orange",
		tier = 3,
		bestValue = true,
		badge = "BestValue",
		pattern = "sunburst",
		benefit = "Everything at once, for far less than buying it apart.",
	},
	--[[
		Seven products means the last row would hold one lonely card. Giving the
		closer two columns turns that gap into a deliberate wide finish.
	]]
	SkipRebirth = {
		glyph = "recycle",
		accent = "Blue",
		tier = 2,
		layout = "feature",
		span = 2,
		pattern = "rings",
		benefit = "Jump a whole rebirth without the grind.",
		features = {
			{
				glyph = "recycle",
				title = "Instant Rebirth",
				note = "No cash requirement to meet.",
			},
			{
				glyph = "upgrade",
				title = "Keeps Every Bonus",
				note = "Counts exactly like a normal rebirth.",
			},
		},
	},
}

--- `kind` is "cash", "booster" or "all".
function GameData.products(kind: string): { any }
	local cashIds = { CashSmall = true, CashMedium = true, CashLarge = true }

	local list = {}
	for _, productId in ipairs(MonetizationConfig.ProductOrder) do
		local isCash = cashIds[productId] == true
		local include = kind == "all"
			or (kind == "cash" and isCash)
			or (kind == "booster" and not isCash)
		if include then
			local definition = MonetizationConfig.Products[productId]
			local style = PRODUCT_STYLE[productId] or { glyph = "crate", tier = 1 }
			table.insert(list, {
				id = productId,
				name = definition.DisplayName,
				amount = definition.ShortLabel or definition.DisplayName,
				description = definition.Description or "",
				glyph = style.glyph,
				accent = style.accent,
				tier = style.tier,
				bestValue = style.bestValue,
				badge = style.badge,
				featured = style.featured,
				-- Card shape; see the note on the same fields in `passes()`.
				layout = style.layout,
				span = style.span,
				pattern = style.pattern,
				features = style.features,
				benefit = style.benefit or definition.Description or "",
				robux = definition.DisplayPrice,
				marketplaceId = definition.MarketplaceId,
			})
		end
	end
	return list
end

--------------------------------------------------------------------------------
-- Scrap collection index
--------------------------------------------------------------------------------

--- Stable scrap order: area order first, then each area's configured pool.
function GameData.scrapOrder(): { string }
	local seen, order = {}, {}
	for _, areaId in ipairs(AreaConfig.Order) do
		for _, scrapId in ipairs(AreaConfig.ById[areaId].ScrapIds) do
			if not seen[scrapId] then
				seen[scrapId] = true
				table.insert(order, scrapId)
			end
		end
	end
	return order
end

function GameData.scrapIndex(discovered: { [string]: any }): { any }
	local list = {}
	for _, scrapId in ipairs(GameData.scrapOrder()) do
		local definition = ScrapConfig.ById[scrapId]
		local record = discovered[scrapId]
		local found = type(record) == "table" and record.Discovered == true

		if definition then
			--[[
				Which 3D preview the index should draw, best first. A discovered scrap shows
				the highest rarity it has been found at -- that is the trophy -- and falls
				back to the plain model when no art exists for that tier. Undiscovered ones
				ask for Normal so the silhouette is the real shape.

				Names must match `ScrapVariants.PreviewName` on the server.
			]]
			local bestVariant = if found and record.HighestVariant
				then record.HighestVariant
				else "Normal"
			table.insert(list, {
				id = scrapId,
				name = definition.DisplayName,
				rarity = if found and record.HighestVariant
					then (GameData.variantRarity[record.HighestVariant] or "Normal")
					else "Normal",
				discovered = found,
				best = definition.BaseValue,
				collected = if found then (record.TotalCollected or 0) else 0,
				model = { `{scrapId}_{bestVariant}`, `{scrapId}_Normal`, scrapId },
			})
		end
	end
	return list
end

--------------------------------------------------------------------------------
-- Prestige
--------------------------------------------------------------------------------

function GameData.prestige(money: number, gears: number, prestigeCount: number)
	local requirement = GameMath.prestigeRequirement(
		PrestigeConfig.BaseMoneyRequirement,
		PrestigeConfig.RequirementGrowth,
		prestigeCount,
		Environment.MaximumMoney
	)
	local reward = GameMath.scaledPrestigeGearReward(
		money,
		requirement,
		prestigeCount,
		PrestigeConfig.MaximumGearsPerPrestige
	)

	return {
		current = prestigeCount,
		money = money,
		requirement = requirement,
		gearsReward = reward,
		ready = money >= requirement,
		shortfall = math.max(0, requirement - money),
		permanentBonus = string.format(
			"%.2fx Cash",
			GameMath.gearValueMultiplier(
				gears,
				PrestigeConfig.GearPower,
				PrestigeConfig.MaximumGearValueMultiplier
			)
		),
		lose = { "Cash", "Normal upgrades", "Area progress" },
		keep = { "Magnets", "Pets", "Potions", "Gears", "Cosmetics" },
	}
end

return GameData
