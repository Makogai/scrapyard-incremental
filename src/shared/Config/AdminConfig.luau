--!strict

local adminUserIds: { [number]: boolean } = {
	[1113999731] = true,
	[7862008029] = true,
	[11218362231] = true,
}

local AdminConfig = {}
AdminConfig.MaximumGrantMoney = 1e12
AdminConfig.MaximumGrantGears = 100000
--[[
	Broadcast and restart bounds.

	The message cap is short on purpose: a broadcast is a banner over gameplay, and anything longer than a
	sentence belongs in the inbox where it can be read at leisure. The restart floor is long enough to read
	and act on; the ceiling is long enough to finish a rebirth.
]]
AdminConfig.MaximumBroadcastLength = 180
AdminConfig.MinimumRestartSeconds = 10
AdminConfig.MaximumRestartSeconds = 600

--[[
	How long a server-wide boost or event may be run for, in minutes.

	A real ceiling, not a formality: these land on everybody, and "1440" fat-fingered into the amount box
	is a day of quintuple payouts across the experience. The owner is not exempt -- the risk is identical
	whoever typed it.
]]
AdminConfig.MaximumServerBoostMinutes = 120
AdminConfig.MaximumEventMinutes = 240

--[[
	TWO TIERS, ONE PANEL.

	Both tiers open the same window; they do not get the same buttons. The line is not seniority, it is
	what cannot be undone from inside the game:

		Admin   money, items, upgrades, pets, titles; events and boosts on THIS server
		Owner   all of that, plus anything that reaches every server at once, grants a paid
		        entitlement, or wipes a save

	`AdminCatalogue` marks the owner-only entries and `AdminService` enforces it. The panel hiding them is
	a courtesy; the server refusing them is the lock.
]]
function AdminConfig.IsAdmin(userId: number): boolean
	--[[
		AN OWNER IS ALWAYS AN ADMIN, as an implication rather than a duplicated id. The alternative is an
		owner who is not in the list below getting no panel at all -- the sort of thing nobody notices
		until the one person who could fix it is the one locked out.
	]]
	return adminUserIds[userId] == true or AdminConfig.IsOwner(userId)
end

--[[
	Who wears the OWNER title.

	`game.CreatorId` is the place's owner -- the account or group that published it -- so this needs no
	list to keep in step with reality. For a GROUP game the creator id is the GROUP's id and no player
	will ever match it, which is why the explicit set below exists as well: put the human owner's user id
	in it and they get the title in a group game too.

	Deliberately separate from `IsAdmin`. An admin can hand out money; an owner is a person. Conflating
	them would mean every admin wears OWNER, which is the one title that should mean exactly one person.
]]
local ownerUserIds: { [number]: boolean } = {
	[1113999731] = true,
	[7862008029] = true,
}

function AdminConfig.IsOwner(userId: number): boolean
	if ownerUserIds[userId] == true then
		return true
	end
	--[[
		The creator check, guarded because THERE IS NOT ALWAYS A `game`.

		This module is required by the Lune test suite, which has no DataModel -- and the moment `IsAdmin`
		started answering through here, `game.CreatorType` threw and took the whole suite down with it. A
		config module that only works inside Roblox cannot be tested, and this one is the last place that
		should go untested.

		Only meaningful when the place is owned by a user anyway: a group's `CreatorId` matches no player,
		which is what the explicit list above is for.
	]]
	local ok, isCreator = pcall(function()
		return game.CreatorType == Enum.CreatorType.User and game.CreatorId == userId
	end)
	return ok and isCreator
end

return table.freeze(AdminConfig)
