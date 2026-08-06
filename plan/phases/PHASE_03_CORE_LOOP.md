# Phase 3: Collection and Selling

Status: automated implementation and single-player Studio validation complete; two-client and Device Emulator checks pending.

## Scope

Register authored spawn markers, spawn initial scrap, perform bounded proximity/eligibility checks, reserve scrap, play smooth client attraction, mutate storage server-side, respawn scrap, implement sell-zone transactions, and bind the basic HUD.

## Acceptance

- First scrap/sale timing is near target with placeholder map.
- Weak magnets/full storage/locked areas reject collection.
- One scrap cannot reward two players or the same player twice.
- Sell duplicates cannot duplicate money; storage clears atomically.
- No full-Workspace per-frame scan or loop per scrap.
- Two-player and mobile movement-only tests are documented.

## Implementation Record

- Studio owns 12 vivid 130x170 plots, each with a toy crusher, owner-only sell zone, bounds, 14 tagged markers, expansion anchors, and shared editable scrap templates.
- ScrapService clones authored templates per assigned plot, stamps owner/plot identity, uses one bounded radius-query loop, enforces configured candidate/per-plot caps, reserves each object to its owner, and respawns from its marker.
- PlayerStateService performs authoritative strength/area/capacity checks both before reservation and atomically at completion; clients receive only an approved attraction effect.
- SellService observes authored zone touches, validates assigned-plot ownership, and debounces atomic storage-to-money transactions. Visitors and empty/repeated touches cannot duplicate money.
- UIController binds live state changes and sale notifications to the authored HUD; ScrapController performs local approved attraction without submitting rewards.
- Studio verified automatic collection, starter-strength rejection, capacity rejection with zero lingering reservations, sale clearing, duplicate-sale rejection, respawn, and nonzero save/rejoin persistence.
