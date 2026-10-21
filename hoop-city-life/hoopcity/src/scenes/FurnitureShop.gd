extends Node2D
## Home & Hearth: furniture for the second floor of your flat. Everything you
## buy is carried home and placed upstairs automatically.

@onready var root: Control = $UI/Root

var money_lbl: Label
var grid: GridContainer

func _ready() -> void:
	Game.profile["last_building"] = "furn"
	UIKit.header(root, Loc.tx("HOME & HEARTH"), Loc.tx("Furnish the second apartment. Buy a piece and it is placed there, ready to use."))
	root.add_child(preload("res://src/ui/StatusBar.tscn").instantiate())

	money_lbl = Label.new()
	money_lbl.add_theme_font_size_override("font_size", 28)
	money_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	money_lbl.position = Vector2(-330, 120)
	money_lbl.custom_minimum_size = Vector2(280, 0)
	money_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(money_lbl)

	var shelf := VBoxContainer.new()
	shelf.set_anchors_preset(Control.PRESET_TOP_LEFT)
	shelf.position = Vector2(56, 200)
	shelf.add_theme_constant_override("separation", 14)
	root.add_child(shelf)

	var floor_lbl := Label.new()
	floor_lbl.add_theme_font_size_override("font_size", 20)
	floor_lbl.custom_minimum_size = Vector2(600, 0)
	floor_lbl.modulate = Color(1, 1, 1, 0.6)
	floor_lbl.text = Loc.tx("Second floor: %s") % (Loc.tx("bought") if Game.profile["home_floor2"] else Loc.tx("not bought yet"))
	shelf.add_child(floor_lbl)

	grid = GridContainer.new()
	grid.columns = clampi(int((root.get_viewport_rect().size.x - 380.0) / 124.0), 3, 6)
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	var gscroll := ScrollContainer.new()
	gscroll.custom_minimum_size = Vector2(grid.columns * 122 + 40,
		maxf(root.get_viewport_rect().size.y - 320.0, 220.0))
	gscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shelf.add_child(gscroll)
	gscroll.add_child(grid)

	UIKit.back_and_phone(root)
	_refresh()

func _refresh() -> void:
	money_lbl.text = Loc.tx("%d$") % Game.profile["money"]
	for c in grid.get_children():
		c.queue_free()
	for id in Items.FURNITURE:
		_tile(id)

func _tile(id: String) -> void:
	var f: Dictionary = Items.furniture(id)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var icon := ItemIcon.new().setup(id, "furniture", 0)
	icon.tooltip_text = Loc.tx(String(f["name"]))
	icon.custom_minimum_size = Vector2(120, 96)
	box.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = Loc.tx(String(f["name"]))
	name_lbl.add_theme_font_size_override("font_size", 19)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_lbl)

	var b := Button.new()
	b.text = Loc.tx("%d$") % int(f["price"])
	b.custom_minimum_size = Vector2(120, 54)
	b.add_theme_font_size_override("font_size", 20)
	if int(f["price"]) > int(Game.profile["money"]):
		b.disabled = true
	else:
		b.pressed.connect(func(): _buy(id))
	box.add_child(b)

	grid.add_child(box)

func _buy(id: String) -> void:
	var f: Dictionary = Items.furniture(id)
	var price: int = int(f["price"])
	if int(Game.profile["money"]) < price:
		Events.toast.emit(Loc.tx("Not enough money"))
		return
	var furn: Array = Game.profile["furniture"]
	if id in furn:
		Events.toast.emit(Loc.tx("Already own %s") % Loc.tx(String(f["name"])))
		return
	Game.add_money(-price)
	furn.append(id)
	SaveSystem.save_game()
	Events.toast.emit(Loc.tx("%s bought · placed in the second apartment") % Loc.tx(String(f["name"])))
	_refresh()
