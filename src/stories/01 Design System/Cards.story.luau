--[[
	Every card in the kit, in every state.
	Item / locked / equipped, pets, upgrades, areas, rewards, index cells,
	cosmetics and leaderboard rows.

	Shop cards are NOT here: they have their own shapes, spans and backdrops now, and
	they live in `src/stories/10 Shop/Cards.story.luau` where those can be compared.
	This section used to render a `GamePassCard` that no longer exists.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)

local Harness = require(script.Parent.Parent.Harness)

local Theme = UI.Theme
local Cards = UI.Cards
local Rows = UI.Rows

local e = React.createElement

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Cards",
	summary = "Item, pet, upgrade, area, reward, collection, cosmetic and leaderboard cards.",
	controls = {
		Rarity = UILabs.Choose(Theme.RarityOrder, 3),
		Locked = UILabs.Boolean(false),
		Equipped = UILabs.Boolean(false),
	},
}, function(props)
	local controls = props.controls

	local itemStates = {
		e(Cards.ItemCard, {
			key = "Playground",
			name = "Advanced Magnet",
			rarity = controls.Rarity,
			glyph = "magnet",
			locked = controls.Locked,
			lockText = if controls.Locked then "Unlock at Prestige 5" else nil,
			equipped = controls.Equipped,
			onClick = function() end,
		}),
		e(
			Cards.MagnetCard,
			{ key = "Normal", name = "Basic Magnet", rarity = "Normal", onClick = function() end }
		),
		e(Cards.MagnetCard, {
			key = "Equipped",
			name = "Advanced Magnet",
			rarity = "Diamond",
			equipped = true,
			onClick = function() end,
		}),
		e(Cards.MagnetCard, {
			key = "Locked",
			name = "Blood Magnet",
			rarity = "Blood",
			locked = true,
			lockText = "Unlock at Prestige 5",
			onClick = function() end,
		}),
		e(Cards.PotionCard, {
			key = "Potion",
			name = "Cash Potion",
			rarity = "Gold",
			owned = 12,
			tint = Theme.Color.Positive,
			onClick = function() end,
		}),
		e(
			Cards.PotionCard,
			{ key = "PotionEmpty", name = "God Potion", rarity = "Radioactive", owned = 0 }
		),
	}

	local pets = {
		e(Cards.PetCard, {
			key = "Rare",
			name = "Scrap Pup",
			rarity = "Rare",
			bonus = "+12% Scrap Value",
			equipped = true,
			onClick = function() end,
		}),
		e(Cards.PetCard, {
			key = "Epic",
			name = "Magnet Drone",
			rarity = "Epic",
			bonus = "+8% Magnet Range",
			onClick = function() end,
		}),
		e(Cards.PetCard, {
			key = "Legendary",
			name = "Gear Bot",
			rarity = "Legendary",
			bonus = "+15% Collection Speed",
			onClick = function() end,
		}),
		e(Cards.PetCard, {
			key = "Mythic",
			name = "Void Vulture",
			rarity = "Mythic",
			bonus = "+40% Scrap Value",
			locked = true,
			lockText = "Hatch from a Mythic Egg",
		}),
		e(Cards.EmptySlot, { key = "Empty" }),
		e(Cards.EmptySlot, { key = "LockedSlot", glyph = "lock", text = "GAME PASS" }),
	}

	local upgrades = {
		e(Rows.UpgradeCard, {
			key = "Range",
			name = "Magnet Range",
			glyph = "pin",
			accent = Theme.Gradient.Cyan,
			level = 12,
			maxLevel = 60,
			current = "25 studs",
			next = "28 studs",
			price = 42_500,
			size = UDim2.fromOffset(860, 104),
		}),
		e(Rows.UpgradeCard, {
			key = "Unaffordable",
			name = "Scrap Value",
			glyph = "coin",
			accent = Theme.Gradient.Gold,
			level = 22,
			maxLevel = 80,
			current = "4.4x",
			next = "4.6x",
			price = 214_000,
			affordable = false,
			amount = "x5",
			size = UDim2.fromOffset(860, 104),
		}),
		e(Rows.UpgradeCard, {
			key = "Maxed",
			name = "Scrap Flow",
			glyph = "recycle",
			accent = Theme.Gradient.Green,
			level = 40,
			maxLevel = 40,
			current = "9.0s respawn",
			price = 0,
			size = UDim2.fromOffset(860, 104),
		}),
	}

	local areas = {
		e(Rows.AreaCard, {
			key = "Current",
			name = "Vehicle Graveyard",
			tier = 3,
			glyph = "scrap",
			unlocked = true,
			current = true,
			bestScrap = "Engine Block",
			bestValue = 4_250,
		}),
		e(Rows.AreaCard, {
			key = "Unlocked",
			name = "Industrial Yard",
			tier = 4,
			glyph = "crate",
			unlocked = true,
			bestScrap = "Turbine Blade",
			bestValue = 38_000,
		}),
		e(Rows.AreaCard, {
			key = "Locked",
			name = "Scrap Harbor",
			tier = 5,
			glyph = "pin",
			unlocked = false,
			cost = 240_000_000,
			bestScrap = "Ship Anchor",
			bestValue = 410_000,
		}),
	}

	local rewards = {
		e(Rows.RewardCard, {
			key = "Claimed",
			day = 1,
			label = "Cash",
			amount = "$25K",
			glyph = "coin",
			state = "claimed",
		}),
		e(Rows.RewardCard, {
			key = "Current",
			day = 4,
			label = "Pet Egg",
			amount = "RARE EGG",
			glyph = "paw",
			state = "current",
		}),
		e(Rows.RewardCard, {
			key = "Locked",
			day = 5,
			label = "Boost",
			amount = "3x LUCK",
			glyph = "bolt",
			state = "locked",
		}),
		e(Rows.RewardCard, {
			key = "Premium",
			day = 7,
			label = "Premium",
			amount = "GOD POTION",
			glyph = "star",
			state = "locked",
			premium = true,
		}),
	}

	local index = {
		e(Cards.CollectionCell, {
			key = "Found",
			name = "Engine Block",
			rarity = "Gold",
			discovered = true,
			best = 4_250,
			collected = 2_480,
		}),
		e(
			Cards.CollectionCell,
			{ key = "Unknown", name = "Ship Anchor", rarity = "Emerald", discovered = false }
		),
		e(Cards.CosmeticCard, {
			key = "Equipped",
			name = "Packed Dirt",
			rarity = "Normal",
			glyph = "ground",
			equipped = true,
		}),
		e(
			Cards.CosmeticCard,
			{ key = "Owned", name = "Concrete", rarity = "Gold", glyph = "ground" }
		),
		e(Cards.CosmeticCard, {
			key = "Shop",
			name = "Checkerplate",
			rarity = "Diamond",
			glyph = "ground",
			state = "shop",
		}),
		e(Cards.CosmeticCard, {
			key = "Prestige",
			name = "Glow Tile",
			rarity = "Electric",
			glyph = "ground",
			state = "prestige",
			requirement = "PRESTIGE 8",
		}),
	}

	local leaderboard = {
		e(Rows.LeaderboardRow, {
			key = "First",
			rank = 1,
			player = "ScrapKing99",
			value = "$4.2Qa",
			size = UDim2.fromOffset(420, 58),
		}),
		e(Rows.LeaderboardRow, {
			key = "Second",
			rank = 2,
			player = "MagnetMaster",
			value = "$1.8Qa",
			size = UDim2.fromOffset(420, 58),
		}),
		e(Rows.LeaderboardRow, {
			key = "Third",
			rank = 3,
			player = "JunkLord",
			value = "$920T",
			size = UDim2.fromOffset(420, 58),
		}),
		e(Rows.LeaderboardRow, {
			key = "You",
			rank = 4,
			player = "Makogai",
			value = "$337.8M",
			highlight = true,
			size = UDim2.fromOffset(420, 58),
		}),
	}

	return e(Harness.Gallery, {
		title = "Cards",
		sections = {
			{ title = "Item cards", items = itemStates, itemSize = UDim2.fromOffset(152, 196) },
			{ title = "Pet cards and slots", items = pets, itemSize = UDim2.fromOffset(158, 218) },
			{ title = "Upgrade rows", items = upgrades, itemSize = UDim2.fromOffset(866, 110) },
			{ title = "Area cards", items = areas, itemSize = UDim2.fromOffset(272, 326) },
			{
				title = "Daily reward cards",
				items = rewards,
				itemSize = UDim2.fromOffset(142, 184),
			},
			{
				title = "Collection and cosmetics",
				items = index,
				itemSize = UDim2.fromOffset(180, 220),
			},
			{
				title = "Leaderboard rows",
				items = leaderboard,
				itemSize = UDim2.fromOffset(426, 64),
			},
		},
	})
end)
