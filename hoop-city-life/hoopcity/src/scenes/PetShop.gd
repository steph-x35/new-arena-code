extends Node2D
## Paws & Claws -- the pet shop. Buy an animal to keep you company at home,
## plus the beds, bowls and toys that keep it happy.

const W := 1600.0
const H := 900.0

var ui_layer: CanvasLayer
var root: Control
var tabs: HBoxContainer
var list_box: VBoxContainer
var lbl_money: Label
var mode := "pets"
var t := 0.0

func _ready() -> void:
	Game.profile["last_building"] = "pets"
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 2
	add_child(ui_layer)
	_build_ui()
	set_process(true)

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

# ------------------------------------------------------------------ UI
func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(root)

	var head := PanelContainer.new()
	head.set_anchors_preset(Control.PRESET_TOP_WIDE)
	head.custom_minimum_size = Vector2(0, 92)
	root.add_child(head)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	head.add_child(hb)

	var back := Button.new()
	back.text = Loc.tx("< Leave")
	back.custom_minimum_size = Vector2(150, 68)
	back.add_theme_font_size_override("font_size", 22)
	# The city scene lives in src/scenes/, NOT src/city/ (that folder only holds
	# the scripts). The wrong path made load() fail silently and Leave did
	# nothing at all. Every other scene uses this exact path.
	back.pressed.connect(func():
		SaveSystem.save_game()
		SceneRouter.goto("res://src/scenes/CityScene.tscn"))
	hb.add_child(back)

	var title := Label.new()
	title.text = Loc.tx("🐾  Paws & Claws")
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(title)

	lbl_money = Label.new()
	lbl_money.add_theme_font_size_override("font_size", 26)
	lbl_money.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(lbl_money)

	tabs = HBoxContainer.new()
	tabs.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tabs.offset_top = 100
	tabs.offset_left = 24
	tabs.offset_right = -24
	tabs.add_theme_constant_override("separation", 12)
	root.add_child(tabs)
	for pair in [["pets", "Animals"], ["gear", "Beds & Gear"], ["mine", "My Pets"]]:
		var b := Button.new()
		b.text = pair[1]
		b.custom_minimum_size = Vector2(0, 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 24)
		var id: String = pair[0]
		b.pressed.connect(func(): mode = id; _refresh())
		tabs.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 186
	scroll.offset_left = 24
	scroll.offset_right = -24
	scroll.offset_bottom = -24
	root.add_child(scroll)

	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 10)
	scroll.add_child(list_box)

	_refresh()

func _row(title: String, sub: String, price: int, action_label: String,
		cb: Callable, enabled := true) -> void:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(0, 104)
	list_box.add_child(pc)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	pc.add_child(hb)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var l1 := Label.new()
	l1.text = title
	l1.add_theme_font_size_override("font_size", 26)
	vb.add_child(l1)
	var l2 := Label.new()
	l2.text = sub
	l2.add_theme_font_size_override("font_size", 18)
	l2.modulate = Color(1, 1, 1, 0.62)
	vb.add_child(l2)

	if price > 0:
		var pl := Label.new()
		pl.text = Loc.tx("$%d") % price
		pl.add_theme_font_size_override("font_size", 26)
		pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pl.modulate = Color(1, 0.88, 0.4) if Game.profile["money"] >= price else Color(1, 0.45, 0.4)
		hb.add_child(pl)

	var b := Button.new()
	b.text = action_label
	b.custom_minimum_size = Vector2(170, 78)
	b.add_theme_font_size_override("font_size", 22)
	b.disabled = not enabled
	b.pressed.connect(cb)
	hb.add_child(b)

func _refresh() -> void:
	lbl_money.text = Loc.tx("$%d   ·   food x%d") % [int(Game.profile["money"]), Pets.food()]
	for c in list_box.get_children():
		c.queue_free()

	match mode:
		"pets":
			for id in Pets.SPECIES:
				var sp: Dictionary = Pets.SPECIES[id]
				var price: int = int(sp["price"])
				var afford: bool = Game.profile["money"] >= price
				_row(String(sp["name"]), String(sp["desc"]), price,
					Loc.tx("Adopt") if afford else Loc.tx("Too dear"),
					func(): _adopt(String(id)), afford)
		"gear":
			for id in Pets.ACCESSORIES:
				var ac: Dictionary = Pets.ACCESSORIES[id]
				var price: int = int(ac["price"])
				var have: bool = Pets.has_accessory(String(id)) and String(id) != "food_bag"
				var afford: bool = Game.profile["money"] >= price
				var note := ""
				if float(ac["company"]) > 0.0:
					note = "+%.1f company" % float(ac["company"])
				if float(ac["mess_mult"]) < 1.0:
					note = "%d%% less mess" % int((1.0 - float(ac["mess_mult"])) * 100.0)
				if String(id) == "food_bag":
					note = "Ten meals."
				_row(String(ac["name"]), note, price,
					Loc.tx("Owned") if have else (Loc.tx("Buy") if afford else Loc.tx("Too dear")),
					func(): _buy_gear(String(id)), afford and not have)
		"mine":
			var list: Array = Pets.owned()
			if list.is_empty():
				var l := Label.new()
				l.text = Loc.tx("No pets yet. An empty flat is a quiet flat.")
				l.add_theme_font_size_override("font_size", 24)
				l.modulate = Color(1, 1, 1, 0.6)
				list_box.add_child(l)
			for i in list.size():
				var p: Dictionary = list[i]
				var sp: Dictionary = Pets.SPECIES[String(p["species"])]
				_row("%s the %s" % [p["name"], sp["name"]],
					"Fullness %d%%" % int(p["hunger"]), 0,
					"Feed", func(): Pets.feed(i); _refresh(), Pets.food() > 0)
			var msg: int = Pets.messes().size()
			_row("Floor", "%d mess(es) to clean · company bonus %+.1f" % [msg, Pets.company_bonus()],
				0, "Clean up", func(): Pets.clean_all(); _refresh(), msg > 0)

func _adopt(species: String) -> void:
	var panel: GamePanel = GamePanel.new().build("Name your %s" % Pets.SPECIES[species]["name"],
		Vector2(760, 460))
	ui_layer.add_child(panel)
	panel.add_text("Give the animal a name. It will be waiting at your flat.", 20)
	var edit := LineEdit.new()
	edit.placeholder_text = String(Pets.SPECIES[species]["name"])
	edit.custom_minimum_size = Vector2(0, 76)
	edit.add_theme_font_size_override("font_size", 26)
	panel.body.add_child(edit)
	panel.add_button(Loc.tx("Adopt"), func():
		var nm: String = edit.text.strip_edges()
		if nm == "":
			nm = String(Pets.SPECIES[species]["name"])
		if Pets.buy_pet(species, nm):
			panel.close()
			_refresh()
		, true)

func _buy_gear(id: String) -> void:
	if Pets.buy_accessory(id):
		_refresh()

# ------------------------------------------------------------------ art
func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.13, 0.11, 0.16))
	# back wall of stacked cages, warm shop light
	draw_rect(Rect2(0, 190, W, 470), Color(0.20, 0.16, 0.20))
	for row in 3:
		for col in 7:
			var x: float = 90.0 + col * 205.0
			var y: float = 220.0 + row * 150.0
			draw_rect(Rect2(x, y, 178, 128), Color(0.10, 0.09, 0.12))
			draw_rect(Rect2(x, y, 178, 128), Color(0.55, 0.45, 0.30), false, 3.0)
			for b in 6:
				var bx: float = x + 14.0 + b * 26.0
				draw_line(Vector2(bx, y + 6), Vector2(bx, y + 122),
					Color(0.62, 0.56, 0.44, 0.55), 2.0)
			# a small animal shape asleep in some of them
			if (row * 7 + col) % 3 == 0:
				var c := Vector2(x + 89, y + 92)
				var bob: float = sin(t * 1.4 + col) * 3.0
				draw_circle(c + Vector2(0, bob), 22.0, Color(0.55, 0.42, 0.30))
				draw_circle(c + Vector2(26, -6 + bob), 13.0, Color(0.60, 0.46, 0.33))
	# floor
	draw_rect(Rect2(0, 660, W, H - 660), Color(0.24, 0.19, 0.16))
	for i in 12:
		draw_line(Vector2(i * 140.0, 660), Vector2(i * 140.0, H), Color(0, 0, 0, 0.15), 2.0)
	# counter
	draw_rect(Rect2(1120, 600, 400, 110), Color(0.42, 0.29, 0.19))
	draw_rect(Rect2(1120, 590, 400, 20), Color(0.55, 0.39, 0.26))
