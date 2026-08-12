--!strict
--[[
	InboxConfig.luau
	The player's mailbox: what a message can be, and how many are kept.

	WHY AN INBOX AT ALL. Admin grants used to land in a player's data silently -- money appeared, a pet
	appeared, and nobody could tell whether it arrived, who sent it, or whether it was a gift or a bug.
	Everything an admin hands out now becomes a message the player CLAIMS, which gives three things a
	silent grant cannot: proof it arrived, the name of the staff member who sent it, and a record after
	the fact.

	Rewards use the same shape as codes, products and the daily calendar, so `PlayerStateService.
	GrantRewards` pays them out and nothing here needs its own granting path:

		{ Money = number?, Gears = number?, Items = { [itemId]: count }?, Spins = number? }
]]

export type InboxRewards = {
	Money: number?,
	Gears: number?,
	Items: { [string]: number }?,
	Spins: number?,
}

export type InboxMessage = {
	--- Unique within one player's mailbox. Claiming is keyed off it, so it must not be reused.
	Id: string,
	--- "Staff" for an admin grant, "System" for anything the game itself sends.
	Kind: string,
	Title: string,
	Body: string,
	--- Display name of the sender. Empty for System messages.
	FromName: string,
	FromUserId: number,
	SentAt: number,
	Rewards: InboxRewards?,
	Claimed: boolean,
}

local InboxConfig = {}

--[[
	How many messages a mailbox keeps, newest first.

	Bounded because this lives in the save. 40 messages of a few hundred bytes is trivial against the
	DataStore limit, and a player who never claims anything cannot grow their save without limit --
	the oldest CLAIMED message is dropped first, so an unclaimed reward is never silently deleted.
]]
InboxConfig.MaximumMessages = 40

--- Hard caps on what a sender can put in a message, so a bad admin cannot bloat a save.
InboxConfig.MaximumTitleLength = 60
InboxConfig.MaximumBodyLength = 280

--[[
	The two senders, and how they read.

	`Staff` carries the verified tick. That badge is the whole point: a player has to be able to tell a
	real staff gift from a message pretending to be one, and only the server ever writes this field.
]]
InboxConfig.Kinds = table.freeze({
	Staff = table.freeze({
		Id = "Staff",
		Label = "STAFF",
		Glyph = "check",
		Accent = "Cyan",
		Verified = true,
	}),
	System = table.freeze({
		Id = "System",
		Label = "SYSTEM",
		Glyph = "note",
		Accent = "Purple",
		Verified = false,
	}),
})

InboxConfig.DefaultKind = "System"

function InboxConfig.kind(kindId: string)
	return InboxConfig.Kinds[kindId] or InboxConfig.Kinds[InboxConfig.DefaultKind]
end

--[[
	How many unclaimed messages a mailbox holds, for the topbar pip.

	Counted rather than stored, so it cannot fall out of step with the list it describes.
]]
function InboxConfig.unclaimedCount(messages: { InboxMessage }?): number
	if messages == nil then
		return 0
	end
	local total = 0
	for _, message in messages do
		if message.Claimed ~= true then
			total += 1
		end
	end
	return total
end

return table.freeze(InboxConfig)
