extends Node2D
## Options: sliders, toggles, a live readout. Landscape, scrollable.

@onready var root: Control = $UI/Root
var info: Label

func _ready() -> void:
	UIKit.header(root, "BASKIN ACADEMY", Loc.t("settings.title"))
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 56
	scroll.offset_top = 150
	scroll.offset_right = -56
	scroll.offset_bottom = -30
	root.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(1100, 0)
	scroll.add_child(v)

	_section(v, Loc.t("settings.display"))
	_row_toggle(v, Loc.t("settings.fps"), "target_fps", 60, 30)
	_row_toggle(v, Loc.t("settings.meter"), "show_shot_meter", true, false)
	_row_toggle(v, Loc.t("settings.left"), "left_handed_ui", true, false)

	_lang_row(v)

	_section(v, Loc.t("settings.difficulty"))
	_diff_row(v)
	var hint := Label.new()
	hint.text = Loc.t("settings.diff.hint")
	hint.add_theme_font_size_override("font_size", 18)
	hint.modulate = Color(1, 1, 1, 0.7)
	v.add_child(hint)

	_section(v, Loc.t("settings.controls"))
	_row_slider(v, Loc.t("settings.stick"), "joystick_sensitivity", 0.4, 2.0, 0.1)

	_section(v, Loc.t("settings.audio"))
	_row_slider(v, Loc.t("settings.sfx"), "sfx", 0.0, 1.0, 0.05)
	_row_slider(v, Loc.t("settings.music"), "music", 0.0, 1.0, 0.05)
	_row_slider(v, Loc.t("settings.voice"), "voice", 0.0, 1.0, 0.05)
	_row_slider(v, Loc.t("settings.crowd"), "crowd", 0.0, 1.0, 0.05)

	_section(v, Loc.t("settings.save"))
	var del := Button.new()
	del.text = Loc.t("settings.del")
	del.custom_minimum_size = Vector2(420, 64)
	del.add_theme_font_size_override("font_size", 22)
	del.pressed.connect(func():
		SaveSystem.delete_save()
		Events.toast.emit(Loc.t("settings.deleted")))
	v.add_child(del)

	info = Label.new()
	info.add_theme_font_size_override("font_size", 18)
	info.modulate = Color(1, 1, 1, 0.7)
	v.add_child(info)

	var back := Button.new()
	back.text = Loc.t("common.back")
	back.custom_minimum_size = Vector2(240, 70)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(func(): SceneRouter.goto(SceneRouter.MENU))
	v.add_child(back)
	_refresh()

## Three buttons, one setting: how hard the opponents really are. It is read by
## every AIBrain (skill, close-outs, steals, doubling) so it changes the match,
## not a label.
func _diff_row(v: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	for i in 3:
		var b := Button.new()
		b.text = Loc.t("settings.diff%d" % i)
		b.custom_minimum_size = Vector2(220, 62)
		b.add_theme_font_size_override("font_size", 22)
		b.set_meta("diff", i)
		b.pressed.connect(func():
			Settings.set_v("difficulty", i)
			Game.profile["difficulty"] = i
			Sfx.play("ui_tap", -6.0)
			_paint_diff(row))
		row.add_child(b)
	_paint_diff(row)

func _paint_diff(row: HBoxContainer) -> void:
	var cur: int = int(Settings.get_v("difficulty", 1))
	for b in row.get_children():
		if b is Button:
			var i: int = int(b.get_meta("diff"))
			var on: bool = i == cur
			b.modulate = Color(1.0, 0.85, 0.30) if on else Color(1, 1, 1, 0.72)
			b.text = ("%s  \u2713" % Loc.t("settings.diff%d" % i)) if on else Loc.t("settings.diff%d" % i)

func _lang_row(v: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var l := Label.new()
	l.text = Loc.t("settings.lang")
	l.custom_minimum_size = Vector2(280, 0)
	l.add_theme_font_size_override("font_size", 22)
	row.add_child(l)
	for code in ["en", "it"]:
		var b := Button.new()
		b.text = "EN" if code == "en" else "IT"
		b.custom_minimum_size = Vector2(96, 62)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func():
			Loc.set_lang(code)
			# repaint every toggle/label on this screen in the new language
			get_tree().reload_current_scene())
		row.add_child(b)

func _section(v: VBoxContainer, title: String) -> void:
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 22)
	l.modulate = Color(1.0, 0.82, 0.28)
	v.add_child(l)

func _row_toggle(v: VBoxContainer, label: String, key: String, on_val, off_val) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(620, 62)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(func():
		var cur = Settings.get_v(key, on_val)
		Settings.set_v(key, off_val if cur == on_val else on_val)
		_refresh())
	b.set_meta("key", key)
	b.set_meta("label", label)
	b.set_meta("on", on_val)
	v.add_child(b)
	_paint_toggle(b)

func _paint_toggle(b: Button) -> void:
	var key: String = String(b.get_meta("key"))
	var label: String = String(b.get_meta("label"))
	var on_val = b.get_meta("on")
	var cur = Settings.get_v(key, on_val)
	var is_on: bool = cur == on_val
	if typeof(on_val) == TYPE_BOOL:
		is_on = bool(cur)
	b.text = "%s    [%s]" % [label, "ON" if is_on else "OFF"]

func _row_slider(v: VBoxContainer, label: String, key: String, mn: float, mx: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(280, 0)
	l.add_theme_font_size_override("font_size", 22)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.custom_minimum_size = Vector2(420, 40)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value = float(Settings.get_v(key, mn))
	var val := Label.new()
	val.custom_minimum_size = Vector2(80, 0)
	val.add_theme_font_size_override("font_size", 22)
	val.text = "%.2f" % s.value
	s.value_changed.connect(func(x):
		Settings.set_v(key, x)
		Sfx.apply_settings()
		if key == "sfx":
			Sfx.play("ui_tap", -6.0)
		val.text = "%.2f" % x
		_refresh())
	row.add_child(s)
	row.add_child(val)
	v.add_child(row)

func _refresh() -> void:
	for c in get_tree().get_nodes_in_group(""):
		pass
	if root:
		for n in root.find_children("*", "Button", true, false):
			if n.has_meta("key"):
				_paint_toggle(n)
	if info:
		info.text = "FPS %d   ·   stick %.1f   ·   SFX %.0f%%   ·   music %.0f%%" % [
			int(Settings.get_v("target_fps", 60)),
			float(Settings.get_v("joystick_sensitivity", 1.0)),
			float(Settings.get_v("sfx", 1.0)) * 100.0,
			float(Settings.get_v("music", 0.7)) * 100.0]
