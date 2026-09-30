extends RefCounted
class_name WeatherArt
## Shared rain / snow / clouds / seasonal foliage for city AND street court.

static func season() -> String:
	var g := _game()
	return String(g.climate_season()) if g != null and g.has_method("climate_season") else "spring"

static func weather() -> String:
	var g := _game()
	return String(g.weather()) if g != null and g.has_method("weather") else "clear"

## 0 = bare, 1 = full canopy. Autumn dries and sheds over the 10-day block.
static func foliage() -> float:
	var g := _game()
	var day: int = 1
	if g != null:
		day = int(g.profile.get("day", 1))
	var in_block: float = float((day - 1) % 10) / 9.0
	match season():
		"spring":
			return lerpf(0.25, 1.0, in_block)
		"summer":
			return 1.0
		"autumn":
			return lerpf(1.0, 0.0, in_block)
		_:
			return 0.0

static func leaf_color() -> Color:
	match season():
		"autumn":
			var t: float = 1.0 - foliage()
			return Color(0.28, 0.55, 0.22).lerp(Color(0.62, 0.32, 0.10), clampf(t * 1.4, 0.0, 1.0))
		"spring":
			return Color(0.42, 0.72, 0.32)
		"winter":
			return Color(0.55, 0.58, 0.52, 0.0)
		_:
			return Color(0.22, 0.52, 0.24)

static func _game() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Game")
	return null

## Sky layer: drifting white clouds + falling rain/snow that vanish at `ground_y`.
static func draw_sky_weather(c: CanvasItem, origin: Vector2, size: Vector2, t: float,
		ground_y := -1.0) -> void:
	var w: String = weather()
	var gy: float = origin.y + size.y * 0.72 if ground_y < 0.0 else ground_y
	if w == "cloudy" or w == "rain" or w == "snow":
		var over: Color = Color(0.55, 0.60, 0.68, 0.16)
		if w == "rain":
			over = Color(0.42, 0.44, 0.48, 0.18)
		c.draw_rect(Rect2(origin, Vector2(size.x, size.y * 0.38)), over)
		for i in 5:
			var cx: float = origin.x + fmod(t * 12.0 + float(i) * 640.0, size.x + 280.0) - 140.0
			var cy: float = origin.y + 28.0 + float(i % 3) * 22.0
			_cloud(c, Vector2(cx, cy), 70.0 + float(i % 3) * 14.0, w == "rain")
	if w == "rain":
		_rain(c, origin, size, gy, t)
	if w == "snow":
		for i in 90:
			var sx: float = origin.x + fmod(float((i * 113) % int(maxf(size.x, 2.0))) + sin(t * 0.8 + float(i)) * 18.0, size.x)
			var life: float = fmod(t * 0.55 + float(i) * 0.017, 1.0)
			var sy: float = origin.y + life * (gy - origin.y)
			if life < 0.97:
				c.draw_circle(Vector2(sx, sy), 2.0 + float(i % 3), Color(0.96, 0.97, 1.0, 0.78))

## Extra city-ground shadow under drifting clouds.
static func draw_cloud_shadows(c: CanvasItem, origin: Vector2, size: Vector2, t: float) -> void:
	if weather() != "cloudy" and weather() != "rain":
		return
	for i in 5:
		var cx: float = origin.x + fmod(t * 22.0 + float(i) * 640.0, size.x + 200.0) - 80.0
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 160.0, origin.y + size.y * 0.55),
			Vector2(cx + 200.0, origin.y + size.y * 0.55),
			Vector2(cx + 140.0, origin.y + size.y * 0.92),
			Vector2(cx - 90.0, origin.y + size.y * 0.92)]),
			Color(0.12, 0.14, 0.18, 0.16))

static func _rain(c: CanvasItem, origin: Vector2, size: Vector2, gy: float, t: float) -> void:
	## Few, slow, almost-vertical droplets — not a sheet sliding left.
	var n := 42
	var sx: float = maxf(size.x, 2.0)
	for i in n:
		var seed: float = float(i) * 19.17
		var life: float = fmod(t * 0.62 + seed * 0.041, 1.0)
		var rx: float = origin.x + fmod(float((i * 137) % int(sx)) + sin(seed) * 8.0, sx)
		var y0: float = origin.y + 6.0
		var ry: float = lerpf(y0, gy, life)
		if life < 0.92:
			var col := Color(0.55, 0.72, 0.88, 0.38)
			c.draw_line(Vector2(rx, ry), Vector2(rx - 1.2, ry + 11.0), col, 1.15)
		else:
			var k: float = (life - 0.92) / 0.08
			c.draw_arc(Vector2(rx, gy), 2.0 + k * 5.0, PI, TAU, 6,
				Color(0.55, 0.74, 0.90, 0.28 * (1.0 - k)), 1.0)

static func _cloud(c: CanvasItem, p: Vector2, r: float, storm := false) -> void:
	var col := Color(0.48, 0.50, 0.54, 0.55) if storm else Color(0.96, 0.97, 0.99, 0.62)
	c.draw_circle(p, r, col)
	c.draw_circle(p + Vector2(r * 0.72, 10.0), r * 0.74, col)
	c.draw_circle(p + Vector2(-r * 0.68, 12.0), r * 0.64, col)
	if not storm:
		c.draw_circle(p + Vector2(r * 0.18, -r * 0.28), r * 0.55, Color(1, 1, 1, 0.40))

static func draw_ground_snow(c: CanvasItem, rect: Rect2) -> void:
	if weather() != "snow" and season() != "winter":
		return
	var a: float = 0.55 if weather() == "snow" else 0.28
	c.draw_rect(rect, Color(0.92, 0.94, 0.98, a))

static func draw_roof_snow(c: CanvasItem, pts: PackedVector2Array) -> void:
	if weather() != "snow" and season() != "winter":
		return
	if pts.size() < 3:
		return
	c.draw_colored_polygon(pts, Color(0.94, 0.96, 1.0, 0.82 if weather() == "snow" else 0.45))
