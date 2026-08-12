# Titles and achievements

What they are, how they are earned, and where each piece lives.

Closes audit item 3.6 (no visible long-term goal beyond the next upgrade) and puts a dent in 3.4 (no
social layer) — a title is the only thing in the game that other players can see you have.

---

## The two design decisions

### 1. Achievements are measured, never flagged

A definition names a `Metric` and a `Threshold`. `AchievementRules` reads the metric off the save and
compares. The only thing stored per achievement is whether the **reward has been paid**.

That single choice buys:

- **Progress bars for free**, and they are always right — the client computes them with the *same*
  function the server pays from, so a bar reading 999/1000 cannot belong to something the server
  thinks is done.
- **Retroactive correctness.** Add an achievement next month and a player who passed its threshold
  last year has it on their next poll. There is no backfill script anywhere in this system.
- **No "did you miss the event" bug class.** Nothing counts increments, so nothing can miss one.

The cost: an achievement can only exist for something the save already counts. That is a feature —
it keeps the list honest, and adding a metric is a deliberate act with a schema change behind it.

### 2. Titles come from achievements and nothing else

Every title is the reward of exactly one achievement, asserted **in both directions** by `tests/`:
no title without an achievement, no achievement pointing at a title that does not exist. So "how do
I get that?" always has an answer a player can read, and there is no second unlock path to keep in
step.

**Titles grant nothing.** No multiplier, no stat. The moment a title carries power it stops being a
badge and becomes an item you are punished for not wearing.

---

## The titles

15 titles across five rarities. Rarity is presentation only — it picks the card colour, the nameplate
colour, and the sort order.

| Rarity | Titles | Colour |
| --- | --- | --- |
| Common | NEWCOMER, COLLECTOR, SCRAP HAULER | grey |
| Rare | SCRAPPER, REBORN, PET KEEPER, REGULAR, WANDERER | blue |
| Epic | SCRAP BARON, ARCHIVIST, TYCOON, ASCENDED | purple |
| Legendary | DEVOTED, FULLY LOADED | gold |
| Mythic | SCRAPYARD LEGEND | pink |

The ladder is deliberately uneven: the first arrives in the first minute so players learn titles
exist, and SCRAPYARD LEGEND (50 rebirths) should stay rare for months. One title nobody has is worth
more to the players who lack it than five everyone can reach.

## The achievements

19 across six tracks — Scrap, Wealth, Rebirth, Pets, Loyalty, World. Thresholds come from where the
game's own curves put a player, not from round numbers: 100 scrap is ten minutes, 1,000 is a session,
a million is weeks.

Rewards are small on purpose (cash, the odd spin). **No achievement may pay gears** -- gears are rebirth
currency and nothing but a rebirth grants them. They used to raise income directly, so "Hold $1,000" paying
5 gears was a permanent x2.67 on every sale in the first minute of play; `tests/run.luau` now asserts no
definition carries a `Gears` reward. An achievement list that pays well becomes
a grind checklist; the title is the real prize.

---

## Where a title shows up

| Surface | Built by | Notes |
| --- | --- | --- |
| Over the head | `TitleController` | Name on top, the title under it — no brackets, dressed by rarity |
| In chat | `TitleController` | `[TITLE] Name: message`, via `TextChatService.OnIncomingMessage` |
| Inventory → TITLES | `InventoryScreen` + `Progression.TitleCard` | Wide cards, equip from here |
| Index → AWARDS | `CollectionScreen` + `Progression.AchievementCard` | Progress and rewards |

### Two forms of the same title

Chat gets `[SCRAP BARON]` — a tag in a line of prose has to be told apart from the message around it.
Over a head it is just **SCRAP BARON**: there is nothing to disambiguate from up there, and brackets
make a title read as a placeholder.

### The better the title, the better it looks

One table in `TitleController` (`TIERS`), five steps, each adding to the one below — so the ladder is
legible from across the yard before you can read the words:

| Rarity | Treatment |
| --- | --- |
| Common | flat grey, 14px. It is a label |
| Rare | the rarity colour, 15px |
| Epic | a gradient across the glyphs — reads as metal rather than ink, 16px |
| Legendary | gradient, 18px, and a glow behind it that breathes |
| Mythic | all of it, 19px, plus the gradient SCROLLS and three sparkles orbit the text |

Built from plain Frames and `TweenService`, the same way `Components/Shine` does it — no textures, no
`ParticleEmitter`, nothing to upload. A nameplate is drawn for every player in the server, so the top
tier has to stay in the region of a handful of tweens.

**The glow is three faint layers, not two strong ones.** The engine has no blur for GUIs, so a glow is
faked by stacking translucent discs, and that only works if each is nearly invisible: at two discs of
0.55 and 0.8 transparency the pair read as a solid lozenge behind the text — a plate, not a halo.

The title block is rebuilt from scratch when the worn title changes, because the tiers differ in which
*children* exist. Reconciling that by hand is how a Mythic plate keeps its sparkles after switching to
a Common one.

### The nameplate replaces Roblox's

`Humanoid.DisplayName` is drawn by the engine and cannot take a second line, so
`DisplayDistanceType = None` switches it off and the controller draws both lines itself. That is the
only way to get "title *under* name" rather than "title floating near name", and it means the two can
never drift apart as the camera moves.

### Both surfaces read a Player attribute

`PlayerStateService` publishes `TitleId` and `TitleTag` (already bracketed) on the Player.
**Attributes, not a remote** — because the audience is every *other* client. Attributes replicate to
everyone and arrive with the Player instance, so someone who joined before you already shows up
wearing theirs, with no request and no cache to invalidate.

---

## Granting a title for testing

Admin panel → **TITLES**, which lists all 15 in rarity order with the tier in the label. Granting from
there **wears** it as well as handing it over — the opposite of what an achievement does, and
deliberate: the reason to grant a title in a test session is almost always to look at it over a head,
and a second trip to the inventory to equip it wastes the one action the panel exists to save.

The panel's right column is sized from the number of sections `AdminCatalogue` produces, so adding a
section cannot push the last tab off the edge again — which is exactly what TITLES did the first time.

## Adding an achievement

```lua
table.freeze({
    Id = "SellHundred",
    Name = "Regular Customer",
    Description = "Sell 100 loads at the crusher",
    Glyph = "recycle",                    -- must exist in Glyphs.byName
    Accent = "Cyan",
    Metric = "TotalSales",                -- must exist in AchievementRules
    Threshold = 100,
    Track = "Wealth",                     -- must exist in AchievementConfig.Tracks
    Reward = table.freeze({ Money = 50_000, TitleId = "Regular" }),
}),
```

Then run `lune run tests/run`. It fails if the metric is unknown, the track is unknown, the threshold
is under 1, the title does not exist, or two achievements grant the same title.

### Adding a metric

`AchievementRules.METRICS` is a table of `name -> (data) -> number`. Add a reader there; every reader
must tolerate a missing field (it runs against saves written by older schema versions). If the number
is not in the save yet, that is a schema change first — `PlayerDataSchema` v15 is the current version.

---

## What each piece owns

| Piece | Owns |
| --- | --- |
| `TitleConfig` | the titles, their rarity, and the `[TAG]` format |
| `AchievementConfig` | the list, thresholds, tracks, rewards |
| `AchievementRules` | reading metrics and progress. Pure, no services, fully tested |
| `AchievementService` | *when* to look, and paying out once |
| `PlayerStateService` | holding/wearing a title, and publishing the attributes |
| `TitleController` | the nameplate and the chat prefix |
| `Progression` | the two card types |

### Two deliberate details

**A poll, not a hook.** Evaluating inside `pushState` would be instant, but granting a reward pushes
state, which re-enters the evaluation — terminating, but doubling the work on every change in the
game. A 3s poll cannot recurse and nobody notices three seconds on a milestone.

**Marked paid before the reward is granted.** `GrantRewards` pushes state and can yield, so recording
first means the worst case is a reward that failed to arrive — not one handed out twice.

---

## Not done yet

- **No achievement notification screen.** Earning one sends a single `Notify` toast. A proper
  full-screen "ACHIEVEMENT UNLOCKED" moment with the title reveal would suit the rarer ones.
- **Nothing is secret.** `AchievementDefinition` has a `Secret` field that nothing reads yet — the
  hook is there for a hidden achievement whose description would spoil something.
- **No title in the leaderboards or the plot owner sign.** Both already show a name; both could show
  the tag next to it, and the attribute is already there to read.
- **No rarity treatment on the title CARDS.** The inventory cards colour by rarity but do not carry the
  gradient, glow or sparkles the nameplate now does — so picking a Mythic title does not preview what
  it will look like over your head.
