# Plot-Based Scrapyard Refactor

Date: 2026-08-06

## Locked Product Change

Scrapyard Incremental is now a plot-based game with 12 permanent server slots. Each player receives one temporary physical plot while their saved progression, appearance stage, upgrades, and customization follow them between servers. Visitors may inspect plots but cannot collect, sell, purchase, move, or trigger another owner's content.

## Preserved Systems

- Epic UI Pack authored HUD and ToyScrapyard visual language
- Versioned persistence, guarded sessions, migration, and sanitized snapshots
- Server-owned storage, value, eligibility, selling, and scrap reservations
- Client-only approved attraction rendering
- Shared scrap, variant, upgrade, formula, and remote configuration

## Shared-World Dependencies Requiring Refactor

- `ScrapService` currently registers one global marker tree and must register markers per assigned plot with `PlotId` and `OwnerUserId`.
- `SellService` currently accepts any player's touch on a global zone and must resolve crusher ownership before selling.
- `PlayerStateService` needs plot progression fields and plot-aware mutation validation.
- Server startup needs `PlotService` before scrap/sell services.
- The Phase 3 shared Front Yard remains a working prototype until plot assignment replaces it.

## Test Plot Review Gate

- Model: `Workspace/Plots/Plot01_Test`
- Dimensions: 130 studs wide by 170 studs deep
- Origin: `(150, 0, 20)`
- Entrance: front-middle at local `Z=-77`
- Crusher: horizontally centered at local `X=0`, back-middle at local `Z=58`
- Back clearance: 27 studs to the boundary for upgraded crusher/output machinery
- Starter markers: 14
- Review template: `ServerStorage/PlotTemplates/StarterPlot_TestReview`

Expansion space is reserved for a left workshop, right vehicle-processing area, back machinery strip, front trophy display, larger storage, conveyors, and visitor circulation. The initial stage intentionally uses dirt, rusty/wood fencing, a small crusher, one storage pile, and substantial open ground.

## Required Test-Plot Hierarchy

```text
Plot01_Test/
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
```

The owner billboard contains stable `OwnerAvatar`, `OwnerName`, and `PlotStats` bindings. Runtime assignment will populate the avatar through `Players:GetUserThumbnailAsync`; no user-specific asset ID is authored into the template.

## Implemented Production Layout

The review layout was approved and cloned into 12 production slots. Three plots occupy each of four inward-facing streets around the shared circular hub. Models rotate by district so every entrance faces the center while retaining the same authored local front/back contract. PlotService, PlotBuildService, schema v3 migration, owner-only scrap, owner-only selling, cleanup, teleporting, and real thumbnail/name/stat signs are implemented.

The production world is an outdoor island rather than a floating test pad. Terrain water surrounds layered cliff, beach, and grass forms; the hub reserves authored spaces for future leaderboards, monetization showcases, daily rewards, prestige, and rotating featured content.

The shared Phase 3 prototype is recoverably archived under `ServerStorage/RefactorArchive`. Remaining release gates are the manual two-client contention/visitor test, Device Emulator layouts, a practical 12-client soak, and configuring the published experience's server-size setting to 12.
