--!strict
--[[
	ScrapVariants.luau
	Finds the authored per-rarity model for a piece of scrap.

	AUTHORING lives in a `Scraps` folder, one subfolder per scrap type, one model per
	rarity inside it:

		Scraps
		  Can                     the type folder
		    NormalMetalCan        rarity prefix + whatever you want to call it
		    RareMetalCan
		    EpicMetalCan
		    LegendaryMetalCan
		    NebulaMetalCan
		  LooseBolt
		    NormalLooseBolt ...
		  SmallMetalPlate
		    NormalMetalSheet ...

	A model's own part colours and its ParticleEmitters ARE the rarity treatment. This
	module hands the model over untouched and `ScrapService` skips its procedural tint
	and emitter entirely -- otherwise the authored art would be overwritten by a flat
	colour and a generic sparkle, which is the opposite of the point.

	MATCHING is by convention so that adding a type is a Studio job, not a code change:

	  * the rarity comes from the model name's prefix, against
	    `ScrapConfig.VariantOrder`, so `EpicMetalCan` is the Epic variant of its folder.
	  * the folder is matched to a scrap id by its `ModelName`, then its `Id`, allowing
	    either to be a suffix of the other -- which is what pairs the `Can` folder with
	    the `MetalCan` scrap without a lookup table.
	  * a folder may carry a `ScrapId` string attribute, which overrides all of that.
	    Use it when a folder name has nothing in common with the config id.

	Anything with no authored folder keeps working: `ScrapService` falls back to the one
	generic model in `ServerStorage.ScrapModels` and its procedural treatment. That
	matters because most scrap types do not have art yet, and it means the set can be
	filled in one type at a time.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ScrapConfig = require(ReplicatedStorage.Shared.Config.ScrapConfig)

local ScrapVariants = {}

local FOLDER_NAME = "Scraps"

--[[
	Where the client can find scrap models to render in a ViewportFrame.

	The authored folder lives in ServerStorage, which the client cannot see, so the
	index would have nothing to draw. This is a separate lightweight copy: emitters and
	highlights are stripped because a ViewportFrame renders neither, and carrying them
	would replicate particle data to every client for no picture at all.

	Named `ScrapPreviews` rather than `ScrapModels` on purpose -- `ServerStorage` already
	has a `ScrapModels` folder holding the generic gameplay models, and two folders with
	one name in two services is a trap.
]]
local PREVIEW_FOLDER = "ScrapPreviews"

--- `<ScrapId>_<VariantId>` for authored art, plain `<ScrapId>` for the generic model.
function ScrapVariants.PreviewName(scrapId: string, variantId: string?): string
	return if variantId then `{scrapId}_{variantId}` else scrapId
end

--- scrapId -> rarity -> model. Built once at start.
local byScrapId: { [string]: { [string]: Instance } } = {}
local sourceFolder: Folder? = nil

--- Case-insensitive "one of these ends with the other", which is what pairs Can/MetalCan.
local function namesAgree(folderName: string, candidate: string): boolean
	local a, b = string.lower(folderName), string.lower(candidate)
	if a == b then
		return true
	end
	return string.sub(b, -#a) == a or string.sub(a, -#b) == b
end

--[[
	Which scrap id a type folder belongs to, plus a reason when it cannot tell.

	Exact names win outright. Only then does the suffix rule get a say, and if it finds
	more than one candidate the folder is refused rather than guessed at -- `ScrapConfig`
	is iterated as a dictionary, so a guess would pick a different scrap on different
	runs, which is the worst kind of bug to be handed.
]]
local function scrapIdFor(folder: Instance): (string?, string?)
	local declared = folder:GetAttribute("ScrapId")
	if typeof(declared) == "string" then
		if ScrapConfig.ById[declared] then
			return declared, nil
		end
		return nil, `ScrapId attribute "{declared}" is not a scrap id`
	end

	local loose = {}
	for scrapId, definition in ScrapConfig.ById do
		local name = string.lower(folder.Name)
		if name == string.lower(scrapId) or name == string.lower(definition.ModelName) then
			return scrapId, nil
		end
		if namesAgree(folder.Name, definition.ModelName) or namesAgree(folder.Name, scrapId) then
			table.insert(loose, scrapId)
		end
	end

	if #loose == 1 then
		return loose[1], nil
	elseif #loose > 1 then
		table.sort(loose)
		return nil, `ambiguous between {table.concat(loose, " and ")} -- set a ScrapId attribute`
	end
	return nil, "matches no scrap id"
end

--- The rarity a model name declares by its prefix.
local function variantOf(model: Instance): string?
	for _, variantId in ScrapConfig.VariantOrder do
		if string.sub(string.lower(model.Name), 1, #variantId) == string.lower(variantId) then
			return variantId
		end
	end
	return nil
end

--[[
	Index the authored models, and move the folder out of Workspace while we are at it.

	Templates in Workspace are a liability: they replicate to every client, they are
	visible to anyone who goes looking, and -- measured on this set -- most of them are
	unanchored, so they fall the instant Play starts. ServerStorage is where template
	data belongs, and authoring in Workspace stays perfectly convenient because Play
	never saves.
]]
function ScrapVariants.Load(): string
	byScrapId = {}

	local folder = workspace:FindFirstChild(FOLDER_NAME)
		or ServerStorage:FindFirstChild(FOLDER_NAME)
	if folder == nil then
		sourceFolder = nil
		return `no {FOLDER_NAME} folder in Workspace or ServerStorage -- every scrap will use its generic model`
	end

	if folder.Parent == workspace then
		for _, descendant in folder:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
		folder.Parent = ServerStorage
	end
	sourceFolder = folder :: Folder

	local matched, unmatched, orphans = {}, {}, {}
	for _, typeFolder in folder:GetChildren() do
		local scrapId, reason = scrapIdFor(typeFolder)
		if scrapId == nil then
			table.insert(unmatched, `{typeFolder.Name} ({reason})`)
			continue
		end

		local variants = {}
		local found = {}
		for _, model in typeFolder:GetChildren() do
			local variantId = variantOf(model)
			if variantId == nil then
				table.insert(orphans, `{typeFolder.Name}/{model.Name}`)
				continue
			end
			variants[variantId] = model
			table.insert(found, variantId)
		end

		if next(variants) ~= nil then
			byScrapId[scrapId] = variants
			table.insert(
				matched,
				`{typeFolder.Name} -> {scrapId} ({#found}/{#ScrapConfig.VariantOrder})`
			)
		end
	end

	--[[
		Reported rather than silent. A folder that matched nothing, or a model with no
		rarity prefix, is invisible at runtime -- the scrap just quietly keeps its old
		look, which is a miserable thing to debug from the game.
	]]
	local report = `indexed {#matched} scrap type(s): {table.concat(matched, ", ")}`
	if #unmatched > 0 then
		report ..= `\n  UNUSED folders: {table.concat(unmatched, ", ")}`
	end
	if #orphans > 0 then
		local rarities = table.concat(ScrapConfig.VariantOrder, "/")
		report ..= `\n  models with no rarity prefix: {table.concat(orphans, ", ")}` .. ` -- prefix one of {rarities}`
	end
	return report
end

--[[
	Publish a render-only copy of every scrap model for the client's index.

	Every scrap type gets a plain `<ScrapId>` entry from the generic model so the index is
	never empty, and each authored rarity gets `<ScrapId>_<VariantId>` on top. The index
	asks for the best rarity it has seen and falls back to the plain name, which is why
	both exist.
]]
function ScrapVariants.PublishPreviews(genericModels: Folder): string
	local previews = ReplicatedStorage:FindFirstChild(PREVIEW_FOLDER)
	if previews then
		previews:Destroy()
	end
	previews = Instance.new("Folder")
	previews.Name = PREVIEW_FOLDER
	previews.Parent = ReplicatedStorage

	local function publish(source: Instance, name: string)
		if previews:FindFirstChild(name) then
			return false
		end
		local clone = source:Clone()
		clone.Name = name
		for _, descendant in clone:GetDescendants() do
			-- A ViewportFrame draws neither of these, so they are pure replication cost.
			if descendant:IsA("ParticleEmitter") or descendant:IsA("Highlight") then
				descendant:Destroy()
			elseif descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
			end
		end
		clone.Parent = previews
		return true
	end

	local generic, authored = 0, 0
	for scrapId, definition in ScrapConfig.ById do
		local source = genericModels:FindFirstChild(definition.ModelName)
		if source and publish(source, ScrapVariants.PreviewName(scrapId, nil)) then
			generic += 1
		end
	end
	for scrapId, variants in byScrapId do
		for variantId, model in variants do
			if publish(model, ScrapVariants.PreviewName(scrapId, variantId)) then
				authored += 1
			end
		end
	end
	return `published {generic} generic and {authored} per-rarity previews to ReplicatedStorage.{PREVIEW_FOLDER}`
end

--- The authored model for this scrap at this rarity, or nil to use the generic one.
function ScrapVariants.Get(scrapId: string, variantId: string): Instance?
	local variants = byScrapId[scrapId]
	if variants == nil then
		return nil
	end
	return variants[variantId]
end

--- Which rarities a scrap has art for. Used by the startup report and by tests.
function ScrapVariants.Coverage(): { [string]: { string } }
	local coverage = {}
	for scrapId, variants in byScrapId do
		local list = {}
		for _, variantId in ScrapConfig.VariantOrder do
			if variants[variantId] then
				table.insert(list, variantId)
			end
		end
		coverage[scrapId] = list
	end
	return coverage
end

function ScrapVariants.SourceFolder(): Folder?
	return sourceFolder
end

return ScrapVariants
