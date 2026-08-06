# Security and Testing

## Trust Model

- Server derives scrap type, variant, weight, value, eligibility, storage mutation, sell award, price, unlock, and prestige reward.
- Scrap has server identity/state and a one-player reservation to prevent duplicate collection.
- Collection validates player session, character position envelope, area access, magnet strength, capacity, scrap availability, and request cadence.
- Sell uses server-observed zone presence and transaction debounce; repeated touches cannot duplicate value.
- Numeric inputs/state are finite, nonnegative, bounded, and schema-validated.
- Failed data loads never become writable defaults. Receipt/product work is outside initial MVP unless separately planned.

## Pure Tests

Test schema migration/validation, scrap eligibility, capacity edges, variant/value calculation, upgrade costs/effects, sell transaction math, area requirements, prestige reward/reset, finite-number clamps, and rate limiter behavior.

## Manual Multiplayer Tests

At minimum: two players collect independently; one scrap cannot reward twice; full storage blocks collection; insufficient strength blocks heavy scrap; sell touch duplicates fail; upgrades/prices are server-derived; gates differ per player; rejoin restores data; failed load does not save; prestige resets only intended fields.

## Mobile/Performance Tests

Use Device Emulator at phone/tablet portrait and landscape. Verify controls avoid Roblox movement UI, menus scroll, text fits, and collection requires no aiming. Profile active scrap counts, query cadence, remote volume, tween cleanup, server frame time, and client render cost. No Workspace-wide per-frame scans or loop per scrap.
