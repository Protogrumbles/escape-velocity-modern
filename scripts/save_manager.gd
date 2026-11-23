# Versioned JSON save / load (design doc §9).
# Save format v1 — one file, user://escape_velocity_save.json:
#   {
#     "save_version": 1,
#     "credits": 500,
#     "ship_class": "shuttle",
#     "current_planet": "astraea",
#     "completed_missions": ["m1-grain-run"],
#     "active_mission": "" | "m2-ore-haul",  ("" means no active mission)
#     "cargo": {"food": 2}
#   }
# Bump save_version on any breaking change and keep a migration
# path in load_game(); never silently drop a field.
class_name SaveManager
extends RefCounted

const SAVE_VERSION := 1
const SAVE_PATH := "user://escape_velocity_save.json"


static func save_game(data: Dictionary) -> Error:
	var to_save := data.duplicate(true)
	to_save["save_version"] = SAVE_VERSION
	var text := JSON.stringify(to_save, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK


static func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = parsed
	if int(data.get("save_version", 0)) != SAVE_VERSION:
		# Unknown version: refuse rather than guess.
		return {}
	return data
