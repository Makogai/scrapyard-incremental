--!nonstrict
--[[
	Announcement.luau
	The server-wide banner: full width, top of the screen, above everything.

	This is not a toast. Toasts are the player's own feed -- "you sold scrap", "code
	redeemed" -- they stack in the corner and are easy to ignore, which is correct
	for routine news. This is for the handful of moments the whole server should
	look up: right now, someone hatching a Secret pet.

	Because it is rare it can afford to be loud: it spans the screen, sits above the
	modal layer, sweeps in, holds, and leaves. Use it sparingly. If it starts firing
	for ordinary events it stops working, and the toast channel exists for those.
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

local Announcement = {}

local HEIGHT = 86

--[[
	props:
		title     "SECRET HATCH!"
		body      "Marko hatched Mythic Autumn Dragon"
		accent    ColorSequence, drives the sweep and the glow
		glyph     icon on the left
		model     optional pet/egg model id, rendered in place of the glyph
		modelKind "pet" | "egg"
		top       design pixels from the top of the screen
		sound     cue name, played once when the banner arrives
		celebrate boolean?  sparkles and a sweep, for the rare ones
]]
function Announcement.Banner(props)
	local accent = props.accent or Theme.Gradient.Pink
	local entrance = Motion.useEntrance(Motion.Spring.Bouncy)

	--[[
		A SOUND, ONCE, ON ARRIVAL.

		A server-wide announcement is the one interruption every player in the game gets at the same moment,
		and it was silent -- so anyone not looking at the top of their screen missed it entirely. `celebrate`
		is the cue when the caller asks for one; the banner never picks its own, because a routine
		announcement should not sound like a Secret hatch.

		In a `useEffect` with no dependencies, so it fires when the banner MOUNTS. Playing it during render
		would fire again on every re-render the tick causes.
	]]
	React.useEffect(function()
		if props.sound then
			Sound.play(props.sound)
		end
	end, {})

	--[[
		Drops in from above rather than scaling: the banner is full width, and a
		scaling full-width element reads as the whole screen lurching.
	]]
	local offset = Motion.lerp(entrance, -HEIGHT - 24, 0)

	local ModelView = require(script.Parent.ModelView)
	local Shine = require(script.Parent.Shine)

	return e(P.Group, {
		key = props.key or "Announcement",
		size = UDim2.new(1, 0, 0, HEIGHT),
		position = offset:map(function(value: number)
			return UDim2.new(0.5, 0, 0, (props.top or 0) + value)
		end),
		anchorPoint = Vector2.new(0.5, 0),
		zIndex = props.zIndex or Theme.Layer.Announcement,
		children = P.compact(
			--[[
				CELEBRATION, only when asked for.

				Sparkles and a glow across the whole strip, on an overlay above the wash so it lights the
				banner rather than tinting one element of it. A routine announcement gets none of this -- the
				effect is what tells everyone that what just happened was rare.
			]]
			if props.celebrate
				then e(Shine.Layer, {
					key = "Celebrate",
					sparkles = true,
					sweep = true,
					color = Theme.Color.White,
					zIndex = 8,
				})
				else nil,
			-- Full-bleed wash, brightest in the middle, so the ends melt into the
			-- screen edges instead of stopping at a hard border.
			e("Frame", {
				key = "Wash",
				BackgroundColor3 = Theme.Color.Ink,
				BackgroundTransparency = 0.15,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
			}, {
				P.gradient(
					ColorSequence.new({
						ColorSequenceKeypoint.new(0, Theme.Color.Ink),
						ColorSequenceKeypoint.new(0.5, Theme.Color.PanelDark),
						ColorSequenceKeypoint.new(1, Theme.Color.Ink),
					}),
					{ rotation = 0 }
				),
				e("UIGradient", {
					key = "EdgeFade",
					Rotation = 0,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.22, 0.1),
						NumberSequenceKeypoint.new(0.78, 0.1),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			}),
			-- Accent rules top and bottom, the part that carries the rarity colour.
			e("Frame", {
				key = "TopRule",
				BackgroundColor3 = Theme.Color.White,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 3),
				ZIndex = 4,
			}, { P.gradient(accent, { rotation = 0 }) }),
			e("Frame", {
				key = "BottomRule",
				BackgroundColor3 = Theme.Color.White,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 3),
				Position = UDim2.fromScale(0, 1),
				AnchorPoint = Vector2.new(0, 1),
				ZIndex = 4,
			}, { P.gradient(accent, { rotation = 0 }) }),

			e(P.Group, {
				key = "Content",
				-- Centre column: the banner is full width but the content is not,
				-- so it stays readable on an ultrawide and clear of the topbar.
				size = UDim2.fromOffset(720, HEIGHT),
				position = UDim2.fromScale(0.5, 0),
				anchorPoint = Vector2.new(0.5, 0),
				zIndex = 6,
				layout = P.list({
					direction = Enum.FillDirection.Horizontal,
					padding = 14,
					hAlign = Enum.HorizontalAlignment.Center,
					vAlign = Enum.VerticalAlignment.Center,
				}),
				children = P.compact(
					--[[
						THREE WAYS TO STAMP THE BANNER, cheapest last: a spinning model for a pet, an IMAGE for a
						person (their avatar, so you can see who is talking), a glyph for anything else.
					]]
					if props.image
						then e(Icon, {
							key = "Portrait",
							image = props.image,
							gradient = accent,
							size = UDim2.fromOffset(HEIGHT - 20, HEIGHT - 20),
							radius = Theme.Radius.Small,
							layoutOrder = 1,
						})
						elseif props.model then e(ModelView.View, {
							key = "Model",
							kind = props.modelKind or "pet",
							model = props.model,
							spin = 70,
							size = UDim2.fromOffset(HEIGHT - 14, HEIGHT - 14),
							layoutOrder = 1,
						})
						else e(Icon, {
							key = "Glyph",
							glyph = props.glyph or "star",
							gradient = accent,
							size = UDim2.fromOffset(HEIGHT - 30, HEIGHT - 30),
							radius = Theme.Radius.Small,
							layoutOrder = 1,
						}),
					e(P.Group, {
						key = "Text",
						size = UDim2.fromOffset(520, HEIGHT - 20),
						layoutOrder = 2,
						layout = P.list({ padding = 2, vAlign = Enum.VerticalAlignment.Center }),
						children = P.compact(
							e(P.Label, {
								key = "Title",
								text = string.upper(props.title or ""),
								textSize = Theme.TextSize.Title,
								gradient = accent,
								align = Enum.TextXAlignment.Left,
								size = UDim2.new(1, 0, 0, 36),
								layoutOrder = 1,
							}),
							if props.body
								then e(P.Label, {
									key = "Body",
									text = props.body,
									textSize = Theme.TextSize.Body,
									color = Theme.Color.Gray,
									align = Enum.TextXAlignment.Left,
									vAlign = Enum.TextYAlignment.Top,
									wrapped = true,
									automaticSize = Enum.AutomaticSize.Y,
									size = UDim2.fromScale(1, 0),
									layoutOrder = 2,
								})
								else nil
						),
					})
				),
			})
		),
	})
end

return Announcement
