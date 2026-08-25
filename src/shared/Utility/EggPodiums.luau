--!strict
--[[
	EggPodiums.luau
	Where in the map a player can hold E to open an egg.

	Studio layout that used to work: one Model named `EggSummonPodium`, optionally
	with `<Area>EggGroup` children. The layout that actually shipped: the groups sit
	directly under `NewMap` (`FrontYardEggGroup`, `WorkshopYardEggGroup`,
	`VehicleGraveyardEggGroup`) and may or may not wrap a podium.

	Both are sites. A group is preferred over a podium that contains it, so three
	eggs get three prompts instead of one prompt on the tallest egg.
]]

local EggPodiums = {}

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

return table.freeze(EggPodiums)
