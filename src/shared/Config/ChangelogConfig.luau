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
