--!strict

return table.freeze({
	PlotCount = 6,
	StreetCount = 2,
	PlotsPerStreet = 3,
	Width = 130,
	Depth = 170,
	MinimumGap = 34,
	DistrictRadius = 325,
	CornerClearance = 15,
	CentralPlazaDiameter = 156,
	StreetWidth = 58,
	IslandDiameter = 1000,
	EntranceLocalZ = -77,
	CrusherLocalZ = 58,
	BackBoundaryLocalZ = 85,
	AuthoredScrapSpawnCount = 22,
	--[[
		A plot's total scrap ceiling. Raised from 28 once markers became pile anchors instead of
		one-piece-each: 22 markers now hold 2-5 pieces depending on how much room they have, which
		tops out around 64. This has to sit above that or the last markers spawn nothing.
	]]
	MaximumActiveScrapPerPlot = 96,
	--[[
		HOW A MARKER BECOMES A PILE. Both numbers are read against a marker's distance to its nearest
		neighbour, so density follows the room the author left rather than a flat count.

		The Front Yard's 8 markers sit 21-27 studs apart and held ONE piece each, which is why it read
		as an empty field with a few objects in it. The Workshop's tightest pair is 5.7 studs apart, so
		a flat count big enough to fill the Front Yard would have piled those two into each other.

		`ScrapPerMarkerDivisor`: pieces = round(nearestNeighbour / this), clamped. At 5 the Front Yard's
		widely spaced markers get 5 pieces each (40 in the yard, up from 8) while the cramped Workshop
		pair still gets the floor of 2 -- which is the point of deriving it rather than setting it.
		`ScrapJitterFraction`: a piece lands anywhere in a disc of nearestNeighbour * this. At 0.42 two
		neighbouring piles do not reach each other; when a pile is too crowded to place a piece cleanly
		`rollPlacement` reaches further, and the overlap test is what keeps that honest.
	]]
	ScrapPerMarkerDivisor = 5,
	ScrapPerMarkerMinimum = 2,
	ScrapPerMarkerMaximum = 6,
	ScrapJitterFraction = 0.42,
	ScrapJitterMaximumStuds = 9,
	TestPlotWorldOrigin = Vector3.new(150, 0, 20),
})
