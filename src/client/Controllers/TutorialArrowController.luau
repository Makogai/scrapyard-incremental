--!nonstrict
--[[
	TutorialArrowController.luau
	The world-space arrow that points at whatever the current objective is.

	The caption on the HUD says what to do; this says WHERE. Between them that is the whole
	onboarding -- no modal, nothing to dismiss, nothing that stops play. Complex tutorials backfire
	on Roblox, so the design goal was "a new player never reads anything and still knows where to
	go". See `TutorialConfig` and `docs/GAME_AUDIT.md`.

	Targets come from the step's `Target` field:

		"scrap"     the nearest live scrap on the player's own plot
		"crusher"   the plot's CrusherSellZone
		anything else / nil   no world arrow (the HUD caption's own arrow covers UI targets)

	BUILT FROM INSTANCES, NOT REACT. It has to hang off a part in the world, which is a
	BillboardGui's job rather than a screen's, and it is driven by a Charm subscription rather than
	a re-render. `Atoms.subscribe` exists exactly so non-React controllers can watch state.

	NOTE ON VERIFICATION: `screen_capture` with a camera override does not draw BillboardGuis, so
	this cannot be checked from a scripted screenshot -- it has to be looked at in a real Play
	session. That mistake cost an afternoon on the plot marker.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local Atoms = require(ReplicatedStorage.Shared.UI.State.Atoms)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)

local TutorialArrowController = {}

local localPlayer = Players.LocalPlayer
local marker: BillboardGui? = nil
local anchor: Part? = nil
local currentTarget: BasePart? = nil
local heartbeat: RBXScriptConnection? = nil

--[[
	An invisible anchor part that the billboard rides on, rather than parenting the billboard to the
	target itself. Two reasons: scrap is destroyed the instant it is collected, and a billboard
	parented to a destroyed part goes with it mid-frame; and the anchor lets the arrow float a fixed
	height above targets of wildly different sizes without touching them.
]]
local function ensureMarker(): BillboardGui
	if marker and marker.Parent then
		return marker
	end

	local part = Instance.new("Part")
	part.Name = "TutorialArrowAnchor"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = workspace
	anchor = part

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TutorialArrow"
	billboard.Size = UDim2.fromOffset(72, 96)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 260
	billboard.Adornee = part
	billboard.Parent = part

	--[[
		A triangle drawn as a rotated frame would be the obvious thing and is wrong -- rotation is
		fine on a world billboard, but a text arrow needs no geometry, scales cleanly, and cannot be
		mistaken for a UI panel. The heavy outline is what keeps it readable against a bright floor.
	]]
	local label = Instance.new("TextLabel")
	label.Name = "Arrow"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "▼"
	label.TextScaled = true
	label.FontFace = Theme.Font.Display
	label.TextColor3 = Theme.Color.Gold
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Theme.Color.Ink
	label.Parent = billboard

	marker = billboard
	return billboard
end

local function hide()
	currentTarget = nil
	if marker then
		marker.Enabled = false
	end
end

--- The player's own plot. Nothing points at someone else's yard.
local function ownPlot(): Model?
	local map = workspace:FindFirstChild("NewMap")
	local root = map and map:FindFirstChild("Plots")
	if root == nil then
		return nil
	end
	for _, plot in root:GetChildren() do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == localPlayer.UserId then
			return plot
		end
	end
	return nil
end

--[[
	Nearest live scrap on the plot.

	Nearest rather than first, because "walk to the thing the arrow is pointing at" should mean the
	shortest walk -- an arrow across the yard when there is scrap at your feet teaches the wrong
	thing about how collection works.
]]
local function nearestScrap(plot: Model): BasePart?
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local folder = plot:FindFirstChild("ActiveScrap", true)
	if root == nil or folder == nil then
		return nil
	end

	local best, bestDistance = nil, math.huge
	for _, scrap in folder:GetChildren() do
		local part = if scrap:IsA("BasePart")
			then scrap
			else scrap:FindFirstChildWhichIsA("BasePart", true)
		if part then
			local distance = (part.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = part, distance
			end
		end
	end
	return best
end

local function resolveTarget(targetName: string?): BasePart?
	if targetName == nil then
		return nil
	end
	local plot = ownPlot()
	if plot == nil then
		return nil
	end
	if targetName == "scrap" then
		return nearestScrap(plot)
	elseif targetName == "crusher" then
		local zone = plot:FindFirstChild("CrusherSellZone")
		return if zone and zone:IsA("BasePart") then zone else nil
	end
	return nil
end

--- The step definition for the current objective, or nil when there is nothing to point at.
local function currentStep()
	if Atoms.tutorialComplete() then
		return nil
	end
	return TutorialConfig.Steps[Atoms.tutorialStep()]
end

local function refresh()
	local step = currentStep()
	if step == nil then
		hide()
		return
	end
	local target = resolveTarget(step.Target)
	if target == nil then
		hide()
		return
	end

	currentTarget = target
	local billboard = ensureMarker()
	billboard.Enabled = true
end

function TutorialArrowController.Start()
	refresh()
	Atoms.subscribe(Atoms.tutorialStep, refresh)
	Atoms.subscribe(Atoms.tutorialComplete, refresh)

	--[[
		Re-resolved every frame while active, because the target MOVES in the sense that matters: the
		nearest piece of scrap changes as the player walks and is destroyed as they collect. A
		one-shot lookup leaves the arrow hanging over a hole in the ground.

		The whole loop is skipped once the chain is finished, so the cost is bounded to a new
		player's first few minutes rather than every session forever.
	]]
	heartbeat = RunService.Heartbeat:Connect(function()
		local step = currentStep()
		if step == nil then
			if marker and marker.Enabled then
				hide()
			end
			return
		end

		--- Destroyed targets are the normal case for scrap, not an error.
		if currentTarget == nil or currentTarget.Parent == nil then
			refresh()
			if currentTarget == nil then
				return
			end
		end

		local target = currentTarget :: BasePart
		if anchor then
			--[[
				Sits above the target's own height rather than a fixed offset, so it clears a
				13-stud crusher zone and a 1-stud can with the same code.
			]]
			anchor.CFrame = CFrame.new(target.Position + Vector3.new(0, target.Size.Y / 2 + 3.5, 0))
		end

		--- Re-pick nearer scrap as the player moves, not just when the current one dies.
		if step.Target == "scrap" then
			local plot = ownPlot()
			local nearer = if plot then nearestScrap(plot) else nil
			if nearer and nearer ~= currentTarget then
				currentTarget = nearer
			end
		end
	end)
end

function TutorialArrowController.Stop()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	if anchor then
		anchor:Destroy()
		anchor = nil
		marker = nil
	end
end

return TutorialArrowController
