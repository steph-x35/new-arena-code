extends Node2D
## Initial creation: name, position, height/weight (affect physics), look, hand.

@onready var root: Control = $UI/Root
var preview: PlayerPreview
var name_edit: LineEdit
var info: Label
var h_lbl: Label
var w_lbl: Label
const POSITIONS := ["PG", "SG", "SF", "PF", "C"]
const POS_PRESETS := {
	"PG": {"h": 185, "w": 80, "handle": 8, "pass": 8, "speed": 6, "rebound": -8, "block": -8},
	"SG": {"h": 193, "w": 88, "three": 8, "mid": 6, "speed": 3, "rebound": -4},
	"SF": {"h": 200, "w": 96, "defense": 5, "close": 4, "rebound": 2},
	"PF": {"h": 206, "w": 108, "rebound": 8, "close": 6, "block": 5, "three": -8, "speed": -4},
	"C":  {"h": 212, "w": 118, "rebound": 12, "block": 10, "close": 8, "three": -14, "speed": -8, "handle": -8},
}

func _ready() -> void:
	Game.profile = Game.default_profile()
	UIKit.header(root, Loc.t("creator.title"), Loc.t("creator.sub"))

	# Compact left column: +/- adjusters instead of one full-height button each.
	# The old layout needed 1168px of vertical space on a 720px screen, which
	# pushed START CAREER off the bottom where it could never be tapped.
	var v := UIKit.column(root, Vector2(56, UIKit.TOP_SAFE), 640, 116.0)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Player name"
	name_edit.text = "Alex Reyes"
	name_edit.custom_minimum_size = Vector2(560, 72)
	name_edit.add_theme_font_size_override("font_size", 26)
	v.add_child(name_edit)

	UIKit.big_button(v, "Position: PG", func(): _cycle_pos(), "", 560).name = "PosBtn"
	h_lbl = UIKit.adjuster(v, "Height  185 cm", func(): _adj_h(-2), func(): _adj_h(2))
	w_lbl = UIKit.adjuster(v, "Weight  80 kg", func(): _adj_w(-3), func(): _adj_w(3))
	UIKit.big_button(v, "Team: Riverside Ravens", func(): _cycle_team(), "", 560).name = "TeamBtn"
	var jn: Label = UIKit.adjuster(v, "Jersey  #7", func(): _adj_jersey(-1), func(): _adj_jersey(1))
	jn.name = "JerseyLbl"

	# Griglia 2x2 COMPATTA: quattro bottoni da 178px in fila escono dalla
	# colonna (640px) e finiscono sotto l'anteprima del personaggio.
	var looks := GridContainer.new()
	looks.columns = 2
	looks.add_theme_constant_override("h_separation", 10)
	looks.add_theme_constant_override("v_separation", 10)
	v.add_child(looks)
	for cfg in [
		[Loc.t("creator.skin"), func():
			Game.profile["skin"] = (Game.profile["skin"] + 1) % 5
			_refresh()],
		[Loc.t("creator.hair"), func():
			Game.profile["hair_style"] = (int(Game.profile.get("hair_style", 0)) + 1) % 6
			_refresh()],
		[Loc.t("Colore capelli"), func():
			Game.profile["hair"] = (Game.profile["hair"] + 1) % Game.HAIR_COLORS.size()
			_refresh()],
		[Loc.t("creator.hand"), func():
			Game.profile["hand"] = "L" if Game.profile["hand"] == "R" else "R"
			_refresh()],
	]:
		var b := Button.new()
		b.text = cfg[0]
		b.custom_minimum_size = Vector2(300, 68)
		b.add_theme_font_size_override("font_size", 20)
		b.clip_text = true
		b.pressed.connect(cfg[1])
		looks.add_child(b)

	# START CAREER is the one mandatory action on this screen, so it is pinned
	# to the bottom edge OUTSIDE the scroll area: a player must never have to
	# discover a scroll gesture to get into the game.
	var start := Button.new()
	start.text = "START CAREER"
	start.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	start.position = Vector2(56, -108)
	start.custom_minimum_size = Vector2(560, 88)
	start.add_theme_font_size_override("font_size", 30)
	start.modulate = Color(1.0, 0.86, 0.45)
	start.pressed.connect(_start)
	root.add_child(start)

	var back := Button.new()
	back.text = "< BACK"
	back.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	back.position = Vector2(-200, 28)
	back.custom_minimum_size = Vector2(170, 72)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(func(): SceneRouter.goto("res://src/scenes/MainMenu.tscn"))
	root.add_child(back)

	info = Label.new()
	info.add_theme_font_size_override("font_size", 20)
	info.set_anchors_preset(Control.PRESET_TOP_LEFT)
	info.position = Vector2(740, UIKit.TOP_SAFE)
	info.custom_minimum_size = Vector2(360, 0)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(info)

	# Live mannequin next to the controls. Skin, hair, hand, height and weight
	# all show up here the moment you change them -- you should never have to
	# reach the city to find out what you picked.
	preview = PlayerPreview.new()
	preview.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.add_child(preview)
	_place_preview()
	get_viewport().size_changed.connect(_place_preview)

	# NOTE: these two used to live at the bottom of _place_preview(), which
	# meant every window resize silently reset the position you had chosen.
	_apply_position("PG")
	_refresh()

func _place_preview() -> void:
	## Sit the stage to the right of the controls, filling the space between
	## them and the attribute read-out.
	if preview == null:
		return
	var s: Vector2 = root.get_viewport_rect().size
	var x: float = 740.0
	var pw: float = clampf(s.x - x - 380.0, 240.0, 420.0)
	var ph: float = clampf(s.y - UIKit.TOP_SAFE - 130.0, 260.0, 520.0)
	preview.position = Vector2(x, UIKit.TOP_SAFE)
	preview.size = Vector2(pw, ph)
	preview.custom_minimum_size = preview.size
	if info:
		info.position = Vector2(x + pw + 20.0, UIKit.TOP_SAFE)
		info.custom_minimum_size = Vector2(maxf(s.x - (x + pw + 40.0), 200.0), 0)

func _cycle_pos() -> void:
	var i: int = (POSITIONS.find(Game.profile["position"]) + 1) % POSITIONS.size()
	_apply_position(POSITIONS[i])
	_refresh()

## Pick the club you sign for. Every 8-team league fixture, the kit screen and
## the phone calendar then follow this choice instead of one hard-coded name.
func _cycle_team() -> void:
	var i: int = (Season.TEAMS.find(Season.my_team()) + 1) % Season.TEAMS.size()
	Game.profile["team"] = Season.TEAMS[i]
	_refresh()

func _apply_position(pos: String) -> void:
	var base := Game.default_profile()
	Game.profile["position"] = pos
	Game.profile["attrs"] = base["attrs"].duplicate()
	var pr: Dictionary = POS_PRESETS[pos]
	Game.profile["height_cm"] = pr["h"]
	Game.profile["weight_kg"] = pr["w"]
	for k in pr:
		if k in ["h", "w"]: continue
		Game.profile["attrs"][k] = clampi(Game.profile["attrs"][k] + pr[k], 25, 90)

func _adj_h(d: int) -> void:
	Game.profile["height_cm"] = clampi(Game.profile["height_cm"] + d, 175, 220)
	_refresh()

func _adj_w(d: int) -> void:
	Game.profile["weight_kg"] = clampi(Game.profile["weight_kg"] + d, 68, 135)
	_refresh()

func _adj_jersey(d: int) -> void:
	var n: int = clampi(int(Game.profile.get("jersey", 7)) + d, 0, 99)
	Game.profile["jersey"] = n
	_refresh()

func _refresh() -> void:
	var pos_btn: Node = root.find_child("PosBtn", true, false)
	if pos_btn and pos_btn is Button:
		pos_btn.text = Loc.t("creator.pos") % Game.profile["position"]
	var team_btn: Node = root.find_child("TeamBtn", true, false)
	if team_btn and team_btn is Button:
		team_btn.text = Loc.t("creator.team") % Season.my_team()
	if h_lbl: h_lbl.text = Loc.t("creator.height") % int(Game.profile["height_cm"])
	if w_lbl: w_lbl.text = Loc.t("creator.weight") % int(Game.profile["weight_kg"])
	var jlbl: Node = root.find_child("JerseyLbl", true, false)
	if jlbl and jlbl is Label:
		jlbl.text = Loc.t("creator.jersey") % int(Game.profile.get("jersey", 7))
	var p: Dictionary = Game.profile
	var lines := ["%s  %d cm  %d kg  %s-handed" % [p["position"], p["height_cm"], p["weight_kg"], p["hand"]],
		"Accel factor: %.2f   Size factor: %.2f" % [Game.mass_factor(), Game.height_factor()], ""]
	for a in Game.ATTRS:
		lines.append("%-10s %d" % [a, Game.attr(a)])
	info.text = "\n".join(lines)
	if preview: preview.queue_redraw()

func _start() -> void:
	Game.profile["name"] = name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else "Alex Reyes"
	Contacts.seed_intro()
	# Fix the league schedule for this career, then build it once.
	Game.profile["seed"] = randi()
	Game.profile["schedule"] = []
	Season.schedule()
	# The rookie signing bonus: exactly 200 coins to spend on your first walk
	# through the city.
	Game.profile["money"] = 200
	Game.add_social_post(Season.handle(), "Signed %s. Welcome to the city." % Game.profile["name"], 120)
	SaveSystem.save_game()
	SceneRouter.goto("res://src/scenes/CityScene.tscn")
