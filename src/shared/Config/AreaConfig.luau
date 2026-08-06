--!strict

local GameTypes = require(script.Parent.Parent.Types.GameTypes)

local function area(definition: GameTypes.AreaDefinition): GameTypes.AreaDefinition
	table.freeze(definition.ScrapIds)
	return table.freeze(definition)
end

local byId: { [GameTypes.AreaId]: GameTypes.AreaDefinition } = {
	FrontYard = area({
		Id = "FrontYard",
		DisplayName = "Front Yard",
		Order = 1,
		UnlockPrice = 0,
		ScrapIds = { "MetalCan", "LooseBolt", "SmallMetalPlate", "Tire" },
	}),
	WorkshopYard = area({
		Id = "WorkshopYard",
		DisplayName = "Workshop Yard",
		Order = 2,
		UnlockPrice = 6500,
		ScrapIds = { "Tire", "BrokenAppliance", "EnginePart", "CarDoor" },
		GateModelName = "WorkshopGate",
	}),
	VehicleGraveyard = area({
		Id = "VehicleGraveyard",
		DisplayName = "Vehicle Graveyard",
		Order = 3,
		UnlockPrice = 90000,
		ScrapIds = { "EnginePart", "CarDoor", "ScrapCar" },
		GateModelName = "VehicleGate",
	}),
}

return table.freeze({
	ById = table.freeze(byId),
	Order = table.freeze({ "FrontYard", "WorkshopYard", "VehicleGraveyard" }),
})
