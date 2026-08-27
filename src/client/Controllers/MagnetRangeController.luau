--!strict
--[[
	MagnetRangeController.luau
	Draws the local player's magnet reach on the ground.

	LOCAL ONLY. These parts are made on the client and never replicate, so every player sees their own
	reach and nobody else's -- which is the whole point of the readout. It is the one thing on screen that
	answers "will that piece come to me if I stand here".

	EVERY MAGNET LOOKS DIFFERENT, and the look comes from `InventoryConfig.Magnets[id].RangeRing`
	unless a cosmetic skin is worn -- then `MagnetSkinConfig` supplies the ring for both the
	ground circle and the held model. Stats stay on the equipped magnet.

	SKIN MOTIONS ARE DISTINCT. Sharing one sweep-and-balls loop made four skins look like
	recolours. Paint is stacked still hoops; Chrome is current around the rim; Ember is fire
	rising; Orbital is solid tilted hoops; Event Horizon is a void: tilted hoops plus accretion
	particles and beams taken from the authored Workspace Animation 1 / 3 textures, laid flat on
	the range disc (not camera-facing on the character). Ember Core is
	a lava pool: flowing rim, bubbling, sparks, and fireballs that hop out of the floor.

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
local MagnetSkinConfig = require(ReplicatedStorage.Shared.Config.MagnetSkinConfig)
local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
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
--- Inward motes for cosmetic skins. Regular magnets leave this pool hidden.
local MAXIMUM_MOTES = 16

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

--- The look for a magnet id, overridden by a worn cosmetic skin.
local function ringFor(magnetId: string, skinId: string)
	if skinId ~= "" then
		local skin = MagnetSkinConfig.ById[skinId]
		if skin ~= nil then
			return skin.RangeRing
		end
	end
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
	local skinId = ""

	--[[
		Every part allocated once, up front, and hidden when the current magnet does not use it.

		Making and destroying parts on a magnet change would churn the client's instance tree for a
		cosmetic swap. Skins add a third rim and a core disc; those pools stay hidden for magnets
		that do not ask for them.
	]]
	local fill = makePart("RangeFill", folder)
	fill.Shape = Enum.PartType.Cylinder
	local coreFill = makePart("RangeCore", folder)
	coreFill.Shape = Enum.PartType.Cylinder

	local outerRim: { BasePart } = {}
	local secondRim: { BasePart } = {}
	local thirdRim: { BasePart } = {}
	local sweep: { BasePart } = {}
	for index = 1, RING_SEGMENTS do
		table.insert(outerRim, makePart(`RangeRim_{index}`, folder))
		table.insert(secondRim, makePart(`RangeRimInner_{index}`, folder))
		table.insert(thirdRim, makePart(`RangeRimThird_{index}`, folder))
	end
	for index = 1, SWEEP_SEGMENTS do
		table.insert(sweep, makePart(`RangeSweep_{index}`, folder))
	end

	local motes: { BasePart } = {}
	for index = 1, MAXIMUM_MOTES do
		local mote = makePart(`RangeMote_{index}`, folder)
		mote.Shape = Enum.PartType.Ball
		table.insert(motes, mote)
	end

	local pulses: { { BasePart } } = {}
	for pulseIndex = 1, MAXIMUM_PULSES do
		local parts: { BasePart } = {}
		for index = 1, PULSE_SEGMENTS do
			table.insert(parts, makePart(`RangePulse{pulseIndex}_{index}`, folder))
		end
		table.insert(pulses, parts)
	end

	--[[
		Event Horizon VFX. Swirl and glow textures from authored Animation 3 sit on spinning
		horizontal cylinders in the magnet-range plane -- the same disc the rings draw -- so
		they yaw around world up instead of standing up as camera-facing billboards. Hidden
		for every other magnet.
	]]
	local voidAnchor = makePart("RangeVoid", folder)
	voidAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
	voidAnchor.Transparency = 1
	local function makeVoidDisc(name: string, textureId: string): (Part, Texture)
		local disc = makePart(name, folder)
		disc.Shape = Enum.PartType.Cylinder
		disc.Material = Enum.Material.Neon
		local tex = Instance.new("Texture")
		tex.Name = "Swirl"
		tex.Texture = textureId
		tex.Face = Enum.NormalId.Right
		tex.Transparency = 1
		tex.Parent = disc
		return disc, tex
	end
	local voidSwirlA, voidSwirlATex = makeVoidDisc("RangeVoidSwirlA", "rbxassetid://12323607020")
	local voidSwirlB, voidSwirlBTex = makeVoidDisc("RangeVoidSwirlB", "rbxassetid://12323607020")
	local voidGlow, voidGlowTex = makeVoidDisc("RangeVoidGlow", "rbxassetid://10598374841")
	local voidCore = makePart("RangeVoidCore", folder)
	voidCore.Shape = Enum.PartType.Cylinder
	voidCore.Material = Enum.Material.SmoothPlastic
	local voidHalo = makePart("RangeVoidHalo", folder)
	voidHalo.Shape = Enum.PartType.Cylinder
	voidHalo.Material = Enum.Material.Neon
	local voidLight = Instance.new("PointLight")
	voidLight.Name = "VoidLight"
	voidLight.Enabled = false
	voidLight.Parent = voidAnchor
	local voidCoreAtt = Instance.new("Attachment")
	voidCoreAtt.Name = "VoidCore"
	voidCoreAtt.Parent = voidAnchor
	local voidRimAtts: { Attachment } = {}
	local voidBeams: { Beam } = {}
	for index = 1, 6 do
		local att = Instance.new("Attachment")
		att.Name = `VoidRim_{index}`
		att.Parent = voidAnchor
		table.insert(voidRimAtts, att)
		local beam = Instance.new("Beam")
		beam.Name = `VoidBeam_{index}`
		beam.Texture = "rbxassetid://5830549480"
		beam.TextureSpeed = 1.8
		beam.TextureLength = 1
		beam.Width0 = 0.9
		beam.Width1 = 0.08
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = false
		beam.Segments = 12
		beam.Attachment0 = att
		beam.Attachment1 = voidCoreAtt
		beam.Enabled = false
		beam.Parent = voidAnchor
		table.insert(voidBeams, beam)
	end

	local voidSparks: { ParticleEmitter } = {}
	local function addVoidSpark(
		texture: string,
		size: number,
		rate: number,
		life: number,
		speed: number,
		accelY: number,
		rotSpeed: number,
		brightness: number
	)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = texture
		emitter.Rate = rate
		emitter.Lifetime = NumberRange.new(life * 0.7, life)
		emitter.Speed = NumberRange.new(speed * 0.4, speed)
		emitter.SpreadAngle = Vector2.new(22, 22)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Acceleration = Vector3.new(0, accelY, 0)
		emitter.Drag = 1.4
		emitter.LockedToPart = false
		emitter.LightEmission = 1
		emitter.LightInfluence = 0
		emitter.Brightness = brightness
		emitter.RotSpeed = NumberRange.new(-rotSpeed, rotSpeed)
		emitter.Size = NumberSequence.new(size, size * 0.25)
		emitter.Enabled = false
		emitter.Parent = voidAnchor
		table.insert(voidSparks, emitter)
	end
	addVoidSpark("rbxassetid://10558510611", 0.32, 6, 0.55, 2.4, 1.6, 420, 4)
	addVoidSpark("rbxassetid://1075864321", 0.4, 3, 0.7, 1.2, 0.8, 0, 1.6)
	addVoidSpark("rbxassetid://7216853898", 1.1, 2, 1.1, 0.6, 1.2, 0, 1.4)

	local function layVoidDisc(
		disc: Part,
		tex: Texture,
		origin: Vector3,
		diameter: number,
		yaw: number,
		colour: Color3,
		texTrans: number,
		partTrans: number
	)
		disc.Size = Vector3.new(0.06, diameter, diameter)
		disc.CFrame = CFrame.new(origin) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.rad(90))
		disc.Color = colour
		disc.Transparency = partTrans
		tex.Transparency = texTrans
		tex.Color3 = colour
		tex.StudsPerTileU = diameter
		tex.StudsPerTileV = diameter
	end

	local function setVoidFx(
		on: boolean,
		origin: Vector3,
		radius: number,
		colour: Color3,
		innerColour: Color3,
		coreColour: Color3,
		time: number
	)
		if not on then
			voidCore.Transparency = 1
			voidHalo.Transparency = 1
			voidSwirlA.Transparency = 1
			voidSwirlB.Transparency = 1
			voidGlow.Transparency = 1
			voidSwirlATex.Transparency = 1
			voidSwirlBTex.Transparency = 1
			voidGlowTex.Transparency = 1
			voidLight.Enabled = false
			for _, beam in voidBeams do
				beam.Enabled = false
			end
			for _, spark in voidSparks do
				spark.Enabled = false
				spark:Clear()
			end
			return
		end
		local diameter = radius * 2
		voidAnchor.Size = Vector3.new(diameter * 0.92, 0.16, diameter * 0.92)
		voidAnchor.CFrame = CFrame.new(origin)
		layVoidDisc(voidSwirlA, voidSwirlATex, origin, diameter * 1.02, time * 1.15, colour, 0.18, 1)
		layVoidDisc(voidSwirlB, voidSwirlBTex, origin, diameter * 0.84, -time * 0.9, innerColour, 0.28, 1)
		layVoidDisc(voidGlow, voidGlowTex, origin, diameter * 0.52, time * 0.35, colour, 0.42, 0.88)
		local coreDiameter = math.max(2.4, radius * 0.36)
		voidCore.Size = Vector3.new(0.12, coreDiameter, coreDiameter)
		voidCore.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))
		voidCore.Color = coreColour
		voidCore.Transparency = 0.08
		local haloDiameter = coreDiameter * 1.55
		voidHalo.Size = Vector3.new(0.05, haloDiameter, haloDiameter)
		voidHalo.CFrame = CFrame.new(origin) * CFrame.Angles(0, time * 0.22, 0) * CFrame.Angles(0, 0, math.rad(90))
		voidHalo.Color = colour
		voidHalo.Transparency = 0.72
		voidLight.Enabled = true
		voidLight.Color = colour
		voidLight.Brightness = 2.1
		voidLight.Range = math.max(10, radius * 0.7)
		voidCoreAtt.Position = Vector3.zero
		local tint = ColorSequence.new(colour, innerColour)
		for index, att in voidRimAtts do
			local angle = time * 0.7 + ((index - 1) / #voidRimAtts) * math.pi * 2
			att.Position = Vector3.new(math.cos(angle) * radius * 0.88, 0.04, math.sin(angle) * radius * 0.88)
		end
		for _, beam in voidBeams do
			beam.Enabled = true
			beam.Color = tint
			beam.Width0 = math.clamp(radius * 0.055, 0.5, 1.6)
		end
		for _, spark in voidSparks do
			spark.Color = tint
			spark.Enabled = true
		end
	end

	--[[
		Ember Core lava kit. An invisible disc is only the particle emitter volume -- there is
		no floor plate. The reach reads as a transparent waving hoop, like Orbital / Horizon,
		with bubbles and fire hopping out of the circle.
	]]
	local LAVA_RIM = Color3.fromRGB(142, 38, 8)
	local LAVA_HOT = Color3.fromRGB(214, 78, 16)
	local LAVA_CORE = Color3.fromRGB(255, 148, 42)
	local SMOKE_DARK = Color3.fromRGB(28, 26, 24)
	local SMOKE_LIGHT = Color3.fromRGB(86, 80, 74)
	local emberPool = makePart("RangeEmberPool", folder)
	emberPool.Size = Vector3.new(0.2, 0.2, 0.2)
	emberPool.Transparency = 1
	local emberLight = Instance.new("PointLight")
	emberLight.Name = "EmberLight"
	emberLight.Enabled = false
	emberLight.Parent = emberPool

	local emberLine = makePart("RangeEmberLine", folder)
	emberLine.Size = Vector3.new(0.2, 0.2, 0.2)
	emberLine.Transparency = 1
	local emberFluid = makePart("RangeEmberFluid", folder)
	emberFluid.Shape = Enum.PartType.Cylinder
	emberFluid.Material = Enum.Material.SmoothPlastic
	emberFluid.Transparency = 1
	local emberWhirlCore = Instance.new("Attachment")
	emberWhirlCore.Name = "EmberWhirlCore"
	emberWhirlCore.Parent = emberFluid
	local emberWhirlRim: { Attachment } = {}
	local emberWhirlBeams: { Beam } = {}
	for index = 1, 8 do
		local att = Instance.new("Attachment")
		att.Name = `EmberWhirl_{index}`
		att.Parent = emberFluid
		table.insert(emberWhirlRim, att)
		local beam = Instance.new("Beam")
		beam.Name = `EmberWhirlBeam_{index}`
		beam.Attachment0 = att
		beam.Attachment1 = emberWhirlCore
		beam.Width0 = 0.7
		beam.Width1 = 0.08
		beam.FaceCamera = false
		beam.LightEmission = 0.75
		beam.LightInfluence = 0
		beam.Texture = "rbxasset://textures/particles/fire_main.dds"
		beam.TextureSpeed = 1.6
		beam.TextureLength = 1
		beam.Segments = 6
		beam.Enabled = false
		beam.Parent = emberFluid
		table.insert(emberWhirlBeams, beam)
	end
	local emberPoolFire = Instance.new("ParticleEmitter")
	emberPoolFire.Name = "EmberPoolFire"
	emberPoolFire.Texture = "rbxasset://textures/particles/fire_main.dds"
	emberPoolFire.Rate = 12
	emberPoolFire.Lifetime = NumberRange.new(0.45, 0.85)
	emberPoolFire.Speed = NumberRange.new(0.5, 1.6)
	emberPoolFire.SpreadAngle = Vector2.new(40, 40)
	emberPoolFire.EmissionDirection = Enum.NormalId.Right
	emberPoolFire.Acceleration = Vector3.new(0, 5, 0)
	emberPoolFire.Drag = 1
	emberPoolFire.LockedToPart = false
	emberPoolFire.LightEmission = 0.5
	emberPoolFire.LightInfluence = 0
	emberPoolFire.Brightness = 1.2
	emberPoolFire.RotSpeed = NumberRange.new(-50, 50)
	emberPoolFire.Size = NumberSequence.new(1.15, 0.2)
	emberPoolFire.Enabled = false
	emberPoolFire.Parent = emberFluid
	local EMBER_LINE_POINTS = 40
	local function makeEmberLoop(name: string): { Atts: { Attachment }, Beams: { Beam } }
		local atts: { Attachment } = {}
		local beams: { Beam } = {}
		for index = 1, EMBER_LINE_POINTS do
			local att = Instance.new("Attachment")
			att.Name = `{name}_{index}`
			att.Parent = emberLine
			table.insert(atts, att)
		end
		for index = 1, EMBER_LINE_POINTS do
			local beam = Instance.new("Beam")
			beam.Name = `{name}Beam_{index}`
			beam.Attachment0 = atts[index]
			beam.Attachment1 = atts[(index % EMBER_LINE_POINTS) + 1]
			beam.Width0 = 0.28
			beam.Width1 = 0.28
			beam.FaceCamera = true
			beam.LightEmission = 0.85
			beam.LightInfluence = 0
			beam.Segments = 3
			beam.Texture = ""
			beam.Enabled = false
			beam.Parent = emberLine
			table.insert(beams, beam)
		end
		return { Atts = atts, Beams = beams }
	end
	local emberLoopOuter = makeEmberLoop("EmberOuter")
	local emberLoopInner = makeEmberLoop("EmberInner")
	local emberLoopHigh = makeEmberLoop("EmberHigh")

	local emberEmitters: { { Inst: ParticleEmitter, Kind: string } } = {}
	local function addEmberEmitter(
		kind: string,
		texture: string,
		sizeFrom: number,
		sizeTo: number,
		rate: number,
		life: number,
		speedMin: number,
		speedMax: number,
		accelY: number,
		spread: number,
		rotSpeed: number,
		brightness: number,
		drag: number,
		lightEmission: number
	)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = texture
		emitter.Rate = rate
		emitter.Lifetime = NumberRange.new(life * 0.7, life)
		emitter.Speed = NumberRange.new(speedMin, speedMax)
		emitter.SpreadAngle = Vector2.new(spread, spread)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Acceleration = Vector3.new(0, accelY, 0)
		emitter.Drag = drag
		emitter.LockedToPart = false
		emitter.LightEmission = lightEmission
		emitter.LightInfluence = 0
		emitter.Brightness = brightness
		emitter.RotSpeed = NumberRange.new(-rotSpeed, rotSpeed)
		emitter.Size = NumberSequence.new(sizeFrom, sizeTo)
		emitter.Enabled = false
		emitter.Parent = emberPool
		table.insert(emberEmitters, { Inst = emitter, Kind = kind })
	end
	--- Built-in fire/smoke, plus the authored Animation 2 spark streaks.
	addEmberEmitter("fire", "rbxasset://textures/particles/fire_main.dds", 1.6, 0.35, 14, 0.9, 2.2, 6.5, 7, 28, 40, 1.15, 1, 0.4)
	addEmberEmitter("smoke", "rbxasset://textures/particles/smoke_main.dds", 2.4, 5.5, 4, 1.5, 0.6, 2.2, 3.5, 22, 10, 0.4, 2, 0)
	addEmberEmitter("spark", "rbxasset://textures/particles/sparkles_main.dds", 0.22, 0.08, 18, 0.45, 10, 22, -38, 55, 280, 1.5, 2, 0.45)
	addEmberEmitter("spark", "rbxassetid://8090715771", 0.35, 0.12, 12, 0.55, 12, 24, -32, 48, 90, 1.3, 1.5, 0.4)
	addEmberEmitter("spark", "rbxassetid://10558510611", 0.4, 0.15, 10, 0.5, 8, 16, -28, 40, 360, 1.4, 1.8, 0.5)
	addEmberEmitter("haze", "rbxassetid://7216853898", 1.8, 3.2, 3, 1.2, 0.4, 1.4, 2.2, 18, 0, 0.55, 1, 0.12)

	local FIRE_TINT = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(86, 14, 4)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(186, 58, 10)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 158, 48)),
	})
	local SPARK_TINT = ColorSequence.new(Color3.fromRGB(180, 48, 8), Color3.fromRGB(255, 190, 70))
	local SMOKE_TINT = ColorSequence.new(SMOKE_DARK, SMOKE_LIGHT)
	local HAZE_TINT = ColorSequence.new(Color3.fromRGB(48, 16, 8), Color3.fromRGB(110, 42, 14))

	local function placeEmberLoop(
		loop: { Atts: { Attachment }, Beams: { Beam } },
		on: boolean,
		radius: number,
		lift: number,
		colour: Color3,
		transparency: number,
		width: number,
		phase: number,
		amp: number
	)
		if not on then
			for _, beam in loop.Beams do
				beam.Enabled = false
			end
			return
		end
		for index, att in loop.Atts do
			local angle = ((index - 1) / EMBER_LINE_POINTS) * math.pi * 2
			local ripple = math.sin(angle * 6 + phase)
			local r = radius * (1 + amp * ripple)
			local y = lift + 0.28 * math.sin(angle * 5 + phase * 1.35)
			att.Position = Vector3.new(math.cos(angle) * r, y, math.sin(angle) * r)
			local beam = loop.Beams[index]
			if beam then
				local heat = 0.5 + 0.5 * math.sin(angle * 4 + phase)
				beam.Enabled = true
				beam.Color = ColorSequence.new(colour:Lerp(LAVA_CORE, heat))
				beam.Transparency = NumberSequence.new(0)
				beam.Width0 = width
				beam.Width1 = width
			end
		end
	end

	local function setEmberFx(
		on: boolean,
		origin: Vector3,
		radius: number,
		time: number,
		rimLift: number,
		innerLift: number,
		thirdScale: number
	)
		if not on then
			emberPool.Transparency = 1
			emberFluid.Transparency = 1
			emberLight.Enabled = false
			emberLine.CFrame = CFrame.new()
			for _, packed in emberEmitters do
				packed.Inst.Enabled = false
				packed.Inst:Clear()
			end
			for _, beam in emberWhirlBeams do
				beam.Enabled = false
			end
			emberPoolFire.Enabled = false
			emberPoolFire:Clear()
			placeEmberLoop(emberLoopOuter, false, 1, 0, Color3.new(), 1, 0.1, 0, 0)
			placeEmberLoop(emberLoopInner, false, 1, 0, Color3.new(), 1, 0.1, 0, 0)
			placeEmberLoop(emberLoopHigh, false, 1, 0, Color3.new(), 1, 0.1, 0, 0)
			return
		end
		local diameter = math.max(6, radius * 1.45)
		emberPool.Size = Vector3.new(diameter, 0.12, diameter)
		emberPool.CFrame = CFrame.new(origin + Vector3.new(0, 0.7, 0))
		emberPool.Transparency = 1
		emberLine.CFrame = CFrame.new(origin)
		local fluidRadius = radius * thirdScale
		local fluidDiam = fluidRadius * 2
		emberFluid.Size = Vector3.new(0.12, fluidDiam, fluidDiam)
		emberFluid.CFrame = CFrame.new(origin + Vector3.new(0, innerLift, 0))
			* CFrame.Angles(0, time * 0.35, 0)
			* CFrame.Angles(0, 0, math.rad(90))
		emberFluid.Color = LAVA_RIM:Lerp(LAVA_CORE, 0.35 + 0.3 * math.sin(time * 2.1))
		emberFluid.Transparency = 0.32
		emberLight.Enabled = true
		emberLight.Color = LAVA_HOT
		emberLight.Range = math.max(8, radius * 0.48)
		emberLight.Brightness = 0.55 + 0.25 * math.abs(math.sin(time * 9) * math.sin(time * 6.2))
		for _, packed in emberEmitters do
			if packed.Kind == "smoke" then
				packed.Inst.Color = SMOKE_TINT
			elseif packed.Kind == "spark" then
				packed.Inst.Color = SPARK_TINT
			elseif packed.Kind == "haze" then
				packed.Inst.Color = HAZE_TINT
			else
				packed.Inst.Color = FIRE_TINT
			end
			packed.Inst.Enabled = true
		end
		local swirlTint = ColorSequence.new(LAVA_RIM, LAVA_CORE)
		emberWhirlCore.Position = Vector3.zero
		for index, att in emberWhirlRim do
			local angle = ((index - 1) / #emberWhirlRim) * math.pi * 2
			att.Position = Vector3.new(0, math.cos(angle) * fluidRadius * 0.9, math.sin(angle) * fluidRadius * 0.9)
		end
		for _, beam in emberWhirlBeams do
			beam.Enabled = true
			beam.Color = swirlTint
			beam.Width0 = math.clamp(fluidRadius * 0.08, 0.4, 1.1)
		end
		emberPoolFire.Color = FIRE_TINT
		emberPoolFire.Enabled = true
		placeEmberLoop(emberLoopOuter, true, radius, rimLift, LAVA_RIM, 0, 0.32, time * 2.2, 0.055)
		placeEmberLoop(emberLoopInner, true, radius * 0.82, innerLift * 0.5, LAVA_HOT, 0, 0.26, -time * 1.85, 0.048)
		placeEmberLoop(emberLoopHigh, true, radius * thirdScale, innerLift, LAVA_CORE, 0, 0.22, time * 2.7, 0.06)
	end

	local function applyState(state)
		currentRange = state.DerivedStats.MagnetRange
		magnetId = state.EquippedMagnet
		skinId = if type(state.ActiveMagnetSkin) == "string" then state.ActiveMagnetSkin else ""
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

		`tilt` / `yaw` lift the hoop into a 3D plane. `flow` is a 0-1 phase that brightens traveling
		lobes so a still ring can look like current. `dash` hides all but 1 of every N segments so a
		spin is visible -- a solid hoop rotating is indistinguishable from one standing still.
	]]
	local function layArc(
		parts: { BasePart },
		centre: Vector3,
		radius: number,
		thickness: number,
		colour: Color3,
		transparency: number,
		from: number,
		span: number,
		tilt: number?,
		yaw: number?,
		flow: number?,
		flowLobes: number?,
		dash: number?,
		dashOffset: number?,
		rippleAmp: number?,
		ripplePhase: number?
	)
		local chord = span * radius / #parts * 1.06
		local plane = CFrame.new(centre) * CFrame.Angles(tilt or 0, yaw or 0, 0)
		local lobes = flowLobes or 3
		local dashEvery = dash or 0
		local offset = dashOffset or 0
		local ripAmp = rippleAmp or 0
		local ripPhase = ripplePhase or 0
		for index, part in parts do
			local t = (index - 1) / #parts
			local angle = from + t * span
			local ripple = if ripAmp > 0 then math.sin(angle * 6 + ripPhase) else 0
			local r = radius * (1 + ripAmp * ripple)
			local yOff = if ripAmp > 0 then 0.32 * math.sin(angle * 5 + ripPhase * 1.35) else 0
			part.Size = Vector3.new(chord, 0.1, thickness)
			part.CFrame = plane
				* CFrame.new(math.cos(angle) * r, yOff, math.sin(angle) * r)
				* CFrame.Angles(0, -angle - math.pi / 2, 0)
			part.Color = colour
			if dashEvery > 1 and ((index - 1 + math.floor(offset)) % dashEvery) ~= 0 then
				part.Transparency = 1
				continue
			end
			if flow ~= nil then
				local wave = 0.5 + 0.5 * math.cos((t - flow) * math.pi * 2 * lobes)
				part.Transparency = math.clamp(0.08 + transparency * (1.15 - wave * wave * 0.95), 0, 1)
			else
				part.Transparency = transparency
			end
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
			coreFill.Transparency = 1
			hide(outerRim)
			hide(secondRim)
			hide(thirdRim)
			hide(sweep)
			hide(motes)
			for _, parts in pulses do
				hide(parts)
			end
			setVoidFx(false, Vector3.zero, 1, Color3.new(), Color3.new(), Color3.new(), 0)
			setEmberFx(false, Vector3.zero, 1, 0, 0, 0, 0.7)
			return
		end

		local ring = ringFor(magnetId, skinId)
		local colour = Theme.Color[ring.Accent] or Theme.Color.Cyan
		local secondaryName = (ring :: any).AccentSecondary
		local innerColour = if typeof(secondaryName) == "string"
			then (Theme.Color[secondaryName] or colour)
			else colour
		local coreName = (ring :: any).CoreAccent
		local coreColour = if typeof(coreName) == "string"
			then (Theme.Color[coreName] or Theme.Color.Ink)
			else Theme.Color.Ink
		local centre = root.Position + Vector3.new(0, GROUND_OFFSET, 0)
		local radius = currentRange
		local area = workspace:FindFirstChild(ArenaConfig.AreaName)
		if area ~= nil and area:IsA("Model") then
			local cf, size = area:GetBoundingBox()
			if ArenaConfig.containsPoint(root.Position, cf, size) then
				radius = math.min(radius, ArenaConfig.MagnetRangeCap)
			end
		end
		local time = os.clock() - startedAt
		local breath = 0.5 + 0.5 * math.sin(time * 1.4)
		local rimLift = (ring :: any).RimLift or 0
		local innerLift = (ring :: any).InnerLift or 0
		local moteCount = math.clamp(math.floor((ring :: any).Motes or 0), 0, MAXIMUM_MOTES)
		local moteMode = (ring :: any).MoteMode
		local flowSpeed = (ring :: any).FlowSpeed
		local flowLobes = (ring :: any).FlowLobes
		local dash = (ring :: any).Dash
		local spin = (ring :: any).Spin or 0
		local tilt = (ring :: any).Tilt or 0
		local pulseFade = if moteMode ~= nil then 0.4 else PULSE_TRANSPARENCY
		local thirdWidth = (ring :: any).ThirdRim or 0
		local fx = (ring :: any).Fx
		if fx == "Ember" then
			colour = LAVA_RIM
			innerColour = LAVA_HOT
			coreColour = LAVA_CORE
		end
		local flowPhase = if typeof(flowSpeed) == "number" then (time * flowSpeed) % 1 else nil
		local spinFrom = time * spin
		local dashOffset = if dash then time * spin * RING_SEGMENTS else nil
		local bobAmp = (ring :: any).Bob or 0
		local yaw = if tilt > 0 then time * (if fx == "Void" then 0.52 else 0.48) else 0
		local function hoopCentre(lift: number, hoopRadius: number, hoopTilt: number, phase: number): Vector3
			local drop = hoopRadius * math.abs(math.sin(hoopTilt))
			local floorY = math.max(lift, drop + 0.65 + bobAmp)
			local wave = if bobAmp > 0 then math.sin(time * 1.2 + phase) * bobAmp else 0
			return centre + Vector3.new(0, floorY + wave, 0)
		end
		local floor = centre
		local outerTilt = if tilt > 0 then (if fx == "Void" then tilt * 0.32 else tilt * 0.55) else 0
		local outerNod = if bobAmp > 0 then math.sin(time * 0.9) * 0.14 else 0
		local innerNod = if bobAmp > 0 then math.sin(time * 1.05 + 2.1) * 0.12 else 0
		local highNod = if bobAmp > 0 then math.sin(time * 0.75 + 4.2) * 0.1 else 0
		local outer = hoopCentre(rimLift, radius, outerTilt, 0)
		local innerY = if thirdWidth > 0 then innerLift * 0.5 else math.max(innerLift, rimLift + 0.28)
		local inner = hoopCentre(innerY, radius * 0.82, tilt, 2.1)
		local thirdScale = (ring :: any).ThirdRimScale or 0.7
		local high = hoopCentre(innerLift, radius * thirdScale, tilt * 0.7, 4.2)

		if fx == "Ember" then
			hide(outerRim)
			hide(secondRim)
			hide(thirdRim)
			hide(sweep)
		else
			layArc(
				outerRim,
				outer,
				radius,
				ring.Rim,
				colour,
				RIM_TRANSPARENCY,
				if dash then spinFrom else 0,
				math.pi * 2,
				if outerTilt > 0 then outerTilt + outerNod else nil,
				if outerTilt > 0 then yaw * 0.7 else nil,
				flowPhase,
				flowLobes,
				dash,
				dashOffset
			)

			if ring.SecondRim > 0 then
				layArc(
					secondRim,
					inner,
					radius * 0.82,
					ring.SecondRim,
					innerColour,
					SECOND_RIM_TRANSPARENCY,
					if dash then -spinFrom * 0.7 else 0,
					math.pi * 2,
					if tilt > 0 then tilt + innerNod else nil,
					if tilt > 0 then yaw else nil,
					if flowPhase ~= nil then (1 - flowPhase) % 1 else nil,
					flowLobes,
					dash,
					if dashOffset then -dashOffset else nil
				)
			else
				hide(secondRim)
			end

			if thirdWidth > 0 then
				layArc(
					thirdRim,
					high,
					radius * thirdScale,
					thirdWidth,
					innerColour,
					SECOND_RIM_TRANSPARENCY,
					if dash then spinFrom * 1.15 else 0,
					math.pi * 2,
					if tilt > 0 then -tilt * 0.7 + highNod else nil,
					if tilt > 0 then -yaw * 1.4 else nil,
					nil,
					nil,
					dash,
					dashOffset
				)
			else
				hide(thirdRim)
			end

			if ring.Sweep then
				layArc(
					sweep,
					outer,
					radius,
					ring.Rim * 1.6,
					colour:Lerp(Color3.new(1, 1, 1), 0.4),
					SWEEP_TRANSPARENCY,
					time * (if flowPhase ~= nil then 1.4 else 0.85),
					SWEEP_ARC
				)
			else
				hide(sweep)
			end
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
				floor,
				pulseRadius,
				ring.Rim * 0.7,
				colour,
				1 - (1 - pulseFade) * fade,
				0,
				math.pi * 2
			)
		end

		local moteSpeed = (ring :: any).MoteSpeed or 0.4
		for index, mote in motes do
			if index > moteCount or typeof(moteMode) ~= "string" then
				mote.Transparency = 1
				continue
			end
			local progress = (time * moteSpeed + (index - 1) / moteCount) % 1
			local fade = math.sin(progress * math.pi)
			if moteMode == "rise" then
				--- Lava: some blobs bubble on the pool and pop; the rest hop out as fireballs.
				local launch = ((index - 1) / moteCount) * math.pi * 2
				local orbit = launch + math.floor(time * moteSpeed + (index - 1) / moteCount) * 0.63
				if index % 3 == 0 then
					local size = 0.2 + progress * 0.95
					local moteRadius = radius * (0.12 + 0.5 * ((index % 5) / 5))
					mote.Size = Vector3.new(size, size * 0.72, size)
					if mote:IsA("Part") then
						mote.Shape = Enum.PartType.Ball
					end
					mote.CFrame = CFrame.new(
						centre + Vector3.new(math.cos(orbit) * moteRadius, size * 0.4, math.sin(orbit) * moteRadius)
					)
					mote.Material = Enum.Material.SmoothPlastic
					mote.Color = Color3.fromRGB(96, 18, 4):Lerp(LAVA_HOT, progress)
					mote.Transparency = if progress < 0.62 then 0.28 else 0.28 + (progress - 0.62) / 0.38 * 0.72
				else
					local startR = radius * (0.18 + 0.5 * ((index % 7) / 7))
					local moteRadius = startR + radius * 0.16 * progress
					local apex = 1.7 + (index % 4) * 0.7
					local height = 0.22 + 4 * apex * progress * (1 - progress)
					local size = 0.28 + 0.18 * fade
					mote.Size = Vector3.new(size, size, size)
					if mote:IsA("Part") then
						mote.Shape = Enum.PartType.Ball
					end
					mote.CFrame = CFrame.new(
						centre + Vector3.new(math.cos(orbit) * moteRadius, height, math.sin(orbit) * moteRadius)
					)
					mote.Material = Enum.Material.SmoothPlastic
					mote.Color = if index % 2 == 0 then LAVA_HOT else Color3.fromRGB(118, 24, 6)
					mote.Transparency = 1 - (0.72 * fade)
				end
			else
				--- Event Horizon: spiral into the core.
				local angle = ((index - 1) / moteCount) * math.pi * 2 + time * 0.9
				local moteRadius = radius * (0.92 - 0.72 * progress)
				local height = (inner.Y - centre.Y) * (0.35 + 0.55 * math.sin(progress * math.pi))
				mote.Size = Vector3.new(0.22, 0.22, 0.22)
				if mote:IsA("Part") then
					mote.Shape = Enum.PartType.Ball
				end
				mote.CFrame = CFrame.new(
					centre + Vector3.new(math.cos(angle) * moteRadius, height, math.sin(angle) * moteRadius)
				)
				mote.Color = if index % 2 == 0 then innerColour else colour
				mote.Transparency = 1 - (0.75 * fade)
			end
		end

		if ring.Fill > 0 and fx ~= "Ember" then
			--- A cylinder's length runs along X, so it has to be tipped on its side to lie flat.
			fill.Size = Vector3.new(0.08, radius * 2, radius * 2)
			fill.CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(90))
			fill.Color = colour
			fill.Transparency = 1 - ring.Fill * (0.8 + breath * 0.2)
		else
			fill.Transparency = 1
		end

		local coreAmount = (ring :: any).CoreFill or 0
		if coreAmount > 0 and fx ~= "Void" and fx ~= "Ember" then
			local coreScale = (ring :: any).CoreScale or 0.28
			local coreRadius = radius * coreScale
			coreFill.Size = Vector3.new(0.1, coreRadius * 2, coreRadius * 2)
			coreFill.CFrame = CFrame.new(centre + Vector3.new(0, innerLift * 0.4, 0))
				* CFrame.Angles(0, 0, math.rad(90))
			coreFill.Color = coreColour
			coreFill.Transparency = 1 - coreAmount * (0.85 + breath * 0.15)
		else
			coreFill.Transparency = 1
		end

		setVoidFx(fx == "Void", outer, radius, colour, innerColour, coreColour, time)
		setEmberFx(fx == "Ember", floor, radius, time, rimLift, innerLift, thirdScale)
	end)
end

return table.freeze(MagnetRangeController)
