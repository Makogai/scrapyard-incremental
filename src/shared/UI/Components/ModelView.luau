--!nonstrict
--[[
	ModelView.luau
	Renders a real 3D model inside the UI, in a ViewportFrame.

	Models come from the repositories `PetService` publishes -- `PetModels` keyed by
	pet id, `EggModels` keyed by egg id -- so nothing here reaches into Workspace and
	a missing model degrades to the fallback glyph instead of erroring.

	Two modes:

		normal      the model, lit, facing the camera
		silhouette  the same model as a solid black shape, for a pet the player has
		            not hatched. The outline is the whole point: it says what you are
		            missing without showing it to you.

	`spin` turns the model on its Y axis, starting from the front-facing angle. It
	costs a heartbeat connection per view, so it is off by default and used only
	where a model is the subject -- the hatch reveal, the egg beside the button.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Motion = require(UI.Motion)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)

local e = React.createElement

local ModelView = {}

--- Where a model id is looked up, by kind.
local REPOSITORIES = {
	pet = "PetModels",
	egg = "EggModels",
	scrap = "ScrapPreviews",
}

--- Parts that mark the front of a model, most specific first.
local FACE_NAMES = { "AnimatedFace", "Face", "Head" }

local FIELD_OF_VIEW = 40

--[[
	Clones the model for a kind/id, or nil when it has not been published. Cloned
	rather than reparented: the repository copy is shared and a ViewportFrame owns
	whatever is inside it.

	`id` may be a list of candidates, tried in order. The scrap index uses that to ask
	for the best rarity it has seen and fall back to the plain model -- so a scrap with
	no art for that tier still draws something instead of dropping to a glyph.
]]
local function cloneModel(kind: string, id: (string | { string })?): Model?
	if id == nil then
		return nil
	end
	local folder = ReplicatedStorage:FindFirstChild(REPOSITORIES[kind] or "PetModels")
	if folder == nil then
		return nil
	end
	local candidates = if type(id) == "table" then id else { id }
	for _, candidate in candidates do
		local source = folder:FindFirstChild(candidate)
		if source and source:IsA("Model") then
			return source:Clone()
		end
	end
	return nil
end

--[[
	Which way the model is looking, flattened to the ground plane.

	The pets' pivots disagree -- Pup's points down -Z, every other Junkyard pet's
	down -X -- so the pivot is no use as a front reference. What they all share is an
	`AnimatedFace` part whose Decal sits on `NormalId.Front`, and `Front` is a part's
	-Z face, which is exactly what `CFrame.LookVector` reports. So the face part
	tells us where each pet is looking, per model, with nothing to configure.

	Falls back to the pivot for a model with no face part, such as an egg.
]]
local function facing(model: Model): Vector3
	for _, name in FACE_NAMES do
		local part = model:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			local look = part.CFrame.LookVector
			-- Flattened, so a pet with a tilted head does not tilt the camera.
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.01 then
				return flat.Unit
			end
		end
	end

	local look = model:GetPivot().LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
end

--[[
	Bounding box of the parts you can actually see.

	Workshop and Quantum pets carry invisible Root / AnimatedFace / helper
	meshes at Transparency 1. `GetBoundingBox` includes those, so the camera
	backs up to frame empty volume and the real silhouette shrinks to a speck
	-- which is what made the second egg look like it had no outlines.
]]
local function visibleBounds(model: Model): (CFrame, Vector3)
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	local found = false
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 0.9 then
			found = true
			local cf = part.CFrame
			local size = part.Size
			for _, sx in { -0.5, 0.5 } do
				for _, sy in { -0.5, 0.5 } do
					for _, sz in { -0.5, 0.5 } do
						local world = cf * Vector3.new(size.X * sx, size.Y * sy, size.Z * sz)
						minX = math.min(minX, world.X)
						minY = math.min(minY, world.Y)
						minZ = math.min(minZ, world.Z)
						maxX = math.max(maxX, world.X)
						maxY = math.max(maxY, world.Y)
						maxZ = math.max(maxZ, world.Z)
					end
				end
			end
		end
	end
	if not found then
		return model:GetBoundingBox()
	end
	local centre = Vector3.new((minX + maxX) * 0.5, (minY + maxY) * 0.5, (minZ + maxZ) * 0.5)
	return CFrame.new(centre), Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
end

--[[
	Makes a model render as one solid black shape: no colour, no texture, no eyes.

	Recolouring alone is not enough -- lighting still picks out every edge, which
	reads as "the real pet, dimmed". Neon and ForceField would also light themselves.
	So every surface is turned black *and* forced to a lit material, the caller
	drives the ViewportFrame's own light to black, and surface art is destroyed
	outright because a Decal ignores part colour entirely.
]]
local function silhouette(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Color = Color3.new(0, 0, 0)
			part.Material = Enum.Material.SmoothPlastic
			part.Reflectance = 0
			part.CastShadow = false
			-- MeshPart textures ignore part colour, so a Rainbow Shock silhouette
			-- would still paint its rainbow and read as the real pet, not an outline.
			if part:IsA("MeshPart") then
				part.TextureID = ""
			end
		elseif part:IsA("SpecialMesh") then
			part.TextureId = ""
		elseif
			part:IsA("Decal")
			or part:IsA("Texture")
			or part:IsA("SurfaceAppearance")
			or part:IsA("ParticleEmitter")
			or part:IsA("Beam")
			or part:IsA("Trail")
			or part:IsA("Light")
			or part:IsA("Highlight")
		then
			-- Anything that draws its own colour would survive the blackout.
			part:Destroy()
		end
	end
end

--[[
	props:
		kind        "pet" | "egg", default "pet"
		model       id within that repository
		silhouette  render as a solid black shape
		spin        true, or degrees per second
		zoom        framing multiplier; below 1 fills more of the box
		yaw         degrees swung around the model from dead-on, default 28
		lift        camera height as a fraction of the model radius
		glyph       fallback icon when the model is missing
		size, position, anchorPoint, layoutOrder, zIndex
]]
function ModelView.View(props)
	local kind = props.kind or "pet"
	local viewportRef = React.useRef(nil :: any)

	--[[
		Whether a model actually rendered. The fallback glyph used to be drawn
		unconditionally underneath the viewport, and a ViewportFrame has a transparent
		background -- so every pet had a giant paw showing through behind it. It is
		only a fallback now: no model, no glyph.
	]]
	local hasModel, setHasModel = React.useState(false)

	React.useEffect(function()
		local viewport = viewportRef.current
		if viewport == nil then
			return
		end

		local model = cloneModel(kind, props.model)
		if model == nil then
			setHasModel(false)
			return
		end
		setHasModel(true)

		-- Read the facing before stripping the face part that reveals it.
		local front = facing(model)
		if props.silhouette then
			silhouette(model)
		end
		model.Parent = viewport

		--[[
			Framed from the model's own bounding sphere, so pets of very different
			sizes all fill the same box, and far enough back that the whole extent fits
			the field of view -- nothing important gets cropped.
		]]
		local origin, extent = visibleBounds(model)
		local frame = {
			centre = origin.Position,
			radius = math.max(extent.Magnitude * 0.5, 0.5),
		}

		local camera = Instance.new("Camera")
		camera.FieldOfView = FIELD_OF_VIEW
		camera.Parent = viewport
		viewport.CurrentCamera = camera

		--[[
			A front three-quarter view. The camera sits along the direction the pet is
			looking -- so it sees the face, never the back -- swung `yaw` degrees round
			and lifted so it looks slightly down. Every pet gets the same treatment, so
			the previews are consistent.
		]]
		local baseYaw = props.yaw or 28
		local degrees = baseYaw
		local function look(yaw: number)
			local distance = (frame.radius / math.tan(math.rad(FIELD_OF_VIEW * 0.5)))
				* (props.zoom or 0.94)
			local lift = frame.radius * (props.lift or 0.32)
			local direction = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(yaw)) * front
			local eye = frame.centre + direction * distance + Vector3.new(0, lift, 0)
			camera.CFrame = CFrame.lookAt(eye, frame.centre)
		end
		look(degrees)

		--[[
			A MeshPart's Size can rewrite itself when the mesh finishes loading, which
			makes the first bounds tiny and the model a speck. Five hatch eggs hit that
			at once. Reframe after the current frame, and once more after a short wait.
		]]
		local function reframe()
			if camera.Parent == nil or model.Parent == nil then
				return
			end
			local nextOrigin, nextExtent = visibleBounds(model)
			frame.centre = nextOrigin.Position
			frame.radius = math.max(nextExtent.Magnitude * 0.5, 0.5)
			look(degrees)
		end
		task.defer(reframe)
		local alive = true
		task.delay(0.2, function()
			if alive then
				reframe()
			end
		end)

		if not props.spin then
			return function()
				alive = false
				setHasModel(false)
				model:Destroy()
				camera:Destroy()
			end
		end

		local speed = if type(props.spin) == "number" then props.spin else 45
		local connection = Motion.heartbeat:Connect(function(deltaTime)
			degrees += speed * deltaTime
			look(degrees)
		end)

		return function()
			alive = false
			connection:Disconnect()
			setHasModel(false)
			model:Destroy()
			camera:Destroy()
		end
	end, {
		--[[
			A candidate list is a fresh table every render, so depending on it directly
			would rebuild the viewport every frame. Joining it gives a stable key that
			still changes when the candidates do.
		]]
		if type(props.model) == "table" then table.concat(props.model, "|") else props.model,
		kind,
		props.silhouette,
		props.spin,
		props.zoom,
		props.yaw,
	})

	return e(P.Group, {
		key = props.key or "ModelView",
		size = props.size or UDim2.fromScale(1, 1),
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex,
		children = P.compact(
			e("ViewportFrame", {
				key = "Viewport",
				ref = viewportRef,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				--[[
					Silhouettes get zero light. With no ambient and no light colour every
					surface renders black whatever its material, which is what makes the
					shape read as a shape rather than as the real pet dimmed down.
					Same treatment as the first egg -- a flat black stamp, no rim mesh.
				]]
				Ambient = if props.silhouette
					then Color3.new(0, 0, 0)
					else Color3.fromRGB(235, 240, 255),
				LightColor = if props.silhouette
					then Color3.new(0, 0, 0)
					else Color3.fromRGB(255, 255, 255),
				LightDirection = Vector3.new(-0.4, -1, -0.6),
				ImageTransparency = props.transparency,
				ZIndex = 3,
			}),
			--[[
				The fallback sits *under* the viewport rather than replacing it: a model
				that has not replicated yet arrives a frame later, and swapping the whole
				subtree at that point flickers.
			]]
			if props.glyph and not hasModel
				then e(Icon, {
					key = "Fallback",
					glyph = props.glyph,
					plain = true,
					size = UDim2.fromScale(0.7, 0.7),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					glyphColor = if props.silhouette then Color3.new(0, 0, 0) else nil,
					zIndex = 2,
				})
				else nil
		),
	})
end

return ModelView
