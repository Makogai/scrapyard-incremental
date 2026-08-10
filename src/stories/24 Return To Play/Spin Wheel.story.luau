--[[
	The daily spin wheel, in all three of its states.

	The wheel is decoration over a decided result -- the server picks the segment and sends back an
	index -- so the story drives it by setting the same `spinRoll` atom the real `SpinResult` remote
	writes. Pressing SPIN in the story runs the mock action, which fakes exactly that round trip.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.RewardsConfig)
local Atoms = require(ReplicatedStorage.Shared.UI.State.Atoms)

local Harness = require(script.Parent.Parent.Harness)

local e = React.createElement

local PHASES = { "idle", "spinning", "revealed" }

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Spin Wheel",
	summary = "Daily spin wheel: idle, spinning, and the revealed prize.",
	controls = {
		Device = UILabs.Choose({ "desktop", "tablet", "mobile" }, 1),
		GameView = UILabs.Boolean(true),
		Phase = UILabs.Choose(PHASES, 1),
		--- Which segment the "server" chose, so every prize row can be reviewed lit.
		Segment = UILabs.Slider(8, 1, #RewardsConfig.Spin.Segments, 1),
		SpinsAvailable = UILabs.Slider(2, 0, 10, 1),
	},
}, function(props)
	local controls = props.controls

	--[[
		Written on every render rather than in an effect. A story is re-rendered when a control moves
		and nothing else, so this is the cheapest way to keep the atoms and the controls in step --
		and it means dragging the Segment slider walks the highlight down the reel live.
	]]
	Atoms.spinsAvailable(controls.SpinsAvailable)
	local index = math.clamp(controls.Segment, 1, #RewardsConfig.Spin.Segments)
	local segment = RewardsConfig.Spin.Segments[index]
	if controls.Phase == "idle" then
		Atoms.spinRoll(nil)
	else
		Atoms.spinRoll({
			Phase = controls.Phase,
			SegmentId = segment.Id,
			Index = index,
			Label = segment.Label,
		})
	end

	return e(Harness.Screen, {
		component = UI.Screens.Spin,
		device = controls.Device,
		gameView = controls.GameView,
	})
end)
