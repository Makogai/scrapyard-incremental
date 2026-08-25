# Asset Production Checklist

This is the authoritative art checklist for the current game configuration. IDs and model names are case-sensitive and should not be renamed after implementation.

## Delivery conventions

For each collectible gameplay object, produce:

1. A low-poly/cartoon Roblox-ready 3D model.
2. A square transparent-background inventory/index icon, preferably `1024x1024` PNG.
3. A clean thumbnail angle that matches the other collection icons.

Runtime model locations currently used:

- Scrap models: `ServerStorage/ScrapModels/<ModelName>`
- Magnet models: `ServerStorage/MagnetModels/<ModelName>`
- Pet models, recommended: `ServerStorage/PetModels/<ModelName>`
- Egg models, recommended: `ServerStorage/EggModels/<ModelName>`

Pet and egg model folders are the intended asset structure but still need their world-follow/hatch presentation connected when final models arrive. Icon asset IDs go into the relevant config file.

## Summary

| Category | 3D models | Icons | Additional assets |
| --- | ---: | ---: | ---: |
| Scrap | 18 | 18 | 4 rarity VFX |
| Pets | 18 | 18 | Optional hatch reveal VFX |
| Eggs | 3 | 3 | 3 hatch/open animations |
| Magnets | 3 | 3 | Range/pull VFX variants |
| Areas | 2 configured gates plus environment sets | Optional area thumbnails | Signs, props, ambience |

## Scrap assets

There are now 18 configured scrap types. The original eight models and ten functional primitive placeholders exist under `ServerStorage/ScrapModels`. All 18 need final polished icons; the ten placeholders need final replacement models. See `plan/SCRAP_RARITY_SYSTEM.md` for complete balance values.

| ID / exact model name | Display name | Spawn rarity | Area availability | Approximate size | Art direction |
| --- | --- | --- | --- | --- | --- |
| `MetalCan` | Metal Can | Any tier | Front Yard | 1.2 × 1.7 × 1.2 | Crushed or dented steel can, chunky silhouette |
| `LooseBolt` | Loose Bolt | Any tier | Front Yard | 0.8 × 0.8 × 0.8 | Oversized readable bolt with broad hex head |
| `SmallMetalPlate` | Small Metal Plate | Any tier | Front Yard | 2.4 × 0.35 × 1.8 | Bent plate with scratches, rivets, and one broken corner |
| `Tire` | Tire | Any tier | Front Yard, Workshop Yard | 2.5 × 2.5 × 1.1 | Worn cartoon tire with deep readable tread |
| `BrokenAppliance` | Broken Appliance | Any tier | Workshop Yard | 3.4 × 3 × 2.8 | Damaged washer/oven hybrid with exposed components |
| `EnginePart` | Engine Part | Any tier | Workshop Yard, Vehicle Graveyard | 3.2 × 2.4 × 2.8 | Stylized engine block with pipes and pistons |
| `CarDoor` | Car Door | Any tier | Workshop Yard, Vehicle Graveyard | 4.5 × 0.5 × 3.4 | Bent vehicle door with handle and broken window frame |
| `ScrapCar` | Scrap Car | Any tier | Vehicle Graveyard | 8 × 3.5 × 5 | Compressed wrecked car, large end-area reward silhouette |
| `RustyPipe` | Rusty Pipe | Any spawn rarity | Front Yard | 2.8 × 0.7 × 0.7 | Bent corroded pipe with readable elbow silhouette |
| `CrushedBucket` | Crushed Bucket | Any spawn rarity | Front Yard | 2 × 1.5 × 2 | Dented utility bucket with broken handle |
| `CopperWire` | Copper Wire Coil | Any spawn rarity | Front Yard | 2.1 × 0.8 × 2.1 | Thick bundled copper cable coil |
| `ToolBox` | Busted Tool Box | Any spawn rarity | Workshop Yard | 2.8 × 1.4 × 1.5 | Open or dented mechanic tool box |
| `BrakeDisc` | Brake Disc | Any spawn rarity | Workshop Yard | 2.5 × 0.55 × 2.5 | Ventilated brake rotor with clear hub |
| `Radiator` | Cracked Radiator | Any spawn rarity | Workshop Yard | 3.4 × 2.6 × 0.8 | Damaged radiator with chunky cooling fins |
| `MotorCoil` | Motor Coil | Any spawn rarity | Workshop Yard | 2.4 × 2.1 × 2.4 | Copper-wound electric motor stator |
| `ExhaustPipe` | Exhaust Assembly | Any spawn rarity | Vehicle Graveyard | 4.8 × 1.3 × 2.2 | Bent exhaust with muffler and tail pipe |
| `Axle` | Heavy Axle | Any spawn rarity | Vehicle Graveyard | 5.5 × 1.2 × 1.2 | Heavy axle shaft with hubs |
| `FuelTank` | Dented Fuel Tank | Any spawn rarity | Vehicle Graveyard | 4.2 × 2.3 × 2.8 | Large dented vehicle fuel tank |

### Scrap variant presentation

Variants reuse the same eight models. They need material/color/VFX treatments, not separate models.

| Variant ID | Display name | Value | Chance | Required presentation |
| --- | --- | ---: | ---: | --- |
| `Normal` | Normal | 1× | 93.825% | Base material and color |
| `Rare` | Rare | 2× | 5% | Blue highlight plus `RareShimmer` |
| `Epic` | Epic | 4× | 1% | Purple highlight plus `EpicPulse` |
| `Legendary` | Legendary | 8× | 0.15% | Gold highlight plus `LegendaryBurst` |
| `Nebula` | Nebula | 25× | 0.025% | Cyan cosmic highlight plus `NebulaAura` |

Unique final VFX needed: `RareShimmer`, `EpicPulse`, `LegendaryBurst`, and `NebulaAura`. Functional generated highlight/particle treatments are already present.

## Pet assets

Every pet needs one 3D companion model and one square icon. None of the final pet icon IDs are configured yet.

The rarity distribution is the same in every egg: Common 55%, Uncommon 25%, Rare 12%, Epic 6%, Legendary 1.8%, Secret 0.2%.

### Junkyard Egg pets

| ID / model name | Display name | Rarity | Cash multiplier | Art direction |
| --- | --- | --- | ---: | --- |
| `TinPup` | Tin Pup | Common | 1.08× | Friendly puppy made from cans and bent sheet metal |
| `BoltBunny` | Bolt Bunny | Uncommon | 1.16× | Bunny with bolt ears, spring legs, and washer details |
| `CanCat` | Can Cat | Rare | 1.28× | Cat formed from colorful cans with a wire tail |
| `GearFox` | Gear Fox | Epic | 1.5× | Clever fox with layered gear fur and glowing eyes |
| `GoldenRaccoon` | Golden Raccoon | Legendary | 2× | Gold-plated scrap raccoon carrying a valuable component |
| `TrashTitan` | Trash Titan | Secret | 4× | Large cute trash golem built from premium junk |

### Workshop Egg pets

| ID / model name | Display name | Rarity | Cash multiplier | Art direction |
| --- | --- | --- | ---: | --- |
| `WrenchMouse` | Wrench Mouse | Common | 1.22× | Small mechanic mouse with wrench ears |
| `SpringFrog` | Spring Frog | Uncommon | 1.38× | Frog with visible coil legs and energetic posture |
| `WelderBear` | Welder Bear | Rare | 1.65× | Bear with welding mask, gloves, and blue spark details |
| `MotorMole` | Motor Mole | Epic | 2.1× | Mole with drill claws and compact motor backpack |
| `ChromeWolf` | Chrome Wolf | Legendary | 3× | Sleek chrome mechanical wolf with blue highlights |
| `CoreDragon` | Core Dragon | Secret | 6× | Compact dragon powered by a glowing workshop reactor core |

### Quantum Egg pets

| ID / model name | Display name | Rarity | Cash multiplier | Art direction |
| --- | --- | --- | ---: | --- |
| `NeonCrab` | Neon Crab | Common | 1.65× | Neon circuit crab with bright claws |
| `CircuitOwl` | Circuit Owl | Uncommon | 2× | Robotic owl with circuit-board wings |
| `PlasmaPanda` | Plasma Panda | Rare | 2.6× | Round panda with contained purple plasma accents |
| `MagnetManta` | Magnet Manta | Epic | 3.5× | Floating manta with magnetic rails and energy trail |
| `NovaLion` | Nova Lion | Legendary | 5× | Lion with a luminous starburst mane |
| `NebulaLeviathan` | Nebula Leviathan | Secret | 8× | Cute cosmic leviathan with orbiting neon scrap |

### Premium pets

These never hatch and use permanent game passes. `TinPup` and `Singularity` currently have correctly named models beneath `Workspace/Pets`; every other pet still needs an exact-name model.

| ID / model name | Display name | Signature ability | Art direction |
| --- | --- | --- | --- |
| `Singularity` | Singularity | Copies 2x the effects of the strongest equipped normal pet | Contained black-hole creature with orbiting scrap |
| `DemonicGhost` | Demonic Ghost | Amplifies all combined pet bonuses by 35% | Cute demonic specter, red flame wisps, scrap-chain details |
| `SinisterLord` | Sinister Lord | Doubles all combined pet bonuses | Premium dark monarch with purple cosmic armor and crown |

### Pet rarity colors

| Rarity | RGB | Hex |
| --- | --- | --- |
| Common | 174, 188, 202 | `#AEBCCA` |
| Uncommon | 91, 214, 126 | `#5BD67E` |
| Rare | 71, 154, 255 | `#479AFF` |
| Epic | 178, 91, 246 | `#B25BF6` |
| Legendary | 255, 183, 48 | `#FFB730` |
| Secret | 255, 75, 148 | `#FF4B94` |

## Egg assets

Each egg needs a world model, shop/hatch icon, idle animation, and hatch/open animation.

| ID / model name | Display name | Area | Price | Theme |
| --- | --- | --- | ---: | --- |
| `JunkyardEgg` | Junkyard Egg | Front Yard | $3,500 | Patchwork steel, cans, bolts, warm rusty colors |
| `WorkshopEgg` | Workshop Egg | Workshop Yard | $35,000 | Industrial casing, hazard markings, welding glow |
| `QuantumEgg` | Quantum Egg | Vehicle Graveyard | $250,000 | Floating high-tech shell, neon energy, orbiting pieces |

## Magnet assets

Magnets do not currently use the pet/scrap rarity system. Their gameplay tiers are Starter, Advanced, and Premium.

All three 3D models currently exist under `ServerStorage/MagnetModels`.

| ID / exact model name | Display name | Tier | Strength | Range | Price/source | Icon status |
| --- | --- | --- | ---: | ---: | --- | --- |
| `MagnetBasic` | Basic Magnet | Starter | 4 | 9 | Free starter | Configured: `rbxassetid://79829676084935` |
| `AdvancedMagnet` | Advanced Magnet | Advanced | 12 | 15 | $60,000 | Needed |
| `QuantumMagnet` | Quantum Magnet | Premium | 25 | 22 | Premium entitlement | Needed |

Additional magnet presentation:

- Held-tool pose/attachment compatibility.
- A readable magnetic beam or particle pull effect.
- Circular animated range indicator.
- Advanced Magnet should have a stronger effect than Basic.
- Quantum Magnet should have the strongest premium color/VFX treatment.

## Area assets

Areas do not have rarities. They represent progression tiers and each should have a distinct environment identity.

| Area ID | Display name | Order | Unlock price | Scrap set | Required area assets |
| --- | --- | ---: | ---: | --- | --- |
| `FrontYard` | Front Yard | 1 | Free | Metal Can, Loose Bolt, Small Metal Plate, Tire | Starter junk piles, fencing, simple machinery, readable area sign, scrap spawn dressing |
| `WorkshopYard` | Workshop Yard | 2 | $12,500 | Tire, Broken Appliance, Engine Part, Car Door | `WorkshopGate`, workshop building/facade, welding props, tool benches, industrial lights, area sign |
| `VehicleGraveyard` | Vehicle Graveyard | 3 | $125,000 | Engine Part, Car Door, Scrap Car | `VehicleGate`, stacked wrecks, crane/compactor props, hazard lights, premium scrapyard dressing, area sign |

Configured gate model names:

- `WorkshopGate`
- `VehicleGate`

The old versions currently exist only in `ServerStorage/RefactorArchive/Map/Gates`; final gates should be placed in the active authored map or a clearly named reusable asset folder.

## Minimum remaining art deliverables

Based on the current Studio/config state, the most important missing final assets are:

1. 19 remaining exact-name pet models (21 total; Tin Pup and Singularity currently match).
2. 21 pet icons.
3. 3 egg models.
4. 3 egg icons.
5. 3 egg hatch/open animations.
6. 18 polished scrap icons and final replacements for the ten new placeholder models.
7. Advanced Magnet icon.
8. Quantum Magnet icon.
9. Final active Workshop and Vehicle gates.
10. Final `RareShimmer`, `EpicPulse`, `LegendaryBurst`, and `NebulaAura` VFX.
11. Final environment dressing/signage for all three areas.
12. A dedicated Rarity Luck upgrade icon for `UpgradeRow_Rarity`.

## Source configuration files

- `src/shared/Config/ScrapConfig.luau`
- `src/shared/Config/PetConfig.luau`
- `src/shared/Config/InventoryConfig.luau`
- `src/shared/Config/AreaConfig.luau`
