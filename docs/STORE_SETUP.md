# Store setup — everything to create in the Creator Dashboard

Fifteen products are fully built, priced, described and rendered in the shop. **Every one has
`MarketplaceId = 0`, so every button reads COMING SOON and no purchase is possible.** This page is
the checklist to close that.

Nothing here needs code. Create the asset, copy the numeric id, paste it into
`src/shared/Config/MonetizationConfig.luau`.

---

## How to create each kind

**Game passes** (permanent, one-time) — Creator Dashboard → your experience → **Associated Items →
Passes → Create a Pass**. Name it, set the price, upload the icon, save. The id is the number in the
URL: `create.roblox.com/dashboard/creations/experiences/<universe>/passes/**1234567**/configure`.

**Developer products** (repeatable) — same experience → **Associated Items → Developer Products →
Create a Developer Product**. The id shows in the list.

**The distinction matters for revenue.** A pass earns on *conversion* — the share of players who buy
it once — and then that player can never spend on it again. A developer product earns on *repeat
frequency*. Our catalogue is 8 passes to 7 products, which caps lifetime spend per player; the cash
packs and booster bundles are the half worth expanding.

**Roblox has no native discounts.** You cannot put a pass on sale, so do not build UI promising
"50% OFF" — a limited offer has to be a separate SKU or a time-gated developer product.

---

## 1. Game passes — 8 to create

Prices are what the shop already advertises. Change them in the dashboard *and* in
`MonetizationConfig.DisplayPrice`, or the shop will lie.

| # | Create as | Price (R$) | Description to paste | Config key |
| --- | --- | --- | --- | --- |
| 1 | **2x Cash Forever** | 299 | Doubles every scrap sale permanently. | `DoubleCash` |
| 2 | **Mega Storage** | 199 | Permanently increases magnet storage by 50%. | `StoragePlus` |
| 3 | **Turbo Collector** | 249 | Permanently doubles collection speed. | `FastCollector` |
| 4 | **Quantum Magnet** | 399 | Exclusive 25 strength, 22 range premium magnet. | `QuantumMagnet` |
| 5 | **+2 Pet Slots** | 249 | Equip two additional pets permanently (maximum five). | `ExtraPetSlots` |
| 6 | **Singularity Pet** | 499 | Copies twice the effects of your strongest equipped normal pet. | `SingularityPet` |
| 7 | **Demonic Ghost Pet** | 699 | Increases every combined pet bonus by 35%. | `DemonicGhostPet` |
| 8 | **Sinister Lord Pet** | 999 | Ultimate premium pet that doubles all combined pet bonuses. | `SinisterLordPet` |

**Fix before creating #4.** The config advertises "25 strength, **32** range" and
`InventoryConfig.QuantumMagnet.BaseRange` is **22**. Pick one. The description above uses 22, which
is what the game actually gives. Also worth knowing: `QuantumMagnet`'s 3D model is currently
`AdvancedMagnet` with a different material — a 399 R$ item that is a recolour of a 60,000-cash one.
See `docs/MAGNETS.md`.

## 2. Developer products — 7 to create

| # | Create as | Price (R$) | Grants | Config key |
| --- | --- | --- | --- | --- |
| 9 | **Cash Crate** | 49 | $25,000 | `CashSmall` |
| 10 | **Cash Vault** | 149 | $150,000 | `CashMedium` |
| 11 | **Cash Mountain** | 399 | $750,000 | `CashLarge` |
| 12 | **Booster Pair** | 79 | 2 Cash Potions, 2 Strength Potions | `BoosterPair` |
| 13 | **Booster Bundle** | 199 | 6 Cash Potions, 6 Strength Potions | `BoosterBundle` |
| 14 | **Mega Starter Bundle** | 299 | $100,000 plus a potion set | `MegaBundle` |
| 15 | **Instant Rebirth** | 149 | Completes one rebirth with no cash requirement | `SkipRebirth` |

---

## 3. Where the ids go

One file. Replace each `MarketplaceId = 0`:

```lua
-- src/shared/Config/MonetizationConfig.luau
DoubleCash      MarketplaceId = 0,  -- pass
StoragePlus     MarketplaceId = 0,  -- pass
FastCollector   MarketplaceId = 0,  -- pass
QuantumMagnet   MarketplaceId = 0,  -- pass
ExtraPetSlots   MarketplaceId = 0,  -- pass
SingularityPet  MarketplaceId = 0,  -- pass
DemonicGhostPet MarketplaceId = 0,  -- pass
SinisterLordPet MarketplaceId = 0,  -- pass
CashSmall       MarketplaceId = 0,  -- developer product
CashMedium      MarketplaceId = 0,  -- developer product
CashLarge       MarketplaceId = 0,  -- developer product
BoosterPair     MarketplaceId = 0,  -- developer product
BoosterBundle   MarketplaceId = 0,  -- developer product
MegaBundle      MarketplaceId = 0,  -- developer product
SkipRebirth     MarketplaceId = 0,  -- developer product
```

`MonetizationService` already handles prompts, receipts and re-grants, and `ProcessedReceipts` is
already in the save schema — so a filled-in id is the only thing between here and working purchases.

## 4. Icons still needed

Passes want a shop icon each. `docs/ICON_PROMPTS.md` has the generation prompts and the exact house
style; four of the eight ids are already in `Assets.Art`:

| Pass | Icon |
| --- | --- |
| ExtraPetSlots | `103179431409211` ✓ |
| FastCollector | `79551795907555` ✓ |
| DoubleCash | `136753021470793` ✓ |
| StoragePlus | `70407724067119` ✓ |
| QuantumMagnet | **missing** |
| SingularityPet | **missing** |
| DemonicGhostPet | **missing** |
| SinisterLordPet | **missing** |

Two magnet icons are also blank — `AdvancedMagnet` and `QuantumMagnet` in `InventoryConfig.IconId`.

---

## 5. After wiring — test the loop

In Studio, purchases run against the real Marketplace but are not charged. Worth checking each:

- [ ] Prompt opens and shows the right name, price and icon
- [ ] Buying grants the thing (check the stat, not the toast)
- [ ] Re-joining still has it — passes re-grant from `Entitlements`, products from `Money`/`Inventory`
- [ ] Buying the same product twice grants twice (`ProcessedReceipts` must not block a *product*)
- [ ] Buying the same pass twice is refused gracefully

---

## 6. What to add next, and why

From `docs/GAME_AUDIT.md`. Not required to ship, but this is where the revenue ceiling is:

**Contextual offers convert 3–5× better than a store you have to open.** Five moments worth an
offer, all of which the game already detects:

| Moment | Offer |
| --- | --- |
| Storage full for the third time this session | Mega Storage |
| Magnet too weak for scrap the player is standing on | The next magnet |
| 10% short of a rebirth | Cash pack |
| Failed to afford an area unlock | Cash pack |
| Egg hatch produced a duplicate | Luck potion |

One rule: these are **offers, not walls**. Appear once, dismissible, no repeat. Roblox players buy
what they want and refuse to buy their way out of broken design — a prompt that blocks play costs
more retention than it earns.

**Cosmetics are the missing category.** Everything for sale is power, which means a player who owns
all eight passes cannot spend again. Magnet skins (see `docs/MAGNETS.md`), plot theme skins, trails
and pedestal effects carry zero balance risk and sell to exactly those players.
