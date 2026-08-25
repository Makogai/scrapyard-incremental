--[[
	Item details: magnet, potion and pet.

	All three share one frame, so switching the Item control shows how the same
	shell adapts to different payloads.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)

local Harness = require(script.Parent.Parent.Harness)

local e = React.createElement

local ITEMS = {
	{ label = "Magnet - owned", kind = "magnet", id = "basic" },
	{ label = "Magnet - equipped", kind = "magnet", id = "advanced" },
	{ label = "Magnet - locked", kind = "magnet", id = "blood" },
	{ label = "Potion", kind = "potion", id = "cash" },
	{ label = "Potion - none owned", kind = "potion", id = "god" },
	{ label = "Pet", kind = "pet", id = "Pup" },
	{ label = "Pet - secret", kind = "pet", id = "MythicAutumnDragon" },
	{ label = "Pet - singularity", kind = "pet", id = "Singularity" },
	{ label = "Pet - locked", kind = "pet", id = "NebulaLeviathan" },
}

local LABELS = {}
for index, item in ipairs(ITEMS) do
	LABELS[index] = item.label
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Item Details",
	summary = "Magnet, potion and pet details. Secret and Singularity pets show a two-column stat grid.",
	controls = {
		Item = UILabs.Choose(LABELS, 2),
		Device = UILabs.Choose({ "desktop", "tablet", "mobile" }, 1),
	},
}, function(props)
	local selected = ITEMS[1]
	for _, item in ipairs(ITEMS) do
		if item.label == props.controls.Item then
			selected = item
			break
		end
	end

	return e(Harness.Screen, {
		component = UI.Screens.DetailsModal,
		device = props.controls.Device,
		detail = { kind = selected.kind, id = selected.id },
	})
end)
