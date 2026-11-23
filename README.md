# escape-velocity-modern

A modern version of Escape Velocity, recreating the look and feel of
UI8's fly demo: a pixel-art ship over ocean and islands, rendered
as **stacked slices** (offset horizontal pixel layers — **not**
Mode 7), with three cameras cycled on Space.

By Sean Steuer — Program Manager, AI Strategy & Operational
Transformation at Netflix. This is a personal game project, not a
Netflix project. Everything in it — planets, factions, prices,
missions, ships — is fictional and illustrative.

> **Status: slice 1, not yet playtested in Godot.** The code was
> written and reviewed by hand in an environment with no Godot
> runtime. Run it in the Godot 4 editor to verify before believing
> any of it. See [Verification](#verification) below.

## What it is

A minimal but real **Godot 4** project (GDScript) implementing the
Stage B loop prototype from [`DESIGN.md`](DESIGN.md):

- **Flight** — Newtonian drift: mouse steering, thrust along the
  nose, brake, afterburner, barrel roll on click, engine trails,
  screen wrap. Turn rate is the stat that matters most.
- **Three cameras** — chase / overhead / cockpit, cycled on Space,
  rendered by the stacked-slice backdrop module.
- **Four ship classes** — shuttle (starter), fighter, interceptor,
  freighter — with visuals in the pixel-ship-factory params format
  (`ship_params_version: 1`) and a stats block (thrust, turn rate,
  hull HP, cargo, weapon) in `data/ships/*.json`.
- **Mission / trade loop** — accept a delivery mission at a port,
  fly to a planet, land, get paid; buy low and sell high across a
  per-planet commodity price table (5 commodities, 3 fictional
  planets).
- **Save / load** — versioned JSON save (`user://escape_velocity_save.json`):
  credits, ship class, current planet, completed missions, cargo,
  active mission.

## What it is NOT

- **Not Mode 7.** The backdrop is flat horizontal strips whose
  offset, colour, and texture speed depend on depth. No texture
  mapping, no rotation, no real 3D projection. The technique is
  explained in the sibling repo `stacked-slice-renderer`
  (`TECHNICAL.md` there) and the module header.
- **Not a complete game.** No combat targets or AI, no hyperjump
  (one system), no shipyard/outfitting, no factions or story, no
  audio, no radar. F fires a shot that flies straight and expires;
  there is nothing to hit yet. Those arrive in Stages C–D
  (see `DESIGN.md` §11).
- **Not playtested.** Nothing here has run inside Godot yet.
- Not a promise about any real game or product, and not Netflix
  data. All worked examples are anonymised/illustrative.

## Quick start — Godot 4

```bash
# Requires Godot 4.x (developed against 4.3, GL Compatibility).
# 1. Open Godot, Import, select this folder (project.godot).
# 2. Open scenes/main.tscn and press F5 (or the Play button).
# 3. You start docked at Astraea Prime.
```

First trade run (about 2 minutes):

1. Press **M** — accept the Grain run (Astraea Prime → Kestrel Station, 250 cr).
2. Press **Enter** — launch.
3. Steer with the mouse, hold **W** to thrust. Fly to Kestrel
   Station (upper right). Brake with **S** as you approach.
4. Inside the white ring, slow below 80 and press **L** — you land
   and get paid 250 cr.
5. While docked, press **1** to buy food (cheap at Astraea, dear at
   Kestrel — the reverse run pays too). Press **Q** to sell all cargo.
6. Press **K** to save, **O** to load.

## Controls

| Input | Action |
|---|---|
| Mouse position | Desired heading |
| W / hold left mouse | Main thrust |
| S | Retro / brake burn |
| Shift (hold) | Afterburner |
| Click (left mouse) | Barrel roll (0.5 s) |
| F | Fire primary (no targets in slice 1) |
| Space | Cycle camera: chase → overhead → cockpit |
| Up / Down | Backdrop scroll speed (also thrust / brake while flying) |
| M | Accept a mission (docked, at a port) |
| L | Land / dock (inside the white ring, speed < 80) |
| Enter | Launch |
| 1–5 | Buy 1t of food / industrial goods / ore / medicine / luxuries (docked) |
| Q | Sell all cargo (docked) |
| K / O | Save / load |

Note: Space and Up/Down are handled by the backdrop renderer
itself (`scripts/stacked_slice_renderer.gd`); `scripts/game.gd`
deliberately does not bind them, so the camera cycles exactly once
per press.

## The three planets (fictional)

| Planet | Economy | Cheap | Dear |
|---|---|---|---|
| Astraea Prime | Agricultural | Food (12 cr) | Luxuries (120 cr) |
| Kestrel Station | Mining | Ore (10 cr) | Luxuries (150 cr) |
| Vireo | Industrial | Industrial goods (20 cr) | Medicine (60 cr) |

Learnable routes in slice 1: food Astraea → Kestrel (12 → 40),
ore Kestrel → Astraea (10 → 30), industrial goods Vireo → Kestrel
(20 → 55). Prices are fixed base prices in slice 1 — no stock
movement or events yet, so the route you learn stays true.

## Files

| File | What it is |
|---|---|
| `project.godot`, `icon.svg` | Godot 4 project (1152×648, GL Compatibility) |
| `scenes/main.tscn` | The only scene: backdrop, 3 planets, player, HUD |
| `scripts/game.gd` | Orchestrator: state, missions, trade, save/load, HUD |
| `scripts/player_ship.gd` | Newtonian flight, banking, trails, roll, shots |
| `scripts/planet.gd` | Landable body (draws body + landing ring) |
| `scripts/economy.gd` | Commodity prices, cargo totals |
| `scripts/save_manager.gd` | Versioned JSON save (v1) |
| `scripts/stacked_slice_renderer.gd` | Backdrop renderer — copied verbatim from the sibling repo (see `REUSE.md`) |
| `data/planets.json` | 3 fictional planets + price tables |
| `data/missions.json` | 4 fictional delivery missions |
| `data/ships/*.json` | 4 ship classes: `visual` (pixel-ship-factory params v1) + `stats` |
| `data/ships/ship_params.schema.json`, `SCHEMA.md`, `factions.json` | Ship params format — copied from the sibling repo (see `REUSE.md`) |
| `DESIGN.md` | Design summary condensed from the full GDD v0.1 |
| `AGENTS.md` | How to continue developing (Cursor / Claude Code, token discipline) |
| `REUSE.md` | What was reused from sibling repos, and where |
| `tests/check_data.py` | Data checks runnable without Godot (stdlib only) |

## Reuse

Two sibling repos by the same author were reused by copy, with
attribution — see [`REUSE.md`](REUSE.md):

- **pixel-ship-factory** — the ship params format
  (`ship_params_version: 1`); ship classes in this game use that
  exact format for their visuals.
- **stacked-slice-renderer** — the Godot 4 backdrop module
  (`StackedSliceRenderer`), copied verbatim and wired in as the
  backdrop renderer. It was not reimplemented.

## Verification

Run without Godot:

```bash
python3 tests/check_data.py
```

That parses every JSON file, validates each ship's `visual` block
against the copied `ship_params.schema.json`, checks the planets
(3, unique ids, all 5 commodity prices present and positive),
missions (destinations exist, pay positive), the save-format fields,
and that every `$Node/Path` referenced in `game.gd` exists in
`scenes/main.tscn` and every script the scene references exists.

**What was verified here:** all JSON parses; all four ship visuals
validate against the schema; planets/missions/save checks pass;
scene node paths match the scripts; the copied renderer and schema
are byte-identical to their sources (`diff` clean); the backdrop
runs in SPACE mode (starfield, not ocean) with `mode = 1` on the
Backdrop node.

**What was NOT verified:** running the game in Godot. The GDScript
was re-read by eye after writing (tabs, `class_name`/`extends`,
signal-free input handling, node paths matching the scene tree),
but no Godot runtime exists in this environment. Before shipping
anything: open `scenes/main.tscn` in Godot 4.x, press Play, and
confirm — the scene loads, the starfield backdrop scrolls, Space cycles the
camera, the ship steers/thrusts/rolls, landing and mission payout
work, and K/O save and load. The old demo-ship-marker quirk is
gone: the backdrop module no longer draws a ship marker at all.

## License

MIT — see [LICENSE](LICENSE).
