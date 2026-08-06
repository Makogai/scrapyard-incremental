--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local CodeConfig = require(script.Parent.Parent.Config.CodeConfig)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RemoteService = require(script.Parent.RemoteService)

local CodeService = {}
local limiter = RateLimiter.new(5, Environment.RemoteRateLimitWindowSeconds)

local function normalize(value: string): string
	return string.upper((string.gsub(value, "%s+", "")))
end

local function rewardSummary(rewards): { { Id: string, Amount: number } }
	local summary = {}
	for _, magnetId in rewards.Magnets or {} do
		table.insert(summary, { Id = magnetId, Amount = 1 })
	end
	for itemId, amount in rewards.Items or {} do
		if amount > 0 then
			table.insert(summary, { Id = itemId, Amount = amount })
		end
	end
	if (rewards.Money or 0) > 0 then
		table.insert(summary, { Id = "Money", Amount = rewards.Money })
	end
	if (rewards.Gears or 0) > 0 then
		table.insert(summary, { Id = "Gears", Amount = rewards.Gears })
	end
	return summary
end

function CodeService.Start()
	RemoteService.GetEvent("RedeemCode").OnServerEvent:Connect(function(player, submitted)
		if
			typeof(submitted) ~= "string"
			or #submitted > 40
			or not limiter:Allow(tostring(player.UserId))
		then
			return
		end
		local definition = CodeConfig[normalize(submitted)]
		local now = os.time()
		local valid = definition ~= nil
			and definition.Enabled == true
			and (definition.StudioOnly ~= true or RunService:IsStudio())
			and (definition.StartsAt == 0 or now >= definition.StartsAt)
			and (definition.ExpiresAt == 0 or now <= definition.ExpiresAt)
		if not valid then
			RemoteService.GetEvent("CodeResult")
				:FireClient(player, false, "INVALID OR EXPIRED CODE")
			return
		end
		local success, message =
			PlayerStateService.TryApplyCodeRewards(player, definition.Id, definition.Rewards)
		RemoteService.GetEvent("CodeResult"):FireClient(
			player,
			success,
			message,
			if success then rewardSummary(definition.Rewards) else nil
		)
		RemoteService.GetEvent("Notify"):FireClient(player, message)
	end)
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(tostring(player.UserId))
	end)
end

return table.freeze(CodeService)
