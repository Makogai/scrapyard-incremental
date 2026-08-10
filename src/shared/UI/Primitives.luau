--[[
	Primitives.luau
	The lowest layer of the SCRAPYARD UI: outlined text, chunky stud panels,
	gradients, strokes and layout helpers.

	Naming convention: every element passes a `key`, because react-roblox uses
	the React key as the Instance name. That keeps the built hierarchy readable
	in the Explorer and maps one-to-one onto the layer names in the design:

		Screen > Header > Tabs > Content > ItemGrid > ItemCard > Icon / Name / Rarity / Button
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)

local e = React.createElement

local P = {}

--------------------------------------------------------------------------------
-- Modifier helpers. These return elements meant to be dropped into a children
-- array; they take positional arguments instead of prop tables to keep call
-- sites short.
--------------------------------------------------------------------------------

function P.corner(radius: number?, key: string?)
	return e("UICorner", {
		key = key or "Corner",
		CornerRadius = UDim.new(0, radius or Theme.Radius.Card),
	})
end

function P.round(key: string?)
	return e("UICorner", {
		key = key or "Corner",
		CornerRadius = UDim.new(1, 0),
	})
end

type StrokeOptions = {
	transparency: number?,
	mode: Enum.ApplyStrokeMode?,
	key: string?,
}

function P.stroke(color: Color3?, thickness: number?, options: StrokeOptions?)
	local opts = options or {}
	return e("UIStroke", {
		key = opts.key or "Stroke",
		Color = color or Theme.Color.Outline,
		Thickness = thickness or Theme.Stroke.Card,
		ApplyStrokeMode = opts.mode or Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Transparency = opts.transparency or 0,
	})
end

type GradientOptions = {
	rotation: number?,
	transparency: NumberSequence?,
	offset: Vector2?,
	key: string?,
}

function P.gradient(colors: ColorSequence, options: GradientOptions?)
	local opts = options or {}
	return e("UIGradient", {
		key = opts.key or "Gradient",
		Color = colors,
		Rotation = opts.rotation or 90,
		Transparency = opts.transparency,
		Offset = opts.offset,
	})
end

type PaddingSpec = number | {
	top: number?,
	bottom: number?,
	left: number?,
	right: number?,
	x: number?,
	y: number?,
}

function P.padding(spec: PaddingSpec, key: string?)
	if type(spec) == "number" then
		return e("UIPadding", {
			key = key or "Padding",
			PaddingTop = UDim.new(0, spec),
			PaddingBottom = UDim.new(0, spec),
			PaddingLeft = UDim.new(0, spec),
			PaddingRight = UDim.new(0, spec),
		})
	end

	local x = spec.x or 0
	local y = spec.y or 0
	return e("UIPadding", {
		key = key or "Padding",
		PaddingTop = UDim.new(0, spec.top or y),
		PaddingBottom = UDim.new(0, spec.bottom or y),
		PaddingLeft = UDim.new(0, spec.left or x),
		PaddingRight = UDim.new(0, spec.right or x),
	})
end

type ListSpec = {
	direction: Enum.FillDirection?,
	padding: number?,
	hAlign: Enum.HorizontalAlignment?,
	vAlign: Enum.VerticalAlignment?,
	sort: Enum.SortOrder?,
	wraps: boolean?,
	key: string?,
}

function P.list(spec: ListSpec?)
	local s = spec or {}
	return e("UIListLayout", {
		key = s.key or "Layout",
		FillDirection = s.direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, s.padding or 0),
		HorizontalAlignment = s.hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = s.vAlign or Enum.VerticalAlignment.Top,
		SortOrder = s.sort or Enum.SortOrder.LayoutOrder,
		Wraps = s.wraps,
	})
end

type GridSpec = {
	cell: UDim2,
	padding: UDim2?,
	maxCells: number?,
	hAlign: Enum.HorizontalAlignment?,
	vAlign: Enum.VerticalAlignment?,
	key: string?,
}

function P.grid(spec: GridSpec)
	return e("UIGridLayout", {
		key = spec.key or "Grid",
		CellSize = spec.cell,
		CellPadding = spec.padding or UDim2.fromOffset(Theme.Space.M, Theme.Space.M),
		FillDirectionMaxCells = spec.maxCells or 0,
		HorizontalAlignment = spec.hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = spec.vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function P.aspect(ratio: number, key: string?)
	return e("UIAspectRatioConstraint", {
		key = key or "Aspect",
		AspectRatio = ratio,
	})
end

function P.sizeConstraint(min: Vector2?, max: Vector2?, key: string?)
	return e("UISizeConstraint", {
		key = key or "SizeConstraint",
		MinSize = min,
		MaxSize = max,
	})
end

--------------------------------------------------------------------------------
-- Label — bold white text with a heavy dark outline. This is the only text
-- element used anywhere in the kit.
--------------------------------------------------------------------------------

function P.Label(props)
	local textSize = props.textSize or Theme.TextSize.Body

	-- `stroke` accepts a thickness, or false to switch the outline off.
	local strokeThickness: number
	if props.stroke == nil then
		strokeThickness = Theme.strokeFor(textSize)
	elseif props.stroke == false then
		strokeThickness = 0
	else
		strokeThickness = props.stroke
	end

	local children = {}
	if strokeThickness > 0 then
		children[#children + 1] = e("UIStroke", {
			key = "TextOutline",
			-- `TextOutline`, not `Outline`: the light palette outlines text in white
			-- while keeping panel borders dark.
			Color = props.strokeColor or Theme.Color.TextOutline,
			Thickness = strokeThickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			LineJoinMode = Enum.LineJoinMode.Round,
		})
	end
	if props.gradient then
		children[#children + 1] = P.gradient(props.gradient, { key = "TextGradient" })
	end
	if props.children then
		for _, child in ipairs(props.children) do
			children[#children + 1] = child
		end
	end

	return e("TextLabel", {
		key = props.key or "Label",
		BackgroundTransparency = 1,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		AutomaticSize = props.automaticSize,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
		Visible = props.visible,

		Text = props.text,
		FontFace = props.font or Theme.Font.Display,
		TextSize = textSize,
		TextColor3 = props.color or Theme.Color.Text,
		TextTransparency = props.textTransparency,
		TextXAlignment = props.align or Enum.TextXAlignment.Center,
		TextYAlignment = props.vAlign or Enum.TextYAlignment.Center,
		TextWrapped = props.wrapped,
		TextTruncate = props.truncate,
		LineHeight = props.lineHeight,
		RichText = props.rich,
	}, children)
end

--------------------------------------------------------------------------------
-- Studs — the LEGO-stud texture on dark panels.
--
-- Rendered as a grid of small rounded squares so the kit needs zero uploaded
-- assets. Set Theme.Studs.Image to a tiled texture id to swap in a single
-- ImageLabel instead.
--------------------------------------------------------------------------------

local MAX_STUDS = 800

function P.Studs(props)
	local area: Vector2 = props.area or Vector2.new(400, 300)
	local spacing = props.spacing or Theme.Studs.Spacing
	local studSize = props.studSize or Theme.Studs.Size
	local transparency = props.transparency or Theme.Studs.Transparency

	--[[
		How many studs actually fit. The run is inset by `inset` at BOTH ends and
		the last cell has no trailing gap, so the space a run of n needs is
		`n * spacing - gap`, not `n * spacing`. Rounding up instead of down here is
		what left the right-hand column and bottom row clipped off every HUD tile.
	]]
	local gap = spacing - studSize
	local inset = math.floor(gap / 2)
	local function fit(extent: number): number
		return math.max(1, math.floor((extent - 2 * inset + gap) / spacing))
	end

	local studs = React.useMemo(function()
		if Theme.Studs.Image then
			return nil
		end

		local cols = fit(area.X)
		local rows = fit(area.Y)
		if cols * rows > MAX_STUDS then
			rows = math.max(1, math.floor(MAX_STUDS / cols))
		end

		local list = table.create(cols * rows)
		for index = 1, cols * rows do
			list[index] = e("Frame", {
				key = "Stud" .. index,
				BackgroundColor3 = props.color or Theme.Studs.Color,
				BackgroundTransparency = transparency,
				BorderSizePixel = 0,
				LayoutOrder = index,
			}, {
				P.corner(math.max(2, studSize * 0.28)),
			})
		end

		return list
	end, { area, spacing, studSize, transparency, props.color or false })

	-- A single tiled ImageLabel is cheaper; the procedural grid is the default
	-- so the kit works with no uploaded assets.
	if Theme.Studs.Image then
		return e("ImageLabel", {
			key = props.key or "Studs",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = Theme.Studs.Image,
			ImageColor3 = props.color or Theme.Studs.Color,
			ImageTransparency = transparency,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(spacing, spacing),
			ZIndex = 0,
		})
	end

	--[[
		Centred, because a stud pitch almost never divides a panel exactly. Left/top
		alignment dumps the entire remainder against one edge, which is what made
		HUD tiles look like the plate had been cut off down the right-hand side.
		Centring splits it, so both margins read as deliberate -- and it stays right
		when `area` is a little off the panel's true rendered size.
	]]
	local children = {
		P.grid({
			key = "StudGrid",
			cell = UDim2.fromOffset(studSize, studSize),
			padding = UDim2.fromOffset(gap, gap),
			maxCells = fit(area.X),
			hAlign = Enum.HorizontalAlignment.Center,
			vAlign = Enum.VerticalAlignment.Center,
		}),
		P.padding(inset, "StudInset"),
	}
	if studs then
		for _, stud in ipairs(studs) do
			children[#children + 1] = stud
		end
	end

	return e("Frame", {
		key = props.key or "Studs",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
	}, children)
end

--------------------------------------------------------------------------------
-- Highlight — the top sheen that makes a surface read as moulded plastic.
--
-- Solid: one uniform band of white at a fixed alpha, inset from the edges so it
-- never touches the outline. Deliberately not a gradient fade -- that reads as
-- glass, and glass is not this art style.
--
-- `Gloss` is kept as an alias because every component asks for it by that name.
--------------------------------------------------------------------------------

function P.Highlight(props)
	local radius = props.radius or Theme.Radius.Card
	local inset = props.inset or Theme.Highlight.Inset

	return e("Frame", {
		key = props.key or "Highlight",
		BackgroundColor3 = props.color or Theme.Color.White,
		-- `strength` is the band's transparency; callers pass it as a "how much
		-- sheen" number, so higher means subtler.
		BackgroundTransparency = props.strength or Theme.Highlight.Transparency,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -inset * 2, props.height or Theme.Highlight.Height, -inset),
		Position = UDim2.fromOffset(inset, inset),
		ZIndex = props.zIndex or 2,
	}, {
		P.corner(math.max(2, radius - inset)),
	})
end

P.Gloss = P.Highlight

--------------------------------------------------------------------------------
-- Shadow — a very mild offset slab. Deliberately not a blur, so it converts
-- cleanly to a Roblox Frame.
--------------------------------------------------------------------------------

function P.Shadow(props)
	local offset = props.offset or 6
	local spread = props.spread or 0
	return e("Frame", {
		key = props.key or "Shadow",
		BackgroundColor3 = props.color or Theme.Color.Ink,
		BackgroundTransparency = props.transparency or 0.55,
		BorderSizePixel = 0,
		Size = UDim2.new(1, spread * 2, 1, spread * 2),
		Position = UDim2.fromOffset(-spread, offset - spread),
		ZIndex = 0,
	}, {
		P.corner(props.radius or Theme.Radius.Panel),
	})
end

--------------------------------------------------------------------------------
-- Panel — the dark stud-textured surface with a thick outline that every
-- window, card and slot is built from.
--
-- Notes:
--   `area`     pixel size used to lay out the stud grid. Derived from `size`
--              when that is offset-based; pass it explicitly for panels sized
--              in scale, or the studs will only cover part of the surface.
--   `shadow`   wraps the panel in a group, so it cannot be combined with
--              `automaticSize` -- give those panels an explicit height.
--------------------------------------------------------------------------------

function P.Panel(props)
	local radius = props.radius or Theme.Radius.Panel
	local area: Vector2? = props.area
	if not area and typeof(props.size) == "UDim2" then
		local size: UDim2 = props.size
		if size.X.Offset > 0 and size.Y.Offset > 0 then
			area = Vector2.new(size.X.Offset, size.Y.Offset)
		end
	end

	local body = {}

	-- Texture layer clips to the rounded corners; content sits above it and is
	-- free to overhang (badges, close buttons).
	if props.studs ~= false or props.gloss then
		local textureChildren = {}
		if props.studs ~= false then
			textureChildren[#textureChildren + 1] = e(P.Studs, {
				key = "Studs",
				area = area,
				color = props.studColor,
				spacing = props.studSpacing,
				transparency = props.studTransparency,
			})
		end
		if props.gloss then
			textureChildren[#textureChildren + 1] = e(P.Highlight, {
				key = "Highlight",
				radius = radius,
				strength = if props.gloss == true then 0.85 else props.gloss,
				-- Short by default: on a 300px card a half-height band stops
				-- reading as a sheen and starts reading as two-tone paint.
				height = props.glossHeight or 0.26,
			})
		end
		textureChildren[#textureChildren + 1] = P.corner(radius, "TextureCorner")

		body[#body + 1] = e("Frame", {
			key = "Texture",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ClipsDescendants = true,
			ZIndex = 0,
		}, textureChildren)
	end

	body[#body + 1] = P.corner(radius, "Corner")
	body[#body + 1] = P.stroke(props.strokeColor, props.strokeThickness or Theme.Stroke.Panel)
	if props.gradient then
		--[[
			`gradientTransparency` is a NumberSequence along the same axis as the
			colour ramp, so a panel can fade out down its own height. Without it a
			panel could only ever be a flat wash with two tones.
		]]
		body[#body + 1] = P.gradient(props.gradient, {
			transparency = props.gradientTransparency,
		})
	end

	if props.children then
		for _, child in ipairs(props.children) do
			body[#body + 1] = child
		end
	end

	local panel = e("Frame", {
		key = if props.shadow then "Body" else (props.key or "Panel"),
		BackgroundColor3 = props.color or Theme.Color.Panel,
		BackgroundTransparency = props.transparency,
		BorderSizePixel = 0,
		Size = if props.shadow then UDim2.fromScale(1, 1) else props.size,
		Position = if props.shadow then nil else props.position,
		AnchorPoint = if props.shadow then nil else props.anchorPoint,
		AutomaticSize = props.automaticSize,
		LayoutOrder = if props.shadow then nil else props.layoutOrder,
		ZIndex = if props.shadow then 1 else props.zIndex,
		ClipsDescendants = props.clip,
		--[[
			READ AGENTS.md RULE 11 BEFORE USING THIS. A GuiObject with non-zero `Rotation` ignores every
			ancestor's `ClipsDescendants`, so a rotated panel inside a scrolling list or a clipped window
			paints over the whole screen. It is only safe on something that never needs clipping -- the
			spin wheel's spokes, which sit in a fixed-size area with margin around them.
		]]
		Rotation = props.rotation,
	}, body)

	if not props.shadow then
		return panel
	end

	return e("Frame", {
		key = props.key or "Panel",
		BackgroundTransparency = 1,
		Size = props.size,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, {
		e(P.Shadow, { key = "Shadow", radius = radius, offset = props.shadowOffset }),
		panel,
	})
end

--------------------------------------------------------------------------------
-- Slot — the recessed dark well used behind item art and empty pet slots.
--------------------------------------------------------------------------------

function P.Slot(props)
	local children = {
		P.corner(props.radius or Theme.Radius.Slot, "Corner"),
		P.stroke(
			props.strokeColor or Theme.Color.Outline,
			props.strokeThickness or Theme.Stroke.Chip
		),
		P.gradient(props.gradient or Theme.Gradient.Slot),
	}
	if props.children then
		for _, child in ipairs(props.children) do
			children[#children + 1] = child
		end
	end

	return e("Frame", {
		key = props.key or "Slot",
		BackgroundColor3 = props.color or Theme.Color.Slot,
		BorderSizePixel = 0,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
		ClipsDescendants = props.clip,
	}, children)
end

--------------------------------------------------------------------------------
-- Chip — small bright rounded tag used for rarities, counts and timers.
--------------------------------------------------------------------------------

--[[
	Chip — small bright rounded tag.

	`layout` is a separate prop, NOT a child, and passing it drops the Highlight.

	Both rules exist for the same reason: a UIListLayout lays out EVERY GuiObject
	child, including the Highlight, whose width is scale-based. On an
	AutomaticSize chip that is a feedback loop -- the highlight's width depends on
	the chip, the chip's width depends on its laid-out children -- and the chip
	resolves hundreds of pixels wide and spills out of whatever contains it.
]]
function P.Chip(props)
	local children = {
		P.corner(props.radius or Theme.Radius.Chip, "Corner"),
		P.stroke(
			props.strokeColor or Theme.Color.Outline,
			props.strokeThickness or Theme.Stroke.Chip
		),
	}
	if props.gradient then
		children[#children + 1] = P.gradient(props.gradient)
	end
	if props.layout then
		children[#children + 1] = props.layout
	end
	if props.gloss ~= false and not props.layout then
		children[#children + 1] = e(P.Gloss, {
			key = "Gloss",
			radius = props.radius or Theme.Radius.Chip,
			strength = 0.82,
			height = 0.5,
		})
	end
	if props.children then
		for _, child in ipairs(props.children) do
			children[#children + 1] = child
		end
	end

	return e("Frame", {
		key = props.key or "Chip",
		BackgroundColor3 = props.color or Theme.Color.PanelLight,
		BorderSizePixel = 0,
		Size = props.size,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		AutomaticSize = props.automaticSize,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, children)
end

--------------------------------------------------------------------------------
-- Divider — a two-tone rule that reads as a moulded seam.
--------------------------------------------------------------------------------

function P.Divider(props)
	return e("Frame", {
		key = props.key or "Divider",
		BackgroundColor3 = props.color or Theme.Color.PanelDark,
		BorderSizePixel = 0,
		Size = props.size or UDim2.new(1, 0, 0, 3),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
	}, {
		P.corner(2),
		e("Frame", {
			key = "Highlight",
			BackgroundColor3 = Theme.Color.PanelLight,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
		}),
	})
end

--------------------------------------------------------------------------------
-- Scroller — a scrolling frame styled to match the kit.
--------------------------------------------------------------------------------

-- Scrollers always carry an inset. Without one, the top and left rows of a grid
-- lose their outlines to the clip edge, and a card growing on hover gets shaved.
local SCROLLER_INSET = { top = 10, left = 10, right = 12, bottom = 12 }

function P.Scroller(props)
	local inset = table.clone(SCROLLER_INSET)
	if type(props.padding) == "number" then
		inset = {
			top = props.padding,
			left = props.padding,
			right = props.padding,
			bottom = props.padding,
		}
	elseif type(props.padding) == "table" then
		for key, value in pairs(props.padding) do
			inset[key] = value
		end
	end

	local children = {}
	if props.layout then
		children[#children + 1] = props.layout
	end
	children[#children + 1] = P.padding(inset, "Inset")
	if props.children then
		for _, child in ipairs(props.children) do
			children[#children + 1] = child
		end
	end

	return e("ScrollingFrame", {
		key = props.key or "Content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,

		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = props.axis or Enum.AutomaticSize.Y,
		ScrollBarThickness = props.scrollBarThickness or 8,
		ScrollBarImageColor3 = Theme.Color.PanelLight,
		ScrollBarImageTransparency = 0.25,
		ScrollingDirection = props.direction or Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
	}, children)
end

--------------------------------------------------------------------------------
-- Small utilities
--------------------------------------------------------------------------------

--- Transparent container. Handy for grouping without adding a visible surface.
function P.Group(props)
	local children = {}
	if props.layout then
		children[#children + 1] = props.layout
	end
	if props.padding then
		children[#children + 1] = P.padding(props.padding, "Inset")
	end
	if props.children then
		for _, child in ipairs(props.children) do
			children[#children + 1] = child
		end
	end

	return e("Frame", {
		key = props.key or "Group",
		BackgroundTransparency = 1,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		AutomaticSize = props.automaticSize,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
		ClipsDescendants = props.clip,
		Visible = props.visible,
		--- Same warning as `P.Panel.rotation`: see AGENTS.md rule 11.
		Rotation = props.rotation,
	}, children)
end

--- Builds a children array from varargs, dropping nils.
---
--- Children MUST be a hole-free array or react-lua treats the table as an
--- object and drops it, so never write `{ a, cond and b or nil, c }` inline --
--- write `P.compact(a, cond and b or nil, c)` instead.
function P.compact(...): { any }
	local out = {}
	for index = 1, select("#", ...) do
		local item = select(index, ...)
		if item ~= nil then
			out[#out + 1] = item
		end
	end
	return out
end

--- Appends every value of `items` onto `target` in order.
function P.append(target: { any }, items: { any }?): { any }
	if items then
		for _, item in ipairs(items) do
			target[#target + 1] = item
		end
	end
	return target
end

return P
