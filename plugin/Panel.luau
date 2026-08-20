--!strict
--[[
	Panel.luau
	The dock widget: every control, and nothing else.

	NO STUDIO API IN HERE. This module builds instances and reports changes through `onChange`; it never
	touches Selection, the mouse or ChangeHistoryService. That split is what makes the painting logic
	testable by reading it -- all the irreversible behaviour lives in `init.server`, and everything here is
	just widgets.

	BUILT FROM PLAIN INSTANCES rather than a UI library. A plugin widget cannot borrow a game's React tree,
	and hand-rolled rows are less code than wiring a framework into a build that has no other need for one.

	Numbers are committed on FocusLost, not per keystroke: a half-typed "0.8" passes through "0." and "0",
	and applying those live means every drag of a value repaints the world twice on its way to the number
	you wanted.
]]

local Presets = require(script.Parent.Presets)

local Panel = {}

local BACKGROUND = Color3.fromRGB(46, 46, 46)
local FIELD = Color3.fromRGB(30, 30, 30)
local TEXT = Color3.fromRGB(235, 235, 235)
local MUTED = Color3.fromRGB(160, 160, 160)
local ACCENT = Color3.fromRGB(0, 132, 255)
local ROW = 24
local PAD = 8

local function label(parent: Instance, text: string, y: number, width: number): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Text = text
	item.TextColor3 = MUTED
	item.TextSize = 13
	item.Font = Enum.Font.Gotham
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Size = UDim2.fromOffset(width, ROW)
	item.Position = UDim2.fromOffset(PAD, y)
	item.Parent = parent
	return item
end

local function box(parent: Instance, value: string, x: number, y: number, width: number): TextBox
	local item = Instance.new("TextBox")
	item.BackgroundColor3 = FIELD
	item.BorderSizePixel = 0
	item.Text = value
	item.TextColor3 = TEXT
	item.TextSize = 13
	item.Font = Enum.Font.Code
	item.ClearTextOnFocus = false
	item.Size = UDim2.fromOffset(width, ROW)
	item.Position = UDim2.fromOffset(x, y)
	item.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = item
	return item
end

local function button(
	parent: Instance,
	text: string,
	x: number,
	y: number,
	width: number
): TextButton
	local item = Instance.new("TextButton")
	item.BackgroundColor3 = FIELD
	item.BorderSizePixel = 0
	item.AutoButtonColor = true
	item.Text = text
	item.TextColor3 = TEXT
	item.TextSize = 13
	item.Font = Enum.Font.GothamMedium
	item.Size = UDim2.fromOffset(width, ROW)
	item.Position = UDim2.fromOffset(x, y)
	item.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = item
	return item
end

local function toNumber(text: string, fallback: number): number
	local value = tonumber(text)
	if value == nil or value ~= value then
		return fallback
	end
	return value
end

--[[
	Build the whole panel.

	`onChange` fires whenever a control moves, with the full settings table -- not a delta. A caller that
	always receives the complete state cannot get out of step with the panel, which is the failure mode of
	passing "what changed".

	`onAction` fires for the buttons: "selection", "pick", "strip", "paint".
]]
function Panel.build(
	parent: Instance,
	settings: Presets.Settings,
	onChange: (Presets.Settings) -> (),
	onAction: (string) -> ()
)
	local root = Instance.new("Frame")
	root.BackgroundColor3 = BACKGROUND
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = parent

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.fromOffset(0, 470)
	scroll.ScrollBarThickness = 6
	scroll.Parent = root

	local y = PAD

	----------------------------------------------------------------- texture
	label(scroll, "TEXTURE", y, 120)
	y += ROW
	--- Preset buttons, two per row, then a free-text id for anything not listed.
	local textureButtons: { [string]: TextButton } = {}
	for index, preset in Presets.Textures do
		local column = (index - 1) % 2
		local item = button(scroll, preset.Name, PAD + column * 108, y, 100)
		textureButtons[preset.Id] = item
		item.Activated:Connect(function()
			settings.TextureId = preset.Id
			for id, other in textureButtons do
				other.BackgroundColor3 = if id == preset.Id then ACCENT else FIELD
			end
			onChange(settings)
		end)
		if column == 1 or index == #Presets.Textures then
			y += ROW + 4
		end
	end
	for id, item in textureButtons do
		item.BackgroundColor3 = if id == settings.TextureId then ACCENT else FIELD
	end

	label(scroll, "ID", y, 30)
	local idBox = box(scroll, settings.TextureId, PAD + 34, y, 174)
	idBox.FocusLost:Connect(function()
		--- Accept a bare number as well as a full rbxassetid:// url; typing the id is what people do.
		local text = idBox.Text
		if tonumber(text) ~= nil then
			text = "rbxassetid://" .. text
		end
		settings.TextureId = text
		idBox.Text = text
		for id, item in textureButtons do
			item.BackgroundColor3 = if id == text then ACCENT else FIELD
		end
		onChange(settings)
	end)
	y += ROW + PAD

	----------------------------------------------------------------- faces
	label(scroll, "FACE", y, 120)
	y += ROW
	local faceButtons: { [string]: TextButton } = {}
	local allButton: TextButton

	local function refreshFaces()
		for face, item in faceButtons do
			item.BackgroundColor3 = if not settings.AllFaces and settings.Face == face
				then ACCENT
				else FIELD
		end
		allButton.BackgroundColor3 = if settings.AllFaces then ACCENT else FIELD
	end

	for index, face in Presets.Faces do
		local column = (index - 1) % 3
		local item = button(scroll, face, PAD + column * 72, y, 66)
		faceButtons[face] = item
		item.Activated:Connect(function()
			settings.Face = face
			settings.AllFaces = false
			refreshFaces()
			onChange(settings)
		end)
		if column == 2 then
			y += ROW + 4
		end
	end
	allButton = button(scroll, "ALL SIX", PAD, y, 210)
	allButton.Activated:Connect(function()
		settings.AllFaces = true
		refreshFaces()
		onChange(settings)
	end)
	refreshFaces()
	y += ROW + PAD

	----------------------------------------------------------------- look
	label(scroll, "TINT (HEX)", y, 90)
	local colourBox = box(scroll, "#" .. settings.Color:ToHex(), PAD + 96, y, 112)
	colourBox.FocusLost:Connect(function()
		local ok, colour = pcall(function()
			return Color3.fromHex((string.gsub(colourBox.Text, "#", "")))
		end)
		if ok then
			settings.Color = colour
		end
		--- Rewrite from the stored value, so a rejected string visibly snaps back instead of lingering.
		colourBox.Text = "#" .. settings.Color:ToHex()
		onChange(settings)
	end)
	y += ROW + 4

	label(scroll, "TRANSPARENCY", y, 90)
	local alphaBox = box(scroll, tostring(settings.Transparency), PAD + 96, y, 112)
	alphaBox.FocusLost:Connect(function()
		settings.Transparency = math.clamp(toNumber(alphaBox.Text, settings.Transparency), 0, 1)
		alphaBox.Text = tostring(settings.Transparency)
		onChange(settings)
	end)
	y += ROW + 4

	label(scroll, "ROTATION", y, 90)
	local rotationBox = box(scroll, tostring(settings.Rotation), PAD + 96, y, 112)
	rotationBox.FocusLost:Connect(function()
		settings.Rotation = toNumber(rotationBox.Text, settings.Rotation) % 360
		rotationBox.Text = tostring(settings.Rotation)
		onChange(settings)
	end)
	y += ROW + PAD

	----------------------------------------------------------------- tiling
	label(scroll, "TILE U / V", y, 90)
	local tileU = box(scroll, tostring(settings.StudsPerTileU), PAD + 96, y, 52)
	local tileV = box(scroll, tostring(settings.StudsPerTileV), PAD + 156, y, 52)

	local function commitTiles(source: TextBox)
		--- Never zero: a zero tile size makes the texture vanish rather than error, which reads as a bug.
		local value = math.max(0.01, toNumber(source.Text, settings.StudsPerTileU))
		if settings.LockSquare then
			settings.StudsPerTileU = value
			settings.StudsPerTileV = value
		elseif source == tileU then
			settings.StudsPerTileU = value
		else
			settings.StudsPerTileV = value
		end
		tileU.Text = tostring(settings.StudsPerTileU)
		tileV.Text = tostring(settings.StudsPerTileV)
		onChange(settings)
	end

	tileU.FocusLost:Connect(function()
		commitTiles(tileU)
	end)
	tileV.FocusLost:Connect(function()
		commitTiles(tileV)
	end)
	y += ROW + 4

	local lockButton = button(scroll, "", PAD, y, 210)
	local function refreshLock()
		lockButton.Text = if settings.LockSquare then "SQUARE TILES: ON" else "SQUARE TILES: OFF"
		lockButton.BackgroundColor3 = if settings.LockSquare then ACCENT else FIELD
	end
	lockButton.Activated:Connect(function()
		settings.LockSquare = not settings.LockSquare
		if settings.LockSquare then
			settings.StudsPerTileV = settings.StudsPerTileU
			tileV.Text = tostring(settings.StudsPerTileV)
		end
		refreshLock()
		onChange(settings)
	end)
	refreshLock()
	y += ROW + 4

	label(scroll, "OFFSET U / V", y, 90)
	local offsetU = box(scroll, tostring(settings.OffsetStudsU), PAD + 96, y, 52)
	local offsetV = box(scroll, tostring(settings.OffsetStudsV), PAD + 156, y, 52)
	offsetU.FocusLost:Connect(function()
		settings.OffsetStudsU = toNumber(offsetU.Text, settings.OffsetStudsU)
		offsetU.Text = tostring(settings.OffsetStudsU)
		onChange(settings)
	end)
	offsetV.FocusLost:Connect(function()
		settings.OffsetStudsV = toNumber(offsetV.Text, settings.OffsetStudsV)
		offsetV.Text = tostring(settings.OffsetStudsV)
		onChange(settings)
	end)
	y += ROW + PAD

	----------------------------------------------------------------- actions
	local paintButton = button(scroll, "PAINT MODE: OFF", PAD, y, 210)
	paintButton.Activated:Connect(function()
		onAction("paint")
	end)
	y += ROW + 4
	button(scroll, "APPLY TO SELECTION", PAD, y, 210).Activated:Connect(function()
		onAction("selection")
	end)
	y += ROW + 4
	button(scroll, "PICK FROM PART", PAD, y, 210).Activated:Connect(function()
		onAction("pick")
	end)
	y += ROW + 4
	button(scroll, "STRIP (PLUGIN TEXTURES)", PAD, y, 210).Activated:Connect(function()
		onAction("strip")
	end)
	y += ROW + PAD

	local status = label(scroll, "Ready.", y, 210)
	status.TextColor3 = MUTED
	status.TextWrapped = true
	status.Size = UDim2.fromOffset(210, ROW * 2)

	scroll.CanvasSize = UDim2.fromOffset(0, y + ROW * 2 + PAD)

	--[[
		The handle back into the panel. `refresh` exists so `Pick from part` can push loaded settings into
		the boxes -- without it the panel would show the old numbers while painting the new ones.
	]]
	return {
		SetStatus = function(text: string)
			status.Text = text
		end,
		SetPaintMode = function(active: boolean)
			paintButton.Text = if active then "PAINT MODE: ON (click parts)" else "PAINT MODE: OFF"
			paintButton.BackgroundColor3 = if active then ACCENT else FIELD
		end,
		Refresh = function()
			idBox.Text = settings.TextureId
			colourBox.Text = "#" .. settings.Color:ToHex()
			alphaBox.Text = tostring(settings.Transparency)
			rotationBox.Text = tostring(settings.Rotation)
			tileU.Text = tostring(settings.StudsPerTileU)
			tileV.Text = tostring(settings.StudsPerTileV)
			offsetU.Text = tostring(settings.OffsetStudsU)
			offsetV.Text = tostring(settings.OffsetStudsV)
			for id, item in textureButtons do
				item.BackgroundColor3 = if id == settings.TextureId then ACCENT else FIELD
			end
			refreshFaces()
			refreshLock()
		end,
	}
end

return Panel
