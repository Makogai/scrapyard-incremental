# Return-to-play systems

Five systems that answer "why come back tomorrow": the daily calendar, playtime milestones, the spin
wheel, the friend boost, and the first-session objective chain.

Why they exist and what they are measured against is in **`docs/GAME_AUDIT.md`**. This is how they
work.

---

## The shared shape

All five grant through **one path**, `PlayerStateService.GrantRewards`, taking the same bundle codes
and developer products already used:

```lua
{ Money = number?, Gears = number?, Items = { [itemId]: count }?, Spins = number? }
```

Clamping happens inside `GrantRewards`, not at the call sites — the call sites are the code most
likely to be handed a bad number.

Config lives in **`src/shared/Config/RewardsConfig.luau`** (daily, playtime, spin, friends) and
**`TutorialConfig.luau`** (the objective chain). Both are pure data; adding a calendar day or a wheel
segment needs no code.

### Two rules that shape every one of them

**1. The client sends an intent and nothing else.** No day index, no reward id, no amount, no
"I landed on the jackpot". `Bridge.claimDaily()` deliberately takes no argument — it used to be
called `actions.claimDaily(currentDay)`, the client telling the server what to pay out.

**2. Days are day numbers, never timestamps.** `DayClock.dayNumber(t)` is `t // 86400`. Every system
asks "have they claimed today" and "was that yesterday", and with raw timestamps both have an
off-by-one that pays out twice: `now - last >= 86400` lets a player claim at 23:59 and again at
00:01. Integer day comparison cannot. UTC on purpose, so the reset happens at the same instant for
everyone.

---

## 1. Daily rewards — `DailyRewardService`

A seven-day calendar that **loops**. Day 7 is the big one.

**The streak is the mechanic, not the reward.** A reward for logging in is pleasant; a streak you
lose by not logging in is a reason to log in. So the streak is what the footer leads with, and it
scales the day's cash by `StreakBonusPerDay` (5%, capped at +100%).

**Only cash scales.** Scaling item counts would hand a 30-day player thirty God Potions; scaling
spins compounds into a wheel that already has a jackpot.

**One missed day is forgiven** — `StreakGraceDays = 1`. Deliberate generosity: losing a 30-day streak
to one busy evening is the kind of punishment that makes players stop returning rather than return
harder.

The calendar day and the streak advance **independently**. A player who breaks their streak carries
on through the calendar rather than being reset in both currencies for one missed day.

`DayClock.advanceStreak` holds all of that, and the test suite covers all five cases: same-day
rejection, first claim, consecutive, inside grace, past grace.

## 2. Playtime rewards — `PlaytimeRewardService`

Five milestones inside one day: 5 min, 15 min, 30 min, 60 min, 2 hr. Reset with the daily reset.

Playtime was already accumulated for the leaderboard and never spent on anything. This spends it.

**Front-loaded on purpose.** The 5-minute milestone exists to be hit during a first session — a
milestone a new player never reaches is a number in a config, not a retention mechanic.

**Banks elapsed wall time, not a fixed amount per tick**, so a hitching server does not shortchange
the player and a late tick still credits the right seconds. One loop for all players rather than a
thread each.

Lives on the **HUD**, not in a menu: these are earned by doing nothing in particular, and a milestone
the player has to go looking for is one they never claim. The bar filling while they play *is* the
mechanic.

## 3. Spin wheel — `SpinService`

**The server picks the prize, grants it, and tells the client where to stop.** That ordering is the
whole security model. A client that spins and then reports where it landed lands on the jackpot every
time.

```
client  RequestSpin
server  consume a spin -> weighted pick -> grant -> SpinResult(segmentId, index)
client  animate the reel to `index`, then reveal
```

The reward is granted **before** the animation finishes, so a player who leaves mid-spin still got
it. Losing rewards to closed windows is the worse failure.

`SpinResult` is its own remote rather than riding `Notify`, because it carries structured data and
`Notify` is a plain string by contract — putting a table down it blanked the entire UI once already
(AGENTS.md rule 13).

**The wheel is drawn as a vertical reel, not a pie.** Roblox has no radial fill, and faking wedges
means rotated GuiObjects, which ignore an ancestor's `ClipsDescendants` and paint over the whole
screen (rule 11). A reel that slides to its stop reads just as well and animates with one spring.

One free spin per day, granted on join, stamped so it cannot be collected twice. Stored spins cap at
25.

## 4. Friend boost — `FriendBoostService`

**+10% money per friend in the same server**, capped at 10 friends.

The cheapest social mechanic there is: no new flow, no matchmaking, no trading rules. It rewards
bringing people, and the reward is visible to both sides. Social systems are the 3–5× retention
lever; this is the smallest step onto that ladder.

Applied to `ScrapValue` in `derivedStats`, so it shows up in the stat readout the player can already
see. A boost you cannot find motivates nobody.

`Player:IsFriendsWith` is a **web call**, so:

- results are cached per unordered pair for the server's lifetime
- the recount is **debounced by 2 seconds**, because a group of friends joining together — the exact
  case this feature exists for — would otherwise fire the same calls several times over
- a failed call is treated as "not friends" and **never cached**, so one bad moment cannot
  permanently deny two players their boost
- a leaving player's cached pairs are dropped, or the table leaks a row per pair over a long server

The count is transient: it describes the room, not the player, so the schema resets
`FriendBoostCount` to 0 on every load.

**Bottom-right HUD icon**, shown even at zero friends. "+0%" next to a friend icon is an invitation;
hiding it until you already have friends means the player who most needs the nudge never sees it.

## 5. First-session objectives — `TutorialService`

**Not a tutorial.** Complex onboarding backfires on Roblox — players have no tolerance for anything
but immediate play, and at least one team raised retention by deleting theirs outright. So there is
no modal, no forced camera, and nothing to dismiss. There is a caption, an arrow, and a reward.

Four steps, each completed by doing the ordinary thing:

| Step | Objective | Satisfied when | Pays |
| --- | --- | --- | --- |
| 1 | Grab some scrap | `TotalScrapCollected >= 5` | $250 |
| 2 | Sell it at the crusher | `Money >= 1` | $500 |
| 3 | Buy an upgrade | any upgrade level `>= 1` | $1,000 |
| 4 | Reach $5,000 | `Money >= 5000` | $2,500 |

**Completion is evaluated server-side from the snapshot**, not reported by the client. That means the
client cannot skip ahead to the rewards, no other service has to call into this one, and any route to
the same outcome counts — which is what "indistinguishable from playing" requires.

`Evaluate` loops rather than checking once, because a player can satisfy two steps between ticks, and
it **re-reads state after each grant** — step 3's reward can itself satisfy step 4's money threshold.

Established players are **opted out on join** (`SkipIfMoneyAbove`, or any upgrade owned). Showing
"GRAB SOME SCRAP" to someone with a rebirth is worse than showing nothing.

The only thing the client may ask for is **Skip**.

### The arrow — `TutorialArrowController`

The caption says what; the arrow says where. Targets come from the step's `Target`:

| Target | Points at |
| --- | --- |
| `"scrap"` | the nearest live scrap on the player's own plot |
| `"crusher"` | the plot's `CrusherSellZone` |
| `nil` / other | no world arrow; the caption's own arrow covers UI targets |

Built from instances rather than React, because it hangs off a part in the world — a `BillboardGui`
on an invisible anchor. The anchor exists so a destroyed target (scrap is destroyed the instant it is
collected) cannot take the billboard with it mid-frame, and so the arrow floats a fixed height above
targets of wildly different sizes.

Re-resolved every frame while active, because the nearest scrap changes as the player walks and dies
as they collect. The loop is skipped entirely once the chain finishes, so the cost is bounded to a new
player's first few minutes.

**`screen_capture` with a camera override does not draw BillboardGuis**, so this cannot be verified
from a scripted screenshot — it needs a real Play session.

---

## Data — schema v14

New fields, all bounded, because every one is "free value on a timer" and an unbounded one is a
direct exploit: an uncapped `SpinsAvailable` is unlimited jackpots, an uncapped `DailyStreak` is an
uncapped cash multiplier.

| Field | Bound |
| --- | --- |
| `DailyStreak` | 3650 |
| `DailyLastClaimDay`, `PlaytimeDay`, `SpinLastGrantDay` | day numbers |
| `DailyCalendarDay` | 1–7 |
| `PlaytimeSecondsToday` | 86400 |
| `PlaytimeClaimed` | keys 1–5 only, `true` only |
| `SpinsAvailable` | 25 |
| `TutorialStep` | 0–5 |
| `FriendBoostCount` | reset to 0 on load |

`PlayerDataSchema` **requires nothing** — it runs under the Lune test runner, which has no
`ReplicatedStorage` — so those bounds are literals mirroring `RewardsConfig`. Keep them in step.

`migrateVersionThirteen` is all defaults. Existing players start with **no streak**, which is right:
a streak they never earned would hand them the day-7 multiplier for free.

### A persistence bug this work uncovered

`ActivePlotTheme` was written by `createDefault` and by the v12 migration but **never copied out of
`raw` in the sanitiser** — so the plot theme had never actually persisted, and every player came back
as `FrontYard` however many times they had converted. Found because a new migration test asserted it
survived a round trip. Fixed, and validated against the real area list.

---

## Verified in Play

| | Result |
| --- | --- |
| All five services boot | clean, no errors |
| Daily claim | money +$500 (day 1, streak 1, no bonus yet) |
| Spin | money +$1,500, which also proves the free daily spin was granted on join |
| Friend boost widget | renders bottom-right at (1330, 692) in a 1365×768 viewport, "+0%" solo |
| Playtime track | renders bottom-centre, "PLAYTIME 5 min" |
| Tutorial | correctly opted out on a $5.9M save |
| Gates | 135 tests, selene 0, stylua clean |

### One bug Play caught that the linters could not

`Parts.FriendBoost` built its children as a **table literal** with a conditional in the middle:

```lua
children = { icon, if active then badge else nil, label }
```

A nil in the middle of an array leaves a hole, and `ipairs` stops dead at it — so the "+0%" label
was silently dropped for every player with no friends, which is exactly the player the widget exists
to talk to. The icon rendered; the label did not.

`P.compact` exists for this. **Any children list with an optional entry that is not last has to go
through it.**

---

## Still open

- **Repeatable daily quests.** The objective chain is the scaffold; it is one-off by design.
- **A real event system.** `EventBanner` still renders hardcoded text promising a 3× event that does
  not exist. Wire it or hide it.
- **Offline earnings**, standard in the genre and a strong return trigger.
- **Trading**, which is the actual 3–5× lever. The friend boost is the first step, not the answer.
