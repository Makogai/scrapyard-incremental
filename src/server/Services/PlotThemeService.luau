--!nonstrict
--[[
	PlotThemeService.luau
	Turns an unlocked area into a whole-plot theme the player can convert to.

	Unlocking an area no longer opens a fenced region inside the yard. It drops that area's
	STRUCTURE on the plot; hold E on it and the entire plot is rebuilt as that theme. A player
	walking past someone else's Vehicle Graveyard can see exactly what they are missing, which
	is the point -- the envy is the feature.

	AUTHORING, all in Studio, no code change to add a theme:

		Workspace.PlotVariants
		  ScrapyardPlot          AreaId = "FrontYard"        one plot per theme
		  WorkshopPlot           AreaId = "WorkshopYard"
		  VehicleGraveyardPlot   AreaId = "VehicleGraveyard"

		Workspace.AreaStructures
		  WorkshopYard           one model per area, named after the area id
		  VehicleGraveyard

		Plot0N.AreaStructureSlots
		  WorkshopYard           a part per area saying where its structure stands
		  VehicleGraveyard

	Both source folders are moved to ServerStorage at startup: they are templates, and in
	Workspace they replicate to every client and can be walked into.

	WHY THE PLAYER IS TELEPORTED. Converting rebuilds the plot's geometry underneath whoever
	is standing on it. Rather than try to be clever about what is safe to swap while occupied,
	the owner is put down in front of their own plot first, the swap happens, and they walk
	back in. It also makes the change something you watch happen to your yard, which is worth
	more than a seamless swap nobody notices.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AreaConfig = require(ReplicatedStorage.Shared.Config.AreaConfig)
local PlotSkinConfig = require(ReplicatedStorage.Shared.Config.PlotSkinConfig)

local PlotBuildService = require(script.Parent.PlotBuildService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local PlotService = require(script.Parent.PlotService)
local RemoteService = require(script.Parent.RemoteService)

local PlotThemeService = {}

local VARIANT_FOLDER = "PlotVariants"
local STRUCTURE_FOLDER = "AreaStructures"
local SLOT_FOLDER = "AreaStructureSlots"

--- How long E must be held. Long enough that nobody converts their plot by walking past.
local HOLD_SECONDS = 2

--- Where the owner is put while their plot is rebuilt, in studs out from the plot's edge.
local STAND_BACK = 18

--- The theme every plot starts as, and the one that needs no unlock.
local DEFAULT_THEME = "FrontYard"

local variants: { [string]: Model } = {}
--[[
	Cosmetic reskins, indexed by area exactly like `variants`. A player who owns the skin pass for the
	theme their plot is wearing gets built from here instead. See `PlotSkinConfig`.
]]
local skins: { [string]: Model } = {}
local structures: { [string]: Model } = {}
local notifyRemote: RemoteEvent

--[[
	Move a template folder out of Workspace and index it by name.

	Same treatment `ScrapVariants` gives the scrap art, and for the same reasons: templates in
	Workspace replicate to every client, are visible to anyone who goes looking, and are
	usually unanchored, so they fall the instant Play starts.
]]
local function adopt(folderName: string, into: { [string]: Model }): string
	local folder = workspace:FindFirstChild(folderName) or ServerStorage:FindFirstChild(folderName)
	if folder == nil then
		return `no {folderName} folder in Workspace or ServerStorage`
	end
	if folder.Parent == workspace then
		for _, descendant in folder:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
		folder.Parent = ServerStorage
	end

	local found = {}
	for _, child in folder:GetChildren() do
		if not child:IsA("Model") then
			continue
		end
		--[[
			An explicit `AreaId` attribute wins, so a variant can be called whatever reads well
			in the explorer. Otherwise the model's own name has to be an area id.
		]]
		local areaId = child:GetAttribute("AreaId")
		if typeof(areaId) ~= "string" or AreaConfig.ById[areaId] == nil then
			areaId = if AreaConfig.ById[child.Name] then child.Name else nil
		end
		if areaId == nil then
			continue
		end
		into[areaId] = child
		table.insert(found, `{child.Name} -> {areaId}`)
	end
	return `{folderName}: {table.concat(found, ", ")}`
end

--------------------------------------------------------------------------------
-- Structures
--------------------------------------------------------------------------------

local function partTopY(part: BasePart): number
	local highest = -math.huge
	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				local corner = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) / 2)
				highest = math.max(highest, corner.Y)
			end
		end
	end
	return highest
end

--[[
	Stand a structure on its slot.

	Measured rather than computed, like the scrap and the richest-player statue: `PivotTo`
	places the pivot, and on an imported model the pivot is wherever the exporter left it, so
	the only reliable way to sit something on a surface is to measure its box afterwards and
	correct.
]]
local function placeStructure(plot: Model, areaId: string)
	local runtime = plot:FindFirstChild("RuntimeObjects")
	local slots = plot:FindFirstChild(SLOT_FOLDER)
	local slot = slots and slots:FindFirstChild(areaId)
	local template = structures[areaId]
	if runtime == nil or slot == nil or not slot:IsA("BasePart") or template == nil then
		return
	end

	local existing = runtime:FindFirstChild(`Structure_{areaId}`)
	if existing then
		existing:Destroy()
	end

	local clone = template:Clone()
	clone.Name = `Structure_{areaId}`
	clone:SetAttribute("AreaId", areaId)
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	clone.Parent = runtime

	clone:PivotTo(CFrame.new(slot.Position.X, slot.Position.Y, slot.Position.Z))
	local centre, size = clone:GetBoundingBox()
	local lift = (partTopY(slot) + size.Y / 2) - centre.Position.Y
	clone:PivotTo(clone:GetPivot() + Vector3.new(0, lift, 0))

	--[[
		The prompt is attached here rather than authored on the model, so a new structure is
		art and nothing else. `PetService` does the same for the egg podium.
	]]
	local anchor = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
	if anchor == nil then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ConvertPlotPrompt"
	prompt.ActionText = "Convert Plot"
	prompt.ObjectText = AreaConfig.ById[areaId].DisplayName or areaId
	prompt.HoldDuration = HOLD_SECONDS
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 12
	-- Structures will have props in front of them.
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(player: Player)
		PlotThemeService.TryConvert(player, areaId)
	end)
end

--- Put a structure on the plot for every area the owner has unlocked but is not standing in.
function PlotThemeService.RefreshStructures(plot: Model, plotState: { [string]: any }?)
	local runtime = plot:FindFirstChild("RuntimeObjects")
	if runtime == nil or plotState == nil then
		return
	end
	for _, child in runtime:GetChildren() do
		if string.match(child.Name, "^Structure_") then
			child:Destroy()
		end
	end

	local unlocked = plotState.UnlockedAreas or {}
	local active = plotState.ActivePlotTheme or DEFAULT_THEME
	for _, areaId in AreaConfig.Order do
		--[[
			Nothing to convert to for the theme you are already on, and nothing to offer for an area
			you have not bought.

			THE DEFAULT THEME DOES GET A STRUCTURE once you are not on it. It used to be excluded on
			the grounds that it is where you start, so there is no unlock to represent -- but this
			structure is the ONLY way to convert a plot, so leaving it out made the first conversion
			irreversible: a player who tried the Workshop look could never get their starting yard
			back. `TryConvert` already exempts the default theme from the unlock check, so the missing
			structure was the only thing in the way.
		]]
		local owned = areaId == DEFAULT_THEME or unlocked[areaId] == true
		if areaId ~= active and owned then
			placeStructure(plot, areaId)
		end
	end
end

--------------------------------------------------------------------------------
-- Conversion
--------------------------------------------------------------------------------

--- A spot outside the plot to stand the owner on while the ground is replaced.
local function standBackCFrame(plot: Model): CFrame?
	local spawn = plot:FindFirstChild("PlayerSpawn")
	local floor = plot:FindFirstChild("PlotFloor", true)
	if spawn == nil or not spawn:IsA("BasePart") or floor == nil or not floor:IsA("BasePart") then
		return nil
	end
	--[[
		Straight out from the plot's centre through the spawn, far enough to clear the fence.
		Using the spawn as the direction keeps them facing their own yard while it changes.
	]]
	local away = spawn.Position - floor.Position
	away = Vector3.new(away.X, 0, away.Z)
	away = if away.Magnitude < 1 then Vector3.new(0, 0, 1) else away.Unit
	local edge = math.max(floor.Size.X, floor.Size.Z) / 2
	local stand = floor.Position + away * (edge + STAND_BACK)
	return CFrame.lookAt(
		Vector3.new(stand.X, partTopY(floor) + 4, stand.Z),
		Vector3.new(floor.Position.X, partTopY(floor) + 4, floor.Position.Z)
	)
end

--[[
	Convert a player's plot to a theme.

	The client sends an area id and nothing else. Ownership, whether the area is unlocked, and
	whether a variant exists are all decided here -- a client that asks for a theme it has not
	bought gets refused, not trusted.
]]
function PlotThemeService.TryConvert(player: Player, areaId: string): (boolean, string)
	if typeof(areaId) ~= "string" or AreaConfig.ById[areaId] == nil then
		return false, "Unknown area"
	end
	local plot = PlotService.GetAssignments()[player]
	if plot == nil then
		return false, "You have no plot"
	end
	local plotState = PlayerStateService.GetPlotState(player)
	if plotState == nil then
		return false, "No player state"
	end
	if areaId ~= DEFAULT_THEME and (plotState.UnlockedAreas or {})[areaId] ~= true then
		return false, "Unlock that area first"
	end
	if variants[areaId] == nil then
		return false, "That plot theme has no model yet"
	end
	if (plotState.ActivePlotTheme or DEFAULT_THEME) == areaId then
		return false, "Your plot is already that theme"
	end

	local saved = PlayerStateService.SetActivePlotTheme(player, areaId)
	if not saved then
		return false, "Could not save that"
	end

	PlotThemeService.Rebuild(player, plot)
	--[[
		`Notify` carries a PLAIN STRING. Every other producer sends one, and `Bridge` is what
		wraps it into a toast payload (`{ Title = message, ... }`).

		This used to fire the wrapped table instead. That put a table in `Title`, so the toast's
		`string.upper(props.title)` threw during render, React tore down the whole tree, and the
		only thing left on screen was the topbar -- from one hold-E. If you want a richer toast
		here, add a dedicated remote; do not change what `Notify` means.
	]]
	notifyRemote:FireClient(
		player,
		`YOUR PLOT IS NOW A {AreaConfig.ById[areaId].DisplayName or areaId}`
	)
	return true, "Converted"
end

--[[
	WEAR OR REMOVE A COSMETIC SKIN, and rebuild the plot so the change is visible immediately.

	`skinId` is a pass id, or "" to go back to the standard build. Sits here rather than in
	`InventoryService` because a skin only exists as a rebuilt plot, and this module is what rebuilds --
	the inventory does not need to learn about plots to let you change your mind about a cosmetic.

	OWNERSHIP is `PlayerStateService.SetActivePlotSkin`'s to enforce, since that is what holds the
	entitlements. What this checks is that the id is a skin AT ALL, so a typo cannot blank a real choice.
]]
function PlotThemeService.WearSkin(player: Player, skinId: string): (boolean, string)
	if skinId ~= "" and skinId ~= PlotSkinConfig.Pass then
		return false, "That skin does not exist"
	end
	--- No models adopted at all means wearing it would silently change nothing; say so instead.
	if skinId ~= "" and next(skins) == nil then
		return false, "That skin has no model yet"
	end
	if not PlayerStateService.SetActivePlotSkin(player, skinId) then
		return false, "You do not own that skin"
	end

	local plot = PlotService.GetPlot(player)
	if plot ~= nil then
		PlotThemeService.Rebuild(player, plot)
	end
	return true, if skinId == "" then "SKIN REMOVED" else "SKIN APPLIED"
end

--[[
	Rebuild a plot from the owner's saved theme.

	Order matters and is the whole reason this is one function rather than scattered calls:

	  1. stand the owner clear, because the floor is about to be replaced under them
	  2. release the active scrap, or `ScrapService` keeps records pointing at destroyed models
	  3. swap the geometry, keeping the slot's own position and PlotId
	  4. re-run the build so the sign, stage visibility and gates re-bind to the new instances
	  5. put the structures back for every unlocked area
]]
function PlotThemeService.Rebuild(player: Player?, plot: Model)
	local plotState = if player then PlayerStateService.GetPlotState(player) else nil
	local themeId = if plotState
		then (plotState.ActivePlotTheme or DEFAULT_THEME)
		else DEFAULT_THEME
	--[[
		A SKIN WINS OVER THE STANDARD VARIANT, when owned, worn, and built for THIS theme.

		Falls through to the normal variant whenever the skin is unowned or its model is missing from
		`Workspace.PlotSkins`, so a half-authored skin degrades to the plot everybody else sees rather than
		to no plot at all.
	]]
	local entitlements = if plotState then plotState.Entitlements else nil
	local wornSkin = if plotState then (plotState.ActivePlotSkin or "") else ""
	local skin = PlotSkinConfig.activeSkinFor(themeId, entitlements, wornSkin)
	local variant = if skin ~= nil and skins[themeId] ~= nil
		then skins[themeId]
		else (variants[themeId] or variants[DEFAULT_THEME])
	if variant == nil then
		warn(`[PlotThemeService] no variant for {themeId} and no {DEFAULT_THEME} fallback`)
		return
	end

	--[[
		Align by the FLOOR, not by the model pivot.

		`Model:GetPivot()` on a model with no PrimaryPart is its bounding-box centre, so it
		moves whenever the contents change -- and the variants carry an extra
		`AreaStructureSlots` folder the live plots did not. Pivoting the rebuilt plot back to
		the old pivot therefore dropped the whole plot several studs off its slot: the plot
		vanished from where it belonged, and `PlayerSpawn` came with it, which is why both the
		join spawn and the My Plot teleport put the player in the air.

		The floor is the one part that means the same thing in both, so the transform from
		variant space to slot space is the one that maps its floor onto the existing floor.
	]]
	local currentFloor = plot:FindFirstChild("PlotFloor", true)
	local variantFloor = variant:FindFirstChild("PlotFloor", true)
	if currentFloor == nil or variantFloor == nil then
		warn(
			`[PlotThemeService] {plot.Name} or variant {variant.Name} has no PlotFloor to align by`
		)
		return
	end
	local relative = currentFloor.CFrame * variantFloor.CFrame:Inverse()
	local plotId = plot:GetAttribute("PlotId")

	PlotService.ReleaseScrap(plot)

	--[[
		Keep `RuntimeObjects` -- it is where structures and spawned scrap live, and other
		services hold it by reference. Everything else is replaced.
	]]
	local runtime = plot:FindFirstChild("RuntimeObjects")
	if runtime then
		runtime:ClearAllChildren()
	end
	for _, child in plot:GetChildren() do
		if child ~= runtime then
			child:Destroy()
		end
	end

	for _, child in variant:GetChildren() do
		if child.Name == "RuntimeObjects" then
			continue
		end
		local clone = child:Clone()
		--[[
			Transform each child explicitly rather than moving the plot afterwards. A folder of
			parts has no pivot of its own to move, so this walks what it finds: models by pivot,
			loose parts by CFrame.
		]]
		if clone:IsA("Model") then
			clone:PivotTo(relative * clone:GetPivot())
		elseif clone:IsA("BasePart") then
			clone.CFrame = relative * clone.CFrame
		else
			for _, descendant in clone:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.CFrame = relative * descendant.CFrame
				end
			end
		end
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
		if clone:IsA("BasePart") then
			clone.Anchored = true
		end
		clone.Parent = plot
	end
	plot:SetAttribute("PlotId", plotId)
	plot:SetAttribute("ActivePlotTheme", themeId)

	if player and plotState then
		PlotBuildService.Apply(plot, player, plotState)
		PlotThemeService.RefreshStructures(plot, plotState)
		--[[
			Stand the scrap back up on the NEW geometry.

			`ReleaseScrap` above only drops the old pieces. This is what re-resolves the markers
			and the `ActiveScrap` folder, both of which the swap destroyed. Missing this call is
			why a plot spawned nothing at all: `ScrapService` activates off the same
			`OnAssigned` signal and runs before this rebuild, so its setup was orphaned every
			single join.
		]]
		PlotService.ActivateScrap(player, plot)
	end

	--[[
		Announce the swap so every service holding a reference under this plot can re-resolve it.
		Fired last, once the new geometry is in and dressed, so subscribers see the final tree.
	]]
	PlotService.NotifyGeometryReplaced(player, plot)

	--[[
		Stand the owner outside their rebuilt plot, measured against the NEW geometry.

		Done after the swap, not before: placing them first meant the reference floor was about
		to be destroyed, so any drift in the rebuild left them hanging in the air.
	]]
	if player then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local stand = standBackCFrame(plot)
		if root and root:IsA("BasePart") and stand then
			root.CFrame = stand
		end
	end
end

function PlotThemeService.Start()
	notifyRemote = RemoteService.GetEvent("Notify")
	print(`[PlotThemeService] {adopt(VARIANT_FOLDER, variants)}`)
	--- Optional: a place with no authored skins simply logs that none were found and carries on.
	print(`[PlotThemeService] {adopt(PlotSkinConfig.Folder, skins)}`)
	print(`[PlotThemeService] {adopt(STRUCTURE_FOLDER, structures)}`)

	--[[
		Build every assigned plot from its owner's saved theme, and keep the structures in step
		as areas are unlocked. `PlotService` fires these when a plot is handed out or refreshed.
	]]
	PlotService.OnAssigned(function(player: Player, plot: Model)
		PlotThemeService.Rebuild(player, plot)
	end)
	PlotService.OnAppearanceRefreshed(function(player: Player, plot: Model)
		PlotThemeService.RefreshStructures(plot, PlayerStateService.GetPlotState(player))
	end)
end

return PlotThemeService
