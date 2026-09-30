extends Node2D
## Procedural skyline, road, sidewalk, buildings, street lamps.

var buildings: Array = []
var night := 0.0
var _bg_seed := 12345
var _skyline: Array = []

func _ready() -> void:
	z_index = -20
	_build_skyline()
	set_process(true)

var _wx := 0.0
func _process(delta: float) -> void:
	_wx += delta
	if _wx < 0.033:
		return
	_wx = 0.0
	if WeatherArt.weather() in ["rain", "snow", "cloudy"] or WeatherArt.season() in ["autumn", "winter"]:
		queue_redraw()

func set_night(v: float) -> void:
	# Re-rasterise the whole city only when the light has moved a whole step.
	# A 0.04 threshold repainted this (the biggest canvas item in the scene)
	# once or twice a second while the tint eased in, which is the "starts
	# stuttering two seconds after I walk" hitch. 0.12 steps = a handful of
	# repaints across an entire dawn/dusk transition, with no visible pop.
	var step := roundf(v / 0.12) * 0.12
	if absf(step - night) < 0.001:
		return
	night = step
	queue_redraw()

## Precompute the skyline and every window's lighting threshold. Seeded and
## deterministic, so the city looks identical -- but drawing no longer needs
## the random generator, which was the biggest per-redraw cost in the scene.
func _build_skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _bg_seed
	_skyline.clear()
	var x := -3600.0
	while x < 3800.0:
		var w := rng.randf_range(90, 190)
		var h := rng.randf_range(180, 520)
		var win: Array = []
		var cols := int(w / 26)
		var rows := int(h / 34)
		for cx in cols:
			for cy in rows:
				win.append({
					"x": x + 10 + cx * 26, "y": -h + 12 + cy * 34,
					"v": rng.randf(),
				})
		_skyline.append({"x": x, "w": w, "h": h, "win": win})
		x += w + rng.randf_range(8, 30)

func _draw() -> void:
	# sky
	draw_rect(Rect2(-3800, -700, 8000, 1600), Color(0.55, 0.72, 0.9).lerp(Color(0.05, 0.06, 0.14), night))
	# far skyline -- geometry precomputed once, so a redraw is pure iteration
	# over cached rectangles with no random generation.
	var lit_p: float = 0.12 + night * 0.5
	var lit_a: float = 0.15 + night * 0.75
	for b in _skyline:
		var w: float = b["w"]
		var h: float = b["h"]
		draw_rect(Rect2(b["x"], -h, w, h + 160),
			Color(0.30, 0.34, 0.42).lerp(Color(0.08, 0.09, 0.16), night))
		for wd in b["win"]:
			if float(wd["v"]) < lit_p:
				draw_rect(Rect2(wd["x"], wd["y"], 12, 18), Color(1.0, 0.9, 0.6, lit_a))

	# sidewalk + road
	draw_rect(Rect2(-3800, 140, 8000, 60), Color(0.62, 0.62, 0.6).lerp(Color(0.2, 0.21, 0.26), night))
	draw_rect(Rect2(-3800, 340, 8000, 220), Color(0.24, 0.24, 0.27).lerp(Color(0.09, 0.09, 0.12), night))
	draw_rect(Rect2(-3800, 200, 8000, 140), Color(0.58, 0.58, 0.57).lerp(Color(0.18, 0.19, 0.24), night))
	for i in range(-70, 72):
		draw_rect(Rect2(i * 100, 445, 55, 6), Color(0.9, 0.85, 0.4, 0.7))

	# The far side of the street. You can never cross the road, so these are
	# pure scenery -- they exist so the opposite pavement is not an empty band
	# of grey. Same drawing vocabulary as the real shops, just smaller, dimmer
	# and pushed back above the far kerb.
	_draw_far_side()

	# Street trees in the gaps between shop fronts, foliage follows the season.
	_draw_street_trees()

	# enterable buildings -- each one has its own silhouette and roof, so the
	# street reads as a place instead of a row of identical boxes.
	for b in buildings:
		_draw_building(b)
	# Beyond the walkable ends: extra shop fronts so the street never dies
	# into a grey void. Pure scenery — the player stops before reaching them.
	_draw_edge_blocks()

	# street lamps + light pools. The beam is only the suggestion; the lamp must
	# actually ILLUMINATE the pavement below it, so a pool of warm light is
	# drawn on the sidewalk and road that brightens as the night deepens.
	for i in range(-7, 8):
		var lx := i * 520.0
		var glow := clampf(night, 0.0, 1.0)
		var bx := lx + 34.0
		if glow > 0.02:
			for k in 6:
				draw_circle(Vector2(bx, 250.0), 70.0 + k * 55.0,
					Color(1.0, 0.90, 0.62, 0.055 * glow))
			draw_rect(Rect2(bx - 90.0, 40.0, 180.0, 200.0),
				Color(1.0, 0.88, 0.55, 0.07 * glow))
			draw_colored_polygon(PackedVector2Array([
				Vector2(bx - 210.0, 336.0), Vector2(bx + 210.0, 336.0),
				Vector2(bx + 70.0, 200.0), Vector2(bx - 70.0, 200.0)]),
				Color(1.0, 0.90, 0.58, 0.20 * glow))
		draw_line(Vector2(lx, 200), Vector2(lx, 40), Color(0.22, 0.22, 0.25), 6)
		draw_line(Vector2(lx, 40), Vector2(lx + 34, 40), Color(0.22, 0.22, 0.25), 5)
		draw_circle(Vector2(bx, 46), 11, Color(0.5, 0.5, 0.5).lerp(Color(1.0, 0.96, 0.75), night))
		if glow > 0.12:
			draw_circle(Vector2(bx, 46), 22.0, Color(1.0, 0.94, 0.70, 0.35 * glow))
			draw_colored_polygon(PackedVector2Array([
				Vector2(bx, 52), Vector2(bx + 160, 340), Vector2(bx - 90, 340)]),
				Color(1.0, 0.92, 0.65, 0.10 * glow))
	# Rain/snow in FRONT of the street so the drops are visible.
	_draw_weather()


func _draw_street_trees() -> void:
	var season: String = "summer"
	if Engine.get_main_loop() is SceneTree:
		var g: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Game")
		if g != null and g.has_method("climate_season"):
			season = String(g.climate_season())
	var leaf: Color
	match season:
		"autumn":
			leaf = Color(0.78, 0.42, 0.12)
		"winter":
			leaf = Color(0.72, 0.76, 0.80, 0.0)
		"spring":
			leaf = Color(0.45, 0.72, 0.32)
		_:
			leaf = Color(0.22, 0.52, 0.24)
	var xs: Array = [-1480.0, -1120.0, -780.0, -420.0, -80.0, 280.0, 640.0, 1020.0, 1380.0]
	for x in xs:
		var trunk := Color(0.32, 0.20, 0.12).lerp(Color(0.12, 0.08, 0.06), night)
		draw_rect(Rect2(x - 6.0, 70.0, 12.0, 130.0), trunk)
		if leaf.a > 0.05:
			var lc: Color = leaf.lerp(leaf.darkened(0.55), night)
			draw_circle(Vector2(x, 40.0), 48.0, lc)
			draw_circle(Vector2(x - 22.0, 58.0), 32.0, lc.darkened(0.08))
			draw_circle(Vector2(x + 24.0, 52.0), 30.0, lc.lightened(0.06))
		elif season == "winter":
			draw_circle(Vector2(x, 48.0), 6.0, trunk)
			for k in 5:
				var a: float = -2.2 + k * 0.55
				draw_line(Vector2(x, 70.0), Vector2(x + cos(a) * 36.0, 70.0 + sin(a) * 28.0), trunk, 3.0)

func _draw_weather() -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	WeatherArt.draw_sky_weather(self, Vector2(-3800, -700), Vector2(8000, 1400), t, 336.0)
	WeatherArt.draw_cloud_shadows(self, Vector2(-3800, 140), Vector2(8000, 220), t)
	if WeatherArt.season() == "winter" or WeatherArt.weather() == "snow":
		draw_rect(Rect2(-3800, 140, 8000, 60), Color(0.90, 0.92, 0.96, 0.45))
		draw_rect(Rect2(-3800, 200, 8000, 140), Color(0.88, 0.90, 0.95, 0.28))

## One building. `id` decides the shape: a pitched roof on the house and the
## shops, timber cladding on the gym, a domed arena for the big games.
func _draw_building(b: Dictionary) -> void:
	var p: Vector2 = b["pos"]
	var id: String = String(b["id"])
	var base: Color = b["color"]
	var col: Color = base.lerp(base.darkened(0.65), night)
	var f := ThemeDB.fallback_font
	var lit := Color(1, 1, 1).lerp(Color(1.0, 0.9, 0.55), night)

	match id:
		"arena":
			_draw_arena(p, col)
		"gym":
			_draw_gym(p, col)
		"court", "park":
			_draw_open_court(p, col, id == "court")
		_:
			_draw_shop(p, col, id == "home")

	# sign board on a post, above whatever roof we just drew
	draw_string(f, Vector2(p.x - 120, p.y - 330), String(b["name"]),
		HORIZONTAL_ALIGNMENT_LEFT, 240, 26, lit)

## Scenery buildings on the unreachable side of the road.
const FAR_SIDE := [
	{"x": -1560.0, "kind": "shop",  "name": "Laundrette",   "col": Color(0.46, 0.52, 0.60)},
	{"x": -1180.0, "kind": "tower", "name": "Apartments",   "col": Color(0.52, 0.44, 0.40)},
	{"x": -860.0,  "kind": "shop",  "name": "Barber",       "col": Color(0.60, 0.40, 0.36)},
	{"x": -520.0,  "kind": "diner", "name": "Corner Diner", "col": Color(0.70, 0.56, 0.28)},
	{"x": -140.0,  "kind": "tower", "name": "Offices",      "col": Color(0.40, 0.46, 0.56)},
	{"x": 240.0,   "kind": "shop",  "name": "Hardware",     "col": Color(0.48, 0.50, 0.44)},
	{"x": 600.0,   "kind": "diner", "name": "Noodle Bar",   "col": Color(0.64, 0.34, 0.34)},
	{"x": 980.0,   "kind": "tower", "name": "Flats",        "col": Color(0.44, 0.42, 0.52)},
	{"x": 1340.0,  "kind": "shop",  "name": "Print Shop",   "col": Color(0.54, 0.48, 0.62)},
	{"x": 1700.0,  "kind": "diner", "name": "Cafe",         "col": Color(0.66, 0.52, 0.30)},
	{"x": 2040.0,  "kind": "tower", "name": "Storage",      "col": Color(0.42, 0.44, 0.48)},
	{"x": -1940.0, "kind": "shop",  "name": "Garage",       "col": Color(0.50, 0.46, 0.40)},
	{"x": -2320.0, "kind": "tower", "name": "Lofts",        "col": Color(0.46, 0.40, 0.48)},
	{"x": -2700.0, "kind": "diner", "name": "Night Diner",  "col": Color(0.62, 0.42, 0.28)},
	{"x": -3080.0, "kind": "shop",  "name": "Tyres",        "col": Color(0.40, 0.44, 0.42)},
	{"x": 2420.0,  "kind": "shop",  "name": "Florist",      "col": Color(0.48, 0.56, 0.40)},
	{"x": 2800.0,  "kind": "tower", "name": "Studios",      "col": Color(0.50, 0.48, 0.54)},
	{"x": 3180.0,  "kind": "diner", "name": "Bakery",       "col": Color(0.70, 0.54, 0.36)},
	{"x": 3560.0,  "kind": "shop",  "name": "Records",      "col": Color(0.42, 0.38, 0.50)},
]
## The far kerb. The walkable pavement is y 150..330 and the road is 340..560,
## so anything the player must not collide with has to stand ABOVE the near
## pavement, on the far side of the sky band. Placing these at 322 put them
## right on top of the player's own footpath.
const FAR_BASE_Y := 138.0

func _draw_far_side() -> void:
	for b in FAR_SIDE:
		var x: float = float(b["x"])
		var col: Color = Color(b["col"]).lerp(Color(b["col"]).darkened(0.72), night)
		# Haze: further away reads as slightly washed out toward the sky.
		col = col.lerp(Color(0.55, 0.66, 0.80), 0.18 * (1.0 - night))
		match String(b["kind"]):
			"tower":
				_far_tower(Vector2(x, FAR_BASE_Y), col)
			"diner":
				_far_diner(Vector2(x, FAR_BASE_Y), col)
			_:
				_far_shop(Vector2(x, FAR_BASE_Y), col)

func _far_tower(p: Vector2, col: Color) -> void:
	var w := 150.0
	var h := 300.0
	draw_rect(Rect2(p.x - w * 0.5, p.y - h, w, h), col)
	draw_rect(Rect2(p.x - w * 0.5, p.y - h, w, h), col.darkened(0.35), false, 3.0)
	# roof lip
	draw_rect(Rect2(p.x - w * 0.5 - 8.0, p.y - h - 12.0, w + 16.0, 14.0), col.darkened(0.28))
	# windows, lit at night
	for row in 6:
		for c in 3:
			var wx: float = p.x - w * 0.5 + 20.0 + c * 44.0
			var wy: float = p.y - h + 26.0 + row * 44.0
			var on: bool = ((row * 3 + c + int(p.x)) % 5) < (1 + int(night * 3.0))
			draw_rect(Rect2(wx, wy, 26.0, 30.0),
				Color(1.0, 0.90, 0.60, 0.85) if on and night > 0.25
				else Color(0.30, 0.38, 0.46).lerp(Color(0.10, 0.12, 0.18), night))

func _far_shop(p: Vector2, col: Color) -> void:
	var w := 170.0
	var h := 180.0
	draw_rect(Rect2(p.x - w * 0.5, p.y - h, w, h), col)
	draw_rect(Rect2(p.x - w * 0.5, p.y - h, w, h), col.darkened(0.35), false, 3.0)
	# awning
	draw_colored_polygon(PackedVector2Array([
		Vector2(p.x - w * 0.5 - 6.0, p.y - 74.0),
		Vector2(p.x + w * 0.5 + 6.0, p.y - 74.0),
		Vector2(p.x + w * 0.5 - 4.0, p.y - 48.0),
		Vector2(p.x - w * 0.5 + 4.0, p.y - 48.0)]), col.darkened(0.30))
	# shopfront glass + door
	draw_rect(Rect2(p.x - w * 0.5 + 14.0, p.y - 44.0, w - 28.0, 44.0),
		Color(0.75, 0.85, 0.92, 0.55).lerp(Color(1.0, 0.86, 0.50, 0.75), night))
	draw_rect(Rect2(p.x - 18.0, p.y - 44.0, 36.0, 44.0), col.darkened(0.45))
	# upper windows
	for c in 2:
		draw_rect(Rect2(p.x - 52.0 + c * 66.0, p.y - h + 30.0, 38.0, 40.0),
			Color(0.32, 0.40, 0.48).lerp(Color(1.0, 0.88, 0.55), night * 0.8))

func _far_diner(p: Vector2, col: Color) -> void:
	var w := 190.0
	var h := 130.0
	# low box with a rounded roof strip
	draw_rect(Rect2(p.x - w * 0.5, p.y - h, w, h), col)
	draw_rect(Rect2(p.x - w * 0.5, p.y - h, w, h), col.darkened(0.35), false, 3.0)
	draw_rect(Rect2(p.x - w * 0.5 - 6.0, p.y - h - 16.0, w + 12.0, 18.0),
		Color(0.85, 0.86, 0.88).lerp(Color(0.30, 0.30, 0.36), night))
	# long window band
	draw_rect(Rect2(p.x - w * 0.5 + 12.0, p.y - 82.0, w - 24.0, 46.0),
		Color(0.78, 0.88, 0.94, 0.6).lerp(Color(1.0, 0.84, 0.46, 0.8), night))
	for c in 4:
		draw_line(Vector2(p.x - w * 0.5 + 12.0 + c * 42.0, p.y - 82.0),
			Vector2(p.x - w * 0.5 + 12.0 + c * 42.0, p.y - 36.0),
			col.darkened(0.4), 3.0)
	draw_rect(Rect2(p.x - 22.0, p.y - 36.0, 44.0, 36.0), col.darkened(0.45))
	# neon sign, only worth lighting at night
	if night > 0.2:
		draw_rect(Rect2(p.x - 40.0, p.y - h - 44.0, 80.0, 24.0),
			Color(1.0, 0.42, 0.36, 0.35 + night * 0.5))

func _draw_edge_blocks() -> void:
	var west := [
		{"x": -1980.0, "name": "Lockups", "col": Color(0.48, 0.44, 0.40)},
		{"x": -2280.0, "name": "Warehouse", "col": Color(0.42, 0.46, 0.50)},
		{"x": -2580.0, "name": "Auto", "col": Color(0.52, 0.36, 0.32)},
		{"x": -2880.0, "name": "Depot", "col": Color(0.40, 0.42, 0.38)},
		{"x": -3180.0, "name": "Yards", "col": Color(0.46, 0.40, 0.36)},
	]
	var east := [
		{"x": 2780.0, "name": "Cinema", "col": Color(0.44, 0.34, 0.48)},
		{"x": 3080.0, "name": "School", "col": Color(0.48, 0.42, 0.36)},
		{"x": 3380.0, "name": "Station", "col": Color(0.40, 0.44, 0.50)},
	]
	for b in west + east:
		_draw_shop(Vector2(float(b["x"]), 60.0),
			Color(b["col"]).lerp(Color(b["col"]).darkened(0.65), night), false)
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(float(b["x"]) - 80.0, -250.0), String(b["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, 180, 22,
			Color(1, 1, 1).lerp(Color(1.0, 0.9, 0.55), night))

## Houses and shops: brick box, pitched tiled roof, chimney, glowing door.
func _draw_shop(p: Vector2, col: Color, is_home: bool) -> void:
	var w := 260.0
	draw_rect(Rect2(p.x - w * 0.5, p.y - 240, w, 380), col)
	draw_rect(Rect2(p.x - w * 0.5, p.y - 240, w, 380), Color(0, 0, 0, 0.35), false, 3)
	# brick courses
	for r in 9:
		draw_line(Vector2(p.x - w * 0.5, p.y - 232 + r * 42),
			Vector2(p.x + w * 0.5, p.y - 232 + r * 42), Color(0, 0, 0, 0.10), 2)
	# pitched roof, overhanging both sides
	var roof := Color(0.42, 0.22, 0.18).lerp(Color(0.14, 0.09, 0.10), night)
	draw_colored_polygon(PackedVector2Array([
		Vector2(p.x - w * 0.5 - 26, p.y - 240),
		Vector2(p.x + w * 0.5 + 26, p.y - 240),
		Vector2(p.x, p.y - 340)]), roof)
	if WeatherArt.weather() == "snow" or WeatherArt.season() == "winter":
		draw_colored_polygon(PackedVector2Array([
			Vector2(p.x - w * 0.5 - 20, p.y - 246),
			Vector2(p.x + w * 0.5 + 20, p.y - 246),
			Vector2(p.x, p.y - 338)]), Color(0.94, 0.96, 1.0, 0.82))
	# roof tiles
	for i in 7:
		var t: float = float(i + 1) / 8.0
		draw_line(Vector2(lerpf(p.x - w * 0.5 - 26, p.x, t), lerpf(p.y - 240, p.y - 340, t)),
			Vector2(lerpf(p.x + w * 0.5 + 26, p.x, t), lerpf(p.y - 240, p.y - 340, t)),
			Color(0, 0, 0, 0.13), 2)
	draw_line(Vector2(p.x - w * 0.5 - 26, p.y - 240), Vector2(p.x + w * 0.5 + 26, p.y - 240),
		Color(0, 0, 0, 0.3), 3)
	# chimney with a wisp of smoke on the house
	if is_home:
		draw_rect(Rect2(p.x + 56, p.y - 330, 34, 62), roof.darkened(0.2))
		for i in 3:
			draw_circle(Vector2(p.x + 73 + sin(float(i)) * 9.0, p.y - 350 - i * 26.0),
				10.0 + i * 4.0, Color(0.85, 0.85, 0.88, 0.16))
	# awning over the shopfront
	else:
		draw_colored_polygon(PackedVector2Array([
			Vector2(p.x - 120, p.y + 20), Vector2(p.x + 120, p.y + 20),
			Vector2(p.x + 145, p.y + 66), Vector2(p.x - 145, p.y + 66)]),
			Color(0.75, 0.28, 0.26).lerp(Color(0.24, 0.10, 0.10), night))
	# door + windows
	draw_rect(Rect2(p.x - 40, p.y + 60, 80, 80),
		Color(0.15, 0.12, 0.1).lerp(Color(1.0, 0.85, 0.5), night * 0.85))
	for r in 2:
		for c in 4:
			draw_rect(Rect2(p.x - 105 + c * 58, p.y - 200 + r * 76, 40, 48),
				Color(0.75, 0.85, 0.95, 0.6).lerp(Color(1.0, 0.88, 0.55, 0.95), night))

## Iron Gym: timber-clad shed with a low sloping roof and a lit sign.
func _draw_gym(p: Vector2, col: Color) -> void:
	var w := 300.0
	var timber := Color(0.46, 0.30, 0.18).lerp(Color(0.16, 0.11, 0.08), night)
	draw_rect(Rect2(p.x - w * 0.5, p.y - 230, w, 370), timber)
	# vertical planks with visible grain
	for i in 15:
		var x: float = p.x - w * 0.5 + i * 20.0
		draw_line(Vector2(x, p.y - 230), Vector2(x, p.y + 140), Color(0, 0, 0, 0.16), 2)
		draw_line(Vector2(x + 6, p.y - 210), Vector2(x + 6, p.y + 120),
			Color(1, 0.9, 0.7, 0.05), 3)
	draw_rect(Rect2(p.x - w * 0.5, p.y - 230, w, 370), Color(0, 0, 0, 0.35), false, 3)
	# shallow gable in darker timber
	draw_colored_polygon(PackedVector2Array([
		Vector2(p.x - w * 0.5 - 30, p.y - 230),
		Vector2(p.x + w * 0.5 + 30, p.y - 230),
		Vector2(p.x + w * 0.5 - 10, p.y - 306),
		Vector2(p.x - w * 0.5 + 10, p.y - 306)]), timber.darkened(0.30))
	# roof beams
	for i in 6:
		var bx: float = lerpf(p.x - w * 0.42, p.x + w * 0.42, float(i) / 5.0)
		draw_line(Vector2(bx, p.y - 232), Vector2(bx, p.y - 300), Color(0, 0, 0, 0.18), 3)
	# big garage-style door and a barbell mark
	draw_rect(Rect2(p.x - 78, p.y + 24, 156, 116),
		Color(0.20, 0.16, 0.13).lerp(Color(0.95, 0.80, 0.45), night * 0.8))
	draw_line(Vector2(p.x - 54, p.y + 82), Vector2(p.x + 54, p.y + 82),
		Color(0.85, 0.85, 0.9, 0.85), 7)
	for sx in [-1.0, 1.0]:
		draw_rect(Rect2(p.x + sx * 54 - 9, p.y + 62, 18, 40), Color(0.80, 0.80, 0.86, 0.9))
	# high strip windows, the way real gyms are lit
	for c in 4:
		draw_rect(Rect2(p.x - 118 + c * 64, p.y - 196, 48, 34),
			Color(0.80, 0.88, 0.96, 0.55).lerp(Color(1.0, 0.90, 0.58, 0.95), night))

## Riverside Arena: a domed bowl with floodlights and a marquee.
func _draw_arena(p: Vector2, col: Color) -> void:
	var w := 380.0
	# bowl
	draw_rect(Rect2(p.x - w * 0.5, p.y - 180, w, 320), col)
	draw_rect(Rect2(p.x - w * 0.5, p.y - 180, w, 320), Color(0, 0, 0, 0.35), false, 3)
	# dome roof
	var dome := col.lightened(0.12)
	var pts := PackedVector2Array()
	for i in 25:
		var a: float = PI + PI * float(i) / 24.0
		pts.append(Vector2(p.x + cos(a) * w * 0.5, p.y - 180 + sin(a) * 130.0))
	pts.append(Vector2(p.x + w * 0.5, p.y - 180))
	pts.append(Vector2(p.x - w * 0.5, p.y - 180))
	draw_colored_polygon(pts, dome)
	# dome ribs
	for i in 7:
		var a2: float = PI + PI * float(i + 1) / 8.0
		draw_line(Vector2(p.x, p.y - 180),
			Vector2(p.x + cos(a2) * w * 0.5, p.y - 180 + sin(a2) * 130.0),
			Color(0, 0, 0, 0.16), 3)
	# floodlight masts
	for sx in [-1.0, 1.0]:
		var mx: float = p.x + sx * (w * 0.5 + 46.0)
		draw_line(Vector2(mx, p.y + 140), Vector2(mx, p.y - 300), Color(0.28, 0.29, 0.34), 8)
		for k in 3:
			var lp := Vector2(mx + sx * 6.0, p.y - 300 + k * 26.0)
			draw_rect(Rect2(lp.x - 20, lp.y - 9, 40, 18),
				Color(0.60, 0.62, 0.68).lerp(Color(1.0, 0.97, 0.80), night))
		if night > 0.12:
			draw_colored_polygon(PackedVector2Array([
				Vector2(mx, p.y - 290), Vector2(p.x + sx * 40, p.y + 140),
				Vector2(p.x - sx * 120, p.y + 140)]),
				Color(1.0, 0.95, 0.75, 0.09 * night))
	# marquee band + entrance arches
	draw_rect(Rect2(p.x - w * 0.5 + 14, p.y - 60, w - 28, 54),
		Color(0.10, 0.10, 0.14).lerp(Color(0.95, 0.30, 0.35), 0.35 + night * 0.4))
	for c in 5:
		draw_rect(Rect2(p.x - w * 0.5 + 30 + c * 68, p.y + 40, 46, 100),
			Color(0.14, 0.12, 0.14).lerp(Color(1.0, 0.86, 0.52), night * 0.85))

## Outdoor courts: fenced tarmac with a visible hoop, not a building at all.
func _draw_open_court(p: Vector2, col: Color, roofed: bool) -> void:
	draw_rect(Rect2(p.x - 160, p.y - 40, 320, 180), col.darkened(0.15))
	draw_rect(Rect2(p.x - 160, p.y - 40, 320, 180), Color(1, 1, 1, 0.28), false, 3)
	draw_arc(Vector2(p.x, p.y + 140), 70, PI, TAU, 20, Color(1, 1, 1, 0.30), 3)
	# chain-link fence
	for i in 17:
		var fx: float = p.x - 160 + i * 20.0
		draw_line(Vector2(fx, p.y - 190), Vector2(fx, p.y - 40), Color(0.72, 0.75, 0.80, 0.30), 2)
	for r in 5:
		draw_line(Vector2(p.x - 160, p.y - 190 + r * 38), Vector2(p.x + 160, p.y - 190 + r * 38),
			Color(0.72, 0.75, 0.80, 0.30), 2)
	# the hoop itself
	draw_line(Vector2(p.x + 96, p.y - 40), Vector2(p.x + 96, p.y - 196), Color(0.30, 0.31, 0.35), 8)
	draw_rect(Rect2(p.x + 52, p.y - 250, 92, 62), Color(0.92, 0.92, 0.95, 0.92))
	draw_rect(Rect2(p.x + 78, p.y - 224, 40, 30), Color(0.85, 0.35, 0.25), false, 3)
	draw_line(Vector2(p.x + 76, p.y - 188), Vector2(p.x + 122, p.y - 188), Color(0.95, 0.45, 0.15), 5)
	HoopArt.draw_net(self, Vector2(p.x + 99, p.y - 186), 23.0, 0.0, 0.0, 34.0)
	# a covered court gets a canopy
	if roofed:
		draw_colored_polygon(PackedVector2Array([
			Vector2(p.x - 190, p.y - 262), Vector2(p.x + 190, p.y - 262),
			Vector2(p.x + 150, p.y - 316), Vector2(p.x - 150, p.y - 316)]),
			Color(0.32, 0.40, 0.46).lerp(Color(0.12, 0.15, 0.20), night))
		for sx in [-1.0, 1.0]:
			draw_line(Vector2(p.x + sx * 172, p.y - 262), Vector2(p.x + sx * 172, p.y + 140),
				Color(0.30, 0.32, 0.36), 7)
