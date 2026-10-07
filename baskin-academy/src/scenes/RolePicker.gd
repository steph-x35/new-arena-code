extends Node2D
## Role select: five cards, one per baskin role, each with its full rules.
## The pick is stored in the profile; the match skips its own picker.

@onready var root: Control = $UI/Root

const CARD_W := 224.0
const CARD_H := 396.0

var selected := 5

func _ready() -> void:
	selected = clampi(int(Game.profile.get("baskin_role", 5)), 1, 5)
	_build()

func _build() -> void:
	for c in root.get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var t := Label.new()
	t.text = Loc.t("rolepick.title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 46)
	t.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	t.position = Vector2(0, 26)
	t.size = Vector2(1280, 60)
	root.add_child(t)
	var sub := Label.new()
	sub.text = Loc.t("rolepick.sub")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.modulate = Color(1, 1, 1, 0.7)
	sub.position = Vector2(0, 92)
	sub.size = Vector2(1280, 30)
	root.add_child(sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.position = Vector2(56, 150)
	root.add_child(row)
	for r in [1, 2, 3, 4, 5]:
		row.add_child(_card(r))

	# bottom row: who you are + go / back
	var who := Label.new()
	who.text = Loc.t("rolepick.as") % Loc.t("role.%d" % selected)
	who.add_theme_font_size_override("font_size", 24)
	who.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	who.position = Vector2(56, 610)
	who.size = Vector2(640, 40)
	root.add_child(who)
	var go := Button.new()
	go.text = Loc.t("rolepick.go")
	go.custom_minimum_size = Vector2(300, 76)
	go.add_theme_font_size_override("font_size", 26)
	go.position = Vector2(706, 596)
	go.pressed.connect(_start)
	root.add_child(go)
	var back := Button.new()
	back.text = Loc.t("common.back")
	back.custom_minimum_size = Vector2(180, 76)
	back.add_theme_font_size_override("font_size", 22)
	back.position = Vector2(1020, 596)
	back.pressed.connect(func(): SceneRouter.goto("res://src/scenes/KitPicker.tscn"))
	root.add_child(back)

func _card(r: int) -> PanelContainer:
	var sel: bool = r == selected
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(CARD_W, CARD_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.13, 0.21, 0.98) if sel else Color(0.055, 0.06, 0.09, 0.95)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(3 if sel else 1)
	sb.border_color = Color(1.0, 0.82, 0.35, 0.9) if sel else Color(1, 1, 1, 0.22)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	pc.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(vb)
	var num := Label.new()
	num.text = str(r)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 62)
	num.add_theme_color_override("font_color",
		Color(1.0, 0.86, 0.45) if sel else Color(1, 1, 1, 0.55))
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(num)
	var nm := Label.new()
	nm.text = Loc.t("role.%d" % r)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", 19)
	nm.add_theme_color_override("font_color",
		Color(1.0, 0.86, 0.45) if sel else Color(0.95, 0.95, 0.97))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nm)
	var ds := Label.new()
	ds.text = Loc.t("role.%d.d" % r)
	ds.add_theme_font_size_override("font_size", 16)
	ds.modulate = Color(1, 1, 1, 0.85)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(ds)
	var hn := Label.new()
	hn.text = Loc.t("role.%d.hint" % r)
	hn.add_theme_font_size_override("font_size", 15)
	hn.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	hn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(hn)
	var rr := r
	pc.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed \
		and ev.button_index == MOUSE_BUTTON_LEFT:
			_select(rr))
	return pc

func _select(r: int) -> void:
	selected = r
	Game.profile["baskin_role"] = r
	Sfx.play("go", -6.0)
	_build()

func _start() -> void:
	Game.profile["baskin_role"] = selected
	Game.profile["next_match_mode"] = "full"
	SceneRouter.goto("res://src/match/MatchScene.tscn")
