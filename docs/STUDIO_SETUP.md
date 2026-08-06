# Scrapyard Incremental Studio Setup

## Connect Rojo

1. Run `.\rokit.exe install` once, restarting the terminal if tool shims are not yet on `PATH`.
2. Run `rojo serve` from the repository.
3. Open the Roblox Studio place and connect the Rojo plugin to `localhost:34872`.
4. Inspect the sync diff before accepting it. Rojo owns code/configuration but preserves unknown instances in Workspace and StarterGui.

## Phase 0 Smoke Test

1. Stop any running Play session so removed legacy scripts are no longer active.
2. Reconnect/sync Rojo, then start Play.
3. Confirm Output contains `Scrapyard Incremental` server and client bootstrap messages with no errors.
4. No Scrapyard gameplay or UI should appear yet; that is correct for the neutral reset.

## Phase 1 Foundation Test

1. Sync Rojo and start a fresh Play session.
2. Confirm both Scrapyard bootstrap messages appear and no configuration assertion fires before the server message.
3. Expand `ReplicatedStorage/Shared/Config` and confirm ScrapConfig, UpgradeConfig, AreaConfig, PrestigeConfig, and Environment are present.
4. Expand `ReplicatedStorage/Remotes` and confirm the state, notification, effect, upgrade, area, prestige, and settings remotes exist with the expected classes.
5. No money, storage, scrap, UI, or DataStore behavior should exist yet.

## Manual Legacy Cleanup

Rojo intentionally does not delete Studio-authored Workspace or StarterGui content. In edit mode, delete these old prototype objects if present:

- `Workspace/Plots`
- `Workspace/HeatwaveArena`
- `StarterGui/MainUI` when it contains Snowflakes, Frost Gems, Snowman collection, merge, raid, rebirth, or Heatwave controls

Keep personal terrain, lighting work, unrelated models, and any assets you intentionally added. Save or publish the place after cleanup. Future Scrapyard map and UI objects remain directly editable in Studio.

## Build and Checks

- Format: `stylua src tests`
- Lint: `selene src`
- Build: `rojo build default.project.json -o scrapyard-incremental.rbxlx`
- Pure tests: `lune run tests/run.luau`

DataStore API access is not needed until Phase 2. When it is introduced, use a published test experience and the separated development store; never test against production data by default.

## Phase 2 Player Data Test

Phase 2 always selects `ScrapyardIncremental_Development_v1` while running in Studio, even if the production configuration flag is false.

1. Publish the test place, then enable **Game Settings > Security > Enable Studio Access to API Services**.
2. Start Play and confirm Output reports `[DataService] Using development store` followed by both Scrapyard bootstrap messages without errors.
3. Confirm `StarterGui/ScrapyardUI` is cloned into `PlayerGui`, its loading panel disappears after the session loads, and money/storage show `$0` and `0 / 20` for a new player.
4. Change test data through a temporary server command or a later gameplay phase, stop Play, rejoin, and confirm money, storage, upgrades, areas, discoveries, settings, and timestamps round-trip.
5. Disable API access (or use an unpublished copy), start Play, and confirm four bounded load attempts occur, the player receives the safe-load kick, and no default session is saved.
6. Start two Studio servers for the same account/session where practical and confirm the second live claim is rejected until the first session releases or its lease expires.

Do not enable production-store testing from Studio. Successful DataStore round-trip validation remains manual because it requires a published experience and account-level API access.

## Studio-authored UI Foundation

`StarterGui/ScrapyardUI` is an authored instance tree seeded from **Epic UI Pack by MapelMarvel**. Panels, currency art, the storage progress bar, and navigation buttons come from that pack. Rojo preserves this tree and only synchronizes controller code. Keep these stable binding names when editing visuals:

- `SafeArea/LoadingPanel`
- `SafeArea/TopBar/MoneyPanel` and `GearsPanel`
- `SafeArea/StoragePanel/StorageBar/Foreground/Fill`
- `SafeArea/Navigation/*Button`
- `SafeArea/Menus/*Menu/CloseButton`

The controller must bind these instances; it must not recreate the production UI tree at runtime.

## Phase 3 Core Loop Test

1. Start Play at `Workspace/SpawnLocation`. Confirm the authored Front Yard creates up to 18 active scrap objects and the first eligible can, bolt, or plate attracts within five seconds without clicking.
2. Confirm starter Magnet Strength 4 ignores tires (required strength 6), while nearby eligible scrap arcs toward the character and updates the authored storage meter.
3. Fill storage to 20 weight, remain near additional scrap, and confirm no further attraction/reservations begin. Walk onto the assigned plot's `CrusherSellZone` and confirm storage clears and money increases once.
4. Remain on/re-enter the sell pad with empty storage and confirm money does not increase again. Stop and rejoin; confirm nonzero money and any remaining stored weight/value persist.
5. In **Test > Clients and Servers**, start one server with two clients. Move both clients toward the same object and confirm exactly one receives it; confirm each HUD/storage state is independent. Repeat while one player is full.
6. In Device Emulator, test phone portrait, phone landscape, and tablet. Confirm movement alone collects scrap, the joystick does not overlap the storage/navigation controls, labels remain readable, and the menus still scroll.
7. In Developer Console/Script Performance, confirm collection uses the single bounded ScrapService query loop. Active scrap must not exceed the configured cap, and there must be no per-scrap heartbeat or full-Workspace scan.

Phase 3 geometry now lives inside the 12 Studio-authored `Workspace/Plots` slots; shared scrap templates remain under `ServerStorage/ScrapModels`. Keep stable plot attributes and child names when editing appearance.

## Plot Architecture Validation

1. Confirm `Workspace/Plots` contains exactly `Plot01` through `Plot12`; each is 130x170 and exposes the hierarchy documented in `plan/PLOT_REFACTOR.md`.
2. Confirm the published experience's server-size setting is 12. `Environment.MaximumPlayers` and `PlotConfig.PlotCount` both fail startup validation unless they match at 12, but the Roblox experience setting must also be configured in Game Settings.
3. Start Play. Confirm the first available plot receives `OwnerUserId`, the player teleports to its entrance, the owner billboard shows the real avatar/display name/saved stage/prestige/total scrap, and exactly 14 starter scrap spawn under that plot's `RuntimeObjects/ActiveScrap`.
4. Confirm every active scrap has matching `PlotId` and `OwnerUserId`. Walk through another slot: it must have no active scrap while unassigned, and its crusher must not sell the visitor's nonzero storage.
5. Stop/rejoin and confirm physical plot assignment is not saved, while money, storage, discoveries, plot stage, crusher level, plot upgrades, theme/customization, trophies, prestige count, and unlocks migrate/load safely.
6. In **Test > Clients and Servers**, run at least two clients. Confirm they receive different slots, cannot attract each other's scrap, cannot sell at each other's crusher, can walk through each other's plots, and releasing one client clears its runtime folder/sign before the slot can be reassigned.
7. Run a 12-client soak when practical. Confirm no more than 28 active scrap per plot, one shared bounded query loop, anchored decorations, stable server frame time, and cleanup of all released-plot instances/connections.

The former shared-yard `Map` and `Gameplay` objects are archived under `ServerStorage/RefactorArchive` for recovery and must remain outside Workspace.
