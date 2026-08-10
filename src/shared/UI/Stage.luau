--[[
	Stage.luau
	Fixed-size preview canvas.

	UI Labs mounts a story into whatever size the preview pane happens to be,
	which is useless for judging a HUD authored at 1920x1080. Stage centres a
	real device-sized canvas inside the available space and scales it to fit, so
	what you see in the plugin is what ships.

		Stage { device = "desktop" | "mobile", children = { ... } }

	It is a preview harness only -- the shipped ScreenGui uses Hooks.useScale
	against the live viewport instead.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)
local Hooks = require(script.Parent.Hooks)
local P = require(script.Parent.Primitives)

local e = React.createElement

local DEVICES = Theme.Devices

local function Stage(props)
	local containerRef = React.useRef(nil :: any)
	local available = Hooks.useMeasure(containerRef)

	--[[
		The shipped ScreenGui sets ZIndexBehavior.Sibling, where a child always
		draws above its parent. A host GUI we do not own -- the UI Labs plugin
		widget, say -- may be left on Global, where ZIndex is a single global sort
		key and a child with a lower ZIndex than its container vanishes behind it.

		Stories would then render differently from the game. Match the game.
	]]
	React.useEffect(function()
		local container = containerRef.current
		if not container then
			return
		end

		local host = container:FindFirstAncestorWhichIsA("LayerCollector")
		if host and host.ZIndexBehavior ~= Enum.ZIndexBehavior.Sibling then
			host.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		end
	end, {})

	local canvas: Vector2 = props.canvas or DEVICES[props.device or "desktop"] or DEVICES.desktop
	local padding = props.padding or 0

	local scale = 1
	if available.X > 0 and available.Y > 0 then
		scale =
			math.min((available.X - padding * 2) / canvas.X, (available.Y - padding * 2) / canvas.Y)
		scale = math.max(scale, 0.05)
	end

	local canvasChildren = {
		e("UIScale", { key = "Scale", Scale = scale }),
	}
	if props.gameView ~= false then
		-- A flat stand-in for the 3D game behind the UI, so overlays can be
		-- judged for how much of the view they eat.
		canvasChildren[#canvasChildren + 1] = e("Frame", {
			key = "GameView",
			BackgroundColor3 = Color3.fromHex("4E6B78"),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 0,
		}, {
			P.gradient(ColorSequence.new(Color3.fromHex("6E8FA0"), Color3.fromHex("3A4F5C"))),
			e(P.Label, {
				key = "Watermark",
				text = "GAME VIEW",
				textSize = 44,
				color = Color3.fromHex("8FA9B6"),
				stroke = false,
				position = UDim2.fromScale(0.5, 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
				size = UDim2.fromScale(1, 0.2),
			}),
		})
	end
	P.append(canvasChildren, props.children)

	return e("Frame", {
		key = "Stage",
		ref = containerRef,
		BackgroundColor3 = Theme.Color.PanelDark,
		BackgroundTransparency = if props.background == false then 1 else 0,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
	}, {
		e("Frame", {
			key = "Canvas",
			BackgroundTransparency = 1,
			-- Sized in design space; the UIScale inside does the fitting, so
			-- children keep authoring in real pixels.
			Size = UDim2.fromOffset(canvas.X * scale, canvas.Y * scale),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ClipsDescendants = true,
		}, {
			e("Frame", {
				key = "Design",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(canvas.X, canvas.Y),
			}, canvasChildren),
		}),
	})
end

return Stage
