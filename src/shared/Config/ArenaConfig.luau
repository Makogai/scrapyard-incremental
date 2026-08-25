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

		2. THE AREA LOCK DOES NOT APPLY. A brand-new player standing in the Pit can pull a scrap car,
		   which they could not do on their own plot for hours yet. That is the draw. What still applies
		   is MAGNET STRENGTH, so the upgrade tree keeps its meaning and the reject flash gets to do its
		   job -- you can see the good stuff and you can see that you cannot lift it.

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

--[[
	How much scrap is in there, and how fast it comes back.

	`TargetScrap` is a CAP. The arena never places more pieces than there are spawn nodes, so one
	authored pad means one piece until more pads are added. It starts full (one per empty node) and
	the refill chases the same number.
]]
ArenaConfig.TargetScrap = 90
ArenaConfig.RefillIntervalSeconds = 2
--- Pieces added per refill tick. Low, so a stripped arena visibly fills back in rather than blinking.
ArenaConfig.RefillPerTick = 4

--- How far apart two pieces must be, centre to centre. Loose: crowding is the point of a hoard.
ArenaConfig.MinimumSpacing = 3.5

--[[
	The scrap that spawns in there, weighted.

	EVERY type in the game, weighted by rarity of appearance rather than by area -- so the Pit is where
	you first SEE the late-game scrap. Weights are deliberately flatter than `SpawnWeight` on a plot:
	that curve exists to make a Front Yard feel like a Front Yard, and this is not one.
]]
ArenaConfig.ScrapWeights = table.freeze({
	MetalCan = 10,
	LooseBolt = 10,
	SmallMetalPlate = 9,
	RustyPipe = 9,
	CrushedBucket = 8,
	CopperWire = 8,
	Tire = 8,
	BrokenAppliance = 7,
	ToolBox = 7,
	BrakeDisc = 7,
	Radiator = 6,
	MotorCoil = 6,
	EnginePart = 6,
	CarDoor = 5,
	ExhaustPipe = 5,
	Axle = 4,
	FuelTank = 3,
	ScrapCar = 2,
})

--- The teleport destination id, which `TeleportService` only honours while the arena is open.
ArenaConfig.DestinationId = "Pit"

return table.freeze(ArenaConfig)
