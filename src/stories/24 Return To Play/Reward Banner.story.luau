--[[
	The reward announcement banner, in every shape it has to take.

	This is what replaced the spin wheel's COLLECT button: the reward is granted the moment the server
	resolves a spin, so there was nothing left to collect -- only something to announce.

	Worth reviewing on its own because the thing most likely to be wrong is the symmetric gradient
	fall-off. It has to read as a banner arriving rather than a card sitting there, and that depends
	entirely on whether both edges vanish cleanly against whatever is behind them. Toggle `GameView` to
	check it over the world rather than over a flat panel.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.RewardsConfig)

local Harness = require(script.Parent.Parent.Harness)

local e = React.createElement
local SEGMENTS = RewardsConfig.Spin.Segments

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Reward Banner",
	summary = "Reward announcement: gradient fade both sides, icon well, money or item.",
	controls = {
		Width = UILabs.Slider(460, 300, 620, 10),
		Shine = UILabs.Boolean(true),
	},
}, function(props)
	local controls = props.controls

	--[[
		Every real spin prize, so the icon choice and the accent are reviewed against the actual config
		rather than invented examples. `glyphFor` is the component's own resolver -- if it picks a coin
		for a potion, that shows up here.
	]]
	local banners = {}
	for _, segment in ipairs(SEGMENTS) do
		banners[#banners + 1] = e(UI.RewardToast.Banner, {
			key = segment.Id,
			title = segment.Label,
			detail = "ADDED TO YOUR ACCOUNT",
			glyph = UI.RewardToast.glyphFor(segment),
			accent = segment.Accent,
			best = controls.Shine and segment.Best == true,
			width = controls.Width,
		})
	end

	return e(Harness.Gallery, {
		title = "Reward banner",
		sections = {
			{
				title = "Every spin prize (the real config)",
				items = banners,
				itemSize = UDim2.fromOffset(controls.Width + 12, 104),
			},
			{
				title = "No detail line",
				items = {
					e(UI.RewardToast.Banner, {
						key = "TitleOnly",
						title = "$25,000",
						glyph = "coin",
						accent = "Green",
						width = controls.Width,
					}),
				},
				itemSize = UDim2.fromOffset(controls.Width + 12, 104),
			},
		},
	})
end)
