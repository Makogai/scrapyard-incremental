# Legacy Audit

## Reuse

- `rokit.toml`, `stylua.toml`, `selene.toml`, `.gitignore`, and Rojo mapping patterns.
- Generic `RateLimiter`, `Janitor`, and logging utilities after naming/type review.
- Server-owned remote creation pattern after replacing definitions.
- Partial Rojo ownership for Workspace and StarterGui.

## Replace

- Snowman player schema and all snowman/economy/upgrade/tier configuration.
- Plot allocation, merge-oriented UI, snow currencies, Heatwave presentation, Snowman entry-point messages.
- `docs/` design, economy, schema, monetization, security, Studio setup, and task content.
- Project/readme naming and generated place name.

## Phase 0 Safety

Do not delete Studio-authored content through Rojo sync without first warning the developer. Source removal should be scoped to known legacy files. Preserve generic utilities only after tests/lint. Record any existing user edits discovered during reset rather than reverting them.
