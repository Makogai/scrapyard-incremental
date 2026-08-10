--[[
	Hooks.luau
	Small shared hooks.

		useViewport   live camera viewport size
		useScale      reference-space -> screen scale factor
		useMeasure    AbsoluteSize of a host instance, for anything that has to
		              know its own pixel size (the stud grid, the preview Stage)
		useTicker     re-renders on an interval, for countdowns
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)

local Hooks = {}

--- Camera viewport size, kept in sync with window resizes.
function Hooks.useViewport(): Vector2
	local camera = Workspace.CurrentCamera
	local size, setSize = React.useState(if camera then camera.ViewportSize else Theme.Reference)

	React.useEffect(function()
		local current = Workspace.CurrentCamera
		if not current then
			return
		end

		setSize(current.ViewportSize)
		local connection = current:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			setSize(current.ViewportSize)
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	return size
end

--[[
	Scale factor that maps the 1920x1080 design space onto the current screen.

	Height-driven with a width guard, then clamped: chunky simulator UI reads
	better slightly small on huge monitors than stretched, and mobile needs a
	floor so touch targets stay tappable.
]]
function Hooks.useScale(): number
	local viewport = Hooks.useViewport()

	return React.useMemo(function()
		local byHeight = viewport.Y / Theme.Reference.Y
		local byWidth = viewport.X / Theme.Reference.X
		local scale = math.min(byHeight, byWidth * 1.25)
		--[[
			The floor used to be 0.55, which on a landscape phone (about 750x361)
			forced the design canvas down to ~1364x656 -- too short to hold the
			left column, the bottom row and Roblox's touch controls at once. 0.42
			buys back the vertical room while keeping buttons big enough to hit.
		]]
		return math.clamp(scale, 0.42, 1.35)
	end, { viewport })
end

--- True on phone-sized screens, where the HUD collapses to the mobile layout.
--[[
	True on a device driven by touch. This is not the same question as
	`useIsMobile`: it asks whether Roblox is drawing its own thumbstick and jump
	button over the bottom corners, which is what the HUD has to dodge.
]]
function Hooks.useIsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

function Hooks.useIsMobile(): boolean
	local viewport = Hooks.useViewport()
	return viewport.X < 900 or viewport.Y < 500
end

--[[
	Height of the Roblox topbar strip, in REAL pixels.

	GuiService.TopbarInset is the engine's own answer and accounts for platform and
	device safe area; GetGuiInset is the older fallback. The result is clamped: a
	zero would put the HUD under the topbar, and a silly value would push it off
	screen.
]]
function Hooks.useTopbarHeight(): number
	local function measure(): number
		local height = 0

		local ok, inset = pcall(function()
			return GuiService.TopbarInset
		end)
		if ok and typeof(inset) == "Rect" then
			height = inset.Max.Y - inset.Min.Y
		end

		if height <= 0 then
			height = GuiService:GetGuiInset().Y
		end

		return math.clamp(height, Theme.Safe.TopPixels, 96)
	end

	local height, setHeight = React.useState(measure)

	React.useEffect(function()
		-- GetPropertyChangedSignal errors outright on an engine that does not have
		-- TopbarInset, so the subscription is optional too.
		local ok, connection = pcall(function()
			return GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
				setHeight(measure())
			end)
		end)

		if not ok or not connection then
			return
		end

		return function()
			connection:Disconnect()
		end
	end, {})

	return height
end

--[[
	Screen insets in DESIGN pixels, ready to drop straight into a layout.

		top     clears the Roblox topbar at the current UIScale
		left    width Roblox's own buttons occupy inside that strip
		width   viewport width in design space, for "does this fit" decisions
]]
function Hooks.useSafeArea()
	local scale = Hooks.useScale()
	local viewport = Hooks.useViewport()
	local topPixels = Hooks.useTopbarHeight()

	return React.useMemo(function()
		return {
			top = math.ceil((topPixels + 6) / scale),
			left = math.ceil(Theme.Safe.TopLeftPixels / scale),
			width = viewport.X / scale,
			height = viewport.Y / scale,
			scale = scale,
		}
	end, { scale, viewport, topPixels } :: { any })
end

--- AbsoluteSize of the instance held by `ref`.
function Hooks.useMeasure(ref): Vector2
	local size, setSize = React.useState(Vector2.zero)

	React.useEffect(function()
		local instance = ref.current
		if not instance then
			return
		end

		setSize(instance.AbsoluteSize)
		local connection = instance:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			setSize(instance.AbsoluteSize)
		end)

		return function()
			connection:Disconnect()
		end
	end, { ref })

	return size
end

--- Re-renders every `interval` seconds. Returns the accumulated tick count.
function Hooks.useTicker(interval: number?): number
	local step = interval or 1
	local tick, setTick = React.useState(0)

	React.useEffect(function()
		local accumulator = 0
		local connection = RunService.Heartbeat:Connect(function(delta)
			accumulator += delta
			if accumulator >= step then
				accumulator -= step
				setTick(function(previous)
					return previous + 1
				end)
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, { step })

	return tick
end

return Hooks
