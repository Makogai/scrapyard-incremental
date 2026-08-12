--!strict
--[[
	SecretPetVfxController.luau
	The burst when somebody pulls a Secret pet.

	Driven by the existing `Announce` remote, which `PetService` already fires to every client on a Secret
	hatch. Reusing it rather than adding a remote means the VFX and the announcement banner can never
	disagree about whether something rare happened.

	EVERYONE SEES IT, AT THE PULLER. A Secret is a once-in-500-rolls event and the social half is the
	point: the burst goes off on the lucky player's character so the rest of the server turns to look. The
	player who actually pulled it gets a stronger version -- a fuller burst and a camera-height flash --
	because being the one who got it should not look identical to watching someone else get it.

	FULLY SELF-CLEANING. Every instance is parented to one folder that is destroyed on a timer, so a burst
	cannot leak parts into the workspace if the player dies, resets or leaves mid-effect.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)

local SecretPetVfxController = {}

--- How long the whole thing lives. Long enough to notice across the yard, short enough not to linger.
local BURST_SECONDS = 3.2
local RING_SECONDS = 1.1

--[[
	Secret pink by default, but read from `PetConfig` so a rarity recolour never leaves the VFX behind.
	`FallbackColor` on the pet itself wins when it has one -- a Secret with bespoke art gets its own burst.
]]
local function colourFor(petId: string?, rarity: string?): Color3
	local definition = if petId ~= nil then PetConfig.Pets[petId] else nil
	if definition ~= nil and typeof(definition.FallbackColor) == "Color3" then
		return definition.FallbackColor
	end
	local byRarity = if rarity ~= nil then (PetConfig.RarityColors or {})[rarity] else nil
	if typeof(byRarity) == "Color3" then
		return byRarity
	end
	return Color3.fromRGB(255, 75, 148)
end

--- An expanding, fading ring on the ground. Reads as an impact without needing an asset.
local function ring(folder: Folder, origin: Vector3, colour: Color3)
	local part = Instance.new("Part")
	part.Name = "Ring"
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = colour
	part.Transparency = 0.25
	part.Size = Vector3.new(0.4, 3, 3)
	--- Rotated so the cylinder's flat face lies on the ground: its length runs along local X.
	part.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))
	part.Parent = folder

	TweenService
		:Create(
			part,
			TweenInfo.new(RING_SECONDS, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{
				Size = Vector3.new(0.4, 34, 34),
				Transparency = 1,
			}
		)
		:Play()
end

--- A column of light, so the pull is visible from across the map rather than only up close.
local function pillar(folder: Folder, origin: Vector3, colour: Color3, strong: boolean)
	local anchor = Instance.new("Part")
	anchor.Name = "Pillar"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(origin)
	anchor.Parent = folder

	local base = Instance.new("Attachment")
	base.Parent = anchor
	local tip = Instance.new("Attachment")
	tip.Position = Vector3.new(0, if strong then 90 else 60, 0)
	tip.Parent = anchor

	local beam = Instance.new("Beam")
	beam.Attachment0 = base
	beam.Attachment1 = tip
	beam.Width0 = if strong then 7 else 4.5
	beam.Width1 = 0
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(colour)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Parent = anchor

	TweenService:Create(beam, TweenInfo.new(BURST_SECONDS, Enum.EasingStyle.Sine), {
		Width0 = 0,
	}):Play()

	local light = Instance.new("PointLight")
	light.Color = colour
	light.Brightness = if strong then 6 else 3
	light.Range = if strong then 46 else 30
	light.Shadows = false
	light.Parent = anchor
	TweenService:Create(light, TweenInfo.new(BURST_SECONDS), { Brightness = 0 }):Play()
end

--- The confetti. One emitter, burst-emitted rather than left running, so it ends on its own.
local function sparks(folder: Folder, origin: Vector3, colour: Color3, strong: boolean)
	local anchor = Instance.new("Part")
	anchor.Name = "Sparks"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(origin + Vector3.new(0, 3, 0))
	anchor.Parent = folder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(colour)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.9, 1.8)
	emitter.Speed = NumberRange.new(18, 34)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Acceleration = Vector3.new(0, -22, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if strong then 0.7 else 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = anchor
	emitter:Emit(if strong then 160 else 90)
end

local function burst(character: Model, colour: Color3, strong: boolean)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		or character:FindFirstChildWhichIsA("BasePart")
	if root == nil then
		return
	end

	--[[
		One folder for the whole burst, dropped on a timer. `Debris` rather than a `task.delay` and a
		manual destroy: it survives the controller being garbage collected and cannot leave orphans.
	]]
	local folder = Instance.new("Folder")
	folder.Name = "SecretPetBurst"
	folder.Parent = workspace
	Debris:AddItem(folder, BURST_SECONDS + 1)

	local origin = root.Position - Vector3.new(0, root.Size.Y * 0.5, 0)
	ring(folder, origin, colour)
	pillar(folder, origin, colour, strong)
	sparks(folder, origin, colour, strong)
end

--[[
	Find the character to play on.

	Matched by `UserId`, with `PlayerName` only as a fallback: two players can share a display name, and
	the burst going off on the wrong person is worse than it not going off at all.
]]
local function characterFor(userId: number?, playerName: string?): (Model?, boolean)
	local localPlayer = Players.LocalPlayer
	if userId ~= nil and userId > 0 then
		local player = Players:GetPlayerByUserId(userId)
		if player ~= nil and player.Character ~= nil then
			return player.Character, player == localPlayer
		end
		return nil, false
	end
	if playerName ~= nil then
		for _, player in Players:GetPlayers() do
			if player.DisplayName == playerName or player.Name == playerName then
				return player.Character, player == localPlayer
			end
		end
	end
	return nil, false
end

function SecretPetVfxController.Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local announce = remotes:WaitForChild("Announce") :: RemoteEvent

	announce.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or payload.Kind ~= "SecretPet" then
			return
		end
		local character, isLocal = characterFor(payload.UserId, payload.PlayerName)
		if character == nil then
			return
		end
		burst(character, colourFor(payload.PetId, payload.Rarity), isLocal)
	end)
end

return table.freeze(SecretPetVfxController)
