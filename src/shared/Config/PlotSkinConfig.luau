--!strict
--[[
	PlotSkinConfig.luau
	Cosmetic plot skins: which pass reskins the plot, and which model it wears per area.

	A SKIN IS JUST ANOTHER PLOT VARIANT. `Workspace.PlotSkins` holds one model per area, tagged with an
	`AreaId` attribute exactly like `PlotVariants`, and `PlotThemeService` clones it onto the plot by the
	same `PlotFloor` alignment. That is the whole mechanism -- no separate rendering path, no per-skin code.
	It also means a skin model is only correct if it carries a `PlotFloor` and a `PlayerSpawn`, since those
	are what the rebuild aligns and respawns by.

	ONE PASS, EVERY AREA. `Pass` is bought once and the plot wears the lava build of whatever area you have
	converted to. Selling it per-area would charge three times for one cosmetic idea, and a player who
	rebirths back to the Front Yard would find themselves looking at a plot they had already paid to reskin.

	PURELY COSMETIC. A skin changes no value, no rate, no capacity. Anything that changes those belongs in
	`UpgradeConfig` or a gameplay pass, and keeping that line clean is what lets a skin be priced on looks
	alone.
]]

export type Skin = {
	AreaId: string,
	ModelName: string,
	DisplayName: string,
}

local PlotSkinConfig = {}

--- The single pass that unlocks every model below.
PlotSkinConfig.Pass = "LavaSkin"

--- Drives the offer card's glow. One accent, because it is one skin.
PlotSkinConfig.Accent = "Orange"

--[[
	Keyed by AREA, because that is the question the UI and the rebuild both ask: "which model does this
	plot wear right now?" Entitlement is a separate question, and has one answer for all three.

	`ModelName` is only for the warning when a model is missing from `Workspace.PlotSkins` -- the lookup
	itself goes through the `AreaId` attribute, so renaming a model in Studio does not break it.
]]
PlotSkinConfig.ByArea = table.freeze({
	FrontYard = table.freeze({
		AreaId = "FrontYard",
		ModelName = "Lava Skin - Front Yard",
		DisplayName = "Lava Front Yard",
	}),
	WorkshopYard = table.freeze({
		AreaId = "WorkshopYard",
		ModelName = "Lava Skin - Workshop",
		DisplayName = "Lava Workshop",
	}),
	VehicleGraveyard = table.freeze({
		AreaId = "VehicleGraveyard",
		ModelName = "Lava Skin - Vehicle Graveyard",
		DisplayName = "Lava Vehicle Graveyard",
	}),
})

--- The folder `PlotThemeService` adopts the skin models out of. Mirrors `PlotVariants`.
PlotSkinConfig.Folder = "PlotSkins"

--- The skin model authored for a given plot theme, or nil for an area with no skin built yet.
function PlotSkinConfig.forArea(areaId: string?): Skin?
	if areaId == nil then
		return nil
	end
	return PlotSkinConfig.ByArea[areaId]
end

--- Whether the player owns the skin at all. Independent of where they are standing.
function PlotSkinConfig.owned(entitlements: { [string]: any }?): boolean
	if entitlements == nil then
		return false
	end
	return entitlements[PlotSkinConfig.Pass] == true
end

--[[
	The skin to rebuild this plot from: owned, and authored for this area.

	Both halves matter. Owning the pass does nothing on an area whose lava model has not been built yet,
	and an authored model does nothing for a player who has not bought the pass.
]]
function PlotSkinConfig.activeSkinFor(areaId: string?, entitlements: { [string]: any }?): Skin?
	if not PlotSkinConfig.owned(entitlements) then
		return nil
	end
	return PlotSkinConfig.forArea(areaId)
end

return table.freeze(PlotSkinConfig)
