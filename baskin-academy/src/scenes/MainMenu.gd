extends Node2D
## Title screen: BASKIN ACADEMY big on top, PLAY + SETTINGS, over an animated
## charcoal skyline with drifting embers. Everything procedural.

@onready var root: Control = $UI/Root

var bg: Node2D
var buildings := []
var motes := []
var title_l: Label
var under: ColorRect
var hero_t := 0.0

func _ready() -> void:
	RenderingServer.set_default_clear_color(Art.INK)
	Sfx.play_life()

	bg = Node2D.new()
	bg.z_index = -5
	bg.draw.connect(_draw_bg)
	root.add_child(bg)

	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var x := -40.0
	while x < 1360.0:
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
		motes.append({"p": Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720)),
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
				m["p"].x = randf_range(0, 1280)
		bg.queue_redraw()
		if under != null:
			var k: float = 0.5 + 0.5 * sin(hero_t * 1.6)
			under.modulate.a = 0.55 + 0.45 * k
			under.size.x = 420.0 + 60.0 * k
			under.position.x = (1280.0 - under.size.x) * 0.5)

	# --- the brand, big on top
	title_l = Label.new()
	title_l.text = "BASKIN ACADEMY"
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_l.add_theme_font_size_override("font_size", 96)
	title_l.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	title_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	title_l.add_theme_constant_override("shadow_offset_x", 4)
	title_l.add_theme_constant_override("shadow_offset_y", 5)
	title_l.position = Vector2(0, 64)
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
	tag.position = Vector2(0, 214)
	tag.size = Vector2(1280, 34)
	root.add_child(tag)

	# --- two choices only: play, settings
	var v := UIKit.column(root, Vector2(360, 330), 560)
	UIKit.big_button(v, Loc.t("menu.play"),
		func(): SceneRouter.goto("res://src/scenes/KitPicker.tscn"),
		Loc.t("menu.play.sub"), 560)
	UIKit.big_button(v, Loc.t("menu.settings"),
		func(): SceneRouter.goto("res://src/scenes/SettingsScene.tscn"), "", 560)
	var ver := Label.new()
	ver.text = "v%s" % Game.VERSION
	ver.add_theme_font_size_override("font_size", 16)
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	root.add_child(ver)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-90, -34)

func _draw_bg() -> void:
	# vertical gradient: ink at the top, warmer charcoal at the horizon
	for i in 24:
		var k := float(i) / 24.0
		bg.draw_rect(Rect2(0, k * 720.0, 1280, 32.0),
			Art.INK.lerp(Color(0.16, 0.12, 0.10), k * 0.8))
	# court-line motif: a giant faint centre circle behind the title
	bg.draw_arc(Vector2(640, 900), 560, 0, TAU, 64, Color(0.949, 0.420, 0.114, 0.10), 3.0)
	bg.draw_arc(Vector2(640, 900), 400, 0, TAU, 64, Color(0.949, 0.420, 0.114, 0.07), 2.0)
	# skyline silhouette with lit windows
	for b in buildings:
		var top := 720.0 - float(b["h"])
		bg.draw_rect(Rect2(b["x"], top, b["w"], b["h"]), Color(0.045, 0.050, 0.068))
		for w in b["wins"]:
			bg.draw_rect(Rect2(b["x"] + w[0], top + w[1], 6, 8),
				Color(0.98, 0.78, 0.26, w[2]))
	# drifting embers
	for m in motes:
		bg.draw_circle(m["p"], m["r"], Color(0.949, 0.420, 0.114, m["a"]))
