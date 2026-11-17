extends CanvasLayer
## Shows actual, clamped meal effects, including negative junk-food health.
var overlay: Control
var icons: Control
var busy := false

func _ready() -> void:
	layer = 201
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.food_consumed.connect(_show)

func _show(hunger: float, energy: float, health: float) -> void:
	if overlay != null and is_instance_valid(overlay):
		return
	busy = false
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.07, 0.09, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)
	var title := Label.new()
	title.text = Loc.t("food.reward")
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	# Draw the symbols ourselves instead of relying on emoji fonts, which are
	# absent on some Android devices and in web builds.
	icons = HBoxContainer.new()
	icons.custom_minimum_size = Vector2(240, 88)
	(icons as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	(icons as HBoxContainer).add_theme_constant_override("separation", 16)
	col.add_child(icons)
	for spec in [["food", Color(1.0, 0.69, 0.25)], ["bolt", Color(1.0, 0.86, 0.28)], ["heart", Color(1.0, 0.35, 0.38)]]:
		var glyph := Control.new()
		glyph.custom_minimum_size = Vector2(68, 68)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var kind: String = spec[0]
		var colour: Color = spec[1]
		glyph.draw.connect(func(): Art.draw_icon(glyph, kind, Rect2(Vector2.ZERO, glyph.size), colour))
		icons.add_child(glyph)
	for row in [["food.hunger", hunger], ["food.energy", energy], ["food.health", health]]:
		var l := Label.new()
		l.text = "%s  %+.0f" % [Loc.t(row[0]), float(row[1])]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 27)
		l.add_theme_color_override("font_color", Color(1.0, 0.48, 0.38) if float(row[1]) < 0.0 else Color(0.82, 1.0, 0.73))
		col.add_child(l)
	var hint := Label.new()
	hint.text = Loc.t("reward.continue")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	col.add_child(hint)
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_close)
	overlay.add_child(btn)
	icons.pivot_offset = Vector2(120, 44)
	icons.scale = Vector2(0.3, 0.3)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(icons, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close() -> void:
	if busy: return
	busy = true
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.tween_property(icons, "scale", Vector2(0.4, 0.4), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(icons, "position:y", icons.position.y - 100.0, 0.4)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(func():
		if is_instance_valid(overlay): overlay.queue_free()
		overlay = null
		busy = false)
