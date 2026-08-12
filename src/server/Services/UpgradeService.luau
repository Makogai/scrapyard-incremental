--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local PlotService = require(script.Parent.PlotService)
local RemoteService = require(script.Parent.RemoteService)

local UpgradeService = {}
--[[
	How many levels one press may buy.

	Comfortably above any real MAX -- the level cap is 10 + 2 per rebirth -- and far below a number that
	would let one event cost the server real time.
]]
local MAXIMUM_BULK = 250

local limiter = RateLimiter.new(
	Environment.MaximumRemoteRequestsPerWindow,
	Environment.RemoteRateLimitWindowSeconds
)

function UpgradeService.Start()
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(tostring(player.UserId))
	end)
	RemoteService.GetEvent("RequestUpgrade").OnServerEvent
		:Connect(function(player, upgradeId, count)
			if typeof(upgradeId) ~= "string" then
				return
			end
			if not limiter:Allow(tostring(player.UserId)) then
				return
			end

			--[[
				ONE REQUEST MAY BUY SEVERAL LEVELS.

				`count` is clamped rather than trusted, and every level is still priced and checked by
				`TryPurchaseUpgrade` -- this loop only saves the round trips. The ceiling is `MAXIMUM_BULK`
				so a hostile client cannot ask for a million iterations of server work in one event.

				Stops at the FIRST refusal, which is what makes a partial buy honest: run out of money at
				level seven of ten and you bought seven, and the message says so.
			]]
			local requested = math.clamp(math.floor(tonumber(count) or 1), 1, MAXIMUM_BULK)
			local bought = 0
			local lastMessage = ""
			for _ = 1, requested do
				local succeeded, message = PlayerStateService.TryPurchaseUpgrade(player, upgradeId)
				lastMessage = message
				if not succeeded then
					break
				end
				bought += 1
			end

			RemoteService.GetEvent("Notify")
				:FireClient(player, if bought > 1 then `BOUGHT {bought} LEVELS` else lastMessage)
			if bought > 0 then
				PlotService.RefreshAppearance(player)
			end
		end)
end

return table.freeze(UpgradeService)
