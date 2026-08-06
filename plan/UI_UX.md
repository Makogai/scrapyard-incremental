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
