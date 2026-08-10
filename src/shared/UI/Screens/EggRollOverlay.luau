--!nonstrict
--[[
	EggRollOverlay.luau
	The hatch. Takes over the whole screen while an egg opens.

	Two phases, driven by the `eggRoll` atom:

		shaking   the egg alone on a dimmed screen, rattling, building up
		revealed  a burst, then the pet turning slowly with its name and rarity

	The HUD is hidden for the duration -- `App` stops drawing it while this is up.
	That is the point of a takeover: nothing competes with the reveal, and there is
	nothing to misclick.

	The server decides what hatched. This overlay never picks a pet; it shows the
	`PetId` the `PetResult` remote sent back, and the shake is simply the wait for
	that round trip dressed up. If the server rejects the roll the atom clears and
	the overlay leaves without a reveal.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Motion = require(UI.Motion)
local Sound = require(UI.Sound)
local P = require(UI.Primitives)
local Indicators = require(UI.Components.Indicators)
local Overlays = require(UI.Components.Overlays)
local ModelView = require(UI.Components.ModelView)

local e = React.createElement

--- How hard the egg rattles, and how fast.
local SHAKE_DEGREES = 9
local SHAKE_PERIOD = 0.09

--[[
	The egg, rattling. Rotation is driven straight off the heartbeat rather than a
	spring: a shake wants a hard reversal at each end, and a spring rounds exactly
	that off.
]]
local function ShakingEgg(props)
	local rotation, setRotation = React.useBinding(0)

	React.useEffect(function()
		local elapsed = 0
		local nextShake = 0
		local swing = 1

		local connection = Motion.heartbeat:Connect(function(deltaTime)
			elapsed += deltaTime
			if elapsed < nextShake then
				return
			end
			nextShake = elapsed + SHAKE_PERIOD
			swing = -swing
			setRotation(swing * SHAKE_DEGREES)
		end)

		-- One cue per swing would be a machine gun; every third reads as a rattle.
		local sounds = task.spawn(function()
			while true do
				Sound.play("shake")
				task.wait(SHAKE_PERIOD * 3)
			end
		end)

		return function()
			connection:Disconnect()
			task.cancel(sounds)
		end
	end, {})

	return e(P.Group, {
		key = props.key or "ShakingEgg",
		size = UDim2.fromOffset(280, 280),
		position = UDim2.fromScale(0.5, 0.46),
		anchorPoint = Vector2.new(0.5, 0.5),
		zIndex = 6,
		children = {
			e("Frame", {
				key = "Pivot",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Rotation = rotation,
			}, {
				e(ModelView.View, {
					key = "Egg",
					kind = "egg",
					model = props.eggId,
					size = UDim2.fromScale(1, 1),
					glyph = "crate",
				}),
			}),
		},
	})
end

--[[
	The pet, revealed. A burst ring expands and fades, the model turns, and the name
	and rarity sit underneath.
]]
local function Reveal(props)
	local pet = props.pet
	local style = Theme.rarity(pet.rarity)
	local burst = Motion.useEntrance(Motion.Spring.Slow)

	React.useEffect(function()
		Sound.play(if pet.rarity == "Secret" then "secret" else "poof")
	end, {})

	return e(P.Group, {
		key = props.key or "Reveal",
		size = UDim2.fromOffset(520, 520),
		position = UDim2.fromScale(0.5, 0.46),
		anchorPoint = Vector2.new(0.5, 0.5),
		zIndex = 6,
		children = P.compact(
			-- Burst: a ring that expands past the pet and fades out behind it.
			e("Frame", {
				key = "Burst",
				BackgroundColor3 = style.color,
				BackgroundTransparency = burst:map(function(value: number)
					return 0.35 + value * 0.65
				end),
				BorderSizePixel = 0,
				Size = burst:map(function(value: number)
					local extent = 120 + value * 380
					return UDim2.fromOffset(extent, extent)
				end),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 2,
			}, { P.corner(999) }),
			e(ModelView.View, {
				key = "Pet",
				kind = "pet",
				model = pet.model,
				spin = 55,
				glyph = "paw",
				size = UDim2.fromOffset(300, 300),
				position = UDim2.fromScale(0.5, 0.42),
				anchorPoint = Vector2.new(0.5, 0.5),
				zIndex = 5,
			}),
			e(P.Label, {
				key = "Name",
				text = pet.name,
				textSize = Theme.TextSize.Hero,
				gradient = style.gradient,
				size = UDim2.new(1, 0, 0, 56),
				position = UDim2.fromScale(0.5, 0.78),
				anchorPoint = Vector2.new(0.5, 0.5),
				zIndex = 7,
			}),
			e(Indicators.RarityBadge, {
				key = "Rarity",
				rarity = pet.rarity,
				textSize = Theme.TextSize.Body,
				size = UDim2.fromOffset(190, 34),
				position = UDim2.fromScale(0.5, 0.88),
				anchorPoint = Vector2.new(0.5, 0.5),
				zIndex = 7,
			}),
			e(P.Label, {
				key = "Dismiss",
				text = "click anywhere to continue",
				textSize = Theme.TextSize.Small,
				color = Theme.Color.GrayDark,
				size = UDim2.new(1, 0, 0, 22),
				position = UDim2.fromScale(0.5, 0.97),
				anchorPoint = Vector2.new(0.5, 0.5),
				zIndex = 7,
			})
		),
	})
end

--[[
	props:
		roll     { EggId, Phase, PetId? } from the `eggRoll` atom
		pet      resolved pet record for `PetId`, when revealed
		onDismiss
]]
local function EggRollOverlay(props)
	local roll = props.roll
	if roll == nil then
		return nil
	end

	local revealed = roll.Phase == "revealed" and props.pet ~= nil

	return e(P.Group, {
		key = props.key or "EggRoll",
		size = UDim2.fromScale(1, 1),
		zIndex = Theme.Layer.Modal + 40,
		children = P.compact(
			--[[
				Heavier than a window's backdrop: this is a takeover, and the game
				view should read as switched off rather than merely behind something.
				Only clickable once revealed, so a click cannot skip the shake.
			]]
			e(Overlays.Backdrop, {
				key = "Backdrop",
				transparency = 0.22,
				zIndex = 1,
				onClick = if revealed then props.onDismiss else nil,
			}),
			if revealed
				then e(Reveal, { key = "Reveal", pet = props.pet })
				else e(ShakingEgg, { key = "Egg", eggId = roll.EggId })
		),
	})
end

return EggRollOverlay
