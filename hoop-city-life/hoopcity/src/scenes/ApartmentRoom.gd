extends Node2D
## The apartment, drawn as an actual room you look at and touch.
## Fridge, bed, wardrobe, TV, shower, desk and window are all real objects
## with their own art and their own interaction panel.

const W := 1600.0
const H := 900.0
const FLOOR_Y := 702.0   # H * 0.78 - everything standing must land exactly here

# Single source of truth for furniture placement. The art AND the clickable
# hotspots both read these, so they can never drift apart again.
const R_SHOWER   := Rect2(40, 348, 190, 354)
const R_FRIDGE   := Rect2(272, 362, 182, 340)
const R_WARDROBE := Rect2(494, 352, 190, 350)
const R_TV       := Rect2(730, 424, 250, 145)   # screen only; stand drawn below
const R_TVSTAND  := Rect2(750, 569, 210, 133)
const R_DESK     := Rect2(1016, 596, 220, 106)
const R_BED       := Rect2(1274, 534, 300, 168)
## The pet strip: the open floor in front of the furniture.
const R_PETS      := Rect2(240, 726, 1080, 150)
const R_WINDOW   := Rect2(1042, 214, 170, 190)
const R_POSTER   := Rect2(300, 140, 150, 190)
const R_LAMP     := Vector2(880, 130)
const R_PLANT    := Vector2(964, 664)
## The staircase to the other apartment (second floor is its own room).
const R_STAIRS   := Rect2(70, 150, 150, 130)

## True when this instance is the bought second apartment, not the main home.
var is_floor2 := false

var night := 0.0
var fridge_open := 0.0        # animated door
var tv_on := false
var tv_flicker := 0.0
var steam := 0.0
var anim_t := 0.0             # free-running clock for the pets
var ui_layer: CanvasLayer      # screen-space: status bar, buttons, modal panels
var spot_layer: CanvasLayer    # scaled to match the room art, holds the hotspots
var hotspots: Control

func _ready() -> void:
	_build_room_ui()
	Events.toast.emit(Loc.tx("Home sweet home"))
	set_process(true)

func _process(delta: float) -> void:
	var t := Game.day_t() * 24.0
	var target: float = 0.0
	if t < 6.0 or t > 20.5: target = 1.0
	elif t < 8.0: target = 1.0 - (t - 6.0) / 2.0
	elif t > 18.5: target = (t - 18.5) / 2.0
	night = lerpf(night, clampf(target, 0.0, 1.0), 2.0 * delta)
	anim_t += delta
	tv_flicker = fmod(tv_flicker + delta * 7.0, TAU)
	steam = maxf(0.0, steam - delta * 0.35)
	queue_redraw()

# ---------------------------------------------------------------- UI + hotspots
func _build_room_ui() -> void:
	ui_layer = CanvasLayer.new()
	# Explicit layer numbers. Both CanvasLayers used to default to 0, and since
	# spot_layer is added second it drew ON TOP of the modal panels: the
	# furniture outlines and their glow bled through an open wardrobe, and the
	# hotspots kept swallowing taps meant for the panel -- tapping a shirt
	# opened the fridge underneath instead.
	ui_layer.layer = 2
	add_child(ui_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	root.add_child(preload("res://src/ui/StatusBar.tscn").instantiate())

	# Hotspots live on their own layer so they can be scaled to line up exactly
	# with the room drawing, while the HUD above stays in screen space.
	spot_layer = CanvasLayer.new()
	spot_layer.layer = 1          # always beneath the modal panels on layer 2
	add_child(spot_layer)
	hotspots = Control.new()
	# The container must be sized to the ART (1600x900), NOT to the viewport.
	# PRESET_FULL_RECT made it as wide as the screen (e.g. 1280), and Godot
	# never delivers input to a child that lies outside its parent's rect --
	# the bed sits at x=1274..1574, so it fell off the end of the container and
	# became permanently unclickable. Everything else happened to fit.
	hotspots.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hotspots.position = Vector2.ZERO
	hotspots.size = Vector2(W, H)
	hotspots.custom_minimum_size = Vector2(W, H)
	hotspots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spot_layer.add_child(hotspots)
	_fit_room()
	call_deferred("_fit_room")
	var _fv: Viewport = get_viewport()
	if _fv != null and not _fv.size_changed.is_connected(_fit_room):
		_fv.size_changed.connect(_fit_room)

	if is_floor2:
		_spot(R_STAIRS, Loc.tx("Stairs"), _open_stairs)
		_spot(R_WINDOW, Loc.tx("Window"), _open_window)
		_build_floor2_spots()
	else:
		_spot(R_FRIDGE, Loc.tx("Fridge"), _open_fridge)
		_spot(R_BED, Loc.tx("Bed"), _open_bed)
		_spot(R_WARDROBE, Loc.tx("Wardrobe"), _open_wardrobe)
		_spot(R_TV, Loc.tx("TV"), _open_tv)
		_spot(R_WINDOW, Loc.tx("Window"), _open_window)
		_spot(R_DESK, Loc.tx("Desk"), _open_desk)
		_spot(R_SHOWER, Loc.tx("Shower"), _open_shower)
		_spot(R_PETS, Loc.tx("Pets"), _open_pets)
		_spot(R_STAIRS, Loc.tx("Stairs"), _open_stairs)

	var leave := Button.new()
	leave.text = Loc.tx("🚪  GO OUTSIDE")
	leave.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	leave.position = Vector2(-320, -120)
	leave.custom_minimum_size = Vector2(280, 84)
	leave.add_theme_font_size_override("font_size", 24)
	leave.pressed.connect(func():
		Game.profile["home_view_floor2"] = false
		SceneRouter.goto("res://src/scenes/CityScene.tscn"))
	root.add_child(leave)

	var phone := Button.new()
	# Icona vettoriale (Art.draw_icon): via l'emoji, ora e' ovunque uguale.
	phone.text = ""
	phone.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	phone.position = Vector2(-120, -230)
	phone.custom_minimum_size = Vector2(90, 90)
	phone.draw.connect(func():
		Art.draw_icon(phone, "phone", Rect2(Vector2.ZERO, phone.size), Color(1, 1, 1, 0.96)))
	phone.resized.connect(phone.queue_redraw)
	phone.pressed.connect(func(): SceneRouter.open_phone())
	root.add_child(phone)


func _fit_room() -> void:
	## La stanza e' un mondo FISSO 1600x900 disegnato 1:1: su schermi piu'
	## bassi (telefono: 720 logici) il fondo spariva (esercizi tagliati).
	## Fit intero: scala per contenere, centra, e risponde a ogni resize.
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var rec: Rect2 = vp.get_visible_rect()
	if rec.size.x <= 0.0 or rec.size.y <= 0.0:
		return
	var s: float = minf(rec.size.x / W, rec.size.y / H)
	if s <= 0.0:
		return
	scale = Vector2(s, s)
	position = ((rec.size - Vector2(W, H) * s) * 0.5).round()
	# SOLO gli hotspot (world-space): i PANNELLI su ui_layer restano piena
	# schermo (letto/frigo/guardaroba usano gia' lo schermo logico).
	if spot_layer != null:
		spot_layer.transform = Transform2D(0.0, scale, 0.0, position)

func _spot(r: Rect2, label: String, cb: Callable) -> void:
	var h := Hotspot.new().setup(r, label)
	h.activated.connect(cb)
	hotspots.add_child(h)

func _panel(title: String, sz := Vector2(900, 760)) -> GamePanel:
	var p := GamePanel.new().build(title, sz)
	ui_layer.add_child(p)
	_set_spots_active(false)
	# Whatever closes the panel -- Back, the X, or a backdrop tap -- the room
	# becomes interactive again. Without this the wardrobe's glowing outlines
	# stayed visible behind the card and stole the taps aimed at it.
	p.tree_exited.connect(func(): _set_spots_active(true))
	return p

func _set_spots_active(on: bool) -> void:
	## Hard on/off for every hotspot: no glow drawn, no input accepted.
	if hotspots == null:
		return
	for h in hotspots.get_children():
		if h is Hotspot:
			h.enabled = on
			h.hovered = false
			h.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
			h.queue_redraw()

# ---------------------------------------------------------------- FRIDGE
func _open_fridge() -> void:
	fridge_open = 1.0
	create_tween().tween_property(self, "fridge_open", 0.0, 6.0)
	var p := _panel("🧊  Fridge")
	_fill_fridge(p)

func _fill_fridge(p: GamePanel) -> void:
	p.clear_body()
	var inv: Dictionary = Game.profile["inventory"]
	var stock := []
	for id in Items.FOOD:
		if int(inv.get(id, 0)) > 0:
			stock.append(id)

	p.add_text("Hunger %d%%   ·   Energy %d%%" % [int(Game.profile["hunger"]), int(Game.profile["energy"])], 22,
		Color(0.7, 0.9, 1.0))
	if stock.is_empty():
		p.add_text("\nThe fridge is empty.\nGrab something from the corner store in the city.", 22,
			Color(1, 1, 1, 0.55))
		p.add_button(Loc.tx("Order a delivery (+3 basics, 25$)"), func():
			if Game.profile["money"] >= 25:
				Game.add_money(-25)
				Items.add("eggs", 1); Items.add("milk", 1); Items.add("water", 1)
				Game.advance_time(30)
				Events.toast.emit(Loc.tx("Delivery arrived"))
				_fill_fridge(p)
			else:
				Events.toast.emit(Loc.tx("Not enough money")), true)
		return

	p.add_text("Tocca per mangiare. Scegli la categoria:", 20, Color(1, 1, 1, 0.5))
	# CATEGORIE come nello shop: cibo / bevande / tutto — niente Liste che
	# escono dai bordi.
	var cats := [["all", "TUTTO"], ["food", "CIBO"], ["drink", "BEVANDE"]]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.body.add_child(row)
	var fridge_ref := [p, stock, inv]
	for c in cats:
		var cid: String = c[0]
		var b := Button.new()
		b.text = c[1]
		b.custom_minimum_size = Vector2(170, 64)
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(func(): _fill_fridge_cat(fridge_ref[0], fridge_ref[1], fridge_ref[2], cid))
		row.add_child(b)
	_fill_fridge_cat(p, stock, inv, "all")

func _fill_fridge_cat(p: GamePanel, stock: Array, inv: Dictionary, cat: String) -> void:
	# pulisci la griglia precedente (tutto dopo la riga categorie)
	var kids := p.body.get_children()
	var cut := -1
	for i in kids.size():
		if kids[i] is GridContainer:
			cut = i
			break
	if cut >= 0:
		for i in range(cut, kids.size()):
			kids[i].queue_free()
	var shown: Array = []
	for id in stock:
		if cat == "all" or (cat == "drink" and id in Items.DRINKS) \
		or (cat == "food" and not id in Items.DRINKS):
			shown.append(id)
	if shown.is_empty():
		p.add_text("Vuoto in questa categoria.", 19, Color(1, 1, 1, 0.45))
		return
	var grid := p.add_grid(p.columns_for(108.0))
	for id in shown:
		var icon := ItemIcon.new().setup(id, "food", int(inv[id]))
		var f: Dictionary = Items.food(id)
		icon.gui_input.connect(func(e):
			if (e is InputEventScreenTouch and e.pressed) \
			or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
				_confirm_eat(id, p))
		icon.tooltip_text = "%s\n%s" % [Loc.tx(String(f.get("name", ""))), Loc.tx(String(f.get("desc", "")))]
		grid.add_child(icon)

	p.add_text("")
	p.add_text("Buffs active:", 20, Color(1, 0.9, 0.5))
	var buffs: Dictionary = Game.profile["buffs"]
	if buffs.is_empty():
		p.add_text("  none", 19, Color(1, 1, 1, 0.4))
	for bid in buffs:
		var b: Dictionary = buffs[bid]
		p.add_text("  • %s ×%.2f" % [String(b["stat"]).capitalize(), float(b["mul"])], 19, Color(0.7, 1, 0.8))

func _confirm_eat(id: String, p: GamePanel) -> void:
	var f: Dictionary = Items.food(id)
	p.clear_body()
	p.add_text(Loc.tx(String(f["name"])), 30, Color(1, 0.95, 0.7))
	p.add_text(String(f.get("desc", "")), 20, Color(1, 1, 1, 0.6))
	p.add_text("")
	p.add_text("Hunger  +%d" % int(f["hunger"]), 22)
	p.add_text("Energy  +%d" % int(f["energy"]), 22)
	var b: Array = f.get("buff", [])
	if b.size() == 3:
		p.add_text("Buff    %s ×%.2f for %dh" % [String(b[0]).capitalize(), float(b[1]), int(b[2]) / 60], 22,
			Color(0.7, 1, 0.8))
	p.add_text("")
	p.add_button(Loc.tx("EAT IT"), func():
		var msg: String = Items.consume(id)
		if msg != "": Events.toast.emit(msg)
		_fill_fridge(p), true)
	p.add_button(Loc.tx("Back"), func(): _fill_fridge(p))

# ---------------------------------------------------------------- BED
func _open_bed() -> void:
	## Sleep for a chosen number of hours, or straight through to the morning.
	## Every option states exactly what it costs you in time and what it gives
	## back, and the clock/day roll over properly.
	var p: GamePanel = _panel(Loc.tx("🛏  Bed"), Vector2(860, 620))
	var hunger: float = Game.profile["hunger"]
	var quality: float = clampf(hunger / 100.0, 0.4, 1.0)
	var energy: float = float(Game.profile["energy"])

	p.add_text("Day %d · %s · energy %d/100 · quality %d%%" % [
		int(Game.profile["day"]), Game.clock_string(), int(energy),
		int(quality * 100)], 21, Color(1, 1, 1, 0.75))

	# --- fixed-length naps: pick how many hours you want
	for hrs in [2, 5, 8]:
		var gain: float = 12.5 * float(hrs) * quality
		var wake: int = (int(Game.profile["minutes"]) + hrs * 60) % 1440
		var label: String = "😴  %dh · wake %02d:%02d · +%d" % [
			hrs, wake / 60, wake % 60, int(gain)]
		p.add_button(label, func():
			_do_sleep(hrs * 60, gain, float(hrs) * 1.5)
			p.close())

	# --- straight through to the morning
	var m: int = int(Game.profile["minutes"])
	var to_morning: int = (1440 - m) + 420 if m > 420 else 420 - m
	p.add_button(Loc.tx("💤  Until 07:00 · %dh%02dm · +%d") % [
		to_morning / 60, to_morning % 60, int(100.0 * quality)], func():
		_do_sleep(to_morning, 100.0 * quality, 12.0)
		p.close(), true)

	p.add_button(Loc.tx("Get up"), func(): p.close())

## Advance the clock, restore energy, burn some hunger. One place, so the
## nap buttons and the sleep-through button can never drift apart.
func _do_sleep(mins: int, energy_gain: float, hunger_cost: float) -> void:
	var day_before: int = int(Game.profile["day"])
	Game.advance_time(mins)
	Game.add_energy(energy_gain)
	Game.add_hunger(-hunger_cost)
	# Rest is what undoes a junk-food diet: every hour of sleep heals a little.
	Game.add_health(min(12.0, float(mins) / 60.0 * 4.0))
	SaveSystem.save_game()
	var days: int = int(Game.profile["day"]) - day_before
	if days > 0:
		Events.toast.emit(Loc.tx("Day %d · woke at %s") % [int(Game.profile["day"]), Game.clock_string()])
	else:
		Events.toast.emit(Loc.tx("Slept until %s") % Game.clock_string())

# ---------------------------------------------------------------- STAIRS
func _floor2_slot_rect(i: int) -> Rect2:
	var slots := [280.0, 500.0, 720.0, 940.0, 1160.0, 1380.0]
	var x: float = slots[i % slots.size()]
	return Rect2(x - 70.0, FLOOR_Y - 180.0, 140.0, 180.0)

func _build_floor2_spots() -> void:
	var furn: Array = Game.profile.get("furniture", [])
	for i in furn.size():
		var id: String = String(furn[i])
		var fid: String = id
		var idx: int = i
		_spot(_floor2_slot_rect(i), Loc.tx(String(Items.furniture(id).get("name", id))),
			func(): _use_floor2_item(fid, idx))

func _use_floor2_item(id: String, _idx: int) -> void:
	var f: Dictionary = Items.furniture(id)
	var p := _panel(Loc.tx("  %s") % f.get("name", id), Vector2(760, 420))
	p.add_text("You bought this for the second apartment.\nUse it here — nothing on this floor works until you furnish it.", 20, Color(1, 1, 1, 0.7))
	match id.trim_prefix("ft_"):
		"bed":
			p.add_button(Loc.tx("Lie down (+8 energy)"), func():
				Game.add_energy(8.0)
				Game.advance_time(20)
				Events.toast.emit(Loc.tx("Rested on the extra bed"))
				p.close())
		"shower":
			p.add_button(Loc.tx("Shower (+12 energy)"), func():
				Game.add_energy(12.0)
				Game.advance_time(15)
				Events.toast.emit(Loc.tx("Showered upstairs"))
				p.close())
		"sofa", "armchair":
			p.add_button(Loc.tx("Sit a while (+5 energy)"), func():
				Game.add_energy(5.0)
				Game.advance_time(15)
				Events.toast.emit(Loc.tx("Sat down"))
				p.close())
		"tv":
			p.add_button(Loc.tx("Watch (+6 energy)"), func():
				Game.add_energy(6.0)
				Game.advance_time(30)
				Events.toast.emit(Loc.tx("Watched TV upstairs"))
				p.close())
		"desk":
			p.add_button(Loc.tx("Sit at the desk"), func():
				Events.toast.emit(Loc.tx("Quiet workspace"))
				p.close())
		_:
			p.add_text("Looks good in the room.", 20, Color(1, 1, 1, 0.5))
	p.add_button(Loc.tx("Back"), func(): p.close())

func _open_stairs() -> void:
	if is_floor2:
		Game.profile["home_view_floor2"] = false
		SaveSystem.save_game()
		SceneRouter.goto("res://src/scenes/HomeScene.tscn")
		return
	var owned: bool = bool(Game.profile.get("home_floor2", false))
	if not owned:
		var p := _panel(Loc.tx("🪜  Second apartment"), Vector2(860, 560))
		p.add_text("Stairs lead to another apartment on this floor.", 22, Color(1, 1, 1, 0.8))
		p.add_text("", 10)
		p.add_text("Unlock it for 1000$. It starts empty — buy furniture\nat Home & Hearth to actually use the room.", 20, Color(1, 1, 1, 0.6))
		p.add_text("", 10)
		p.add_button(Loc.tx("BUY APARTMENT  ·  1000$"), func():
			if int(Game.profile["money"]) >= 1000:
				Game.add_money(-1000)
				Game.profile["home_floor2"] = true
				SaveSystem.save_game()
				Events.toast.emit(Loc.tx("Second apartment unlocked"))
				p.close()
				queue_redraw()
			else:
				Events.toast.emit(Loc.tx("You need 1000$")), true)
		p.add_button(Loc.tx("Back"), func(): p.close())
		return
	Game.profile["home_view_floor2"] = true
	SaveSystem.save_game()
	SceneRouter.goto("res://src/scenes/HomeScene.tscn")

# ---------------------------------------------------------------- WARDROBE
func _open_wardrobe() -> void:
	var p := _panel("👕  Wardrobe")
	_fill_wardrobe(p)

func _fill_wardrobe(p: GamePanel) -> void:
	p.clear_body()
	var owned: Array = Game.profile["owned"]
	# Every wearable slot, not just tops and shoes -- shorts, hats and glasses
	# were buyable but there was no way to actually put them on.
	const SLOT_NAMES := {
		"jersey": "Tops", "shorts": "Shorts", "shoes": "Shoes",
		"hat": "Hats", "glasses": "Glasses", "acc": "Accessories"}
	for slot in ["jersey", "shorts", "shoes", "hat", "glasses", "acc"]:
		p.add_text(String(SLOT_NAMES.get(slot, slot)), 26, Color(0.7, 0.9, 1.0))
		# Column count from the real screen width: 5 fixed 104px icons plus
		# margins overflowed the card on short landscape tablets.
		var grid := p.add_grid(p.columns_for(116.0))
		var any := false
		for id in Items.WEAR:
			var w: Dictionary = Items.wear(id)
			if String(w.get("slot", "")) != slot: continue
			if not id in owned: continue
			any = true
			var icon := ItemIcon.new().setup(id, "wear", 0)
			icon.selected = (Game.profile["outfit"].get(slot, "") == id)
			icon.gui_input.connect(func(e):
				if (e is InputEventScreenTouch and e.pressed) \
				or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
					Game.profile["outfit"][slot] = id
					var wb: Array = w.get("buff", [])
					if wb.size() == 2:
						Game.add_buff("wear_" + id, String(wb[0]), float(wb[1]), 100000)
					SaveSystem.save_game()
					Events.toast.emit(Loc.tx("Wearing %s") % w["name"])
					_fill_wardrobe(p))
			grid.add_child(icon)
		if not any:
			p.add_text("  nothing here yet", 19, Color(1, 1, 1, 0.4))
		p.add_text("")

# ---------------------------------------------------------------- TV
func _open_tv() -> void:
	tv_on = not tv_on
	if not tv_on:
		Events.toast.emit(Loc.tx("TV off"))
		return
	var p := _panel(Loc.tx("📺  Highlights"), Vector2(880, 620))
	var games: Array = Game.profile["last_games"]
	if games.is_empty():
		p.add_text("Nothing about you on air yet.\nGo play a game.", 22, Color(1, 1, 1, 0.55))
	else:
		p.add_text("SPORTS DESK — recent form", 24, Color(1, 0.85, 0.4))
		for g in games:
			p.add_text("Day %d   %d pts · %d ast · %d reb   grade %s   %s" % [
				g["day"], g["pts"], g["ast"], g["reb"], g["grade"], Loc.tx("WIN") if g["won"] else Loc.tx("LOSS")], 20)
	p.add_text("")
	p.add_button(Loc.tx("Watch for an hour (relax, +8 energy)"), func():
		Game.advance_time(60)
		Game.add_energy(8.0)
		Game.add_hunger(-4.0)
		Events.toast.emit(Loc.tx("Chilled out for an hour"))
		p.close())

# ---------------------------------------------------------------- PETS
func _open_pets() -> void:
	var p: GamePanel = _panel(Loc.tx("🐾  Pets"), Vector2(880, 700))
	var list: Array = Pets.owned()
	if list.is_empty():
		p.add_text("No animals here yet. Paws & Claws is at the east end of town.",
			22, Color(1, 1, 1, 0.7))
		p.add_button(Loc.tx("Close"), func(): p.close())
		return

	var msgs: int = Pets.messes().size()
	p.add_text("Company bonus %+.1f energy per day" % Pets.company_bonus(), 22,
		Color(0.6, 1.0, 0.7) if Pets.company_bonus() >= 0.0 else Color(1.0, 0.6, 0.5))
	p.add_text("Food in the flat: %d meal(s)" % Pets.food(), 19, Color(1, 1, 1, 0.65))

	for i in list.size():
		var pet: Dictionary = list[i]
		var sp: Dictionary = Pets.SPECIES[String(pet["species"])]
		var hung: int = int(pet["hunger"])
		p.add_text("%s the %s  ·  fullness %d%%" % [pet["name"], sp["name"], hung], 21,
			Color(1, 1, 1, 0.85) if hung > 30 else Color(1.0, 0.65, 0.5))
		var idx: int = i
		p.add_button(Loc.tx("Feed %s") % pet["name"], func():
			if Pets.feed(idx):
				p.close()
				_open_pets())

	if msgs > 0:
		p.add_button(Loc.tx("🧹  Clean up %d mess(es)") % msgs, func():
			Pets.clean_all()
			p.close()
			_open_pets(), true)
	else:
		p.add_text("The floor is clean.", 19, Color(0.6, 1.0, 0.7))
	p.add_button(Loc.tx("Close"), func(): p.close())

# ---------------------------------------------------------------- WINDOW
func _open_window() -> void:
	var p := _panel(Loc.tx("🪟  Window"), Vector2(760, 520))
	p.add_text("Day %d · %s · %s" % [Game.profile["day"], Game.clock_string(), Game.daypart().capitalize()], 26)
	p.add_text(Game.weather_label(), 24, Color(0.75, 0.88, 1.0))
	var t := Game.day_t() * 24.0
	var wx: String = Game.weather()
	var view := Loc.tx("The street is quiet.")
	if wx == "rain":
		view = "Rain on the glass. Grey roofs, wet pavement, the courts look empty."
	elif wx == "snow":
		view = "Snow drifting past the pane. The street is muffled and white."
	elif wx == "cloudy":
		view = "A low grey ceiling. Soft light, no shadows on the street."
	elif t > 7 and t < 10: view = "Morning traffic is building up. People heading to work."
	elif t >= 10 and t < 17: view = "Bright out. You can see the courts from here."
	elif t >= 17 and t < 21: view = "Golden light on the buildings. Best time to shoot around."
	else: view = "Street lamps on, headlights sliding past. The city hums."
	p.add_text(view, 22, Color(1, 1, 1, 0.7))
	p.add_text("")
	p.add_text("Energy %d%%   Hunger %d%%   Wallet %d$   Rep %d" % [
		int(Game.profile["energy"]), int(Game.profile["hunger"]),
		Game.profile["money"], Game.profile["rep"]], 22, Color(0.7, 0.9, 1.0))

# ---------------------------------------------------------------- DESK
func _open_desk() -> void:
	var p: GamePanel = _panel(Loc.tx("💻  Desk"), Vector2(880, 620))
	p.add_text("Lavori da casa: ogni turno ricarica anche il telefono "
		+ "(%d%% adesso)." % int(Game.profile.get("battery", 100.0)), 20,
		Color(1, 1, 1, 0.6))
	p.add_text("")
	if Game.profile["energy"] < 15:
		p.add_text("You are too tired to focus.", 24, Color(1, 0.6, 0.5))
	else:
		p.add_text("Scegli il lavoro: ogni tipo paga e ricarica in modo diverso.",
			19, Color(1, 1, 1, 0.55))
		p.add_button(Loc.tx("Correzione bozze  ·  6 quiz logici  (2h, −20 energia, +35% batteria)"), func():
			p.close()
			_start_work(), true)
		p.add_button(Loc.tx("Contabilita'  ·  4 conti a mente  (2h, −15 energia, +30% batteria)"), func():
			p.close()
			_start_accounting(), true)
		p.add_button(Loc.tx("Consegne in bici  ·  4 codici a memoria  (2h, −15 energia, +20% batteria)"), func():
			p.close()
			_start_delivery(), true)
	p.add_button(Loc.tx("Review attributes & badges"), func():
		p.close()
		SceneRouter.open_phone())

# ------------------------------------------------------------------ WORK
## Proofreading shift: six small logic puzzles. Each is a short sequence with
## a rule -- doubling, adding, alternating -- and exactly one wrong entry.
## Money is earned per correct answer, so a careless shift genuinely pays less.
var _work_round := 0
var _work_right := 0
var _work_panel: GamePanel = null

func _start_work() -> void:
	_work_round = 0
	_work_right = 0
	_next_work_round()

func _make_puzzle() -> Dictionary:
	## Build a sequence from a random rule, then corrupt exactly one entry.
	var kind: int = randi() % 4
	var start_v: int = 2 + randi() % 9
	var seq: Array = []
	var label := ""
	match kind:
		0:
			var step: int = 2 + randi() % 7
			for i in 6:
				seq.append(start_v + step * i)
			label = "invoice numbers"
		1:
			for i in 6:
				seq.append(start_v * int(pow(2, i)))
			label = "doubling totals"
		2:
			var step2: int = 3 + randi() % 5
			for i in 6:
				seq.append(start_v + step2 * i * (i + 1) / 2)
			label = "running balance"
		_:
			var a: int = start_v
			var b: int = start_v + 1 + randi() % 5
			for i in 6:
				seq.append(a if i % 2 == 0 else b)
			label = "alternating shift codes"
	# corrupt one entry that is not the first, by a visible amount
	var bad_i: int = 1 + randi() % 5
	var delta: int = (1 + randi() % 4) * (1 if randf() < 0.5 else -1)
	var shown: Array = seq.duplicate()
	shown[bad_i] = int(seq[bad_i]) + delta
	return {"shown": shown, "bad": bad_i, "label": label}

func _next_work_round() -> void:
	if _work_round >= 6:
		_finish_work()
		return
	var pz: Dictionary = _make_puzzle()
	_work_panel = _panel(Loc.tx("💻  Job %d of 6") % (_work_round + 1), Vector2(900, 600))
	_work_panel.add_text("Proof the %s. One value is wrong -- tap it."
		% String(pz["label"]), 21, Color(1, 1, 1, 0.72))
	_work_panel.add_text("Correct so far: %d" % _work_right, 18, Color(1, 1, 1, 0.45))
	_work_panel.add_text("")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_work_panel.body.add_child(row)
	var shown: Array = pz["shown"]
	for i in shown.size():
		var b := Button.new()
		b.text = str(shown[i])
		b.custom_minimum_size = Vector2(120, 96)
		b.add_theme_font_size_override("font_size", 26)
		var picked: int = i
		var answer: int = int(pz["bad"])
		b.pressed.connect(func(): _answer_work(picked, answer))
		row.add_child(b)

func _answer_work(picked: int, answer: int) -> void:
	if picked == answer:
		_work_right += 1
		Events.toast.emit(Loc.tx("Correct"))
	else:
		Events.toast.emit(Loc.tx("Missed it -- that one was fine"))
	_work_round += 1
	if _work_panel != null:
		_work_panel.close()
		_work_panel = null
	# let the panel finish closing before the next one opens
	await get_tree().create_timer(0.22).timeout
	_next_work_round()

# ---------------------------------------------------------------- WORK extra
## CONTABILITA': quattro conti a mente (a + b − c). Paga 15$ a conto
## corretto + 10$ se li prendi tutti. Ricarica il telefono del 30%.
var _acct_round := 0
var _acct_right := 0
var _acct_answer := 0

func _start_accounting() -> void:
	_acct_round = 0
	_acct_right = 0
	_next_acct()

func _next_acct() -> void:
	if _acct_round >= 4:
		_finish_acct()
		return
	var a: int = 18 + randi() % 70
	var b: int = 5 + randi() % 40
	var c: int = 3 + randi() % 25
	_acct_answer = a + b - c
	_work_panel = _panel(Loc.tx("💻  Account %d of 4") % (_acct_round + 1), Vector2(900, 560))
	_work_panel.add_text("Mental math, quickly but carefully:", 21, Color(1, 1, 1, 0.72))
	_work_panel.add_text("%d  +  %d  −  %d  =  ?" % [a, b, c], 42, Color(1.0, 0.86, 0.48))
	_work_panel.add_text("Correct so far: %d" % _acct_right, 18, Color(1, 1, 1, 0.45))
	var opts: Array = [_acct_answer, _acct_answer + 1 + randi() % 6, _acct_answer - 1 - randi() % 6]
	opts.shuffle()
	for v in opts:
		var val: int = int(v)
		_work_panel.add_button(str(val), func(): _answer_acct(val), true)

func _answer_acct(v: int) -> void:
	if v == _acct_answer:
		_acct_right += 1
		Events.toast.emit(Loc.tx("Correct"))
	else:
		Events.toast.emit(Loc.tx("Missed it"))
	_acct_round += 1
	if _work_panel != null:
		_work_panel.close()
		_work_panel = null
	await get_tree().create_timer(0.22).timeout
	_next_acct()

func _finish_acct() -> void:
	Game.advance_time(120)
	Game.add_energy(-15.0)
	var pay: int = _acct_right * 15
	if _acct_right == 4:
		pay += 10
	Game.add_money(pay)
	Game.profile["battery"] = clampf(float(Game.profile.get("battery", 100.0)) + 30.0, 0.0, 100.0)
	SaveSystem.save_game()
	var p: GamePanel = _panel(Loc.tx("💻  Shift over"), Vector2(760, 480))
	p.add_text("%d/4 correct  ·  +%d$  ·  phone +30%%" % [_acct_right, pay],
		24, Color(0.7, 1.0, 0.7))
	p.add_button(Loc.tx("Done"), func(): p.close())

## SMISTAMENTO PACCHI: memoria vera — memorizzi il codice del pacco,
## poi lo ricompini. Paga solo se ricordi. Ricarica il telefono del 20%.
var _mem_round := 0
var _mem_right := 0
var _mem_code := ""
var _mem_input: Array = []
var _mem_panel: GamePanel = null
var _mem_display: Label = null

func _start_delivery() -> void:
	_mem_round = 0
	_mem_right = 0
	_next_mem()

func _next_mem() -> void:
	if _mem_round >= 4:
		_finish_mem()
		return
	# codice da 5 cifre (ripetizioni ammesse)
	var code: Array = []
	for i in 5:
		code.append(randi() % 10)
	_mem_code = "".join(code)
	_mem_input = []
	_mem_panel = _panel(Loc.tx("📦  Pacco %d di 4") % (_mem_round + 1), Vector2(900, 620))
	_mem_panel.add_text("Memorizza il codice del pacco:", 21, Color(1, 1, 1, 0.72))
	var big := Label.new()
	big.text = _mem_code
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_font_size_override("font_size", 58)
	big.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	_mem_panel.body.add_child(big)
	_mem_panel.add_text("Tra 2 secondi sparisce: ricompinalo DELL'ORDINE GIUSTO.",
		18, Color(1, 1, 1, 0.5))
	_mem_panel.visible = false
	await get_tree().create_timer(2.0).timeout
	if _mem_panel != null:
		_mem_panel.close()
		_mem_panel = null
	_ask_mem(code)

func _ask_mem(code: Array) -> void:
	_mem_panel = _panel(Loc.tx("📦  Riscrivi il codice"), Vector2(900, 660))
	_mem_display = Label.new()
	_mem_display.text = "_ _ _ _ _"
	_mem_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mem_display.add_theme_font_size_override("font_size", 44)
	_mem_display.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	_mem_panel.body.add_child(_mem_display)
	_mem_panel.add_text("Tocca le cifre nell'ordine giusto (c'e' anche un'esca).",
		19, Color(1, 1, 1, 0.55))
	_mem_panel.add_text("Corretti finora: %d" % _mem_right, 17, Color(1, 1, 1, 0.45))
	# le 5 cifre del codice + 1 esca, MISCHIATE
	var pool: Array = code.duplicate()
	pool.append(randi() % 10)
	pool.shuffle()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_mem_panel.body.add_child(row)
	for v in pool:
		var val: int = int(v)
		var b := Button.new()
		b.text = str(val)
		b.custom_minimum_size = Vector2(110, 92)
		b.add_theme_font_size_override("font_size", 30)
		b.pressed.connect(func(): _tap_mem(val))
		row.add_child(b)

func _tap_mem(v: int) -> void:
	if _mem_input.size() >= 5:
		return
	_mem_input.append(v)
	_mem_display.text = _mem_display_progress()
	if _mem_input.size() >= 5:
		var ok: bool = "".join(_mem_input) == _mem_code
		if ok:
			_mem_right += 1
			Events.toast.emit(Loc.tx("Correct"))
		else:
			Events.toast.emit(Loc.tx("Wrong"))
		_mem_round += 1
		if _mem_panel != null:
			_mem_panel.close()
			_mem_panel = null
		await get_tree().create_timer(0.35).timeout
		_next_mem()

func _mem_display_progress() -> String:
	var parts: PackedStringArray = []
	for i in 5:
		parts.append(str(_mem_input[i]) if i < _mem_input.size() else "_")
	return " ".join(parts)

func _finish_mem() -> void:
	Game.advance_time(120)
	Game.add_energy(-15.0)
	Game.add_hunger(-12.0)
	var pay: int = _mem_right * 12
	if _mem_right == 4:
		pay += 14
	Game.add_money(pay)
	Game.profile["battery"] = clampf(float(Game.profile.get("battery", 100.0)) + 20.0, 0.0, 100.0)
	SaveSystem.save_game()
	var p: GamePanel = _panel(Loc.tx("📦  Turno finito"), Vector2(760, 480))
	p.add_text("%d/4 codici corretti  ·  +%d$  ·  telefono +20%%" % [_mem_right, pay],
		24, Color(0.7, 1.0, 0.7))
	p.add_button(Loc.tx("Done"), func(): p.close())

func _finish_work() -> void:
	Game.advance_time(120)
	Game.add_energy(-20.0)
	Game.add_hunger(-10.0)
	# 12$ a job, plus a bonus for a flawless shift. A guessed shift earns
	# roughly a quarter of what a careful one does.
	var pay: int = _work_right * 12
	if _work_right == 6:
		pay += 25
	Game.add_money(pay)
	Game.profile["battery"] = clampf(float(Game.profile.get("battery", 100.0)) + 35.0, 0.0, 100.0)
	SaveSystem.save_game()
	var p: GamePanel = _panel(Loc.tx("💻  Shift over"), Vector2(760, 480))
	p.add_text("%d of 6 correct" % _work_right, 34,
		Color(0.5, 1.0, 0.6) if _work_right >= 5 else Color(1, 0.85, 0.4))
	p.add_text("Paid %d$%s" % [pay, Loc.tx("  (perfect-shift bonus)") if _work_right == 6 else ""],
		26, Color(1, 0.92, 0.55))
	if _work_right <= 2:
		p.add_text("The agency was not impressed.", 19, Color(1, 0.6, 0.5))
	p.add_text("")
	p.add_button(Loc.tx("Close"), func(): p.close(), true)

# ---------------------------------------------------------------- SHOWER
func _open_shower() -> void:
	steam = 1.0
	Game.advance_time(20)
	Game._roll_weather()
	Game.add_energy(12.0)
	Game.add_buff("fresh", "all", 1.03, 240)
	SaveSystem.save_game()
	Events.toast.emit(Loc.tx("Shower. %s  (+12 energy)") % Game.weather_label())

# ---------------------------------------------------------------- ART
func _draw() -> void:
	var lamp := night   # interior lights come on at night

	# ---- walls & floor
	var wall := Color(0.36, 0.40, 0.50).lerp(Color(0.16, 0.18, 0.26), night)
	draw_rect(Rect2(0, 0, W, FLOOR_Y), wall)
	var floor_c := Color(0.48, 0.36, 0.26).lerp(Color(0.20, 0.16, 0.15), night)
	draw_rect(Rect2(0, FLOOR_Y, W, H - FLOOR_Y), floor_c)
	for i in 30:
		var x := i * 58.0
		draw_line(Vector2(x, FLOOR_Y), Vector2(x - 46, H), Color(0, 0, 0, 0.07), 2)
	draw_rect(Rect2(0, FLOOR_Y - 16, W, 16), wall.darkened(0.28))
	draw_line(Vector2(0, FLOOR_Y), Vector2(W, FLOOR_Y), Color(0, 0, 0, 0.28), 3)

	# soft warm pool from the lamp at night
	if lamp > 0.05:
		for i in 7:
			var rr := 240.0 + i * 95.0
			draw_circle(R_LAMP + Vector2(0, 210), rr, Color(1.0, 0.85, 0.55, 0.018 * lamp))

	_draw_rug()
	_draw_poster()
	_draw_window()
	_draw_stairs()
	if is_floor2:
		_draw_floor2_room()
	else:
		_draw_shower()
		_draw_fridge()
		_draw_wardrobe()
		_draw_tv()
		_draw_desk()
		_draw_bed()
		_draw_plant()
		_draw_pet_gear()
		_draw_pets()
		_draw_messes()
	_draw_lamp(lamp)

	if night > 0.02:
		draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.07, 0.16, 0.30 * night))

## ------------------------------------------------------------------ PETS
## The animals you adopted actually live here: they wander along the floor,
## sleep in the bed you bought them, and leave messes you have to clean.
func _draw_pets() -> void:
	var list: Array = Pets.owned()
	for i in list.size():
		var p: Dictionary = list[i]
		var sp: Dictionary = Pets.SPECIES.get(String(p["species"]), {})
		if sp.is_empty():
			continue
		var sz: float = float(sp["size"])
		var shape: String = String(sp.get("shape", "dog"))
		var hungry: bool = float(p["hunger"]) < 30.0
		var col: Color = Color(sp["col"])
		if hungry:
			col = col.lerp(Color(0.45, 0.42, 0.40), 0.45)

		# Where this animal lives. Birds perch high, fish stay in their tank,
		# everything else walks the floor on its own beat.
		var home_x: float = 300.0 + float(p.get("x", 0.5)) * 900.0
		var speed: float = 0.35 + i * 0.08
		var x: float = home_x + sin(anim_t * speed) * (300.0 + i * 60.0)
		var y: float = FLOOR_Y + 44.0 + i * 12.0
		var facing: float = signf(cos(anim_t * speed))
		if facing == 0.0:
			facing = 1.0

		match shape:
			"bird":
				# perches on a shelf, only shuffling side to side
				x = home_x
				y = FLOOR_Y - 250.0 - i * 8.0
				_draw_pet_bird(Vector2(x, y), sz, col, facing, i)
			"fish":
				x = home_x
				y = FLOOR_Y - 96.0
				_draw_pet_fish(Vector2(x, y), sz, col, i)
			"turtle":
				x = home_x + sin(anim_t * 0.12) * 120.0   # very slow
				_draw_pet_turtle(Vector2(x, y), sz, col, signf(cos(anim_t * 0.12)))
			"snake":
				x = home_x + sin(anim_t * 0.3) * 90.0
				_draw_pet_snake(Vector2(x, y), sz, col, facing)
			"rabbit":
				_draw_pet_rabbit(Vector2(x, y), sz, col, facing, i)
			"hamster":
				_draw_pet_hamster(Vector2(x, y), sz, col, facing, i)
			"lizard":
				_draw_pet_lizard(Vector2(x, y), sz, col, facing)
			"cat":
				_draw_pet_cat(Vector2(x, y), sz, col, facing, i)
			_:
				_draw_pet_dog(Vector2(x, y), sz, col, facing, i)

		# name tag + a bubble when it is hungry
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(x - 30, y + 34), String(p["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.55))
		if hungry:
			draw_circle(Vector2(x, y - 76.0 * sz), 15.0, Color(0.95, 0.85, 0.35, 0.9))
			draw_string(f, Vector2(x - 5, y - 69.0 * sz), "!",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.2, 0.15, 0.05))

func _pet_shadow(c: Vector2, w: float) -> void:
	draw_colored_polygon(_ellipse_pts(c, Vector2(w, w * 0.22)), Color(0, 0, 0, 0.22))

## Dog: long body, upright head, floppy ear, wagging tail, four legs.
func _draw_pet_dog(pos: Vector2, sz: float, col: Color, facing: float, i: int) -> void:
	var bw: float = 64.0 * sz
	var bh: float = 32.0 * sz
	var bob: float = absf(sin(anim_t * 3.2 + i)) * 5.0 * sz
	_pet_shadow(pos + Vector2(0, bh * 0.55), bw * 0.55)
	for lx in [-0.30, -0.10, 0.16, 0.34]:
		draw_line(Vector2(pos.x + bw * lx, pos.y - bob + bh * 0.2),
			Vector2(pos.x + bw * lx, pos.y + bh * 0.45), col.darkened(0.28), 6.0 * sz)
	draw_colored_polygon(_ellipse_pts(pos + Vector2(0, -bob),
		Vector2(bw * 0.5, bh * 0.5)), col)
	var head := Vector2(pos.x + facing * bw * 0.48, pos.y - bob - bh * 0.62)
	draw_circle(head, 16.0 * sz, col.lightened(0.08))
	# snout
	draw_colored_polygon(_ellipse_pts(head + Vector2(facing * 13.0 * sz, 5.0 * sz),
		Vector2(11.0 * sz, 7.0 * sz)), col.lightened(0.16))
	draw_circle(head + Vector2(facing * 21.0 * sz, 3.0 * sz), 3.4 * sz, Color(0.10, 0.09, 0.10))
	# floppy ear
	draw_colored_polygon(_ellipse_pts(head + Vector2(-facing * 8.0 * sz, -4.0 * sz),
		Vector2(7.0 * sz, 13.0 * sz)), col.darkened(0.22))
	draw_circle(head + Vector2(facing * 6.0 * sz, -3.0 * sz), 2.8 * sz, Color(0.08, 0.07, 0.09))
	# wagging tail
	draw_line(Vector2(pos.x - facing * bw * 0.5, pos.y - bob - bh * 0.2),
		Vector2(pos.x - facing * bw * 0.78, pos.y - bob - bh * 0.7 - sin(anim_t * 9.0) * 12.0 * sz),
		col.darkened(0.1), 6.0 * sz)

## Cat: lower and sleeker, pointed ears, long curling tail.
func _draw_pet_cat(pos: Vector2, sz: float, col: Color, facing: float, i: int) -> void:
	var bw: float = 58.0 * sz
	var bh: float = 26.0 * sz
	var bob: float = absf(sin(anim_t * 2.6 + i)) * 3.0 * sz
	_pet_shadow(pos + Vector2(0, bh * 0.6), bw * 0.5)
	for lx in [-0.28, -0.08, 0.14, 0.32]:
		draw_line(Vector2(pos.x + bw * lx, pos.y - bob + bh * 0.15),
			Vector2(pos.x + bw * lx, pos.y + bh * 0.5), col.darkened(0.25), 5.0 * sz)
	draw_colored_polygon(_ellipse_pts(pos + Vector2(0, -bob),
		Vector2(bw * 0.5, bh * 0.5)), col)
	var head := Vector2(pos.x + facing * bw * 0.46, pos.y - bob - bh * 0.75)
	draw_circle(head, 14.0 * sz, col.lightened(0.06))
	# pointed ears
	for e in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			head + Vector2(e * 9.0 * sz, -8.0 * sz),
			head + Vector2(e * 3.0 * sz, -20.0 * sz),
			head + Vector2(e * 13.0 * sz, -14.0 * sz)]), col.darkened(0.15))
	draw_circle(head + Vector2(facing * 5.0 * sz, -1.0 * sz), 2.6 * sz, Color(0.15, 0.55, 0.25))
	# long tail with an S curve
	var t0 := Vector2(pos.x - facing * bw * 0.5, pos.y - bob - bh * 0.1)
	var prev := t0
	for k in 6:
		var f: float = float(k + 1) / 6.0
		var pt := t0 + Vector2(-facing * 34.0 * sz * f,
			-26.0 * sz * f - sin(anim_t * 2.2 + f * 3.0) * 9.0 * sz * f)
		draw_line(prev, pt, col.darkened(0.08), 5.0 * sz)
		prev = pt

## Parrot: upright on a perch, hooked beak, big folded wing, long tail feathers.
func _draw_pet_bird(pos: Vector2, sz: float, col: Color, facing: float, i: int) -> void:
	# the shelf it sits on
	draw_rect(Rect2(pos.x - 60.0, pos.y + 22.0 * sz, 120.0, 10.0), Color(0.42, 0.30, 0.20))
	var sway: float = sin(anim_t * 1.6 + i) * 3.0 * sz
	var bw: float = 26.0 * sz
	var bh: float = 44.0 * sz
	# tail feathers hanging below
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(sway - 6.0 * sz, bh * 0.2),
		pos + Vector2(sway + 6.0 * sz, bh * 0.2),
		pos + Vector2(sway - facing * 10.0 * sz, bh * 0.95)]), col.darkened(0.25))
	# upright body
	draw_colored_polygon(_ellipse_pts(pos + Vector2(sway, 0), Vector2(bw * 0.5, bh * 0.5)), col)
	# folded wing
	draw_colored_polygon(_ellipse_pts(pos + Vector2(sway + facing * 4.0 * sz, 2.0 * sz),
		Vector2(bw * 0.30, bh * 0.34)), col.darkened(0.18))
	# head + hooked beak
	var head := pos + Vector2(sway, -bh * 0.58)
	draw_circle(head, 12.0 * sz, col.lightened(0.10))
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(facing * 9.0 * sz, -2.0 * sz),
		head + Vector2(facing * 20.0 * sz, 2.0 * sz),
		head + Vector2(facing * 9.0 * sz, 7.0 * sz)]), Color(0.95, 0.78, 0.25))
	draw_circle(head + Vector2(facing * 4.0 * sz, -2.0 * sz), 2.4 * sz, Color(0.08, 0.07, 0.09))
	# feet gripping the perch
	for fx in [-4.0, 4.0]:
		draw_line(pos + Vector2(sway + fx * sz, bh * 0.42),
			pos + Vector2(sway + fx * sz, bh * 0.62), Color(0.85, 0.70, 0.30), 3.0 * sz)

## Turtle: domed shell with plates, stumpy legs, small head poking out.
func _draw_pet_turtle(pos: Vector2, sz: float, col: Color, facing: float) -> void:
	if facing == 0.0:
		facing = 1.0
	var sw: float = 56.0 * sz
	var sh: float = 30.0 * sz
	_pet_shadow(pos + Vector2(0, sh * 0.5), sw * 0.5)
	# stumpy legs
	for lx in [-0.30, 0.26]:
		draw_rect(Rect2(pos.x + sw * lx, pos.y + sh * 0.05, 11.0 * sz, 13.0 * sz),
			col.darkened(0.25))
	# head
	var head := Vector2(pos.x + facing * sw * 0.52, pos.y - sh * 0.05)
	draw_colored_polygon(_ellipse_pts(head, Vector2(12.0 * sz, 9.0 * sz)),
		col.lightened(0.22))
	draw_circle(head + Vector2(facing * 5.0 * sz, -2.5 * sz), 2.2 * sz, Color(0.08, 0.07, 0.09))
	# domed shell -- a half ellipse, not a circle
	var dome := PackedVector2Array()
	for k in 21:
		var a: float = PI + PI * float(k) / 20.0
		dome.append(pos + Vector2(cos(a) * sw * 0.5, sin(a) * sh * 0.85))
	dome.append(pos + Vector2(sw * 0.5, 0))
	dome.append(pos + Vector2(-sw * 0.5, 0))
	draw_colored_polygon(dome, col.darkened(0.12))
	# shell plates
	for k in 3:
		var px: float = pos.x - sw * 0.24 + k * sw * 0.24
		draw_line(Vector2(px, pos.y), Vector2(px, pos.y - sh * 0.72),
			col.darkened(0.35), 2.5 * sz)
	draw_line(Vector2(pos.x - sw * 0.42, pos.y - sh * 0.34),
		Vector2(pos.x + sw * 0.42, pos.y - sh * 0.34), col.darkened(0.35), 2.5 * sz)
	# tail
	draw_line(Vector2(pos.x - facing * sw * 0.5, pos.y - sh * 0.05),
		Vector2(pos.x - facing * sw * 0.62, pos.y), col.darkened(0.2), 4.0 * sz)

## Rabbit: tall ears, round body, hops in an arc.
func _draw_pet_rabbit(pos: Vector2, sz: float, col: Color, facing: float, i: int) -> void:
	var hop: float = absf(sin(anim_t * 3.4 + i)) * 22.0 * sz
	var c := pos + Vector2(0, -hop)
	var bw: float = 44.0 * sz
	var bh: float = 34.0 * sz
	_pet_shadow(pos + Vector2(0, bh * 0.4), bw * 0.5 * (1.0 - hop / (40.0 * sz)))
	# hind legs tuck up as it rises
	draw_colored_polygon(_ellipse_pts(c + Vector2(-facing * bw * 0.28, bh * 0.28),
		Vector2(12.0 * sz, 9.0 * sz)), col.darkened(0.18))
	draw_colored_polygon(_ellipse_pts(c, Vector2(bw * 0.5, bh * 0.5)), col)
	var head := c + Vector2(facing * bw * 0.42, -bh * 0.44)
	draw_circle(head, 13.0 * sz, col.lightened(0.06))
	# the long ears -- the whole point of a rabbit
	for e in [-0.35, 0.15]:
		var base := head + Vector2(e * 14.0 * sz, -8.0 * sz)
		var tip := base + Vector2(-facing * 4.0 * sz + e * 6.0 * sz, -30.0 * sz)
		draw_line(base, tip, col.lightened(0.04), 8.0 * sz)
		draw_line(base, tip, Color(0.95, 0.72, 0.74, 0.55), 3.5 * sz)
	draw_circle(head + Vector2(facing * 5.0 * sz, -1.0 * sz), 2.6 * sz, Color(0.35, 0.10, 0.10))
	# puff tail
	draw_circle(c + Vector2(-facing * bw * 0.5, -bh * 0.05), 7.5 * sz, Color(1, 1, 1, 0.92))

## Hamster: a tiny round ball with tiny ears, scurrying.
func _draw_pet_hamster(pos: Vector2, sz: float, col: Color, facing: float, i: int) -> void:
	var r: float = 20.0 * sz
	var scurry: float = sin(anim_t * 9.0 + i) * 2.5 * sz
	var c := pos + Vector2(0, -r * 0.5 + scurry)
	_pet_shadow(pos + Vector2(0, r * 0.35), r * 0.9)
	draw_circle(c, r, col)
	draw_colored_polygon(_ellipse_pts(c + Vector2(0, r * 0.35),
		Vector2(r * 0.75, r * 0.45)), col.lightened(0.14))
	var head := c + Vector2(facing * r * 0.72, -r * 0.15)
	draw_circle(head, r * 0.6, col.lightened(0.08))
	for e in [-1.0, 1.0]:
		draw_circle(head + Vector2(e * r * 0.3, -r * 0.5), r * 0.24, col.darkened(0.2))
	draw_circle(head + Vector2(facing * r * 0.3, -r * 0.1), 2.2 * sz, Color(0.08, 0.07, 0.09))
	draw_circle(head + Vector2(facing * r * 0.55, r * 0.05), 2.0 * sz, Color(0.95, 0.65, 0.68))

## Snake: a coiled S of overlapping segments, no legs at all.
func _draw_pet_snake(pos: Vector2, sz: float, col: Color, facing: float) -> void:
	_pet_shadow(pos + Vector2(0, 6.0 * sz), 46.0 * sz)
	var pts := PackedVector2Array()
	for k in 22:
		var f: float = float(k) / 21.0
		pts.append(pos + Vector2((-0.5 + f) * 96.0 * sz * facing,
			sin(f * TAU + anim_t * 1.6) * 13.0 * sz))
	for k in pts.size() - 1:
		var w: float = lerpf(13.0, 5.0, float(k) / float(pts.size() - 1)) * sz
		draw_line(pts[k], pts[k + 1], col, w)
	# banding
	for k in range(0, pts.size() - 1, 3):
		draw_circle(pts[k], 5.0 * sz, col.darkened(0.28))
	var head: Vector2 = pts[0]
	draw_colored_polygon(_ellipse_pts(head, Vector2(12.0 * sz, 8.0 * sz)), col.lightened(0.10))
	draw_circle(head + Vector2(-facing * 4.0 * sz, -2.5 * sz), 2.2 * sz, Color(0.95, 0.85, 0.2))
	# flicking tongue
	if sin(anim_t * 4.0) > 0.4:
		draw_line(head + Vector2(-facing * 10.0 * sz, 0),
			head + Vector2(-facing * 20.0 * sz, -2.0 * sz), Color(0.9, 0.2, 0.3), 2.0)

## Gecko: flat, wide-footed, splayed legs and a thick tail.
func _draw_pet_lizard(pos: Vector2, sz: float, col: Color, facing: float) -> void:
	var bw: float = 58.0 * sz
	var bh: float = 18.0 * sz
	_pet_shadow(pos + Vector2(0, bh * 0.6), bw * 0.5)
	# splayed legs, bent outward
	for lx in [-0.26, 0.22]:
		for e in [-1.0, 1.0]:
			draw_line(Vector2(pos.x + bw * lx, pos.y),
				Vector2(pos.x + bw * lx + e * 13.0 * sz, pos.y + 11.0 * sz),
				col.darkened(0.22), 4.5 * sz)
	# thick tapering tail
	var tail := PackedVector2Array()
	for k in 10:
		var f: float = float(k) / 9.0
		tail.append(Vector2(pos.x - facing * (bw * 0.5 + f * 42.0 * sz),
			pos.y + sin(f * 3.0 + anim_t * 2.4) * 7.0 * sz))
	for k in tail.size() - 1:
		draw_line(tail[k], tail[k + 1], col.darkened(0.08),
			lerpf(12.0, 3.0, float(k) / 9.0) * sz)
	draw_colored_polygon(_ellipse_pts(pos, Vector2(bw * 0.5, bh * 0.5)), col)
	var head := Vector2(pos.x + facing * bw * 0.56, pos.y - 2.0 * sz)
	draw_colored_polygon(_ellipse_pts(head, Vector2(15.0 * sz, 10.0 * sz)), col.lightened(0.12))
	draw_circle(head + Vector2(facing * 5.0 * sz, -3.5 * sz), 3.0 * sz, Color(0.95, 0.85, 0.2))
	draw_circle(head + Vector2(facing * 5.0 * sz, -3.5 * sz), 1.4 * sz, Color(0.08, 0.07, 0.09))

## Fish: a lit tank on a stand, with fish drifting inside it.
func _draw_pet_fish(pos: Vector2, sz: float, col: Color, i: int) -> void:
	var w: float = 150.0 * sz
	var h: float = 96.0 * sz
	var r := Rect2(pos.x - w * 0.5, pos.y - h * 0.5, w, h)
	# stand
	draw_rect(Rect2(pos.x - w * 0.5, pos.y + h * 0.5, w, 74.0), Color(0.30, 0.22, 0.16))
	# water
	draw_rect(r, Color(0.16, 0.45, 0.62, 0.85))
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 8.0), Color(0.75, 0.92, 1.0, 0.5))
	# gravel
	draw_rect(Rect2(r.position.x, r.end.y - 14.0, r.size.x, 14.0), Color(0.45, 0.40, 0.32))
	# a couple of plants
	for k in 3:
		var px: float = r.position.x + 20.0 + k * 44.0 * sz
		draw_line(Vector2(px, r.end.y - 14.0), Vector2(px + sin(anim_t + k) * 6.0,
			r.end.y - 48.0 * sz), Color(0.20, 0.60, 0.30), 5.0)
	# the fish themselves
	for k in 3:
		var f: float = fmod(anim_t * (0.30 + k * 0.10) + k * 0.4, 1.0)
		var fx: float = lerpf(r.position.x + 18.0, r.end.x - 18.0, f)
		var fy: float = r.position.y + 26.0 + k * 22.0 * sz + sin(anim_t * 2.0 + k) * 6.0
		var dir: float = 1.0 if fmod(anim_t * (0.30 + k * 0.10) + k * 0.4, 2.0) < 1.0 else -1.0
		var fc: Color = col.lightened(k * 0.12)
		draw_colored_polygon(_ellipse_pts(Vector2(fx, fy), Vector2(11.0 * sz, 6.0 * sz)), fc)
		draw_colored_polygon(PackedVector2Array([
			Vector2(fx - dir * 10.0 * sz, fy),
			Vector2(fx - dir * 19.0 * sz, fy - 6.0 * sz),
			Vector2(fx - dir * 19.0 * sz, fy + 6.0 * sz)]), fc.darkened(0.15))
	# glass
	draw_rect(r, Color(0.85, 0.95, 1.0, 0.85), false, 4.0)

## Beds, bowls and toys you bought, sitting against the left wall.
func _draw_pet_gear() -> void:
	var acc: Array = Pets.accessories()
	var bx := 200.0
	for id in acc:
		var ac: Dictionary = Pets.ACCESSORIES.get(String(id), {})
		if ac.is_empty():
			continue
		match String(ac["kind"]):
			"bed":
				draw_colored_polygon(_ellipse_pts(Vector2(bx, FLOOR_Y + 62.0),
					Vector2(64, 26)), Color(0.55, 0.40, 0.26))
				draw_colored_polygon(_ellipse_pts(Vector2(bx, FLOOR_Y + 56.0),
					Vector2(50, 18)), Color(0.72, 0.34, 0.34))
			"hygiene":
				draw_rect(Rect2(bx - 44, FLOOR_Y + 44, 88, 34), Color(0.62, 0.64, 0.70))
				draw_rect(Rect2(bx - 38, FLOOR_Y + 50, 76, 22), Color(0.80, 0.78, 0.68))
			"toy":
				draw_circle(Vector2(bx, FLOOR_Y + 62.0), 14.0, Color(0.85, 0.35, 0.30))
				draw_line(Vector2(bx - 22, FLOOR_Y + 62.0), Vector2(bx + 22, FLOOR_Y + 62.0),
					Color(0.90, 0.78, 0.40), 7.0)
		bx += 150.0
	# food bowl whenever there is food in the flat
	if Pets.food() > 0:
		draw_colored_polygon(_ellipse_pts(Vector2(bx, FLOOR_Y + 62.0), Vector2(34, 15)),
			Color(0.30, 0.55, 0.75))
		draw_colored_polygon(_ellipse_pts(Vector2(bx, FLOOR_Y + 58.0), Vector2(26, 10)),
			Color(0.52, 0.38, 0.22))

## Puddles and piles. Tap one to clean it -- that is the chore loop.
func _draw_messes() -> void:
	var m: Array = Pets.messes()
	for i in m.size():
		var e: Dictionary = m[i]
		var x: float = 200.0 + float(e.get("x", 0.5)) * 1200.0
		var y: float = FLOOR_Y + 96.0 + (i % 3) * 26.0
		if String(e.get("kind", "solid")) == "wet":
			draw_colored_polygon(_ellipse_pts(Vector2(x, y), Vector2(40, 14)),
				Color(0.85, 0.78, 0.35, 0.55))
			draw_colored_polygon(_ellipse_pts(Vector2(x, y), Vector2(26, 9)),
				Color(0.92, 0.86, 0.45, 0.65))
		else:
			for k in 3:
				draw_circle(Vector2(x - 12.0 + k * 12.0, y - k * 5.0),
					11.0 - k * 2.0, Color(0.34, 0.24, 0.16))
		# a faint ring so it reads as tappable
		draw_arc(Vector2(x, y), 34.0, 0, TAU, 20,
			Color(1.0, 0.55, 0.45, 0.30 + 0.20 * sin(anim_t * 3.0 + i)), 2.0)

func _ellipse_pts(c: Vector2, r: Vector2) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 20:
		var a: float = TAU * i / 20.0
		p.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return p

## Contact shadow under a standing object, so nothing looks like it floats.
func _ground_shadow(r: Rect2, spread := 26.0) -> void:
	var y := r.position.y + r.size.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(r.position.x, y),
		Vector2(r.position.x + r.size.x, y),
		Vector2(r.position.x + r.size.x + spread, y + spread * 1.4),
		Vector2(r.position.x - spread * 0.3, y + spread * 1.4)]),
		Color(0, 0, 0, 0.20))

## The staircase on the left wall: drawn as steps rising toward the gallery.
func _draw_stairs() -> void:
	var owned: bool = bool(Game.profile.get("home_floor2", false))
	var c := Color(0.44, 0.34, 0.24).lerp(Color(0.18, 0.14, 0.12), night)
	var up := Color(0.66, 0.52, 0.36).lerp(Color(0.26, 0.20, 0.17), night)
	for i in 6:
		var x0: float = 90.0 + i * 20.0
		var y0: float = 262.0 - i * 20.0
		draw_rect(Rect2(x0, y0, 90, 12), up if owned else c)
	if not owned and not is_floor2:
		draw_line(Vector2(96, 260), Vector2(196, 262), Color(0.9, 0.3, 0.3), 5)
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(88, 140), Loc.tx("DOWN") if is_floor2 else Loc.tx("STAIRS"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.35))

func _draw_floor2_room() -> void:
	var f := ThemeDB.fallback_font
	var furn: Array = Game.profile.get("furniture", [])
	if furn.is_empty():
		draw_string(f, Vector2(420, 420), "Empty apartment — buy furniture at Home & Hearth",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.32))
		return
	for i in furn.size():
		var r: Rect2 = _floor2_slot_rect(i)
		_draw_furniture_piece(String(furn[i]), Vector2(r.position.x + r.size.x * 0.5, FLOOR_Y))

## The second floor, drawn as a gallery along the top of the wall once it is
## bought. Empty at first; every piece of furniture you buy is placed here in
## the order it was bought.
func _draw_upstairs() -> void:
	if not bool(Game.profile.get("home_floor2", false)):
		return
	var wall := Color(0.40, 0.44, 0.55).lerp(Color(0.17, 0.19, 0.27), night)
	var floor_c := Color(0.50, 0.40, 0.30).lerp(Color(0.22, 0.18, 0.16), night)
	draw_rect(Rect2(0, 40, W, 200), wall.darkened(0.12))
	draw_line(Vector2(0, 240), Vector2(W, 240), Color(0, 0, 0, 0.35), 4)
	draw_rect(Rect2(0, 226, W, 14), floor_c.darkened(0.2))
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(24, 66), "UPSTAIRS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
		Color(1, 1, 1, 0.35))
	var furn: Array = Game.profile.get("furniture", [])
	var slots: Array = [280.0, 500.0, 720.0, 940.0, 1160.0, 1380.0]
	for i in mini(furn.size(), slots.size()):
		_draw_furniture_piece(String(furn[i]), Vector2(slots[i], 226.0))
	if furn.is_empty():
		draw_string(f, Vector2(300, 150), "empty floor — furnish me at Home & Hearth",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.28))

## One piece of furniture on the upstairs floor, small and side-on.
func _draw_furniture_piece(id: String, base: Vector2) -> void:
	var col: Color = Color(Items.furniture(id).get("col", Color(0.5, 0.5, 0.5)))
	var k := id.trim_prefix("ft_")
	match k:
		"shower":
			draw_rect(Rect2(base.x - 24, base.y - 110, 48, 110), col, false, 5)
			draw_line(base + Vector2(-8, -60), base + Vector2(0, -14), Color(0.4, 0.8, 1.0), 5)
		"bed":
			draw_rect(Rect2(base.x - 44, base.y - 40, 88, 40), col, true)
			draw_rect(Rect2(base.x - 52, base.y - 62, 20, 62), col.darkened(0.3), true)
			draw_rect(Rect2(base.x - 30, base.y - 30, 60, 12), Color(1, 1, 1, 0.5), true)
		"sofa":
			draw_rect(Rect2(base.x - 44, base.y - 36, 88, 36), col, true)
			draw_rect(Rect2(base.x - 44, base.y - 72, 88, 36), col.darkened(0.25), true)
		"rug":
			draw_colored_polygon(_ellipse_room(base + Vector2(0, -4), Vector2(70, 18)), col)
			draw_colored_polygon(_ellipse_room(base + Vector2(0, -4), Vector2(48, 12)), col.lightened(0.2))
		"wardrobe":
			draw_rect(Rect2(base.x - 26, base.y - 118, 52, 118), col, true)
			draw_line(base + Vector2(0, -118), base + Vector2(0, 0), Color(0, 0, 0, 0.3), 3)
		"armchair":
			draw_rect(Rect2(base.x - 30, base.y - 40, 60, 40), col, true)
			draw_rect(Rect2(base.x - 30, base.y - 76, 60, 36), col.darkened(0.25), true)
		"lamp":
			draw_line(base + Vector2(0, 0), base + Vector2(0, -74), col.darkened(0.4), 5)
			draw_colored_polygon(PackedVector2Array([
				base + Vector2(-20, -64), base + Vector2(20, -64), base + Vector2(0, -92)]), col)
		"plant":
			draw_rect(Rect2(base.x - 12, base.y - 26, 24, 26), Color(0.62, 0.44, 0.30), true)
			draw_circle(base + Vector2(0, -46), 24, col)
		"tv":
			draw_rect(Rect2(base.x - 40, base.y - 66, 80, 52), col, true)
			draw_rect(Rect2(base.x - 14, base.y - 14, 28, 14), Color(0.3, 0.3, 0.35), true)
		"shelf":
			draw_rect(Rect2(base.x - 34, base.y - 116, 68, 116), col, true)
			for i in 4:
				draw_line(base + Vector2(-34, -92 + i * 24), base + Vector2(34, -92 + i * 24),
					Color(0, 0, 0, 0.25), 3)
		"desk":
			draw_rect(Rect2(base.x - 40, base.y - 46, 80, 12), col, true)
			draw_rect(Rect2(base.x - 34, base.y - 34, 10, 34), col.darkened(0.3), true)
			draw_rect(Rect2(base.x + 24, base.y - 34, 10, 34), col.darkened(0.3), true)
		"table":
			draw_rect(Rect2(base.x - 42, base.y - 40, 84, 12), col, true)
			draw_rect(Rect2(base.x - 36, base.y - 28, 10, 28), col.darkened(0.3), true)
			draw_rect(Rect2(base.x + 26, base.y - 28, 10, 28), col.darkened(0.3), true)
		_:
			draw_rect(Rect2(base.x - 30, base.y - 50, 60, 50), col, true)

func _ellipse_room(c: Vector2, r: Vector2) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 18:
		var a: float = TAU * i / 18.0
		p.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return p

func _draw_rug() -> void:
	var c := Vector2(880, 790)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-300, -46), c + Vector2(300, -46),
		c + Vector2(370, 74), c + Vector2(-370, 74)]),
		Color(0.42, 0.28, 0.34).lerp(Color(0.18, 0.13, 0.18), night))
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-246, -30), c + Vector2(246, -30),
		c + Vector2(300, 56), c + Vector2(-300, 56)]),
		Color(0.52, 0.34, 0.40).lerp(Color(0.22, 0.16, 0.22), night))

func _draw_window() -> void:
	var r := R_WINDOW
	var wx: String = WeatherArt.weather()
	var sky := Color(0.55, 0.75, 0.95).lerp(Color(0.05, 0.06, 0.16), night)
	if wx == "rain":
		sky = Color(0.38, 0.42, 0.48).lerp(Color(0.08, 0.09, 0.14), night)
	elif wx == "cloudy":
		sky = Color(0.58, 0.62, 0.68).lerp(Color(0.10, 0.11, 0.16), night)
	elif wx == "snow":
		sky = Color(0.72, 0.78, 0.86).lerp(Color(0.12, 0.14, 0.20), night)
	draw_rect(r, sky)
	for i in 4:
		var bh := 58.0 + i * 20.0
		draw_rect(Rect2(r.position.x + 8 + i * 40, r.position.y + r.size.y - bh, 34, bh),
			Color(0.30, 0.34, 0.44).lerp(Color(0.10, 0.11, 0.18), night))
		if night > 0.3:
			for k in 3:
				if (i + k) % 2 == 0:
					draw_rect(Rect2(r.position.x + 14 + i * 40, r.position.y + r.size.y - bh + 12 + k * 18, 9, 11),
						Color(1.0, 0.88, 0.55, 0.85))
	if wx != "rain" and wx != "cloudy":
		draw_circle(r.position + Vector2(128, 44), 16.0,
			Color(1.0, 0.93, 0.6).lerp(Color(0.92, 0.94, 1.0), night))
	else:
		WeatherArt._cloud(self, r.position + Vector2(50, 36), 28.0, wx == "rain")
		WeatherArt._cloud(self, r.position + Vector2(118, 28), 22.0, wx == "rain")
	if wx == "rain":
		WeatherArt._rain(self, r.position, r.size, r.position.y + r.size.y - 4.0, anim_t)
	elif wx == "snow":
		WeatherArt.draw_sky_weather(self, r.position, r.size, anim_t, r.position.y + r.size.y - 4.0)
	draw_rect(r, Color(0.22, 0.20, 0.20), false, 8.0)
	draw_line(r.position + Vector2(r.size.x * 0.5, 0), r.position + Vector2(r.size.x * 0.5, r.size.y),
		Color(0.22, 0.20, 0.20), 6)
	draw_line(r.position + Vector2(0, r.size.y * 0.5), r.position + Vector2(r.size.x, r.size.y * 0.5),
		Color(0.22, 0.20, 0.20), 6)
	# sunlight pooling on the floor
	if night < 0.6:
		draw_colored_polygon(PackedVector2Array([
			Vector2(r.position.x, FLOOR_Y), Vector2(r.position.x + r.size.x, FLOOR_Y),
			Vector2(r.position.x + r.size.x + 80, H - 40), Vector2(r.position.x - 60, H - 40)]),
			Color(1.0, 0.95, 0.75, 0.09 * (1.0 - night)))

func _draw_fridge() -> void:
	var r := R_FRIDGE
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	var body := Color(0.82, 0.84, 0.88).lerp(Color(0.40, 0.43, 0.50), night)
	_ground_shadow(r)
	draw_rect(r, body)
	draw_rect(r, Color(0, 0, 0, 0.18), false, 3)
	draw_line(Vector2(x, y + 104), Vector2(x + w, y + 104), Color(0, 0, 0, 0.25), 3)

	if fridge_open > 0.01:
		var open_w := w * 0.86 * fridge_open
		draw_rect(Rect2(x + 8, y + 112, w - 16, h - 124), Color(0.90, 0.94, 0.98))
		draw_rect(Rect2(x + 8, y + 112, w - 16, h - 124), Color(1.0, 0.98, 0.85, 0.55 * fridge_open))
		var inv: Dictionary = Game.profile["inventory"]
		var slot := 0
		for id in Items.FOOD:
			if int(inv.get(id, 0)) <= 0: continue
			if slot >= 9: break
			var sx := x + 22 + (slot % 3) * 50
			var sy := y + 146 + int(slot / 3) * 60
			var fc: Color = Items.food(id).get("col", Color.WHITE)
			draw_rect(Rect2(sx, sy, 32, 38), fc)
			draw_rect(Rect2(sx, sy, 32, 38), Color(0, 0, 0, 0.2), false, 1.5)
			slot += 1
		for s in 3:
			draw_line(Vector2(x + 12, y + 138 + s * 60), Vector2(x + w - 12, y + 138 + s * 60),
				Color(0.75, 0.80, 0.88), 2)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, y + 108), Vector2(x - open_w, y + 108 + 16 * fridge_open),
			Vector2(x - open_w, y + h - 16 * fridge_open), Vector2(x, y + h)]),
			body.lightened(0.05))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + 8, y + 116), Vector2(x + w, y + 126),
			Vector2(x + w + 120, FLOOR_Y + 90), Vector2(x - 60, FLOOR_Y + 90)]),
			Color(1.0, 0.96, 0.78, 0.12 * fridge_open))
	else:
		draw_rect(Rect2(x + 10, y + 116, w - 20, h - 128), body.darkened(0.04))
		# photo + magnets: small human touches
		draw_rect(Rect2(x + 28, y + 146, 44, 32), Color(0.95, 0.95, 0.92))
		draw_rect(Rect2(x + 28, y + 146, 44, 32), Color(0.2, 0.2, 0.2), false, 1.5)
		draw_circle(Vector2(x + 116, y + 152), 8, Color(0.85, 0.30, 0.28))
		draw_circle(Vector2(x + 138, y + 176), 7, Color(0.30, 0.60, 0.85))
		draw_rect(Rect2(x + 92, y + 204, 56, 38), Color(0.98, 0.90, 0.35))
		# a note stuck on the door
		draw_line(Vector2(x + 100, y + 216), Vector2(x + 140, y + 216), Color(0.4, 0.4, 0.4), 2)
		draw_line(Vector2(x + 100, y + 226), Vector2(x + 132, y + 226), Color(0.4, 0.4, 0.4), 2)
	draw_rect(Rect2(x + w - 24, y + 28, 9, 58), Color(0.35, 0.37, 0.42))
	draw_rect(Rect2(x + w - 24, y + 134, 9, 88), Color(0.35, 0.37, 0.42))

func _draw_wardrobe() -> void:
	var r := R_WARDROBE
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	var wood := Color(0.50, 0.36, 0.24).lerp(Color(0.22, 0.17, 0.14), night)
	_ground_shadow(r)
	draw_rect(r, wood)
	draw_rect(r, Color(0, 0, 0, 0.25), false, 3)
	draw_line(Vector2(x + w * 0.5, y), Vector2(x + w * 0.5, y + h), Color(0, 0, 0, 0.28), 3)
	for i in 2:
		draw_rect(Rect2(x + 16 + i * 95, y + 24, 62, 132), wood.lightened(0.06))
		draw_rect(Rect2(x + 16 + i * 95, y + 174, 62, 132), wood.lightened(0.06))
	draw_circle(Vector2(x + w * 0.5 - 12, y + h * 0.5), 6, Color(0.85, 0.78, 0.45))
	draw_circle(Vector2(x + w * 0.5 + 12, y + h * 0.5), 6, Color(0.85, 0.78, 0.45))
	# your current jersey hanging on the door
	var jid: String = String(Game.profile["outfit"].get("jersey", "team_home"))
	var jc: Color = Items.wear(jid).get("col", Color(0.2, 0.5, 0.9))
	var hx := x + w + 26
	draw_line(Vector2(hx, y + 36), Vector2(hx, y + 62), Color(0.7, 0.7, 0.75), 3)
	draw_colored_polygon(PackedVector2Array([
		Vector2(hx - 20, y + 66), Vector2(hx + 20, y + 66),
		Vector2(hx + 28, y + 92), Vector2(hx + 14, y + 96),
		Vector2(hx + 14, y + 166), Vector2(hx - 14, y + 166),
		Vector2(hx - 14, y + 96), Vector2(hx - 28, y + 92)]), jc)

func _draw_bed() -> void:
	var r := R_BED
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	_ground_shadow(r, 20.0)
	# frame sits on the floor
	draw_rect(Rect2(x, y + 58, w, r.size.y - 58), Color(0.42, 0.30, 0.22).lerp(Color(0.20, 0.15, 0.13), night))
	# mattress
	draw_rect(Rect2(x + 8, y + 34, w - 16, 76), Color(0.92, 0.92, 0.95).lerp(Color(0.45, 0.48, 0.60), night))
	var duvet := Color(0.30, 0.45, 0.72).lerp(Color(0.15, 0.22, 0.38), night)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + 104, y + 38), Vector2(x + w - 8, y + 34),
		Vector2(x + w - 8, y + 116), Vector2(x + 96, y + 116)]), duvet)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + 104, y + 38), Vector2(x + 168, y + 36),
		Vector2(x + 160, y + 60), Vector2(x + 96, y + 62)]), duvet.lightened(0.18))
	draw_colored_polygon(_round_rect(Rect2(x + 20, y + 38, 84, 42), 12),
		Color(0.97, 0.97, 0.99).lerp(Color(0.55, 0.58, 0.68), night))
	draw_colored_polygon(_round_rect(Rect2(x + 28, y + 26, 78, 38), 12),
		Color(0.99, 0.99, 1.0).lerp(Color(0.60, 0.63, 0.72), night))
	# headboard against the wall
	draw_rect(Rect2(x - 8, y - 46, 22, 150), Color(0.38, 0.27, 0.20).lerp(Color(0.18, 0.14, 0.12), night))

func _draw_tv() -> void:
	var s := R_TVSTAND
	var t := R_TV
	_ground_shadow(s, 18.0)
	draw_rect(s, Color(0.30, 0.24, 0.20).lerp(Color(0.15, 0.13, 0.12), night))
	draw_rect(Rect2(s.position.x + 14, s.position.y + 18, s.size.x - 28, 46), Color(0, 0, 0, 0.18))
	# neck
	draw_rect(Rect2(t.position.x + t.size.x * 0.5 - 18, t.position.y + t.size.y, 36, 20), Color(0.20, 0.20, 0.22))
	draw_rect(t, Color(0.10, 0.11, 0.13))
	var screen := Rect2(t.position.x + 8, t.position.y + 8, t.size.x - 16, t.size.y - 16)
	if tv_on:
		draw_rect(screen, Color(0.25, 0.45, 0.30))
		draw_rect(Rect2(screen.position.x, screen.position.y + screen.size.y * 0.55,
			screen.size.x, screen.size.y * 0.45), Color(0.62, 0.45, 0.26))
		draw_circle(screen.position + Vector2(70 + sin(tv_flicker) * 12, 92), 9, Color(0.9, 0.3, 0.3))
		draw_circle(screen.position + Vector2(150 + cos(tv_flicker * 0.8) * 14, 98), 9, Color(0.3, 0.5, 0.9))
		draw_rect(Rect2(screen.position.x + 10, screen.position.y + 8, 86, 20), Color(0, 0, 0, 0.6))
		draw_rect(screen, Color(1, 1, 1, 0.04 + 0.03 * sin(tv_flicker * 3.0)))
		draw_circle(t.get_center(), 220, Color(0.55, 0.75, 1.0, 0.030))
	else:
		draw_rect(screen, Color(0.06, 0.07, 0.09))
		draw_line(screen.position + Vector2(14, screen.size.y - 16),
			screen.position + Vector2(screen.size.x - 20, 16), Color(1, 1, 1, 0.045), 22)

func _draw_desk() -> void:
	var r := R_DESK
	var x := r.position.x
	var y := r.position.y
	_ground_shadow(r, 14.0)
	draw_rect(Rect2(x, y, r.size.x, 16), Color(0.46, 0.33, 0.23).lerp(Color(0.22, 0.17, 0.14), night))
	draw_rect(Rect2(x + 10, y + 16, 12, r.size.y - 16), Color(0.36, 0.26, 0.18))
	draw_rect(Rect2(x + r.size.x - 22, y + 16, 12, r.size.y - 16), Color(0.36, 0.26, 0.18))
	# laptop
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + 70, y), Vector2(x + 150, y), Vector2(x + 158, y + 10), Vector2(x + 62, y + 10)]),
		Color(0.62, 0.64, 0.70))
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + 74, y), Vector2(x + 146, y), Vector2(x + 150, y - 52), Vector2(x + 70, y - 52)]),
		Color(0.20, 0.22, 0.26))
	draw_rect(Rect2(x + 76, y - 48, 68, 44), Color(0.32, 0.56, 0.86).lerp(Color(0.5, 0.72, 1.0), 0.3))
	# mug
	draw_rect(Rect2(x + 176, y - 22, 22, 24), Color(0.88, 0.35, 0.30))
	draw_arc(Vector2(x + 202, y - 10), 8, -PI * 0.5, PI * 0.5, 10, Color(0.88, 0.35, 0.30), 4)
	# a stack of notes
	draw_rect(Rect2(x + 22, y - 10, 34, 10), Color(0.94, 0.93, 0.88))
	draw_rect(Rect2(x + 24, y - 16, 34, 8), Color(0.90, 0.89, 0.84))

func _draw_shower() -> void:
	var r := R_SHOWER
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	# tiled alcove, standing on the floor
	draw_rect(r, Color(0.72, 0.78, 0.82).lerp(Color(0.28, 0.32, 0.40), night))
	var rows := int(h / 48.0) + 1
	for i in rows:
		draw_line(Vector2(x, y + i * 48), Vector2(x + w, y + i * 48), Color(1, 1, 1, 0.16), 2)
	for i in 5:
		draw_line(Vector2(x + i * 44, y), Vector2(x + i * 44, y + h), Color(1, 1, 1, 0.16), 2)
	draw_rect(r, Color(0, 0, 0, 0.20), false, 3)
	# head + pipe
	draw_line(Vector2(x + w * 0.5, y + 12), Vector2(x + w * 0.5, y + 54), Color(0.60, 0.62, 0.66), 6)
	draw_rect(Rect2(x + w * 0.5 - 18, y + 50, 36, 12), Color(0.72, 0.74, 0.78))
	if steam > 0.01:
		for i in 14:
			var wx := x + w * 0.5 - 16 + randf_range(0, 32)
			draw_line(Vector2(wx, y + 62), Vector2(wx - 3, y + h - 60 + randf_range(-20, 20)),
				Color(0.75, 0.90, 1.0, 0.35 * steam), 2)
		for i in 8:
			draw_circle(Vector2(x + 30 + randf_range(0, w - 60), y + h * 0.5 + randf_range(-50, 60)),
				randf_range(10, 26), Color(1, 1, 1, 0.05 * steam))
	# basin sits at the bottom of the alcove
	draw_colored_polygon(_round_rect(Rect2(x + 6, y + h - 34, w - 12, 30), 10), Color(0.92, 0.94, 0.96))

func _draw_plant() -> void:
	var pos := R_PLANT
	var pot := Rect2(pos.x - 26, pos.y, 52, 56)
	_ground_shadow(pot, 10.0)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-26, 0), pos + Vector2(26, 0),
		pos + Vector2(19, 56), pos + Vector2(-19, 56)]),
		Color(0.66, 0.38, 0.26).lerp(Color(0.30, 0.18, 0.14), night))
	var g := Color(0.28, 0.58, 0.32).lerp(Color(0.13, 0.28, 0.18), night)
	for i in 7:
		var a := -PI * 0.5 + (i - 3) * 0.34
		var tip := pos + Vector2(cos(a), sin(a)) * (62.0 + (i % 3) * 9.0)
		draw_line(pos + Vector2(0, -4), tip, g, 7)
		draw_circle(tip, 9, g.lightened(0.12))

func _draw_poster() -> void:
	## Whatever you bought and hung at Page & Print, drawn by the SHARED poster
	## art so the shop preview and this wall can never disagree.
	var r := R_POSTER
	var id: String = Library.hung()
	if id == "":
		draw_rect(r, Color(0.30, 0.30, 0.36).lerp(Color(0.18, 0.18, 0.24), night))
		draw_rect(r, Color(0, 0, 0, 0.3), false, 3)
		draw_string(ThemeDB.fallback_font, r.position + Vector2(18, r.size.y * 0.55),
			Loc.tx("empty frame"), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 30, 17,
			Color(1, 1, 1, 0.30))
		return
	PosterArt.draw_poster(self, id, r, night, true)

func _draw_lamp(on: float) -> void:
	var pos := R_LAMP
	draw_line(pos, pos + Vector2(0, -70), Color(0.28, 0.28, 0.32), 4)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-42, 0), pos + Vector2(42, 0), pos + Vector2(26, -42), pos + Vector2(-26, -42)]),
		Color(0.85, 0.78, 0.60).lerp(Color(1.0, 0.90, 0.62), on))
	if on > 0.05:
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(-42, 2), pos + Vector2(42, 2),
			pos + Vector2(210, FLOOR_Y - pos.y), pos + Vector2(-210, FLOOR_Y - pos.y)]),
			Color(1.0, 0.90, 0.60, 0.05 * on))

func _round_rect(r: Rect2, rad: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	var corners := [
		[Vector2(r.position.x + rad, r.position.y + rad), PI, PI * 1.5],
		[Vector2(r.position.x + r.size.x - rad, r.position.y + rad), PI * 1.5, TAU],
		[Vector2(r.position.x + r.size.x - rad, r.position.y + r.size.y - rad), 0.0, PI * 0.5],
		[Vector2(r.position.x + rad, r.position.y + r.size.y - rad), PI * 0.5, PI],
	]
	for c in corners:
		for i in 6:
			var a: float = lerpf(c[1], c[2], i / 5.0)
			p.append(c[0] + Vector2(cos(a), sin(a)) * rad)
	return p
