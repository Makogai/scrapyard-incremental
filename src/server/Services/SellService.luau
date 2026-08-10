--!strict
--[[
	SellService.luau
	Selling happens by standing on your plot's `CrusherSellZone`.

	THE CONNECTION IS RE-BOUND WHEN A PLOT IS REBUILT. It used to be made once at startup, which
	broke selling completely: `PlotThemeService.Rebuild` destroys every child of a plot and clones
	fresh ones from the variant, and it runs on EVERY JOIN -- so the zone this service connected to
	at bootstrap was destroyed before any player ever stood on it. See
	`PlotService.OnGeometryReplaced`.
]]

local Players = game:GetService("Players")

local PlayerStateService = require(script.Parent.PlayerStateService)
local PlotService = require(script.Parent.PlotService)

local SellService = {}
local lastSell: { [Player]: number } = {}

--- One live connection per plot, so a re-bind replaces rather than stacks.
local zoneConnections: { [Model]: RBXScriptConnection } = {}

local function bindPlot(plot: Model)
	local existing = zoneConnections[plot]
	if existing then
		existing:Disconnect()
		zoneConnections[plot] = nil
	end

	local zone = plot:FindFirstChild("CrusherSellZone")
	if zone == nil or not zone:IsA("BasePart") then
		warn(`[SellService] {plot:GetFullName()} has no CrusherSellZone -- selling will not work`)
		return
	end
	--[[
		A zone authored with `CanTouch` off never fires, and the symptom is identical to this
		service not running at all, so it is asserted here rather than left to Studio.
	]]
	zone.CanTouch = true

	zoneConnections[plot] = zone.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = if character then Players:GetPlayerFromCharacter(character) else nil
		if player == nil or not PlotService.IsOwner(player, plot) then
			return
		end
		local now = os.clock()
		if now - (lastSell[player] or 0) < 0.75 then
			return
		end
		lastSell[player] = now
		PlayerStateService.TrySell(player)
	end)
end

function SellService.Start()
	local map = assert(workspace:FindFirstChild("NewMap"), "Workspace.NewMap required")
	local plotRoot = assert(map:FindFirstChild("Plots"), "Workspace.NewMap.Plots required")
	for _, plot in plotRoot:GetChildren() do
		if plot:IsA("Model") then
			bindPlot(plot)
		end
	end

	-- and again whenever a plot's geometry is swapped for a different theme
	PlotService.OnGeometryReplaced(function(_player, plot)
		bindPlot(plot)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastSell[player] = nil
	end)
end

return table.freeze(SellService)
