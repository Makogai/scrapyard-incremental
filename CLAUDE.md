# Scrapyard Incremental Engineering Guide

This repository is being reset from Merge a Snowman into **Scrapyard Incremental**, a server-authoritative Roblox incremental game written in strict native Luau and synchronized with Studio through Rojo.

## Required Reading

Before planning or implementation work, read:

1. `plan/MEMORY.md` for current status and decisions.
2. `plan/ROADMAP.md` for phase order and gates.
3. The active file under `plan/phases/`.
4. Relevant architecture/economy/world/UI plans.

Update `plan/MEMORY.md` at the end of every meaningful task. It is the durable handoff, not a diary: record completed work, decisions, verification, manual Studio state, blockers, and the exact next action.

## Architecture

- Use `--!strict` in every Luau source file.
- Use focused server services, client controllers, shared types/configuration, and centralized remotes.
- The server owns collection eligibility, scrap state, storage, money, upgrades, areas, prestige, and persistence.
- Clients render attraction/effects and submit intent only where needed; they never submit rewards, prices, strength, capacity, or unlock results.
- Do not scan all of Workspace every frame. Use area registries, spatial queries with bounded cadence, and per-player candidate limits.
- Keep balancing values configuration-driven and pure formulas testable outside engine behavior.

## Studio Ownership

Workspace terrain, map geometry, scrap spawn markers, machines, gates, and StarterGui templates are Studio-authored. Rojo owns code and configuration and must preserve unknown Studio instances in authored containers. Runtime fallbacks are development conveniences, never the primary production map.

## Quality Gate

After each implementation phase: run StyLua, Selene, available tests, and `rojo build`; review remote/security and mobile performance; update plan status; list changed files; provide exact Studio tests; distinguish automated from manual verification. Do not claim Studio tests passed unless actually run.

## Scope

Build one playable phase at a time. Do not carry Snowman-specific mechanics into the new game unless `plan/LEGACY_AUDIT.md` explicitly approves reuse. Do not begin terrain production until its planned phase. Avoid unrelated refactors and giant scripts.
