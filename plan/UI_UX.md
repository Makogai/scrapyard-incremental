# UI and UX

## HUD

- Top: Money; Gears hidden/locked until relevant.
- Bottom: storage progress, stored value/capacity, prominent Upgrades control, optional sell teleport only after unlock.
- Side: collapsible Shop, Upgrades, Areas, Collection, Settings menu.
- Context: short collection/discovery/reward notifications; prestige confirmation; area gate purchase surface.

## Interaction Rules

Core play requires movement only. Buttons use at least 44px-equivalent touch targets, safe-area-aware positioning, scrollable menus, readable text, and explicit locked/ready/full states. Do not depend only on color. Desktop gets hover feedback; touch gets pressed feedback. Modal content never permanently blocks movement or progression.

## Authored Template

StarterGui is Studio-authored and preserved by Rojo. Controllers bind stable instance names and update values; they do not rebuild the final visual tree. A code fallback may exist for clean builds but must be seedable into Studio. UI changes in Studio must be saved/published and recorded in `MEMORY.md`.

## Full Cartoon Rework

The production `ScrapyardUI` uses one Epic UI Pack-derived design system:

- dark plum construction outlines, cream content surfaces, rounded toy-like geometry, glossy highlight strips, and vivid semantic accent colors;
- compact layered cash/Gears cards, a cyan bottom storage capsule, and a cream navigation rail with distinct orange/cyan/yellow/purple/pink controls;
- one modal chassis across Upgrades, Areas, Collection, Settings, Prestige, Inventory, Magnet Shop, and Exclusive Shop;
- red square close controls with a readable text glyph, dimmed world focus, and hidden Backpack hotbar while a modal is open;
- viewport-driven phone scaling that preserves the full desktop canvas instead of compressing fixed-offset modal content.

Do not add one-off flat panels. New surfaces should reuse the existing `ReworkCorner`, `ReworkStroke`, `ReworkGradient`, and `ReworkResponsiveScale` conventions and remain authored in Studio.

## Motion and Accessibility

Use short scale/tween feedback for storage, money, buttons, and unlocks. Reduced-effects mode disables nonessential particles, pulses, and screen motion. Separate toggles control particles/screen effects, sound, and music. Avoid camera shake by default for this movement-focused game.
# Premium UI Pack native interface

`StarterGui/PackGameplayUI` is the visible runtime interface. It is composed from direct clones of the purchased pack's HUD, Upgrades, Settings, Rebirth, Shop, Index, and Currencies instances. Do not rebuild it from Frames or apply custom skin layers. Permitted changes are game-specific text, icons, values, repeated row/card counts, and controller bindings.

The pack HUD retains its exact two-column six-button layout, native wide utility button, bottom-left stat stack, button sizing, borders, typography, and spacing. Pack screens retain their native outer frame, header, close control, content rows, sliders, toggles, and card artwork.

The older `ScrapyardUI` has been removed from StarterGui and archived at `ServerStorage/LegacyUIArchive/ScrapyardUI`. It must never be restored as a runtime visual source. `PackUIController` owns the pack-native HUD, navigation, live stats, upgrade rendering/purchases, menu visibility, and prestige action.

The untouched imported demos are preserved in Studio under `ServerStorage/PremiumUIReference`; they must not be moved back to Workspace because the 1,293 reference descendants would replicate unnecessarily.

Current mapping:

- HUD navigation uses the pack HUD button artwork in compact left-side form.
- Upgrade and area surfaces use the pack Upgrades/Index frames and textured row elements.
- Settings uses the stock Settings frame and purple switch artwork.
- Prestige uses the Rebirth frame/header treatment.
- Inventory and Collection use the Index frame treatment.
- Magnet and Exclusive shops use the Shop frame, header, and purchase buttons.
- Pets uses the Shop shell, Upgrades row textures, and pack purchase buttons.
- Close controls use the pack's red close-button artwork.

Stable gameplay instance names remain unchanged. `KitSkin`, `KitHeader`, `KitButtonSkin`, and `KitX` are authored presentation children and must not be used as gameplay bindings. Later personalization should replace/tint those presentation layers while preserving the parent controls.
