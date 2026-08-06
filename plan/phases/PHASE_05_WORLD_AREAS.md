# Phase 5: Authored World and Areas

## Scope

Build/edit the three Studio-owned sections, terrain, area bounds, spawn markers, generic scrap props, crushers, and gates. Implement per-player unlock purchases and gate presentation without making decorative geometry authoritative.

## Acceptance

- Front Yard, Workshop Yard, and Vehicle Graveyard have distinct readable routes and scrap pools.
- Gates show area, price, featured scrap, affordability, and ownership.
- Server validates and saves unlocks; locked-area scrap cannot be collected.
- Terrain/map remain editable outside Play mode and survive Rojo sync.
- Mobile performance stays within active-scrap/part budgets.

## Implemented

- Every Studio-authored plot contains a forward Front Yard, left Workshop Yard, and right Vehicle Graveyard with distinct floors, routes, props, colors, and readable gate cards.
- Workshop includes a canopy, tool crates, and industrial floor; Vehicle Graveyard includes slate ground and generic colorful wreck props. The upgrade rack was moved out of the reserved Workshop footprint.
- Each plot has 22 authored spawn markers: 8 Front Yard, 7 Workshop, and 7 Vehicle. Twelve occupied plots produce at most 264 active scrap, below the configured global 300 and per-plot 28 limits.
- `ScrapService` carries marker `AreaId` through weighted pool selection, instances, reservations, collection checks, and respawns. Locked-area items can be visible behind gates but cannot reward players.
- `AreaService` accepts only an area ID, rate-limits requests, and calls a sequential server transaction. The server derives price, deducts once, unlocks the area/scrap pool, advances PlotStage, pushes state, and refreshes the owner gate.
- The authored Epic-style Areas modal shows three area cards with route description, featured scrap, configured price, ownership, and affordability.

## Verification

- Live pool count was 22 per owned plot: Front 8, Workshop 7, Vehicle 7.
- Forced movement beside a locked Workshop appliance left it present; normal Front Yard collection still succeeded.
- Malformed, unaffordable, and Vehicle-before-Workshop requests changed neither cash nor ownership.
- A Studio-development save seeded with exactly `$6,500` purchased Workshop through the real client remote: cash became `$0`, UI became Owned/Unlocked, PlotStage became 2, and the barrier became invisible/non-collidable.
- Stop/rejoin restored Workshop ownership and the open gate. With a Studio-development strength level of 4, a Workshop appliance collected successfully after rejoin.
- iPhone 17 Pro landscape playtest at 750x361 retained readable text, scrolling access, safe-area clipping, close control, and 92px touch targets. Studio was reset to the default viewport afterward.
- StyLua, Selene, 71 Lune assertions, and Rojo build pass. The only console warning remains the pre-existing third-party `StarterGui:SetCore` warning.
