--[[
	Notification toasts.

	The stack sits under the boost timers on the right so it never covers the
	event banner, the menu column, or the mobile touch controls. Press SPAWN to
	push a live toast through the real store, expiry included.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)

local Theme = UI.Theme
local P = UI.Primitives
local Buttons = UI.Buttons
local Mock = UI.Mock
local Stage = UI.Stage
local Store = UI.Store

local e = React.createElement

--- Live demo: toasts go through the store and expire on its tick.
local function LiveStack()
	local state, actions = Store.use()
	local nextIndex, setNextIndex = React.useState(1)

	return e(P.Group, {
		key = "LiveStack",
		size = UDim2.fromScale(1, 1),
		children = {
			e(Buttons.Button, {
				key = "Spawn",
				text = "SPAWN NOTIFICATION",
				glyph = "plus",
				variant = "Primary",
				size = UDim2.fromOffset(320, 60),
				position = UDim2.fromOffset(40, 40),
				onClick = function()
					local template = Mock.notifications[nextIndex]
					actions.notify(template)
					setNextIndex(nextIndex % #Mock.notifications + 1)
				end,
			}),
			e(P.Label, {
				key = "Hint",
				text = "Toasts expire on the store's own tick, newest at the top.",
				textSize = Theme.TextSize.Body,
				font = Theme.Font.Bold,
				color = Theme.Color.Gray,
				align = Enum.TextXAlignment.Left,
				size = UDim2.fromOffset(560, 26),
				position = UDim2.fromOffset(40, 112),
			}),
			e(UI.Screens.Notifications, {
				key = "Notifications",
				toasts = state.toasts,
			}),
		},
	})
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Notifications",
	summary = "Toast styles and the live auto-expiring stack.",
	controls = {
		ShowStatic = UILabs.Boolean(true),
	},
}, function(props)
	local statics = {}
	if props.controls.ShowStatic then
		for index, toast in ipairs(Mock.notifications) do
			statics[#statics + 1] = e(UI.Overlays.Toast, {
				key = "Static" .. index,
				title = toast.title,
				body = toast.body,
				reward = toast.reward,
				glyph = toast.glyph,
				accent = Theme.Gradient[toast.accent],
				layoutOrder = index,
			})
		end
	end

	return e(Stage, {
		key = "Stage",
		device = "desktop",
		children = {
			e(
				Store.Provider,
				{ key = "Store", mock = true, children = e(LiveStack, { key = "Live" }) }
			),
			e(P.Group, {
				key = "Samples",
				size = UDim2.fromOffset(340, 600),
				position = UDim2.fromOffset(40, 170),
				layout = P.list({ padding = 10 }),
				children = statics,
			}),
		},
	})
end)
