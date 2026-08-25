--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AreaConfig = require(ReplicatedStorage.Shared.Config.AreaConfig)
local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local PlotConfig = require(ReplicatedStorage.Shared.Config.PlotConfig)
local ScrapConfig = require(ReplicatedStorage.Shared.Config.ScrapConfig)
local GameTypes = require(ReplicatedStorage.Shared.Types.GameTypes)
local PlayerStateService = require(script.Parent.PlayerStateService)
local PlotService = require(script.Parent.PlotService)
local RemoteService = require(script.Parent.RemoteService)

type ScrapRecord = {
	Instance: Instance,
	--[[
		The marker it stands on, and the plot that owns it. BOTH nil for arena scrap, which has neither: it
		is placed at a rolled point inside a circle and belongs to nobody.
	]]
	Marker: BasePart?,
	Plot: Model?,
	--[[
		Who may take it. `0` means ANYONE -- see `ArenaConfig` for why that exists and what it changes.

		`ReservedUserId` still does the rest: first magnet to reserve a piece gets it and the others find
		nothing there, which is the race the Pit is built around.
	]]
	OwnerUserId: number,
	ScrapId: string,
	AreaId: string,
	VariantId: string,
	ReservedUserId: number?,
	--[[
		Half the piece's widest horizontal measurement, so the scatter can keep pieces out of each
		other. Stored per record rather than measured on demand: the check runs against every other
		piece on the plot on every spawn, and re-measuring 60 bounding boxes each time would be silly.
	]]
	FootprintRadius: number,
	--[[
		When each player was last told THIS piece is out of reach, keyed by user id.

		On the record rather than in a table keyed by player, so it dies with the piece and cannot leak.
		The magnet query runs several times a second; without this the piece would be shaking constantly
		for as long as anyone stood near it.
	]]
	RejectedAt: { [number]: number },
}

local ScrapVariants = require(script.Parent.ScrapVariants)

local ScrapService = {}
local activeByInstance: { [Instance]: ScrapRecord } = {}
local foldersByPlot: { [Model]: Folder } = {}
--[[
	Where arena scrap lives: one folder belonging to no plot.

	`ArenaService` owns the arena's CONTENTS -- it places pieces and tops the count back up. What has to
	live here is the part the magnet touches: this folder in the query filter, the ownership exemption, and
	the collect path that skips every plot check.
]]
local publicFolder: Folder? = nil
local templates: Folder
local gameplayEffect: RemoteEvent
local notifyRemote: RemoteEvent
--[[
	A sanity net, NOT a design knob -- nothing this big can be intentional.

	Scrap size is authored in Studio: the spawner never resizes art to a target, so this is the only
	number that can ever change how big a piece of scrap is. It exists because Roblox rewrites a
	`MeshPart`'s `Size` when its mesh asset resolves, and when that goes wrong the result is absurd
	rather than merely wrong. Measured from the generic templates: `CopperWire` came back 966 studs
	across, others 414, 745, 1130 and 1739. A piece that size parks itself inside every collection
	radius and spams the magnet warning across the screen.

	It is set far above any deliberate size -- a car door at 4 studs, a whole scrap car at 12, are all
	left exactly as authored -- so it only ever catches the runaway case, and it warns by name when it
	does, because the fix belongs in Studio.
]]
local RUNAWAY_SCRAP_STUDS = 24

--[[
	Below this a measured bounding box is not a box at all.

	An empty container, a model whose parts have not replicated, a mis-exported asset. Nothing is
	scaled off this measurement any more, so it is purely a "that model is broken" signal.
]]
local MINIMUM_MEASURABLE_STUDS = 0.05

--- How long before the SAME rejection reason may be shown to a player again.
local REJECTION_SAME_REASON_SECONDS = 10

--- Minimum spacing between ANY two rejection notices, so alternating reasons cannot ping-pong.
local REJECTION_ANY_REASON_SECONDS = 4

--[[
	How often ONE PIECE may flash at ONE PLAYER.

	Separate from the toast throttles above and much shorter, because it answers a different question.
	The toast says WHY, once, quietly. This says WHICH, on the piece itself -- and the whole point is that
	it keeps saying it while you are stood there, so the tint reads as a property of that object rather
	than as a one-off animation you might have missed.

	Tuned against the client's hold time: `SCRAP_REJECT_SECONDS` there is slightly longer than this, so a
	player who does not move sees an unbroken red rather than a flicker.
]]
local REJECTION_FLASH_SECONDS = 1.2

local lastRejectionNotice: { [Player]: { [string]: number } } = {}
local lastRejectionAt: { [Player]: number } = {}
local overlap = OverlapParams.new()

--[[
	The downward cast that finds the floor under a jittered spawn point.

	EXCLUDE, not include: it has to hit whatever the author actually built there -- plot floor, ramp,
	pallet -- and the one thing it must never hit is the scrap already standing on that floor, which
	would stack the yard into towers. Players are handled at the hit instead of on this list, because a
	list of characters goes stale the moment somebody respawns.
]]
local groundRay = RaycastParams.new()
groundRay.FilterType = Enum.RaycastFilterType.Exclude
groundRay.IgnoreWater = true
groundRay.RespectCanCollide = false

local function refreshOverlapFilter()
	local folders = {}
	for _, folder in foldersByPlot do
		table.insert(folders, folder)
	end
	--- The arena's folder is not under any plot, so it has to be added by hand or the magnet misses it.
	if publicFolder ~= nil then
		table.insert(folders, publicFolder)
	end
	overlap.FilterDescendantsInstances = folders
	groundRay.FilterDescendantsInstances = folders
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

--- The counterpart read, so a re-ground can keep the rotation a piece was already given.
local function instanceCFrame(instance: Instance): CFrame
	if instance:IsA("Model") then
		return instance:GetPivot()
	elseif instance:IsA("BasePart") then
		return instance.CFrame
	end
	return CFrame.identity
end

--[[
	How far a piece of scrap rests above the marker it spawned on.

	Small and deliberate: it should read as sitting on the ground, not hovering. Zero
	would z-fight the plot floor on flat models like the metal plate.
]]
local SCRAP_HOVER = 0.06

--[[
	The WORLD-ALIGNED box of a piece of scrap: its centre, and its size along the world axes.

	Computed from the parts' own corners rather than from `Model:GetBoundingBox()` or
	`GetExtentsSize()`, and that is the whole point. BOTH of those Roblox functions return a box
	aligned to the model's PrimaryPart when it has one -- a LOCAL box, not a world one. Grounding needs
	the world height, and models are now stood up at whatever angle they were authored at, so using
	either put scrap at the wrong altitude the moment a model was rotated:

		SmallMetalPlate  floated 1.11 studs, because the local box is 2.35 tall while the plate, lying
		                 flat, is really 0.13 tall in the world
		CrushedBucket    sank 0.16 studs, because its PrimaryPart is turned relative to its geometry

	Both were invisible in a local measurement -- I measured them that way first and read the wrong
	answer, which is exactly the trap this function now closes for every caller.

	Eight corners per part is the honest way to do it: a part contributes its rotated extremes, so a
	tilted or spun model reports the box it actually occupies.
]]
local function boundsOf(instance: Instance): (Vector3, Vector3)
	if instance:IsA("BasePart") then
		--- A lone part still has to be measured rotated: its `Size` is local, its corners are not.
		local minimum, maximum = nil, nil
		local half = instance.Size / 2
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local corner = instance.CFrame * Vector3.new(half.X * x, half.Y * y, half.Z * z)
					minimum = if minimum then minimum:Min(corner) else corner
					maximum = if maximum then maximum:Max(corner) else corner
				end
			end
		end
		if minimum == nil or maximum == nil then
			return instance.Position, instance.Size
		end
		return (minimum + maximum) / 2, maximum - minimum
	end

	if not instance:IsA("Model") then
		return Vector3.zero, Vector3.zero
	end

	local minimum, maximum = nil, nil
	for _, part in instance:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						local corner = part.CFrame * Vector3.new(half.X * x, half.Y * y, half.Z * z)
						minimum = if minimum then minimum:Min(corner) else corner
						maximum = if maximum then maximum:Max(corner) else corner
					end
				end
			end
		end
	end
	if minimum == nil or maximum == nil then
		--- No parts at all. `placeOnMarker` warns about this; here it just means "no box".
		return instance:GetPivot().Position, Vector3.zero
	end
	return (minimum + maximum) / 2, maximum - minimum
end

--[[
	Is this part somebody's body?

	A player standing on a spawn point must not be mistaken for the floor. Checked at the hit rather
	than filtered out up front, because a list of characters goes stale the moment anyone respawns.
]]
local function isCharacterPart(part: BasePart): boolean
	local model = part:FindFirstAncestorWhichIsA("Model")
	while model ~= nil do
		if model:FindFirstChildOfClass("Humanoid") ~= nil then
			return true
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return false
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
	WHERE AND HOW A SINGLE PIECE OF SCRAP SITS. Rolled once at spawn, then kept.

	Kept, rather than re-rolled, because a piece has to be re-grounded when its mesh resolves a few
	frames later -- and re-rolling there would make scrap visibly hop and spin as the yard loaded.
]]
type Placement = {
	--- Where the piece stands, jittered off the marker. Y is the surface its underside lands on.
	Position: Vector3,
	--- Its FINAL world rotation: the random turn already composed with the model's authored angle.
	Rotation: CFrame,
}

--[[
	How far a piece may tip out of true, in degrees.

	Small on purpose. A piece of scrap resting on rubble is never perfectly level, and a few degrees
	reads as exactly that -- but the model's authored angle is what says whether the thing is standing
	up or lying on its side, and a big tilt would throw that away.
]]
local SCRAP_TILT_DEGREES = 7

--[[
	How high a tilt is allowed to lift a piece's far edge off the floor, in studs.

	The tilt is an ANGLE, so what it does to a piece depends entirely on how wide that piece is: 7
	degrees lifts a metal can's corner by a couple of centimetres and the end of a 12-stud scrap car
	by three quarters of a stud. The first reads as "resting on gravel", the second as "floating".

	So the angle is capped per piece by this distance instead. Small objects still get the full tilt;
	long ones get however much keeps them visibly on the ground.
]]
local MAXIMUM_TILT_LIFT_STUDS = 0.28

--[[
	The turn a piece of scrap spawns with: a random yaw, and a lean capped by how wide the piece is.

	Shared by both placements. `rollPlacement` picks a spot in a marker's disc; `rollPlacementAt` is handed
	one. Neither should have its own idea of how scrap is angled, or arena scrap would visibly sit
	differently from plot scrap.

	ONE LEAN OF AN EXACT SIZE, about a random horizontal axis. Tilting independently on X and Z was the
	obvious way to write it and is not bounded: the two combine, so a 7-degree cap on each produced a
	10-degree lean in the corner direction. A single angle about a random axis looks just as random and its
	size is exactly what it says.

	The cap is measured across the piece's FULL width, because what reads as floating is the far edge
	against the floor -- not the middle. A brake disc, being flat and wide, is what this binds on.
]]
local function scatterRotation(authored: CFrame, ownRadius: number): CFrame
	local widest = math.max(ownRadius * 2, 0.01)
	local allowed = math.min(
		math.rad(SCRAP_TILT_DEGREES),
		math.asin(math.min(1, MAXIMUM_TILT_LIFT_STUDS / widest))
	)
	local axis = math.random() * math.pi * 2
	local lean = CFrame.fromAxisAngle(
		Vector3.new(math.cos(axis), 0, math.sin(axis)),
		allowed * math.random()
	)
	return lean * CFrame.Angles(0, math.random() * math.pi * 2, 0) * authored
end

--[[
	Roll a placement for one piece: somewhere in the marker's disc, turned to face anywhere.

	SCATTER, NOT A GRID. Every marker used to hold exactly one piece at its exact centre and exact
	angle, so a yard read as rows of objects at regular intervals -- and because the marker never
	moved, clearing an area and waiting rebuilt the identical formation piece for piece. Now the
	marker is a pile ANCHOR: position is jittered inside its own disc and the turn is random, so no
	two respawns look the same.

	`radius` comes from the marker's distance to its nearest neighbour (see `PlotConfig`), so a piece
	can never wander into the next pile however far apart the author spaced them.

	THE YAW IS APPLIED ON TOP OF THE AUTHORED ROTATION, and the tilt is small. That is what keeps this
	compatible with sizing and posing models in Studio: a can authored lying on its side stays lying on
	its side, it just points somewhere different each time.

	IT ALSO REFUSES TO PUT TWO PIECES INSIDE EACH OTHER. Scatter alone produced pairs 0.74 studs apart
	-- touching is what a scrapyard looks like, but intersecting is what a bug looks like -- so each
	candidate spot is scored against the pieces already on the plot and the best of a handful wins.
	Best-of-N rather than retry-until-clear on purpose: a crowded pile has no clear spot left, and a
	loop that insists on one would never end.

	AND IT WIDENS ITS SEARCH WHEN CROWDED. Best-of-8 inside a fixed disc still left 9 intersecting pairs
	out of 60 pieces, because in the Workshop -- where the tightest markers are 5.7 studs apart, so the
	disc is only 2.4 studs wide -- there was genuinely nowhere clear to put the second piece. Later
	attempts reach progressively further out, which is safe precisely because the clearance test is
	against real pieces rather than against the disc: wandering towards a neighbouring pile is only
	allowed if that pile has room.
]]
local SCATTER_ATTEMPTS = 16

--- How much further than its own disc a crowded piece may reach by the last attempt.
local SCATTER_REACH = 2.2

local function rollPlacement(
	marker: BasePart,
	radius: number,
	authored: CFrame,
	ownRadius: number,
	occupied: { ScrapRecord }
): Placement
	--- The spot furthest from its neighbours out of several tries, unless one is simply clear.
	local offset = Vector3.zero
	local bestClearance = -math.huge
	for attempt = 1, SCATTER_ATTEMPTS do
		--- Each failed attempt reaches a little further out, so a crowded pile can still find space.
		local reach = 1 + (attempt - 1) / (SCATTER_ATTEMPTS - 1) * (SCATTER_REACH - 1)
		--- sqrt keeps the scatter even across the disc; without it everything crowds the centre
		local distance = radius * reach * math.sqrt(math.random())
		local angle = math.random() * math.pi * 2
		local candidate = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local point = marker.CFrame.Position + candidate

		--[[
			Clearance is the gap left AFTER both footprints are accounted for, so a big car door needs
			more room than a bolt and the test is symmetric between the two pieces.
		]]
		local clearance = math.huge
		for _, record in occupied do
			local other = instanceCFrame(record.Instance).Position
			local flat = (Vector3.new(point.X, 0, point.Z) - Vector3.new(other.X, 0, other.Z)).Magnitude
			clearance = math.min(clearance, flat - ownRadius - record.FootprintRadius)
		end

		if clearance > bestClearance then
			bestClearance = clearance
			offset = candidate
		end
		--- Already clear of everything: no reason to keep rolling.
		if clearance >= 0 then
			break
		end
		--- Nothing to avoid at all, so the first roll is as good as any.
		if attempt == 1 and clearance == math.huge then
			break
		end
	end

	local surfaceY = markerTopY(marker)
	--[[
		FIND THE REAL FLOOR UNDER THE JITTERED POINT, and refuse the jitter if there isn't one.

		The marker's own height is only the right answer directly above the marker. Jitter a piece
		sideways and it can end up over a kerb, a pallet or the lip of the plot, where using the
		marker's height would leave it floating or buried. So the surface is measured, and a hit
		further than `SURFACE_TOLERANCE` from the marker's own height means the piece has wandered
		somewhere structurally different -- onto a container roof, into a pit -- and it goes back to
		the marker instead.
	]]
	local SURFACE_TOLERANCE = 3
	local origin = marker.CFrame.Position + offset + Vector3.new(0, 8, 0)
	local hit = workspace:Raycast(origin, Vector3.new(0, -24, 0), groundRay)
	local position
	if
		hit ~= nil
		and not isCharacterPart(hit.Instance)
		and math.abs(hit.Position.Y - surfaceY) <= SURFACE_TOLERANCE
	then
		position = Vector3.new(origin.X, hit.Position.Y, origin.Z)
	else
		position = Vector3.new(marker.CFrame.Position.X, surfaceY, marker.CFrame.Position.Z)
	end

	return { Position = position, Rotation = scatterRotation(authored, ownRadius) }
end

--[[
	A placement at a KNOWN point, for scrap that has no marker.

	The arena chooses its own points -- it is a circle, not a set of authored pads -- so the only work left
	is the two things a marker would otherwise have supplied: the floor height under that point, and the
	turn. Both are the same rules a plot uses, which is why arena scrap sits and leans identically.

	No surface tolerance to check against here. On a plot the tolerance guards against a jittered piece
	wandering onto a container roof; the arena is a flat disc with walls, so whatever the ray hits IS the
	floor, and a miss can only mean the geometry has not been built yet.
]]
local function rollPlacementAt(point: Vector3, authored: CFrame, ownRadius: number): Placement
	local hit = workspace:Raycast(point + Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), groundRay)
	local surfaceY = if hit ~= nil and not isCharacterPart(hit.Instance)
		then hit.Position.Y
		else point.Y
	return {
		Position = Vector3.new(point.X, surfaceY, point.Z),
		Rotation = scatterRotation(authored, ownRadius),
	}
end

--[[
	Stand an instance on its placement, measured rather than computed.

	Setting the CFrame in one shot does not work: `PivotTo` positions the PIVOT, and on an imported
	model the pivot is wherever the exporter left it rather than the centre of the geometry. Measuring
	after placing and shifting by the difference lands the underside on the surface whatever the pivot
	is -- the same reason the richest-player statue is positioned by measurement.

	Shared, because anything that moves or re-scales a scrap has to re-ground it afterwards. Idempotent
	on purpose: called again with the same placement, a piece lands in exactly the same spot.
]]
local function standAt(instance: Instance, placement: Placement)
	setInstanceCFrame(instance, placement.Rotation + placement.Position)

	-- measured at the instance's CURRENT scale, which is the whole point of doing it here
	local centre, box = boundsOf(instance)
	local lift = (placement.Position.Y + box.Y / 2 + SCRAP_HOVER) - centre.Y
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
	Pull a runaway model back to something the game can survive, or leave it completely alone.

	Not a fit and not a design decision: the ONLY case this acts on is a model so large it breaks
	collection, and it says so in the output rather than quietly making the art a different size.
	See `RUNAWAY_SCRAP_STUDS` for why the case exists at all.
]]
local function clampIfRunaway(instance: Instance, definition: GameTypes.ScrapDefinition)
	local _, box = boundsOf(instance)
	local longest = math.max(box.X, box.Y, box.Z)
	if longest <= RUNAWAY_SCRAP_STUDS then
		return
	end

	local correction = RUNAWAY_SCRAP_STUDS / longest
	if instance:IsA("Model") then
		instance:ScaleTo(instance:GetScale() * correction)
	elseif instance:IsA("BasePart") then
		-- the net has to cover a single-part scrap too, which `ScaleTo` cannot
		instance.Size *= correction
	end
	warnOnceForScrap(
		definition,
		`measures {string.format("%.0f", longest)} studs across -- clamped to `
			.. `{RUNAWAY_SCRAP_STUDS} so it does not break collection. Fix the model's size in Studio; `
			.. `the spawner does not resize art.`
	)
end

--[[
	Pit hoard presentation. SCALE DOWN ONLY, to `ArenaConfig.FitLongestStuds`.

	These four models were authored as display pieces and overfill the 3.5-stud spawn
	grid. Plot scrap is untouched. Robot Arm's cap is the highest so it stays the
	large jackpot on the floor.
]]
local function fitPitScrap(instance: Instance, definition: GameTypes.ScrapDefinition)
	if definition.PitOnly ~= true then
		return
	end
	local target = ArenaConfig.FitLongestStuds[definition.Id]
	if typeof(target) ~= "number" or target <= 0 then
		return
	end
	local _, box = boundsOf(instance)
	local longest = math.max(box.X, box.Y, box.Z)
	if longest < MINIMUM_MEASURABLE_STUDS or longest <= target then
		return
	end
	local correction = target / longest
	if instance:IsA("Model") then
		instance:ScaleTo(instance:GetScale() * correction)
	elseif instance:IsA("BasePart") then
		instance.Size *= correction
	end
end

--[[
	Put a piece of scrap on its marker EXACTLY as it was authored: same size, same rotation.

	THIS IS THE WHOLE CONTRACT. Whatever a model looks like in Studio is what appears in the yard, so
	scale and rotate the template and the game follows. Nothing here scales art to fit a number.

	What this replaces, and why it went: every model used to be normalised against a declared
	`ScrapConfig.Size`, then turned by a `ModelRotation` to correct art exported on the wrong axis,
	then spun by a random yaw. It worked, but it made the art untunable -- the only way to change how a
	piece of scrap looked was to edit config numbers, restart, and go and look at it -- and it threw
	away whatever an artist had done in Studio. Sizing a model in Studio, where you can see it, is
	simply a better loop.

	The one thing still computed is HEIGHT, because the placement decides where a piece stands and only
	the model knows how tall it is. `standAt` measures the box and lands the underside on the surface at
	whatever angle the model is saved at, plus the scatter turn from `rollPlacement`.
]]
local function placeScrap(
	instance: Instance,
	definition: GameTypes.ScrapDefinition,
	placement: Placement
)
	local _, box = boundsOf(instance)
	local longest = math.max(box.X, box.Y, box.Z)
	if longest < MINIMUM_MEASURABLE_STUDS then
		warnOnceForScrap(
			definition,
			`measures only {string.format("%.4f", longest)} studs -- check the model has parts `
				.. `and is not an empty container`
		)
	end

	clampIfRunaway(instance, definition)
	fitPitScrap(instance, definition)
	standAt(instance, placement)
end

--[[
	Re-stand a piece of scrap once its art has finished loading.

	Roblox rewrites a `MeshPart`'s `Size` when its mesh asset resolves, which can land several frames
	after the clone is placed. Nothing re-sizes art to a target any more, but a box that changes AFTER
	placement leaves the piece floating above its spot or sunk into it, so it has to be re-grounded --
	and a mesh that snaps to a native 966 studs still has to be caught.

	It re-uses the SAME placement, which is why placements are rolled once and kept: re-rolling here
	would make every piece of scrap hop to a new spot and spin as the yard finished loading.

	Driven by the size change itself, plus once on the next frame for art that resolved during the
	clone. Event-driven, no polling.
]]
local function restandAfterLoad(
	instance: Instance,
	definition: GameTypes.ScrapDefinition,
	placement: Placement
)
	if instance.Parent == nil then
		return
	end
	clampIfRunaway(instance, definition)
	fitPitScrap(instance, definition)
	standAt(instance, placement)
end

local function guardSizeAfterLoad(
	instance: Instance,
	definition: GameTypes.ScrapDefinition,
	placement: Placement
)
	local connections: { RBXScriptConnection } = {}
	local function recheck()
		restandAfterLoad(instance, definition, placement)
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

--[[
	HOW MUCH ROOM A MARKER HAS, cached on the marker itself.

	Both the pile size and the scatter radius come from a marker's distance to its nearest neighbour,
	which is a property of the LAYOUT rather than of any one spawn -- so it is measured once when the
	plot activates and written to the marker as an attribute.

	On the marker deliberately, not in a table keyed by marker: `PlotThemeService.Rebuild` destroys and
	replaces `ScrapSpawnLocations` wholesale, and a table would quietly accumulate dead markers for the
	life of the server. An attribute dies with the instance it is on.
]]
local NEIGHBOUR_ATTRIBUTE = "ScrapNeighbourStuds"

local function measureMarkerSpacing(markers: Instance)
	local parts = {}
	for _, marker in markers:GetChildren() do
		if marker:IsA("BasePart") then
			table.insert(parts, marker)
		end
	end
	for index, marker in parts do
		local nearest = math.huge
		for other, candidate in parts do
			if other ~= index then
				nearest = math.min(nearest, (marker.Position - candidate.Position).Magnitude)
			end
		end
		--- A lone marker has no neighbour to crowd, so it gets the widest scatter allowed.
		if nearest == math.huge then
			nearest = PlotConfig.ScrapJitterMaximumStuds / PlotConfig.ScrapJitterFraction
		end
		marker:SetAttribute(NEIGHBOUR_ATTRIBUTE, nearest)
	end
end

local function neighbourStudsOf(marker: BasePart): number
	local measured = marker:GetAttribute(NEIGHBOUR_ATTRIBUTE)
	if typeof(measured) == "number" and measured > 0 then
		return measured
	end
	--- Never measured -- a respawn onto a marker from a rebuild that raced us. A middling guess is fine.
	return 12
end

local function jitterRadiusOf(marker: BasePart): number
	return math.min(
		neighbourStudsOf(marker) * PlotConfig.ScrapJitterFraction,
		PlotConfig.ScrapJitterMaximumStuds
	)
end

--- How many pieces this marker's pile holds: the more room it has, the more scrap it gets.
local function pileSizeOf(marker: BasePart): number
	local pieces = math.round(neighbourStudsOf(marker) / PlotConfig.ScrapPerMarkerDivisor)
	return math.clamp(pieces, PlotConfig.ScrapPerMarkerMinimum, PlotConfig.ScrapPerMarkerMaximum)
end

--- Every piece already standing on this plot, which is what a new one has to avoid.
local function plotRecords(plot: Model): { ScrapRecord }
	local records = {}
	for _, record in activeByInstance do
		if record.Plot == plot and record.Instance.Parent ~= nil then
			table.insert(records, record)
		end
	end
	return records
end

--[[
	Put one piece of arena scrap at a world point. Returns the instance, or nil if it could not be made.

	Deliberately NOT a variant of `spawnAt`: that function is about a plot -- it reads the plot's theme,
	counts the plot's scrap against a per-plot cap, and hands the record a marker to respawn on. None of
	that applies here, and threading four "unless it is the arena" branches through it would have made the
	plot path harder to read to save duplicating the twenty lines below.

	What it DOES share is everything that decides how scrap looks and sits: the same templates, the same
	rarity roll, the same authored-art fallback, `placeScrap` for the size and the lean, and
	`guardSizeAfterLoad` for the late mesh resolve. So arena scrap is the same art, standing the same way.
]]
function ScrapService.SpawnPublic(
	scrapId: string,
	position: Vector3,
	luckMultiplier: number
): Instance?
	local folder = publicFolder
	local definition = ScrapConfig.ById[scrapId]
	if folder == nil or definition == nil then
		return nil
	end

	local variantId = weightedVariant(luckMultiplier)
	local authored = ScrapVariants.Get(scrapId, variantId)
	local baseArt = authored or ScrapVariants.Get(scrapId, "Normal")
	local template = baseArt
	if template == nil and templates ~= nil then
		template = templates:FindFirstChild(definition.ModelName)
	end
	if template == nil then
		return nil
	end

	local instance = template:Clone()
	instance.Name = `Pit_{scrapId}`
	instance:SetAttribute("ScrapId", scrapId)
	instance:SetAttribute("VariantId", variantId)
	--[[
		Pit-only scrap has no plot area. Recording "FrontYard" would file a Robot Arm as a
		Front Yard discovery; recording nothing would fail `TryCollect`'s area lookup. `Pit`
		is a sentinel `CanCollect` accepts only with `ignoreAreaLock`.
	]]
	local areaId = if definition.PitOnly == true or #definition.AreaIds == 0
		then ArenaConfig.PublicAreaId
		else definition.AreaIds[1]
	instance:SetAttribute("AreaId", areaId)
	instance:SetAttribute("OwnerUserId", 0)
	instance:SetAttribute("ReservedUserId", 0)

	--[[
		Pit models are authored art sitting in ScrapModels, not the generic tinted box.
		Washing them to the rarity swatch is what threw away the colours set in Studio.
		Rare+ still gets the highlight overlay when there is no per-rarity mesh.
	]]
	local flattenColour = baseArt == nil and definition.PitOnly ~= true
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			if flattenColour then
				descendant.Color = ScrapConfig.Variants[variantId].Color
			end
		end
	end
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		if flattenColour then
			instance.Color = ScrapConfig.Variants[variantId].Color
		end
	end
	if authored == nil then
		addVariantEffects(instance, variantId)
	end

	--- Same scatter rules as a plot: authored rotation, a random yaw, a capped lean, stood on the floor.
	local authoredCFrame = instanceCFrame(instance)
	local _, ownBox = boundsOf(instance)
	local placement = rollPlacementAt(
		position,
		authoredCFrame - authoredCFrame.Position,
		math.max(ownBox.X, ownBox.Z) / 2
	)
	placeScrap(instance, definition, placement)
	instance.Parent = folder
	guardSizeAfterLoad(instance, definition, placement)

	activeByInstance[instance] = {
		Instance = instance,
		Marker = nil,
		Plot = nil,
		OwnerUserId = 0,
		ScrapId = scrapId,
		AreaId = areaId,
		VariantId = variantId,
		ReservedUserId = nil,
		FootprintRadius = math.max(ownBox.X, ownBox.Z) / 2,
		RejectedAt = {},
	}
	return instance
end

--- Where arena scrap is parented, and what the magnet query has to include to find it.
function ScrapService.SetPublicFolder(folder: Folder?)
	publicFolder = folder
	refreshOverlapFilter()
end

--- Every public piece currently standing, so `ArenaService` can count and top up.
function ScrapService.CountPublic(): number
	local count = 0
	for _, record in activeByInstance do
		if record.OwnerUserId == 0 and record.Instance.Parent ~= nil then
			count += 1
		end
	end
	return count
end

--- Drop every public piece. Called when the arena closes.
function ScrapService.ClearPublic()
	for instance, record in activeByInstance do
		if record.OwnerUserId == 0 then
			activeByInstance[instance] = nil
			if instance.Parent ~= nil then
				instance:Destroy()
			end
		end
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

local spawnAt: (Player, Model, BasePart) -> ()

--[[
	An uncollected piece eventually despawns and a new random one takes its place.

	Without this a pile you walked past stayed the same cans until you picked them, so the
	yard stopped looking like a random scrap pile. Collection respawn is a separate delay
	on the magnet path. Arena scrap is not refreshed: the pit tops up to a count.
]]
local function refreshStanding(player: Player, record: ScrapRecord)
	local instance = record.Instance
	if activeByInstance[instance] ~= record or instance.Parent == nil then
		return
	end
	if record.ReservedUserId ~= nil then
		task.delay(1, function()
			refreshStanding(player, record)
		end)
		return
	end
	local marker = record.Marker
	local plot = record.Plot
	activeByInstance[instance] = nil
	instance:Destroy()
	if
		player.Parent ~= nil
		and marker ~= nil
		and marker.Parent ~= nil
		and plot ~= nil
		and PlotService.IsOwner(player, plot)
	then
		spawnAt(player, plot, marker)
	end
end

local function scheduleIdleRefresh(player: Player, record: ScrapRecord)
	if record.OwnerUserId == 0 then
		return
	end
	local spread = ScrapConfig.IdleRefreshSpread
	local waitFor = ScrapConfig.IdleRefreshSeconds * ((1 - spread) + math.random() * spread * 2)
	task.delay(waitFor, function()
		refreshStanding(player, record)
	end)
end

spawnAt = function(player: Player, plot: Model, marker: BasePart)
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
	--[[
		FALL BACK TO THE NORMAL ART BEFORE FALLING BACK TO A BOX.

		Only three scrap types have art for all five rarities; the other fifteen have a Normal model and
		nothing else. Those used to drop straight to the generic template, which for most types is a plain
		`Part` with a name label on it -- so a Rare appliance spawned as a blue cube reading "APPLIANCE"
		next to fifteen hand-made ones. At roughly 4% of spawns that is two or three boxes visible in the
		yard at any moment.

		The hand-made Normal model wearing the rarity highlight and emitter is better in every way: it
		still reads as rare at a glance, and it reads as an appliance.
	]]
	local baseArt = authored or ScrapVariants.Get(scrapId, "Normal")
	local template = baseArt or templates:FindFirstChild(ScrapConfig.ById[scrapId].ModelName)
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
		Anchoring and collision apply either way -- scrap is a static prop the magnet queries, not
		something physics should own.

		The COLOUR is only flattened on the generic box, which has no art to lose. Hand-made art keeps its
		own colours whether or not it was made for this rarity, because a flat rarity wash over a detailed
		model looks worse than the model does.
	]]
	local flattenColour = baseArt == nil
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			if flattenColour then
				descendant.Color = ScrapConfig.Variants[variantId].Color
			end
		end
	end
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		if flattenColour then
			instance.Color = ScrapConfig.Variants[variantId].Color
		end
	end
	--- The rarity glow goes on anything that is not purpose-made for this rarity, art included.
	if authored == nil then
		addVariantEffects(instance, variantId)
	end
	--[[
		The placement is rolled ONCE, here, and read off the clone BEFORE it is moved -- at this point
		its rotation is still the one the model was authored with, which is what the scatter turn has to
		be composed on top of. Reading it after `placeScrap` would compound the previous roll.
	]]
	local authoredCFrame = instanceCFrame(instance)
	--[[
		KNOCKED OVER, sometimes. A `TumbleChance` attribute on the model says how often a piece spawns
		on its side instead of the way it was posed -- 0.4 means roughly two cans in five are lying down.

		An attribute on the MODEL rather than a field in `ScrapConfig`, so posing a piece of scrap stays
		one job in one place: you pose it in Studio, and you say there how reliably it stays posed. A
		yard of cans all standing perfectly upright is the tell that nothing ever knocked them over.
	]]
	local tumbleChance = template:GetAttribute("TumbleChance")
	if typeof(tumbleChance) == "number" and math.random() < tumbleChance then
		authoredCFrame = CFrame.Angles(math.rad(90), 0, 0)
			* (authoredCFrame - authoredCFrame.Position)
	end
	local _, ownBox = boundsOf(instance)
	--- Widest horizontal half-measure: what the piece takes up on the floor, whichever way it is turned.
	local footprintRadius = math.max(ownBox.X, ownBox.Z) / 2
	local placement = rollPlacement(
		marker,
		jitterRadiusOf(marker),
		authoredCFrame - authoredCFrame.Position,
		footprintRadius,
		plotRecords(plot)
	)
	placeScrap(instance, ScrapConfig.ById[scrapId], placement)
	instance.Parent = folder
	-- parented first: the guard bails on an unparented instance, and mesh sizes resolve after this
	guardSizeAfterLoad(instance, ScrapConfig.ById[scrapId], placement)
	if variantId == "Nebula" then
		notifyRemote:FireAllClients(
			`NEBULA SPAWN! {player.DisplayName} found a {ScrapConfig.ById[scrapId].DisplayName} on their plot!`
		)
		gameplayEffect:FireAllClients("NebulaSpawn", player.DisplayName, scrapId, areaId)
	end
	local record: ScrapRecord = {
		Instance = instance,
		Marker = marker,
		Plot = plot,
		OwnerUserId = player.UserId,
		ScrapId = scrapId,
		AreaId = areaId,
		VariantId = variantId,
		ReservedUserId = nil,
		FootprintRadius = footprintRadius,
		RejectedAt = {},
	}
	activeByInstance[instance] = record
	scheduleIdleRefresh(player, record)
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
	--- `OwnerUserId == 0` is arena scrap: anyone may take it, first to reserve wins.
	local public = record.OwnerUserId == 0
	if record.ReservedUserId ~= nil or not (public or record.OwnerUserId == player.UserId) then
		return
	end
	record.ReservedUserId = player.UserId
	record.Instance:SetAttribute("ReservedUserId", player.UserId)
	local duration = math.clamp(distance / math.max(speed, 1), 0.12, 0.75)
	gameplayEffect:FireClient(player, "AttractScrap", record.Instance, duration)
	task.delay(duration, function()
		--[[
			The plot-ownership re-check is skipped for arena scrap, which has no plot to own. Everything else
			still holds: the record must still be live and still reserved by this player, so a piece somebody
			else took in the meantime cannot be collected twice.
		]]
		local plot = record.Plot
		if
			activeByInstance[record.Instance] ~= record
			or record.ReservedUserId ~= player.UserId
			or (not public and (plot == nil or not PlotService.IsOwner(player, plot)))
		then
			return
		end
		local collected = PlayerStateService.TryCollect(
			player,
			record.ScrapId,
			record.VariantId,
			record.AreaId,
			public
		)
		if not collected then
			record.ReservedUserId = nil
			record.Instance:SetAttribute("ReservedUserId", 0)
			return
		end
		activeByInstance[record.Instance] = nil
		gameplayEffect:FireClient(player, "Collected", record.ScrapId, record.VariantId)
		record.Instance:Destroy()
		--[[
			Arena scrap does not respawn where it fell. `ArenaService` tops the arena back up to a target
			count instead, so a crowd stripping one side does not leave that side permanently bare -- see
			`ArenaConfig`.
		]]
		if public then
			return
		end
		--[[
			DESYNCHRONISED ON PURPOSE. A fixed delay means a pile cleared in one sweep comes back in one
			sweep, all together, in the same formation -- which is the "it appears as a grid" complaint.
			A spread of +/-30% staggers a pile back into existence piece by piece instead.
		]]
		local spread = 0.7 + math.random() * 0.6
		--[[
			THE FLOOR IS A FRACTION OF THIS SCRAP'S OWN INTERVAL, not a flat number of seconds.

			It used to be `max(0.45, ...)`, which meant a 2-second can and a 12-second scrap car could both
			bottom out at 0.45s -- so at high Spawn Rate the difference between cheap and expensive scrap
			quietly disappeared, and the car became six times more common relative to its price. A
			proportional floor keeps the ratio between scrap types intact however fast the player makes it.
		]]
		local base = ScrapConfig.ById[record.ScrapId].RespawnSeconds
		local respawnSeconds =
			math.max(base * ScrapConfig.MinimumRespawnFraction, base * respawnMultiplier * spread)
		task.delay(respawnSeconds, function()
			local marker = record.Marker
			local ownerPlot = record.Plot
			if
				marker ~= nil
				and marker.Parent ~= nil
				and ownerPlot ~= nil
				and PlotService.IsOwner(player, ownerPlot)
			then
				spawnAt(player, ownerPlot, marker)
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
		--[[
			Two ways a piece can be yours to take: it is on your plot, or it belongs to nobody.

			The arena case skips the plot comparison entirely -- arena records have no plot -- and skips the
			area lock further down, which is what lets a new player pull a scrap car in there.
		]]
		local public = record ~= nil and record.OwnerUserId == 0
		if
			record
			and record.ReservedUserId == nil
			and (public or (record.Plot == plot and record.OwnerUserId == player.UserId))
		then
			checked += 1
			local eligible, reason =
				PlayerStateService.CanCollect(player, record.ScrapId, record.AreaId, public)
			if not eligible and reason == "StorageFull" then
				--[[
					AUTO SELL has to fire HERE, not only after a successful pickup.

					A full bag is refused by `CanCollect`, so `TryCollect` never runs and the pass
					that is supposed to dump a full bag would never dump one. Sell, then ask again
					so this same piece can be reserved in the same query.
				]]
				if PlayerStateService.AutoSellIfFull(player) then
					eligible, reason =
						PlayerStateService.CanCollect(player, record.ScrapId, record.AreaId, public)
				end
			end
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
					POINT AT THE PIECE, not just at the player.

					The toast below says why, and it is throttled to seconds because repeating it is
					noise. What it could never say is WHICH piece -- so a player standing in a pile with
					one too-heavy radiator in it was told "magnet too weak" with nothing to look at, and
					the only way to find out which one was to walk away and come back.

					Sent per piece per player on its own short throttle, and the client turns it into a
					tint and a shake on that exact model. Two reasons, two colours -- see
					`ScrapController`.
				]]
				local flashNow = os.clock()
				local lastFlash = record.RejectedAt[player.UserId]
				if lastFlash == nil or flashNow - lastFlash >= REJECTION_FLASH_SECONDS then
					record.RejectedAt[player.UserId] = flashNow
					gameplayEffect:FireClient(player, "RejectScrap", record.Instance, reason)
				end
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
	--- Spacing first: both the pile size and the scatter radius are read from it.
	measureMarkerSpacing(markers)
	for _, marker in markers:GetChildren() do
		if marker:IsA("BasePart") and marker:GetAttribute("Enabled") ~= false then
			--[[
				A PILE, not a piece. One piece per marker put 8 objects on a Front Yard whose markers sit
				21-27 studs apart, which is what made the yard read as an empty field -- see `pileSizeOf`.
			]]
			for _ = 1, pileSizeOf(marker) do
				spawnAt(player, plot, marker)
			end
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
	print(`[ScrapService] {ScrapVariants.AdoptWorkspaceModels(templates)}`)
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
