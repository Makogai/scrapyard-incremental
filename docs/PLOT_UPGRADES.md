# Plot upgrades — design

Replaces "areas are regions inside one plot" with "areas are **themes your whole plot can
become**". Unlocking an area no longer opens a fenced-off corner of your yard; it drops a
structure on your plot that you hold **E** on to convert the entire plot into that theme.

The point is envy. With six players on a map you walk past other yards constantly. A player
whose plot is still the starting scrapyard, standing next to a full Vehicle Graveyard plot,
has a concrete thing to want — and it is visible from outside the fence, unlike a stat on a
sign.

---

## Status

Implemented and Play-verified end to end.

| | State |
| --- | --- |
| `Workspace.PlotVariants` — three editable plots | done |
| `Workspace.AreaStructures` — named slots, moved to ServerStorage at boot | done |
| `AreaStructureSlots` on each variant | done |
| Structure appears for each unlocked area | done |
| Hold-E prompt (2s) attached from code | done |
| Conversion: validate, save, teleport clear, rebuild, replace structures | done |
| `ActivePlotTheme` persisted (schema v13, migration defaults to `FrontYard`) | done |
| Plot built from the saved theme on join | done |
| Scrap re-activated after a rebuild | done — was broken, see below |
| Sign card refreshes after a rebuild | done — was broken, see below |

## Three bugs this system shipped with

All three came from the same blind spot: the rebuild replaces instances that other code had
already resolved by name, and nothing re-resolved them. Worth reading before touching `Rebuild`.

### 1. `Notify` is a plain string, and sending a table blanked the entire UI

`TryConvert` fired the `Notify` remote with a toast-shaped table:

```lua
notifyRemote:FireClient(player, { Title = "Plot", Body = "...", Glyph = "home" })
```

Every other producer in the codebase sends a **plain string**, and `Bridge` is what wraps it into
`{ Title = message, ... }`. So `Title` became a table, `Overlays.Toast` called
`string.upper` on it, the error escaped during React's render phase, and **React tore down the
whole tree** — one hold-E left the player with nothing but the topbar and no way back. The same
payload also killed `AudioController`'s `Notify` connection, silently disabling every later sound
hook.

Fixed by sending a string. `Overlays.Toast` now coerces its text and `AudioController` type-checks
the payload, so the worst case is a wrong-looking toast rather than a dead interface. **A toast is
the one component rendered straight from a server payload — it must never be able to throw.**

If you want a richer toast from the server, add a dedicated remote. Do not change what `Notify`
means.

### 2. Scrap never spawned, on every join

`ScrapService.activatePlot` and `PlotThemeService.Rebuild` both run off
`PlotService.OnAssigned`, and `ScrapService.Start()` is called first (`init.server.luau` line 31
vs 50). So on **every join**: scrap activated, cached its `ActiveScrap` folder and its
`ScrapSpawnLocations` markers — and then the rebuild destroyed both. `foldersByPlot` pointed at a
destroyed folder for the rest of the session and the plot sat permanently empty. Converting did
it again.

`ReleaseScrap` had a matching `ActivateScrap` missing all along: the rebuild dropped the old
scrap and never stood any back up. `ScrapService.ActivatePlot` is now public and idempotent
(it clears before it builds), `PlotService.ActivateScrap` passes through to it, and `Rebuild`
calls it after `PlotBuildService.Apply`. Ordering no longer matters.

Verified in Play: 15 pieces in a live, parented `ActiveScrap` folder on the assigned plot, and
none on the five unassigned ones.

### 3. The sign card — a replication race, not a missing card

The long-standing "sign reads AVAILABLE PLOT after a rebuild" defect was never about stale
attributes. **A newly replicated Model's descendants arrive on the client over several frames**,
so the `ChildAdded` re-bind — which deferred exactly one frame and then read the card once — found
a bare `OwnerSign` with nothing under it, logged "has no authored card", and gave up for good. The
card was in the place file the whole time; Edit mode confirmed all six plots and all three
variants have it.

`bindSign` now polls for the card for up to 10 seconds and is spawned rather than called inline,
and it guards against binding one sign twice. `refreshMarker` got the same treatment: it retries
once after 2 seconds and only warns about plots still missing a marker, so a genuine authoring gap
is still reported — Plot04 currently has no `YourPlotMarker` and says so.

**The lesson for anything else that binds to plot geometry: `FindFirstChild` immediately after
`ChildAdded` is a race.** Wait for what you need.

Verified in Play: `Structure_WorkshopYard` placed with a 2-second prompt, holding E flipped the
plot's `ActivePlotTheme` from `FrontYard` to `WorkshopYard`, the plot came back with
`PlotFloor`, `OwnerSign`, `Crusher`, `ScrapSpawnLocations` and `AreaStructureSlots` all intact,
and the structure for the now-active theme correctly disappeared. `VehicleGraveyard` is locked
on this save so no structure appeared for it, which is right.

### Align rebuilt plots by the FLOOR, never by the pivot

`Model:GetPivot()` on a model with no `PrimaryPart` is its bounding-box centre, so it moves
whenever the contents change. The variants carry an extra `AreaStructureSlots` folder the live
plots did not, so pivoting a rebuilt plot back to its old pivot dropped it a quarter of a stud
off its slot — the plot appeared to vanish from where it belonged, and `PlayerSpawn` went with
it, which put both the join spawn and the My Plot teleport in the air.

The floor is the one part that means the same thing in both, so the transform is the one that
maps the variant's `PlotFloor` onto the existing `PlotFloor`, applied to each cloned child
explicitly. Verified: floor back at 20.073, exactly where it started, and `PlayerSpawn` 0.2
studs above the floor top.

The owner is also stood outside **after** the swap rather than before. Placing them first used
a floor that was about to be destroyed, so any drift left them hanging.

### 4. A Scrapyard plot spawned Workshop scrap

The plot showed the starting Scrapyard and spawned Workshop scrap in it.

Every plot — and every variant — still carries spawn markers tagged for all three areas, because
that is what they were authored for when an area was a fenced region inside one yard:

| marker tag | count per plot |
| --- | --- |
| `FrontYard` | 8 |
| `WorkshopYard` | 7 |
| `VehicleGraveyard` | 7 |

`ScrapService.spawnAt` picked the scrap from **the marker's** tag, so the moment a player unlocked
Workshop, 7 markers on their Scrapyard-themed plot started producing Workshop scrap. Under the old
region system that was correct; under themes it is nonsense.

**The plot's theme now decides what spawns.** `spawnAt` reads `ActivePlotTheme` off the plot (which
`Rebuild` writes before scrap is activated), falling back to player state, then `FrontYard`.

**The marker's own tag still decides whether it spawns at all**, which is the deliberate half of
the change: unlocking an area still earns you more spawn points on your yard, so the markers keep
doing the job they were authored for and early-game density is unchanged. Flipping every marker on
at once would have taken a new plot from 8 live spawn points to 22 against a
`MaximumActiveScrapPerPlot` of 28 — the cap would never bind and early scrap would roughly triple.
Only the *contents* come from the theme.

So the marker tag now means **"which unlock earns this spawn point"**, not "what spawns here".

Verified in Play, both directions, on a plot with areas unlocked so more than 8 markers were live:

| plot theme | 15 spawned pieces |
| --- | --- |
| `FrontYard` | MetalCan, LooseBolt, SmallMetalPlate, RustyPipe, CrushedBucket, Tire |
| `WorkshopYard` | BrakeDisc, BrokenAppliance, CarDoor, EnginePart, Radiator, Tire, ToolBox |

Nothing foreign in either, and every piece stamped with the plot's theme.

### 5. Standing on the crusher stopped selling

`SellService.Start()` connected `Touched` on each plot's `CrusherSellZone` **once at bootstrap**.
The rebuild destroys every child of the plot and clones fresh ones, so that connection died with
the old part — and because `Rebuild` runs on *every join*, the zone it bound to was gone before any
player ever stood on it. Selling was broken outright, not just after converting.

`CanTouch` was `true` on every variant and every live plot, so that was never a factor.

### The hook that stops this recurring

Bugs 2, 3 and 5 are one mistake made three times: a service resolved something under a plot, and
the rebuild replaced it. Each shipped looking like a completely different bug — nothing spawning,
signs stuck on AVAILABLE PLOT, selling dead.

So there is now one signal:

```lua
PlotService.OnGeometryReplaced(function(player, plot)
    -- re-resolve anything you hold under this plot
end)
```

`PlotThemeService.Rebuild` fires it last, once the new geometry is in and dressed, via
`PlotService.NotifyGeometryReplaced`. `SellService` uses it to re-bind its `Touched` connection,
disconnecting the previous one so re-binds replace rather than stack.

**If you resolve anything under a plot outside that callback, it will break.** `Rebuild` runs on
every join, so "it only breaks if someone converts" is not a defence.

Audited at the same time, and safe:

| | why |
| --- | --- |
| `TeleportService` | re-resolves `PlayerSpawn` / `CrusherSellZone` per call |
| `ShopService` | its walk-in zones are map-level (`Magnet Shop`, `AreaShop`, `Shop`) |
| `PetService` | its prompts are on `Workspace.Pets`, not on plots |
| `PlotBuildService` | `Rebuild` calls it after the swap, so it always re-resolves |
| `ScrapService` | re-activated explicitly by `Rebuild`, which needs a fixed order |

### Still to retire

The scrap half of the old region system is now dealt with (see 4 above). What remains:

- **`updateAreaGates`** still shows and hides the per-area gate models (`AreaConfig.GateModelName`
  — `WorkshopGate`, `VehicleGate`). Those gates fenced off regions that no longer exist as places.
- **`AreaService` unlocks stay.** Unlocking is still how you earn the right to convert to a theme,
  and it is now also what earns extra spawn points. That part is load-bearing, not legacy.

So the thing to remove is the gate geometry and `updateAreaGates`, not the unlock system. Two
systems both claiming to own "areas" is how the shop ended up with a dead `Assets.Art` table
nothing read.

## Art direction

The look of the three themes -- palettes, floors, fences, props, particles, the sign, and a
build checklist -- is in **`docs/PLOT_ART_DIRECTION.md`**. This document is the mechanics; that
one is the art.

## Where things go

### `Workspace.PlotVariants`

One editable plot per theme, parked at x = 1100/1360/1620 (clear of the map, which ends
around x = 527). These are **templates** — the game will clone one onto a player's plot slot,
so they are never played on directly.

```
Workspace.PlotVariants
  ScrapyardPlot          AreaId = "FrontYard"          the starting look; a copy of Plot01
  WorkshopPlot           AreaId = "WorkshopYard"       yours to theme
  VehicleGraveyardPlot   AreaId = "VehicleGraveyard"   yours to theme
```

All three are currently identical copies of `Plot01`. Retheme the second and third freely —
geometry, colours, props, whatever. **What must stay** is the named machinery the services
already look for, because a variant has to be a drop-in replacement:

| Must keep | Who needs it |
| --- | --- |
| `PlotFloor` | scrap grounding, the plot marker |
| `ScrapSpawnLocations` with its `Spawn_*` / `AreaSpawn_*` parts | `ScrapService` |
| `OwnerSign` with `Board` → `PlotSignPlate` → `PlotSignSurface` → `Card` | `PlotSignController` |
| `Crusher` with `CrusherSellZone` | selling |
| `PlayerSpawn` | teleport-to-plot |
| `Boundaries.PlotBounds` | plot bounds |
| `RuntimeObjects` (empty folder) | runtime spawns |

An `AreaId` attribute on each variant is how the code will pick one. Add a fourth theme by
cloning a variant, setting its `AreaId`, and adding the matching `AreaConfig` entry — no code
change.

### `Workspace.AreaStructures`

One model per area, **named exactly after the area id**. Drop your art in; keep the name.

```
Workspace.AreaStructures
  FrontYard          (the default theme -- see the note below)
  WorkshopYard
  VehicleGraveyard
```

Each currently holds a translucent `Placeholder` part so the slot is visible. Replace it with
real art and set the model's `PrimaryPart`, which is what the code will position by.

`FrontYard` exists for symmetry but is not needed at first: it is the theme you start with,
so there is nothing to unlock. Keep the slot — it becomes useful if you ever let a player
revert.

---

## Runtime behaviour to build

### 1. Unlocking an area places its structure

When a player unlocks an area, clone `AreaStructures.<AreaId>` into their plot's
`RuntimeObjects` at an authored spot. The plot needs a marker per area so the structure lands
somewhere deliberate rather than computed:

```
Plot0N.AreaStructureSlots
  WorkshopYard        a small anchored part; the structure's PrimaryPart goes here
  VehicleGraveyard
```

Add those to each variant. Position them by measurement (bounding box bottom onto the
marker's top) the way `ScrapService` places scrap — a structure that floats or sinks reads as
broken, and every model will arrive at a different size.

### 2. Hold E on the structure to convert the plot

A `ProximityPrompt` on the structure's `PrimaryPart`, `HoldDuration` around 2 seconds so it
cannot be triggered by accident:

- `ActionText` — "Convert Plot"
- `ObjectText` — the area's `DisplayName`
- `RequiresLineOfSight = false` (structures will have props in front of them)

`PetService` already attaches a hold-E prompt to `EggSummonPodium` from code rather than
authoring one per model — copy that, so a new structure needs no prompt authored.

On trigger, server-side:

1. Verify the triggering player owns the plot, and that the area is unlocked. Client sends an
   **area id only** — never a plot reference, never a theme name it chose.
2. Write `ActivePlotTheme = <AreaId>` to their data.
3. Rebuild the plot from the matching variant.
4. Notify: "Your plot is now a Vehicle Graveyard".

### 3. Rebuilding the plot

The heavy part, and where the risk is. `PlotService` currently assigns one of six authored
plots and `PlotBuildService` dresses it. Converting means swapping the geometry under a
standing player.

Recommended: **keep the plot slot, swap its contents.** The slot's position and `PlotId`
stay; the variant is cloned in and pivoted to the slot's origin. That keeps every other
service's assumptions intact — they all resolve things by name under the plot.

Order matters:

1. Despawn active scrap (`ScrapService` holds `activeByInstance`; leaving them orphans the
   records).
2. Clear the slot's children except `RuntimeObjects`.
3. Clone the variant in, pivot to the slot origin.
4. Re-run `PlotBuildService.Apply` so the sign, stage visibility and gates re-bind.
5. Re-place the structures for every unlocked area.
6. Teleport the player to `PlayerSpawn` if they are standing where geometry now is.

`PlotSignController` binds on join, so a swapped-in sign needs re-binding — either re-bind on
`ChildAdded` or have the controller watch the plot. Worth deciding before writing it.

### 4. Persistence

`ActivePlotTheme` in `PlayerDataSchema`, defaulting to `"FrontYard"`. Bump the schema
version; the migration is a default, so it is cheap. On join, build the plot from the saved
theme rather than always the scrapyard.

### 5. What `AreaConfig` becomes

Areas stop being places and become themes. `AreaIds` on scrap definitions currently means
"which region does this spawn in"; under the new system the natural reading is "which theme
spawns this scrap", which is a nicer knob — a Vehicle Graveyard plot yielding car doors and
engine parts instead of cans falls out of it for free.

That is a real content decision, not a rename. Worth doing deliberately: it changes what a
theme is *for*, from cosmetic to economic.

---

## Suggestions

Things this opens up, roughly in order of value for effort.

**Make the theme legible from outside.** The sign already shows the owner; add the theme to
it. A player walking past reads "MARKO'S VEHICLE GRAVEYARD" and knows exactly what they are
looking at. Cheap — one more attribute and one label.

**Let the theme change what spawns, not just how it looks.** If a Workshop plot yields
different scrap at different values, converting is a real decision rather than a skin. This
is where the depth is.

**Do not delete the old theme's progress.** If converting resets anything a player earned,
they will not do it. Let them convert back and forth freely, or make it explicitly one-way
with a loud confirmation. Silent loss is the one thing that will hurt retention here.

**A conversion moment.** The plot swapping instantly is a wasted opportunity. A couple of
seconds of dust, a rumble, the old geometry dropping and the new rising — the same treatment
the egg hatch gets. This is the screenshot players share.

**Show the locked themes.** The structure for a theme you *cannot* afford should be visible
and silhouetted, like the undiscovered scrap in the index. Seeing the shape of what you are
missing is what makes the index work, and it will work here too.

**Theme-specific machines.** A Workshop plot with a machine the scrapyard does not have gives
each theme an identity beyond decoration, and gives you somewhere to hang future upgrades.

**Consider a fourth theme as a pass.** If themes are desirable, one exclusive theme is a
clean monetisation slot that does not touch balance — cosmetic-only, so it cannot be
pay-to-win.

---

## Risks worth knowing before starting

- **Swapping geometry under a standing player** is the sharp edge. Every service that resolves
  things by name under the plot must re-resolve after a swap. `PlotSignController` binds once
  on join; `ScrapService` holds live instance references.
- **Six variants times three themes** is eighteen plots of geometry to keep in step if you
  ever author per-slot differences. Keep variants generic and slot-agnostic.
- **The old area-region system has to be retired, not left alongside.** Two systems both
  claiming to own "areas" is how the shop ended up with a dead `Assets.Art` table nothing
  read.
