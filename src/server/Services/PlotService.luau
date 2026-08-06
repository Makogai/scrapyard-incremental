--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStateService = require(script.Parent.PlayerStateService)
local PlotBuildService = require(script.Parent.PlotBuildService)
local PlotRules = require(ReplicatedStorage.Shared.Utility.PlotRules)

local PlotService = {}
local plots: { Model } = {}
local assignments: { [Player]: Model } = {}
local assignedCallbacks: { (Player, Model) -> () } = {}
local releasedCallbacks: { (Player, Model) -> () } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}

local function teleportToPlot(player: Player, character: Model)
	local plot = assignments[player]
	if plot == nil then
		return
	end
	local spawn = plot:FindFirstChild("PlayerSpawn")
	if spawn and spawn:IsA("BasePart") then
		character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
	end
end

local function assignWhenLoaded(player: Player)
	local deadline = os.clock() + 45
	while
		player.Parent == Players
		and not PlayerStateService.IsLoaded(player)
		and os.clock() < deadline
	do
		task.wait(0.1)
	end
	if player.Parent ~= Players or not PlayerStateService.IsLoaded(player) then
		return
	end
	for _, plot in plots do
		if (plot:GetAttribute("OwnerUserId") or 0) == 0 then
			local state = PlayerStateService.GetPlotState(player)
			if state == nil then
				return
			end
			assignments[player] = plot
			PlotBuildService.Apply(plot, player, state)
			characterConnections[player] = player.CharacterAdded:Connect(function(character)
				task.defer(teleportToPlot, player, character)
			end)
			if player.Character then
				teleportToPlot(player, player.Character)
			end
			for _, callback in assignedCallbacks do
				callback(player, plot)
			end
			return
		end
	end
	player:Kick("All scrapyard plots are currently occupied. Please join another server.")
end

local function release(player: Player)
	local plot = assignments[player]
	if plot == nil then
		return
	end
	for _, callback in releasedCallbacks do
		callback(player, plot)
	end
	local connection = characterConnections[player]
	if connection then
		connection:Disconnect()
		characterConnections[player] = nil
	end
	assignments[player] = nil
	PlotBuildService.Reset(plot)
end

function PlotService.Start()
	local root = assert(workspace:FindFirstChild("Plots"), "Workspace.Plots is required")
	for _, child in root:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("PlotId") ~= nil then
			table.insert(plots, child)
			PlotBuildService.Reset(child)
		end
	end
	table.sort(plots, function(a, b)
		return tostring(a:GetAttribute("PlotId")) < tostring(b:GetAttribute("PlotId"))
	end)
	assert(#plots == 12, `Expected 12 authored plots, found {#plots}`)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(assignWhenLoaded, player)
	end)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		task.spawn(assignWhenLoaded, player)
	end
end

function PlotService.GetPlot(player: Player): Model?
	return assignments[player]
end

function PlotService.IsOwner(player: Player, plot: Model): boolean
	local assigned = assignments[player]
	return PlotRules.isOwner(
		plot:GetAttribute("OwnerUserId") or 0,
		player.UserId,
		if assigned then tostring(assigned:GetAttribute("PlotId")) else nil,
		tostring(plot:GetAttribute("PlotId"))
	)
end

function PlotService.GetAssignments(): { [Player]: Model }
	return table.clone(assignments)
end

function PlotService.RefreshAppearance(player: Player)
	local plot = assignments[player]
	local state = PlayerStateService.GetPlotState(player)
	if plot and state then
		PlotBuildService.Refresh(plot, player, state)
	end
end

function PlotService.OnAssigned(callback: (Player, Model) -> ())
	table.insert(assignedCallbacks, callback)
end

function PlotService.OnReleased(callback: (Player, Model) -> ())
	table.insert(releasedCallbacks, callback)
end

return table.freeze(PlotService)
