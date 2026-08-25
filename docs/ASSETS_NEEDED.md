# Assets we need

Every image and model the UI can use, what is already in, and exactly where each id
goes. Paste ids straight into this file's code blocks or into the source files it
points at — both are the same thing, the blocks are just copy-paste shaped.

**Nothing here is load-bearing.** Every icon slot falls back to a procedurally drawn
glyph and every plate slot falls back to a drawn panel, so a blank id is a slightly
plainer UI, never a broken one. That means we can do this in any order, and ship
partway through.

## Where ids go

Four destinations. Which one depends on the kind of thing, not on where it appears.

| Asset group | Count still needed | Goes in | Live? |
| --- | --- | --- | --- |
| Glyph icons | 17 of 35 | `src/shared/UI/Assets.luau` → `Assets.Icons` | yes |
| Chrome plates | 0 of 19 | `Assets.luau` → `Assets.Plates` | yes |
| Game pass icons | 4 of 8 | `Assets.luau` → `Assets.Art["pass:<Id>"]` | yes |
| Pet icons | 21 of 21 | `src/shared/Config/PetConfig.luau` → `IconAssetId` | yes |
| Egg icons | 3 of 3 | `PetConfig.luau` → `eggs.*.IconAssetId` | yes |
| Item / potion / magnet icons | 2 of 7 | `src/shared/Config/InventoryConfig.luau` → `IconId` | yes |
| Upgrade art | 8 (ids already pasted) | `Assets.Art["upgrade:<Id>"]` | **no — see below** |
| Area art | 3 | nowhere yet | **no — see below** |
| Egg + pet 3D models | 3 eggs, 21 pets | `Workspace.Pets/<Egg Name>/` in Studio | yes |

Two of those rows do nothing today. Read *Not wired yet* before spending art on them.

---

## 1. Glyph icons — 17 blank

These are the small marks that appear everywhere: buttons, rows, headers, badges.
One id replaces that glyph across the whole game, at every size, with tints and
layouts unchanged. Keys must match the glyph names, which is why they are exact.

Highest value first — the top group appears on almost every screen.

```lua
-- src/shared/UI/Assets.luau, in Assets.Icons
	star = "",       -- rarity marks, Secret pet cards, the MegaBundle product
	crate = "",      -- storage passes, cash packs, the Cash Crate product
	bolt = "",       -- collection speed, Turbo Collector pass, boost readouts
	clock = "",      -- potion timers, COMING SOON notices, daily rewards
	trophy = "",     -- leaderboard, Sinister Lord pass
	medal = "",      -- leaderboard ranks
	check = "",      -- equipped ticks, completed rows
	cross = "",      -- window close, denied states
	plus = "",       -- +2 Pet Slots, buy-amount stepper
	minus = "",      -- buy-amount stepper
	chevron = "",    -- scroll hints, expandable rows
	note = "",       -- the UPDATES topbar button; label-only until this lands
	calendar = "",   -- daily rewards
	palette = "",    -- skins / cosmetics
	ground = "",     -- plot tiles
	fence = "",      -- plot fencing
	sign = "",       -- plot sign
```

Already in and working: `gameLogo`, `arrow`, `coin`, `cash`, `gear`, `robux`, `upgrade`,
`recycle`, `magnet`, `potion`, `scrap`, `lock`, `paw`, `pin`, `home`, `basket`,
`bag`, `book`, `sliders`.

There are also glyph names the drawing code knows but `Assets.Icons` has no key for:
`gears`, `storage`, `prestige`, `pet`, `area`, `inventory`. If you have art
for one, adding the key is all it takes — no other change. `cash` shares the
painted coin with `coin` (`rbxassetid://130780043686108`).

## 2. Game pass icons — 4 left

Prompts, accent colours and the full brief are already written up in
[ICON_PROMPTS.md](ICON_PROMPTS.md). Slots are pre-created, so pasting is the only
step.

```lua
-- src/shared/UI/Assets.luau, in Assets.Art
	["pass:DoubleCash"] = "rbxassetid://136753021470793",     -- DONE
	["pass:StoragePlus"] = "rbxassetid://70407724067119",     -- DONE
	["pass:FastCollector"] = "rbxassetid://79551795907555",   -- DONE
	["pass:ExtraPetSlots"] = "rbxassetid://103179431409211",  -- DONE
	["pass:QuantumMagnet"] = "",     -- Quantum Magnet       (Pink)
	["pass:SingularityPet"] = "",    -- Singularity Pet      (Cyan)
	["pass:DemonicGhostPet"] = "",   -- Demonic Ghost Pet    (Red)
	["pass:SinisterLordPet"] = "",   -- Sinister Lord Pet    (Purple)
```

## 3. Pet icons — 21

Pet cards render the real 3D model in a ViewportFrame, so these 2D icons are the
**fallback**, not the main event. They show up where a viewport is wrong or too
expensive: notifications, the announcement banner, compact rows. Worth having, but
the models below matter more.

Ids go in `PetConfig.luau` next to each pet, on its existing empty `IconAssetId`.

**Junkyard Egg**

| Pet id | Name | Rarity |
| --- | --- | --- |
| `Pup` | Pup | Common |
| `Zebra` | Zebra | Uncommon |
| `QueenKitty` | Queen Kitty | Rare |
| `PastelAngel` | Pastel Angel | Epic |
| `AutumnDragon` | Autumn Dragon | Legendary |
| `MythicAutumnDragon` | Mythic Autumn Dragon | Secret |

**Workshop Egg**

| Pet id | Name | Rarity |
| --- | --- | --- |
| `WrenchMouse` | Wrench Mouse | Common |
| `SpringFrog` | Spring Frog | Uncommon |
| `WelderBear` | Welder Bear | Rare |
| `MotorMole` | Motor Mole | Epic |
| `ChromeWolf` | Chrome Wolf | Legendary |
| `CoreDragon` | Core Dragon | Secret |

**Quantum Egg**

| Pet id | Name | Rarity |
| --- | --- | --- |
| `NeonCrab` | Neon Crab | Common |
| `CircuitOwl` | Circuit Owl | Uncommon |
| `PlasmaPanda` | Plasma Panda | Rare |
| `MagnetManta` | Magnet Manta | Epic |
| `NovaLion` | Nova Lion | Legendary |
| `NebulaLeviathan` | Nebula Leviathan | Secret |

**Premium** (the three pass pets — not rollable)

| Pet id | Name | Rarity |
| --- | --- | --- |
| `Singularity` | Singularity | Secret |
| `DemonicGhost` | Demonic Ghost | Secret |
| `SinisterLord` | Sinister Lord | Secret |

## 4. Eggs — 3 icons

```lua
-- src/shared/Config/PetConfig.luau, on each egg definition
	JunkyardEgg  IconAssetId = ""   -- Junkyard Egg,  $3,500,  Front Yard
	WorkshopEgg  IconAssetId = ""   -- Workshop Egg
	QuantumEgg   IconAssetId = ""   -- Quantum Egg
```

## 5. Items — 2 blank

```lua
-- src/shared/Config/InventoryConfig.luau
	AdvancedMagnet  IconId = ""   -- also the only cosmetic in the SKINS section
	QuantumMagnet   IconId = ""   -- the pass magnet
```

Already in: `MagnetBasic`, `CashPotion`, `StrengthPotion`, `LuckPotion`,
`GodPotion`.

**Magnets have their own document.** `docs/MAGNETS.md` covers the three that exist (measured),
a planned free ladder and premium line, the effects, the model spec, and generation prompts for
both icons and 3D. Two things it flags that belong on this page: `QuantumMagnet`'s model is
`AdvancedMagnet` with a different material — a 399 R$ item that is a recolour of a 60k cash one —
and the three existing models disagree on scale (2.43 studs vs 1.55, one of them 0.20 thick).

## 6. 3D models — in Studio, not in this file

These are the ones that actually carry the pet reveal and the summon podium, and no
id in a config replaces them. They live in the place tree, so they are a Studio job.

- **Egg models** at `Workspace.Pets/<Egg DisplayName>/Egg` — one each for
  `Junkyard Egg`, `Workshop Egg`, `Quantum Egg`. The summon UI and the hatch
  animation both read this path.
- **Pet models** — 21 of them, named after each pet's `ModelName` in `PetConfig`,
  which today equals its id. These are found by a **recursive** search under
  `Workspace.Pets`, so the folder structure is up to you; only the model's own name
  has to match. `ServerStorage.Pets` works too if you would rather keep them out of
  the workspace.

Two requirements the code depends on, both learned the hard way:

1. A pet needs a part named `AnimatedFace`, `Face` or `Head` for the camera to work
   out which way it faces. Without one, pets render facing away — the pivot alone is
   not reliable, since different models disagree about it.
2. Un-obtained pets are rendered as solid black silhouettes by blanking part colours
   and lighting. Models with baked-in textures or SurfaceAppearance may not go fully
   black, so keep materials simple.

Scale is handled for you: `PetConfig.FollowerLongestAxis` normalises every pet to the
same size in the world, with a per-pet `FollowerScale` override.

## Not wired yet

Two groups where pasting an id today does nothing. Both are a couple of lines to
hook up, using the same pattern the game passes now use — say the word and I will.

- **Upgrade art.** `Assets.Art` already holds eight `upgrade:*` ids, and nothing
  reads them. `GameData.upgradeView` returns a glyph only, so upgrade rows draw the
  glyph regardless. Those eight ids have been dead the whole time.
- **Area art.** No slot exists at all; `GameData.areas` returns a glyph only. Three
  areas: `FrontYard`, `WorkshopYard`, `VehicleGraveyard`.

## Two id bugs worth fixing while we are in here

- `Assets.Icons.paw` is **crown artwork**. Every paw in the game is a crown — the
  pet cards, `+2 Pet Slots`, the pets menu. This is the "crown behind the pets" you
  spotted earlier; it was never a stray element, just the wrong id in a shared slot.
  A real paw icon fixes it everywhere at once.
- `Assets.Icons.book` and `Assets.Icons.bag` are **the same id**
  (`125806058579575`), so the index/book mark and the inventory mark are identical.

---

## Specs

Same for everything unless a section says otherwise.

- **1024×1024, square, transparent PNG.** Not wide — every icon box in the UI is
  square, and a wide image gets letterboxed inside it. This is what went wrong with
  the first splash logo.
- **No baked-in text.** Cards, rows and buttons draw their own labels, and card
  titles specifically render their lead token oversized — art with "2X" in it fights
  that.
- **No background panel, frame or drop shadow.** Every slot supplies its own well,
  gradient, outline and corner radius. Art that brings its own box looks pasted on.
- **Check it at 128 px** before uploading. That is roughly the size a card's art well
  renders at on desktop, and smaller on phone.
- **Style:** the shared cartoon style block in [ICON_PROMPTS.md](ICON_PROMPTS.md) is
  what keeps everything looking like one set — chunky simplified shapes, thick
  near-black `#10131A` outline, flat fills with one soft gradient. Reuse it verbatim
  for any of the groups above, changing only the subject line.

Plates are the exception: they are chrome artwork rather than icons, so each is
whatever aspect the thing it backs is (a wide slab for `shopButton`, a thin bar for
`storageTrack`). All 19 are already filled from the authored UI, so they only need new
art if we restyle the chrome.

## Both id formats work

Anywhere an id is accepted you can pass a plain string or a table, when one icon
needs different framing from the rest:

```lua
Assets.Icons.coin = "rbxassetid://123"                            -- default framing
Assets.Icons.coin = { id = "rbxassetid://123", scale = 0.8 }      -- smaller in its box
Assets.Icons.lock = { id = "rbxassetid://123", color = Color3.new(1, 1, 1) }  -- tinted
```

`scale` is the fraction of the icon box the image fills, default `0.66`. Bump it when
an icon reads small, drop it when one crowds its well.

You can also bulk-load from anywhere without touching this file, which is how a
server payload or a config module could override art at runtime:

```lua
Assets.set({
	Icons = { magnet = "rbxassetid://1" },
	Art = { ["pass:DoubleCash"] = "rbxassetid://2" },
	Plates = { navButton = "rbxassetid://3" },
})
```
