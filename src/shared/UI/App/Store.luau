--!nonstrict
--[[
	Store.luau
	The seam between the UI kit and the game.

	Every screen in the kit consumes exactly `state` and `actions`. That contract
	is unchanged from the standalone kit -- what changed is everything behind it:

		before   local React state seeded from Mock.luau
		now      Charm atoms fed by the server, and actions that fire remotes

	Because the contract held, all eighteen screens migrated without edits.

	Two modes:

		live (default)  atoms are populated by State/Bridge from StateChanged;
		                actions send bare intents to the server
		mock            atoms are seeded from Mock.luau and actions mutate them
		                locally, so UI Labs stories still run in Edit mode with no
		                server, no remotes and no DataStore

	`Store.use()` returns the same shape in both, so a screen cannot tell which
	it is running under -- which is the point: the storybook exercises the real
	components, not a parallel copy of them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayersService = game:GetService("Players")

--[[
	Zero when there is no LocalPlayer, which is the case on the server and in some story harnesses.
	`AdminConfig.IsAdmin(0)` is false, so the admin entry point simply never offers itself there.
]]
local localUserId = if PlayersService.LocalPlayer then PlayersService.LocalPlayer.UserId else 0

local AdminConfig = require(ReplicatedStorage.Shared.Config.AdminConfig)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.RewardsConfig)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local TitleConfig = require(ReplicatedStorage.Shared.Config.TitleConfig)
local AchievementConfig = require(ReplicatedStorage.Shared.Config.AchievementConfig)
local AchievementRules = require(ReplicatedStorage.Shared.Utility.AchievementRules)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local DayClock = require(ReplicatedStorage.Shared.Utility.DayClock)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)
local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)

local UI = script.Parent.Parent
local Atoms = require(UI.State.Atoms)
local Bridge = require(UI.State.Bridge)
local GameData = require(UI.GameData)
local Hooks = require(UI.Hooks)
local Mock = require(UI.Mock)
local Sound = require(UI.Sound)

local useAtom = ReactCharm.useAtom

local Store = {}

Store.Context = React.createContext(nil)

-- Re-exported so screens and controllers can reach the raw layers when they need
-- something the flattened `state` does not carry.
Store.Atoms = Atoms
Store.Bridge = Bridge
Store.GameData = GameData

--------------------------------------------------------------------------------
-- Mock seeding, for stories only
--------------------------------------------------------------------------------

local function seedMock()
	Atoms.money(Mock.player.cash)
	Atoms.gears(Mock.player.gears)
	Atoms.storedWeight(Mock.player.storage)
	Atoms.storedValue(Mock.player.storageValue)
	Atoms.prestigeCount(Mock.player.prestige)
	Atoms.totalScrapCollected(Mock.player.totalScrap)
	Atoms.equippedMagnet(Mock.player.equippedMagnet)
	Atoms.equippedPets(table.clone(Mock.player.equippedPets))

	local derived = Atoms.derived()
	local copy = table.clone(derived)
	copy.StorageCapacity = Mock.player.capacity
	Atoms.derived(copy)

	local levels, owned, inventory = {}, {}, {}
	for _, definition in ipairs(Mock.upgrades) do
		levels[definition.id] = definition.level
	end
	for _, magnet in ipairs(Mock.magnets) do
		owned[magnet.id] = magnet.owned == true
	end
	for _, potion in ipairs(Mock.potions) do
		inventory[potion.id] = potion.owned
	end
	Atoms.upgradeLevels(levels)
	Atoms.ownedMagnets(owned)
	Atoms.inventory(inventory)

	local areas = {}
	for _, area in ipairs(Mock.areas) do
		areas[area.id] = area.unlocked
	end
	Atoms.unlockedAreas(areas)

	--[[
		Return-to-play state, seeded mid-progress rather than empty: a story showing "streak 0, no
		spins, nothing claimable" demonstrates none of the states worth reviewing. This is a player
		three days into a streak, an hour into the day, with a spin banked and two friends on.
	]]
	Atoms.dailyStreak(3)
	Atoms.dailyCalendarDay(4)
	Atoms.dailyClaimable(true)
	Atoms.playtimeSeconds(1100)
	Atoms.playtimeClaimed({ [1] = true, [2] = true })
	Atoms.spinsAvailable(2)
	Atoms.spinRoll(nil)
	Atoms.friendCount(2)
	Atoms.tutorialStep(2)
	Atoms.tutorialComplete(false)

	Atoms.loaded(true)
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

--[[
	Client-only actions. Identical in both modes, because opening a window or
	selecting a tab is never the server's business.
]]
local function localActions()
	local self = {}

	function self.openScreen(name: string)
		Atoms.screen(name)
		Atoms.detail(nil)
	end

	function self.closeScreen()
		Atoms.screen(nil)
		Atoms.detail(nil)
	end

	function self.openDetail(kind: string, id: string)
		Atoms.detail({ Kind = kind, Id = id })
	end

	function self.closeDetail()
		Atoms.detail(nil)
	end

	function self.setBuyAmount(amount: string)
		Atoms.buyAmount(amount)
	end

	function self.confirm(spec)
		Atoms.confirm(spec)
	end

	function self.closeConfirm()
		Atoms.confirm(nil)
	end

	function self.openEggSummon(eggId: string)
		Atoms.eggSummon(eggId)
	end

	function self.closeEggSummon()
		Atoms.eggSummon(nil)
	end

	--[[
		Starts the takeover, then sends the intent. The overlay goes up first on
		purpose: the shake is the round trip, so it has to begin before the request
		rather than after the answer.
	]]
	--- `count` is the batch size; 1 when the caller does not ask for a multi-hatch.
	function self.summonEgg(eggId: string, count: number?)
		if Atoms.eggRoll() ~= nil then
			return
		end
		--- The batch is recorded on the roll so the reveal knows how many pets to expect.
		Atoms.eggRoll({ EggId = eggId, Phase = "shaking", Count = count or 1 })
		Bridge.openEgg(eggId, count)
	end

	function self.dismissEggRoll()
		Atoms.eggRoll(nil)
	end

	function self.dismissAnnounce()
		Atoms.announce(nil)
	end

	function self.notify(toast)
		Bridge.notify({
			Title = toast.title or toast.Title,
			Body = toast.body or toast.Body,
			Reward = toast.reward or toast.Reward,
			Glyph = toast.glyph or toast.Glyph,
			Accent = toast.accent or toast.Accent,
		})
	end

	function self.dismissToast(id: number)
		local kept = {}
		for _, toast in ipairs(Atoms.toasts()) do
			if toast.Id ~= id then
				table.insert(kept, toast)
			end
		end
		Atoms.toasts(kept)
	end

	return self
end

--[[
	Live actions. Each one sends an intent and nothing else; the authoritative
	result arrives back through StateChanged and re-renders whatever is on screen.

	Note what is absent: no optimistic mutation of money, levels or unlocks. The
	server is the only thing that may move those numbers, so the UI waits.
]]
local function liveActions()
	local self = localActions()

	function self.buyUpgrade(upgradeId: string)
		Sound.play("purchase")
		Bridge.requestUpgrade(upgradeId)
	end

	function self.unlockArea(areaId: string)
		Sound.play("purchase")
		Bridge.requestAreaUnlock(areaId)
	end

	function self.teleport(areaId: string)
		Bridge.requestTeleport(areaId)
	end

	function self.teleportHome()
		-- "MyPlot" is the id TeleportService accepts; "Home" was silently rejected.
		Bridge.requestTeleport("MyPlot")
	end

	function self.prestige()
		Sound.play("prestige")
		Bridge.requestPrestige()
	end

	function self.equipMagnet(magnetId: string)
		Sound.play("equip")
		Bridge.equipMagnet(magnetId)
	end

	function self.equipSkin() end

	function self.usePotion(itemId: string)
		Sound.play("equip")
		Bridge.useConsumable(itemId)
	end

	function self.buyMagnet(magnetId: string)
		Sound.play("purchase")
		Bridge.buyMagnet(magnetId)
	end

	function self.purchase(id: string, kind: string?)
		Sound.play("purchase")
		if kind == "Product" then
			Bridge.promptProduct(id)
		else
			Bridge.promptPass(id)
		end
	end

	function self.equipPet(petId: string)
		Bridge.petAction("EquipPet", petId)
	end

	function self.unequipPet(petId: string)
		Bridge.petAction("UnequipPet", petId)
	end

	function self.deletePet(petId: string)
		Bridge.petAction("DeletePet", petId)
	end

	function self.buyPetSlot()
		Bridge.petAction("BuyPetSlot", "slot")
	end

	--[[
		`count` is the batch: 1, or 3/5 with the matching pass. The server re-checks the entitlement, so
		this passes the number straight through rather than gating it here.
	]]
	function self.hatchEgg(eggId: string, count: number?)
		Bridge.openEgg(eggId, count)
	end

	--[[
		PetService has no bulk equip/unequip. Screens that want those send one
		EquipPet/UnequipPet intent per pet, so each is validated individually.
	]]
	function self.equipBestPets() end

	function self.unequipAllPets()
		for _, petId in ipairs(Atoms.equippedPets()) do
			Bridge.petAction("UnequipPet", petId)
		end
	end

	function self.setSetting(key: string, value: any)
		-- Echo locally so a slider tracks the thumb, then let the server confirm.
		local settings = table.clone(Atoms.settings())
		settings[key] = value
		Atoms.settings(settings)
		Bridge.updateSetting(key, value)
	end

	function self.resetSettings()
		for key, value in pairs({
			ParticlesEnabled = true,
			ScreenEffectsEnabled = true,
			SoundEnabled = true,
			MusicEnabled = true,
			SoundVolume = 0.8,
			MusicVolume = 0.55,
		}) do
			self.setSetting(key, value)
		end
	end

	--[[
		Return-to-play intents. `claimDaily` takes NO ARGUMENT on purpose: the screen used to pass
		the day it believed was claimable, and the server must never take a claim target from the
		client. Any argument passed here is ignored.
	]]
	function self.claimDaily()
		Bridge.claimDaily()
	end

	function self.claimPlaytime(milestoneIndex: number)
		Bridge.claimPlaytime(milestoneIndex)
	end

	function self.spinWheel()
		--[[
			Refused locally when there is nothing to spend, so a mistimed click does not spend a remote
			call to be told no. The server still checks -- this is politeness, not security.

			A REVEALED roll is cleared rather than treated as busy. The reward is already granted and the
			banner is only an announcement, so making the player wait for it to time out before spinning
			again would be the UI holding them up for no reason. Only a spin still turning blocks.
		]]
		local roll = Atoms.spinRoll()
		if roll ~= nil and roll.Phase == "spinning" then
			return
		end
		if Atoms.spinsAvailable() <= 0 then
			return
		end
		if roll ~= nil then
			Atoms.spinRoll(nil)
		end
		Bridge.requestSpin()
	end

	--- Clears the wheel takeover once the player has seen their prize.
	function self.closeSpin()
		Atoms.spinRoll(nil)
	end

	function self.equipTitle(titleId: string)
		Sound.play("equip")
		Bridge.equipTitle(titleId)
	end

	function self.skipTutorial()
		Bridge.skipTutorial()
	end

	function self.adminCommand(
		command: string,
		amount: number?,
		targetMode: string,
		targetUserId: number?,
		itemId: string?
	)
		Bridge.adminCommand(command, amount, targetMode, targetUserId, itemId)
	end

	function self.redeemCode(code: string)
		Bridge.redeemCode(code)
	end

	--[[
		Selling is a Touched event on the plot's CrusherSellZone, so the button
		teleports the player onto it rather than asking the server for money.
	]]
	function self.sell()
		Bridge.requestTeleport("MyCrusher")
	end

	--[[
		A MOCK `summonEgg` USED TO SIT HERE, INSIDE THE LIVE ACTIONS, and it shadowed the real one in
		`localActions`. Its own comment said "mock mode plays the server's half of the roll itself", which
		is exactly what it did -- in the live game:

			- it rolled the pet ON THE CLIENT from the egg's weights
			- it wrote the win straight into the `ownedPets` atom
			- it never sent `OpenEgg`, so the server granted nothing and charged nothing

		A player hatched, saw a pet, saw it in their inventory, and lost it on rejoin. Cash was never
		deducted either. It was found while wiring the multi-hatch: the x3 button reached this instead of
		the real action, so the server never heard about the batch.

		Moved rather than fixed in place. `localActions.summonEgg` is the real one -- it fires the remote and
		lets `PetResult` drive the reveal -- and the rolling version now sits in `mockActions`, which is the
		only place that should ever pretend to be a server.
	]]
	function self.collect() end
	function self.grant() end
	function self.reset() end
	function self.setCosmetic() end
	function self.toggleAutoCollect() end

	return self
end

--[[
	Mock actions. Mutate the atoms directly so stories stay interactive without a
	server. Deliberately not shared with the live path: a story that fakes a
	purchase must never be able to do so in game.
]]
local function mockActions()
	local self = localActions()

	--[[
		Stories have no server, so mock mode plays the server's half of the roll itself: pick from the
		egg's real weights and reveal after the same beat.

		This is where that code belongs, and where it now lives -- it used to sit in `liveActions`, where it
		shadowed the real one and quietly made hatching a client-side fiction. See the note there.

		Batch aware, so the multi-hatch reveal can be reviewed in a story: `count` rolls that many pets and
		hands the overlay a list, exactly as `PetResult` does in game.
	]]
	function self.summonEgg(eggId: string, count: number?)
		if Atoms.eggRoll() ~= nil then
			return
		end
		local batch = math.max(1, count or 1)
		Atoms.eggRoll({ EggId = eggId, Phase = "shaking", Count = batch })

		local egg = GameData.eggRoll(eggId)
		if egg == nil then
			return
		end

		local won = {}
		for _ = 1, batch do
			local roll = math.random()
			local cursor = 0
			local pick = egg.pets[1]
			for _, pet in ipairs(egg.pets) do
				cursor += pet.chance
				if roll <= cursor then
					pick = pet
					break
				end
			end
			table.insert(won, pick)
		end

		task.delay(1.4, function()
			local current = Atoms.eggRoll()
			if current ~= nil and current.Phase == "shaking" then
				local owned = table.clone(Atoms.ownedPets())
				local ids = {}
				for _, pet in ipairs(won) do
					owned[pet.id] = (owned[pet.id] or 0) + 1
					table.insert(ids, pet.id)
				end
				Atoms.ownedPets(owned)
				Atoms.eggRoll({
					EggId = eggId,
					Phase = "revealed",
					PetId = ids[1],
					PetIds = ids,
				})
			end
		end)
	end

	function self.buyUpgrade(upgradeId: string)
		local levels = table.clone(Atoms.upgradeLevels())
		levels[upgradeId] = (levels[upgradeId] or 0) + 1
		Atoms.upgradeLevels(levels)
		Sound.play("purchase")
	end

	function self.unlockArea(areaId: string)
		local areas = table.clone(Atoms.unlockedAreas())
		areas[areaId] = true
		Atoms.unlockedAreas(areas)
	end

	function self.equipMagnet(magnetId: string)
		Atoms.equippedMagnet(magnetId)
	end

	function self.usePotion(itemId: string)
		local inventory = table.clone(Atoms.inventory())
		inventory[itemId] = math.max(0, (inventory[itemId] or 0) - 1)
		Atoms.inventory(inventory)
	end

	function self.prestige()
		Atoms.money(0)
		Atoms.prestigeCount(Atoms.prestigeCount() + 1)
	end

	function self.setSetting(key: string, value: any)
		local settings = table.clone(Atoms.settings())
		settings[key] = value
		Atoms.settings(settings)
	end

	function self.grant(amount: number)
		Atoms.money(Atoms.money() + amount)
	end

	function self.reset()
		seedMock()
	end

	function self.sell()
		Atoms.money(Atoms.money() + Atoms.storedValue())
		Atoms.storedWeight(0)
	end

	function self.collect(amount: number)
		Atoms.storedWeight(math.min(Atoms.derived().StorageCapacity, Atoms.storedWeight() + amount))
	end

	--[[
		Mock reward systems, so the stories are actually usable without a server. Deliberately not
		shared with the live path -- a story that fakes a claim must never be able to do so in game.
	]]
	function self.claimDaily()
		if not Atoms.dailyClaimable() then
			return
		end
		Atoms.dailyClaimable(false)
		Atoms.dailyStreak(Atoms.dailyStreak() + 1)
		Atoms.dailyCalendarDay((Atoms.dailyCalendarDay() % 7) + 1)
		Atoms.money(Atoms.money() + 2500)
	end

	function self.spinWheel()
		if Atoms.spinsAvailable() <= 0 or Atoms.spinRoll() ~= nil then
			return
		end
		Atoms.spinsAvailable(Atoms.spinsAvailable() - 1)
		local segments = RewardsConfig.Spin.Segments
		local index = math.random(1, #segments)
		local segment = segments[index]
		Atoms.spinRoll({
			Phase = "spinning",
			SegmentId = segment.Id,
			Index = index,
			Label = segment.Label,
		})
		task.delay(RewardsConfig.Spin.AnimationSeconds, function()
			local current = Atoms.spinRoll()
			if current ~= nil and current.Phase == "spinning" then
				Atoms.spinRoll({
					Phase = "revealed",
					SegmentId = segment.Id,
					Index = index,
					Label = segment.Label,
				})
				Atoms.money(Atoms.money() + (segment.Money or 0))
				task.delay(RewardsConfig.Spin.RevealSeconds, function()
					local shown = Atoms.spinRoll()
					if shown ~= nil and shown.Phase == "revealed" then
						Atoms.spinRoll(nil)
					end
				end)
			end
		end)
	end

	function self.closeSpin()
		Atoms.spinRoll(nil)
	end

	for _, name in ipairs({
		"teleport",
		"teleportHome",
		"equipSkin",
		"buyMagnet",
		"purchase",
		"equipPet",
		"unequipPet",
		"deletePet",
		"buyPetSlot",
		"hatchEgg",
		"equipBestPets",
		"unequipAllPets",
		"resetSettings",
		"redeemCode",
		"claimPlaytime",
		"skipTutorial",
		"adminCommand",
		"setCosmetic",
		"toggleAutoCollect",
	}) do
		if not self[name] then
			self[name] = function() end
		end
	end

	return self
end

--------------------------------------------------------------------------------
-- Provider
--------------------------------------------------------------------------------

function Store.Provider(props)
	local mock = props.mock == true

	local actions = React.useMemo(function()
		return if mock then mockActions() else liveActions()
	end, { mock })

	React.useEffect(function()
		if mock then
			seedMock()
			return
		end

		-- Connecting yields on WaitForChild, so it cannot run during render.
		-- Bridge.start only latches once it has the Remotes folder, so retrying
		-- is safe and a slow server boot cannot leave the UI permanently blank.
		local cancelled = false
		task.spawn(function()
			for attempt = 1, 10 do
				if cancelled then
					return
				end
				if Bridge.start() then
					print(string.format("[ScrapyardUI] Bridge connected on attempt %d", attempt))
					return
				end
				task.wait(1)
			end
			if not cancelled then
				warn("[ScrapyardUI] Bridge never connected - UI is showing defaults")
			end
		end)

		return function()
			cancelled = true
		end
	end, { mock })

	-- One-second client tick: expire toasts and count down boost timers. Boost
	-- expiry timestamps are absolute and server-issued, so this only re-renders;
	-- it never invents remaining time.
	React.useEffect(function()
		if props.live == false then
			return
		end

		local accumulator = 0
		local connection = RunService.Heartbeat:Connect(function(delta)
			accumulator += delta
			if accumulator >= 1 then
				local seconds = math.floor(accumulator)
				accumulator -= seconds
				Bridge.expireToasts(seconds)
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, { props.live })

	local value = React.useMemo(function()
		return { actions = actions }
	end, { actions })

	return React.createElement(Store.Context.Provider, { value = value }, props.children)
end

--------------------------------------------------------------------------------
-- Hook
--------------------------------------------------------------------------------

--[[
	Returns `state, actions`.

	`state` is assembled fresh from the atoms each render. Every field a screen
	reads is subscribed individually, so a money change re-renders the currency
	row and nothing else.
]]
function Store.use()
	local context = React.useContext(Store.Context)

	local money = useAtom(Atoms.money)
	local gears = useAtom(Atoms.gears)
	local storedWeight = useAtom(Atoms.storedWeight)
	local storedValue = useAtom(Atoms.storedValue)
	local derived = useAtom(Atoms.derived)
	local upgradeLevels = useAtom(Atoms.upgradeLevels)
	local unlockedAreas = useAtom(Atoms.unlockedAreas)
	local prestigeCount = useAtom(Atoms.prestigeCount)
	local ownedMagnets = useAtom(Atoms.ownedMagnets)
	local equippedMagnet = useAtom(Atoms.equippedMagnet)
	local inventory = useAtom(Atoms.inventory)
	local activeBoosts = useAtom(Atoms.activeBoosts)
	local activeEvent = useAtom(Atoms.activeEvent)
	local totalScrapCollected = useAtom(Atoms.totalScrapCollected)
	local eggOpenCounts = useAtom(Atoms.eggOpenCounts)
	local unlockedAchievements = useAtom(Atoms.unlockedAchievements)
	local unlockedTitles = useAtom(Atoms.unlockedTitles)
	local equippedTitle = useAtom(Atoms.equippedTitle)
	local entitlements = useAtom(Atoms.entitlements)
	local ownedPets = useAtom(Atoms.ownedPets)
	local equippedPets = useAtom(Atoms.equippedPets)
	local maximumEquippedPets = useAtom(Atoms.maximumEquippedPets)
	local discoveredScrap = useAtom(Atoms.discoveredScrap)
	local settings = useAtom(Atoms.settings)
	local loaded = useAtom(Atoms.loaded)

	local screen = useAtom(Atoms.screen)
	local detail = useAtom(Atoms.detail)
	local confirm = useAtom(Atoms.confirm)
	local toasts = useAtom(Atoms.toasts)
	local buyAmount = useAtom(Atoms.buyAmount)
	local eggSummon = useAtom(Atoms.eggSummon)
	local eggRoll = useAtom(Atoms.eggRoll)
	local announce = useAtom(Atoms.announce)

	--[[
		The player list for the admin panel, refreshed on a ticker.

		Read straight from `Players` rather than mirrored into an atom: it is not server state, it is the
		room the client is already in, and a snapshot that goes stale as people join is worse than no
		list. Two seconds is often enough for a panel nobody is watching continuously.
	]]
	local roster = Hooks.useTicker(2)
	local players = React.useMemo(function()
		local list = {}
		for _, player in PlayersService:GetPlayers() do
			table.insert(list, { userId = player.UserId, name = player.Name })
		end
		table.sort(list, function(a, b)
			return a.name < b.name
		end)
		return list
	end, { roster })

	local dailyStreak = useAtom(Atoms.dailyStreak)
	local dailyCalendarDay = useAtom(Atoms.dailyCalendarDay)
	local dailyClaimable = useAtom(Atoms.dailyClaimable)
	local playtimeSeconds = useAtom(Atoms.playtimeSeconds)
	local playtimeClaimed = useAtom(Atoms.playtimeClaimed)
	local spinsAvailable = useAtom(Atoms.spinsAvailable)
	local spinRoll = useAtom(Atoms.spinRoll)
	local friendCount = useAtom(Atoms.friendCount)
	local tutorialStep = useAtom(Atoms.tutorialStep)
	local tutorialComplete = useAtom(Atoms.tutorialComplete)

	-- Boosts arrive as absolute expiry timestamps; the HUD wants seconds left.
	local now = os.time()
	local boosts = {}
	for boostId, expiresAt in pairs(activeBoosts) do
		local remaining = expiresAt - now
		if remaining > 0 then
			-- Resolve the potion behind the boost so the HUD can show its bottle
			-- and say what it does; unknown boosts fall back to their raw id.
			local potion = GameData.boost(boostId)
			table.insert(boosts, {
				-- Normalised: the snapshot key is "<BoostId>EndsAt".
				id = GameData.boostId(boostId),
				label = if potion then potion.name else boostId,
				description = if potion then potion.description else nil,
				image = if potion then potion.image else nil,
				seconds = remaining,
			})
		end
	end
	table.sort(boosts, function(a, b)
		return a.seconds > b.seconds
	end)

	--[[
		The server-wide event, resolved from the id the server sent.

		The countdown is computed against the client clock exactly as the boost timers above are -- the
		server owns WHICH event and WHEN it ends, the client only counts down to it. `nil` when the
		schedule has nothing at all, which is the honest state for a HUD that used to permanently
		advertise an event that did not exist.
	]]
	--[[
		ACHIEVEMENT PROGRESS IS COMPUTED HERE, from the same `AchievementRules` the server pays from.

		The snapshot already carries every field those rules read, so the client can draw an exact
		progress bar without a single extra remote -- and because it is literally the same function, a bar
		that says 999/1000 cannot belong to an achievement the server thinks is complete.

		The shape below is the save's shape, not a new one: `AchievementRules` takes a save table, and
		handing it a differently-named copy is how the two would drift.
	]]
	local achievementData = {
		TotalScrapCollected = totalScrapCollected,
		Money = money,
		PrestigeCount = prestigeCount,
		DailyStreak = dailyStreak,
		UpgradeLevels = upgradeLevels,
		OwnedPets = ownedPets,
		EggOpenCounts = eggOpenCounts,
		UnlockedAreas = unlockedAreas,
		OwnedMagnets = ownedMagnets,
		DiscoveredScrap = discoveredScrap,
	}

	local achievements = {}
	for index, definition in ipairs(AchievementConfig.Definitions) do
		local value, threshold, complete = AchievementRules.progress(achievementData, definition)
		local title = TitleConfig.resolve(definition.Reward.TitleId)
		achievements[index] = {
			id = definition.Id,
			name = definition.Name,
			description = definition.Description,
			glyph = definition.Glyph,
			accent = definition.Accent,
			track = definition.Track,
			value = value,
			threshold = threshold,
			--- Earned, from the live numbers. `paid` is whether the reward has landed yet.
			complete = complete,
			paid = unlockedAchievements[definition.Id] == true,
			reward = definition.Reward,
			titleText = if title then title.Text else nil,
		}
	end

	--[[
		Titles, sorted by rarity then by name so the list reads worst-to-best rather than in config
		order. Locked ones stay in the list with their source named: a title you cannot see is a goal you
		do not have.
	]]
	local titles = {}
	for _, definition in ipairs(TitleConfig.Titles) do
		local owned = unlockedTitles[definition.Id] == true
		--[[
			A staff title nobody holds is not shown at all.

			Every other locked title is a GOAL -- its text is the point of the list. "ADMIN, locked, be an
			admin" is not a goal, it is a tease, and listing it invites the question of how to get it. Held,
			it appears like anything else.
		]]
		if owned or definition.Staff ~= true then
			local source = if definition.Source
				then AchievementConfig.ById[definition.Source]
				else nil
			table.insert(titles, {
				id = definition.Id,
				text = definition.Text,
				rarity = definition.Rarity,
				accent = TitleConfig.accent(definition),
				rank = TitleConfig.rarityRank(definition.Rarity),
				owned = owned,
				equipped = equippedTitle == definition.Id,
				sourceName = if source then source.Name elseif definition.Staff then "Staff" else "",
				sourceDetail = if source
					then source.Description
					elseif definition.Staff then "Granted by the game, not earned"
					else "",
			})
		end
	end
	table.sort(titles, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return a.text < b.text
	end)

	local ownedTitleCount = 0
	for _, title in ipairs(titles) do
		if title.owned then
			ownedTitleCount += 1
		end
	end

	--[[
		Which multi-hatch tiers are unlocked, and what each one costs to buy if not.

		Largest first, matching the config, so the window offers the biggest the player owns and the
		cheapest they do not.
	]]
	local hatchBatches = {}
	for index, batch in ipairs(PetConfig.HatchBatches) do
		local pass = MonetizationConfig.Passes[batch.Entitlement]
		hatchBatches[index] = {
			count = batch.Count,
			passId = batch.Entitlement,
			owned = entitlements[batch.Entitlement] == true,
			price = if pass then pass.DisplayPrice else 0,
		}
	end

	local event = nil
	local nextEvent = nil
	if activeEvent and activeEvent.Id then
		local definition = nil
		for _, candidate in ipairs(EventConfig.Events) do
			if candidate.Id == activeEvent.Id then
				definition = candidate
				break
			end
		end
		--[[
			THE HUD STRIP IS FOR LIVE EVENTS ONLY.

			It used to carry the upcoming one too, in grey, so a player would learn the cadence. That job
			moved to the world billboard, which is a better place for it: the HUD is where the game tells
			you what is true RIGHT NOW, and a permanent strip counting down to Saturday is the same kind of
			furniture the fake banner was -- always on screen, never actionable.

			`nextEvent` is still exposed for anything that wants to build anticipation elsewhere.
		]]
		local live = activeEvent.Live == true
		local target = if live then activeEvent.EndsAt else activeEvent.StartsAt
		local remaining = math.max(0, (target or now) - now)
		if definition and live then
			event = {
				id = definition.Id,
				title = definition.Title,
				detail = definition.Detail,
				glyph = definition.Glyph,
				accent = definition.Accent,
				live = true,
				seconds = remaining,
			}
		elseif definition then
			nextEvent = {
				id = definition.Id,
				title = definition.Title,
				detail = definition.Detail,
				glyph = definition.Glyph,
				accent = definition.Accent,
				live = false,
				seconds = remaining,
			}
		end
	end

	local state = {
		loaded = loaded,

		cash = money,
		gears = gears,
		eventTokens = nil,
		prestige = prestigeCount,
		storage = storedWeight,
		storageValue = storedValue,
		capacity = derived.StorageCapacity,
		derived = derived,

		upgradeLevels = upgradeLevels,
		unlockedAreas = unlockedAreas,
		ownedMagnets = ownedMagnets,
		equippedMagnet = equippedMagnet,
		equippedSkin = nil,
		potionCounts = inventory,
		entitlements = entitlements,
		ownedPets = ownedPets,
		equippedPets = equippedPets,
		-- The server's number, not a guess derived from what is equipped.
		petSlots = maximumEquippedPets,
		discoveredScrap = discoveredScrap,
		settings = settings,

		--[[
			Hatch batches this player may use. Built from `PetConfig.HatchBatches`, so a new tier is a config
			entry and a pass -- not an edit to the egg window.
		]]
		hatchBatches = hatchBatches,

		achievements = achievements,
		achievementsUnlocked = AchievementRules.unlockedCount(
			AchievementConfig.Definitions,
			unlockedAchievements
		),
		achievementTracks = AchievementConfig.Tracks,
		titles = titles,
		titlesOwned = ownedTitleCount,
		equippedTitle = equippedTitle,

		boosts = boosts,
		event = event,
		nextEvent = nextEvent,
		screen = screen,
		detail = if detail then { kind = detail.Kind, id = detail.Id } else nil,
		confirm = confirm,
		toasts = toasts,
		buyAmount = buyAmount,
		eggSummon = eggSummon,
		eggRoll = eggRoll,
		announce = announce,
		autoCollect = nil,
		cosmetics = {},

		--[[
			Return-to-play state. `claimedDays` is kept because `DailyRewardsScreen` already read it,
			but it now means what it says: how many days of the current calendar are behind you.
		]]
		claimedDays = math.max(0, dailyCalendarDay - 1),

		players = players,
		--[[
			Whether to OFFER the admin entry point. Not a permission check -- the server re-checks on every
			command -- just a reason not to show a button that would refuse everyone who pressed it.
		]]
		isAdmin = AdminConfig.IsAdmin(localUserId),

		dailyStreak = dailyStreak,
		--[[
			The login boost the streak is currently worth, computed ONCE here rather than in each place
			that shows it. The HUD icon and the rewards footer both display it, and two copies of this
			arithmetic is two chances for them to disagree by a percent.
		]]
		dailyBoostPercent = math.floor(
			math.min(
				math.max(0, dailyStreak - 1) * RewardsConfig.Daily.StreakBonusPerDay,
				RewardsConfig.Daily.MaximumStreakBonus
			)
					* 100
				+ 0.5
		),
		dailyDays = RewardsConfig.Daily.Days,
		--- Seconds until the reset, so the screen can show a live countdown.
		dailyResetSeconds = DayClock.secondsUntilNextDay(os.time()),
		dailyCalendarDay = dailyCalendarDay,
		dailyClaimable = dailyClaimable,
		playtimeSeconds = playtimeSeconds,
		playtimeClaimed = playtimeClaimed,
		playtimeMilestones = RewardsConfig.Playtime.Milestones,
		spinsAvailable = spinsAvailable,
		spinRoll = spinRoll,
		spinSegments = RewardsConfig.Spin.Segments,
		friendCount = friendCount,
		friendBoost = friendCount * RewardsConfig.Friends.BoostPerFriend,
		--[[
			`tutorialStep` is the CURRENT objective, so the step definition is resolved here rather
			than in three different components. nil once finished, which is what hides the overlay.
		]]
		tutorialStep = if tutorialComplete then nil else TutorialConfig.Steps[tutorialStep],
		tutorialTotal = #TutorialConfig.Steps,
		tutorialComplete = tutorialComplete,
	}

	local actions = if context then context.actions else Store.noopActions
	return state, actions
end

--------------------------------------------------------------------------------
-- Fallback, for a component rendered with no Provider above it
--------------------------------------------------------------------------------

Store.noopActions = setmetatable({}, {
	__index = function()
		return function() end
	end,
})

return Store
