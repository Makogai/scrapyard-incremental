--!strict
--[[
	LeaderstatsService.luau
	The two columns in Roblox's own player list -- the one Tab opens.

	`leaderstats` is a convention rather than an API: a folder of that name under a Player, holding
	Value objects, and the CoreGui player list draws one column per child in child order. Nothing in
	this game read it before, so Tab showed a bare list of names.

		Rebirths   IntValue     the number, so the list SORTS by it
		Money      StringValue  abbreviated, "$2.04M"

	WHY MONEY IS A STRING. The player list only sorts on a numeric value, and it cannot abbreviate: a
	`NumberValue` of 2040000 is drawn as "2040000", which is unreadable at column width and gets worse
	every rebirth. Abbreviating means giving up sorting on it -- and sorting on REBIRTHS is the more
	honest ranking anyway, because money resets to zero every time somebody prestiges, so a money
	leaderboard ranks whoever has not rebirthed recently.

	Updated from `PlayerStateService.pushState`, which is the single funnel every money and prestige
	change already passes through. A timer would have been less code and would have shown a stale
	number for a second or two after every sale.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.UI.Format)

local LeaderstatsService = {}

local FOLDER_NAME = "leaderstats"

--[[
	Get or make the folder and its two values.

	Built on demand rather than on `PlayerAdded`, because state arrives after the session loads and
	this is called from the push that follows it -- so the first call is always the one that creates it.
]]
local function ensure(player: Player): (IntValue?, StringValue?)
	local folder = player:FindFirstChild(FOLDER_NAME)
	if folder == nil then
		local made = Instance.new("Folder")
		made.Name = FOLDER_NAME
		made.Parent = player
		folder = made
	end

	local rebirths = folder:FindFirstChild("Rebirths")
	if rebirths == nil then
		local made = Instance.new("IntValue")
		--- First child, so the list sorts on it.
		made.Name = "Rebirths"
		made.Value = 0
		made.Parent = folder
		rebirths = made
	end

	local money = folder:FindFirstChild("Money")
	if money == nil then
		local made = Instance.new("StringValue")
		made.Name = "Money"
		made.Value = "$0"
		made.Parent = folder
		money = made
	end

	if rebirths:IsA("IntValue") and money:IsA("StringValue") then
		return rebirths, money
	end
	--[[
		Something else is already using those names, with different classes. Do not fight it: leaderstats
		is a shared convention, and clobbering another writer's values would be worse than showing nothing.
	]]
	return nil, nil
end

--[[
	Publish a player's columns.

	Takes the data rather than reading it back, so this cannot disagree with the push it is called
	from, and so it needs nothing from `PlayerStateService` -- which is what keeps the dependency
	one-way.
]]
function LeaderstatsService.Publish(player: Player, data: { [string]: any })
	if player.Parent == nil then
		return
	end
	local rebirths, money = ensure(player)
	if rebirths == nil or money == nil then
		return
	end

	local prestige = tonumber(data.PrestigeCount) or 0
	local cash = tonumber(data.Money) or 0
	rebirths.Value = math.max(0, math.floor(prestige))
	money.Value = Format.money(math.max(0, cash))
end

function LeaderstatsService.Start()
	--[[
		Nothing to connect. The folder is created by the first `Publish`, and it lives under the Player,
		so it is removed with them -- no teardown and no table of players to leak.

		The only reason this exists is so the service reads like every other one in `init.server`, and so
		there is one place to look when the columns are wrong.
	]]
	for _, player in Players:GetPlayers() do
		ensure(player)
	end
end

return table.freeze(LeaderstatsService)
