--!strict

local Players = game:GetService("Players")

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

local function updateSign(plot: Model, player: Player?, plotState: { [string]: any }?)
	local sign = plot:FindFirstChild("OwnerSign")
	local board = if sign then sign:FindFirstChild("Board") else nil
	local billboard = if board then board:FindFirstChild("OwnerBillboard") else nil
	local card = if billboard then billboard:FindFirstChild("Card") else nil
	if billboard and billboard:IsA("BillboardGui") then
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 0
		billboard.StudsOffset = Vector3.new(0, 12, 0)
	end
	if card == nil then
		return
	end
	local ownerName = card:FindFirstChild("OwnerName") :: TextLabel?
	local plotStats = card:FindFirstChild("PlotStats") :: TextLabel?
	local avatar = card:FindFirstChild("OwnerAvatar") :: ImageLabel?
	if player == nil or plotState == nil then
		if billboard and billboard:IsA("BillboardGui") then
			billboard.Enabled = false
		end
		if ownerName then
			ownerName.Text = "AVAILABLE PLOT"
		end
		if plotStats then
			plotStats.Text = "STAGE 1  •  0 PRESTIGE\n0 TOTAL SCRAP"
		end
		if avatar then
			avatar.Image = ""
			local placeholder = avatar:FindFirstChild("Placeholder")
			if placeholder and placeholder:IsA("GuiObject") then
				placeholder.Visible = true
			end
		end
		return
	end
	if billboard and billboard:IsA("BillboardGui") then
		billboard.Enabled = true
	end
	if ownerName then
		ownerName.Text = string.upper(`{player.DisplayName}'S YARD`)
	end
	if plotStats then
		plotStats.Text =
			`STAGE {plotState.PlotStage}  •  {plotState.PrestigeCount} PRESTIGE\n{plotState.TotalScrapCollected} TOTAL SCRAP`
	end
	if avatar then
		task.spawn(function()
			local succeeded, image = pcall(function()
				return Players:GetUserThumbnailAsync(
					player.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size150x150
				)
			end)
			if succeeded and plot:GetAttribute("OwnerUserId") == player.UserId then
				avatar.Image = image
				local placeholder = avatar:FindFirstChild("Placeholder")
				if placeholder and placeholder:IsA("GuiObject") then
					placeholder.Visible = false
				end
			end
		end)
	end
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
