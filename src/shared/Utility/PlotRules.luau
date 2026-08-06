--!strict

local PlotRules = {}

function PlotRules.isOwner(
	ownerUserId: number,
	playerUserId: number,
	assignedPlotId: string?,
	targetPlotId: string?
): boolean
	return ownerUserId > 0
		and ownerUserId == playerUserId
		and assignedPlotId ~= nil
		and assignedPlotId == targetPlotId
end

return table.freeze(PlotRules)
