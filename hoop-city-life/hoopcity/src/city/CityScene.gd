extends Node2D
## Explorable 2D city: day/night tint, street lights, traffic, enterable buildings.

const BUILDINGS := [
	{"id": "home",  "name": "Home",         "pos": Vector2(-760, 60),  "scene": "res://src/scenes/HomeScene.tscn",  "color": Color(0.35, 0.45, 0.62)},
	{"id": "gym",   "name": "Iron Gym",     "pos": Vector2(-260, 60),  "scene": "res://src/scenes/GymScene.tscn",   "color": Color(0.62, 0.38, 0.30)},
	{"id": "court", "name": "Team Court",   "pos": Vector2(300, 60),   "scene": "res://src/scenes/TeamCourt.tscn",  "color": Color(0.30, 0.55, 0.42)},
	{"id": "arena", "name": "Riverside Arena","pos": Vector2(880, 60), "scene": "res://src/scenes/ArenaLobby.tscn",  "color": Color(0.55, 0.35, 0.62)},
	{"id": "shop",  "name": "Fit & Kicks",  "pos": Vector2(-1180, 60), "scene": "res://src/scenes/ShopScene.tscn",  "color": Color(0.66, 0.56, 0.25)},
	{"id": "furn",  "name": "Home & Hearth","pos": Vector2(-1460, 60), "scene": "res://src/scenes/FurnitureShop.tscn",  "color": Color(0.55, 0.50, 0.35)},
	{"id": "books", "name": "Page & Print", "pos": Vector2(1340, 60), "scene": "res://src/scenes/BookShop.tscn", "color": Color(0.42, 0.35, 0.58)},
	{"id": "pets",  "name": "Paws & Claws", "pos": Vector2(1780, 60),  "scene": "res://src/scenes/PetShop.tscn",  "color": Color(0.58, 0.42, 0.30)},
	{"id": "physio","name": "Rehab Lab",    "pos": Vector2(2180, 60),  "scene": "res://src/scenes/PhysioShop.tscn", "color": Color(0.35, 0.62, 0.58)},
	{"id": "park",  "name": "Street Court", "pos": Vector2(620, 60),   "scene": "res://src/scenes/SoloCourt.tscn",  "color": Color(0.38, 0.60, 0.55)},
]

var player: Node2D
var cars: Array = []
var tint: CanvasModulate
var prompt: Label
var near_building: Dictionary = {}
var _last_night := -1.0
var _walk_accum := 0.0
var joystick: VirtualJoystick

const SPEED := 260.0

func _ready() -> void:
	_build_world()
	_build_hud()
	set_process(true)
	CareerEvents.open_if_pending(self)
	_celebrate_title() # festa scudetto: pannello sopra la citta' gia' viva

## Dopo lo scudetto, il primo rientro in citta' e' una FESTA: pannello
## pieno con il trofeo vinto, bonus fanbase e promessa per la prossima.
func _celebrate_title() -> void:
	if not bool(Game.profile.get("celebrate", false)):
		return
	Game.profile["celebrate"] = false
	var layer := CanvasLayer.new()
	add_child(layer)
	var p: GamePanel = GamePanel.new().build("CAMPIONI!", Vector2(880, 640))
	layer.add_child(p)
	p.add_text("Il %s ha vinto il titolo." % Season.my_team(), 26, Color(1.0, 0.85, 0.35))
	p.add_text("Trofei: %d   ·   Stagione %d   ·   +250 followers" % [
		int(Game.profile.get("trophies", 0)), int(Game.profile.get("season_n", 1))],
		21, Color(0.95, 0.95, 0.9))
	p.add_text("La citta' festeggia. Il palmares e' nel telefono, sotto My Card.",
		19, Color(1, 1, 1, 0.6))
	p.add_button("GRAZIE RAGAZZI", func(): p.close(), true)

func _exit_tree() -> void:
	Sfx.stop_rain()

func _build_world() -> void:
	tint = CanvasModulate.new()
	add_child(tint)

	var art := Node2D.new()
	art.set_script(preload("res://src/city/CityVisual.gd"))
	art.buildings = BUILDINGS
	add_child(art)

	player = Node2D.new()
	player.set_script(preload("res://src/city/CityPlayer.gd"))
	# Re-emerge from the door we actually went through. Hard-coding the home
	# door meant leaving the gym teleported you across town to your flat.
	player.position = _spawn_point()
	add_child(player)

	var end_trees := Node2D.new()
	end_trees.set_script(preload("res://src/city/CityEndTrees.gd"))
	add_child(end_trees)

	for i in 8:
		var c := Node2D.new()
		c.set_script(preload("res://src/city/Car.gd"))
		c.setup(randf_range(-1600, 1900), 1 if i % 2 == 0 else -1)
		add_child(c)
		cars.append(c)

	# Passers-by on the pavement, so the street is alive. They walk the same
	# sidewalk as the player and re-tint with the day/night cycle like the cars.
	for i in 9:
		var w := Node2D.new()
		w.set_script(preload("res://src/city/Pedestrian.gd"))
		w.setup(randf_range(-1700, 2400), 1 if i % 2 == 0 else -1)
		add_child(w)

	# The camera is a SIBLING of the player and is followed directly each
	# frame. It used to be parented to the player WITH position smoothing on;
	# smoothing fights a directly-set parent position every frame, which is
	# what made the street view judder once you got walking.
	var cam := Camera2D.new()
	# Raised so the frame is the street + shop roofs, not empty tarmac below.
	cam.zoom = Vector2(0.88, 0.88)
	add_child(cam)
	cam.make_current()

## The sidewalk band: the feet stop at the base of the buildings and lamp
## posts (the top edge of the pavement, y=200) and can never reach the road
## (which starts at y=340). This keeps the player in the same strip the
## pedestrians use, instead of drifting up over the shop fronts.
const SIDEWALK_TOP := 200.0
const SIDEWALK_BOTTOM := 336.0
const LAMP_STEP := 520.0

func _collide_world(pos: Vector2) -> Vector2:
	pos.y = clampf(pos.y, SIDEWALK_TOP, SIDEWALK_BOTTOM)
	pos.x = clampf(pos.x, -1700.0, 2480.0)
	# Lamps are scenery: the player walks straight through them.
	return pos

func _spawn_point() -> Vector2:
	## Re-emerge from the door we actually went through. Hard-coding the home
	## door meant leaving the gym teleported you across town to your flat.
	var last: String = String(Game.profile.get("last_building", ""))
	for b in BUILDINGS:
		if b["id"] == last:
			return b["pos"] + Vector2(0, 150)
	return Vector2(-760, 210)

func _build_hud() -> void:
	# Rain lives on a LOWER canvas so clouds/drops never cover life/level.
	var rain_layer := CanvasLayer.new()
	rain_layer.layer = 8
	add_child(rain_layer)
	var rain_root := Control.new()
	rain_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	rain_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rain_root.set_script(preload("res://src/city/CityWeatherHud.gd"))
	rain_layer.add_child(rain_root)

	var hud := CanvasLayer.new()
	hud.layer = 30
	add_child(hud)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(root)

	joystick = VirtualJoystick.new()
	joystick.set_anchors_preset(Control.PRESET_FULL_RECT)
	joystick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The joystick only listens on the LEFT half of the screen, so tapping
	# ENTER or the phone with the right thumb can never drag the player.
	var left := Control.new()
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.anchor_right = 0.5
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(joystick)
	root.add_child(left)

	var bar := preload("res://src/ui/StatusBar.tscn").instantiate()
	root.add_child(bar)

	# MENU sulla riga della barra (vita/soldi), in alto a destra. Aggiunto
	# DOPO la barra e con z_index alto: nessuno sfondo puo' coprirlo.
	var menu_btn := Button.new()
	menu_btn.text = "MENU"
	menu_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_btn.position = Vector2(-122, 8)
	menu_btn.custom_minimum_size = Vector2(108, 52)
	menu_btn.add_theme_font_size_override("font_size", 18)
	menu_btn.z_index = 100
	menu_btn.pressed.connect(func():
		SaveSystem.save_game()
		SceneRouter.goto("res://src/scenes/MainMenu.tscn"))
	root.add_child(menu_btn)

	prompt = Label.new()
	prompt.add_theme_font_size_override("font_size", 26)
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(-200, -220)
	prompt.custom_minimum_size = Vector2(400, 0)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt)

	var enter := Button.new()
	enter.text = Loc.tx("ENTER")
	enter.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	enter.position = Vector2(-190, -180)
	enter.custom_minimum_size = Vector2(150, 110)
	enter.add_theme_font_size_override("font_size", 24)
	enter.pressed.connect(_enter)
	root.add_child(enter)

	var phone := Button.new()
	# Icona vettoriale (Art.draw_icon): nessuna emoji, identica su ogni device.
	phone.text = ""
	phone.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	phone.position = Vector2(-190, -310)
	phone.custom_minimum_size = Vector2(150, 100)
	phone.draw.connect(func():
		Art.draw_icon(phone, "phone", Rect2(Vector2.ZERO, phone.size), Color(1, 1, 1, 0.96)))
	phone.resized.connect(phone.queue_redraw)
	phone.pressed.connect(func(): SceneRouter.open_phone())
	root.add_child(phone)

func _process(delta: float) -> void:
	player.position = _collide_world(player.position + joystick.output * SPEED * delta)
	# Follow the player with the sibling camera (no smoothing, so no jitter).
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		cam.position = player.position + Vector2(0.0, -210.0)
	# Time advances with DISTANCE walked, not with frames: the old code called
	# Game.advance_time() every single frame while moving (the %30 gate still
	# ran advance_time(0) on the other 29), and each call walked the profile,
	# the buffs, the pets and fired signals -- pure waste that only existed in
	# the city, which is why walking through it stuttered.
	if joystick.output.length() > 0.05:
		_walk_accum += joystick.output.length() * SPEED * delta
		if _walk_accum >= 2400.0:
			_walk_accum = 0.0
			Game.advance_time(1)

	near_building = {}
	for b in BUILDINGS:
		if player.position.distance_to(b["pos"] + Vector2(0, 150)) < 110.0:
			near_building = b
			break
	var ptext: String = ("Enter %s" % near_building["name"]) if near_building else ""
	if prompt.text != ptext:
		prompt.text = ptext

	_update_tint()

func _update_tint() -> void:
	var t := Game.day_t()
	# keyframed day curve: dawn 6h, noon 12h, dusk 19h, night 22h
	var c: Color
	var h := t * 24.0
	if h < 5.5:   c = Color(0.28, 0.32, 0.52)
	elif h < 7.5: c = Color(0.28, 0.32, 0.52).lerp(Color(1.0, 0.86, 0.72), (h - 5.5) / 2.0)
	elif h < 16.5:c = Color(1.0, 0.98, 0.95)
	elif h < 19.5:c = Color(1.0, 0.98, 0.95).lerp(Color(0.95, 0.62, 0.42), (h - 16.5) / 3.0)
	elif h < 21.5:c = Color(0.95, 0.62, 0.42).lerp(Color(0.30, 0.33, 0.55), (h - 19.5) / 2.0)
	else:         c = Color(0.26, 0.30, 0.50)
	# Settle onto the target colour instead of lerping toward it forever: an
	# endless lerp never quite arrives, so every frame counted as "changed"
	# and re-tinted the whole city.
	if tint.color.is_equal_approx(c):
		tint.color = c
	else:
		tint.color = tint.color.lerp(c, 0.05)
		if tint.color.is_equal_approx(c):
			tint.color = c
	var night: float = 1.0 - clampf((c.r + c.g + c.b) / 3.0, 0.0, 1.0)
	# Only notify when the light level has genuinely moved.
	if absf(night - _last_night) < 0.01:
		return
	_last_night = night
	for child in get_children():
		if child.has_method("set_night"):
			child.set_night(night)

func _enter() -> void:
	if near_building.is_empty(): return
	# Remember the door so leaving puts us back on this pavement, not at home.
	Game.profile["last_building"] = near_building["id"]
	SceneRouter.goto(near_building["scene"])
