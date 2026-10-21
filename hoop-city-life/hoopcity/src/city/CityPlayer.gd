extends Node2D
## The walking avatar in the city / home / shops. Reads outfit from the profile.

var t := 0.0
var moving := false
var last_pos := Vector2.ZERO
var facing := 1.0
var walk_back := false

func _ready() -> void:
	z_index = 8

func _process(delta: float) -> void:
	var was_moving := moving
	var dx := position.x - last_pos.x
	var dy := position.y - last_pos.y
	moving = position.distance_to(last_pos) > 0.5
	last_pos = position
	if moving:
		t += delta * 9.0
		if absf(dx) > 0.4:
			facing = 1.0 if dx > 0.0 else -1.0
		# Stick / walk UP the pavement (toward the shops) = back view.
		walk_back = dy < -0.35
	else:
		walk_back = false
	# Only repaint when the pose is actually changing: standing still, the
	# figure is identical from frame to frame.
	if moving or was_moving != moving:
		queue_redraw()

func _draw() -> void:
	# One shared avatar for every scene, so your character does not change
	# style the moment you walk through a door.
	var h := 62.0 * Game.height_factor()
	# No ball in the street: he walks with his arms swinging, not clutching a
	# basketball that follows him everywhere like it is glued on.
	Avatar.draw_body(self, Vector2.ZERO, h, facing,
		Avatar.pose(Avatar.RUN if moving else Avatar.IDLE, t),
		Avatar.colours(true), false, true, true)

func _wear_col(slot: String, fallback: Color) -> Color:
	var id: String = String(Game.profile["outfit"].get(slot, ""))
	if id == "":
		return fallback
	var w: Dictionary = Items.wear(id)
	if w.is_empty() or not w.has("col"):
		return fallback
	return Color(w["col"])

func _ellipse(c: Vector2, r: Vector2) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		p.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return p
