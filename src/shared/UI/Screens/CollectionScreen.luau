--[[
	CollectionScreen.luau

	COLLECTION index with SCRAP / MAGNETS / PETS / ACHIEVEMENTS tabs.

	Achievements live here rather than in their own window because this is already the screen about
	progress rather than about doing: what you have found, what you are missing. An achievement list is
	the same question asked about your history instead of the catalogue.

	Undiscovered entries keep their silhouette and footprint so the grid shows
	the shape of what is missing -- that gap is the reason players keep digging.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Format = require(UI.Format)
local GameData = require(UI.GameData)
local P = require(UI.Primitives)
local Buttons = require(UI.Components.Buttons)
local Indicators = require(UI.Components.Indicators)
local Cards = require(UI.Components.Cards)
local Overlays = require(UI.Components.Overlays)
local Progression = require(UI.Components.Progression)

local e = React.createElement

local TABS = {
	{ id = "SCRAP", text = "SCRAP", glyph = "scrap" },
	{ id = "MAGNETS", text = "MAGNETS", glyph = "magnet" },
	{ id = "PETS", text = "PETS", glyph = "paw" },
	{ id = "ACHIEVEMENTS", text = "AWARDS", glyph = "trophy" },
}

--- Discovery tiles are square art; an achievement is a sentence and a bar. See the note in the header.
local INDEX_CELL = UDim2.fromOffset(146, 168)
local ACHIEVEMENT_CELL =
	UDim2.fromOffset(Progression.ACHIEVEMENT_CARD.X, Progression.ACHIEVEMENT_CARD.Y)

local function CollectionScreen(props)
	local state = props.state
	local actions = props.actions
	local tab, setTab = React.useState("SCRAP")

	local cells = {}
	local found, total = 0, 0

	if tab == "SCRAP" then
		for index, entry in ipairs(GameData.scrapIndex(state.discoveredScrap, state.unlockedAreas)) do
			total += 1
			if entry.discovered then
				found += 1
			end
			--[[
				An undiscovered entry names its area instead of saying "UNDISCOVERED" at everything.

				Every scrap in this list can be found, but eleven of the eighteen need an area the player
				may not have bought yet -- and a wall of identical "UNDISCOVERED" cards is what made the
				index look like it was advertising scrap that does not exist. Naming the area turns each
				card into a pointer: this one is in the Workshop Yard, which you have; that one is in the
				Vehicle Graveyard, which you do not.
			]]
			local hint = if entry.areaName == nil
				then nil
				elseif entry.available then string.upper(entry.areaName)
				else `LOCKED: {string.upper(entry.areaName)}`
			cells[#cells + 1] = e(Cards.CollectionCell, {
				key = entry.id,
				name = entry.name,
				rarity = entry.rarity,
				glyph = "scrap",
				model = entry.model,
				discovered = entry.discovered,
				best = entry.best,
				collected = entry.collected,
				hint = hint,
				dimmed = not entry.available,
				layoutOrder = index,
			})
		end
	elseif tab == "MAGNETS" then
		for index, magnet in ipairs(GameData.magnets()) do
			total += 1
			local owned = state.ownedMagnets[magnet.id] == true
			if owned then
				found += 1
			end
			cells[#cells + 1] = e(Cards.CollectionCell, {
				key = magnet.id,
				name = magnet.name,
				rarity = magnet.rarity,
				glyph = "magnet",
				discovered = owned,
				best = magnet.range,
				collected = magnet.strength,
				layoutOrder = index,
			})
		end
	--[[
		`elseif`, not `else`. With AWARDS added, an open `else` built the pet list for that tab too --
		twenty "???" cells beside the achievements and a footer reading 3/40 instead of 3/19.
	]]
	elseif tab == "PETS" then
		for index, pet in ipairs(GameData.pets(state.ownedPets)) do
			total += 1
			if pet.owned then
				found += 1
			end
			cells[#cells + 1] = e(Cards.CollectionCell, {
				key = pet.id,
				name = pet.name,
				rarity = pet.rarity,
				glyph = "paw",
				discovered = pet.owned,
				best = 0,
				collected = pet.count,
				layoutOrder = index,
			})
		end
	end

	local awards = tab == "ACHIEVEMENTS"

	if awards then
		--[[
			SECTIONS IN A LIST, not cards in one grid.

			The first version put a track heading in a grid cell, which cost a whole cell and shunted every
			card after it -- one card on the first row, two on the next, ragged all the way down. A grid
			cannot span a cell, so the fix is one `P.Group` per track: a full-width heading, then that
			track's own two-column grid. The outer scroller becomes a vertical list of those.

			Each section states its own height, because a `UIGridLayout` inside an auto-sized frame does not
			report one -- rows are counted here instead.
		]]
		local byTrack: { [string]: { any } } = {}
		for _, achievement in ipairs(state.achievements or {}) do
			total += 1
			if achievement.complete then
				found += 1
			end
			local bucket = byTrack[achievement.track]
			if bucket == nil then
				bucket = {}
				byTrack[achievement.track] = bucket
			end
			table.insert(bucket, achievement)
		end

		local HEADING = 30
		local GAP = 10
		local order = 0
		for _, track in ipairs(state.achievementTracks or {}) do
			local bucket = byTrack[track]
			if bucket then
				order += 1
				local cards = {}
				for index, achievement in ipairs(bucket) do
					cards[index] = e(Progression.AchievementCard, {
						key = achievement.id,
						id = achievement.id,
						name = achievement.name,
						description = achievement.description,
						glyph = achievement.glyph,
						accent = achievement.accent,
						value = achievement.value,
						threshold = achievement.threshold,
						complete = achievement.complete,
						reward = achievement.reward,
						titleText = achievement.titleText,
						layoutOrder = index,
					})
				end

				local rows = math.ceil(#bucket / 2)
				local sectionHeight = HEADING
					+ rows * Progression.ACHIEVEMENT_CARD.Y
					+ (rows - 1) * GAP

				cells[#cells + 1] = e(P.Group, {
					key = `Track{track}`,
					size = UDim2.new(1, 0, 0, sectionHeight),
					layoutOrder = order,
					children = {
						e(P.Label, {
							key = "Heading",
							text = string.upper(track),
							textSize = Theme.TextSize.Small,
							font = Theme.Font.Bold,
							color = Theme.Color.Gold,
							align = Enum.TextXAlignment.Left,
							size = UDim2.new(1, 0, 0, HEADING),
							zIndex = 2,
						}),
						e(P.Group, {
							key = "Cards",
							size = UDim2.new(1, 0, 1, -HEADING),
							position = UDim2.fromOffset(0, HEADING),
							layout = P.grid({
								cell = ACHIEVEMENT_CELL,
								padding = UDim2.fromOffset(GAP, GAP),
							}),
							children = cards,
						}),
					},
				})
			end
		end
	end

	return e(Overlays.Modal, {
		key = props.key or "CollectionScreen",
		title = "Collection",
		glyph = "book",
		headerColor = Theme.Gradient.Purple,
		size = UDim2.fromOffset(1060, 700),
		onClose = actions.closeScreen,
		tabs = e(Buttons.TabBar, {
			key = "Tabs",
			tabs = TABS,
			active = tab,
			variant = "Premium",
			size = UDim2.fromScale(1, 1),
			hAlign = Enum.HorizontalAlignment.Left,
			onSelect = setTab,
		}),
		footerHeight = 54,
		footer = e(P.Group, {
			key = "Progress",
			size = UDim2.fromScale(1, 1),
			children = {
				e(P.Label, {
					key = "Label",
					text = if awards then "ACHIEVEMENTS" else "COLLECTION",
					textSize = Theme.TextSize.Small,
					font = Theme.Font.Bold,
					color = Theme.Color.Gray,
					align = Enum.TextXAlignment.Left,
					size = UDim2.new(0, 160, 1, 0),
				}),
				e(Indicators.ProgressBar, {
					key = "Bar",
					value = found,
					max = total,
					gradient = if awards then Theme.Gradient.Gold else Theme.Gradient.Purple,
					height = 30,
					size = UDim2.new(1, -180, 0, 30),
					position = UDim2.fromScale(1, 0.5),
					anchorPoint = Vector2.new(1, 0.5),
					text = Format.fraction(found, total),
				}),
			},
		}),
		children = {
			e(P.Scroller, {
				key = "IndexGrid",
				padding = { right = 10, bottom = 6 },
				--[[
					Awards stack as SECTIONS -- see the note where they are built -- so that tab wants a vertical
					list. Every other tab is a flat catalogue and wants the grid.
				]]
				layout = if awards
					then P.list({ padding = 16 })
					else P.grid({
						cell = INDEX_CELL,
						padding = UDim2.fromOffset(12, 12),
					}),
				children = cells,
			}),
		},
	})
end

return CollectionScreen
