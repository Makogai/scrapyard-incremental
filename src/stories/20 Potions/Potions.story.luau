--[[
	Active potion tiles -- the bottom-right cluster on the HUD.

	Each tile is the bottle on a gradient slab with the time left directly
	underneath, and hovering it names the potion and quotes its description. In the
	game the row is fed by `state.boosts`, which `Store` builds from `ActiveBoosts`
	and resolves through `GameData.boost`, so the art and copy here are the real
	ones out of `InventoryConfig` rather than story-only stand-ins.

	Every variant renders at once, one row each, with the cash/gears/rebirth
	readouts bottom-left for reference. They all run **top to bottom**:
	`P.gradient` rotates 90 degrees, so keypoint 0 is the top edge.

	The variant list is read out of `Parts.BOOST_VARIANTS` rather than written here,
	so renaming or adding a look cannot leave this story pointing at names that no
	longer exist.

	Controls:

		Extent          tile edge length in design pixels
		Count           tiles per row, to check spacing
		Tooltip         holds every row's tooltip open -- UI Labs cannot hover, so
		                this is the only way to style it. Rows are spaced so the
		                tooltips do not collide.
		OverrideOpacity apply Opacity as a flat transparency to every row instead
		                of each variant's own, for finding a value worth writing
		                down. Note this replaces an alpha ramp with a flat value.
		Opacity         the value used when OverrideOpacity is on
		GameView        the flat stand-in for the 3D game, which is the only honest
		                way to judge a translucent variant

	To change what ships, set `Parts.BOOSTS.variant` -- or retune a row of
	`Parts.BOOST_VARIANTS` -- in `src/shared/UI/Screens/Hud/Parts.luau`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)

local Parts = UI.Screens.HudParts
local Stage = UI.Stage
local Theme = UI.Theme
local P = UI.Primitives

local e = React.createElement

--- The potions the game has. `GameData.boost` takes the `BoostId` or the
--- snapshot's `<BoostId>EndsAt` key.
local BOOST_IDS = { "CashBoost", "StrengthBoost", "LuckBoost", "GodBoost" }

-- Enough vertical room for a row plus the tooltip that opens above the next one.
local ROW_PITCH = 172
local FIRST_ROW = 210

--[[
	Variant names, shipped default first. Enumerated from the module: hardcoding
	them meant a rename broke this story silently, and a Studio session holding an
	older `Shared.UI` in its require cache asked for names that module had never
	heard of -- which renders nothing rather than saying why.
]]
local function variantNames(): { string }
	local names = {}
	for name in pairs(Parts.BOOST_VARIANTS or {}) do
		table.insert(names, name)
	end
	table.sort(names)

	local shipped = Parts.BOOSTS and Parts.BOOSTS.variant
	local shippedIndex = if shipped then table.find(names, shipped) else nil
	if shippedIndex then
		table.remove(names, shippedIndex)
		table.insert(names, 1, shipped)
	end
	return names
end

--- How a variant fills its slab, in words. Tolerant of a variant that declares
--- neither an alpha ramp nor a flat transparency.
local function describeLook(look, controls): string
	if controls.OverrideOpacity then
		return string.format("   flat transparency %.2f (overridden)", controls.Opacity)
	end

	local ramp = look.gradientTransparency
	if ramp then
		local points = ramp.Keypoints
		return string.format(
			"   fades top %.2f -> bottom %.2f",
			points[1].Value,
			points[#points].Value
		)
	end
	return string.format("   flat transparency %.2f", look.transparency or 0)
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Potions",
	summary = "Every potion-tile variant at once, with the HUD readouts alongside for reference.",
	controls = {
		Extent = UILabs.Slider(62, 40, 110, 2),
		Count = UILabs.Slider(2, 1, 4, 1),
		Tooltip = UILabs.Boolean(true),
		OverrideOpacity = UILabs.Boolean(false),
		Opacity = UILabs.Slider(0.18, 0, 0.6, 0.02),
		GameView = UILabs.Boolean(true),
	},
}, function(props)
	local controls = props.controls
	local variants = variantNames()
	local shipped = Parts.BOOSTS and Parts.BOOSTS.variant

	--[[
		A stale require cache is the one thing this story cannot render around, so
		it says so on screen instead of drawing nothing. Reloading the place clears
		it.
	]]
	if #variants == 0 then
		return e(Stage, {
			key = "Stage",
			device = "desktop",
			gameView = false,
			children = {
				e(P.Label, {
					key = "Stale",
					text = "Parts.BOOST_VARIANTS is empty. Studio is holding an older"
						.. " Shared.UI in its require cache -- reload the place.",
					textSize = Theme.TextSize.Body,
					color = Theme.Color.Gold,
					wrapped = true,
					size = UDim2.fromScale(0.7, 0.4),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
				}),
			},
		})
	end

	-- Staggered timers, so the countdown column is not a wall of identical text.
	local boosts = {}
	for index = 1, controls.Count do
		local boostId = BOOST_IDS[index]
		local potion = UI.GameData.boost(boostId)
		boosts[index] = {
			id = boostId,
			label = if potion then potion.name else boostId,
			description = if potion then potion.description else nil,
			image = if potion then potion.image else nil,
			seconds = 600 - index * 137,
		}
	end

	local rows = {}
	for index, variant in ipairs(variants) do
		local top = FIRST_ROW + (index - 1) * ROW_PITCH
		local look = Parts.BOOST_VARIANTS[variant] or {}

		rows[#rows + 1] = e(P.Label, {
			key = variant .. "Label",
			text = string.upper(variant)
				.. (if shipped == variant then "  (SHIPPED)" else "")
				.. describeLook(look, controls),
			textSize = Theme.TextSize.Small,
			color = if shipped == variant then Theme.Color.Gold else Theme.Color.Gray,
			align = Enum.TextXAlignment.Right,
			size = UDim2.fromOffset(520, 24),
			position = UDim2.new(1, -24, 0, top - 26),
			anchorPoint = Vector2.new(1, 0),
		})

		rows[#rows + 1] = e(Parts.BoostTimers, {
			key = variant,
			boosts = boosts,
			extent = controls.Extent,
			variant = variant,
			transparency = if controls.OverrideOpacity then controls.Opacity else nil,
			tooltipVisible = controls.Tooltip,
			position = UDim2.new(1, -24, 0, top),
			anchorPoint = Vector2.new(1, 0),
		})
	end

	return e(Stage, {
		key = "Stage",
		device = "desktop",
		gameView = controls.GameView,
		children = {
			e(P.Group, {
				key = "Hud",
				size = UDim2.fromScale(1, 1),
				children = P.compact(
					e(P.Label, {
						key = "Hint",
						text = "Every variant runs top-to-bottom: keypoint 0 is the top edge",
						textSize = Theme.TextSize.Small,
						color = Theme.Color.Gray,
						align = Enum.TextXAlignment.Left,
						size = UDim2.new(1, -48, 0, 24),
						position = UDim2.fromOffset(24, 24),
					}),
					-- The real HUD readouts, for reference.
					e(Parts.CurrencyStack, {
						key = "Currencies",
						cash = 1_284_500,
						gears = 42,
						prestige = 3,
						position = UDim2.new(0, 24, 1, -24),
						anchorPoint = Vector2.new(0, 1),
					}),
					table.unpack(rows)
				),
			}),
		},
	})
end)
