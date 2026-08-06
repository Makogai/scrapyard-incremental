--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AdminConfig = require(ReplicatedStorage.Shared.Config.AdminConfig)
local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local PlotService = require(script.Parent.PlotService)
local RemoteService = require(script.Parent.RemoteService)
local ScrapService = require(script.Parent.ScrapService)

local AdminService = {}
local limiter = RateLimiter.new(
	Environment.MaximumRemoteRequestsPerWindow,
	Environment.RemoteRateLimitWindowSeconds
)

local function boundedAmount(command: string, value: any): number?
	if command ~= "AddMoney" and command ~= "AddGears" then
		return nil
	end
	if typeof(value) ~= "number" or value ~= value then
		return nil
	end
	local maximum = if command == "AddMoney"
		then AdminConfig.MaximumGrantMoney
		else AdminConfig.MaximumGrantGears
	return math.floor(math.clamp(value, 0, maximum))
end

function AdminService.Start()
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(tostring(player.UserId))
	end)
	RemoteService.GetEvent("AdminCommand").OnServerEvent
		:Connect(function(admin, command, amount, targetMode)
			if
				not AdminConfig.IsAdmin(admin.UserId)
				or typeof(command) ~= "string"
				or (targetMode ~= "Self" and targetMode ~= "All")
				or ((command == "ResetTestProfile" or command == "GrantTestItems") and (not RunService:IsStudio() or targetMode ~= "Self"))
				or not limiter:Allow(tostring(admin.UserId))
			then
				return
			end
			local safeAmount = boundedAmount(command, amount)
			if (command == "AddMoney" or command == "AddGears") and safeAmount == nil then
				return
			end
			local targets = if targetMode == "All" then Players:GetPlayers() else { admin }
			local applied = 0
			for _, target in targets do
				local succeeded = PlayerStateService.AdminMutate(target, command, safeAmount)
				if succeeded then
					applied += 1
					PlotService.RefreshAppearance(target)
					ScrapService.RefreshPlayer(target)
				end
			end
			RemoteService.GetEvent("Notify")
				:FireClient(admin, `ADMIN: {command} applied to {applied} player(s)`)
		end)
end

return table.freeze(AdminService)
