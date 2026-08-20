--!strict
--[[
	Presets.luau
	The texture list, and the settings the panel opens with.

	GAME-AGNOSTIC ON PURPOSE. Nothing here knows about any particular place, model or naming scheme -- drop
	the built plugin into any Studio install and it works on whatever is in front of it. The way you reach a
	look that already exists in YOUR world is `Pick from part`: click a surface that is right, the panel
	loads its exact settings, and you paint the rest with it. That is better than presets baked into code,
	because the source of truth stays the thing you can see.

	ADD TEXTURES BY EDITING THIS LIST. Ids only, no code change anywhere else. A pre-rotated variant of an
	image is just another entry -- `Texture.Rotation` handles most cases, but a pattern whose tiling has to
	rotate WITH it (a checkerboard at 45 degrees still wants square tiles) is cleaner as its own asset.
]]

export type Settings = {
	TextureId: string,
	Face: string,
	Color: Color3,
	Transparency: number,
	Rotation: number,
	StudsPerTileU: number,
	StudsPerTileV: number,
	OffsetStudsU: number,
	OffsetStudsV: number,
	LockSquare: boolean,
	AllFaces: boolean,
}

local Presets = {}

--- Roblox's own free textures, so a fresh install has something to paint with immediately.
Presets.Textures = {
	{ Name = "Checker", Id = "rbxassetid://10630078103" },
	{ Name = "Studs", Id = "rbxassetid://6073841299" },
	{ Name = "Grid", Id = "rbxassetid://2244840070" },
	{ Name = "Noise", Id = "rbxassetid://9084344115" },
}

Presets.Faces = { "Top", "Bottom", "Front", "Back", "Left", "Right" }

--[[
	Neutral defaults: an untinted, opaque, 4-stud tile on every face.

	Deliberately boring. A plugin that opens with somebody else's tint and transparency makes its first
	click look broken -- better to start from "the texture, as authored" and let the panel or a pick move
	you from there.
]]
function Presets.default(): Settings
	return {
		TextureId = Presets.Textures[1].Id,
		Face = "Front",
		Color = Color3.new(1, 1, 1),
		Transparency = 0,
		Rotation = 0,
		StudsPerTileU = 4,
		StudsPerTileV = 4,
		OffsetStudsU = 0,
		OffsetStudsV = 0,
		--[[
			Square tiles by default: most surface patterns are square, and unequal tiling silently turns a
			checkerboard into stripes. Unlock it when you actually want the stretch.
		]]
		LockSquare = true,
		--- All six faces, because "resurface this part" almost never means one side.
		AllFaces = true,
	}
end

--[[
	The attribute stamped on every Texture this plugin creates.

	It is what makes `Strip` safe: without it the only way to clear a part would be to delete every Texture
	on it, including hand-placed ones the plugin never touched.
]]
Presets.Marker = "ResurfacePlugin"

return Presets
