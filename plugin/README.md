# Resurface

A Studio plugin for painting tiled `Texture` objects onto parts, with controls.

**Not specific to this game.** Nothing in it references a place, a model or a naming scheme, so the built
`.rbxm` works in any Studio install. It lives in this repo because this is where it was written, not
because it depends on anything here.

## Build and install

```
rojo build plugin.project.json -o "%LOCALAPPDATA%\Roblox\Plugins\Resurface.rbxm"
```

Restart Studio (or right-click the Plugins folder → refresh) and a **Resurface** toolbar button appears.
Rebuild and repeat to update; there is no live-sync for plugins.

Note this is a *separate* Rojo project from `default.project.json`, and `plugin/` is deliberately absent
from that one — syncing it into the game would put a plugin script inside the place.

## Controls

| Control | What it writes |
| --- | --- |
| Texture presets / ID | `Texture.Texture` — a bare number is accepted and expanded to `rbxassetid://` |
| Face / ALL SIX | `Texture.Face`, or one Texture per face |
| Tint | `Texture.Color3`, as hex |
| Transparency | `Texture.Transparency`, 0–1 |
| Rotation | `Texture.Rotation`, degrees |
| Tile U / V | `StudsPerTileU` / `StudsPerTileV` |
| Square tiles | Locks U and V together — a checkerboard with unequal tiling is stripes |
| Offset U / V | `OffsetStudsU` / `OffsetStudsV`, to line a pattern up across adjacent parts |

## Actions

- **Paint mode** — click parts in the viewport. Activates the plugin so the mouse reports targets.
- **Apply to selection** — every `BasePart` in the selection, including inside selected models.
- **Pick from part** — select a part that already looks right and load its exact settings. This is how you
  reproduce an existing surface rather than dialling it in again, and it is why no game-specific preset is
  baked into the code.
- **Strip** — removes textures *this plugin* created and nothing else.

## Two decisions worth knowing

**Every write is undoable.** Each action is wrapped in a `ChangeHistoryService` recording, so Ctrl+Z takes
back a whole paint rather than one property at a time. A plugin that can touch thousands of parts and
cannot be undone eventually eats somebody's map. `TryBeginRecording` is used where available and falls back
to `SetWaypoint`, both under `pcall` — a plugin that errors on an unfamiliar Studio version is worse than
one that undoes coarsely.

**Repaint reuses, it does not stack.** Applying to a face that already has a Texture edits that Texture
rather than parenting a second one to the same face. Otherwise clicking the same wall twice silently piles
up invisible duplicates.

**Strip only removes its own work**, found by a `ResurfacePlugin` attribute the plugin stamps on everything
it creates. Without that marker the only way to clear a part would be deleting every Texture on it,
including hand-placed ones that were there first.

## Known warning

`selene` flags `CreateDockWidgetPluginGui` as deprecated. It is still the standard way to make a plugin
widget and has no in-use replacement, so the warning stands. `selene plugin` should report exactly one
warning and nothing else.
