--!nonstrict
--[[
	TutorialArrowController.luau
	A 3D arrow in the world, pointing at whatever the current objective is.

	The HUD caption says what to do; this says WHERE. Between them that is the whole onboarding -- no
	modal, nothing to dismiss, nothing that stops play. The design goal was "a new player never reads
	anything and still knows where to go". See `TutorialConfig` and `docs/GAME_AUDIT.md`.

	REAL GEOMETRY, NOT A BILLBOARD. It used to be a "▼" in a `BillboardGui`, which always faced the
	camera and read as a UI sticker floating in the scene. This is a shaft and a cone of actual parts:
	it has a direction in the world, it catches the light, and it bobs and turns on the spot, which a
	flat glyph cannot do. It also means `screen_capture` can see it, which a BillboardGui cannot.

	TARGETS -- and the important one is what it does NOT do:

		"yard"     the middle of the player's own scrap field, computed from their spawn markers.
		           NOT one piece of scrap. An arrow pinned to a single collectable is wrong twice
		           over: it vanishes the instant that piece is collected, and it teaches "go to that
		           one thing" when the lesson is "walk around your yard and your magnet does the rest".
		"crusher"  the plot's CrusherSellZone.
		anything else, including "upgrades", is a SCREEN target and belongs to the HUD's spotlight.

	Driven by a Charm subscription rather than a re-render, because it owns instances rather than UI.
	`Atoms.subscribe` exists exactly so non-React controllers can watch state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local Atoms = require(ReplicatedStorage.Shared.UI.State.Atoms)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)

local TutorialArrowController = {}

local localPlayer = Players.LocalPlayer

--- How high the arrow floats above its target, and how far it bobs.
local HOVER_HEIGHT = 7
local BOB_AMPLITUDE = 0.9
local BOB_SPEED = 2.2
local TURN_DEGREES_PER_SECOND = 55

local arrow: Model? = nil
--- Which target name the arrow is currently following, for the subscription to compare against.
local currentTargetName: string? = nil
local heartbeat: RBXScriptConnection? = nil
local elapsed = 0

--[[
	Builds the arrow once and reuses it.

	`Neon` on purpose: it has to read against a bright green floor in daylight and a dark yard at
	night, and Neon is the one material that does both without a light source. Every part is
	non-collidable and non-queryable so it can never block the player, trip the crusher's Touched
	volume, or appear in the scrap overlap query -- the same rules the plot props follow.
]]
local function buildArrow(): Model
	local model = Instance.new("Model")
	model.Name = "TutorialArrow"

	local function piece(name: string, size: Vector3, offset: Vector3, shape: Enum.PartType?)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Shape = shape or Enum.PartType.Block
		part.Color = Theme.Color.Gold
		part.Material = Enum.Material.Neon
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		--- Offsets are relative to the model's pivot, applied when it is positioned.
		part:SetAttribute("Offset", offset)
		return part
	end

	--[[
		A wedge pair makes the head. Roblox has no cone primitive that points down, and two mirrored
		wedges read as an arrowhead from every angle a player will see it from -- which a cylinder,
		the other option, does not.
	]]
	local head = Instance.new("WedgePart")
	head.Name = "HeadFront"
	head.Size = Vector3.new(2.6, 2.2, 1.3)
	head.Color = Theme.Color.Gold
	head.Material = Enum.Material.Neon
	head.Anchored = true
	head.CanCollide = false
	head.CanTouch = false
	head.CanQuery = false
	head.CastShadow = false
	head.Parent = model
	head:SetAttribute("Offset", Vector3.new(0, 0, 0))
	head:SetAttribute("Roll", 180)

	local headBack = head:Clone()
	headBack.Name = "HeadBack"
	headBack:SetAttribute("Roll", 0)
	headBack.Parent = model

	piece("Shaft", Vector3.new(1.1, 2.4, 1.1), Vector3.new(0, 2.2, 0))
	--- A darker collar where the shaft meets the head, so the silhouette is not one gold blob.
	local collar = piece("Collar", Vector3.new(1.6, 0.45, 1.6), Vector3.new(0, 1.2, 0))
	collar.Color = Theme.Color.Orange

	model.PrimaryPart = head
	return model
end

local function ensureArrow(): Model
	if arrow and arrow.Parent then
		return arrow
	end
	local model = buildArrow()
	model.Parent = workspace
	arrow = model
	return model
end

--- Places every piece relative to a pivot, honouring each part's authored offset and roll.
local function placeArrow(model: Model, pivot: CFrame)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			local offset = part:GetAttribute("Offset") or Vector3.zero
			local roll = part:GetAttribute("Roll")
			local cframe = pivot * CFrame.new(offset)
			if roll then
				cframe = cframe * CFrame.Angles(0, 0, math.rad(roll))
			end
			part.CFrame = cframe
		end
	end
end

local function hide()
	currentTargetName = nil
	if arrow then
		arrow:Destroy()
		arrow = nil
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
	The centre of the scrap field, averaged over the spawn markers.

	A fixed point rather than a piece of scrap, so the arrow stays put while the player walks into it
	and cannot be destroyed out from under itself.
]]
local function yardCentre(plot: Model): Vector3?
	local markers = plot:FindFirstChild("ScrapSpawnLocations")
	if markers == nil then
		return nil
	end
	local total, count = Vector3.zero, 0
	for _, marker in markers:GetChildren() do
		if marker:IsA("BasePart") then
			total += marker.Position
			count += 1
		end
	end
	if count == 0 then
		return nil
	end
	return total / count
end

local function currentStep()
	if Atoms.tutorialComplete() then
		return nil
	end
	return TutorialConfig.Steps[Atoms.tutorialStep()]
end

--[[
	Resolves the anchor point for a step.

	Returns a position rather than a part, because "yard" has no part to hang off -- and because a
	position cannot be destroyed mid-frame the way a scrap model can.
]]
local function resolveAnchor(targetName: string?): Vector3?
	if targetName == nil then
		return nil
	end
	local plot = ownPlot()
	if plot == nil then
		return nil
	end
	if targetName == "yard" then
		return yardCentre(plot)
	elseif targetName == "crusher" then
		local zone = plot:FindFirstChild("CrusherSellZone")
		if zone and zone:IsA("BasePart") then
			return zone.Position + Vector3.new(0, zone.Size.Y / 2, 0)
		end
	end
	return nil
end

function TutorialArrowController.Start()
	local function refresh()
		local step = currentStep()
		currentTargetName = if step then step.Target else nil
		if step == nil or currentTargetName == nil then
			hide()
		end
	end

	refresh()
	Atoms.subscribe(Atoms.tutorialStep, refresh)
	Atoms.subscribe(Atoms.tutorialComplete, refresh)

	--[[
		Re-resolved every frame while a world step is live. The plot can be rebuilt underneath it -- a
		theme conversion replaces every child -- so holding a resolved position would leave the arrow
		hanging over where the yard used to be.

		The whole loop is skipped once the chain finishes, so the cost is bounded to a new player's
		first few minutes rather than every session forever.
	]]
	heartbeat = RunService.Heartbeat:Connect(function(deltaTime)
		local step = currentStep()
		local targetName = if step then step.Target else nil
		--- "upgrades" and friends are screen targets: the HUD spotlight owns those.
		if targetName ~= "yard" and targetName ~= "crusher" then
			if arrow then
				hide()
			end
			return
		end

		local anchor = resolveAnchor(targetName)
		if anchor == nil then
			if arrow then
				hide()
			end
			return
		end

		elapsed += deltaTime
		local bob = math.sin(elapsed * BOB_SPEED) * BOB_AMPLITUDE
		local spin = (elapsed * TURN_DEGREES_PER_SECOND) % 360
		--- Turning on the spot is what makes it read as an object rather than a decal.
		local pivot = CFrame.new(anchor + Vector3.new(0, HOVER_HEIGHT + bob, 0))
			* CFrame.Angles(0, math.rad(spin), 0)
		placeArrow(ensureArrow(), pivot)
	end)
end

function TutorialArrowController.Stop()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	hide()
end

return TutorialArrowController
