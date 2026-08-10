# Plot art direction — the three themes

Art brief for the three plot variants in `Workspace.PlotVariants`. Each one is the same
playable space wearing a different identity, and a player should be able to tell which theme
a yard is from across the map, from the silhouette and colour alone.

The mechanical contract lives in `docs/PLOT_UPGRADES.md`. This document is only about how they
look.

---

## The house style, measured off the existing plot

Everything already in the game is **flat `Plastic`, no textures, no reflectance**. Match that
or a new plot will read as imported from a different game.

| Element | Colour | Count on Plot01 |
| --- | --- | --- |
| `PlotFloor` | `#08A549` green | 1 slab, 130 x 1 x 170 |
| Fence rails | `#566D6F` steel blue-grey | 204 parts |
| Fence posts | `#242D3E` dark navy | 152 |
| Crusher body | `#7C5C46` brown | 144 |
| Trim greys | `#636063` / `#4D4D4D` | ~25 |

**`#566D6F` steel and `#242D3E` navy are the thread.** Every theme keeps them somewhere —
usually the fence posts and metal trim. They are what make three different-looking yards feel
like one game.

The UI palette is worth borrowing from, because it ties the world to the HUD:

| | Hex |
| --- | --- |
| Gold | `#FFD21C` |
| Orange | `#FF9A2B` |
| Green | `#72F000` |
| Cyan | `#21E5F5` |
| Purple | `#B530FF` |
| Ink (all outlines) | `#10131A` |

### One accent per theme

Grey plus **one** bright colour reads as designed. Two reads as clutter. Each theme below gets
exactly one.

### Escalation

The three themes are a progression, so each should feel like more work went into the yard than
the last:

1. **Scrapyard** — open dirt and grass, things left where they fell
2. **Workshop** — paved, painted, organised, everything has a place
3. **Vehicle Graveyard** — big, stacked, vertical, deliberately imposing

Read left to right that is: messy → tidy → *impressive*. The third should make someone on the
first want it.

---

## 1. Scrapyard Plot — the starting yard

`AreaId = "FrontYard"` · accent: **Green `#72F000`** · already built, this is the reference

**Identity.** A patch of ground someone dumped scrap on. Nothing is organised because nothing
has been earned yet. Its job is to be a fine starting point that looks plain next to the
others.

**Floor.** Keep `#08A549`. If you touch it at all, break the flat green with a few worn dirt
patches in `#7C5C46` at large scale — irregular, not a pattern.

**Fence.** Keep as-is. It is the reference every other fence should rhyme with.

**Props.** Sparse and random: a few oil drums, a tyre or two, one broken pallet. Deliberately
under-decorated — resist the urge to make the starter nice.

**Extras.** Nothing. This is the baseline.

---

## 2. Workshop Plot — the second tier

`AreaId = "WorkshopYard"` · accent: **Safety orange `#FF9A2B`**

**Identity.** Grass yard becomes a paved, painted, organised shop floor. The story is *someone
who takes this seriously works here*.

**Floor.**

| Role | Colour |
| --- | --- |
| Slab base | `#9BA3A8` |
| Second panel tone | `#8A9298` |
| Painted markings | `#FFC61E` |
| Hazard stripes | `#FFC61E` + `#242D3E` |
| Oil stains | `#3A3F45` at ~0.6 transparency |

Alternate the two greys in large squares so it reads as poured concrete sections rather than
tiles. Paint walkway lines and a hatched square around the crusher — painted floor markings do
more for "industrial" than any prop.

**Fence.** Chain-link panels and corrugated sheet in `#566D6F`, posts `#242D3E`, yellow caps on
the corner posts. **Keep the existing post spacing** so the silhouette still matches from a
distance. Built — see below.

**Hero props** — pick three or four, cluster them, do not scatter: workbench, pillar drill,
band saw, welding station, anvil, engine hoist, gantry crane, air compressor, rolling tool
chest.

**Supporting.** Tool rack, pegboard with tools, vice, wheelbarrow, work light, fire
extinguisher, warning signs.

**Scatter.** Oil drums, jerry cans, wooden pallets, cable reels, tyre stacks, toolboxes, metal
crates.

**Lighting.** The map has a night skybox, so this pays off more here than usual. Hanging shop
lights over the benches, a fluorescent strip inside the structure, `SpotLight`s on the hero
machines, one warm `PointLight` in the doorway.

**Particles.** See the section below — welding sparks are the signature effect for this one.

### Built so far

The floor, the cyan accent and the 460-part fence are Marko's. Everything below was added on
top of that, and follows his cyan `#38DBCF` rather than the orange this brief originally
proposed — one accent per theme, and the floor had already claimed cyan.

`WorkshopPlot.FloorMarkings` (27 parts, all `CanCollide`/`CanTouch`/`CanQuery` false so they
cannot trip `CrusherSellZone`'s Touched volume or the scrap overlap query):

- two cyan walkway lines, 116 studs from `PlayerSpawn` to the crusher
- a yellow `#FFC61E` hazard border around `CrusherSellZone` with 7 alternating diagonal bars
- two work-bay outlines near the back fence
- six oil stains

`WorkshopPlot.WorkshopProps` (196 parts, grouped as Models so a group can be moved as one):

| Group | What |
| --- | --- |
| `FabricationBay` | pegboard wall with nine hung tools, cabinet bench with cyan drawer lines, bench vice |
| `PillarDrill` | column drill standing at the bench end |
| `ToolChest` | the one bought asset — see below |
| `WeldingBay` | welding table, workpiece, welder unit, two gas bottles, an L-shaped screen |
| `StorageRow` | shelving rack, three pallets of plate stock, three crates, two cable reels |
| `DrumClusterEast` / `DrumClusterWest` | oil drums, one tipped on its side |
| `AirCompressor` | tank, motor, gauge |
| `ChimneyStack` | the landmark — 26-stud flue, tops out at y 50 against a fence top of 28.9 |
| `ShopLights` | two mast lights with warm `PointLight`s over the bays |
| `Safety` | two fire extinguishers |

Five emitters, all low-rate: weld sparks (`Rate` 26, short-lived, with a cold `PointLight`
flash), compressor steam, chimney smoke, and dust under each shop light.

`OwnerSign` is themed per the table below: steel post, bolted plate, and a hazard stripe
placed strictly **below** the board's bottom face so it can never cover the card.

#### The fence was rebuilt, and why

The imported kit was 356 parts across 77 nested Models with **every single part named `Part`**,
so nothing in it could be found or edited without hunting through the tree. It has been replaced
with an authored one at 290 parts — 66 fewer — grouped so any piece can be selected by name:

```
PlotFence
  PlotFenceDecorations   Marko's barrels and crates, left untouched
  WestRun / EastRun / NorthRunWest / NorthRunEast / SouthRun
      Panel   one per 7-stud bay
      Rib     one navy stiffener per bay
      Post    at every bay boundary
      CapRail one continuous part per run
      KickPlate  ditto
  CornerPosts   taller, with the yellow caps
  Gate          posts, hazard header, two sliding leaves, track
```

Post spacing is the kit's original 7 studs, measured off it before deleting, so the silhouette
still rhymes with the Scrapyard from a distance. 78 bays, panel top at 24.17, posts proud at
24.72.

Three things that made it work, all of which took a look at the render to find:

- **Corrugation for free.** Alternating each bay between `#566D6F` and `#617B7B` and stepping it
  0.1 studs in depth reads as ribbed sheet from any angle. Real rib parts per bay would have cost
  ~230 parts on their own.
- **Continuous cap rail and kick plate, one part per run** rather than one per bay. That single
  choice is most of the 66-part saving.
- **The cap rail must be navy, not steel.** A light top edge made the whole fence read as pale
  slats. Dark on top is the same heavy ink outline the UI kit puts on everything, and it is what
  makes the fence look solid and cartoony rather than washed out.

The first pass put cyan on the gate posts, the header, the leaves and the corner collars, plus
loose yellow blocks. It read as clutter. Yellow is now concentrated in one place — the gate
header — and cyan is down to a single band per gate post. **One accent, one place it shouts.**

#### The gate

The kit already left a 42-stud gap in the north run at x 1339–1381, centred on `PlayerSpawn`, so
that is where the entrance went. Gate posts at 7.2 studs, a yellow hazard header with navy
slashes across the top, and two leaves parked **open**.

The leaves slide along the *outside* face rather than swinging inward. Swinging them in was the
first idea and it clipped the `StorageRow` pallets; sliding them out keeps the 42-stud opening
walkable, touches nothing inside the plot, and still reads unmistakably as a gate.

The perimeter is verified closed: 78 panels, zero holes on any run apart from the gate.

**Part count is 867, not the ~700 this document targets.** The fence is 290 of that plus 104 of
Marko's decorations; the props are 196. If six Workshop plots on screen ever costs frames, the
cheapest win left is dropping the per-bay `Rib` parts (78) — the alternating panel tone and depth
step already carry most of the corrugated read on their own.

#### Check props against the named markers, not by eye

Two placements looked fine in the viewport and were wrong:

- the air compressor sat inside `AreaStructureSlots.WorkshopYard`, so the structure placed
  there at runtime would have grown straight through it
- a fire extinguisher clipped `PlayerSpawn`'s footprint

Neither is visible from a screenshot. The check that found them was
`workspace:GetPartBoundsInBox` over every prop, against each `Spawn_*` / `AreaSpawn_*` marker
(6-stud pad), each `AreaStructureSlots` part (10-stud pad), `CrusherSellZone` and
`PlayerSpawn`. Run it after any decorating pass — it is cheap and it is the only thing that
catches a prop growing into a marker's future contents.

Two smaller traps from the same pass: a vertical-extent check must use the part's **rotated**
world extent, because an upright `Part` cylinder has its length on `Size.X`, not `Size.Y` — the
naive check flagged three flush cylinders as sunk. And `ParticleEmitter.SpreadAngle` is a
`Vector2`, not a number.

#### The one bought asset

`132411241457896` — "Garage Tool Box Workbench Tools Mechanic", free, 47 parts, no meshes,
already anchored, 5.5 x 4 x 5 studs. It needed cleaning before it fitted: three bundled
`LightConfig` scripts deleted, and all 47 parts moved off `Metal` onto `SmoothPlastic`, because
`Metal` catches specular and reads as imported from another game next to the flat house style.

Most free-store searches for pallets, crates and drums returned junk or single textured
`MeshPart`s. Those are all faster to build from parts, and they match the palette exactly —
which is why everything else here is authored rather than bought.

#### Left to do

- The crusher is unthemed — deliberately, to avoid colliding with whatever `PlotBuildService`
  does to it per stage. Worth confirming before repainting it
- Nothing along the inside of the west and east fence runs; the middle of the floor must stay
  open for scrap
- No looping ambient `Sound` yet
- The gate leaves read as more fence at a glance. A stronger visual break between leaf and panel
  would sell the threshold harder
- None of this is verified in Play yet — Edit mode has been reliable for world geometry, but the
  emitters and the shop-light `PointLight`s have only been seen in Edit

---

## 3. Vehicle Graveyard Plot — the third tier

`AreaId = "VehicleGraveyard"` · accent: **Cyan `#21E5F5`**, used sparingly and only as light

**Identity.** Big, stacked, vertical. Where the workshop is tidy, this is *monumental* — car
bodies piled three high, a crane over the top, everything oversized. This is the plot people
should point at.

**Floor.**

| Role | Colour |
| --- | --- |
| Base dirt | `#5C4A38` compacted earth |
| Gravel patches | `#7A7368` |
| Tyre tracks | `#3E332A`, wide and curved |
| Standing water | `#2B3A3F` at ~0.5 transparency, flat and glossy |

Darker than both other floors on purpose. It makes the cyan lights and the pale car bodies pop,
and reads as heavier ground.

**Fence.** Tall corrugated sheet in `#566D6F` with visible rust patches `#8A4B2A`, navy posts,
and barbed wire or angled top rails. **Make it taller than the other two** — height at the
boundary is most of what makes this plot feel imposing from outside.

**Hero props.** Verticality is the whole trick: crushed car stacks (2–3 high), a car crusher or
baler, a magnet crane or gantry, a shipping container, a bus or truck shell.

**Supporting.** Wheel stacks, engine blocks, bumper piles, door piles, an oil tank, jersey
barriers.

**Scatter.** Hubcaps, exhausts, seats, windscreen glass shards, number plates.

**Lighting.** Sparse and cold. Two or three tall floodlight masts with cyan-white `SpotLight`s
pointing down and inward, deep shadow between them. Dark with pools of light beats evenly lit —
it is what makes it feel large.

---

## Particles and effects

Cheap, and the difference between a set and a place. Keep rates low: six plots are visible at
once, and this is the first thing to cost frames.

**Rules learned the hard way in the UI, which apply here too:**

- Prefer a **few looping emitters** over many. `Rate` 2–8 is plenty for ambience.
- Give every emitter a **`ParticleEmitter.Enabled` you can turn off** — you will want to.
- Do not rotate parts to fake effects; use the emitter's own `SpreadAngle`.

| Theme | Effect | Where | Settings |
| --- | --- | --- | --- |
| Scrapyard | Dust motes | Over the open floor | `Rate` 3, huge lifetime, near-zero speed, `#7C5C46`, transparency 0.85 |
| Scrapyard | Flies | Over a bin or drum | `Rate` 2, tiny size, erratic `Acceleration` |
| Workshop | **Welding sparks** | On the welding station | `Rate` 6 in bursts, `#FFC61E` → `#FF9A2B`, `Speed` 8–14, `SpreadAngle` 35, short lifetime, `Acceleration` `(0, -60, 0)` |
| Workshop | Steam / vent puff | Air compressor | `Rate` 1.5, white, transparency 0.8, slow upward drift |
| Workshop | Dust in the light beams | Under shop lights | `Rate` 2, white, transparency 0.9 |
| Graveyard | Cold mist at ground level | Across the floor | `Rate` 2, wide `Size`, `#2B3A3F`, transparency 0.88, very slow |
| Graveyard | Ember / ash rising | Near the crusher | `Rate` 4, `#FF9A2B`, slow upward, long lifetime |
| Graveyard | Crane spark shower | When the crusher fires | Burst on demand, not looping |

**One-off moments worth building:**

- **A conversion effect** when the plot changes theme — dust burst, a rumble, old geometry
  dropping and new rising. The player is already stood outside watching (the rebuild teleports
  them clear), so there is a captive audience. This is the clip people share.
- **A crusher flourish** — sparks and a `Sound` when scrap is sold, themed per plot.

---

## The sign

Every plot has an `OwnerSign`, and it is the one element that must stay recognisable across
all three — it is how a passer-by reads whose yard this is.

Current build: post `1.4 x 4.51` in `Glacier` brown, board `18 x 7 x 1` in `Plastic`
`#FF912D` orange with `Studs` surfaces. The card on it is cream `#FFE9B8` → gold `#FFC24A`
with a `#3A2412` outline.

**Keep the card exactly as it is on all three.** It is UI, not scenery, and it should look
identical everywhere for the same reason the HUD does.

**The post and board frame may be themed**, and that is a nice touch:

| Theme | Post | Board frame |
| --- | --- | --- |
| Scrapyard | Brown timber, as now | `#FF912D` orange, as now |
| Workshop | Steel `#566D6F` with a bolted plate look | Same orange, plus a yellow hazard stripe along the bottom edge |
| Graveyard | Heavy rusted girder `#8A4B2A` | Same orange, weathered, one corner dented |

**Do not** change the board's `18 x 7 x 1` size or rename `Board` — the card is aligned to that
face by measurement, and the rebuild aligns the plot by `PlotFloor`.

**Worth adding:** put the theme name on the sign. "MARKO'S VEHICLE GRAVEYARD" readable from
outside the fence is the cheapest possible amplifier for the envy loop — one attribute, one
label, and it makes the plot's tier legible at a glance.

---

## Extras that punch above their cost

- **A gate.** Give each fence a proper entrance rather than a gap. A gate reads as a threshold
  and makes the plot feel owned.
- **Theme the crusher.** Same machine, three paint jobs: rusty, orange-and-steel, industrial
  cyan-lit. Cheap continuity that sells the progression.
- **Ground decals under props.** A dark patch under every heavy object stops things looking
  like they are floating, which is the single most common tell of a pasted-in model.
- **One oversized landmark per theme**, visible above the fence line: workshop chimney,
  graveyard crane. It is how a player picks a plot out from across the map.
- **Sound.** A quiet looping `Sound` per theme — workshop machinery hum, graveyard wind and
  creaking metal — with `RollOffMaxDistance` tight enough that it does not bleed between plots.
- **Silhouette the locked structures.** The structure for a theme a player cannot afford should
  be visible but blacked out, the way undiscovered scrap works in the index. Seeing the shape of
  what you are missing is what makes that grid work, and it will work here.

---

## Build checklist

Per plot, before you call it done:

- [ ] Everything **anchored** — imported models are usually not, and they fall the instant Play
      starts
- [ ] Materials `Plastic` / `SmoothPlastic` only
- [ ] `PlotFloor` still named that, still one slab (the rebuild aligns the whole plot by it)
- [ ] `ScrapSpawnLocations`, `CrusherSellZone`, `PlayerSpawn`, `OwnerSign`, `RuntimeObjects`,
      `Boundaries.PlotBounds` all present and unobstructed
- [ ] `AreaStructureSlots` holds a part per non-default area, clear of props
- [ ] Middle of the floor left open — that is where scrap spawns and players run
- [ ] Part count in the region of **700** (Plot01 is 696, and six plots exist at once)
- [ ] Emitter rates low, and every emitter easy to find and disable

I can measure any of the last four for you once a plot is built — part count, unanchored parts,
anything overlapping a spawn marker, and whether the required children survived.
