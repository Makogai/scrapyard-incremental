--!strict
--[[
	EggPodiums.luau
	Where in the map a player can hold E to open an egg.

	Authored path:

		Workspace.NewMap.FeaturedPodium.EggSummonPodium
		  FrontYardEggGroup          JunkyardEgg / Front Yard Egg
		  WorkshopYardEggGroup       WorkshopEgg
		  VehicleGraveyardEggGroup   QuantumEgg / Vehicle Graveyard Egg

	A leftover group sitting anywhere else under NewMap still counts. The podium
	model itself is not a site when it contains groups -- otherwise one prompt
	on the tallest egg would open the starter roster for every mesh.
]]

local EggPodiums = {}

--[[
	Folder name -> egg id. `WorkshopGraveyardEggGroup` is a Studio typo for the
	Workshop yard; keep the alias so an unsaved place still binds the right egg.
]]
EggPodiums.SiteEggIds = table.freeze({
	FrontYardEggGroup = "JunkyardEgg",
	WorkshopYardEggGroup = "WorkshopEgg",
	WorkshopGraveyardEggGroup = "WorkshopEgg",
	VehicleGraveyardEggGroup = "QuantumEgg",
} :: { [string]: string })

local NOT_THE_EGG = { "stand", "group", "base", "podium", "plinth", "pedestal", "hitbox", "prompt" }

local function isEggGroup(instance: Instance): boolean
	return string.find(string.lower(instance.Name), "egggroup", 1, true) ~= nil
end

local function ancestorIsEggGroup(instance: Instance, map: Instance): boolean
	local parent = instance.Parent
	while parent ~= nil and parent ~= map do
		if isEggGroup(parent) then
			return true
		end
		parent = parent.Parent
	end
	return false
end

local function looksLikeTheEgg(name: string): boolean
	local lowered = string.lower(name)
	if not string.find(lowered, "egg", 1, true) then
		return false
	end
	for _, banned in NOT_THE_EGG do
		if string.find(lowered, banned, 1, true) then
			return false
		end
	end
	return true
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

--[[
	Every distinct summon site under `map`.

	Egg groups first; a leftover `EggSummonPodium` is only used when it is not
	inside a group and does not itself contain groups.
]]
function EggPodiums.collect(map: Instance): { Instance }
	local groups = {}
	local podiums = {}
	for _, instance in map:GetDescendants() do
		if isEggGroup(instance) then
			table.insert(groups, instance)
		elseif instance:IsA("Model") and instance.Name == "EggSummonPodium" then
			table.insert(podiums, instance)
		end
	end

	local sites = table.clone(groups)
	for _, podium in podiums do
		if ancestorIsEggGroup(podium, map) then
			continue
		end
		local hasGroupChild = false
		for _, child in podium:GetChildren() do
			if isEggGroup(child) then
				hasGroupChild = true
				break
			end
		end
		if not hasGroupChild then
			table.insert(sites, podium)
		end
	end
	return sites
end

--[[
	The egg mesh inside a site: a child named like an egg, else the largest model.
	Used by the hologram and by publishing clones into ReplicatedStorage.EggModels.
]]
function EggPodiums.findVisualEgg(root: Instance): Instance?
	for _, child in root:GetChildren() do
		if (child:IsA("Model") or child:IsA("BasePart")) and looksLikeTheEgg(child.Name) then
			return child
		end
	end

	local best: Instance? = nil
	local bestVolume = 0
	for _, child in root:GetChildren() do
		if not (child:IsA("Model") or child:IsA("BasePart")) then
			continue
		end
		local lowered = string.lower(child.Name)
		local banned = false
		for _, name in NOT_THE_EGG do
			if string.find(lowered, name, 1, true) then
				banned = true
				break
			end
		end
		if banned then
			continue
		end
		local parts = partsOf(child)
		if #parts == 0 then
			continue
		end
		local min, max = worldBounds(parts)
		local size = max - min
		local volume = size.X * size.Y * size.Z
		if volume > bestVolume then
			best = child
			bestVolume = volume
		end
	end
	return best
end

return table.freeze(EggPodiums)
