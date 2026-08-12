--!strict
--[[
	MagnetRangeController.luau
	Draws the local player's magnet reach on the ground.

	LOCAL ONLY. These parts are made on the client and never replicate, so every player sees their own
	reach and nobody else's -- which is the whole point of the readout. It is the one thing on screen that
	answers "will that piece come to me if I stand here".

	EVERY MAGNET LOOKS DIFFERENT, and the look comes from `InventoryConfig.Magnets[id].RangeRing`, not from
	a branch in here. Basic gets one hairline ring; Advanced adds a second line and a faint disc; Quantum
	adds a sweep travelling round the edge. So an upgrade is visible before you read a stat, and a new
	magnet gets a ring by adding a field rather than by editing this file.

	IT READS AS MAGNETIC BECAUSE THE PULSES FALL INWARD. A ring expanding outward is radar -- something
	being emitted, sweeping for contacts. A ring collapsing toward the player is attraction, which is what
	the object on their back actually does. Same number of parts either way; the direction is the entire
	difference between "I am scanning" and "everything in here is coming to me".

	The pulse also does the job the fill was doing badly. A filled disc says "this area is mine" by
	covering it, which is exactly what made earlier passes imposing; a thin ring falling through the same
	area says it without hiding the scrap lying there.

	IT IS DELIBERATELY QUIET. Earlier passes were a bright ring and a solid disc, which is a lot of glow
	sitting permanently under the player and on top of the scrap they are trying to look at. Everything
	here is a hairline at 40-60% transparency over a fill that barely registers -- and Basic has no fill at
	all, so the starter experience is the least imposing of the three. Reach is a hint, not a headline.

	WHAT IT REPLACED: 36 segments per ring, positioned with `CFrame.Angles(0, -angle, 0)`. That points a
	part's X axis RADIALLY, so they were spokes sticking outward like speedometer ticks, each one
	`radius * 0.16` long -- longer and scruffier the more range you upgraded. The tangent at angle `t` is
	`(-sin t, 0, cos t)`, needing `y = -t - 90 degrees`; that one term is the difference between a ring and
	a starburst.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InventoryConfig = require(ReplicatedStorage.Shared.Config.InventoryConfig)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local ClientPreferences = require(script.Parent.Parent.ClientPreferences)

local MagnetRangeController = {}

--[[
	How far below the character's root the ring sits.

	The root is at the character's middle, not their feet, so this is most of a body height down. A fixed
	offset rather than a raycast on purpose: reach is a sphere around the player, so the honest drawing on
	a slope is a disc at their own height, not one draped over the terrain.
]]
local GROUND_OFFSET = -2.85

--[[
	How many boxes make a ring.

	72 leaves segments barely over a stud long at any range this game reaches, so the flat spots are far
	smaller than the line is thick and it reads as a circle. A `Cylinder` part cannot do this -- it is a
	filled disc, not a ring -- and a torus would be a mesh asset for something that is four lines of maths.
]]
local RING_SEGMENTS = 72

--- Boxes in the Quantum sweep, and how far round the circle it covers.
local SWEEP_SEGMENTS = 10
local SWEEP_ARC = math.rad(46)

--[[
	Pulse rings: how many boxes each is made of, and how many can be in flight.

	Half the segment count of the rim, because a pulse is thinner, fainter and moving -- nobody can see the
	flat spots on something that is never still and never fully opaque. `MAXIMUM_PULSES` caps the pools;
	a magnet asking for more gets this many.
]]
local PULSE_SEGMENTS = 36
local MAXIMUM_PULSES = 2

--[[
	Where a pulse starts and stops.

	It begins just inside the rim rather than on it -- starting on the rim makes the rim itself look like
	it is flickering -- and dies before it reaches the player, because a ring collapsing onto the character
	draws the eye to their feet instead of to the scrap.
]]
local PULSE_FROM = 0.94
local PULSE_TO = 0.3

--- How visible a pulse is at its brightest, a third of the way in. Fainter than the rim, deliberately.
local PULSE_TRANSPARENCY = 0.55

--[[
	The quiet end of every opacity in here.

	`RIM_TRANSPARENCY` is the visible line and still lets the ground through. The fill is whatever the
	magnet asks for, which tops out at 0.07 -- a wash rather than a surface, so scrap lying inside the
	circle still reads as lying on the floor rather than under coloured glass.
]]
local RIM_TRANSPARENCY = 0.42
local SECOND_RIM_TRANSPARENCY = 0.62
local SWEEP_TRANSPARENCY = 0.34

--- What a magnet with no `RangeRing` gets. Never an invisible indicator.
local FALLBACK_RING = {
	Accent = "Cyan",
	Fill = 0,
	Rim = 0.16,
	SecondRim = 0,
	Sweep = false,
	PulseSeconds = 2.6,
	PulseRings = 1,
}

local function makePart(name: string, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Transparency = 1
	part.Parent = parent
	return part
end

--- The look for a magnet id, falling back rather than erroring on an unknown one.
local function ringFor(magnetId: string)
	local definition = InventoryConfig.Magnets[magnetId]
	local ring = if definition then (definition :: any).RangeRing else nil
	return ring or FALLBACK_RING
end

function MagnetRangeController.Start()
	local player = Players.LocalPlayer
	local folder = Instance.new("Folder")
	folder.Name = "LocalMagnetRange"
	folder.Parent = workspace

	local currentRange = 18
	local magnetId = "MagnetBasic"

	--[[
		Every part allocated once, up front, and hidden when the current magnet does not use it.

		Making and destroying parts on a magnet change would churn the client's instance tree for a
		cosmetic swap, and the pools are small: 72 + 72 + 10 + 1.
	]]
	local fill = makePart("RangeFill", folder)
	fill.Shape = Enum.PartType.Cylinder

	local outerRim: { BasePart } = {}
	local secondRim: { BasePart } = {}
	local sweep: { BasePart } = {}
	for index = 1, RING_SEGMENTS do
		table.insert(outerRim, makePart(`RangeRim_{index}`, folder))
		table.insert(secondRim, makePart(`RangeRimInner_{index}`, folder))
	end
	for index = 1, SWEEP_SEGMENTS do
		table.insert(sweep, makePart(`RangeSweep_{index}`, folder))
	end

	local pulses: { { BasePart } } = {}
	for pulseIndex = 1, MAXIMUM_PULSES do
		local parts: { BasePart } = {}
		for index = 1, PULSE_SEGMENTS do
			table.insert(parts, makePart(`RangePulse{pulseIndex}_{index}`, folder))
		end
		table.insert(pulses, parts)
	end

	local function applyState(state)
		currentRange = state.DerivedStats.MagnetRange
		magnetId = state.EquippedMagnet
		ClientPreferences.Update(state.Settings)
	end
	ReplicatedStorage.Remotes.StateChanged.OnClientEvent:Connect(applyState)
	local initial = ReplicatedStorage.Remotes.RequestInitialState:InvokeServer()
	if initial then
		applyState(initial)
	end

	local function hide(parts: { BasePart })
		for _, part in parts do
			part.Transparency = 1
		end
	end

	--[[
		Lay a band of boxes along an arc, tangentially.

		`from` and `span` are radians. A full ring is `span = 2*pi`; the sweep passes a fraction of that and
		moves `from` over time. Each box is a hair longer than the exact chord so neighbours overlap rather
		than meeting exactly -- a seam shows at this scale and an overlap does not.
	]]
	local function layArc(
		parts: { BasePart },
		centre: Vector3,
		radius: number,
		thickness: number,
		colour: Color3,
		transparency: number,
		from: number,
		span: number
	)
		local chord = span * radius / #parts * 1.06
		for index, part in parts do
			local angle = from + ((index - 1) / #parts) * span
			part.Size = Vector3.new(chord, 0.1, thickness)
			part.CFrame = CFrame.new(
				centre + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			) * CFrame.Angles(0, -angle - math.pi / 2, 0)
			part.Color = colour
			part.Transparency = transparency
		end
	end

	local startedAt = os.clock()
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if
			root == nil
			or not root:IsA("BasePart")
			or not ClientPreferences.Get("ScreenEffectsEnabled")
		then
			fill.Transparency = 1
			hide(outerRim)
			hide(secondRim)
			hide(sweep)
			for _, parts in pulses do
				hide(parts)
			end
			return
		end

		local ring = ringFor(magnetId)
		local colour = Theme.Color[ring.Accent] or Theme.Color.Cyan
		local centre = root.Position + Vector3.new(0, GROUND_OFFSET, 0)
		local radius = currentRange
		local time = os.clock() - startedAt
		--[[
			A very small breath, and only on the fill.

			The ring holds still because a solid ring rotating is indistinguishable from one standing
			still -- that is why the old spoked version had to spin. Keeping the movement to a slight
			change in the fill means the thing that moves is the thing carrying no information.
		]]
		local breath = 0.5 + 0.5 * math.sin(time * 1.4)

		layArc(outerRim, centre, radius, ring.Rim, colour, RIM_TRANSPARENCY, 0, math.pi * 2)

		if ring.SecondRim > 0 then
			layArc(
				secondRim,
				centre,
				radius - ring.Rim * 3,
				ring.SecondRim,
				colour,
				SECOND_RIM_TRANSPARENCY,
				0,
				math.pi * 2
			)
		else
			hide(secondRim)
		end

		if ring.Sweep then
			--- One slow lap every eight seconds or so: present, never distracting.
			layArc(
				sweep,
				centre,
				radius,
				ring.Rim * 1.6,
				colour:Lerp(Color3.new(1, 1, 1), 0.4),
				SWEEP_TRANSPARENCY,
				time * 0.8,
				SWEEP_ARC
			)
		else
			hide(sweep)
		end

		--[[
			The pulses, each one a lap of `PulseSeconds` offset evenly from the others.

			Faded in AND out over the trip -- brightest around a third of the way down -- so a pulse does not
			pop into existence at the rim or vanish abruptly at the inner edge. `math.sin(progress * pi)`
			gives that shape for free.
		]]
		local wanted = math.clamp(math.floor(ring.PulseRings or 0), 0, MAXIMUM_PULSES)
		local period = math.max(0.3, ring.PulseSeconds or 2.6)
		for pulseIndex, parts in pulses do
			if pulseIndex > wanted then
				hide(parts)
				continue
			end
			local offset = (pulseIndex - 1) / wanted
			local progress = ((time / period) + offset) % 1
			local pulseRadius = radius * (PULSE_FROM + (PULSE_TO - PULSE_FROM) * progress)
			local fade = math.sin(progress * math.pi)
			layArc(
				parts,
				centre,
				pulseRadius,
				ring.Rim * 0.7,
				colour,
				1 - (1 - PULSE_TRANSPARENCY) * fade,
				0,
				math.pi * 2
			)
		end

		if ring.Fill > 0 then
			--- A cylinder's length runs along X, so it has to be tipped on its side to lie flat.
			fill.Size = Vector3.new(0.08, radius * 2, radius * 2)
			fill.CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(90))
			fill.Color = colour
			fill.Transparency = 1 - ring.Fill * (0.8 + breath * 0.2)
		else
			fill.Transparency = 1
		end
	end)
end

return table.freeze(MagnetRangeController)
