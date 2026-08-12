--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local ArenaConfig = require(game:GetService("ReplicatedStorage").Shared.Config.ArenaConfig)
local ArenaService = require(script.Parent.ArenaService)
local PlotService = require(script.Parent.PlotService)
local RemoteService = require(script.Parent.RemoteService)

local TeleportService = {}
local limiter = RateLimiter.new(4, Environment.RemoteRateLimitWindowSeconds)

local function destinationFor(player: Player, destinationId: string): BasePart?
	if destinationId == "MyPlot" then
		local plot = PlotService.GetPlot(player)
		local spawn = if plot then plot:FindFirstChild("PlayerSpawn") else nil
		return if spawn and spawn:IsA("BasePart") then spawn else nil
	end
	--[[
		Selling is a Touched event on the plot's CrusherSellZone (SellService).
		There is no sell remote and there should not be one -- the HUD's SELL
		button walks the player onto their own zone and lets the existing handler
		do the selling, so the server keeps deciding what a sale is worth.
	]]
	if destinationId == "MyCrusher" then
		local plot = PlotService.GetPlot(player)
		local zone = if plot then plot:FindFirstChild("CrusherSellZone") else nil
		return if zone and zone:IsA("BasePart") then zone else nil
	end
	--[[
		THE PIT, and only while it is open.

		Checked here rather than trusted from the client: the destination id arrives over a remote, and
		"send me to the arena" is worth lying about the moment the arena stops existing -- the floor is
		destroyed when the event ends, so a stale request would drop somebody into empty space.
	]]
	if destinationId == ArenaConfig.DestinationId then
		return ArenaService.SpawnPart()
	end
	if destinationId ~= "Leaderboards" and destinationId ~= "Shop" then
		return nil
	end
	local map = workspace:FindFirstChild("NewMap")
	local destinations = if map then map:FindFirstChild("TeleportDestinations") else nil
	local destination = if destinations then destinations:FindFirstChild(destinationId) else nil
	return if destination and destination:IsA("BasePart") then destination else nil
end

function TeleportService.Start()
	RemoteService.GetEvent("RequestTeleport").OnServerEvent:Connect(function(player, destinationId)
		if type(destinationId) ~= "string" or not limiter:Allow(tostring(player.UserId)) then
			return
		end
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local destination = destinationFor(player, destinationId)
		if character == nil or humanoid == nil or humanoid.Health <= 0 or destination == nil then
			return
		end
		character:PivotTo(destination.CFrame + Vector3.new(0, 4, 0))
	end)
end

return table.freeze(TeleportService)
