--!strict
--[[
	AchievementService.luau
	Notices when an achievement has been earned, and pays for it once.

	IT DECIDES NOTHING. Whether a goal is met is read by `AchievementRules` off the save, and the
	thresholds live in `AchievementConfig`. This service owns exactly two things: when to look, and
	handing out the reward.

	WHY A POLL AND NOT A HOOK. Evaluating inside `pushState` would be instant, but granting a reward
	pushes state, which would re-enter the evaluation -- terminating, because the second pass finds
	nothing new, but doing every check twice for every change in the game. A three second poll costs one
	pass over twenty definitions per player and cannot recurse. Achievements are milestones; nobody
	notices three seconds.

	PAID ONCE, AND THE SAVE RECORDS ONLY THAT. `UnlockedAchievements[id] = true` means "the reward has
	been handed over", not "the goal is met" -- progress is always re-read from the live numbers. That is
	what makes an achievement added next month immediately correct for a player who passed its threshold
	last month, and it is why there is no backfill step anywhere in this file.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchievementConfig = require(ReplicatedStorage.Shared.Config.AchievementConfig)
local TitleConfig = require(ReplicatedStorage.Shared.Config.TitleConfig)
local AchievementRules = require(ReplicatedStorage.Shared.Utility.AchievementRules)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RemoteService = require(script.Parent.RemoteService)

local AchievementService = {}

--- How often each loaded player is checked.
local POLL_SECONDS = 3

--[[
	How many awards one pass may hand out.

	A brand new player who somehow satisfies half the list at once -- a restored save, an admin grant,
	a schema change that widens a metric -- would otherwise get a wall of notifications. The rest are
	picked up on the next pass, so nothing is lost, it just arrives in readable batches.
]]
local MAXIMUM_PER_PASS = 3

local started = false

--[[
	Grant one achievement, if it is still unpaid.

	Returns the definition when it paid out, so the caller can announce it -- and nil when another pass
	got there first, which is what makes this safe to call from more than one place.
]]
function AchievementService.TryAward(player: Player, achievementId: string)
	local definition = AchievementConfig.ById[achievementId]
	if definition == nil then
		return nil
	end
	local data = PlayerStateService.GetSaveData(player)
	if data == nil or data.UnlockedAchievements[achievementId] == true then
		return nil
	end
	local _, _, complete = AchievementRules.progress(data, definition)
	if not complete then
		return nil
	end

	--[[
		Recorded BEFORE the reward is granted. `GrantRewards` pushes state, and a push is a yield point
		on some paths -- marking it paid first means the worst case is a reward that failed to arrive,
		not one handed out twice.
	]]
	data.UnlockedAchievements[achievementId] = true
	PlayerStateService.GrantRewards(player, {
		Money = definition.Reward.Money,
		Gears = definition.Reward.Gears,
		Spins = definition.Reward.Spins,
		TitleId = definition.Reward.TitleId,
	})
	PlayerStateService.RefreshTitle(player)
	return definition
end

--- One pass over the list for one player.
local function evaluate(player: Player)
	local data = PlayerStateService.GetSaveData(player)
	if data == nil then
		return
	end
	local earned =
		AchievementRules.newlyEarned(data, AchievementConfig.Definitions, data.UnlockedAchievements)
	if #earned == 0 then
		return
	end

	local notify = RemoteService.GetEvent("Notify")
	for index = 1, math.min(#earned, MAXIMUM_PER_PASS) do
		local definition = AchievementService.TryAward(player, earned[index])
		if definition then
			--[[
				`Notify` carries a PLAIN STRING by contract (AGENTS.md rule 13). The title is named in the
				same line rather than sent as a second toast: two notifications for one achievement reads
				as a bug, and the title is the part worth shouting about.
			]]
			local titleText = TitleConfig.resolve(definition.Reward.TitleId)
			local message = if titleText
				then `ACHIEVEMENT: {definition.Name} -- title unlocked: {titleText.Text}`
				else `ACHIEVEMENT: {definition.Name}`
			notify:FireClient(player, message)
		end
	end
end

--- Evaluate one player now. For callers that just changed something big, like a rebirth.
function AchievementService.Evaluate(player: Player)
	evaluate(player)
end

function AchievementService.Start()
	if started then
		return
	end
	started = true

	RemoteService.GetEvent("EquipTitle").OnServerEvent:Connect(function(player, titleId)
		--- The only argument is a string id; anything else is a client that should not be trusted.
		if typeof(titleId) ~= "string" or #titleId > 64 then
			return
		end
		local succeeded, message = PlayerStateService.TryEquipTitle(player, titleId)
		if not succeeded then
			RemoteService.GetEvent("Notify"):FireClient(player, string.upper(message))
		end
	end)

	--[[
		The poll. Every loaded player, every few seconds.

		Deliberately not per-player timers: one loop is easier to reason about, and a player who joins
		mid-cycle simply gets checked on the next tick rather than needing its own schedule.
	]]
	task.spawn(function()
		while true do
			task.wait(POLL_SECONDS)
			for _, player in Players:GetPlayers() do
				--- Wrapped: one player's bad save must not stop everyone else being evaluated.
				local succeeded, err = pcall(evaluate, player)
				if not succeeded then
					warn(`[AchievementService] {player.Name}: {err}`)
				end
			end
		end
	end)

	--[[
		On join, once their data has loaded: a returning player whose achievements predate this system
		should have them before they finish walking to their plot, not three seconds later.
	]]
	local function evaluateWhenLoaded(player: Player)
		task.spawn(function()
			local deadline = os.clock() + 30
			while os.clock() < deadline do
				if PlayerStateService.IsLoaded(player) then
					PlayerStateService.RefreshTitle(player)
					evaluate(player)
					return
				end
				task.wait(0.5)
			end
		end)
	end

	Players.PlayerAdded:Connect(evaluateWhenLoaded)
	for _, player in Players:GetPlayers() do
		evaluateWhenLoaded(player)
	end
end

return table.freeze(AchievementService)
