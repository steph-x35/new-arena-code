extends Node2D
## SFIDA UN AMICO — la stanza condivisa (passo 1).
## Aprire il campo, trovarlo, collegarsi, misurare il ping. La partita in
## due è il passo 2: qui non si gioca ancora, e il gioco esistente non
## viene toccato.

@onready var root: Control = $UI/Root

var _v: VBoxContainer
var _list_box: VBoxContainer = null   # client: l'elenco dei campi trovati
var _stat1: Label = null              # riga di stato grande
var _stat2: Label = null              # riga di stato piccola (ping, avvisi)
var _ip_lbl: Label = null             # host: il tuo indirizzo, per il giro a mano
var _ip_edit: LineEdit = null         # client: indirizzo a mano
var _list_hash := ""                  # ricostruisce la lista solo se cambia
var _mode := ""                       # pick / host / client
var _duel_next := false               # vero = sto andando al duello: la connessione resta


func _ready() -> void:
	UIKit.header(root, "HOOP CITY LIFE", Loc.t("lobby.title"))
	UIKit.back_and_phone(root, "res://src/scenes/MainMenu.tscn")
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 56
	scroll.offset_top = 150
	scroll.offset_right = -56
	scroll.offset_bottom = -30
	root.add_child(scroll)
	_v = VBoxContainer.new()
	_v.add_theme_constant_override("separation", 14)
	_v.custom_minimum_size = Vector2(1100, 0)
	scroll.add_child(_v)
	NetLayer.client_connected.connect(_on_client_connected)
	NetLayer.connected_to_host.connect(_on_connected)
	NetLayer.connection_failed.connect(_on_conn_failed)
	NetLayer.disconnected.connect(_on_disc)
	NetLayer.ping_ms.connect(_on_ping)
	NetLayer.duel_ev_rx.connect(_on_duel_ev)
	_build_pick()


func _exit_tree() -> void:
	if not _duel_next:
		NetLayer.close()


func _process(_delta: float) -> void:
	if _mode == "client":
		_refresh_rooms()


# ------------------------------------------------------------------ viste
func _clear() -> void:
	for c in _v.get_children():
		_v.remove_child(c)
		c.queue_free()
	_list_box = null
	_stat1 = null
	_stat2 = null
	_ip_lbl = null
	_ip_edit = null


func _build_pick() -> void:
	_mode = "pick"
	_clear()
	_label(Loc.t("lobby.intro"), 20, Color(1, 1, 1, 0.7))
	UIKit.big_button(_v, Loc.t("lobby.host"), _tap_host, Loc.t("lobby.host.sub"))
	UIKit.big_button(_v, Loc.t("lobby.find"), _tap_client, Loc.t("lobby.find.sub"))
	_stat1 = _label("", 20, Color(1.0, 0.55, 0.4))


func _build_host() -> void:
	_mode = "host"
	_clear()
	_label(Loc.t("lobby.host"), 30, Color(1.0, 0.82, 0.35))
	_stat1 = _label(Loc.t("lobby.waiting"), 20, Color(1, 1, 1, 0.8))
	_stat2 = _label("", 18, Color(1, 1, 1, 0.55))
	_label(Loc.t("lobby.manual"), 18, Color(1, 1, 1, 0.5))
	_ip_lbl = _label("", 32, Color(0.55, 0.85, 1.0))
	_label(Loc.t("lobby.next"), 18, Color(1, 1, 1, 0.5))
	UIKit.big_button(_v, Loc.t("lobby.close"), _tap_close)
	var ips := NetLayer.host_ips()
	if _ip_lbl != null:
		_ip_lbl.text = "  ·  ".join(ips) if not ips.is_empty() else "—"


func _build_client() -> void:
	_mode = "client"
	_clear()
	_label(Loc.t("lobby.find"), 30, Color(1.0, 0.82, 0.35))
	_label(Loc.t("lobby.rooms"), 18, Color(1, 1, 1, 0.55))
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 10)
	_v.add_child(_list_box)
	_list_hash = ""
	_label(Loc.t("lobby.manual"), 18, Color(1, 1, 1, 0.5))
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "192.168.43.1"
	_ip_edit.custom_minimum_size = Vector2(520, 62)
	_ip_edit.add_theme_font_size_override("font_size", 24)
	_v.add_child(_ip_edit)
	UIKit.big_button(_v, Loc.t("lobby.connect"), _tap_connect)
	_label(Loc.t("lobby.next"), 18, Color(1, 1, 1, 0.5))
	UIKit.big_button(_v, Loc.t("lobby.close"), _tap_close)
	_stat1 = _label("", 20, Color(1, 1, 1, 0.8))
	_stat2 = _label("", 18, Color(1, 1, 1, 0.55))
	if not NetLayer.search():
		if _stat1 != null:
			_stat1.text = Loc.t("lobby.searchfailed")


# ------------------------------------------------------------------ azioni
func _tap_host() -> void:
	if NetLayer.host():
		_build_host()
	elif _stat1 != null:
		_stat1.text = Loc.t("lobby.hostfailed")


func _tap_client() -> void:
	_build_client()


func _tap_close() -> void:
	NetLayer.close()
	_build_pick()


func _tap_connect() -> void:
	if _ip_edit == null:
		return
	var ip := _ip_edit.text.strip_edges()
	if ip == "":
		if _stat1 != null:
			_stat1.text = Loc.t("lobby.addr")
		return
	_connect(ip)


func _connect(ip: String) -> void:
	if _stat1 != null:
		_stat1.text = "%s %s" % [Loc.t("lobby.connecting"), ip]
	if _stat2 != null:
		_stat2.text = ""
	NetLayer.connect_room(ip)


# ------------------------------------------------------------------ rete
func _refresh_rooms() -> void:
	if _list_box == null or NetLayer.state != NetLayer.State.SEARCHING:
		return
	var rooms := NetLayer.rooms()
	var h := ""
	for r in rooms:
		h += "%s|%s|%s;" % [String(r["name"]), String(r["ip"]), String(r["ver"])]
	if h == _list_hash:
		return
	_list_hash = h
	for c in _list_box.get_children():
		_list_box.remove_child(c)
		c.queue_free()
	if rooms.is_empty():
		_label_in(_list_box, Loc.t("lobby.hint"), 18, Color(1, 1, 1, 0.5))
		return
	for r in rooms:
		var txt: String = "%s  ·  %s" % [String(r["name"]), String(r["ip"])]
		if String(r["ver"]) != Game.VERSION:
			txt += "  ·  %s" % Loc.t("lobby.oldver")
		var b := Button.new()
		b.text = txt
		b.custom_minimum_size = Vector2(640, 76)
		b.add_theme_font_size_override("font_size", 22)
		b.clip_text = true
		var ip := String(r["ip"])
		b.pressed.connect(func() -> void: _connect(ip))
		_list_box.add_child(b)


func _on_client_connected(info: Dictionary) -> void:
	if _mode == "host" and _stat1 != null:
		_stat1.text = "%s: %s" % [Loc.t("lobby.connected"), String(info.get("name", "?"))]
	if _mode == "host":
		UIKit.big_button(_v, Loc.t("lobby.start"), _tap_start)
		if _stat2 != null:
			_stat2.text = ""
			if String(info.get("ver", "")) != Game.VERSION:
				_stat2.text = Loc.t("lobby.vermismatch")


func _on_connected(info: Dictionary) -> void:
	if _mode == "client" and _stat1 != null:
		_stat1.text = "%s: %s" % [Loc.t("lobby.connected"), String(info.get("name", "?"))]
		if _stat2 != null:
			_stat2.text = ""
			if String(info.get("ver", "")) != Game.VERSION:
				_stat2.text = Loc.t("lobby.vermismatch")


func _on_conn_failed() -> void:
	if _mode != "client":
		return
	if _stat1 != null:
		_stat1.text = Loc.t("lobby.connfailed")
	NetLayer.search()   # si riparte dalla ricerca: la lista si aggiorna da sola


func _on_disc() -> void:
	if _mode == "host":
		if _stat1 != null:
			_stat1.text = Loc.t("lobby.waiting")
		if _stat2 != null:
			_stat2.text = Loc.t("lobby.lost")
	elif _mode == "client":
		if _stat1 != null:
			_stat1.text = Loc.t("lobby.lost")
		_list_hash = ""
		NetLayer.search()


func _on_ping(ms: int) -> void:
	if _stat2 != null:
		_stat2.text = Loc.t("lobby.ping") % ms


# ------------------------------------------------------------------ ui
func _label(text: String, size := 20, col := Color(1, 1, 1, 0.8)) -> Label:
	return _label_in(_v, text, size, col)


func _label_in(parent: Control, text: String, size := 20, col := Color(1, 1, 1, 0.8)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.modulate = col
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _tap_start() -> void:
	## L'host lancia l'1v1: se stesso e l'altro cambiano scena, la stanza
	## resta aperta (la chiude chi esce dal duello).
	_duel_next = true
	NetLayer.rpc("rpc_duel_ev", {"t": "start"})
	SceneRouter.goto("res://src/scenes/DuelScene.tscn")


func _on_duel_ev(d: Dictionary) -> void:
	if String(d.get("t", "")) == "start":
		_duel_next = true
		SceneRouter.goto("res://src/scenes/DuelScene.tscn")
