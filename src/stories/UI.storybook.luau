--[[
	UI.storybook.luau
	Entry point for the UI Labs Studio plugin.

	UI Labs scans the DataModel for modules whose name ends in `.storybook`, so
	installing the plugin and opening this place is all the setup needed -- no
	extra wiring, no play-testing to see a screen.

	Plugin: https://create.roblox.com/store/asset/14293316215/

	Stories live beside this file and are named `*.story.luau`. Each one is built
	with UILabs.CreateReactStory so React state and hooks work inside the plugin
	exactly as they do in game.
]]

return {
	name = "SCRAPYARD UI",
	storyRoots = { script.Parent },
	groupRoots = true,
}
