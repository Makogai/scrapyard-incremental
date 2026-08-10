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

--- How often a plot sign's numbers are refreshed.
local SIGN_REFRESH_SECONDS = 3

function PlotService.Start()
	local map = assert(workspace:FindFirstChild("NewMap"), "Workspace.NewMap is required")
	local root = assert(map:FindFirstChild("Plots"), "Workspace.NewMap.Plots is required")
	for _, child in root:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("PlotId") ~= nil then
			table.insert(plots, child)
			PlotBuildService.Reset(child)
		end
	end
	table.sort(plots, function(a, b)
		return tostring(a:GetAttribute("PlotId")) < tostring(b:GetAttribute("PlotId"))
	end)
	assert(#plots == 6, `Expected 6 authored plots, found {#plots}`)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(assignWhenLoaded, player)
	end)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		task.spawn(assignWhenLoaded, player)
	end

	--[[
		Keep the owner signs current. Only the sign, and only every few seconds: cash and
		scrap change constantly, but redoing stage visibility and area gates on a timer
		would be wasteful and would fight whatever else is touching them.
	]]
	task.spawn(function()
		while true do
			task.wait(SIGN_REFRESH_SECONDS)
			for player, plot in assignments do
				local state = PlayerStateService.GetPlotState(player)
				if state then
					PlotBuildService.RefreshSign(plot, player, state)
				end
			end
		end
	end)
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

local appearanceCallbacks: { (Player, Model) -> () } = {}

function PlotService.RefreshAppearance(player: Player)
	local plot = assignments[player]
	local state = PlayerStateService.GetPlotState(player)
	if plot and state then
		PlotBuildService.Refresh(plot, player, state)
		for _, callback in appearanceCallbacks do
			task.spawn(callback, player, plot)
		end
	end
end

--[[
	Hand the scrap on a plot back before its geometry is replaced. A thin passthrough so
	`PlotThemeService` does not have to know which service owns scrap.
]]
function PlotService.ReleaseScrap(plot: Model)
	local ScrapService = require(script.Parent.ScrapService)
	ScrapService.ReleasePlot(plot)
end

--[[
	Stand the scrap back up after a plot's geometry has been replaced. The other half of
	`ReleaseScrap`, and not optional: a rebuild destroys the folder and the markers `ScrapService`
	resolved, so without this the plot never spawns anything again.
]]
function PlotService.ActivateScrap(player: Player, plot: Model)
	local ScrapService = require(script.Parent.ScrapService)
	ScrapService.ActivatePlot(player, plot)
end

--[[
	Fired after a plot's geometry has been REPLACED, by `PlotThemeService.Rebuild`.

	Subscribe to this if your service holds a reference to anything under a plot -- a part, a
	folder, an event connection. A rebuild destroys every child of the plot and clones fresh ones
	from the variant, so any reference resolved earlier is now pointing at a destroyed instance.

	This exists because that mistake has now been made three separate times, each shipping as a
	different-looking bug:

	  * `ScrapService` cached its `ActiveScrap` folder and spawn markers -- nothing spawned, ever
	  * `PlotSignController` bound the sign card once -- signs read AVAILABLE PLOT forever
	  * `SellService` connected `Touched` on `CrusherSellZone` at startup -- standing on the
	    crusher stopped selling

	`Rebuild` runs on EVERY JOIN, not just on conversion, so "it only breaks if someone converts"
	is not a defence. If you resolve something under a plot outside this callback, it will break.
]]
local rebuiltCallbacks: { (Player?, Model) -> () } = {}

function PlotService.OnGeometryReplaced(callback: (Player?, Model) -> ())
	table.insert(rebuiltCallbacks, callback)
end

--- Called by `PlotThemeService.Rebuild` once the new geometry is in and dressed.
function PlotService.NotifyGeometryReplaced(player: Player?, plot: Model)
	for _, callback in rebuiltCallbacks do
		task.spawn(callback, player, plot)
	end
end

--- Fired after `RefreshAppearance`, for anything that has to re-dress the plot.
function PlotService.OnAppearanceRefreshed(callback: (Player, Model) -> ())
	table.insert(appearanceCallbacks, callback)
end

function PlotService.OnAssigned(callback: (Player, Model) -> ())
	table.insert(assignedCallbacks, callback)
end

function PlotService.OnReleased(callback: (Player, Model) -> ())
	table.insert(releasedCallbacks, callback)
end

return table.freeze(PlotService)
