--!strict

return table.freeze({
	--[[
		Next rebirth costs `BaseMoneyRequirement * RequirementGrowth ^ R`, with R = completed rebirths.
		First rebirth is $2,000,000; the second is $3,100,000; then $4,805,000, and so on.

		THESE TWO MOVE TOGETHER WITH THE REBIRTH BONUS. Value compounds as `1.25 ^ R`. Cost grows as
		`1.55 ^ R`. Time-to-next therefore scales with (1.55/1.25)^R = 1.24^R, so each rebirth is still
		a longer grind than the last. If the bonus ever outruns the cost, the ladder collapses inward.
	]]
	BaseMoneyRequirement = 2000000,
	RequirementGrowth = 1.55,
	--[[
		Permanent, per rebirth, on top of resetting money/areas/upgrades.

		`ValuePerPrestige` is the increment inside `RebirthValueMultiplier = (1 + ValuePerPrestige) ^ R`
		-- each rebirth multiplies scrap value by 1.25, not +0.25 linearly. `LuckPerPrestige` is RAW luck
		added after upgrade/pet luck: `RebirthLuck = R * 0.05`. UpgradeLevelsPerPrestige on each upgrade
		raises the ceiling so the same upgrades keep going.
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
