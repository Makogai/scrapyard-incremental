# Monetization setup

Everything sellable in the game, what to create for it, and what art it needs.

`MonetizationConfig.luau` is already complete: names, prices, descriptions and the reward each item
grants are written and wired. The only thing missing is the **numeric ids Roblox assigns when you
create the item on its side**. Every entry currently reads `MarketplaceId = 0`.

**STATUS: all 28 created and wired (2026-08-20).** 11 passes and 17 developer products, every
`MarketplaceId` filled. The tables below are kept as the record of what was created and what each item
is meant to cost.

**Two things still outstanding:**

1. **Every pass is `Offsale`.** Roblox does not take a price on the pass creation form -- it creates the
   pass, and the price is set afterwards on the pass itself. Until that is done a pass cannot be bought,
   even though its id is wired. The 17 developer products DO have their prices set, because that form
   does take one.
2. ~~No icons.~~ **Done (2026-08-20).** All 28 items have art, from `images/monetization` (20) and
   `images/upgrades` (7). Rarity Luck reuses `scrap_flow`, matching what `Assets.luau` already does in
   game. Uploaded icons sit in Roblox moderation for a while before they display, so grey placeholders
   in the dashboard right after upload are expected, not a failure.

**Uploading more art later:** the browser tooling can only read files it has been given access to, so
`images/` had to be copied into the session scratchpad first. If you want this repeated, either copy the
files across again or run `/add-dir` on the images folder.

Managed Pricing is **Disabled** on all 17 products, deliberately: it is on by default and would have let
Roblox vary the real price regionally, which would disagree with the `DisplayPrice` our UI prints.

A `MarketplaceId = 0` is not a crash. `Bridge.promptPass` / `promptProduct` check the id first: a real id
opens the Roblox purchase dialog, no id shows a "not available yet" toast naming the item. So every buy
button is live and politely unavailable until you paste the real numbers, which beats a button that
appears the week somebody remembers to wire it up.

> **This was broken until 2026-08-20 and it is worth knowing why.** Both of those functions used to fire
> the `MonetizationPrompt` remote instead. That remote is gated on `RunService:IsStudio()` *and*
> `AdminConfig.IsAdmin`, so on a live server it returned immediately and every buy button in the React UI
> did nothing at all — the shop, the magnet shop, the egg batch passes, Skip Rebirth and the details
> modal all route through the same two functions, so that was the entire monetization surface. The cause
> was structural: `MarketplaceService:PromptGamePassPurchase` only opens the dialog when called on the
> CLIENT, so a purchase can never be a remote round trip. `MonetizationPrompt` still exists as what it
> always was underneath — the Studio-only, admin-only path that grants without charging so a reward can
> be tested before it is live.

---

## Pass or product? (this decides which list you use)

| | Pass | Developer product |
| --- | --- | --- |
| Bought | **once**, owned forever | **repeatedly** |
| Roblox calls it | Pass (formerly Game Pass) | Developer Product |
| Where it lives | Creator Dashboard → Passes | Creator Dashboard → Developer Products |
| Our code checks | `data.Entitlements[Id]` | `ProcessReceipt` → grants, then forgets |

Get this wrong and the item still works, but a pass created as a product can be bought endlessly, and a
product created as a pass can be bought only once. Match the tables below.

---

## Where to create them

**Creator Dashboard** — https://create.roblox.com/dashboard/creations

1. **Creations** → pick the Scrapyard experience
2. Left sidebar → **Monetization**
3. **Passes** or **Developer Products** → **Create**
4. Fill in Name, Description, Price, upload the icon
5. Open the item you just made and copy the **numeric id out of the URL**
   (`.../store/12345678/My-Pass` → `12345678`)

Studio cannot create these. The Asset Manager handles images and models, not monetization.

**Price note:** the Price column below is what to type into the dashboard. `DisplayPrice` in our config
is only what the UI *prints* — Roblox owns the real price, and if the two disagree the player sees one
number and is charged another. Keep them equal.

---

## Passes (11) — bought once, owned forever

| # | Name to type | Price | Description to paste | Config key |
| --- | --- | --- | --- | --- |
| 1 | 2x Cash Forever | 299 | Doubles every scrap sale permanently. | `DoubleCash` |
| 2 | Mega Storage | 199 | Permanently increases magnet storage by 50%. | `StoragePlus` |
| 3 | Turbo Collector | 249 | Permanently doubles collection speed. | `FastCollector` |
| 4 | Quantum Magnet | 399 | Exclusive 25 strength, 32 range premium magnet. | `QuantumMagnet` |
| 5 | 2x Walk Speed | 199 | Move twice as fast, permanently. Stacks with your speed upgrade. | `PermanentSpeed` |
| 6 | +2 Pet Slots | 249 | Equip two additional pets permanently (maximum five). | `ExtraPetSlots` |
| 7 | Triple Hatch | 199 | Open three eggs at once, forever. Costs three eggs' cash. | `TripleHatch` |
| 8 | Penta Hatch | 349 | Open five eggs at once, forever. Costs five eggs' cash. | `PentaHatch` |
| 9 | Singularity Pet | 499 | Copies twice the effects of your strongest equipped normal pet. | `SingularityPet` |
| 10 | Demonic Ghost Pet | 699 | Increases every combined pet bonus by 35%. | `DemonicGhostPet` |
| 11 | Sinister Lord Pet | 999 | Ultimate premium pet that doubles all combined pet bonuses. | `SinisterLordPet` |

> **Singularity Pet is limited to 500 copies globally.** Roblox has no built-in stock limit, so ours is
> enforced in `LimitedStockService` with a DataStore counter reserved *before* the grant. Nothing to do
> in the dashboard — just do not be surprised when it sells out.

---

## Developer products (17) — repeatable

### Robux upgrade levels (8) — 29 each

One product per upgrade, because a developer product carries no parameters: the thing bought **is** the
id. All the same price, all the same sentence shape.

| Name to type | Price | Description to paste | Config key |
| --- | --- | --- | --- |
| Magnet Strength +1 | 29 | Instantly add one level of Magnet Strength, no scrap cash needed. | `RobuxUpgradeMagnetStrength` |
| Magnet Range +1 | 29 | Instantly add one level of Magnet Range, no scrap cash needed. | `RobuxUpgradeMagnetRange` |
| Storage Capacity +1 | 29 | Instantly add one level of Storage Capacity, no scrap cash needed. | `RobuxUpgradeStorageCapacity` |
| Walk Speed +1 | 29 | Instantly add one level of Walk Speed, no scrap cash needed. | `RobuxUpgradeMovementSpeed` |
| Scrap Value +1 | 29 | Instantly add one level of Scrap Value, no scrap cash needed. | `RobuxUpgradeScrapValue` |
| Collection Speed +1 | 29 | Instantly add one level of Collection Speed, no scrap cash needed. | `RobuxUpgradeCollectionSpeed` |
| Scrap Flow +1 | 29 | Instantly add one level of Scrap Flow, no scrap cash needed. | `RobuxUpgradeScrapFlow` |
| Rarity Luck +1 | 29 | Instantly add one level of Rarity Luck, no scrap cash needed. | `RobuxUpgradeRarity` |

**These eight need no new art.** Reuse the upgrade icons already in the game — `Assets.luau` lists them
under `upgrade:*`, and the source PNGs are whatever you uploaded those from. The same picture in the
shop row and on the product is a feature, not laziness.

### Cash (3)

| Name to type | Price | Description to paste | Config key |
| --- | --- | --- | --- |
| Cash Crate | 49 | $25,000 Scrap Cash. | `CashSmall` |
| Cash Vault | 149 | $150,000 Scrap Cash. | `CashMedium` |
| Cash Mountain | 399 | $750,000 Scrap Cash. | `CashLarge` |

### Boosters (3)

| Name to type | Price | Description to paste | Config key |
| --- | --- | --- | --- |
| Booster Pair | 79 | 2 Cash Potions and 2 Strength Potions. | `BoosterPair` |
| Booster Bundle | 199 | 6 Cash Potions and 6 Strength Potions. | `BoosterBundle` |
| Mega Starter Bundle | 299 | $100,000 plus 10 of each potion. | `MegaBundle` |

### Spins and rebirth (3)

| Name to type | Price | Description to paste | Config key |
| --- | --- | --- | --- |
| 1 Spin | 59 | One extra spin of the lucky wheel. | `SpinOne` |
| 3 Spins | 120 | Three extra spins of the lucky wheel. | `SpinThree` |
| Instant Rebirth | 149 | Completes one rebirth immediately without the cash requirement. | `SkipRebirth` |

---

## Icons

**20 new icons needed** — 28 items minus the 8 upgrade products that reuse existing art.

**Spec:** 512x512 PNG, square, subject centred with a little breathing room. They are shown as small as
~64px in the Roblox store list, so fine detail or text turns to mush: one readable silhouette per icon.
Icons go through moderation, so allow a few minutes before they appear.

### The style block — paste this once, at the top of your ChatGPT session

```
You are generating store icons for a Roblox game called Scrapyard Incremental: a cartoon
junkyard-tycoon game where players pull scrap metal with magnets, sell it, and rebirth.

Style rules for EVERY icon in this batch. Keep them identical so the set reads as one family:
- 512x512, square, 1:1
- Bold 3D cartoon render, chunky exaggerated proportions, thick soft edges
- Bright saturated palette, strong rim light from the upper left
- Single hero object, centred, filling about 80% of the frame
- Simple dark radial-gradient background, slightly darker at the corners, no scenery
- NO text, NO numbers, NO letters, NO logos, NO watermarks, no borders or frames
- Must stay readable shrunk to 64x64: one clear silhouette, no fine detail
- Consistent camera: three-quarter view, slightly above the object

I will give you subjects one at a time. Render each in exactly this style.
```

### Subjects — one line each

| Icon | Prompt subject |
| --- | --- |
| 2x Cash Forever | A fat stack of glowing green banknotes with a golden ribbon shape wrapping it, coins spilling from the base |
| Mega Storage | An oversized riveted steel storage crate, lid bursting open with scrap metal overflowing, glowing cyan seams |
| Turbo Collector | A chunky horseshoe magnet leaning forward with cyan speed streaks trailing behind it |
| Quantum Magnet | A sleek futuristic horseshoe magnet in white and violet, crackling with purple energy arcs and floating orbiting particles |
| 2x Walk Speed | A pair of cartoon boots with bright green motion streaks and small dust puffs at the heels |
| +2 Pet Slots | Three glowing empty pet collar rings floating in a row, the front two lit gold, the back one dim |
| Triple Hatch | Three cracked cartoon eggs side by side, warm golden light spilling from the cracks |
| Penta Hatch | Five cracked cartoon eggs in a fan arrangement, bright golden light bursting from all of them |
| Singularity Pet | A small round cartoon creature made of swirling black-and-violet void, single glowing cyan eye, event-horizon ring around it |
| Demonic Ghost Pet | A cute but menacing translucent red ghost creature with small horns and glowing ember eyes |
| Sinister Lord Pet | A tiny regal cartoon demon lord with a black-and-gold crown, a cape, and a glowing red aura |
| Cash Crate | A small wooden crate half full of green banknotes and gold coins |
| Cash Vault | A heavy steel safe with its door open, green banknotes and gold coins pouring out |
| Cash Mountain | A towering pile of gold coins and green banknotes, glowing brightly at the peak |
| Booster Pair | Two cartoon potion bottles side by side, one gold and one red, corked, with soft glows |
| Booster Bundle | Six cartoon potion bottles clustered together in a pyramid, gold and red, glowing |
| Mega Starter Bundle | A treasure chest overflowing with gold coins, plus a cluster of glowing gold and red potion bottles |
| 1 Spin | A single colourful segmented prize wheel seen at a three-quarter angle, one segment glowing |
| 3 Spins | Three overlapping colourful prize wheels, the front one glowing brightest |
| Instant Rebirth | A glowing cyan circular arrow loop with a bright star burst at its centre, gear teeth around the ring |

---

## Can Claude create these for me?

Short answer: **no for the creating, yes for everything around it.**

**Creating passes and products — no.** Roblox's Open Cloud API has no endpoint for it. There are old
undocumented web endpoints that can, but they authenticate with your account cookie
(`.ROBLOSECURITY`), which is a full account credential. I am not going to ask you to paste that into a
tool session, and it is unsupported besides — it breaks without notice and can invalidate your login.
The 28 items are clicks in the dashboard. Budget half an hour.

**Uploading the icons — possibly.** Open Cloud's Assets API can upload images with an API key scoped to
`asset:write`, which would save hand-uploading 20 files. I would want to verify the current endpoint
shape before relying on it, and the pass or product itself still has to be created by hand, so the
saving is real but modest. Say the word and I will check.

**Wiring the ids into the code — fully automated, and this is the part worth automating.** 28 hand-edits
is exactly where a typo silently sells the wrong thing.

### Give me the ids like this

Paste a plain list, one per line, in any order — config key then id:

```
DoubleCash 123456789
StoragePlus 987654321
RobuxUpgradeMagnetStrength 456789123
```

I will apply them in one pass, and fail loudly rather than guess if a key does not exist, an id is not
numeric, or the same id appears twice. Pointing two products at one id is the mistake that looks fine
and charges people for the wrong thing.

You do not have to do all 28 at once. Send whatever you have created; the rest stay politely
unavailable.

---

## After the ids are in

1. **Test in Studio.** `MonetizationService` has a Studio path that grants without charging, so the
   reward and the receipt bookkeeping can be exercised before anything is live.
2. **Then one real purchase per shape** — one pass, one repeatable product, one Robux upgrade level.
   Three different code paths: entitlements, `ProcessReceipt`, and the upgrade-level grant.
3. **`SkipRebirth` deserves its own check.** It performs a real rebirth, which resets areas and rebuilds
   the plot. It had a bug where the old yard was left standing; fixed, but worth seeing once.
