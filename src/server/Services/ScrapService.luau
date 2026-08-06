--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AreaConfig = require(ReplicatedStorage.Shared.Config.AreaConfig)
local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local PlotConfig = require(ReplicatedStorage.Shared.Config.PlotConfig)
local ScrapConfig = require(ReplicatedStorage.Shared.Config.ScrapConfig)
local PlayerStateService = require(script.Parent.PlayerStateService)
local PlotService = require(script.Parent.PlotService)
local RemoteService = require(script.Parent.RemoteService)

type ScrapRecord = {
	Instance: Instance,
	Marker: BasePart,
	Plot: Model,
	OwnerUserId: number,
	ScrapId: string,
	AreaId: string,
	VariantId: string,
	ReservedUserId: number?,
}

local ScrapService = {}
local activeByInstance: { [Instance]: ScrapRecord } = {}
local foldersByPlot: { [Model]: Folder } = {}
local templates: Folder
local gameplayEffect: RemoteEvent
local notifyRemote: RemoteEvent
local lastRejectionNotice: { [Player]: { Reason: string, At: number } } = {}
local overlap = OverlapParams.new()

local function refreshOverlapFilter()
	local folders = {}
	for _, folder in foldersByPlot do
		table.insert(folders, folder)
	end
	overlap.FilterDescendantsInstances = folders
end

local function weightedScrap(areaId: string): string
	local area = AreaConfig.ById[areaId] or AreaConfig.ById.FrontYard
	local choices = {}
	local total = 0
	for _, scrapId in area.ScrapIds do
		table.insert(choices, scrapId)
		total += ScrapConfig.ById[scrapId].SpawnWeight
	end
	if #choices == 0 then
		return "MetalCan"
	end
	local roll = math.random() * total
	for _, scrapId in choices do
		roll -= ScrapConfig.ById[scrapId].SpawnWeight
		if roll <= 0 then
			return scrapId
		end
	end
	return choices[1]
end

local function weightedVariant(): string
	local roll = math.random(1, ScrapConfig.VariantRollTotal)
	for variantId, variant in ScrapConfig.Variants do
		roll -= variant.SpawnWeight
		if roll <= 0 then
			return variantId
		end
	end
	return "Normal"
end

local function setInstanceCFrame(instance: Instance, target: CFrame)
	if instance:IsA("Model") then
		instance:PivotTo(target)
	elseif instance:IsA("BasePart") then
		instance.CFrame = target
	end
end

local function countPlotScrap(plot: Model): number
	local count = 0
	for _, record in activeByInstance do
		if record.Plot == plot then
			count += 1
		end
	end
	return count
end

local function spawnAt(player: Player, plot: Model, marker: BasePart)
	local folder = foldersByPlot[plot]
	if
		folder == nil
		or not PlotService.IsOwner(player, plot)
		or not PlayerStateService.IsAreaUnlocked(player, tostring(marker:GetAttribute("AreaId")))
		or countPlotScrap(plot) >= PlotConfig.MaximumActiveScrapPerPlot
	then
		return
	end
	local areaId = marker:GetAttribute("AreaId")
	if typeof(areaId) ~= "string" or AreaConfig.ById[areaId] == nil then
		areaId = "FrontYard"
	end
	local scrapId = weightedScrap(areaId)
	local variantId = weightedVariant()
	local template = templates:FindFirstChild(ScrapConfig.ById[scrapId].ModelName)
	if template == nil then
		warn(`[ScrapService] Missing template {scrapId}`)
		return
	end
	local instance = template:Clone()
	local plotId = tostring(plot:GetAttribute("PlotId"))
	instance.Name = `{scrapId}_{marker.Name}`
	instance:SetAttribute("ScrapId", scrapId)
	instance:SetAttribute("VariantId", variantId)
	instance:SetAttribute("AreaId", areaId)
	instance:SetAttribute("PlotId", plotId)
	instance:SetAttribute("OwnerUserId", player.UserId)
	instance:SetAttribute("ReservedUserId", 0)
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.Color = ScrapConfig.Variants[variantId].Color
		end
	end
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		instance.Color = ScrapConfig.Variants[variantId].Color
	end
	setInstanceCFrame(instance, marker.CFrame + Vector3.new(0, 1.5, 0))
	instance.Parent = folder
	activeByInstance[instance] = {
		Instance = instance,
		Marker = marker,
		Plot = plot,
		OwnerUserId = player.UserId,
		ScrapId = scrapId,
		AreaId = areaId,
		VariantId = variantId,
		ReservedUserId = nil,
	}
end

local function scrapRootFromPart(part: BasePart): Instance?
	local current: Instance? = part
	while current and current ~= workspace do
		if activeByInstance[current] then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function reserve(player: Player, record: ScrapRecord, distance: number, speed: number)
	if record.ReservedUserId ~= nil or record.OwnerUserId ~= player.UserId then
		return
	end
	record.ReservedUserId = player.UserId
	record.Instance:SetAttribute("ReservedUserId", player.UserId)
	local duration = math.clamp(distance / math.max(speed, 1), 0.12, 0.75)
	gameplayEffect:FireClient(player, "AttractScrap", record.Instance, duration)
	task.delay(duration, function()
		if
			activeByInstance[record.Instance] ~= record
			or record.ReservedUserId ~= player.UserId
			or not PlotService.IsOwner(player, record.Plot)
		then
			return
		end
		local collected =
			PlayerStateService.TryCollect(player, record.ScrapId, record.VariantId, record.AreaId)
		if not collected then
			record.ReservedUserId = nil
			record.Instance:SetAttribute("ReservedUserId", 0)
			return
		end
		activeByInstance[record.Instance] = nil
		gameplayEffect:FireClient(player, "Collected", record.ScrapId, record.VariantId)
		record.Instance:Destroy()
		task.delay(ScrapConfig.ById[record.ScrapId].RespawnSeconds, function()
			if record.Marker.Parent and PlotService.IsOwner(player, record.Plot) then
				spawnAt(player, record.Plot, record.Marker)
			end
		end)
	end)
end

local function queryPlayer(player: Player)
	local stats = PlayerStateService.GetDerivedStats(player)
	local plot = PlotService.GetPlot(player)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if stats == nil or plot == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	local parts = workspace:GetPartBoundsInRadius(root.Position, stats.MagnetRange, overlap)
	local checked = 0
	for _, part in parts do
		if checked >= Environment.MaximumScrapCandidatesPerQuery then
			break
		end
		local scrapRoot = scrapRootFromPart(part)
		local record = if scrapRoot then activeByInstance[scrapRoot] else nil
		if
			record
			and record.Plot == plot
			and record.OwnerUserId == player.UserId
			and record.ReservedUserId == nil
		then
			checked += 1
			local eligible, reason =
				PlayerStateService.CanCollect(player, record.ScrapId, record.AreaId)
			if eligible then
				reserve(
					player,
					record,
					(part.Position - root.Position).Magnitude,
					stats.CollectionSpeed
				)
			elseif reason == "StorageFull" or reason == "TooHeavy" then
				local previous = lastRejectionNotice[player]
				if
					previous == nil
					or previous.Reason ~= reason
					or os.clock() - previous.At >= 3
				then
					lastRejectionNotice[player] = { Reason = reason, At = os.clock() }
					notifyRemote:FireClient(
						player,
						if reason == "StorageFull"
							then "MAGNET STORAGE FULL — VISIT YOUR CRUSHER"
							else "MAGNET TOO WEAK FOR THIS SCRAP"
					)
				end
			end
		end
	end
end

local function activatePlot(player: Player, plot: Model)
	local runtime = assert(plot:FindFirstChild("RuntimeObjects"), "Plot RuntimeObjects missing")
	local active = Instance.new("Folder")
	active.Name = "ActiveScrap"
	active.Parent = runtime
	foldersByPlot[plot] = active
	refreshOverlapFilter()
	local markers = assert(plot:FindFirstChild("ScrapSpawnLocations"), "Plot markers missing")
	for _, marker in markers:GetChildren() do
		if marker:IsA("BasePart") and marker:GetAttribute("Enabled") ~= false then
			spawnAt(player, plot, marker)
		end
	end
end

local function deactivatePlot(_player: Player, plot: Model)
	for instance, record in activeByInstance do
		if record.Plot == plot then
			activeByInstance[instance] = nil
			instance:Destroy()
		end
	end
	foldersByPlot[plot] = nil
	local folder = plot:FindFirstChild("ActiveScrap", true)
	if folder and folder:IsA("Folder") then
		folder:Destroy()
	end
	refreshOverlapFilter()
end

function ScrapService.RefreshPlayer(player: Player)
	local plot = PlotService.GetPlot(player)
	if plot == nil then
		return
	end
	deactivatePlot(player, plot)
	activatePlot(player, plot)
end

function ScrapService.Start()
	templates = assert(
		ServerStorage:FindFirstChild("ScrapModels"),
		"ServerStorage.ScrapModels required"
	) :: Folder
	gameplayEffect = RemoteService.GetEvent("GameplayEffect")
	notifyRemote = RemoteService.GetEvent("Notify")
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.MaxParts = Environment.MaximumScrapCandidatesPerQuery
	PlotService.OnAssigned(activatePlot)
	PlotService.OnReleased(deactivatePlot)
	Players.PlayerRemoving:Connect(function(player)
		lastRejectionNotice[player] = nil
	end)
	for player, plot in PlotService.GetAssignments() do
		activatePlot(player, plot)
	end
	task.spawn(function()
		while true do
			task.wait(Environment.CollectionQueryIntervalSeconds)
			for _, player in Players:GetPlayers() do
				queryPlayer(player)
			end
		end
	end)
end

return table.freeze(ScrapService)
