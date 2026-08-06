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
	definition("ShopAction", "RemoteEvent"),
	definition("MonetizationPrompt", "RemoteEvent"),
	definition("MonetizationResult", "RemoteEvent"),
}

return table.freeze(definitions)
