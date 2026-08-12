--!strict

local AreaRules = {}

--[[
	WHAT AN AREA COSTS THIS PLAYER, RIGHT NOW.

	Area unlocks reset on rebirth, so without rising prices a player who has done ten rebirths buys the
	Graveyard back for the same $450,000 they paid on their first run -- when they now earn that in a
	minute. Every area past the first would be a formality, and two thirds of the game would be scenery
	you walk through on the way to the third one.

	`1.45 ^ rebirths` is chosen to sit BELOW income growth, not match it: prices rise, but re-unlocking
	still gets easier in real terms, so a rebirth feels like progress rather than like being sent back to
	the start. Rebirth 5 pays $2.88M for a Graveyard that cost $450K on run one.

	A FUNCTION, not a number baked into the config, because four separate places ask this question -- the
	server's unlock check, the server's charge, the React store, and the retired authored UI. A per-rebirth
	price computed independently in four places is a bug waiting for the fifth caller.
]]
local PRICE_GROWTH_PER_REBIRTH = 1.45

function AreaRules.unlockPrice(basePrice: number, prestigeCount: number): number
	if basePrice ~= basePrice or basePrice < 0 then
		return 0
	end
	local rebirths = math.max(0, math.floor(prestigeCount or 0))
	return math.floor(basePrice * PRICE_GROWTH_PER_REBIRTH ^ rebirths)
end

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
