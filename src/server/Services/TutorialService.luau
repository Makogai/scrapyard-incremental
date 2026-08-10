--!strict
--[[
	TutorialService.luau
	The first-session objective chain.

	NOT A TUTORIAL, and that distinction drove the design. Complex onboarding backfires on Roblox --
	players have no tolerance for anything but immediate play, and at least one team raised retention
	by deleting theirs. So there is no modal, nothing to dismiss, and no forced camera. There is a
	caption, an arrow, and a reward, and every step is completed by doing the ordinary thing.

	COMPLETION IS EVALUATED FROM STATE, NOT REPORTED BY THE CLIENT. Each step in `TutorialConfig`
	names a snapshot field and a threshold, and this service polls it. That means:

	  - the client cannot skip ahead to collect the rewards
	  - no other service has to call into this one, so there are no new coupling edges to
	    `PlayerStateService` (which everything already requires)
	  - a step is satisfied by any route to the same outcome, which is what "indistinguishable from
	    playing" requires

	Established players are opted out on join. Showing "GRAB SOME SCRAP" to someone with a rebirth is
	worse than showing nothing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RemoteService = require(script.Parent.RemoteService)

local TutorialService = {}
local limiter = RateLimiter.new(4, Environment.RemoteRateLimitWindowSeconds)
local STEPS = TutorialConfig.Steps
local STEP_COUNT = #STEPS

local function stepAt(index: number)
	for _, step in STEPS do
		if step.Index == index then
			return step
		end
	end
	return nil
end

--[[
	Resolve a condition field off the reward state.

	`TotalUpgradeLevels` is derived rather than stored -- "have they bought any upgrade" is the
	interesting question and no single field answers it.
]]
local function fieldValue(state: { [string]: any }, field: string): number
	if field == "TotalUpgradeLevels" then
		local total = 0
		for _, level in state.UpgradeLevels do
			total += level
		end
		return total
	end
	local value = state[field]
	return if typeof(value) == "number" then value else 0
end

--- Should this player be offered the chain at all?
local function shouldSkip(state: { [string]: any }): boolean
	if state.Money > TutorialConfig.SkipIfMoneyAbove then
		return true
	end
	for _, level in state.UpgradeLevels do
		if level > 0 then
			return true
		end
	end
	return false
end

--[[
	Advance as far as the player's state allows, granting each step's reward as it is passed.

	A loop rather than a single check, because a player can satisfy two steps between ticks -- and
	because an established player being opted in by a config change should not have to wait four
	seconds to be walked through steps they finished months ago.
]]
function TutorialService.Evaluate(player: Player)
	local state = PlayerStateService.GetRewardState(player)
	if state == nil or state.TutorialComplete then
		return
	end

	local step = state.TutorialStep
	if step <= 0 then
		if shouldSkip(state) then
			PlayerStateService.SetTutorialProgress(player, STEP_COUNT + 1, true)
			return
		end
		PlayerStateService.SetTutorialProgress(player, 1, false)
		step = 1
	end

	local notify = RemoteService.GetEvent("Notify")
	while step >= 1 and step <= STEP_COUNT do
		local definition = stepAt(step)
		if definition == nil then
			break
		end
		local current = fieldValue(state, definition.Condition.Field)
		if current < definition.Condition.AtLeast then
			break
		end

		PlayerStateService.GrantRewards(player, { Money = definition.Money })
		step += 1
		local finished = step > STEP_COUNT
		PlayerStateService.SetTutorialProgress(player, step, finished)
		notify:FireClient(
			player,
			if finished then "TUTORIAL COMPLETE -- GOOD LUCK OUT THERE" else "OBJECTIVE COMPLETE"
		)

		--[[
			Re-read rather than reuse the captured state: the grant above changed Money, and step 4's
			condition is a money threshold. Reusing the stale copy would fail to notice that the
			reward for step 3 just satisfied step 4.
		]]
		local refreshed = PlayerStateService.GetRewardState(player)
		if refreshed == nil then
			return
		end
		state = refreshed
		if finished then
			return
		end
	end
end

function TutorialService.Start()
	local action = RemoteService.GetEvent("TutorialAction")

	--[[
		The only thing the client may ask for is to skip. It cannot advance, and it cannot claim --
		those are decided by `Evaluate` from state.
	]]
	action.OnServerEvent:Connect(function(player: Player, request: any)
		if not limiter:Allow(tostring(player.UserId)) or request ~= "Skip" then
			return
		end
		PlayerStateService.SetTutorialProgress(player, STEP_COUNT + 1, true)
	end)

	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(tostring(player.UserId))
	end)

	task.spawn(function()
		while true do
			task.wait(TutorialConfig.CheckIntervalSeconds)
			for _, player in Players:GetPlayers() do
				TutorialService.Evaluate(player)
			end
		end
	end)
end

return table.freeze(TutorialService)
