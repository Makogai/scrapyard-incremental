# Phase 4: Upgrades

## Scope

Implement server-calculated purchases and authored UI for Magnet Strength, Magnet Range, Storage Capacity, Movement Speed, Scrap Value, and Collection Speed. Apply effects to collection/sell/character systems through one derived-stat path.

## Acceptance

- UI shows current level, next effect, price, max state, and affordability.
- Client submits upgrade ID only; server derives price/effect and saves purchase.
- Currency never becomes negative; simultaneous requests cannot double-spend.
- All six upgrades produce bounded observable effects on desktop/mobile.

## Implemented

- `UpgradeService` accepts only an upgrade ID, applies the shared remote rate limit, and delegates to a synchronous server-owned transaction.
- `PlayerStateService.TryPurchaseUpgrade` derives price and effect from shared configuration, rejects invalid/max/unaffordable purchases, deducts once without yielding, updates levels, applies WalkSpeed immediately, and pushes a fresh public snapshot.
- The authored Epic-style upgrade menu contains six scrolling cards with current level, next effect, price, max state, and visible affordability treatment. Runtime code binds stable instances; it does not generate the menu.
- Every authored plot contains a compact six-meter `UpgradeDisplay`. `PlotBuildService` rebuilds its fill heights and labels from saved upgrade levels without clearing runtime scrap.

## Verification

- Live Studio purchase: Magnet Strength level 0 -> 1, cash reduced by the server price `$45`, and next price changed to `$68`.
- Burst test: 20 Storage Capacity requests stopped at level 6 when funds were insufficient; cash remained `$176` and never became negative. A table payload and unknown ID caused no mutation.
- Movement Speed level 0 -> 1 changed the live Humanoid WalkSpeed from 16 to 16.8.
- Stop/rejoin restored Strength 1, Storage 6, Movement 1, `$51`, WalkSpeed 16.8, derived storage 68, and the corresponding authored plot-meter fills.
- StyLua, Selene, 64 Lune assertions, and Rojo build pass. Desktop Studio is complete; touch/device-emulator and multi-client checks remain release QA.
