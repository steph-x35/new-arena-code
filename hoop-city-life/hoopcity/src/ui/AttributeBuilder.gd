extends VBoxContainer
## Editor condiviso: stesso budget e stesse barre nel creator e nel telefono.

const GROUPS := [
	{"name": "CONCLUSIONE", "color": Color(0.30, 0.64, 1.0), "attrs": ["close", "dunk"]},
	{"name": "TIRO", "color": Color(0.30, 0.85, 0.48), "attrs": ["mid", "three"]},
	{"name": "REGIA", "color": Color(1.0, 0.72, 0.28), "attrs": ["handle", "pass"]},
	{"name": "DIFESA", "color": Color(0.98, 0.35, 0.37), "attrs": ["defense", "steal", "block"]},
	{"name": "RIMBALZI", "color": Color(0.72, 0.43, 0.95), "attrs": ["rebound"]},
	{"name": "FISICO", "color": Color(0.35, 0.82, 0.83), "attrs": ["speed", "accel", "stamina"]},
]
var summary: Label
var sliders := {}
var values := {}
var syncing := false
var effects := {}
var glow_styles := {}
var glow_colors := {}
var save_on_change := false

func build(columns := 1, persist := false) -> void:
	Game.ensure_attribute_builder()
	save_on_change = persist
	add_theme_constant_override("separation", 10)
	summary = Label.new()
	summary.add_theme_font_size_override("font_size", 20)
	summary.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	add_child(summary)
	var hint := Label.new()
	hint.text = "Trascina o usa +/−. Alcune abilità collegate crescono insieme."
	hint.add_theme_font_size_override("font_size", 15)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 12)
	add_child(grid)
	for group in GROUPS:
		var col: Color = group["color"]
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 5)
		grid.add_child(box)
		var title := Label.new()
		title.text = group["name"]
		title.add_theme_font_size_override("font_size", 17)
		title.add_theme_color_override("font_color", col)
		box.add_child(title)
		for key in group["attrs"]:
			var a: String = String(key)
			var value := Label.new()
			value.add_theme_font_size_override("font_size", 16)
			box.add_child(value)
			values[a] = value
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			box.add_child(row)
			var minus := Button.new()
			minus.text = "−"
			minus.custom_minimum_size = Vector2(38, 38)
			minus.pressed.connect(func(): _change(a, -1))
			row.add_child(minus)
			var slider := HSlider.new()
			slider.min_value = 1
			slider.max_value = 99
			slider.step = 1
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.custom_minimum_size = Vector2(100, 38)
			var track := StyleBoxFlat.new()
			track.bg_color = Color(0.16, 0.17, 0.20)
			track.set_corner_radius_all(4)
			track.content_margin_top = 4
			track.content_margin_bottom = 4
			var fill := StyleBoxFlat.new()
			fill.bg_color = col
			fill.set_corner_radius_all(4)
			fill.content_margin_top = 4
			fill.content_margin_bottom = 4
			# Una luce sotto la barra, nel colore del reparto, solo mentre cambia.
			fill.shadow_size = 12
			fill.shadow_offset = Vector2(0, 5)
			fill.shadow_color = Color(col.r, col.g, col.b, 0.0)
			glow_styles[a] = fill
			glow_colors[a] = col
			slider.add_theme_stylebox_override("slider", track)
			slider.add_theme_stylebox_override("grabber_area", fill)
			slider.add_theme_stylebox_override("grabber_area_highlight", fill)
			slider.value_changed.connect(func(v): _set_value(a, int(v)))
			row.add_child(slider)
			sliders[a] = slider
			var plus := Button.new()
			plus.text = "+"
			plus.custom_minimum_size = Vector2(38, 38)
			plus.pressed.connect(func(): _change(a, 1))
			row.add_child(plus)
	_sync()

func _change(a: String, delta: int) -> void:
	var allocated: int = int(Game.profile["attribute_alloc"].get(a, 0))
	_apply(a, allocated + delta)

func _set_value(a: String, target: int) -> void:
	if syncing: return
	var allocated: int = int(Game.profile["attribute_alloc"].get(a, 0))
	_apply(a, allocated + target - Game.attr(a))

func _apply(a: String, target: int) -> void:
	var before := {}
	for key in Game.ATTRS:
		before[key] = Game.attr(key)
	var changed := Game.allocate_attribute(a, target)
	if changed and save_on_change:
		SaveSystem.save_game()
	_sync()
	if changed:
		for key in Game.ATTRS:
			if Game.attr(key) != int(before[key]) and values.has(key):
				_flash_value(String(key))

func _sync() -> void:
	syncing = true
	summary.text = "PUNTI DISPONIBILI  %d" % int(Game.profile.get("attr_points", 0))
	for a in Game.ATTRS:
		if not sliders.has(a): continue
		(sliders[a] as HSlider).set_value_no_signal(Game.attr(a))
		(values[a] as Label).text = "%s  %d" % [Game.ATTR_LABELS[a], Game.attr(a)]
	syncing = false

func _flash_value(a: String) -> void:
	var label: Label = values[a]
	if effects.has(a) and is_instance_valid(effects[a]):
		(effects[a] as Tween).kill()
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.32))
	var fill: StyleBoxFlat = glow_styles[a]
	var col: Color = glow_colors[a]
	fill.shadow_color = Color(col.r, col.g, col.b, 0.85)
	var tween := create_tween().set_parallel(true)
	effects[a] = tween
	tween.tween_property(fill, "shadow_color", Color(col.r, col.g, col.b, 0.0), 0.75)
	tween.tween_method(func(c: Color):
		if is_instance_valid(label): label.add_theme_color_override("font_color", c),
		Color(1.0, 0.84, 0.32), Color.WHITE, 0.65)
