--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)

local PetFollowerController = {}
local followers: { [Player]: { Model } } = {}
local connections: { [Player]: RBXScriptConnection } = {}

local function prepare(model: Model)
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
		Scaled to a target size along the longest axis, so pets of wildly different
		proportions all read as the same "pet sized" thing behind the player.

		The target is `PetConfig.FollowerLongestAxis` with an optional per-pet
		multiplier from `PetConfig.FollowerScale` -- a long dragon looks enormous at
		the same longest-axis size that suits a compact pup. Both are config, so
		tuning this needs no code change.

		Unlike the old version this scales *down or up*: it used to only shrink
		models already larger than the target, which left small ones untouched and
		inconsistent.
	]]
	local size = model:GetExtentsSize()
	local largest = math.max(size.X, size.Y, size.Z)
	if largest <= 0 then
		return
	end

	local multiplier = PetConfig.FollowerScale[model.Name] or 1
	local target = PetConfig.FollowerLongestAxis * multiplier
	model:ScaleTo(model:GetScale() * target / largest)
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
			local source = if repository
				then repository:FindFirstChild(definition.ModelName)
				else nil
			local model = if source and source:IsA("Model")
				then source:Clone()
				else fallbackModel(petId)
			model.Name = `{player.Name}_{petId}_{index}`
			model:SetAttribute("PetFollower", true)
			prepare(model)
			if definition.Premium then
				local glow = Instance.new("Highlight")
				glow.Name = "PremiumGlow"
				glow.FillColor = definition.FallbackColor
				glow.FillTransparency = 0.55
				glow.OutlineColor = Color3.new(1, 1, 1)
				glow.OutlineTransparency = 0.15
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
				local target = CFrame.lookAt(position, position + root.CFrame.LookVector)
				local current = model:GetPivot()
				model:PivotTo(current:Lerp(target, math.clamp(12 * deltaTime, 0, 1)))
			end
		end
	end)
end

return table.freeze(PetFollowerController)
