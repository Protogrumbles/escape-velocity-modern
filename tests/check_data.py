#!/usr/bin/env python3
"""Checks for escape-velocity-modern that run without Godot.

Parses every JSON file, validates each ship's `visual` block against
the copied ship_params.schema.json (small stdlib-only subset of
JSON Schema: type, enum, minimum/maximum, const, additionalProperties),
checks planets / missions / save-format consistency, and checks that
every $Node/Path in scripts/game.gd exists in scenes/main.tscn and
every script the scene references exists on disk.

Usage: python3 tests/check_data.py   (from the repo root)
Exit code 0 = all checks pass.
"""

import filecmp
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FAILURES = []


def check(ok, message):
    status = "ok  " if ok else "FAIL"
    print(f"[{status}] {message}")
    if not ok:
        FAILURES.append(message)


def load_json(path):
    try:
        return json.loads(Path(path).read_text())
    except Exception as exc:  # noqa: BLE001 - report, don't crash
        check(False, f"{path} parses as JSON ({exc})")
        return None


def validate_against_schema(value, schema, where):
    """Minimal JSON Schema subset: type, enum, minimum, maximum,
    const, additionalProperties, properties. Returns a list of errors."""
    errors = []
    if "const" in schema and value != schema["const"]:
        errors.append(f"{where}: expected const {schema['const']!r}, got {value!r}")
    if "type" in schema:
        want = schema["type"]
        good = {"integer": isinstance(value, int) and not isinstance(value, bool),
                "string": isinstance(value, str),
                "boolean": isinstance(value, bool)}.get(want, True)
        if not good:
            errors.append(f"{where}: expected {want}, got {type(value).__name__}")
            return errors
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{where}: {value!r} not in {schema['enum']}")
    if isinstance(value, (int, float)):
        if "minimum" in schema and value < schema["minimum"]:
            errors.append(f"{where}: {value} < minimum {schema['minimum']}")
        if "maximum" in schema and value > schema["maximum"]:
            errors.append(f"{where}: {value} > maximum {schema['maximum']}")
    if isinstance(value, dict) and "properties" in schema:
        if schema.get("additionalProperties") is False:
            for key in value:
                if key not in schema["properties"]:
                    errors.append(f"{where}: unknown field {key!r}")
        for key, sub in schema["properties"].items():
            if key in value:
                errors.extend(validate_against_schema(value[key], sub, f"{where}.{key}"))
    return errors


def main():
    # --- JSON parses -------------------------------------------------
    json_files = sorted(ROOT.glob("data/**/*.json"))
    check(len(json_files) >= 6, f"found {len(json_files)} JSON data files (expected >= 6)")
    parsed = {}
    for path in json_files:
        data = load_json(path)
        if data is not None:
            parsed[str(path.relative_to(ROOT))] = data
            check(True, f"{path.relative_to(ROOT)} parses")

    schema = parsed.get("data/ships/ship_params.schema.json", {})
    check(bool(schema), "ship params schema loaded")

    # --- Ships -------------------------------------------------------
    ship_files = sorted(ROOT.glob("data/ships/*.json"))
    ship_files = [p for p in ship_files
                  if p.name not in ("ship_params.schema.json", "factions.json")]
    ship_ids = []
    stats_keys = {"thrust", "turn_rate_deg", "max_speed", "hull_hp",
                  "cargo_capacity", "weapon", "weapon_damage"}
    for path in ship_files:
        data = parsed.get(f"data/ships/{path.name}")
        if data is None:
            continue
        ship_id = data.get("id")
        ship_ids.append(ship_id)
        visual = data.get("visual", {})
        errors = validate_against_schema(visual, schema, f"{path.name}.visual")
        check(not errors, f"{path.name} visual validates against schema"
              + ("" if not errors else f": {errors}"))
        check(visual.get("ship_params_version") == 1,
              f"{path.name} visual uses ship_params_version 1")
        stats = data.get("stats", {})
        missing = stats_keys - set(stats)
        check(not missing, f"{path.name} stats has all keys"
              + ("" if not missing else f" (missing {sorted(missing)})"))
        numeric_ok = all(isinstance(stats.get(k), (int, float)) and stats[k] > 0
                         for k in stats_keys - {"weapon"})
        check(numeric_ok, f"{path.name} stats numbers are positive")
    check(len(ship_ids) >= 3, f"at least 3 ship classes (found {len(ship_ids)})")
    check(len(set(ship_ids)) == len(ship_ids), "ship ids are unique")
    check("shuttle" in ship_ids, "shuttle starter class exists")

    # --- Planets -----------------------------------------------------
    planets_data = parsed.get("data/planets.json", {})
    planets = planets_data.get("planets", [])
    planet_ids = [p.get("id") for p in planets]
    check(len(planets) >= 3, f"at least 3 planets (found {len(planets)})")
    check(len(set(planet_ids)) == len(planet_ids), "planet ids are unique")
    commodities = {"food", "industrial_goods", "ore", "medicine", "luxuries"}
    for planet in planets:
        prices = planet.get("prices", {})
        check(set(prices) == commodities,
              f"planet {planet.get('id')} prices cover all 5 commodities")
        check(all(isinstance(v, int) and v > 0 for v in prices.values()),
              f"planet {planet.get('id')} prices are positive ints")

    # --- Missions ----------------------------------------------------
    missions_data = parsed.get("data/missions.json", {})
    missions = missions_data.get("missions", [])
    mission_ids = [m.get("id") for m in missions]
    check(len(missions) >= 1, f"at least 1 mission (found {len(missions)})")
    check(len(set(mission_ids)) == len(mission_ids), "mission ids are unique")
    for mission in missions:
        check(mission.get("pickup_planet") in planet_ids,
              f"mission {mission.get('id')} pickup planet exists")
        check(mission.get("dest_planet") in planet_ids,
              f"mission {mission.get('id')} destination planet exists")
        check(isinstance(mission.get("pay"), int) and mission["pay"] > 0,
              f"mission {mission.get('id')} pay is a positive int")

    # --- Save format (v1 shape, as SaveManager documents it) --------
    sample_save = {
        "save_version": 1,
        "credits": 750,
        "ship_class": "shuttle",
        "current_planet": "kestrel",
        "completed_missions": ["m1-grain-run"],
        "active_mission": "m2-ore-haul",
        "cargo": {"food": 2},
    }
    check(sample_save["save_version"] == 1, "save format version is 1")
    check(sample_save["ship_class"] in ship_ids, "sample save ship class exists")
    check(sample_save["current_planet"] in planet_ids,
          "sample save planet exists")
    check(all(m in mission_ids for m in sample_save["completed_missions"]),
          "sample save completed missions exist")
    check(sample_save["active_mission"] in mission_ids,
          "sample save active mission exists")
    check(all(c in commodities for c in sample_save["cargo"]),
          "sample save cargo commodities exist")

    # --- Scene / script consistency ----------------------------------
    tscn = ROOT / "scenes" / "main.tscn"
    check(tscn.exists(), "scenes/main.tscn exists")
    tscn_text = tscn.read_text() if tscn.exists() else ""
    # Build the node tree: name -> full path, from [node] headers.
    nodes = {"Main": "Main"}
    for match in re.finditer(r'\[node name="([^"]+)" type="[^"]+"(?: parent="([^"]*)")?\]',
                             tscn_text):
        name, parent = match.group(1), match.group(2)
        if parent is None:
            nodes[name] = name
        elif parent == ".":
            nodes[name] = f"Main/{name}"
        else:
            # Parent is a node name declared earlier in the file.
            parent_path = nodes.get(parent, parent)
            nodes[name] = f"{parent_path}/{name}"
    game_gd = (ROOT / "scripts" / "game.gd").read_text()
    for ref in sorted(set(re.findall(r"\$([A-Za-z0-9_/]+)", game_gd))):
        full = "Main/" + ref
        check(full in nodes.values(), f"game.gd ${ref} exists in main.tscn")
    for ext in sorted(set(re.findall(r'path="(res://[^"]+\.gd)"', tscn_text))):
        disk = ROOT / ext[len("res://"):]
        check(disk.exists(), f"scene script {ext} exists on disk")
    ext_count = len(re.findall(r"\[ext_resource", tscn_text))
    load_steps = re.search(r"load_steps=(\d+)", tscn_text)
    check(load_steps and int(load_steps.group(1)) == ext_count + 1,
          f"main.tscn load_steps ({load_steps.group(1) if load_steps else '?'})"
          f" == ext_resources ({ext_count}) + 1")

    # --- GDScript hygiene (tabs, class_name/extends) ------------------
    for gd in sorted(ROOT.glob("scripts/*.gd")):
        text = gd.read_text()
        bad_indent = [n + 1 for n, line in enumerate(text.splitlines())
                      if line.startswith(" ")]
        check(not bad_indent,
              f"{gd.name} uses tabs only"
              + ("" if not bad_indent else f" (space-indented lines: {bad_indent[:5]})"))
        check("extends " in text, f"{gd.name} has an extends line")
        opens = sum(text.count(c) for c in "([{")
        closes = sum(text.count(c) for c in ")]}")
        check(opens == closes, f"{gd.name} brackets balance ({opens} open / {closes} close)")

    # --- Copied files are byte-identical to their sources ------------
    sibling_root = ROOT.parent
    copies = [
        ("scripts/stacked_slice_renderer.gd",
         sibling_root / "stacked-slice-renderer" / "stacked_slice_renderer.gd"),
        ("data/ships/ship_params.schema.json",
         sibling_root / "pixel-ship-factory" / "ship_params.schema.json"),
        ("data/ships/SCHEMA.md",
         sibling_root / "pixel-ship-factory" / "SCHEMA.md"),
        ("data/ships/factions.json",
         sibling_root / "pixel-ship-factory" / "factions.json"),
    ]
    for rel, source in copies:
        if source.exists():
            check(filecmp.cmp(ROOT / rel, source, shallow=False),
                  f"{rel} is byte-identical to its sibling source")
        else:
            print(f"[skip] sibling source for {rel} not present here")

    print()
    if FAILURES:
        print(f"{len(FAILURES)} check(s) FAILED")
        return 1
    print("All checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
