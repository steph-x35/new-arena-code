extends Node2D
## HOW TO PLAY — the screen a FIRST-TIMER lands on from the menu. Left: the
## whole game in short sections (what baskin is, the court, the roles, the
## points, the key rules, the controls). Right: a top-down vector diagram of
## the adapted court with the five sectors of a side area, so the geometry is
## SEEN, not just read. Everything is localised (Loc) and procedural.

@onready var root: Control = $UI/Root

const SEC_COL := Color(1.0, 0.84, 0.40)     # section titles
const TXT_COL := Color(0.93, 0.94, 0.97)    # body text

func _ready() -> void:
	RenderingServer.set_default_clear_color(Art.INK)
	var bg := ColorRect.new()
	bg.color = Color(0.078, 0.086, 0.110)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -2
	root.add_child(bg)
	# faint court motif behind everything
	var motif := Control.new()
	motif.set_anchors_preset(Control.PRESET_FULL_RECT)
	motif.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motif.draw.connect(_draw_motif.bind(motif))
	motif.z_index = -1
	root.add_child(motif)

	var title := Label.new()
	title.text = Loc.t("guide.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	title.position = Vector2(0, 30)
	title.size = Vector2(1280, 74)
	root.add_child(title)
	var sub := Label.new()
	sub.text = Loc.t("guide.sub")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 21)
	sub.modulate = Color(1, 1, 1, 0.7)
	sub.position = Vector2(0, 100)
	sub.size = Vector2(1280, 30)
	root.add_child(sub)

	# ---- left: the guide, scrollable (it is long by design) ----------------
	var v := UIKit.column(root, Vector2(56, 150), 600)
	_section(v, "guide.what_h")
	_body(v, "guide.what")
	_section(v, "guide.court_h")
	_body(v, "guide.court")
	_section(v, "guide.roles_h")
	for r in [1, 2, 3, 4, 5]:
		_role_row(v, r)
	_section(v, "guide.points_h")
	_body(v, "guide.points")
	_section(v, "guide.keys_h")
	_body(v, "guide.keys")
	_section(v, "guide.controls_h")
	_body(v, "guide.controls")

	# ---- right: the court diagram + caption + actions ----------------------
	var diagram := Control.new()
	diagram.position = Vector2(700, 168)
	diagram.size = Vector2(520, 350)
	diagram.draw.connect(_draw_court.bind(diagram))
	root.add_child(diagram)
	var cap := Label.new()
	cap.text = Loc.t("guide.diagram")
	cap.add_theme_font_size_override("font_size", 18)
	cap.modulate = Color(1, 1, 1, 0.75)
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.position = Vector2(700, 524)
	cap.size = Vector2(520, 56)
	root.add_child(cap)

	var play := UIKit.menu_button(root, Loc.t("rolepick.go"),
		func(): SceneRouter.goto("res://src/scenes/KitPicker.tscn"), "primary", 300)
	play.position = Vector2(700, 600)
	var back := UIKit.menu_button(root, Loc.t("common.back"),
		func(): SceneRouter.goto(SceneRouter.MENU), "ghost", 200)
	back.position = Vector2(1020, 600)

func _section(v: VBoxContainer, key: String) -> void:
	var l := Label.new()
	l.text = Loc.t(key)
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", SEC_COL)
	v.add_child(l)

func _body(v: VBoxContainer, key: String) -> void:
	var l := Label.new()
	l.text = Loc.t(key)
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", TXT_COL)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(580, 0)
	v.add_child(l)

func _role_row(v: VBoxContainer, r: int) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	var num := Label.new()
	num.text = Loc.t("role.%d" % r)
	num.add_theme_font_size_override("font_size", 18)
	num.add_theme_color_override("font_color", SEC_COL)
	num.custom_minimum_size = Vector2(150, 0)
	h.add_child(num)
	var d := Label.new()
	d.text = Loc.t("role.%d.d" % r)
	d.add_theme_font_size_override("font_size", 16)
	d.add_theme_color_override("font_color", TXT_COL)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.custom_minimum_size = Vector2(410, 0)
	h.add_child(d)

# ------------------------------------------------------------- the diagram
## Top-down adapted court, drawn on the `d` control. Same layout as the match
## floor: the two side poles sit at half court on the long sidelines, each
## carrying the HIGH (2.20 m) and LOW (1.20 m) hoop; the 3 m semicircle is
## split into the five regulation sectors with the spot values painted on.
func _draw_court(d: Control) -> void:
	var wood := Rect2(20, 40, 480, 260)
	d.draw_rect(wood, Color(0.72, 0.53, 0.33))
	for i in 12:
		var y := 40 + i * 21.7
		d.draw_line(Vector2(20, y), Vector2(500, y), Color(0.66, 0.47, 0.28, 0.5), 1.0)
	var line := Color(0.97, 0.97, 0.95, 0.9)
	# border + mid line + centre circle
	d.draw_rect(wood, line, 2.5, false)
	d.draw_line(Vector2(260, 40), Vector2(260, 300), line, 2.0)
	d.draw_arc(Vector2(260, 170), 24, 0, TAU, 32, line, 2.0)
	# traditional hoops, both short ends
	d.draw_line(Vector2(46, 130), Vector2(46, 210), line, 4.0)
	d.draw_arc(Vector2(56, 170), 11, 0, TAU, 24, Color(1.0, 0.45, 0.15), 3.0)
	d.draw_arc(Vector2(56, 170), 44, -PI * 0.5, PI * 0.5, 24, line, 1.5)
	d.draw_line(Vector2(454, 130), Vector2(454, 210), line, 4.0)
	d.draw_arc(Vector2(464, 170), 11, 0, TAU, 24, Color(1.0, 0.45, 0.15), 3.0)
	d.draw_arc(Vector2(464, 170), 44, PI * 0.5, PI * 1.5, 24, line, 1.5)
	# the two side areas at half court
	for sy in [-1.0, 1.0]:
		var hc := Vector2(260.0, 40.0 if sy < 0.0 else 300.0)
		var a0 := 0.0 if sy < 0.0 else PI
		var r := 54.0
		d.draw_arc(hc, r, a0, a0 + PI, 40, line, 2.5)
		# dashed 3.70 m arc (the 2R / role-3 free-throw line)
		for i in 12:
			d.draw_arc(hc, 66.0, a0 + i * (PI / 12.0) + 0.05,
				a0 + (i + 1) * (PI / 12.0) - 0.05, 3, Color(0.97, 0.97, 0.95, 0.7), 1.6)
		# five sectors: 200/150/70/150/200 cm of the 770 cm semicircle
		for cm in [200.0, 350.0, 420.0, 570.0]:
			var sa: float = a0 + (cm / 770.0) * PI
			d.draw_line(hc + Vector2(cos(sa), sin(sa)) * 8.0,
				hc + Vector2(cos(sa), sin(sa)) * r, line, 1.4)
		# spot values: 2 straight ahead, 3 on the sides
		var in_dir := Vector2(0.0, -sy)
		var f := ThemeDB.fallback_font
		for sd in [[0.0, "2", 33.0], [0.45, "3", 37.0], [-0.45, "3", 37.0],
				[1.16, "3", 30.0], [-1.16, "3", 30.0]]:
			var sp: Vector2 = hc + in_dir.rotated(sd[0]) * sd[2]
			d.draw_string(f, sp + Vector2(-14, -6), str(sd[1]),
				HORIZONTAL_ALIGNMENT_CENTER, 28, 24, Color(0.25, 0.15, 0.05, 0.85))
		# the double hoop on the pole: HIGH rim + LOW rim, facing the court
		d.draw_rect(Rect2(hc - Vector2(3, 3), Vector2(6, 6)), Color(0.2, 0.2, 0.24))
		d.draw_arc(hc + in_dir * 14.0, 9.0, 0, TAU, 20, Color(1.0, 0.45, 0.15), 2.6)
		d.draw_arc(hc + in_dir * 26.0, 5.5, 0, TAU, 16, Color(1.0, 0.62, 0.25), 2.2)
	# legend chips under the court
	d.draw_arc(Vector2(34, 336), 6, 0, TAU, 16, Color(1.0, 0.45, 0.15), 2.4)
	d.draw_string(ThemeDB.fallback_font, Vector2(46, 342), "2.20 m",
		HORIZONTAL_ALIGNMENT_LEFT, 80, 15, Color(1, 1, 1, 0.75))
	d.draw_arc(Vector2(126, 336), 4, 0, TAU, 16, Color(1.0, 0.62, 0.25), 2.2)
	d.draw_string(ThemeDB.fallback_font, Vector2(138, 342), "1.20 m",
		HORIZONTAL_ALIGNMENT_LEFT, 80, 15, Color(1, 1, 1, 0.75))

func _draw_motif(m: Control) -> void:
	# a giant faint centre circle, same idea as the main menu
	var sz := m.size
	m.draw_arc(Vector2(sz.x * 0.5, sz.y * 1.55), 560, 0, TAU, 64,
		Color(0.949, 0.420, 0.114, 0.07), 3.0)
