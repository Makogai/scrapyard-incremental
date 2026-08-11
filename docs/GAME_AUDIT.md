# Scrapyard Incremental — audit and growth plan

An honest read of the whole game against what the genre actually requires, and a prioritised
plan for retention, monetisation and depth.

Everything in "what we have" was read out of the code or measured in Studio, not assumed. Where
I am estimating rather than measuring, it says so.

---

> **STATUS — updated after the first build pass.** Four of the retention systems in section 5 are
> now built, wired and Play-verified: **daily rewards with a streak, playtime milestones, the daily
> spin wheel, the friend boost, and the first-session objective chain.** Section 3.2 and 3.5 are
> closed. Monetisation (3.1) is deliberately untouched and is documented separately in
> **`docs/STORE_SETUP.md`** — the fifteen Marketplace assets to create and where each id goes.
> The remaining open items are 3.3 (the fake event banner), 3.4 (no trading), 3.6 and 3.7.

> **STATUS — second pass, presentation and admin.** The wheel was rebuilt for depth and legibility:
> a three-ring bevelled rim, radially shaded wedges, alternating tone so two same-accent prizes cannot
> merge into one slice, icons sized from the wedge chord so they can never cross a seam, a dark hub, a
> chunky pin pointer that kicks while the wheel turns, and an ODDS panel built from the same `Weight`
> values the server draws from. Prize art now comes from each item's own `IconId`, so four different
> potions stop being four identical green flasks — on the wheel, the calendar and the playtime grid
> alike. Spin packs (1 and 3 spins) sit beside the wheel through the new `RobuxPrice` component, which
> is now the single place a Robux price is drawn.
>
> Also fixed: Roblox's Backpack row kept coming back because the splash restored
> `CoreGuiType.All` after the UI had disabled it; the reward banner dropped its icon and text for
> every non-jackpot prize (mid-array `nil`, AGENTS rule 17) and the same hole would have cost
> non-admins most of the desktop HUD; the daily modal's dead band and the hero card's empty lower half
> (`Rows.RewardCard` now lays out from its own height); locked playtime cards read as *more* prominent
> than live ones because `Gradient.Dead` is lighter than `Gradient.Slot`.
>
> Admin can now grant **spins, a daily-streak position and rebirths** — anything a player holds a
> count of — and the panel is wide enough for its own tab strip, which ACTIONS used to hang off.

## The headline

**The game is mechanically further along than it is commercially.** There are 22 server services,
19 screens, 17 scrap types, 21 pets, 8 upgrades, 3 plot themes, a rebirth system, an index, three
leaderboards and a codes system. That is a real game.

But:

- **Every one of the 16 monetisation entries has `MarketplaceId = 0`.** Revenue is currently
  impossible. Not underperforming — impossible.
- ~~**Nothing brings a player back tomorrow.**~~ **FIXED.** Daily rewards, playtime milestones, a
  daily spin wheel and the friend boost are all live, with the objective chain teaching the loop on
  the first session. Quests and a real event system are still outstanding.
- **The HUD advertises an event that does not exist.** `EventBanner` is rendered with no props, so
  every player permanently sees "SCRAP RUSH EVENT — 3x scrap value in every area" with a countdown.
  It is hardcoded placeholder text.
- **There is no social layer at all.** No trading, no guilds, no parties, no co-op. The research is
  blunt about this: social systems are worth **3–5× on retention**.

Those four are the whole story. Fixing them does not require new gameplay — it requires wiring what
is already built and adding the two or three systems the genre treats as table stakes.

---

## 1. What the game is today

### The core loop

Walk near scrap → magnet collects it into storage → walk to the crusher and stand on it → sell →
buy upgrades → repeat → rebirth for gears → repeat.

Base storage is 20 and scrap weights run 0.5–4, so a new player carries roughly **5–10 pieces per
trip** before having to walk to the crusher. That trip is the game's heartbeat. Genre guidance puts
a healthy simulator core loop at **15–20 seconds**; ours has never been measured, and it should be.

### Systems inventory

| System | State |
| --- | --- |
| Scrap collection, 17 types, 5 rarity variants | shipped |
| 8 upgrades (strength, range, storage, speed, value, collect speed, flow, luck) | shipped |
| 3 plot themes with hold-E conversion, persisted | shipped |
| Rebirth / prestige with gears | shipped |
| 21 pets across 6 rarities, eggs, hatching | shipped |
| Scrap index / discovery | shipped |
| 3 leaderboards (Robux, rebirths, playtime) + richest-player pedestal | shipped |
| Redeem codes | shipped |
| Consumable potions (cash, strength, luck, god) | shipped |
| 3 magnets | shipped, but two share one model and two have no icon |
| **Monetisation** | **built, entirely unwired** |
| Daily rewards, 7-day calendar with a forgiving streak | **shipped** |
| Playtime milestones, 5 per day | **shipped** |
| Daily spin wheel, server-decided | **shipped** |
| Friend boost, +10% money per friend in-server | **shipped** |
| First-session objective chain (4 steps, server-verified) | **shipped** |
| **Timed events** | **fake banner only** |
| Repeatable daily quests | do not exist (the objective chain is one-off) |
| Onboarding / first-session direction | **shipped** — caption + world arrow, no modal |
| Trading | does not exist |
| Guilds / parties / co-op | does not exist |


---

## 2. The benchmarks we are aiming at

From BLOXG's 2026 data across 850+ promoted games, and Roblox's own retention guidance:

| Metric | Simulator average | Good | Great | Excellent |
| --- | --- | --- | --- | --- |
| D1 retention | **32%** | 20% | 30% | 40%+ |
| D7 retention | **14%** | 8% | 15% | 20%+ |
| D30 retention | **6.2%** | — | — | — |

Monetisation:

| Metric | Benchmark |
| --- | --- |
| Paying conversion | 1–3% typical, 2–5% for tycoon-likes. **Below 1% means the offer is wrong, not the players** |
| ARPPU | 100–300 Robux for tycoon-likes |
| Developer share | 70% after Roblox's 30% cut |
| Contextual prompts vs passive store listing | **3–5× better conversion** |

Two platform facts worth designing around:

- **Roblox has no native discount or limited-time pricing.** You cannot put a game pass on sale. Any
  "limited offer" has to be built as a *different SKU* or as a time-gated dev product.
- **Roblox players do not respond to coercion.** They buy things they want; they do not buy their way
  out of deliberately broken design. Slowing progress to force purchases reliably costs more
  retention than it earns revenue.

---

## 3. Weaknesses, ranked by what they cost

### 3.1 Monetisation is switched off — `MarketplaceId = 0` on all 16 entries

There are 8 game passes and 7+ dev products defined, priced, described and rendered in a shop that
has been through two design passes. Every button reads COMING SOON because no Marketplace asset is
attached.

This is a half-day of clicking in the Creator Dashboard and it is worth more than any feature on
this page. **Nothing else in this document matters until this is done.**

Second-order problem: the catalogue is built almost entirely of **permanent passes**. Passes earn on
*conversion* — the one-time share of players who buy. Dev products earn on *repeat frequency*. A
catalogue weighted toward passes has a hard revenue ceiling per player: once a whale owns all eight,
they cannot spend again. The cash packs and booster bundles are the repeatable half and they are the
ones to build out.

### 3.2 There is no reason to return tomorrow — FIXED

Was the single largest retention gap. Three holes, all now closed:

| Was | Now |
| --- | --- |
| Daily rewards screen existed; `claimDaily` was `function self.claimDaily() end` | `DailyRewardService`, 7-day looping calendar, streak with a cash bonus, one missed day forgiven |
| Playtime accumulated only to rank a leaderboard | `PlaytimeRewardService`, 5 milestones from 5 min to 2 hr, resetting daily |
| Nothing to collect between sessions | `SpinService`, weighted wheel, one free spin a day |
| Nothing social at all | `FriendBoostService`, +10% money per friend in the server |

**The streak is the mechanic, not the reward.** A reward for logging in is pleasant; a streak you
lose by not logging in is a reason to log in. It is deliberately forgiving — `StreakGraceDays = 1`,
so one missed evening does not wipe a 30-day streak. Punishing that hard makes players stop
returning rather than return harder.

Worth keeping the honest counter-example in mind: one Roblox devforum developer added daily rewards
and saw **no retention change at all**. Daily rewards alone are not a strategy — they are one layer
of four, and the other three (a visible long-term goal, a social hook, a live-events cadence) still
need work. Repeatable daily *quests* are still outstanding.

**Design notes worth keeping:**

- Every claim is an **intent with no arguments**. `claimDaily` used to be called as
  `actions.claimDaily(currentDay)` — the client telling the server which day to pay out, which is
  exactly the value a server must never accept. The server reads the claimable day from saved data.
- Days are stored as **day numbers** (`os.time() // 86400`), never timestamps. `now - last >= 86400`
  lets a player claim at 23:59 and again at 00:01; integer day comparison cannot. `DayClock` holds
  that logic and the test suite covers all five streak cases.
- The spin wheel's **server picks and grants before the animation starts**. The client is sent an
  index and turns the reel to it. A client that spins and reports where it landed lands on the
  jackpot every time.

### 3.3 The HUD lies to every player

`EventBanner` is rendered from `Desktop.luau` and `Mobile.luau` with **no data props**, so it falls
back to its own hardcoded defaults: "SCRAP RUSH EVENT", "3x scrap value in every area", and a
countdown that means nothing. It is always on screen and always says the same thing.

This is worse than a missing feature. A permanent banner promising a 3× multiplier that is not
active teaches players to ignore the HUD, and the first time you ship a *real* event they will not
notice it. Either wire it or hide it — do not ship it as decoration.

### 3.4 No social layer, in a genre where social is the retention multiplier

Social systems are reported to improve retention by **3–5×**, and the games that reach 12-month
sustainability are the ones where players stay connected to *each other*, not just to the game.

We have exactly one social surface: leaderboards, plus the richest-player pedestal. Both are
one-way — you can look at other players, you cannot interact with them.

Pet Simulator 99 is the reference case here and its lesson is specific: **because everything is
tradable, players built an economy around it.** The trading layer, not the hatching loop, is what
produced a secondary market, a social hierarchy, and 2.3 billion visits. The ultra-rare tiers
(HUGE, TITANIC, GARGANTUAN) work as *status symbols* — they are valuable because other players can
see and want them.

We already have the raw material: 5 scrap rarity variants, 21 pets across 6 rarities, an index that
tracks what you have found, and a Nebula tier that announces itself server-wide. None of it can
change hands.

The four-layer model the research keeps returning to:

1. a tight core loop (15–20s) — **we have this**
2. a visible long-term goal — **partially; rebirth exists but is not surfaced as a goal**
3. a social or trading hook — **missing entirely**
4. a live-events cadence — **missing entirely**

We have one and a half of four.

### 3.5 The first 60 seconds has no direction — FIXED

**Now shipped**, and deliberately not as a tutorial.

Four objectives — collect scrap → sell at the crusher → buy an upgrade → reach $5,000 — each paying
cash. A HUD caption says what to do and a bouncing world-space arrow says where. Nothing blocks
play, there is nothing to dismiss, and there is a SKIP.

**Completion is evaluated server-side from state the client cannot fake.** Each step names a
snapshot field and a threshold; `TutorialService` polls them. That means no other service had to
call into it, and any route to the same outcome counts.

Players with progress are opted out on join — showing "GRAB SOME SCRAP" to someone with a rebirth is
worse than showing nothing.

The original problem, for the record:

The nuance here matters, because the obvious fix is wrong. Complex tutorials **backfire** on Roblox
— players have no tolerance for anything but immediate fun, and at least one team found that
*removing* the tutorial entirely and letting existing players guide new ones raised retention.

So the answer is not a tutorial. It is a **first-session objective chain** — three or four goals
that are indistinguishable from playing: *collect 10 scrap → sell at the crusher → buy any upgrade →
reach $1,000*. Each one pays out. It teaches the loop by making the player do it, and it doubles as
the quest system from 3.2.

### 3.6 Progression has visible holes

Measured from the configs:

- **The magnet ladder skips its own middle.** Basic is strength 4, the next purchasable is 12 at
  60,000 cash. CopperWire (5), Tire (6), ToolBox (9) and BrokenAppliance (10) all sit inside that
  gap with nothing to buy. Detailed in `docs/MAGNETS.md`.
- **No magnet reaches the top of the scrap ladder.** Scrap requires up to 45 strength (ScrapCar);
  the best magnet in the game is 25, and it is the premium one. The gap is only closable by stacking
  upgrades, pets and potions — which is defensible, but it means the two most valuable scrap types
  are invisible to most players.
- **Rebirth is a wall, not a goal.** `BaseMoneyRequirement` 350,000 with 2.25× growth. There is a
  screen for it, but nothing in the HUD builds anticipation toward it. Anticipation before a rebirth
  is one of the emotional beats the genre is built on, and we are not playing it.

### 3.7 No content cadence, and no vehicle for one

Successful simulators ship **every 1–2 weeks**, with a monthly or seasonal event that adds
collectibles without resetting progress. Pet Simulator 99 updates every Saturday at 5pm GMT — the
predictability is the point.

We have no event system, so there is no vehicle for a cadence even if the content existed. The
closest thing is the codes system, which is a good start and already built.

### 3.8 Production health affects all of the above

Worth stating plainly, because it caps how fast the cadence in 3.7 can run:

- Three separate bugs this month came from the same root cause — services holding references to plot
  children that `PlotThemeService.Rebuild` replaces. Now guarded by `PlotService.OnGeometryReplaced`
  and documented, but `Rebuild` runs on **every join**, which makes it a far hotter path than
  "convert your plot" implies. Consider making it a no-op when the theme already matches.
- **Seven generic scrap models resolve at absurd sizes** (ToolBox at 1739 studs, BrokenAppliance
  1130, CarDoor 1125, CopperWire 966, Radiator 745, BrakeDisc 414, Tire 11). They are clamped at
  runtime now, so every spawn pays for a re-scale and a re-ground. Source art wants fixing.
- Green static gates plus Edit-mode rendering repeatedly passed on broken visuals this month. Only
  Play-mode measurement caught them. Keep that habit.

**What is good:** 99 tests pass, selene and stylua are clean, every UI component has a story in
`src/stories`, and the docs are genuinely current. That is a better foundation than most games at
this stage and it is what makes a 1–2 week cadence realistic.

---

## 4. What is strong — do not break these

- **The plot theme system.** Converting your whole yard into a different area, visible from outside
  the fence, with six players walking past each other, is a genuinely good envy loop and it is not
  a common mechanic. This is the most differentiated thing in the game.
- **Scrap rarity variants with authored per-rarity art.** Not tinted fallbacks — real models with
  their own colours and emitters. That is expensive to do and it shows.
- **The index.** Discovery tracking is already the backbone of a completion goal.
- **The UI.** Chunky, consistent, tokenised through one theme file, with a story per component. It
  reads as a real product.
- **The Nebula server-wide announcement.** The right instinct: make a rare event everyone sees.

---

## 5. Retention plan

### D1 — get them to come back once

| Priority | Action | Why |
| --- | --- | --- |
| 1 | **First-session objective chain.** 3–4 goals disguised as play: collect 10 scrap → sell → buy an upgrade → reach $1,000. Each pays cash | Fixes 3.5 without a tutorial. Doubles as the quest scaffold |
| 2 | **Wire daily rewards with a visible streak.** Day 1–7 calendar, escalating, streak counter on the HUD | Screen and action already exist; needs a service and a schema field |
| 3 | **A "come back in 4 hours" reward.** One offline-ish timer with a chest | Cheap second return trigger inside day one |
| 4 | **Surface the next unlock permanently.** A HUD strip reading "next: Workshop Yard — $12,500" | Turns an implicit goal explicit. Costs one label |

### D7 — build a habit

| Priority | Action | Why |
| --- | --- | --- |
| 1 | **Daily quests.** 3 rotating: sell N scrap, discover a new type, hatch an egg | The single most-cited D7 mechanic |
| 2 | **Real timed events, and delete the fake banner.** Weekend 2–3× scrap value, wired to the existing banner | Fixes 3.3 and creates the cadence vehicle from 3.7. Weekend multiplier windows are what let F2P players keep pace |
| 3 | **Rebirth anticipation.** Progress bar toward the next rebirth in the HUD, with a preview of what it grants | Rebirth is the long-term goal and it is currently invisible |
| 4 | **Weekly leaderboard resets** alongside the all-time boards | Gives non-whales a board they can actually win |

### D30 — give them a reason to still be here

| Priority | Action | Why |
| --- | --- | --- |
| 1 | **Trading.** Scrap variants and pets, with a trade plaza | The 3–5× lever. This is the highest-ceiling item in this document |
| 2 | **Status-tier collectibles.** One tier above Nebula, extremely rare, visible to others, never sold for Robux | PS99's HUGE tier is the model. Status only works if it cannot be bought |
| 3 | **Index completion rewards.** The `CollectorsMagnet` in `docs/MAGNETS.md` is the shape | Converts the index from a list into a goal |
| 4 | **Seasonal event with exclusive cosmetics** on a monthly beat | Adds collectibles without resetting progress |
| 5 | **Guilds / crews** with a shared goal | The "connected to each other" layer |

---

## 6. Monetisation plan

### Immediately

1. **Create the Marketplace assets and fill in all 16 `MarketplaceId` values.** Nothing else counts.
2. **Fix the two lies in the catalogue.** `QuantumMagnet` advertises "25 strength, 32 range" and has
   22. `QuantumMagnet`'s model is `AdvancedMagnet` with a different material — a 399 R$ item that is
   a recolour of a 60,000-cash item.
3. **Add the two missing magnet icons.** Two of three magnets have no icon.

### Then — shift weight from passes to repeatables

The catalogue is pass-heavy, which caps lifetime spend per player. Build out the repeatable side:

- **Cash packs** already exist (25k / 150k / 750k) — keep and extend
- **Booster bundles** already exist — these are the best-shaped SKU in the catalogue
- **Egg / hatch multipliers** as dev products, sold *at the hatch screen*
- **Rebirth skip** exists; price it against the actual grind length

### Contextual offers — the 3–5× lever

Contextual prompts convert **3–5× better than passive store listings**. We currently have a shop
you have to choose to open, and nothing else.

Places to offer something at the exact moment it is wanted:

| Moment | Offer |
| --- | --- |
| Storage full for the third time in a session | Storage pass |
| Magnet too weak for a piece of scrap the player is standing on | The next magnet |
| Player is 10% short of a rebirth | Cash pack |
| Player just failed to afford an area unlock | Cash pack |
| Egg hatch produced a duplicate | Luck potion |

**One rule:** these must be offers, not walls. Roblox players buy what they want and refuse to buy
their way out of broken design. A prompt that appears once, is dismissible, and does not repeat is
an offer. One that blocks play is a wall, and it will cost more retention than it earns.

### Cosmetics — the underused half

Right now everything for sale is power. Cosmetics are the only category that monetises players who
already own everything, and they carry zero balance risk:

- Magnet skins (`MagnetSkinPack` in `docs/MAGNETS.md`) — reuses every model already made
- Plot theme skins beyond the three functional ones
- Trails, name tags, pedestal effects for the richest-player statue

### What not to do

- Do not gate the loop behind purchases
- Do not build fake scarcity — Roblox has no native discounts, so "50% OFF" on a pass is a lie the
  platform will not back up
- Do not sell the top status tier for Robux; that is what makes it status

---

## 7. Game depth plan

Beyond retention plumbing, the things that make the game itself better:

- **Make the theme change what spawns, not just how it looks.** Half-done already: scrap now follows
  the plot's theme rather than the marker. The next step is making themes *economically* different —
  a Vehicle Graveyard yielding higher-value, higher-strength scrap makes converting a real decision
  instead of a skin. This is where the depth is, and it is cheap because the plumbing exists.
- **A second verb.** The loop is one verb: walk near things. The crusher is a place you stand. A
  second interaction — a sorting minigame, a repair bench that upgrades scrap a tier, a compactor
  that trades quantity for value — is the difference between "run around and click" and a game.
  The genre's most-cited criticism is exactly this.
- **Fill the magnet ladder** (`docs/MAGNETS.md`): `ScrapHook` at 7 and `WorkshopCoil` at 10 fix the
  worst gap in the progression.
- **The pull tether.** A `Beam` from magnet to scrap during collection. One effect, every magnet,
  and it makes the core loop *legible* — currently collection just happens.
- **Storage-full on the magnet itself.** The magnet is the object players stare at all session.
  Putting the full-storage state on it beats a toast.
- **Offline earnings.** Standard in the genre, and a strong return trigger. Needs care not to
  undercut active play.

---

## 8. What the competition does that we do not

Drawn from Pet Simulator 99, the clearest reference point in the genre:

| They do | We do | Gap |
| --- | --- | --- |
| Everything tradable → player-run economy | Nothing tradable | The 3–5× retention lever |
| Weekly updates, same day and time | No cadence | Predictability is the product |
| HUGE / TITANIC status tiers | Nebula exists but is not a status object | Status needs to be visible and unbuyable |
| Weekend 3×–12× multiplier windows | A fake permanent 3× banner | Real windows let F2P keep pace and create appointment play |
| Number scaling into quintillions | Money capped, gears capped | Big-number satisfaction is a real mechanic |
| Trading Plaza as a social space | No shared space | Somewhere to meet is a feature |

Their core loop — hatch, collect, fuse, upgrade — was not novel. They refined an existing loop into
behavioural science and then built a **social economy on top of it**. We have the loop. We do not
have the layer above it.

---

## 9. Prioritised roadmap

Ordered by return on effort, not by size.

### Week 1 — unblock revenue and stop lying

- [ ] Fill in all 15 `MarketplaceId` values — **see `docs/STORE_SETUP.md`**
- [ ] Hide or wire `EventBanner` — no fake events
- [ ] Fix `QuantumMagnet`'s range mismatch and give it its own model
- [ ] Add the two missing magnet icons

### Weeks 2–3 — day one

- [x] Daily reward service + streak, wiring the existing screen and `claimDaily`
- [x] First-session objective chain (4 goals)
- [x] Playtime milestones (was not in the original plan; the data was already there)
- [x] Daily spin wheel
- [x] Friend boost, +10% money per friend
- [ ] "Next unlock" strip in the HUD

### Weeks 4–6 — day seven

- [ ] Daily quests (3 rotating) — the objective chain is the scaffold to build these on
- [ ] Real timed event system, driving the real banner
- [ ] Rebirth progress bar and preview
- [ ] Weekly leaderboard resets
- [ ] Contextual offer prompts at the five moments above

### Weeks 7–12 — day thirty

- [ ] Trading (scrap variants and pets) + a trade plaza
- [ ] One unbuyable status tier above Nebula
- [ ] Index completion rewards
- [ ] Magnet ladder filled in
- [ ] Cosmetic SKUs (magnet skins first)
- [ ] Theme-differentiated scrap economics

### Ongoing

- [ ] A content beat every 1–2 weeks, same day
- [ ] A seasonal event monthly
- [ ] Fix the seven oversized generic scrap models
- [ ] Make `Rebuild` a no-op when the theme already matches

---

## 10. Instrument these before shipping the plan

Most of this is guesswork without numbers. Roblox's analytics cover retention and funnels; the
game-specific ones we have to emit ourselves:

- **D1 / D7 / D30**, against 32% / 14% / 6.2%
- **Median session length**, and **time to first sale** — the 3.5 fix should move this
- **Core loop duration** — time between sells. Target 15–20s early game
- **Funnel drop-off**: joined → first collect → first sell → first upgrade → first area unlock →
  first rebirth. The biggest cliff is the thing to fix next
- **Paying conversion**, against 1–3%. Below 1% means the offer is wrong
- **ARPPU**, against 100–300 Robux
- **Which SKU converts**, and **where the player was standing when they bought**
- **Rebirth count distribution** — if almost nobody rebirths once, the wall is too high

---

## Sources

- [Roblox Retention Rate Benchmarks by Genre (2026) — BLOXG](https://bloxg.com/statistics/roblox-retention-benchmarks)
- [Retention — Roblox Creator Hub](https://create.roblox.com/docs/production/analytics/retention)
- [LiveOps essentials — Roblox Creator Hub](https://create.roblox.com/docs/production/game-design/liveops-essentials)
- [First Week Retention: Optimizing Day-1 Through Day-7 — RoLearn](https://rolearn.dev/guidance/first-week-retention-optimization/)
- [Monetization Strategy Fundamentals for Roblox — RoLearn](https://rolearn.dev/guidance/monetization-fundamentals/)
- [Roblox Player Retention Strategies — BLOXG](https://bloxg.com/guides/roblox-player-retention)
- [Inside BIG Games: How Pet Simulator Became a $100M Roblox Empire — RoWatcher](https://rowatcher.com/news/inside-big-games-how-pet-simulator-became-a-100m-roblox-empire)
- [Pet Simulator 99 Economy Explained — RoWatcher](https://rowatcher.com/news/pet-simulator-99-economy-explained-gems-enchants-and-the-true-cost-of-progress)
- [The Complete Guide to Monetizing a Roblox Game in 2026 — Medium](https://medium.com/@andy.a.g/the-complete-guide-to-monetizing-a-roblox-game-in-2026-c5e915a7c778)
- [Roblox Game Pass Pricing Guide 2026 — UGCCraft](https://ugccraft.com/blog/roblox-game-passes-pricing-guide/)
- [Roblox simulation games: a B2B production guide — Game-Ace](https://game-ace.com/blog/roblox-simulation-games/)
- [Help getting D1 and D7 retention up — Roblox DevForum](https://devforum.roblox.com/t/help-getting-d1-and-d7-retention-up/3159449)
- [5 mistakes creators make building new games on Roblox — TechCrunch](https://techcrunch.com/2021/03/26/5-mistakes-creators-make-building-new-games-on-roblox/)
