--!strict
--[[
	MagnetSkinBuilder.luau
	Builds the held magnet for a cosmetic skin from primitives.

	ORIENTATION MATCHES `MagnetBasic`, not AdvancedMagnet. The default union is
	Y-up (poles along +Y). Attach's 90/90 maps part +Y forward; a head-in-+X
	build maps to world up, so the U stood on its handle. Grip PrimaryPart at
	the origin, opening +Y, U in the XY plane, thin in Z.

	EVERY SKIN IS A ROUNDED HORSESHOE. Box poles on a square yoke read as an H,
	not a magnet. Identity is dressing on that U. ServerStorage.MagnetModels is
	not on the client, so shop previews rebuild this U rather than cloning
	MagnetBasic.

	`buildPreview` is already Y-up; it only yaws so a ViewportFrame sees the
	opening. The hand uses `build`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local MagnetSkinConfig = require(ReplicatedStorage.Shared.Config.MagnetSkinConfig)

local MagnetSkinBuilder = {}

local POLE_SEP = 0.52
local POLE_LEN = 1.28
local THICK = 0.42
local TIP = 0.5
local BEND_SEGS = 6

local function colour(name: string): Color3
	return Theme.Color[name] or Theme.Color.Cyan
end

local function part(
	name: string,
	size: Vector3,
	cframe: CFrame,
	paint: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local instance = Instance.new("Part")
	instance.Name = name
	instance.Size = size
	instance.CFrame = cframe
	instance.Color = paint
	instance.Material = material
	instance.Anchored = true
	instance.CanCollide = false
	instance.CanTouch = false
	instance.CanQuery = false
	instance.CastShadow = false
	instance.Parent = parent
	return instance
end

local function light(parent: BasePart, paint: Color3, brightness: number)
	local point = Instance.new("PointLight")
	point.Name = "SkinLight"
	point.Color = paint
	point.Brightness = brightness
	point.Range = 7
	point.Parent = parent
end

--[[
	Looping magnet emitters stay Rate 2-8 and named, so they can be switched off
	in one place. Locked to the part so they frame the U instead of filling the
	yard. Textures already used by Event Horizon's ground FX.
]]
local function idleEmitter(
	parent: BasePart,
	name: string,
	texture: string,
	rate: number,
	size: number,
	paint: Color3
)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Texture = texture
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(0.55, 1.05)
	emitter.Speed = NumberRange.new(0.12, 0.5)
	emitter.SpreadAngle = Vector2.new(48, 48)
	emitter.Drag = 2.2
	emitter.LockedToPart = true
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Brightness = 2.2
	emitter.RotSpeed = NumberRange.new(-80, 80)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, size * 0.18),
	})
	emitter.Color = ColorSequence.new(paint)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.7, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = parent
end

local function poleArc(tipA: BasePart, tipB: BasePart, paint: Color3)
	local a0 = Instance.new("Attachment")
	a0.Name = "HorizonArcA"
	a0.Parent = tipA
	local a1 = Instance.new("Attachment")
	a1.Name = "HorizonArcB"
	a1.Parent = tipB
	local beam = Instance.new("Beam")
	beam.Name = "HorizonArc"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(paint)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.5, 0.12),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	beam.Width0 = 0.08
	beam.Width1 = 0.08
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 8
	beam.Parent = tipA
end

local function aura(model: Model, paint: Color3)
	local highlight = Instance.new("Highlight")
	highlight.Name = "HorizonAura"
	highlight.FillColor = paint
	highlight.OutlineColor = paint
	highlight.FillTransparency = 0.88
	highlight.OutlineTransparency = 0.28
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
end

--[[
	The U. Grip sits at the bottom of the curve so attach's PivotTo matches
	MagnetBasic (poles +Y). Bend is a semicircle of cylinders; poles are
	cylinders too -- a box yoke is what made this read as a staple. Face looks
	-Z, the flat of the U, so the shop camera frames the opening.
]]
local function horseshoe(model: Model, body: Color3, accent: Color3, tipA: Color3, tipB: Color3)
	local radius = POLE_SEP
	part("Grip", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 0.06, 0), body, Enum.Material.SmoothPlastic, model)
	for index = 1, BEND_SEGS do
		local fromAngle = math.pi + ((index - 1) / BEND_SEGS) * math.pi
		local toAngle = math.pi + (index / BEND_SEGS) * math.pi
		local mid = (fromAngle + toAngle) * 0.5
		local pos = Vector3.new(math.cos(mid) * radius, radius + math.sin(mid) * radius, 0)
		local chord = radius * (toAngle - fromAngle) * 1.12
		local paint = body
		local material = Enum.Material.SmoothPlastic
		local name = `Bend{index}`
		if index == math.ceil(BEND_SEGS / 2) then
			paint = accent
			material = Enum.Material.Neon
			name = "Stripe"
		end
		local segment = part(
			name,
			Vector3.new(chord, THICK, THICK),
			CFrame.new(pos) * CFrame.Angles(0, 0, mid + math.pi / 2),
			paint,
			material,
			model
		)
		segment.Shape = Enum.PartType.Cylinder
	end
	local poleY = radius + POLE_LEN * 0.5
	local leftPole = part(
		"PoleL",
		Vector3.new(POLE_LEN, THICK, THICK),
		CFrame.new(-radius, poleY, 0) * CFrame.Angles(0, 0, math.rad(90)),
		body,
		Enum.Material.SmoothPlastic,
		model
	)
	leftPole.Shape = Enum.PartType.Cylinder
	local rightPole = part(
		"PoleR",
		Vector3.new(POLE_LEN, THICK, THICK),
		CFrame.new(radius, poleY, 0) * CFrame.Angles(0, 0, math.rad(90)),
		body,
		Enum.Material.SmoothPlastic,
		model
	)
	rightPole.Shape = Enum.PartType.Cylinder
	local tipY = radius + POLE_LEN
	local left = part("TipL", Vector3.new(TIP, TIP, TIP), CFrame.new(-radius, tipY, 0), tipA, Enum.Material.Neon, model)
	left.Shape = Enum.PartType.Ball
	local right = part("TipR", Vector3.new(TIP, TIP, TIP), CFrame.new(radius, tipY, 0), tipB, Enum.Material.Neon, model)
	right.Shape = Enum.PartType.Ball
	local face = part(
		"Face",
		Vector3.new(0.08, 0.08, 0.08),
		CFrame.new(0, radius + POLE_LEN * 0.4, 0),
		body,
		Enum.Material.SmoothPlastic,
		model
	)
	face.Transparency = 1
end

local function wrapPoles(model: Model, paint: Color3, offsets: { number })
	for index, y in offsets do
		local a = part(
			`WrapL{index}`,
			Vector3.new(0.11, THICK + 0.16, THICK + 0.16),
			CFrame.new(-POLE_SEP, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
			paint,
			Enum.Material.Neon,
			model
		)
		a.Shape = Enum.PartType.Cylinder
		local b = part(
			`WrapR{index}`,
			Vector3.new(0.11, THICK + 0.16, THICK + 0.16),
			CFrame.new(POLE_SEP, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
			paint,
			Enum.Material.Neon,
			model
		)
		b.Shape = Enum.PartType.Cylinder
	end
end

local function ringBoxes(
	model: Model,
	prefix: string,
	radius: number,
	thickness: number,
	center: CFrame,
	tilt: number,
	paint: Color3,
	count: number
)
	local span = math.pi * 2
	local chord = span * radius / count * 1.08
	for index = 1, count do
		local angle = ((index - 1) / count) * span
		local offset = center
			* CFrame.Angles(tilt, 0, 0)
			* CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			* CFrame.Angles(0, -angle - math.pi / 2, 0)
		part(`{prefix}_{index}`, Vector3.new(chord, 0.1, thickness), offset, paint, Enum.Material.Neon, model)
	end
end

local function yardPaint(model: Model)
	horseshoe(model, colour("Orange"), colour("Gold"), colour("Red"), colour("Blue"))
end

local function chromeCoil(model: Model)
	horseshoe(model, Theme.Color.Gray, colour("Cyan"), colour("Cyan"), colour("Blue"))
	--[[
		Current down the inner face of each arm -- a stripe, not Horizon's bands
		around the tips.
	]]
	local poleY = POLE_SEP + POLE_LEN * 0.5
	local seam = Vector3.new(0.07, POLE_LEN * 0.88, 0.14)
	part(
		"SeamL",
		seam,
		CFrame.new(-POLE_SEP + THICK * 0.32, poleY, 0),
		colour("Cyan"),
		Enum.Material.Neon,
		model
	)
	part(
		"SeamR",
		seam,
		CFrame.new(POLE_SEP - THICK * 0.32, poleY, 0),
		colour("Cyan"),
		Enum.Material.Neon,
		model
	)
end

local function emberCore(model: Model)
	horseshoe(model, colour("Ink"), colour("Orange"), colour("Gold"), colour("Orange"))
	local charcoal = colour("Ink"):Lerp(colour("Orange"), 0.18)
	for _, name in { "PoleL", "PoleR" } do
		local pole = model:FindFirstChild(name)
		if pole and pole:IsA("BasePart") then
			pole.Color = charcoal
		end
	end
	--[[
		Molten sleeve along the whole arm, plus a lava core between the poles.
		No rings at the tips -- those are Horizon's.
	]]
	local poleY = POLE_SEP + POLE_LEN * 0.5
	local sleeveSize = Vector3.new(POLE_LEN * 0.92, THICK + 0.12, THICK + 0.12)
	local left = part(
		"SleeveL",
		sleeveSize,
		CFrame.new(-POLE_SEP, poleY, 0) * CFrame.Angles(0, 0, math.rad(90)),
		colour("Orange"),
		Enum.Material.Neon,
		model
	)
	left.Shape = Enum.PartType.Cylinder
	left.Transparency = 0.42
	local right = part(
		"SleeveR",
		sleeveSize,
		CFrame.new(POLE_SEP, poleY, 0) * CFrame.Angles(0, 0, math.rad(90)),
		colour("Orange"),
		Enum.Material.Neon,
		model
	)
	right.Shape = Enum.PartType.Cylinder
	right.Transparency = 0.42
	local core = part(
		"Core",
		Vector3.new(0.5, 0.5, 0.5),
		CFrame.new(0, POLE_SEP + POLE_LEN * 0.35, 0),
		colour("Orange"),
		Enum.Material.Neon,
		model
	)
	core.Shape = Enum.PartType.Ball
	light(core, colour("Orange"), 1.35)
	idleEmitter(core, "EmberOrb", "rbxassetid://7216853898", 4, 0.38, colour("Orange"))
end

local function orbital(model: Model)
	horseshoe(model, colour("Purple"), colour("Gold"), colour("Gold"), colour("Orange"))
	local globeY = POLE_SEP + 0.42
	local globe = part(
		"Globe",
		Vector3.new(0.72, 0.72, 0.72),
		CFrame.new(0, globeY, 0),
		colour("Purple"),
		Enum.Material.SmoothPlastic,
		model
	)
	globe.Shape = Enum.PartType.Ball
	local around = CFrame.new(0, globeY + 0.12, 0)
	ringBoxes(model, "RingA", 0.78, 0.18, around, math.rad(10), colour("Gold"), 6)
	ringBoxes(model, "RingB", 1.05, 0.12, around, math.rad(24), colour("Orange"), 6)
	light(globe, colour("Gold"), 0.45)
end

--[[
	Same U as the default magnet, dressed as a premium energy skin: charcoal
	body, white mechanical plates, cyan neon poles. No disc between the tips --
	that read as a different object. The reach ring stays the void kit.
]]
local function eventHorizon(model: Model)
	local ink = colour("Ink")
	local white = colour("White")
	local cyan = colour("Cyan")
	local charcoal = ink:Lerp(white, 0.14)
	horseshoe(model, charcoal, white, cyan, cyan)

	local stripe = model:FindFirstChild("Stripe")
	if stripe and stripe:IsA("BasePart") then
		stripe.Material = Enum.Material.SmoothPlastic
		stripe.Color = white
	end

	local poleY = POLE_SEP + POLE_LEN * 0.5
	part(
		"PlateL",
		Vector3.new(THICK * 0.55, POLE_LEN * 0.62, 0.09),
		CFrame.new(-POLE_SEP, poleY, THICK * 0.3),
		white,
		Enum.Material.SmoothPlastic,
		model
	)
	part(
		"PlateR",
		Vector3.new(THICK * 0.55, POLE_LEN * 0.62, 0.09),
		CFrame.new(POLE_SEP, poleY, THICK * 0.3),
		white,
		Enum.Material.SmoothPlastic,
		model
	)
	wrapPoles(model, cyan, { POLE_SEP + 0.36, POLE_SEP + 0.9 })

	local core = part(
		"Core",
		Vector3.new(0.34, 0.34, 0.34),
		CFrame.new(0, POLE_SEP, 0),
		cyan,
		Enum.Material.Neon,
		model
	)
	core.Shape = Enum.PartType.Ball
	light(core, cyan, 1.1)

	local tipL = model:FindFirstChild("TipL")
	local tipR = model:FindFirstChild("TipR")
	if tipL and tipL:IsA("BasePart") and tipR and tipR:IsA("BasePart") then
		poleArc(tipL, tipR, cyan)
		idleEmitter(tipL, "HorizonSparkL", "rbxassetid://10558510611", 4, 0.22, cyan)
		idleEmitter(tipR, "HorizonSparkR", "rbxassetid://10558510611", 4, 0.22, cyan)
	end
	idleEmitter(core, "HorizonOrb", "rbxassetid://7216853898", 3, 0.42, cyan)
	aura(model, cyan)
end

function MagnetSkinBuilder.build(skinId: string): Model?
	local definition = MagnetSkinConfig.ById[skinId]
	if definition == nil then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = definition.Id
	if skinId == "YardPaint" then
		yardPaint(model)
	elseif skinId == "ChromeCoil" then
		chromeCoil(model)
	elseif skinId == "EmberCore" then
		emberCore(model)
	elseif skinId == "Orbital" then
		orbital(model)
	elseif skinId == "EventHorizon" then
		eventHorizon(model)
	else
		horseshoe(model, colour(definition.Accent), colour(definition.Accent), colour("Red"), colour("Blue"))
	end
	local gripPart = model:FindFirstChild("Grip")
	if gripPart and gripPart:IsA("BasePart") then
		model.PrimaryPart = gripPart
		model:PivotTo(CFrame.new())
	end
	return model
end

--[[
	Same Y-up model, yawed so the U faces the camera. Shop cards use this; the
	hand weld uses `build`.
]]
function MagnetSkinBuilder.buildPreview(skinId: string): Model?
	local model = MagnetSkinBuilder.build(skinId)
	if model == nil then
		return nil
	end
	model:PivotTo(CFrame.Angles(0, math.rad(22), 0))
	return model
end

return table.freeze(MagnetSkinBuilder)
