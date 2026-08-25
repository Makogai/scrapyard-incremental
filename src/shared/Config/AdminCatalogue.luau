--!strict
--[[
	AdminCatalogue.luau
	Everything an admin can hand out, derived from the game's own configs.

	DYNAMIC BY CONSTRUCTION. Nothing here lists a magnet, a potion, an upgrade or a pet by name -- it
	walks `InventoryConfig`, `UpgradeConfig` and `PetConfig`. Add a new magnet and it appears in the
	admin panel with no edit here and no edit in the UI. That was the requirement, and it is also the
	only way a panel like this stays true: a hand-maintained list of grantables drifts from the real
	content within a week.

	The panel is a VIEW of this. It renders whatever sections and entries it finds, so a new section
	added below shows up without touching `AdminScreen`.

	Every entry names an existing `PlayerStateService.AdminMutate` command. This module invents no
	server behaviour -- if a command is not implemented there, it does not belong here.

		Command   the AdminMutate command string
		ItemId    passed through as the command's item argument, when it takes one
		Amount    true if the entry uses the panel's amount box
		Danger    true for anything destructive, so the UI can style it apart
		Owner     true if only the owner may use it -- see `OWNER_ONLY_COMMANDS`

	A section may also declare `Mode = "MultiSelect"`, which asks the panel for a tick list and a single
	action button instead of one button per entry. That exists because some things are only useful
	together: turning on four boosts is one decision, not four.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local TitleConfig = require(ReplicatedStorage.Shared.Config.TitleConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local InventoryConfig = require(ReplicatedStorage.Shared.Config.InventoryConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)

export type AdminEntry = {
	Id: string,
	Label: string,
	Command: string,
	ItemId: string?,
	Amount: boolean?,
	Danger: boolean?,
	Owner: boolean?,
	Glyph: string?,
	Accent: string?,
}

export type AdminSection = {
	Id: string,
	Label: string,
	Glyph: string,
	Accent: string,
	Entries: { AdminEntry },
	--- `"MultiSelect"` for a tick list with one action; nil for a button per entry.
	Mode: string?,
	--- MultiSelect only: what the action button says, the command it sends, and what the amount means.
	ActionLabel: string?,
	Command: string?,
	AmountLabel: string?,
	Owner: boolean?,
}

local AdminCatalogue = {}

--[[
	WHAT ONLY THE OWNER MAY DO.

	The test is not "how powerful" but "what cannot be undone from inside the game":

		GrantEntitlement   writes the flag a real Robux purchase writes. Handing out paid unlocks is the
		                   owner's call, not a moderation tool.
		ResetProfile       wipes a save with no undo. `AdminService` also refuses it for the EVERYONE and
		                   EVERY SERVER targets, so it can only ever reach one person at a time.

	Everything else is available to an admin, INCLUDING events and server-wide boosts: those expire on
	their own and are clamped by `AdminConfig`, so the worst case is a busy hour rather than a lost save.

	Reach is gated separately -- see `isOwnerOnlyTarget`. "Everyone in this server" and "everyone in the
	game" are different amounts of damage, whatever the command is.
]]
local OWNER_ONLY_COMMANDS = table.freeze({
	GrantEntitlement = true,
	ResetProfile = true,
})

--- Reach that only the owner has. One server is an admin's business; every server is not.
local OWNER_ONLY_TARGETS = table.freeze({
	AllServers = true,
})

function AdminCatalogue.isOwnerOnlyCommand(command: string): boolean
	return OWNER_ONLY_COMMANDS[command] == true
end

function AdminCatalogue.isOwnerOnlyTarget(target: string): boolean
	return OWNER_ONLY_TARGETS[target] == true
end

--[[
	Target modes the panel offers.

	`AllServers` is the one with teeth: it goes out over `MessagingService` and lands on every running
	server. It is listed last and flagged `Wide` so the UI can make it look like the serious option it
	is.
]]
AdminCatalogue.Targets = table.freeze({
	table.freeze({ Id = "Self", Label = "ME", Glyph = "paw" }),
	table.freeze({ Id = "Player", Label = "PICKED PLAYER", Glyph = "friends" }),
	table.freeze({ Id = "All", Label = "EVERYONE HERE", Glyph = "friends" }),
	table.freeze({
		Id = "AllServers",
		Label = "EVERY SERVER",
		Glyph = "star",
		Wide = true,
		--- Owner-only, enforced in `AdminService`; the panel hides it from an admin as a courtesy.
		Owner = true,
	}),
})

--- Builds the section list fresh. Called by the UI, so a live config edit shows up on reopen.
function AdminCatalogue.build(): { AdminSection }
	local sections: { AdminSection } = {}

	--[[
		Resources use the amount box. Money and gears are the only two grantables where the number is
		the point rather than the item.
	]]
	--[[
		SERVER-WIDE STAFF TOOLS. Owner-gated: a broadcast speaks for the game, and a restart ends everyone's
		session, so neither belongs behind the same permission as handing out a potion.

		`Broadcast` takes its text from the panel's message field; `RESTART` takes seconds from the amount
		stepper. Both are handled once per press rather than per target -- see `AdminService`.
	]]
	table.insert(sections, {
		Id = "server",
		Label = "SERVER",
		Glyph = "admin",
		Accent = "Red",
		Entries = {
			{
				Id = "Broadcast",
				Label = "BROADCAST",
				Command = "Broadcast",
				Text = true,
				Owner = true,
				Glyph = "note",
				Accent = "Cyan",
			},
			--[[
				DANGER, so it takes the panel's tap-again confirm.

				It sits next to BROADCAST, and the two are one mis-tap apart: pressing this ends every session
				on the server, and there is no undo once the countdown starts -- CANCEL RESTART only helps if
				somebody notices in time. `ResetProfile` is flagged for the same reason.

				`Amount` is the countdown in SECONDS, clamped server-side to
				`AdminConfig.MinimumRestartSeconds`..`MaximumRestartSeconds`.
			]]
			{
				Id = "RestartServer",
				Label = "RESTART",
				Command = "RestartServer",
				Amount = true,
				Owner = true,
				Danger = true,
				Glyph = "clock",
				Accent = "Red",
			},
			{
				Id = "CancelRestart",
				Label = "CANCEL RESTART",
				Command = "CancelRestart",
				Owner = true,
				Glyph = "cross",
				Accent = "Gray",
			},
		},
	})

	table.insert(sections, {
		Id = "resources",
		Label = "RESOURCES",
		Glyph = "coin",
		Accent = "Green",
		Entries = {
			{
				Id = "AddMoney",
				Label = "CASH",
				Command = "AddMoney",
				Amount = true,
				Glyph = "coin",
				Accent = "Green",
			},
			{
				Id = "AddGears",
				Label = "GEARS",
				Command = "AddGears",
				Amount = true,
				Glyph = "gear",
				Accent = "Gold",
			},
			{
				Id = "AddSlag",
				Label = "SLAG",
				Command = "AddSlag",
				Amount = true,
				Glyph = "crate",
				Accent = "Gold",
			},
			--[[
				The three that were missing, and the reason this section is RESOURCES rather than
				CURRENCIES: anything a player holds a COUNT of belongs here, so testing a spin, a streak
				position or a rebirth tier needs no console command.
			]]
			{
				Id = "AddSpins",
				Label = "SPINS",
				Command = "AddSpins",
				Amount = true,
				Glyph = "wheel",
				Accent = "Purple",
			},
			{
				Id = "SetDailyStreak",
				--- SET, not add: the point of testing a streak is landing on a chosen calendar day.
				Label = "STREAK (SET)",
				Command = "SetDailyStreak",
				Amount = true,
				Glyph = "calendar",
				Accent = "Cyan",
			},
			{
				--[[
					A guaranteed-Secret roll. The amount box sets how many.

					Lives with RESOURCES because it is a count the player holds, and the point of it is the
					ROLL: spending one runs the real hatch, the real reveal and the real server-wide
					announcement, which is what anyone granting this is actually trying to look at.
				]]
				Id = "GrantSecretTicket",
				Label = "SECRET TICKETS",
				Command = "GrantSecretTicket",
				Amount = true,
				Glyph = "star",
				Accent = "Gold",
			},
			{
				Id = "AddRebirths",
				Label = "REBIRTHS",
				Command = "AddRebirths",
				Amount = true,
				Glyph = "star",
				Accent = "Pink",
			},
		},
	})

	--- Magnets, in shop order so the panel reads the same way the shop does.
	local magnets: { AdminEntry } = {}
	for _, magnetId in InventoryConfig.MagnetOrder do
		local definition = InventoryConfig.Magnets[magnetId]
		if definition then
			table.insert(magnets, {
				Id = magnetId,
				Label = definition.DisplayName,
				Command = "GrantMagnet",
				ItemId = magnetId,
				Glyph = "magnet",
				Accent = "Blue",
			})
		end
	end
	table.insert(sections, {
		Id = "magnets",
		Label = "MAGNETS",
		Glyph = "magnet",
		Accent = "Blue",
		Entries = magnets,
	})

	--- Potions. These take a count, so they use the amount box.
	local consumables: { AdminEntry } = {}
	for _, itemId in InventoryConfig.ConsumableOrder do
		local definition = InventoryConfig.Consumables[itemId]
		if definition then
			table.insert(consumables, {
				Id = itemId,
				Label = definition.DisplayName,
				Command = "GrantConsumable",
				ItemId = itemId,
				Amount = true,
				Glyph = "potion",
				Accent = "Purple",
			})
		end
	end
	table.insert(sections, {
		Id = "potions",
		Label = "POTIONS",
		Glyph = "potion",
		Accent = "Purple",
		Entries = consumables,
	})

	--- Upgrades, in config order, each adding levels by the amount box.
	local upgrades: { AdminEntry } = {}
	for _, upgradeId in UpgradeConfig.Order do
		local definition = UpgradeConfig.ById[upgradeId]
		if definition then
			table.insert(upgrades, {
				Id = upgradeId,
				Label = definition.DisplayName,
				Command = "AddUpgradeLevels",
				ItemId = upgradeId,
				Amount = true,
				Glyph = "upgrade",
				Accent = "Cyan",
			})
		end
	end
	table.insert(sections, {
		Id = "upgrades",
		Label = "UPGRADES",
		Glyph = "upgrade",
		Accent = "Cyan",
		Entries = upgrades,
	})

	--[[
		Pets. `PetConfig.Order` if it exists, otherwise whatever the table holds -- a dictionary walk
		gives an unstable order, so the list is sorted to keep the panel from reshuffling between opens.
	]]
	local petIds: { string } = {}
	if PetConfig.Order then
		for _, petId in PetConfig.Order do
			table.insert(petIds, petId)
		end
	else
		for petId in PetConfig.Pets do
			table.insert(petIds, petId)
		end
		table.sort(petIds)
	end
	local pets: { AdminEntry } = {}
	for _, petId in petIds do
		local definition = PetConfig.Pets[petId]
		if definition then
			table.insert(pets, {
				Id = petId,
				Label = definition.DisplayName or petId,
				Command = "GrantPet",
				ItemId = petId,
				Amount = true,
				Glyph = "paw",
				Accent = "Pink",
			})
		end
	end
	table.insert(sections, {
		Id = "pets",
		Label = "PETS",
		Glyph = "paw",
		Accent = "Pink",
		Entries = pets,
	})

	--[[
		One-shot actions. `ResetProfile` is flagged `Danger` because it wipes a save with no undo, so the
		panel asks twice before sending it -- and the server refuses it for any target broader than one
		named player.
	]]
	--[[
		Game passes, as entitlements.

		The panel could already hand out every consumable, magnet, pet, spin and title but not the one
		category that costs real money -- which made testing anything gated behind a pass impossible
		without buying it. Granting here writes the same `Entitlements` flag a receipt does, so what is
		being tested is the real unlocked state rather than a lookalike.
	]]
	local entitlements: { AdminEntry } = {}
	for _, passId in MonetizationConfig.PassOrder do
		local definition = MonetizationConfig.Passes[passId]
		if definition then
			table.insert(entitlements, {
				Id = passId,
				Label = definition.DisplayName,
				Command = "GrantEntitlement",
				ItemId = passId,
				Glyph = "robux",
				Accent = "Pink",
				Owner = true,
			})
		end
	end
	table.insert(sections, {
		Id = "passes",
		Label = "PASSES",
		Glyph = "robux",
		Accent = "Pink",
		Entries = entitlements,
		Owner = true,
	})

	--[[
		Titles, in rarity order so the list reads the way the inventory tab does.

		Granting a title from here WEARS it as well. That is the opposite of what an achievement does --
		which only hands it over -- and it is deliberate: the reason to grant a title in a test session is
		almost always to look at it over a head, and needing a second trip to the inventory to do that
		wastes the one action the panel exists to save.
	]]
	local titles: { AdminEntry } = {}
	local sortedTitles = table.clone(TitleConfig.Titles)
	table.sort(sortedTitles, function(a, b)
		local rankA, rankB = TitleConfig.rarityRank(a.Rarity), TitleConfig.rarityRank(b.Rarity)
		if rankA ~= rankB then
			return rankA < rankB
		end
		return a.Text < b.Text
	end)
	for _, definition in sortedTitles do
		table.insert(titles, {
			Id = definition.Id,
			--- The rarity is in the label because the whole point of granting one is to see its tier.
			Label = `{definition.Text} ({string.upper(definition.Rarity)})`,
			Command = "GrantTitle",
			ItemId = definition.Id,
			Glyph = "trophy",
			Accent = TitleConfig.accent(definition),
		})
	end
	table.insert(sections, {
		Id = "titles",
		Label = "TITLES",
		Glyph = "trophy",
		Accent = "Pink",
		Entries = titles,
	})

	table.insert(sections, {
		Id = "actions",
		Label = "ACTIONS",
		Glyph = "sliders",
		Accent = "Orange",
		Entries = {
			{
				Id = "UnlockAllAreas",
				Label = "UNLOCK ALL AREAS",
				Command = "UnlockAllAreas",
				Glyph = "pin",
				Accent = "Green",
			},
			{
				Id = "MaxUpgrades",
				Label = "MAX UPGRADES",
				Command = "MaxUpgrades",
				Glyph = "upgrade",
				Accent = "Cyan",
			},
			{
				Id = "GrantTestItems",
				Label = "TEST ITEM PACK",
				Command = "GrantTestItems",
				Glyph = "basket",
				Accent = "Gold",
			},
			{
				Id = "ClearStorage",
				Label = "CLEAR STORAGE",
				Command = "ClearStorage",
				Glyph = "crate",
				Accent = "Neutral",
			},
			--[[
				A REAL WIPE, on any server, on yourself or on a picked player.

				It used to be `ResetTestProfile` and `AdminService` refused it unless you were in Studio AND
				targeting yourself -- so "reset someone" silently did nothing, which is worse than a refusal
				because nothing says so. The name went with the restriction: this is not a test helper.

				Still owner-only, still `Danger` so the panel asks twice, and `AdminService` refuses it for
				the EVERYONE and EVERY SERVER targets -- a mis-tap there wipes a server with no undo.
			]]
			{
				Id = "ResetProfile",
				Label = "RESET PROFILE",
				Command = "ResetProfile",
				Danger = true,
				Glyph = "recycle",
				Accent = "Red",
				Owner = true,
			},
		},
	})

	--[[
		EVENTS, started by hand.

		One entry per scheduled event plus a stop. The amount box is MINUTES here rather than a quantity,
		which is why the section says so in its own label -- the box is shared across sections and cannot
		change its own caption.

		Not a multi-select: exactly one event is live at a time by definition, so a tick list would be
		offering a choice the system cannot honour. Starting a second one replaces the first.
	]]
	local eventEntries: { AdminEntry } = {}
	for _, definition in EventConfig.Events do
		table.insert(eventEntries, {
			Id = definition.Id,
			Label = definition.Title,
			Command = "StartEvent",
			ItemId = definition.Id,
			Amount = true,
			Glyph = definition.Glyph,
			Accent = definition.Accent,
		})
	end
	table.insert(eventEntries, {
		Id = "StopEvent",
		Label = "STOP EVENT",
		Command = "StopEvent",
		Glyph = "cross",
		Accent = "Neutral",
	})
	table.insert(sections, {
		Id = "events",
		Label = "EVENTS",
		Glyph = "star",
		Accent = "Cyan",
		Entries = eventEntries,
		AmountLabel = "MINUTES",
	})

	--[[
		THE PIT. Server-level, like events: the wreck is not a per-player save field.

		Its own tab so the amount box can say HP instead of inheriting EVENTS' MINUTES.
	]]
	table.insert(sections, {
		Id = "pit",
		Label = "THE PIT",
		Glyph = "crate",
		Accent = "Orange",
		AmountLabel = "HP",
		Entries = {
			{
				Id = "SetWreckHp",
				Label = "SET WRECK HP",
				Command = "SetWreckHp",
				Amount = true,
				Glyph = "crate",
				Accent = "Orange",
			},
		},
	})

	--[[
		BOOSTS: potion effects turned on directly, several at once, for a chosen number of minutes.

		A MULTI-SELECT because that is how the decision is actually made -- "double cash and triple luck
		for half an hour" is one announcement, and firing it as separate commands would stagger the start
		times and burn a rate-limit slot each.

		Distinct from the `potions` section above, which hands over BOTTLES. A bottle needs the player to
		open their inventory and drink it, so it is the wrong tool for something meant to land on everyone
		at once: half the server never opens the bag.
	]]
	local boostEntries: { AdminEntry } = {}
	for itemId, definition in InventoryConfig.Consumables do
		table.insert(boostEntries, {
			Id = itemId,
			Label = definition.DisplayName,
			Command = "ActivateBoost",
			ItemId = itemId,
			Glyph = "potion",
			Accent = "Purple",
		})
	end
	table.sort(boostEntries, function(a, b)
		return a.Label < b.Label
	end)
	table.insert(sections, {
		Id = "boosts",
		Label = "BOOSTS",
		Glyph = "potion",
		Accent = "Purple",
		Mode = "MultiSelect",
		ActionLabel = "ACTIVATE SELECTED",
		Command = "ActivateBoost",
		AmountLabel = "MINUTES",
		Entries = boostEntries,
	})

	return sections
end

return table.freeze(AdminCatalogue)
