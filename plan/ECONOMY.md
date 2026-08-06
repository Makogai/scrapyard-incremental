# Economy and Balance

## Initial Tuning Targets

| Milestone | Target |
| --- | --- |
| First collection | <= 5 seconds |
| First sale | 20-30 seconds |
| First upgrade | 30-45 seconds |
| Workshop unlock | 5-8 minutes |
| Vehicle Graveyard | 20-30 minutes |
| First Gear prestige | 45-75 minutes |

## Scrap Baseline

Phase 1 starting weight/value/strength values are: Can 1/3/1, Bolt 0.5/2/1, Plate 3/9/3, Tire 6/20/6, Appliance 14/55/10, Engine Part 28/135/16, Car Door 42/240/24, and Scrap Car 160/1,250/45. Area overlap prevents an upgrade from invalidating all previous content.

Variants multiply base value after normal scrap value bonuses: Normal 1, Silver 2, Gold 5, Rainbow 15. Spawn weights, not client randomness, determine variants.

## Upgrade Formula

Each upgrade defines base price, growth rate, maximum level, and an effect function/table. Default price shape: `floor(basePrice * growthRate ^ currentLevel)`. Strength uses discrete thresholds; range, storage, and collection speed use bounded curves; movement speed has a conservative hard cap; value multiplier stacking is capped.

Phase 1 uses bounded linear effects by level: Strength starts at 4 and caps at 54; Range 18-48 studs; Storage 20-220 weight; Movement 16-24 WalkSpeed; Scrap Value 1-3.4x; Collection Speed 24-60 studs/second. Initial prices are 45, 60, 40, 125, 180, and 90 respectively, each with its own configured growth rate.

Workshop Yard costs 6,500 and Vehicle Graveyard costs 90,000. First prestige requires 750,000 money and grants one Gear per full requirement multiple, capped at 100 per prestige. Each Gear contributes +10% value, with the total Gear multiplier capped at 10x.

## Selling

Stored weight controls capacity; stored value records the sum of server-approved collected scrap. On sell: `moneyAward = floor(storedValue * scrapValueMultiplier * gearMultiplier)`, with finite-number clamps. The transaction clears storage and grants money atomically before presentation signals.

## Prestige

The first prestige threshold is configured against earned progression, not a client-submitted balance. Gear reward uses a simple bounded formula based on money above threshold. Gear multiplier should provide meaningful acceleration without skipping the entire early loop; initial target is approximately +10% value per Gear with a configured cap/curve.

## Telemetry Questions

Measure time-to-first-pickup/sale/upgrade/area/prestige, storage-full abandonment, upgrade distribution, session length, and mobile frame cost. Rebalance configuration rather than scattering constants.
