# Phase 1: Shared Foundations

Status: **Automated work complete (2026-08-06); Studio validation pending.**

## Scope

Create strict shared game/state types, eight scrap definitions, four variants, six upgrade definitions, three areas, prestige config, environment caps, pure math, and centralized remote definitions. Add tests before services depend on formulas.

## Acceptance

- Every balance value has one config owner and stable ID.
- Invalid tiers/weights/variants/levels cannot produce NaN, infinity, negative values, or unbounded multipliers.
- Upgrade cost/effect, scrap value, storage eligibility, and prestige math tests pass.
- No server secret or mutable authoritative table is replicated.

## Verification

- StyLua: passed
- Selene production profile: 0 errors, 0 warnings, 0 parse errors
- Selene Lune-test profile: 0 errors, 0 warnings, 0 parse errors
- Lune: 23 foundation assertions passed
- Rojo: built `scrapyard-incremental.rbxlx`
- Studio: startup configuration validation/manual remote inspection pending
