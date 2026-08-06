# Phase 7: Prestige and Collection

## Scope

Implement confirmed Gears prestige, permanent multiplier, exact reset/preserve transaction, prestige UI, collection silhouettes/details, best variant, lifetime counts, and discovery notifications.

## Acceptance

- Requirement/reward/reset are server-calculated and tested.
- Money, normal upgrades, areas, and storage reset; Gears, discoveries, permanent bonuses, settings, and passes remain.
- Duplicate prestige requests cannot grant twice.
- Collection persists accurately and undiscovered entries reveal no unintended details.

## Completed Work

- Added the server-owned, rate-limited prestige transaction. The server calculates eligibility and Gear reward, grants once, and resets cash, storage, all six normal upgrades, plot stage, and area unlocks back to Front Yard.
- Preserved Gears, prestige count, discovery records, lifetime collection counts, best variants, player settings, customization, and permanent entitlements across the reset.
- Added an authored Epic-style Prestige navigation button and modal directly in `StarterGui`, with requirement progress, reward, current/next permanent multiplier, reset/keep disclosure, and two-step confirmation.
- Replaced the collection placeholder with eight authored scrolling cards. Discovered entries show name, best variant, and lifetime count; undiscovered entries expose no scrap identity or stats.
- Added first-discovery and improved-variant notifications through the normal authoritative collection transaction.
- Live Studio verified an eligible prestige from `$828,486`, two rapid prestige requests granting exactly one Gear, zeroed storage/money/upgrades, Front-Yard-only state, preserved collection/settings, and persistence after stop/rejoin. The undiscovered Scrap Car card showed only `?????`, `UNDISCOVERED`, and its generic discovery hint.
- Phase 7 quality gate: StyLua and both Selene profiles pass, 73 Lune assertions pass, and Rojo builds successfully.
