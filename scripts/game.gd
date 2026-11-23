# Escape Velocity Modern — slice 1 orchestrator (Stage B loop prototype).
# Owns the game state (credits, ship, cargo, missions, docked),
# loads the data files, wires the player ship to its ship-class
# stats, and drives the HUD.
#
# The backdrop renderer (StackedSliceRenderer, scripts/
# stacked_slice_renderer.gd) owns Space (camera cycle) and Up/Down
# (backdrop scroll speed) in its own _unhandled_input, so this
# script deliberately does NOT handle Space, Up or Down. The camera
# label below just reads backdrop.camera_mode.
#
# Controls (see also README.md):
#   Mouse steer, W / left mouse thrust, S brake, Shift afterburner,
#   click barrel roll, F fire, Space cycle camera (backdrop),
#   M accept mission (docked), L land, Enter launch,
#   1-5 buy 1t of a commodity (docked), Q sell all cargo (docked),
#   K save, O load.
extends Node2D

const START_CREDITS := 500
const START_SHIP := "shuttle"
const START_PLANET := "astraea"
const LAND_SPEED_MAX := 80.0

const SHIP_FILES: Array[String] = [
	"res://data/ships/shuttle.json",
	"res://data/ships/fighter.json",
	"res://data/ships/interceptor.json",
	"res://data/ships/freighter.json",
]

@onready var backdrop: StackedSliceRenderer = $Backdrop
@onready var planets_root: Node2D = $Planets
@onready var player: PlayerShip = $Player
@onready var credits_label: Label = $HUD/CreditsLabel
@onready var ship_label: Label = $HUD/ShipLabel
@onready var planet_label: Label = $HUD/PlanetLabel
@onready var mission_label: Label = $HUD/MissionLabel
@onready var cargo_label: Label = $HUD/CargoLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var camera_label: Label = $HUD/CameraLabel

var credits: int = START_CREDITS
var ship_class: String = START_SHIP
var current_planet: String = START_PLANET
var completed_missions: Array = []
var active_mission_id: String = ""
var cargo: Dictionary = {}
var docked: bool = true

var _ships: Dictionary = {}
var _planets: Dictionary = {}
var _planets_by_id: Dictionary = {}
var _missions: Array = []
var _planet_nodes: Array = []


func _ready() -> void:
	_load_data()
	_collect_planet_nodes()
	if _ships.has(ship_class):
		var ship_data: Dictionary = _ships[ship_class]
		player.apply_stats(ship_data.get("stats", {}))
		ship_label.text = "Ship: " + String(ship_data.get("name", ship_class))
	_dock_at_current_planet()
	_say("Docked at Astraea Prime. Press M for a mission, 1-5 to buy, Enter to launch.")
	_refresh_hud()


func _load_data() -> void:
	for path in SHIP_FILES:
		var ship_data := _load_json(path)
		if ship_data.has("id"):
			_ships[String(ship_data["id"])] = ship_data
	var planets_data := _load_json("res://data/planets.json")
	for planet in planets_data.get("planets", []):
		_planets_by_id[String(planet["id"])] = planet
	var missions_data := _load_json("res://data/missions.json")
	_missions = missions_data.get("missions", [])


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: " + path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Bad JSON in: " + path)
		return {}
	return parsed


func _collect_planet_nodes() -> void:
	_planet_nodes.clear()
	for child in planets_root.get_children():
		if child is PlanetBody:
			_planet_nodes.append(child)


func _process(_delta: float) -> void:
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_M:
			_accept_mission()
		KEY_L:
			_try_land()
		KEY_ENTER, KEY_KP_ENTER:
			_launch()
		KEY_K:
			_save()
		KEY_O:
			_load()
		KEY_Q:
			_sell_all_cargo()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			_buy_commodity(key_event.keycode - KEY_1)


func _planet_node(planet_id: String) -> PlanetBody:
	for node in _planet_nodes:
		if node.planet_id == planet_id:
			return node
	return null


func _nearest_planet_in_range() -> PlanetBody:
	for node in _planet_nodes:
		var dist := player.global_position.distance_to(node.global_position)
		if dist <= node.landing_radius():
			return node
	return null


func _try_land() -> void:
	if docked:
		_say("Already docked. Press Enter to launch.")
		return
	var node := _nearest_planet_in_range()
	if node == null:
		_say("No planet in landing range. Fly inside the white ring.")
		return
	if player.speed_now() > LAND_SPEED_MAX:
		_say("Too fast to land. Brake (S) below " + str(int(LAND_SPEED_MAX)) + " and try again.")
		return
	current_planet = node.planet_id
	_dock_at_current_planet()
	_say("Docked at " + _planet_name(current_planet) + ".")
	_check_mission_delivery()


func _dock_at_current_planet() -> void:
	var node := _planet_node(current_planet)
	if node != null:
		var away := (player.global_position - node.global_position).normalized()
		if away.length() < 0.5:
			away = Vector2(0, 1)
		player.global_position = node.global_position + away * (node.radius + 30.0)
	docked = true
	player.set_frozen(true)


func _launch() -> void:
	if not docked:
		return
	docked = false
	player.set_frozen(false)
	var node := _planet_node(current_planet)
	if node != null:
		var away := (player.global_position - node.global_position).normalized()
		player.global_position = node.global_position + away * (node.radius + 60.0)
	_say("Launched. Fly to your destination — the white ring is the landing zone.")


func _planet_name(planet_id: String) -> String:
	var planet: Dictionary = _planets_by_id.get(planet_id, {})
	return String(planet.get("name", planet_id))


func _accept_mission() -> void:
	if not docked:
		_say("Missions are posted at ports. Land first (L).")
		return
	for mission in _missions:
		var mission_id := String(mission["id"])
		if String(mission["pickup_planet"]) == current_planet and not completed_missions.has(mission_id) and mission_id != active_mission_id:
			active_mission_id = mission_id
			_say("Mission accepted: " + String(mission["title"]) + " — deliver to " + _planet_name(String(mission["dest_planet"])) + " for " + str(int(mission["pay"])) + " cr.")
			return
	_say("No new missions at this port right now.")


func _check_mission_delivery() -> void:
	if active_mission_id == "":
		return
	for mission in _missions:
		if String(mission["id"]) == active_mission_id and String(mission["dest_planet"]) == current_planet:
			credits += int(mission["pay"])
			completed_missions.append(active_mission_id)
			_say("Mission complete: " + String(mission["title"]) + ". Paid " + str(int(mission["pay"])) + " cr.")
			active_mission_id = ""
			return


func _buy_commodity(index: int) -> void:
	if not docked:
		_say("Trade at a port. Land first (L).")
		return
	if index < 0 or index >= Economy.COMMODITIES.size():
		return
	var commodity: String = Economy.COMMODITIES[index]
	var planet: Dictionary = _planets_by_id.get(current_planet, {})
	var cost := Economy.buy_cost(planet, commodity, 1)
	if cost <= 0:
		_say("That commodity is not traded here.")
		return
	if credits < cost:
		_say("Not enough credits for 1t " + commodity + " (" + str(cost) + " cr).")
		return
	var ship_data: Dictionary = _ships.get(ship_class, {})
	var capacity := int(Dictionary(ship_data.get("stats", {})).get("cargo_capacity", 0))
	if Economy.cargo_used(cargo) >= capacity:
		_say("Hold is full (" + str(capacity) + "t). Sell cargo (Q) or fly a bigger ship.")
		return
	credits -= cost
	cargo[commodity] = int(cargo.get(commodity, 0)) + 1
	_say("Bought 1t " + commodity + " for " + str(cost) + " cr at " + _planet_name(current_planet) + ".")


func _sell_all_cargo() -> void:
	if not docked:
		_say("Trade at a port. Land first (L).")
		return
	if cargo.is_empty():
		_say("Hold is empty — nothing to sell.")
		return
	var planet: Dictionary = _planets_by_id.get(current_planet, {})
	var value := Economy.cargo_value(cargo, planet)
	credits += value
	cargo.clear()
	_say("Sold cargo for " + str(value) + " cr at " + _planet_name(current_planet) + ".")


func _save() -> void:
	var data := {
		"credits": credits,
		"ship_class": ship_class,
		"current_planet": current_planet,
		"completed_missions": completed_missions,
		"active_mission": active_mission_id,
		"cargo": cargo,
	}
	var err := SaveManager.save_game(data)
	if err == OK:
		_say("Saved. (user://escape_velocity_save.json)")
	else:
		_say("Save failed: error " + str(err))


func _load() -> void:
	var data := SaveManager.load_game()
	if data.is_empty():
		_say("No save found, or the save version is not v1.")
		return
	credits = int(data.get("credits", START_CREDITS))
	ship_class = String(data.get("ship_class", START_SHIP))
	current_planet = String(data.get("current_planet", START_PLANET))
	completed_missions = data.get("completed_missions", [])
	active_mission_id = String(data.get("active_mission", ""))
	cargo = data.get("cargo", {})
	if _ships.has(ship_class):
		var ship_data: Dictionary = _ships[ship_class]
		player.apply_stats(ship_data.get("stats", {}))
		ship_label.text = "Ship: " + String(ship_data.get("name", ship_class))
	_dock_at_current_planet()
	_say("Loaded save. Docked at " + _planet_name(current_planet) + ".")


func _say(text: String) -> void:
	message_label.text = text


func _camera_name() -> String:
	match backdrop.camera_mode:
		StackedSliceRenderer.CameraMode.CHASE:
			return "chase"
		StackedSliceRenderer.CameraMode.OVERHEAD:
			return "overhead"
		StackedSliceRenderer.CameraMode.COCKPIT:
			return "cockpit"
	return "chase"


func _mission_text() -> String:
	if active_mission_id == "":
		return "Mission: none — press M at a port"
	for mission in _missions:
		if String(mission["id"]) == active_mission_id:
			return "Mission: " + String(mission["title"]) + " -> " + _planet_name(String(mission["dest_planet"])) + " (" + str(int(mission["pay"])) + " cr)"
	return "Mission: none"


func _cargo_text() -> String:
	var ship_data: Dictionary = _ships.get(ship_class, {})
	var capacity := int(Dictionary(ship_data.get("stats", {})).get("cargo_capacity", 0))
	var parts: Array[String] = []
	for commodity in Economy.COMMODITIES:
		if int(cargo.get(commodity, 0)) > 0:
			parts.append(commodity + " x" + str(int(cargo[commodity])))
	var held := "empty"
	if parts.size() > 0:
		held = parts[0]
		for i in range(1, parts.size()):
			held += ", " + parts[i]
	return "Cargo: " + held + " (" + str(Economy.cargo_used(cargo)) + "/" + str(capacity) + "t)"


func _refresh_hud() -> void:
	credits_label.text = "Credits: " + str(credits) + " cr"
	planet_label.text = "Port: " + _planet_name(current_planet) + (" (docked)" if docked else " (in flight)")
	mission_label.text = _mission_text()
	cargo_label.text = _cargo_text()
	camera_label.text = "Camera: " + _camera_name() + " (Space)  |  Speed: " + str(int(player.speed_now()))
