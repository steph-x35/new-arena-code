extends Node2D
## IRON GYM -- now a real room you look at and touch, exactly like the home.
## The weight machines and cardio gear are drawn on the wall/floor and each one
## is a clickable hotspot with its own panel. The basketball court-work drills
## moved to the Team Court, where the court actually is.

const W := 1600.0
const H := 900.0
const FLOOR_Y := 702.0   # everything standing must land exactly here

# Single source of truth for machine placement. Art and hotspots both read it.
const R_BENCH  := Rect2(80, 402, 210, 300)
const R_SQUAT  := Rect2(320, 372, 200, 330)
const R_CLEAN  := Rect2(560, 500, 220, 202)
const R_DEAD   := Rect2(820, 500, 220, 202)
const R_BOX    := Rect2(1080, 500, 170, 202)
const R_MED    := Rect2(1290, 520, 210, 182)
const R_BIKE   := Rect2(160, 626, 210, 112)
const R_TREAD  := Rect2(440, 626, 260, 112)
const R_WINDOW := Rect2(700, 120, 300, 200)
const R_SIGN   := Rect2(40, 180, 230, 170)     # "TEAM COURT" sign
const R_DOOR   := Rect2(1500, 300, 100, 300)

# Court-work basketball exercises live at the Team Court now; the gym keeps
# the weights and cardio only.
const LIFTS := [
	{"lift": "bench",       "name": "Bench Press",  "sub": "Rebound / block / close / stamina", "cost": 22, "rect": R_BENCH},
	{"lift": "squat",       "name": "Back Squat",   "sub": "Heavier bar, tighter timing",       "cost": 22, "rect": R_SQUAT},
	{"lift": "power_clean", "name": "Power Clean",  "sub": "Explosive - the hardest tempo",     "cost": 22, "rect": R_CLEAN},
	{"lift": "deadlift",    "name": "Deadlift",     "sub": "A heavy pull off the floor",        "cost": 22, "rect": R_DEAD},
	{"lift": "box_jump",    "name": "Box Jump",     "sub": "Plyo: explode onto the box",        "cost": 24, "rect": R_BOX},
	{"lift": "med_slam",    "name": "Med Ball Slam","sub": "Plyo: explosive ball slam",         "cost": 24, "rect": R_MED},
]

const CARDIO := [
	{"machine": "bike",      "name": "Exercise Bike", "sub": "Hold a cadence - stamina / speed", "cost": 18, "rect": R_BIKE},
	{"machine": "treadmill", "name": "Treadmill",     "sub": "Match the pace changes - stamina / accel", "cost": 18, "rect": R_TREAD},
]

var ui_layer: CanvasLayer
var spot_layer: CanvasLayer
var hotspots: Control
var anim_t := 0.0

func _ready() -> void:
	Game.profile["last_building"] = "gym"
	Sfx.stop_music()   # solo/1v1 courts: squeaks, swish and bounces only
	_build_room_ui()
	Events.toast.emit(Loc.tx("Welcome to Iron Gym"))
	set_process(true)

func _process(delta: float) -> void:
	anim_t += delta
	queue_redraw()

# ---------------------------------------------------------------- UI + hotspots
func _build_room_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 2
	add_child(ui_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)
	RenderingServer.set_default_clear_color(Color(0.16, 0.18, 0.22))

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

	for d in LIFTS:
		_spot(d["rect"], String(d["name"]), func(dd = d): _open_station(dd))
	for cme in CARDIO:
		_spot(cme["rect"], String(cme["name"]), func(cc = cme): _open_station(cc))
	# The basketball side of training is a sign pointing at the Team Court.
	_spot(R_SIGN, "Team Court", func(): SceneRouter.goto("res://src/scenes/TeamCourt.tscn"))
	_spot(R_DOOR, "Exit", func(): SceneRouter.goto("res://src/scenes/CityScene.tscn"))


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

func _panel(title: String, sz := Vector2(900, 760)) -> GamePanel:
	var p := GamePanel.new().build(title, sz)
	ui_layer.add_child(p)
	_set_spots_active(false)
	p.tree_exited.connect(func(): _set_spots_active(true))
	return p

func _set_spots_active(on: bool) -> void:
	if hotspots == null:
		return
	for h in hotspots.get_children():
		if h is Hotspot:
			h.enabled = on
			h.hovered = false
			h.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
			h.queue_redraw()

# ---------------------------------------------------------------- stations
func _open_station(d: Dictionary) -> void:
	var kind := String(d.get("lift", d.get("machine", "")))
	var title: String = "%s" % String(d["name"])
	var p := _panel(title)
	var cost: int = int(d["cost"])
	var e: float = float(Game.profile["energy"])
	p.add_text(String(d["sub"]), 22, Color(0.7, 0.9, 1.0))
	p.add_text("Energy  %d/100   ·   cost %d" % [int(e), cost], 20, Color(1, 1, 1, 0.7))
	p.add_text("", 12)
	p.add_text("A good session grows the attributes this lift feeds.", 19, Color(1, 1, 1, 0.5))
	p.add_text("", 12)
	p.add_button(Loc.tx("💪  START  (-%d energy)") % cost, func():
		_start(d, p), true)
	p.add_button(Loc.tx("Back"), func(): p.close())

func _start(d: Dictionary, p: GamePanel = null) -> void:
	var cost: int = int(d["cost"])
	if Game.profile["energy"] < float(cost):
		Events.toast.emit(Loc.tx("Too tired. Eat or sleep first."))
		return
	if p: p.close()
	# Change scene — overlaying DrillScene on a hidden gym left Android on
	# the default grey clear-color (no current camera). A real scene change
	# keeps Camera2D current and always paints a floor.
	Game.profile["pending_drill"] = {
		# Identificativi PIANI per il motore: DrillScene non deve mai ricevere
		# la stringa tradotta ("pesi") o l'esercizio diventa un fermo immagine.
		"kind": "weights" if d.has("lift") else "cardio",
		"lift": String(d.get("lift", "bench")),
		"machine": String(d.get("machine", "bike")),
		"return": "res://src/scenes/GymScene.tscn",
	}
	SceneRouter.goto("res://src/scenes/DrillScene.tscn")

## Show / hide the whole room, CanvasLayers included, so a running drill is
## never drawn over by the gym menu.
func _set_room_visible(on: bool) -> void:
	visible = on
	if ui_layer != null:
		ui_layer.visible = on
	if spot_layer != null:
		spot_layer.visible = on
	_set_spots_active(on)

# ---------------------------------------------------------------- drawing
func _draw() -> void:
	# walls & rubber floor
	draw_rect(Rect2(0, 0, W, FLOOR_Y), Color(0.30, 0.34, 0.42))
	draw_rect(Rect2(0, FLOOR_Y, W, H - FLOOR_Y), Color(0.16, 0.18, 0.22))
	for i in 22:
		var x := i * 76.0
		draw_line(Vector2(x, FLOOR_Y), Vector2(x - 50, H), Color(0, 0, 0, 0.10), 2)
	draw_rect(Rect2(0, FLOOR_Y - 16, W, 16), Color(0.22, 0.25, 0.32))
	draw_line(Vector2(0, FLOOR_Y), Vector2(W, FLOOR_Y), Color(0, 0, 0, 0.35), 3)

	# mirror wall strip behind the stations
	draw_rect(Rect2(40, 180, 1400, 150), Color(0.55, 0.68, 0.80, 0.18))
	draw_rect(Rect2(40, 180, 1400, 150), Color(0.8, 0.9, 1.0, 0.22), false, 4)

	_draw_window()
	_draw_sign()
	_draw_door()
	_draw_bench()
	_draw_squat()
	_draw_platform(R_CLEAN, "CLEAN")
	_draw_platform(R_DEAD, "DEADLIFT")
	_draw_box()
	_draw_med()
	_draw_bike()
	_draw_treadmill()

func _bar(c: Vector2, w: float, col := Color(0.35, 0.35, 0.38)) -> void:
	draw_rect(Rect2(c.x - w * 0.5, c.y - 7, w, 14), col, true)
	draw_circle(c + Vector2(-w * 0.5, 0), 9, Color(0.15, 0.15, 0.18))
	draw_circle(c + Vector2(w * 0.5, 0), 9, Color(0.15, 0.15, 0.18))

func _draw_bench() -> void:
	var r := R_BENCH
	# uprights + barbell
	draw_rect(Rect2(r.position.x + 20, r.position.y + 30, 16, 120), Color(0.14, 0.15, 0.18))
	draw_rect(Rect2(r.end.x - 36, r.position.y + 30, 16, 120), Color(0.14, 0.15, 0.18))
	_bar(Vector2(r.get_center().x, r.position.y + 60), r.size.x - 40)
	# the bench itself
	draw_rect(Rect2(r.position.x + 60, r.position.y + 150, 90, 26), Color(0.85, 0.24, 0.22), true)
	draw_rect(Rect2(r.position.x + 45, r.position.y + 176, 8, 60), Color(0.13, 0.14, 0.16))
	draw_rect(Rect2(r.position.x + 157, r.position.y + 176, 8, 60), Color(0.13, 0.14, 0.16))

func _draw_squat() -> void:
	var r := R_SQUAT
	for xo in [30.0, r.size.x - 46.0]:
		draw_rect(Rect2(r.position.x + xo, r.position.y + 20, 16, 200), Color(0.14, 0.15, 0.18))
	_bar(Vector2(r.get_center().x, r.position.y + 46), r.size.x - 40)
	# safety rails
	draw_rect(Rect2(r.position.x + 14, r.position.y + 150, r.size.x - 28, 8), Color(0.30, 0.32, 0.36))

func _draw_platform(r: Rect2, label: String) -> void:
	draw_rect(r, Color(0.11, 0.12, 0.14), true)
	draw_rect(r, Color(0.35, 0.38, 0.44), false, 3)
	_bar(Vector2(r.get_center().x, r.position.y + 40), r.size.x - 60)
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(r.position.x + 16, r.position.y + 110), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.86, 0.4))

func _draw_box() -> void:
	var r := R_BOX
	var w := 150.0
	for i in 3:
		var y := r.end.y - 36.0 - i * 34.0
		var b := Rect2(r.get_center().x - w * 0.5 + i * 8.0, y, w, 34)
		draw_rect(b, Color(0.72, 0.38, 0.22).darkened(i * 0.08), true)
		draw_rect(b, Color(0.4, 0.2, 0.12), false, 2)

func _draw_med() -> void:
	var r := R_MED
	for i in 3:
		var c := Vector2(r.position.x + 40 + i * 62.0, r.end.y - 40.0)
		draw_circle(c, 30, Color(0.16, 0.18, 0.24).lerp(Color(0.35, 0.3, 0.4), i * 0.3))
		draw_arc(c, 30, 0, TAU, 18, Color(0, 0, 0, 0.25), 2)

func _draw_bike() -> void:
	var r := R_BIKE
	var c := Vector2(r.get_center().x, r.end.y - 34.0)
	draw_circle(c + Vector2(-46, 0), 34, Color(0.1, 0.1, 0.12), false, 5)
	draw_line(c + Vector2(-46, 0), c + Vector2(0, -40), Color(0.85, 0.85, 0.9), 5)
	draw_line(c + Vector2(0, -40), c + Vector2(34, -18), Color(0.85, 0.85, 0.9), 5)
	draw_line(c + Vector2(34, -18), c + Vector2(40, 0), Color(0.85, 0.85, 0.9), 5)
	draw_rect(Rect2(c.x - 24, c.y - 52, 40, 18), Color(0.2, 0.22, 0.26))
	draw_line(c + Vector2(40, 0), c + Vector2(46, 0), Color(0.1, 0.1, 0.12), 6)

func _draw_treadmill() -> void:
	var r := R_TREAD
	draw_rect(Rect2(r.position.x + 30, r.position.y + 30, r.size.x - 60, 14), Color(0.85, 0.85, 0.9), true)
	draw_rect(Rect2(r.position.x + 46, r.position.y + 60, 10, 66), Color(0.15, 0.16, 0.18))
	draw_rect(Rect2(r.end.x - 56, r.position.y + 60, 10, 66), Color(0.15, 0.16, 0.18))
	# deck and belt
	draw_rect(Rect2(r.position.x + 26, r.position.y + 76, r.size.x - 52, 22), Color(0.1, 0.1, 0.12), true)
	draw_rect(Rect2(r.position.x + 26, r.position.y + 76, r.size.x - 52, 22), Color(0.3, 0.32, 0.36), false, 2)

func _draw_window() -> void:
	var r := R_WINDOW
	draw_rect(r, Color(0.45, 0.62, 0.78), true)
	draw_rect(r, Color(0.9, 0.95, 1.0, 0.5), false, 6)
	draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color(0.9, 0.95, 1.0, 0.5), 5)
	draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color(0.9, 0.95, 1.0, 0.5), 5)

func _draw_sign() -> void:
	var r := R_SIGN
	draw_rect(r, Color(0.10, 0.12, 0.16), true)
	draw_rect(r, Color(1, 0.86, 0.4), false, 4)
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(r.position.x + 26, r.position.y + 56), "TEAM",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 0.9, 0.5))
	draw_string(f, Vector2(r.position.x + 26, r.position.y + 108), "COURT",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 0.9, 0.5))
	draw_string(f, Vector2(r.position.x + 26, r.position.y + 148), "court work ->",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.6))

func _draw_door() -> void:
	var r := R_DOOR
	draw_rect(r, Color(0.42, 0.30, 0.18), true)
	draw_rect(r, Color(0.25, 0.17, 0.09), false, 4)
	draw_circle(Vector2(r.position.x + 22, r.get_center().y), 7, Color(0.9, 0.8, 0.4))
