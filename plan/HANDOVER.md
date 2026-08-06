# Scrapyard Incremental Handover

Date: 2026-08-06

## Current State

- Phase 0 product reset: complete.
- Phase 0-2: complete.
- Phase 3 collection/selling: automated and single-player Studio validation complete; multi-client/device checks documented.
- Phase 4 upgrades: implemented and single-player Studio validated; touch/device and multi-client release checks remain.
- Phase 5 authored areas: implemented and desktop/iPhone Studio validated; multi-client/12-player soak remains release QA.
- Plot upgrade rack is intentionally hidden. Expansion geometry is owner-state-driven, and gate billboards are locally filtered to the assigned owner plot.
- Owner admin panel is configured for user ID `1113999731` with Self/All cash, Gears, area, upgrade, and storage tools.
- Phase 6 settings/feedback is complete: saved toggles, collapse control, responsive settings modal, collection/sale feedback, and empty named audio hooks are implemented and desktop/phone/tablet validated.
- Phase 7 prestige/collection is complete: server-owned reset/reward, duplicate protection, permanent Gear multiplier, authored prestige modal, eight collection cards, and discovery notifications are implemented and live persistence-validated.
- Plot refactor: implementation complete; multi-client/12-player soak remains manual.
- StyLua and both Selene profiles pass.
- Lune foundation/data/gameplay/ownership/monetization tests: 81 passed.
- Rojo builds `scrapyard-incremental.rbxlx`.
- Persistence, plot assignment, owner-only scrap collection/selling, authored UI, 12 plot slots, and shared hub exist.
- The authored Exclusive Shop, schema-v6 entitlements/receipt history, secure Marketplace receipt service, and premium Quantum Magnet are implemented. Marketplace IDs remain safe `0` placeholders until created in Creator Dashboard; setup is documented in `docs/MONETIZATION_SETUP.md`.
- Branch `ui/full-rework` contains the full Epic-derived cartoon interface rework and responsive/modal controller changes. The authored visual tree is saved in Studio; preserve its stable binding names and `Rework*` design-system instances.

## New Session Start

1. Read `CLAUDE.md`, `plan/MEMORY.md`, `plan/PLOT_REFACTOR.md`, and `plan/phases/PHASE_07_META.md`.
2. Keep Roblox Studio open with MCP and Rojo connected.
3. Do not restore `ServerStorage/RefactorArchive/Map` or `Gameplay` to Workspace.
4. Preserve the authored Prestige/Collection instances in `StarterGui`; gameplay UI must not be generated at runtime.

## Next Work

Begin Phase 8 security/performance/release hardening. Run the two-client ownership test and 12-player soak, audit all remotes/rate limits, and preserve the authored area/UI hierarchy.
# Current world layout

- The experience supports 12 simultaneous player plots.
- Three plots line each of four short inward-facing streets around a central circular plaza.
- The center reserves visible authored spaces for leaderboards, featured purchases, daily rewards, prestige, and showcase content.
- The map is an outdoor 1000-stud island surrounded by Terrain water, with beach/cliff edging, trees, rocks, streetlights, clouds, atmosphere, and warm afternoon lighting.
- District rows sit 325 studs from the hub. This gives adjacent corner plots 15 studs of horizontal clearance; island surfaces stay at or below the plot-foundation underside to prevent clipping.
- World geometry lives directly in Studio under `Workspace/Plots`, `Workspace/SharedHub`, and `Workspace/IslandEnvironment`; gameplay must not recreate it at runtime.
