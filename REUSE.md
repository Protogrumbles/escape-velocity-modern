# Reuse — what was copied from sibling repos

Both sources are sibling repos by the same author (Sean Steuer),
built in the same series. Files were copied verbatim where noted;
nothing was reimplemented differently.

## stacked-slice-renderer

Source: `../stacked-slice-renderer/`

- `scripts/stacked_slice_renderer.gd` — copied **verbatim**
  (verified with `diff`: identical). The Godot 4 module
  (`class_name StackedSliceRenderer extends Node2D`) is wired in as
  the backdrop renderer on the `Backdrop` node in
  `scenes/main.tscn`, with `mode = 1` (SPACE): a starfield of three
  layers at 0.2x / 0.5x / 1.0x parallax plus nebula wisps — the
  DESIGN.md §2 mapping, implemented in the sibling repo first and
  re-copied here. Its public interface is used as documented:
  exported `slice_height`, `horizon_y`, `speed`, `camera_mode`
  (CHASE / OVERHEAD / COCKPIT), colours, `viewport_size`, `islands`;
  functions `slice_depth()`, `slice_offset()`,
  `slice_texture_offset()`, `ocean_color()`, `project_island()`,
  `cycle_camera()`, `set_speed()`. The game reads
  `backdrop.camera_mode` for the HUD and lets the module own Space
  (camera cycle) and Up/Down (scroll speed) in its own
  `_unhandled_input`.
- The old demo-ship-marker quirk is **fixed**: the module no longer
  draws a ship marker at all (removed in the sibling repo, then
  re-copied). The player ship is drawn only by
  `scripts/player_ship.gd`.

## pixel-ship-factory

Source: `../pixel-ship-factory/`

- `data/ships/ship_params.schema.json` — copied **verbatim**
  (verified with `diff`: identical). JSON Schema draft 2020-12 for
  the ship params format, version 1.
- `data/ships/SCHEMA.md` — copied **verbatim**. Human-readable
  documentation of the same format.
- `data/ships/factions.json` — copied **verbatim**. The seven faction
  palettes (`ember`, `azure`, `verdant`, `violet`, `solar`,
  `ghost`, `falcon` — `falcon` is the UI8 fly-demo jet reference
  preset) the ship visuals reference.
- `data/ships/*.json` (`shuttle`, `fighter`, `interceptor`,
  `freighter`) — new files written for this game. Each file's
  `visual` block uses the exact params format above
  (`ship_params_version: 1`; fields `hull_length`, `hull_width`,
  `wing_style`, `cockpit`, `engine_glow`, `faction`, `scale`,
  `detail`). The interceptor / fighter / freighter visuals match
  the sibling repo's `examples/` params; the shuttle is new.
  Each file adds a `stats` block (thrust, turn rate, hull HP,
  cargo, weapon) that is this game's own data, not part of the
  sibling schema — the schema validates the `visual` block only.
