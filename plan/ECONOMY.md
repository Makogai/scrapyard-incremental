# Economy and Balance

## Initial Tuning Targets

| Milestone | Target |
| --- | --- |
| First collection | <= 5 seconds |
| First sale | 20-30 seconds |
| First upgrade | 30-45 seconds |
| Workshop unlock | 4-8 minutes |
| Vehicle Graveyard | 20-35 minutes |
| First Gear prestige | 30-50 minutes |

## Scrap Baseline

Phase 1 starting weight/value/strength values are: Can 1/3/1, Bolt 0.5/2/1, Plate 3/9/3, Tire 6/20/6, Appliance 14/55/10, Engine Part 28/135/16, Car Door 42/240/24, and Scrap Car 160/1,250/45. Area overlap prevents an upgrade from invalidating all previous content.

Variants multiply base value after normal scrap value bonuses: Normal 1, Silver 2, Gold 5, Rainbow 15. Spawn weights, not client randomness, determine variants.

## Prestige-Capped Upgrade Formula

All seven run upgrades have an upgrade-specific starting cap. Every prestige expands those caps, turning each run into a visible completion target while preserving long-term scaling. Prices use a hybrid polynomial/root-exponential curve:

`floor(baseCost * (level + 1) ^ costPower * growthRate ^ sqrt(level))`.

This keeps early levels understandable while allowing later prestige runs to grow substantially longer.

- Magnet Strength, Storage Capacity, and Collection Speed use power curves and continue growing.
- Magnet Range starts at 9 studs, grows gradually, and remains bounded at 42 studs.
- Movement Speed approaches 28 without destabilizing character control.
- Scrap Value compounds by 8.5% per level within server numeric bounds.
- Scrap Flow is the seventh upgrade. It multiplies each scrap definition's respawn delay and approaches a safe 0.18x floor; the service also enforces an absolute 0.45-second minimum.

The schema permits levels up to one million only as an exploit-defense numeric boundary. Prestige resets all seven run levels and raises their next-run caps.

Workshop Yard costs 12,500, Vehicle Graveyard costs 125,000, and Advanced Magnet costs 60,000. Pet eggs provide optional sinks at 3,500, 35,000, and 250,000.

## Selling

Stored weight controls capacity; stored value records the sum of server-approved collected scrap. On sell: `moneyAward = floor(storedValue * scrapValueMultiplier * gearMultiplier)`, with finite-number clamps. The transaction clears storage and grants money atomically before presentation signals.

## Prestige

The first prestige requires 350,000 Scrap Cash. Requirement N is `350,000 * 2.25 ^ PrestigeCount`, bounded at the global currency ceiling. Permanent pets and Gears accelerate repeat runs while expanded upgrade caps provide new spending room.

Gear reward scales with the square root of money above the current requirement plus a 15% veteran factor per previous prestige. The first exact-threshold prestige grants one Gear. Permanent Gear value uses `(1 + Gears) ^ 0.55`, avoiding the former reachable 10x hard cap while keeping early acceleration controlled.

## Telemetry Questions

Measure time-to-first-pickup/sale/upgrade/area/prestige, storage-full abandonment, upgrade distribution, session length, and mobile frame cost. Rebalance configuration rather than scattering constants.
