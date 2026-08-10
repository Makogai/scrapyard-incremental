--!strict

local PlotBuildService = {}

local function setRequiredStageVisibility(plot: Model, stage: number)
	for _, instance in plot:GetDescendants() do
		local requiredStage = instance:GetAttribute("RequiredStage")
		if typeof(requiredStage) == "number" and instance:IsA("BasePart") then
			local visible = requiredStage <= stage
			instance.Transparency = if visible then 0 else 1
			instance.CanCollide = visible
			instance.CanTouch = visible
			instance.CanQuery = visible
			for _, child in instance:GetChildren() do
				if child:IsA("SelectionBox") then
					child.Visible = visible
				end
			end
		end
	end
end

--[[
	Publish who owns a plot and how they are doing, as attributes on its `OwnerSign`.

	The server stays the only thing that knows this, but it no longer draws it. It used to
	poke text into an authored `Card` inside a `BillboardGui` floating twelve studs above
	the board -- which is the "floating shi" this replaces. `PlotSignController` reads these
	attributes and renders the real UI kit onto a SurfaceGui on the board itself, so the
	sign looks like the rest of the game instead of like a debug label.

	Attributes rather than a remote because they replicate per-instance for free, arrive
	with the plot, and a late-joining client gets the current values without asking.

	`Money` is public information here in the same sense the richest-player podium makes it
	public: it is on a sign anyone can walk up to.
]]
local function updateSign(plot: Model, player: Player?, plotState: { [string]: any }?)
	local sign = plot:FindFirstChild("OwnerSign")
	if sign == nil then
		return
	end

	--[[
		The authored billboard is retired. The client puts its own marker above the plot,
		visible only to that plot's owner, which is the thing that was actually useful about
		a floating label -- finding your own yard.
	]]
	local board = sign:FindFirstChild("Board")
	local billboard = if board then board:FindFirstChild("OwnerBillboard") else nil
	if billboard and billboard:IsA("BillboardGui") then
		billboard.Enabled = false
	end

	if player == nil or plotState == nil then
		sign:SetAttribute("Occupied", false)
		sign:SetAttribute("OwnerUserId", 0)
		sign:SetAttribute("OwnerName", "")
		sign:SetAttribute("Rebirths", 0)
		sign:SetAttribute("Money", 0)
		sign:SetAttribute("TotalScrap", 0)
		sign:SetAttribute("Stage", 1)
		return
	end

	sign:SetAttribute("Occupied", true)
	sign:SetAttribute("OwnerUserId", player.UserId)
	sign:SetAttribute("OwnerName", player.DisplayName)
	sign:SetAttribute("Rebirths", plotState.PrestigeCount or 0)
	sign:SetAttribute("Money", plotState.Money or 0)
	sign:SetAttribute("TotalScrap", plotState.TotalScrapCollected or 0)
	sign:SetAttribute("Stage", plotState.PlotStage or 1)
end

local function updateUpgradeDisplay(plot: Model, upgradeLevels: { [string]: number }?)
	local display = plot:FindFirstChild("UpgradeDisplay")
	if display == nil then
		return
	end
	for _, descendant in display:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("BillboardGui") or descendant:IsA("SurfaceGui") then
			descendant.Enabled = false
		elseif descendant:IsA("SelectionBox") then
			descendant.Visible = false
		end
	end
	for _, meter in display:GetChildren() do
		local upgradeId = meter:GetAttribute("UpgradeId")
		local maximumLevel = meter:GetAttribute("MaximumLevel")
		if typeof(upgradeId) == "string" and typeof(maximumLevel) == "number" then
			local level = if upgradeLevels then upgradeLevels[upgradeId] or 0 else 0
			local ratio = math.clamp(level / maximumLevel, 0, 1)
			local fill = meter:FindFirstChild("Fill")
			if fill and fill:IsA("BasePart") then
				local height = 0.35 + 6.65 * ratio
				local baseY = fill:GetAttribute("MeterBaseY")
				fill.Size = Vector3.new(fill.Size.X, height, fill.Size.Z)
				if typeof(baseY) == "number" then
					fill.Position =
						Vector3.new(fill.Position.X, baseY + height / 2, fill.Position.Z)
				end
			end
			local label = meter:FindFirstChild("LevelLabel", true)
			if label and label:IsA("TextLabel") then
				label.Text = `LV {level}`
			end
		end
	end
end

local function updateAreaGates(
	plot: Model,
	unlockedAreas: { [string]: boolean }?,
	ownerActive: boolean
)
	local sections = plot:FindFirstChild("AreaSections")
	if sections == nil then
		return
	end
	for _, section in sections:GetChildren() do
		local areaId = section:GetAttribute("AreaId")
		if typeof(areaId) == "string" then
			local unlocked = unlockedAreas ~= nil and unlockedAreas[areaId] == true
			for _, descendant in section:GetDescendants() do
				if descendant:IsA("BasePart") then
					if descendant:GetAttribute("AuthoredTransparency") == nil then
						descendant:SetAttribute("AuthoredTransparency", descendant.Transparency)
						descendant:SetAttribute("AuthoredCanCollide", descendant.CanCollide)
					end
					local shouldShow = ownerActive and (areaId == "FrontYard" or unlocked)
					descendant.Transparency = if shouldShow
						then descendant:GetAttribute("AuthoredTransparency")
						else 1
					descendant.CanCollide = shouldShow
						and descendant:GetAttribute("AuthoredCanCollide") == true
					descendant.CanTouch = descendant.CanCollide
					descendant.CanQuery = shouldShow
				elseif descendant:IsA("SelectionBox") then
					descendant.Visible = ownerActive and (areaId == "FrontYard" or unlocked)
				end
			end
			local barrier = section:FindFirstChild("GateBarrier", true)
			if barrier and barrier:IsA("BasePart") then
				barrier.Transparency = 1
				barrier.CanCollide = false
				barrier.CanTouch = barrier.CanCollide
				barrier.CanQuery = barrier.CanCollide
			end
			local prompt = section:FindFirstChild("GateBillboard", true)
			if prompt and prompt:IsA("BillboardGui") then
				prompt.Enabled = false
			end
			local status = section:FindFirstChild("Status", true)
			if status and status:IsA("TextLabel") then
				status.Text = if unlocked then "UNLOCKED" else "LOCKED"
				status.TextColor3 = if unlocked
					then Color3.fromRGB(90, 205, 92)
					else Color3.fromRGB(255, 105, 105)
			end
		end
	end
end

--[[
	Just the sign, without the visibility and gate work `Refresh` does.

	Cash and total scrap move constantly, and a sign showing a number from whenever the
	player last unlocked something is worse than no number. This is cheap to call on a
	timer: attributes only replicate when the value actually changes.
]]
function PlotBuildService.RefreshSign(plot: Model, player: Player?, plotState: { [string]: any }?)
	updateSign(plot, player, plotState)
end

function PlotBuildService.Apply(plot: Model, player: Player, plotState: { [string]: any })
	local runtime = plot:FindFirstChild("RuntimeObjects")
	if runtime then
		runtime:ClearAllChildren()
	end
	plot:SetAttribute("OwnerUserId", player.UserId)
	plot:SetAttribute("OwnerName", player.Name)
	plot:SetAttribute("PlotStage", plotState.PlotStage)
	setRequiredStageVisibility(plot, plotState.PlotStage)
	updateSign(plot, player, plotState)
	updateUpgradeDisplay(plot, plotState.UpgradeLevels)
	updateAreaGates(plot, plotState.UnlockedAreas, true)
end

function PlotBuildService.Refresh(plot: Model, player: Player, plotState: { [string]: any })
	plot:SetAttribute("PlotStage", plotState.PlotStage)
	setRequiredStageVisibility(plot, plotState.PlotStage)
	updateSign(plot, player, plotState)
	updateUpgradeDisplay(plot, plotState.UpgradeLevels)
	updateAreaGates(plot, plotState.UnlockedAreas, true)
end

function PlotBuildService.Reset(plot: Model)
	local runtime = plot:FindFirstChild("RuntimeObjects")
	if runtime then
		runtime:ClearAllChildren()
	end
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("OwnerName", "")
	plot:SetAttribute("PlotStage", 1)
	setRequiredStageVisibility(plot, 1)
	updateSign(plot, nil, nil)
	updateUpgradeDisplay(plot, nil)
	updateAreaGates(plot, { FrontYard = true }, false)
end

return table.freeze(PlotBuildService)
