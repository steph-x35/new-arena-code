extends Node
## La rete locale della SFIDA UN AMICO (v2.42.0, passo 1).
##
## Due telefoni sulla stessa rete — il WiFi di casa o l'hotspot di uno dei
## due — e nessun server in mezzo: chi apre il campo fa da host, l'altro
## lo raggiunge.
##   SCOPERTA  : beacon UDP in broadcast ogni 0,5 s (porta 47899). Chi
##               cerca vede comparire i campi vicini, niente indirizzi
##               da digitare (resta però l'ingresso manuale, se il
##               broadcast non passa sulla rete di turno).
##   CANALE    : ENet sulla porta 7777, un solo ospite a stanza.
##   PING      : misurato da entrambi i lati ogni 2 s.
## Il passo 1 arriva fino a stanza collegata: nome, ping, avvisi. La
## partita in due è il passo 2 — questo layer non tocca il gioco.

const GAME_PORT := 7777
const DISC_PORT := 47899
const MAGIC := "HOOPCITY-ROOM"
const BEACON_EVERY := 0.5
const PING_EVERY := 2.0

enum State { OFF, HOSTING, SEARCHING, CONNECTING, CONNECTED }

signal room_found(info: Dictionary)          # client: trovato un campo
signal client_connected(info: Dictionary)    # host: è entrato lo sfidante
signal connected_to_host(info: Dictionary)   # client: dentro la stanza
signal connection_failed()                   # client: collegamento fallito
signal disconnected()                        # il collegamento è caduto
signal ping_ms(ms: int)                      # ping misurato da questo telefono
signal duel_state(d: Dictionary)             # 1v1: stato dell'altro giocatore
signal duel_shot_rx(d: Dictionary)           # 1v1: esito del tiro dell'altro
signal duel_ev_rx(d: Dictionary)             # 1v1: eventi di gioco (punti, palla...)
signal duel_look_rx(d: Dictionary)           # 1v1: aspetto dell'altro giocatore

var state: int = State.OFF
var role := ""                               # "host" / "client"
var my_name := ""
var peer_name := ""
var peer_ver := ""

var _beacon: PacketPeerUDP = null            # host: manda il beacon
var _listener: PacketPeerUDP = null          # client: ascolta i beacon
var _rooms := {}                             # ip -> {name, ip, ver, t}
var _t := 0.0
var _ping_t := 0.0
var _ping_seq := 0
var _has_peer := false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	if state == State.HOSTING:
		_t += delta
		if _t >= BEACON_EVERY:
			_t = 0.0
			_send_beacon()
	elif state == State.SEARCHING:
		_poll_rooms()
	if _linked():
		_ping_t += delta
		if _ping_t >= PING_EVERY:
			_ping_t = 0.0
			_ping_seq += 1
			rpc("rpc_ping", _ping_seq, int(Time.get_ticks_msec()))


func _linked() -> bool:
	return _has_peer or state == State.CONNECTED


# ------------------------------------------------------------------ RPC
@rpc("any_peer", "call_remote", "reliable")
func rpc_hello(nick: String, ver: String) -> void:
	## Il client si presenta appena il canale è su.
	if role == "host":
		peer_name = nick
		peer_ver = ver
		_has_peer = true
		# il beacon tace finché c'è uno sfidante dentro
		rpc_id(multiplayer.get_remote_sender_id(), "rpc_welcome", my_name, Game.VERSION)
		client_connected.emit({"name": peer_name, "ver": peer_ver})


@rpc("any_peer", "call_remote", "reliable")
func rpc_welcome(nick: String, ver: String) -> void:
	## Il ricevere il benvenuto CHIUDE il collegamento del client: adesso
	## il nome dell'host c'è, e si è davvero dentro.
	if role == "client":
		peer_name = nick
		peer_ver = ver
		state = State.CONNECTED
		connected_to_host.emit({"name": peer_name, "ver": peer_ver})


@rpc("any_peer", "call_remote", "unreliable")
func rpc_ping(seq: int, t0: int) -> void:
	rpc_id(multiplayer.get_remote_sender_id(), "rpc_pong", seq, t0)


@rpc("any_peer", "call_remote", "unreliable")
func rpc_pong(seq: int, t0: int) -> void:
	if seq == _ping_seq:
		ping_ms.emit(int(Time.get_ticks_msec()) - t0)


# ------------------------------------------------------------------ RPC 1v1
# Il canale della partita in due. Gli @rpc vivono qui (path identico su
# entrambi i telefoni: /root/NetLayer) e vengono RIEMESSI come signal:
# la DuelScene li ascolta. Per spedire: NetLayer.rpc("rpc_duel_me", d).

@rpc("any_peer", "call_remote", "unreliable")
func rpc_duel_me(d: Dictionary) -> void:
	duel_state.emit(d)

@rpc("any_peer", "call_remote", "reliable")
func rpc_duel_shot(d: Dictionary) -> void:
	duel_shot_rx.emit(d)

@rpc("any_peer", "call_remote", "reliable")
func rpc_duel_ev(d: Dictionary) -> void:
	duel_ev_rx.emit(d)

@rpc("any_peer", "call_remote", "reliable")
func rpc_duel_look(d: Dictionary) -> void:
	duel_look_rx.emit(d)

# ------------------------------------------------------------------ comandi
func host() -> bool:
	## Apri il campo: server ENet + beacon di scoperta. Ritorna false solo
	## se la porta di gioco è già occupata (molto raro).
	close()
	my_name = String(Game.profile.get("name", "Player"))
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(GAME_PORT, 1) != OK:
		return false
	multiplayer.multiplayer_peer = peer
	_beacon = PacketPeerUDP.new()
	# NB: set_broadcast_enabled() restituisce void — niente da controllare.
	# Se la rete di turno rifiuta il broadcast, il beacon semplicemente non
	# passa: la stanza resta raggiungibile per indirizzo (campo manuale).
	_beacon.set_broadcast_enabled(true)
	role = "host"
	state = State.HOSTING
	_t = 0.0
	return true


func search() -> bool:
	## Cerca i campi vicini (beacon in ascolto).
	close()
	my_name = String(Game.profile.get("name", "Player"))
	_listener = PacketPeerUDP.new()
	if _listener.bind(DISC_PORT) != OK:
		_listener.close()
		_listener = null
		return false
	role = "client"
	state = State.SEARCHING
	return true


func connect_room(ip: String) -> bool:
	## Collegati a un campo, per indirizzo (dalla lista o a mano).
	if ip == "":
		return false
	close()
	my_name = String(Game.profile.get("name", "Player"))
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, GAME_PORT) != OK:
		return false
	multiplayer.multiplayer_peer = peer
	role = "client"
	state = State.CONNECTING
	return true


func close() -> void:
	## Chiude tutto e riporta il layer a spento. Chiamata dall'uscita della
	## stanza: nessun socket lasciato appeso.
	if _beacon != null:
		_beacon.close()
		_beacon = null
	if _listener != null:
		_listener.close()
		_listener = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_rooms.clear()
	peer_name = ""
	peer_ver = ""
	_has_peer = false
	role = ""
	state = State.OFF
	_ping_t = 0.0


# ------------------------------------------------------------------ letture
func rooms() -> Array:
	## I campi visti di recente (scade dopo 3 s senza beacon).
	var out := []
	var now := int(Time.get_ticks_msec())
	for ip in _rooms.keys():
		var r: Dictionary = _rooms[ip]
		if now - int(r.get("t", 0)) > 3000:
			_rooms.erase(ip)
			continue
		out.append(r)
	return out


func host_ips() -> Array:
	## Gli indirizzi di questo telefono da digitare sull'altro, se la
	## ricerca automatica non parte. Prima le reti locali classiche.
	var out := []
	for ip in IP.get_local_addresses():
		var s := String(ip)
		var parts := s.split(".")
		if parts.size() != 4:
			continue
		if parts[0] == "127" or parts[0] == "169":
			continue
		if s.begins_with("192.168.") or s.begins_with("10.") or s.begins_with("172."):
			out.append(s)
	return out


# ------------------------------------------------------------------ interno
func _send_beacon() -> void:
	if _beacon == null or _has_peer:
		return
	var pkt := var_to_bytes({"magic": MAGIC, "name": my_name, "ver": Game.VERSION})
	for addr in _broadcast_addrs():
		_beacon.set_dest_address(addr, DISC_PORT)
		_beacon.put_packet(pkt)


func _poll_rooms() -> void:
	if _listener == null:
		return
	while _listener.get_available_packet_count() > 0:
		var pkt := _listener.get_packet()
		var ip := _listener.get_packet_ip()
		var d = bytes_to_var(pkt)
		if typeof(d) != TYPE_DICTIONARY:
			continue
		if String(d.get("magic", "")) != MAGIC:
			continue
		var info := {
			"name": String(d.get("name", "?")),
			"ip": ip,
			"ver": String(d.get("ver", "")),
			"t": int(Time.get_ticks_msec()),
		}
		var was_new := not _rooms.has(ip)
		_rooms[ip] = info
		if was_new:
			room_found.emit(info)


func _broadcast_addrs() -> Array:
	var out := {"255.255.255.255": true}
	for ip in IP.get_local_addresses():
		var s := String(ip)
		var parts := s.split(".")
		if parts.size() != 4 or parts[0] == "127" or parts[0] == "169":
			continue
		out["%s.%s.%s.255" % [parts[0], parts[1], parts[2]]] = true
	return out.keys()


func _on_peer_connected(_id: int) -> void:
	pass   # host: il nome arriva con rpc_hello


func _on_peer_disconnected(_id: int) -> void:
	if role == "host":
		peer_name = ""
		peer_ver = ""
		_has_peer = false
		_t = 0.0
		disconnected.emit()


func _on_connected_to_server() -> void:
	# client: il canale è su — presentati all'host
	if role == "client":
		rpc_id(1, "rpc_hello", my_name, Game.VERSION)


func _on_connection_failed() -> void:
	if state == State.CONNECTING:
		close()
		connection_failed.emit()


func _on_server_disconnected() -> void:
	if role == "client":
		close()
		disconnected.emit()
