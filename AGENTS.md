# Scrapyard Incremental — Agent Guide

This file is the entry point for any coding agent (Codex, Claude Code, or other).
`CLAUDE.md` contains the same engineering rules; this file is the canonical
version and both must be kept in step.

## Required Reading

**`docs/RETENTION_SYSTEMS.md`** covers the five return-to-play systems (daily rewards, playtime,
spin wheel, friend boost, onboarding). **`docs/STORE_SETUP.md`** is the Marketplace checklist.

**`docs/GAME_AUDIT.md` is the current strategic picture** — what the game is, how it measures
against genre benchmarks, the ranked weaknesses, and the prioritised roadmap for retention,
monetisation and depth. Read it before proposing new features, so work lands against the plan
rather than beside it.

Before planning or implementation work, read in this order:

1. `plan/MEMORY.md` — current status, locked decisions, verification record
2. `plan/ROADMAP.md` — phase order and gates
3. The active file under `plan/phases/`
4. `plan/UI_MIGRATION.md` — **required for any UI work**
5. Relevant architecture/economy/world plans

Update `plan/MEMORY.md` at the end of every meaningful task. It is the durable
handoff, not a diary: record completed work, decisions, verification, manual
Studio state, blockers, and the exact next action.

## The Big Recent Change: UI is now React

**The authored premium-pack UI has been replaced by a code-owned React kit.**
If you have context from before 2026-08-09, this is the thing that changed.

- **Old:** `StarterGui/PackGameplayUI` — 1,466 authored instances bound by name
  in a 1,338-line `PackUIController`.
- **New:** `src/shared/UI/` — React components in source, mounted by
  `src/client/Controllers/ReactUIController.luau`.

`PackGameplayUI` still exists in StarterGui but is **disabled at runtime**, and
`PackUIController` is no longer started. Rollback is one line in
`src/client/init.client.luau`. Do not delete either until the device matrix passes.

The React UI is **Play-verified**: it mounts, the Bridge connects, and a purchase
round-trips through the confirm modal to a server charge and back into both the
window and the HUD. See the Play session log in `plan/UI_MIGRATION.md`.

Read `plan/UI_MIGRATION.md` before touching UI. The short version:

```
src/shared/UI/
  State/Atoms.luau    Charm atoms: server-owned mirror + client-owned UI state
  State/Bridge.luau   the ONLY module that touches remotes
  GameData.luau       Shared/Config -> screen props, via the server's own GameMath
  App/Store.luau      the seam: exposes { state, actions } to every screen
  Screens/            one file per window
  Components/         the reusable kit
```

### Rules for UI work

1. **Screens consume `{ state, actions }` and nothing else.** A screen must never
   require `Bridge`, `Atoms`, or a remote directly. This contract is why all
   eighteen kit screens migrated without edits — keep it intact.
2. **Send intents, never values.** `Bridge` sends an upgrade id, an area id, a pet
   id. No price, level, reward, effect, or unlock result leaves the client. If you
   are passing a number the server could compute, that is the exploit.
3. **No optimistic mutation of authoritative state.** Live actions do not touch
   money, levels, or unlocks locally; they wait for `StateChanged`. Only settings
   echo locally, so a slider tracks the thumb.
4. **Prices come from `GameData`,** which calls the same `GameMath` functions
   `PlayerStateService` charges with. Never hardcode a price in a screen.
5. **Add a screen** by writing `Screens/<Name>Screen.luau`, registering it in
   `App/init.luau`'s `SCREENS` table, and adding an entry to `HudParts.MENU_ITEMS`
   or `TopBar.ITEMS`. `MagnetShopScreen.luau` is the reference for a
   game-specific screen; `UpgradesScreen.luau` for a config-driven one.
6. **A button with no server behind it must say so.** SELL teleports to the plot's
   `CrusherSellZone` because selling is a Touched event there and no sell remote
   exists; unlocked area cards read `UNLOCKED` because the map has no per-area
   destinations. Do not add a remote to make a button feel wired -- either give it
   a real path or make the UI honest about the gap.
7. **Every UI change ships with its story.** `src/stories` is the place of truth
   for the interface: it is where the look gets reviewed and tuned. So when you
   add a component, add a variant, or change a default, update the story in the
   same commit -- and expose the knob as a UI Labs control rather than leaving it
   hardcoded. A component with no story cannot be reviewed without launching the
   game, and a variant with no control cannot be compared against the others.
   Stories run in `mock` mode, so they must never need a server.
8. **All image ids live in `src/shared/UI/Assets.luau`** -- `Icons` (by glyph
   name), `Plates` (chrome artwork), `Art` (`"kind:id"`). Never paste an
   `rbxassetid://` into a screen or component. Item, pet and egg icons are the
   exception: `InventoryConfig.IconId` and `PetConfig.IconAssetId` already flow
   through `GameData`. `docs/ASSETS_NEEDED.md` is the full map of what art exists,
   what is missing, and which slot each id belongs in -- including which slots are
   not read yet. `docs/ICON_PROMPTS.md` holds the shared art style.
9. **The topbar is TopbarPlus, not React.** `UPDATES`, `INDEX` and `SETTINGS` are
   registered by `client/Controllers/TopbarController` and driven off the `screen`
   atom. Do not also add them to `Parts.MENU_ITEMS`.
10. **Never call a plugin-security API from shared UI code.** `RunService:IsEdit()`
   answers in UI Labs and *throws* in a LocalScript; one unguarded call took down
   the entire require chain and left the old GUI on screen. `pcall` it.
11. **Never rotate a GuiObject that has to stay inside something.** Roblox lets a
   GuiObject with non-zero `Rotation` ignore an ancestor's `ClipsDescendants`, so a
   rotated child paints over the whole screen no matter how many clipping parents
   sit above it. This is why `Shine` and `SecretVFX` contain nothing rotated: the
   sweep's diagonal comes from a rotated `UIGradient` (a property of the fill, which
   clips normally) and sparkles are rounded squares rather than 45-degree diamonds.
   Rotation is fine on something meant to overhang, like the shop button's wiggle.
12. **Never spam a notification, and never let one throw.** Two separate rules, both
   learned from the same incident.
   *Spam:* `Bridge.notify` collapses an identical toast (same Title, Body and Reward)
   into the card already on screen, refreshing it and counting it as `x3` rather than
   stacking. The queue holds four cards, so one message repeating on a tick used to
   fill the entire stack and push everything else off. Server-side throttles are still
   required on top — `ScrapService`'s magnet rejection has both a per-reason cooldown
   and a spacing between any two notices, because its old check re-fired instantly
   whenever the *reason* changed and two alternating reasons ping-ponged forever.
   *Throwing:* a toast is the one component rendered straight from a server payload.
   An error in React's render phase unmounts the **whole tree**, so a bad payload once
   left the player with nothing but the topbar. `Overlays.Toast` coerces its text for
   that reason. Fix the producer, but never rely on the producer being right.
13. **The `Notify` remote carries a plain string.** `Bridge` is what wraps it into a
   toast payload. Firing a pre-wrapped table down it is what caused rule 12's
   incident. If you want a richer toast from the server, add a dedicated remote —
   do not change what `Notify` means.
14. **Never hold a reference to anything under a plot without re-resolving it.**
   `PlotThemeService.Rebuild` destroys every child of a plot and clones fresh ones from
   the variant, and it runs on **every join**, not only when someone converts. Subscribe
   to `PlotService.OnGeometryReplaced(player, plot)` and re-resolve there. This exact
   mistake shipped three times as three unrelated-looking bugs: nothing spawning
   (`ScrapService` cached its folder and markers), every sign stuck on AVAILABLE PLOT
   (`PlotSignController` bound the card once), and standing on the crusher not selling
   (`SellService` connected `Touched` at bootstrap). Disconnect the old connection when
   you re-bind, or they stack. Details in `docs/PLOT_UPGRADES.md`.
15. **Reward claims are intents with no arguments.** Every return-to-play claim sends "claim" and
   nothing else — no day index, no reward id, no amount, no "I landed on the jackpot". `claimDaily`
   used to be called `actions.claimDaily(currentDay)`; the server must never take a claim target
   from a client. It reads what is claimable from saved data. The spin wheel decides and grants
   server-side and sends the client an index to animate to. Details in
   `docs/RETENTION_SYSTEMS.md`.
16. **Days are day numbers, never timestamps.** `DayClock.dayNumber(t)` is `t // 86400`. Anything
   asking "have they claimed today" or "was that yesterday" uses integer day comparison, because
   `now - last >= 86400` lets a player claim at 23:59 and again at 00:01.
17. **`P.compact` any children list with an optional entry that is not last.** A nil in the middle
   of a table literal leaves a hole and `ipairs` stops dead at it, silently dropping every child
   after it. That dropped the friend boost's "+0%" label for exactly the players it was written
   for — and no linter catches it.
18. **A plot's THEME decides what spawns on it, not the spawn marker.** Every plot still
   carries markers tagged `FrontYard` / `WorkshopYard` / `VehicleGraveyard` from when
   areas were fenced regions inside one yard. `ScrapService` reads the plot's
   `ActivePlotTheme` for the scrap type; the marker's own tag only decides *whether* that
   spawn point is live yet, which is what makes unlocking an area earn you more of them.
   Reading the marker for the contents is what made a Scrapyard plot spawn Workshop scrap.

## Architecture

- Use `--!strict` in every Luau source file. **One approved exception:** the React
  UI kit under `src/shared/UI` is `--!nonstrict`, because React prop tables are
  open and strict typing there means casting to `any` at every call site. Its
  `State/` modules are strict. No gameplay source changed strictness.
- Focused server services, client controllers, shared types/configuration, and
  centralized remotes.
- The server owns collection eligibility, scrap state, storage, money, upgrades,
  areas, prestige, pets, and persistence.
- Clients render attraction/effects and submit intent only. They never submit
  rewards, prices, strength, capacity, or unlock results.
- Do not scan all of Workspace every frame. Use area registries, spatial queries
  with bounded cadence, and per-player candidate limits.
- Keep balancing values configuration-driven and formulas pure and testable.

## Studio Ownership

Workspace terrain, map geometry, scrap spawn markers, machines, gates, and plot
templates are Studio-authored. Rojo owns code and configuration and must preserve
unknown Studio instances in authored containers.

**UI is no longer Studio-authored.** New UI goes in source, not StarterGui.

## Toolchain

Rokit pins the tools; Wally manages Luau packages.

```bash
./rokit.exe install                       # rojo, stylua, selene, lune, wally
"$HOME/.rokit/bin/wally.exe" install      # use ROKIT's wally
```

A stray Aftman-managed `wally` on PATH will refuse to run — call Rokit's binary
by path if `wally install` complains about `aftman.toml`.

`Packages` → `ReplicatedStorage.Packages`. `DevPackages` (UI Labs) and
`src/stories` → **ServerStorage**, so the storybook never replicates to clients.

## Quality Gate

After each implementation phase, all four must pass:

```bash
"$HOME/.rokit/bin/stylua.exe" src/
"$HOME/.rokit/bin/selene.exe" src/          # 0 errors, 0 warnings, 0 parse errors
"$HOME/.rokit/bin/lune.exe" run tests/run.luau
"$HOME/.rokit/bin/rojo.exe" build -o scrapyard-incremental.rbxlx
```

Then review remote/security and mobile performance, update plan status, list
changed files, give exact Studio tests, and distinguish automated from manual
verification. **Do not claim Studio tests passed unless they were actually run.**

## Verifying UI Without Guessing

A Roblox Studio MCP is available. Static analysis will not catch layout bugs;
measure the real instance tree instead.

- `require()` caches by ModuleScript, so a Rojo sync does **not** invalidate an
  already-required tree. Clone `ReplicatedStorage.Shared.UI` into a temp folder
  and require the clone to test freshly synced code in Edit mode.
- Mount into a `ScreenGui` under `CoreGui` with `ZIndexBehavior = Sibling`,
  `task.wait(~0.6)` for React to flush, then walk `GetDescendants()` comparing
  each object's `AbsolutePosition`/`AbsoluteSize` against its parent's.
- In Edit mode `screen_capture` returns only the 3D viewport. In **Play** mode it
  does include the GUI, which makes it the fastest check that a visual complaint is
  actually fixed — measure to find the cause, capture to confirm the look.
- Clean up the CoreGui and temp folders afterwards.

In Play mode, drive the real thing instead: `start_stop_play`, then
`user_mouse_input` clicks at measured rects, then re-read the rendered text.

- MCP mouse coordinates match `AbsolutePosition` **1:1**. Under `IgnoreGuiInset`
  that origin is the topbar inset, so the true screen top is `y = -inset` (-58 at
  1365x768) — do not add the inset back or clicks land a row low.
- When hunting elements that escape their box, **do not** treat "has a clipping
  ancestor" as proof it is contained. Two ways that reads as a false pass: the
  `ScrollingFrame` behind the whole page satisfies it, and a rotated child ignores
  the clip anyway (rule 11). Find the *nearest* clipping ancestor and check it is
  the card, then check nothing in the subtree is rotated. Overflowing rects are
  normal on their own -- `P.Studs` tiles past its clipping parent by design, and
  `Shine`'s sweep is deliberately wider and taller than its host.
- `key` is reserved by React and stripped from props, so every composite button is
  named `Button` in the Explorer. Locate elements by measuring, not by path.
- **MCP round-trip latency is seconds, so anything on a timer cannot be checked by
  wait-then-look.** A `screen_capture` issued after a click can easily land 6+
  seconds later. The spin reveal is a 3.5s window, and chasing it with screenshots
  produced four separate false "it never renders" conclusions -- the banner was
  mounting correctly the whole time.
  Instead, fire the real remote from inside the `execute_luau` call and poll in the
  same call, so no latency sits between the trigger and the measurement:

  ```lua
  local slot = ... -- capture the parent BEFORE triggering
  ReplicatedStorage.Remotes.RequestSpin:FireServer()
  for _ = 1, 60 do task.wait(0.12) ... end -- poll here, in the same call
  ```

  A conclusion from a screenshot of a transient state is not evidence. Measure
  inside one call, or extend the state's lifetime first.
- **Mouse coordinates are VIEWPORT pixels; `screen_capture` returns a different,
  larger image.** At 1365x768 the capture came back 1702 wide, so coordinates read
  off a screenshot are ~1.25x too big and clicks land somewhere else entirely --
  which silently closed a modal and looked like a broken button. Always take click
  targets from `AbsolutePosition`, never from the image.

## Scope

Build one playable phase at a time. Do not carry Snowman-specific mechanics into
the product unless `plan/LEGACY_AUDIT.md` explicitly approves reuse. Avoid
unrelated refactors and giant scripts.
