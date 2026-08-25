--!nonstrict
--[[
	EggSummonScreen.luau
	The egg podium window: what is inside this egg, and the button to roll it.

	Opened by the hold-E prompt on a `*EggGroup` under
	`Workspace.NewMap.FeaturedPodium.EggSummonPodium`, which fires `OpenEggSummon`
	with the egg's id.

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
local RobuxPrice = require(UI.Components.RobuxPrice)
local SecretVFX = require(UI.Components.SecretVFX)

local e = React.createElement

--[[
	Card footprints. The Secret is **wider only** -- a taller card made the bottom
	row sit unevenly and read as a mistake rather than as emphasis. Extra width plus
	its VFX layer is enough to carry the importance.
]]
local CARD_HEIGHT = 228
local CARD = Vector2.new(196, CARD_HEIGHT)
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
				glyph = "paw",
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

	--[[
		THE MULTI-HATCH ROW: one button per tier, and the tier decides what the button IS.

			owned      "x3" over the cash it costs -- pressing it opens three
			not owned  the same button carrying a Robux price, which buys the pass

		One control in two states rather than two controls, because they occupy the same place in the
		player's head: "open more at once". A separate shop row for the passes would make buying them a
		different errand from using them.

		Smallest count first so the row reads x3 then x5 left to right, even though the config lists them
		largest-first (which is the order the SERVER wants when picking the best a player owns).
	]]
	local batches = table.clone(state.hatchBatches or {})
	table.sort(batches, function(a, b)
		return a.count < b.count
	end)

	local batchButtons = {}
	for index, batch in ipairs(batches) do
		local batchCost = egg.price * batch.count
		--- `state.cash`, the same field the single-summon affordability check above reads.
		local canAfford = (state.cash or 0) >= batchCost
		batchButtons[index] = e(P.Group, {
			key = `Batch{batch.count}`,
			size = UDim2.fromOffset(150, 88),
			layoutOrder = 1 + index,
			children = P.compact(
				e(Buttons.Button, {
					key = "Button",
					text = `x{batch.count}`,
					--- Owned: what it costs in cash. Not owned: nothing, the Robux tag says it.
					subtext = if batch.owned then Format.money(batchCost) else "UNLOCK",
					variant = if not unlocked
						then "Disabled"
						elseif batch.owned then "Purchase"
						else "Premium",
					disabled = not unlocked or (batch.owned and not canAfford),
					textSize = Theme.TextSize.Heading,
					subtextSize = Theme.TextSize.Small,
					size = UDim2.fromScale(1, 1),
					lip = 7,
					onClick = function()
						if batch.owned then
							actions.summonEgg(egg.id, batch.count)
						else
							--- Passes go through the same prompt path as every other pass.
							actions.purchase(batch.passId, "Pass")
						end
					end,
				}),
				--[[
					The price tag, only while the tier is locked. `RobuxPrice`'s corner variant is safe here:
					the footer does not clip, which is the condition rule 11 puts on anything rotated.
				]]
				if batch.owned
					then nil
					else e(RobuxPrice.Tag, {
						key = "Price",
						amount = batch.price,
						variant = "corner",
						position = UDim2.new(1, 8, 1, 6),
						anchorPoint = Vector2.new(1, 1),
						zIndex = 8,
					})
			),
		})
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
		--[[
			Taller footer than the single button needed, because the multi-hatch row lives here: either the
			x3/x5 buttons a player owns, or the Robux tags to buy them.
		]]
		footerHeight = 118,
		footer = e(P.Group, {
			key = "Footer",
			size = UDim2.fromScale(1, 1),
			children = {
				--[[
					THE LITTLE SPINNING EGG USED TO SIT HERE and it is gone, because the footer now holds three
					buttons instead of one: SUMMON plus the two multi-hatch tiers. With them in place the egg
					was overlapped by the row and read as a rendering fault.

					Nothing is lost. The window's header names the egg and every card below is its contents --
					the preview was decoration on a screen that is already entirely about this one egg.
				]]
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
					size = UDim2.new(1, -36, 1, 0),
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					layout = P.list({
						direction = Enum.FillDirection.Horizontal,
						padding = GAP,
						hAlign = Enum.HorizontalAlignment.Center,
						vAlign = Enum.VerticalAlignment.Center,
					}),
					children = P.append({
						e(Buttons.Button, {
							key = "Summon",
							text = if unlocked then "SUMMON" else "AREA LOCKED",
							subtext = if unlocked then Format.money(egg.price) else nil,
							variant = if unlocked then "Purchase" else "Disabled",
							disabled = not unlocked or not affordable,
							textSize = Theme.TextSize.Title,
							subtextSize = Theme.TextSize.Heading,
							subtextFont = Theme.Font.Display,
							size = UDim2.fromOffset(276, 88),
							layoutOrder = 1,
							lip = 7,
							onClick = function()
								actions.summonEgg(egg.id)
							end,
						}),
					}, batchButtons),
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
