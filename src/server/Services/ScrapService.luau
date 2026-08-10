--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AreaConfig = require(ReplicatedStorage.Shared.Config.AreaConfig)
local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local PlotConfig = require(ReplicatedStorage.Shared.Config.PlotConfig)
local ScrapConfig = require(ReplicatedStorage.Shared.Config.ScrapConfig)
local GameTypes = require(ReplicatedStorage.Shared.Types.GameTypes)
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

local ScrapVariants = require(script.Parent.ScrapVariants)

local ScrapService = {}
local activeByInstance: { [Instance]: ScrapRecord } = {}
local foldersByPlot: { [Model]: Folder } = {}
local templates: Folder
local gameplayEffect: RemoteEvent
local notifyRemote: RemoteEvent
--[[
	Nothing spawns larger than this on its longest axis.

	A default R15 character is about 5 studs tall, and the rule is simply that scrap must never be
	bigger than the player: anything larger reads as a bug, blocks the yard, and cannot be walked
	around. One piece scaled to roughly the size of the map, parked itself inside the collection
	radius, and spammed the magnet warning on every query.

	Raise this if a deliberately oversized piece is wanted later -- it is one number on purpose.
]]
local MAXIMUM_SCRAP_STUDS = 5

--[[
	Below this a measured bounding box is not worth dividing by.

	Normalisation is `declaredSize / measuredSize`, so a model that measures near zero -- an empty
	container, a model whose parts have not replicated, a mis-exported asset -- produces a
	multiplier in the thousands. Refusing to normalise and warning is right; guessing is not.
]]
local MINIMUM_MEASURABLE_STUDS = 0.05

--- How long before the SAME rejection reason may be shown to a player again.
local REJECTION_SAME_REASON_SECONDS = 10

--- Minimum spacing between ANY two rejection notices, so alternating reasons cannot ping-pong.
local REJECTION_ANY_REASON_SECONDS = 4

local lastRejectionNotice: { [Player]: { [string]: number } } = {}
local lastRejectionAt: { [Player]: number } = {}
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

local function weightedVariant(luckMultiplier: number): string
	local weights: { [string]: number } = {}
	local total = 0
	for _, variantId in ScrapConfig.VariantOrder do
		local variant = ScrapConfig.Variants[variantId]
		local weight = if variantId == "Normal"
			then variant.SpawnWeight
			else variant.SpawnWeight * math.max(1, luckMultiplier) ^ variant.LuckExponent
		weights[variantId] = weight
		total += weight
	end
	local roll = math.random() * total
	for _, variantId in ScrapConfig.VariantOrder do
		local weight = weights[variantId]
		roll -= weight
		if roll <= 0 then
			return variantId
		end
	end
	return "Normal"
end

--[[
	The generic treatment: tint every part to the rarity colour, add a highlight and a
	sparkle. This is the FALLBACK, used only for scrap types with no authored model --
	see `ScrapVariants`. Applying it on top of authored art would replace hand-made
	colours with a flat wash and hand-made emitters with one generic puff.
]]
local function addVariantEffects(instance: Instance, variantId: string)
	if variantId == "Normal" then
		return
	end
	local color = ScrapConfig.Variants[variantId].Color
	local highlight = Instance.new("Highlight")
	highlight.Name = `Rarity_{variantId}`
	highlight.FillColor = color
	highlight.OutlineColor = color:Lerp(Color3.new(1, 1, 1), 0.45)
	highlight.FillTransparency = if variantId == "Nebula" then 0.35 else 0.72
	highlight.OutlineTransparency = if variantId == "Rare" then 0.35 else 0.05
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = instance
	local emitterPart = if instance:IsA("BasePart")
		then instance
		else instance:FindFirstChildWhichIsA("BasePart", true)
	if emitterPart then
		local attachment = Instance.new("Attachment")
		attachment.Name = "RarityEffectAttachment"
		attachment.Parent = emitterPart
		local particles = Instance.new("ParticleEmitter")
		particles.Name = ScrapConfig.Variants[variantId].EffectName or "RarityParticles"
		particles.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.55))
		particles.LightEmission = if variantId == "Nebula" then 1 else 0.55
		particles.Lifetime = NumberRange.new(0.45, 1.1)
		particles.Rate = if variantId == "Nebula"
			then 16
			elseif variantId == "Legendary" then 9
			else 4
		particles.Speed = NumberRange.new(0.25, 0.8)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, if variantId == "Nebula" then 0.34 else 0.18),
			NumberSequenceKeypoint.new(1, 0),
		})
		particles.Parent = attachment
	end
end

local function setInstanceCFrame(instance: Instance, target: CFrame)
	if instance:IsA("Model") then
		instance:PivotTo(target)
	elseif instance:IsA("BasePart") then
		instance.CFrame = target
	end
end

--[[
	How far a piece of scrap rests above the marker it spawned on.

	Small and deliberate: it should read as sitting on the ground, not hovering. Zero
	would z-fight the plot floor on flat models like the metal plate.
]]
local SCRAP_HOVER = 0.06

local function boundsOf(instance: Instance): (Vector3, Vector3)
	if instance:IsA("Model") then
		local cframe, size = instance:GetBoundingBox()
		return cframe.Position, size
	elseif instance:IsA("BasePart") then
		return instance.Position, instance.Size
	end
	return Vector3.zero, Vector3.zero
end

--- The true world-space top of a marker, corners included, so a tilted pad still works.
local function markerTopY(marker: BasePart): number
	local highest = -math.huge
	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				local corner =
					marker.CFrame:PointToWorldSpace(marker.Size * Vector3.new(x, y, z) / 2)
				highest = math.max(highest, corner.Y)
			end
		end
	end
	return highest
end

--[[
	Stand an instance on the marker, measured rather than computed.

	Placing it in one shot does not work: `PivotTo` positions the PIVOT, and on an imported model
	the pivot is wherever the exporter left it rather than the centre of the geometry. Measuring
	after placing and shifting by the difference lands the underside on the marker whatever the
	pivot is -- the same reason the richest-player statue is positioned by measurement.

	Shared, because anything that changes a scrap's scale has to re-ground it afterwards.
]]
local function groundOnMarker(instance: Instance, marker: BasePart)
	local flat = marker.CFrame - marker.CFrame.Position
	setInstanceCFrame(instance, flat + marker.CFrame.Position)

	-- measured at the instance's CURRENT scale, which is the whole point of doing it here
	local centre, box = boundsOf(instance)
	local lift = (markerTopY(marker) + box.Y / 2 + SCRAP_HOVER) - centre.Y
	if instance:IsA("Model") then
		instance:PivotTo(instance:GetPivot() + Vector3.new(0, lift, 0))
	elseif instance:IsA("BasePart") then
		instance.CFrame = instance.CFrame + Vector3.new(0, lift, 0)
	end
end

--[[
	Complain about a bad scrap model once per scrap id, not once per spawn.

	Scrap respawns forever, so an unguarded warning here is its own spam problem -- the output
	window fills and hides everything else, which is exactly the failure this pass is fixing.
]]
local warnedScrapIds: { [string]: true } = {}
local function warnOnceForScrap(definition: GameTypes.ScrapDefinition, detail: string)
	local id = tostring(definition.Id)
	if warnedScrapIds[id] then
		return
	end
	warnedScrapIds[id] = true
	warn(`[ScrapService] scrap model for "{id}" {detail}`)
end

--[[
	Size the model to its declared footprint and stand it on the marker.

	Two separate bugs this replaces. Scale: authored models arrive at whatever the
	exporter produced -- the metal can was 3.08 studs tall against a declared 1.7, the
	loose bolt 2.4 against 0.8 -- so they are normalised by their longest axis against
	`definition.Size`. Uniform, so proportions and orientation survive; a model standing
	on the wrong axis is a Studio fix, not something to squash out here. Generic models
	were authored to match `Size` already and are left alone.

	Position: the old code lifted every model a flat 1.5 studs from the marker's centre,
	which floats a bolt and buries a car door. Measuring the model's own box and putting
	its underside on the marker's top surface is right for anything, at any scale.
]]
--[[
	How long a piece of scrap's longest axis should end up, in studs.

	`definition.Size` is documented as "the one place that decides how big a piece of scrap looks
	in the world", and this makes that true -- for authored AND generic art. Generic models used to
	be exempt, on the stated grounds that they were already authored to match. They are not: five
	of them measured 11, 414, 745, 1130 and 1739 studs, which is what produced map-sized scrap.

	The ceiling is last and absolute: nothing is ever bigger than the player. It also bites two
	legitimate definitions whose declared `Size` exceeds it (`ScrapCar` at 8, `RustyPipe` at 5.5);
	raise `MAXIMUM_SCRAP_STUDS` if that is the wrong trade.
]]
local function desiredLongestAxis(definition: GameTypes.ScrapDefinition): number
	local declared = math.max(definition.Size[1], definition.Size[2], definition.Size[3])
	return math.min(declared * (definition.ModelScale or 1), MAXIMUM_SCRAP_STUDS)
end

local function fitToMarker(
	instance: Instance,
	definition: GameTypes.ScrapDefinition,
	marker: BasePart
)
	--[[
		Measured ONCE, up front, and the scale resolves to a single factor applied once.

		Deliberate: chaining a second `ScaleTo` off a re-measured box makes the result depend on
		when the first one settles. The grounding pass does re-measure, because it needs the
		final box.
	]]
	local _, unscaledBox = boundsOf(instance)
	local longest = math.max(unscaledBox.X, unscaledBox.Y, unscaledBox.Z)

	local scale = definition.ModelScale or 1
	if longest < MINIMUM_MEASURABLE_STUDS then
		--[[
			Refuse to divide by a box this small. `target / longest` with a near-zero `longest` is
			an astronomic multiplier, and guessing here would create the very bug being fixed.
		]]
		warnOnceForScrap(
			definition,
			`measures only {string.format("%.4f", longest)} studs -- not resized, `
				.. `check the model has parts and is not an empty container`
		)
	else
		scale = desiredLongestAxis(definition) / longest
	end

	if math.abs(scale - 1) > 0.001 then
		if instance:IsA("Model") then
			instance:ScaleTo(scale)
		elseif instance:IsA("BasePart") then
			-- the net has to cover a single-part scrap too, which `ScaleTo` cannot
			instance.Size *= scale
		end
	end

	groundOnMarker(instance, marker)
end

--[[
	Keep a piece of scrap inside the cap even after its art finishes loading.

	THIS IS THE ONE THAT ACTUALLY MATTERS. Roblox rewrites a `MeshPart`'s `Size` when its mesh
	asset resolves, which can land several frames after the clone is placed -- so the spawn-time
	fit measures a small placeholder box, finds nothing to clamp, and then the mesh snaps to its
	native size. A generic BrakeDisc arrived 413 studs across exactly that way, with its model
	scale left at the untouched `ModelScale` of 1.08, proving the clamp had seen a small box. It
	then sat inside the collection radius being rejected on every query, which is what spammed the
	magnet warning across the whole screen.

	So the cap is re-applied whenever a MeshPart under this scrap changes size, plus once on the
	next frame for art that resolved during the clone. Event-driven, no polling.
]]
local function enforceScrapSize(
	instance: Instance,
	definition: GameTypes.ScrapDefinition,
	marker: BasePart
)
	if instance.Parent == nil then
		return
	end
	local _, box = boundsOf(instance)
	local longest = math.max(box.X, box.Y, box.Z)
	local desired = desiredLongestAxis(definition)
	if longest < MINIMUM_MEASURABLE_STUDS or desired <= 0 then
		return
	end
	-- a fraction of a stud is not worth a re-scale and a re-ground every time a mesh settles
	if math.abs(longest - desired) <= 0.02 then
		return
	end

	local correction = desired / longest
	if instance:IsA("Model") then
		instance:ScaleTo(instance:GetScale() * correction)
	elseif instance:IsA("BasePart") then
		instance.Size *= correction
	end
	-- scaling moved the box, so it has to be stood back on the marker
	groundOnMarker(instance, marker)

	if longest > MAXIMUM_SCRAP_STUDS then
		warnOnceForScrap(
			definition,
			`resolved to {string.format("%.0f", longest)} studs, far past the `
				.. `{MAXIMUM_SCRAP_STUDS}-stud ceiling -- the model itself wants fixing`
		)
	end
end

local function guardSizeAfterLoad(
	instance: Instance,
	definition: GameTypes.ScrapDefinition,
	marker: BasePart
)
	local connections: { RBXScriptConnection } = {}
	local function recheck()
		enforceScrapSize(instance, definition, marker)
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("MeshPart") then
			table.insert(connections, descendant:GetPropertyChangedSignal("Size"):Connect(recheck))
		end
	end
	instance.Destroying:Once(function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
	task.defer(recheck)
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
	--[[
		WHAT SPAWNS IS DECIDED BY THE PLOT'S THEME, NOT BY THE MARKER.

		Areas used to be fenced regions inside one yard, so every plot -- and every variant --
		still carries markers tagged for all three: 8 `FrontYard`, 7 `WorkshopYard`, 7
		`VehicleGraveyard`. Reading the marker's tag to pick the scrap meant a plot showing the
		starting Scrapyard spawned Workshop and Vehicle Graveyard scrap the moment those areas
		were unlocked, which is nonsense now that an area is a theme the WHOLE plot wears.

		The marker's own tag still decides WHETHER it spawns at all -- see the unlock check above.
		That keeps the progression the markers were authored for (unlocking an area earns you more
		spawn points on your yard) and keeps early-game density where it was; with 22 markers and a
		cap of 28 the cap would otherwise never bind. Only the CONTENTS come from the theme.

		The attribute is written by `PlotThemeService.Rebuild`, which runs before scrap is
		activated. Player state is the fallback, and it is the authority if they ever disagree.
	]]
	local areaId = plot:GetAttribute("ActivePlotTheme")
	if typeof(areaId) ~= "string" or AreaConfig.ById[areaId] == nil then
		local plotState = PlayerStateService.GetPlotState(player)
		areaId = plotState and plotState.ActivePlotTheme
	end
	if typeof(areaId) ~= "string" or AreaConfig.ById[areaId] == nil then
		areaId = "FrontYard"
	end
	local scrapId = weightedScrap(areaId)
	local variantId = weightedVariant(PlayerStateService.GetLuckMultiplier(player))
	--[[
		Authored art first. `ScrapVariants` returns the model made for this exact rarity,
		with its own colours and emitters already on it; only when a scrap type has no
		authored folder do we fall back to the one generic model plus the procedural
		treatment below.
	]]
	local authored = ScrapVariants.Get(scrapId, variantId)
	local template = authored or templates:FindFirstChild(ScrapConfig.ById[scrapId].ModelName)
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
	--[[
		Anchoring and collision apply either way -- scrap is a static prop the magnet
		queries, not something physics should own. The COLOUR does not: an authored model
		is already the right colour, and overwriting it would throw the art away.
	]]
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			if authored == nil then
				descendant.Color = ScrapConfig.Variants[variantId].Color
			end
		end
	end
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		if authored == nil then
			instance.Color = ScrapConfig.Variants[variantId].Color
		end
	end
	if authored == nil then
		addVariantEffects(instance, variantId)
	end
	fitToMarker(instance, ScrapConfig.ById[scrapId], marker)
	instance.Parent = folder
	-- parented first: the guard bails on an unparented instance, and mesh sizes resolve after this
	guardSizeAfterLoad(instance, ScrapConfig.ById[scrapId], marker)
	if variantId == "Nebula" then
		notifyRemote:FireAllClients(
			`NEBULA SPAWN! {player.DisplayName} found a {ScrapConfig.ById[scrapId].DisplayName} on their plot!`
		)
		gameplayEffect:FireAllClients("NebulaSpawn", player.DisplayName, scrapId, areaId)
	end
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

local function reserve(
	player: Player,
	record: ScrapRecord,
	distance: number,
	speed: number,
	respawnMultiplier: number
)
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
		local respawnSeconds =
			math.max(0.45, ScrapConfig.ById[record.ScrapId].RespawnSeconds * respawnMultiplier)
		task.delay(respawnSeconds, function()
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
					stats.CollectionSpeed,
					stats.RespawnMultiplier
				)
			elseif reason == "StorageFull" or reason == "TooHeavy" then
				--[[
					Throttled per reason AND per player.

					The old test was `previous.Reason ~= reason`, which fired immediately whenever
					the reason changed -- so a player standing near one too-heavy piece and one
					collectable piece alternated StorageFull / TooHeavy on every query and spammed
					both messages forever, filling the whole notification stack.

					Two gates now: the same reason has a long cooldown, and any two rejection
					notices are spaced, so alternating reasons cannot ping-pong past the first.
				]]
				local now = os.clock()
				local byReason = lastRejectionNotice[player]
				if byReason == nil then
					byReason = {}
					lastRejectionNotice[player] = byReason
				end
				local sameReasonAt = byReason[reason]
				local anyReasonAt = lastRejectionAt[player]
				if
					(sameReasonAt == nil or now - sameReasonAt >= REJECTION_SAME_REASON_SECONDS)
					and (anyReasonAt == nil or now - anyReasonAt >= REJECTION_ANY_REASON_SECONDS)
				then
					byReason[reason] = now
					lastRejectionAt[player] = now
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

--[[
	Stand a plot's scrap up: a fresh `ActiveScrap` folder, and one piece at every enabled marker.

	SAFE TO CALL ON AN ALREADY-ACTIVE PLOT, because it clears first. That is the whole point.

	`PlotThemeService.Rebuild` replaces `RuntimeObjects`' contents and `ScrapSpawnLocations`
	wholesale, which destroys the folder `foldersByPlot` points at and every marker resolved here.
	Both this and the rebuild run off `PlotService.OnAssigned`, and `ScrapService.Start` is called
	first (init.server.luau line 31 vs 50) -- so on *every join* scrap was set up and then
	immediately orphaned by the rebuild, and the plot sat permanently empty. Converting a plot did
	the same thing again.

	So the rebuild calls this afterwards, and ordering stops mattering.

	The two lookups warn instead of asserting: this runs inside a callback list, and a hard error
	here took the rest of the assignment chain with it.
]]
function ScrapService.ActivatePlot(player: Player, plot: Model)
	-- forget anything a previous activation left behind, including a folder the rebuild orphaned
	for instance, record in activeByInstance do
		if record.Plot == plot then
			activeByInstance[instance] = nil
			if instance.Parent ~= nil then
				instance:Destroy()
			end
		end
	end
	foldersByPlot[plot] = nil
	local stale = plot:FindFirstChild("ActiveScrap", true)
	if stale and stale:IsA("Folder") then
		stale:Destroy()
	end

	local runtime = plot:FindFirstChild("RuntimeObjects")
	if runtime == nil then
		warn(`[ScrapService] {plot:GetFullName()} has no RuntimeObjects -- no scrap can spawn`)
		return
	end
	local markers = plot:FindFirstChild("ScrapSpawnLocations")
	if markers == nil then
		warn(`[ScrapService] {plot:GetFullName()} has no ScrapSpawnLocations -- no scrap can spawn`)
		return
	end

	local active = Instance.new("Folder")
	active.Name = "ActiveScrap"
	active.Parent = runtime
	foldersByPlot[plot] = active
	refreshOverlapFilter()
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

--[[
	Drop every active piece of scrap on a plot and forget it.

	Called before a plot's geometry is swapped for a different theme. Without it the records in
	`activeByInstance` keep pointing at destroyed models, and `countPlotScrap` keeps counting
	them -- so the plot would never refill.
]]
function ScrapService.ReleasePlot(plot: Model)
	for instance, record in activeByInstance do
		if record.Plot == plot then
			activeByInstance[instance] = nil
			if instance.Parent ~= nil then
				instance:Destroy()
			end
		end
	end
end

function ScrapService.RefreshPlayer(player: Player)
	local plot = PlotService.GetPlot(player)
	if plot == nil then
		return
	end
	-- `ActivatePlot` clears before it rebuilds, so it is the whole refresh on its own
	ScrapService.ActivatePlot(player, plot)
end

function ScrapService.Start()
	templates = assert(
		ServerStorage:FindFirstChild("ScrapModels"),
		"ServerStorage.ScrapModels required"
	) :: Folder
	print(`[ScrapService] ScrapVariants: {ScrapVariants.Load()}`)
	print(`[ScrapService] {ScrapVariants.PublishPreviews(templates)}`)
	gameplayEffect = RemoteService.GetEvent("GameplayEffect")
	notifyRemote = RemoteService.GetEvent("Notify")
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.MaxParts = Environment.MaximumScrapCandidatesPerQuery
	PlotService.OnAssigned(ScrapService.ActivatePlot)
	PlotService.OnReleased(deactivatePlot)
	Players.PlayerRemoving:Connect(function(player)
		lastRejectionNotice[player] = nil
		lastRejectionAt[player] = nil
	end)
	for player, plot in PlotService.GetAssignments() do
		ScrapService.ActivatePlot(player, plot)
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
