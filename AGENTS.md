# AGENTS.md — escape-velocity-modern

How to continue developing this game with Claude Code / Cursor CLI.
Read this file and `DESIGN.md` before changing anything.

## What this repo is

A Godot 4 (GDScript) Stage B loop prototype: one system, three
planets, four ships, delivery missions, trading, save/load. No
combat targets, no AI, no hyperjump, no audio. See `README.md` for
the honest scope and `DESIGN.md` for the design it condenses.

## Token discipline

- **Small diffs, one system at a time.** Flight, economy, missions,
  and save are separate scripts for a reason. Touch one per change.
- **Read before you edit.** Re-read the `.gd` file you are changing
  and `scenes/main.tscn` before editing either. Node names and
  `$Paths` in `game.gd` must match the scene tree exactly — a rename
  in one place without the other is the most common break here.
- **Data over code.** New ships, planets, commodities, and missions
  are data files (`data/*.json`), not code changes. If a change
  needs a code edit to add content, the data format is wrong — fix
  the format instead.
- **No Godot runtime here.** You cannot run the game in this
  environment. After every change, run `python3 tests/check_data.py`
  and re-read every `.gd` file you touched end to end. State
  clearly that Godot execution is still unverified.
- **Never reimplement the backdrop.** `scripts/stacked_slice_renderer.gd`
  is copied verbatim from the sibling repo `stacked-slice-renderer`.
  If it needs a change, change it there first, then re-copy and note
  it in `REUSE.md`. Same for the ship params format: `ship_params_version`
  stays 1; a breaking change bumps the version in the sibling repo
  first (see `data/ships/SCHEMA.md`).

## Conventions

- GDScript: **tabs** for indentation, `class_name` where a script is
  referenced by type from another script (`PlayerShip`,
  `PlanetBody`, `Economy`, `SaveManager`, `StackedSliceRenderer`).
  `game.gd` has no `class_name` (it is the scene root).
- Scene: one scene (`scenes/main.tscn`), `load_steps` = ext_resources + 1.
  Keep it that way until a second scene is genuinely needed.
- All sample data is fictional and labelled as such. No client
  data, no real credentials, no real API keys, ever.
- Prices are fixed base prices in slice 1. Stock-sensitive pricing
  and events are Stage B follow-ups — design them in `DESIGN.md`
  first, then implement in `scripts/economy.gd`.
- Save format is versioned (`SaveManager.SAVE_VERSION`, currently
  1). A breaking change bumps the version and adds a migration path
  in `load_game()`; never silently drop a field.

## How to continue (Cursor / Claude Code)

```bash
# Open this folder in Cursor. The game runs in Godot 4, not in Cursor.
# 1. Open the Godot 4 editor, import this folder, open scenes/main.tscn.
# 2. Press F5. Verify the checklist in README.md ("Verification").
# 3. Ask the agent for one slice at a time, e.g.:
#    "Add a second system and hyperjump (J) following DESIGN.md §4."
#    "Add pirate AI following DESIGN.md §7 — one archetype, flee/pursue only."
#    "Replace the drawn ship in player_ship.gd with the pixel-ship-factory
#     sprite for the active ship class."
```

## Suggested next slices (in order)

1. **Verify in Godot** — the checklist in README.md. Fix what breaks.
2. **Art pass** — generate sprites with pixel-ship-factory per ship
   class and replace the drawn shapes in `player_ship.gd`. (The
   backdrop's demo ship marker is already gone — the module draws
   no ship marker since the SPACE-mode change — and the backdrop
   already runs as a starfield, not an ocean.)
3. **Hyperjump** — second system, jump points, fuel (DESIGN.md §4).
4. **Combat + one AI archetype** — pirates that demand cargo, then
   flee or fight (DESIGN.md §7).
5. **Shipyard / outfitter** — buy hulls, fit gear (DESIGN.md §8).
6. **Stock-sensitive pricing + events** (DESIGN.md §5).
