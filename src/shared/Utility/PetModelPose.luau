--!strict
--[[
	PetModelPose.luau
	How a pet model faces, independent of whatever the exporter left on the pivot.

	The authored pets do not share a pivot convention. Pup looks along the pivot
	-Z and is stored upside down; the other Junkyard pets look along -X. The UI
	already ignores the pivot and reads `AnimatedFace` (Decal on Front = the
	part's LookVector). Followers have to do the same, or Pup stands on its head
	and ScaleTo measures the wrong box.
]]

local PetModelPose = {}

local FACE_NAMES = { "AnimatedFace", "Face", "Head" }

function PetModelPose.facePart(model: Model): BasePart?
	for _, name in FACE_NAMES do
		local part = model:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function rotationFromLookUp(look: Vector3, up: Vector3): CFrame
	local right = look:Cross(up)
	if right.Magnitude < 0.01 then
		up = Vector3.yAxis
		right = look:Cross(up)
	end
	if right.Magnitude < 0.01 then
		return CFrame.identity
	end
	right = right.Unit
	local orthonormalUp = right:Cross(look).Unit
	return CFrame.fromMatrix(Vector3.zero, right, orthonormalUp, -look)
end

--[[
	Pivot-space rotation of the face: identity means "the pivot already faces
	LookVector -Z with Up +Y", which is what `CFrame.lookAt` assumes.
]]
function PetModelPose.faceRotationInPivot(model: Model): CFrame
	local face = PetModelPose.facePart(model)
	if face == nil then
		return CFrame.identity
	end
	local faceInPivot = model:GetPivot():ToObjectSpace(face.CFrame)
	return rotationFromLookUp(faceInPivot.LookVector, faceInPivot.UpVector)
end

--[[
	World CFrame to `PivotTo` so the pet stands at `position`, faces along `look`
	(flattened to the ground), and its face Up matches world Up.
]]
function PetModelPose.worldPivot(
	model: Model,
	position: Vector3,
	look: Vector3,
	faceRotation: CFrame?
): CFrame
	local flat = Vector3.new(look.X, 0, look.Z)
	local lookFlat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local desired = CFrame.lookAt(Vector3.zero, lookFlat)
	local faceRot = faceRotation or PetModelPose.faceRotationInPivot(model)
	return CFrame.new(position) * desired * faceRot:Inverse()
end

--[[
	Axis-aligned world box the pet would occupy if stood facing -Z at the origin.
	`GetExtentsSize` is in pivot space, so a model stored on its side or head reports
	a box that has nothing to do with how it looks behind the player.
]]
function PetModelPose.standingBounds(model: Model, faceRotation: CFrame?): (Vector3, Vector3)
	local standing =
		PetModelPose.worldPivot(model, Vector3.zero, Vector3.new(0, 0, -1), faceRotation)
	local pivot = model:GetPivot()
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = Vector3.new(-math.huge, -math.huge, -math.huge)
	local any = false
	for _, descendant in model:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end
		any = true
		local world = standing * pivot:ToObjectSpace(descendant.CFrame)
		local half = descendant.Size * 0.5
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local corner = world * Vector3.new(half.X * x, half.Y * y, half.Z * z)
					min = min:Min(corner)
					max = max:Max(corner)
				end
			end
		end
	end
	if not any then
		return Vector3.zero, Vector3.zero
	end
	return min, max
end

function PetModelPose.standingExtents(model: Model, faceRotation: CFrame?): Vector3
	local min, max = PetModelPose.standingBounds(model, faceRotation)
	return max - min
end

--[[
	Pivot-local offset from the pivot to the visual bottom-centre, in the standing
	pose. Followers add this so every pet hovers at the same height even when the
	exporter left the pivot in the head, the feet, or off to one side.
]]
function PetModelPose.hoverLocalOffset(model: Model, faceRotation: CFrame?): Vector3
	local min, max = PetModelPose.standingBounds(model, faceRotation)
	local bottomCentre = Vector3.new((min.X + max.X) * 0.5, min.Y, (min.Z + max.Z) * 0.5)
	local standing =
		PetModelPose.worldPivot(model, Vector3.zero, Vector3.new(0, 0, -1), faceRotation)
	return standing:PointToObjectSpace(bottomCentre)
end

--[[
	Authored pet models often carry a Highlight or a coloured light from Studio.
	Those clone onto followers and wash the whole body (the red hue). Followers
	should look like the art.
]]
function PetModelPose.stripStudioFx(model: Model)
	for _, item in model:GetDescendants() do
		if item:IsA("Highlight") or item:IsA("SelectionBox") or item:IsA("Light") then
			item:Destroy()
		end
	end
	local rootHighlight = model:FindFirstChildWhichIsA("Highlight")
	if rootHighlight then
		rootHighlight:Destroy()
	end
end

return table.freeze(PetModelPose)
