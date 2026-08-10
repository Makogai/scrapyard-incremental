--!nonstrict
--[[
	EggSummonScreen.luau
	The egg podium window: what is inside this egg, and the button to roll it.

	Opened by the hold-E prompt on `Workspace.NewMap.EggSummonPodium`, which fires
	`OpenEggSummon` with the egg's id.

	Two rows rather than one line of six, so the cards stay big enough to read on a
	phone:

		Common     Uncommon   Rare
		Epic       Legendary  SECRET (wider, with its own VFX layer)

	Each card carries only what belongs on a "what can I roll" screen: the pet, its
	name, its rarity and its drop chance. No owned counts and no duplicate badges --
	that is inventory information, and it lives in the Pets window.

	An undiscovered pet renders as a solid black silhouette of the real model with its
	name as `???`: the shape is the tease. The Secret keeps its effects either way, so
	a locked Secret is a bright halo around a black shape.

	Contents come from `GameData.eggRoll`, which reads `PetConfig`, so changing an
	egg's pets needs no change here. The Secret's chance arrives marked `hidden`
	rather than as a number, so its real odds never reach the client.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Format = require(UI.Format)
local GameData = require(UI.GameData)
local P = require(UI.Primitives)
local Buttons = require(UI.Components.Buttons)
local Overlays = require(UI.Components.Overlays)
local ModelView = require(UI.Components.ModelView)
local SecretVFX = require(UI.Components.SecretVFX)

local e = React.createElement

--[[
	Card footprints. The Secret is **wider only** -- a taller card made the bottom
	row sit unevenly and read as a mistake rather than as emphasis. Extra width plus
	its VFX layer is enough to carry the importance.
]]
local CARD_HEIGHT = 200
local CARD = Vector2.new(172, CARD_HEIGHT)
local SECRET_CARD = Vector2.new(268, CARD_HEIGHT)
local GAP = 12
--- Breathing room between the cards and the window edge.
local INSET = 10

--[[
	One pet.

	Deliberately few strokes: the panel's own outline and nothing else boxed. The
	rarity is coloured text rather than a badge chip, which keeps it readable without
	adding a second border inside a small card.
]]
local function PetCard(props)
	local pet = props.pet
	local style = Theme.rarity(pet.rarity)
	local owned = pet.owned == true
	local secret = pet.secret == true
	local extent = if secret then SECRET_CARD else CARD

	--[[
		The preview takes most of the card and the three lines below it are packed
		tight underneath, so the art gets everything left over rather than the reverse.
	]]
	local artHeight = CARD_HEIGHT - 62

	return e(P.Panel, {
		key = pet.id,
		size = UDim2.fromOffset(extent.X, extent.Y),
		layoutOrder = pet.slot,
		radius = Theme.Radius.Card,
		color = Theme.Color.Card,
		gradient = Theme.Gradient.Card,
		strokeThickness = Theme.Stroke.Card,
		--[[
			The border carries the rarity once discovered. A locked card keeps the
			plain outline so it does not leak how special its contents are -- except
			the Secret, which is meant to shout either way.
		]]
		strokeColor = if owned or secret then style.color else Theme.Color.Outline,
		studs = false,
		children = P.compact(
			--[[
				Behind the pet, inside the card, under the text. Runs whether or not the
				Secret is discovered: bright effects around a black silhouette is exactly
				the intended contrast.
			]]
			if secret
				then e(SecretVFX.Layer, {
					key = "VFX",
					size = UDim2.new(1, -12, 0, artHeight + 12),
					position = UDim2.new(0.5, 0, 0, 6),
					anchorPoint = Vector2.new(0.5, 0),
					zIndex = 2,
				})
				else nil,
			e(ModelView.View, {
				key = "Model",
				kind = "pet",
				model = pet.model,
				silhouette = not owned,
				size = UDim2.new(1, -12, 0, artHeight),
				position = UDim2.new(0.5, 0, 0, 6),
				anchorPoint = Vector2.new(0.5, 0),
				zIndex = 5,
			}),
			e(P.Label, {
				key = "Name",
				-- Hidden along with the shape; silhouette plus rarity is the tease.
				text = if owned then pet.name else "???",
				textSize = if secret then Theme.TextSize.Body else Theme.TextSize.Small,
				size = UDim2.new(1, -12, 0, 22),
				position = UDim2.new(0.5, 0, 0, artHeight + 2),
				anchorPoint = Vector2.new(0.5, 0),
				truncate = Enum.TextTruncate.AtEnd,
				zIndex = 6,
			}),
			e(P.Label, {
				key = "Rarity",
				text = string.upper(pet.rarity),
				textSize = Theme.TextSize.Small,
				color = style.color,
				size = UDim2.new(1, -12, 0, 18),
				position = UDim2.new(0.5, 0, 0, artHeight + 21),
				anchorPoint = Vector2.new(0.5, 0),
				zIndex = 6,
			}),
			e(P.Label, {
				key = "Chance",
				text = if pet.hidden then "?%" else Format.chance(pet.chance),
				textSize = if secret then Theme.TextSize.Heading else Theme.TextSize.Body,
				color = if pet.hidden then Theme.Color.Gold else Theme.Color.White,
				size = UDim2.new(1, -12, 0, 26),
				position = UDim2.new(0.5, 0, 0, artHeight + 37),
				anchorPoint = Vector2.new(0.5, 0),
				zIndex = 6,
			})
		),
	})
end

--- One centred row of cards.
local function Row(props)
	return e(P.Group, {
		key = props.key,
		size = UDim2.new(1, 0, 0, props.height),
		layoutOrder = props.layoutOrder,
		layout = P.list({
			direction = Enum.FillDirection.Horizontal,
			padding = GAP,
			hAlign = Enum.HorizontalAlignment.Center,
			vAlign = Enum.VerticalAlignment.Top,
		}),
		children = props.children,
	})
end

local function EggSummonScreen(props)
	local state = props.state
	local actions = props.actions

	local egg = GameData.eggRoll(state.eggSummon, state.ownedPets)
	if egg == nil then
		return nil
	end

	local unlocked = state.unlockedAreas[egg.requiredArea] == true
	local affordable = state.cash >= egg.price

	--[[
		Split three and three. `GameData.eggRoll` returns them in ascending rarity, so
		the first three fill the top row and the Secret lands last on the bottom -- no
		rarity name is hardcoded here.
	]]
	local top, bottom = {}, {}
	for index, pet in ipairs(egg.pets) do
		local card = e(PetCard, { key = pet.id, pet = pet })
		if index <= 3 then
			top[#top + 1] = card
		else
			bottom[#bottom + 1] = card
		end
	end

	return e(Overlays.Modal, {
		key = props.key or "EggSummonScreen",
		title = egg.name,
		glyph = "paw",
		headerColor = Theme.Gradient.Purple,
		--[[
			Wide enough for the bottom row plus insets, and with room to spare in the
			footer for a second button beside SUMMON.
		]]
		width = CARD.X * 2 + SECRET_CARD.X + GAP * 2 + INSET * 2 + 44,
		contentHeight = CARD_HEIGHT * 2 + GAP + INSET * 2,
		onClose = actions.closeEggSummon,
		footerHeight = 96,
		footer = e(P.Group, {
			key = "Footer",
			size = UDim2.fromScale(1, 1),
			children = {
				--[[
					The egg, small, beside the button: it ties the price to the thing being
					opened without taking room from the cards.
				]]
				e(ModelView.View, {
					key = "Egg",
					kind = "egg",
					model = egg.model,
					spin = 30,
					size = UDim2.fromOffset(88, 88),
					position = UDim2.new(0, 10, 0.5, 0),
					anchorPoint = Vector2.new(0, 0.5),
				}),
				--[[
					The primary action, and it should look like one. `subtextSize` puts the
					price at heading weight directly under the label -- it used to inherit
					`TextSize.Small`, which turned the cost into a caption.
				]]
				--[[
					A centred row rather than one absolutely-placed button, so a second
					action (multi-summon, auto-summon) drops in beside this one without
					moving anything. No icon on it: the label and the price are the
					message, and a glyph only ate width from both.
				]]
				e(P.Group, {
					key = "Actions",
					size = UDim2.new(1, -200, 1, 0),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					layout = P.list({
						direction = Enum.FillDirection.Horizontal,
						padding = GAP,
						hAlign = Enum.HorizontalAlignment.Center,
						vAlign = Enum.VerticalAlignment.Center,
					}),
					children = {
						e(Buttons.Button, {
							key = "Summon",
							text = if unlocked then "SUMMON" else "AREA LOCKED",
							subtext = if unlocked then Format.money(egg.price) else nil,
							variant = if unlocked then "Purchase" else "Disabled",
							disabled = not unlocked or not affordable,
							textSize = Theme.TextSize.Title,
							subtextSize = Theme.TextSize.Heading,
							subtextFont = Theme.Font.Display,
							size = UDim2.fromOffset(300, 82),
							layoutOrder = 1,
							lip = 7,
							onClick = function()
								actions.summonEgg(egg.id)
							end,
						}),
					},
				}),
			},
		}),
		children = {
			e(P.Group, {
				key = "Rows",
				size = UDim2.fromScale(1, 1),
				padding = INSET,
				layout = P.list({
					direction = Enum.FillDirection.Vertical,
					padding = GAP,
					hAlign = Enum.HorizontalAlignment.Center,
				}),
				children = {
					e(Row, { key = "Top", height = CARD_HEIGHT, layoutOrder = 1, children = top }),
					e(Row, {
						key = "Bottom",
						height = CARD_HEIGHT,
						layoutOrder = 2,
						children = bottom,
					}),
				},
			}),
		},
	})
end

return EggSummonScreen
