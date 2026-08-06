# Phase 0: Product Reset

Status: **Automated work complete (2026-08-06); Studio smoke test pending.**

## Scope

Rename the project to Scrapyard Incremental, safely remove Snowman-only code/docs, retain approved tooling/utilities, establish neutral strict bootstraps, replace shared remote/config foundations, and update README/Studio setup.

## Acceptance

- No runtime reference to snowmen, merging, plots, raids, or Heatwave.
- Rojo maps shared/server/client correctly and preserves Studio-owned Workspace/StarterGui.
- Server/client boot with Scrapyard identity and no gameplay assumptions.
- StyLua, Selene, and Rojo build pass.
- Legacy Studio objects that need manual deletion are listed, not silently removed.
- `MEMORY.md` records changed files, verification, and Phase 1 next action.

## Verification

- StyLua: passed
- Selene: 0 errors, 0 warnings, 0 parse errors
- Rojo: built `scrapyard-incremental.rbxlx`
- Studio: manual bootstrap/legacy cleanup pending; see `docs/STUDIO_SETUP.md`
