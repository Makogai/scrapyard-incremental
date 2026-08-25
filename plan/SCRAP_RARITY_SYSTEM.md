# Scrap Rarity and Expanded Catalog

## Core rule

Scrap type and rarity are independent rolls. Any scrap type—including a basic Metal Can—can spawn as Normal, Rare, Epic, Legendary, or Nebula.

Example: `MetalCan` determines the model, weight, base cash value, and strength requirement. Its rarity determines the color/VFX and value multiplier.

## Rarity tiers

These are the level-zero base odds before Rarity Luck or potion boosts.

| Tier | Base weight | Base chance | Value multiplier | Luck exponent | Presentation |
| --- | ---: | ---: | ---: | ---: | --- |
| Normal | 93,825 | 93.825% | 1× | 0 | Base metal presentation |
| Rare | 5,000 | 5% | 2× | 1.0 | Blue highlight and `RareShimmer` |
| Epic | 1,000 | 1% | 4× | 1.5 | Purple highlight and `EpicPulse` |
| Legendary | 150 | 0.15% | 8× | 2.0 | Gold highlight and `LegendaryBurst` |
| Nebula | 25 | 0.025% (1 in 4,000) | 25× | 2.6 | Cyan cosmic highlight and `NebulaAura` |

Weights sum to `VariantRollTotal` 100,000. Rarity odds are dynamically re-normalized after luck is applied. For each non-Normal tier:

```text
effective weight = base weight × rarity luck ^ tier luck exponent
```

Normal remains at weight 93,825. Higher rarities therefore benefit more strongly from Rarity Luck than lower rarities.

## Rarity Luck upgrade

Upgrade ID: `Rarity`

Display name: `Rarity Luck`

- Starting cap: 8 levels.
- Cap gained per prestige: 4 levels.
- Starting cost: $350.
- Base effect: 1× rarity luck.
- Each level adds approximately 0.12 luck before the mild power curve.
- Hard effect cap: 8×.
- Luck Potion and God Potion multiply the upgrade result.
- The upgrade resets on prestige like the other cash upgrades.
- `UpgradeRow_Rarity` is authored in the Upgrades screen. It currently reuses the Scrap Flow row art as a layout-safe placeholder and needs a dedicated rarity/luck icon.

## Nebula server event

When a Nebula scrap spawns:

1. Every player in the current server receives a notification naming the plot owner and scrap type.
2. Every client receives the `NebulaSpawn` gameplay effect.
3. Screen-effects-enabled clients receive a short cyan cosmic flash.
4. The scrap remains on the owner's plot until collected or the plot is refreshed.

The alert happens when the scrap spawns, not when it is collected.

## Expanded scrap catalog

There are now 18 scrap types: the original eight plus ten new types.

### Front Yard

| ID | Display name | Base value | Weight | Strength | Spawn weight |
| --- | --- | ---: | ---: | ---: | ---: |
| `MetalCan` | Metal Can | $45 | 1 | 1 | 30 |
| `LooseBolt` | Loose Bolt | $55 | 0.5 | 1 | 26 |
| `SmallMetalPlate` | Small Metal Plate | $70 | 3 | 3 | 20 |
| `RustyPipe` | Rusty Pipe | $85 | 2 | 2 | 22 |
| `CrushedBucket` | Crushed Bucket | $100 | 4 | 4 | 16 |
| `CopperWire` | Copper Wire Coil | $120 | 3.5 | 5 | 12 |
| `Tire` | Tire | $200 | 6 | 6 | 10 |

### Workshop Yard

| ID | Display name | Base value | Weight | Strength | Spawn weight |
| --- | --- | ---: | ---: | ---: | ---: |
| `Tire` | Tire | $200 | 6 | 6 | 10 |
| `BrokenAppliance` | Broken Appliance | $240 | 14 | 10 | 26 |
| `ToolBox` | Busted Tool Box | $290 | 10 | 9 | 24 |
| `BrakeDisc` | Brake Disc | $350 | 12 | 12 | 20 |
| `Radiator` | Cracked Radiator | $430 | 20 | 15 | 16 |
| `MotorCoil` | Motor Coil | $610 | 18 | 16 | 13 |
| `EnginePart` | Engine Part | $700 | 28 | 16 | 18 |
| `CarDoor` | Car Door | $850 | 42 | 24 | 9 |

### Vehicle Graveyard

| ID | Display name | Base value | Weight | Strength | Spawn weight |
| --- | --- | ---: | ---: | ---: | ---: |
| `EnginePart` | Engine Part | $700 | 28 | 16 | 18 |
| `CarDoor` | Car Door | $850 | 42 | 24 | 9 |
| `ExhaustPipe` | Exhaust Assembly | $1,000 | 35 | 21 | 22 |
| `Axle` | Heavy Axle | $1,150 | 58 | 29 | 16 |
| `FuelTank` | Dented Fuel Tank | $1,350 | 74 | 35 | 11 |
| `ScrapCar` | Scrap Car | $1,750 | 160 | 45 | 5 |

## New model status

Temporary functional models are authored in `ServerStorage/ScrapModels` for:

- `RustyPipe`
- `CrushedBucket`
- `CopperWire`
- `ToolBox`
- `BrakeDisc`
- `Radiator`
- `MotorCoil`
- `ExhaustPipe`
- `Axle`
- `FuelTank`

These allow all 18 types to spawn immediately. They are deliberately simple primitive placeholders and should be replaced one-for-one with final models using the exact same names.

## Save migration

Schema version 10 adds the Rarity upgrade and new scrap discovery entries. Legacy highest variants migrate as follows:

| Legacy variant | New variant |
| --- | --- |
| Silver | Rare |
| Gold | Epic |
| Rainbow | Legendary |

No existing player is automatically credited with Nebula discovery.

## Implementation files

- `src/shared/Config/ScrapConfig.luau`
- `src/shared/Config/AreaConfig.luau`
- `src/shared/Config/UpgradeConfig.luau`
- `src/server/Services/ScrapService.luau`
- `src/server/Services/PlayerStateService.luau`
- `src/client/Controllers/ScrapController.luau`
- `src/shared/Utility/PlayerDataSchema.luau`
