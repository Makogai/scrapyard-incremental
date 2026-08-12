--!strict

return table.freeze({
	--[[
		Rebirth 1 at $2M with x1.75 growth, from the economy pass. See `plan/ECONOMY_REBALANCE.md`.

		THESE TWO MOVE TOGETHER WITH THE REBIRTH BONUS. The cost growth has to outrun the permanent income
		bonus a rebirth grants, or every rebirth is faster than the last and the ladder collapses inward:
		x1.75 against +25% value per rebirth works, x1.75 against a bigger bonus would not.
	]]
	BaseMoneyRequirement = 2000000,
	RequirementGrowth = 1.75,
	--[[
		Permanent, per rebirth, on top of resetting money/areas/upgrades.

		`ValuePerPrestige` is what makes a rebirth worth doing at all; `LuckPerPrestige` is what makes the
		late game feel different rather than just bigger; `UpgradeLevelsPerPrestige` raises the ceiling so
		the same upgrades keep going.
	]]
	ValuePerPrestige = 0.25,
	LuckPerPrestige = 0.05,
	MaximumGearsPerPrestige = 10000,
})

--[[
	THERE IS NO GEARS -> VALUE MULTIPLIER ANY MORE, and this note is here so it does not come back.

	Gears used to raise income directly: `(1 + gears) ^ 0.55`, capped at x1,000,000. Two things were wrong
	with it. It made a rebirth pay TWICE -- once through `ValuePerPrestige` and again through the gear
	curve -- so the two could only ever be tuned against each other. And at `^0.55` the curve was shaped
	for the single-digit gear counts a rebirth actually pays, which meant any other source of gears
	detonated it: the "hold $1,000" achievement handed out 5 gears, worth a permanent x2.67 on all income,
	inside the first minute of play. `Legend` handed out 1,000, worth x45.

	Gears are now purely rebirth currency. They are earned per rebirth, they survive a rebirth, nothing
	else grants them, and they have no passive effect -- they are banked for a spend sink.
	`ValuePerPrestige` is the single payoff for rebirthing, which is the number to tune.
]]
