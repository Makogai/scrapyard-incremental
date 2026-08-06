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

## Motion and Accessibility

Use short scale/tween feedback for storage, money, buttons, and unlocks. Reduced-effects mode disables nonessential particles, pulses, and screen motion. Separate toggles control particles/screen effects, sound, and music. Avoid camera shake by default for this movement-focused game.
