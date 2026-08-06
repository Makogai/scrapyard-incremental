# Architecture

## Proposed Source Tree

```text
src/
  shared/
    Config/Environment.luau
    Config/ScrapConfig.luau
    Config/UpgradeConfig.luau
    Config/AreaConfig.luau
    Config/PrestigeConfig.luau
    Config/UITheme.luau
    Types/PlayerData.luau
    Types/GameState.luau
    Remotes/Definitions.luau
    Utility/Math.luau
    Utility/RateLimiter.luau
    Utility/Janitor.luau
  server/
    Services/RemoteService.luau
    Services/DataService.luau
    Services/PlayerStateService.luau
    Services/PlotService.luau
    Services/PlotBuildService.luau
    Services/ScrapService.luau
    Services/SellService.luau
    Services/UpgradeService.luau
    Services/AreaService.luau
    Services/PrestigeService.luau
    init.server.luau
  client/
    Controllers/StateController.luau
    Controllers/ScrapController.luau
    Controllers/UIController.luau
    Controllers/EffectsController.luau
    Components/
    init.client.luau
tests/
```

## Responsibilities

- DataService: load/migrate/validate/save only; no gameplay rules.
- PlayerStateService: in-memory sessions, sanitized snapshots/deltas, mutation boundary.
- PlotService: discovers 12 authored slots, assigns/releases ownership, teleports owners, and exposes the sole ownership-resolution boundary.
- PlotBuildService: applies saved stage/theme state, updates owner signs/thumbnails, clears runtime objects, and resets released slots.
- ScrapService: area registries, spawn lifecycle, eligibility, reservation, collection transaction, respawn.
- SellService: sell-zone debounce, storage conversion, multipliers, crusher signal.
- UpgradeService: configured costs/effects and purchases.
- AreaService: authored gates, unlock validation, access state.
- PrestigeService: requirement/reward/reset transaction.
- InventoryService: authoritative equip/use intent, timed boosts, and held-magnet character lifecycle.
- StateController: client snapshot/delta cache.
- ScrapController: visual attraction driven by server-approved state.
- UIController: binds authored UI, sends intent, renders state.
- EffectsController: bounded particles, tweens, audio, reduced-effects behavior.

## Core Data Flow

After data loads, PlotService assigns one authored plot and PlotBuildService applies saved appearance state. ScrapService registers only that plot's markers, stamps every runtime object with plot/owner identity, and maintains a bounded per-plot population. At a controlled cadence it checks nearby owner candidates using spatial queries, validates plot ownership plus strength/capacity/session/area, reserves one scrap to its owner, and authorizes collection. Visitors never enter the transaction. Visual motion may run client-side, but the server completes value/weight mutation from its own config and identity. Compact deltas update HUD and collection feedback.

## Dependency Rules

Shared code has no server authority. Client never requires server modules. Services start in explicit order: remotes, player state, plots, scrap, then selling. They communicate through narrow APIs and plot lifecycle callbacks. No circular dependencies, per-scrap infinite loops, physical plot IDs in saved data, or direct DataStore calls outside DataService.
