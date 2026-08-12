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
| **THE PIT** | Fri 18:00 → 22:00 | opens a shared arena; 1.25× collection speed |

Two midweek windows, a Friday arena, and one weekend block: a reason to log in that is not the weekend,
and a weekend block long enough that no timezone misses it.

**The Pit's slot is not a free choice.** Windows may not overlap, and Scrap Rush already owns all of
Saturday and Sunday — so Friday 18:00 is the busiest hour left. That matters more for this event than any
other: a shared arena with nobody else in it is just a worse plot.

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

### Starting one by hand

**Admin panel → EVENTS.** Pick an event, put a number of MINUTES in the amount box, tap it. `STOP EVENT`
hands control back to the schedule. Admins can do this as well as owners: an override expires on its own
and is clamped by `AdminConfig.MaximumEventMinutes`, so the worst case is a busy afternoon.

It works through `EventConfig.setOverride`, which `activeAt` checks **before** the schedule — and that is
deliberately the same function everything else already calls: `derivedStats` for the multipliers, the
player snapshot for the HUD banner, `EventService` for the world billboard and the announcement. So a
hand-started event cannot be live for the payouts and absent from the banner, or the reverse. It is
server-side state living in a config module for exactly that reason; the alternative was two answers to
one question, which is how a banner ends up claiming 3x while the payouts disagree.

`EventService.Republish` pushes it out immediately rather than waiting up to `POLL_SECONDS`, and
announces it — an admin who presses start and watches nothing happen for five seconds reasonably
concludes the button is broken.

Verified live: `EventState.LiveId` went from empty to `ScrapStorm`, the player snapshot reported
`ScrapStorm` with 1738s remaining, and the HUD banner read "Scrap respawns twice as fast" over a 27:14
countdown.

### Testing a window without waiting for it

The override above is usually easier. To test the SCHEDULE itself, temporarily point
`StartDay`/`StartHour` at the current UTC hour, restart Play, and read the banner and `DerivedStats` —
then put it back. That is how the live path was verified: respawn went 1.0 → 2.0 and collection 24 → 36
while the banner turned cyan and dropped its "Next event:" prefix.

---

## THE PIT — the one event that is a place

Every other event multiplies a number. The Pit opens a walled arena in empty space south of the map,
fills it with scrap **nobody owns**, and lets everyone in the server race for the same pieces. Friday
18:00–22:00 UTC, and startable by hand from the admin panel like any other.

It exists because of a gap: everything else in this game happens on your own plot, alone. Your scrap is
yours, it respawns for you, nobody can touch it — the right default for an idle game, and also the
reason two players in one server never interact with the same object. The Pit is the one place they do.

### The three rules, each a deliberate departure from the plot loop

| Rule | Why |
| --- | --- |
| **Nobody owns the scrap** (`OwnerUserId = 0`) | `ReservedUserId` already makes the race safe — first magnet to reserve a piece gets it, the loser's finds nothing there |
| **The area lock does not apply** | A brand-new player can pull a scrap car in there. That is the draw. Magnet **strength** still gates it, so the upgrade tree keeps its meaning |
| **It refills to a target instead of respawning per piece** | A crowd stripping one side of a shared hoard must not leave that side permanently bare, and nobody should be able to camp a respawn point |

### Geometry is generated, not authored

`ArenaService.build` makes a cylinder floor, a ring of 30 wall slabs with neon caps, a landing pad and
four rim lights — about 1,080 parts. Authoring it in Studio would mean a permanent 1,000-part model
replicating to every client all week for the sake of a Friday evening, and changing `ArenaConfig`'s
radius would mean rebuilding it by hand.

**The rim lights are dim on purpose.** The first pass ran four lights at 2.4 brightness over 84 studs,
which is four overlapping lights on every square foot of a 120-stud bowl: the floor went flat grey and
every piece of scrap rendered pure white. Scrap art is mid-grey metal, so it has nowhere to go when
overexposed — and being able to tell one piece from another is the entire reason to light the place.

### Getting in and out

An `ENTER THE PIT` button appears on the HUD under the event banner, and only while an arena event is
live. The teleport destination is checked server-side against `ArenaService.IsOpen()` — the floor is
destroyed when the event ends, so a stale request would drop somebody into empty space. When it closes,
anyone still inside is put back on their own plot **before** the geometry is destroyed; otherwise they
fall through the void until Roblox resets them, which reads as the game breaking rather than the event
ending.

### Verified live

Started from the admin panel: the arena built at (250, 65, −560) with 1,078 parts and 90/90 pieces
across 17 scrap types. Walking a magnet round the floor collected 12 pieces — including an **Axle**,
which is Vehicle Graveyard scrap on a Front Yard plot, so the area bypass works — while `TooHeavy`
rejections fired for the pieces past the magnet's strength. Count went 90 → 86 with the refill topping
it back up.

---

## What each piece owns

| Piece | Owns |
| --- | --- |
| `EventConfig` | the schedule and the multipliers. Pure, no dependencies |
| `ArenaConfig` | the Pit's design: where, how big, how much scrap, and the three rules above |
| `ArenaService` | building it, filling it, tearing it down, and evacuating |
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
