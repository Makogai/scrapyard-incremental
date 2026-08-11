--[[
	Motion.luau
	Animation, built on littensy/ripple springs.

		useMotion(initial)          -> binding, motion
		useSpring(target, options)  -> binding that springs whenever target changes
		usePressable(config)        -> hover/press state, scale + sink bindings, handlers
		useEntrance(options)        -> 0 -> 1 binding on mount

	Values arrive as React bindings, so an animating button updates its UIScale
	directly and never re-renders the component tree. That is what makes it
	affordable to animate every button on screen.

	All motions share ONE RunService.Heartbeat connection: ripple accepts a custom
	heartbeat object, so a hundred buttons cost a hundred cheap table steps, not a
	hundred engine connections.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local Ripple = require(ReplicatedStorage.Packages.Ripple)

local Motion = {}

--------------------------------------------------------------------------------
-- Spring presets. Tension/friction, matching ripple's own config shape.
--------------------------------------------------------------------------------

Motion.Spring = {
	-- UI feedback: fast, barely any overshoot
	Snappy = { tension = 460, friction = 28 },
	-- Press down / release: very fast, no wobble
	Press = { tension = 760, friction = 36 },
	-- Panels and meters settling
	Gentle = { tension = 200, friction = 24 },
	-- Windows opening: a little cartoon overshoot
	Bouncy = { tension = 300, friction = 17 },
	-- Long travel
	Slow = { tension = 130, friction = 26 },
}

--------------------------------------------------------------------------------
-- Shared heartbeat
--------------------------------------------------------------------------------

local listeners: { (number) -> () } = {}
local connection: RBXScriptConnection? = nil

local sharedHeartbeat = {}

function sharedHeartbeat:Connect(callback: (number) -> ())
	listeners[#listeners + 1] = callback

	if not connection then
		connection = RunService.Heartbeat:Connect(function(deltaTime)
			-- Reverse iteration so a disconnect mid-step cannot skip a listener.
			for index = #listeners, 1, -1 do
				listeners[index](deltaTime)
			end
		end)
	end

	return {
		Disconnect = function()
			local index = table.find(listeners, callback)
			if index then
				table.remove(listeners, index)
			end
			if #listeners == 0 and connection then
				connection:Disconnect()
				connection = nil
			end
		end,
	}
end

Motion.heartbeat = sharedHeartbeat

--------------------------------------------------------------------------------
-- Hooks
--------------------------------------------------------------------------------

--- A ripple motion paired with a React binding.
function Motion.useMotion(initial: any)
	local binding, setBinding = React.useBinding(initial)

	-- Held in a ref rather than a memo: React is free to discard a memo, and a
	-- discarded motion would leak its heartbeat subscription.
	local motionRef = React.useRef(nil :: any)
	if not motionRef.current then
		motionRef.current =
			Ripple.createMotion(initial, { heartbeat = sharedHeartbeat, start = true })
	end
	local motion = motionRef.current

	React.useEffect(function()
		-- Ripple stops notifying once a motion settles, so this costs nothing
		-- while idle.
		local disconnect = motion:onStep(function(value)
			setBinding(value)
		end)

		return function()
			disconnect()
			motion:destroy()
		end
	end, {})

	return binding, motion
end

--[[
	An occasional attention wiggle: idle most of the time, then a short spring
	back and forth. Returns a rotation binding in degrees, so it drives a
	`Rotation` property without re-rendering.

	Deliberately built on the shared heartbeat and a single motion rather than a
	`task.delay` loop, so it costs nothing while settled and dies with the
	component.

	options:
		every    seconds between wiggles, default 6
		angle    peak rotation in degrees, default 4
		shakes   half-swings per wiggle, default 4
		delay    seconds before the first wiggle, default `every`
]]
function Motion.useWiggle(options: any?)
	local config = options or {}
	local every = config.every or 6
	local angle = config.angle or 4
	local shakes = config.shakes or 4

	local binding, motion = Motion.useMotion(0)

	React.useEffect(function()
		local elapsed = -(config.delay or every)
		local swingsLeft = 0
		local direction = 1

		local disconnect = Motion.heartbeat:Connect(function(deltaTime)
			elapsed += deltaTime

			if swingsLeft > 0 then
				-- Settled enough: throw it the other way.
				if math.abs(motion:get() - direction * angle) < angle * 0.25 then
					swingsLeft -= 1
					direction = -direction
					local target = if swingsLeft == 0 then 0 else direction * angle
					motion:spring(target, Motion.Spring.Snappy)
				end
				return
			end

			if elapsed >= every then
				elapsed = 0
				swingsLeft = shakes
				direction = 1
				motion:spring(angle, Motion.Spring.Snappy)
			end
		end)

		return function()
			disconnect:Disconnect()
		end
	end, { every, angle, shakes })

	return binding
end

--[[
	A value that climbs forever at `degreesPerSecond`, for something that idles in motion.

	NOT a spring, and deliberately not a Ripple motion either. A spring settles, and settling is the
	opposite of what an idle wheel wants -- it should be visibly alive before anyone touches it, which
	is what tells the player the thing is interactive at all. Ripple only notifies `onStep` while its
	solver is running, so driving it with `set` every frame is relying on behaviour that is not what
	`set` is for.

	So this is a bare `useBinding` updated from the shared heartbeat: one connection, one addition and
	one binding write per frame. Wrapped at 360 so the number cannot grow without bound over a long
	session, and it stops accumulating while `enabled` is false so a wheel mid-spin is not fighting its
	own idle drift.
]]
function Motion.useSpin(degreesPerSecond: number, enabled: boolean?)
	local binding, setBinding = React.useBinding(0)

	React.useEffect(function()
		if enabled == false then
			return
		end
		local angle = 0
		local disconnect = Motion.heartbeat:Connect(function(deltaTime)
			angle = (angle + degreesPerSecond * deltaTime) % 360
			setBinding(angle)
		end)
		return function()
			disconnect:Disconnect()
		end
	end, { degreesPerSecond, enabled })

	return binding
end

--- Springs toward `target` whenever it changes. Read-only convenience wrapper.
function Motion.useSpring(target: any, options: any?)
	local binding, motion = Motion.useMotion(target)

	React.useEffect(function()
		motion:spring(target, options or Motion.Spring.Gentle)
	end, { target })

	return binding
end

--- 0 -> 1 once, on mount. Map it to scale, offset or transparency.
function Motion.useEntrance(options: any?)
	local binding, motion = Motion.useMotion(0)

	React.useEffect(function()
		motion:spring(1, options or Motion.Spring.Bouncy)
	end, {})

	return binding
end

--[[
	usePressable — the shared interaction model for every pressable surface.

	Returns:
		hovered  boolean        for hover washes
		pressed  boolean
		scale    binding<number>  put on a UIScale inside the button
		sink     binding<number>  0..1, how far the face has sunk onto its base
		events   table            merge into the button's props

	The scale binding belongs on a UIScale inside an inner frame, never on the
	element a layout is measuring -- scaling a layout child shifts its siblings.
]]
function Motion.usePressable(config: any?)
	local settings = config or {}
	local disabled = settings.disabled == true

	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)

	local scale, scaleMotion = Motion.useMotion(1)
	local sink, sinkMotion = Motion.useMotion(0)

	local hoverScale = settings.hoverScale or 1.045
	local pressScale = settings.pressScale or 0.975

	React.useEffect(function()
		local target = 1
		if not disabled then
			if pressed then
				target = pressScale
			elseif hovered then
				target = hoverScale
			end
		end
		scaleMotion:spring(target, if pressed then Motion.Spring.Press else Motion.Spring.Snappy)
	end, { hovered, pressed, disabled, hoverScale, pressScale })

	React.useEffect(function()
		sinkMotion:spring(if pressed and not disabled then 1 else 0, Motion.Spring.Press)
	end, { pressed, disabled })

	local events = {
		[React.Event.MouseEnter] = function()
			setHovered(true)
			if not disabled and settings.onHover then
				settings.onHover()
			end
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
			setPressed(false)
		end,
		[React.Event.MouseButton1Down] = function()
			setPressed(true)
		end,
		[React.Event.MouseButton1Up] = function()
			setPressed(false)
		end,
		[React.Event.TouchTap] = function()
			-- Touch has no hover, so give it the press flash explicitly.
			setPressed(true)
			task.delay(0.09, function()
				setPressed(false)
			end)
		end,
		[React.Event.Activated] = function()
			if disabled then
				return
			end
			if settings.onClick then
				settings.onClick()
			end
		end,
	}

	return {
		hovered = hovered and not disabled,
		pressed = pressed and not disabled,
		scale = scale,
		sink = sink,
		events = events,
	}
end

--------------------------------------------------------------------------------
-- Binding helpers
--------------------------------------------------------------------------------

--- Maps a 0..1 binding onto a pixel Y offset, for press sink depth.
function Motion.offsetY(binding, depth: number)
	return binding:map(function(value)
		return UDim2.fromOffset(0, value * depth)
	end)
end

--- Maps a 0..1 binding onto a horizontal fill size.
function Motion.fillX(binding)
	return binding:map(function(value)
		return UDim2.fromScale(math.clamp(value, 0, 1), 1)
	end)
end

--- Lerps a 0..1 entrance binding between two numbers.
function Motion.lerp(binding, from: number, to: number)
	return binding:map(function(value)
		return from + (to - from) * value
	end)
end

return Motion
