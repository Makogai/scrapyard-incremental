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
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	Glyph: string?,
	Accent: string?,
}

export type AdminSection = {
	Id: string,
	Label: string,
	Glyph: string,
	Accent: string,
	Entries: { AdminEntry },
}

local AdminCatalogue = {}

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
	}),
})

--- Builds the section list fresh. Called by the UI, so a live config edit shows up on reopen.
function AdminCatalogue.build(): { AdminSection }
	local sections: { AdminSection } = {}

	--[[
		Resources use the amount box. Money and gears are the only two grantables where the number is
		the point rather than the item.
	]]
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
		One-shot actions. `ResetTestProfile` is flagged `Danger` because it wipes a save, and the UI
		asks twice before sending it -- the server also refuses it outside Studio and for any target
		other than yourself.
	]]
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
			{
				Id = "ResetTestProfile",
				Label = "RESET PROFILE",
				Command = "ResetTestProfile",
				Danger = true,
				Glyph = "recycle",
				Accent = "Red",
			},
		},
	})

	return sections
end

return table.freeze(AdminCatalogue)
