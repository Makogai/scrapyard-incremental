--!strict

local adminUserIds: { [number]: boolean } = {
	[1113999731] = true,
	[7862008029] = false,
}

local AdminConfig = {}
AdminConfig.MaximumGrantMoney = 1e12
AdminConfig.MaximumGrantGears = 100000

function AdminConfig.IsAdmin(userId: number): boolean
	return adminUserIds[userId] == true
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
}

function AdminConfig.IsOwner(userId: number): boolean
	if ownerUserIds[userId] == true then
		return true
	end
	--- Only meaningful when the place is owned by a user; a group's CreatorId matches no player.
	return game.CreatorType == Enum.CreatorType.User and game.CreatorId == userId
end

return table.freeze(AdminConfig)
