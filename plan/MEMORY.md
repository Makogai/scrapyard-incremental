# Project Memory

Last updated: 2026-08-06

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
- Variants: Normal 1x, Silver 2x, Gold 5x, Rainbow 15x.
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

## Blockers and Manual Work

- No blocker for Phase 1 source work.
- Roblox Studio MCP is connected and operational in this session.
- Legacy Snowman objects were confirmed absent; `Workspace/Plots` now intentionally contains the new 12-slot Scrapyard architecture.
- Run the Phase 0 Studio smoke test from `docs/STUDIO_SETUP.md` and confirm both Scrapyard bootstrap messages.
- Run the Phase 1 Studio foundation test from `docs/STUDIO_SETUP.md`; confirm startup validation and remote creation.
- Studio API access is enabled and basic development-store load/save/rejoin validation passed; Studio remains hard-isolated to the development store.
- Final map art and Creator Store assets require manual Studio work in Phase 5+.

## Exact Next Action

Continue Phase 8 with the final phone/tablet matrix, disposable-key load failure drill, fresh-profile economy timing run, and manual two-client/12-player local-server soak. Do not mark release-ready until those evidence rows are complete.
