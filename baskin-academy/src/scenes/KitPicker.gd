extends Node2D
## PREPARTITA — one choice only: how long a quarter lasts. Teams, kits and
## format are fixed (full 5v5 baskin), so the screen is a single centered
## column: title, durations, what comes next, TIP OFF.

@onready var root: Control = $UI/Root

const QUARTERS := [
	{"s": 90.0, "l": "1:30"},
	{"s": 120.0, "l": "2:00"},
	{"s": 180.0, "l": "3:00"},
	{"s": 240.0, "l": "4:00"},
	{"s": 360.0, "l": "6:00"},
	{"s": 480.0, "l": "8:00"},
]

var summary: Label

func _ready() -> void:
	# A match is always the full 5v5 indoor game now: 1v1 lives in the old
	# street mode and is not part of this build.
	Game.profile["next_match_mode"] = "full"
	if String(Game.profile.get("next_opponent", "")) == "" \
	or not Game.CLUBS.has(String(Game.profile["next_opponent"])) \
	or String(Game.profile["next_opponent"]) == Game.club_my_team():
		Game.profile["next_opponent"] = _opponents()[0]
	Game.set_team_kit(1, Game.club_kit(String(Game.profile["next_opponent"])))
	# No kit screen anymore: make sure the two shirts can never clash.
	if Game.team_kit(0) == Game.team_kit(1):
		for id in Game.KITS:
			if id != Game.team_kit(0):
				Game.set_team_kit(1, id)
				break
	if not Game.profile.has("quarter_seconds"):
		Game.profile["quarter_seconds"] = 120.0
	if not Game.profile.has("match_is_fixture"):
		Game.profile["match_is_fixture"] = false
	_build()

func _opponents() -> Array:
	return Game.CLUBS.filter(func(t): return t != Game.club_my_team())

func _build() -> void:
	for c in root.get_children():
		c.queue_free()
	_header()
	var cap := Label.new()
	cap.text = Loc.t("match.len.title")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 24)
	cap.position = Vector2(0, 208)
	cap.size = Vector2(1280, 36)
	root.add_child(cap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.position = Vector2(255, 262)
	root.add_child(row)
	var cur: float = float(Game.profile.get("quarter_seconds", 120.0))
	for opt in QUARTERS:
		var secs: float = float(opt["s"])
		_choice(row, String(opt["l"]), absf(secs - cur) < 0.5, Vector2(120, 72), 20,
			func():
				Game.profile["quarter_seconds"] = secs
				_build())
	var nx := Label.new()
	nx.text = Loc.t("setup.next")
	nx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nx.add_theme_font_size_override("font_size", 20)
	nx.modulate = Color(1, 1, 1, 0.6)
	nx.position = Vector2(0, 400)
	nx.size = Vector2(1280, 30)
	root.add_child(nx)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 14)
	acts.position = Vector2(373, 540)
	root.add_child(acts)
	var go := Button.new()
	go.text = Loc.t("setup.tipoff")
	go.custom_minimum_size = Vector2(340, 84)
	go.add_theme_font_size_override("font_size", 26)
	go.pressed.connect(_start)
	acts.add_child(go)
	var back := Button.new()
	back.text = Loc.t("common.back")
	back.custom_minimum_size = Vector2(180, 84)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(func(): SceneRouter.goto(SceneRouter.MENU))
	acts.add_child(back)

func _choice(parent: Control, text: String, selected: bool, size: Vector2,
	font_sz: int, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.add_theme_font_size_override("font_size", font_sz)
	if selected:
		_highlight(b, Color(0.949, 0.420, 0.114), true)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

## Title plus the live summary line, so what is about to be played is always
## readable at the top of the screen.
func _header() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	root.add_child(bg)
	var t := Label.new()
	t.text = Loc.t("setup.title")
	t.position = Vector2(56, 34)
	t.add_theme_font_size_override("font_size", UIKit.FONT_TITLE)
	root.add_child(t)
	summary = Label.new()
	summary.position = Vector2(56, 96)
	summary.add_theme_font_size_override("font_size", 19)
	summary.modulate = Color(1, 1, 1, 0.7)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.size = Vector2(1180, 30)
	root.add_child(summary)
	_refresh_summary()

func _refresh_summary() -> void:
	if summary == null:
		return
	var secs: float = float(Game.profile.get("quarter_seconds", 120.0))
	var mins: String = "%d:%02d" % [int(secs) / 60, int(secs) % 60]
	var opp: String = String(Game.profile["next_opponent"])
	var venue: String = Game.club_arena(Game.club_my_team() if bool(Game.profile.get("next_home", true)) else opp)
	summary.text = Loc.t("setup.summary") % [
		Game.club_my_team(), opp, mins,
		Loc.t("setup.official_short") if bool(Game.profile.get("match_is_fixture", false))
		else Loc.t("setup.friendly_short"), venue]

func _highlight(b: Button, col: Color, ink := false) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.85)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_color_override("font_color",
		Color(0.08, 0.08, 0.1) if ink or col.get_luminance() > 0.45 else Color(1, 1, 1))

func _start() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["next_kit_return"] = SceneRouter.MENU
	SceneRouter.goto("res://src/scenes/RolePicker.tscn")
