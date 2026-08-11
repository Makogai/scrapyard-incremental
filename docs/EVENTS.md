# Timed events

The weekly event schedule, what it multiplies, and how to add to it.

Closes audit item 3.3 (the HUD advertised an event that did not exist) and gives 3.7 the vehicle it
was missing — a content cadence needs something to hang content on.

---

## The one design decision

**The schedule is a pure function of UTC time.** `EventConfig.activeAt(os.time())` answers "what is
on right now" from arithmetic — no database, no admin action, no cron job, no persisted state.

That buys four things:

- **Every server agrees.** They all read the same clock and run the same maths, so two servers cannot
  disagree about whether Scrap Rush is on.
- **Nothing to forget.** The multipliers are live the instant a window opens because
  `derivedStats` reads the same function on every recompute. There is no "start the event" step that
  can be missed, and a server where `EventService` failed to start still pays out correctly.
- **It is testable without a game.** `tests/run.luau` sweeps every hour of the week and asserts no two
  windows overlap, every event opens at some point, and `activeAt` agrees with an independently
  computed schedule. That is where off-by-one weekdays get caught.
- **Players can learn it.** "Double scrap all weekend" is a promise kept by construction. Pet
  Simulator 99 updates every Saturday at 5pm GMT and the predictability *is* the retention mechanic.

The cost: events cannot be triggered on a whim. A one-off surprise event wants a different tool — an
`Announce` broadcast plus a manual multiplier — and can be added without touching any of this.

**All times are UTC.** `os.date("!*t", …)` reads it explicitly. Never use the local-time form here or
the schedule starts depending on where the server happens to be running.

---

## The schedule

| Event | Window (UTC) | Effect |
| --- | --- | --- |
| **SCRAP RUSH** | Sat 00:00 → Mon 00:00 | 2× scrap value |
| **SCRAP STORM** | Tue 18:00 → 20:00 | 2× respawn rate, 1.5× collection speed |
| **LUCKY HOUR** | Wed 18:00 → 20:00 | 2× rare-variant luck |

Two midweek windows and one weekend block: a reason to log in that is not the weekend, and a weekend
block long enough that no timezone misses it.

### Why the multipliers are modest

They stack on top of potions, pets, passes and the friend boost, all of which are already
multiplicative. A "3×" weekend is nothing like 3× in practice — the old fake banner promised 3× scrap
value, and 2× is what the economy can absorb once everything else is counted.

---

## Adding an event

One entry in `EventConfig.Events`:

```lua
table.freeze({
    Id = "GearFever",
    Title = "GEAR FEVER",
    Detail = "2x gears from every sale",
    Glyph = "gear",                       -- must exist in Glyphs.luau
    Accent = "Gold",                      -- must exist in Theme.Color and Theme.Gradient
    Effects = table.freeze({ ScrapValue = 2 }),
    StartDay = 5,                         -- os.date wday: 1 = Sunday, 7 = Saturday
    StartHour = 18,
    DurationHours = 2,
}),
```

Then:

1. **Run the tests.** `lune run tests/run` fails if the new window overlaps an existing one or never
   opens. One event at a time is the assumption both the stacked multipliers and the single banner
   rest on.
2. **Check the story.** `02 Main HUD Desktop → Event Banner` builds a row per scheduled event from the
   config, so a new glyph or accent that does not read against the panel shows up with no story edit.
3. **Wire the effect if it is a new one.** `Effects` keys are read by name:

| Key | Read in | Applies to |
| --- | --- | --- |
| `ScrapValue` | `PlayerStateService.derivedStats` | sale value |
| `CollectionSpeed` | `PlayerStateService.derivedStats` | magnet pickup rate |
| `RespawnRate` | `PlayerStateService.derivedStats` | scrap respawn |
| `Luck` | `PlayerStateService.GetLuckMultiplier` | rare variant rolls |

A key nothing reads is silently ignored — `multiplierAt` returns 1 for anything absent. If an event
needs a stat that is not in the table above, add the `EventConfig.multiplierAt("YourKey", now)` call
where that stat is computed, and it will apply everywhere that stat is used.

### Testing a window without waiting for it

Temporarily point `StartDay`/`StartHour` at the current UTC hour, restart Play, and read the banner
and `DerivedStats` — then put it back. That is how the live path was verified: respawn went 1.0 → 2.0
and collection 24 → 36 while the banner turned cyan and dropped its "Next event:" prefix.

---

## What each piece owns

| Piece | Owns |
| --- | --- |
| `EventConfig` | the schedule and the multipliers. Pure, no dependencies |
| `PlayerStateService.derivedStats` | applying multipliers. Calls `EventConfig` directly — no service coupling |
| `PlayerStateService.publicSnapshot` | telling the client which event is live and when it ends |
| `EventService` | noticing turnover: re-push snapshots, announce once |
| `Store` | resolving the id to title/glyph/accent, counting the timer down |
| `Parts.EventBanner` | drawing it, live or upcoming. **No content defaults** |

### Two deliberate details

**The client is told which event is live rather than computing it.** The schedule is pure, so the
client *could* run it — but a player with a wrong system clock would then see a banner that disagrees
with the multipliers they are actually getting, which is exactly the failure the fake banner was. The
server sends `{ Id, EndsAt | StartsAt, Live }`; the client only counts down, the same way boost timers
already work.

**`EventService` announces nothing on its first pass.** A player joining mid-event gets the banner
from their snapshot; a popup saying the event "just started" would be a lie, and a server booting
during Scrap Rush would otherwise announce it to everyone who joined afterwards too.

---

## Not done yet

- **No exclusive rewards.** These events change multipliers only. Audit item 4 in the roadmap wants a
  seasonal event with cosmetics that do not reset progress; this schedule is the hook to hang it on.
- **No anticipation.** Nothing counts down to the weekend anywhere but the banner. A "starts in 2 days"
  line in the shop or on the daily modal would use `EventConfig.nextAt` and cost very little.
- **One-off events have no path.** Deliberate — see the trade at the top. Add `Announce` plus a manual
  multiplier if a surprise event is ever wanted, and keep it out of `EventConfig`.
