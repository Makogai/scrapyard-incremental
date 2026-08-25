# Scrapyard Incremental Studio Setup

## Connect Rojo

1. Run `.\rokit.exe install` once, restarting the terminal if tool shims are not yet on `PATH`.
2. Run `rojo serve` from the repository.
3. Open the Roblox Studio place and connect the Rojo plugin to `localhost:34872`.
4. Inspect the sync diff before accepting it. Rojo owns code/configuration but preserves unknown instances in Workspace and StarterGui.

## Phase 0 Smoke Test

1. Stop any running Play session so removed legacy scripts are no longer active.
2. Reconnect/sync Rojo, then start Play.
3. Confirm Output contains `Scrapyard Incremental` server and client bootstrap messages with no errors.
4. No Scrapyard gameplay or UI should appear yet; that is correct for the neutral reset.

## Phase 1 Foundation Test

1. Sync Rojo and start a fresh Play session.
2. Confirm both Scrapyard bootstrap messages appear and no configuration assertion fires before the server message.
3. Expand `ReplicatedStorage/Shared/Config` and confirm ScrapConfig, UpgradeConfig, AreaConfig, PrestigeConfig, and Environment are present.
4. Expand `ReplicatedStorage/Remotes` and confirm the state, notification, effect, upgrade, area, prestige, and settings remotes exist with the expected classes.
5. No money, storage, scrap, UI, or DataStore behavior should exist yet.

## Manual Legacy Cleanup

Rojo intentionally does not delete Studio-authored Workspace or StarterGui content. In edit mode, delete these old prototype objects if present:

- `Workspace/Plots`
- `Workspace/HeatwaveArena`
- `StarterGui/MainUI` when it contains Snowflakes, Frost Gems, Snowman collection, merge, raid, rebirth, or Heatwave controls

Keep personal terrain, lighting work, unrelated models, and any assets you intentionally added. Save or publish the place after cleanup. Future Scrapyard map and UI objects remain directly editable in Studio.

## Build and Checks

- Format: `stylua src tests`
- Lint: `selene src`
- Build: `rojo build default.project.json -o scrapyard-incremental.rbxlx`
- Pure tests: `lune run tests/run.luau`

DataStore API access is not needed until Phase 2. When it is introduced, use a published test experience and the separated development store; never test against production data by default.

## Phase 2 Player Data Test

Phase 2 always selects `ScrapyardIncremental_Development_v1` while running in Studio, even if the production configuration flag is false.

1. Publish the test place, then enable **Game Settings > Security > Enable Studio Access to API Services**.
2. Start Play and confirm Output reports `[DataService] Using development store` followed by both Scrapyard bootstrap messages without errors.
3. Confirm `StarterGui/ScrapyardUI` is cloned into `PlayerGui`, its loading panel disappears after the session loads, and money/storage show `$0` and `0 / 20` for a new player.
4. Change test data through a temporary server command or a later gameplay phase, stop Play, rejoin, and confirm money, storage, upgrades, areas, discoveries, settings, and timestamps round-trip.
5. Disable API access (or use an unpublished copy), start Play, and confirm four bounded load attempts occur, the player receives the safe-load kick, and no default session is saved.
6. Start two Studio servers for the same account/session where practical and confirm the second live claim is rejected until the first session releases or its lease expires.

Do not enable production-store testing from Studio. Successful DataStore round-trip validation remains manual because it requires a published experience and account-level API access.

## Studio-authored UI Foundation

`StarterGui/ScrapyardUI` is an authored instance tree seeded from **Epic UI Pack by MapelMarvel**. Panels, currency art, the storage progress bar, and navigation buttons come from that pack. Rojo preserves this tree and only synchronizes controller code. Keep these stable binding names when editing visuals:

- `SafeArea/LoadingPanel`
- `SafeArea/TopBar/MoneyPanel` and `GearsPanel`

## Egg summon podiums

Each area egg is its own site. `PetService` binds a hold-E prompt to the highest part
of that site, and `EggHologramController` dresses its egg.

The names that count (Folder or Model, anywhere under `Workspace.NewMap`):

```
NewMap
  FrontYardEggGroup            Junkyard Egg (Pup, Zebra, ...)
    Egg
    Stand
  WorkshopYardEggGroup         Workshop Egg
  VehicleGraveyardEggGroup     Quantum Egg
```

The group name is the egg: `FrontYard` → Junkyard, `WorkshopYard` → Workshop,
`VehicleGraveyard` → Quantum. You can also set an `EggId` attribute or StringValue
(`JunkyardEgg` / `WorkshopEgg` / `QuantumEgg`) if you want to override the name.

A leftover Model named `EggSummonPodium` still works when it does not contain groups.
Do not put one prompt on a parent that wraps all three eggs -- that is what made only
the tallest egg hold-E, and always open the Junkyard roster.

The hologram wants, inside each group:

```
FrontYardEggGroup
  Egg                         -- Model or BasePart, the thing that floats
  Stand                       -- left alone
```

The egg is found by name (something containing "egg", excluding stand/base/group/podium/plinth/pedestal),
falling back to the largest child model. Nothing is required: a podium that does not match is skipped
silently rather than erroring, so a half-built podium never breaks a playtest.

Two optional attributes, on the group or the podium, retune it without touching code:

| Attribute | Type | Effect |
| --- | --- | --- |
| `HologramColor` | Color3 | Tint of the rim, the light shaft and the motes |
| `HologramFloat` | number | Bob amplitude in studs; `0` pins the egg still |

The effect is client-only, so the egg's real position and collision never move -- which is why the
prompt anchored to it keeps working while it floats.
- `SafeArea/StoragePanel/StorageBar/Foreground/Fill`
- `SafeArea/Navigation/*Button`
- `SafeArea/Menus/*Menu/CloseButton`

The controller must bind these instances; it must not recreate the production UI tree at runtime.

## Phase 3 Core Loop Test

1. Start Play at `Workspace/SpawnLocation`. Confirm the authored Front Yard creates up to 18 active scrap objects and the first eligible can, bolt, or plate attracts within five seconds without clicking.
2. Confirm starter Magnet Strength 4 ignores tires (required strength 6), while nearby eligible scrap arcs toward the character and updates the authored storage meter.
3. Fill storage to 20 weight, remain near additional scrap, and confirm no further attraction/reservations begin. Walk onto the assigned plot's `CrusherSellZone` and confirm storage clears and money increases once.
4. Remain on/re-enter the sell pad with empty storage and confirm money does not increase again. Stop and rejoin; confirm nonzero money and any remaining stored weight/value persist.
5. In **Test > Clients and Servers**, start one server with two clients. Move both clients toward the same object and confirm exactly one receives it; confirm each HUD/storage state is independent. Repeat while one player is full.
6. In Device Emulator, test phone portrait, phone landscape, and tablet. Confirm movement alone collects scrap, the joystick does not overlap the storage/navigation controls, labels remain readable, and the menus still scroll.
7. In Developer Console/Script Performance, confirm collection uses the single bounded ScrapService query loop. Active scrap must not exceed the configured cap, and there must be no per-scrap heartbeat or full-Workspace scan.

Phase 3 geometry now lives inside the 12 Studio-authored `Workspace/Plots` slots; shared scrap templates remain under `ServerStorage/ScrapModels`. Keep stable plot attributes and child names when editing appearance.

## Plot Architecture Validation

1. Confirm `Workspace/Plots` contains exactly `Plot01` through `Plot12`; each is 130x170 and exposes the hierarchy documented in `plan/PLOT_REFACTOR.md`.
2. Confirm the published experience's server-size setting is 12. `Environment.MaximumPlayers` and `PlotConfig.PlotCount` both fail startup validation unless they match at 12, but the Roblox experience setting must also be configured in Game Settings.
3. Start Play. Confirm the first available plot receives `OwnerUserId`, the player teleports to its entrance, the owner billboard shows the real avatar/display name/saved stage/prestige/total scrap, and exactly 14 starter scrap spawn under that plot's `RuntimeObjects/ActiveScrap`.
4. Confirm every active scrap has matching `PlotId` and `OwnerUserId`. Walk through another slot: it must have no active scrap while unassigned, and its crusher must not sell the visitor's nonzero storage.
5. Stop/rejoin and confirm physical plot assignment is not saved, while money, storage, discoveries, plot stage, crusher level, plot upgrades, theme/customization, trophies, prestige count, and unlocks migrate/load safely.
6. In **Test > Clients and Servers**, run at least two clients. Confirm they receive different slots, cannot attract each other's scrap, cannot sell at each other's crusher, can walk through each other's plots, and releasing one client clears its runtime folder/sign before the slot can be reassigned.
7. Run a 12-client soak when practical. Confirm no more than 28 active scrap per plot, one shared bounded query loop, anchored decorations, stable server frame time, and cleanup of all released-plot instances/connections.

The former shared-yard `Map` and `Gameplay` objects are archived under `ServerStorage/RefactorArchive` for recovery and must remain outside Workspace.

## TopbarPlus

TopbarPlus is a **Studio-authored Roblox package**, not a Wally dependency: it has a
`PackageLink`, so it updates through Studio's package system and must not be copied
into the Rojo tree. Rojo only manages `ReplicatedStorage.Packages` and
`ReplicatedStorage.Shared`, so its folder is preserved across syncs.

Expected place state:

1. `ReplicatedStorage/TopbarPlus/Icon` — the package. Moved here from `Workspace`,
   which is where the asset drops it. `Icon` writes a reference object into
   `ReplicatedStorage` on first require so duplicate copies cannot both run.
2. `ReplicatedStorage/TopbarPlus/READ_ME` — **must stay `Disabled`**. It is a
   `Script` with `RunContext = Client`, so it runs wherever it is parented and
   would add an "Example" icon to the live topbar.
3. `ServerStorage/ThumbnailCamera` — a Studio-only helper for rendering icon
   images. Moved out of the replicated folder; harmless, and not needed at runtime.

`client/Controllers/TopbarController` registers the icons and degrades to a warning
if the package is missing, so a fresh clone without it still boots. To verify: Play,
then confirm `UPDATES` sits at the far left of the topbar and `INDEX` / `SETTINGS`
at the right, and that clicking one opens its window and clicking it again closes it.

## Pet and Egg Models

One folder per egg under `Workspace.Pets`, named after the egg's `DisplayName`:

```
Workspace/Pets/
  Junkyard Egg/
    Egg                     <- the egg itself
    Pup                     <- Common
    Zebra                   <- Uncommon
    Queen Kitty             <- Rare
    Pastel Angel            <- Epic
    Autumn Dragon           <- Legendary
    Mythic Autumn Dragon    <- Secret
```

Model names must match `ModelName` in `Shared/Config/PetConfig`. `PetService`
publishes them at server start into `ReplicatedStorage.PetModels` (keyed by pet id)
and `ReplicatedStorage.EggModels` (keyed by egg id), then moves `Workspace.Pets`
into `ServerStorage` so the source models never ship to clients. The UI renders from
those two folders only — nothing reaches into Workspace.

Consequences worth knowing:

1. **An egg with no `Egg` model gets a generated placeholder** and a warning. The
   summon flow still works; the egg is just an obviously-unfinished spheroid.
2. **A pet whose model is missing renders its fallback glyph.** No error, so check
   the warnings if a slot looks wrong.
3. **In Edit mode those folders do not exist** until the place has been played once
   since the last sync, because publishing happens on server start. A story
   previewing pets in Edit mode therefore shows glyphs — that is the degraded state
   working, not a bug.
4. Renaming a pet in `PetConfig` without renaming its model leaves it with nothing
   to render. `PlayerDataSchema` version 11 carries the old Junkyard ids across, so
   a rename does not cost players their pets, but a new rename needs the same
   treatment.

Egg podiums are map geometry: a Folder or Model named `<Area>EggGroup` anywhere under
`Workspace.NewMap` (`FrontYardEggGroup`, `WorkshopYardEggGroup`, `VehicleGraveyardEggGroup`).
`PetService` attaches the hold-E prompt itself, so no authored prompt is needed. The group
name picks the egg; an `EggId` StringValue or attribute overrides it. A model named
`EggSummonPodium` is only used when it is not already inside one of those groups.

## The richest-player pedestal

`NewMap.RichestPlayer` shows a statue of whoever currently holds the most cash.
`RichestPlayerService` rebuilds it only when the winner changes, dances it on a loop
and turns it slowly in place.

What it needs in the tree:

```
NewMap.RichestPlayer                 attributes live here
  CharacterPedestal (Model)          what the statue stands on
    Pedestel                         the disc; its top is the stand surface
    Tablet1, Tablet 2, Tablet 3, ..  plaques; a space in the name is fine
      <MeshPart>
        PlaqueSurface (Part)         <- MOVE THIS to reposition a plaque
          RichestPlaque (SurfaceGui)
            Header / PlayerName / Cash
  DisplayCharacter (Folder)          the statue is parented here
  EditorPreview                      standing placeholder, destroyed at runtime
```

### Positioning the plaques

Each tablet carries a thin almost-invisible `PlaqueSurface` part with the SurfaceGui on
its top face. **Select and move those four parts** — position, rotation and size are all
yours, and the service leaves an authored plaque completely alone. Verified: a plaque
swung 12 degrees and squashed to 80% came back from Play untouched.

What the service does with them:

| What it finds on a tablet | What it does |
| --- | --- |
| `PlaqueSurface` with a complete `RichestPlaque` | reuses both, only writes the text |
| `PlaqueSurface` with no or a partial GUI | keeps your part, rebuilds just the GUI |
| neither | builds both from the geometry rules |

So restyling the labels by hand survives too, as long as `Header`, `PlayerName` and
`Cash` all still exist. Delete a `PlaqueSurface` and it comes back computed, which is the
way to reset one you have pushed too far.

**Keep a plaque at least ~0.1 studs clear of the tablet mesh.** Laying one perfectly
flush looks right in Edit and then fails to render in game from most camera angles. This
is not a subtle artifact you can tune away: a plaque measured 0.0036 studs inside the
mesh drew nothing with `ZOffset` at 0.2, nothing with `AlwaysOnTop` forced on, and
nothing with an opaque magenta frame filling the canvas — while every property read
correct on both the server and the client. Move it 0.15 clear along its own normal and it
draws from everywhere. The part has to physically escape the mesh; no property does it.

The four current plaques share one hand placement: tilted 35.46 degrees to lie on the
tablet's sloped face, 3.33 x 5.14 studs, lifted 0.15 clear. If you re-tune one and want
the others to follow, copy its transform *relative to its own tablet* — a frame with +X
pointing outward from the pedestal, +Y up — and apply that same relative transform on the
other three. Copying world CFrames directly will not work, because each tablet faces a
different way.

### The Edit-mode placeholder

`EditorPreview` is a baked avatar rig standing where the real statue will: same 5x
scale, same disc, soles on the same target height, so it shows the footprint (26 studs
wide) and the height (30 studs) the winner will actually fill. It is anchored and
non-colliding, and the service destroys it on start, so it costs nothing at runtime.

If you move the pedestal, move the preview with it — nothing repositions it
automatically, because it is a design reference rather than something the game reads.

Nothing beyond those names is matched by path. The stand height is the top of the
`Pedestel` part, and each tablet's outward face is derived from geometry — so the
pedestal can be moved, rotated or rebuilt and it still works. Any child named
`Tablet<n>` gets a `RichestPlaque` SurfaceGui built on it at runtime reading RICHEST
PLAYER / name / cash; there is no authored GUI to keep in sync, and adding a fifth
tablet needs no code change.

Three things to know before editing the model:

1. **Anchor every part.** An imported model usually is not, and unanchored the
   pedestal's own parts collide with each other the instant Play starts and drift
   apart — measured once at 69x5x83 studs from an authored 32x3x32, with the statue
   positioned against a moving surface and ending up 13 studs under the disc. The
   service anchors what it finds and warns, but fix it in the model.
2. **The tablets are flat plaques recessed into the disc.** Their largest face is the
   top, and their tops sit 0.044 studs *below* the disc's, so a plaque laid straight on
   a tablet is inside the disc geometry. The service lifts each one clear
   (`PLAQUE_CLEARANCE`) onto a thin aligned helper part named `PlaqueSurface`. If you
   restyle the tablets — standing them up as signs, for instance — the code follows the
   geometry and needs no change.
3. **The statue stands flush automatically.** The soles are aligned to the disc every
   frame, so it holds for any avatar, scale, rig or accessory. `HeightOffset` is a
   deliberate art nudge on top of that, not the correction: it is `-1.05`, chosen as the
   median of the dance's 2.2-stud foot travel so the statue reads as planted rather than
   touching down for one frame per cycle. At `0` it was technically flush and visibly
   floating 99% of the time.

Three Roblox behaviours this fought, all worth knowing before you touch the plaque code:

- **`Model:ScaleTo` does not re-pose limbs in the same frame.** Measure the feet
  straight after it and you get their unscaled offsets. Wait a Heartbeat.
- **A rotated GuiObject is not clipped or composed predictably.** Rotating a
  `SurfaceGui`'s contents to suit which side of the pedestal a tablet is on made plaques
  render or not depending on the camera. That is why the orientation is done in world
  space with an aligned part instead, and nothing in here rotates a GuiObject. Same
  rule as AGENTS.md rule 11.
- **A part at `Transparency = 1` does not draw its SurfaceGui.** The helper part is
  `0.99`, which looks identical and renders.

Attributes on `RichestPlayer`: `DanceAnimationId` (required), `AvatarScale` (5),
`HeightOffset` (0), `RotationSeconds` (10). `LabelOffset` is legacy and only affects
the optional `WinnerBillboard`.

The legacy `Podium` part and its `WinnerBillboard` are no longer the stand. They are
left in place and the billboard is still kept up to date if present, but the pedestal
replaced them — and `Podium`/`SpotlightRig` sit about 40 studs from where
`CharacterPedestal` is now, so the spotlight no longer points at the statue.

## Scrap models, per rarity

Scrap art is authored in `Workspace.Scraps`, one folder per scrap type, one model per
rarity inside it:

```
Workspace.Scraps
  Can                     the type folder
    NormalMetalCan        rarity prefix + whatever you want to call it
    RareMetalCan
    EpicMetalCan
    LegendaryMetalCan
    NebulaMetalCan
  LooseBolt/  SmallMetalPlate/  Tire/  ...
```

**A model's own part colours and its ParticleEmitters are the rarity treatment.**
`ScrapService` clones the model and leaves the look alone — it does not tint a part or
add an emitter when authored art exists. Colour the mesh and parent the emitters however
you like; that is what shows up in game.

How the matching works, so adding a type is a Studio job and not a code change:

- **Rarity comes from the model name's prefix**, checked against
  `ScrapConfig.VariantOrder` (`Normal`, `Rare`, `Epic`, `Legendary`, `Nebula`). So
  `EpicMetalCan` is the Epic variant of its folder. A model with no rarity prefix is
  ignored and named in the startup log.
- **The folder is matched to a scrap id** by `ModelName` then `Id`, allowing either to
  be a suffix of the other — which is what pairs the `Can` folder with the `MetalCan`
  scrap with no lookup table. Exact names always win. If the suffix rule finds more than
  one candidate the folder is refused rather than guessed at, and says so.
- **A folder may carry a `ScrapId` string attribute**, which overrides all of the above.
  Use it when a folder name has nothing in common with the config id.

**Partial sets are fine.** A scrap type with no authored folder — or a rarity you have
not made yet — falls back to the single generic model in `ServerStorage.ScrapModels`
plus a procedural tint and sparkle. `Tire` currently has only `NormalTire`; its other
four rarities use the fallback. So the set can be filled in one model at a time.

Two things the service does to the folder at startup, both deliberate:

1. **It moves `Workspace.Scraps` to `ServerStorage`.** Templates in Workspace replicate
   to every client and are visible to anyone who goes looking. Authoring in Workspace
   stays convenient because Play never saves.
2. **It anchors every part on the way out.** Measured, most of these were unanchored, so
   they fell the instant Play started — the same trap the pedestal had.

Read the startup line to see what it made of your folders:

```
[ScrapService] ScrapVariants: indexed 4 scrap type(s): Can -> MetalCan (5/5),
  LooseBolt -> LooseBolt (5/5), SmallMetalPlate -> SmallMetalPlate (5/5), Tire -> Tire (1/5)
```

Anything it could not place is listed there too, with the reason. Nothing fails silently,
because a mis-named folder otherwise just leaves the scrap looking like it always did.

### Scrap icons in the Index

The COLLECTION index draws the real 3D scrap model in a ViewportFrame rather than a
glyph. A discovered entry shows the highest rarity it has been found at; an undiscovered
one shows the same model blacked out, so the grid tells you the shape of what you are
missing.

That needs the models on the client, and the authored folder is in ServerStorage where
the client cannot see it. So `ScrapVariants.PublishPreviews` copies them to
`ReplicatedStorage.ScrapPreviews`, named `<ScrapId>_<VariantId>` for authored art plus a
plain `<ScrapId>` from the generic model. The index asks for its best rarity first and
falls back to the plain name, so every scrap type draws something even with no art. The
copies have their ParticleEmitters and Highlights stripped -- a ViewportFrame renders
neither, so carrying them would replicate particle data for no picture.

Two consequences worth knowing:

- **A Nebula preview reads dark.** Those models are nearly black and rely on their
  emitters for the look, and emitters do not render in a ViewportFrame. The rarity is
  still legible from the cell's coloured stripe. Tell me if you would rather the index
  showed a lower tier instead.
- **UI Labs shows glyphs, not models.** Publishing happens on the server at runtime and a
  story has no server, so the cells degrade to their glyph there. Review the 3D framing
  in Play.

### How big a scrap model is, and which way it faces

**Studio decides. Both of them, completely.** `ScrapService` clones the template and stands it on
its marker at exactly the size and rotation it was saved at. So the loop is: select the model in
`Workspace.Scraps` (above — one folder per scrap type, one model per rarity), scale it, rotate it,
and that is what spawns. Nothing in code or config normalises it.

Verified live: all five scrap types on a running plot came out identical to their templates in both
size and rotation, and every underside landed at exactly the same height.

This replaced a data-driven scheme, and the swap is worth understanding so nobody rebuilds it.
`ScrapConfig` used to carry a `Size` footprint that every model was uniformly scaled to, a
`ModelScale` multiplier on top, and a `ModelRotation` correction for art exported on the wrong axis.
It worked, and it was still the wrong shape: the only way to change how a piece of scrap looked was
to edit a number, restart, and go and look at it — and because the spawner flattened every model
onto its marker's orientation, rotating a model in Studio did nothing at all. **All three fields are
deleted, not deprecated.** If you go looking for a size field, there isn't one, and that is the
point: two things claiming to control the same size is how art ends up wrong with no obvious culprit.

**Anchor every part of a template.** This is not a style note, it is the difference between the model
you made and the model that spawns. An unanchored template part falls the instant Play starts —
`ScrapVariants.Load` anchors them, but only once it runs, and by then a multi-part model has already
collapsed. `NormalBrokenAppliance` is 65 loose MeshParts with no welds: it measured 3.79 × 6.22 × 2.95
in Studio and 1.97 × 3.22 × 1.53 in game, as a heap on the floor. That was the "broken appliance is too
small" report. Worse, the falling pieces shoved the *neighbouring* `NormalEnginePart` apart even though
that model was itself fully anchored, so it spawned at 56% of its authored size. 108 parts across
`Workspace.Scraps` and `ServerStorage.ScrapModels` were unanchored and now are not.

### Scatter, piles and poses

**A marker is a pile anchor, not a spawn point.** Each one holds several pieces, scattered inside a
disc, each turned to face anywhere and leaning a few degrees. All of it is derived from the marker's
distance to its nearest neighbour, so density follows the room you left when you placed them — see
`PlotConfig.ScrapPerMarkerDivisor` and `ScrapJitterFraction`. The Front Yard's markers sit 21–27 studs
apart and get 5 pieces each; the Workshop's tightest pair is 5.7 studs apart and gets the floor of 2.

Placement refuses to put two pieces inside each other: a candidate spot is scored against every piece
already on the plot using both footprints, and a crowded pile reaches progressively further out until it
finds room. It also raycasts for the real floor under the jittered point, so a piece can rest on a
pallet or a welding table rather than hovering at the marker's height — and if it has wandered somewhere
structurally different (a container roof, a pit) it goes back to the marker instead.

The lean is capped by a distance, not an angle: `MAXIMUM_TILT_LIFT_STUDS` (0.28) limits how far a
piece's far edge may come off the floor, so a small can gets the full 7° and a 12-stud scrap car gets
almost none. Measured live, the worst height a lean added to any piece was +0.29 studs.

**`TumbleChance` is an attribute on the model.** Set it in Studio, per model, and that fraction of
spawns arrive knocked onto their side instead of the way you posed them — 0.45 on cans, 0.35 on bolts
and exhaust pipes, 0.4 on buckets, 0.3 on toolboxes, 0.25 on fuel tanks. Nothing lists these in code:
posing a piece of scrap and saying how reliably it stays posed are the same job, done in the same place.
A yard of cans all perfectly upright is the tell that nothing ever knocked one over.

**Rarity variants fall back to the Normal art, not to a box.** Only three scrap types have art for all
five rarities. The other fifteen used to drop to the generic template for a Rare or Epic roll, which for
most types is a plain `Part` with a name label — a blue cube reading "APPLIANCE" in a yard of hand-made
models, at roughly 4% of spawns. Now they clone the Normal model and wear the rarity highlight and
emitter over it.

**What the art measures today**, longest axis in studs, measured live off the `Normal` models. A
default R15 character is about 5 studs tall, so the six at the top are the ones that read as
oversized in the yard — they are the resize list:

| model | authored size | longest |
| --- | --- | --- |
| NormalScrapCar | 12.14 × 2.75 × 4.85 | **12.14** |
| NormalFuelTank | 10.03 × 3.43 × 3.80 | **10.03** |
| NormalAxle | 3.49 × 2.62 × 9.38 | **9.38** |
| NormalMotorCoil | 2.00 × 5.30 × 2.00 | **5.30** |
| NormalRustyPipe | 1.00 × 5.21 × 1.92 | **5.21** |
| NormalRadiator | 0.94 × 3.22 × 5.01 | **5.01** |
| NormalCopperWire | 2.94 × 0.63 × 4.30 | 4.30 |
| NormalMetalSheet | 4.05 × 0.23 × 3.25 | 4.05 |
| NormalCarDoor | 1.93 × 3.49 × 3.24 | 3.49 |
| NormalToolBox | 1.32 × 1.19 × 3.30 | 3.30 |
| NormalBrokenAppliance | 1.97 × 3.22 × 1.53 | 3.22 |
| NormalMetalCan | 1.39 × 3.08 × 1.40 | 3.08 |
| NormalTire | 3.00 × 1.03 × 3.01 | 3.01 |
| NormalExhaustPipe | 1.44 × 0.77 × 2.99 | 2.99 |
| NormalCrushedBucket | 2.69 × 2.14 × 2.44 | 2.69 |
| NormalLooseBolt | 2.12 × 2.42 × 1.84 | 2.42 |
| NormalBrakeDisc | 2.31 × 0.45 × 2.31 | 2.31 |
| NormalEnginePart | 1.96 × 1.30 × 1.27 | 1.96 |

Nothing in the list is *wrong* any more — it is just art, and the numbers are what you are now free
to change directly. The rarity variants of a scrap are separate models, so resizing `NormalMetalCan`
does not resize `EpicMetalCan`; scale the whole type folder's contents together.

**Height is the one thing still computed**, because the marker decides where a piece stands and only
the model knows how tall it is. The model's box is measured and its underside placed on the marker's
top surface, plus `SCRAP_HOVER` (0.06 studs, enough to stop a flat model z-fighting the plot floor).
The old code added a flat 1.5 studs to the marker's centre, which floated a bolt and buried a car
door. Verified at exactly +0.0600 on every live piece.

That measurement is a **world** box built from every part's eight rotated corners, not
`Model:GetBoundingBox()` or `GetExtentsSize()`. Both of those align to the model's `PrimaryPart` when
it has one — a *local* box — so the moment a model is saved at an angle they report the wrong height:
the metal plate floated 1.11 studs and the crushed bucket sank 0.16 before this was fixed. This
matters much more now that models keep their authored rotation.

Position is measured rather than computed for the same reason the richest-player statue is:
`PivotTo` positions the *pivot*, and on an imported model the pivot is wherever the exporter left it,
not the centre of the geometry.

### The one number that can still override your art

`RUNAWAY_SCRAP_STUDS = 24` in `ScrapService`. It is a sanity net, not a knob: a piece measuring more
than 24 studs on any axis is scaled down and warned about by name.

It exists because **Roblox rewrites a `MeshPart`'s `Size` when its mesh asset resolves**, which can
land several frames after the clone is placed — so what a model measures at spawn is not always what
it measures a moment later. When that goes wrong the numbers are absurd rather than merely wrong, and
a piece that size parks itself inside every collection radius and gets rejected on every magnet
query, which is what once spammed the magnet warning across the whole screen.

24 is far above anything deliberate — a car door at 4 studs, a whole scrap car at 12, are untouched —
so in practice it only ever fires on broken art. **Seven generic models fire it today and want fixing
in Studio:**

| scrap | generic model resolves to |
| --- | --- |
| ToolBox | **1739 studs** |
| BrokenAppliance | 1130 |
| CarDoor | 1125 |
| CopperWire | 966 |
| Radiator | 745 |
| BrakeDisc | 414 |
| Tire | 11 |

`ScrapService` warns once per scrap id with the measured figure, so this table regenerates itself
every session — check the output window after a Play test. (Tire at 11 studs is under the net, so it
spawns at 11 studs. That is the new contract working as designed: fix it in Studio.)

`ScrapService` also connects to `GetPropertyChangedSignal("Size")` on every `MeshPart` under a piece
of scrap and re-grounds it whenever one changes, plus once on the next frame, so late-resolving art
does not end up hovering. Event-driven, no polling, and the connections are dropped on `Destroying`.

## Plot owner signs

Each plot's sign carries the owner's card as **authored instances** in the place file, and
the code only fills in values. What you see in Edit is exactly what ships -- there is no
React and no separate preview to drift out of sync.

```
Plot0N.OwnerSign
  Board                      <- server writes the data as attributes on OwnerSign
    PlotSignPlate              Occupied / OwnerUserId / OwnerName
      PlotSignSurface          Rebirths / Money / TotalScrap / Stage
        Card                 <- EDIT THIS FREELY. Colours, fonts, spacing, all yours.
          AvatarWell.Avatar    ImageLabel; gets the headshot
          OwnerName            TextLabel
          Stats                hidden on a free plot
            Rebirths.Value     TextLabel
            Cash.Value
            Scrap.Value
  Post
```

`PlotSignController` writes text into those named children and one image into `Avatar`.
Rename or delete one and it is skipped with a warning; restyling needs no code change.
`PlotService` refreshes the numbers every 3 seconds, and attributes only replicate when a
value actually changes.

### The 0.2-stud rule

The card sits on a thin near-invisible `PlotSignPlate` **0.2 studs off the board's face**,
not on the board itself. That is not a preference, it is what renders:

| where the SurfaceGui was | result in game |
| --- | --- |
| on the `Board` face directly | did not draw at all |
| plate 0.06 off the face | did not draw |
| plate 0.20 off the face | draws, and reads as flush |

All three rendered correctly in Edit, which is what makes this worth writing down -- Edit is
not a reliable check for whether a world SurfaceGui will draw. Two related traps already
cost time on the pedestal plaques: a part at `Transparency = 1` does not draw its SurfaceGui
at all (these plates are `0.99`), and `ZOffset` will not rescue a GUI that is too close to
geometry behind it.

The **post was moved 0.3 studs back** so it sits behind the board's face. It used to stand
0.2 proud and cut a strip out of the middle of the card, which is why the card used to float
half a stud out in front.

### If you redesign a sign

- Edit one plot's `Card`, then clone the whole `OwnerSign` to the other five rather than
  editing six copies. Copying a few properties misses things like per-face surface types.
- The plate is yours too: move or resize it and the canvas follows. The controller only
  builds one if none exists.
- All six are currently identical: post 1.4 x 4.51 in Glacier, board 18 x 7 x 1 in Plastic
  with `Studs` surfaces, plate 17.3 x 6.3 at 0.70 from the board centre, card 692 x 252.

### The floating marker

One client-side `YOUR PLOT` label above your own plot's floor only (`MARKER_HEIGHT`, 14
studs). Anchored to `PlotFloor` rather than the plot's bounding box -- the box takes in the
fence and crusher and came out nearly 400 studs tall, which put the marker 213 studs up.
