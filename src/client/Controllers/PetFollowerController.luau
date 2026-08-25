--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local PetModelPose = require(ReplicatedStorage.Shared.Utility.PetModelPose)

local PetFollowerController = {}
local followers: { [Player]: { Model } } = {}
local connections: { [Player]: RBXScriptConnection } = {}
local faceRotations: { [Model]: CFrame } = {}
local hoverOffsets: { [Model]: Vector3 } = {}

local function prepare(model: Model, petId: string)
	PetModelPose.stripStudioFx(model)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.Massless = true
		end
	end
	--[[
		Scaled to a target size along the longest STANDING axis.

		`GetExtentsSize` is in pivot space. Pup is stored upside down with a
		different pivot from the other Junkyard pets, so that box was nothing like
		the pet you actually see -- it came out the wrong size AND on its head.
		`PetModelPose` stands it up using `AnimatedFace` first, then we measure.

		The target is `PetConfig.FollowerLongestAxis` with an optional per-pet
		multiplier from `PetConfig.FollowerScale`. Pass the pet id, not `model.Name`:
		followers are renamed `{player}_{id}_{index}` before this runs, so looking
		up by the instance name never hit the table.
	]]
	local faceRotation = PetModelPose.faceRotationInPivot(model)
	faceRotations[model] = faceRotation
	local size = PetModelPose.standingExtents(model, faceRotation)
	local largest = math.max(size.X, size.Y, size.Z)
	if largest <= 0 then
		hoverOffsets[model] = Vector3.zero
		return
	end

	local multiplier = PetConfig.FollowerScale[petId] or 1
	local target = PetConfig.FollowerLongestAxis * multiplier
	model:ScaleTo(model:GetScale() * target / largest)
	hoverOffsets[model] = PetModelPose.hoverLocalOffset(model, faceRotation)
end

local function fallbackModel(petId: string): Model
	local definition = PetConfig.Pets[petId]
	local model = Instance.new("Model")
	model.Name = petId
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(2.4, 2.1, 2.4)
	body.Material = Enum.Material.SmoothPlastic
	body.Color = definition.FallbackColor
	body.Parent = model
	local face = Instance.new("Part")
	face.Name = "Face"
	face.Shape = Enum.PartType.Ball
	face.Size = Vector3.new(1.75, 1.55, 1.55)
	face.Color = definition.FallbackColor:Lerp(Color3.new(1, 1, 1), 0.18)
	face.CFrame = body.CFrame * CFrame.new(0, 0.4, -1.25)
	face.Parent = model
	model.PrimaryPart = body
	return model
end

local function clear(player: Player)
	local existing = followers[player]
	if existing then
		for _, model in existing do
			faceRotations[model] = nil
			hoverOffsets[model] = nil
			model:Destroy()
		end
	end
	followers[player] = nil
end

local function rebuild(player: Player)
	clear(player)
	local encoded = player:GetAttribute("EquippedPets")
	if typeof(encoded) ~= "string" then
		return
	end
	local ok, ids = pcall(HttpService.JSONDecode, HttpService, encoded)
	if not ok or typeof(ids) ~= "table" then
		return
	end
	local repository = ReplicatedStorage:FindFirstChild("PetModels")
	local models = {}
	for index, petId in ids do
		local definition = if typeof(petId) == "string" then PetConfig.Pets[petId] else nil
		if definition then
			--[[
				KEYED BY PET ID, NOT BY `ModelName`.

				`PetService.publishPetModels` finds each source model by its `ModelName` and then renames the
				clone to the PET ID -- so the repository's children are ids. Looking up by `ModelName` here
				therefore only found the pets whose two names happen to be identical, and every pet whose
				model name has a space in it silently fell back to the placeholder ball:

					QueenKitty          "Queen Kitty"
					PastelAngel         "Pastel Angel"
					AutumnDragon        "Autumn Dragon"
					MythicAutumnDragon  "Mythic Autumn Dragon"

				Which is why equipping those four gave you coloured balloons while their cards -- which ask
				`ModelView` for the same models BY ID -- looked right.

				`ModelName` is kept as a fallback so a repository populated by hand, under the source names,
				still resolves.
			]]
			local source = if repository
				then repository:FindFirstChild(petId) or repository:FindFirstChild(
					definition.ModelName
				)
				else nil
			local model = if source and source:IsA("Model")
				then source:Clone()
				else fallbackModel(petId)
			model.Name = `{player.Name}_{petId}_{index}`
			model:SetAttribute("PetFollower", true)
			local prepared, prepareError = pcall(prepare, model, petId)
			if not prepared then
				warn(`[PetFollower] {petId} pose/scale failed: {prepareError}`)
			end
			if definition.Premium then
				--[[
					Outline only. A filled Highlight is a wash over every part, which is
					why premium pets (and any authored Highlight cloned off the model)
					looked red or pink instead of their own colours.
				]]
				local glow = Instance.new("Highlight")
				glow.Name = "PremiumGlow"
				glow.FillTransparency = 1
				glow.OutlineColor = definition.FallbackColor
				glow.OutlineTransparency = 0.35
				glow.DepthMode = Enum.HighlightDepthMode.Occluded
				glow.Parent = model
			end
			model.Parent = workspace
			table.insert(models, model)
		end
	end
	followers[player] = models
end

local function watch(player: Player)
	if connections[player] then
		connections[player]:Disconnect()
	end
	connections[player] = player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

function PetFollowerController.Start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		clear(player)
		if connections[player] then
			connections[player]:Disconnect()
			connections[player] = nil
		end
	end)
	RunService.RenderStepped:Connect(function(deltaTime)
		local now = os.clock()
		for player, models in followers do
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if not root or not root:IsA("BasePart") then
				continue
			end
			local count = #models
			for index, model in models do
				local column = index - (count + 1) / 2
				local row = math.floor((index - 1) / 3)
				local side = column * 2.65
				local behind = 4.8 + row * 2.3 + math.abs(column) * 0.25
				local bob = math.sin(now * 2.4 + index * 0.9) * 0.28
				local position = root.Position
					+ root.CFrame.RightVector * side
					- root.CFrame.LookVector * behind
					+ Vector3.new(0, 1.9 + bob, 0)
				local target = PetModelPose.worldPivot(
					model,
					position,
					root.CFrame.LookVector,
					faceRotations[model]
				)
				local hoverOffset = hoverOffsets[model]
				if hoverOffset then
					target = target * CFrame.new(-hoverOffset)
				end
				local current = model:GetPivot()
				model:PivotTo(current:Lerp(target, math.clamp(12 * deltaTime, 0, 1)))
			end
		end
	end)
end

return table.freeze(PetFollowerController)
