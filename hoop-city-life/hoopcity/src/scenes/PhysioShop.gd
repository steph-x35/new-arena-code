extends Node2D
## Rehab Lab as a real room: tap the table, ice bath, or the shop shelf.

const W := 1600.0
const H := 900.0
const FLOOR_Y := 702.0

const R_TABLE := Rect2(80, 380, 420, 322)
const R_ICE := Rect2(560, 430, 340, 272)
const R_SHELF := Rect2(960, 240, 520, 462)
const R_DOOR := Rect2(1480, 300, 100, 400)

var ui_layer: CanvasLayer
var spot_layer: CanvasLayer
var hotspots: Control
var night := 0.0

const TREATMENTS := [
	{"id": "ice", "name": "Ice bath", "price": 22, "health": 5, "energy": 4,
		"buff": ["stamina", 1.04, 180], "desc": "Cold plunge. +5 health."},
	{"id": "massage", "name": "Sports massage", "price": 38, "health": 5, "energy": 6,
		"buff": ["all", 1.05, 240], "desc": "Soft-tissue work. +5 health."},
	{"id": "tape", "name": "Ankle tape", "price": 18, "health": 3, "energy": 0,
		"buff": ["accel", 1.06, 360], "desc": "Taped and locked. +3 health."},
	{"id": "stretch", "name": "Mobility session", "price": 16, "health": 4, "energy": 3,
		"buff": ["speed", 1.04, 200], "desc": "Hips and back. +4 health."},
]

const GEAR := [
	{"id": "knee_sleeve", "name": "Knee sleeve", "price": 55,
		"desc": "Extra bounce on the glass.", "buff": ["rebound", 1.06, 720]},
	{"id": "ankle_brace", "name": "Ankle brace", "price": 48,
		"desc": "Cleaner landings.", "buff": ["accel", 1.05, 720]},
	{"id": "wrist_tape", "name": "Wrist wrap", "price": 28,
		"desc": "Steadier midrange.", "buff": ["mid", 1.05, 480]},
	{"id": "compression", "name": "Compression tights", "price": 62,
		"desc": "Legs hold up late.", "buff": ["stamina", 1.08, 600]},
]

func _ready() -> void:
	Game.profile["last_building"] = "physio"
	RenderingServer.set_default_clear_color(Color(0.78, 0.82, 0.84))
	_build_ui()
	get_viewport().size_changed.connect(_fit)
	_fit()
	set_process(true)

func _process(delta: float) -> void:
	night = lerpf(night, 0.0 if Game.day_t() > 0.28 and Game.day_t() < 0.78 else 0.55, 2.0 * delta)
	queue_redraw()

func _fit() -> void:
	var vp := get_viewport_rect().size
	var s: float = minf(vp.x / W, vp.y / H)
	scale = Vector2(s, s)
	position = (vp - Vector2(W, H) * s) * 0.5
	if spot_layer:
		spot_layer.transform = Transform2D(0.0, Vector2.ONE * s, 0.0, position)

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 2
	add_child(ui_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)
	root.add_child(preload("res://src/ui/StatusBar.tscn").instantiate())

	spot_layer = CanvasLayer.new()
	spot_layer.layer = 1
	add_child(spot_layer)
	hotspots = Control.new()
	hotspots.position = Vector2.ZERO
	hotspots.size = Vector2(W, H)
	hotspots.custom_minimum_size = Vector2(W, H)
	hotspots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spot_layer.add_child(hotspots)
	_fit_room()
	call_deferred("_fit_room")
	var _fv: Viewport = get_viewport()
	if _fv != null and not _fv.size_changed.is_connected(_fit_room):
		_fv.size_changed.connect(_fit_room)
	_spot(R_TABLE, "Table", _open_table)
	_spot(R_ICE, "Ice bath", _open_ice)
	_spot(R_SHELF, "Shop shelf", _open_shelf)

	var leave := Button.new()
	leave.text = Loc.tx("GO OUTSIDE")
	leave.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	leave.position = Vector2(-320, -120)
	leave.custom_minimum_size = Vector2(280, 84)
	leave.add_theme_font_size_override("font_size", 24)
	leave.pressed.connect(func(): SceneRouter.goto("res://src/scenes/CityScene.tscn"))
	root.add_child(leave)


func _fit_room() -> void:
	## La stanza e' un mondo FISSO 1600x900 disegnato 1:1: su schermi piu'
	## bassi (telefono: 720 logici) il fondo spariva (esercizi tagliati).
	## Fit intero: scala per contenere, centra, e risponde a ogni resize.
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var rec: Rect2 = vp.get_visible_rect()
	if rec.size.x <= 0.0 or rec.size.y <= 0.0:
		return
	var s: float = minf(rec.size.x / W, rec.size.y / H)
	if s <= 0.0:
		return
	scale = Vector2(s, s)
	position = ((rec.size - Vector2(W, H) * s) * 0.5).round()
	# SOLO gli hotspot (world-space): i PANNELLI su ui_layer restano piena
	# schermo (letto/frigo/guardaroba usano gia' lo schermo logico).
	if spot_layer != null:
		spot_layer.transform = Transform2D(0.0, scale, 0.0, position)

func _spot(r: Rect2, label: String, cb: Callable) -> void:
	var h := Hotspot.new().setup(r, label)
	h.activated.connect(cb)
	hotspots.add_child(h)

func _panel(title: String, sz := Vector2(860, 640)) -> GamePanel:
	var p := GamePanel.new().build(title, sz)
	ui_layer.add_child(p)
	return p

func _open_table() -> void:
	var p := _panel("TREATMENT TABLE")
	p.add_text("Lie down. Pick a session.", 22, Color(1, 1, 1, 0.7))
	for t in TREATMENTS:
		if String(t["id"]) == "ice":
			continue
		var title: String = "%s  ·  $%d  ·  ❤+%d" % [t["name"], t["price"], t["health"]]
		p.add_button(title, func():
			_buy_treat(t)
			p.close())
	p.add_button(Loc.tx("Back"), func(): p.close())

func _open_ice() -> void:
	var t: Dictionary = TREATMENTS[0]
	var p := _panel("ICE BATH")
	p.add_text(String(t["desc"]), 22)
	p.add_button(Loc.tx("Plunge  ·  $%d") % int(t["price"]), func():
		_buy_treat(t)
		p.close(), true)
	p.add_button(Loc.tx("Back"), func(): p.close())

const GEAR_PALETTE := ["#e8e8ea", "#23252d", "#c8434c", "#2f63c0", "#3f9e57", "#e5a125"]
const GEAR_DEFAULT_COL := {
	"knee_sleeve": "#3a3d45", "ankle_brace": "#e8e8ea",
	"wrist_tape": "#e8e8ea", "compression": "#23252d"}

func _open_shelf() -> void:
	var p := _panel(Loc.tx("GEAR SHELF"), Vector2(900, 700))
	p.add_text(Loc.tx("Tap a product to buy it. Buffs last on the court."), 20, Color(1, 1, 1, 0.65))
	for g in GEAR:
		var gid: String = String(g["id"])
		var owned: Dictionary = (Game.profile.get("gear", {}) as Dictionary).get(gid, {})
		if owned.is_empty():
			p.add_button("%s  ·  $%d" % [Loc.tx(String(g["name"])), int(g["price"])], func():
				_buy_gear(g)
				p.close())
			continue
		# owned: equip toggle, side (DX/SX) and colour swatches
		var on: bool = bool(owned.get("on", true))
		var side: int = int(owned.get("side", 1))
		var state: String = Loc.tx("EQUIPPED") if on else Loc.tx("OWNED")
		p.add_text("%s  ·  %s" % [Loc.tx(String(g["name"])), state], 21, Color(1, 0.95, 0.7))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		p.body.add_child(row)
		var b_on := Button.new()
		b_on.text = Loc.tx("REMOVE") if on else Loc.tx("EQUIP")
		b_on.custom_minimum_size = Vector2(150, 52)
		b_on.pressed.connect(func():
			_set_gear(gid, {"on": not on})
			p.close()
			_open_shelf())
		row.add_child(b_on)
		if gid != "compression":
			var b_side := Button.new()
			var side_s: String = Loc.tx("DX") if side == 1 else Loc.tx("SX")
			b_side.text = (Loc.tx("ARM: %s") if gid == "wrist_tape" else Loc.tx("LEG: %s")) % side_s
			b_side.custom_minimum_size = Vector2(150, 52)
			b_side.pressed.connect(func():
				_set_gear(gid, {"side": -side})
				p.close()
				_open_shelf())
			row.add_child(b_side)
		for hexc in GEAR_PALETTE:
			var sw := Button.new()
			sw.text = "⬤"
			sw.custom_minimum_size = Vector2(52, 52)
			sw.add_theme_color_override("font_color", Color(hexc))
			sw.add_theme_color_override("font_pressed_color", Color(hexc))
			sw.pressed.connect(func():
				_set_gear(gid, {"col": hexc})
				p.close()
				_open_shelf())
			row.add_child(sw)
	p.add_button(Loc.tx("Back"), func(): p.close())

## Merge one change (on / side / col) into the owned-gear entry and save.
func _set_gear(gid: String, change: Dictionary) -> void:
	var all: Dictionary = Game.profile.get("gear", {})
	var entry: Dictionary = all.get(gid, {})
	for k in change:
		entry[k] = change[k]
	all[gid] = entry
	Game.profile["gear"] = all
	SaveSystem.save_game()

func _buy_treat(t: Dictionary) -> void:
	var price: int = int(t["price"])
	if int(Game.profile["money"]) < price:
		Events.toast.emit(Loc.tx("Not enough money"))
		return
	Game.profile["money"] = int(Game.profile["money"]) - price
	Game.add_health(minf(float(t["health"]), 5.0))
	Game.add_energy(float(t["energy"]))
	var b: Array = t.get("buff", [])
	if b.size() == 3:
		Game.add_buff("physio_" + String(t["id"]), String(b[0]), float(b[1]), int(b[2]))
	Game.advance_time(20)
	SaveSystem.save_game()
	Events.toast.emit("%s  ❤+%d" % [t["name"], int(t["health"])])

func _buy_gear(g: Dictionary) -> void:
	var price: int = int(g["price"])
	if int(Game.profile["money"]) < price:
		Events.toast.emit(Loc.tx("Not enough money"))
		return
	Game.profile["money"] = int(Game.profile["money"]) - price
	var b: Array = g.get("buff", [])
	if b.size() == 3:
		Game.add_buff("gear_" + String(g["id"]), String(b[0]), float(b[1]), int(b[2]))
	# owned forever from here: visible on the body while equipped
	_set_gear(String(g["id"]), {"on": true, "side": 1,
		"col": String(GEAR_DEFAULT_COL.get(String(g["id"]), "#e8e8ea"))})
	Events.toast.emit(Loc.tx("Bought  %s") % Loc.tx(String(g["name"])))

func _draw() -> void:
	var wall := Color(0.86, 0.90, 0.92).lerp(Color(0.28, 0.32, 0.36), night)
	draw_rect(Rect2(0, 0, W, H), wall)
	draw_rect(Rect2(0, FLOOR_Y, W, H - FLOOR_Y), Color(0.72, 0.74, 0.76).lerp(Color(0.22, 0.24, 0.28), night))
	# windows
	draw_rect(Rect2(180, 80, 260, 180), Color(0.55, 0.72, 0.88).lerp(Color(0.18, 0.22, 0.40), night))
	draw_rect(Rect2(480, 80, 260, 180), Color(0.55, 0.72, 0.88).lerp(Color(0.18, 0.22, 0.40), night))
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(40, 50), "REHAB LAB", HORIZONTAL_ALIGNMENT_LEFT, -1, 36,
		Color(0.12, 0.35, 0.40))
	# treatment table
	draw_rect(R_TABLE, Color(0.92, 0.93, 0.95))
	draw_rect(Rect2(R_TABLE.position + Vector2(30, 40), Vector2(360, 90)), Color(0.20, 0.55, 0.58))
	draw_rect(Rect2(R_TABLE.position + Vector2(30, 140), Vector2(360, 140)), Color(0.95, 0.95, 0.97))
	draw_string(f, Vector2(R_TABLE.position.x + 40, R_TABLE.position.y + 30), "TABLE",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.15, 0.25, 0.28))
	# ice bath
	draw_rect(R_ICE, Color(0.55, 0.72, 0.78))
	draw_rect(Rect2(R_ICE.position + Vector2(20, 40), Vector2(300, 180)), Color(0.35, 0.62, 0.72))
	for i in 8:
		draw_circle(R_ICE.position + Vector2(50 + i * 34, 120 + sin(float(i)) * 8), 10.0,
			Color(0.85, 0.95, 1.0, 0.7))
	draw_string(f, Vector2(R_ICE.position.x + 24, R_ICE.position.y + 28), "ICE BATH",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.95, 0.98, 1.0))
	# shop shelf
	draw_rect(R_SHELF, Color(0.62, 0.48, 0.32))
	for row in 4:
		var y: float = R_SHELF.position.y + 40.0 + row * 100.0
		draw_rect(Rect2(R_SHELF.position.x + 16, y, R_SHELF.size.x - 32, 12), Color(0.42, 0.30, 0.18))
		for col in 4:
			var box := Rect2(R_SHELF.position.x + 36 + col * 118, y - 70, 96, 66)
			draw_rect(box, Color(0.35, 0.70, 0.62) if (row + col) % 2 == 0 else Color(0.90, 0.90, 0.92))
	draw_string(f, Vector2(R_SHELF.position.x + 24, R_SHELF.position.y + 28), "SHOP SHELF",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.95, 0.85))
	# door
	draw_rect(R_DOOR, Color(0.30, 0.42, 0.40))
