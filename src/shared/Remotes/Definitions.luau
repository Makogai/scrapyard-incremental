--!strict

export type RemoteKind = "RemoteEvent" | "RemoteFunction"
export type Definition = {
	Name: string,
	Kind: RemoteKind,
}

local function definition(name: string, kind: RemoteKind): Definition
	return table.freeze({ Name = name, Kind = kind })
end

local definitions: { Definition } = {
	definition("RequestInitialState", "RemoteFunction"),
	definition("StateChanged", "RemoteEvent"),
	definition("Notify", "RemoteEvent"),
	definition("GameplayEffect", "RemoteEvent"),
	definition("RequestUpgrade", "RemoteEvent"),
	definition("RequestAreaUnlock", "RemoteEvent"),
	definition("RequestPrestige", "RemoteEvent"),
	definition("UpdateSettings", "RemoteEvent"),
	definition("AdminCommand", "RemoteEvent"),
	definition("InventoryAction", "RemoteEvent"),
	definition("RedeemCode", "RemoteEvent"),
	definition("CodeResult", "RemoteEvent"),
	definition("OpenMagnetShop", "RemoteEvent"),
	definition("OpenAreaShop", "RemoteEvent"),
	definition("OpenExclusiveShop", "RemoteEvent"),
	definition("RequestTeleport", "RemoteEvent"),
	definition("ShopAction", "RemoteEvent"),
	definition("MonetizationPrompt", "RemoteEvent"),
	definition("MonetizationResult", "RemoteEvent"),
	definition("PetAction", "RemoteEvent"),
	definition("PetResult", "RemoteEvent"),
	definition("OpenPetShop", "RemoteEvent"),
	--[[
		Server -> every client. A broadcast for the handful of moments the whole
		server should see: a Secret pet hatching, for now. `Notify` stays the
		per-player channel for anything routine.
	]]
	definition("Announce", "RemoteEvent"),
	--[[
		Server -> one client: a cross-server chat line, already filtered FOR THAT PLAYER.

		One fire per recipient rather than a broadcast, and that is the whole point: the same words are
		allowed between two adults and blocked for a child, so `GlobalChatService` filters the text once
		per person and each client gets their own version. A `FireAllClients` here would mean one filtered
		result standing in for everybody, which is exactly what the filter exists to prevent.

		Also carries the server's own refusals -- a cooldown, a busy topic -- as a `System` string, so the
		player finds out why their message did not appear.
	]]
	definition("GlobalChat", "RemoteEvent"),
	--- Server -> one client: the egg podium was used, open the summon window.
	definition("OpenEggSummon", "RemoteEvent"),

	--[[
		Return-to-play systems. Client -> server carries an INTENT AND NOTHING ELSE: no day index,
		no reward id, no amount. The server reads what is claimable out of saved data, which is why
		`claimDaily` no longer takes the day the client thought it was on.
	]]
	definition("ClaimDailyReward", "RemoteEvent"),
	definition("ClaimPlaytimeReward", "RemoteEvent"),
	definition("RequestSpin", "RemoteEvent"),
	--[[
		Server -> one client: which wheel segment was won and its index, so the wheel can be
		animated to land there. Structured, so it gets its own remote rather than riding `Notify`,
		which is a plain string by contract (AGENTS.md rule 13).
	]]
	definition("SpinResult", "RemoteEvent"),
	--- Client -> server: "Skip" only. Steps are advanced by the server from state.
	definition("TutorialAction", "RemoteEvent"),
	--[[
		Client -> server: wear a title, or "" for none. Carries a title ID and nothing else -- the
		server checks the player actually holds it, because a client that could name any title could
		wear the one nobody has earned.
	]]
	definition("EquipTitle", "RemoteEvent"),

	--[[
		THE MAILBOX. Client -> server carries an intent and a message id, never a reward: what a message
		pays is read from saved data, so a client cannot name its own prize. See `InboxService`.

		There is no server -> client counterpart. The mailbox rides the normal state snapshot, which means
		it arrives with everything else and cannot be shown out of step with the money it paid.
	]]
	definition("InboxAction", "RemoteEvent"),

	--[[
		Server -> every client: a staff message, with the sender's name and whether to draw the verified
		tick. Separate from `Announce` because that one is for gameplay moments and this one is a person
		talking -- and separate from `Notify`, which is a plain string by contract (AGENTS.md rule 13).
	]]
	definition("AdminBroadcast", "RemoteEvent"),

	--[[
		Server -> clients: the restart countdown, as an ABSOLUTE `EndsAt` rather than seconds remaining, so
		every client ticks its own clock and no two players see different numbers. A nil `EndsAt` is a
		cancel.
	]]
	definition("ServerRestart", "RemoteEvent"),

	--- Client -> server: claim a like/group reward, or the next friend milestone. Intent only.
	definition("SocialAction", "RemoteEvent"),
}

return table.freeze(definitions)
