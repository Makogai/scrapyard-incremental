--!strict
--[[
	ArenaConfig.luau
	THE PIT: a shared arena that opens while its event runs, full of scrap nobody owns.

	WHY IT EXISTS. Everything else in this game happens on your own plot, alone. Your scrap is yours, it
	respawns for you, and nobody else can touch it -- which is the right default for an idle game and also
	means two players in the same server never actually interact with the same object. The Pit is the one
	place they do: one hoard, everyone in it, and whoever's magnet reaches a piece first gets it.

	THE THREE RULES THAT MAKE IT WORK, and each one is a deliberate departure from the plot loop:

		1. NOBODY OWNS THE SCRAP. Records spawn with `OwnerUserId = 0`, which `ScrapService` reads as
		   public. The existing `ReservedUserId` already makes the race safe -- first to reserve wins and
		   the loser's magnet simply finds nothing there.

		2. THE AREA LOCK DOES NOT APPLY. A brand-new player standing in the Pit can pull a Drone,
		   which they could not farm on a plot they have not bought yet. That is the draw. What still
		   applies is MAGNET STRENGTH, so the upgrade tree keeps its meaning and the reject flash gets
		   to do its job -- you can see a Robot Arm and you can see that you cannot lift it.

		3. IT REFILLS RATHER THAN RESPAWNING PER PIECE. Plot scrap respawns where it was, on its own
		   timer, because it is yours. A shared hoard topped up onto empty spawn nodes instead means a
		   crowd strips one side and the next piece can land on any free node, so nobody can camp a spot.

	WHERE IT IS. Authored as `Workspace.Event Area`. Players land on `Event Area Spawn Point.PitSpawn`.
	Scrap stands on parts inside `PitScrapSpawns` -- duplicate `Spawn01` in Studio to add more nodes.
]]

local ArenaConfig = {}

--- The event that opens it. `EventConfig` marks this one `Arena = true`; nothing else here checks that.
ArenaConfig.EventId = "ScrapPit"

--- The Studio-authored arena. Looked up by name under Workspace (and NewMap as a fallback).
ArenaConfig.AreaName = "Event Area"
--- The model players teleport onto. Must contain (or get) a `PitSpawn` BasePart.
ArenaConfig.SpawnModelName = "Event Area Spawn Point"
ArenaConfig.SpawnPartName = "PitSpawn"
--- Folder of spawn nodes. Every BasePart (or Model) child is a loot pad; duplicate to add more.
ArenaConfig.ScrapSpawnFolderName = "PitScrapSpawns"
--- Folder of authored Pit scrap models (`Drone`, `Submarine`, `LavaCoreScrap`, `Robot Arm`).
ArenaConfig.EventScrapFolderName = "EventScrap"

--[[
	How much scrap is in there, and how fast it comes back.

	`TargetScrap` is a CAP. The arena never places more pieces than there are spawn nodes, so one
	authored pad means one piece until more pads are added. It starts full (one per empty node) and
	the refill chases the same number.
]]
ArenaConfig.TargetScrap = 90
ArenaConfig.RefillIntervalSeconds = 2
--- Pieces added per refill tick. Low, so a stripped arena visibly fills back in rather than blinking.
--- Six players strip a 39-pad floor fast; 6/tick still reads as a refill, not a blink.
ArenaConfig.RefillPerTick = 6

--- How far apart two pieces must be, centre to centre. Loose: crowding is the point of a hoard.
ArenaConfig.MinimumSpacing = 3.5

--[[
	Magnet reach inside the Event Area is capped. Plot upgrades and pets can push range past 40
	studs, which lets one maxed player vacuum a clustered hoard from a single stand. The Pit is
	supposed to be a crowd; 16 studs is still bigger than a starter magnet (5) and small enough
	that two people standing apart are not grabbing the same pile.
]]
ArenaConfig.MagnetRangeCap = 16

--[[
	Whether a world point sits inside the Event Area's bounding box. Same padding
	`ArenaService.PlayerIsInside` uses. Callers pass the area's GetBoundingBox().
]]
function ArenaConfig.containsPoint(point: Vector3, areaCf: CFrame, areaSize: Vector3): boolean
	local half = areaSize * 0.5 + Vector3.new(8, 20, 8)
	local delta = areaCf:PointToObjectSpace(point)
	return math.abs(delta.X) <= half.X
		and math.abs(delta.Y) <= half.Y
		and math.abs(delta.Z) <= half.Z
end

--[[
	The scrap that spawns in there, weighted.

	PIT-ONLY TYPES. Plot scrap used to fill this list so a new player could see a scrap car
	before they unlocked the Graveyard. That job is now the four authored Pit pieces, and
	the strength gates on those are the reason to upgrade a magnet before Friday.

	Weights are flatter than a plot's `SpawnWeight`: a Front Yard is supposed to feel like
	cans, and this is a shared hoard. Robot Arm is the rare jackpot.
]]
ArenaConfig.ScrapWeights = table.freeze({
	Drone = 40,
	Submarine = 28,
	LavaCoreScrap = 18,
	RobotArm = 8,
})

--[[
	Attribute written onto every public piece that has no plot area. `TryCollect` accepts
	this when `ignoreAreaLock` is set, so Pit scrap is not filed as Front Yard discovery.
]]
ArenaConfig.PublicAreaId = "Pit"

--[[
	How big a Pit piece may be, longest axis, after clone.

	NOT a Studio replacement: plot scrap still stands at authored size. These models were
	built as display pieces and overfill the hoard (pads sit 3.5 studs apart). Only SCALE
	DOWN -- a Robot Arm that is already the jackpot size is left alone. Robot Arm's cap is
	the high one so it stays the big piece on the floor.
]]
ArenaConfig.FitLongestStuds = table.freeze({
	Drone = 3.5,
	Submarine = 6.5,
	LavaCoreScrap = 5,
	RobotArm = 16,
})

--[[
	ONE WRECK at a time. Players standing next to it chip integrity; more people finish it
	faster, one person can finish it alone. It is not magnet-collectable. When it breaks it
	spills public Pit chunks and pays slag to whoever was actually chipping.

	Where it stands: an authored part named `WreckAnchor` under Event Area.
	The art is the Workspace instance named `RobotWreck` or `Robot Wreck`. Pit scrap
	lives in `EventScrap` and must never be used as the wreck.
]]
ArenaConfig.Wreck = table.freeze({
	--[[
		8 HP/s and 120 integrity was 15 seconds for one player. 4 HP/s and 3600 is 15 minutes
		alone, about 2.5 minutes with six people all in range. Chip range is the player's
		magnet reach, not a flat radius.
	]]
	Integrity = 3600,
	ChipPerSecond = 4,
	TickSeconds = 0.25,
	RespawnSeconds = 45,
	ChunkCount = 8,
	ContributorSlag = 12,
	ActivityRequired = true,
	FolderName = "PitWrecks",
	AnchorName = "WreckAnchor",
	--- Longest axis after clone. 48 is a landmark over the 16-stud Robot Arm without being a building.
	FitLongestStuds = 48,
	--- Yaw applied when standing the clone on WreckAnchor. 180 turns the import around.
	YawDegrees = 180,
	--- Seconds of sparks/smoke/shake after HP hits 0, before the mesh shatters.
	BreakdownSeconds = 1.7,
	--[[
		Shield pauses chip DPS until someone magnets the single overload node.
		One node, magnet range (same verb as scrap), then it moves. Groups race;
		a solo player can still do it. Do not require every pad.
		450 HP at 4/s is ~112s solo, ~19s with six in range.
	]]
	ShieldEveryIntegrity = 450,
	ShieldCooldownSeconds = 8,
	--- Skip a late shield so the last sliver is not a fetch quest.
	ShieldSkipBelow = 80,
	NodeMinStuds = 32,
	NodeMaxStuds = 95,
	--- If nobody magnets it, hop to another pad rather than hiding forever.
	NodeRelocateSeconds = 22,
	ShieldBurstCount = 6,
	NodeBurstCount = 4,
	--- World-space HP plate: sits this many studs above the floor, not on the robot's crown.
	BarHeightStuds = 9,
	BarWidthStuds = 10,
	--- The authored model. Never a Pit scrap type.
	ModelNames = table.freeze({ "RobotWreck" }),
	ChunkWeights = table.freeze({
		Drone = 4,
		Submarine = 3,
		LavaCoreScrap = 2,
		RobotArm = 1,
	}),
})

--- The teleport destination id, which `TeleportService` only honours while the arena is open.
ArenaConfig.DestinationId = "Pit"

return table.freeze(ArenaConfig)
