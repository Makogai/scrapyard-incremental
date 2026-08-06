# Phase 2: Player Data

Status: complete; nonzero gameplay mutation recheck follows in Phase 3.

## Scope

Implement versioned defaults, migration, validation, retrying load/save, in-memory sessions, autosave jitter, removal/shutdown saves, development DataStore isolation, sanitized initial snapshots, and loading-failure handling.

## Acceptance

- New/returning players receive valid data; missing fields repair through tested migrations.
- Failed loads cannot overwrite existing data and do not enter gameplay.
- Only DataService accesses DataStoreService.
- Money/storage/upgrades/areas/discoveries/settings/timestamps round-trip.
- Studio DataStore setup and failure tests are documented.

## Implementation Record

- Current schema version is 2 with deterministic defaults, v1 migration, field repair/clamping, future-schema rejection, and corrupt-root rejection.
- DataService exclusively owns DataStoreService access, exponential retries, development-store selection in Studio, expiring job claims, guarded saves, and explicit release.
- PlayerStateService owns loaded sessions, sanitized public snapshots, autosave jitter, removal saves, shutdown saves, and safe load rejection.
- The unpublished-place failure path was exercised in Studio: all retries failed, no session entered gameplay, and the player was safely kicked.
- After publication/API access, Studio selected the development store, loaded a new session, released it on stop, and reclaimed it successfully on rejoin.
- Pure migration/default/repair coverage is included in the 46-assertion Lune suite.
