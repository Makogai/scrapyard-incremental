--!strict
--[[
	FriendBoostService.luau
	+10% money per friend in the same server.

	The cheapest social mechanic that exists: no new UI flow, no matchmaking, no trading rules. It
	rewards bringing people, the reward is visible to both sides, and it makes a full server better
	than an empty one. `docs/GAME_AUDIT.md` has the reasoning -- social systems are the 3-5x
	retention lever and this is the smallest step onto that ladder.

	FRIENDSHIP IS CHECKED SERVER-SIDE with `Player:IsFriendsWith`, which is a web call. So:

	  - results are cached per unordered pair for the lifetime of the server, because friendship
	    does not change during a session in any way we need to track
	  - the recount is debounced, because six players joining at once would otherwise fire 30 calls
	  - a failed call is treated as "not friends" and retried on the next recount, never as an error
	    the player sees

	The count is written to `PlayerStateService.SetFriendCount`, which feeds `derivedStats` and so
	shows up in the stat readout the player can already see.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RewardsConfig = require(ReplicatedStorage.Shared.Config.RewardsConfig)
local PlayerStateService = require(script.Parent.PlayerStateService)

local FriendBoostService = {}

--- Cached `IsFriendsWith` results, keyed by the two user ids in ascending order.
local friendships: { [string]: boolean } = {}
local recountQueued = false

local function pairKey(a: number, b: number): string
	return if a < b then `{a}:{b}` else `{b}:{a}`
end

local function areFriends(a: Player, b: Player): boolean
	local key = pairKey(a.UserId, b.UserId)
	local cached = friendships[key]
	if cached ~= nil then
		return cached
	end
	--[[
		`IsFriendsWith` yields and can throw when the web call fails. A failure must not be cached,
		or one bad moment permanently denies two players their boost for the rest of the server.
	]]
	local succeeded, result = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	if not succeeded then
		return false
	end
	friendships[key] = result == true
	return result == true
end

--[[
	Recount every player's friends in this server and publish the numbers.

	O(n^2) in players, which is fine: a Roblox server is a handful of people and every pair after
	the first recount is a cache hit.
]]
function FriendBoostService.Recount()
	local players = Players:GetPlayers()
	for _, player in players do
		local count = 0
		for _, other in players do
			if other ~= player and areFriends(player, other) then
				count += 1
			end
		end
		PlayerStateService.SetFriendCount(
			player,
			math.min(count, RewardsConfig.Friends.MaximumFriends)
		)
	end
end

--[[
	Debounced recount.

	Joins arrive in bursts -- a group of friends joining together is the exact case this feature
	exists for -- and recounting on each one would fire the same web calls several times over.
]]
local function queueRecount()
	if recountQueued then
		return
	end
	recountQueued = true
	task.delay(2, function()
		recountQueued = false
		FriendBoostService.Recount()
	end)
end

function FriendBoostService.Start()
	Players.PlayerAdded:Connect(queueRecount)
	Players.PlayerRemoving:Connect(function(player)
		--[[
			Drop this player's cached pairs. Keeping them would leak a row per pair across a long
			server life, and they are worthless once the player is gone.
		]]
		for key in friendships do
			if string.find(key, tostring(player.UserId), 1, true) then
				friendships[key] = nil
			end
		end
		queueRecount()
	end)
	queueRecount()
end

return table.freeze(FriendBoostService)
