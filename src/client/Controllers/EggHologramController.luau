--!strict
--[[
	EggHologramController.luau
	Makes the egg on every summon podium read as a hologram: translucent, rim-lit, a shaft of light rising
	through it, and floating gently up and down.

	Authored shape (all of it optional -- a podium that does not match is skipped):

		Workspace.NewMap.FeaturedPodium.EggSummonPodium
		  FrontYardEggGroup
		    FrontYardEgg                  the mesh that floats
		    FrontYardEggStand             left alone
		  WorkshopYardEggGroup
		  VehicleGraveyardEggGroup

	The egg is found by name: something containing "egg" that is not the group, the stand or the podium
	base. If nothing matches, the largest child Model is used, because "the big thing on the podium" is the
	egg in every layout we have.

	CLIENT-SIDE ON PURPOSE. Every part of this is cosmetic, so it costs the server nothing, replicates
	nothing, and can bob at full framerate. The trade is that the egg's real collision and its real
	position never move -- only what this player sees -- which is exactly what we want for map geometry
	that a `ProximityPrompt` is anchored to.

	Per-podium overrides, so the map can be retuned without touching code. Set either on the group or on
	the podium:

		HologramColor    Color3     the tint, rim and light shaft colour
		HologramFloat    number     bob amplitude in studs (0 disables the float)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EggPodiums = require(ReplicatedStorage.Shared.Utility.EggPodiums)

local EggHologramController = {}

--[[
	0.3 is what was asked for: clearly see-through, still clearly a solid object with its own texture and
	its cartoon shading intact. Past about 0.5 a MeshPart stops reading as an egg and starts reading as
	glass.
]]
local HOLOGRAM_TRANSPARENCY = 0.3

--- The default tint. Overridden per podium by a `HologramColor` attribute.
local HOLOGRAM_COLOUR = Color3.fromRGB(96, 220, 255)

--[[
	THE FLOAT. Small and slow -- "a bit going up and down" rather than a bounce.

	0.35 studs against an egg a few studs tall is a movement you notice without it looking like the egg is
	trying to escape. The period is deliberately not a round number: several podiums in view drift out of
	phase with each other instead of pulsing in unison, which reads as alive rather than as a script.
]]
local FLOAT_STUDS = 0.35
local FLOAT_SECONDS = 2.6

--- How far the shaft of light rises above the egg, and how much wider than the egg it starts.
local BEAM_RISE_STUDS = 7
local BEAM_BASE_SCALE = 0.85
local BEAM_TIP_SCALE = 0.2

--------------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------------

--[[
	The WORLD axis-aligned box around a set of parts.

	Not `Model:GetBoundingBox()`: that box is aligned to the model's PrimaryPart, so for a rotated or
	off-pivot egg it reports a box in the wrong space and the light shaft lands beside the egg instead of
	through it. Eight rotated corners per part is the only reading that survives an authored rotation.
]]
local function worldBounds(parts: { BasePart }): (Vector3, Vector3)
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in parts do
		local half = part.Size * 0.5
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local corner = part.CFrame * Vector3.new(half.X * x, half.Y * y, half.Z * z)
					min = min:Min(corner)
					max = max:Max(corner)
				end
			end
		end
	end
	return min, max
end

local function partsOf(instance: Instance): { BasePart }
	local parts = {}
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

--------------------------------------------------------------------------------
-- Finding the egg
--------------------------------------------------------------------------------

--[[
	Every egg to dress, across every podium.

	Each site from `EggPodiums` is searched for its visual egg. The group is
	returned alongside so its attribute overrides can be read.
]]
local function collectEggs(map: Instance): { { Egg: Instance, Holder: Instance } }
	local found = {}
	for _, site in EggPodiums.collect(map) do
		local egg = EggPodiums.findVisualEgg(site)
		if egg ~= nil then
			table.insert(found, { Egg = egg, Holder = site })
		end
	end
	return found
end

--------------------------------------------------------------------------------
-- The look
--------------------------------------------------------------------------------

local function attributeColour(holder: Instance, podium: Instance?): Color3
	local own = holder:GetAttribute("HologramColor")
	if typeof(own) == "Color3" then
		return own
	end
	if podium ~= nil then
		local inherited = podium:GetAttribute("HologramColor")
		if typeof(inherited) == "Color3" then
			return inherited
		end
	end
	return HOLOGRAM_COLOUR
end

local function attributeFloat(holder: Instance): number
	local own = holder:GetAttribute("HologramFloat")
	if typeof(own) == "number" then
		return math.max(0, own)
	end
	return FLOAT_STUDS
end

--[[
	Translucency and a rim, applied to the egg's own parts.

	`CastShadow = false` because a hologram casting a hard shadow is the single thing that breaks the
	illusion fastest. Material and colour are left alone: the car egg was generated with cartoon shading
	and the point is to see it THROUGH the effect, not to replace it with a cyan blob.
]]
local function dressEgg(egg: Instance, parts: { BasePart }, colour: Color3)
	for _, part in parts do
		part.Transparency = math.max(part.Transparency, HOLOGRAM_TRANSPARENCY)
		part.CastShadow = false
		--- Anchored, or the bob fights gravity and the egg sinks through its own stand.
		part.Anchored = true
	end

	--[[
		The rim light. `Occluded` rather than the default `AlwaysOnTop`: an outline that draws through
		walls turns every egg into a waypoint visible across the whole map.
	]]
	local highlight = Instance.new("Highlight")
	highlight.Name = "HologramRim"
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = colour
	highlight.FillTransparency = 0.82
	highlight.OutlineColor = colour
	highlight.OutlineTransparency = 0.25
	highlight.Adornee = if egg:IsA("Model") then egg else nil
	if highlight.Adornee == nil and egg:IsA("BasePart") then
		highlight.Adornee = egg
	end
	highlight.Parent = egg
end

--[[
	The shaft of light rising through the egg, plus motes drifting up it.

	Parented to a static invisible part rather than to the egg, so the light column stays put while the egg
	floats through it. A beam that bobs with its egg looks like a lift, not a light.
]]
local function buildLightColumn(holder: Instance, min: Vector3, max: Vector3, colour: Color3)
	local centre = (min + max) * 0.5
	local width = math.max(max.X - min.X, max.Z - min.Z)

	local anchor = Instance.new("Part")
	anchor.Name = "HologramColumn"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(Vector3.new(centre.X, min.Y, centre.Z))
	anchor.Parent = holder

	local base = Instance.new("Attachment")
	base.Name = "Base"
	base.Parent = anchor

	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.Position = Vector3.new(0, BEAM_RISE_STUDS, 0)
	tip.Parent = anchor

	--[[
		No texture: an untextured Beam is a flat band of colour, and with a transparency ramp that is
		exactly a light shaft. Avoids shipping an asset for something two NumberSequence keypoints do.
	]]
	local beam = Instance.new("Beam")
	beam.Name = "HologramBeam"
	beam.Attachment0 = base
	beam.Attachment1 = tip
	beam.Width0 = width * BEAM_BASE_SCALE
	beam.Width1 = width * BEAM_TIP_SCALE
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(colour)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.45, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Parent = anchor

	--- Slow rising specks. Rate is low on purpose: this is atmosphere, not a fountain.
	local motes = Instance.new("ParticleEmitter")
	motes.Name = "HologramMotes"
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.Color = ColorSequence.new(colour)
	motes.LightEmission = 1
	motes.LightInfluence = 0
	motes.Rate = 7
	motes.Lifetime = NumberRange.new(1.6, 2.6)
	motes.Speed = NumberRange.new(1.8, 3.2)
	motes.SpreadAngle = Vector2.new(8, 8)
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.16),
		NumberSequenceKeypoint.new(1, 0),
	})
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	motes.EmissionDirection = Enum.NormalId.Top
	motes.Acceleration = Vector3.new(0, 1.2, 0)
	motes.Parent = base

	--- A soft local glow so the egg lights its own stand.
	local light = Instance.new("PointLight")
	light.Name = "HologramGlow"
	light.Color = colour
	light.Brightness = 1.6
	light.Range = math.max(10, width * 3)
	light.Shadows = false
	light.Parent = anchor
end

--------------------------------------------------------------------------------
-- Start
--------------------------------------------------------------------------------

function EggHologramController.Start()
	local map = workspace:WaitForChild("NewMap", 20)
	if map == nil then
		warn("[EggHologram] Workspace.NewMap never appeared - no eggs dressed")
		return
	end

	type Floater = { Egg: Instance, Origin: CFrame, Amplitude: number, Phase: number }
	local floaters: { Floater } = {}

	for index, entry in collectEggs(map) do
		local egg = entry.Egg
		local parts = partsOf(egg)
		if #parts == 0 then
			continue
		end

		local podium = egg:FindFirstAncestorOfClass("Model")
		local colour = attributeColour(entry.Holder, podium)
		local min, max = worldBounds(parts)

		dressEgg(egg, parts, colour)
		buildLightColumn(entry.Holder, min, max, colour)

		local amplitude = attributeFloat(entry.Holder)
		if amplitude > 0 then
			table.insert(floaters, {
				Egg = egg,
				Origin = if egg:IsA("Model")
					then (egg :: Model):GetPivot()
					else (egg :: BasePart).CFrame,
				Amplitude = amplitude,
				--[[
					A per-egg phase offset from the index, so two podiums in one shot are never in
					lockstep. `Math.random` is not needed and a fixed offset is reproducible.
				]]
				Phase = (index - 1) * 0.7,
			})
		end
	end

	if #floaters == 0 then
		return
	end

	--[[
		One connection for every egg rather than one each. Vertical translation only -- no spin, because
		rotating a model whose pivot is not at its centre swings it around a point beside itself, and the
		float is what was asked for.
	]]
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, floater in floaters do
			local lift = math.sin((now / FLOAT_SECONDS + floater.Phase) * math.pi * 2)
				* floater.Amplitude
			local pose = floater.Origin * CFrame.new(0, lift, 0)
			local egg = floater.Egg
			if egg:IsA("Model") then
				(egg :: Model):PivotTo(pose)
			elseif egg:IsA("BasePart") then
				(egg :: BasePart).CFrame = pose
			end
		end
	end)
end

return EggHologramController
