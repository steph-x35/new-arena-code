extends CanvasLayer
## In-game smartphone. Behaves like a real handset:
##   home screen with tappable app icons -> app opens -> BACK returns home
##   -> BACK on the home screen closes the phone.
## There is ALWAYS a way out (on-screen back, the X, the hardware Back key,
## and tapping the dimmed area outside the device).
##
## Landscape-safe: the handset body is sized from the live viewport, so it can
## never be taller than the screen the way the old fixed 560x900 frame was.

## "glyph" e' il nome di un glifo vettoriale di Art.draw_icon: nessuna emoji,
## cosi' le icone sono identiche su ogni dispositivo (gli emoji dipendono dal
## font di sistema e su alcuni Android mancano o escono in bianco).
const APPS := [
	{"id": "messages", "name": "Messages", "col": Color(0.30, 0.80, 0.45), "glyph": "chat"},
	{"id": "social",   "name": "HoopFeed", "col": Color(0.25, 0.62, 0.95), "glyph": "ball"},
	{"id": "calendar", "name": "Calendar", "col": Color(0.95, 0.42, 0.38), "glyph": "calendar"},
	{"id": "shop",     "name": "Store",    "col": Color(0.98, 0.66, 0.25), "glyph": "cart"},
	{"id": "profile",  "name": "My Card",  "col": Color(0.66, 0.45, 0.95), "glyph": "person"},
	{"id": "stats",    "name": "Stats",    "col": Color(0.30, 0.74, 0.78), "glyph": "chart"},
]

## Wallpapers for the handset. Each is a two-tone gradient the frame paints
## behind every app, chosen from the home screen. Stored in
## Game.profile["wallpaper"] so the choice survives save/load.
const WALLPAPERS := {
	"dusk":   {"name": "Dusk",       "top": Color(0.10, 0.14, 0.34), "bottom": Color(0.32, 0.18, 0.36)},
	"night":  {"name": "Night Court","top": Color(0.05, 0.07, 0.15), "bottom": Color(0.12, 0.20, 0.30)},
	"ember":  {"name": "Ember",      "top": Color(0.22, 0.10, 0.08), "bottom": Color(0.46, 0.28, 0.15)},
	"teal":   {"name": "Teal",       "top": Color(0.04, 0.20, 0.22), "bottom": Color(0.14, 0.38, 0.36)},
	"grape":  {"name": "Grape",      "top": Color(0.12, 0.07, 0.22), "bottom": Color(0.30, 0.16, 0.40)},
}

var screen: Control          # the app viewport inside the handset
var frame: PanelContainer    # the handset body; its panel paints the wallpaper
var wallpaper: TextureRect   # the gradient background behind every app
var body: VBoxContainer      # scrolling content of the current app
var title: Label
var clock_lbl: Label
var home_clock: Label
var batt_lbl: Label
var back_btn: Button
var scroll: ScrollContainer

var current_app := "home"
var open_thread := ""        # contact id when reading a conversation

func _ready() -> void:
	layer = 90

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	# Tapping outside the handset puts the phone away.
	dim.gui_input.connect(func(e):
		if (e is InputEventScreenTouch and e.pressed) \
		or (e is InputEventMouseButton and e.pressed):
			SceneRouter.close_phone())
	add_child(dim)

	# Lo SPAZIO LOGICO dello stretch (come GamePanel): get_visible_rect()
	# = ~1520x720 sul telefono; get_viewport_rect() darebbe i PIXEL GREZZI
	# (2280x1080) e il telefono esce dallo schermo sulle tavolette piu'
	# strette. Ecco perche' sul telefono la chat era tagliata.
	var vp: Vector2 = dim.get_viewport().get_visible_rect().size
	# Handset: tall-ish, but always inside the screen with margin to spare.
	var ph: float = clampf(vp.y - 56.0, 240.0, 760.0)
	var pw: float = clampf(ph * 0.62, 300.0, 540.0)

	frame = PanelContainer.new()
	frame.custom_minimum_size = Vector2(pw, ph)
	frame.size = Vector2(pw, ph)
	frame.clip_contents = true
	# TOP_LEFT + piazzamento via codice (come GamePanel): le misure al _ready
	# possono essere FAZIOSE dopo la rotazione (qui era 1280x1280): il
	# piazzamento vero arriva da _place_phone() deferred e a ogni resize.
	frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11)
	sb.border_color = Color(0.32, 0.34, 0.40)
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(34)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	frame.add_theme_stylebox_override("panel", sb)
	add_child(frame)

	# The wallpaper: a gradient TextureRect pinned to the handset's content
	# area, drawn UNDER the app content so it shows behind every screen.
	wallpaper = TextureRect.new()
	wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallpaper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallpaper.stretch_mode = TextureRect.STRETCH_SCALE
	frame.add_child(wallpaper)
	_apply_wallpaper()

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	frame.add_child(col)

	# ---- status bar (clock, day, battery) : the little details sell it
	var status := HBoxContainer.new()
	var fill_l := Control.new()
	fill_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(fill_l)
	# Niente piu' giorno/ora piccoli in alto (richiesta utente): resta solo
	# la batteria. L'orologio e' il grande della home.
	clock_lbl = null
	var fill_r := Control.new()
	fill_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(fill_r)
	batt_lbl = Label.new()
	batt_lbl.text = "%d%%" % int(Game.profile.get("battery", 100.0))
	batt_lbl.add_theme_font_size_override("font_size", 16)
	batt_lbl.modulate = Color(1, 1, 1, 0.7)
	status.add_child(batt_lbl)
	col.add_child(status)

	# ---- app bar: back + title + close
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	back_btn = Button.new()
	back_btn.text = "<"
	back_btn.custom_minimum_size = Vector2(56, 52)
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.pressed.connect(go_back)
	head.add_child(back_btn)

	title = Label.new()
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	head.add_child(title)

	# No X buttons on the top bar: tapping outside the handset puts the
	# phone away (players kept mis-tapping the corner crosses).
	col.add_child(head)

	# ---- app screen
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	# Scrollbar sottile e quasi invisibile: quella di default riempiva
	# un dito di colonna nel telefono stretto.
	var _vs: VScrollBar = scroll.get_v_scroll_bar()
	_vs.modulate = Color(1, 1, 1, 0.22)
	_vs.custom_minimum_size = Vector2(6, 0)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 9)
	scroll.add_child(body)

	# ---- BATTERIA SCARICA: schermo nero, telefono inutilizzabile ----
	if float(Game.profile.get("battery", 100.0)) <= 0.5:
		var dead := ColorRect.new()
		dead.color = Color(0, 0, 0)
		dead.set_anchors_preset(Control.PRESET_FULL_RECT)
		dead.mouse_filter = Control.MOUSE_FILTER_STOP
		frame.add_child(dead)
		# contorno batteria vuoto, appena accennato: capisci il perche'
		dead.draw.connect(func():
			var r := dead.get_rect()
			var c := r.size * 0.5
			dead.draw_rect(Rect2(c - Vector2(46, 22), Vector2(92, 44)),
				Color(1, 1, 1, 0.10), false, 2.0)
			dead.draw_rect(Rect2(c + Vector2(46, -10), Vector2(7, 20)),
				Color(1, 1, 1, 0.10)))
		set_process(false)
		return
	# ---- home indicator: always returns to the app grid
	var homebar := Button.new()
	homebar.text = "———"
	homebar.custom_minimum_size = Vector2(0, 40)
	homebar.add_theme_font_size_override("font_size", 18)
	homebar.pressed.connect(func(): open_app("home"))
	col.add_child(homebar)

	Events.phone_thread_changed.connect(func(_c): if current_app == "messages": _refresh())
	_place_phone()
	call_deferred("_place_phone")
	var _vp: Viewport = get_viewport()
	if _vp != null and not _vp.size_changed.is_connected(_place_phone):
		_vp.size_changed.connect(_place_phone)
	open_app("home")

func _place_phone() -> void:
	## Telefono sempre centrato e MAI fuori schermo (anche dopo rotazioni o
	## con le misure faziose del primo _ready). Stesso pattern di GamePanel.
	if frame == null or not is_instance_valid(frame):
		return
	var live: Viewport = get_viewport()
	if live == null:
		return
	var vp: Vector2 = live.get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var ph: float = clampf(vp.y - 56.0, 240.0, 760.0)
	var pw: float = clampf(ph * 0.62, 300.0, 540.0)
	frame.custom_minimum_size = Vector2(pw, ph)
	frame.size = Vector2(pw, ph)
	frame.pivot_offset = Vector2(pw, ph) * 0.5
	frame.position = ((vp - Vector2(pw, ph)) * 0.5).round()
	frame.position.x = clampf(frame.position.x, 8.0, maxf(8.0, vp.x - pw - 8.0))
	frame.position.y = clampf(frame.position.y, 8.0, maxf(8.0, vp.y - ph - 8.0))

func _unhandled_input(event: InputEvent) -> void:
	## Android Back / Esc walks the stack instead of killing the app.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()

func go_back() -> void:
	if open_thread != "":
		open_thread = ""
		open_app("messages")
	elif current_app != "home":
		open_app("home")
	else:
		SceneRouter.close_phone()

# ------------------------------------------------------------------ helpers
func _clear() -> void:
	for c in body.get_children():
		c.queue_free()

func _txt(t: String, size := 20, col := Color(1, 1, 1, 0.9)) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.modulate = col
	body.add_child(l)
	return l

func _sep() -> void:
	body.add_child(HSeparator.new())

func _row_button(text: String, cb: Callable, tint := Color(1, 1, 1, 1), h := 74) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_size_override("font_size", 20)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.modulate = tint
	b.pressed.connect(cb)
	body.add_child(b)
	return b

func _refresh() -> void:
	open_app(current_app)

# ------------------------------------------------------------------ routing
func _process(_delta: float) -> void:
	# l'orario di gioco avanza mentre il telefono e' aperto (solo home grande)
	if home_clock != null and current_app == "home":
		home_clock.text = Game.clock_string()
	if batt_lbl != null:
		var b: float = float(Game.profile.get("battery", 100.0))
		batt_lbl.text = "%d%%" % int(b)
		batt_lbl.modulate = Color(1.0, 0.42, 0.36, 0.95) if b < 20.0 else Color(1, 1, 1, 0.7)

func open_app(app: String) -> void:
	current_app = app
	# Piazza SINCRONA prima di renderizzare: le bolle si misurano su
	# frame.size e al primo ingresso poteva essere ancora quello stale
	# del _ready (558x900 su rotazione), cosi' la PRIMA chat era
	# "lunghissima" e dopo il primo refresh tornava a posto.
	_place_phone()
	if app != "messages":
		open_thread = ""
	back_btn.text = "<"
	back_btn.visible = app != "home"
	_clear()
	match app:
		"home": title.text = "";              _home()
		"messages": title.text = Loc.t("phone.messages");  _messages()
		"social": title.text = Loc.t("phone.social");    _social()
		"calendar": title.text = Loc.t("phone.calendar");  _calendar()
		"shop": title.text = Loc.t("phone.shop");         _shop()
		"profile": title.text = Loc.t("phone.profile");    _profile()
		"stats": title.text = Loc.t("phone.stats");        _stats()
		"wallpaper": title.text = Loc.t("phone.wallpaper"); _wallpaper()

# ------------------------------------------------------------------ home
func _home() -> void:
	var name: String = String(Game.profile.get("name", "Rookie"))
	# Orologio GRANDE in un chip scuro centrato: impossibile da perdere,
	# qualunque sia lo sfondo del telefono.
	var hchip := PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.07, 0.08, 0.11, 0.94)
	hsb.set_corner_radius_all(20)
	hsb.content_margin_left = 30
	hsb.content_margin_right = 30
	hsb.content_margin_top = 12
	hsb.content_margin_bottom = 12
	hchip.add_theme_stylebox_override("panel", hsb)
	hchip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	home_clock = Label.new()
	home_clock.text = Game.clock_string()
	home_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_clock.add_theme_font_size_override("font_size", 62)
	home_clock.modulate = Color(1, 1, 1, 1.0)
	hchip.add_child(home_clock)
	body.add_child(hchip)
	var sub := Label.new()
	sub.text = "%s  ·  Day %d  ·  %s" % [name, int(Game.profile.get("day", 1)), Game.daypart()]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 17)
	sub.modulate = Color(1, 1, 1, 0.55)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(sub)
	body.add_child(Control.new())

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 18)
	# Fill the whole handset width: the apps spread across the screen like a
	# real launcher instead of huddling in the middle.
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(grid)

	for a in APPS:
		grid.add_child(_app_icon(a))

	_sep()
	var wb := _row_button("      Change wallpaper", func(): open_app("wallpaper"),
		Color(0.85, 0.9, 1.0), 62)
	var wic := Control.new()
	wic.position = Vector2(16, 19)
	wic.size = Vector2(24, 24)
	wic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wic.draw.connect(func(): Art.draw_icon(wic, "image", Rect2(Vector2.ZERO, wic.size), Color.WHITE))
	wb.add_child(wic)

func _app_icon(a: Dictionary) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var b := Button.new()
	b.custom_minimum_size = Vector2(96, 96)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = ""
	# glifo vettoriale centrato nel tile, disegnato dal motore: nitido a ogni
	# DPI e identico su ogni device.
	var ic := Control.new()
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw.connect(func(): Art.draw_icon(ic, String(a["glyph"]),
		Rect2(Vector2(26, 26), ic.size - Vector2(52, 52)), Color(1, 1, 1, 0.96)))
	b.add_child(ic)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(a["col"]) * Color(1, 1, 1, 0.92)
	sb.set_corner_radius_all(20)
	b.add_theme_stylebox_override("normal", sb)
	var sbp := sb.duplicate()
	sbp.bg_color = Color(a["col"]).lightened(0.22)
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_stylebox_override("hover", sbp)
	b.pressed.connect(open_app.bind(String(a["id"])))
	wrap.add_child(b)

	# unread badge on Messages, like a real launcher
	if String(a["id"]) == "messages":
		var n: int = Contacts.total_unread()
		if n > 0:
			var badge := Label.new()
			badge.text = "  ● %d new" % n
			badge.add_theme_font_size_override("font_size", 14)
			badge.modulate = Color(1, 0.45, 0.42)
			wrap.add_child(badge)

	var l := Label.new()
	l.text = Loc.tx(String(a["name"]))
	l.add_theme_font_size_override("font_size", 15)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.modulate = Color(1, 1, 1, 0.8)
	wrap.add_child(l)
	return wrap

# ------------------------------------------------------------------ messages
func _messages() -> void:
	if open_thread != "":
		_thread_view(open_thread)
		return
	var ids: Array = Contacts.contact_ids()
	if ids.is_empty():
		_txt("No contacts yet.", 20, Color(1, 1, 1, 0.5))
		return
	for cid in ids:
		var p: Dictionary = Contacts.PEOPLE[cid]
		var t: Array = Contacts.thread(cid)
		var last: String = "Tap to start a conversation."
		var when := ""
		if not t.is_empty():
			var m: Dictionary = t[t.size() - 1]
			last = String(m["text"])
			if String(m.get("who", "them")) == "me":
				last = "You: " + last
			when = "D%d %s" % [int(m.get("day", 1)), String(m.get("time", ""))]
		# Anteprima UNA riga sola (ellipsis): tutte le righe uguali,
		# niente coach-lunga-3-righe mentre gli altri son corti.
		last = last.replace("\n", " ")
		if last.length() > 34:
			last = last.substr(0, 32) + "..."
		var n: int = Contacts.unread(cid)
		var head: String = String(p["name"])
		if n > 0:
			head += "  ● %d" % n
		var b := _row_button("%s   %s\n%s" % [head, when, last],
			func(): open_thread = cid; _refresh(), Color(1, 1, 1, 1), 84)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.clip_text = true
		b.modulate = Color(p["col"]).lerp(Color.WHITE, 0.45) if n > 0 else Color(1, 1, 1, 0.86)

func _thread_view(cid: String) -> void:
	var p: Dictionary = Contacts.PEOPLE[cid]
	title.text = String(p["name"])
	Contacts.mark_read(cid)

	_txt(String(p["role"]), 15, Color(1, 1, 1, 0.45))
	_sep()

	# Larghezza bolla dal FRAME del telefono (stabile da _ready), MAI dallo
	# scroll: appena aperto scroll.size.x e' ancora 0 e le bolle collassavano
	# in colonne di una-parola-per-riga (le chat "male" sul telefono).
	var maxw: float = clampf(frame.size.x - 96.0, 160.0, 340.0)
	for m in Contacts.thread(cid):
		var mine: bool = String(m.get("who", "them")) == "me"
		var bubble := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.20, 0.42, 0.72) if mine else Color(0.17, 0.19, 0.24)
		sb.set_corner_radius_all(16)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 9
		sb.content_margin_bottom = 9
		bubble.add_theme_stylebox_override("panel", sb)
		bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if mine else Control.SIZE_SHRINK_BEGIN

		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 2)
		var tl := Label.new()
		tl.text = String(m["text"])
		tl.add_theme_font_size_override("font_size", 19)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# la bolla si adatta al testo (corta = stretta, lunga = a capo),
		# ma non sfora MAI oltre maxw, con il margine delle proprie pareti.
		var nat: float = tl.get_theme_default_font().get_string_size(
			tl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		tl.custom_minimum_size = Vector2(clampf(nat + 6.0, 110.0, maxw), 0)
		inner.add_child(tl)
		var st := Label.new()
		st.text = "D%d %s" % [int(m.get("day", 1)), String(m.get("time", ""))]
		st.add_theme_font_size_override("font_size", 13)
		st.modulate = Color(1, 1, 1, 0.45)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		inner.add_child(st)
		bubble.add_child(inner)
		body.add_child(bubble)

	_sep()
	_txt("Reply", 16, Color(1, 1, 1, 0.5))
	for opt in Contacts.reply_options(cid):
		var label: String = String(opt["label"])
		var reply: String = String(opt["reply"])
		_row_button(label, func(): _do_reply(cid, label, reply), Color(0.75, 0.9, 1.0), 62)

func _do_reply(cid: String, mine: String, their: String) -> void:
	Contacts.send(cid, mine)
	_refresh()
	# A human takes a beat before answering; instant replies feel robotic.
	await get_tree().create_timer(0.9).timeout
	if not is_instance_valid(self):
		return
	Contacts.receive(cid, their)
	Contacts.mark_read(cid)
	SaveSystem.save_game()
	if current_app == "messages" and open_thread == cid:
		_refresh()

# ------------------------------------------------------------------ other apps
func _social() -> void:
	var posts: Array = Game.profile["social"]
	if posts.is_empty():
		_txt("Nothing yet. Go play a game.", 20, Color(1, 1, 1, 0.5))
	for p in posts:
		_txt("%s  ·  Day %d %s" % [p["author"], p["day"], p["time"]], 17, Color(0.55, 0.78, 1.0))
		_txt(String(p["text"]), 20)
		var likes_row := HBoxContainer.new()
		likes_row.add_theme_constant_override("separation", 6)
		body.add_child(likes_row)
		for cfg in [["heart", int(p["likes"])], ["chat", int(p["comments"].size())]]:
			var sic := Control.new()
			sic.custom_minimum_size = Vector2(18, 18)
			sic.draw.connect(func(): Art.draw_icon(sic, String(cfg[0]),
				Rect2(Vector2.ZERO, sic.size), Color(1, 1, 1, 0.55)))
			likes_row.add_child(sic)
			var sl := Label.new()
			sl.text = str(cfg[1])
			sl.add_theme_font_size_override("font_size", 15)
			sl.modulate = Color(1, 1, 1, 0.45)
			likes_row.add_child(sl)
		_sep()

func _calendar() -> void:
	var day: int = Game.profile["day"]
	var s: Dictionary = Game.profile["season"]
	_txt("%s   %d-%d" % [Season.my_team(), int(s["wins"]), int(s["games"]) - int(s["wins"])],
		20, Color(1, 0.88, 0.45))
	_txt("%d followers" % Season.followers(), 17, Color(0.6, 0.85, 1.0))
	_sep()

	for e in Season.upcoming(12):
		var d: int = int(e["day"])
		var is_today: bool = d == day
		var kind: String = String(e["kind"])
		var col := Color(1, 1, 1, 0.55)
		match kind:
			"game": col = Color(1.0, 0.55, 0.45)
			"practice": col = Color(0.55, 0.85, 1.0)
			"weights": col = Color(0.98, 0.78, 0.35)
		if is_today:
			col = col.lightened(0.2)

		var tag := ""
		if bool(e.get("skipped", false)):
			tag = "   (skipped)"
		elif bool(e.get("done", false)):
			tag = "   ✓ %s" % String(e.get("result", "done"))

		_txt("Day %d%s" % [d, "   ▸ TODAY" if is_today else ""], 17,
			Color(1, 0.9, 0.4) if is_today else Color(1, 1, 1, 0.45))
		_txt("   " + Season.label_for(e) + tag, 19, col)

		# Today's practice can be attended or skipped right from the phone.
		if is_today and kind == "practice" and not bool(e.get("done", false)):
			_row_button("Go to practice  (+followers)",
				func():
					Season.attend_practice()
					_refresh(), Color(0.7, 1.0, 0.8), 62)
			_row_button("Skip it  (-followers, coach notices)",
				func():
					Season.skip_practice()
					_refresh(), Color(1.0, 0.7, 0.65), 62)
		if is_today and kind == "game" and not bool(e.get("done", false)):
			_row_button("Head to the arena",
				func():
					SceneRouter.close_phone()
					Game.profile["next_match_mode"] = "full"
					Game.profile["match_is_fixture"] = true
					SceneRouter.goto("res://src/match/MatchScene.tscn"),
				Color(1.0, 0.85, 0.6), 62)
		body.add_child(HSeparator.new())

func _shop() -> void:
	_txt("Wallet: %d$" % Game.profile["money"], 24, Color(0.6, 1.0, 0.7))
	_txt("Delivered straight to your apartment.", 16, Color(1, 1, 1, 0.5))
	_sep()
	var owned: Array = Game.profile["owned"]
	var listed := 0
	for id in Items.WEAR:
		if id in owned:
			continue
		var w: Dictionary = Items.wear(id)
		listed += 1
		if listed > 10:
			break
		var price: int = int(w["price"])
		_row_button("%s\n%d$  ·  %s" % [w["name"], price, String(w["slot"])],
			func():
				if Game.profile["money"] >= price:
					Game.add_money(-price)
					Game.profile["owned"].append(id)
					Events.toast.emit("Delivered: %s" % w["name"])
					Game.advance_time(10)
					SaveSystem.save_game()
					_refresh()
				else:
					Events.toast.emit("Not enough money."), Color(1, 1, 1, 0.9), 78)
	if listed == 0:
		_txt("You own everything in stock.", 19, Color(1, 1, 1, 0.5))

func _profile() -> void:
	var p: Dictionary = Game.profile
	_txt("%s  #%d" % [p["name"], p["jersey"]], 26, Color(1, 0.9, 0.4))
	_txt("%s  ·  %d cm  ·  %d kg" % [p["position"], p["height_cm"], p["weight_kg"]], 18, Color(1, 1, 1, 0.7))
	_txt("Level %d   XP %d/%d" % [p["level"], p["xp"], Game.xp_for_next_level()], 19)
	_txt("Rep %d   %d$   Energy %d   Hunger %d" % [p["rep"], p["money"], int(p["energy"]), int(p["hunger"])], 19)
	_sep()
	# PALMARES: trofei vinti e stagioni archiviate.
	var tro: int = int(p.get("trophies", 0))
	_txt("PALMARES", 20, Color(1.0, 0.8, 0.4))
	_txt("Trofei: %d   ·   Stagione %d in corso" % [tro, int(p.get("season_n", 1))], 19,
		Color(1.0, 0.9, 0.4) if tro > 0 else Color(1, 1, 1, 0.75))
	for a in p.get("awards", []):
		var t: String = "MVP" if String(a["type"]) == "mvp" else "Capocannoniere"
		_txt("%s S%d   (%s ppg)" % [t, int(a["n"]), str(a.get("ppg", 0.0))],
			16, Color(1.0, 0.85, 0.35))
	for a in p.get("season_archive", []):
		_txt("S%d   %dV-%dS   %d pts   high %d" % [int(a["n"]), int(a["wins"]),
			int(a["games"]) - int(a["wins"]), int(a["pts"]), int(a["high_pts"])],
			16, Color(1, 1, 1, 0.65))
	if (p.get("season_archive", []) as Array).is_empty() and tro == 0:
		_txt("Ancora nessuna stagione completata.", 16, Color(1, 1, 1, 0.45))
	_sep()
	_txt("ATTRIBUTES   (points: %d)" % p["attr_points"], 20, Color(0.7, 0.9, 1.0))
	for a in Game.ATTRS:
		var h := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s %d" % [a.capitalize(), Game.attr(a)]
		l.add_theme_font_size_override("font_size", 18)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var b := Button.new()
		b.text = "+"
		b.custom_minimum_size = Vector2(58, 48)
		b.disabled = p["attr_points"] <= 0
		b.pressed.connect(func():
			if Game.spend_point(a): _refresh())
		h.add_child(b)
		body.add_child(h)
	_sep()
	_txt("BADGES", 20, Color(1.0, 0.8, 0.4))
	if p["badges"].is_empty():
		_txt("None yet.", 18, Color(1, 1, 1, 0.5))
	for bid in p["badges"]:
		_txt("• %s — %s" % [Game.BADGES[bid]["name"], Game.BADGES[bid]["desc"]], 17)

func _stats() -> void:
	## Pagina STATISTICHE STAGIONAVERE: medie a griglia, percentuali di tiro,
	## career high e game log colorato (verde W / rossa L).
	var s: Dictionary = Game.profile["season"]
	var ng: int = int(s["games"])
	_txt("SEASON", 24, Color(0.6, 0.9, 1.0))
	if ng == 0:
		_txt("No games played yet.", 18, Color(1, 1, 1, 0.5))
		_sep()
		_txt("Play a match and this page fills up: averages, shooting and your game log.", 17, Color(1, 1, 1, 0.45))
		return
	var w: int = int(s["wins"])
	var g := float(ng)
	_txt("%d-%d   ·   %.0f%% vinte   ·   %d partite" % [w, ng - w, 100.0 * float(w) / g, ng],
		19, Color(1, 1, 1, 0.75))
	_sep()
	_txt("PER GAME", 20, Color(1, 1, 1, 0.65))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	for row in [["PTS", "pts"], ["REB", "reb"], ["AST", "ast"],
				["STL", "stl"], ["BLK", "blk"], ["TO", "tov"]]:
		var cell := VBoxContainer.new()
		var big := Label.new()
		big.text = "%.1f" % [float(s[row[1]]) / g]
		big.add_theme_font_size_override("font_size", 30)
		big.modulate = Color(1, 1, 1, 0.95)
		cell.add_child(big)
		var nm := Label.new()
		nm.text = row[0]
		nm.add_theme_font_size_override("font_size", 14)
		nm.modulate = Color(1, 1, 1, 0.5)
		cell.add_child(nm)
		grid.add_child(cell)
	_sep()
	var fga: int = int(s.get("fga", 0))
	var fgm: int = int(s.get("fgm", 0))
	var tpa: int = int(s.get("tpa", 0))
	var tpm: int = int(s.get("tpm", 0))
	var fgp := 0.0 if fga == 0 else 100.0 * float(fgm) / float(fga)
	var tpp := 0.0 if tpa == 0 else 100.0 * float(tpm) / float(tpa)
	_txt("TIRO   %d/%d  (%.0f%%)" % [fgm, fga, fgp], 19, Color(1, 1, 1, 0.85))
	_txt("DALLE TRE   %d/%d  (%.0f%%)" % [tpm, tpa, tpp], 19, Color(1, 1, 1, 0.85))
	var hi: Dictionary = s.get("high", {})
	if typeof(hi) == TYPE_DICTIONARY and not hi.is_empty():
		_txt("CAREER HIGH   %d pts · %d reb · %d ast · %d stl · %d blk" % [
			int(hi.get("pts", 0)), int(hi.get("reb", 0)), int(hi.get("ast", 0)),
			int(hi.get("stl", 0)), int(hi.get("blk", 0))], 18, Color(1.0, 0.86, 0.48))
	_sep()
	_txt("GAME LOG", 20, Color(0.8, 0.9, 1.0))
	for gm in Game.profile["last_games"]:
		var won: bool = bool(gm.get("won", false))
		var sc: Array = gm.get("score", [0, 0])
		var line := "%s  %s  %d-%d  ·  %d pts %d reb %d ast  ·  %s" % [
			"W" if won else "L", String(gm.get("opp", "")), int(sc[0]), int(sc[1]),
			int(gm["pts"]), int(gm["reb"]), int(gm["ast"]), String(gm.get("grade", ""))]
		_txt(line, 17, Color(0.55, 1.0, 0.55) if won else Color(1.0, 0.55, 0.5))

# ------------------------------------------------------------------ wallpaper
func _apply_wallpaper() -> void:
	## Paint the chosen gradient behind the whole handset. The frame's panel
	## (dark bezel + border + rounded corners) stays; only the wallpaper
	## texture swaps.
	if frame == null or wallpaper == null:
		return
	var id: String = String(Game.profile.get("wallpaper", "dusk"))
	var wp: Dictionary = WALLPAPERS.get(id, WALLPAPERS["dusk"])
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([wp["top"], wp["bottom"]])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 2
	tex.height = 2
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	wallpaper.texture = tex

func _wallpaper() -> void:
	_txt("Pick a wallpaper", 24, Color(0.7, 0.9, 1.0))
	_txt("It shows behind every app on the phone.", 16, Color(1, 1, 1, 0.5))
	_sep()
	for id in WALLPAPERS:
		var wp: Dictionary = WALLPAPERS[id]
		var active: bool = String(Game.profile.get("wallpaper", "dusk")) == id
		var b := _row_button(
			"%s %s" % [String(wp["name"]), "✓" if active else ""],
			func():
				Game.profile["wallpaper"] = id
				SaveSystem.save_game()
				_apply_wallpaper()
				_refresh(),
			Color(wp["top"]).lerp(Color(wp["bottom"]), 0.6).lightened(0.25), 66)
		b.modulate = Color(1, 1, 1, 1)
