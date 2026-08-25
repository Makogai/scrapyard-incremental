--!strict
--[[
	ArenaService.luau
	Opens THE PIT on the authored `Workspace.Event Area` while its event runs, fills the
	authored spawn nodes with scrap nobody owns, and clears it afterwards.

	See `ArenaConfig` for the design and the numbers. This file is the machinery:

		- watch the event schedule for anything flagged `Arena`
		- bind the authored Event Area (spawn pad + loot nodes) when one opens
		- keep empty nodes topped up to `TargetScrap` while it is open
		- clear the scrap when it closes, and put anybody still inside back on their own plot

	THE GEOMETRY IS AUTHORED. It used to be a generated cylinder in the void; the map now has a real
	Event Area, so this service must not build or destroy it. Scrap is the only thing that comes and
	goes with the event.

	IT POLLS, like `EventService` does, and for the same reasons: a server that starts mid-event has to
	open the arena on the way up, and a schedule edited during a session has to be noticed. A `task.delay`
	to the boundary is tighter and wrong in both cases.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local PlotService = require(script.Parent.PlotService)
local ScrapService = require(script.Parent.ScrapService)

local ArenaService = {}

--- How often the schedule is checked, matching `EventService` so the two turn over together.
local POLL_SECONDS = 5

local arena: Model? = nil
local scrapFolder: Folder? = nil
local started = false
local missingAreaWarned = false
local missingMarkersWarned = false
local openArena: () -> ()
local closeArena: () -> ()

--- The live arena event, or nil. One place asks the question so the answer cannot differ between callers.
local function arenaEvent(): EventConfig.EventDefinition?
	local definition = EventConfig.activeAt(os.time())
	if definition ~= nil and definition.Arena == true then
		return definition
	end
	return nil
end

local function findArea(): Model?
	local direct = workspace:FindFirstChild(ArenaConfig.AreaName)
	if direct and direct:IsA("Model") then
		return direct
	end
	local nested = workspace:FindFirstChild(ArenaConfig.AreaName, true)
	if nested and nested:IsA("Model") then
		return nested
	end
	return nil
end

local function spawnMarkers(area: Model): { BasePart }
	local folder = area:FindFirstChild(ArenaConfig.ScrapSpawnFolderName)
	if folder == nil then
		return {}
	end
	local markers = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(markers, child)
		elseif child:IsA("Model") then
			local part = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart", true)
			if part then
				table.insert(markers, part)
			end
		end
	end
	return markers
end

--[[
	Where to put a generated pad if Studio has not authored `PitSpawn`.

	Beside the spawn model, never on a loot node. Those pads are scrap piles; standing
	players on Spawn01 is what this used to do after the sculpture-collision fix.
]]
local function fallbackSpawnCFrame(area: Model, spawnModel: Instance?): CFrame
	local origin = if spawnModel and spawnModel:IsA("Model")
		then spawnModel:GetPivot().Position
		else area:GetPivot().Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	if spawnModel then
		params.FilterDescendantsInstances = { spawnModel }
	end
	local offsets = {
		Vector3.new(-16, 40, 0),
		Vector3.new(0, 40, -16),
		Vector3.new(16, 40, 0),
		Vector3.new(0, 40, 16),
		Vector3.new(0, 80, 0),
	}
	for _, offset in offsets do
		local hit = workspace:Raycast(origin + offset, Vector3.new(0, -200, 0), params)
		if hit then
			return CFrame.new(hit.Position + Vector3.new(0, 3, 0))
		end
	end
	return CFrame.new(origin + Vector3.new(0, 6, 0))
end

--[[
	The teleport target: an upright, invisible part.

	A PART rather than a CFrame, because that is what `TeleportService.destinationFor` deals in.
	The authored `PitSpawn` under Event Area Spawn Point is the destination. This used to
	overwrite that part onto the first loot node every open, which is why ENTER THE PIT
	dropped people on scrap.

	Authored collision on the spawn model is left alone. A leftover workaround used to
	force `CanCollide = false` on every tall part in here, so Studio collision never
	survived Play and players fell through the pad they had just turned on.
]]
local function ensureSpawnPart(area: Model): BasePart?
	local spawnModel = area:FindFirstChild(ArenaConfig.SpawnModelName, true)
	local host: Instance = if spawnModel then spawnModel else area

	local existing = host:FindFirstChild(ArenaConfig.SpawnPartName, true)
	if existing and existing:IsA("BasePart") then
		existing.CanCollide = false
		return existing
	end

	local created = Instance.new("Part")
	created.Name = ArenaConfig.SpawnPartName
	created.Size = Vector3.new(8, 0.5, 8)
	created.Anchored = true
	created.CanCollide = false
	created.CanQuery = false
	created.CanTouch = false
	created.Transparency = 1
	created.CFrame = fallbackSpawnCFrame(area, spawnModel)
	created.Parent = host
	return created
end

--- Whether the Pit is open right now. Read by `TeleportService` before it will send anyone there.
function ArenaService.IsOpen(): boolean
	return arenaEvent() ~= nil and findArea() ~= nil
end

function ArenaService.SpawnPart(): BasePart?
	if arenaEvent() == nil then
		return nil
	end
	--[[
		Open on the teleport itself.

		The HUD button appears as soon as the snapshot says the Pit is live. The old
		loop waited up to five seconds before binding the Event Area, so the first
		clicks did nothing. Binding here means ENTER THE PIT works on the first press.
	]]
	if arena == nil then
		openArena()
	end
	local model = arena
	if model == nil then
		return nil
	end
	return ensureSpawnPart(model)
end

--[[
	Bind or unbind to match the live schedule.

	`EventService.Republish` calls this when an admin starts or stops an event, so the
	Pit does not lag the HUD banner by a poll.
]]
function ArenaService.Sync()
	if arenaEvent() ~= nil then
		openArena()
	else
		closeArena()
	end
end

local weightedTotal = 0
for _, weight in ArenaConfig.ScrapWeights do
	weightedTotal += weight
end

local function rollScrapId(): string
	local roll = math.random() * weightedTotal
	for scrapId, weight in ArenaConfig.ScrapWeights do
		roll -= weight
		if roll <= 0 then
			return scrapId
		end
	end
	return "MetalCan"
end

--[[
	Add up to `count` pieces onto empty authored spawn nodes.

	One node, one piece: with a single pad the arena holds a single scrap until more pads are
	duplicated in Studio. Occupied means another public piece is already within MinimumSpacing.
]]
local function fill(count: number)
	local folder = scrapFolder
	local model = arena
	if folder == nil or model == nil then
		return
	end
	local markers = spawnMarkers(model)
	if #markers == 0 then
		if not missingMarkersWarned then
			missingMarkersWarned = true
			warn(
				`[ArenaService] No spawn nodes in {ArenaConfig.AreaName}/{ArenaConfig.ScrapSpawnFolderName}. Duplicate Spawn01 in Studio to add loot pads.`
			)
		end
		return
	end

	local existing = {}
	for _, piece in folder:GetChildren() do
		local position = if piece:IsA("Model")
			then piece:GetPivot().Position
			elseif piece:IsA("BasePart") then piece.Position
			else nil
		if position ~= nil then
			table.insert(existing, position)
		end
	end

	local spawned = 0
	for _, marker in markers do
		if spawned >= count then
			break
		end
		local point = marker.Position
		local clear = true
		for _, other in existing do
			local flat = (Vector3.new(point.X, 0, point.Z) - Vector3.new(other.X, 0, other.Z)).Magnitude
			if flat < ArenaConfig.MinimumSpacing then
				clear = false
				break
			end
		end
		if clear and ScrapService.SpawnPublic(rollScrapId(), point, 1) ~= nil then
			table.insert(existing, point)
			spawned += 1
		end
	end
end

--[[
	Put everybody standing in the Event Area back on their own plot.

	Called when the Pit closes. The area itself stays in the world, but the shared hoard is gone, so
	anyone left inside would be standing in an empty event map. Home is their plot spawn, the same
	destination `TeleportService` uses for MyPlot.
]]
local function evacuate(area: Model)
	local cf, size = area:GetBoundingBox()
	local half = size * 0.5 + Vector3.new(8, 20, 8)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") then
			local delta = cf:PointToObjectSpace(root.Position)
			if math.abs(delta.X) <= half.X and math.abs(delta.Y) <= half.Y and math.abs(delta.Z) <= half.Z then
				local plot = PlotService.GetPlot(player)
				local home = if plot then plot:FindFirstChild("PlayerSpawn") else nil
				if home ~= nil and home:IsA("BasePart") and character ~= nil then
					character:PivotTo(home.CFrame + Vector3.new(0, 4, 0))
				end
			end
		end
	end
end

openArena = function()
	if arena ~= nil then
		return
	end
	local model = findArea()
	if model == nil then
		if not missingAreaWarned then
			missingAreaWarned = true
			warn(
				`[ArenaService] {ArenaConfig.AreaName} was not in Workspace. The Pit cannot open until that model exists.`
			)
		end
		return
	end

	ensureSpawnPart(model)

	local leftover = model:FindFirstChild("PitScrap")
	if leftover then
		leftover:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "PitScrap"
	folder.Parent = model

	arena = model
	scrapFolder = folder
	ScrapService.SetPublicFolder(folder)
	--- One piece per empty node, capped at TargetScrap.
	local filled, fillError = pcall(fill, ArenaConfig.TargetScrap)
	if not filled then
		warn(`[ArenaService] Pit loot failed to spawn: {fillError}`)
	end
end

closeArena = function()
	local model = arena
	if model == nil then
		return
	end
	evacuate(model)
	ScrapService.ClearPublic()
	ScrapService.SetPublicFolder(nil)
	local folder = scrapFolder
	if folder then
		folder:Destroy()
	end
	arena = nil
	scrapFolder = nil
end

function ArenaService.Start()
	if started then
		return
	end
	started = true

	if arenaEvent() ~= nil then
		task.defer(openArena)
	end

	task.spawn(function()
		local sinceRefill = 0
		while true do
			task.wait(POLL_SECONDS)
			local live = arenaEvent()
			if live ~= nil and arena == nil then
				openArena()
			elseif live == nil and arena ~= nil then
				closeArena()
			end

			if arena ~= nil then
				sinceRefill += POLL_SECONDS
				if sinceRefill >= ArenaConfig.RefillIntervalSeconds then
					sinceRefill = 0
					local missing = ArenaConfig.TargetScrap - ScrapService.CountPublic()
					if missing > 0 then
						fill(math.min(missing, ArenaConfig.RefillPerTick))
					end
				end
			end
		end
	end)

	--- Nothing on join: a player arriving does not change whether the Pit is open.
end

return table.freeze(ArenaService)
