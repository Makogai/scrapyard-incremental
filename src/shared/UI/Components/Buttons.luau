--[[
	Buttons.luau
	Every pressable surface in SCRAPYARD.

	All of them share one body, `Shell`:

		Root      TextButton at a fixed size -- the thing a layout measures
		Visual      inner frame carrying the UIScale, so hover growth never
		            shifts the siblings around it
		Base          solid darker slab, and the only outline on the button
		Face            solid coloured face, inset by `lip` at the bottom

	Two rules make it read as a moulded toy rather than a web button: the Base is
	a SOLID slab, so the visible bottom strip is colour rather than an outline;
	and the Face carries no stroke of its own, so you never see a double line
	where the two meet.

	Pressing springs the Face down onto the Base and shrinks the whole button
	slightly; hovering grows it. Both run on ripple springs through
	Motion.usePressable, so every button in the game feels identical.

		Button        variant-driven: Primary / Secondary / Purchase / Danger /
		              Premium / Event / Shop / Neutral / Disabled
		IconButton    small square, for close / plus / settings
		CloseButton   red X, centred in a window header
		MenuButton    large HUD menu tile with icon over label
		WideMenuButton  full-width menu row (the HUD Shop button)
		TabButton     active / inactive window tab
		TabBar        row of TabButtons
		Stepper       x1 / x5 / MAX multiplier selector
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Motion = require(UI.Motion)
local Sound = require(UI.Sound)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)

local e = React.createElement

local Buttons = {}

--------------------------------------------------------------------------------
-- Shell
--------------------------------------------------------------------------------

--[[
	The "NEW!" flag. Sits outside the button's content layout so it can overhang
	the corner, and above everything so the highlight cannot wash it out.

	props: text, position, anchorPoint, gradient
]]
local function NewFlag(props)
	return e(P.Chip, {
		key = props.key or "NewFlag",
		gradient = props.gradient or Theme.Gradient.Red,
		color = Theme.Color.Red,
		size = UDim2.fromOffset(props.width or 52, props.height or 24),
		position = props.position or UDim2.new(1, 4, 0, -6),
		anchorPoint = props.anchorPoint or Vector2.new(1, 0),
		radius = Theme.Radius.Small,
		zIndex = 12,
		children = {
			e(P.Label, {
				key = "Text",
				text = props.text or "NEW!",
				textSize = Theme.TextSize.Micro,
				size = UDim2.fromScale(1, 1),
				zIndex = 13,
			}),
		},
	})
end

Buttons.NewFlag = NewFlag

local function Shell(props)
	local disabled = props.disabled == true
	local lip = props.lip or Theme.Lip.Button
	local radius = props.radius or Theme.Radius.Button
	local staticSink = props.staticSink or 0

	--[[
		`wiggle` is an occasional attention nudge for buttons that want to be
		noticed. The hook must run unconditionally -- it is a hook -- so a disabled
		wiggle is a zero-angle one, which never leaves 0 and never re-renders.
	]]
	local wiggle = Motion.useWiggle(
		if props.wiggle
			then (if type(props.wiggle) == "table" then props.wiggle else nil)
			else { angle = 0, every = math.huge }
	)

	local press = Motion.usePressable({
		disabled = disabled,
		hoverScale = props.hoverScale or Theme.Hover.Scale,
		pressScale = props.pressScale or Theme.Hover.PressScale,
		onHover = if props.silent
			then nil
			else function()
				Sound.play(props.hoverSound or "hover")
			end,
		onClick = function()
			if not props.silent then
				Sound.play(props.sound or "click")
			end
			if props.onClick then
				props.onClick()
			end
		end,
	})

	local faceChildren = P.compact(
		P.corner(radius),
		-- No stroke on the Face: the Base already outlines the silhouette, and a
		-- second one turns the bottom lip into a pair of lines.
		if props.gradient then P.gradient(props.gradient) else nil,
		if props.studs
			then e("Frame", {
				key = "Texture",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ClipsDescendants = true,
				ZIndex = 0,
			}, {
				P.corner(radius, "TextureCorner"),
				e(P.Studs, {
					key = "Studs",
					area = props.studs.area,
					spacing = props.studs.spacing,
					studSize = props.studs.studSize,
				}),
			})
			else nil,
		if props.highlight ~= false
			then e(P.Highlight, {
				key = "Highlight",
				radius = radius,
				strength = if type(props.highlight) == "number" then props.highlight else nil,
				height = props.highlightHeight,
				zIndex = 2,
			})
			else nil,
		if props.glow
			then P.stroke(props.glow, 3, { key = "GlowRing", transparency = 0.12 })
			else nil,
		if press.hovered and props.hoverWash ~= false
			then e("Frame", {
				key = "Hover",
				BackgroundColor3 = Theme.Color.White,
				BackgroundTransparency = Theme.Hover.Wash,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 3,
			}, { P.corner(radius) })
			else nil
	)

	P.append(faceChildren, props.children)

	local rootProps = {
		key = props.key or "Button",
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Active = not disabled,
		Selectable = not disabled,
		Size = props.size,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
		Visible = props.visible,
	}
	for event, handler in pairs(press.events) do
		rootProps[event] = handler
	end

	return e("TextButton", rootProps, {
		e("Frame", {
			key = "Visual",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			-- Rotation, not a second UIScale: the wiggle has to compose with the
			-- press scale already on this frame.
			Rotation = wiggle,
		}, {
			e("UIScale", { key = "Scale", Scale = press.scale }),
			-- Solid slab: this is what the visible bottom strip actually is.
			e("Frame", {
				key = "Base",
				BackgroundColor3 = props.baseColor,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
			}, {
				P.corner(radius),
				P.stroke(props.strokeColor, props.strokeThickness or Theme.Stroke.Button),
			}),
			e("Frame", {
				key = "Face",
				BackgroundColor3 = props.faceColor or Theme.Color.White,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 1, -lip),
				Position = press.sink:map(function(value)
					return UDim2.fromOffset(0, staticSink + value * (lip - staticSink))
				end),
				ZIndex = 2,
			}, faceChildren),
		}),
	})
end

Buttons.Shell = Shell

--------------------------------------------------------------------------------
-- Button
--------------------------------------------------------------------------------

--[[
	props:
		text          string
		subtext       string?      small line under the label
		variant       string?      key into Theme.Button, default "Primary"
		glyph         string?      icon glyph name, sits left of the label
		image         string?      real artwork instead of a glyph
		size          UDim2
		disabled      boolean?     forces the Disabled variant and blocks onClick
		onClick       function?
		sound         string?      cue name, default "click"
		silent        boolean?     no audio at all
]]
function Buttons.Button(props)
	local disabled = props.disabled == true
	local variantName = if disabled then "Disabled" else (props.variant or "Primary")
	local variant = Theme.Button[variantName] or Theme.Button.Primary
	local textSize = props.textSize or Theme.TextSize.Button

	local labelChildren = {}
	if props.glyph or props.image then
		labelChildren[#labelChildren + 1] = e(Icon, {
			key = "Icon",
			glyph = props.glyph,
			image = props.image,
			plain = true,
			size = UDim2.fromOffset(props.iconSize or textSize + 8, props.iconSize or textSize + 8),
			layoutOrder = 1,
		})
	end

	if props.subtext then
		labelChildren[#labelChildren + 1] = e(P.Group, {
			key = "Text",
			size = UDim2.fromOffset(0, 0),
			automaticSize = Enum.AutomaticSize.XY,
			layoutOrder = 2,
			layout = P.list({ padding = 0, hAlign = Enum.HorizontalAlignment.Center }),
			children = {
				e(P.Label, {
					key = "Primary",
					text = props.text,
					textSize = textSize,
					color = variant.text,
					automaticSize = Enum.AutomaticSize.XY,
					size = UDim2.fromOffset(0, 0),
					layoutOrder = 1,
				}),
				e(P.Label, {
					key = "Secondary",
					text = props.subtext,
					--[[
						`subtextSize` exists because this was pinned to `Small`, which
						turned a price into a caption. A primary call to action needs its
						cost readable at a glance, so the caller decides the weight.
					]]
					textSize = props.subtextSize or Theme.TextSize.Small,
					font = props.subtextFont or Theme.Font.Bold,
					color = props.subtextColor or Theme.Color.White,
					automaticSize = Enum.AutomaticSize.XY,
					size = UDim2.fromOffset(0, 0),
					layoutOrder = 2,
				}),
			},
		})
	else
		labelChildren[#labelChildren + 1] = e(P.Label, {
			key = "Text",
			text = props.text,
			textSize = textSize,
			color = variant.text,
			automaticSize = Enum.AutomaticSize.XY,
			size = UDim2.fromOffset(0, 0),
			layoutOrder = 2,
		})
	end

	return e(Shell, {
		key = props.key or "Button",
		size = props.size or UDim2.fromOffset(200, 56),
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex,
		visible = props.visible,
		radius = props.radius or Theme.Radius.Button,
		lip = props.lip or Theme.Lip.Button,
		baseColor = variant.base,
		gradient = variant.gradient,
		strokeColor = variant.stroke,
		strokeThickness = props.strokeThickness,
		highlight = if disabled then 0.9 else nil,
		disabled = disabled,
		onClick = props.onClick,
		sound = props.sound,
		silent = props.silent,
		children = {
			e(P.Group, {
				key = "Label",
				size = UDim2.fromScale(1, 1),
				zIndex = 4,
				padding = { x = props.inset or 10 },
				layout = P.list({
					direction = Enum.FillDirection.Horizontal,
					padding = Theme.Space.S,
					hAlign = Enum.HorizontalAlignment.Center,
					vAlign = Enum.VerticalAlignment.Center,
				}),
				children = labelChildren,
			}),
		},
	})
end

--------------------------------------------------------------------------------
-- IconButton
--------------------------------------------------------------------------------

function Buttons.IconButton(props)
	local disabled = props.disabled == true
	local variant = Theme.Button[if disabled then "Disabled" else (props.variant or "Secondary")]
		or Theme.Button.Secondary
	local extent = props.extent or 40
	local radius = props.radius or Theme.Radius.Small

	return e(Shell, {
		key = props.key or "IconButton",
		size = props.size or UDim2.fromOffset(extent, extent),
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex,
		radius = radius,
		lip = props.lip or Theme.Lip.Small,
		baseColor = variant.base,
		gradient = variant.gradient,
		strokeColor = variant.stroke,
		disabled = disabled,
		onClick = props.onClick,
		sound = props.sound,
		silent = props.silent,
		children = {
			e(Icon, {
				key = "Icon",
				glyph = props.glyph or "plus",
				image = props.image,
				plain = true,
				size = UDim2.fromScale(props.glyphScale or 0.52, props.glyphScale or 0.52),
				position = UDim2.fromScale(0.5, 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
				glyphColor = props.glyphColor or Theme.Color.White,
				zIndex = 4,
			}),
		},
	})
end

--- Red X. Windows centre it in their header, so it lands in the same place on
--- every screen instead of overhanging a corner by eye.
function Buttons.CloseButton(props)
	return e(Buttons.IconButton, {
		key = props.key or "CloseButton",
		variant = "Danger",
		glyph = "cross",
		glyphScale = 0.42,
		extent = props.extent or 44,
		position = props.position or UDim2.new(1, -14, 0.5, 0),
		anchorPoint = props.anchorPoint or Vector2.new(1, 0.5),
		radius = Theme.Radius.Chip,
		zIndex = props.zIndex or 20,
		sound = "close",
		onClick = props.onClick,
	})
end

--------------------------------------------------------------------------------
-- MenuButton — HUD menu tile: big icon over a bold label, on a studded plate.
--------------------------------------------------------------------------------

function Buttons.MenuButton(props)
	local size = props.size or UDim2.fromOffset(104, 104)
	local radius = props.radius or Theme.Radius.Card
	local labelSize = props.textSize or Theme.TextSize.Small

	return e(Shell, {
		key = props.key or "MenuButton",
		size = size,
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex,
		radius = radius,
		lip = props.lip or Theme.Lip.Card,
		baseColor = props.baseColor or Theme.Color.PanelDark,
		faceColor = Theme.Color.Panel,
		gradient = props.gradient or Theme.Gradient.Panel,
		strokeColor = Theme.Color.Outline,
		strokeThickness = Theme.Stroke.Card,
		-- HUD tiles keep the stud texture: they sit over the game view, where the
		-- LEGO plate is the point. Grid cards do not.
		studs = { area = Vector2.new(size.X.Offset, size.Y.Offset), spacing = 22, studSize = 10 },
		highlight = 0.84,
		highlightHeight = 0.3,
		glow = if props.glow then (props.glowColor or Theme.Color.Gold) else nil,
		wiggle = props.wiggle,
		onClick = props.onClick,
		sound = props.sound or "tap",
		children = P.compact(
			if props.isNew then e(NewFlag, { key = "New", text = props.newText }) else nil,
			e(P.Group, {
				key = "Content",
				size = UDim2.fromScale(1, 1),
				zIndex = 5,
				padding = { top = 8, bottom = 7, x = 6 },
				layout = P.list({
					padding = 4,
					hAlign = Enum.HorizontalAlignment.Center,
					vAlign = Enum.VerticalAlignment.Center,
				}),
				children = {
					--[[
						`flatIcon` is the bare-art variant: no gradient tile behind
						the icon, and the art runs larger to fill the space the tile
						used to take. Art with its own background reads as a sticker
						on a sticker otherwise.
					]]
					e(Icon, {
						key = "Icon",
						glyph = props.glyph,
						image = props.image,
						plain = props.flatIcon,
						gradient = if props.flatIcon
							then nil
							else (props.accent or Theme.Gradient.Blue),
						size = UDim2.fromOffset(
							props.iconSize or (if props.flatIcon then 62 else 50),
							props.iconSize or (if props.flatIcon then 62 else 50)
						),
						radius = Theme.Radius.Chip,
						glyphColor = props.glyphColor,
						glyphAccent = props.glyphAccent,
						layoutOrder = 1,
					}),
					e(P.Label, {
						key = "Name",
						text = props.text,
						textSize = labelSize,
						size = UDim2.new(1, 0, 0, labelSize + 6),
						layoutOrder = 2,
					}),
				},
			}),
			-- Notification pip sits outside the layout so it can overhang.
			if props.badge
				then e(P.Chip, {
					key = "Badge",
					gradient = Theme.Gradient.Red,
					color = Theme.Color.Red,
					size = UDim2.fromOffset(26, 26),
					position = UDim2.new(1, 5, 0, -5),
					anchorPoint = Vector2.new(1, 0),
					zIndex = 10,
					children = {
						e(P.Label, {
							key = "Count",
							text = tostring(props.badge),
							textSize = Theme.TextSize.Tiny,
						}),
					},
				})
				else nil
		),
	})
end

--- Wide menu row: icon on the left, label centred. The HUD Shop button, which
--- spans both menu columns.
function Buttons.WideMenuButton(props)
	local size = props.size or UDim2.fromOffset(220, 68)
	local radius = props.radius or Theme.Radius.Card

	return e(Shell, {
		key = props.key or "WideMenuButton",
		size = size,
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex,
		radius = radius,
		lip = props.lip or Theme.Lip.Card,
		baseColor = props.baseColor or Theme.Color.PanelDark,
		faceColor = Theme.Color.Panel,
		gradient = props.gradient or Theme.Gradient.Panel,
		strokeColor = Theme.Color.Outline,
		strokeThickness = Theme.Stroke.Card,
		studs = { area = Vector2.new(size.X.Offset, size.Y.Offset), spacing = 22, studSize = 10 },
		highlight = 0.84,
		highlightHeight = 0.36,
		glow = if props.glow then (props.glowColor or Theme.Color.Gold) else nil,
		wiggle = props.wiggle,
		onClick = props.onClick,
		sound = props.sound or "tap",
		children = P.compact(
			e(P.Group, {
				key = "Content",
				size = UDim2.fromScale(1, 1),
				zIndex = 5,
				padding = { x = 10 },
				layout = P.list({
					direction = Enum.FillDirection.Horizontal,
					padding = Theme.Space.M,
					hAlign = Enum.HorizontalAlignment.Center,
					vAlign = Enum.VerticalAlignment.Center,
				}),
				children = {
					-- Same bare-art variant as the square tiles; see MenuButton.
					e(Icon, {
						key = "Icon",
						glyph = props.glyph,
						image = props.image,
						plain = props.flatIcon,
						gradient = if props.flatIcon
							then nil
							else (props.accent or Theme.Gradient.Pink),
						size = UDim2.fromOffset(
							props.iconSize or (if props.flatIcon then 58 else 46),
							props.iconSize or (if props.flatIcon then 58 else 46)
						),
						glyphColor = props.glyphColor,
						glyphAccent = props.glyphAccent,
						layoutOrder = 1,
					}),
					e(P.Label, {
						key = "Name",
						text = props.text,
						textSize = props.textSize or Theme.TextSize.Heading,
						automaticSize = Enum.AutomaticSize.X,
						size = UDim2.fromOffset(0, 34),
						layoutOrder = 2,
					}),
				},
			}),
			if props.isNew then e(NewFlag, { key = "New", text = props.newText }) else nil
		),
	})
end

--------------------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------------------

function Buttons.TabButton(props)
	local active = props.active == true
	local radius = Theme.Radius.Chip
	local lip = 4

	local variant = if active
		then (Theme.Button[props.variant or "Purchase"] or Theme.Button.Purchase)
		else Theme.Button.Neutral

	local content
	if props.glyph then
		content = e(P.Group, {
			key = "Content",
			size = UDim2.fromScale(1, 1),
			zIndex = 4,
			layout = P.list({
				direction = Enum.FillDirection.Horizontal,
				padding = 6,
				hAlign = Enum.HorizontalAlignment.Center,
				vAlign = Enum.VerticalAlignment.Center,
			}),
			children = {
				e(Icon, {
					key = "Icon",
					glyph = props.glyph,
					plain = true,
					size = UDim2.fromOffset(24, 24),
					layoutOrder = 1,
				}),
				e(P.Label, {
					key = "Name",
					text = props.text,
					textSize = props.textSize or Theme.TextSize.Body,
					color = if active then Theme.Color.White else Color3.fromHex("E2E9F3"),
					automaticSize = Enum.AutomaticSize.X,
					size = UDim2.fromOffset(0, 24),
					layoutOrder = 2,
				}),
			},
		})
	else
		content = e(P.Label, {
			key = "Name",
			text = props.text,
			textSize = props.textSize or Theme.TextSize.Body,
			color = if active then Theme.Color.White else Color3.fromHex("E2E9F3"),
			zIndex = 4,
		})
	end

	return e(Shell, {
		key = props.key or "Tab",
		size = props.size or UDim2.fromOffset(150, 44),
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = if active then 3 else 2,
		radius = radius,
		lip = lip,
		-- An inactive tab rests one lip lower, as though it has not been pushed
		-- forward yet.
		staticSink = if active then 0 else lip,
		baseColor = variant.base,
		gradient = if active then variant.gradient else Theme.Gradient.Gray,
		strokeColor = Theme.Color.Outline,
		highlight = if active then 0.74 else 0.86,
		hoverScale = 1.035,
		onClick = props.onClick,
		sound = "tap",
		children = { content },
	})
end

--[[
	TabBar
		tabs      { { id = "MAGNETS", text = "MAGNETS", glyph = "magnet"? }, ... }
		active    id of the selected tab
		onSelect  function(id)
]]
function Buttons.TabBar(props)
	local children = {}
	for index, tab in ipairs(props.tabs) do
		children[#children + 1] = e(Buttons.TabButton, {
			key = tab.id,
			text = tab.text or tab.id,
			glyph = tab.glyph,
			active = props.active == tab.id,
			variant = tab.variant or props.variant,
			size = props.tabSize or UDim2.new(0, 150, 1, 0),
			layoutOrder = index,
			textSize = props.textSize,
			onClick = function()
				if props.onSelect then
					props.onSelect(tab.id)
				end
			end,
		})
	end

	return e(P.Group, {
		key = props.key or "Tabs",
		size = props.size or UDim2.new(1, 0, 0, 44),
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		zIndex = props.zIndex,
		layout = P.list({
			direction = Enum.FillDirection.Horizontal,
			padding = props.padding or Theme.Space.S,
			hAlign = props.hAlign or Enum.HorizontalAlignment.Center,
			vAlign = Enum.VerticalAlignment.Bottom,
		}),
		children = children,
	})
end

--------------------------------------------------------------------------------
-- Stepper — x1 / x5 / MAX buy-amount selector
--------------------------------------------------------------------------------

function Buttons.Stepper(props)
	local options = props.options or { "x1", "x5", "MAX" }
	local children = {}

	for index, option in ipairs(options) do
		local active = props.active == option
		children[#children + 1] = e(Buttons.Button, {
			key = option,
			text = option,
			variant = if active then "Purchase" else "Neutral",
			textSize = props.textSize or Theme.TextSize.Small,
			size = props.optionSize or UDim2.fromOffset(58, 34),
			lip = 4,
			radius = Theme.Radius.Small,
			inset = 4,
			layoutOrder = index,
			sound = "tap",
			onClick = function()
				if props.onSelect then
					props.onSelect(option)
				end
			end,
		})
	end

	return e(P.Group, {
		key = props.key or "Stepper",
		size = props.size or UDim2.fromOffset(190, 34),
		position = props.position,
		anchorPoint = props.anchorPoint,
		layoutOrder = props.layoutOrder,
		layout = P.list({
			direction = Enum.FillDirection.Horizontal,
			padding = 6,
			hAlign = props.hAlign or Enum.HorizontalAlignment.Right,
			vAlign = Enum.VerticalAlignment.Center,
		}),
		children = children,
	})
end

return Buttons
