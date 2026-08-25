--[[
	Icon.luau
	The single icon component used everywhere in the kit.

	Three modes, all with the same footprint so swapping one for another never
	changes a layout:

		tile  (default) art on a chunky gradient tile with a dark outline
		plain           bare art, no tile
		image           real artwork

	Art resolution, in order:

		1. props.image                     -- explicit, wins over everything
		2. Assets.Icons[props.glyph]       -- the project-wide asset table
		3. the procedural glyph            -- ships working with nothing uploaded

	So filling in one row of Assets.Icons replaces that icon across every screen
	without touching a single call site.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)
local Assets = require(script.Parent.Assets)
local Glyphs = require(script.Parent.Glyphs)
local P = require(script.Parent.Primitives)

local e = React.createElement

local function Icon(props)
	-- An explicit image beats the asset table, which beats the procedural glyph.
	-- An empty string is "no art", not a broken ImageLabel that hides the glyph.
	local art = if type(props.image) == "string" and props.image ~= ""
		then { id = props.image }
		else Assets.icon(props.glyph)
	local glyphComponent = if type(props.glyph) == "string"
		then Glyphs.get(props.glyph)
		else props.glyph

	local inner
	if art then
		inner = e("ImageLabel", {
			key = "Art",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = art.id,
			ImageColor3 = art.color or props.imageColor,
			ScaleType = Enum.ScaleType.Fit,
		})
	elseif glyphComponent then
		inner = e(glyphComponent, {
			key = "Glyph",
			color = props.glyphColor,
			accent = props.glyphAccent,
		})
	else
		-- Letter fallback: the first character of `label`, so an unmapped icon
		-- still reads as a deliberate badge rather than an empty hole.
		inner = e("TextLabel", {
			key = "Letter",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = string.upper(string.sub(props.label or "?", 1, 1)),
			FontFace = Theme.Font.Display,
			TextColor3 = props.glyphColor or Theme.Color.White,
			TextScaled = true,
		}, {
			e("UIStroke", {
				key = "TextOutline",
				Color = Theme.Color.Outline,
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				LineJoinMode = Enum.LineJoinMode.Round,
			}),
		})
	end

	if props.plain then
		-- Real art fills the box; a procedural glyph is drawn to its own bounds.
		local fill = props.glyphScale or (if art then (art.scale or 1) else 1)
		return e("Frame", {
			key = props.key or "Icon",
			BackgroundTransparency = 1,
			Size = props.size or UDim2.fromOffset(32, 32),
			Position = props.position,
			AnchorPoint = props.anchorPoint,
			LayoutOrder = props.layoutOrder,
			ZIndex = props.zIndex,
			--- Rotation is safe only where nothing needs clipping: AGENTS.md rule 11.
			Rotation = props.rotation,
		}, {
			e("Frame", {
				key = "Content",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(fill, fill),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
			}, { inner }),
		})
	end

	local radius = props.radius or Theme.Radius.Chip
	local inset = props.glyphScale or (if art then (art.scale or 0.78) else 0.66)

	return e("Frame", {
		key = props.key or "Icon",
		BackgroundColor3 = props.color or Theme.Color.PanelLight,
		BorderSizePixel = 0,
		Size = props.size or UDim2.fromOffset(48, 48),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
		Rotation = props.rotation,
	}, {
		P.corner(radius),
		P.stroke(props.strokeColor, props.strokeThickness or Theme.Stroke.Chip),
		P.gradient(props.gradient or Theme.Gradient.Panel),
		e(P.Highlight, { key = "Highlight", radius = radius, strength = 0.82, height = 0.34 }),
		-- Inset inside the tile so the outline never crowds the art.
		e("Frame", {
			key = "Content",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(inset, inset),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 3,
		}, { inner }),
	})
end

return Icon
