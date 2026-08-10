--!strict
--[[
	RichestPlayerService.luau
	The statue of whoever is currently carrying the most cash.

	Every `REFRESH_SECONDS` it asks `PlayerStateService` for public state, picks the
	richest connected player, and -- only when the winner actually changes -- rebuilds
	an avatar statue on the pedestal. The statue is anchored, non-colliding and
	massless, dances on a loop, and turns slowly in place.

	PRESENTATION lives on the pedestal model's four tablets. Each one gets a
	`SurfaceGui` reading RICHEST PLAYER / name / cash, generated at runtime so all four
	always agree and so a new pedestal needs no authored GUIs.

	WHAT THIS EXPECTS IN STUDIO

		NewMap.RichestPlayer                     the display root, carries the attributes
		  CharacterPedestal (Model)              what the winner stands on
		    Pedestel                             the body; its top is the stand surface
		    Tablet1 .. Tablet 4                  plaques; names may or may not have a space
		  DisplayCharacter (Folder)              where the statue is parented
		  EditorPreview                          a baked preview frame, destroyed at runtime

	Nothing here is matched by path beyond that. The stand height is the highest point
	of the pedestal's parts, and a tablet's outward face is derived from geometry -- so
	the model can be moved, rotated or rebuilt and this still works.

	Attributes on `RichestPlayer`, all designer-tunable:

		DanceAnimationId  required
		AvatarScale       default 5
		HeightOffset      default 0 -- see the note on flushness below
		RotationSeconds   default 10
		LabelOffset       legacy, only used by the optional WinnerBillboard
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerStateService = require(script.Parent.PlayerStateService)

local RichestPlayerService = {}

local REFRESH_SECONDS = 2
local currentWinnerUserId = 0
local avatarGeneration = 0

--- Matches `Tablet1`, `Tablet 2`, `Tablet  10`. The authored names are inconsistent.
local TABLET_PATTERN = "^Tablet%s*%d+$"

local FACE_NORMALS: { { any } } = {
	{ Enum.NormalId.Right, Vector3.new(1, 0, 0) },
	{ Enum.NormalId.Left, Vector3.new(-1, 0, 0) },
	{ Enum.NormalId.Top, Vector3.new(0, 1, 0) },
	{ Enum.NormalId.Bottom, Vector3.new(0, -1, 0) },
	{ Enum.NormalId.Back, Vector3.new(0, 0, 1) },
	{ Enum.NormalId.Front, Vector3.new(0, 0, -1) },
}

--- Canvas resolution for the plaques. 64 gives ~330x185 on the authored tablets.
local PIXELS_PER_STUD = 64

--[[
	Lift the canvas clear of the surface it sits on.

	This is the small one. It stops a plaque that already clears the mesh from
	z-fighting it, and that is all it is good for -- see PLAQUE_CLEARANCE for why it
	cannot rescue a plaque that is actually inside the geometry.
]]
local PLAQUE_Z_OFFSET = 0.05

local HEADER_COLOR = Color3.fromRGB(255, 255, 255)
local NAME_COLOR = Color3.fromRGB(255, 244, 105)
local CASH_COLOR = Color3.fromRGB(89, 255, 128)
local STROKE_COLOR = Color3.fromRGB(32, 18, 48)

local function compact(value: number): string
	if value >= 1e12 then
		return string.format("%.2fT", value / 1e12)
	elseif value >= 1e9 then
		return string.format("%.2fB", value / 1e9)
	elseif value >= 1e6 then
		return string.format("%.2fM", value / 1e6)
	elseif value >= 1e3 then
		return string.format("%.1fK", value / 1e3)
	end
	return tostring(math.floor(value))
end

--[[
	The true world-space top of a part, corners and all, so a rotated or beveled slab
	still reports the surface something can stand on.
]]
local function partTopY(part: BasePart): number
	local maximumY = -math.huge
	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				local corner = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) / 2)
				maximumY = math.max(maximumY, corner.Y)
			end
		end
	end
	return maximumY
end

--[[
	The disc the winner actually stands on.

	Preferred over the model's bounding box because the tablets stick out past the
	body on all four sides, so the box's centre is a wider circle than the surface --
	and any tablet that ends up marginally taller than the body would become the
	"stand height". Falls back to the whole model when no body part is named.
]]
local BODY_NAMES = { "Pedestel", "Pedestal", "Base", "Top" }

local function standPart(pedestal: Instance): BasePart?
	if pedestal:IsA("BasePart") then
		return pedestal
	end
	for _, name in BODY_NAMES do
		local child = pedestal:FindFirstChild(name)
		if child then
			local part = if child:IsA("BasePart")
				then child :: BasePart
				else child:FindFirstChildWhichIsA("BasePart", true)
			if part then
				return part
			end
		end
	end
	return nil
end

--- The surface the winner stands on: the body's top, or the model's highest point.
local function standSurfaceY(pedestal: Instance): number
	local body = standPart(pedestal)
	if body then
		return partTopY(body)
	end
	local highest = -math.huge
	for _, descendant in pedestal:GetDescendants() do
		if descendant:IsA("BasePart") then
			highest = math.max(highest, partTopY(descendant))
		end
	end
	return highest
end

local function horizontalCentre(pedestal: Instance): Vector3
	local body = standPart(pedestal)
	if body then
		return body.Position
	end
	if pedestal:IsA("BasePart") then
		return pedestal.Position
	end
	return (pedestal :: Model):GetBoundingBox().Position
end

--[[
	Map geometry has to be anchored, and an imported model usually is not.

	This is not defensive tidying: unanchored, the pedestal's own parts collide with
	each other the instant Play starts and drift apart. Measured once at 69x5x83 studs
	from an authored 32x3x32, with the statue being positioned against a moving
	surface -- it ended up 13 studs below the disc.
]]
local function anchorPedestal(pedestal: Instance)
	local loosened = 0
	for _, descendant in pedestal:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant.Anchored then
			descendant.Anchored = true
			loosened += 1
		end
	end
	if pedestal:IsA("BasePart") and not (pedestal :: BasePart).Anchored then
		(pedestal :: BasePart).Anchored = true
		loosened += 1
	end
	if loosened > 0 then
		warn(
			`[RichestPlayerService] Anchored {loosened} loose part(s) in `
				.. `{pedestal:GetFullName()} -- anchor them in Studio so they cannot drift.`
		)
	end
end

--------------------------------------------------------------------------------
-- Tablets
--------------------------------------------------------------------------------

--[[
	Where a plaque goes on a tablet.

	NOTHING HERE ROTATES A GuiObject. The obvious implementation puts a `SurfaceGui` on
	the tablet's top face and spins its contents to suit which side of the pedestal the
	tablet is on -- and it does not work. A rotated GuiObject is not clipped or composed
	predictably (the same trap as rule 11 in AGENTS.md), so whether a given plaque drew
	at all depended on the camera angle: east would render while south came out a blank
	grey rectangle, with all four in provably identical states.

	So the orientation is done in world space instead. Each tablet gets a thin invisible
	part whose axes are aligned to the pedestal, and the plaque sits on ITS top face at
	rotation zero. Measured mapping for a top face: the canvas's X follows the part's Z
	and its Y follows the part's X, so text runs along the part's +Z with its top toward
	the part's -X. Point the helper's +X outward and the text reads left-to-right along
	the tangent with its top inward -- correct for someone standing outside, on all four
	sides, with no per-tablet special casing.

	Two kinds of tablet, told apart by which face is biggest:

	  FLAT (the authored ones)  largest face is the top, so it is a floor plaque and gets
	                            the aligned helper part described above.
	  UPRIGHT                   largest face is vertical, so it is a sign; the plaque goes
	                            straight onto whichever vertical face points outward.
]]
local PLAQUE_THICKNESS = 0.05

--[[
	How far above the surrounding surface a plaque floats.

	It has to clear the pedestal disc, not just its own tablet: measured, a tablet's top
	sits 0.044 studs BELOW the disc's, so the tablets are recessed into the body and a
	plaque laid on one is inside the disc geometry.

	0.15, not a hair's breadth, because near-coplanar is the failure case. A plaque
	measured 0.0036 studs inside the mesh would not render at all from most angles --
	not with `ZOffset` at 0.2, not with `AlwaysOnTop` forced on, and not with an opaque
	magenta frame filling the canvas, while every property read correct on both the
	server and the client. Move the part 0.15 clear along its own normal and it draws
	from everywhere. The GUI has to physically escape the mesh; no property will do it.
]]
local PLAQUE_CLEARANCE = 0.15

--[[
	The helper part has to be *almost* invisible rather than invisible.

	At `Transparency = 1` Roblox stops drawing the part's SurfaceGui along with the part,
	so the plaque vanished while every property on it read as correct and present on the
	server. 0.99 is indistinguishable and renders.
]]
local PLAQUE_HOST_TRANSPARENCY = 0.99

type Tablet = {
	header: TextLabel,
	name: TextLabel,
	cash: TextLabel,
}

local function styleLabel(
	label: TextLabel,
	color: Color3,
	font: Enum.Font,
	position: UDim2,
	size: UDim2
)
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeColor3 = STROKE_COLOR
	label.TextStrokeTransparency = 0
	label.Position = position
	label.Size = size
end

local function outwardOf(part: BasePart, centre: Vector3): Vector3
	local away = part.Position - centre
	away = Vector3.new(away.X, 0, away.Z)
	return if away.Magnitude < 0.01 then Vector3.new(0, 0, -1) else away.Unit
end

--- The vertical face pointing furthest away from the middle, for an upright tablet.
local function outwardFace(part: BasePart, away: Vector3): Enum.NormalId
	local bestFace = Enum.NormalId.Front
	local bestDot = -math.huge
	for _, entry in FACE_NORMALS do
		local face: Enum.NormalId = entry[1]
		local localNormal: Vector3 = entry[2]
		local dot = part.CFrame:VectorToWorldSpace(localNormal):Dot(away)
		if dot > bestDot then
			bestDot = dot
			bestFace = face
		end
	end
	return bestFace
end

--[[
	The SurfaceGui itself, on a host part and a face chosen by the caller. Shared so an
	authored `PlaqueSurface` and a generated one produce an identical plaque.
]]
local function buildPlaque(host: BasePart, face: Enum.NormalId): Tablet
	local gui = Instance.new("SurfaceGui")
	gui.Name = "RichestPlaque"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	-- Unlit, so the plaque reads the same whatever the spotlight is doing.
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ZOffset = PLAQUE_Z_OFFSET
	gui.Adornee = host
	gui.Parent = host

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Text = "RICHEST PLAYER"
	styleLabel(
		header,
		HEADER_COLOR,
		Enum.Font.GothamBlack,
		UDim2.fromScale(0, 0.04),
		UDim2.fromScale(1, 0.26)
	)
	header.Parent = gui

	local name = Instance.new("TextLabel")
	name.Name = "PlayerName"
	name.Text = "WAITING FOR PLAYER"
	styleLabel(
		name,
		NAME_COLOR,
		Enum.Font.GothamBlack,
		UDim2.fromScale(0, 0.3),
		UDim2.fromScale(1, 0.42)
	)
	name.Parent = gui

	local cash = Instance.new("TextLabel")
	cash.Name = "Cash"
	cash.Text = "$0 CASH"
	styleLabel(
		cash,
		CASH_COLOR,
		Enum.Font.GothamBold,
		UDim2.fromScale(0, 0.72),
		UDim2.fromScale(1, 0.26)
	)
	cash.Parent = gui

	return { header = header, name = name, cash = cash }
end

--- The three labels of a plaque, or nil when one is missing.
local function labelsOf(gui: SurfaceGui): Tablet?
	local header = gui:FindFirstChild("Header")
	local name = gui:FindFirstChild("PlayerName")
	local cash = gui:FindFirstChild("Cash")
	if
		header
		and header:IsA("TextLabel")
		and name
		and name:IsA("TextLabel")
		and cash
		and cash:IsA("TextLabel")
	then
		return { header = header, name = name, cash = cash }
	end
	return nil
end

--[[
	The plaque for one tablet: RICHEST PLAYER over the name over the cash.

	AUTHORED PLAQUES WIN. If a tablet already has a `PlaqueSurface` part, that part's
	position, size and rotation are left exactly alone -- nudge it in Studio and the
	change sticks. If it also carries a complete `RichestPlaque`, that is reused
	wholesale, so restyling the labels by hand survives too.

	Only what is missing gets built. A `PlaqueSurface` with no GUI on it gets one; a
	tablet with neither gets both, placed by the geometry rules below. That way the
	pedestal works out of the box and is still hand-tunable.
]]
local function buildTablet(part: BasePart, centre: Vector3, surfaceY: number): Tablet
	local away = outwardOf(part, centre)
	local size = part.Size
	local isFlat = size.X * size.Z > math.max(size.Z * size.Y, size.X * size.Y)

	local authored = part:FindFirstChild("PlaqueSurface")
	if authored and authored:IsA("BasePart") then
		local existing = authored:FindFirstChild("RichestPlaque")
		if existing and existing:IsA("SurfaceGui") then
			local labels = labelsOf(existing)
			if labels then
				return labels
			end
			-- Half-built: keep the authored part, replace the GUI.
			existing:Destroy()
		end
		return buildPlaque(authored, Enum.NormalId.Top)
	end

	local stale = part:FindFirstChild("RichestPlaque")
	if stale then
		stale:Destroy()
	end

	local host: BasePart = part
	local face = Enum.NormalId.Top

	if isFlat then
		--[[
			Extents resolved against the pedestal rather than the part's own axes, so a
			tablet on the north side and one on the east side both come out the same shape.
		]]
		local radial = math.abs(away.X) * size.X + math.abs(away.Z) * size.Z
		local tangential = math.abs(away.Z) * size.X + math.abs(away.X) * size.Z

		local surface = Instance.new("Part")
		surface.Name = "PlaqueSurface"
		-- X is radial, Z is the reading direction. See the mapping note above.
		surface.Size = Vector3.new(radial, PLAQUE_THICKNESS, tangential)
		local restsOn = math.max(partTopY(part), surfaceY)
		surface.CFrame = CFrame.fromMatrix(
			Vector3.new(
				part.Position.X,
				restsOn + PLAQUE_CLEARANCE + PLAQUE_THICKNESS / 2,
				part.Position.Z
			),
			away,
			Vector3.yAxis
		)
		surface.Anchored = true
		surface.CanCollide = false
		surface.CanTouch = false
		surface.CanQuery = false
		surface.Massless = true
		surface.Transparency = PLAQUE_HOST_TRANSPARENCY
		surface.Parent = part
		host = surface
	else
		face = outwardFace(part, away)
	end

	return buildPlaque(host, face)
end

local function buildTablets(pedestal: Instance): { Tablet }
	local centre = horizontalCentre(pedestal)
	-- Plaques have to clear this, not just their own tablet. See PLAQUE_CLEARANCE.
	local surfaceY = standSurfaceY(pedestal)
	local tablets = {}
	for _, child in pedestal:GetChildren() do
		if not string.match(child.Name, TABLET_PATTERN) then
			continue
		end
		-- A tablet is authored as a Model wrapping one MeshPart, but tolerate a bare part.
		local part = if child:IsA("BasePart")
			then child :: BasePart
			else child:FindFirstChildWhichIsA("BasePart", true)
		if part then
			table.insert(tablets, buildTablet(part, centre, surfaceY))
		end
	end
	return tablets
end

local function writeTablets(tablets: { Tablet }, nameText: string, cashText: string)
	for _, tablet in tablets do
		tablet.name.Text = nameText
		tablet.cash.Text = cashText
	end
end

--------------------------------------------------------------------------------
-- The statue
--------------------------------------------------------------------------------

local function findWinner(): (Player?, number)
	local winner: Player? = nil
	local highestMoney = -1
	for _, player in Players:GetPlayers() do
		local state = PlayerStateService.GetPublicState(player)
		if state then
			local money = math.max(0, state.Money or 0)
			if
				money > highestMoney
				or (money == highestMoney and winner ~= nil and player.UserId < winner.UserId)
			then
				winner = player
				highestMoney = money
			end
		end
	end
	return winner, math.max(0, highestMoney)
end

--[[
	The lowest point the avatar actually occupies, preferring the feet.

	This is what makes the statue sit flush. The old code derived the standing height
	from `Humanoid.HipHeight` and then needed a hand-tuned `HeightOffset` of 3.45
	studs on top -- a fudge calibrated against the old podium, which is why it floats
	on any other surface. Measuring the rig instead is self-correcting: it holds for
	any scale, any rig, and any accessory.

	Feet first, whole bounding box as a fallback. The box includes hair and tails,
	which can hang below the soles on some avatars and would sink the statue.
]]
local function avatarBottomY(avatar: Model): number
	local lowest = math.huge
	for _, footName in { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" } do
		local foot = avatar:FindFirstChild(footName)
		if foot and foot:IsA("BasePart") then
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						local corner =
							foot.CFrame:PointToWorldSpace(foot.Size * Vector3.new(x, y, z) / 2)
						lowest = math.min(lowest, corner.Y)
					end
				end
			end
		end
	end
	if lowest < math.huge then
		return lowest
	end
	local boundsCFrame, boundsSize = avatar:GetBoundingBox()
	return boundsCFrame.Position.Y - boundsSize.Y / 2
end

local function createWinnerAvatar(
	displayRoot: Folder,
	pedestal: Instance,
	player: Player,
	danceAnimationId: string,
	avatarScale: number,
	heightOffset: number,
	rotationSeconds: number
)
	avatarGeneration += 1
	local generation = avatarGeneration
	displayRoot:ClearAllChildren()

	local succeeded, avatar = pcall(function()
		return Players:CreateHumanoidModelFromUserIdAsync(player.UserId)
	end)
	if not succeeded or avatar == nil then
		warn(`[RichestPlayerService] Could not create avatar for {player.Name}`)
		return
	end

	avatar.Name = "WinnerAvatar"
	local humanoid = avatar:FindFirstChildOfClass("Humanoid")
	local rootPart = avatar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid == nil or rootPart == nil then
		avatar:Destroy()
		return
	end

	--[[
		The tablets carry the name and the cash now, so the built-in nameplate is
		switched off -- it was a third copy of the same text, on top of the plaques and
		the overhead plate.
	]]
	humanoid.DisplayName = player.DisplayName
	humanoid.NameDisplayDistance = 0
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.AutoRotate = false

	for _, descendant in avatar:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
	rootPart.Anchored = true
	avatar.Parent = displayRoot
	avatar:ScaleTo(math.max(0.1, avatarScale))

	--[[
		`ScaleTo` does not move the limbs in the same frame -- the rig re-solves on the
		next physics step. Measured: straight after `ScaleTo(5)` the feet still report
		their unscaled offset, so the lift below came out 11.4 studs short and the statue
		sank into the pedestal a frame later. One Heartbeat is enough; two for margin.

		Yielding means a newer winner could have superseded this build, so every wait is
		followed by a generation check.
	]]
	local function superseded(): boolean
		return generation ~= avatarGeneration or avatar.Parent == nil
	end

	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()
	if superseded() then
		avatar:Destroy()
		return
	end

	--[[
		Face the way the pedestal's front faces, or straight down -Z when the pedestal
		is a Model with no meaningful orientation of its own.
	]]
	local orientation = if pedestal:IsA("BasePart")
		then pedestal.CFrame
		else (pedestal :: Model):GetBoundingBox()
	local horizontalLook = Vector3.new(orientation.LookVector.X, 0, orientation.LookVector.Z)
	horizontalLook = if horizontalLook.Magnitude < 0.1
		then Vector3.new(0, 0, 1)
		else horizontalLook.Unit

	--[[
		Centred on the pedestal, then dropped so the soles meet its top surface exactly.
		`heightOffset` is a deliberate nudge on top of flush, not the correction that
		used to be doing the whole job.
	]]
	local targetBottom = standSurfaceY(pedestal) + heightOffset

	--- Move the statue so its soles land on the target. Returns how far it had to go.
	local function snapToSurface(): number
		local delta = targetBottom - avatarBottomY(avatar)
		if math.abs(delta) > 0.001 then
			avatar:PivotTo(avatar:GetPivot() + Vector3.new(0, delta, 0))
		end
		return delta
	end

	local centre = horizontalCentre(pedestal)
	avatar:PivotTo(CFrame.lookAt(centre, centre + horizontalLook))
	snapToSurface()

	--[[
		Snap again once the rig has settled into the scaled pose. The first snap is right
		for the geometry it measured; this one absorbs whatever the re-solve moved.

		Still not the last word -- the dance re-poses the legs again, so the real snap
		happens further down once it is playing.
	]]
	RunService.Heartbeat:Wait()
	if superseded() then
		avatar:Destroy()
		return
	end
	snapToSurface()

	local boundsCFrame, boundsSize = avatar:GetBoundingBox()
	local nameplate = Instance.new("BillboardGui")
	nameplate.Name = "OverheadNameplate"
	nameplate.Adornee = rootPart
	nameplate.AlwaysOnTop = true
	nameplate.MaxDistance = 500
	-- Scale components are world-space studs, so the plate follows perspective instead
	-- of remaining a fixed number of screen pixels as the camera moves.
	nameplate.Size = UDim2.fromScale(8, 1.9)
	nameplate.StudsOffsetWorldSpace =
		Vector3.new(0, boundsCFrame.Position.Y + boundsSize.Y / 2 - rootPart.Position.Y + 2, 0)
	nameplate.Parent = rootPart

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PlayerName"
	styleLabel(
		nameLabel,
		NAME_COLOR,
		Enum.Font.GothamBlack,
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 0.62)
	)
	nameLabel.Text = player.DisplayName:upper()
	nameLabel.Parent = nameplate

	local cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "Cash"
	styleLabel(
		cashLabel,
		CASH_COLOR,
		Enum.Font.GothamBold,
		UDim2.fromScale(0, 0.62),
		UDim2.fromScale(1, 0.38)
	)
	cashLabel.Text = "$0 CASH"
	cashLabel.Parent = nameplate

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local animation = Instance.new("Animation")
	animation.Name = "WinnerDance"
	animation.AnimationId = danceAnimationId
	local loaded, track = pcall(animator.LoadAnimation, animator, animation)
	animation:Destroy()
	if loaded and track then
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Action
		track:Play(0.25)
	end

	--[[
		Flush, for something that is dancing, is not one number: the soles should touch
		the disc at the lowest point of the routine and lift off it during, never sink
		through it. A single measurement cannot express that -- this dance swings the feet
		through 2.1 studs, so snapping on one frame left the statue up to 2.7 studs under
		the surface, and sampling a fixed window only worked if the window happened to
		contain the deepest pose. Capped at 2.5s it did not: still 0.6 short.

		So the rule is enforced continuously rather than solved once. Each frame, if the
		current pose would dip through the disc, the anchor rises by exactly the
		shortfall. That converges within one cycle, cannot overshoot because it only ever
		lifts, and needs to know nothing about the animation's length or shape.
	]]
	local displayPivot = avatar:GetPivot()

	task.spawn(function()
		local angle = 0
		while avatar.Parent and generation == avatarGeneration do
			local deltaTime = RunService.Heartbeat:Wait()
			angle = (angle + deltaTime * math.pi * 2 / math.max(1, rotationSeconds)) % (math.pi * 2)
			avatar:PivotTo(displayPivot * CFrame.Angles(0, angle, 0))

			local sink = targetBottom - avatarBottomY(avatar)
			if sink > 0.001 then
				displayPivot = displayPivot + Vector3.new(0, sink, 0)
				avatar:PivotTo(displayPivot * CFrame.Angles(0, angle, 0))
			end
		end
	end)
end

function RichestPlayerService.Start()
	local map = assert(workspace:FindFirstChild("NewMap"), "NewMap missing")
	local display = assert(map:FindFirstChild("RichestPlayer"), "NewMap.RichestPlayer missing")
	local editorPreview = display:FindFirstChild("EditorPreview")
	if editorPreview then
		editorPreview:Destroy()
	end

	--[[
		The pedestal, preferred in the order it is most likely to be authored: inside
		the display, loose in Workspace, or -- for the original setup -- the flat
		`Podium` part this replaced.
	]]
	local pedestal = display:FindFirstChild("CharacterPedestal")
		or workspace:FindFirstChild("CharacterPedestal")
		or display:FindFirstChild("Podium")
	assert(pedestal, "RichestPlayer needs a CharacterPedestal model (or a legacy Podium part)")

	local displayRoot =
		assert(display:FindFirstChild("DisplayCharacter"), "DisplayCharacter missing") :: Folder

	--[[
		Anchor before anything is measured. Every position below -- the stand surface,
		the centre, each tablet's outward face -- is read off this geometry, so it has
		to be still first.
	]]
	anchorPedestal(pedestal)

	local tablets = buildTablets(pedestal)
	if #tablets == 0 then
		warn(
			`[RichestPlayerService] No tablets found under {pedestal:GetFullName()} -- `
				.. `expected children named like "Tablet1".`
		)
	end

	--[[
		The authored billboard is optional now. Where it exists it is kept updated in
		place, but it is no longer moved onto the avatar's head: between the plaques,
		the overhead plate and Roblox's own nameplate the winner had the same text on
		screen three times.
	]]
	local billboardName: TextLabel? = nil
	local billboardCash: TextLabel? = nil
	local legacyBillboard = pedestal:FindFirstChild("WinnerBillboard", true)
	if legacyBillboard then
		local panel = legacyBillboard:FindFirstChild("Panel")
		if panel then
			billboardName = panel:FindFirstChild("PlayerName") :: TextLabel?
			billboardCash = panel:FindFirstChild("Cash") :: TextLabel?
		end
	end

	local danceAnimationId = display:GetAttribute("DanceAnimationId")
	assert(typeof(danceAnimationId) == "string", "RichestPlayer DanceAnimationId missing")
	local avatarScale = display:GetAttribute("AvatarScale")
	local heightOffset = display:GetAttribute("HeightOffset")
	local rotationSeconds = display:GetAttribute("RotationSeconds")

	task.spawn(function()
		while display.Parent do
			local winner, money = findWinner()
			local nameText, cashText

			if winner == nil then
				currentWinnerUserId = 0
				avatarGeneration += 1
				displayRoot:ClearAllChildren()
				nameText, cashText = "WAITING FOR PLAYER", "$0 CASH"
			else
				nameText = winner.DisplayName:upper()
				cashText = `$ {compact(money)} CASH`
				if currentWinnerUserId ~= winner.UserId then
					currentWinnerUserId = winner.UserId
					createWinnerAvatar(
						displayRoot,
						pedestal,
						winner,
						danceAnimationId,
						if typeof(avatarScale) == "number" then avatarScale else 5,
						--[[
							Zero by default. The stand height is measured off the rig now, so
							this is a nudge for art reasons rather than the correction that used
							to be doing the whole job.
						]]
						if typeof(heightOffset) == "number" then heightOffset else 0,
						if typeof(rotationSeconds) == "number" then rotationSeconds else 10
					)
				end
				local avatar = displayRoot:FindFirstChild("WinnerAvatar")
				local overhead = avatar and avatar:FindFirstChild("OverheadNameplate", true)
				local overheadCash = overhead and overhead:FindFirstChild("Cash")
				if overheadCash and overheadCash:IsA("TextLabel") then
					overheadCash.Text = cashText
				end
			end

			writeTablets(tablets, nameText, cashText)
			if billboardName then
				billboardName.Text = nameText
			end
			if billboardCash then
				billboardCash.Text = cashText
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return table.freeze(RichestPlayerService)
