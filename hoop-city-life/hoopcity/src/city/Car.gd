extends Node2D
## Simple traffic agent: drives its lane, brakes for the car ahead and for red lights.

var dir := 1
var speed := 200.0
var base_speed := 200.0
var col := Color.RED
var night := 0.0
const LANE_A := 380.0
const LANE_B := 480.0

func setup(x: float, d: int) -> void:
	dir = d
	position = Vector2(x, LANE_A if d > 0 else LANE_B)
	base_speed = randf_range(150, 300)
	speed = base_speed
	col = Color.from_hsv(randf(), 0.6, 0.85)
	z_index = 5

func set_night(v: float) -> void:
	# Repaint only on whole light steps: headlights switch on/off at a
	# threshold, everything finer is handled by the global day/night tint.
	var step := roundf(v / 0.15) * 0.15
	if absf(step - night) < 0.001:
		return
	night = step
	queue_redraw()

## Cars in the same lane, cached once instead of rescanning every child of the
## scene on every frame. The old loop walked the whole scene tree per car, per
## frame -- with eight cars that is a scan of everything sixty times a second,
## which is what made walking through the city stutter.
var _lane_mates: Array = []
var _rescan := 0.0

func _refresh_lane_mates() -> void:
	_lane_mates.clear()
	var parent := get_parent()
	if parent == null:
		return
	for c in parent.get_children():
		if c == self or c.get_script() != get_script():
			continue
		if absf(c.position.y - position.y) > 10.0:
			continue
		_lane_mates.append(c)

func _process(delta: float) -> void:
	# Lane membership never changes, so this only has to run once.
	_rescan -= delta
	if _lane_mates.is_empty() and _rescan <= 0.0:
		_refresh_lane_mates()
		_rescan = 2.0

	# brake for the car ahead in the same lane
	var blocked := false
	for c in _lane_mates:
		if not is_instance_valid(c):
			continue
		var ahead: float = (c.position.x - position.x) * dir
		if ahead > 0 and ahead < 150:
			blocked = true
			break
	# traffic light every 900px: red for part of the cycle
	var phase := fmod(Time.get_ticks_msec() / 1000.0, 12.0)
	var light_red := phase < 4.0
	var next_light: float = (floor(position.x / 900.0) + (1 if dir > 0 else 0)) * 900.0
	var dist_light: float = (next_light - position.x) * dir
	if light_red and dist_light > 0 and dist_light < 120:
		blocked = true

	speed = lerpf(speed, 0.0 if blocked else base_speed, 4.0 * delta)
	position.x += dir * speed * delta
	if position.x > 1900: position.x = -1900
	if position.x < -1900: position.x = 1900
	# The car's ARTWORK does not change as it drives -- only its position does,
	# and moving a Node2D already redraws it. Repainting by hand every frame
	# just burned time.

func _draw() -> void:
	var w := 78.0
	var h := 28.0
	draw_rect(Rect2(-w / 2, -h, w, h), col.lerp(col.darkened(0.5), night))
	draw_rect(Rect2(-w * 0.22, -h - 16, w * 0.5, 16), col.darkened(0.25))
	draw_circle(Vector2(-w * 0.28, 0), 8, Color(0.1, 0.1, 0.12))
	draw_circle(Vector2(w * 0.28, 0), 8, Color(0.1, 0.1, 0.12))
	if night > 0.2:
		var fx := dir * w * 0.5
		draw_circle(Vector2(fx, -h * 0.55), 5, Color(1, 0.95, 0.7))
		var beam := PackedVector2Array([
			Vector2(fx, -h * 0.55), Vector2(fx + dir * 150, -h * 0.9), Vector2(fx + dir * 150, h * 0.4)])
		draw_colored_polygon(beam, Color(1, 0.95, 0.7, 0.13 * night))
