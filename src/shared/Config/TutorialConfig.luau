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

	`Target` says what to point at, and there are two kinds:

		WORLD targets get a 3D arrow floating above them, built from parts by
		`TutorialArrowController`:
			"yard"     the middle of the player's own scrap field -- NOT one piece of scrap. An arrow
			           stuck to a single collectable is wrong twice over: it vanishes the moment the
			           piece is collected, and it teaches "go to that one thing" when the lesson is
			           "walk around your yard".
			"crusher"  the plot's CrusherSellZone

		SCREEN targets darken the HUD and leave one control lit:
			"upgrades" the UPGRADE tile in the menu grid

		nil        caption only, no pointer
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
		Detail = "Walk around your yard. Your magnet picks up scrap on its own.",
		Target = "yard",
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
		Detail = "Tap UPGRADE and spend that cash. A bigger magnet grabs heavier scrap.",
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
