extends Node2D
## Corner store: tabbed shelves of tappable goods.
## Landscape layout - tabs on the left, a wide grid filling the width.

@onready var root: Control = $UI/Root

var money_lbl: Label
var grid: GridContainer
var detail: Label
var tab := "meals"

const TABS := [
	{"id": "meals",   "name": "MEALS"},
	{"id": "junk",    "name": "JUNK FOOD"},
	{"id": "drinks",  "name": "DRINKS"},
	{"id": "supps",   "name": "SUPPLEMENTS"},
	{"id": "jersey",  "name": "TOPS"},
	{"id": "shorts",  "name": "SHORTS"},
	{"id": "shoes",   "name": "SHOES"},
	{"id": "hat",     "name": "HATS"},
	{"id": "glasses", "name": "GLASSES"},
	{"id": "acc",     "name": "ACCESSORIES"},
]

var tab_buttons: Dictionary = {}

func _ready() -> void:
	Game.profile["last_building"] = "shop"
	UIKit.header(root, "FIT & KICKS", "Tap an item to buy it. Gear you own can be worn from the wardrobe.")
	root.add_child(preload("res://src/ui/StatusBar.tscn").instantiate())

	money_lbl = Label.new()
	money_lbl.add_theme_font_size_override("font_size", 28)
	money_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	money_lbl.position = Vector2(-330, 120)
	money_lbl.custom_minimum_size = Vector2(280, 0)
	money_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(money_lbl)

	var cols := HBoxContainer.new()
	cols.set_anchors_preset(Control.PRESET_TOP_LEFT)
	cols.position = Vector2(50, 180)
	cols.add_theme_constant_override("separation", 26)
	root.add_child(cols)

	# left: vertical tab rail
	# Scrollable rail: 8 entries at 62px would overflow a short landscape screen.
	var rail_scroll := ScrollContainer.new()
	rail_scroll.custom_minimum_size = Vector2(258, maxf(root.get_viewport_rect().size.y - 230.0, 180.0))
	# Keep the rail pinned to the top at its minimum height. Without this the
	# HBox stretches (or centres) the scroll viewport against the taller shelf
	# column, which pushed the last tabs and LEAVE off the bottom of short
	# landscape screens.
	rail_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(rail_scroll)
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 8)
	rail.custom_minimum_size = Vector2(250, 0)
	rail_scroll.add_child(rail)
	for t in TABS:
		var b := Button.new()
		b.text = String(t["name"])
		b.custom_minimum_size = Vector2(240, 58)
		b.add_theme_font_size_override("font_size", 20)
		var id: String = String(t["id"])
		b.pressed.connect(func(): _set_tab(id))
		rail.add_child(b)
		tab_buttons[id] = b
	var leave := Button.new()
	leave.text = "LEAVE"
	leave.custom_minimum_size = Vector2(240, 58)
	leave.add_theme_font_size_override("font_size", 20)
	leave.pressed.connect(func(): SceneRouter.goto("res://src/scenes/CityScene.tscn"))
	rail.add_child(leave)

	# right: the shelf
	var shelf := VBoxContainer.new()
	shelf.add_theme_constant_override("separation", 14)
	cols.add_child(shelf)

	# Lo scaffale SCORRE in verticale e le colonne si calcolano dallo spazio
	# vero: 8 colonne fisse tagliavano l'ultima colonna e nascondevano i
	# nuovi item in fondo alle righe.
	grid = GridContainer.new()
	grid.columns = clampi(int((root.get_viewport_rect().size.x - 380.0) / 122.0), 3, 8)
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	var gscroll := ScrollContainer.new()
	gscroll.custom_minimum_size = Vector2(grid.columns * 120 + 40,
		maxf(root.get_viewport_rect().size.y - 300.0, 220.0))
	gscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shelf.add_child(gscroll)
	gscroll.add_child(grid)

	detail = Label.new()
	detail.add_theme_font_size_override("font_size", 20)
	detail.custom_minimum_size = Vector2(900, 70)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.modulate = Color(1, 1, 1, 0.8)
	shelf.add_child(detail)

	UIKit.back_and_phone(root)
	_set_tab("meals")

func _set_tab(id: String) -> void:
	tab = id
	for k in tab_buttons:
		tab_buttons[k].modulate = Color(1, 0.85, 0.4) if k == id else Color(1, 1, 1, 0.7)
	_refresh()

func _ids_for_tab() -> Array:
	match tab:
		"meals":  return Items.meals()
		"junk":   return Items.junk()
		"drinks": return Items.DRINKS
		"supps":  return Items.SUPPLEMENTS
		_:        return Items.wear_by_slot(tab)

func _refresh() -> void:
	money_lbl.text = "%d$" % Game.profile["money"]
	for c in grid.get_children():
		c.queue_free()
	var kind: String = "food" if tab in ["meals", "junk", "drinks", "supps"] else "wear"
	for id in _ids_for_tab():
		var price: int = int((Items.food(id) if kind == "food" else Items.wear(id)).get("price", 0))
		if kind == "wear" and price <= 0 and not (id in Game.profile["owned"]):
			continue
		_tile(id, kind, price)

func _tile(id: String, kind: String, price: int) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var owned: bool = kind == "wear" and id in Game.profile["owned"]
	var have: int = Items.owned_count(id) if kind == "food" else 0
	var icon := ItemIcon.new().setup(id, kind, have)
	icon.selected = owned
	icon.gui_input.connect(func(e):
		if (e is InputEventScreenTouch and e.pressed) \
		or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
			_buy(id, kind, price))
	icon.mouse_entered.connect(func(): _describe(id, kind))
	box.add_child(icon)

	var nm := Label.new()
	nm.text = String((Items.food(id) if kind == "food" else Items.wear(id)).get("name", id))
	nm.add_theme_font_size_override("font_size", 14)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.custom_minimum_size = Vector2(104, 0)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(nm)

	var l := Label.new()
	l.text = "owned" if owned else "%d$" % price
	l.add_theme_font_size_override("font_size", 17)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var afford: bool = Game.profile["money"] >= price
	l.modulate = Color(0.6, 1.0, 0.7) if owned else (Color(1, 0.92, 0.6) if afford else Color(1, 0.5, 0.45))
	box.add_child(l)

	grid.add_child(box)

func _describe(id: String, kind: String) -> void:
	if kind == "food":
		var f: Dictionary = Items.food(id)
		var bits: Array = []
		if int(f.get("hunger", 0)) != 0: bits.append("hunger %+d" % int(f["hunger"]))
		if int(f.get("energy", 0)) != 0: bits.append("energy %+d" % int(f["energy"]))
		if f.has("buff"):
			var b: Array = f["buff"]
			bits.append("%s x%.2f for %dmin" % [String(b[0]), float(b[1]), int(b[2])])
		detail.text = "%s - %s   [%s]" % [f.get("name", id), f.get("desc", ""), ", ".join(bits)]
	else:
		var w: Dictionary = Items.wear(id)
		var extra := ""
		if w.has("buff"):
			var b2: Array = w["buff"]
			extra = "   [%s x%.2f while worn]" % [String(b2[0]), float(b2[1])]
		detail.text = "%s%s" % [w.get("name", id), extra]

func _buy(id: String, kind: String, price: int) -> void:
	if kind == "wear" and id in Game.profile["owned"]:
		Events.toast.emit("You already own that.")
		return
	if Game.profile["money"] < price:
		Events.toast.emit("Not enough money.")
		return
	Game.add_money(-price)
	if kind == "food":
		Items.add(id, 1)
		Events.toast.emit("Bought %s" % Items.food(id)["name"])
	else:
		Game.profile["owned"].append(id)
		# Wear it immediately. Buying a shirt and still looking identical reads
		# as a broken purchase; you can always switch back in the wardrobe.
		var w: Dictionary = Items.wear(id)
		var slot: String = String(w.get("slot", ""))
		if slot != "":
			Game.profile["outfit"][slot] = id
			var wb: Array = w.get("buff", [])
			if wb.size() == 2:
				Game.add_buff("wear_" + id, String(wb[0]), float(wb[1]), 100000)
		Events.toast.emit("Bought & wearing %s" % w["name"])
	Game.advance_time(10)
	SaveSystem.save_game()
	_refresh()
