# Magnets — what we have, and what to add

The magnet is the one item the player looks at for the entire session. It is in their right
hand, on screen, every second they play. It deserves more than three entries.

This document is the plan for that: what exists (measured, not assumed), the constraint that
decides how many tiers are worth having, a free ladder, a premium line, the effects, and the
prompts to generate the art.

---

## What exists today

Three magnets, in `src/shared/Config/InventoryConfig.luau`:

| Id | Name | Strength | Range | How you get it | Icon |
| --- | --- | --- | --- | --- | --- |
| `MagnetBasic` | Basic Magnet | 4 | 9 | starting item | `79829676084935` |
| `AdvancedMagnet` | Advanced Magnet | 12 | 15 | `ShopPrice = 60000` cash | **missing** |
| `QuantumMagnet` | Quantum Magnet | 25 | 22 | `Premium = true`, 399 R$ | **missing** |

### The models, measured

From `ServerStorage.MagnetModels`:

| Model | Class | Parts | Size | Material |
| --- | --- | --- | --- | --- |
| `MagnetBasic` | `UnionOperation` | 1 | 1.83 × 2.43 × 0.40 | SmoothPlastic |
| `AdvancedMagnet` | Model | 14 | 1.55 × 0.20 × 1.29 | Plastic |
| `QuantumMagnet` | Model | 14 | 1.55 × 0.20 × 1.29 | Neon |

Three things fall out of that table, and all three are worth fixing before adding more:

1. **`QuantumMagnet` is `AdvancedMagnet` with a different material.** Identical geometry, part
   count and size. The 399 R$ item and the 60k cash item are the same object. That is the single
   most visible thing on this list.
2. **The scales disagree.** `MagnetBasic` is 2.43 studs on its long axis and stands upright;
   the other two are 1.55 and are 0.20 studs *thin*. One attach offset cannot flatter both, so
   swapping magnets changes how the hand reads.
3. **Two of three have no icon.** `IconId = ""` on Advanced and Quantum.

### Not wired

`MonetizationConfig.QuantumMagnet` has `MarketplaceId = 0`, so the premium magnet cannot
actually be bought — the shop button reads COMING SOON. It also advertises **"25 strength, 32
range"** while `InventoryConfig` says `BaseRange = 22`. One of those two numbers is a lie; pick
one.

---

## The constraint: the strength ladder

Every scrap has a `RequiredMagnetStrength`. That ladder is what decides how many magnet tiers
are worth having — a magnet that unlocks nothing new is a number, not an upgrade.

| Required strength | Scrap it unlocks |
| --- | --- |
| 1 | MetalCan, LooseBolt |
| 2 | RustyPipe |
| 3 | SmallMetalPlate |
| 4 | CrushedBucket |
| 5 | CopperWire |
| 6 | Tire |
| 9 | ToolBox |
| 10 | BrokenAppliance |
| 12 | BrakeDisc |
| 15 | Radiator |
| 16 | EnginePart, MotorCoil |
| 21 | ExhaustPipe |
| 24 | CarDoor |
| 29 | Axle |
| 35 | FuelTank |
| 45 | ScrapCar |

**The top of the ladder is 45. The best magnet in the game is 25.** Strength also comes from the
`MagnetStrength` upgrade, pets and the Strength Potion (`+15`), so the gap is meant to be closed
by those — but it means no magnet alone reaches ScrapCar, and the two most valuable scrap types
are gated behind stacking three systems. Worth knowing before pricing anything.

**The gaps that matter:**

- **4 → 12 is one purchase.** A new player buys nothing between the starting magnet and a 60,000
  cash item, while CopperWire, Tire, ToolBox and BrokenAppliance all sit inside that gap. This is
  the weakest stretch of the whole progression.
- **Above 25 there is nothing to buy.** Axle, FuelTank and ScrapCar have no magnet aimed at them.

---

## How a magnet is attached — the model spec

`InventoryService.attach` clones `ServerStorage.MagnetModels.<Id>` and welds it to the
character's `RightHand` (or `Right Arm`) at:

```lua
hand.CFrame * CFrame.new(0, -0.85, -0.25) * CFrame.Angles(0, math.rad(90), math.rad(90))
```

Every part is then set `Anchored = false`, `Massless = true`, and
`CanCollide` / `CanTouch` / `CanQuery = false`, so a magnet can never push the player, block the
scrap overlap query, or trip the crusher's Touched volume.

**Spec for a new magnet model:**

| | |
| --- | --- |
| Name | exactly the config `Id` — that is how it is found |
| Longest axis | **2.0–2.5 studs.** Standardise; the current three do not agree |
| Parts | **20 or fewer**, or a single mesh. Six players carry one on screen |
| Materials | `Plastic`, `SmoothPlastic`, `Neon` only — no textures |
| Orientation | **match `AdvancedMagnet` exactly.** The attach code applies a fixed rotation, so a model authored on a different axis grows sideways out of the wrist. Import yours next to it, align, then delete the reference |
| `PrimaryPart` | set it — everything else is measured, but this is what `PivotTo` uses |
| Anchored | leave anchored in the template; the service unanchors on clone |

**Adding a magnet needs no code.** One entry in `InventoryConfig.Magnets`, its `Id` added to
`MagnetOrder`, a model of that name in `ServerStorage.MagnetModels`, an `IconId`. Premium ones
also need a `MonetizationConfig` entry and a real `MarketplaceId`.

---

## The free ladder — bought with in-game cash

Each tier is aimed at a specific shelf of the ladder, so every purchase visibly unlocks
something. Prices are a starting point, not balanced numbers.

| Id | Name | Str | Range | Price | Unlocks | Fantasy |
| --- | --- | --- | --- | --- | --- | --- |
| `MagnetBasic` | Basic Magnet | 4 | 9 | free | the starting five | *exists* |
| `ScrapHook` | Scrap Hook | 7 | 11 | 3,500 | CopperWire, Tire | A bent rebar hook with a fridge magnet gaffer-taped to it. Deliberately janky — first thing you build yourself |
| `WorkshopCoil` | Workshop Coil | 10 | 13 | 18,000 | ToolBox, BrokenAppliance | Copper wire wound round an iron core, exposed and warm. First *made* thing rather than found |
| `AdvancedMagnet` | Advanced Magnet | 12 | 15 | 60,000 | BrakeDisc | *exists* — reprice against the two above, 60k for +2 over WorkshopCoil is a poor deal |
| `IndustrialElectromagnet` | Industrial Electromagnet | 16 | 18 | 250,000 | Radiator, EnginePart, MotorCoil | A proper yellow-and-steel plant magnet with a warning stripe and a rotating beacon |
| `SalvageRig` | Salvage Rig | 21 | 20 | 1,200,000 | ExhaustPipe | Backpack-fed, hoses running up the arm to a heavy head |
| `WreckerCrane` | Wrecker's Claw | 29 | 24 | 8,000,000 | CarDoor, Axle | A scaled-down wrecking-yard disc on a stub of chain. Heavy, scarred, obviously expensive |

That takes a free player from 4 to 29 in six purchases, each one opening new scrap. `FuelTank`
(35) and `ScrapCar` (45) stay behind upgrades, pets and potions — which is a reasonable place to
leave the ceiling.

### Free but earned, not bought

Cash is not the only "free". These cost nothing and are far stronger retention hooks than a price
tag, because they cannot be skipped:

| Id | Name | Str | Range | Earned by | Why |
| --- | --- | --- | --- | --- | --- |
| `RebirthMagnet` | Prestige Magnet | 18 | 20 | first rebirth | Gives rebirth an object you carry. The reward is visible to other players, which is the point |
| `CollectorsMagnet` | Collector's Magnet | 22 | 22 | discover every scrap in the Index | Makes the Index a goal rather than a list. Ties directly to `DiscoveredScrap` |
| `FoundersMagnet` | Founder's Magnet | 12 | 15 | play before a cutoff date | Cosmetic-tier stats on purpose — pure status. Never re-issue it |

`RebirthMagnet` and `CollectorsMagnet` are deliberately *between* cash tiers, so earning one
skips a purchase rather than replacing the ladder.

---

## The premium line — Robux

Premium magnets should be either **a shortcut** or **a ceiling raise**, and it should be obvious
which. Selling something the free ladder later beats, without saying so, is how a shop loses
trust.

| Id | Name | Str | Range | Price | Role |
| --- | --- | --- | --- | --- | --- |
| `QuantumMagnet` | Quantum Magnet | 25 | 22 | 399 R$ | *exists* — a **shortcut**. The free `WreckerCrane` beats it at 29. That is fine, but the shop should say "skip ahead", not imply endgame |
| `VoidMagnet` | Void Magnet | 40 | 28 | 699 R$ | **Ceiling raise** — the only item that reaches FuelTank (35) on its own |
| `SingularityMagnet` | Singularity Magnet | 60 | 34 | 1,299 R$ | Top of the game. Reaches ScrapCar (45) with room to spare. Pairs with the existing `SingularityPet` pass as a matching set |
| `MagnetSkinPack` | Chrome Skin Pack | — | — | 199 R$ | **Cosmetic only.** Re-skins whatever magnet you have. Cannot be pay-to-win because it carries no stats, and it monetises players who already own the top magnet |

`MagnetSkinPack` is the one I would build first of these four. It has no balance risk, it sells to
players who have nothing left to buy, and it reuses every model already made.

**Before shipping any of them:** fill in `MarketplaceId`. All the current pass ids are `0`, so
every button reads COMING SOON.

---

## Effects

This is where the money is. A magnet is held up in front of the camera constantly, so an effect
on it is seen more than any other VFX in the game.

### Rules

Learned from the plot particles and the UI kit, and they apply here harder because six players
carry a magnet at once:

- **`Rate` 2–8 for anything looping.** A magnet emitter runs for the entire session.
- **Name every emitter and keep it findable**, so it can be switched off in one place.
- **One accent colour per magnet.** Grey plus one bright colour reads as designed; two reads as
  clutter.
- **Never obscure the hand or the scrap.** The effect frames the magnet; it does not fill the
  screen. Anything that reads as fog fails.
- **Bursts on events, loops for identity.** A collection burst can be showy because it is brief.
- **No rotated `GuiObject`s** if any of this ever gets a billboard — a rotated GuiObject ignores
  `ClipsDescendants` and paints over the whole screen.

### Per magnet

| Magnet | Idle | On collect | Accent |
| --- | --- | --- | --- |
| Basic Magnet | none — it is the baseline | tiny grey dust puff | — |
| Scrap Hook | none | dust puff + a single spark | — |
| Workshop Coil | two slow orange sparks arcing pole to pole, `Rate` 3 | brief coil flare, warm `PointLight` pulse | Orange `#FF9A2B` |
| Advanced Magnet | thin cyan electric arc between poles, faint `PointLight` | arc snaps brighter, small ring | Cyan `#21E5F5` |
| Industrial Electromagnet | rotating amber beacon on the housing, quiet hum `Sound` | heavy clunk, dust ring at the feet | Gold `#FFD21C` |
| Salvage Rig | metal filings drifting toward the head and sticking | filings jump outward, hose hiss | Steel `#566D6F` |
| Wrecker's Claw | slow chain sway, occasional scrape spark | ground dust ring, low thud | Rust `#8A4B2A` |
| Prestige Magnet | slow rising gold motes | gold flash ring | Gold `#FFD21C` |
| Collector's Magnet | small orbiting icons of discovered scrap | icons converge inward | Green `#72F000` |
| Quantum Magnet | purple ring orbiting the head, `Neon` body already | ring collapses inward then snaps back | Purple `#B530FF` |
| Void Magnet | inward-spiralling dark particles, black core, *negative* look | brief radial pull distortion | Ink `#10131A` + Purple rim |
| Singularity Magnet | accretion disc, lightning tether to the nearest scrap | disc flares white, shockwave ring | Pink `#FF4CA7` |

### Effect vocabulary worth building once

Each of these is reusable across magnets, which is what makes a large magnet roster cheap:

- **Pull tether.** A `Beam` from the magnet head to the scrap being collected. This is the single
  best one — it makes collection *legible*, and it works on every magnet with just a colour swap.
- **Charge-up glow.** Magnet brightens as `CollectionSpeed` fills, so the wait reads as a wind-up
  instead of a delay.
- **Collection burst.** One-shot emitter at the scrap's position, tinted by rarity — reuse the
  `ScrapConfig.Variants` colours that already exist.
- **Rarity flash.** On a Legendary or Nebula pickup, the magnet itself flashes that variant's
  colour. Free drama, and it teaches the rarity colours.
- **Idle aura.** A `PointLight` plus a low-rate emitter. Cheapest possible tier signal — a player
  can tell your magnet tier across the yard.
- **Hand trail.** A short `Trail` between two attachments on the head, so swinging the arm reads.
  Keep `Lifetime` under 0.3 or it smears.
- **Orbiting satellites.** Two or three small parts circling the head. Reads as "advanced" and
  costs three parts plus a `CFrame` update.
- **Storage-full warning.** Magnet dims and the effect stops when storage is full. Currently that
  state is only a toast; putting it on the object the player is already looking at is better than
  a notification, and it would have made the magnet-spam bug obvious immediately.

---

## Config shapes

A free magnet:

```lua
WorkshopCoil = table.freeze({
    Id = "WorkshopCoil",
    DisplayName = "Workshop Coil",
    Description = "Hand-wound copper on an iron core. Warm to the touch.",
    BaseStrength = 10,
    BaseRange = 13,
    ModelName = "WorkshopCoil",
    ShopPrice = 18000,
    IconId = "rbxassetid://0000000000",
}),
```

A premium magnet needs the `InventoryConfig` entry with `Premium = true`, plus:

```lua
VoidMagnet = table.freeze({
    Id = "VoidMagnet",
    MarketplaceId = 0,           -- REPLACE. 0 means the button reads COMING SOON
    DisplayName = "Void Magnet",
    Description = "Exclusive 40 strength, 28 range premium magnet.",
    DisplayPrice = 699,
    Color = Color3.fromRGB(90, 40, 140),
}),
```

Then add the `Id` to `InventoryConfig.MagnetOrder` (shop order) and, for premium, the
monetisation order list.

**Keep the description numbers in sync with `BaseStrength` / `BaseRange`.** `QuantumMagnet`
currently advertises a range of 32 and has 22.

---

## Prompts

Two pipelines, because no single tool does both well:

- **Icon** → image generator (ChatGPT / DALL·E). Square, transparent, goes in `IconId`.
- **3D model** → text-to-3D (Forge / ForgeGUI, Meshy, Rodin). Or generate a concept image first
  and use image-to-3D, which holds the silhouette much better than text alone.

ChatGPT cannot output a mesh directly. Use it for the concept image and the icon, then feed the
image into whichever 3D tool you are using.

### Shared 3D style block

Put this in front of every model prompt:

> Low-poly stylised game asset for a cartoon Roblox game. Chunky simplified forms, big readable
> silhouette, no fine detail and no thin parts. Flat solid colours, no textures, no decals, no
> text. Clean hard edges, slightly toy-like, friendly rather than gritty. Built from simple
> primitives — boxes, cylinders, tori. Single connected object, centred, upright, handle at the
> bottom and business end at the top. Low triangle count, game-ready, no interior geometry.

**Negative prompt:**

> photorealistic, PBR, ray tracing, rust texture, grunge, noise, subsurface detail, thin wires,
> fragile spindly parts, floating disconnected pieces, text, letters, numbers, logos, watermark,
> environment, ground plane, base, pedestal, background, high polygon count, hair, cloth

**Output settings:** one object, longest axis normalised, ideally under 2,000 triangles. Export
`.obj` or `.fbx`. It will arrive at the wrong scale — that is expected; the spec above says
2.0–2.5 studs and Studio is where you set it.

### Per-magnet subject lines

Append one of these to the style block.

**Scrap Hook** — free tier 1

> Subject: a crude handmade scrap grabber. A bent length of rusty rebar as a handle, with a
> chunky rectangular fridge magnet lashed to the end with grey tape and a twist of wire.
> Deliberately amateur and asymmetrical, like it was made in a yard from junk. Muted brown-grey
> metal with one strip of dull red tape.

**Workshop Coil** — free tier 2

> Subject: a hand-wound electromagnet. A thick iron cylinder core wrapped in visible chunky
> copper wire coils, a short black rubber grip below, and two stubby flat pole faces at the top.
> Two thin wires trail from the base. Warm copper-orange coils against dark grey iron.

**Industrial Electromagnet** — free tier 4

> Subject: a heavy industrial lifting electromagnet, scaled down to hand size. A wide flat
> circular steel disc head with a thick yellow-and-black hazard-striped housing above it, a
> boxy motor block, a small amber rotating beacon on top, and a chunky black grip. Safety yellow
> and steel blue-grey.

**Salvage Rig** — free tier 5

> Subject: a rugged salvage magnet with a rectangular twin-pole head, a reinforced steel frame,
> and two thick ribbed rubber hoses running down from the back of the head toward the wrist.
> Practical and heavy-looking, with bolt heads and a riveted plate. Steel blue-grey with dark
> navy fittings.

**Wrecker's Claw** — free tier 6

> Subject: a wrecking-yard lifting disc, hand sized. A thick scarred circular steel plate with a
> heavy central boss, a short stub of oversized chain links rising from the top, and a worn
> knurled grip. Battered and dented, obviously expensive and heavy. Dark rusted steel with
> darker navy shadowed recesses.

**Prestige Magnet** — earned

> Subject: an ornate horseshoe magnet trophy. Classic U-shaped magnet form with polished
> chamfered edges, a small crown motif at the top of the arch, and a fluted grip. Rich gold with
> deep amber shadowing, jewellery-like but still chunky and toy-simple.

**Void Magnet** — premium

> Subject: a sinister void magnet. A ring-shaped head made of angular dark facets with a
> perfectly black hollow centre, thin glowing violet seams tracing the facets, and a tapered
> black grip wrapped in dark banding. Almost entirely near-black with violet emissive lines
> only. Ominous, sharp, high-contrast.

**Singularity Magnet** — premium top tier

> Subject: a cosmic singularity magnet. A flat circular accretion-disc head with concentric
> layered rings around a tiny brilliant white core, a bracket of two curved arms holding the
> disc, and a smooth dark grip. Deep space purples and magentas with a white-hot centre.
> Powerful and elegant, still chunky and low-poly.

### Icon prompts

Icons use the style block in `docs/ICON_PROMPTS.md` — same near-black `#10131A` outline, flat
fills, transparent square. Subject lines: reuse the ones above but describe them as a **single
centred object, three-quarter front view, filling the frame**, and drop the "upright, handle at
the bottom" instruction, which is a modelling note rather than an icon one.

Two icons are needed for magnets that already exist:

```lua
-- src/shared/Config/InventoryConfig.luau
AdvancedMagnet.IconId = "rbxassetid://0000000000"
QuantumMagnet.IconId  = "rbxassetid://0000000000"
```

### Where everything goes

| Asset | Destination |
| --- | --- |
| Model | `ServerStorage.MagnetModels.<Id>` — named exactly the config `Id` |
| Icon | `InventoryConfig.Magnets.<Id>.IconId` — magnet icons flow through `GameData`, they do **not** go in `Assets.luau` |
| Premium product | `MonetizationConfig` entry plus a real `MarketplaceId` |
| Shop order | `InventoryConfig.MagnetOrder` |

---

## What I would do first

In order, cheapest meaningful win first:

1. **Give `QuantumMagnet` its own model.** It is a 399 R$ item that is currently a recoloured
   copy of a 60k cash item.
2. **The two missing icons.** Two of three magnets have no icon today.
3. **Fill in `MarketplaceId`.** Nothing premium is buyable.
4. **The pull tether `Beam`.** One effect, every magnet, makes collection readable.
5. **`ScrapHook` and `WorkshopCoil`.** They fill the worst gap in the progression — 4 to 12 with
   nothing to buy in between.
6. **Standardise the model scale** at 2.0–2.5 studs before there are ten of these to redo.
