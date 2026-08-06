# Inventory, Magnets, and Boosts

## Product Contract

- Magnets are permanent owned equipment. Exactly one magnet is equipped and visibly held by the character.
- Each magnet supplies server-owned base strength and range. Existing upgrade levels add their configured improvement above the starter baseline, so changing equipment does not erase upgrades.
- Consumables are counted inventory items. Using one is an authoritative, rate-limited transaction and creates an absolute server expiry timestamp.
- Cash boosts multiply final scrap sale value; strength boosts add to collection eligibility. Clients display state and submit only equip/use intent.
- The local player sees an animated neon ring at the authoritative equipped range. Advanced Magnet adds a brighter, counter-rotating violet layer; the player's Screen Effects setting hides both.
- Inventory, ownership, equipped magnet, and active boost expiries persist. Prestige preserves all of them. The Studio test-profile reset clears them to starter defaults.

## Initial Content

| Item | Type | Effect |
| --- | --- | --- |
| Basic Magnet | Magnet | 4 base strength, 18 base range |
| Advanced Magnet | Magnet | 12 base strength, 24 base range; cyan/violet energy effect |
| Cash Boost Potion | Consumable | 2x sale value for 10 minutes |
| Strength Boost Potion | Consumable | +15 strength for 10 minutes |

Future magnets are added to `InventoryConfig.Magnets`, given a matching template under `ServerStorage/MagnetModels`, and represented by an authored inventory card. Future consumables follow the same configured effect/duration and counted-inventory pattern. Acquisition sources—shop, rewards, codes, passes, or drops—must call a bounded server mutation; they must never let clients submit quantities.

The authored Advanced Magnet is a multi-part Model. Its held template includes two stronger particle layers, a brighter point light, and an occluded Highlight; player Particles and Screen Effects settings control these components.

## Authored Studio Contract

- The user-supplied `MagnetBasic` UnionOperation is stored at `ServerStorage/MagnetModels/MagnetBasic`.
- `InventoryService` clones it into the character as `EquippedMagnet`, disables collision/query/touch, makes it massless, and welds it to the right hand/arm.
- `StarterGui/ScrapyardUI` owns `InventoryButton`, `InventoryMenu`, and stable `InventoryRow_<ItemId>` cards. Runtime code only renders/binds these instances.
- The Studio-only admin action `GRANT 3 OF EACH TEST POTION` supplies consumables for QA. It is server-rejected in published servers and only targets Self.
- Inventory presentation uses three authored tabs: Magnets, Consumables, and Skins. Magnets/Consumables render compact selectable grids; selecting a card updates a large detail panel where the only Equip/Use action lives. Skins intentionally shows a dedicated Coming Soon state.
- Item artwork is centralized in `ItemIconConfig`; empty image IDs use authored glyph fallbacks. Successful code redemption opens an authored six-slot reward reveal using those same icons, names, colors, and quantities.

## Next Expansion

Add acquisition/shop rules and at least two later magnets only after their prices/unlock sources are designed. Add a compact always-visible boost timer only if playtests show players need it outside the inventory modal.
