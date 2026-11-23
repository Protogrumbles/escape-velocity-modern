# Ship params — schema v1 (stable)

This is the stable, versioned format a later game repo will reuse to
describe a ship. Do not change the meaning of an existing field.
New fields are added as **optional, with a default**, and keep
`ship_params_version` at 1. A breaking change bumps the version and is
documented here first.

Machine-readable form: [`ship_params.schema.json`](ship_params.schema.json)
(JSON Schema, draft 2020-12).

## Example

```json
{
  "ship_params_version": 1,
  "hull_length": 32,
  "hull_width": 12,
  "wing_style": "delta",
  "cockpit": true,
  "engine_glow": true,
  "faction": "ember",
  "scale": 8,
  "detail": "medium"
}
```

All fields are optional. Omit one and the default below is used.
Unknown fields are **rejected** by `ship_factory.py` — a typo should
fail loudly, not silently produce a different ship.

## Fields

| Field | Type | Default | Range / values | Meaning |
|---|---|---|---|---|
| `ship_params_version` | integer | `1` | must be `1` | Schema version. |
| `hull_length` | integer | `32` | 16–48 | Hull length in low-res pixels, before scaling. Longer = sleeker. |
| `hull_width` | integer | `12` | 6–20 | Hull width in low-res pixels, before scaling. |
| `wing_style` | string | `"delta"` | `delta`, `swept`, `straight`, `none` | Wing shape. `none` renders a wingless dart. |
| `cockpit` | boolean | `true` | `true` / `false` | Draw the bright cockpit canopy near the nose. |
| `engine_glow` | boolean | `true` | `true` / `false` | Draw the fading engine exhaust at the tail. |
| `faction` | string | `"ember"` | `ember`, `azure`, `verdant`, `violet`, `solar`, `ghost`, `falcon` | Palette key. Palettes live in `factions.json`. `falcon` is the reference preset — the UI8 fly-demo jet colours (body `#545969`, accent `#f0580e`, canopy `#1e8ca0`). |
| `scale` | integer | `8` | 1–16 | Nearest-neighbour upscale. Output PNG is `(hull_length + 10) × scale` wide and `(hull_width + 14) × scale` tall. |
| `detail` | string | `"medium"` | `low`, `medium`, `high` | How many deterministic panel/window details are sprinkled on the hull. |
| `voxel_slices` | integer | `0` | 0–24 | Slices the `voxel-stack` export emits. `0` = no model. Only used by `voxel-stack`; the flat PNG ignores it. |

## Seeds

The seed is **not** part of the params file — it is passed on the
command line (`--seed`). The seed may be an integer or a string.
Same seed + same params = byte-identical PNG, on any machine running
the same version of this tool. Different seeds give different ships
(the RNG also drives panel details, the accent stripe and glow length).

## Factions (`factions.json`)

Each faction is an object of hex colours:

| Key | Used for |
|---|---|
| `hull`, `hull_dark`, `hull_light` | Hull body, edges, upper shading |
| `wing` | Wings |
| `cockpit` | Cockpit canopy |
| `engine` | Engine nozzle and glow |
| `accent` | Wing tips, panel details, hull stripe |
| `outline` | Dark keel / engine outline |

To add a faction: add a key to `factions.json`, add the name to the
`faction` enum in `ship_params.schema.json` and in `SCHEMA.md`, and
add a gallery entry. Do not remove a faction that shipped in v1.

## Voxel-stack export

The default PNG is **top-down only** — a flat sprite, with no
information about what the ship looks like from another angle.
`ship_factory.py voxel-stack` emits the same ship as a multi-slice
model instead:

```bash
python3 ship_factory.py voxel-stack --seed 42 --faction falcon --slices 12 --out falcon.json
```

The model is JSON: `slice_count` horizontal slices from tail (`y=0`)
to nose (`y=hull_length`), each with `half_width`, `wing_span`,
`offset` (0 at export — the renderer shifts it by bank), `role`
(`hull` / `canopy` / `engine`) and `colour`, plus a separate `flame`
layer (`style: "realistic"`, as in the reference). A renderer draws
the slices stacked and shifts each slice sideways by
`bank * index * slice_spacing` (`slice_spacing` is 1, as published),
which reveals side faces when the ship banks — the UI8 fly-demo
trick. Same seed + same params = byte-identical model. The field
`voxel_slices` (0–24, default 0) selects the slice count; the schema
version stays 1 because the field is new and optional.

## Version history

- **v1** (initial release): the nine fields above, factions
  `ember`, `azure`, `verdant`, `violet`, `solar`, `ghost`.
- **v1.1**: added the `falcon` reference-preset faction (UI8
  fly-demo jet colours) and the optional `voxel_slices` field with
  the `voxel-stack` export. Schema version stays 1 — both are
  additive, and every v1 params file still validates.
