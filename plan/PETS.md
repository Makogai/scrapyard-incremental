# Pet Hatchery

Pets are permanent collection progression and survive prestige. Pets can affect cash, magnet strength/range, scrap storage, movement speed, collection speed, scrap respawn rate, and rarity luck. Ordinary bonuses combine additively: two `+50%` cash pets produce a stable `2.0x` cash multiplier.

## Eggs and odds

| Egg | Price | Area | Common | Uncommon | Rare | Epic | Legendary | Secret |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Junkyard | $3,500 | Front Yard | 55% | 25% | 12% | 6% | 1.8% | 0.2% |
| Workshop | $35,000 | Workshop | 55% | 25% | 12% | 6% | 1.8% | 0.2% |
| Quantum | $250,000 | Vehicle Graveyard | 55% | 25% | 12% | 6% | 1.8% | 0.2% |

Each egg contains six unique pets. Roll 50 guarantees Legendary-or-better, with a 10% Secret chance on that pity roll. Roll 500 guarantees the Secret. Pity is tracked independently per egg and persists. `NebulaLeviathan` is the Quantum Egg Secret; Singularity is no longer hatchable.

## Effects and premium pets

Higher rarities gain broader utility effects. Common pets add one utility stat alongside cash; Uncommon through Epic progressively add more; Legendary and Secret pets improve nearly the whole progression loop.

| Premium pet | Suggested pass price | Signature ability |
| --- | ---: | --- |
| Singularity | R$499 | Adds twice the bonus effects of the strongest equipped non-premium pet |
| Demonic Ghost | R$699 | Amplifies all combined pet bonuses by 35% |
| Sinister Lord | R$999 | Doubles all combined pet bonuses |

These are permanent game-pass pets, are never included in egg rolls, and are configured as `SingularityPet`, `DemonicGhostPet`, and `SinisterLordPet` in `MonetizationConfig`. Marketplace IDs remain `0` until created in Creator Dashboard.

## Equipment

- One slot is available by default.
- Two permanent cash upgrades cost $25,000 and $175,000.
- The `ExtraPetSlots` pass adds two permanent slots.
- Maximum equipped pets: five.
- Duplicate copies may be equipped up to the owned count.

## Collection storage and menu

- Players begin with capacity for 50 total pet copies across all species.
- Hatching is rejected before charging cash when storage is full.
- `PetsScreen` is built directly from the same purchased-pack window, textured cards, typography, image close button, and floating popover used by Inventory and Magnet Shop. It renders only pets the player owns. Clicking a card opens the centered details popover with rarity, description, effects, owned/equipped counts, equip action, and delete action; no details panel is permanently visible.
- Players can equip or unequip one copy from the detail panel.
- Deleting requires a confirmation modal and removes exactly one copy. If that copy was equipped, it is unequipped before deletion.

## Asset workflow

Pet and egg art hooks live in `src/shared/Config/PetConfig.luau`. Put named companion models anywhere beneath `Workspace/Pets` (or `ServerStorage/Pets`) and keep each model name equal to its `ModelName`. At server start, matching models are copied into `ReplicatedStorage/PetModels`, and the Workspace source folder is moved into ServerStorage for the live session. Missing models use a rarity-colored client placeholder.

Equipped pets are visible to every client. They float in a formation behind their owner, smoothly follow movement, face the player's direction, bob gently, have no collision/query/touch, and premium pets receive an extra glow. Current matching authored models are `TinPup` and `Singularity`; add the rest using exact config names.
