# Project Memory

Last updated: 2026-08-25

## Identity

- Product: **Scrapyard Incremental**
- Platform: Roblox, native strict Luau, Rojo/Rokit
- Audience: broad mobile-first casual players
- Core loop: move near scrap -> magnet attracts eligible scrap -> storage fills -> sell at crusher -> buy upgrades -> unlock areas -> prestige for Gears

## Current Status

- Active stage: Phase 6 UI/feedback/mobile polish implemented and validated
- Completed phases: Phase 0 - Product Reset; Phase 1 - Shared Foundations; Phase 2 - Player Data
- Next phase: Phase 7 Gears prestige and collection book, with multi-client/12-player soak retained as release QA
- New planning system: complete
- Neutral Scrapyard server/client bootstrap: complete
- Shared Scrapyard contracts/formulas: complete
- Scrapyard persistence implementation: complete and verified with nonzero Phase 3 data
- Scrapyard gameplay implementation: Phase 3 automated and single-player work complete
- Studio terrain/map production: intentionally deferred
- Manual Studio state: legacy cleanup and single-player bootstrap/foundation/core-loop checks passed

## Locked Decisions

- Full pivot from Merge a Snowman; Snowman tiers, merging, legacy plot mechanics, raids, and Heatwave are not part of the new product.
- Product direction changed on 2026-08-06 to 12 large player-owned scrapyard plots; old Snowman plot mechanics remain disallowed, but a new server-authoritative plot architecture is now required.
- Server-authoritative rewards and progression.
- Movement-only core collection; no precise aiming or mandatory collection button.
- One authored scrapyard map with three unlockable sections.
- Workspace and StarterGui remain Studio-authored/partially managed by Rojo.
- Gears are the single MVP prestige currency.
- Initial scrap roster: Can, Bolt, Plate, Tire, Appliance, Engine Part, Car Door, Scrap Car.
- Variants: Normal 1x, Rare 2x, Epic 4x, Legendary 8x, Nebula 25x. Base odds 93.825 / 5 / 1 / 0.15 / 0.025 percent.
- Do not build detailed terrain until Phase 5; use named primitive placeholders first.

## Phase 0 Completed Work

- Renamed the Rojo project and build output to Scrapyard Incremental.
- Removed Snowman player schema, tier/economy/upgrade configs, plot service, generated UI/controller, and old design documents.
- Removed the redundant Aftman manifest; Rokit remains the single pinned tool manager.
- Retained and reviewed generic logging, cleanup, rate-limiter, and server-owned remote foundations.
- Replaced environment config, remote definitions, and strict entry points with neutral Scrapyard versions.
- Preserved partial Rojo ownership for editable Workspace and StarterGui content.
- Added Scrapyard-specific Studio setup and explicit manual legacy-object cleanup instructions.

## Phase 1 Completed Work

- Added stable strict IDs/types for eight scrap objects, four variants, six upgrades, three areas, player data, derived stats, and public state.
- Configured scrap weights/values/strength gates/spawn behavior/model names and variant odds/multipliers.
- Configured bounded upgrade costs/effects, area pools/prices, first prestige, and environment numeric/performance caps.
- Added pure finite-number, cost, effect, scrap-value, capacity, prestige-reward, and Gear-multiplier formulas.
- Added fail-fast server startup validation for IDs, references, weights, dimensions, totals, prices, effects, levels, and prestige bounds.
- Expanded centralized remote definitions for future state, effects, upgrades, areas, prestige, and settings intents; no handlers or authority were added client-side.
- Pinned Lune 0.10.5 and added an executable 23-assertion foundation test suite with its own Selene Luau profile.

## Phase 2 Completed Work

- Added schema-v2 defaults, v1 migration, strict repair/clamping, corrupt-root and future-version rejection, and timestamp fields.
- Added retrying DataService load/save operations with Studio development-store isolation, expiring JobId session claims, ownership-guarded writes, and explicit session release.
- Added PlayerStateService session ownership, autosave jitter, removal/shutdown saves, safe load-failure kicks, and sanitized initial public snapshots.
- Added authored `StarterGui/ScrapyardUI` directly in Studio using Epic UI Pack by MapelMarvel panels, currency art, progress bars, and buttons; Rojo preserves it and UIController only binds stable instances.
- Added loading, money/Gears, storage, navigation, notification, and placeholder menu surfaces. Later phases populate authoritative gameplay content.
- Refined the authored HUD to visual revision 3 after live review: compact dark layered cards, orange/teal accents, a slim storage meter, and semantic Epic UI Pack icons for Upgrades, Areas, Collection, and Settings. Navigation labels remain visible beside icons for accessibility.
- Restyled the authored HUD to visual revision 5 with the broad-audience `ToyScrapyard` palette: sunny orange/yellow, aqua/blue, violet, coral, and lime; chunky navy outlines; rounded faces; white highlights; decorative bolts; and stronger pack shadows. Live Studio review confirmed readable contrast and a compact footprint.

## Legacy State

No Snowman-specific runtime source remains. Historical references exist only in planning/audit and manual cleanup documentation. Studio may still contain authored `Plots`, `HeatwaveArena`, or the old `MainUI`; Rojo intentionally does not delete these.

## Verification Record

- Previous Snowman baseline: StyLua, Selene, and Rojo build passed before pivot.
- Phase 0 on 2026-08-06: StyLua passed; Selene reported 0 errors, 0 warnings, and 0 parse errors; Rojo built `scrapyard-incremental.rbxlx` successfully.
- Phase 0 Studio bootstrap smoke test passed during later-phase Studio runs.
- Phase 1 on 2026-08-06: both Selene profiles passed; 23 Lune assertions passed; StyLua passed; Rojo built `scrapyard-incremental.rbxlx`.
- Phase 1 Studio startup/configuration validation passed during later-phase Studio runs.
- Phase 2 on 2026-08-06: StyLua passed; both Selene profiles passed; 46 Lune assertions passed; Rokit-pinned Rojo built `scrapyard-incremental.rbxlx`.
- Phase 2 Studio failure test passed in unpublished `Place1`: four retry attempts occurred, the load exhausted safely, no default session entered gameplay, and the player was kicked. No project Luau/UI errors remained on rerun.
- Phase 2 published Studio validation on 2026-08-06: the development store loaded successfully, the authored UI bound without project errors, stopping released/saved the session, and a subsequent Play session reclaimed and loaded it successfully. Nonzero gameplay-field round-trip remains covered by schema tests until Phase 3 introduces an authorized mutation path.
- UI visual revision 5 Studio smoke test passed; StyLua, Selene, and the Rokit-pinned Rojo build passed after the replication-wait adjustment.

## Phase 3 Completed Work

- Added the server-authoritative collection/storage/selling transaction boundary, pre-reservation and completion-time eligibility checks, bounded spatial queries, one-player scrap reservations, configured respawns, and debounced sell-zone transactions.
- Added client-only approved attraction rendering and live authored HUD updates/notifications; clients never submit scrap IDs, rewards, strength, capacity, value, or sale amounts.
- Authored the vivid placeholder Front Yard, toy crusher, sell pad, 18 tagged spawn markers, area bounds, and all eight scrap templates directly in Studio.
- Corrected the authored HUD to visual revision 6 by removing the cash-card bolt/highlight artifacts and reducing the storage/cash shadows to thin consistent drops.
- Fixed a real shutdown persistence race between PlayerRemoving and BindToClose by coordinating in-flight saves and recognizing released sessions.
- Phase 3 pure suite now contains 55 assertions including strength, area, capacity, and sell-award rules.
- Studio single-player validation passed: automatic movement-only collection, heavy-scrap rejection, storage updates, no reservations at 19.5/20 for oversized scrap, `$64` atomic sale, duplicate empty sale rejection, and `$304` persistence after stop/rejoin.

## Plot Refactor Completed Work

- Inspected the shared Phase 3 yard: 96x86 studs with its crusher offset around X=-30/Z=19; ScrapService, SellService, and current marker records depend on shared-world paths and lack plot ownership.
- Added configurable 12-player/12-plot targets with a 130x170 initial plot size.
- Approved the 130x170 test layout, then generated `Workspace/Plots/Plot01` through `Plot12`. The final campus groups three plots on each of four short streets around a central plaza, with entrances facing inward.
- Built the authored outdoor island environment: surrounding Terrain water, layered coast, central feature reservations, landscaping, streetlights, atmospheric sky, clouds, and warm lighting. No runtime world fallback constructs it.
- Added a vivid overhead owner card with stable avatar/name/stage/prestige/total-scrap bindings, 14 owner-only marker locations, dirt/fence starter visuals, named expansion areas, and an approval copy at `ServerStorage/PlotTemplates/StarterPlot_TestReview`.
- Replaced modal text `X` controls with round coral Epic UI Pack close-icon buttons.
- Migrated player data to schema v3 with repaired defaults for plot stage/upgrades, unlocked scrap/machines, crusher level, theme/customization, trophies, and prestige count. Physical slot IDs and runtime instances are not saved.
- Added PlotService assignment/release/teleport/ownership resolution and PlotBuildService stage/sign/avatar/reset/runtime cleanup.
- Refactored ScrapService to spawn 14 items only for assigned plots, cap per-plot populations, stamp PlotId/OwnerUserId, and reject visitors before reservation and again before reward.
- Refactored SellService to accept only the assigned owner at that plot's crusher. Studio verified an owner sale and verified that carrying nonzero storage into Plot02 did not change money or storage.
- Verified player removal resets OwnerUserId and clears 14 runtime scrap after the DataStore release save; assignment and `$840` saved state loaded correctly on rejoin.
- Archived the obsolete shared `Map` and `Gameplay` recoverably under `ServerStorage/RefactorArchive`; the final smoke test confirmed both are absent from Workspace.
- Full decisions and contracts are recorded in `plan/PLOT_REFACTOR.md`.
- Engine-integrated TestEZ coverage begins with DataService/gameplay services; Phase 1 pure logic uses the faster Lune runner.

## Phase 4 Completed Work

- Added a rate-limited `UpgradeService` and synchronous server-calculated purchase transaction; clients submit only an upgrade ID and never price, effect, or target level.
- Implemented all six configured upgrades through the existing derived-stat path, including immediate Humanoid WalkSpeed refresh and authoritative state pushes.
- Authored six vivid Epic-style scrolling upgrade cards directly in `StarterGui`, showing level, next effect, price, max state, and affordability.
- Authored a six-meter upgrade rack on every plot and added non-destructive `PlotBuildService.Refresh` behavior so plot appearance rebuilds from saved upgrade levels without clearing scrap.
- Studio verified purchase deduction/effect, malformed requests, rapid requests, insufficient funds, persistence, character speed, and saved plot-meter rebuild. StyLua, Selene, 64 Lune assertions, and Rojo build pass.

## Phase 5 Completed Work

- Authored Front Yard, Workshop Yard, and Vehicle Graveyard sections directly into all 12 plots, including two owner-state gates, distinct route materials/colors, workshop canopy/crates, generic vehicle wreck props, and compact gate cards.
- Expanded each plot to 22 area-tagged markers (8/7/7). Twelve full plots remain bounded at 264 active scrap versus the global 300 cap.
- Refactored ScrapService to preserve each marker's area through pool selection, instance attributes, collection authority, and respawn instead of hard-coding Front Yard.
- Added sequential server-owned area purchases, gate refresh, plot-stage progression, saved scrap unlocks, and an authored three-card Epic-style Areas menu.
- Studio verified locked-area rejection, normal Front collection, invalid/order/funds rejection, exact-price Workshop purchase, gate opening, stage 2, persistence, and Workshop collection after meeting strength. iPhone 17 Pro landscape UI passed at 750x361 and the simulator was reset.
- Phase 5 quality gate: StyLua and Selene pass, 71 Lune assertions pass, and Rojo builds successfully.

## Visibility and Admin Follow-up

- Hid the authored plot upgrade rack on all plots while preserving it for possible later redesign.
- Locked expansion props/floors now remain hidden until that plot owner unlocks the area. Unowned plots show no expansion geometry or gate prompts; authored defaults are hidden in Edit mode and rebuilt from saved state during assignment.
- Added client-local prompt filtering so a player sees floating area gate cards only for their assigned plot. Unlocked prompts disappear.
- Added a secure owner admin foundation for user ID `1113999731`. The authored admin panel supports Self/All loaded-player targeting, amount entry, add cash, add Gears, unlock all areas, max upgrades, and clear storage.
- `AdminService` independently checks the allowlist, payload types, target mode, grant caps, and rate limit before using server-owned mutations. Non-admin clients cannot gain authority by cloning or firing the UI remote.
- Live Studio verified rack suppression, zero expansion parts/prompts on an unowned plot, one owner prompt on a locked area, unlocked-area reveal, prompt removal, cash grant, All-target Gears/max upgrades, WalkSpeed 24, and PlotStage 3.
- Corrected unreadable admin controls: thick contextual `UIStroke` objects were outlining button/TextBox glyphs. All admin input/control strokes now use `ApplyStrokeMode.Border`; live desktop capture confirmed crisp labels and amount text.

## Phase 6 Completed Work

- Implemented saved Particles, Screen Effects, Sound, and Music settings with server validation and shared client preference enforcement.
- Authored the Settings modal, responsive toggle cards, feedback `UIScale` hooks, icon-only navigation collapse control, and four empty named audio replacement hooks in SoundService.
- Added curved/spinning attraction, optional collection sparks, rare highlight, money/storage/notification pulses, throttled storage-full/too-heavy notices, and presentation-only crusher press feedback.
- Modal visibility now hides owner ADMIN and suppresses notifications, eliminating compact-screen overlay collisions.
- Desktop, iPhone 17 Pro landscape 750x361, and iPad Pro M5 landscape 1375x1032 passed live visual checks. The simulator was reset and Particles restored ON after persistence/suppression testing.
- Phase 6 quality gate: StyLua and Selene pass, 73 Lune assertions pass, and Rojo builds successfully.

## Phase 7 Completed Work

- Prestige is a rate-limited server transaction using shared `PrestigeConfig`/`GameMath`; the client submits no reward or reset values.
- Eligibility begins at `$750,000`. Each successful prestige grants the server-calculated Gears, increments `PrestigeCount`, and cannot double-grant when duplicate requests arrive after the reset.
- Money, storage, all normal upgrades, plot stage, and area access reset. Front Yard remains unlocked; Workshop Yard and Vehicle Graveyard become locked. Gears, discoveries, lifetime counts, best variants, settings, customization, and permanent data remain.
- `StarterGui` contains the authored `PrestigeButton`, `PrestigeMenu`, `PrestigeContent`, `PrestigeAction`, and eight stable `CollectionRow_<ScrapId>` cards. Do not replace them with runtime-created UI.
- Undiscovered cards reveal no identity or stats. First discoveries and improved best variants notify the player from the authoritative collection path.
- Live Studio verified an eligible reset, duplicate-request protection, exact reset/preserve state, and stop/rejoin persistence. StyLua, both Selene profiles, 73 Lune assertions, and Rojo build pass.

## Phase 8 Hardening In Progress

- First exploit/concurrency review found no client-supplied reward, price, unlock, sale, collection, or prestige result. Mutations are synchronous server transactions, and world ownership is checked before collection/selling.
- All remote rate-limit buckets now remove departed players, preventing slow table growth in long-running servers. `RequestInitialState` is newly limited to four calls per five seconds.
- Data load failure, corrupt roots, future schemas, active foreign leases, and save ownership loss fail closed. A rejected load creates no session/plot and therefore cannot overwrite progress with defaults.
- SceneAnalysisService measured 5,385 runtime instances, 77,021 triangles, and 179 draw calls from the active view. The 11 unparented instances belonged to standard PlayerModule/character behavior. Custom script memory could not be queried because Studio reports the `STUDIOPLAT37936` flag unavailable.
- `docs/RELEASE_CHECKLIST.md` now records exact production flags/DataStore isolation, asset checks, multiplayer/device matrix, failure drills, economy timing run, and go/no-go criteria.
- Automated hardening gate remains green: StyLua, both Selene profiles, 73 Lune assertions, and Rojo build pass.
- Prestige UI follow-up: centered the modal action, corrected the navigation button's inherited right alignment/icon spacing, and explicitly displays `10.0x (MAX)` / `VALUE CAP REACHED` when the permanent multiplier is capped. The development profile has 20,026 test Gears, so its value multiplier correctly remains at the configured 10x cap.
- Locked-area follow-up: Workshop/Vehicle geometry, gates, barriers, billboards, and scrap are now completely absent until the area is unlocked. Area purchases remain available through the Areas menu; unlock/prestige/admin mutations rebuild the active scrap set from the new authoritative area state.
- Added a two-click `RESET TEST PROFILE` control to the authored admin panel. `ResetTestProfile` is server-rejected outside Studio and only permits Self targeting; it replaces the current development session with schema defaults and refreshes movement, plot appearance, and scrap.
- Applied the reset to user `1113999731`'s development profile and verified after stop/rejoin: Money 0, Gears 0, PrestigeCount 0, TotalScrapCollected 0, storage 0, six upgrades at 0, only Front Yard unlocked, zero visible Workshop/Vehicle parts, and eight Front Yard scrap items.

## Inventory and Magnet Foundation

- Added schema v4 inventory state: `OwnedMagnets`, `EquippedMagnet`, counted `Inventory`, and absolute `ActiveBoosts` expiry timestamps. Older saves migrate to owned/equipped Basic Magnet with empty consumables.
- Added configured equipment/consumables. Basic Magnet preserves the original 4 strength/18 range baseline; upgrade gains stack above magnet bases. Cash Potion gives 2x sale value and Strength Potion gives +15 strength, each for 10 minutes.
- Moved the user-authored `MagnetBasic` UnionOperation from Workspace to `ServerStorage/MagnetModels/MagnetBasic`. `InventoryService` clones, massless-welds, and lifecycle-refreshes the equipped model on the right hand/arm.
- Authored `InventoryButton`, `InventoryMenu`, Basic Magnet card, and two potion cards directly in `StarterGui`. Equip/use requests are type-checked, rate-limited, ownership/count validated, and server timed.
- Added Studio-only Self-target `GRANT 3 OF EACH TEST POTION` to the admin panel. Live verified held Union/WeldConstraint, unchanged 4/18 baseline, potion counts 3→2, strength 4→19, scrap value 1x→2x, and server expiry timestamps. Reset the development profile clean after QA.
- Inventory design and extension rules are recorded in `plan/INVENTORY_EQUIPMENT.md`. Quality gate now passes 76 Lune assertions plus StyLua, both Selene profiles, and Rojo build.
- Rebuilt the first inventory list into a polished tabbed collection interface: Magnets and Consumables have two-column item grids, selected-card outlines, a large color-matched item preview, descriptions/stats/status, and one contextual Equip/Use action. Skins has a distinct `COMING SOON` panel. Live desktop testing verified tab switching, card filtering, default selection, and contextual empty/equipped states.
- Added the user-authored multi-part Advanced Magnet as a locked 12-strength/24-range option with cyan/violet particles, glow, and Highlight governed by presentation settings. Live equip verification confirmed the held Model and derived stats.
- Added schema-v5 one-time code redemption and a Settings code-entry card with inline success/error state. Definitions are server-only and support enabled, Studio-only, starts, expiry, stable redemption ID, and bounded magnet/item/currency rewards. `STUDIOKIT` is a non-production QA code for Advanced Magnet plus two of each potion.
- Added centralized `AudioConfig` and populated the authored hooks with one ambient music track plus collect/sell/confirm effects. IDs, attribution, replacement instructions, and code-management instructions are in `docs/CONTENT_CONFIG.md`.
- Added saved 0–100% SFX and Music sliders as authored Settings rows. They update visually while dragging, send one bounded value on release, and multiply centralized base audio volumes. Live verified 35% SFX and 25% Music, including the music hook scaling from 0.16 to 0.04.
- Authored `Workspace/SharedHub/MagnetShop`: a vivid booth, cartoon shopkeeper, permanent sign, and proximity prompt. The prompt opens an authored Advanced Magnet shop modal. `ShopService` owns the `$5,000` price transaction and rejects insufficient funds, duplicate ownership, malformed actions, and rapid requests.
- Live shop QA verified `$0` rejection, exact `$5,000` deduction to zero, ownership grant, duplicate rejection, and owned-state UI. The development profile was reset clean after testing (default 80% SFX, 55% Music, Advanced Magnet locked).
- Added a client-only animated range visualization built from 36 cyan neon segments. Advanced Magnet displays a second violet counter-rotating layer at its authoritative 24-stud range, while Basic shows one layer at 18 studs; Screen Effects disables the visualization.
- Strengthened the held Advanced Magnet to two enabled particle emitters and a 2.5-brightness point light. Added centralized item image IDs/glyph/color fallbacks and an authored six-slot code reward reveal. Live QA verified `BETA` revealed Advanced Magnet x1 plus both potions x2, then Advanced equip produced 72 visible range segments, range 24, two emitters, and brightness 2.5.
- Inventory/range/reward follow-up quality gate: StyLua, both Selene profiles, 79 Lune assertions, and Rojo build pass.
- Added the authored Exclusive Shop with four permanent passes and six repeatable developer products. Central configuration uses zero-ID safe placeholders, Studio admin-only grant simulation, live Marketplace price lookup, join-time pass reconciliation, and idempotent receipt delivery saved before acknowledgement.
- Added the premium Quantum Magnet at 25 strength/32 range with a pink/cyan two-emitter effect and inventory card. Permanent benefits are 2x sale value, +50% storage, 2x collection speed, and Quantum ownership; all survive prestige.
- Fresh-profile Studio QA verified baseline-to-premium stats (storage 20 to 30, collection 24 to 48, sale value 1 to 2), Mega Bundle delivery ($100,000 and 10 of each potion), and Quantum equip/effect. Profile was reset afterward.
- Created branch `ui/full-rework` and rebuilt the complete authored `ScrapyardUI` around the Epic UI Pack base elements. HUD, storage, navigation, all eight menus, Admin, notifications, loading, and code rewards now share vivid toy-like gradients, cream card surfaces, plum construction borders, highlights, and consistent close controls.
- Added modal world dimming, automatic Backpack hotbar suppression while overlays are open, compact viewport scaling, and a full-canvas phone modal strategy. Fixed the storage bar anchor and included Exclusive Shop in navigation collapse behavior.
- Device Simulator QA passed iPhone 17 Pro landscape (749x361), iPad Pro M5 13-inch landscape (1374x1030), and default desktop. Simulator returned to default, Studio returned to Edit mode, and client bootstrap completed.
- Fixed the Exclusive Shop controller's nested-card lookup: `WaitForChild(..., true)` incorrectly treated the timeout parameter as recursive search; binding now uses asserted recursive `FindFirstChild`.
- Reworked the short finite economy into a long-form incremental loop. Schema v7 adds Scrap Flow and preserves/migrates seven run upgrades with an exploit-defense ceiling of one million levels; all UI rows display `LV. N / INF`.
- Upgrade prices now use hybrid polynomial/root-exponential growth. Strength, storage, collection speed and value continue compounding; range and movement use safe asymptotic curves; Scrap Flow reduces configured respawn delays toward 0.18x with a hard 0.45-second server floor.
- Workshop/Vehicle unlocks now cost $75K/$2.5M, Advanced Magnet costs $350K, and first prestige requires $25M. Each prestige requirement grows 2.2x, Gear rewards scale with overdrive and prestige history, and permanent Gear value uses an uncapped-feeling power curve instead of the reachable 10x finish.
- Live Studio QA verified clean schema-v7 migration/defaults, level-one Flow (1.0 to 0.957x) and Value (1.0 to 1.085x), safe level-100 stats, exact first prestige, next requirement $55M, all-seven-level reset, and clean test-profile reset.

## React UI Migration Complete

- Replaced the authored `PackGameplayUI` binding path with a code-owned React UI kit under `src/shared/UI`. Full detail is in `plan/UI_MIGRATION.md`. `AGENTS.md` is the new agent entry point and carries the same rules as `CLAUDE.md`.
- Added Wally beside Rokit. React 17.2.1, ReactRoblox 17.2.1, Ripple 0.9.3, Charm 0.11.0, and ReactCharm 0.4.0 are shared dependencies; UI Labs 2.4.2 is a dev dependency mapped to ServerStorage so the storybook never replicates to clients.
- State is Charm atoms. `UI/State/Atoms.luau` holds a server-owned mirror of `PublicPlayerState` plus client-only window and selection state; `UI/State/Bridge.luau` is the only module that touches remotes.
- Every screen consumes `{ state, actions }`. Preserving that contract let all eighteen kit screens migrate without edits. `Store.Provider` runs live against the server or in `mock` mode for stories, and screens cannot tell which.
- The client submits intents only: an upgrade ID, an area ID, a pet ID. No price, level, reward, effect, or unlock result leaves the client, and live actions never optimistically mutate money, levels, or unlocks. Only settings echo locally so sliders track the thumb.
- `UI/GameData.luau` derives displayed prices, effects, level caps, prestige requirements, and pet slot counts from the same `GameMath` and configuration the server enforces with, so displayed and charged values cannot drift.
- All shipped screens read live data: HUD, Upgrades, Areas, Prestige, Inventory, Item Details, Shop, Collection, Pets, Magnet Shop, and Settings including code redemption. `Mock.luau` is now referenced only by stories.
- Added `MagnetShopScreen` for the world booth prompt. Removed Daily Rewards and Plot Customisation from the router because no server system backs them, and left Leaderboards out because `LeaderboardService` writes in-world boards with no client feed.
- `PackGameplayUI` is disabled at runtime, not deleted; `PackUIController` is no longer started. Rollback is one line in `src/client/init.client.luau`.
- Deviation from the strict-Luau rule, recorded in `AGENTS.md` and `CLAUDE.md`: the UI kit is `--!nonstrict` because React prop tables are open. `State/Atoms.luau` and `State/Bridge.luau` are `--!strict`, and no gameplay source changed strictness.
- Verified live in Studio against real configs: MagnetRange level 0 shows 9 to 9.75 studs at $100 with cap 8; Workshop $12,500 and Vehicle $125,000; first prestige $350,000; bulk x5 from level 0 costs $2,644; 21 pets, 3 area-gated eggs, pet slots 1 at base and 5 with both upgrades plus the pass. All eleven screens and the full app mounted without error.
- Quality gate green: StyLua, Selene 0 errors / 0 warnings / 0 parse errors, 91 Lune assertions, Rojo build.
- Play-verified end to end through the Studio MCP with synthetic mouse clicks, not by calling actions directly: the React UI mounts and the authored `PackGameplayUI` is disabled; the Bridge connects and the HUD shows real save data; clicking SELL teleports the character onto the crusher zone and money goes $0 to $679 with storage 7/25 to 0/25; buying Storage Capacity goes through the confirm modal, costs $60, raises the level 0 to 1, and updates the HUD capacity from 25 to 33 with the next price recomputed to $192. Nothing is optimistic; every number arrives via `StateChanged`.
- Six defects that passed StyLua, Selene, Lune, a Rojo build and Edit-mode mounting were only found by playing. Full list in `plan/UI_MIGRATION.md`. The headline one: `Sound.luau` called `RunService:IsEdit()`, which carries Plugin security and throws in a LocalScript, killing the whole require chain so the old GUI stayed on screen. Any plugin-gated call in shared UI code must be pcall'ed.
- Also fixed while playing: the root canvas covered only 71 percent of the screen because a `fromScale(1, 1)` frame sat under a `UIScale`; every UI Labs story was silently running in live mode because `Root` forwarded `live` while the provider reads `mock`; the HUD SELL button was a no-op and HOME sent an id `TeleportService` rejects.
- Selling is a Touched event on the plot's `CrusherSellZone` and there is deliberately no sell remote. The SELL button teleports the player there through a new `MyCrusher` destination in `TeleportService.destinationFor`, behind the same `PlotService.GetPlot` ownership check as `MyPlot`. Do not add a sell remote.
- Area cards no longer offer TELEPORT: the map has no per-area geometry and `destinationFor` has no area ids, so unlocked cards read UNLOCKED and are disabled until destinations exist.
- Art pass: every image id the UI uses was harvested out of the authored `PackGameplayUI` before it was retired and now lives in `src/shared/UI/Assets.luau` under `Icons`, `Plates`, and `Art`. Nothing else in the UI may hardcode an asset id. `Theme.Font.Money` and `Theme.Gradient.Money` reproduce the authored cash readout exactly.
- HUD layout reworked: travel row (Shop / My Plot / Leaderboard) hugs the top centre inside the topbar strip with the event banner directly beneath it; the menu grid is centred vertically on the left and no longer carries INDEX; the bottom-left stack is gears, rebirths, then cash as the big green number.
- `UPDATES`, `INDEX` and `SETTINGS` are TopbarPlus icons registered by `client/Controllers/TopbarController`, driven off the `screen` atom so they release when a window is closed any other way. TopbarPlus is a Studio-authored package in `ReplicatedStorage/TopbarPlus` with its `READ_ME` script disabled; see `docs/STUDIO_SETUP.md`.
- New `Shared/Config/ChangelogConfig` and `Screens/ChangelogScreen` back the UPDATES window. Add an entry when you ship.
- Found and fixed in the second Play pass: the Settings window was fully disconnected because its rows used the kit's camelCase names while the server persists `PlayerSettings` in PascalCase. Four rows with no server field behind them were removed rather than left as toggles that remember nothing.
- Play-verified again with real clicks: topbar Settings opens and mirrors the live save (Music ON, Music Volume 9%, Sound Volume 68%, Particles ON), topbar Updates renders all three changelog releases, the LEADERBOARD travel button teleported the character to within 2.7 studs of the destination part, and the HUD reports zero off-screen objects at 1365x768.
- HUD trimmed further: AREAS left the menu grid (four tiles now), the bottom-right SELL/HOME cluster is no longer rendered on desktop, and the cash pill lost its icon so the green number stands alone as it did in the authored HUD. `Parts.ContextActions` still exists in the kit if SELL is wanted back.
- HUD tiles use the new `flatIcon` variant of `MenuButton`/`WideMenuButton`: bare art, no gradient tile, larger icon. The travel row uses ordinary kit buttons rather than the authored teleport plate art, and the topbar SETTINGS icon is a flat cog with no label.
- Fixed two stud-plate faults in `P.Studs`: the column/row count rounded up when it should floor (the run is inset at both ends and the last cell needs no trailing gap) and the grid was top-left aligned, so all the slack piled against the right and bottom edges; it now floors and centres. Separately, `MenuGrid` sized the wide SHOP slab with a scale width, and `WideMenuButton` reads `size.X.Offset` to size the stud area, so it saw 0 and drew one column. Verified live: every plate now has symmetric margins.
- `MenuButton`/`WideMenuButton` gained `isNew` (red NEW! corner flag) and `wiggle` (occasional nudge, via the new `Motion.useWiggle`, driven off the shared heartbeat so idle costs nothing). The wide SHOP slab's switches are collected in `Parts.SHOP`; per-tile ones live on the `MENU_ITEMS` row. The SHOP slab's gold `glow` ring was removed -- it sat outside the slab's own outline and read as a second, mismatched border.
- `Screens/Hud/Desktop.luau`'s header comment carries the "where to change the HUD" map (position -> Desktop, content -> Parts, look -> Theme, pictures -> Assets, topbar -> TopbarController). Same table is in `plan/UI_MIGRATION.md`.
- The game is landscape-locked, so there is no separate phone HUD: `App` always renders `HudDesktop` and the canvas scale shrinks it. `Hud/Mobile.luau` (portrait) is still in the tree for its story but is not routed to. `Hooks.useScale`'s floor dropped from 0.55 to 0.42, because at 0.55 a landscape phone only got a ~1364x656 design canvas.
- Touch handling turns on whether a cluster can steal the touch, not on where it sits: the menu column is buttons so on touch it top-anchors and shrinks its tiles to clear the thumbstick; cash and storage are inert frames so they only lift by `Theme.Safe.BottomBand`. `HudDesktop` takes a `touch` prop so the device checks can force it on a desktop Studio.
- Active potions now have a HUD element: `Parts.BoostTile` in the top right -- bottle on the dark gradient slab, time under it, hover tooltip with the potion name and description. It is a `TextButton` on `Motion.usePressable`, not a `Frame` with `MouseEnter`, because Roblox will not route hover to a frame that has interactive layers above it.
- Key-shape trap, the same class as the settings bug: `PlayerData.ActiveBoosts` is keyed `CashBoostEndsAt` while the consumable declares `BoostId = "CashBoost"`. `GameData.boostId` strips the suffix; without it every tile shows a raw id.
- MCP `user_mouse_input` clicks work but `moveTo` does not park the cursor (`Mouse.X/Y` stayed at the corner), so hover cannot be verified through it. Verified the tooltip instead by forcing it on, measuring, and reverting.
- Potion tiles moved to the bottom right, with the tooltip opening upward and anchored on its right edge. They use `Theme.Gradient.Glass` at `transparency = 0.18` rather than a solid slab, collected in `Parts.BOOSTS`. Toasts took over the top-right band the potions vacated.
- `Overlays.Toast` now sizes itself to its text: title and body both wrap and auto-size, and the card height comes from a measured text box converted back to design units via `measured.Y * (textWidth / measured.X)` -- absolute pixels would be wrong under the canvas UIScale, and that ratio needs no knowledge of the scale. The trigger was the server sending whole sentences as a *title* with no body ("Magnet storage full..."), which ran off the right edge. Verified live: overflow went from +52px to -19px.
- Toast palette moved onto the dark panel the rest of the HUD uses; it was `Theme.Color.Card` (mid blue, glossy) with a gold title, which read as a different design language. The accent colour now lives only on the stripe and icon.
- `Theme.Devices` is all landscape now (desktop 1920x1080, tablet 1375x1032, mobile 750x361) so the storybook previews layouts that can actually ship. Story 03 previews `HudDesktop` at the phone canvas with `Touch` on; story 19 Full App gained a `Touch` control and its screen list is now exactly `App`'s SCREENS table (`daily`, `plot` and `leaderboards` were listed and opened nothing). `Harness.Screen` forwards `touch`.
- Reminder that bit twice while measuring: React strips `key` from composite components, so `P.Label` instances are all named "Label" and `HudDesktop`'s root is "Group". Find HUD pieces by walking the tree or by their text, never by instance name.
- Standing rule now recorded in `AGENTS.md`: every UI change ships with its story updated, and every new knob is exposed as a UI Labs control rather than hardcoded. `src/stories` is the place of truth for the interface.
- Potion tile looks are named in `Parts.BOOST_VARIANTS`, all running top-to-bottom (`P.gradient` rotates 90 degrees, so keypoint 0 is the top edge). Default is `Fade`: 50% opacity at the top edge fading to fully invisible at the bottom (never near-solid, since the tile is shading over the game view), and no outline -- a border around a slab that fades out only draws attention to the box that is meant to be disappearing. A variant can set `stroke = 0` to drop it. `Solid` and `Glass` are flat-transparency alternatives. `P.Panel` gained `gradientTransparency` (a NumberSequence on the same axis as the colour ramp) to make this possible -- previously a panel could only be a flat two-tone wash, and `PanelDeep`'s two tones are so close the ramp direction was invisible. A fade needs the alpha ramp, not the colour one.
- No plate-art variant, deliberately: `Assets.Plates.statPill` is a wide pill, so stretching it into a square tile makes a dark centre fading out both ways. A square tile cannot match those readouts at all -- the art is the wrong shape -- so match the feel instead. `Indicators.StatPill` renders an `ImageLabel` with that plate when an id is configured, not a drawn panel.
- The tile is exactly as tall as its contents: bottle at y 4, timer immediately beneath, 62x70 at `extent = 62`. The timer used to be pinned to the bottom edge with a 9px dead band above it.
- Trap worth remembering: **`Indicators.StatPill` is not a drawn panel.** It renders an `ImageLabel` with `Assets.plate("statPill")` whenever an id is configured and only falls back to a painted panel otherwise. Matching it by copying gradient tokens produces a slab that visibly stands out, which is what the first attempt did. `BoostTile` now makes the same plate-or-panel decision. Verify a "matches X" claim by comparing the rendered instance (class and image id), never the tokens.
- New stories: **20 Potions** (variant / opacity / size / count / tooltip-hold, with the readouts rendered alongside for comparison) and **21 Updates** (changelog from the real config). The design-system Buttons story gained `FlatIcon`, `NewFlag` and `Wiggle` controls; the Feedback story gained a `StatPill` section. 27 story modules, all requiring cleanly.
- `BoostTile` takes `tooltipVisible`, because UI Labs cannot hover and the tooltip could not otherwise be styled.
- Studio caches modules for the whole session: a Studio that already loaded `Shared.UI` keeps that copy after a Rojo sync, so UI Labs renders old code and a story asking for something the cached module lacks renders nothing. Reload the place to clear it. Stories therefore enumerate from the module (`Parts.BOOST_VARIANTS`) instead of restating its contents, and the Potions story shows an explicit "reload" message if the table is empty. To verify freshly-synced UI, clone `Shared.UI` and require the clone, or test in Play mode where VMs start empty.
- `Overlays.Tooltip` takes a `look` prop shaped like a `BOOST_VARIANTS` entry, and `BoostTile` hands it its own, so a tile and its tooltip share one fill by construction and cannot drift apart -- verified identical for all three variants. A look with `stroke = 0` also drops the drop-shadow, since both only outline a box that is meant to fade away; kit labels carry their own text outline so legibility survives. The tooltip also sizes itself to its text via the same measured-ratio trick as the toast. Its body used to be a fixed 38px box with no wrapping, which silently clipped the longer potion descriptions -- the God Potion needs two lines, and the card now grows 56 -> 71px to fit.
- Egg summoning shipped for the Junkyard egg, generalised to all three. Flow: hold-E prompt on `Workspace.NewMap.EggSummonPodium` (attached by `PetService`, not authored) -> `OpenEggSummon` -> `EggSummonScreen` -> SUMMON sends an `OpenEgg` intent -> `eggRoll` atom "shaking" -> server rolls -> `PetResult` names the pet -> "revealed". The shake is the round trip dressed up; `Bridge` holds the reveal 1.1s so a fast server still animates. A rejected roll clears the overlay.
- The six Junkyard pets were renamed to match their authored models (Pup, Zebra, Queen Kitty, Pastel Angel, Autumn Dragon, Mythic Autumn Dragon = Common..Secret). `PlayerDataSchema` version 11 migrates old ids so nobody loses pets. Chances are 55/25/12/6/1.8/0.2%; the Secret renders as `?%` because `GameData.eggRoll` marks it `hidden` rather than sending the number.
- New UI: `Components/ModelView` (ViewportFrame renderer over `ReplicatedStorage.PetModels` / `EggModels`, with a silhouette mode for unowned pets), `Screens/EggSummonScreen`, `Screens/EggRollOverlay` (full takeover -- `App` hides the HUD and any open window while `eggRoll` is set), and `Components/Announcement` (full-width top banner at `Theme.Layer.Announcement` = 500, for Secret hatches only, broadcast on the new `Announce` remote).
- `Theme.Rarity` was missing `Uncommon` and `Secret`, so two of the six pet rarities were silently falling back to Normal grey. Added, and `PetRarityOrder` now lists the real six. Also added `Format.chance` -- `Format.percent` prefixes a "+" and rounds too hard for a 0.20% drop.
- Model conventions: one folder per egg under `Workspace.Pets` named after the egg's DisplayName, holding `Egg` plus its six pets, names matching `ModelName`. `PetService` publishes to `ReplicatedStorage.PetModels`/`EggModels` then moves the source into ServerStorage. A missing `Egg` gets a generated placeholder and a warning; a missing pet model falls back to its glyph. Those folders do not exist in Edit mode until the place has been played once since the last sync. Full detail in `docs/STUDIO_SETUP.md`.
- Egg/pet config invariants (six per egg, weights summing to `RollTotal`, Secret in slot six) are checked in Studio rather than Lune: `PetConfig` reaches for `script`, which Lune cannot provide.
- Egg summon window redesigned to two rows (Common/Uncommon/Rare on top; Epic/Legendary/Secret below) with the Secret card larger at 238x196 vs 150x172 and its own animated VFX layer. Cards show pet, name, rarity and chance only -- no owned counts, one stroke per card, rarity as coloured text rather than a badge chip. The row split is by index, not rarity name, because `GameData.eggRoll` returns ascending rarity.
- `Components/SecretVFX`: stacked discs, a ten-ray starburst, sparkles and motes, built imperatively into one host Frame and animated purely by looping TweenService tweens (`RepeatCount = -1`, `Reverses`, staggered `DelayTime`). No RenderStepped or Heartbeat, and React never re-renders the nodes. Cancels tweens and destroys children on unmount -- verified that closing drops counts to zero and three reopens hold steady at 3/10/7/5.
- **Pet facing must be derived, never assumed.** The Junkyard pets' pivots disagree (Pup -Z, the rest -X). They all share an `AnimatedFace` part with a Decal on `NormalId.Front`, and `Front` is a part's -Z face = `CFrame.LookVector`, so that vector gives each pet's facing with nothing to configure. `ModelView` places the camera along it, swung 28 degrees and lifted. Verified by dot product: +0.88 on all six (was -0.42, i.e. looking at their backs).
- Silhouettes have to be black *and* unlit: recolour every surface, force a lit material, destroy Decals/Textures/SurfaceAppearance/emitters, and set the ViewportFrame's `Ambient` and `LightColor` to zero. Recolouring alone still lets lighting pick out edges, which reads as the real pet dimmed.
- `Buttons.Button` gained `subtextSize`/`subtextFont`; the subtext was pinned to `TextSize.Small`, which is why the summon price was unreadable. Now 26px under a 34px label.
- Pets window: egg row removed (eggs are summoned at the podium) and the grid shows owned pets only. `GameData.petRarity` was deleted -- it folded Uncommon onto Common and Secret onto Mythic from before `Theme.Rarity` had those styles, so the Pets window called Zebra "COMMON" while the egg window called it "UNCOMMON".
- Egg summon window second pass: Secret card is wider only (268x200) not taller, since a taller card read as a mistake rather than emphasis; all cards 200 tall with previews up from 130x94 to 156x126 (252x126 for the Secret); modal widened with a 10px inset; hint text and button icon removed; the footer is now a centred row so a second button drops in beside SUMMON without moving anything.
- `ModelView`'s fallback glyph was being drawn *unconditionally* behind the viewport, and a ViewportFrame has a transparent background -- so every pet had a giant paw showing through. It is now gated on whether a model actually rendered.
- `Cards.PetCard` renders the real model instead of a glyph (the Pets window used to draw the same paw for every entry), preview up to 144x118, rarity demoted from a 30px badge chip to small coloured text, card height cut to 196 to match the equipped rail. Legendary and Secret carry the VFX layer, via a new `Gold` palette on `SecretVFX` -- verified live as Gold on Chrome Wolf and Secret on the Secret card, both animating.
- **Rojo cannot sync while Studio is playtesting**: Studio blocks script modification during a session, so files saved mid-playtest never reach the DataModel. A measurement taken then reports the old build. Stop Play, let the sync land, and confirm with `script_grep` on the Edit DataModel before trusting the numbers.
- Pet fixes: `BaseEquipSlots` is 2 (was 1). The "EQUIPPED 2 / 1" header came from `Store` deriving `petSlots` as `math.max(1, #equippedPets)`; it now reads the server's `MaximumEquippedPets` straight off the snapshot via a new atom, so client and server cannot disagree. The extra rail slot says "UPGRADE FOR MORE <price>" rather than just a price.
- The duplicated warning was `PetService` firing both `PetResult` and `Notify` with the same text. `Notify` was dropped for pet actions; `Bridge` turns the single `PetResult` into one toast titled "Pets", skipped only for a successful hatch because the reveal already says it. Verified: one toast on success, one on failure.
- Clicking a pet now shows its model -- `DetailsModal` only ever drew a glyph or flat image, and pets have neither. Artwork well raised to 228 with the window height derived from it.
- Follower size is config: `PetConfig.FollowerLongestAxis` (2.4 studs) plus per-pet multipliers in `PetConfig.FollowerScale`. The old code only ever shrank models already bigger than the target, so small pets were left inconsistent; it now scales both ways.
- New splash/loading screen: `Screens/SplashScreen` + `client/Controllers/SplashController`, its own ScreenGui at DisplayOrder 100. **The game icon goes in `Assets.Icons.gameLogo`**; a lettered placeholder draws until then. The bar reports real readiness (remotes, Shared.UI, PetModels, `Atoms.loaded`, character) rather than a timer, with a hard 30s exit so it can never trap a player.
- Trap: `SplashController.Start` must not yield. The first version waited up to 5s for `Shared` inside `Start`, which delayed every controller after it and pushed `AdminController` past its own `WaitForChild` (infinite-yield warning). Everything blocking moved into a `task.spawn`.
- `Assets.icon` lower-cased the key it was given, which worked only because every glyph name happened to be one lower-case word. `gameLogo` therefore looked up `gamelogo`, found nothing, and the splash silently drew its placeholder over a perfectly good asset id. It now matches exact-first and falls back to lower-case; `Assets.set` stores keys as given. Verified that `gameLogo` resolves and that lower-case glyphs still do.
- The splash logo box is wide (680x260 by default), not square, with `ScaleType.Fit` -- a wide banner fills the width, a square mark still centres, neither is cropped or squashed. Constants at the top of `Screens/SplashScreen` (`LOGO_WIDTH/HEIGHT/Y`, `TITLE_Y`, `BAR_WIDTH/HEIGHT`) are all overridable by props so the story can find a value before it is committed.
- Story **23 Splash** drives progress, status, title and every logo dimension, and its header lists exactly which file to edit for each thing.
- Light theme shipped: two palettes in `Theme.luau`, `Theme.setPalette` mutating `Theme.Color`/`Theme.Gradient` in place so all 41 consuming files pick it up untouched (only `TextSize`, `Safe` and `Devices` are captured at module scope and none differ between palettes). `App` keys its subtree on the palette name to force the re-read, since table mutation is invisible to React. Only surfaces and text change; rarity and accent colours are identical in both.
- Two prerequisites worth remembering: `P.Label` defaulted to `Color.White` with a black outline, which is illegible on a pale panel -- labels now use the semantic `Color.Text` / `Color.TextOutline`, which flip. And `Theme.Studs.Color` is captured at load, so `setPalette` has to update it (plus its transparency) by hand.
- The toggle is a persisted setting (`PlayerSettings.LightTheme`, schema v12) in a new Display section of the settings window, with a `LightTheme` control on the Full App story that drives the same atom. Verified live both ways including server persistence.
- Shop redesigned as a storefront: three tabs (GAME PASSES / RESOURCES / SKINS), each a featured banner plus a scrolling grid of promo cards. `Components/Shop` holds the reusable set (`Badge`, `Price`, `BuyButton`, `ProductCard`, `FeaturedBanner`); `Components/Shine` is a generalised TweenService effect layer (sweep/glow/sparkles/rays) modelled on `SecretVFX`, opt-in per tier so a grid only pays for what it uses.
- Products are data rows: `GameData.PASS_STYLE` / `PRODUCT_STYLE` carry accent colour, tier, badge, `featured` and short selling copy. `benefit` is kept separate from the config `Description` because one is written to be accurate and the other to sell. Adding a category = a `TABS` row plus a branch in `itemsFor`.
- Two constraints visible in game: every Robux item shows COMING SOON because all `MarketplaceId`s are still 0 (`DisplayPrice` is shown so cards are not priceless, but Roblox owns the real charge), and the SKINS tab has one product because magnets are the only cosmetics with a `ShopPrice`. `MagnetShopScreen` keeps its own cards and was untouched.
- Shop second pass: tabs removed for one scrolling page (FEATURED / GAME PASSES / SKINS / RESOURCES) with `Shop.SectionHeader` dividers, four 228x316 cards across, window width derived from `COLUMNS` and `CARD_SIZE`.
- The effects were escaping the cards because badges overhung the corner, which stopped a card clipping its own contents. Badges moved inside the border and every card/well/banner sets `clip = true` -- verified 72 effect parts, 0 unclipped, 0 offscreen.
- Price folded into the buy button (`robux`/`cash` props render the amount under BUY with the currency glyph) and the button carries a `Shine` sweep; only a buyable offer shows a price or shines. `Shop.Title` splits a lead token and enlarges it (2X / MEGA / +2) using two labels rather than RichText, since RichText cannot give the halves different stroke weights.
- Featured-slot bug worth remembering: a single loop that assigned as it went let whichever card came first win, so an explicitly flagged product lost to a merely loud one. Two passes now -- flagged first, highest tier as fallback.
- Not yet verified: the phone/tablet device matrix against the new UI. Robux prices display as 0 until `MonetizationConfig` has real Marketplace IDs. Unrelated pre-existing warning seen in Play: `[Pets] Authored PetHatchery prompt is missing`.

## Blockers and Manual Work

- No blocker for Phase 1 source work.
- Roblox Studio MCP is connected and operational in this session.
- Legacy Snowman objects were confirmed absent; `Workspace/Plots` now intentionally contains the new 12-slot Scrapyard architecture.
- Run the Phase 0 Studio smoke test from `docs/STUDIO_SETUP.md` and confirm both Scrapyard bootstrap messages.
- Run the Phase 1 Studio foundation test from `docs/STUDIO_SETUP.md`; confirm startup validation and remote creation.
- Studio API access is enabled and basic development-store load/save/rejoin validation passed; Studio remains hard-isolated to the development store.
- Final map art and Creator Store assets require manual Studio work in Phase 5+.

## Exact Next Action

The Pit now uses four Pit-only scraps authored in Workspace (`Drone`, `Submarine`, `LavaCoreScrap`, `Robot Arm`). Robot Arm is strength 50, the hardest pull in the game. They never spawn on plots. Pickups pay slag (banks across weeks). The Pit shop spends slag (client sends offer id). One wreck chips while players stand nearby and spills public chunks. `PIT DIVER` title for discovering all four. Changelog 0.5.0.

Pit shop Secret Ticket is 2,500 slag, God Potion 6,000. Pit scrap keeps authored colours (no rarity wash on those models). Drone / Submarine / Lava Core scale down to fit the hoard; Robot Arm stays the large piece. Changelog 0.5.1.

Pit shop is HUD **PIT SHOP** only — no ProximityPrompt on `PitSpawn`. The wreck stands in front of PitSpawn (not the Event Area pivot), scaled to 22 studs with a WRECK bar. Changelog 0.5.2.

Pit shop opens by walking into **Event Shop** (`CHS_Shop` under that booth, same as Magnet Shop). HUD PIT SHOP button is gone; ENTER THE PIT remains. Wreck placement is a Studio part named **`WreckAnchor`** under Event Area — no spawn-pad fallback (that was why it floated). Changelog 0.5.3.

The wreck art is the Workspace model named **`Wreck`**, cloned onto `WreckAnchor`. Colours stay authored (no orange wash). Longest axis is scaled to 72 studs. `WreckAnchor` inside `PitScrapSpawns` is not a loot pad. Changelog 0.5.4.

Wreck template search tries each name in Workspace before falling through -- Submarine in ScrapModels was winning first. Chipping no longer needs bag space. Range is 40 studs. Changelog 0.5.5.

The wreck is **only** the Workspace instance named `RobotWreck`. Pit scrap models live in `EventScrap` and are never the wreck. Changelog 0.5.7.

Finder looks up `Workspace.RobotWreck` first (confirmed in Studio as a Model). Clones onto `WreckAnchor` without moving the authored asset. Changelog 0.5.8.

`Workspace.RobotWreck.meshes[0]` shipped Unanchored. Physics dropped it through the floor before `WreckService.Open`, so the wreck spawned as Submarine (old fallback) and as nothing once that fallback was removed. Runtime now pins every BasePart and stashes a ServerStorage clone at module load (before `ArenaService.Start`). Changelog 0.5.9.

Pit wreck clone yaws `ArenaConfig.Wreck.YawDegrees` (180) when it stands on `WreckAnchor`. Change that number if the facing is still wrong.

Wreck is collidable (Hull), scaled to 48 studs, HP on HUD above storage plus a chest-height world plate. Changelog 0.5.10. Pit has ~39 loot pads so TargetScrap 90 never fills; refill is 6/tick. Next: duplicate spawn pads in Studio toward 60–90, and a Pit sell pad by Event Shop.

Wreck integrity is 3600 at 4 HP/s (about 15 minutes alone). Chip range is the player's magnet reach (capped at 16 studs inside the Event Area). World HP plate has no MaxDistance. Breaking plays a shard burst. Spawn pads were an 87×101 cluster on a 204-stud floor — spread them across the cylinder in Studio. Changelog 0.5.11.

Admin panel **THE PIT** tab: SET WRECK HP (amount box, 1–100000). Applies to the live wreck, or the next spawn if none is up. Server command, not a save field. Clamped in `AdminService`.

Wreck break: sparks and smoke while it shakes, then the original mesh is destroyed and ten scaled clones fly up and out. Players standing in the spawn volume are shoved out so they are not trapped in the hull.

Wreck shield (changelog 0.5.12): after `ShieldEveryIntegrity` (450) HP chipped, DPS pauses. One neon OVERLOAD pillar on a Pit scrap pad; magnet range drops the shield, spills extra public scrap, then the node moves. Solo can still finish. HUD bar reads SHIELDED (cyan). Tune in `ArenaConfig.Wreck`.

Egg sites are the three folders under `NewMap.FeaturedPodium.EggSummonPodium`: `FrontYardEggGroup` (JunkyardEgg), `WorkshopYardEggGroup` (WorkshopEgg), `VehicleGraveyardEggGroup` (QuantumEgg). Each has an `EggId` attribute. The hatch overlay clones those meshes into `ReplicatedStorage.EggModels`. Changelog 0.5.13.

Pack coin `rbxassetid://121498047668196` (`Coins_2`) is `Assets.Icons.coin` — HUD, daily, playtime, spin. Pack bills `rbxassetid://76672014495401` (`Money_1`) is `Assets.Icons.cash` — Pit shop Scrap Stash and Scrap Haul only. Changelog 0.5.14.

**Studio:** Save the place -- folder renames (`WorkshopGraveyardEggGroup` -> `WorkshopYardEggGroup`, inner Workshop egg/stand, Vehicle Graveyard mesh name) live in the Studio file. Then Play-verify: three hold-E prompts open three different eggs, and SUMMON shakes the authored mesh not a white ball.

**Studio (wreck):** Select `Workspace.RobotWreck` / `meshes[0]`, set **Anchored**, save the place. Runtime pin is a safety net; an unanchored mesh can still void before scripts if Studio physics runs first. Play-verify: Output `template is ...RobotWreck` and a wreck on `WreckAnchor` with a WRECK bar. Chip until the bar says SHIELDED, then magnet the glowing OVERLOAD.

No event pet yet — wait for a model weaker than Sinister Lord.

JunkyardEgg display name is Front Yard Egg; QuantumEgg is Vehicle Graveyard Egg. Egg hold-E sits on a padded invisible hitbox with 18-stud reach. Authored podium signs that still said Junkyard/Quantum are rewritten on bind. Changelog 0.4.12.

Load sanitiser `BASE_PET_SLOTS` is 3, matching `PetConfig.BaseEquipSlots`. It was still 1, so a rejoin trimmed EquippedPets to one. Changelog 0.4.11.

Equipped pet followers strip authored Highlights/lights (the red wash) and hover from the visual bottom, not the exporter pivot. Premium pets keep an outline with no fill. Changelog 0.4.10.

ScrapyardPlot FrontYard spawn markers were all in two rows at the entrance (z -150 to -188). They are now spread front / mid / back across the floor so the starter yard is not empty behind the first piles. Still 8 FrontYard points; Workshop and Graveyard markers still unlock later. Studio save required -- this is authored geometry.

One-shot affordance toasts: Workshop Yard and Advanced Magnet. Server polls every 2s, fires `Notify` once, stamps `AffordHints` on the save. Already owning the thing skips the toast. No HUD tiles yet -- that waits on the other developer. Changelog 0.4.9.

Premium models come from `NewMap.FeaturedPodium` placeholders, not `Workspace.Pets`. Singularity uses the new podium model; the old `Pets.Singularity` body is now Sinister Lord (`SINISTER LORD`). Knight stays `Scrap Chrimson Knight`. Boosts unchanged from 0.4.6. Changelog 0.4.7.

Premium pet prices stay 499 / 699 / 999. Singularity is the limited cash pet (×8 value, +300% strength). Scrap Crimson Knight is luck / respawn / storage. Sinister Lord is the permanent flagship (×5 value, +400% strength, +18% walk speed). Do not put ×20 cash on two premiums -- they add. Changelog 0.4.6.

Demonic Ghost display name is Scrap Crimson Knight (`Id` still `DemonicGhost`). Changelog 0.4.5.

Hatchable RarityLuck is under that premium's +20%: Junkyard Secret +12%, Workshop Secret +14%, Quantum Secret +16%, Legendaries +10%. Changelog 0.4.4.

Each wheel spin adds another six turns from the last landing angle. The winner flash and prize banner wait until the pointer is on the wedge. Cash reward art is the painted coin `rbxassetid://130780043686108`. Workshop/Quantum silhouettes use the same flat black stamp as Junkyard.

Daily and playtime rewards are separate windows (calendar vs clock icons on the HUD). Playtime seconds interpolate on a 1s ticker so the open window counts down. Event start audio is `EventSoundConfig` (Pit = `93775470439672`).

Scrap Normal base values were already the live table ($45 MetalCan through $1,750 ScrapCar). Rarity odds and payouts were retuned in `ScrapConfig`: Normal 93.825% ×1, Rare 5% ×2, Epic 1% ×4, Legendary 0.15% ×8, Nebula 0.025% ×25, with `VariantRollTotal` 100,000.

Rebirth cost is `$2,000,000 × 1.55 ^ R`. Permanent value is `1.25 ^ R`. Luck is raw `R × 0.05`.

Workshop and Quantum (Vehicle Graveyard) pets now use per-rarity boost tables. Premium pets no longer copy/amplify the team.

Upgrade cash cost is `BaseCost × Growth ^ currentLevel`. Level 1 prices: Strength $650, Range $500, Storage $800, Speed $1,200, Value $1,500, Collection $900, Spawn Rate $2,200, Luck $3,000. Basic Magnet starts at 5 studs; range is +1/level (level 4 = old 9, level 10 = 15). Growth 1.35. EffectCap still 42. Changelog 0.4.8. Scrap Flow display name is Spawn Rate. Combined pet cash still capped at +100%. Junkyard pets not retuned.

Movement Speed is Power +2 per level from 16 to a cap of 28 (level 1 = 18 walk speed). The old diminishing +0.07 curve was unnoticeable.

Buying Workshop / Vehicle Graveyard now sets `ActivePlotTheme` and rebuilds the plot. Hold-E convert structures and convert-back are gone. On load, theme is the highest unlocked area.

`Format.short` was eating integer trailing zeros (`%.?0+$`), so $100K showed as $1K. Trim now only applies to the decimal part.

AUTO SELL sells the current load on purchase, on join if the bag is already full, and when the magnet is blocked by a full bag (not only after a pickup that fills it).

Movement Speed is +3 per level from 16 (level 1 = 19, level 10 = 46, cap 64). The 2x Walk Speed pass multiplies after the upgrade and is applied on purchase, on every state push, and on CharacterAdded (it previously never wrote WalkSpeed).

Singularity MoneyMultiplier is 8. Hatchable pet cash is capped at +100% for the whole egg-pet team; no single hatchable fills it. Ladder (C/U/R/E/L/S): Junkyard +8/12/16/22/30/40, Workshop +10/14/18/26/34/44, Quantum +12/16/20/28/38/50. Three best Front Yard pets reach +92%; Workshop and Graveyard teams hit the cap. Premium cash adds after. Inspect shows each pet's own share plus a combine note. Knight is unchanged (`+40%` cash plus luck/respawn/storage). Changelog 0.5.16.

Pet inspect uses a two-column compact stat grid in a scrolling viewport (168px) so every bonus is visible.

WalkSpeed is re-applied whenever the Humanoid's WalkSpeed changes, because HumanoidDescription overwrites it ~1s after spawn/upgrade. Uncollected plot scrap idle-refreshes after ~80s.

Hub leaderboards (`LeaderboardService`) find `Leaderboard_TopPlaytime` / `TopRebirths` / `TopRobux` anywhere under Workspace, fill or build the SurfaceGui rows, resolve usernames from the live player then `GetNameFromUserIdAsync`, and fall back to whoever is connected when the OrderedDataStore is empty.

Egg sites are each `<Area>EggGroup` under NewMap. Equipped followers pose from `AnimatedFace` (`PetModelPose`); Pup's `FollowerScale` is 0.7.

Triple and penta hatch shake that many eggs on the takeover (same rattle as a single summon), then the existing batch reveal. `roll.Count` sizes the shake row. The rotating layer is an inner pivot -- UIListLayout was swallowing Rotation on the row children, so a batch sat still. Changelog 0.5.18.

The Pit uses authored `Workspace.Event Area`. Players land on the authored `Event Area Spawn Point.PitSpawn` — loot nodes in `PitScrapSpawns` are scrap only. The area is never destroyed; only the `PitScrap` folder comes and goes with the event.

## 2026-08-22 — Pets and Pit teleport

Root cause of both regressions: `ShopService.Start` asserted `NewMap["Magnet Shop"]` (space). The map now has `MagnetShop`. That throw aborted server bootstrap, so `PetService`, `ArenaService`, `TeleportService`, events, and return-to-play never started.

Also fixed, because they were real once bootstrap ran again:

- Workshop/Quantum Studio models were renamed (Yin Yang, Fracture, Decore, …) and no longer matched `PetConfig.ModelName`. Publish now matches name, then leftover models in egg-folder roster order. Display names follow the art. Duplicate Quantum `Decore` renamed to `Nova Lion` in Studio.
- ENTER THE PIT uses the authored `PitSpawn`. Do not rewrite spawn-model `CanCollide`: that leftover workaround was why players fell through parts they had set solid in Studio.
- Changelog 0.4.3.

**Save the Studio place** — PitSpawn move, spawn-sculpture collision, and the Nova Lion rename are place instances, not Rojo.

Verified in Play: 19 pet models published (all hatchable plus Singularity); ScrapPit override opened; character PivotTo Event Area floor at Y≈1027.

