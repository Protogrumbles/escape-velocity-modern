# Player ship — Newtonian flight with mouse steering (design doc §3).
# The ship turns toward the mouse cursor at its turn rate; thrust
# accelerates along the nose, not along the velocity, so the ship
# drifts. Arrow keys / A,D steer as a keyboard-only fallback.
# Left mouse click triggers a barrel roll (0.5 s). F fires the
# primary weapon. There are no enemies in slice 1, so shots simply
# fly straight and expire; combat arrives in Stage C.
#
# Stats are applied at runtime by game.gd from data/ships/*.json
# via apply_stats(). The visuals here are drawn shapes, not a
# sprite: the pixel-ship-factory sprite for the ship class is the
# art pass that replaces _draw_ship() (see AGENTS.md).
class_name PlayerShip
extends Node2D

const VIEWPORT_SIZE := Vector2(1152, 648)
const ROLL_DURATION := 0.5
const SHOT_SPEED := 520.0
const SHOT_LIFETIME := 1.2
const TRAIL_LENGTH := 84
const AFTERBURNER_MULT := 1.8

var thrust_accel: float = 180.0
var turn_rate_deg: float = 150.0
var max_speed: float = 300.0
var hull_hp: float = 70.0
var cargo_capacity: int = 10
var weapon_name: String = "Light pulse laser"
var weapon_damage: int = 6

var velocity: Vector2 = Vector2.ZERO
var frozen: bool = false
var thrusting: bool = false
var banking: float = 0.0

var _roll_timer: float = 0.0
var _shots: Array = []
var _trail: Array = []
var _fire_cooldown: float = 0.0


func apply_stats(stats: Dictionary) -> void:
	thrust_accel = float(stats.get("thrust", thrust_accel))
	turn_rate_deg = float(stats.get("turn_rate_deg", turn_rate_deg))
	max_speed = float(stats.get("max_speed", max_speed))
	hull_hp = float(stats.get("hull_hp", hull_hp))
	cargo_capacity = int(stats.get("cargo_capacity", cargo_capacity))
	weapon_name = String(stats.get("weapon", weapon_name))
	weapon_damage = int(stats.get("weapon_damage", weapon_damage))


func speed_now() -> float:
	return velocity.length()


func set_frozen(value: bool) -> void:
	frozen = value
	if frozen:
		velocity = Vector2.ZERO
		thrusting = false


func _unhandled_input(event: InputEvent) -> void:
	if frozen:
		return
	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.pressed and button_event.button_index == MOUSE_BUTTON_LEFT:
			_start_roll()


func _start_roll() -> void:
	if _roll_timer > 0.0:
		return
	_roll_timer = ROLL_DURATION
	# Small sideways kick, as in the design doc.
	var side := Vector2(-sin(rotation), cos(rotation))
	velocity += side * 60.0


func _process(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	if _roll_timer > 0.0:
		_roll_timer = maxf(0.0, _roll_timer - delta)
	_update_shots(delta)
	if frozen:
		queue_redraw()
		return
	_steer(delta)
	_thrust(delta)
	_wrap_to_viewport()
	_update_trail()
	queue_redraw()


func _steer(delta: float) -> void:
	var turn_rate := deg_to_rad(turn_rate_deg)
	var desired_change := 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		desired_change = -turn_rate * delta
	elif Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		desired_change = turn_rate * delta
	else:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 24.0:
			var desired := to_mouse.angle()
			var diff := wrapf(desired - rotation, -PI, PI)
			var step := clampf(diff, -turn_rate * delta, turn_rate * delta)
			desired_change = step
	rotation += desired_change
	# Banking is proportional to how hard we are turning this frame.
	banking = clampf(desired_change / maxf(turn_rate * delta, 0.001), -1.0, 1.0)


func _thrust(delta: float) -> void:
	var afterburner := Input.is_key_pressed(KEY_SHIFT)
	var want_thrust := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	thrusting = want_thrust
	var accel := thrust_accel * (AFTERBURNER_MULT if afterburner else 1.0)
	if want_thrust:
		velocity += Vector2(cos(rotation), sin(rotation)) * accel * delta
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		# Retro / brake burn: weak reverse thrust.
		velocity -= Vector2(cos(rotation), sin(rotation)) * thrust_accel * 0.4 * delta
	# Very gentle drag cap only, so top speed stays readable (doc §3).
	velocity *= exp(-0.05 * delta)
	if velocity.length() > max_speed * (AFTERBURNER_MULT if afterburner else 1.0):
		velocity = velocity.normalized() * max_speed * (AFTERBURNER_MULT if afterburner else 1.0)
	global_position += velocity * delta
	if Input.is_key_pressed(KEY_F) and _fire_cooldown <= 0.0:
		_fire()


func _fire() -> void:
	_fire_cooldown = 0.22
	var nose := global_position + Vector2(cos(rotation), sin(rotation)) * 26.0
	_shots.append({
		"pos": nose,
		"vel": Vector2(cos(rotation), sin(rotation)) * SHOT_SPEED + velocity * 0.5,
		"life": SHOT_LIFETIME,
	})


func _update_shots(delta: float) -> void:
	var kept: Array = []
	for shot in _shots:
		shot["pos"] = shot["pos"] + shot["vel"] * delta
		shot["life"] = float(shot["life"]) - delta
		if float(shot["life"]) > 0.0:
			kept.append(shot)
	_shots = kept


func _update_trail() -> void:
	# Trail entries are {pos, kind}: "engine" (orange, always while
	# thrusting) and "wing_l" / "wing_r" (white wingtip contrails,
	# only while banking hard — DESIGN.md section 2). Three entries
	# per frame at most, hence TRAIL_LENGTH 84 (was 28 x 1).
	if thrusting:
		var nose := Vector2(cos(rotation), sin(rotation))
		_trail.append({"pos": global_position - nose * 20.0, "kind": "engine"})
		if absf(banking) > 0.3:
			var side := Vector2(-sin(rotation), cos(rotation))
			_trail.append({"pos": global_position + side * 10.0 - nose * 8.0, "kind": "wing_l"})
			_trail.append({"pos": global_position - side * 10.0 - nose * 8.0, "kind": "wing_r"})
		while _trail.size() > TRAIL_LENGTH:
			_trail.remove_at(0)
	elif _trail.size() > 0:
		_trail.remove_at(0)


func _wrap_to_viewport() -> void:
	var p := global_position
	if p.x < -32.0:
		p.x = VIEWPORT_SIZE.x + 32.0
	elif p.x > VIEWPORT_SIZE.x + 32.0:
		p.x = -32.0
	if p.y < -32.0:
		p.y = VIEWPORT_SIZE.y + 32.0
	elif p.y > VIEWPORT_SIZE.y + 32.0:
		p.y = -32.0
	global_position = p


func _draw() -> void:
	# Engine trail: fading dots behind the ship. Engine dots are
	# orange; wingtip contrails are white and smaller.
	for i in _trail.size():
		var alpha := float(i) / maxf(float(_trail.size()), 1.0) * 0.55
		var entry: Dictionary = _trail[i]
		var trail_pos: Vector2 = entry["pos"]
		var local: Vector2 = to_local(trail_pos)
		if String(entry["kind"]) == "engine":
			draw_circle(local, 2.5, Color(1.0, 0.7, 0.28, alpha))
		else:
			draw_circle(local, 1.5, Color(1.0, 1.0, 1.0, alpha * 0.8))
	# Barrel roll: squash the ship vertically through the roll.
	var roll_scale := 1.0
	if _roll_timer > 0.0:
		roll_scale = absf(cos((_roll_timer / ROLL_DURATION) * PI))
	_draw_ship(roll_scale)
	# Shots.
	for shot in _shots:
		var shot_pos: Vector2 = shot["pos"]
		var local_shot: Vector2 = to_local(shot_pos)
		draw_circle(local_shot, 2.0, Color(1.0, 0.9, 0.4))


func _draw_ship(roll_scale: float) -> void:
	# Ship points +X (rotation is the heading). Hull in muted tones;
	# engine glow carries the saturated colour (art rules, doc §2).
	var bank_shear := banking * 4.0
	var nose := Vector2(24, 0)
	var tail_left := Vector2(-16, -9 * roll_scale + bank_shear)
	var tail_right := Vector2(-16, 9 * roll_scale - bank_shear)
	var hull := PackedVector2Array([nose, tail_left, Vector2(-8, 0), tail_right])
	draw_colored_polygon(hull, Color(0.62, 0.66, 0.72))
	draw_line(nose, tail_left, Color(0.25, 0.28, 0.33), 1.5)
	draw_line(nose, tail_right, Color(0.25, 0.28, 0.33), 1.5)
	# Cockpit canopy near the nose.
	draw_circle(Vector2(8, 0), 3.5 * maxf(roll_scale, 0.3), Color(0.62, 0.91, 1.0))
	# Engine glow at the tail; brighter while thrusting.
	if thrusting:
		var glow_len := 12.0 + sin(Time.get_ticks_msec() / 40.0) * 3.0
		draw_rect(Rect2(-16 - glow_len, -3, glow_len, 6), Color(1.0, 0.7, 0.28))
