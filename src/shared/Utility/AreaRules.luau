--!strict

local AreaRules = {}

function AreaRules.canUnlock(
	alreadyUnlocked: boolean,
	previousUnlocked: boolean,
	money: number,
	price: number
): (boolean, string)
	if alreadyUnlocked then
		return false, "Area already unlocked"
	end
	if not previousUnlocked then
		return false, "Unlock the previous area first"
	end
	if money ~= money or price ~= price or money < 0 or price < 0 or money < price then
		return false, "Not enough Scrap Cash"
	end
	return true, "Unlocked"
end

return table.freeze(AreaRules)
