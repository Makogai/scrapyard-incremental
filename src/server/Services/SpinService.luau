--!strict
--[[
	SpinService.luau
	The daily spin wheel.

	THE SERVER PICKS THE PRIZE AND TELLS THE CLIENT WHERE TO STOP. That ordering is the whole
	security model of a wheel: the animation is decoration over a result that is already decided and
	already granted. A client that spins first and reports what it landed on is a client that lands
	on the jackpot every time.

	So the flow is:

		client: RequestSpin
		server: consume a spin -> weighted pick -> grant -> SpinResult(segmentId, index)
		client: animate the wheel so it lands on `index`, then show what was won

	The reward is granted before the animation finishes. If the player leaves mid-spin they still
	got it, which is the right way round -- the alternative loses rewards to closed windows.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.RewardsConfig)
local DayClock = require(ReplicatedStorage.Shared.Utility.DayClock)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RemoteService = require(script.Parent.RemoteService)

local SpinService = {}
local SEGMENTS = RewardsConfig.Spin.Segments

--[[
	Rate limited well below the animation length. Not an anti-cheat measure -- `ConsumeSpin` is what
	stops a player spinning more times than they have spins -- but it keeps a held-down button from
	burning a whole day's spins before the first wheel has stopped turning.
]]
local limiter = RateLimiter.new(3, Environment.RemoteRateLimitWindowSeconds)

local totalWeight = 0
for _, segment in SEGMENTS do
	totalWeight += segment.Weight
end

--- Weighted pick. Returns the segment and its 1-based index, which is what the wheel animates to.
local function pickSegment(): ({ [string]: any }, number)
	local roll = math.random() * totalWeight
	for index, segment in SEGMENTS do
		roll -= segment.Weight
		if roll <= 0 then
			return segment, index
		end
	end
	return SEGMENTS[#SEGMENTS], #SEGMENTS
end

--[[
	Spend a spin and resolve it.

	Returns `(spun, message, segmentId?, segmentIndex?)`. The index is what the client needs; the id
	is for the message and for anything that wants to log which prizes are actually landing.
]]
function SpinService.TrySpin(player: Player): (boolean, string, string?, number?)
	if not PlayerStateService.IsLoaded(player) then
		return false, "Your data is still loading"
	end
	if not PlayerStateService.ConsumeSpin(player) then
		return false, "NO SPINS LEFT -- COME BACK TOMORROW"
	end

	local segment, index = pickSegment()
	PlayerStateService.GrantRewards(player, {
		Money = segment.Money,
		Items = segment.Items,
		Spins = segment.Spins,
		Gears = segment.Gears,
	})
	return true, `YOU WON {segment.Label}!`, segment.Id, index
end

--- Hand out the day's free spins. Idempotent per day, so calling it on every join is safe.
function SpinService.GrantDailySpins(player: Player)
	PlayerStateService.GrantDailySpins(player, DayClock.today(), RewardsConfig.Spin.DailyFreeSpins)
end

function SpinService.Start()
	local request = RemoteService.GetEvent("RequestSpin")
	local result = RemoteService.GetEvent("SpinResult")
	local notify = RemoteService.GetEvent("Notify")

	request.OnServerEvent:Connect(function(player: Player)
		if not limiter:Allow(tostring(player.UserId)) then
			return
		end
		local spun, message, segmentId, index = SpinService.TrySpin(player)
		if spun and segmentId and index then
			--[[
				The result goes on its own remote, not on `Notify`. `Notify` is a plain string by
				contract and the wheel needs structured data; putting a table down it is what blanked
				the whole UI once already. See AGENTS.md rule 13.
			]]
			result:FireClient(player, segmentId, index, message)
		else
			notify:FireClient(player, message)
		end
	end)

	--- Free spins are granted on join, once their data has actually loaded.
	local function grantWhenLoaded(player: Player)
		task.spawn(function()
			local deadline = os.clock() + 30
			while os.clock() < deadline do
				if PlayerStateService.IsLoaded(player) then
					SpinService.GrantDailySpins(player)
					return
				end
				task.wait(0.5)
			end
		end)
	end

	Players.PlayerAdded:Connect(grantWhenLoaded)
	for _, player in Players:GetPlayers() do
		grantWhenLoaded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(tostring(player.UserId))
	end)
end

return table.freeze(SpinService)
