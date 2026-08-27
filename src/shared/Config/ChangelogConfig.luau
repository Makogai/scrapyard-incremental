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
			Version = "0.5.32",
			Date = "2026-08-27",
			Title = "Event Horizon spins on the ground",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Event Horizon's swirl and glow now spin flat on the magnet reach circle, not as vertical discs stuck to the character.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.31",
			Date = "2026-08-27",
			Title = "Magnet range stays on your plot",
			Changes = table.freeze({
				table.freeze({
					Kind = "Balance" :: ChangeKind,
					Text = "Magnet reach is capped at 16 studs. Quantum, Salvage and Advanced start closer in, and range upgrades add less per level, so a maxed rebirth-6 Quantum no longer pulls from the next plot.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.30",
			Date = "2026-08-27",
			Title = "Ember Core whirlpool",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Ember Core's inner fill is a spinning magma whirl now, not the same swirl discs as Event Horizon.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.29",
			Date = "2026-08-27",
			Title = "Ember Core molten rings",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Ember Core rings are solid molten lines now, and the inner circle is filled with swirling lava.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.28",
			Date = "2026-08-27",
			Title = "Ember Core is a smooth ring",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Ember Core's circles are a continuous waving line now, not a chain of boxes.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.27",
			Date = "2026-08-27",
			Title = "Ember Core is a waving ring",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Ember Core no longer paints a lava plate on the floor. It is a transparent waving ring, with the bubbles and fire still coming out of the circle.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.26",
			Date = "2026-08-27",
			Title = "Ember Core looks like fire",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Ember Core uses molten reds, ember orange and charcoal smoke now, instead of neon gold glow.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.25",
			Date = "2026-08-27",
			Title = "Ember Core is lava",
			Changes = table.freeze({
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Ember Core is a lava pool now -- bubbling magma, hopping fireballs, sparks, and a flowing hot rim -- instead of a few embers drifting up.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.24",
			Date = "2026-08-27",
			Title = "Horizon quiet, Orbital moving",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Event Horizon no longer strobes on the ground -- the void swirl, beams, and rings stay.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Orbital rings now roll and ride up and down, instead of sitting at a fixed height.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.23",
			Date = "2026-08-27",
			Title = "Orbital rings and Event Horizon",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Orbital reach rings are now solid spinning hoops, lifted so the tilted circle no longer clips the ground.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Event Horizon is a real void now -- a dark core, accretion beams, and spinning swirl discs -- instead of a quieter version of the planet rings.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.22",
			Date = "2026-08-26",
			Title = "Magnet skins actually look different",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Each magnet skin now has its own silhouette in your hand -- a real U-magnet, a wrapped chrome coil, a glowing barrel, planet rings, or a black hole -- instead of five similar sticks.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Skin reach effects no longer share one animation. Paint is stacked hoops, Chrome is current around the rim, Ember is fire rising, Orbital is tilted planet rings, and Event Horizon is still the one that swallows motes.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.21",
			Date = "2026-08-26",
			Title = "Magnet skins sit in the hand",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Magnet skins now sit in the palm the way the real magnets do, instead of floating beside the hand.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Skin reach rings lift off the floor a little and pull motes inward, so the circle reads as a volume rather than a sticker.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.20",
			Date = "2026-08-26",
			Title = "Magnet skins",
			Changes = table.freeze({
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Five magnet skins restyle the magnet in your hand and the reach ring around you. They are cosmetics only -- strength and range stay on the magnet you equipped. Grant them from the admin panel while we look at the models; a Robux crate comes later.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.19",
			Date = "2026-08-25",
			Title = "Gear Shop",
			Changes = table.freeze({
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "The Gear Shop is open. Spend Gears on a rebirth head start, a nest-egg cash kit, a bag floor, an extra pet slot, scrap luck, egg fortune, and Secret tickets. Some rows unlock at later rebirths. Gears still do not raise income, and Skip Rebirth stays a Robux product.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.18",
			Date = "2026-08-25",
			Title = "Multi-hatch eggs rattle",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Summoning 3 or 5 eggs now rattles each egg the way a single summon does, instead of leaving a row of tiny still models.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.17",
			Date = "2026-08-25",
			Title = "Triple and penta hatch shake",
			Changes = table.freeze({
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Summoning 3 or 5 eggs now shakes that many eggs on screen, then reveals the pets in a row. Single summons are unchanged.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.16",
			Date = "2026-08-25",
			Title = "Egg pets combine for scrap value",
			Changes = table.freeze({
				table.freeze({
					Kind = "Balance" :: ChangeKind,
					Text = "Egg-pet scrap value now adds toward a shared +100% cap instead of one Secret filling it alone. Equip a few hatchables to reach the ceiling; premium pets still add on top.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.15",
			Date = "2026-08-25",
			Title = "Pet scrap-value labels",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Pet cards now show the scrap-value you actually get. Egg pets share a +100% team cap, so a Secret reads +100% rather than a raw x3.5 that never paid out. Premium pets still add on top of that cap.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.14",
			Date = "2026-08-25",
			Title = "Coin and cash icons",
			Changes = table.freeze({
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Money in the HUD, daily calendar, playtime ladder and spin wheel now uses the pack coin. The Pit shop's two cash crates use the banded bill stack.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.13",
			Date = "2026-08-25",
			Title = "Real egg meshes",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Hold-E at the island podium now opens the egg whose folder you are facing, and the hatch shake uses that egg's real mesh instead of a blank white placeholder.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.12",
			Date = "2026-08-25",
			Title = "Pit wreck shield",
			Changes = table.freeze({
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "The Pit wreck now raises a shield after a chunk of damage. Magnet the glowing OVERLOAD on the floor to drop it -- it then moves, and dropping it bursts extra scrap. Same walk-near-the-glow as collecting scrap; one player can still finish the wreck alone.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.11",
			Date = "2026-08-25",
			Title = "Tougher Pit wreck",
			Changes = table.freeze({
				table.freeze({
					Kind = "Balance" :: ChangeKind,
					Text = "The Pit wreck takes much longer to break, only chips when your magnet can reach it, and bursts apart when it falls. Magnet range is shorter inside the Pit so one player cannot vacuum the whole floor.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.10",
			Date = "2026-08-25",
			Title = "Wreck you can stand on",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "The Pit wreck is solid, a bit smaller, and shows its HP on the HUD above your bag so you do not have to zoom out to find the bar.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.9",
			Date = "2026-08-25",
			Title = "Wreck stays put",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "The Pit wreck now appears when the event starts. The imported RobotWreck mesh was unanchored, so it fell through the world before it could be cloned onto WreckAnchor.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.8",
			Date = "2026-08-25",
			Title = "Find RobotWreck",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "The Pit wreck finds RobotWreck even with a space in the name, and still appears if WreckAnchor is missing by standing where that model already is.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.7",
			Date = "2026-08-25",
			Title = "Robot wreck",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "The Pit wreck is the Workspace RobotWreck model. Pit scrap models live in EventScrap and are not used as the wreck.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.6",
			Date = "2026-08-25",
			Title = "Wreck is Wreck",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "The Pit wreck is only the Workspace Wreck model. It no longer falls back to Submarine or any other Pit scrap.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.5",
			Date = "2026-08-25",
			Title = "Wreck art and chipping",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "The Pit wreck now uses the Workspace Wreck model. It was spawning as a Submarine because that template was found first.",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Standing next to the wreck chips it. A full bag no longer blocks chipping.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.4",
			Date = "2026-08-25",
			Title = "Authored wreck",
			Changes = table.freeze({
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "The Pit wreck is the Workspace Wreck model, spawned on WreckAnchor. It keeps its authored colours and stands as a large landmark.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.3",
			Date = "2026-08-25",
			Title = "Pit shop walk-in",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "The Pit shop opens by walking into Event Shop, the same way as Magnet Shop. There is no HUD shop button -- go to the Pit first.",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Place a part named WreckAnchor under Event Area where the wreck should stand. It no longer floats off the spawn pad.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.2",
			Date = "2026-08-25",
			Title = "Pit shop and wreck",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "The Pit shop is the HUD PIT SHOP button. There is no interaction prompt on the spawn pad.",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "The wreck now stands in front of where you land, larger than the hoard, with a WRECK bar. Stand next to it to chip it.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.1",
			Date = "2026-08-25",
			Title = "Pit shop and scrap",
			Changes = table.freeze({
				table.freeze({
					Kind = "Balance" :: ChangeKind,
					Text = "Pit shop Secret Ticket is 2,500 slag and God Potion is 6,000 slag.",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Pit scrap keeps the colours authored on the model. Drone, Submarine and Lava Core sit smaller on the floor; Robot Arm stays the big piece.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.5.0",
			Date = "2026-08-25",
			Title = "The Pit",
			Changes = table.freeze({
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "The Pit now drops unique scrap: Drone, Submarine, Lava Core, and Robot Arm. Robot Arm needs the strongest magnet. Pickups pay slag, spent at the Pit shop. Stand next to the wreck to chip it into more scrap.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.4.12",
			Date = "2026-08-24",
			Title = "Egg prompts",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "The first egg is now Front Yard Egg, the second Workshop Egg, and the third Vehicle Graveyard Egg. Hold-E reach is larger, and podium signs are rewritten from config.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.4.11",
			Date = "2026-08-24",
			Title = "Pets stay equipped",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Rejoining used to unequip all but one pet. All three starter slots now survive a leave.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.4.10",
			Date = "2026-08-24",
			Title = "Pet follower colours",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Equipped pets keep their real colours (the red wash was a Highlight fill) and hover at the same height instead of following each model's pivot.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.4.9",
			Date = "2026-08-22",
			Title = "Afford hints",
			Changes = table.freeze({
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "The first time you can afford the Workshop Yard or a stronger magnet, a toast points you at the Area Shop or Magnet Shop. Each hint fires once.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.4.8",
			Date = "2026-08-22",
			Title = "Tighter starter magnet",
			Changes = table.freeze({
				table.freeze({
					Kind = "Balance" :: ChangeKind,
					Text = "The Basic Magnet now starts at 5 studs. Range upgrades are +1 stud and $500, then grow at 1.35x, so the old 9-stud start is level 4 and the base cap is 15.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.4.7",
			Date = "2026-08-22",
			Title = "Premium podium models",
			Changes = table.freeze({
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Singularity, Scrap Crimson Knight, and Sinister Lord now use their Featured Podium models. The old Singularity body is Sinister Lord's.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.4.6",
			Date = "2026-08-22",
			Title = "Premium pet ladder",
			Changes = table.freeze({
				table.freeze({
					Kind = "Balance" :: ChangeKind,
					Text = "Sinister Lord is the 999 flagship: ×5 scrap value, +400% magnet strength, walk speed, and a stronger pull. Singularity stays the limited 499 cash pet at ×8 value and +300% strength. Scrap Crimson Knight stays the luck and storage pet.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.4.5",
			Date = "2026-08-22",
			Title = "Scrap Crimson Knight",
			Changes = table.freeze({
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Demonic Ghost is now Scrap Crimson Knight, and uses the Featured Podium model.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.4.4",
			Date = "2026-08-22",
			Title = "Hatchable luck sits under Ghost",
			Changes = table.freeze({
				table.freeze({
					Kind = "Balance" :: ChangeKind,
					Text = "Hatchable pet luck no longer beats Demonic Ghost. Secrets are +12% / +14% / +16% (Junkyard / Workshop / Quantum). Legendaries cap at +10%. Ghost stays +20%.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.4.3",
			Date = "2026-08-22",
			Title = "Pit teleport and pets",
			Changes = table.freeze({
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "ENTER THE PIT lands on the Event Area floor. It was dropping you inside the spawn sculpture, which looked like the button did nothing.",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Workshop and Quantum pets show their models again after the Studio rename (Yin Yang, Fracture, and the rest).",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "A renamed MagnetShop was aborting the whole server start, which is why pets and the Pit button died together.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.4.2",
			Date = "2026-08-22",
			Title = "The Pit uses Event Area",
			Changes = table.freeze({
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "THE PIT now uses the Event Area in the world. Hold ENTER THE PIT while it is on and you land on the Event Area spawn. Duplicate the red Spawn01 pad to add more loot spots.",
				}),
			}),
		}),
		table.freeze({
			Version = "0.4.1",
			Date = "2026-08-21",
			Title = "Scrap Rarity Tuning",
			Changes = table.freeze({
				table.freeze({
					Kind = "Balance" :: ChangeKind,
					Text = "Rarer scrap is more common, and pays less: Rare 5% ×2, Epic 1% ×4, Legendary 0.15% ×8, Nebula 0.025% ×25. Normal scrap is still $45–$1,750.",
				}),
				table.freeze({
					Kind = "Balance" :: ChangeKind,
					Text = "Rebirth cost now grows ×1.55 each time ($2M, then $3.1M, then $4.805M). Each rebirth permanently multiplies scrap value by 1.25 and adds +5% luck.",
				}),
				table.freeze({
					Kind = "Balance" :: ChangeKind,
					Text = "Workshop and Vehicle Graveyard pets have new boosts. Premium pets no longer copy or amplify the team: Singularity is +500% magnet strength, Demonic Ghost is +40% scrap value, Sinister Lord is +200% strength.",
				}),
				table.freeze({
					Kind = "Balance" :: ChangeKind,
					Text = "Upgrade prices start higher and grow simply: each level costs the last one times a growth rate. Magnet Strength is $650 then ×1.30, Rarity Luck is $3,000 then ×1.45. Scrap Flow is now called Spawn Rate.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Buying the Workshop or Vehicle Graveyard now converts your whole plot automatically. There is no hold-E to switch themes, and no way to switch back except a rebirth.",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Cash amounts that end in zero now show the zero: $100K no longer reads as $1K.",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "AUTO SELL now dumps the scrap you are carrying the moment you buy it, and whenever your bag is full. You no longer have to walk to the crusher once first.",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Storage is whole slots. A bar that said 51 while you could only carry 50 was rounding a fraction; the last space now fills.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Scrap that sits uncollected for about 80 seconds despawns and a new random piece takes its place.",
				}),
				table.freeze({
					Kind = "Balance" :: ChangeKind,
					Text = "Movement Speed is +3 per level and maxes near 46 (almost 3x default). The 2x Walk Speed pass now actually doubles that, including after you respawn.",
				}),
				table.freeze({
					Kind = "Balance" :: ChangeKind,
					Text = "Singularity now gives ×20 scrap value, on top of +500% magnet strength. Paid pet cash is no longer flattened to the hatchable +100% cap.",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Hub leaderboards now show player names. Empty Studio stores still list whoever is in the server, instead of ten blank rows.",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Each area egg is now its own hold-E: Front Yard opens Junkyard pets, Vehicle Graveyard opens Quantum pets. Before, only the tallest egg worked and it always showed the starter roster.",
				}),
				table.freeze({
					Kind = "Fix" :: ChangeKind,
					Text = "Equipping Pup no longer puts it upside down or at the wrong size. Followers now face and scale from the pet's face, not its exporter pivot.",
				}),
			}),
		}),
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
					Kind = "New" :: ChangeKind,
					Text = "LAVA SKIN pass: your plot becomes cracked volcanic rock with lava running through it. One purchase covers every area -- the Front Yard, the Workshop and the Vehicle Graveyard each get their own lava build, and rebirthing back to the Front Yard keeps it.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "SKINS tab in your inventory: switch your plot between the standard yard and any skin you own, as often as you like.",
				}),
				table.freeze({
					Kind = "New" :: ChangeKind,
					Text = "Passes you can walk into: step on the 2X MONEY, AUTO SELL or 2X MOVEMENT SPEED pad on your plot to buy it, and the pad goes away once it is yours.",
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
