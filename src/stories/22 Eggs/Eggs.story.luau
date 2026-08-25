--[[
	Egg summoning, end to end: the podium window, the hatch takeover, and the
	server-wide announcement.

	In game the sequence is: hold E at a `*EggGroup` under
	`Workspace.NewMap.FeaturedPodium.EggSummonPodium` ->
	`OpenEggSummon` -> this window -> SUMMON sends an `OpenEgg` intent -> the egg
	shakes while the server rolls -> `PetResult` names the pet -> reveal. A Secret
	also goes out on `Announce` to every client.

	This story runs the whole thing in mock mode: `Store`'s mock `summonEgg` rolls
	against the egg's **real** weights from `PetConfig` and reveals on the same beat,
	so pressing SUMMON here behaves the way it does in game. Owned pets accumulate
	as you roll, which is how to check the silhouette-to-rendered transition.

	Models come from `ReplicatedStorage.PetModels` / `EggModels`, published by
	`PetService` at server start. In an Edit-mode preview those folders only exist if
	the place has been played once since the last sync -- without them every slot
	falls back to its glyph, which is the intended degraded state, not a bug.

	Controls:

		Phase       what to show. `summon` is the window; `shaking` and `revealed`
		            jump straight into the takeover without waiting on a roll.
		Egg         which egg's contents to show
		Batch       1, 3 or 5 eggs. Shaking puts that many meshes on screen; revealed
		            shows that many pets.
		RevealPet   which pet the single reveal shows, 1 = Common .. 6 = Secret
		Announce    show the full-width banner as well
		OwnAll      pretend every pet is already hatched, to compare the rendered
		            slots against the silhouettes
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(game:GetService("ServerStorage").DevPackages.UILabs)
local UI = require(ReplicatedStorage.Shared.UI)

local Stage = UI.Stage
local Store = UI.Store

local e = React.createElement

local EGG_IDS = { "JunkyardEgg", "WorkshopEgg", "QuantumEgg" }
local PHASES = { "summon", "shaking", "revealed" }
local BATCHES = { "1", "3", "5" }

--[[
	Drives the atoms directly, which is what the Bridge does in game. A story cannot
	wait on a server, so the phases are set rather than played.
]]
local function Scene(props)
	local controls = props.controls
	local state, actions = Store.use()

	React.useEffect(function()
		local Atoms = UI.Atoms
		local eggId = controls.Egg
		local ownedPasses = table.clone(Atoms.entitlements())
		ownedPasses.TripleHatch = true
		ownedPasses.PentaHatch = true
		Atoms.entitlements(ownedPasses)

		if controls.OwnAll then
			local egg = UI.GameData.eggRoll(eggId)
			local owned = {}
			for _, pet in ipairs(egg.pets) do
				owned[pet.id] = 1
			end
			Atoms.ownedPets(owned)
		end

		if controls.Phase == "summon" then
			Atoms.eggRoll(nil)
			Atoms.eggSummon(eggId)
		else
			Atoms.eggSummon(nil)
			local egg = UI.GameData.eggRoll(eggId)
			local batch = math.clamp(tonumber(controls.Batch) or 1, 1, 5)
			local ids = {}
			for index = 1, batch do
				local pet = egg.pets[((controls.RevealPet - 1 + index - 1) % #egg.pets) + 1]
				ids[index] = pet.id
			end
			local pet = egg.pets[math.clamp(controls.RevealPet, 1, #egg.pets)]
			Atoms.eggRoll({
				EggId = eggId,
				Phase = controls.Phase,
				Count = batch,
				PetId = if controls.Phase == "revealed" then pet.id else nil,
				PetIds = if controls.Phase == "revealed" then ids else nil,
			})
		end

		if controls.Announce then
			local egg = UI.GameData.eggRoll(eggId)
			local pet = egg.pets[#egg.pets]
			Atoms.announce({
				Kind = "SecretPet",
				PlayerName = "Marko",
				PetId = pet.id,
				PetName = pet.name,
				Rarity = pet.rarity,
			})
		else
			Atoms.announce(nil)
		end
	end, {
		controls.Phase,
		controls.Egg,
		controls.RevealPet,
		controls.Batch,
		controls.Announce,
		controls.OwnAll,
	})

	return e(UI.App, {
		key = "App",
		-- Stage sizes the canvas, so the app renders 1:1 inside it.
		device = "desktop",
		scale = 1,
		state = state,
		actions = actions,
	})
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	name = "Eggs",
	summary = "Egg summon window, hatch takeover (1 / 3 / 5 eggs) and the server-wide announcement.",
	controls = {
		Phase = UILabs.Choose(PHASES, 1),
		Egg = UILabs.Choose(EGG_IDS, 1),
		Batch = UILabs.Choose(BATCHES, 1),
		RevealPet = UILabs.Slider(6, 1, 6, 1),
		Announce = UILabs.Boolean(false),
		OwnAll = UILabs.Boolean(false),
	},
}, function(props)
	return e(Stage, {
		key = "Stage",
		device = "desktop",
		children = {
			e(Store.Provider, {
				-- Stories have no server: always mock, never live remotes.
				key = "Store",
				mock = true,
				children = e(Scene, { key = "Scene", controls = props.controls }),
			}),
		},
	})
end)
