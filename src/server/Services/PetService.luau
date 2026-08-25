--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local EggPodiums = require(ReplicatedStorage.Shared.Utility.EggPodiums)
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
	Egg folder names in Studio do not always match `DisplayName`.

	Junkyard is `Junkyard Egg`. Workshop and Quantum were saved as `WorkshopEgg` /
	`QuantumEgg` -- the egg id with no space -- so looking up only the display name
	never found them, and those eggs published placeholders.
]]
local function findEggFolder(sourceFolder: Instance, eggId: string): Instance?
	local egg = PetConfig.Eggs[eggId]
	local candidates = {
		egg.DisplayName,
		egg.Id,
		egg.ModelName,
		(string.gsub(egg.DisplayName, " ", "")),
	}
	for _, name in candidates do
		local found = sourceFolder:FindFirstChild(name)
		if found then
			return found
		end
	end
	return nil
end

local function asEggModel(source: Instance, eggId: string): Model
	local model: Model
	if source:IsA("Model") then
		model = source:Clone()
		model.Name = eggId
	else
		model = Instance.new("Model")
		model.Name = eggId
		local part = source:Clone()
		part.Parent = model
		if part:IsA("BasePart") then
			model.PrimaryPart = part
		end
	end
	local junk = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("ProximityPrompt") then
			table.insert(junk, descendant)
		end
	end
	for _, descendant in junk do
		descendant:Destroy()
	end
	return model
end

--[[
	Publishes one model per egg into `ReplicatedStorage.EggModels`, keyed by egg id
	so the client can render it in a ViewportFrame without reaching into Workspace.

	Podium meshes on FeaturedPodium win: those are the eggs the player is standing
	in front of. `Workspace.Pets/<egg>/Egg` is the old path. A placeholder is last.
]]
local function publishEggModels(sourceFolder: Instance?)
	local repository = ReplicatedStorage:FindFirstChild("EggModels") or Instance.new("Folder")
	repository.Name = "EggModels"
	repository.Parent = ReplicatedStorage

	local map = workspace:FindFirstChild("NewMap")
	if map then
		for _, site in EggPodiums.collect(map) do
			local tagged = site:GetAttribute("EggId")
			local eggId = if typeof(tagged) == "string"
				then tagged
				else EggPodiums.SiteEggIds[site.Name]
			if typeof(eggId) ~= "string" or PetConfig.Eggs[eggId] == nil then
				continue
			end
			if repository:FindFirstChild(eggId) then
				continue
			end
			local visual = EggPodiums.findVisualEgg(site)
			if visual == nil then
				continue
			end
			asEggModel(visual, eggId).Parent = repository
		end
	end

	for _, eggId in PetConfig.EggOrder do
		if repository:FindFirstChild(eggId) then
			continue
		end
		local definition = PetConfig.Eggs[eggId]
		local folder = if sourceFolder then findEggFolder(sourceFolder, eggId) else nil
		local authored = folder and folder:FindFirstChild("Egg")
		if authored and (authored:IsA("Model") or authored:IsA("BasePart")) then
			asEggModel(authored, eggId).Parent = repository
		else
			warn(
				`[Pets] No Egg model on the podium or in Workspace.Pets/{definition.DisplayName} - using a placeholder`
			)
			placeholderEgg(eggId).Parent = repository
		end
	end
end

local function findPremiumPodiumModel(definition: any): Model?
	local newMap = workspace:FindFirstChild("NewMap")
	local podium = newMap and newMap:FindFirstChild("FeaturedPodium")
	if podium == nil then
		return nil
	end
	local names = {
		definition.ModelName,
		definition.DisplayName,
		string.upper(definition.DisplayName),
	}
	for _, name in names do
		local found = podium:FindFirstChild(name, true)
		if found and found:IsA("Model") then
			return found
		end
	end
	return nil
end

local function publishClone(repository: Folder, source: Model, petId: string)
	if repository:FindFirstChild(petId) then
		return
	end
	local clone = source:Clone()
	clone.Name = petId
	clone.Parent = repository
end

--[[
	Publishes one model per pet into `ReplicatedStorage.PetModels`, keyed by pet id.

	Name match first (`ModelName`, then `DisplayName`), then leftover models in each
	egg folder in roster order. Workshop and Quantum were renamed in Studio
	(Yin Yang, Fracture, ...) without matching config, and a recursive name lookup
	also cannot tell two models both called `Decore` apart. Slot order is what
	keeps those clones publishing after a rename.
]]
local function publishPetModels()
	local repository = ReplicatedStorage:FindFirstChild("PetModels") or Instance.new("Folder")
	repository.Name = "PetModels"
	repository.Parent = ReplicatedStorage
	local sourceFolder = workspace:FindFirstChild("Pets") or ServerStorage:FindFirstChild("Pets")
	if sourceFolder == nil then
		warn("[Pets] Add pet models beneath Workspace.Pets or ServerStorage.Pets")
		return
	end

	local claimed: { [Instance]: boolean } = {}

	--[[
		Hatchable pets come from Pets/. Premium pets do not -- Singularity used to
		live there, and that old model is now Sinister Lord's art. If we scan Pets
		for premium ids first, Singularity keeps publishing the old body.
	]]
	for petId, definition in PetConfig.Pets do
		if definition.Premium == true then
			continue
		end
		local source = sourceFolder:FindFirstChild(definition.ModelName, true)
			or sourceFolder:FindFirstChild(definition.DisplayName, true)
		if source and source:IsA("Model") and claimed[source] ~= true then
			claimed[source] = true
			publishClone(repository, source, petId)
		end
	end

	--[[
		Premium models sit on FeaturedPodium, one placeholder each:

		  Singularity Placeholder / Featured Pet / Singularity
		  Scrap Chrimson Knight Placeholder / Featured Pet / Scrap Chrimson Knight
		  Sinister Lord Placeholder / Featured Pet / SINISTER LORD

		Clone only. Do not move or destroy the podium original. Pets.Singularity is
		the old body and is left unused on purpose.
	]]
	for petId, definition in PetConfig.Pets do
		if repository:FindFirstChild(petId) or definition.Premium ~= true then
			continue
		end
		local source = findPremiumPodiumModel(definition)
		if source and claimed[source] ~= true then
			claimed[source] = true
			publishClone(repository, source, petId)
		else
			warn(
				`[Pets] No model for premium pet {petId} (tried {definition.ModelName} / {definition.DisplayName})`
			)
		end
	end

	for _, eggId in PetConfig.EggOrder do
		local egg = PetConfig.Eggs[eggId]
		local folder = findEggFolder(sourceFolder, eggId)
		if folder == nil then
			warn(`[Pets] No folder for {eggId} under Pets (tried {egg.DisplayName} / {egg.Id})`)
			continue
		end
		local unused = {}
		for _, child in folder:GetChildren() do
			if child:IsA("Model") and child.Name ~= "Egg" and claimed[child] ~= true then
				table.insert(unused, child)
			end
		end
		local nextUnused = 1
		for _, petId in egg.PetIds do
			if repository:FindFirstChild(petId) then
				continue
			end
			local source = unused[nextUnused]
			nextUnused += 1
			if source and source:IsA("Model") then
				claimed[source] = true
				publishClone(repository, source, petId)
			else
				warn(`[Pets] No model for {petId} in Pets/{folder.Name}`)
			end
		end
	end

	publishEggModels(sourceFolder)
	if sourceFolder.Parent == workspace then
		sourceFolder.Parent = ServerStorage
	end
end

--[[
	Which egg a site sells.

	An explicit `EggId` attribute or StringValue wins. Folder names on
	`FeaturedPodium.EggSummonPodium` map through `EggPodiums.SiteEggIds`. Otherwise
	the instance name is matched against the egg id, its required area, or its
	display name. Unlabelled leftover podiums still fall back to the starter egg.
]]
local function resolveEggId(site: Instance): string
	local node: Instance? = site
	while node ~= nil and node ~= workspace do
		local value = node:FindFirstChild("EggId")
		local eggId = if value and value:IsA("StringValue")
			then value.Value
			else node:GetAttribute("EggId")
		if typeof(eggId) == "string" and PetConfig.Eggs[eggId] ~= nil then
			return eggId
		end
		local mapped = EggPodiums.SiteEggIds[node.Name]
		if mapped ~= nil then
			return mapped
		end
		local lowered = string.lower(node.Name)
		for _, candidate in PetConfig.EggOrder do
			local egg = PetConfig.Eggs[candidate]
			if
				string.find(lowered, string.lower(egg.Id), 1, true)
				or string.find(lowered, string.lower(egg.RequiredArea), 1, true)
				or string.find(
					lowered,
					string.lower((string.gsub(egg.DisplayName, " ", ""))),
					1,
					true
				)
			then
				return candidate
			end
		end
		node = node.Parent
	end
	return PetConfig.EggOrder[1]
end

--[[
	Wires a hold-E prompt onto every egg site in the map.

	The prompt is created here rather than authored, because the podium is map
	geometry and this is behaviour. Each `<Area>EggGroup` is its own site, so three
	eggs get three prompts. Binding only `EggSummonPodium` put one prompt on the
	tallest egg and opened the starter roster no matter which model you were facing.
]]
local function worldAabb(parts: { BasePart }): (Vector3?, Vector3?)
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = Vector3.new(-math.huge, -math.huge, -math.huge)
	local any = false
	for _, part in parts do
		any = true
		local half = part.Size * 0.5
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local corner = part.CFrame:PointToWorldSpace(
						Vector3.new(half.X * x, half.Y * y, half.Z * z)
					)
					min = min:Min(corner)
					max = max:Max(corner)
				end
			end
		end
	end
	if not any then
		return nil, nil
	end
	return min, max
end

--[[
	Invisible volume the prompt lives on, bigger than the egg itself.

	The prompt used to parent to the site's highest part -- often a tiny mesh at the
	top of a tall egg -- so MaxActivationDistance was measured from over your head
	and you had to walk into the model. A padded hitbox at the egg's centre is the
	reach players expect.
]]
local function ensureSummonHitbox(site: Instance): BasePart?
	local existing = site:FindFirstChild("SummonHitbox")
	if existing and existing:IsA("BasePart") then
		existing:Destroy()
	end

	local parts = {}
	if site:IsA("BasePart") then
		table.insert(parts, site)
	end
	for _, descendant in site:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "SummonHitbox" then
			table.insert(parts, descendant)
		end
	end
	local min, max = worldAabb(parts)
	if min == nil or max == nil then
		return nil
	end

	local size = max - min
	local pad = Vector3.new(10, 4, 10)
	local hitbox = Instance.new("Part")
	hitbox.Name = "SummonHitbox"
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanQuery = false
	hitbox.CanTouch = false
	hitbox.Massless = true
	hitbox.Transparency = 1
	hitbox.Size = Vector3.new(math.max(size.X, 6), math.max(size.Y, 8), math.max(size.Z, 6)) + pad
	hitbox.CFrame = CFrame.new((min + max) * 0.5)
	hitbox.Parent = site
	return hitbox
end

--[[
	Podium signs are Studio-authored ("Junkyard Egg", "Quantum Egg") and do not
	read `PetConfig`. Rewrite any egg-title label under the site, and the prompt.
]]
local function relabelEggSite(site: Instance, displayName: string)
	for _, descendant in site:GetDescendants() do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			local lowered = string.lower(descendant.Text)
			if string.find(lowered, "egg", 1, true) then
				descendant.Text = displayName
			end
		elseif descendant:IsA("ProximityPrompt") then
			descendant.ObjectText = displayName
		end
	end
end

local function bindSummonPodiums()
	local map = workspace:WaitForChild("NewMap", 20)
	if map == nil then
		warn("[Pets] Workspace.NewMap never appeared - no egg podiums bound")
		return
	end

	local bound = 0
	for _, site in EggPodiums.collect(map) do
		for _, descendant in site:GetDescendants() do
			if descendant:IsA("ProximityPrompt") then
				descendant:Destroy()
			end
		end

		local anchor = ensureSummonHitbox(site)
		if anchor == nil then
			continue
		end

		local eggId = resolveEggId(site)
		local displayName = PetConfig.Eggs[eggId].DisplayName
		relabelEggSite(site, displayName)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SummonPrompt"
		prompt.ObjectText = displayName
		prompt.ActionText = "Summon Egg"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 18
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = anchor

		prompt.Triggered:Connect(function(player)
			RemoteService.GetEvent("OpenEggSummon"):FireClient(player, eggId)
		end)
		bound += 1
	end

	--[[
		Signs sometimes sit beside the group rather than inside it. Catch leftover
		"Junkyard Egg" / "Quantum Egg" labels anywhere under NewMap.
	]]
	for _, descendant in map:GetDescendants() do
		if not (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) then
			continue
		end
		local lowered = string.lower(descendant.Text)
		if string.find(lowered, "egg", 1, true) == nil then
			continue
		end
		if string.find(lowered, "junkyard", 1, true) then
			descendant.Text = PetConfig.Eggs.JunkyardEgg.DisplayName
		elseif string.find(lowered, "quantum", 1, true) then
			descendant.Text = PetConfig.Eggs.QuantumEgg.DisplayName
		end
	end

	if bound == 0 then
		warn(
			"[Pets] No egg sites found in Workspace.NewMap. Put FrontYardEggGroup / WorkshopYardEggGroup / VehicleGraveyardEggGroup under FeaturedPodium.EggSummonPodium."
		)
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
			--- `count` is how many copies of this pet to drop; the screen's bulk delete uses it.
			local copies = if typeof(count) == "number" then math.floor(count) else 1
			success, message = PlayerStateService.TryDeletePet(player, targetId, copies)
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
					--- So the VFX can find the right character: display names are not unique.
					UserId = player.UserId,
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
