# Phase 6: UI, Feedback, and Mobile Polish

## Scope

Finish Studio-authored HUD/menu templates, storage/money feedback, crusher motion, scrap shake/arc/particles, rare variants, sounds/hooks, discovery notices, safe-area layout, and settings for particles, screen effects, sound, and music.

## Acceptance

- Core HUD is clean; side menu collapses; menus scroll and buttons meet touch size.
- Phone/tablet/desktop layouts do not overlap controls or truncate important text.
- Effects clean up and respect settings; reduced modes preserve gameplay clarity.
- No invented asset IDs; replacement points are named/documented.

## Implemented

- Authored a four-card Settings modal for particles, screen effects, sound, and music. Toggles are server-validated, saved in player data, pushed through public state, and applied through shared client preferences.
- Added an authored icon-only chevron control that collapses the right navigation from labeled 116px buttons to 52px icon controls and restores the original layout.
- Added money/storage/notification pulse hooks, a curved spinning magnet attraction, optional collection spark bursts, rare-variant attraction highlighting, throttled heavy/full-storage notices, and a client-only crusher press on successful sales.
- Added `SoundService/ScrapyardAudio` with empty `CollectSound`, `SellSound`, `ConfirmSound`, and `MusicLoop` replacement hooks. Code plays only nonempty approved IDs and respects Sound/Music settings.
- Modal state suppresses the owner ADMIN toggle and notifications, preventing overlays on compact screens.

## Verification

- Desktop Settings menu rendered all four saved toggles and a readable full-storage notice. Navigation collapsed to 52px, hid labels/dividers, centered icons, and rotated the chevron.
- Particles OFF persisted across stop/rejoin and produced zero client `CollectionSpark` parts during a successful collection. It was restored ON after testing.
- iPhone 17 Pro landscape (750x361) passed after compacting toggle columns/descriptions: no ADMIN/notification overlap, full title, readable labels, scrolling, and large touch targets.
- iPad Pro M5 13-inch landscape (1375x1032) passed with all four rows readable and no HUD/navigation/modal collisions.
- Studio Device Simulator was reset to the default viewport.
- StyLua, Selene, 73 Lune assertions, and Rojo build pass. Audio hooks intentionally contain no invented IDs.
