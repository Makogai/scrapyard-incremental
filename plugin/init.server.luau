--!strict
--[[
	Resurface
	Paint a tiled Texture onto any part, with controls, and take it back off again.

	Works in any place. Nothing here knows about a particular game -- the way you reproduce a look that
	already exists in your world is PICK FROM PART, which reads a surface you point at and loads its exact
	settings into the panel.

	WHAT IT DOES
		Paint mode      click parts in the viewport to apply the current settings
		Selection       apply to everything selected, including parts inside selected models
		Pick            read settings back off a part that already looks right
		Strip           remove only the textures this plugin created

	EVERY WRITE IS UNDOABLE. Each action is wrapped in a ChangeHistoryService recording, so Ctrl+Z takes
	back a whole paint rather than one property at a time. That is not politeness -- a plugin that can
	touch thousands of parts and cannot be undone is a plugin that eventually eats somebody's map.

	IT ONLY DELETES ITS OWN WORK. Textures the plugin creates get a `ResurfacePlugin` attribute, and Strip
	uses that. Without it the only way to clear a part would be deleting every Texture on it, including
	hand-placed ones that were there first.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local Panel = require(script.Panel)
local Presets = require(script.Presets)

local settings = Presets.default()
local paintMode = false

local toolbar = plugin:CreateToolbar("Resurface")
local toggleButton = toolbar:CreateButton(
	"Resurface",
	"Paint tiled textures onto parts",
	"rbxasset://textures/ui/GuiImagePlaceholder.png"
)
toggleButton.ClickableWhenViewportHidden = true

local widget = plugin:CreateDockWidgetPluginGui(
	"ResurfacePanel",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 240, 520, 240, 360)
)
widget.Title = "Resurface"
widget.Name = "Resurface"

--[[
	Undo wrapping, tolerant of both APIs.

	`TryBeginRecording`/`FinishRecording` is the current way and groups a whole action into one undo step.
	Older Studio builds only have `SetWaypoint`, which is coarser but still undoable. Wrapped in `pcall`
	because a plugin that errors on an unfamiliar Studio version is worse than one that undoes clumsily.
]]
local function recorded(name: string, body: () -> ())
	local identifier: string? = nil
	local began = pcall(function()
		identifier = ChangeHistoryService:TryBeginRecording(name, name)
	end)

	local ok, err = pcall(body)

	if began and identifier ~= nil then
		pcall(function()
			ChangeHistoryService:FinishRecording(
				identifier,
				if ok
					then Enum.FinishRecordingOperation.Commit
					else Enum.FinishRecordingOperation.Cancel
			)
		end)
	else
		pcall(function()
			ChangeHistoryService:SetWaypoint(name)
		end)
	end

	if not ok then
		warn("[Resurface] " .. tostring(err))
	end
end

--[[
	Write one Texture. Reuses an existing one on the same face rather than stacking a second on top of it,
	which is what made repeated clicks on the same wall quietly pile up invisible duplicates.
]]
local function applyFace(part: BasePart, face: Enum.NormalId)
	local existing: Texture? = nil
	for _, child in part:GetChildren() do
		if child:IsA("Texture") and child.Face == face then
			existing = child
			break
		end
	end

	local texture = existing or Instance.new("Texture")
	texture.Face = face
	texture.Texture = settings.TextureId
	texture.Color3 = settings.Color
	texture.Transparency = settings.Transparency
	texture.Rotation = settings.Rotation
	texture.StudsPerTileU = settings.StudsPerTileU
	texture.StudsPerTileV = settings.StudsPerTileV
	texture.OffsetStudsU = settings.OffsetStudsU
	texture.OffsetStudsV = settings.OffsetStudsV
	texture:SetAttribute(Presets.Marker, true)
	texture.Parent = part
end

local function applyTo(part: BasePart)
	if settings.AllFaces then
		for _, face in Presets.Faces do
			applyFace(part, (Enum.NormalId :: any)[face])
		end
	else
		applyFace(part, (Enum.NormalId :: any)[settings.Face])
	end
end

--- Every BasePart in a selection, including the ones inside selected models.
local function partsFrom(instances: { Instance }): { BasePart }
	local parts = {}
	local seen = {}
	for _, instance in instances do
		if instance:IsA("BasePart") and not seen[instance] then
			seen[instance] = true
			table.insert(parts, instance)
		end
		for _, descendant in instance:GetDescendants() do
			if descendant:IsA("BasePart") and not seen[descendant] then
				seen[descendant] = true
				table.insert(parts, descendant)
			end
		end
	end
	return parts
end

local handle
handle = Panel.build(widget, settings, function()
	--- Settings changed. Nothing repaints retroactively: the next click uses the new values.
	handle.SetStatus("Settings updated.")
end, function(action: string)
	if action == "paint" then
		paintMode = not paintMode
		handle.SetPaintMode(paintMode)
		if paintMode then
			plugin:Activate(true)
			handle.SetStatus("Paint mode on. Click parts in the viewport.")
		else
			plugin:Deactivate()
			handle.SetStatus("Paint mode off.")
		end
		return
	end

	if action == "selection" then
		local parts = partsFrom(Selection:Get())
		if #parts == 0 then
			handle.SetStatus("Nothing selected.")
			return
		end
		recorded("Resurface selection", function()
			for _, part in parts do
				applyTo(part)
			end
		end)
		handle.SetStatus(`Painted {#parts} part{if #parts == 1 then "" else "s"}.`)
		return
	end

	if action == "pick" then
		local parts = partsFrom(Selection:Get())
		local source: Texture? = nil
		for _, part in parts do
			for _, child in part:GetChildren() do
				if child:IsA("Texture") then
					source = child
					break
				end
			end
			if source ~= nil then
				break
			end
		end
		if source == nil then
			handle.SetStatus("Select a part that already has a Texture, then pick.")
			return
		end
		settings.TextureId = source.Texture
		settings.Face = source.Face.Name
		settings.Color = source.Color3
		settings.Transparency = source.Transparency
		settings.Rotation = source.Rotation
		settings.StudsPerTileU = source.StudsPerTileU
		settings.StudsPerTileV = source.StudsPerTileV
		settings.OffsetStudsU = source.OffsetStudsU
		settings.OffsetStudsV = source.OffsetStudsV
		settings.LockSquare = source.StudsPerTileU == source.StudsPerTileV
		handle.Refresh()
		handle.SetStatus(`Picked from {source.Parent and source.Parent.Name or "part"}.`)
		return
	end

	if action == "strip" then
		local parts = partsFrom(Selection:Get())
		if #parts == 0 then
			handle.SetStatus("Nothing selected.")
			return
		end
		local removed = 0
		recorded("Resurface strip", function()
			for _, part in parts do
				for _, child in part:GetChildren() do
					--- Only ours. See the note at the top about why the marker exists.
					if child:IsA("Texture") and child:GetAttribute(Presets.Marker) == true then
						child:Destroy()
						removed += 1
					end
				end
			end
		end)
		handle.SetStatus(`Removed {removed} texture{if removed == 1 then "" else "s"}.`)
		return
	end
end)

--[[
	Click-to-paint.

	`plugin:GetMouse()` only reports targets while the plugin is activated, which is why paint mode calls
	`Activate`. Guarded on `paintMode` as well, because deactivation and the last queued click can race.
]]
local mouse = plugin:GetMouse()
mouse.Button1Down:Connect(function()
	if not paintMode then
		return
	end
	local target = mouse.Target
	if target == nil then
		return
	end
	recorded("Resurface part", function()
		applyTo(target)
	end)
	handle.SetStatus(`Painted {target.Name}.`)
end)

toggleButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

--- Leaving paint mode armed across a plugin deactivation would keep swallowing viewport clicks.
plugin.Deactivation:Connect(function()
	if paintMode then
		paintMode = false
		handle.SetPaintMode(false)
		handle.SetStatus("Paint mode off.")
	end
end)

plugin.Unloading:Connect(function()
	widget:Destroy()
end)
