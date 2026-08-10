--!strict
--[[
	TutorialConfig.luau
	The first-session objective chain.

	NOT A TUTORIAL. Complex onboarding backfires on Roblox -- players have no tolerance for
	anything but immediate play, and at least one team raised retention by deleting theirs
	outright. So there are no modal dialogs, no forced camera, and nothing to dismiss. There is a
	caption, an arrow, and a reward.

	Each step is completed by DOING THE THING, and completion is decided server-side from state
	the player cannot fake (`TutorialService` evaluates `Condition` against the live snapshot).
	The client is told which step it is on; it never decides.

	`Target` tells the client what to point the arrow at:
		"scrap"    the nearest piece of scrap on the player's plot
		"crusher"  the plot's CrusherSellZone
		"upgrades" the Upgrade button in the HUD
		nil        no arrow, caption only
]]

export type TutorialStep = {
	Index: number,
	Title: string,
	Detail: string,
	Target: string?,
	Money: number?,
	--- Field on the public snapshot, and the value it must reach.
	Condition: { Field: string, AtLeast: number },
}

local steps: { TutorialStep } = {
	table.freeze({
		Index = 1,
		Title = "GRAB SOME SCRAP",
		Detail = "Walk up to scrap in your yard. Your magnet does the rest.",
		Target = "scrap",
		Money = 250,
		Condition = table.freeze({ Field = "TotalScrapCollected", AtLeast = 5 }),
	}),
	table.freeze({
		Index = 2,
		Title = "SELL IT AT THE CRUSHER",
		Detail = "Stand on the crusher pad to turn scrap into cash.",
		Target = "crusher",
		Money = 500,
		Condition = table.freeze({ Field = "Money", AtLeast = 1 }),
	}),
	table.freeze({
		Index = 3,
		Title = "BUY AN UPGRADE",
		Detail = "Open UPGRADE and spend that cash. Bigger magnet, more scrap.",
		Target = "upgrades",
		Money = 1000,
		Condition = table.freeze({ Field = "TotalUpgradeLevels", AtLeast = 1 }),
	}),
	table.freeze({
		Index = 4,
		Title = "REACH $5,000",
		Detail = "Keep the loop going. Then check the SHOP for a better magnet.",
		Target = nil,
		Money = 2500,
		Condition = table.freeze({ Field = "Money", AtLeast = 5000 }),
	}),
}

return table.freeze({
	Steps = table.freeze(steps),
	--- How often the server re-checks whether the current step is satisfied.
	CheckIntervalSeconds = 1,
	--[[
		Players who already have progress skip the chain entirely. Anyone past this much cash or
		any upgrade at all has clearly played before, and showing them "GRAB SOME SCRAP" would be
		insulting rather than helpful.
	]]
	SkipIfMoneyAbove = 5000,
})
