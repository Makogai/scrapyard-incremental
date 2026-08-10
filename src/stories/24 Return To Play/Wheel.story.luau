--[[
	The prize wheel component on its own, which is where the geometry gets judged.

	Reviewed in isolation rather than only inside the spin screen because the things most likely to be
	wrong are structural: whether the wedges meet cleanly, whether the labels stay inside their wedge
	at every angle, and whether the count still works when the config changes length.

	`Segments` drives that last one -- drag it down to 4 and up to 10 and the wedges should stay tidy
	at every step. `Rotation` parks the wheel at any angle, which is how you check that a wedge under
	the pointer really is the one the screen would claim won.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.RewardsConfig)

local Harness = require(script.Parent.Parent.Harness)

local e = React.createElement
local ALL = RewardsConfig.Spin.Segments

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Wheel",
	summary = "Pie-wedge prize wheel: segment count, rotation, and the best-prize treatment.",
	controls = {
		Segments = UILabs.Slider(#ALL, 3, 10, 1),
		Rotation = UILabs.Slider(0, -360, 360, 5),
		Extent = UILabs.Slider(392, 240, 520, 8),
		--- The gold wedge and its shine follow the `Best` flag, so this proves it is data-driven.
		ShowBest = UILabs.Boolean(true),
	},
}, function(props)
	local controls = props.controls

	--[[
		Built by cycling the real config rather than inventing segments, so the labels and colours under
		review are the ones that will ship. Cycling means a count above the config length repeats
		entries, which is fine -- the point is the geometry, not the prize list.
	]]
	local segments = {}
	for index = 1, controls.Segments do
		local source = ALL[((index - 1) % #ALL) + 1]
		segments[index] = {
			Id = `Seg{index}`,
			Label = source.Label,
			Glyph = source.Glyph,
			Accent = source.Accent,
			Best = controls.ShowBest and index == controls.Segments,
		}
	end

	return e(Harness.Gallery, {
		title = "Prize wheel",
		sections = {
			{
				title = "Wheel (use the controls panel)",
				items = {
					e(UI.Wheel, {
						key = "Wheel",
						segments = segments,
						rotation = controls.Rotation,
						extent = controls.Extent,
					}),
				},
				itemSize = UDim2.fromOffset(controls.Extent + 20, controls.Extent + 46),
			},
		},
	})
end)
