--[[
	NotificationStack.luau

	Toasts stack downward from the top-right, newest first. The store expires them
	on its own tick, so this component is purely presentational.

	Each toast sizes itself to its text, so the stack's own height is a generous
	upper bound rather than a measurement -- the list layout does the real work.

	Kept clear of the top-centre event banner and the left menu column so nothing
	important is ever covered.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local P = require(UI.Primitives)
local Overlays = require(UI.Components.Overlays)

local e = React.createElement

local function NotificationStack(props)
	local toasts = props.toasts or {}
	if #toasts == 0 then
		return nil
	end

	local cards = {}
	for index, toast in ipairs(toasts) do
		cards[#cards + 1] = e(Overlays.Toast, {
			key = "Toast" .. toast.Id,
			title = toast.Title,
			-- Repeats collapse into one card in `Bridge.notify`; this is how the player can
			-- still tell it happened more than once.
			count = toast.Count,
			body = toast.Body,
			reward = toast.Reward,
			glyph = toast.Glyph,
			accent = Theme.Gradient[toast.Accent or "Green"],
			width = props.width or 320,
			layoutOrder = index,
		})
	end

	return e(P.Group, {
		key = props.key or "Notifications",
		size = UDim2.fromOffset(props.width or 320, 460),
		position = props.position or UDim2.new(1, -24, 0, 130),
		anchorPoint = props.anchorPoint or Vector2.new(1, 0),
		zIndex = props.zIndex or Theme.Layer.Toast,
		layout = P.list({
			padding = 8,
			hAlign = Enum.HorizontalAlignment.Right,
		}),
		children = cards,
	})
end

return NotificationStack
