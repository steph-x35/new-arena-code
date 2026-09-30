extends Node2D
## Title screen, v1.8: the brand lockup (logo on a cream card) over an
## animated charcoal skyline, menu column on the right. Everything
## procedural except the logo texture itself.

@onready var root: Control = $UI/Root

var bg: Node2D
var buildings := []
var motes := []
var logo_tex: Texture2D
var hero: Control
var logo: TextureRect
var logo_shadow: TextureRect
var hero_t := 0.0
var mv_w := 1280.0     # larghezza logica visibile (layout adattivo)
var mv_h := 720.0      # altezza logica visibile
var _menu_col: Control
var _menu_col_w := 560.0
var perf_mode := false      # dispositivi datati: 30 fps e meno decori
var _bg_skip := 0
var _logo_taps := 0
var _logo_last_ms := -100000

func _logo_tap() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _logo_last_ms > 1500:
		_logo_taps = 0
	_logo_last_ms = now
	_logo_taps += 1
	if _logo_taps >= 5:
		_logo_taps = 0
		Career.skip_to_game()

func _draw_hero() -> void:
	if hero == null:
		return
	var c := hero
	var glow_c := Vector2(200, 170)
	var pulse: float = 0.5 + 0.5 * sin(hero_t * 1.25)
	# Glow: anelli concentrici con alpha decrescente (radial hecho a mano).
	for i in 22:
		var rr: float = 70.0 + float(i) * 7.5 + pulse * 9.0
		var aa: float = 0.05 * (1.0 - float(i) / 22.0)
		c.draw_circle(glow_c, rr, Color(0.949, 0.42, 0.11, aa))
	# Arco da tre che attraversa il fondo, come il segno sul parquet.
	c.draw_arc(Vector2(200, 470), 150.0, PI * 1.18, PI * 1.82, 40,
		Color(0.949, 0.42, 0.11, 0.30), 3.0)
	# Tre strisce diagonali in basso a sinistra, ritmo da divisa.
	var stripe := [Vector2(0, 420), Vector2(34, 420), Vector2(94, 348), Vector2(60, 348)]
	var s_col: Color = Color(0.949, 0.42, 0.11, 0.22)
	c.draw_colored_polygon(PackedVector2Array(stripe), s_col)
	var s2 := [Vector2(44, 420), Vector2(66, 420), Vector2(126, 348), Vector2(104, 348)]
	c.draw_colored_polygon(PackedVector2Array(s2), Color(1, 1, 1, 0.07))
	var s3 := [Vector2(88, 420), Vector2(98, 420), Vector2(158, 348), Vector2(148, 348)]
	c.draw_colored_polygon(PackedVector2Array(s3), s_col)

func _ready() -> void:
	# Sfondo OMOGENEO: il verde del parco non deve filtrare nelle bande del
	# menu (su schermi alti il clear color si vedeva in basso).
	RenderingServer.set_default_clear_color(Art.INK)
	Sfx.play_life()
	logo_tex = load("res://assets/logo_t.png") as Texture2D

	bg = Node2D.new()
	bg.z_index = -5
	bg.draw.connect(_draw_bg)
	root.add_child(bg)

	# Dimensioni logiche visibili AGGIORNATE: guida tutto il layout
	# (hero, bottoni, skyline, motes) su QUALUNQUE schermo.
	mv_w = maxf(get_viewport().get_visible_rect().size.x, 1280.0)
	mv_h = maxf(get_viewport().get_visible_rect().size.y, 720.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# Skyline FINO AL BORDO DESTRO visibile (era ferma a 1360).
	var _sky_max: float = maxf(mv_w, 1360.0)
	var x := -40.0
	while x < _sky_max + 80.0:
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
		motes.append({"p": Vector2(rng.randf_range(0, mv_w), rng.randf_range(0, 720)),
			"v": rng.randf_range(6.0, 22.0), "r": rng.randf_range(1.5, 3.5),
			"a": rng.randf_range(0.10, 0.35)})

	hero_t = 0.0
	# AUTO-DETECT: su tablet/telefoni lenti (es. Galaxy Tab S del 2014) il
	# gioco a 60 fps saltella. Dopo 2.5 s nel menu misuriamo: se stiamo
	# sotto le ~42 fps passiamo a 30 e spegniamo i decori, una volta sola.
	get_tree().create_timer(2.5).timeout.connect(func():
		if Engine.get_frames_per_second() < 42 \
		and int(Settings.get_v("target_fps", 60)) == 60 \
		and not bool(Settings.get_v("fps_auto_done", false)):
			Settings.set_v("fps_auto_done", true)
			Settings.set_v("target_fps", 30)
			Settings.set_v("lowgfx", true)
			perf_mode = true
			Events.toast.emit("Modalita performance attiva (30 fps)"))
	# Bob del logo + glow pulsante: il menu respira invece di stare fermo.
	get_tree().process_frame.connect(func():
		hero_t += 1.0 / 60.0
		if hero != null:
			var bob: float = sin(hero_t * 1.25) * 6.0
			logo.position = Vector2(45, 26 + bob)
			logo_shadow.position = logo.position + Vector2(7, 11 + bob * 0.25)
			hero.queue_redraw()
		# LOWGFX: lo sfondo del menu si ridisegna 1 volta su 4.
		_bg_skip = (int(_bg_skip) + 1) % 4
		if not perf_mode or _bg_skip == 0:
			bg.queue_redraw()
		var d := 1.0 / 60.0
		if perf_mode:
			return
		for m in motes:
			m["p"].y -= m["v"] * d
			if m["p"].y < -6.0:
				m["p"].y = mv_h + 6.0
				m["p"].x = randf_range(0, mv_w)
		bg.queue_redraw())

	# --- brand lockup, left half
	# HERO di sinistra: niente piu' logo "sparato li in mezzo" — glow
	# arancio che pulsa, ombra portata sotto il logo, bob lento e decori
	# da campo (arco da tre + strisce diagonali). Composizione, non cartello.
	hero = Control.new()
	# Centro nella meta' SINISTRA dello schermo reale (era (120,158)
	# fisso in un 1280x720: su telefono allungato tutto a sinistra,
	# destra vuota).
	hero.position = Vector2(maxf(24.0, mv_w * 0.5 * 0.5 - 200.0), maxf(12.0, (mv_h - 420.0) * 0.5) + 30.0)
	hero.size = Vector2(400, 420)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.draw.connect(_draw_hero)
	root.add_child(hero)
	logo_shadow = TextureRect.new()
	logo_shadow.texture = logo_tex
	logo_shadow.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	logo_shadow.custom_minimum_size = Vector2(310, 310)
	logo_shadow.size = Vector2(310, 310)
	logo_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_shadow.modulate = Color(0, 0, 0, 0.38)
	logo_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(logo_shadow)
	logo = TextureRect.new()
	logo.texture = logo_tex
	logo.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	logo.custom_minimum_size = Vector2(310, 310)
	logo.size = Vector2(310, 310)
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# SEGRETO: 5 tap rapide sul logo (quello che e' anche l'icona dell app)
	# e il menu porta direttamente alla prossima gara. Nessun bottone in giro.
	logo.mouse_filter = Control.MOUSE_FILTER_STOP
	logo.gui_input.connect(func(e):
		if (e is InputEventScreenTouch and e.pressed) \
		or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
			_logo_tap())
	hero.add_child(logo)
	var tag := Label.new()
	tag.text = Loc.t("tagline")
	tag.add_theme_font_size_override("font_size", 19)
	tag.add_theme_color_override("font_color", Color(0.80, 0.80, 0.84))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.custom_minimum_size = Vector2(400, 0)
	tag.position = Vector2(0, 352)
	hero.add_child(tag)

	# --- menu column, right half
	# Colonna bottoni nella meta' DESTRA reale (era (640,150) fisso:
	# su uno schermo da 1560 logico occupava il centro-sinistra).
	var _bw: float = minf(560.0, mv_w * 0.44)
	var v := UIKit.column(root, Vector2(mv_w - _bw - 90.0, 150.0), _bw)
	_menu_col = v.get_parent()   # lo ScrollContainer, quello posizionato
	_menu_col_w = _bw
	# aggiorna anche le grand latitudini dei bottoni
	var _btn_w: float = _bw
	if SaveSystem.has_save():
		UIKit.big_button(v, Loc.t("menu.continue"), func():
			SaveSystem.load_game()
			SceneRouter.goto("res://src/scenes/CityScene.tscn"), "", _btn_w)
	UIKit.big_button(v, Loc.t("menu.new"), func():
		SceneRouter.goto("res://src/scenes/CharacterCreator.tscn"), "", _btn_w)
	UIKit.big_button(v, Loc.t("menu.quick"), func():
		if not SaveSystem.has_save():
			Game.profile = Game.default_profile()
		else:
			SaveSystem.load_game()
		# A quick exhibition is still a broadcast: a random club comes to
		# visit in its own colours, in its own style.
		Game.profile["next_match_mode"] = "full"
		Game.profile["match_is_fixture"] = false
		Game.profile["next_opponent"] = Season.TEAMS.filter(
			func(t): return t != Season.my_team()).pick_random()
		Game.profile["next_home"] = true
		Game.set_team_kit(1, Season.kit_for(String(Game.profile["next_opponent"])))
		SceneRouter.goto("res://src/match/MatchScene.tscn"), "", _btn_w)
	UIKit.big_button(v, Loc.t("menu.settings"), func():
		SceneRouter.goto("res://src/scenes/SettingsScene.tscn"), "", _btn_w)
	UIKit.big_button(v, Loc.t("menu.quit"), func(): get_tree().quit(), "", _btn_w)
	var ver := Label.new()
	ver.text = "v%s" % Game.VERSION
	ver.add_theme_font_size_override("font_size", 16)
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	root.add_child(ver)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-90, -34)
	mv_rel()
	call_deferred("mv_rel")
	var _mv: Viewport = get_viewport()
	if _mv != null and not _mv.size_changed.is_connected(mv_rel):
		_mv.size_changed.connect(mv_rel)

func mv_rel() -> void:
	## Ritira hero e colonna bottoni quando le dimensioni reali cambiano
	## (dopo il _ready: rotazione, split-screen, resize: resta centrato).
	mv_w = maxf(get_viewport().get_visible_rect().size.x, 1280.0)
	mv_h = maxf(get_viewport().get_visible_rect().size.y, 720.0)
	if hero != null:
		hero.position.x = maxf(24.0, mv_w * 0.5 * 0.5 - 200.0)
		hero.position.y = maxf(12.0, (mv_h - 420.0) * 0.5) + 30.0
	if _menu_col != null:
		_menu_col.position.x = mv_w - _menu_col_w - 90.0

func _draw_bg() -> void:
	# vertical gradient: ink at the top, warmer charcoal at the horizon
	for i in 24:
		var k := float(i) / 24.0
		bg.draw_rect(Rect2(0, k * 720.0, maxf(1280.0, mv_w), 32.0),
			Art.INK.lerp(Color(0.16, 0.12, 0.10), k * 0.8))
	# court-line motif: a giant faint centre circle behind the logo
	bg.draw_arc(Vector2(300, 760), 430, 0, TAU, 64, Color(0.949, 0.420, 0.114, 0.10), 3.0)
	bg.draw_arc(Vector2(300, 760), 300, 0, TAU, 64, Color(0.949, 0.420, 0.114, 0.07), 2.0)
	# skyline silhouette with lit windows
	for b in buildings:
		var top := 720.0 - float(b["h"])
		bg.draw_rect(Rect2(b["x"], top, b["w"], b["h"]), Color(0.045, 0.050, 0.068))
		for w in b["wins"]:
			bg.draw_rect(Rect2(b["x"] + w[0], top + w[1], 6, 8),
				Color(0.98, 0.78, 0.26, w[2]))
	# drifting embers (spenti in modalita performance)
	if perf_mode:
		return
	for m in motes:
		bg.draw_circle(m["p"], m["r"], Color(0.949, 0.420, 0.114, m["a"]))
