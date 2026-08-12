--!strict
--[[
	ArenaService.luau
	Builds THE PIT while its event runs, fills it with scrap nobody owns, and takes it away afterwards.

	See `ArenaConfig` for the design and the numbers. This file is the machinery:

		- watch the event schedule for anything flagged `Arena`
		- build the floor, the wall ring, the pad and the lights when one opens
		- keep it topped up to `TargetScrap` while it is open
		- tear it down when it closes, and put anybody still inside back on their own plot

	NOTHING IS AUTHORED IN STUDIO. The arena is generated, and that is deliberate: it exists for a few
	hours a week, it sits in empty space off the edge of the map, and a Studio-authored version would be a
	permanent 2,000-part model replicating to every client all week for the sake of a Friday evening.
	Generating it also means `ArenaConfig` can change its size and the geometry follows.

	IT POLLS, like `EventService` does, and for the same reasons: a server that starts mid-event has to
	build the arena on the way up, and a schedule edited during a session has to be noticed. A `task.delay`
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

local ARENA_NAME = "ScrapPitArena"

local arena: Model? = nil
local scrapFolder: Folder? = nil
local started = false

--- The live arena event, or nil. One place asks the question so the answer cannot differ between callers.
local function arenaEvent(): EventConfig.EventDefinition?
	local definition = EventConfig.activeAt(os.time())
	if definition ~= nil and definition.Arena == true then
		return definition
	end
	return nil
end

--- Whether the Pit is open right now. Read by `TeleportService` before it will send anyone there.
function ArenaService.IsOpen(): boolean
	return arena ~= nil and arena.Parent ~= nil and arenaEvent() ~= nil
end

--[[
	Where a player lands: an invisible upright part on the pad.

	A PART rather than a CFrame, because that is what `TeleportService.destinationFor` deals in and the Pit
	should not be the one destination that needs its own code path there.

	It cannot be the pad itself. The pad is a cylinder, and a cylinder has to be rotated 90 degrees to lie
	flat -- teleporting to that CFrame would lay the player down on their side.
]]
function ArenaService.SpawnPart(): BasePart?
	if not ArenaService.IsOpen() then
		return nil
	end
	local model = arena
	local spawnPart = if model then model:FindFirstChild("PitSpawn") else nil
	return if spawnPart and spawnPart:IsA("BasePart") then spawnPart else nil
end

local function makePart(name: string, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Material = Enum.Material.Metal
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

--[[
	The arena, built from scratch.

	A cylinder floor and a ring of wall slabs. The slabs are boxes rather than a mesh because a box is one
	part with no asset to load, and thirty of them at this radius read as a curve -- the wall is 12 studs
	long per segment against a 60-stud radius, so the flat spots are smaller than a player.
]]
local function build(): Model
	local model = Instance.new("Model")
	model.Name = ARENA_NAME

	local origin = ArenaConfig.Origin

	local floor = makePart("PitFloor", model)
	floor.Shape = Enum.PartType.Cylinder
	--- A cylinder's length runs along X, so it has to be turned on its side to lie flat.
	floor.Size = Vector3.new(
		ArenaConfig.FloorThickness,
		ArenaConfig.FloorRadius * 2,
		ArenaConfig.FloorRadius * 2
	)
	floor.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))
	floor.Color = Color3.fromRGB(58, 62, 74)
	floor.Material = Enum.Material.Concrete
	model.PrimaryPart = floor

	--[[
		The pad players land on: a darker disc in the middle, kept clear of scrap.

		Raised a hair above the floor rather than flush, or the two coplanar faces z-fight.
	]]
	local pad = makePart("PitPad", model)
	pad.Shape = Enum.PartType.Cylinder
	pad.Size = Vector3.new(0.4, ArenaConfig.PadRadius * 2, ArenaConfig.PadRadius * 2)
	pad.CFrame = CFrame.new(origin + Vector3.new(0, ArenaConfig.FloorThickness / 2 + 0.2, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	pad.Color = Color3.fromRGB(255, 87, 87)
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.55
	pad.CanCollide = false

	--- The teleport target: upright, invisible, and out of the way of everything else.
	local spawnPart = makePart("PitSpawn", model)
	spawnPart.Size = Vector3.new(4, 1, 4)
	spawnPart.CFrame = CFrame.new(origin + Vector3.new(0, ArenaConfig.FloorThickness / 2 + 0.5, 0))
	spawnPart.Transparency = 1
	spawnPart.CanCollide = false
	spawnPart.CanQuery = false

	local walls = Instance.new("Folder")
	walls.Name = "PitWalls"
	walls.Parent = model

	local segments = ArenaConfig.WallSegments
	--- Chord length for one segment, plus a little overlap so the corners do not show daylight.
	local segmentLength = 2 * math.pi * ArenaConfig.FloorRadius / segments * 1.06
	for index = 1, segments do
		local angle = (index - 1) / segments * math.pi * 2
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local wall = makePart(`PitWall{index}`, walls)
		wall.Size = Vector3.new(ArenaConfig.WallThickness, ArenaConfig.WallHeight, segmentLength)
		wall.CFrame = CFrame.new(
			origin
				+ outward * ArenaConfig.FloorRadius
				+ Vector3.new(0, ArenaConfig.WallHeight / 2 + ArenaConfig.FloorThickness / 2, 0)
		) * CFrame.Angles(0, -angle, 0)
		wall.Color = Color3.fromRGB(44, 74, 120)

		--- A neon cap along the top, every third segment lit, so the ring reads at night.
		local cap = makePart(`PitWallCap{index}`, walls)
		cap.Size = Vector3.new(ArenaConfig.WallThickness + 0.6, 1.2, segmentLength)
		cap.CFrame = wall.CFrame * CFrame.new(0, ArenaConfig.WallHeight / 2 + 0.6, 0)
		cap.Material = Enum.Material.Neon
		cap.Color = if index % 3 == 0
			then Color3.fromRGB(255, 87, 87)
			else Color3.fromRGB(33, 229, 245)
		cap.CanCollide = false
	end

	--[[
		Four lights on the rim, not one in the middle.

		A single central light leaves the wall faces flat and the scrap under it shadowless. Four around
		the edge cross-light the floor, which is where everything the player cares about is lying.
	]]
	for index = 1, 4 do
		local angle = (index - 1) / 4 * math.pi * 2
		local host = makePart(`PitLampPost{index}`, model)
		host.Size = Vector3.new(1.4, 12, 1.4)
		host.Transparency = 1
		host.CanCollide = false
		host.CFrame = CFrame.new(
			ArenaConfig.Origin
				+ Vector3.new(math.cos(angle), 0, math.sin(angle)) * (ArenaConfig.FloorRadius - 6)
				+ Vector3.new(0, ArenaConfig.WallHeight * 0.7, 0)
		)
		--[[
			Dim, and short-ranged enough that the four do not all reach the middle.

			The first pass ran these at 2.4 brightness over 84 studs, which is four overlapping lights on
			every square foot of a 120-stud bowl: the floor went flat grey and every piece of scrap
			rendered white. Scrap art is mostly mid-grey metal, so it has nowhere to go when overexposed --
			and the whole reason to light the arena is to be able to tell one piece from another.
		]]
		local light = Instance.new("PointLight")
		light.Brightness = 0.9
		light.Range = ArenaConfig.FloorRadius * 0.8
		light.Color = Color3.fromRGB(255, 232, 205)
		light.Shadows = true
		light.Parent = host
	end

	return model
end

--- A point on the floor that is not on the pad. Rejection sampling: the pad is small next to the disc.
local function rollFloorPoint(): Vector3
	local origin = ArenaConfig.Origin
	for _ = 1, 24 do
		--- sqrt for an even spread; without it everything crowds the middle, which is the pad.
		local distance = ArenaConfig.FloorRadius * math.sqrt(math.random())
		local angle = math.random() * math.pi * 2
		if distance > ArenaConfig.PadRadius + 2 and distance < ArenaConfig.FloorRadius - 6 then
			return origin
				+ Vector3.new(
					math.cos(angle) * distance,
					ArenaConfig.FloorThickness / 2,
					math.sin(angle) * distance
				)
		end
	end
	--- Every roll landed on the pad or the wall. Take the ring between them and be done.
	local angle = math.random() * math.pi * 2
	local distance = (ArenaConfig.PadRadius + ArenaConfig.FloorRadius) / 2
	return origin
		+ Vector3.new(
			math.cos(angle) * distance,
			ArenaConfig.FloorThickness / 2,
			math.sin(angle) * distance
		)
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
	Add up to `count` pieces, skipping points that land on top of something already there.

	The spacing check is against the scrap folder's own children rather than through `ScrapService`,
	because the only thing that matters here is "is this spot free" and the folder is the cheapest
	possible answer.
]]
local function fill(count: number)
	local folder = scrapFolder
	if folder == nil then
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

	for _ = 1, count do
		local point = nil
		for _ = 1, 8 do
			local candidate = rollFloorPoint()
			local clear = true
			for _, other in existing do
				local flat = (Vector3.new(candidate.X, 0, candidate.Z) - Vector3.new(
					other.X,
					0,
					other.Z
				)).Magnitude
				if flat < ArenaConfig.MinimumSpacing then
					clear = false
					break
				end
			end
			if clear then
				point = candidate
				break
			end
		end
		if point == nil then
			--- The floor is full enough that eight tries found nowhere. Stop rather than stack.
			return
		end
		--[[
			Luck 1: the arena's rarity roll is the BASE one for everybody.

			Rolling it against whoever happens to trigger the refill would mean the hoard's contents
			depended on which player's luck stat got there first, which is indefensible in a shared space.
		]]
		if ScrapService.SpawnPublic(rollScrapId(), point, 1) ~= nil then
			table.insert(existing, point)
		end
	end
end

--[[
	Put everybody standing in the arena back on their own plot.

	Called when the Pit closes. Without it the floor is destroyed under their feet and they fall through
	the void until Roblox resets them, which reads as the game breaking rather than the event ending.
]]
local function evacuate()
	local origin = ArenaConfig.Origin
	local reach = ArenaConfig.FloorRadius + ArenaConfig.WallThickness + 8
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") then
			local flat = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(
				origin.X,
				0,
				origin.Z
			)).Magnitude
			if flat <= reach then
				--[[
					Moved the same way `TeleportService` moves anyone: onto their plot's own spawn pad. Done
					inline rather than through a new `PlotService.TeleportHome`, because one caller does not
					justify a new public API on a service five other things depend on.
				]]
				local plot = PlotService.GetPlot(player)
				local home = if plot then plot:FindFirstChild("PlayerSpawn") else nil
				if home ~= nil and home:IsA("BasePart") and character ~= nil then
					character:PivotTo(home.CFrame + Vector3.new(0, 4, 0))
				end
			end
		end
	end
end

local function open()
	if arena ~= nil then
		return
	end
	local model = build()
	local folder = Instance.new("Folder")
	folder.Name = "PitScrap"
	folder.Parent = model
	model.Parent = workspace

	arena = model
	scrapFolder = folder
	ScrapService.SetPublicFolder(folder)
	--- Built full, not empty: the first player through the door should find a hoard.
	fill(ArenaConfig.TargetScrap)
end

local function close()
	local model = arena
	if model == nil then
		return
	end
	--- People first: the floor is about to stop existing.
	evacuate()
	ScrapService.ClearPublic()
	ScrapService.SetPublicFolder(nil)
	arena = nil
	scrapFolder = nil
	model:Destroy()
end

function ArenaService.Start()
	if started then
		return
	end
	started = true

	task.spawn(function()
		local sinceRefill = 0
		while true do
			task.wait(POLL_SECONDS)
			local live = arenaEvent()
			if live ~= nil and arena == nil then
				open()
			elseif live == nil and arena ~= nil then
				close()
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
