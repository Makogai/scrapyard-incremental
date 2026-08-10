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
}

return table.freeze(definitions)
