--[[
	TopBar.luau
	A row of native-looking buttons in the Roblox topbar strip.

	Roblox exposes no API for adding buttons to its own topbar, and its CoreGui
	renders ABOVE every player GUI -- so anything drawn inside that strip is either
	covered by Roblox's own buttons or crammed against them. This row therefore
	sits just BELOW the strip, on the right, and only borrows its styling:

		- a dark translucent rounded square with a white glyph, so it reads as
		  chrome rather than as one of the chunky coloured game buttons
		- top-right, below the measured topbar height, so it never collides with
		  the menu, chat, leaderboard or backpack toggles on the left

	If you enable TopbarPlus or Roblox ever ships a real API, delete this and
	register `TopBar.ITEMS` with it: the ids already match the screen names the
	store's `openScreen` takes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent.Parent
local Theme = require(UI.Theme)
local Hooks = require(UI.Hooks)
local Motion = require(UI.Motion)
local Sound = require(UI.Sound)
local P = require(UI.Primitives)
local Icon = require(UI.Icon)

local e = React.createElement

local TopBar = {}

--- Screens reachable from the topbar. Ids match `actions.openScreen`.
TopBar.ITEMS = {
	{ id = "collection", glyph = "book" },
	{ id = "pets", glyph = "paw" },
	{ id = "shop", glyph = "basket" },
	{ id = "settings", glyph = "sliders" },
}

local BUTTON = 36
local GAP = 6

--- One topbar button, styled to match Roblox's own chrome.
local function NativeButton(props)
	local press = Motion.usePressable({
		hoverScale = 1.08,
		pressScale = 0.94,
		onHover = function()
			Sound.play("hover")
		end,
		onClick = function()
			Sound.play("tap")
			if props.onClick then
				props.onClick()
			end
		end,
	})

	local rootProps = {
		key = props.key,
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(BUTTON, BUTTON),
		LayoutOrder = props.layoutOrder,
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
		}, {
			e("UIScale", { key = "Scale", Scale = press.scale }),
			e("Frame", {
				key = "Plate",
				BackgroundColor3 = Color3.fromRGB(16, 18, 24),
				BackgroundTransparency = if press.hovered then 0.22 else 0.42,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
			}, {
				P.corner(9),
				P.stroke(Theme.Color.White, 1, { transparency = 0.78 }),
				e(Icon, {
					key = "Icon",
					glyph = props.glyph,
					plain = true,
					size = UDim2.fromScale(0.56, 0.56),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					glyphColor = Theme.Color.White,
					zIndex = 3,
				}),
			}),
		}),
	})
end

TopBar.NativeButton = NativeButton

--[[
	props:
		onOpen   function(screenId)
		items    override for TopBar.ITEMS
		inset    right-hand margin, default 12
]]
function TopBar.TopBar(props)
	local items = props.items or TopBar.ITEMS
	local safe = Hooks.useSafeArea()

	local children = {
		P.list({
			direction = Enum.FillDirection.Horizontal,
			padding = GAP,
			hAlign = Enum.HorizontalAlignment.Right,
			vAlign = Enum.VerticalAlignment.Center,
		}),
	}

	for index, item in ipairs(items) do
		children[#children + 1] = e(NativeButton, {
			key = item.id,
			glyph = item.glyph,
			layoutOrder = index,
			onClick = function()
				if props.onOpen then
					props.onOpen(item.id)
				end
			end,
		})
	end

	local span = #items * BUTTON + (#items - 1) * GAP

	return e(P.Group, {
		key = props.key or "TopBar",
		size = UDim2.fromOffset(span, BUTTON),
		-- Below the topbar strip, measured at the live scale. Sitting inside the
		-- strip would put these under Roblox's own buttons, which draw on top.
		position = props.position or UDim2.new(1, -(props.inset or 12), 0, safe.top),
		anchorPoint = props.anchorPoint or Vector2.new(1, 0),
		zIndex = props.zIndex or Theme.Layer.HudOverlay,
		children = children,
	})
end

return TopBar
