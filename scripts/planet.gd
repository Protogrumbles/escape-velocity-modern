# A landable body in the current system (design doc §4).
# The node is placed in scenes/main.tscn; game.gd reads planet_id
# and looks the body up in data/planets.json for its name, economy
# and prices. The landing radius ring is drawn around the body.
class_name PlanetBody
extends Node2D

@export var planet_id: String = ""
@export var radius: float = 48.0
@export var colour: Color = Color(0.35, 0.62, 0.38)

const LANDING_MARGIN := 40.0


func landing_radius() -> float:
	return radius + LANDING_MARGIN


func _draw() -> void:
	# Body: solid disc with a darker rim, then the landing ring.
	draw_circle(Vector2.ZERO, radius, colour)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, colour.darkened(0.35), 3.0)
	# Inner detail ring, so planets are distinguishable at a glance.
	draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 32, colour.lightened(0.25), 2.0)
	# Landing radius: where L works, if you are slow enough.
	draw_arc(Vector2.ZERO, landing_radius(), 0.0, TAU, 64, Color(1, 1, 1, 0.35), 1.5)
