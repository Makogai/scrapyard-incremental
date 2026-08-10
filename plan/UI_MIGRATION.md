# UI Migration: PackGameplayUI to the React Kit

Last updated: 2026-08-09 (migration complete, Play-verified, art + topbar pass)

Migration of the authored premium-pack UI onto a code-owned React component kit.
This document is the handover: read it, then continue from **Remaining Work**.

## Why

`PackGameplayUI` was 1,466 authored Studio instances driven by a 1,338-line
`PackUIController` that bound them by name. Every visual change meant Studio
work, every new screen meant more `WaitForChild` paths, and nothing was
reviewable in a diff. The kit replaces that with typed components in source.

## What Exists Now

### Dependencies

Wally was added alongside Rokit. `rokit.toml` pins `wally`; `wally.toml` declares:

| Package | Realm | Why |
| --- | --- | --- |
| `jsdotlua/react` 17.2.1 | shared | component model |
| `jsdotlua/react-roblox` 17.2.1 | shared | renderer |
| `littensy/ripple` 0.9.3 | shared | springs. **0.9.3 deliberately, not 0.10.x** — 0.10 uses `require("@self/…")` string requires |
| `littensy/charm` 0.11.0 | shared | atoms |
| `littensy/react-charm` 0.4.0 | shared | `useAtom` |
| `pepeeltoro41/ui-labs` 2.4.2 | **dev** | storybook — dev-dependency so it never ships to clients |

`Packages` maps to `ReplicatedStorage.Packages`. `DevPackages` and the storybook
map to **ServerStorage**, which is not replicated, so UI Labs costs players
nothing.

Run `wally install` with Rokit's wally (`C:/Users/<you>/.rokit/bin/wally.exe`) —
a stray Aftman `wally` on PATH will refuse.

### Layout

```
src/shared/UI/
  Theme / Format / Glyphs / Icon / Primitives / Motion / Sound / Assets / Hooks
  Components/    Buttons, Indicators, Inputs, Overlays, Cards, Rows, Shop
  Screens/       one file per window, plus Hud/{Desktop,Mobile,Parts,TopBar}
  State/
    Atoms.luau   Charm atoms: server-owned mirror + client-owned UI state
    Bridge.luau  the ONLY place the UI touches remotes
  GameData.luau  Shared/Config -> screen props, via the server's own GameMath
  App/
    Store.luau   the seam: exposes { state, actions } over atoms + Bridge
    init.luau    Root + App: HUD, window router, toasts, confirms
  Mock.luau      sample data, stories only
src/client/Controllers/ReactUIController.luau   mounts it
src/stories/                                    UI Labs storybook
```

### The Load-Bearing Idea

Every screen consumes exactly `{ state, actions }`. The standalone kit filled
that from local React state seeded with `Mock`; the game fills it from Charm
atoms fed by `StateChanged`. **Because the contract held, all eighteen screens
migrated without edits.** Keep it that way: a screen must never require `Bridge`,
`Atoms` or a remote directly.

`Store.Provider` has two modes:

- **live** (default) — `Bridge.start()` populates atoms; actions send intents
- **mock** (`mock = true`) — atoms seeded from `Mock`, actions mutate locally

so stories run in Edit mode with no server, no remotes and no DataStore, while
exercising the real components rather than a parallel copy.

### Security Boundary

`Bridge` sends **intents only** — an upgrade id, an area id, a pet id. No price,
level, reward, effect or unlock result ever leaves the client. `Store`'s live
actions deliberately do **not** optimistically mutate money, levels or unlocks;
they wait for the authoritative `StateChanged`. This preserves the property
Phase 8's exploit review depends on.

If you add an action and find yourself passing a number the server could compute,
stop — that is the exploit.

`GameData` computes displayed prices with the **same** `GameMath` functions
`PlayerStateService` charges with (`incrementalUpgradeCost`,
`incrementalUpgradeEffect`, `upgradeMaximumLevel`, `prestigeRequirement`,
`scaledPrestigeGearReward`, `gearValueMultiplier`), so the displayed price is the
enforced price and cannot drift.

## Screen Status

All shipped screens read live game data. `Mock.luau` is referenced only by the
UI Labs stories.

| Screen | Source of truth | Intents sent |
| --- | --- | --- |
| HUD desktop/mobile | `state` money/gears/storage/boosts | `RequestTeleport` |
| Upgrades | `GameData.upgradeView` + `state.upgradeLevels` | `RequestUpgrade` |
| Areas | `GameData.areas` + `state.unlockedAreas` | `RequestAreaUnlock`, `RequestTeleport` |
| Prestige | `GameData.prestige` | `RequestPrestige`, `MonetizationPrompt` |
| Inventory | `GameData.magnets/consumables` + `state.ownedMagnets` / `potionCounts` | - |
| Item details | same, per payload | `InventoryAction`, `ShopAction`, `PetAction`, `MonetizationPrompt` |
| Shop | `GameData.passes/products` + `state.entitlements` | `MonetizationPrompt` |
| Collection | `GameData.scrapIndex(state.discoveredScrap)` | - |
| Pets | `GameData.pets/eggs/petSlots` + `state.ownedPets` | `PetAction` (OpenEgg / Equip / Unequip / Delete / BuySlot) |
| Magnet shop | `GameData.magnets` | `ShopAction`, `InventoryAction`, `MonetizationPrompt` |
| Settings | `state.settings` | `UpdateSettings`, `RedeemCode` |

### Deliberately not shipped

- **Daily rewards, Plot customisation** - kit screens with no server system
  behind them. A window with nothing behind it is worse than no window.
- **Leaderboards** - `LeaderboardService` writes in-world SurfaceGui boards and
  exposes no client feed. A menu version would be inventing data. If a feed is
  added later, the kit's `LeaderboardScreen.luau` is still in the tree.
- **Admin** - `AdminUI` and `AdminController` are untouched and still authored.
  Admin is owner-only and already works; migrating it buys nothing.

## Verified

Measured live in Studio through the MCP against the real configs:

```
MagnetRange    lv0    9 studs -> 9.75 studs   $100   max 8
MagnetStrength lv3 p1 8.62 strength -> 10.38 strength   $758   max 18
area FrontYard $0   WorkshopYard $12500   VehicleGraveyard $125000
prestige req $350000    bulk x5 from lv0: $2644 for 5 levels
pets=21  eggs=3  slots(lv0,no pass)=1  slots(lv2+pass)=5  nextSlot=$25000
egg gating: Junkyard unlocked=true, Workshop/Quantum unlocked=false

OK HudDesktop 1043   HudMobile  375   Upgrades   2314   Inventory 1869
OK Pets       2939   Areas     1657   Prestige   1461   Shop      2205
OK Settings   1289   Collection 2265  MagnetShop 1117   FULL APP  1045
```

Quality gate green: StyLua, Selene 0/0/0, 91 Lune assertions, Rojo build.

### Live Play session

Played through the Studio MCP against a real dev-store save, driving the UI with
synthetic mouse clicks rather than by calling actions directly:

```
mount            ScrapyardReactUI enabled, 1061 instances; PackGameplayUI disabled
bridge           "Bridge connected on attempt 1", snapshot applied
canvas           root 1365x768 on a 1365x768 viewport, 0 objects off screen
HUD              gears 3, storage 7/25, est. value $124 -- all via StateChanged
click INVENTORY  opens with live magnets (Basic owned, Advanced $60K, Quantum pass)
click SELL       character (105,23,5) -> (-10,25,5), storage 7/25 -> 0/25, $0 -> $679
click UPGRADE    live prices: MagnetRange $100, 9 -> 9.75 studs; ScrapValue MAXED
buy Storage      confirm -> BUY -> $679 -> $619, level 0 -> 1, HUD capacity 25 -> 33,
                 next price recomputed to $192
```

The purchase is the whole contract in one click: intent out, nothing optimistic,
`StateChanged` back, both the window and the HUD re-render from it.

### Defects the Play session found

Every one of these passed StyLua, Selene, the Lune suite, a Rojo build **and**
Edit-mode mounting. None would have been caught without running the game.

1. `Sound.luau` called `RunService:IsEdit()`, which carries **Plugin security** --
   it answers inside UI Labs and *throws* in a LocalScript. The throw killed the
   `Buttons -> DetailsModal -> UI` require chain, so `ReactUIController` never
   reached `retireAuthoredUI()` and the old authored GUI stayed on screen. This
   was the "I hit Play and the old GUI was there" bug.
2. `Bridge.start()` set `started = true` *before* resolving the Remotes folder, so
   a single slow boot disabled live data permanently. It now latches only on
   success, and `Store` retries ten times.
3. The root canvas was `fromScale(1, 1)` under a `UIScale` of `viewport/1920`, so
   the UI covered only 71% of the screen and everything anchored to a bottom or
   right edge fell short. Now `fromScale(1/scale, 1/scale)`.
4. `Root` forwarded `live` while `Store.Provider` reads `mock`, so **every story
   ran in live mode against no server**, rendering zeros instead of `Mock` data.
5. HUD `SELL` was a live no-op and `HOME` sent `"Home"`, an id `TeleportService`
   rejects. Selling is a Touched event on the plot's `CrusherSellZone`, so `SELL`
   now teleports there via a new `MyCrusher` destination -- gated by the same
   `PlotService.GetPlot` ownership check as `MyPlot` -- and lets `SellService` do
   the selling. No sell remote exists, and none was added.
6. Area cards offered `TELEPORT` on unlocked areas, but the map has no per-area
   geometry and `destinationFor` has no area ids. Unlocked cards now read
   `UNLOCKED` and are disabled. Pass `onTeleport` again once destinations exist.

A second Play pass, after the art and topbar work, found two more:

0. **Stud plates were cut off, and the wide SHOP slab had almost none.** Two
   separate faults in `P.Studs`. First, `ceil(area / spacing)` counted one column
   and one row too many -- the run is inset at both ends and the last cell needs no
   trailing gap -- and the grid was top-left aligned, so the entire remainder piled
   against the right and bottom edges. The count now floors correctly and the grid
   is centred, which also keeps it right when `area` is slightly off a panel's true
   rendered size. Second, `MenuGrid` sized the SHOP slab with
   `UDim2.new(1, 0, 0, h)`; `WideMenuButton` reads `size.X.Offset` to work out how
   many studs fit, and a scale width reports **0**, so it drew a single column on
   the left edge. It is sized in offset now.


7. **The Settings window was entirely disconnected.** Its rows used the kit's
   camelCase names (`particles`, `music`, `sfx`) while the server persists
   `PlayerSettings` in PascalCase (`ParticlesEnabled`, `MusicVolume`), so every
   toggle read as OFF and every slider as 0% regardless of the real save, and each
   write sent a key the server ignored. Rows now use the `PlayerSettings` field
   names. Four rows the kit shipped -- other players' effects, magnet range,
   notifications, reduced motion -- had no server field at all and are no longer
   rendered; add the field to `PlayerSettings` first, then the row.

## Art and Chrome

### `src/shared/UI/Assets.luau` is the one place ids live

Every image in the UI resolves through this module, in three tables:

| Table | Keyed by | Used for |
| --- | --- | --- |
| `Assets.Icons` | glyph name (`gear`, `paw`, `home`) | replaces that icon **everywhere** it appears |
| `Assets.Plates` | chrome name (`navButton`, `statPill`) | background artwork for slabs, pills, window frames |
| `Assets.Art` | `"<kind>:<id>"` (`upgrade:MagnetStrength`) | per-entity artwork |

A blank id falls back to the procedural drawing, so clearing one never breaks a
layout. Every id currently in there was **harvested from the authored
`PackGameplayUI`** before it was retired, which is why the React UI wears the art
the game already shipped rather than the kit's placeholder glyphs.

Two exceptions, both deliberate:

- **Magnets and potions are not in `Assets.Art`.** `InventoryConfig` already
  carries an `IconId` per item and `GameData` passes it through as `image`, which
  beats the table. Edit the config for those.
- **`Assets.Icons.note` is blank.** The authored pack had no changelog art, so the
  UPDATES topbar icon runs label-only until an id lands there.

The travel buttons deliberately do **not** use the authored teleport plates
(`Assets.Plates.teleport*`, still listed). Those plates carry a baked-in label and
outline that fight the rest of the HUD, so the row uses ordinary kit buttons.
SETTINGS on the topbar is icon-only -- a flat cog, no label.

`Theme.Font.Money` and `Theme.Gradient.Money` were lifted off the authored
`MoneyValue` label so the cash readout keeps its exact original look.

### HUD layout

```
top strip     Roblox chrome (left) | UPDATES | ... | INDEX  [cog]
top centre    travel row: SHOP / MY PLOT / LEADERBOARD, hugging the top edge
              event banner directly beneath it
left          menu grid, centred vertically: UPGRADE INVENTORY PETS REBIRTH,
              with SHOP spanning underneath
bottom left   gears / rebirths / cash, cash biggest and nearest the corner
bottom centre storage meter
```

Nothing is drawn in the bottom right. `Parts.ContextActions` (SELL / HOME) is
still in the kit but is no longer rendered on desktop: MY PLOT in the travel row
covers HOME, and SELL only ever teleported to the crusher. Mobile keeps its inline
sell button on the storage meter. Re-add the cluster if the desktop wants SELL back.

HUD tiles use the `flatIcon` variant of `MenuButton` / `WideMenuButton`: no
gradient tile behind the art, and the icon runs larger to fill the space the tile
used to take. Art that carries its own background reads as a sticker on a sticker
otherwise.

Both button components also take `isNew` (red **NEW!** corner flag, `newText` to
change the word) and `wiggle` (occasional attention nudge -- `true` for the
defaults, or a table like `{ every = 4, angle = 6 }`). `Motion.useWiggle` drives it
off the shared heartbeat and a single spring, so it costs nothing while settled.
The wide SHOP slab's switches live in one place, `Parts.SHOP`; menu tiles take
theirs from their own `MENU_ITEMS` row.

### Phone / landscape

The game is landscape-locked, so there is **no separate phone HUD**: `App` always
renders `HudDesktop` and the canvas scale shrinks it. `Screens/Hud/Mobile.luau` is
the old portrait layout, still in the tree for its story but no longer routed to.

`Hooks.useScale`'s floor was lowered from 0.55 to **0.42**. At 0.55 a landscape
phone (about 750x361) got a design canvas of only ~1364x656, too short to hold the
left column, the bottom row and Roblox's touch controls at once.

`HudDesktop` takes a `touch` prop (defaulting to `Hooks.useIsTouch`, forceable for
device checks). The distinction that drives the touch layout is **whether a cluster
can steal the touch**:

- the menu column is buttons, so on touch it hangs from the top and uses smaller
  tiles (92 / 58 instead of 104 / 68) to genuinely clear the thumbstick
- cash and storage are plain frames with no input, so they cannot block movement;
  they still lift by `Theme.Safe.BottomBand` so the stick does not draw through the
  numbers

Everything else keeps its desktop position.

### Active potions

`Parts.BoostTimers` renders one `BoostTile` per running boost in the **bottom
right**:
the bottle on the same dark gradient slab the cash and gears readouts use, with
the time left underneath, and a hover tooltip naming the potion and quoting its
description. It renders nothing at all when no boost is running.

The tooltip opens **upward** and is anchored on its right edge, because a corner
tile has no room to grow down or right.

`Overlays.Tooltip` takes a **`look`** prop -- the shape of a `BOOST_VARIANTS` entry
(`color`, `gradient`, `gradientTransparency`, `transparency`, `stroke`) -- and
`BoostTile` hands it its own. The tile and its tooltip therefore share one fill by
construction and cannot drift: retune the variant and both follow. A near-solid
card beside a translucent tile was the thing to avoid.

A look with `stroke = 0` also drops the drop-shadow. Both exist to separate a solid
card from the scene; on a fill that fades to nothing they only outline the box that
is meant to disappear. Legibility survives because every kit label carries its own
black text outline.

Callers that pass no `look` get `DEFAULT_TOOLTIP_LOOK`, a mild ramp in the same
direction, still solid enough to sit over anything.

It also **sizes itself to its text** now, by the same measured-ratio trick the toast
uses. The body was a fixed 38px box with no wrapping, which silently clipped the
longer descriptions: the God Potion's runs to two lines and the card grows from 56
to 71px design to fit it.

The tile is a `TextButton` driven by `Motion.usePressable`, not a `Frame` with
`MouseEnter`: Roblox only routes hover to a frame when nothing interactive sits
above it, and the panel's own highlight and gloss layers do.

`Parts.BOOST_VARIANTS` holds the named looks and `Parts.BOOSTS.variant` picks the
shipped one. All of them run **top to bottom**: `P.gradient` rotates 90 degrees, so
keypoint 0 is the top edge and keypoint 1 the bottom.

| Variant | Look |
| --- | --- |
| `Fade` (default) | 50% opacity at the top fading to invisible at the bottom, no outline |
| `Solid` | flat two-tone wash, opaque |
| `Glass` | wider light-to-dark sweep at a fixed transparency |

The outline is dropped for `Fade` (`stroke = 0` in the variant): a border around a
slab that fades out only draws attention to the box that is supposed to be
disappearing.

**`P.Panel` gained `gradientTransparency`** for this: a NumberSequence along the
same axis as the colour ramp. Without it a panel could only ever be a flat wash of
two tones, and `PanelDeep`'s two tones (`2a4874` -> `1c3358`) are so close that the
direction of the ramp is invisible. A fade needs the alpha ramp, not the colour one.

**There is no plate-art variant, deliberately.** `Assets.Plates.statPill` -- the
artwork the cash and gears readouts wear -- is a **wide** pill. Stretched into a
square tile its left-to-right shading becomes a dark centre fading out in both
directions, which reads as sideways and wrong. Do not add it back for a square
tile. Two related traps to keep straight:

- `Indicators.StatPill` is **not** a drawn panel: it renders an `ImageLabel` with
  that plate whenever an id is configured. So a square tile cannot match those
  readouts by any means -- the art is the wrong shape. Match the *feel*, not the
  asset.
- A "matches X" claim has to be checked against the rendered instance -- class,
  image id, gradient rotation, **and the alpha ramp** -- never the tokens that fed
  it. Checking tokens is what let a flat wash ship as a "subtle gradient" twice.

The tile is exactly as tall as its contents: bottle at y 4, timer immediately
beneath, no dead band. At `extent = 62` that is a 62x70 tile.

Compare them all in the **20 Potions** story, which renders every variant at once
with the readouts alongside for exactly that check.

Toasts moved into the top-right band the potions vacated.

`Store` resolves each boost through `GameData.boost`. Note the key shapes:
`PlayerData.ActiveBoosts` is keyed **`CashBoostEndsAt`** while the consumable
declares **`BoostId = "CashBoost"`** -- `GameData.boostId` strips the suffix, and
without it every tile would fall back to showing a raw id.

### Notifications

`Overlays.Toast` sizes itself to its text. Both the title and the body wrap and
auto-size, and the card's height is derived from a measured text box:

```
contentHeight = measured.Y * (textWidth / measured.X)
```

Measuring in absolute pixels would be wrong -- everything sits under a canvas
`UIScale` -- so the measured box is converted back to design units through its own
known design width. That ratio is exact and needs no knowledge of the scale.

This matters because the server sends whole sentences as a **title** with no body
("Magnet storage full, visit your crusher"), and unwrapped that ran straight out
of the right-hand side of the card.

The card also uses the same dark panel as every other HUD readout. It was
`Theme.Color.Card` -- a mid blue with a gloss sheen -- which read as a different
design language sitting next to the cash and storage slabs, with a gold title on
top of it. The accent colour now lives only on the stripe and the icon.

### The storybook is the place of truth

`Theme.Devices` is all landscape, because the experience is locked to it -- a
portrait canvas would preview a layout that cannot ship:

| Device | Canvas |
| --- | --- |
| desktop | 1920x1080 |
| tablet | 1375x1032 (iPad Pro, landscape) |
| mobile | 750x361 (iPhone, landscape) |

- **19 Full App** is the whole client. `Device` picks the canvas, `Touch` picks the
  layout. Its screen list is now exactly `App`'s `SCREENS` table -- `daily`, `plot`
  and `leaderboards` were listed there and silently opened nothing.
- **03 HUD Phone (landscape)** previews `HudDesktop` at the phone canvas with
  `Touch` on, because there is no phone-specific HUD any more.
- `Harness.Screen` forwards a `touch` prop, so any screen story can exercise the
  touch offsets from a desktop Studio.
- **20 Potions** renders every boost-tile variant at once, with the
  cash/gears/rebirth stack alongside for reference. Controls: extent, count,
  opacity override, and a `Tooltip` switch that holds the tooltip open (UI Labs
  cannot hover). It reads the variant list out of `Parts.BOOST_VARIANTS` rather
  than hardcoding names, so a rename cannot leave it pointing at names that no
  longer exist -- and it renders an explicit "reload the place" message if that
  table comes back empty.
- **21 Updates** renders the changelog window from the real config.
- **01 Design System / Bars, Badges & Inputs** gained a `StatPill` section --
  what the HUD readouts are actually built from.
- **01 Design System / Buttons** gained `FlatIcon`, `NewFlag` and `Wiggle`
  controls, and shows the real `MENU_ITEMS` list.

Treat this as standing: a component with no story cannot be reviewed without
launching the game, and a variant with no control cannot be compared against the
others. Add the knob as a control, not a hardcoded value.

**Studio caches modules for the life of the session.** `require` is keyed by
ModuleScript, so a Studio that has already loaded `Shared.UI` keeps that copy even
after a Rojo sync: UI Labs then renders old code, and a story asking for something
the cached module lacks renders nothing at all. Reload the place to clear it. Two
consequences worth designing for, both of which cost real time here:

- Stories should read from the module (enumerate a table) rather than restate its
  contents, so a stale cache degrades instead of breaking.
- To verify freshly-synced UI, either clone `Shared.UI` and require the clone, or
  test in Play mode -- its VMs start empty. An Edit-mode probe in a long session is
  measuring whatever was cached, which is how a "verified" check came back clean on
  code that was never loaded.

### Egg summoning

Hold E at a `Workspace.NewMap.EggSummonPodium`. `PetService` attaches the prompt
itself (map geometry is authored, behaviour is not) and fires `OpenEggSummon` with
an egg id; the client never decides that a player is standing at a podium.

```
prompt -> OpenEggSummon -> EggSummonScreen -> SUMMON sends OpenEgg (an intent)
       -> eggRoll atom goes "shaking" -> server rolls -> PetResult names the pet
       -> eggRoll goes "revealed" -> Secret also broadcasts on Announce
```

The shake **is** the round trip, dressed up. The overlay goes up before the request
so there is something to watch while the server answers, and a rejected roll clears
it rather than revealing nothing. `Bridge` holds the reveal for 1.1s so a fast
server does not make the whole animation one frame.

- `Screens/EggSummonScreen` — **two rows**, not one line of six: Common/Uncommon/
  Rare on top, Epic/Legendary/Secret below, with the Secret card larger (238x196 vs
  150x172) and carrying its own VFX layer. Cards hold only what belongs on a "what
  can I roll" screen — pet, name, rarity, chance. No owned counts or duplicate
  badges; that is inventory information and it lives in the Pets window. One stroke
  per card, and the rarity is coloured text rather than a badge chip, so a small
  card is not full of nested borders.

  The split is by index, not by rarity name: `eggRoll` returns ascending rarity, so
  the first three are the top row and the Secret lands last.

  Owned pets render their real model; unowned show a **solid black silhouette** with
  the name as `???`. Chances sit underneath, and the Secret reads `?%` — `eggRoll`
  marks it `hidden` rather than sending 0.20%, so the real odds never reach the
  client.
- `Components/SecretVFX` — the layer behind the Secret pet: three stacked discs
  breathing (Roblox has no radial gradient, so falloff is faked by stacking), a
  ten-ray starburst on one slow rotation tween, seven sparkles and five motes.

  Built **imperatively** into a single host Frame rather than as React elements, and
  animated entirely by looping `TweenService` tweens (`RepeatCount = -1`, `Reverses`,
  staggered with `DelayTime`). No RenderStepped, no Heartbeat, and React never
  re-renders forty nodes. Tweens are cancelled and children destroyed on unmount, so
  closing and reopening cannot stack duplicates — verified: closing drops the counts
  to zero and three reopens hold steady.

  It runs whether or not the Secret is discovered. Bright effects around a black
  silhouette is the intended contrast.
- `Screens/EggRollOverlay` — the takeover. `App` stops drawing the HUD and any open
  window while `eggRoll` is set: nothing competes with the reveal and there is
  nothing to misclick. The shake is driven straight off the heartbeat, not a spring,
  because a shake wants a hard reversal at each end and a spring rounds that off.
- `Components/ModelView` — a ViewportFrame renderer for `PetModels` / `EggModels`,
  framed from the model's own bounding **sphere** so nothing is cropped and pets of
  very different sizes fill the same box. `spin` costs a heartbeat connection, so it
  is only used where a model is the subject.

  **Facing is derived per model, never assumed.** The pets' pivots disagree — Pup's
  points down -Z, every other Junkyard pet's down -X — so the pivot is useless as a
  front reference. What they share is an `AnimatedFace` part whose Decal sits on
  `NormalId.Front`, and `Front` is a part's -Z face, which is exactly what
  `CFrame.LookVector` reports. The camera is placed along that vector, swung 28
  degrees and lifted, giving a consistent front three-quarter view. Verified by
  measuring the dot product of (camera - centre) against each pet's face vector:
  **+0.88 = cos(28 degrees) on all six**. Before the fix it was -0.42, i.e. the
  camera was behind their heads.

  Silhouettes are genuinely black, not dimmed: every surface is recoloured black and
  forced to a lit material, surface art (Decals, Textures, SurfaceAppearance,
  emitters) is destroyed, and the ViewportFrame's own `Ambient` and `LightColor` go
  to zero so nothing can shade an edge into visibility. Verified as
  `colouredParts=0, selfLit=0, surfaceArt=0`.
- `Components/Announcement` — full-width, top of screen, `Theme.Layer.Announcement`
  (500, above everything including a takeover). **Not** a toast: toasts are the
  player's own feed and are meant to be ignorable. This is for the rare moment the
  whole server should look up. It fires only for Secret hatches; if it starts firing
  for routine events it stops working.

`Buttons.Button` gained `subtextSize` / `subtextFont`. The subtext was pinned to
`TextSize.Small`, which turned the summon price into a caption; it now renders at
heading weight (26 design px) under a 34px SUMMON label.

The Pets window lost its egg row: eggs are summoned at the podium, and offering them
in two places meant two presentations of the same action. Its grid also shows **only
owned pets** now — locked cards there duplicated the summon window and made the
collection look emptier than it was.

`GameData.petRarity` was deleted rather than fixed. It mapped Uncommon onto Common
and Secret onto Mythic, from when `Theme.Rarity` lacked those two styles; once they
existed the map was a silent lie, and the Pets window called Zebra "COMMON" while the
egg window correctly called it "UNCOMMON". Rarity now passes straight through.

Model conventions and the placeholder behaviour are in `docs/STUDIO_SETUP.md`.

### Light theme

Two palettes in `Theme.luau`, switched by `Theme.setPalette("Light" | "Dark")`.
Only **surfaces and text** move. Rarity colours, accents and button gradients are
identical in both, because those are the game's identity -- and a rarity that
changed colour with the theme would read as a different rarity.

`setPalette` mutates `Theme.Color` and `Theme.Gradient` **in place**. That is
deliberate: 41 files read `Theme.Color.X` inside their render functions, so an
in-place swap reaches all of them with no change to any of them. The only
module-scope reads are `TextSize`, `Safe` and `Devices`, none of which differ
between palettes -- checked before choosing this over a context.

Mutating a table is invisible to React, so `App` keys its subtree on the palette
name; changing it remounts and everything re-reads. Theme switching is rare, so a
remount beats threading a context through 41 files.

Two things this needed:

- **Semantic text tokens.** `P.Label` defaulted to `Theme.Color.White` with a black
  outline -- illegible on a pale panel. Labels now use `Theme.Color.Text` and
  `Theme.Color.TextOutline`, which flip (white-on-black becomes dark-on-white).
  `White` and `Ink` stay literal.
- **`Theme.Studs.Color`** is captured at load, so `setPalette` updates it by hand
  along with its transparency -- studs need more presence on a pale panel.

The toggle is a persisted setting: `PlayerSettings.LightTheme`, schema v12, in the
new **Display** section of the settings window. Preview it with `LightTheme` in the
Full App story, which drives the same settings atom the real toggle does.

Verified live: panel `1f3760 -> c4d3ea`, text `ffffff -> 16233a`, text outline
`10131a -> ffffff`, studs `6c9bd8 @0.90 -> a8bedd @0.72`, and back again, with the
server persisting the choice.

### Shop

**One scrolling page, no tabs**: FEATURED, then GAME PASSES, SKINS, RESOURCES,
separated by `Shop.SectionHeader` dividers. A player scrolls past everything on sale
instead of guessing which tab is worth opening.

Four cards across at 228x316; the window width is derived from `COLUMNS` and
`CARD_SIZE`, so widening one widens the other.

`Components/Shop` is the reusable set: `Badge`, `Price`, `BuyButton`, `ProductCard`,
`FeaturedBanner`. `Components/Shine` is the animation layer (sweep / glow /
sparkles / rays), built the same way as `SecretVFX` -- imperative, looping
TweenService tweens, no per-frame Lua, cancelled on unmount.

Three things the first pass got wrong, all fixed:

- **Effects escaped the cards.** Badges overhung the corner, which meant a card could
  not clip its own contents. Badges are inside the border now and every card, well
  and banner sets `clip = true`. Verified live: **72 effect parts, 0 unclipped**.
- **Price and CTA were two rows.** They are one control now -- `BuyButton` takes
  `robux`/`cash` and renders the amount under BUY with the currency glyph, so the
  offer and the action are the same object. The button also carries a `Shine` sweep,
  and only a buyable offer shows a price or shines.
- **Titles were one flat line.** `Shop.Title` splits a lead token and blows it up:
  **2X** over CASH FOREVER, **MEGA** over STORAGE, **+2** over PET SLOTS. Two labels
  rather than RichText, because RichText cannot give the halves different stroke
  weights and the chunky outline is the look. The split is by pattern, so products
  that do not exist yet get it too.

**A product is a data row, not a layout.** `GameData`'s `PASS_STYLE` and
`PRODUCT_STYLE` carry the accent colour, tier, badge, `featured` flag and the short
selling copy; the screen reads them and never names a product. Adding a category is
a `TABS` row plus a branch in `itemsFor`.

`benefit` is deliberately separate from the config's `Description`: that one is
written to be accurate, this one to sell, and it has to fit two lines.

The tier ladder (`Shop.TIERS`) is the value story: tier 1 is plain, tier 2 sweeps
and glows, tier 3 adds sparkles. That is what makes a bigger pack *look* more
valuable before its price is read.

Two honest constraints, both visible in game today:

- Every Robux item reads **COMING SOON**, because every `MarketplaceId` in
  `MonetizationConfig` is still `0`. `DisplayPrice` is shown so the cards are not
  priceless, but it is presentation only -- Roblox owns what is actually charged.
- The **SKINS tab has one product**: magnets are the only cosmetics that exist and
  only those with a `ShopPrice` qualify. Plot skins, crate skins and UI themes slot
  into `itemsFor` the same way.

`MagnetShopScreen` still has its own cards and was not touched.

### Where to change the HUD

| Want to change | File |
| --- | --- |
| where a cluster sits (margins, anchors) | `Screens/Hud/Desktop.luau` |
| what is in a cluster (tiles, travel row, SHOP flags) | `Screens/Hud/Parts.luau` |
| the phone layout | `Screens/Hud/Mobile.luau` |
| colours, gradients, fonts, sizes, radii, safe areas | `Theme.luau` |
| image ids | `Assets.luau` |
| the components themselves | `Components/Buttons`, `Indicators`, `Overlays` |
| spring feel and wiggle timing | `Motion.luau` |
| topbar icons and what they open | `client/Controllers/TopbarController.luau` |

Position -> Desktop, content -> Parts, look -> Theme, pictures -> Assets. The same
table is in the header comment of `Desktop.luau` so it is found from the code.

The travel row sits **inside** the topbar strip on purpose: Roblox's chrome only
occupies the left of it, so the middle is free. `Parts.TELEPORT_ITEMS` ids are
passed to the server verbatim and must match `TeleportService.destinationFor` --
adding one there without adding a destination is a button that does nothing.

### TopbarPlus

`UPDATES` (far left), `INDEX` and `SETTINGS` (right) are TopbarPlus icons
registered by `client/Controllers/TopbarController`, not React components. They are
deliberately **not** also in the menu grid: TopbarPlus owns its own selected state,
and a window reachable from two places gets two of them.

Selection is driven off the `screen` atom, not the click, so an icon also releases
when the window is closed by its X or by the backdrop. The package itself is
Studio-authored -- see `docs/STUDIO_SETUP.md` for the expected place state.

### Changelog

`Shared/Config/ChangelogConfig` -> `Screens/ChangelogScreen`. Newest first, rendered
in file order. Add an entry when you ship.

## Remaining Work

1. **Device matrix.** Re-run Phase 6's iPhone 17 Pro landscape (750x361) and
   iPad Pro M5 landscape (1375x1032) against the new UI. Safe areas come from
   `GuiService.TopbarInset`, but this has not been checked on device.
2. **Delete the old path** once the device matrix passes: remove `PackUIController.luau`,
   archive `PackGameplayUI` into `ServerStorage`, and drop `Mock.luau` from the
   shipped tree if the stories are retired too.
3. **Robux prices.** Shop cards pass `robux = 0` because every `MarketplaceId` in
   `MonetizationConfig` is still a `0` placeholder. When real IDs exist, either
   pass the price from `MonetizationService`'s live lookup or fetch it with
   `MarketplaceService:GetProductInfo`. Items with id `0` currently show a
   "not available yet" toast instead of a dead buy button.
4. **Pet hatch reveal.** `PetResult` only toasts a message; a reveal animation
   would be a better payoff, and the kit has no component for it yet.

## Rollback

One line. In `src/client/init.client.luau` swap `ReactUIController.Start()` back
to `PackUIController.Start()` and delete the `retireAuthoredUI` call, or simply
re-enable `PackGameplayUI`. Nothing authored was deleted:
`PackGameplayUI` still lives in `StarterGui`, disabled at runtime;
`ServerStorage/LegacyUIArchive` and `ServerStorage/PremiumUIReference` are
untouched.

## Deviations From CLAUDE.md

**`--!strict` is not used in the UI kit.** React components take open prop tables,
and strict Luau on ~60 component files would mean typing every prop bag or
casting to `any` at every call site — noise that hides real errors rather than
catching them. The kit is `--!nonstrict`; `State/Atoms.luau` and
`State/Bridge.luau` — the parts that touch game data and remotes — **are**
`--!strict`, and the rest of `src/` is unchanged.

If this is not acceptable, the boundary to argue about is `GameData.luau`; it
could be made strict with typed return records.

## Gotchas

- `require()` caches by ModuleScript, so a Rojo sync does **not** invalidate an
  already-required tree. To test freshly synced UI code in Edit mode, clone
  `Shared.UI` into a temp folder and require the clone.
- `screen_capture` over MCP returns only the 3D viewport — **it does not include
  GUI**. Verify UI by walking `AbsolutePosition`/`AbsoluteSize`, not screenshots.
- A `UIListLayout` on a container that has decoration children lays out the
  decorations too. `P.Chip` takes `layout` as a prop for this reason.
- Under `ZIndexBehavior.Global` a child at or below its container's ZIndex hides
  behind it. The shipped ScreenGui uses `Sibling`; `Stage` forces it for stories.
- **`key` is reserved by React and stripped from props**, so the kit's
  `key = props.key or "Button"` pattern never sees a caller's key: every composite
  button is named `Button` in the Explorer and instance paths are ambiguous.
  Address elements by measuring rects, not by path. Add an explicit `name` prop if
  readable hierarchies are ever wanted.
- When hunting off-screen elements, **skip anything under a `ClipsDescendants`
  ancestor**. `P.Studs` deliberately tiles past its `Texture` parent, which clips
  it -- a naive walk reports eight phantom escapes.
- Under `IgnoreGuiInset`, `AbsolutePosition` is reported relative to the topbar
  inset origin, so the true top of the screen is `y = -inset` (-58 at 1365x768).
  MCP `user_mouse_input` coordinates match `AbsolutePosition` 1:1 -- do not add the
  inset back or clicks land a row low.
- `RunService:IsEdit()` is plugin-security. Any plugin-gated call in shared UI code
  must be `pcall`ed or it throws the moment a LocalScript requires the module.
