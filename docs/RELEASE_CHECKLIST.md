# Release Candidate Checklist

Use this checklist in order. Do not point production at the development DataStore or publish while a Studio test session is running.

## Automated Gate

1. Run `stylua src tests`.
2. Run `selene src` and `selene --config tests/selene.toml tests`.
3. Run `lune run tests/run.luau`.
4. Run the Rokit-managed Rojo binary: `%USERPROFILE%\.rokit\bin\rojo.exe build default.project.json -o scrapyard-incremental.rbxlx`.
5. Confirm no secret, private asset ID, or development-only admin identity was added unintentionally.

## Studio Production Configuration

1. Open **Game Settings > Basic Info** and confirm the title, description, genre, supported devices, and 12-player server size.
2. Open **Game Settings > Security**. Enable Studio API access only for deliberate development-store testing; it is not required by live servers. Keep third-party HTTP and asset loading disabled unless a documented feature needs them.
3. Confirm `Environment.UseDevelopmentDataStore` remains `false`. Studio still uses `ScrapyardIncremental_Development_v1` because `RunService:IsStudio()` is true; published servers use `ScrapyardIncremental_PlayerData_v1`.
4. Publish to a private release-candidate place first. Join it from the Roblox client and confirm the console reports the production store, never the development store.
5. In **Creator Dashboard > Data Stores**, verify the production store appears only after the private live-server test. Never copy development keys into it.
6. Set the experience icon, thumbnails, and required screenshots in Creator Dashboard. Verify ownership/moderation status for every uploaded image, mesh, and future sound before making the experience public.
7. Keep the four named `SoundService` hooks empty until approved audio IDs are available; do not ship placeholder or unowned audio.

## Multiplayer Matrix

Record date, tester/device, result, and evidence for every row:

| Test | Required result | Status |
| --- | --- | --- |
| Two players receive different plots | Unique `PlotId` and owner labels | Pending manual multi-client test |
| Visitor collects owner scrap | No storage, money, or discovery change | Pending manual multi-client test |
| Visitor enters owner crusher | No sale or storage change | Pending manual multi-client test |
| Owner leaves and rejoins | Plot clears, session releases, saved state rebuilds | Passed single-client; repeat with two clients |
| 12-player join/leave soak | 12 unique plots, no orphan scrap/owners, stable server frame time | Pending manual local-server test |
| Desktop keyboard/mouse | HUD, all modals, collection, prestige, admin owner UI | Passed single-client |
| Phone landscape | Safe areas, scrolling, 44px+ controls, no modal overlap | Passed Phase 6; repeat final build |
| Tablet landscape | Safe areas, scrolling, modal readability | Passed Phase 6; repeat final build |

## Failure Drills

1. With a disposable development key, disable Studio API access and join. The player must be kicked with the safe-load message and must not receive a plot or a new default session.
2. Re-enable API access and verify the prior development record is unchanged.
3. Start two Studio/server sessions against the same disposable development key. The second session must reject the active lease rather than load or overwrite it.
4. Close a test server during an autosave and rejoin after the lease path is resolved. Confirm the last successful record loads and no default data replaces it.
5. Send malformed and rapid upgrade, area, settings, prestige, and admin requests. Confirm no currency or progression mutation and no server error.

## Economy Timing Run

Use a fresh development key with no admin grants. Record elapsed time for first pickup, first sale, first upgrade, Workshop, Vehicle Graveyard, and first prestige against `plan/ECONOMY.md`. Run at least one desktop and one phone session. Change only shared configuration/formulas after reviewing both runs.

## Go/No-Go

Release only when all automated checks pass, the manual rows above have evidence, failure drills preserve existing data, production-store isolation is confirmed, assets are approved, and no critical duplication or ownership path remains open.
