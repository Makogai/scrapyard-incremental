--!strict
--[[
	WreckService.luau
	THE PIT's chip-away wreck: one big piece, server-owned integrity, public chunks when it breaks.

	Not magnet-collectable. Players whose magnet reaches it chip it. A shield
	pauses that DPS until someone magnets the one overload node on the floor;
	then the node moves. More people finish it faster; one person can finish it
	alone.

	WHERE IT STANDS. A Studio part named `WreckAnchor` under Event Area. The art is
	ONLY the instance named `RobotWreck`. Pit scrap is never a fallback.
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local AdminConfig = require(ReplicatedStorage.Shared.Config.AdminConfig)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RemoteService = require(script.Parent.RemoteService)
local ScrapService = require(script.Parent.ScrapService)

local WreckService = {}

local wreckConfig = ArenaConfig.Wreck
local started = false
local area: Model? = nil
local folder: Folder? = nil
local wreck: Model? = nil
local groundAt: Vector3? = nil
local integrity = 0
local integrityMax = wreckConfig.Integrity
local integrityOverride: number? = nil
local dying = false
local deathGeneration = 0
local fillBar: Frame? = nil
local label: TextLabel? = nil
local contributions: { [number]: number } = {}
local respawnAt = 0
local retriedTemplate = false
local shielded = false
local chippedSinceShield = 0
local shieldReadyAt = 0
local overload: Model? = nil
local overloadSpawnedAt = 0
local lastOverloadPad: BasePart? = nil
local clearShield = function(_shouldBurst: boolean) end

local function isTemplate(instance: Instance): boolean
	return instance:IsA("Model") or instance:IsA("BasePart")
end

local function unwrap(instance: Instance): Instance?
	if isTemplate(instance) then
		return instance
	end
	if instance:IsA("Folder") then
		local model = instance:FindFirstChildWhichIsA("Model")
		if model then
			return model
		end
		local part = instance:FindFirstChildWhichIsA("BasePart")
		if part then
			return part
		end
	end
	return nil
end

local function compactName(instance: Instance): string
	return string.lower((string.gsub(instance.Name, "[%s_%-]+", "")))
end

local function isWreckName(instance: Instance): boolean
	if instance.Name == wreckConfig.AnchorName then
		return false
	end
	local n = compactName(instance)
	return n == "robotwreck" or n == "wreck"
end

local function isLiveClone(instance: Instance): boolean
	return instance:FindFirstAncestor("PitWrecksLive") ~= nil
end

local function dumpWreckish()
	warn(
		"[WreckService] No RobotWreck found. Workspace models/parts whose names mention robot or wreck:"
	)
	for _, inst in Workspace:GetDescendants() do
		local n = compactName(inst)
		if
			(isTemplate(inst) or inst:IsA("Folder"))
			and (string.find(n, "wreck", 1, true) or string.find(n, "robot", 1, true))
		then
			warn(`  {inst:GetFullName()} ({inst.ClassName})`)
		end
	end
end

local STORED_TEMPLATE_NAME = "RobotWreckTemplate"

local function pinParts(instance: Instance)
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.AssemblyLinearVelocity = Vector3.zero
		instance.AssemblyAngularVelocity = Vector3.zero
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function findWreckAsset(): Instance?
	--[[
		Authored path, confirmed in Studio: Workspace.RobotWreck (Model, one MeshPart).
		Look there first -- a descendant walk can hit the wrong thing, and moving the
		template into ScrapModels/WreckSource made later Play sessions miss it.
		A ServerStorage clone is a safety copy in case the Workspace mesh is still
		unanchored in the place file and falls before Open.
	]]
	local stored = ServerStorage:FindFirstChild(STORED_TEMPLATE_NAME)
	if stored then
		local asset = unwrap(stored)
		if asset then
			return asset
		end
	end
	for _, name in wreckConfig.ModelNames do
		local direct = Workspace:FindFirstChild(name)
		if direct then
			local asset = unwrap(direct)
			if asset then
				return asset
			end
		end
	end
	local spaced = Workspace:FindFirstChild("Robot Wreck")
	if spaced then
		local asset = unwrap(spaced)
		if asset then
			return asset
		end
	end

	local partFallback: Instance? = nil
	for _, inst in Workspace:GetDescendants() do
		if isLiveClone(inst) or not isWreckName(inst) then
			continue
		end
		if inst:FindFirstAncestor("EventScrap") ~= nil then
			continue
		end
		if inst:FindFirstAncestor("ScrapModels") ~= nil then
			continue
		end
		local asset = unwrap(inst)
		if asset == nil then
			continue
		end
		if asset:IsA("Model") then
			return asset
		end
		if partFallback == nil then
			partFallback = asset
		end
	end
	return partFallback
end

local function wreckTemplate(): Instance?
	local found = findWreckAsset()
	if found == nil then
		dumpWreckish()
		return nil
	end
	print(`[WreckService] template is {found:GetFullName()} ({found.ClassName})`)
	return found
end

local function topOf(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position + Vector3.new(0, instance.Size.Y / 2, 0)
	end
	if instance:IsA("Model") then
		local cf, size = instance:GetBoundingBox()
		return cf.Position + Vector3.new(0, size.Y / 2, 0)
	end
	return nil
end

local function anchors(host: Model, placed: Instance?): { Vector3 }
	local named = host:FindFirstChild(wreckConfig.AnchorName, true)
		or Workspace:FindFirstChild(wreckConfig.AnchorName, true)
	if named then
		local point = topOf(named)
		if point then
			return { point }
		end
	end
	if placed then
		local point = topOf(placed)
		if point then
			print("[WreckService] no WreckAnchor -- standing the wreck where RobotWreck already is")
			return { point }
		end
	end
	local points = {}
	local wrecksFolder = host:FindFirstChild(wreckConfig.FolderName)
	if wrecksFolder then
		for _, child in wrecksFolder:GetChildren() do
			local point = topOf(child)
			if point then
				table.insert(points, point)
			end
		end
	end
	if #points > 0 then
		return points
	end
	warn(
		"[WreckService] Place a part named WreckAnchor under Event Area on the floor -- wreck will not appear until that exists"
	)
	return {}
end

local function solidify(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanTouch = false
			if descendant.Name == "WreckHpAnchor" then
				descendant.CanCollide = false
				descendant.CanQuery = false
				continue
			end
			descendant.CanCollide = true
			if descendant:IsA("MeshPart") then
				pcall(function()
					descendant.CollisionFidelity = Enum.CollisionFidelity.Hull
				end)
			end
		end
	end
end

local function placeHpAnchor(model: Model, ground: Vector3): BasePart
	local existing = model:FindFirstChild("WreckHpAnchor")
	local part: BasePart
	if existing and existing:IsA("BasePart") then
		part = existing
	else
		part = Instance.new("Part")
		part.Name = "WreckHpAnchor"
		part.Size = Vector3.new(0.2, 0.2, 0.2)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CastShadow = false
		part.Parent = model
	end
	part.CFrame = CFrame.new(ground.X, ground.Y + wreckConfig.BarHeightStuds, ground.Z)
	return part
end

local function fitLandmark(model: Model)
	local target = wreckConfig.FitLongestStuds
	local _, size = model:GetBoundingBox()
	local longest = math.max(size.X, size.Y, size.Z)
	if longest < 0.05 or target <= 0 or math.abs(longest - target) < 0.2 then
		return
	end
	model:ScaleTo(model:GetScale() * (target / longest))
end

local function standOn(model: Model, ground: Vector3)
	local yaw = math.rad(wreckConfig.YawDegrees)
	model:PivotTo(CFrame.new(ground) * CFrame.Angles(0, yaw, 0))
	local cf, size = model:GetBoundingBox()
	local lift = (ground.Y + size.Y / 2) - cf.Position.Y
	model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
end

local function setBar()
	local fill = fillBar
	local text = label
	local maxIntegrity = integrityMax
	local ratio = if maxIntegrity > 0 then math.clamp(integrity / maxIntegrity, 0, 1) else 0
	if fill then
		fill.Size = UDim2.fromScale(ratio, 1)
		fill.BackgroundColor3 = if shielded
			then Color3.fromRGB(33, 229, 245)
			else Color3.fromRGB(255, 140, 48)
	end
	if text then
		text.Text = if shielded
			then "SHIELDED"
			else `WRECK  {math.ceil(integrity)} / {maxIntegrity}`
	end
	local model = wreck
	if model then
		model:SetAttribute("WreckIntegrity", math.ceil(integrity))
		model:SetAttribute("WreckIntegrityMax", maxIntegrity)
		model:SetAttribute("WreckShielded", shielded)
	end
end

local function attachBillboard(model: Model, ground: Vector3)
	local adornee = placeHpAnchor(model, ground)
	local gui = Instance.new("BillboardGui")
	gui.Name = "WreckIntegrity"
	--[[
		Sized in studs so it is a world plate at chest height, not a 220px sticker
		on the robot's crown that you have to zoom out and look up to find.
	]]
	gui.Size = UDim2.fromScale(wreckConfig.BarWidthStuds, 2.2)
	gui.StudsOffset = Vector3.zero
	gui.AlwaysOnTop = true
	gui.MaxDistance = 0
	gui.LightInfluence = 0
	gui.Adornee = adornee
	gui.Parent = model

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
	back.BorderSizePixel = 0
	back.Parent = gui
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 8)
	backCorner.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(20, 24, 32)
	stroke.Parent = back

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 140, 48)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = fill

	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.Text = ""
	text.Parent = back
	local textStroke = Instance.new("UIStroke")
	textStroke.Thickness = 2
	textStroke.Color = Color3.fromRGB(20, 24, 32)
	textStroke.Parent = text

	fillBar = fill
	label = text
	setBar()
end

local chunkTotal = 0
for _, weight in wreckConfig.ChunkWeights do
	chunkTotal += weight
end

local function rollChunkId(): string
	local roll = math.random() * chunkTotal
	for scrapId, weight in wreckConfig.ChunkWeights do
		roll -= weight
		if roll <= 0 then
			return scrapId
		end
	end
	return "Drone"
end

local function spillBurst(position: Vector3, count: number)
	if count <= 0 then
		return
	end
	for index = 1, count do
		local angle = (index / count) * math.pi * 2
		local radius = 6 + (index % 3) * 3
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		ScrapService.SpawnPublic(rollChunkId(), position + offset, 1)
	end
end

local function spill(position: Vector3)
	spillBurst(position, wreckConfig.ChunkCount)
end

local function payContributors()
	local total = 0
	for _, amount in contributions do
		total += amount
	end
	if total <= 0 then
		return
	end
	for userId, amount in contributions do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local share = wreckConfig.ContributorSlag * (amount / total)
			PlayerStateService.GrantSlag(
				player,
				math.max(4, math.floor(share + 0.5)),
				"WRECK CLEARED"
			)
		end
	end
end

local function wreckMesh(model: Model): BasePart?
	local source: BasePart? = nil
	local bestVolume = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "WreckHpAnchor" then
			local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
			if volume > bestVolume then
				source = descendant
				bestVolume = volume
			end
		end
	end
	return source or model.PrimaryPart
end

local function attachBreakdownFx(host: BasePart)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "WreckSparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 120, 40))
	sparks.LightEmission = 0.85
	sparks.LightInfluence = 0
	sparks.Lifetime = NumberRange.new(0.12, 0.35)
	sparks.Rate = 70
	sparks.Speed = NumberRange.new(18, 48)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Acceleration = Vector3.new(0, -20, 0)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Parent = host

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "WreckSmoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 70, 75), Color3.fromRGB(30, 30, 32))
	smoke.LightEmission = 0
	smoke.LightInfluence = 0.15
	smoke.Lifetime = NumberRange.new(0.8, 1.6)
	smoke.Rate = 28
	smoke.Speed = NumberRange.new(2, 7)
	smoke.SpreadAngle = Vector2.new(40, 40)
	smoke.Acceleration = Vector3.new(0, 14, 0)
	smoke.Rotation = NumberRange.new(0, 180)
	smoke.RotSpeed = NumberRange.new(-40, 40)
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.2),
		NumberSequenceKeypoint.new(1, 6),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Parent = host

	local light = Instance.new("PointLight")
	light.Name = "WreckBreakdownLight"
	light.Color = Color3.fromRGB(255, 170, 70)
	light.Brightness = 4
	light.Range = 28
	light.Parent = host
end

local function ejectOverlappingPlayers(model: Model)
	local cf, size = model:GetBoundingBox()
	local half = size * 0.5
	local pad = 8
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root == nil or not root:IsA("BasePart") then
			continue
		end
		local localPoint = cf:PointToObjectSpace(root.Position)
		local inside = math.abs(localPoint.X) < (half.X - 1)
			and math.abs(localPoint.Z) < (half.Z - 1)
			and localPoint.Y > -half.Y
			and localPoint.Y < half.Y
		if not inside then
			continue
		end
		local away =
			Vector3.new(root.Position.X - cf.Position.X, 0, root.Position.Z - cf.Position.Z)
		if away.Magnitude < 0.2 then
			away = Vector3.new(1, 0, 0)
		end
		local reach = math.max(half.X, half.Z) + pad
		local dest = Vector3.new(cf.Position.X, root.Position.Y, cf.Position.Z) + away.Unit * reach
		character:PivotTo(CFrame.new(dest) * (character:GetPivot() - character:GetPivot().Position))
		root.AssemblyLinearVelocity = away.Unit * 28 + Vector3.new(0, 8, 0)
	end
end

local function explodeWreck(model: Model, position: Vector3)
	--[[
		The live wreck is one imported MeshPart. Unanchoring it (CanCollide off) drops it
		through the floor, which reads as sinking. Shatter it into flying copies of the
		same mesh instead, and destroy the original so it never falls.
	]]
	CollectionService:RemoveTag(model, "PitWreck")
	local source = wreckMesh(model)
	local host = folder or model.Parent
	local burst = Instance.new("Folder")
	burst.Name = "WreckBurst"
	burst.Parent = host

	local hub = Instance.new("Part")
	hub.Name = "WreckFlash"
	hub.Anchored = true
	hub.CanCollide = false
	hub.CanTouch = false
	hub.CanQuery = false
	hub.Transparency = 1
	hub.Size = Vector3.one
	hub.CFrame = CFrame.new(position + Vector3.new(0, 12, 0))
	hub.Parent = burst
	local flash = Instance.new("PointLight")
	flash.Color = Color3.fromRGB(255, 140, 48)
	flash.Brightness = 10
	flash.Range = 48
	flash.Parent = hub
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.4, 1)
	emitter.Speed = NumberRange.new(28, 80)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -28, 0)
	emitter.LightEmission = 0.7
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 170, 70), Color3.fromRGB(80, 40, 20))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.8),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	emitter.Parent = hub
	emitter:Emit(70)

	local fadeInfo = TweenInfo.new(1.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	if source ~= nil and source:IsA("BasePart") then
		local pieces = 10
		for index = 1, pieces do
			local wrap = Instance.new("Model")
			wrap.Name = "WreckChunk"
			local chunk = source:Clone()
			chunk.Name = "Mesh"
			chunk.Anchored = false
			chunk.CanCollide = false
			chunk.CanTouch = false
			chunk.CanQuery = false
			chunk.Massless = true
			chunk.Parent = wrap
			wrap.PrimaryPart = chunk
			wrap.Parent = burst
			local scale = 0.14 + math.random() * 0.16
			pcall(function()
				wrap:ScaleTo(scale)
			end)
			local y = 1 - ((index - 0.5) / pieces) * 2
			local ring = math.sqrt(math.max(0, 1 - y * y))
			local theta = math.pi * (1 + math.sqrt(5)) * (index - 1)
			local outward = Vector3.new(
				math.cos(theta) * ring,
				0.55 + math.abs(y) * 0.45,
				math.sin(theta) * ring
			)
			if outward.Magnitude < 0.05 then
				outward = Vector3.new(0, 1, 0)
			end
			outward = outward.Unit
			wrap:PivotTo(
				CFrame.new(position + outward * (6 + math.random() * 8) + Vector3.new(0, 10, 0))
					* CFrame.Angles(
						math.random() * math.pi,
						math.random() * math.pi,
						math.random() * math.pi
					)
			)
			chunk.AssemblyLinearVelocity = outward * (42 + math.random() * 38)
				+ Vector3.new(0, 62 + math.random() * 24, 0)
			chunk.AssemblyAngularVelocity = Vector3.new(
				(math.random() - 0.5) * 18,
				(math.random() - 0.5) * 18,
				(math.random() - 0.5) * 18
			)
			TweenService:Create(chunk, fadeInfo, { Transparency = 1 }):Play()
		end
	end

	for _ = 1, 10 do
		local shard = Instance.new("Part")
		shard.Name = "WreckSpark"
		shard.Anchored = false
		shard.CanCollide = false
		shard.CanTouch = false
		shard.Massless = true
		shard.Material = Enum.Material.Neon
		shard.Color = Color3.fromRGB(200 + math.random(0, 40), 80 + math.random(0, 40), 30)
		shard.Size = Vector3.new(
			1.2 + math.random() * 2.2,
			1.2 + math.random() * 2.2,
			1.2 + math.random() * 2.2
		)
		shard.CFrame = CFrame.new(
			position
				+ Vector3.new(
					(math.random() - 0.5) * 16,
					8 + math.random() * 14,
					(math.random() - 0.5) * 16
				)
		)
		shard.Parent = burst
		local away = shard.Position - position
		if away.Magnitude < 0.2 then
			away = Vector3.new(math.random() - 0.5, 1, math.random() - 0.5)
		end
		shard.AssemblyLinearVelocity = away.Unit * (36 + math.random() * 40) + Vector3.new(0, 50, 0)
		shard.AssemblyAngularVelocity = Vector3.new(
			(math.random() - 0.5) * 16,
			(math.random() - 0.5) * 16,
			(math.random() - 0.5) * 16
		)
		TweenService:Create(shard, fadeInfo, { Transparency = 1 }):Play()
	end

	model:Destroy()
	Debris:AddItem(burst, 1.7)
end

local function beginBreakdown(model: Model, position: Vector3)
	clearShield(false)
	dying = true
	deathGeneration += 1
	local token = deathGeneration
	local mesh = wreckMesh(model)
	if mesh then
		attachBreakdownFx(mesh)
	end
	local origin = model:GetPivot()
	task.spawn(function()
		local elapsed = 0
		local step = 0.05
		local duration = wreckConfig.BreakdownSeconds
		while elapsed < duration and wreck == model and token == deathGeneration do
			local shake = CFrame.new(
				(math.random() - 0.5) * 1.1,
				math.random() * 0.35,
				(math.random() - 0.5) * 1.1
			)
			model:PivotTo(origin * shake)
			elapsed += step
			task.wait(step)
		end
		if token ~= deathGeneration then
			return
		end
		if model.Parent == nil then
			dying = false
			return
		end
		if wreck == model then
			wreck = nil
			groundAt = nil
			fillBar = nil
			label = nil
		end
		dying = false
		explodeWreck(model, position)
		spill(position)
		respawnAt = os.clock() + wreckConfig.RespawnSeconds
	end)
end

local function destroyWreck()
	clearShield(false)
	deathGeneration += 1
	dying = false
	local model = wreck
	wreck = nil
	groundAt = nil
	fillBar = nil
	label = nil
	if model then
		model:Destroy()
	end
end

local function spawnWreck()
	local host = area
	local parent = folder
	if host == nil or parent == nil then
		return
	end
	local template = wreckTemplate()
	if template == nil then
		warn("[WreckService] No RobotWreck model in Workspace -- wreck will not appear")
		if not retriedTemplate then
			retriedTemplate = true
			task.delay(1, function()
				if area ~= nil and wreck == nil then
					spawnWreck()
				end
			end)
		end
		return
	end
	local templateName = compactName(template)
	if
		templateName == "submarine"
		or templateName == "drone"
		or templateName == "robotarm"
		or templateName == "lavacore"
		or templateName == "lavacorescrap"
	then
		warn(`[WreckService] refusing {template:GetFullName()} -- only RobotWreck may spawn`)
		return
	end
	local points = anchors(host, template)
	if #points == 0 then
		return
	end
	destroyWreck()
	local point = points[math.random(1, #points)]
	pinParts(template)
	local clone = template:Clone()
	clone.Name = "PitWreck"
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanTouch = false
		end
	end
	if clone:IsA("Folder") then
		local wrapped = Instance.new("Model")
		wrapped.Name = "PitWreck"
		for _, child in clone:GetChildren() do
			child.Parent = wrapped
		end
		clone:Destroy()
		clone = wrapped
	end
	if clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanTouch = false
		local wrapped = Instance.new("Model")
		wrapped.Name = "PitWreck"
		clone.Parent = wrapped
		wrapped.PrimaryPart = clone
		clone = wrapped
	end
	if not clone:IsA("Model") then
		clone:Destroy()
		return
	end
	if clone:IsA("Model") then
		local mesh = clone:FindFirstChildWhichIsA("BasePart", true)
		if mesh and mesh:IsA("BasePart") then
			clone.PrimaryPart = mesh
		end
	end
	clone.Parent = parent
	local scaled, scaleError = pcall(fitLandmark, clone)
	if not scaled then
		warn(`[WreckService] ScaleTo failed: {scaleError}`)
	end
	standOn(clone, point)
	solidify(clone)
	wreck = clone
	groundAt = point
	dying = false
	shielded = false
	chippedSinceShield = 0
	shieldReadyAt = 0
	integrityMax = integrityOverride or wreckConfig.Integrity
	integrity = integrityMax
	contributions = {}
	CollectionService:AddTag(clone, "PitWreck")
	attachBillboard(clone, point)
	ejectOverlappingPlayers(clone)
	local function restAnd()
		if dying then
			return
		end
		local model = wreck
		local ground = groundAt
		if model == nil or ground == nil then
			return
		end
		fitLandmark(model)
		standOn(model, ground)
		solidify(model)
		placeHpAnchor(model, ground)
		ejectOverlappingPlayers(model)
	end
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("MeshPart") then
			descendant:GetPropertyChangedSignal("Size"):Connect(restAnd)
		end
	end
	task.defer(restAnd)
	local at = clone:GetPivot().Position
	print(
		`[WreckService] spawned from {template.Name} at `
			.. `{string.format("%.0f, %.0f, %.0f", at.X, at.Y, at.Z)}`
	)
end

local function distanceToBox(point: Vector3, cf: CFrame, size: Vector3): number
	local localPoint = cf:PointToObjectSpace(point)
	local half = size / 2
	local dx = math.max(math.abs(localPoint.X) - half.X, 0)
	local dy = math.max(math.abs(localPoint.Y) - half.Y, 0)
	local dz = math.max(math.abs(localPoint.Z) - half.Z, 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function nearWreck(player: Player, root: Vector3, boxCf: CFrame, boxSize: Vector3): boolean
	local stats = PlayerStateService.GetDerivedStats(player)
	if stats == nil then
		return false
	end
	return distanceToBox(root, boxCf, boxSize) <= stats.MagnetRange
end

local function notifyPit(message: string)
	local host = area
	if host == nil then
		return
	end
	local cf, size = host:GetBoundingBox()
	local remote = RemoteService.GetEvent("Notify")
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") and ArenaConfig.containsPoint(root.Position, cf, size) then
			remote:FireClient(player, message)
		end
	end
end

local function scrapPads(): { BasePart }
	local host = area
	if host == nil then
		return {}
	end
	local spawnFolder = host:FindFirstChild(ArenaConfig.ScrapSpawnFolderName)
	if spawnFolder == nil then
		return {}
	end
	local pads = {}
	for _, child in spawnFolder:GetChildren() do
		if child:IsA("BasePart") then
			if child.Name ~= wreckConfig.AnchorName and child.Name ~= "Wreck" then
				table.insert(pads, child)
			end
		elseif child:IsA("Model") then
			if child.Name ~= wreckConfig.AnchorName and child.Name ~= "Wreck" then
				local part = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart", true)
				if part and part:IsA("BasePart") then
					table.insert(pads, part)
				end
			end
		end
	end
	return pads
end

local function pickPad(): BasePart?
	local origin = groundAt
	local model = wreck
	if origin == nil and model then
		origin = model:GetPivot().Position
	end
	if origin == nil then
		return nil
	end
	local minD = wreckConfig.NodeMinStuds
	local maxD = wreckConfig.NodeMaxStuds
	local inRange = {}
	local any = {}
	for _, pad in scrapPads() do
		table.insert(any, pad)
		local delta = Vector3.new(pad.Position.X - origin.X, 0, pad.Position.Z - origin.Z)
		local distance = delta.Magnitude
		if distance >= minD and distance <= maxD then
			table.insert(inRange, pad)
		end
	end
	local pool = if #inRange > 0 then inRange else any
	if #pool == 0 then
		return nil
	end
	local filtered = {}
	for _, pad in pool do
		if pad ~= lastOverloadPad then
			table.insert(filtered, pad)
		end
	end
	if #filtered > 0 then
		pool = filtered
	end
	return pool[math.random(1, #pool)]
end

local function createOverload(pad: BasePart)
	local parent = folder
	if parent == nil then
		return
	end
	local existing = overload
	if existing then
		existing:Destroy()
		overload = nil
	end
	local padTop = pad.Position + Vector3.new(0, pad.Size.Y / 2, 0)
	local height = 14
	local width = 3.2
	local model = Instance.new("Model")
	model.Name = "WreckOverload"

	local pillar = Instance.new("Part")
	pillar.Name = "Beacon"
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanTouch = false
	pillar.CanQuery = true
	pillar.Material = Enum.Material.Neon
	pillar.Color = Color3.fromRGB(33, 229, 245)
	pillar.Transparency = 0.12
	pillar.Size = Vector3.new(width, height, width)
	pillar.CFrame = CFrame.new(padTop + Vector3.new(0, height / 2, 0))
	pillar.Parent = model
	model.PrimaryPart = pillar

	local disc = Instance.new("Part")
	disc.Name = "Disc"
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanTouch = false
	disc.CanQuery = false
	disc.Material = Enum.Material.Neon
	disc.Color = Color3.fromRGB(33, 229, 245)
	disc.Transparency = 0.35
	disc.Size = Vector3.new(7.5, 0.35, 7.5)
	disc.CFrame = CFrame.new(padTop + Vector3.new(0, 0.2, 0))
	disc.Parent = model

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(33, 229, 245)
	light.Brightness = 3.2
	light.Range = 26
	light.Parent = pillar

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(180, 255, 255), Color3.fromRGB(33, 229, 245))
	sparks.LightEmission = 0.9
	sparks.LightInfluence = 0
	sparks.Lifetime = NumberRange.new(0.25, 0.7)
	sparks.Rate = 28
	sparks.Speed = NumberRange.new(2, 8)
	sparks.SpreadAngle = Vector2.new(40, 40)
	sparks.Acceleration = Vector3.new(0, 12, 0)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Parent = pillar

	local gui = Instance.new("BillboardGui")
	gui.Name = "OverloadLabel"
	gui.Size = UDim2.fromScale(7, 1.8)
	gui.StudsOffset = Vector3.new(0, height / 2 + 1.4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 0
	gui.LightInfluence = 0
	gui.Adornee = pillar
	gui.Parent = model
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.Text = "OVERLOAD"
	text.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(12, 40, 48)
	stroke.Parent = text

	model.Parent = parent
	overload = model
	overloadSpawnedAt = os.clock()
	lastOverloadPad = pad
end

clearShield = function(shouldBurst: boolean)
	local node = overload
	local nodePosition = if node then node:GetPivot().Position else nil
	if node then
		node:Destroy()
	end
	overload = nil
	local model = wreck
	if model then
		local highlight = model:FindFirstChild("WreckShield")
		if highlight then
			highlight:Destroy()
		end
		local field = model:FindFirstChild("WreckShieldField")
		if field then
			field:Destroy()
		end
	end
	if shouldBurst then
		local wreckPos = groundAt
		if wreckPos == nil and model then
			wreckPos = model:GetPivot().Position
		end
		if wreckPos then
			spillBurst(wreckPos, wreckConfig.ShieldBurstCount)
		end
		if nodePosition then
			spillBurst(nodePosition, wreckConfig.NodeBurstCount)
		end
	end
	local wasShielded = shielded
	shielded = false
	if wasShielded then
		setBar()
	end
end

local function raiseShield()
	local model = wreck
	if model == nil or dying or shielded then
		return
	end
	local pad = pickPad()
	if pad == nil then
		warn("[WreckService] no Pit scrap pad for the overload node -- shield skipped")
		return
	end
	shielded = true
	chippedSinceShield = 0
	local highlight = Instance.new("Highlight")
	highlight.Name = "WreckShield"
	highlight.FillColor = Color3.fromRGB(33, 229, 245)
	highlight.OutlineColor = Color3.fromRGB(180, 255, 255)
	highlight.FillTransparency = 0.62
	highlight.OutlineTransparency = 0.15
	highlight.Parent = model
	local field = Instance.new("ForceField")
	field.Name = "WreckShieldField"
	field.Visible = true
	field.Parent = model
	createOverload(pad)
	setBar()
	notifyPit("SHIELD UP -- magnet the glowing OVERLOAD")
end

local function dropShield()
	if not shielded then
		return
	end
	clearShield(true)
	chippedSinceShield = 0
	shieldReadyAt = os.clock() + wreckConfig.ShieldCooldownSeconds
	notifyPit("SHIELD DOWN -- keep chipping")
end

local function relocateOverload()
	local pad = pickPad()
	if pad == nil then
		return
	end
	createOverload(pad)
end

local function tickOverload()
	local node = overload
	if node == nil or node.PrimaryPart == nil then
		if shielded then
			local pad = pickPad()
			if pad then
				createOverload(pad)
			end
		end
		return
	end
	local boxCf, boxSize = node:GetBoundingBox()
	for _, player in Players:GetPlayers() do
		if PlayerStateService.CanChipWreck(player) then
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if
				root
				and root:IsA("BasePart")
				and nearWreck(player, root.Position, boxCf, boxSize)
			then
				dropShield()
				return
			end
		end
	end
	if os.clock() - overloadSpawnedAt >= wreckConfig.NodeRelocateSeconds then
		relocateOverload()
	end
end

local function chip()
	local model = wreck
	if model == nil or dying or integrity <= 0 or shielded then
		return
	end
	local boxCf, boxSize = model:GetBoundingBox()
	local origin = boxCf.Position
	local chipAmount = wreckConfig.ChipPerSecond * wreckConfig.TickSeconds
	local removed = 0
	for _, player in Players:GetPlayers() do
		if PlayerStateService.CanChipWreck(player) then
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if
				root
				and root:IsA("BasePart")
				and nearWreck(player, root.Position, boxCf, boxSize)
			then
				integrity = math.max(0, integrity - chipAmount)
				removed += chipAmount
				contributions[player.UserId] = (contributions[player.UserId] or 0) + chipAmount
			end
		end
	end
	if removed > 0 then
		chippedSinceShield += removed
		setBar()
	end
	if integrity <= 0 then
		payContributors()
		beginBreakdown(model, groundAt or origin)
		return
	end
	if
		os.clock() >= shieldReadyAt
		and chippedSinceShield >= wreckConfig.ShieldEveryIntegrity
		and integrity > wreckConfig.ShieldSkipBelow
	then
		raiseShield()
	end
end

function WreckService.Open(host: Model)
	area = host
	retriedTemplate = false
	local leftover = host:FindFirstChild("PitWrecksLive")
	if leftover then
		leftover:Destroy()
	end
	local live = Instance.new("Folder")
	live.Name = "PitWrecksLive"
	live.Parent = host
	folder = live
	respawnAt = 0
	WreckService.PinTemplate()
	spawnWreck()
end

function WreckService.SetIntegrity(hp: number): string
	local clamped = math.floor(math.clamp(hp, 1, AdminConfig.MaximumWreckHp))
	integrityOverride = clamped
	integrityMax = clamped
	if wreck ~= nil and not dying then
		integrity = clamped
		setBar()
		return `wreck HP set to {clamped}`
	end
	return `next wreck will spawn at {clamped} HP`
end

function WreckService.Close()
	destroyWreck()
	local live = folder
	if live then
		live:Destroy()
	end
	folder = nil
	area = nil
	contributions = {}
	respawnAt = 0
	retriedTemplate = false
	shielded = false
	chippedSinceShield = 0
	shieldReadyAt = 0
	lastOverloadPad = nil
end

function WreckService.PinTemplate()
	--[[
		RobotWreck is an imported MeshPart and ships Unanchored. The first physics
		step drops it through the floor, then Open finds nothing. Submarine never
		did this: adopted scrap is anchored in ServerStorage. Pin as soon as this
		module loads -- ArenaService requires us during its own require, before
		ArenaService.Start can Open.
	]]
	local found: Instance? = nil
	for _, name in wreckConfig.ModelNames do
		local direct = Workspace:FindFirstChild(name)
		if direct then
			found = unwrap(direct)
			if found then
				break
			end
		end
	end
	if found == nil then
		local spaced = Workspace:FindFirstChild("Robot Wreck")
		if spaced then
			found = unwrap(spaced)
		end
	end
	if found == nil then
		found = findWreckAsset()
	end
	if found == nil then
		return
	end
	pinParts(found)
	if ServerStorage:FindFirstChild(STORED_TEMPLATE_NAME) == nil then
		local copy = found:Clone()
		copy.Name = STORED_TEMPLATE_NAME
		pinParts(copy)
		copy.Parent = ServerStorage
	end
end

function WreckService.Start()
	if started then
		return
	end
	started = true
	WreckService.PinTemplate()
	task.spawn(function()
		while true do
			task.wait(wreckConfig.TickSeconds)
			if area == nil then
				continue
			end
			if wreck == nil then
				if respawnAt > 0 and os.clock() >= respawnAt then
					respawnAt = 0
					spawnWreck()
				end
			elseif not dying then
				if shielded then
					tickOverload()
				else
					chip()
				end
			end
		end
	end)
end

-- ArenaService requires this module during its own require, which is the earliest
-- server Lua runs. Pin then, before the first physics step can void the mesh.
WreckService.PinTemplate()

return table.freeze(WreckService)
