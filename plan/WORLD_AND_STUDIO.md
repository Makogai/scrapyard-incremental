# World and Studio Authoring

## Ownership

Studio owns Workspace terrain, lighting art, props, machines, gates, spawn markers, and scrap model templates. Rojo owns scripts/configuration and preserves unknown Workspace instances. This lets the developer edit terrain and visuals normally without runtime reconstruction.

## Authored Workspace Contract

```text
Workspace/
  Plots/
    Plot01 ... Plot12/
      Boundaries/
      PlayerSpawn
      Entrance/
      OwnerSign/
      MachineLocations/
      CrusherSellZone
      ScrapSpawnLocations/
      DecorationLocations/
      ExpansionAreas/
      TrophyLocations/
      RuntimeObjects/
  SharedHub/
```

The 12 slots are 130x170 studs, grouped as three plots on each of four short streets. North, east, south, and west districts face inward toward a 156-stud central plaza, avoiding a single long row while preserving at least 34 studs lateral separation. Every plot keeps the same authored local front/back contract after rotation. Crushers are local X=0/Z=58, leaving 27 studs of back clearance. Markers and runtime scrap carry `PlotId`, `OwnerUserId`, type, variant, and reservation identity. Sell zones and bounds are anchored nonvisual query parts. Model templates have no unknown scripts.

The campus sits on a 1000-stud landscaped island surrounded by Terrain water. District rows are centered 325 studs from the hub, leaving 15 studs of clear space between the nearest corners of adjacent streets. Island surfaces terminate at or below Y=0 so they do not clip through plot foundations. The central hub contains authored reservations for leaderboards, featured purchases, daily rewards, prestige, and a rotating showcase. Curbs, lamps, trees, rocks, beach edging, clouds, atmosphere, and warm outdoor lighting establish the environment without runtime world construction.

Claimed plot identity cards use authored `BillboardGui` instances with `AlwaysOnTop`, no distance cutoff, and a raised offset. The avatar, player name, stage, prestige, and total scrap therefore remain readable from the island overview; unclaimed plot cards stay hidden.

Each plot now contains `AreaSections/FrontYard`, `WorkshopYard`, and `VehicleGraveyard`. Workshop occupies the left reserve and Vehicle the right reserve; their authored gate barriers are presentation/collision only and are refreshed from saved ownership. Spawn markers carry `AreaId`, with 8 Front, 7 Workshop, and 7 Vehicle markers per plot. Gate cards cap visibility at 95 studs to prevent cross-plot sign clutter.

Authored expansion instances default hidden. PlotBuildService reveals an owner's unlocked sections, reveals only the relevant locked gate for progression, and hides every expansion on unowned plots. AreaPromptController additionally filters floating gate cards per client so only the assigned plot's locked prompt is visible. `UpgradeDisplay` remains authored but intentionally hidden pending a later visual redesign.

`SoundService/ScrapyardAudio` contains empty named replacement hooks for Collect, Sell, Confirm, and Music. Assign approved Roblox audio IDs directly in Studio; no source change is required. Effects are client-only presentation and respect the saved settings contract.

`ServerStorage/PlotTemplates/StarterPlot_TestReview` is the approved source template. `ServerStorage/RefactorArchive` holds the retired shared Phase 3 prototype recoverably. Do not restore its `Map` or `Gameplay` folders to Workspace alongside the plot services.

## Terrain Timing

Do not invest in final terrain during foundation/data work. Phase 3 uses obvious primitives and markers for the loop. Phase 5 replaces placeholders with editable terrain and toy-like low-poly props after gameplay scale, routes, spawn density, and machine footprints are proven.

## Art Rules

Friendly colorful scrapyard, chunky silhouettes, clean materials, soft shadows, restrained effects, generic unbranded vehicles. Avoid gritty realism, excessive neon, visual clutter, free-model scripts, and collision-heavy decorative piles.
