# Robux Store Catalog

This is the source of truth for every Roblox monetization item. Update this file whenever a pass or developer product is added, removed, repriced, renamed, or receives new artwork.

## Asset Standard

- Generate square `1024 x 1024` artwork, then export/upload as PNG.
- Keep the important object inside the central 75% safe area.
- Transparent background, no words, no prices, no Roblox logo, no watermark.
- Match the established game icons: vivid toy-like 3D cartoon rendering, chunky Roblox proportions, dark navy outline, glossy highlights, bright rim light, clean silhouette, energetic scrap-yard colors.
- Store the resulting Marketplace ID in `src/shared/Config/MonetizationConfig.luau`.

## Game Passes — Permanent, One Purchase

| Config ID | Dashboard Name | Price | Effect | Image |
|---|---|---:|---|---|
| `DoubleCash` | 2x Cash Forever | R$299 | Permanently doubles scrap-sale cash | Ready |
| `StoragePlus` | Mega Storage | R$199 | Permanently adds 50% storage | Ready |
| `FastCollector` | Turbo Collector | R$249 | Permanently doubles collection speed | Ready |
| `QuantumMagnet` | Quantum Magnet | R$399 | Unlocks the premium Quantum Magnet | Ready |
| `ExtraPetSlots` | +2 Pet Slots | R$249 | Permanently adds two equipped-pet slots | Ready |
| `SingularityPet` | Singularity Pet | R$499 | Copies 2x the strongest normal pet's effects | Needed |
| `DemonicGhostPet` | Demonic Ghost Pet | R$699 | Amplifies all pet bonuses by 35% | Needed |
| `SinisterLordPet` | Sinister Lord Pet | R$999 | Doubles all combined pet bonuses | Needed |

## Developer Products — Repeatable

| Config ID | Dashboard Name | Price | Reward | Image |
|---|---|---:|---|---|
| `CashSmall` | Cash Crate | R$49 | $25,000 Scrap Cash | Ready |
| `CashMedium` | Cash Vault | R$149 | $150,000 Scrap Cash | Ready |
| `CashLarge` | Cash Mountain | R$399 | $750,000 Scrap Cash | Ready |
| `BoosterPair` | Booster Pair | R$79 | 2 Cash + 2 Strength Potions | Ready |
| `BoosterBundle` | Booster Bundle | R$199 | 6 Cash + 6 Strength Potions | Ready |
| `MegaBundle` | Mega Starter Bundle | R$299 | $100,000 + 10 Cash + 10 Strength Potions | Ready |
| `SkipRebirth` | Instant Rebirth | R$149 | Completes exactly one rebirth immediately | Needed |

The first eleven images above are already generated. Keep the prompts below for consistent regeneration and future variants.

## Icon Prompts

### DoubleCash

Follow the exact visual style of the existing Scrapyard Incremental shop icons. Create a square transparent-background icon showing two thick stacks of bright green cartoon cash bursting upward beside a bold golden `x2` symbol made as a physical 3D object. Add tiny gold coins and warm spark particles, chunky dark navy outline, glossy toy-plastic shading, strong readable silhouette, centered composition. No written words, price, watermark, border, or Roblox logo.

### StoragePlus

Follow the existing shop-icon style. Create a square transparent-background icon of an oversized reinforced blue-and-cyan scrap storage crate with its lid open and colorful metal junk overflowing outward. Add upward expansion arrows as physical glowing shapes, chunky navy outline, glossy toy-like 3D materials, bright cyan rim light, centered readable silhouette. No text, price, watermark, border, or Roblox logo.

### FastCollector

Follow the existing shop-icon style. Create a square transparent-background icon of a vivid purple-and-cyan magnet rocketing forward with cartoon speed trails, small bolts and scrap pieces being pulled behind it, energetic motion, thick navy outline, glossy 3D toy rendering, electric highlights, centered silhouette. No text, price, watermark, border, or Roblox logo.

### QuantumMagnet

Follow the existing shop-icon style. Create a square transparent-background icon of a premium futuristic horseshoe magnet glowing neon magenta, violet, and cyan, with a miniature swirling quantum vortex between its poles and small metal fragments orbiting it. Chunky Roblox-friendly proportions, dark navy outline, glossy toy-plastic rendering, dramatic rim lighting, centered luxury silhouette. No text, price, watermark, border, or Roblox logo.

### ExtraPetSlots

Follow the existing shop-icon style. Create a square transparent-background icon with three adorable stylized scrapyard pet silhouettes grouped together: a bolt bunny, gear fox, and tin-can puppy. Place two bright green plus tokens behind them as physical symbols. Friendly toy-like 3D rendering, chunky navy outline, vivid colors, warm highlights, centered composition. No text, price, watermark, border, or Roblox logo.

### Singularity Pet — New Image Needed

Follow the exact visual style of the existing Scrapyard Incremental shop icons. Create a square transparent-background icon of a cute premium black-hole companion with a glossy dark spherical core, bright cyan event horizon, and tiny colorful scrap pieces orbiting in two luminous rings. Add a subtle doubled spectral silhouette behind it to suggest copying another pet's power. Chunky Roblox-friendly 3D proportions, thick dark navy outline, vivid cyan and violet rim lighting, luxury sparkle, strong centered silhouette. No text, numbers, price, watermark, border, or Roblox logo.

### Demonic Ghost Pet — New Image Needed

Follow the exact visual style of the existing Scrapyard Incremental shop icons. Create a square transparent-background icon of an adorable but powerful demonic ghost companion, floating red-and-black flame body, small curved horns, glowing orange eyes, and broken scrap chains orbiting it. Add outward red energy waves to suggest amplifying the whole pet team. Chunky Roblox-friendly 3D cartoon rendering, thick dark navy outline, glossy highlights, dramatic red and hot-pink rim light, centered premium silhouette. No text, numbers, price, watermark, border, or Roblox logo.

### Sinister Lord Pet — New Image Needed

Follow the exact visual style of the existing Scrapyard Incremental shop icons. Create a square transparent-background icon of the ultimate cute dark-lord companion wearing oversized purple cosmic armor and a jagged glowing crown, with violet eyes, black flame cape, and two crossed energy halos behind it. Make it clearly the most prestigious and powerful pet icon, with intense purple, magenta, and gold lighting, chunky Roblox-friendly 3D proportions, thick navy outline, glossy toy-plastic materials, centered luxury silhouette. No text, numbers, price, watermark, border, or Roblox logo.

### CashSmall

Follow the existing shop-icon style. Create a square transparent-background icon of a small orange-red wooden-and-metal cash crate cracked open with green bills and a few gold coins popping out. Chunky navy outline, glossy toy-like 3D shading, warm gold sparkle, centered simple silhouette. No text, price, watermark, border, or Roblox logo.

### CashMedium

Follow the existing shop-icon style. Create a square transparent-background icon of a sturdy orange-and-gold scrapyard vault with its round door open, several bundles of green cash and coins spilling forward. Make it visibly more valuable than a small crate, with bright warm rim light, chunky navy outline, glossy toy rendering, centered silhouette. No text, price, watermark, border, or Roblox logo.

### CashLarge

Follow the existing shop-icon style. Create a square transparent-background icon of a huge mountain of green cash bundles, gold coins, and glowing treasure emerging from a red industrial scrap container. Maximum-value feeling, vivid orange and gold lighting, chunky dark outline, polished 3D cartoon rendering, strong centered silhouette. No text, price, watermark, border, or Roblox logo.

### BoosterPair

Follow the existing shop-icon style. Create a square transparent-background icon showing two large magical scrapyard potion bottles crossing slightly: one bright green cash potion with a coin emblem and one electric red strength potion with a magnet emblem. Add a few matching particles, glossy glass, chunky navy outline, toy-like 3D rendering, centered composition. No text, price, watermark, border, or Roblox logo.

### BoosterBundle

Follow the existing shop-icon style. Create a square transparent-background icon of a compact premium case overflowing with six colorful cartoon potion bottles, led by green cash and red magnet-strength potions. Add purple energy ribbons, glossy glass, chunky dark outline, vivid toy-like 3D rendering, centered high-value silhouette. No text, price, watermark, border, or Roblox logo.

### MegaBundle

Follow the existing shop-icon style. Create a square transparent-background icon of an extravagant hot-pink-and-gold starter chest bursting open with green cash bundles, many colorful potion bottles, coins, bolts, and star particles. Make it feel like the largest bundle, with glossy toy-plastic materials, thick navy outline, dramatic rim lighting, centered composition. No text, price, watermark, border, or Roblox logo.

### Instant Rebirth — New Image Needed

Follow the exact visual style of the existing Scrapyard Incremental shop icons. Create a square transparent-background icon of a glowing circular rebirth arrow wrapping around a bright magenta prestige crystal and golden gear. The arrow should imply instant forward progression, with a small lightning streak and celebratory star burst. Use vivid cyan, magenta, purple, and gold; chunky Roblox-friendly 3D proportions; thick dark navy outline; glossy toy-plastic highlights; strong centered silhouette. No written words, numbers, price, watermark, border, or Roblox logo.

## Creator Dashboard Checklist

1. Create the eight permanent entries under **Monetization → Passes**.
2. Create the seven repeatable entries under **Monetization → Developer Products**.
3. Use the exact names and intended prices from this document.
4. Upload the matching icon to each entry.
5. Copy each numeric asset/product ID into its `MarketplaceId` field in `MonetizationConfig.luau`.
6. Publish the place and test purchases using Roblox's test-purchase flow before release.
7. Never convert Instant Rebirth into a pass; it must remain repeatable.
