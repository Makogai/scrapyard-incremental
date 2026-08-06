# Scrapyard Incremental

Scrapyard Incremental is a mobile-first Roblox incremental game built with native strict Luau and Rojo. Up to 12 players receive large personal scrapyard plots, automatically attract their own nearby scrap, manage storage, sell through their own crusher, evolve the plot visually, purchase upgrades, and prestige for permanent Gears. Players may visit other yards but all rewards and machines remain owner-authoritative.

## Current Status

Phases 0-7 and the plot-architecture refactor are implemented. The project includes schema-v3 persistence, guarded sessions, 12 authored plot slots, owner-only gameplay, three saved areas, six upgrades, saved presentation settings, server-owned Gear prestige, a persistent collection book, and a vivid Epic-style authored HUD. The two-client and 12-player soak gates remain for Phase 8 release hardening.

Read the authoritative plan in this order:

1. [Project memory](plan/MEMORY.md)
2. [Roadmap](plan/ROADMAP.md)
3. [Game design](plan/GAME_DESIGN.md)
4. [Architecture](plan/ARCHITECTURE.md)
5. [Phase 0 reset](plan/phases/PHASE_00_RESET.md)
6. [Plot refactor](plan/PLOT_REFACTOR.md)

## Tooling

Pinned tools are managed through Rokit. After `.\rokit.exe install`, use `rojo serve`, `stylua src tests`, `selene src`, `lune run tests/run.luau`, and `rojo build default.project.json -o scrapyard-incremental.rbxlx`. The project uses partial Rojo management: code/configuration lives in the repository, while final Workspace terrain/map and StarterGui presentation remain editable in Studio.
