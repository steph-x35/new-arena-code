extends Node2D
## Title screen (v1.19 restyle): BASKIN ACADEMY over a night arena — skyline,
## drifting embers and, as the hero art, the DOUBLE side basket (high 2.20 m +
## low 1.20 m on the same pole) that makes a baskin court a baskin court.
## PLAY is the one big orange action; HOW TO PLAY and SETTINGS stay quiet
## beside it, so a first-timer knows exactly what to press first.

@onready var root: Control = $UI/Root

var bg: Node2D
var buildings := []
var motes := []
var title_l: Label
var under: ColorRect
var hero_t := 0.0
var vw := 1280.0                 # larghezza VERA del viewport (tablet/phone)

func _ready() -> void:
	RenderingServer.set_default_clear_color(Art.INK)
	Sfx.play_life()
	var vs: Vector2 = root.get_viewport_rect().size
	vw = maxf(vs.x, 1280.0)
	var dx := UIKit.center_dx(root)

	bg = Node2D.new()
	bg.z_index = -5
	bg.draw.connect(_draw_bg)
	root.add_child(bg)

	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var x := -40.0
	while x < vw + 60.0:
		var w := rng.randf_range(70.0, 150.0)
		var h := rng.randf_range(120.0, 300.0)
		var wins := []
		for i in int(w / 22.0) * int(h / 26.0):
			if rng.randf() < 0.30:
				wins.append([rng.randf_range(6, w - 10), rng.randf_range(8, h - 12),
					rng.randf_range(0.22, 0.55)])
		buildings.append({"x": x, "w": w, "h": h, "wins": wins})
		x += w + rng.randf_range(6.0, 26.0)
	for i in 26:
		motes.append({"p": Vector2(rng.randf_range(0, vw), rng.randf_range(0, 720)),
			"v": rng.randf_range(6.0, 22.0), "r": rng.randf_range(1.5, 3.5),
			"a": rng.randf_range(0.10, 0.35)})

	hero_t = 0.0
	get_tree().process_frame.connect(func():
		hero_t += 1.0 / 60.0
		var d := 1.0 / 60.0
		for m in motes:
			m["p"].y -= m["v"] * d
			if m["p"].y < -6.0:
				m["p"].y = 726.0
				m["p"].x = randf_range(0, vw)
		bg.queue_redraw()
		if under != null:
			var k: float = 0.5 + 0.5 * sin(hero_t * 1.6)
			under.modulate.a = 0.55 + 0.45 * k
			under.size.x = 420.0 + 60.0 * k
			under.position.x = (vw - under.size.x) * 0.5)

	# --- the brand, big on top
	title_l = Label.new()
	title_l.text = "BASKIN ACADEMY"
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_l.add_theme_font_size_override("font_size", 96)
	title_l.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	title_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	title_l.add_theme_constant_override("shadow_offset_x", 4)
	title_l.add_theme_constant_override("shadow_offset_y", 5)
	title_l.position = Vector2(dx, 64)
	title_l.size = Vector2(1280, 120)
	root.add_child(title_l)
	under = ColorRect.new()
	under.color = Color(0.949, 0.42, 0.11)
	under.position = Vector2(430, 196)
	under.size = Vector2(420, 6)
	root.add_child(under)
	var tag := Label.new()
	tag.text = Loc.t("tagline")
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 22)
	tag.add_theme_color_override("font_color", Color(0.82, 0.82, 0.86))
	tag.position = Vector2(dx, 214)
	tag.size = Vector2(1280, 34)
	root.add_child(tag)

	# --- one big action, two quiet ones
	var play := UIKit.menu_button(root, Loc.t("menu.play"),
		func(): SceneRouter.goto("res://src/scenes/KitPicker.tscn"), "primary", 520)
	play.position = Vector2(380.0 + dx, 316)
	var how := UIKit.menu_button(root, Loc.t("menu.how"),
		func(): SceneRouter.goto("res://src/scenes/RulesScene.tscn"), "ghost", 250)
	how.position = Vector2(380.0 + dx, 428)
	var cfg := UIKit.menu_button(root, Loc.t("menu.settings"),
		func(): SceneRouter.goto("res://src/scenes/SettingsScene.tscn"), "ghost", 250)
	cfg.position = Vector2(650.0 + dx, 428)
	var ver := Label.new()
	ver.text = "v%s" % Game.VERSION
	ver.add_theme_font_size_override("font_size", 16)
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	root.add_child(ver)
	ver.position = Vector2(24, 688)

func _draw_bg() -> void:
	# REAL viewport size: on tablets/tall phones the canvas is wider/ taller
	# than the 1280x720 design -- the backdrop must cover it all or a dark
	# stripe shows on the right (the playtest bug).
	var vs: Vector2 = root.get_viewport_rect().size
	var w := maxf(vs.x, 1280.0)
	var h := maxf(vs.y, 720.0)
	# vertical gradient: ink at the top, warmer charcoal at the horizon
	for i in 24:
		var k := float(i) / 24.0
		bg.draw_rect(Rect2(0, k * h, w, h / 24.0 + 1.0),
			Art.INK.lerp(Color(0.16, 0.12, 0.10), k * 0.8))
	# court-line motif: a giant faint centre circle behind the title
	bg.draw_arc(Vector2(w * 0.5, h * 1.25), 560, 0, TAU, 64, Color(0.949, 0.420, 0.114, 0.10), 3.0)
	bg.draw_arc(Vector2(w * 0.5, h * 1.25), 400, 0, TAU, 64, Color(0.949, 0.420, 0.114, 0.07), 2.0)
	# skyline silhouette with lit windows
	for b in buildings:
		var top := h - float(b["h"])
		bg.draw_rect(Rect2(b["x"], top, b["w"], b["h"]), Color(0.045, 0.050, 0.068))
		for w in b["wins"]:
			bg.draw_rect(Rect2(b["x"] + w[0], top + w[1], 6, 8),
				Color(0.98, 0.78, 0.26, w[2]))
	# drifting embers
	for m in motes:
		bg.draw_circle(m["p"], m["r"], Color(0.949, 0.420, 0.114, m["a"]))
	_draw_hero_hoop()

## The baskin signature as hero art: one pole, TWO baskets — 2.20 m and
## 1.20 m — in spotlight, right of the buttons. Scale: 90 px = 1 m, floor
## line at y = 700 (the same proportions the match draws, so what a player
## sees here is what he gets on the court).
func _draw_hero_hoop() -> void:
	var vs: Vector2 = root.get_viewport_rect().size
	var px := maxf(vs.x, 1280.0) - 112.0
	var floor_y := maxf(vs.y, 720.0) - 20.0
	var steel := Color(0.16, 0.17, 0.21)
	# spotlight cone over the whole assembly
	bg.draw_colored_polygon(PackedVector2Array([
		Vector2(px - 122.0, 0), Vector2(px + 128.0, 0),
		Vector2(px + 76.0, floor_y), Vector2(px - 80.0, floor_y)]),
		Color(1.0, 0.82, 0.55, 0.05))
	# floor line + shadow
	bg.draw_line(Vector2(px - 168.0, floor_y), Vector2(px + 108.0, floor_y),
		Color(0.949, 0.420, 0.114, 0.28), 3.0)
	# soft shadow at the base of the pole: a flattened ellipse as a polygon
	# (CanvasItem has no draw_ellipse in 4.3)
	var shadow := PackedVector2Array()
	for i in 20:
		var sa: float = TAU * float(i) / 20.0
		shadow.append(Vector2(px + cos(sa) * 60.0, floor_y - 7.0 + sin(sa) * 6.0))
	bg.draw_colored_polygon(shadow, Color(0, 0, 0, 0.30))
	# pole + base
	bg.draw_rect(Rect2(px - 5.0, 248.0, 10.0, floor_y - 240.0), steel)
	bg.draw_rect(Rect2(px - 16.0, floor_y - 8.0, 32.0, 8.0), Color(0.12, 0.13, 0.16))
	# the two hoops: HIGH first (2.20 m at 90 px/m), then LOW (1.20 m)
	var f := ThemeDB.fallback_font
	for hy: float in [502.0, 592.0]:
		var big := hy < 550.0
		var board_x := px - (64.0 if big else 50.0)
		var bh := 30.0 if big else 22.0
		# arm from the pole to the little board
		bg.draw_rect(Rect2(board_x, hy - 2.0, px - board_x, 4.0), steel)
		# transparent mini board with an orange target square
		bg.draw_rect(Rect2(board_x - 5.0, hy - bh * 0.55, 5.0, bh),
			Color(0.75, 0.80, 0.86, 0.92))
		# rim: a bar sticking out toward the court, side view
		var rw := 30.0 if big else 21.0
		bg.draw_line(Vector2(board_x - 5.0, hy + 4.0),
			Vector2(board_x - 5.0 - rw, hy + 4.0), Art.ORANGE, 3.5)
		# short net
		var ny := hy + 5.0
		var nend := ny + (24.0 if big else 16.0)
		bg.draw_colored_polygon(PackedVector2Array([
			Vector2(board_x - 5.0 - rw, ny), Vector2(board_x - 5.0, ny),
			Vector2(board_x - 5.0 - rw * 0.25, nend),
			Vector2(board_x - 5.0 - rw * 0.75, nend)]),
			Color(0.95, 0.95, 0.92, 0.15))
		# regulation height tag next to each rim
		bg.draw_string(f, Vector2(board_x + 10.0, hy + 8.0),
			"2.20 m" if big else "1.20 m",
			HORIZONTAL_ALIGNMENT_LEFT, 90, 17, Color(1.0, 0.84, 0.40, 0.85))
	# a ball resting on the floor beside the low hoop
	bg.draw_circle(Vector2(px - 122.0, floor_y - 9.0), 9.0, Color(0.85, 0.47, 0.16))
	bg.draw_arc(Vector2(px - 122.0, floor_y - 9.0), 9.0, -PI * 0.18, PI * 0.18, 12,
		Color(0.45, 0.20, 0.05, 0.8), 1.5)
