--!nonstrict
--[[
	Mock.luau
	Sample game data for the UI kit.

	This is the single place the screens read their content from, so swapping in
	a real data layer means replacing this module -- no screen changes. Numbers
	follow a believable incremental curve rather than round placeholders, which
	is what surfaces layout problems (long values, wide names) early.
]]

local Mock = {}

--------------------------------------------------------------------------------
-- Player
--------------------------------------------------------------------------------

Mock.player = {
	name = "MAKOGAI",
	displayName = "Makogai",
	cash = 337_800_000,
	gears = 42,
	eventTokens = 1_250,
	prestige = 4,
	totalScrap = 2_400_000,

	storage = 650,
	capacity = 1_000,
	storageValue = 12_450,

	area = "vehicle_graveyard",
	equippedMagnet = "advanced",
	equippedPets = { "scrap_pup", "magnet_drone", "gear_bot" },
	petSlots = 3,
	ownedPets = 14,
	maxPets = 50,

	inventoryOwned = 24,
	inventoryTotal = 154,
	collectionFound = 82,
	collectionTotal = 154,

	autoCollect = true,
}

--------------------------------------------------------------------------------
-- Upgrades
--------------------------------------------------------------------------------

--[[
	Each upgrade is anchored at its starting level: `base` is the value shown at
	`level`, and every level after that adds `step`. Prices grow geometrically
	from `basePrice`. Buying in the UI recomputes both, so the arrow on an
	upgrade card always shows a real next value.
]]
Mock.upgrades = {
	{
		id = "magnet_strength",
		name = "Magnet Strength",
		glyph = "magnet",
		accent = "Red",
		level = 18,
		maxLevel = 60,
		base = 2.8,
		step = 0.2,
		unit = "mult",
		basePrice = 68_400,
		growth = 1.15,
	},
	{
		id = "magnet_range",
		name = "Magnet Range",
		glyph = "pin",
		accent = "Cyan",
		level = 12,
		maxLevel = 60,
		base = 25,
		step = 3,
		unit = "studs",
		basePrice = 42_500,
		growth = 1.15,
	},
	{
		id = "storage_capacity",
		name = "Storage Capacity",
		glyph = "crate",
		accent = "Orange",
		level = 9,
		maxLevel = 50,
		base = 1_000,
		step = 250,
		unit = "count",
		basePrice = 96_000,
		growth = 1.18,
	},
	{
		id = "movement_speed",
		name = "Movement Speed",
		glyph = "bolt",
		accent = "Yellow",
		level = 7,
		maxLevel = 25,
		base = 22,
		step = 2,
		unit = "speed",
		basePrice = 128_000,
		growth = 1.22,
	},
	{
		id = "scrap_value",
		name = "Scrap Value",
		glyph = "coin",
		accent = "Gold",
		level = 22,
		maxLevel = 80,
		base = 4.4,
		step = 0.2,
		unit = "mult",
		basePrice = 214_000,
		growth = 1.16,
	},
	{
		id = "collection_speed",
		name = "Collection Speed",
		glyph = "clock",
		accent = "Purple",
		level = 14,
		maxLevel = 40,
		base = 1.7,
		step = 0.1,
		unit = "mult",
		basePrice = 305_000,
		growth = 1.17,
	},
	{
		-- Already maxed, so the screen always demonstrates the MAXED state.
		id = "scrap_flow",
		name = "Scrap Flow",
		glyph = "recycle",
		accent = "Green",
		level = 40,
		maxLevel = 40,
		base = 9,
		step = -0.2,
		unit = "respawn",
		basePrice = 480_000,
		growth = 1.2,
	},
}

--------------------------------------------------------------------------------
-- Magnets
--------------------------------------------------------------------------------

Mock.magnets = {
	{
		id = "basic",
		name = "Basic Magnet",
		rarity = "Normal",
		description = "A simple but reliable magnet.",
		range = 20,
		strength = 1.5,
		speed = 1.0,
		owned = true,
	},
	{
		id = "golden",
		name = "Golden Magnet",
		rarity = "Gold",
		description = "Pulls scrap that others walk past.",
		range = 26,
		strength = 2.2,
		speed = 1.3,
		owned = true,
	},
	{
		id = "advanced",
		name = "Advanced Magnet",
		rarity = "Diamond",
		description = "Workshop grade. Handles the heavy stuff.",
		range = 34,
		strength = 3.4,
		speed = 1.8,
		owned = true,
	},
	{
		id = "emerald",
		name = "Emerald Magnet",
		rarity = "Emerald",
		description = "Grown, not built. Nobody asks questions.",
		range = 40,
		strength = 4.6,
		speed = 2.1,
		owned = true,
	},
	{
		id = "blood",
		name = "Blood Magnet",
		rarity = "Blood",
		description = "Runs hot. Very hot.",
		range = 48,
		strength = 6.0,
		speed = 2.5,
		owned = false,
		unlock = "Unlock at Prestige 5",
	},
	{
		id = "electric",
		name = "Electric Magnet",
		rarity = "Electric",
		description = "Arcs across the whole yard.",
		range = 56,
		strength = 7.8,
		speed = 3.0,
		owned = false,
		unlock = "Unlock at Prestige 8",
	},
	{
		id = "quantum",
		name = "Quantum Magnet",
		rarity = "Radioactive",
		description = "Collects scrap that has not spawned yet.",
		range = 70,
		strength = 12.0,
		speed = 4.2,
		owned = false,
		unlock = "Game Pass",
	},
	{
		id = "admin",
		name = "Admin Magnet",
		rarity = "Admin",
		description = "You should not be seeing this.",
		range = 120,
		strength = 50.0,
		speed = 10.0,
		owned = false,
		unlock = "Staff only",
	},
}

--------------------------------------------------------------------------------
-- Skins
--------------------------------------------------------------------------------

Mock.skins = {
	{ id = "skin_rust", name = "Rusted", rarity = "Normal", owned = true, equipped = true },
	{ id = "skin_chrome", name = "Chrome", rarity = "Diamond", owned = true },
	{ id = "skin_gold", name = "Solid Gold", rarity = "Gold", owned = true },
	{ id = "skin_toxic", name = "Toxic Drip", rarity = "Radioactive", owned = true },
	{
		id = "skin_circuit",
		name = "Circuit",
		rarity = "Electric",
		owned = false,
		unlock = "Prestige 6",
	},
	{
		id = "skin_crimson",
		name = "Crimson",
		rarity = "Blood",
		owned = false,
		unlock = "Prestige 9",
	},
	{ id = "skin_leaf", name = "Overgrown", rarity = "Emerald", owned = true },
	{ id = "skin_void", name = "Void", rarity = "Admin", owned = false, unlock = "Staff only" },
}

--------------------------------------------------------------------------------
-- Potions
--------------------------------------------------------------------------------

Mock.potions = {
	{
		id = "cash",
		name = "Cash Potion",
		rarity = "Gold",
		effect = "2x Cash",
		duration = 900,
		owned = 12,
		tint = Color3.fromHex("69EF28"),
		description = "Doubles every payout while it lasts.",
	},
	{
		id = "strength",
		name = "Magnet Strength Potion",
		rarity = "Blood",
		effect = "2.5x Strength",
		duration = 600,
		owned = 5,
		tint = Color3.fromHex("FF5757"),
		description = "Rips heavier scrap out of the pile.",
	},
	{
		id = "luck",
		name = "Luck Potion",
		rarity = "Emerald",
		effect = "2x Luck",
		duration = 900,
		owned = 3,
		tint = Color3.fromHex("21E5F5"),
		description = "Better odds on rare scrap spawns.",
	},
	{
		id = "god",
		name = "God Potion",
		rarity = "Radioactive",
		effect = "All boosts 3x",
		duration = 300,
		owned = 1,
		tint = Color3.fromHex("DBFF3D"),
		description = "Everything at once. Use it well.",
	},
}

--------------------------------------------------------------------------------
-- Pets
--------------------------------------------------------------------------------

Mock.pets = {
	{
		id = "scrap_pup",
		name = "Scrap Pup",
		rarity = "Rare",
		bonus = "+12% Scrap Value",
		description = "Found in the starter yard. Never lets go.",
		owned = true,
	},
	{
		id = "magnet_drone",
		name = "Magnet Drone",
		rarity = "Epic",
		bonus = "+8% Magnet Range",
		description = "Hovers just above the pile, scanning.",
		owned = true,
	},
	{
		id = "gear_bot",
		name = "Gear Bot",
		rarity = "Legendary",
		bonus = "+15% Collection Speed",
		description = "Built from parts nobody claimed.",
		owned = true,
	},
	{
		id = "rust_rat",
		name = "Rust Rat",
		rarity = "Common",
		bonus = "+4% Scrap Value",
		owned = true,
	},
	{
		id = "bolt_bug",
		name = "Bolt Bug",
		rarity = "Common",
		bonus = "+5% Collection Speed",
		owned = true,
	},
	{ id = "crane_cat", name = "Crane Cat", rarity = "Rare", bonus = "+10% Storage", owned = true },
	{
		id = "weld_wolf",
		name = "Weld Wolf",
		rarity = "Epic",
		bonus = "+11% Magnet Strength",
		owned = true,
	},
	{ id = "junk_jelly", name = "Junk Jelly", rarity = "Rare", bonus = "+9% Luck", owned = true },
	{
		id = "piston_pig",
		name = "Piston Pig",
		rarity = "Epic",
		bonus = "+13% Movement Speed",
		owned = true,
	},
	{
		id = "chrome_crab",
		name = "Chrome Crab",
		rarity = "Legendary",
		bonus = "+18% Scrap Value",
		owned = true,
	},
	{
		id = "turbo_toad",
		name = "Turbo Toad",
		rarity = "Rare",
		bonus = "+7% Scrap Flow",
		owned = true,
	},
	{
		id = "salvage_snake",
		name = "Salvage Snake",
		rarity = "Epic",
		bonus = "+12% Magnet Range",
		owned = true,
	},
	{
		id = "core_cub",
		name = "Core Cub",
		rarity = "Legendary",
		bonus = "+20% Collection Speed",
		owned = true,
	},
	{
		id = "titan_tortoise",
		name = "Titan Tortoise",
		rarity = "Legendary",
		bonus = "+25% Storage",
		owned = true,
	},
	{
		id = "void_vulture",
		name = "Void Vulture",
		rarity = "Mythic",
		bonus = "+40% Scrap Value",
		description = "Circles the deepest part of the yard.",
		owned = false,
		unlock = "Hatch from a Mythic Egg",
	},
	{
		id = "quantum_quokka",
		name = "Quantum Quokka",
		rarity = "Mythic",
		bonus = "+35% All Stats",
		owned = false,
		unlock = "Prestige 12",
	},
}

--------------------------------------------------------------------------------
-- Areas
--------------------------------------------------------------------------------

Mock.areas = {
	{
		id = "starter_yard",
		name = "Starter Yard",
		tier = 1,
		cost = 0,
		unlocked = true,
		bestScrap = "Tin Can",
		bestValue = 12,
		glyph = "ground",
	},
	{
		id = "workshop",
		name = "Workshop",
		tier = 2,
		cost = 25_000,
		unlocked = true,
		bestScrap = "Power Drill",
		bestValue = 340,
		glyph = "gear",
	},
	{
		id = "vehicle_graveyard",
		name = "Vehicle Graveyard",
		tier = 3,
		cost = 850_000,
		unlocked = true,
		bestScrap = "Engine Block",
		bestValue = 4_250,
		glyph = "scrap",
	},
	{
		id = "industrial_yard",
		name = "Industrial Yard",
		tier = 4,
		cost = 12_500_000,
		unlocked = true,
		bestScrap = "Turbine Blade",
		bestValue = 38_000,
		glyph = "crate",
	},
	{
		id = "scrap_harbor",
		name = "Scrap Harbor",
		tier = 5,
		cost = 240_000_000,
		unlocked = false,
		bestScrap = "Ship Anchor",
		bestValue = 410_000,
		glyph = "pin",
	},
	{
		id = "military_salvage",
		name = "Military Salvage",
		tier = 6,
		cost = 6_800_000_000,
		unlocked = false,
		bestScrap = "Tank Hull",
		bestValue = 5_200_000,
		glyph = "medal",
	},
	{
		id = "space_junkyard",
		name = "Space Junkyard",
		tier = 7,
		cost = 145_000_000_000,
		unlocked = false,
		bestScrap = "Satellite Core",
		bestValue = 74_000_000,
		glyph = "star",
	},
}

--------------------------------------------------------------------------------
-- Prestige
--------------------------------------------------------------------------------

Mock.prestige = {
	current = 4,
	cash = 12_400_000,
	requirement = 20_000_000,
	gearsReward = 3,
	permanentBonus = "+15% Cash",
	nextBonus = "+20% Cash",
	skipRobux = 199,
	lose = { "Cash", "Normal upgrades", "Area progress" },
	keep = { "Magnets", "Pets", "Potions", "Gears", "Cosmetics" },
}

--------------------------------------------------------------------------------
-- Shop
--------------------------------------------------------------------------------

Mock.gamePasses = {
	{
		id = "cash2x",
		name = "2x Cash Forever",
		description = "Every payout doubled, permanently.",
		glyph = "coin",
		accent = "Gold",
		robux = 199,
	},
	{
		id = "mega_storage",
		name = "Mega Storage",
		description = "Triples your scrap storage capacity.",
		glyph = "crate",
		accent = "Orange",
		robux = 149,
	},
	{
		id = "turbo_collector",
		name = "Turbo Collector",
		description = "Auto-collect, twice as fast.",
		glyph = "bolt",
		accent = "Yellow",
		robux = 249,
	},
	{
		id = "quantum_magnet",
		name = "Quantum Magnet",
		description = "The strongest magnet in the game. Yours instantly.",
		glyph = "magnet",
		accent = "Purple",
		robux = 799,
		premium = true,
	},
	{
		id = "pet_slots",
		name = "+2 Pet Slots",
		description = "Equip five pets instead of three.",
		glyph = "paw",
		accent = "Pink",
		robux = 179,
	},
}

Mock.cashProducts = {
	{
		id = "cash_crate",
		name = "Cash Crate",
		amount = "$500K",
		glyph = "crate",
		robux = 99,
		tier = 1,
	},
	{
		id = "cash_vault",
		name = "Cash Vault",
		amount = "$5M",
		glyph = "crate",
		robux = 399,
		tier = 2,
		bonus = "+25% BONUS",
		bestValue = true,
	},
	{
		id = "cash_mountain",
		name = "Cash Mountain",
		amount = "$75M",
		glyph = "coin",
		robux = 1_999,
		tier = 3,
		bonus = "+60% BONUS",
	},
}

Mock.boosterProducts = {
	{
		id = "booster_pair",
		name = "Booster Pair",
		amount = "2 POTIONS",
		glyph = "potion",
		robux = 79,
		tier = 1,
	},
	{
		id = "booster_bundle",
		name = "Booster Bundle",
		amount = "8 POTIONS",
		glyph = "potion",
		robux = 299,
		tier = 2,
		bonus = "+2 FREE",
	},
	{
		id = "mega_starter",
		name = "Mega Starter Bundle",
		amount = "EVERYTHING",
		glyph = "star",
		robux = 899,
		tier = 3,
		bonus = "BEST DEAL",
		bestValue = true,
	},
}

--------------------------------------------------------------------------------
-- Daily rewards
--------------------------------------------------------------------------------

Mock.dailyRewards = {
	{ day = 1, label = "Cash", amount = "$25K", glyph = "coin", state = "claimed" },
	{ day = 2, label = "Potion", amount = "2x CASH", glyph = "potion", state = "claimed" },
	{ day = 3, label = "Cash", amount = "$250K", glyph = "coin", state = "claimed" },
	{ day = 4, label = "Pet Egg", amount = "RARE EGG", glyph = "paw", state = "current" },
	{ day = 5, label = "Boost", amount = "3x LUCK", glyph = "bolt", state = "locked" },
	{ day = 6, label = "Cash", amount = "$5M", glyph = "coin", state = "locked" },
	{
		day = 7,
		label = "Premium",
		amount = "GOD POTION",
		glyph = "star",
		state = "locked",
		premium = true,
	},
}

--------------------------------------------------------------------------------
-- Scrap index
--------------------------------------------------------------------------------

Mock.scrapIndex = {
	{
		id = "tin_can",
		name = "Tin Can",
		rarity = "Normal",
		discovered = true,
		best = 12,
		collected = 48_200,
	},
	{
		id = "bolt",
		name = "Loose Bolt",
		rarity = "Normal",
		discovered = true,
		best = 18,
		collected = 39_100,
	},
	{
		id = "hubcap",
		name = "Hubcap",
		rarity = "Normal",
		discovered = true,
		best = 46,
		collected = 21_400,
	},
	{
		id = "car_door",
		name = "Car Door",
		rarity = "Gold",
		discovered = true,
		best = 880,
		collected = 6_120,
	},
	{
		id = "engine_block",
		name = "Engine Block",
		rarity = "Gold",
		discovered = true,
		best = 4_250,
		collected = 2_480,
	},
	{
		id = "golden_engine",
		name = "Golden Engine",
		rarity = "Gold",
		discovered = true,
		best = 42_000,
		collected = 118,
	},
	{
		id = "turbine",
		name = "Turbine Blade",
		rarity = "Diamond",
		discovered = true,
		best = 38_000,
		collected = 940,
	},
	{
		id = "reactor",
		name = "Reactor Core",
		rarity = "Diamond",
		discovered = true,
		best = 210_000,
		collected = 62,
	},
	{ id = "anchor", name = "Ship Anchor", rarity = "Emerald", discovered = false },
	{ id = "propeller", name = "Ship Propeller", rarity = "Emerald", discovered = false },
	{ id = "tank_hull", name = "Tank Hull", rarity = "Blood", discovered = false },
	{ id = "missile", name = "Spent Missile", rarity = "Blood", discovered = false },
	{ id = "capacitor", name = "Arc Capacitor", rarity = "Electric", discovered = false },
	{ id = "satellite", name = "Satellite Core", rarity = "Radioactive", discovered = false },
	{ id = "warp_coil", name = "Warp Coil", rarity = "Radioactive", discovered = false },
	{ id = "admin_cube", name = "Admin Cube", rarity = "Admin", discovered = false },
}

--------------------------------------------------------------------------------
-- Plot cosmetics
--------------------------------------------------------------------------------

Mock.cosmetics = {
	GROUND = {
		{ id = "dirt", name = "Packed Dirt", rarity = "Normal", glyph = "ground", equipped = true },
		{ id = "gravel", name = "Gravel", rarity = "Normal", glyph = "ground" },
		{ id = "concrete", name = "Concrete", rarity = "Gold", glyph = "ground" },
		{
			id = "checker",
			name = "Checkerplate",
			rarity = "Diamond",
			glyph = "ground",
			state = "shop",
		},
		{ id = "grass", name = "Overgrown", rarity = "Emerald", glyph = "ground" },
		{
			id = "glow",
			name = "Glow Tile",
			rarity = "Electric",
			glyph = "ground",
			state = "prestige",
			requirement = "PRESTIGE 8",
		},
	},
	FENCE = {
		{ id = "wire", name = "Chain Link", rarity = "Normal", glyph = "fence", equipped = true },
		{ id = "wood", name = "Wooden Slats", rarity = "Normal", glyph = "fence" },
		{ id = "steel", name = "Steel Panels", rarity = "Gold", glyph = "fence" },
		{ id = "neon", name = "Neon Posts", rarity = "Electric", glyph = "fence", state = "shop" },
		{ id = "bone", name = "Scrap Bone", rarity = "Blood", glyph = "fence", state = "locked" },
	},
	CRUSHER = {
		{
			id = "basic_crusher",
			name = "Basic Crusher",
			rarity = "Normal",
			glyph = "gear",
			equipped = true,
		},
		{ id = "hydraulic", name = "Hydraulic", rarity = "Gold", glyph = "gear" },
		{ id = "shredder", name = "Shredder", rarity = "Diamond", glyph = "gear", state = "shop" },
		{
			id = "plasma",
			name = "Plasma Cutter",
			rarity = "Radioactive",
			glyph = "bolt",
			state = "prestige",
			requirement = "PRESTIGE 10",
		},
	},
	SIGN = {
		{
			id = "plank",
			name = "Painted Plank",
			rarity = "Normal",
			glyph = "sign",
			equipped = true,
		},
		{ id = "metal_sign", name = "Metal Sign", rarity = "Gold", glyph = "sign" },
		{ id = "led", name = "LED Board", rarity = "Electric", glyph = "sign", state = "shop" },
		{ id = "holo", name = "Hologram", rarity = "Admin", glyph = "sign", state = "locked" },
	},
	THEME = {
		{
			id = "classic",
			name = "Classic Yard",
			rarity = "Normal",
			glyph = "palette",
			equipped = true,
		},
		{ id = "sunset", name = "Sunset", rarity = "Gold", glyph = "palette" },
		{
			id = "toxic",
			name = "Toxic Waste",
			rarity = "Radioactive",
			glyph = "palette",
			state = "shop",
		},
		{
			id = "midnight",
			name = "Midnight",
			rarity = "Electric",
			glyph = "palette",
			state = "prestige",
			requirement = "PRESTIGE 6",
		},
	},
}

--------------------------------------------------------------------------------
-- Leaderboards
--------------------------------------------------------------------------------

Mock.leaderboards = {
	{
		id = "cash",
		title = "Most Cash",
		glyph = "coin",
		accent = "Green",
		rows = {
			{ player = "ScrapKing99", value = "$4.2Qa" },
			{ player = "MagnetMaster", value = "$1.8Qa" },
			{ player = "JunkLord", value = "$920T" },
			{ player = "Makogai", value = "$337.8M", highlight = true },
			{ player = "RustyRick", value = "$210M" },
			{ player = "BoltBandit", value = "$96M" },
			{ player = "YardHog", value = "$44M" },
			{ player = "TinTitan", value = "$12M" },
		},
	},
	{
		id = "prestiges",
		title = "Most Prestiges",
		glyph = "recycle",
		accent = "Purple",
		rows = {
			{ player = "RebirthRon", value = "412" },
			{ player = "LoopLegend", value = "388" },
			{ player = "ScrapKing99", value = "301" },
			{ player = "CycleCindy", value = "154" },
			{ player = "Makogai", value = "4", highlight = true },
		},
	},
	{
		id = "scrap",
		title = "Most Scrap",
		glyph = "scrap",
		accent = "Cyan",
		rows = {
			{ player = "HoarderHank", value = "88.2B" },
			{ player = "ScrapKing99", value = "71.4B" },
			{ player = "PileParker", value = "60.1B" },
			{ player = "Makogai", value = "2.4M", highlight = true },
		},
	},
}

--------------------------------------------------------------------------------
-- Active boosts shown in the HUD
--------------------------------------------------------------------------------

Mock.activeBoosts = {
	{ id = "cash", label = "2x Cash", seconds = 522, tint = Color3.fromHex("69EF28") },
	{ id = "luck", label = "2x Luck", seconds = 251, tint = Color3.fromHex("21E5F5") },
}

--------------------------------------------------------------------------------
-- Notifications used by the toast demo
--------------------------------------------------------------------------------

Mock.notifications = {
	{ title = "New Scrap Discovered!", body = "Engine Block", glyph = "scrap", accent = "Cyan" },
	{ title = "Area Unlocked!", body = "Vehicle Graveyard", glyph = "pin", accent = "Green" },
	{
		title = "Upgrade Purchased!",
		body = "Magnet Range Lv. 14",
		glyph = "upgrade",
		accent = "Blue",
	},
	{
		title = "Rare Scrap!",
		body = "Golden Engine",
		reward = "+ $4,250",
		glyph = "coin",
		accent = "Gold",
	},
}

--------------------------------------------------------------------------------
-- Lookup helpers
--------------------------------------------------------------------------------

local function indexById(list)
	local map = {}
	for _, entry in ipairs(list) do
		map[entry.id] = entry
	end
	return map
end

Mock.magnetsById = indexById(Mock.magnets)
Mock.petsById = indexById(Mock.pets)
Mock.areasById = indexById(Mock.areas)
Mock.potionsById = indexById(Mock.potions)
Mock.upgradesById = indexById(Mock.upgrades)

function Mock.find(list, id)
	for _, entry in ipairs(list) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

return Mock
