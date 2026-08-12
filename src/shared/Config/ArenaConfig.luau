--!strict
--[[
	ArenaConfig.luau
	THE PIT: a walled arena that appears while its event runs, full of scrap nobody owns.

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
		   timer, because it is yours. A shared hoard topped up to a target count instead means a crowd
		   strips one side of the arena and the refill lands anywhere, so nobody can camp a spot.

	WHERE IT IS. Deliberately off the edge of the map, in the void south of everything, and reached only
	by teleport. Floating is not a compromise -- the walls mean you cannot see out and the nebula sky is
	the backdrop, so the Pit reads as somewhere else rather than as a fenced-off corner of the yard.
]]

local ArenaConfig = {}

--- The event that opens it. `EventConfig` marks this one `Arena = true`; nothing else here checks that.
ArenaConfig.EventId = "ScrapPit"

--[[
	The middle of the arena floor, in world space.

	South of the map, which spans Z -399..179 -- far enough out that nothing can overlap it and no plot
	can ever grow into it. Y matches the plots' floor height so the skybox and lighting read the same.
]]
ArenaConfig.Origin = Vector3.new(250, 65, -560)

--[[
	Geometry. "Huge" was the requirement, so these are big numbers on purpose: 120 studs across is
	roughly the width of a whole plot, and the wall is tall enough that you cannot see over it from the
	floor -- which is what makes the place feel enclosed rather than decorated.
]]
ArenaConfig.FloorRadius = 60
ArenaConfig.FloorThickness = 4
ArenaConfig.WallHeight = 30
ArenaConfig.WallThickness = 6
--- Segments in the ring. 30 is enough that the wall reads as a curve rather than as a polygon.
ArenaConfig.WallSegments = 30

--[[
	How much scrap is in there, and how fast it comes back.

	`TargetScrap` is what the arena is topped up to, not what it starts with -- it starts full and the
	refill chases the same number. 90 across a 120-stud circle is dense enough to see a field of it from
	the entrance and sparse enough to walk through.
]]
ArenaConfig.TargetScrap = 90
ArenaConfig.RefillIntervalSeconds = 2
--- Pieces added per refill tick. Low, so a stripped arena visibly fills back in rather than blinking.
ArenaConfig.RefillPerTick = 4

--[[
	Keep-clear radius around the spawn pad.

	Players arrive here, and arriving inside a pile means the first thing that happens is your magnet
	fires at whatever you materialised on top of. The pad is also where the countdown board stands.
]]
ArenaConfig.PadRadius = 14

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
