--!strict
--[[
	ChangelogConfig.luau
	What the UPDATES window shows.

	Newest first -- the window renders this list in order and does not sort, so the
	order here is the order players see. `Tag` colours the version pill:

		New      a feature
		Fix      a bug fix
		Balance  an economy or tuning change

	Add an entry when you ship, not when you start. The window's "NEW" pip keys off
	`Version` of the first entry, so a placeholder at the top marks the whole game
	as updated.
]]

export type ChangeKind = "New" | "Fix" | "Balance"

export type ChangeEntry = {
	Version: string,
	Date: string,
	Title: string,
	Changes: { { Kind: ChangeKind, Text: string } },
}

return table.freeze({
	Entries = table.freeze({
		--[[
			NEWEST FIRST. The unread flag on the UPDATES button keys off this first entry's `Version` -- see
			`TopbarController` -- so adding an entry here is the only step needed to make the button announce
			that the build changed. There is no second list to keep in step.
		]]
		table.freeze({
			Version = "0.4.0",
			Date = "2026-08-12",
			Title = "Economy Rebalance",
			Changes = table.freeze({
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "INBOX, top right. Everything the team sends you now arrives as mail you claim, showing who sent it and a verified tick so you know it is really staff.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Rewards for liking the game, joining the group, and for every friend playing alongside you. Buttons on the right of the screen.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "2X WALK SPEED pass: permanent, and it stacks with your speed upgrade.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "The Singularity pet is now limited to 500 across the whole game. Once they are gone, they are gone.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Pulling a Secret pet now sets off a burst of light everyone on the server can see.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Staff can broadcast a message to the server and start a visible restart countdown, so a restart no longer looks like a crash.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "The egg on the summon podium is a hologram now: see-through, rim-lit, a shaft of light rising through it and floating gently in place.",
				}),
				table.freeze({
					Kind = "Balance" :: ChangeKind,
					Text = "Everything is worth more and costs more. Scrap sells for $45 up to $1,750, the Workshop costs $75,000, the Vehicle Graveyard $450,000, and your first rebirth $2,000,000. A first run should take about an hour instead of a couple of minutes.",
				}),
				table.freeze({
					Kind = "Balance" :: ChangeKind,
					Text = "Storage counts PIECES now, not weight. 25 to start, and a scrap car takes exactly as much room as a bolt -- finding something rare is no longer a punishment.",
				}),
				table.freeze({
					Kind = "Balance" :: ChangeKind,
					Text = "GEARS ARE REBIRTH CURRENCY ONLY. They no longer multiply your income, and nothing but a rebirth grants them. Holding $1,000 used to quietly hand you a permanent x2.67 on every sale.",
				}),
				table.freeze({
					Kind = "Balance" :: ChangeKind,
					Text = "Rebirth now pays exactly one thing: +25% scrap value, every time, forever. It also grants +5% luck and +2 upgrade levels. Area unlocks reset and their prices rise 45% per rebirth.",
				}),
				table.freeze({
					Kind = "Balance" :: ChangeKind,
					Text = "Playtime rewards pay far less cash and far more potions. Potions are shorter and weaker, there is a new Spawn Potion that speeds respawns, and time only counts while you are actually playing.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "SALVAGE MAGNET: the strongest magnet scrap cash can buy, $3,000,000, unlocked once you have reached the Vehicle Graveyard. Magnets survive rebirth.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Every upgrade now has a Robux option: +1 level instantly, without the scrap cash.",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "BUY x5 and MAX now really buy that many upgrade levels. They were being cut short after about twelve, and fewer if you had clicked anything recently.",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Owning two of the same pet and equipping one left the second copy offering only UNEQUIP. Both copies now behave, and you can equip and unequip at the same time.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Pet cards are tinted by rarity, and your pets turn slowly in their cards instead of standing still.",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Rebirthing now puts your plot back to the Front Yard. It used to take the area unlocks away but leave the old yard standing, so you kept a Vehicle Graveyard you no longer owned.",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "The storage bar's EST. VALUE was a flat guess of $19 a piece and was wrong for every load. It now shows what the crusher will actually pay you.",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "A brand-new profile was instantly awarded $1,500,000, 305 gears and two titles it had not earned, because the scrap index counted every scrap as already discovered.",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Scrap you cannot pick up now flashes and shakes -- red if your magnet is too weak, amber if your storage is full -- so you can see which piece is the problem.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.3.0",
			Date = "2026-08-09",
			Title = "New Interface",
			Changes = table.freeze({
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "The whole interface was rebuilt: faster windows, cleaner cards, and animation on every button.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Travel row at the top of the screen jumps you to the Shop, the Leaderboard or your plot.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "This Updates window, so you can see what changed.",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "The SELL button now works from anywhere -- it walks you to your crusher.",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Cash, rebirths and gears no longer overlap the Roblox menu on small screens.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.2.0",
			Date = "2026-07-26",
			Title = "Pets & Eggs",
			Changes = table.freeze({
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Hatch eggs for pets that boost your collection. Equip more with pet slot upgrades.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Scrap Index tracks every scrap type you have discovered.",
				}),
				table.freeze({
					Kind = "Balance" :: ChangeKind,
					Text = "Rebirth requirement lowered for the first three rebirths.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.1.0",
			Date = "2026-07-12",
			Title = "Scrapyard Opens",
			Changes = table.freeze({
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Collect scrap, sell it at the crusher, and upgrade your magnet.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Three areas to unlock, each with rarer scrap than the last.",
				}),
			}),
		}),
	}),
})
