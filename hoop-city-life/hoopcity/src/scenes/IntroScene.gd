extends Node2D
## Animated title intro on a BRIGHT court-daylight background (explicitly not
## the dark menu look). Everything is procedural: a sunlit hardwood floor, a
## hoop, a ball that bounces in, arcs up and swishes through the net, then the
## logo lands and the menu buttons fade in.
##
## Fully skippable: any tap jumps straight to the end state. An intro you
## cannot skip is a bug on the second launch.

var t := 0.0
var skipped := false
var done := false

# ball state (procedural, not physics-driven: the beat must be identical every run)
var ball_pos := Vector2.ZERO
var ball_h := 0.0
var ball_spin := 0.0
var net_wobble := 0.0
var flash := 0.0

var ui: Control
var buttons: VBoxContainer
var title_lbl: Label
var sub_lbl: Label

const FLOOR_Y := 250.0
## Rim sits 370px above the floor line -- a believable 10ft at this scale.
const HOOP := Vector2(340.0, -120.0)
const T_SWISH := 3.05

func _ready() -> void:
	Sfx.play_life()
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)

	title_lbl = Label.new()
	title_lbl.text = "HOOP CITY LIFE"
	title_lbl.add_theme_font_size_override("font_size", 92)
	title_lbl.add_theme_color_override("font_color", Color(0.10, 0.12, 0.18))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# A full-width strip with centred text. PRESET_CENTER_TOP anchors the
	# label's LEFT edge to the middle of the screen, so offsetting by half its
	# width pushed the title off the left edge -- that is why it looked cut.
	title_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_lbl.modulate.a = 0.0
	ui.add_child(title_lbl)

	sub_lbl = Label.new()
	sub_lbl.text = Loc.t("tagline")
	sub_lbl.add_theme_font_size_override("font_size", 22)
	sub_lbl.add_theme_color_override("font_color", Color(0.22, 0.25, 0.33))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Full-width strip, same reason as the title above.
	sub_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub_lbl.modulate.a = 0.0
	ui.add_child(sub_lbl)

	buttons = VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.modulate.a = 0.0
	ui.add_child(buttons)

	_add_btn(Loc.t("menu.new"), func(): SceneRouter.goto("res://src/scenes/CharacterCreator.tscn"))
	if SaveSystem.has_save():
		_add_btn(Loc.t("menu.continue"), func():
			SaveSystem.load_game()
			SceneRouter.goto("res://src/scenes/CityScene.tscn"))
	_add_btn(Loc.t("menu.quick"), func():
		if not SaveSystem.has_save(): Game.profile = Game.default_profile()
		else: SaveSystem.load_game()
		Game.profile["next_match_mode"] = "full"
		Game.profile["match_is_fixture"] = true
		SceneRouter.goto("res://src/match/MatchScene.tscn"))
	_add_btn(Loc.t("menu.settings"), func(): SceneRouter.goto("res://src/scenes/SettingsScene.tscn"))
	_add_btn(Loc.t("menu.quit"), func(): get_tree().quit())

	var skip := Label.new()
	skip.text = Loc.t("intro.skip")
	skip.add_theme_font_size_override("font_size", 18)
	skip.add_theme_color_override("font_color", Color(0.30, 0.33, 0.40))
	skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.position = Vector2(-170, -46)
	ui.add_child(skip)
	skip.name = "SkipHint"

	_layout()
	get_viewport().size_changed.connect(_layout)

func _add_btn(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(420, 78)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(cb)
	buttons.add_child(b)

func _layout() -> void:
	var s: Vector2 = ui.get_viewport_rect().size
	title_lbl.position = Vector2(0.0, s.y * 0.10)
	title_lbl.custom_minimum_size = Vector2(0.0, 110.0)
	title_lbl.size = Vector2(s.x, 110.0)
	# Shrink the type on narrow screens so a long title can never overflow.
	var f: Font = ThemeDB.fallback_font
	var fs := 92
	while fs > 40 and f.get_string_size(title_lbl.text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x > s.x - 80.0:
		fs -= 4
	title_lbl.add_theme_font_size_override("font_size", fs)
	sub_lbl.position = Vector2(0.0, s.y * 0.10 + 104.0)
	sub_lbl.custom_minimum_size = Vector2(0.0, 30.0)
	sub_lbl.size = Vector2(s.x, 30.0)
	# buttons: bottom-left, clear of the hoop on the right
	buttons.position = Vector2(64, s.y - 78.0 * buttons.get_child_count()
		- 12.0 * maxi(buttons.get_child_count() - 1, 0) - 40.0)

func _unhandled_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed)
	if tap and not done:
		_finish_now()

func _finish_now() -> void:
	skipped = true
	t = maxf(t, T_SWISH + 1.2)
	done = true
	title_lbl.modulate.a = 1.0
	sub_lbl.modulate.a = 1.0
	buttons.modulate.a = 1.0
	var hint: Node = ui.get_node_or_null("SkipHint")
	if hint: hint.visible = false
	queue_redraw()

func _process(delta: float) -> void:
	if done:
		net_wobble = maxf(0.0, net_wobble - delta * 2.0)
		flash = maxf(0.0, flash - delta * 2.2)
		queue_redraw()
		return

	t += delta
	_animate_ball()

	# fade the title in as the ball drops through
	title_lbl.modulate.a = clampf((t - T_SWISH + 0.35) / 0.5, 0.0, 1.0)
	sub_lbl.modulate.a = clampf((t - T_SWISH - 0.15) / 0.5, 0.0, 1.0)
	buttons.modulate.a = clampf((t - T_SWISH - 0.45) / 0.6, 0.0, 1.0)
	net_wobble = maxf(0.0, net_wobble - delta * 2.0)
	flash = maxf(0.0, flash - delta * 2.2)

	if t > T_SWISH + 1.3:
		done = true
		var hint: Node = ui.get_node_or_null("SkipHint")
		if hint: hint.visible = false
	queue_redraw()

func _animate_ball() -> void:
	## Three beats: roll in, two dribbles, then the shot arc into the hoop.
	if t < 0.85:
		# rolls in from the left along the floor
		var k: float = t / 0.85
		ball_pos = Vector2(lerpf(-600.0, -300.0, ease(k, 0.4)), 0.0)
		ball_h = 16.0
		ball_spin += 0.42
	elif t < 2.05:
		# two dribbles in place
		var k2: float = (t - 0.85) / 1.20
		ball_pos = Vector2(lerpf(-300.0, -190.0, k2), 0.0)
		ball_h = absf(sin(k2 * PI * 2.4)) * 132.0 + 12.0
		ball_spin += 0.30
	elif t < T_SWISH:
		# the shot: parabola from the release point into the rim
		var k3: float = (t - 2.05) / (T_SWISH - 2.05)
		var from := Vector2(-190.0, 0.0)
		ball_pos = Vector2(lerpf(from.x, HOOP.x, k3), 0.0)
		var apex := 330.0
		ball_h = lerpf(150.0, -HOOP.y, k3) + sin(k3 * PI) * apex
		ball_spin += 0.24
		if k3 >= 1.0 and net_wobble <= 0.0:
			net_wobble = 1.0
			flash = 1.0
	else:
		# drops through the net and settles
		var k4: float = clampf((t - T_SWISH) / 0.8, 0.0, 1.0)
		ball_pos = Vector2(HOOP.x + k4 * 26.0, 0.0)
		ball_h = lerpf(-HOOP.y - 40.0, 14.0, ease(k4, 2.2))
		ball_spin += 0.18
		if net_wobble <= 0.0 and k4 < 0.1:
			net_wobble = 1.0

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	var s: Vector2 = get_viewport_rect().size
	# Work in a centred coordinate space regardless of resolution.
	draw_set_transform(s * 0.5, 0.0, Vector2.ONE)

	_draw_bright_background(s)
	_draw_hoop()
	_draw_ball()

func _draw_bright_background(s: Vector2) -> void:
	var half := s * 0.5 + Vector2(40, 40)

	# --- bright sky-lit wall (light, not the dark menu)
	for i in 10:
		var k := i / 9.0
		var c := Color(0.99, 0.97, 0.92).lerp(Color(0.82, 0.88, 0.96), k)
		draw_rect(Rect2(-half.x, -half.y + k * (FLOOR_Y + half.y), half.x * 2.0,
			(FLOOR_Y + half.y) / 9.0 + 2.0), c)

	# sun glow, upper right
	for i in 9:
		draw_circle(Vector2(half.x * 0.52, -half.y * 0.62), 90.0 + i * 46.0,
			Color(1.0, 0.96, 0.72, 0.055))

	# --- warm hardwood floor
	draw_rect(Rect2(-half.x, FLOOR_Y, half.x * 2.0, half.y * 2.0), Color(0.86, 0.68, 0.42))
	for i in 26:
		var x := -half.x + i * 92.0
		draw_line(Vector2(x, FLOOR_Y), Vector2(x - 70.0, half.y), Color(0.72, 0.54, 0.32, 0.5), 2.0)
	draw_line(Vector2(-half.x, FLOOR_Y), Vector2(half.x, FLOOR_Y), Color(0.62, 0.45, 0.26), 4.0)
	# Three-point arc, FLATTENED into perspective and drawn below the floor
	# line so it lies on the boards instead of standing up like a rainbow.
	var arc_pts := PackedVector2Array()
	for i in 41:
		var a: float = PI + PI * (i / 40.0)
		arc_pts.append(Vector2(HOOP.x - 40.0 + cos(a) * 430.0,
			FLOOR_Y + 60.0 - sin(a) * 74.0))
	for i in arc_pts.size() - 1:
		draw_line(arc_pts[i], arc_pts[i + 1], Color(0.99, 0.98, 0.94, 0.80), 5.0)
	draw_line(Vector2(-half.x, FLOOR_Y + 128.0), Vector2(half.x, FLOOR_Y + 128.0),
		Color(0.99, 0.98, 0.94, 0.30), 3.0)

	# soft light pool under the hoop
	for i in 6:
		draw_circle(Vector2(HOOP.x, FLOOR_Y + 30.0), 120.0 + i * 60.0, Color(1.0, 0.95, 0.75, 0.03))

	# make-flash: a warm bloom when the ball goes through
	if flash > 0.01:
		draw_circle(Vector2(HOOP.x, HOOP.y), 260.0 * (1.0 + (1.0 - flash)),
			Color(1.0, 0.85, 0.35, 0.20 * flash))

func _draw_hoop() -> void:
	var backboard := Vector2(HOOP.x + 92.0, HOOP.y - 40.0)
	# pole + arm
	draw_rect(Rect2(backboard.x + 62.0, HOOP.y - 60.0, 22.0, FLOOR_Y - HOOP.y + 60.0),
		Color(0.38, 0.40, 0.46))
	draw_rect(Rect2(backboard.x + 6.0, HOOP.y - 26.0, 62.0, 14.0), Color(0.38, 0.40, 0.46))
	# backboard (white, translucent glass look)
	draw_rect(Rect2(backboard.x, backboard.y - 60.0, 16.0, 180.0), Color(0.98, 0.98, 1.0, 0.92))
	draw_rect(Rect2(backboard.x, backboard.y - 60.0, 16.0, 180.0), Color(0.35, 0.38, 0.45), false, 3.0)
	draw_rect(Rect2(backboard.x - 46.0, HOOP.y - 34.0, 46.0, 60.0), Color(0.90, 0.30, 0.22), false, 4.0)

	# rim
	draw_line(Vector2(HOOP.x - 46.0, HOOP.y), Vector2(HOOP.x + 46.0, HOOP.y),
		Color(0.92, 0.40, 0.12), 7.0)
	# net: strands sway after a make
	var sway := sin(Time.get_ticks_msec() / 90.0) * 9.0 * net_wobble
	for i in 8:
		var fx: float = -40.0 + i * 11.5
		var top := Vector2(HOOP.x + fx, HOOP.y + 2.0)
		var bot := Vector2(HOOP.x + fx * 0.45 + sway * (0.4 + i * 0.05), HOOP.y + 62.0 + net_wobble * 10.0)
		draw_line(top, bot, Color(1, 1, 1, 0.85), 2.0)
		if i < 7:
			var mid_a := top.lerp(bot, 0.5)
			var mid_b := Vector2(HOOP.x + fx + 11.5, HOOP.y + 2.0).lerp(
				Vector2(HOOP.x + (fx + 11.5) * 0.45 + sway, HOOP.y + 62.0), 0.5)
			draw_line(mid_a, mid_b, Color(1, 1, 1, 0.6), 1.6)

func _draw_ball() -> void:
	var c := Vector2(ball_pos.x, FLOOR_Y - ball_h)
	# shadow shrinks with height: sells the arc
	var shrink: float = clampf(1.0 - ball_h / 460.0, 0.22, 1.0)
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		pts.append(Vector2(ball_pos.x + cos(a) * 26.0 * shrink, FLOOR_Y + sin(a) * 8.0 * shrink))
	draw_colored_polygon(pts, Color(0.35, 0.26, 0.16, 0.26 * shrink))

	draw_circle(c, 26.0, Color(0.92, 0.47, 0.13))
	draw_circle(c, 26.0, Color(0.98, 0.66, 0.32))
	draw_circle(c - Vector2(7, 7), 15.0, Color(0.96, 0.58, 0.22))
	draw_arc(c, 26.0, 0, TAU, 26, Color(0.30, 0.15, 0.06), 2.4)
	# seams rotate with the spin
	var a1 := ball_spin
	draw_line(c + Vector2(cos(a1), sin(a1)) * 26.0, c - Vector2(cos(a1), sin(a1)) * 26.0,
		Color(0.30, 0.15, 0.06), 2.2)
	var a2 := ball_spin + PI * 0.5
	draw_line(c + Vector2(cos(a2), sin(a2)) * 26.0, c - Vector2(cos(a2), sin(a2)) * 26.0,
		Color(0.30, 0.15, 0.06), 2.2)
	draw_arc(c + Vector2(cos(a1), sin(a1)) * 9.0, 24.0, a1 + 1.1, a1 + 2.1, 12,
		Color(0.30, 0.15, 0.06), 2.0)
