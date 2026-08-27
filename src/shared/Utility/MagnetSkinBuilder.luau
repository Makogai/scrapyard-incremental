--!strict
--[[
	MagnetSkinBuilder.luau
	Builds the held magnet for a cosmetic skin from primitives.

	ORIENTATION MATCHES `AdvancedMagnet`: grip PrimaryPart at the origin, head
	in +X, model lying in XZ. Attach applies a fixed 90/90, so a Y-up build
	floats beside the hand.

	Silhouette over part count. A U with ball tips reads as a magnet; a cube
	with three bands does not. Stay under 20 parts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local MagnetSkinConfig = require(ReplicatedStorage.Shared.Config.MagnetSkinConfig)

local MagnetSkinBuilder = {}

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
	point.Range = 8
	point.Parent = parent
end

local function grip(model: Model, paint: Color3): Part
	return part("Grip", Vector3.new(0.24, 0.24, 0.24), CFrame.new(), paint, Enum.Material.SmoothPlastic, model)
end

local function horseshoe(model: Model, body: Color3, accent: Color3, tipA: Color3, tipB: Color3, wrapped: boolean)
	local material = if wrapped then Enum.Material.Neon else Enum.Material.SmoothPlastic
	grip(model, body)
	part("Yoke", Vector3.new(0.38, 0.38, 1.38), CFrame.new(0.24, 0, 0), body, material, model)
	part("PoleL", Vector3.new(1.35, 0.38, 0.38), CFrame.new(1.05, 0, -0.5), body, material, model)
	part("PoleR", Vector3.new(1.35, 0.38, 0.38), CFrame.new(1.05, 0, 0.5), body, material, model)
	part("Stripe", Vector3.new(0.14, 0.42, 1.22), CFrame.new(0.24, 0, 0), accent, Enum.Material.Neon, model)
	local left = part("TipL", Vector3.new(0.48, 0.48, 0.48), CFrame.new(1.72, 0, -0.5), tipA, Enum.Material.Neon, model)
	left.Shape = Enum.PartType.Ball
	local right = part("TipR", Vector3.new(0.48, 0.48, 0.48), CFrame.new(1.72, 0, 0.5), tipB, Enum.Material.Neon, model)
	right.Shape = Enum.PartType.Ball
	if wrapped then
		local wraps = { 0.7, 1.15 }
		for index, x in wraps do
			local a = part(
				`WrapL{index}`,
				Vector3.new(0.1, 0.56, 0.56),
				CFrame.new(x, 0, -0.5),
				accent,
				Enum.Material.Neon,
				model
			)
			a.Shape = Enum.PartType.Cylinder
			local b = part(
				`WrapR{index}`,
				Vector3.new(0.1, 0.56, 0.56),
				CFrame.new(x, 0, 0.5),
				accent,
				Enum.Material.Neon,
				model
			)
			b.Shape = Enum.PartType.Cylinder
		end
	end
end

local function coil(model: Model, body: Color3, accent: Color3)
	grip(model, body)
	part("Stem", Vector3.new(0.5, 0.28, 0.28), CFrame.new(0.34, 0, 0), body, Enum.Material.SmoothPlastic, model)
	local barrel = part("Barrel", Vector3.new(1.15, 0.78, 0.78), CFrame.new(1.15, 0, 0), body, Enum.Material.SmoothPlastic, model)
	barrel.Shape = Enum.PartType.Cylinder
	local xs = { 0.7, 0.92, 1.15, 1.38, 1.6 }
	for index, x in xs do
		local band =
			part(`Band{index}`, Vector3.new(0.12, 0.92, 0.92), CFrame.new(x, 0, 0), accent, Enum.Material.Neon, model)
		band.Shape = Enum.PartType.Cylinder
	end
	local core = part("Core", Vector3.new(0.52, 0.52, 0.52), CFrame.new(1.15, 0, 0), accent, Enum.Material.Neon, model)
	core.Shape = Enum.PartType.Ball
	light(core, accent, 1.25)
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
		part(
			`{prefix}_{index}`,
			Vector3.new(chord, 0.1, thickness),
			offset,
			paint,
			Enum.Material.Neon,
			model
		)
	end
end

local function planet(model: Model, body: Color3, accent: Color3, ring: Color3)
	grip(model, body)
	local globe = part("Globe", Vector3.new(0.95, 0.95, 0.95), CFrame.new(0.95, 0, 0), body, Enum.Material.SmoothPlastic, model)
	globe.Shape = Enum.PartType.Ball
	local belt = part(
		"Belt",
		Vector3.new(0.12, 0.98, 0.98),
		CFrame.new(0.95, 0, 0),
		accent,
		Enum.Material.Neon,
		model
	)
	belt.Shape = Enum.PartType.Cylinder
	local around = CFrame.new(0.95, 0, 0)
	ringBoxes(model, "RingA", 0.82, 0.2, around, math.rad(8), ring, 8)
	ringBoxes(model, "RingB", 1.12, 0.14, around, math.rad(22), accent, 8)
	light(globe, accent, 0.5)
end

local function void(model: Model, body: Color3, accent: Color3, rim: Color3)
	grip(model, rim)
	local horizon = part("Horizon", Vector3.new(0.92, 0.92, 0.92), CFrame.new(0.95, 0, 0), body, Enum.Material.SmoothPlastic, model)
	horizon.Shape = Enum.PartType.Ball
	local disc = part(
		"Disc",
		Vector3.new(0.06, 1.85, 1.85),
		CFrame.new(0.95, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
		rim,
		Enum.Material.Neon,
		model
	)
	disc.Shape = Enum.PartType.Cylinder
	local halo = part(
		"Halo",
		Vector3.new(0.05, 2.25, 2.25),
		CFrame.new(0.95, 0, 0) * CFrame.Angles(math.rad(14), 0, math.rad(90)),
		accent,
		Enum.Material.Neon,
		model
	)
	halo.Shape = Enum.PartType.Cylinder
	local spark = part("Spark", Vector3.new(0.28, 0.28, 0.28), CFrame.new(0.95, 0, 0), accent, Enum.Material.Neon, model)
	spark.Shape = Enum.PartType.Ball
	light(spark, accent, 0.85)
end

function MagnetSkinBuilder.build(skinId: string): Model?
	local definition = MagnetSkinConfig.ById[skinId]
	if definition == nil then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = definition.Id
	if skinId == "YardPaint" then
		horseshoe(model, colour("Orange"), colour("Gold"), colour("Red"), colour("Blue"), false)
	elseif skinId == "ChromeCoil" then
		horseshoe(model, Theme.Color.Gray, colour("Cyan"), colour("Cyan"), colour("Blue"), true)
	elseif definition.Form == "Coil" then
		coil(model, colour("Ink"), colour("Orange"))
	elseif definition.Form == "Planet" then
		planet(model, colour("Purple"), colour("Gold"), colour("Orange"))
	elseif definition.Form == "Void" then
		void(model, colour("Ink"), colour("Pink"), colour("Purple"))
	else
		horseshoe(model, colour(definition.Accent), colour(definition.Accent), colour("Red"), colour("Blue"), false)
	end
	local gripPart = model:FindFirstChild("Grip")
	if gripPart and gripPart:IsA("BasePart") then
		model.PrimaryPart = gripPart
		model:PivotTo(CFrame.new())
	end
	return model
end

return table.freeze(MagnetSkinBuilder)
