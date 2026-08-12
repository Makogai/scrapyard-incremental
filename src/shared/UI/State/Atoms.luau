--!strict
--[[
	Atoms.luau
	The client's view of the world, as Charm atoms.

	Two groups, and the split matters:

		SERVER-OWNED   mirrors of PublicPlayerState. Written only by Bridge when a
		               StateChanged arrives. Nothing in the UI may write these --
		               the server owns money, storage, upgrades, areas and prestige,
		               and a UI that writes them is a UI that lies to the player.

		CLIENT-OWNED   which window is open, which item is selected, toast queue,
		               buy-amount selector. Purely local, never sent anywhere.

	Charm rather than a React context because the same state is read from
	controllers that are not React (magnet range visualiser, audio, pet follower).
	An atom can be subscribed from anywhere; a context cannot.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local GameState = require(ReplicatedStorage.Shared.Types.GameState)
local GameTypes = require(ReplicatedStorage.Shared.Types.GameTypes)

export type Toast = {
	Id: number,
	Title: string,
	Body: string?,
	Reward: string?,
	Glyph: string?,
	Accent: string?,
	Life: number,
}

export type Confirm = {
	Title: string,
	Lines: { string }?,
	Glyph: string?,
	Price: number?,
	Robux: number?,
	ConfirmText: string?,
	ConfirmVariant: string?,
	ConfirmDisabled: boolean?,
	OnConfirm: (() -> ())?,
}

export type Detail = {
	Kind: string,
	Id: string,
}

local Atoms = {}

--------------------------------------------------------------------------------
-- Server-owned. Written only by State/Bridge.
--------------------------------------------------------------------------------

local function emptyDerived(): GameState.DerivedStats
	return {
		MagnetStrength = 0,
		MagnetRange = 0,
		StorageCapacity = 1,
		MovementSpeed = 16,
		ScrapValue = 1,
		CollectionSpeed = 1,
		RespawnMultiplier = 1,
		RarityLuck = 1,
		PetMoneyMultiplier = 1,
	}
end

Atoms.money = Charm.atom(0)
Atoms.gears = Charm.atom(0)
Atoms.storedWeight = Charm.atom(0)
Atoms.storedValue = Charm.atom(0)
--[[
	THE MAILBOX AND THE SOCIAL CLAIMS, both server-owned and arriving in the normal snapshot.

	Not client-predicted: a claim pays money and marks a message, and those two have to land together or
	the player sees one without the other.
]]
Atoms.inbox = Charm.atom({} :: { { [string]: any } })
Atoms.socialClaims = Charm.atom({} :: { [string]: boolean })
--[[
	The two server-wide notices, written by `ServerNoticeController` rather than by a snapshot: they are
	moments, not state, and they belong to the SERVER rather than to this player's save.

	`broadcast` is `{ message, fromName, verified, receivedAt }` or nil.
	`restart` is `{ endsAt, startedBy }` or nil -- an ABSOLUTE deadline, so the HUD ticks its own clock.
]]
Atoms.broadcast = Charm.atom(nil :: { [string]: any }?)
Atoms.restart = Charm.atom(nil :: { [string]: any }?)
Atoms.derived = Charm.atom(emptyDerived())
Atoms.upgradeLevels = Charm.atom({} :: { [GameTypes.UpgradeId]: number })
Atoms.upgradeMaximums = Charm.atom({} :: { [GameTypes.UpgradeId]: number })
Atoms.unlockedAreas = Charm.atom({} :: { [GameTypes.AreaId]: boolean })

-- Extended state the pack UI already relied on. The server sends these in the
-- same StateChanged payload; missing fields simply stay at their defaults.
Atoms.prestigeCount = Charm.atom(0)
Atoms.totalScrapCollected = Charm.atom(0)
Atoms.ownedMagnets = Charm.atom({} :: { [string]: boolean })
Atoms.equippedMagnet = Charm.atom("MagnetBasic")
Atoms.inventory = Charm.atom({} :: { [string]: number })
Atoms.activeBoosts = Charm.atom({} :: { [string]: number })

--[[
	The server-wide event: `{ Id, EndsAt | StartsAt, Live }`.

	Identity comes from the server, not from running the schedule locally, so a player with a wrong
	system clock cannot be shown a banner that disagrees with the multipliers they are getting. The
	title, glyph and accent are looked up from `EventConfig` by id at render time.
]]
Atoms.activeEvent = Charm.atom(nil :: { [string]: any }?)

--[[
	Achievements and titles.

	`unlockedAchievements` is the PAID set, not the earned set: progress is recomputed from the other
	atoms by `AchievementRules`, exactly as the server recomputes it from the save. One rule
	implementation, two readers.
]]
--- Eggs opened per egg id, which one achievement counts and nothing else reads yet.
Atoms.eggOpenCounts = Charm.atom({} :: { [string]: number })

--[[
	Pet storage, and guaranteed-Secret tickets.

	Storage capacity is the number hatching is refused over, so the pets window shows it: a player told
	"pet storage is full" can look up and see 50/50 rather than counting cards.
]]
Atoms.petStorageCapacity = Charm.atom(0)
Atoms.secretTickets = Charm.atom(0)

Atoms.unlockedAchievements = Charm.atom({} :: { [string]: boolean })
Atoms.unlockedTitles = Charm.atom({} :: { [string]: boolean })
Atoms.equippedTitle = Charm.atom("")
Atoms.entitlements = Charm.atom({} :: { [string]: boolean })
Atoms.ownedPets = Charm.atom({} :: { [string]: number })
Atoms.equippedPets = Charm.atom({} :: { string })
Atoms.petSlotUpgradeLevel = Charm.atom(0)
--[[
	The server's own equip-slot count, straight out of the snapshot. The UI used to
	derive this, which is how the header came to read "EQUIPPED 2 / 1": two pets were
	equipped while the client believed there was one slot. One source of truth.
]]
Atoms.maximumEquippedPets = Charm.atom(PetConfig.BaseEquipSlots)
Atoms.discoveredScrap = Charm.atom({} :: { [string]: any })
Atoms.settings = Charm.atom({
	ParticlesEnabled = true,
	ScreenEffectsEnabled = true,
	SoundEnabled = true,
	MusicEnabled = true,
	SoundVolume = 0.8,
	MusicVolume = 0.55,
})

--[[
	Return-to-play state, all server-owned. The server sends answers rather than raw timestamps --
	`dailyClaimable` is a boolean it computed, not something the client works out from a clock it
	controls. See `PlayerStateService.publicSnapshot`.
]]
Atoms.dailyStreak = Charm.atom(0)
Atoms.dailyCalendarDay = Charm.atom(1)
Atoms.dailyClaimable = Charm.atom(false)
Atoms.playtimeSeconds = Charm.atom(0)
Atoms.playtimeClaimed = Charm.atom({} :: { [number]: boolean })
Atoms.spinsAvailable = Charm.atom(0)
Atoms.tutorialStep = Charm.atom(0)
Atoms.tutorialComplete = Charm.atom(false)
Atoms.friendCount = Charm.atom(0)

--- True once the first authoritative snapshot has landed. Screens show their
--- loading state until then rather than rendering zeroes as if they were real.
Atoms.loaded = Charm.atom(false)

--------------------------------------------------------------------------------
-- Client-owned. Free for the UI to write.
--------------------------------------------------------------------------------

Atoms.screen = Charm.atom(nil :: string?)
Atoms.detail = Charm.atom(nil :: Detail?)
Atoms.confirm = Charm.atom(nil :: Confirm?)
Atoms.toasts = Charm.atom({} :: { Toast })
Atoms.buyAmount = Charm.atom("x1")

--[[
	Egg summoning, all client-owned. The server decides *what* hatched; these three
	only describe what the player is looking at while it happens.

		eggSummon  egg id whose summon window is open, or nil
		eggRoll    the roll takeover: nil when idle, otherwise
		           { EggId, Phase = "shaking" | "revealed", PetId? }
		announce   the full-width banner, or nil
]]
Atoms.eggSummon = Charm.atom(nil :: string?)
Atoms.eggRoll = Charm.atom(nil :: { [string]: any }?)
Atoms.announce = Charm.atom(nil :: { [string]: any }?)
Atoms.deviceOverride = Charm.atom(nil :: string?)

--[[
	The spin wheel takeover, client-owned because it only describes an animation. The server has
	already decided and already granted the prize; this is where the wheel is in the process of
	showing it.

		nil                                    idle
		{ Phase = "spinning", Index, ... }     turning toward Index
		{ Phase = "revealed", Index, Label }   stopped, prize shown
]]
Atoms.spinRoll = Charm.atom(nil :: { [string]: any }?)

--------------------------------------------------------------------------------
-- Derived
--------------------------------------------------------------------------------

Atoms.storageFull = Charm.computed(function()
	local capacity = Atoms.derived().StorageCapacity
	return capacity > 0 and Atoms.storedWeight() >= capacity
end)

--- Applies a PublicPlayerState snapshot. The single write path for server state.
--[[
	Charm's `subscribe`, re-exported. Controllers live outside React and still need
	to react to state; going through here keeps `Packages.Charm` an implementation
	detail of this module rather than something every controller imports.

	Returns an unsubscribe function.
]]
Atoms.subscribe = Charm.subscribe

function Atoms.applySnapshot(snapshot: any)
	if type(snapshot) ~= "table" then
		return
	end

	if type(snapshot.Money) == "number" then
		Atoms.money(snapshot.Money)
	end
	if type(snapshot.Gears) == "number" then
		Atoms.gears(snapshot.Gears)
	end
	if type(snapshot.StoredWeight) == "number" then
		Atoms.storedWeight(snapshot.StoredWeight)
	end
	if type(snapshot.StoredValue) == "number" then
		Atoms.storedValue(snapshot.StoredValue)
	end
	if type(snapshot.Inbox) == "table" then
		Atoms.inbox(snapshot.Inbox)
	end
	if type(snapshot.SocialClaims) == "table" then
		Atoms.socialClaims(snapshot.SocialClaims)
	end
	if type(snapshot.DerivedStats) == "table" then
		Atoms.derived(snapshot.DerivedStats)
	end
	if type(snapshot.UpgradeLevels) == "table" then
		Atoms.upgradeLevels(snapshot.UpgradeLevels)
	end
	if type(snapshot.UpgradeMaximumLevels) == "table" then
		Atoms.upgradeMaximums(snapshot.UpgradeMaximumLevels)
	end
	if type(snapshot.UnlockedAreas) == "table" then
		Atoms.unlockedAreas(snapshot.UnlockedAreas)
	end

	if type(snapshot.PrestigeCount) == "number" then
		Atoms.prestigeCount(snapshot.PrestigeCount)
	end
	if type(snapshot.TotalScrapCollected) == "number" then
		Atoms.totalScrapCollected(snapshot.TotalScrapCollected)
	end
	if type(snapshot.OwnedMagnets) == "table" then
		Atoms.ownedMagnets(snapshot.OwnedMagnets)
	end
	if type(snapshot.EquippedMagnet) == "string" then
		Atoms.equippedMagnet(snapshot.EquippedMagnet)
	end
	if type(snapshot.Inventory) == "table" then
		Atoms.inventory(snapshot.Inventory)
	end
	if type(snapshot.PetStorageCapacity) == "number" then
		Atoms.petStorageCapacity(snapshot.PetStorageCapacity)
	end
	if type(snapshot.SecretTickets) == "number" then
		Atoms.secretTickets(snapshot.SecretTickets)
	end
	if type(snapshot.EggOpenCounts) == "table" then
		Atoms.eggOpenCounts(snapshot.EggOpenCounts)
	end
	if type(snapshot.UnlockedAchievements) == "table" then
		Atoms.unlockedAchievements(snapshot.UnlockedAchievements)
	end
	if type(snapshot.UnlockedTitles) == "table" then
		Atoms.unlockedTitles(snapshot.UnlockedTitles)
	end
	if type(snapshot.EquippedTitle) == "string" then
		Atoms.equippedTitle(snapshot.EquippedTitle)
	end
	if type(snapshot.ActiveEvent) == "table" then
		Atoms.activeEvent(snapshot.ActiveEvent)
	end
	if type(snapshot.ActiveBoosts) == "table" then
		Atoms.activeBoosts(snapshot.ActiveBoosts)
	end
	if type(snapshot.Entitlements) == "table" then
		Atoms.entitlements(snapshot.Entitlements)
	end
	if type(snapshot.OwnedPets) == "table" then
		Atoms.ownedPets(snapshot.OwnedPets)
	end
	if type(snapshot.EquippedPets) == "table" then
		Atoms.equippedPets(snapshot.EquippedPets)
	end
	if type(snapshot.MaximumEquippedPets) == "number" then
		Atoms.maximumEquippedPets(snapshot.MaximumEquippedPets)
	end
	if type(snapshot.PetSlotUpgradeLevel) == "number" then
		Atoms.petSlotUpgradeLevel(snapshot.PetSlotUpgradeLevel)
	end
	if type(snapshot.DiscoveredScrap) == "table" then
		Atoms.discoveredScrap(snapshot.DiscoveredScrap)
	end
	if type(snapshot.Settings) == "table" then
		Atoms.settings(snapshot.Settings)
	end

	if type(snapshot.DailyStreak) == "number" then
		Atoms.dailyStreak(snapshot.DailyStreak)
	end
	if type(snapshot.DailyCalendarDay) == "number" then
		Atoms.dailyCalendarDay(snapshot.DailyCalendarDay)
	end
	if type(snapshot.DailyClaimable) == "boolean" then
		Atoms.dailyClaimable(snapshot.DailyClaimable)
	end
	if type(snapshot.PlaytimeSecondsToday) == "number" then
		Atoms.playtimeSeconds(snapshot.PlaytimeSecondsToday)
	end
	if type(snapshot.PlaytimeClaimed) == "table" then
		Atoms.playtimeClaimed(snapshot.PlaytimeClaimed)
	end
	if type(snapshot.SpinsAvailable) == "number" then
		Atoms.spinsAvailable(snapshot.SpinsAvailable)
	end
	if type(snapshot.TutorialStep) == "number" then
		Atoms.tutorialStep(snapshot.TutorialStep)
	end
	if type(snapshot.TutorialComplete) == "boolean" then
		Atoms.tutorialComplete(snapshot.TutorialComplete)
	end
	if type(snapshot.FriendBoostCount) == "number" then
		Atoms.friendCount(snapshot.FriendBoostCount)
	end

	Atoms.loaded(true)
end

return Atoms
