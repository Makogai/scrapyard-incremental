--[[
	Overlays.luau
	Window chrome and floating surfaces.

		Modal           the standard game window: gradient header, stud body,
		                overhanging red close button
		ConfirmModal    small centred yes/no dialog
		Tooltip         dark pointer-follow card
		Toast           single notification card
		Backdrop        dim wash behind a modal, optionally with a real Lighting blur

	Modals are deliberately smaller than the screen: the player has to be able
	to see the game behind them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Hooks = require(UI.Hooks)
local Motion = require(UI.Motion)
local Sound = require(UI.Sound)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)
local FadeBanner = require(script.Parent.FadeBanner)
local Buttons = require(script.Parent.Buttons)
local Indicators = require(script.Parent.Indicators)

local e = React.createElement

local Overlays = {}

--------------------------------------------------------------------------------
-- Backdrop
--------------------------------------------------------------------------------

--[[
	`blur` adds a real `BlurEffect` to Lighting for as long as the backdrop is mounted.

	It has to live in Lighting because that is the only place Roblox will blur the 3D world from -- a
	ScreenGui cannot blur what is behind it. Created and destroyed with the component so it can never
	outlive the overlay that asked for it, which is the failure mode that leaves a player staring at a
	permanently blurred game.

	Guarded with `pcall`: `Lighting` is present in a story too, so this is safe there, but a future
	caller mounting it somewhere unusual should degrade to "no blur" rather than throw inside an effect.
]]
local function useBackdropBlur(enabled: boolean?, size: number?)
	React.useEffect(function()
		if not enabled then
			return
		end
		local blur
		local ok = pcall(function()
			blur = Instance.new("BlurEffect")
			blur.Size = size or 18
			blur.Name = "ScrapyardBackdropBlur"
			blur.Parent = game:GetService("Lighting")
		end)
		if not ok then
			return
		end
		return function()
			if blur then
				blur:Destroy()
			end
		end
	end, { enabled, size })
end

function Overlays.Backdrop(props)
	useBackdropBlur(props.blur, props.blurSize)

	return e("TextButton", {
		key = props.key or "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Color.Ink,
		BackgroundTransparency = props.transparency or 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.zIndex or 1,
		Modal = props.modal,

		[React.Event.Activated] = function()
			if props.onClick then
				props.onClick()
			end
		end,
	})
end

--------------------------------------------------------------------------------
-- Modal
--------------------------------------------------------------------------------

--[[
	props:
		title       string
		subtitle    string?          rendered as a chip beside the title
		headerColor ColorSequence?   defaults to the yellow header gradient
		glyph       string?          icon in the header
		size        UDim2?           explicit size
		width       number?          with contentHeight, sizes the window to fit
		contentHeight number?        natural height of `children`
		tabs        element?         placed on the header's lower edge
		footer      element?
		onClose     function?
		children    { element }      body content
		headerRight element?         e.g. a live currency chip

	Prefer `width` + `contentHeight` over `size`. The window then measures itself
	from its chrome and its content, instead of a hand-picked number that leaves a
	slab of empty panel under short content.
]]
function Overlays.Modal(props)
	local headerHeight = props.headerHeight or 66
	local hasTabs = props.tabs ~= nil
	local tabsHeight = if hasTabs then (props.tabsHeight or 52) else 0
	local footerHeight = if props.footer then (props.footerHeight or 66) else 0
	local radius = Theme.Radius.Panel

	-- Chrome around the content: header, tabs, footer, and the 10px gap above the
	-- content plus 12px below it.
	local chrome = headerHeight + tabsHeight + footerHeight + 22
	local size = props.size
	if not size then
		size = UDim2.fromOffset(props.width or 900, chrome + (props.contentHeight or 460))
	end

	-- The close button is centred inside the header rather than overhanging the
	-- corner, so it lands in exactly the same place on every window. Everything
	-- else on the right of the header is inset to clear it.
	local closeExtent = props.closeExtent or 44
	local rightInset = if props.onClose then (closeExtent + 26) else 18

	-- Windows spring open. Scaling the modal is safe: it is absolutely
	-- positioned, so nothing is being laid out around it.
	local entrance = Motion.useEntrance(Motion.Spring.Bouncy)

	React.useEffect(function()
		Sound.play("open")
	end, {})

	local headerChildren = P.compact(
		P.corner(radius, "HeaderCorner"),
		P.stroke(Theme.Color.Outline, Theme.Stroke.Panel),
		P.gradient(props.headerColor or Theme.Gradient.Yellow),
		e(P.Gloss, { key = "Gloss", radius = radius, strength = 0.66, height = 0.55 }),
		if props.glyph
			then e(Icon, {
				key = "Icon",
				glyph = props.glyph,
				plain = true,
				size = UDim2.fromOffset(headerHeight - 24, headerHeight - 24),
				position = UDim2.new(0, 16, 0.5, 0),
				anchorPoint = Vector2.new(0, 0.5),
				zIndex = 4,
			})
			else nil,
		-- Title and subtitle run together on the LEFT. The subtitle used to be
		-- right-aligned, which parked it against the close button.
		e(P.Group, {
			key = "TitleRow",
			size = UDim2.new(1, -(rightInset + (if props.glyph then headerHeight else 40)), 1, 0),
			position = UDim2.fromOffset(if props.glyph then headerHeight - 4 else 22, 0),
			-- Clipped so an unusually long title can never reach the close button.
			clip = true,
			zIndex = 4,
			layout = P.list({
				direction = Enum.FillDirection.Horizontal,
				padding = 12,
				vAlign = Enum.VerticalAlignment.Center,
			}),
			children = P.compact(
				e(P.Label, {
					key = "Title",
					text = string.upper(props.title or ""),
					textSize = props.titleSize or Theme.TextSize.Title,
					size = UDim2.fromOffset(0, 40),
					automaticSize = Enum.AutomaticSize.X,
					align = Enum.TextXAlignment.Left,
					layoutOrder = 1,
				}),
				if props.subtitle
					then e(Indicators.Badge, {
						key = "Subtitle",
						text = props.subtitle,
						gradient = Theme.Gradient.PanelDeep,
						textSize = Theme.TextSize.Small,
						layoutOrder = 2,
					})
					else nil
			),
		}),
		if props.headerRight
			then e(P.Group, {
				key = "HeaderRight",
				size = UDim2.new(0, 320, 1, 0),
				position = UDim2.new(1, -rightInset, 0.5, 0),
				anchorPoint = Vector2.new(1, 0.5),
				zIndex = 5,
				layout = P.list({
					direction = Enum.FillDirection.Horizontal,
					padding = Theme.Space.S,
					hAlign = Enum.HorizontalAlignment.Right,
					vAlign = Enum.VerticalAlignment.Center,
				}),
				children = { props.headerRight },
			})
			else nil
	)

	local bodyChildren = P.compact(
		e(P.Panel, {
			key = "Header",
			size = UDim2.new(1, 0, 0, headerHeight),
			zIndex = 4,
			radius = radius,
			studs = false,
			children = headerChildren,
		}),
		if hasTabs
			then e(P.Group, {
				key = "Tabs",
				size = UDim2.new(1, -24, 0, tabsHeight),
				position = UDim2.fromOffset(12, headerHeight + 6),
				zIndex = 5,
				children = { props.tabs },
			})
			else nil,
		e(P.Group, {
			key = "Content",
			size = UDim2.new(1, -24, 1, -(headerHeight + tabsHeight + footerHeight + 22)),
			position = UDim2.fromOffset(12, headerHeight + tabsHeight + 10),
			zIndex = 3,
			children = props.children,
		}),
		if props.footer
			then e(P.Group, {
				key = "Footer",
				size = UDim2.new(1, -24, 0, footerHeight),
				position = UDim2.new(0, 12, 1, -8),
				anchorPoint = Vector2.new(0, 1),
				zIndex = 5,
				children = { props.footer },
			})
			else nil,
		if props.onClose
			then e(Buttons.CloseButton, {
				key = "CloseButton",
				onClick = props.onClose,
				extent = closeExtent,
				-- Vertically centred on the header band, inset from the edge.
				position = UDim2.new(1, -14, 0, math.floor(headerHeight / 2)),
				anchorPoint = Vector2.new(1, 0.5),
			})
			else nil
	)

	return e(P.Panel, {
		key = props.key or "Window",
		size = size,
		position = props.position or UDim2.fromScale(0.5, 0.5),
		anchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
		zIndex = props.zIndex or Theme.Layer.Modal,
		shadow = true,
		shadowOffset = 8,
		radius = radius,
		color = Theme.Color.Panel,
		gradient = Theme.Gradient.Panel,
		children = P.append({
			e("UIScale", { key = "Entrance", Scale = Motion.lerp(entrance, 0.9, 1) }),
		}, bodyChildren),
	})
end

--------------------------------------------------------------------------------
-- ConfirmModal
--------------------------------------------------------------------------------

--[[
	props:
		title          "PURCHASE UPGRADE?"
		body           element?   free-form middle block
		lines          { string }?  simple text rows when no body is given
		price          number?    cash price shown large
		robux          number?
		confirmText    default "CONFIRM"
		confirmVariant default "Primary"
		cancelText     default "CANCEL"
		onConfirm / onCancel
		headerColor    ColorSequence?
]]
local CONFIRM_HEADER = 58
local CONFIRM_ACTIONS = 74
local CONFIRM_GAP = 12

function Overlays.ConfirmModal(props)
	local width = props.width or 460
	local lines = props.lines or {}
	local entrance = Motion.useEntrance(Motion.Spring.Bouncy)

	local content = {}
	local order = 0

	-- Height is summed as content is pushed: this modal cannot use
	-- AutomaticSize because it also draws a shadow, and the shadow wrapper would
	-- collapse. See the note on Primitives.Panel.
	local contentHeight = 0
	local function push(child, height: number)
		order += 1
		content[#content + 1] = child
		contentHeight += height + (if order > 1 then CONFIRM_GAP else 0)
	end

	if props.glyph then
		push(
			e(Icon, {
				key = "Icon",
				glyph = props.glyph,
				gradient = props.glyphGradient,
				size = UDim2.fromOffset(76, 76),
				radius = Theme.Radius.Card,
				layoutOrder = order + 1,
			}),
			76
		)
	end

	for index, line in ipairs(lines) do
		local isFirst = index == 1
		-- Secondary lines wrap, so they get two lines of room.
		local height = if isFirst then 32 else 46
		push(
			e(P.Label, {
				key = "Line" .. index,
				text = line,
				textSize = if isFirst then Theme.TextSize.Heading else Theme.TextSize.Body,
				font = if isFirst then Theme.Font.Display else Theme.Font.Bold,
				color = if isFirst then Theme.Color.White else Theme.Color.Gray,
				wrapped = not isFirst,
				vAlign = if isFirst then nil else Enum.TextYAlignment.Top,
				size = UDim2.new(1, 0, 0, height),
				layoutOrder = order + 1,
			}),
			height
		)
	end

	if props.body then
		push(props.body, props.bodyHeight or 60)
	end

	if props.price or props.robux then
		push(
			e(Indicators.PriceTag, {
				key = "Price",
				cash = props.price,
				robux = props.robux,
				textSize = Theme.TextSize.Title,
				layoutOrder = order + 1,
			}),
			42
		)
	end

	local height = CONFIRM_HEADER + 36 + contentHeight + CONFIRM_ACTIONS

	return e(P.Panel, {
		key = props.key or "ConfirmModal",
		size = props.size or UDim2.fromOffset(width, height),
		position = props.position or UDim2.fromScale(0.5, 0.5),
		anchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
		zIndex = props.zIndex or Theme.Layer.Modal + 10,
		shadow = true,
		radius = Theme.Radius.Panel,
		children = {
			e("UIScale", { key = "Entrance", Scale = Motion.lerp(entrance, 0.88, 1) }),
			-- The stack lives in its own group. A UIListLayout placed directly on a
			-- Panel would also lay out the Panel's own full-size stud texture frame,
			-- which pushes every real child out through the bottom of the window.
			e(P.Group, {
				key = "Stack",
				size = UDim2.fromScale(1, 1),
				-- Centred: Content and Actions are inset from the panel edges, and a
				-- vertical list ignores their own Position offsets.
				layout = P.list({ padding = 0, hAlign = Enum.HorizontalAlignment.Center }),
				children = {
					e(P.Panel, {
						key = "Header",
						size = UDim2.new(1, 0, 0, 58),
						layoutOrder = 1,
						radius = Theme.Radius.Panel,
						studs = false,
						children = {
							P.gradient(props.headerColor or Theme.Gradient.Yellow),
							e(P.Gloss, {
								key = "Gloss",
								radius = Theme.Radius.Panel,
								strength = 0.66,
								height = 0.55,
							}),
							e(P.Label, {
								key = "Title",
								text = string.upper(props.title or ""),
								textSize = Theme.TextSize.Heading,
								zIndex = 4,
							}),
						},
					}),
					e(P.Group, {
						key = "Content",
						size = UDim2.new(1, -32, 0, contentHeight + 36),
						position = UDim2.fromOffset(16, 0),
						layoutOrder = 2,
						padding = { y = 18 },
						layout = P.list({
							padding = Theme.Space.M,
							hAlign = Enum.HorizontalAlignment.Center,
						}),
						children = content,
					}),
					e(P.Group, {
						key = "Actions",
						size = UDim2.new(1, -32, 0, CONFIRM_ACTIONS),
						position = UDim2.fromOffset(16, 0),
						layoutOrder = 3,
						padding = { bottom = 14 },
						layout = P.list({
							direction = Enum.FillDirection.Horizontal,
							padding = Theme.Space.M,
							hAlign = Enum.HorizontalAlignment.Center,
							vAlign = Enum.VerticalAlignment.Center,
						}),
						children = {
							e(Buttons.Button, {
								key = "Cancel",
								text = props.cancelText or "CANCEL",
								variant = "Danger",
								size = UDim2.fromOffset((width - 60) / 2, 52),
								layoutOrder = 1,
								onClick = props.onCancel,
							}),
							e(Buttons.Button, {
								key = "Confirm",
								text = props.confirmText or "CONFIRM",
								variant = props.confirmVariant or "Primary",
								size = UDim2.fromOffset((width - 60) / 2, 52),
								layoutOrder = 2,
								disabled = props.confirmDisabled,
								onClick = props.onConfirm,
							}),
						},
					}),
				},
			}),
		},
	})
end

--------------------------------------------------------------------------------
-- Tooltip
--------------------------------------------------------------------------------

--[[
	Hover popup. Sizes itself to its text -- the body was a fixed 38px box with no
	wrapping, which silently clipped the longer potion descriptions.

	`look` hands the tooltip the same fill its anchor uses, so the two cannot drift
	apart: `{ color, gradient, gradientTransparency, transparency, stroke }`, the
	shape of a `Parts.BOOST_VARIANTS` entry. Pass the variant and a fading tile gets
	an equally fading tooltip instead of a near-solid card beside a translucent one.

	A look with `stroke = 0` also drops the drop-shadow: both exist to separate a
	solid card from the scene, and on a fill that fades to nothing they only outline
	the box that is meant to disappear. Legibility survives it because every kit
	label carries its own black outline.

	props: title, body, hint, look, width, position, anchorPoint, zIndex
]]
--- Used when a caller passes no `look`: a mild ramp in the same direction the HUD
--- tiles use, still solid enough to sit over anything.
local DEFAULT_TOOLTIP_LOOK = {
	gradientTransparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.04),
		NumberSequenceKeypoint.new(1, 0.24),
	}),
}

function Overlays.Tooltip(props)
	local width = props.width or 250
	local inset = 10
	local textWidth = width - inset * 2

	--[[
		Measured in absolute pixels and converted back to design units through the
		text column's own known design width. Everything sits under a canvas
		UIScale, so the raw measurement is in screen pixels; that ratio is exact and
		needs no knowledge of the scale.
	]]
	local textRef = React.useRef(nil :: any)
	local measured = Hooks.useMeasure(textRef)
	local contentHeight = if measured.X > 0 then measured.Y * (textWidth / measured.X) else 0
	local height = math.max(props.minHeight or 48, math.ceil(contentHeight) + inset * 2)

	local textChildren = P.compact(
		P.list({ padding = 3 }),
		e(P.Label, {
			key = "Title",
			text = props.title,
			textSize = Theme.TextSize.Body,
			align = Enum.TextXAlignment.Left,
			vAlign = Enum.TextYAlignment.Top,
			wrapped = true,
			automaticSize = Enum.AutomaticSize.Y,
			size = UDim2.fromScale(1, 0),
			layoutOrder = 1,
		}),
		if props.body
			then e(P.Label, {
				key = "Body",
				text = props.body,
				textSize = Theme.TextSize.Small,
				font = Theme.Font.Bold,
				color = Theme.Color.Gray,
				align = Enum.TextXAlignment.Left,
				vAlign = Enum.TextYAlignment.Top,
				wrapped = true,
				automaticSize = Enum.AutomaticSize.Y,
				size = UDim2.fromScale(1, 0),
				layoutOrder = 2,
			})
			else nil,
		if props.hint
			then e(P.Label, {
				key = "Hint",
				text = props.hint,
				textSize = Theme.TextSize.Tiny,
				font = Theme.Font.Bold,
				color = Theme.Color.Gold,
				align = Enum.TextXAlignment.Left,
				size = UDim2.new(1, 0, 0, 18),
				layoutOrder = 3,
			})
			else nil
	)

	local look = props.look or DEFAULT_TOOLTIP_LOOK
	local stroke = if look.stroke ~= nil then look.stroke else Theme.Stroke.Chip

	return e(P.Panel, {
		key = props.key or "Tooltip",
		size = props.size or UDim2.fromOffset(width, height),
		position = props.position,
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex or Theme.Layer.Tooltip,
		-- Chip radius like the tiles; a window's heavier treatment made a hover
		-- popup look like a second panel.
		radius = Theme.Radius.Chip,
		color = look.color or Theme.Color.PanelDark,
		gradient = look.gradient or Theme.Gradient.PanelDeep,
		gradientTransparency = look.gradientTransparency,
		transparency = look.transparency,
		strokeThickness = stroke,
		studs = false,
		-- See the note above: a shadow on a fill that fades out is just a box.
		shadow = stroke ~= 0,
		shadowOffset = 3,
		children = {
			e("Frame", {
				key = "Text",
				ref = textRef,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(textWidth, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Position = UDim2.fromOffset(inset, inset),
			}, textChildren),
		},
	})
end

--------------------------------------------------------------------------------
-- Toast — one notification card. NotificationStack handles the queue.
--------------------------------------------------------------------------------

--[[
	props:
		title    "RARE SCRAP!"
		body     "Golden Engine"
		reward   "+ $4,250"         optional bright bottom line
		accent   ColorSequence?     stripe + title colour
		glyph    string?
]]
--[[
	Toast text is coerced, not trusted.

	A toast is the one component rendered straight from a server payload, so a producer that
	sends the wrong shape crashes it during render -- and an uncaught render error unmounts the
	entire React tree, leaving the player with nothing but the topbar. That happened for real:
	`PlotThemeService` fired the `Notify` remote with a table, `string.upper` threw on it, and one
	hold-E blanked the whole interface.

	Fixing the producer is the actual fix. This makes the blast radius a wrong-looking toast
	instead of a dead UI.
]]
local function asText(value: unknown): string
	local kind = typeof(value)
	if kind == "string" then
		return value :: string
	elseif value == nil then
		return ""
	elseif kind == "number" then
		return tostring(value)
	end
	warn(`[Overlays.Toast] expected string text, got {kind} -- check what fired the notification`)
	return ""
end

function Overlays.Toast(props)
	local accent = props.accent or Theme.Gradient.Green
	local width = props.width or 320
	local glyphInset = if props.glyph then 76 else 22
	local textWidth = width - glyphInset - 14

	--[[
		The card grows to fit its text. Measuring in absolute pixels would be
		wrong -- the whole UI sits under a canvas UIScale -- so the measured box is
		converted back to design units through its own known design width. That
		ratio is exact and needs no knowledge of the scale.
	]]
	local textRef = React.useRef(nil :: any)
	local measured = Hooks.useMeasure(textRef)
	local contentHeight = if measured.X > 0 then measured.Y * (textWidth / measured.X) else 0
	local height = math.max(props.height or 74, math.ceil(contentHeight) + 22)

	local entrance = Motion.useEntrance(Motion.Spring.Bouncy)

	--[[
		TWO LOOKS, ONE SWITCH -- the same pair the event banner offers, chosen from
		`Theme.Variant.Toast` and overridable per call.

			"fade"   the spin-reward treatment: accent dissolving to both edges, no outline
			"card"   the outlined dark slab with the colour stripe down the left

		The fade version drops the stripe. The stripe exists to carry the accent on a neutral card, and
		on a card whose whole fill IS the accent it is a second copy of the same information.

		The measuring below still runs and still sets the height, so a long notification grows in either
		look -- the icon is optional in both, and `x3` collapsing works the same way.
	]]
	if (props.variant or Theme.Variant.Toast) == "fade" then
		local title = if typeof(props.count) == "number" and props.count > 1
			then `{asText(props.title)}  x{props.count}`
			else asText(props.title)
		--- The body carries the detail; a reward line wins it, because that is the part worth reading.
		local detail = if props.reward then asText(props.reward) else asText(props.body)
		return e(FadeBanner.Banner, {
			key = props.key or "Toast",
			title = title,
			detail = if detail ~= "" then detail else nil,
			glyph = props.glyph,
			accent = props.accentName or "Green",
			titleSize = Theme.TextSize.Small,
			detailColor = if props.reward then Theme.Color.Positive else Theme.Color.Gray,
			--[[
				Wraps and grows, exactly as the card variant does. The server sends whole sentences as a
				title -- "Magnet storage full, visit your crusher" -- and the fade banner's default is to
				truncate, which would quietly drop the half that tells the player what to do.

				`textRef` is the same ref the measuring above reads, so the height below is derived from the
				labels this variant actually rendered rather than from the card variant's.
			]]
			wrap = true,
			textRef = textRef,
			width = width,
			height = math.max(height - 12, 56),
			layoutOrder = props.layoutOrder,
			zIndex = props.zIndex,
		})
	end

	local card = e(P.Panel, {
		key = "Card",
		size = UDim2.fromScale(1, 1),
		zIndex = props.zIndex,
		radius = Theme.Radius.Card,
		--[[
			The same dark panel every other HUD readout uses. This was
			`Theme.Color.Card` -- a mid blue with a gloss sheen -- which read as a
			different design language sitting next to the cash and storage slabs.
		]]
		color = Theme.Color.PanelDark,
		gradient = Theme.Gradient.PanelDeep,
		gloss = false,
		studs = false,
		strokeThickness = Theme.Stroke.Card,
		shadow = true,
		shadowOffset = 5,
		children = P.compact(
			-- Colour stripe reads the notification type at a glance.
			e("Frame", {
				key = "Accent",
				BackgroundColor3 = Theme.Color.White,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 8, 1, -10),
				Position = UDim2.new(0, 5, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				ZIndex = 3,
			}, {
				P.corner(4),
				P.gradient(accent),
			}),
			if props.glyph
				then e(Icon, {
					key = "Icon",
					glyph = props.glyph,
					gradient = accent,
					size = UDim2.fromOffset(46, 46),
					position = UDim2.new(0, 20, 0.5, 0),
					anchorPoint = Vector2.new(0, 0.5),
					radius = Theme.Radius.Small,
					zIndex = 3,
				})
				else nil,
			e("Frame", {
				key = "Text",
				ref = textRef,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(textWidth, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Position = UDim2.new(0, glyphInset, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				ZIndex = 3,
			}, {
				P.list({ padding = 2 }),
				e(P.Label, {
					key = "Title",
					--[[
						`x3` when a repeated toast collapsed into this card. Appended to the
						title rather than given its own badge so it costs no layout: the card
						already measures its own text and grows to fit.
					]]
					text = if typeof(props.count) == "number" and props.count > 1
						then `{string.upper(asText(props.title))}  x{props.count}`
						else string.upper(asText(props.title)),
					textSize = Theme.TextSize.Small,
					-- White, not gold: the stripe and icon already carry the accent,
					-- and a third colour on the same card is noise.
					color = props.titleColor or Theme.Color.White,
					align = Enum.TextXAlignment.Left,
					vAlign = Enum.TextYAlignment.Top,
					--[[
						The title wraps too. Most are two words, but the server sends
						whole sentences as a title with no body -- "Magnet storage
						full, visit your crusher" -- and unwrapped that ran straight
						out of the right-hand side of the card.
					]]
					wrapped = true,
					automaticSize = Enum.AutomaticSize.Y,
					size = UDim2.fromScale(1, 0),
					layoutOrder = 1,
				}),
				if props.body
					then e(P.Label, {
						key = "Body",
						text = asText(props.body),
						textSize = Theme.TextSize.Body,
						font = Theme.Font.Bold,
						color = Theme.Color.Gray,
						align = Enum.TextXAlignment.Left,
						vAlign = Enum.TextYAlignment.Top,
						-- Wraps and grows instead of running off the right-hand edge,
						-- which is what "Storage full" used to do.
						wrapped = true,
						automaticSize = Enum.AutomaticSize.Y,
						size = UDim2.fromScale(1, 0),
						layoutOrder = 2,
					})
					else nil,
				if props.reward
					then e(P.Label, {
						key = "Reward",
						text = asText(props.reward),
						textSize = Theme.TextSize.Body,
						color = Theme.Color.Positive,
						align = Enum.TextXAlignment.Left,
						size = UDim2.new(1, 0, 0, 22),
						layoutOrder = 3,
					})
					else nil,
			})
		),
	})

	return e("Frame", {
		key = props.key or "Toast",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, height),
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, {
		e("Frame", {
			key = "Visual",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
		}, {
			e("UIScale", { key = "Entrance", Scale = Motion.lerp(entrance, 0.7, 1) }),
			card,
		}),
	})
end

return Overlays
