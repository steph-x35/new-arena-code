extends Node2D
## Pre-match kit selection: pick the colours for your side and the opposition
## before tipping off. Two swatch grids, a live preview of both jerseys, and a
## guard so the two teams can never wear the same colour.

@onready var root: Control = $UI/Root

var mode := "full"
var opponent := "Practice Squad"
var preview: Control

func _ready() -> void:
	mode = String(Game.profile.get("next_match_mode", "full"))
	opponent = String(Game.profile.get("next_opponent", "Practice Squad"))
	_build()

func _build() -> void:
	for c in root.get_children():
		c.queue_free()
	UIKit.header(root, Loc.tx("TEAM KITS"), Loc.tx("Choose the colours before you tip off."))

	preview = KitPreview.new()
	preview.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	preview.position = Vector2(-420, 150)
	preview.custom_minimum_size = Vector2(360, 220)
	preview.size = Vector2(360, 220)
	root.add_child(preview)

	var v := UIKit.column(root, Vector2(56, 150), 620)
	UIKit.label(v, Loc.tx("YOUR TEAM  ·  %s") % Season.my_team(), 20)
	_swatches(v, 0)
	UIKit.label(v, Loc.tx("OPPONENT  ·  %s") % opponent, 20)
	_swatches(v, 1)

	# Quarter length: the player chooses the match duration before tipping off.
	UIKit.label(v, Loc.t("match.len.title"), 17)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 10)
	v.add_child(lrow)
	var cur: float = float(Game.profile.get("quarter_seconds", 120.0))
	for opt in [{"s": 90.0, "l": "1:30"}, {"s": 120.0, "l": "2:00"}, {"s": 180.0, "l": "3:00"}]:
		var lb := Button.new()
		lb.text = String(opt["l"])
		lb.custom_minimum_size = Vector2(110, 52)
		lb.add_theme_font_size_override("font_size", 18)
		if absf(float(opt["s"]) - cur) < 0.5:
			var sbx := StyleBoxFlat.new()
			sbx.bg_color = Color(0.949, 0.420, 0.114)
			sbx.set_corner_radius_all(10)
			lb.add_theme_stylebox_override("normal", sbx)
			lb.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
		lb.pressed.connect(func():
			Game.profile["quarter_seconds"] = float(opt["s"])
			_build())
		lrow.add_child(lb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var go := Button.new()
	go.text = Loc.tx("▶  TIP OFF")
	go.custom_minimum_size = Vector2(380, 82)
	go.add_theme_font_size_override("font_size", 26)
	go.pressed.connect(func(): _start())
	row.add_child(go)
	var back := Button.new()
	back.text = Loc.tx("Back")
	back.custom_minimum_size = Vector2(210, 82)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(func():
		SceneRouter.goto("res://src/scenes/TeamCourt.tscn"))
	row.add_child(back)

## A row of colour swatches for one team.
func _swatches(parent: Control, team: int) -> void:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	parent.add_child(grid)
	var current: String = Game.team_kit(team)
	var other: String = Game.team_kit(1 - team)
	for id in Game.KITS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(112, 56)
		b.text = String(Game.KITS[id]["name"])
		b.add_theme_font_size_override("font_size", 15)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Game.KITS[id]["col"])
		sb.set_corner_radius_all(10)
		if id == current:
			sb.border_color = Color(1, 1, 1)
			sb.set_border_width_all(4)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_color_override("font_color",
			Color(0.08, 0.08, 0.1) if Color(Game.KITS[id]["col"]).get_luminance() > 0.5
			else Color(1, 1, 1))
		# Both sides in the same colour would be unplayable, so the colour the
		# OTHER team is already wearing cannot be picked here.
		if id == other:
			b.disabled = true
			b.text = Loc.tx("in use")
		var kid: String = id
		var t: int = team
		b.pressed.connect(func():
			Game.set_team_kit(t, kid)
			_build())
		grid.add_child(b)

func _start() -> void:
	Game.profile["next_match_mode"] = mode
	Game.profile["next_opponent"] = opponent
	SceneRouter.goto("res://src/match/MatchScene.tscn")
