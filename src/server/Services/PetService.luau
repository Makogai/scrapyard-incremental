--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RemoteService = require(script.Parent.RemoteService)

local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)

local PetService = {}
local limiter = RateLimiter.new(8, Environment.RemoteRateLimitWindowSeconds)

--[[
	Egg models live beside their pets: `Workspace.Pets/<Egg DisplayName>/Egg`. That
	keeps one folder per egg holding everything it needs, so adding an egg is a
	single drag rather than a config edit.

	Until an artist drops a real `Egg` in, a placeholder is generated so the summon
	flow is playable. It is a plain spheroid, deliberately ugly enough that nobody
	mistakes it for finished art.
]]
local function placeholderEgg(eggId: string): Model
	local model = Instance.new("Model")
	model.Name = eggId

	local shell = Instance.new("Part")
	shell.Name = "Shell"
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.new(3, 3.8, 3)
	shell.Color = Color3.fromRGB(226, 219, 198)
	shell.Material = Enum.Material.SmoothPlastic
	shell.Anchored = true
	shell.CanCollide = false
	shell.Parent = model

	local speckle = Instance.new("Part")
	speckle.Name = "Speckle"
	speckle.Shape = Enum.PartType.Ball
	speckle.Size = Vector3.new(1.1, 1.1, 1.1)
	speckle.Color = Color3.fromRGB(120, 158, 106)
	speckle.Material = Enum.Material.SmoothPlastic
	speckle.Anchored = true
	speckle.CanCollide = false
	speckle.CFrame = shell.CFrame * CFrame.new(0.7, 0.5, 1.1)
	speckle.Parent = model

	model.PrimaryPart = shell
	return model
end

--[[
	Publishes one model per egg into `ReplicatedStorage.EggModels`, keyed by egg id
	so the client can render it in a ViewportFrame without reaching into Workspace.
]]
local function publishEggModels(sourceFolder: Instance?)
	local repository = ReplicatedStorage:FindFirstChild("EggModels") or Instance.new("Folder")
	repository.Name = "EggModels"
	repository.Parent = ReplicatedStorage

	for _, eggId in PetConfig.EggOrder do
		if repository:FindFirstChild(eggId) then
			continue
		end
		local definition = PetConfig.Eggs[eggId]
		local folder = sourceFolder and sourceFolder:FindFirstChild(definition.DisplayName)
		local authored = folder and folder:FindFirstChild("Egg")
		if authored and authored:IsA("Model") then
			local clone = authored:Clone()
			clone.Name = eggId
			clone.Parent = repository
		else
			warn(
				`[Pets] No Egg model in Workspace.Pets/{definition.DisplayName} - using a placeholder`
			)
			placeholderEgg(eggId).Parent = repository
		end
	end
end

local function publishPetModels()
	local repository = ReplicatedStorage:FindFirstChild("PetModels") or Instance.new("Folder")
	repository.Name = "PetModels"
	repository.Parent = ReplicatedStorage
	local sourceFolder = workspace:FindFirstChild("Pets") or ServerStorage:FindFirstChild("Pets")
	if sourceFolder == nil then
		warn("[Pets] Add pet models beneath Workspace.Pets or ServerStorage.Pets")
		return
	end
	for petId, definition in PetConfig.Pets do
		local source = sourceFolder:FindFirstChild(definition.ModelName, true)
		if source and source:IsA("Model") and repository:FindFirstChild(petId) == nil then
			local clone = source:Clone()
			clone.Name = petId
			clone.Parent = repository
		end
	end
	publishEggModels(sourceFolder)
	if sourceFolder.Parent == workspace then
		sourceFolder.Parent = ServerStorage
	end
end

--[[
	Wires a hold-E prompt onto every egg podium in the map.

	The prompt is created here rather than authored, because the podium is map
	geometry and this is behaviour. A podium may carry an `EggId` StringValue or
	attribute to say which egg it summons; without one it sells the first egg in
	`EggOrder`, which is the starter.
]]
local function bindSummonPodiums()
	local map = workspace:WaitForChild("NewMap", 20)
	if map == nil then
		warn("[Pets] Workspace.NewMap never appeared - no egg podiums bound")
		return
	end

	local bound = 0
	for _, podium in map:GetDescendants() do
		if not podium:IsA("Model") or podium.Name ~= "EggSummonPodium" then
			continue
		end

		-- Highest part, so the prompt floats over the podium rather than inside it.
		local anchor: BasePart? = nil
		for _, part in podium:GetDescendants() do
			if part:IsA("BasePart") and (anchor == nil or part.Position.Y > anchor.Position.Y) then
				anchor = part
			end
		end
		if anchor == nil then
			continue
		end

		local eggIdValue = podium:FindFirstChild("EggId")
		local eggId = if eggIdValue and eggIdValue:IsA("StringValue")
			then eggIdValue.Value
			else podium:GetAttribute("EggId")
		if typeof(eggId) ~= "string" or PetConfig.Eggs[eggId] == nil then
			eggId = PetConfig.EggOrder[1]
		end

		local prompt = anchor:FindFirstChildWhichIsA("ProximityPrompt")
			or Instance.new("ProximityPrompt")
		prompt.Name = "SummonPrompt"
		prompt.ObjectText = PetConfig.Eggs[eggId].DisplayName
		prompt.ActionText = "Summon Egg"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = anchor

		prompt.Triggered:Connect(function(player)
			RemoteService.GetEvent("OpenEggSummon"):FireClient(player, eggId)
		end)
		bound += 1
	end

	if bound == 0 then
		warn("[Pets] No EggSummonPodium found in Workspace.NewMap")
	end
end

function PetService.Start()
	publishPetModels()
	local actionRemote = RemoteService.GetEvent("PetAction")
	local resultRemote = RemoteService.GetEvent("PetResult")
	actionRemote.OnServerEvent:Connect(function(player, action, targetId, count)
		if
			typeof(action) ~= "string"
			or typeof(targetId) ~= "string"
			or not limiter:Allow(tostring(player.UserId))
		then
			return
		end
		local success, message, petIds
		if action == "OpenEgg" then
			--[[
				`count` is the batch size and arrives from the client, so it is validated as a number here
				and validated as an ENTITLEMENT in `TryOpenEgg`. Anything unexpected falls back to one --
				the safe direction, since one is what every player is allowed.
			]]
			local batch = if typeof(count) == "number" then math.floor(count) else 1
			success, message, petIds = PlayerStateService.TryOpenEgg(player, targetId, batch)
		elseif action == "EquipPet" then
			success, message = PlayerStateService.TryEquipPet(player, targetId)
		elseif action == "UnequipPet" then
			success, message = PlayerStateService.TryUnequipPet(player, targetId)
		elseif action == "DeletePet" then
			success, message = PlayerStateService.TryDeletePet(player, targetId)
		elseif action == "BuyPetSlot" then
			success, message = PlayerStateService.TryBuyPetSlot(player)
		else
			return
		end
		--[[
			`PetResult` only. This used to fire `Notify` with the same text as well,
			which put every pet message on screen twice -- two identical warnings for
			one failed equip. The client turns this single result into one toast.
		]]
		--- The list, not one id: the reveal draws every pet the batch produced.
		resultRemote:FireClient(player, success, message, petIds)

		--[[
			A Secret hatch is the one pet event worth interrupting everyone for, so
			it goes out on `Announce` as well. The client decides how to draw it; the
			server only says what happened and to whom.
		]]
		if success and action == "OpenEgg" and petIds then
			--- Any Secret in the batch is worth the announcement, so the whole list is checked.
			local secretId = nil
			for _, candidate in petIds do
				local candidateDefinition = PetConfig.Pets[candidate]
				if candidateDefinition and candidateDefinition.Rarity == "Secret" then
					secretId = candidate
					break
				end
			end
			local petId = secretId
			local definition = if petId then PetConfig.Pets[petId] else nil
			if definition and definition.Rarity == "Secret" then
				RemoteService.GetEvent("Announce"):FireAllClients({
					Kind = "SecretPet",
					PlayerName = player.DisplayName,
					PetId = petId,
					PetName = definition.DisplayName,
					Rarity = definition.Rarity,
				})
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(tostring(player.UserId))
	end)
	task.spawn(function()
		local hatchery = workspace:WaitForChild("PetHatchery", 20)
		local prompt = hatchery and hatchery:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.Triggered:Connect(function(player)
				RemoteService.GetEvent("OpenPetShop"):FireClient(player)
			end)
		else
			warn("[Pets] Authored PetHatchery prompt is missing")
		end
	end)

	task.spawn(bindSummonPodiums)
end

return table.freeze(PetService)
