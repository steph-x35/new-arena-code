extends Node2D
## Menu degli ALLENAMENTO: quattro esercizi guidati, un gesto chiave per
## ciascuno. Niente cronometro e difesa ferma: si ripete finche' non entra,
## e i fischi continuano a insegnare le regole.

@onready var root: Control = $UI/Root

func _ready() -> void:
	_build()

func _build() -> void:
	for c in root.get_children():
		c.queue_free()
	var dx := UIKit.center_dx(root)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var t := Label.new()
	t.text = Loc.t("drill.title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 44)
	t.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	t.position = Vector2(dx, 30)
	t.size = Vector2(1280, 58)
	root.add_child(t)
	var sub := Label.new()
	sub.text = Loc.t("drill.sub")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 19)
	sub.modulate = Color(1, 1, 1, 0.7)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.position = Vector2(dx, 94)
	sub.size = Vector2(1280, 34)
	root.add_child(sub)
	for i in Drills.LIST.size():
		var d: Dictionary = Drills.LIST[i]
		var b := Button.new()
		b.text = Loc.t(String(d["loc"]))
		b.custom_minimum_size = Vector2(800, 92)
		b.add_theme_font_size_override("font_size", 22)
		b.position = Vector2(240.0 + dx, 170.0 + i * 112.0)
		var id := String(d["id"])
		b.pressed.connect(func(): _start(id))
		root.add_child(b)
	var back := Button.new()
	back.text = Loc.t("common.back")
	back.custom_minimum_size = Vector2(200, 68)
	back.add_theme_font_size_override("font_size", 22)
	back.position = Vector2(1020.0 + dx, 618)
	back.pressed.connect(func(): SceneRouter.goto(SceneRouter.MENU))
	root.add_child(back)

func _start(id: String) -> void:
	Game.profile["next_match_mode"] = "drill"
	Game.profile["next_drill"] = id
	SceneRouter.goto("res://src/match/MatchScene.tscn")
