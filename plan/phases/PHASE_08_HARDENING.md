# Phase 8: Hardening and Release Candidate

## Scope

Complete exploit review, load/save failure drills, concurrency audit, numeric bounds, cleanup review, server/client profiling, economy timing tests, multiplayer/mobile matrix, documentation, and production configuration.

## Acceptance

- Automated checks and build pass; exceptions are documented.
- No known critical currency, collection, sell, unlock, or prestige duplication path.
- Data failure never overwrites progress.
- Target milestone timings are measured and config adjusted.
- Manual two-player and device matrix is recorded.
- Publishing, assets, DataStore, icons, and production flags have exact Studio steps.

## Work in Progress

- Completed the first remote/concurrency audit. Upgrade, area, settings, admin, and prestige requests validate payloads, are rate-limited, and call synchronous server-owned transactions. Collection and selling originate from server-observed world state.
- Added cleanup for every per-player remote limiter on `PlayerRemoving` and bounded `RequestInitialState` to four calls per normal rate window.
- Confirmed load failure/corrupt/future-schema paths create no playable session and kick instead of saving defaults. `UpdateAsync` save ownership rejects missing or foreign session leases.
- Runtime scene analysis measured 5,385 instances, 77,021 triangles, and 179 draw calls from the active player view. Script-memory analysis was unavailable behind Studio flag `STUDIOPLAT37936`; audio/animation memory was normal avatar/CoreGui content. Eleven unparented instances traced to standard PlayerModule/character scripts, not game services.
- Added `docs/RELEASE_CHECKLIST.md` with exact production configuration, DataStore isolation, asset, multiplayer/device, failure-drill, timing-run, and go/no-go steps.
- Current automated gate: StyLua and both Selene profiles pass, 73 Lune assertions pass, and Rojo builds successfully.
