--[[
	Harness.luau
	Shared scaffolding for the UI Labs stories. Not a story itself.

		Screen    mounts a screen inside a Store provider on a device-sized Stage
		Gallery   scrollable spec sheet for the design-system pages
		Row       a labelled row of component samples
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UI = require(ReplicatedStorage.Shared.UI)

local Theme = UI.Theme
local P = UI.Primitives
local Stage = UI.Stage
local Store = UI.Store

local e = React.createElement

local Harness = {}

--------------------------------------------------------------------------------
-- Screen — a store-connected screen on a device canvas
--------------------------------------------------------------------------------

local function Connected(props)
	local state, actions = Store.use()

	-- Stories can pre-open a screen or an item detail so the plugin shows the
	-- interesting state immediately instead of an empty HUD.
	React.useEffect(function()
		if props.screen then
			actions.openScreen(props.screen)
		end
		if props.detail then
			actions.openDetail(props.detail.kind, props.detail.id)
		end
	end, {})

	return e(props.component, {
		key = "Story",
		state = state,
		actions = actions,
		device = props.device,
		scale = props.scale,
		-- Lets a story preview the touch-control offsets on a desktop Studio.
		touch = props.touch,
		-- Opens a tabbed screen straight onto one category.
		tab = props.tab,
	})
end

--[[
	Harness.Screen({
		component = UI.Screens.Upgrades,
		device = "desktop",   -- canvas size
		hud = false,          -- draw the flat game-view backdrop
		live = true,          -- run the simulation tick
	})
]]
function Harness.Screen(props)
	return e(Stage, {
		key = "Stage",
		device = props.device or "desktop",
		gameView = props.gameView ~= false,
		children = {
			e(Store.Provider, {
				-- Stories have no server: always mock, never live remotes.
				key = "Store",
				mock = true,
				children = e(Connected, {
					key = "Connected",
					component = props.component,
					screen = props.screen,
					detail = props.detail,
					device = props.deviceProp,
					scale = props.scale,
					touch = props.touch,
					tab = props.tab,
				}),
			}),
		},
	})
end

--------------------------------------------------------------------------------
-- Gallery — the design-system spec sheet
--------------------------------------------------------------------------------

--[[
	sections = {
		{ title = "Primary", items = { element, ... }, gap = 12, height = nil },
		...
	}
]]
function Harness.Gallery(props)
	local blocks = {}

	for index, section in ipairs(props.sections) do
		local rowChildren = {}
		for itemIndex, item in ipairs(section.items) do
			rowChildren[#rowChildren + 1] = e(P.Group, {
				key = "Item" .. itemIndex,
				size = section.itemSize or UDim2.fromOffset(220, section.height or 70),
				automaticSize = if section.itemSize then nil else Enum.AutomaticSize.None,
				layoutOrder = itemIndex,
				children = { item },
			})
		end

		blocks[#blocks + 1] = e(P.Group, {
			key = section.title,
			size = UDim2.fromScale(1, 0),
			automaticSize = Enum.AutomaticSize.Y,
			layoutOrder = index,
			layout = P.list({ padding = 10 }),
			children = {
				e(P.Label, {
					key = "SectionTitle",
					text = string.upper(section.title),
					textSize = Theme.TextSize.Body,
					color = Theme.Color.Gold,
					align = Enum.TextXAlignment.Left,
					size = UDim2.new(1, 0, 0, 26),
					layoutOrder = 1,
				}),
				e(P.Group, {
					key = "Items",
					size = UDim2.fromScale(1, 0),
					automaticSize = Enum.AutomaticSize.Y,
					layoutOrder = 2,
					layout = P.list({
						direction = Enum.FillDirection.Horizontal,
						padding = section.gap or 12,
						wraps = true,
					}),
					children = rowChildren,
				}),
			},
		})
	end

	return e("Frame", {
		key = "Gallery",
		BackgroundColor3 = Theme.Color.PanelDark,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, {
		e(P.Scroller, {
			key = "Content",
			padding = 20,
			layout = P.list({ padding = 22 }),
			children = P.compact(
				if props.title
					then e(P.Label, {
						key = "Title",
						text = string.upper(props.title),
						textSize = Theme.TextSize.Title,
						align = Enum.TextXAlignment.Left,
						size = UDim2.new(1, 0, 0, 42),
						layoutOrder = 0,
					})
					else nil,
				e(P.Group, {
					key = "Sections",
					size = UDim2.fromScale(1, 0),
					automaticSize = Enum.AutomaticSize.Y,
					layoutOrder = 1,
					layout = P.list({ padding = 24 }),
					children = blocks,
				})
			),
		}),
	})
end

return Harness
