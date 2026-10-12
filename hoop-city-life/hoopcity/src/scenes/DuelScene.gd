extends Node2D
## SFIDA UN AMICO — l'1v1 in tempo reale sul campetto (passo 2).
##
## Due telefoni, una sola rete, un canestro: chi segna di piu' vince.
## Il netcode e' volutamente semplice, come il basket del campetto:
##   TIRO    : lo decide CHI TIRA, sul suo orologio (il metro verde non
##             deve soffrire di rete). L'esito viaggia all'host, che tiene
##             il punteggio e simula la palla per entrambi.
##   MOVIMENTO: ciascuno e' padrone della propria posizione; l'altro la
##             vede arrivare a 30 Hz e la interpola.
##   PALLA   : in mano a chi ce l'ha (nessun sync necessario); in volo la
##             simula l'host. Il cliente simula in locale il PROPRIO tiro
##             perche' il swish si deve sentire subito, dal suo telefono.
## Regole da campetto: 2 punti, 3 da dietro l'arco, primo a 11, dopo il
## canestro la palla va all'altro. Nessuna rubata (v1): la difesa si fa
## mettendosi davanti — restringe la finestra verde di chi tira.

const RIM := Vector2(Court.COURT_W * 0.5 - Court.FIBA_HOOP_INSET, 0.0)
const RIM_HEIGHT := Court.RIM_HEIGHT
const RIM_HALF := 42.0
const GRAV := 1800.0
const BALL_R := Court.BALL_R
const CAM_ZOOM := 1.04
const WIN_SCORE := 11
const MOVE_SPEED := 310.0
const SEND_HZ := 30.0
const DUNK_R := 132.0          # ~7 piedi dal ferro
const CONTEST_R := 115.0       # il difensore addosso restringe la finestra
const PICKUP_R := 66.0

var joystick: VirtualJoystick
var meter: ShotMeter
var btn_shoot: TouchButton
var lbl_top: Label
var lbl_mid: Label
var court_art: Node
var game_on := false
var over := false

# ---- il mio giocatore (questo telefono)
var player_pos := Vector2(RIM.x - 640.0, -140.0)
var facing := 1.0
var dribble_t := 0.0
var charging := false
var charge := 0.0
var ideal := 0.55
var shot_anim := 0.0
var pump_t := 0.0
var hot := false
var streak := 0
var hand_left := false

# ---- la mia schiacciata (stessa coreografia del campetto solo)
var dunk_phase := ""           # "" | rise | hang | drop
var dunk_anim := 0.0
var dunk_style := ""
var dunk_rise_t := 0.70
var dunk_ball_t := 0.0
var hang_swing_t := 0.0
var hang_lift_now := 0.0
var dust_t := 0.0
var dust_big := false

# ---- l'avversario (l'altro telefono)
var foe := {
	"pos": Vector2(RIM.x - 640.0, 160.0), "t_pos": Vector2(RIM.x - 640.0, 160.0),
	"facing": -1.0, "kind": Avatar.DRIBBLE, "amount": 0.0, "phase": 0.0,
	"dp": "", "ds": "", "da": 0.0, "ht": 0.0, "ho": false,
	"name": "?", "look": {}, "seen": false,
}
var foe_colours := {}

# ---- palla e punteggio (host autoritativo)
var ball_pos := Vector2.ZERO
var ball_h := 0.0
var ball_vel := Vector2.ZERO
var ball_vh := 0.0
var ball_live := false
var ball_spin := 0.0
var ball_settled := 0.0
var prev_h := 0.0
var prev_pos := Vector2.ZERO
var my_shot_live := false          # il mio tiro, simulato in locale
var holder := 0                    # 0 = io, 1 = lui, -1 = palla libera
var pending := {}                  # host: esito del tiro in volo
var flight_t := 0.0
var score_me := 0
var score_foe := 0

var net_wobble := 0.0
var net_t := 0.0
var _send_t := 0.0
var _net_ok := false
var _begin_t := 0.0
var _msg_t := 0.0


func _ready() -> void:
	Sfx.stop_music()
	hand_left = Game.shooting_hand() < 0.0
	court_art = $CourtVisual
	court_art.z_index = -10
	court_art.visible = true
	court_art.modulate = Color.WHITE
	if court_art.has_method("apply_env"):
		court_art.apply_env("street")
	else:
		court_art.env = "street"
		court_art.queue_redraw()
	RenderingServer.set_default_clear_color(Color(0.30, 0.44, 0.23))
	var cam: Camera2D = $Camera2D
	cam.zoom = Vector2.ONE * CAM_ZOOM
	cam.position = Vector2(0.0, -40.0)
	cam.enabled = true
	cam.make_current()
	set_meta("cam", cam)
	_build_hud()
	_net_ok = (NetLayer.state == NetLayer.State.CONNECTED) \
		or (NetLayer.role == "host" and NetLayer._has_peer)
	NetLayer.duel_state.connect(_on_foe_state)
	NetLayer.duel_shot_rx.connect(_on_foe_shot)
	NetLayer.duel_ev_rx.connect(_on_ev)
	NetLayer.duel_look_rx.connect(_on_foe_look)
	NetLayer.disconnected.connect(_on_net_lost)
	if not _net_ok:
		lbl_mid.text = Loc.t("duel.nolink")
		return
	# scambio aspetto: l'altro ti deve vedere COME SEI
	NetLayer.rpc("rpc_duel_look", _my_look())
	_lbl_top_refresh()
	if NetLayer.role == "host":
		_begin_t = 1.2    # si parte appena l'altro ha il tempo di entrare


func _exit_tree() -> void:
	if NetLayer.duel_state.is_connected(_on_foe_state):
		NetLayer.duel_state.disconnect(_on_foe_state)
	if NetLayer.duel_shot_rx.is_connected(_on_foe_shot):
		NetLayer.duel_shot_rx.disconnect(_on_foe_shot)
	if NetLayer.duel_ev_rx.is_connected(_on_ev):
		NetLayer.duel_ev_rx.disconnect(_on_ev)
	if NetLayer.duel_look_rx.is_connected(_on_foe_look):
		NetLayer.duel_look_rx.disconnect(_on_foe_look)
	if NetLayer.disconnected.is_connected(_on_net_lost):
		NetLayer.disconnected.disconnect(_on_net_lost)


func _my_look() -> Dictionary:
	var c: Dictionary = Avatar.colours(true)
	return {
		"name": String(Game.profile.get("name", "Player")),
		"skin": c.get("skin", Color(0.72, 0.53, 0.38)),
		"hair": c.get("hair", Color(0.16, 0.13, 0.12)),
		"jersey": c.get("jersey", Color(0.22, 0.24, 0.28)),
		"shorts": c.get("shorts", Color(0.20, 0.22, 0.30)),
		"shoes": c.get("shoes", Color(0.9, 0.9, 0.92)),
		"num": int(Game.profile.get("jersey", 7)),
		"hf": Game.height_factor(),
	}


# ------------------------------------------------------------------ HUD
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	joystick = VirtualJoystick.new()
	joystick.set_anchors_preset(Control.PRESET_FULL_RECT)
	joystick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left := Control.new()
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.anchor_right = 0.5
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(joystick)
	root.add_child(left)

	lbl_top = Label.new()
	lbl_top.add_theme_font_size_override("font_size", 26)
	lbl_top.position = Vector2(28, 22)
	root.add_child(lbl_top)

	lbl_mid = Label.new()
	lbl_mid.add_theme_font_size_override("font_size", 36)
	lbl_mid.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lbl_mid.position = Vector2(0, 96)
	lbl_mid.custom_minimum_size = Vector2(0, 48)
	lbl_mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(lbl_mid)

	btn_shoot = TouchButton.new()
	btn_shoot.text = "SHOOT"
	btn_shoot.hold_mode = true
	btn_shoot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_shoot.position = Vector2(-210, -230)
	btn_shoot.custom_minimum_size = Vector2(190, 190)
	btn_shoot.size = Vector2(190, 190)
	btn_shoot.pressed_down.connect(_shoot_down)
	btn_shoot.released.connect(_shoot_up)
	root.add_child(btn_shoot)

	meter = ShotMeter.new()
	meter.set_anchors_preset(Control.PRESET_TOP_LEFT)
	meter.position = Vector2(0, 0)
	meter.custom_minimum_size = Vector2(120, 78)
	meter.size = Vector2(120, 78)
	meter.max_charge = 1.4
	meter.visible = false
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(meter)

	var leave := Button.new()
	leave.text = "< " + Loc.t("duel.leave")
	leave.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	leave.position = Vector2(-170, 24)
	leave.custom_minimum_size = Vector2(160, 60)
	leave.add_theme_font_size_override("font_size", 22)
	leave.pressed.connect(_leave)
	root.add_child(leave)

	var again := Button.new()
	again.text = Loc.t("duel.rematch")
	again.set_anchors_preset(Control.PRESET_CENTER)
	again.position = Vector2(-160, 150)
	again.custom_minimum_size = Vector2(320, 72)
	again.add_theme_font_size_override("font_size", 24)
	again.visible = false
	again.pressed.connect(_tap_rematch)
	root.add_child(again)
	set_meta("again", again)


func _lbl_top_refresh() -> void:
	lbl_top.text = "%s %d  ·  %d %s" % [Loc.t("duel.you"), score_me,
		score_foe, String(foe.get("name", "?"))]


func _say(msg: String, t := 2.2) -> void:
	lbl_mid.text = msg
	_msg_t = t


# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	dribble_t += delta * 4.2
	net_t += delta
	net_wobble = HoopArt.decay(net_wobble, delta)
	pump_t = maxf(0.0, pump_t - delta)
	dust_t = maxf(0.0, dust_t - delta)
	shot_anim = maxf(0.0, shot_anim - delta * 4.5)
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			lbl_mid.text = ""
	# l'avversario scivola verso l'ultima posizione ricevuta
	var tp: Vector2 = foe["t_pos"]
	foe["pos"] = (foe["pos"] as Vector2).lerp(tp, clampf(14.0 * delta, 0.0, 1.0))

	if not game_on:
		_wait_flow(delta)
		_camera(delta)
		queue_redraw()
		return

	if not over:
		_my_move(delta)
		_dunk_flow(delta)
		_charge_flow(delta)
	_host_ball(delta)
	_resolve_flight(delta)
	_camera(delta)
	_send(delta)
	queue_redraw()


func _wait_flow(delta: float) -> void:
	if not _net_ok:
		return
	if NetLayer.role == "host":
		if foe["seen"] and not game_on:
			_begin_t = minf(_begin_t, 0.5)
		_begin_t -= delta
		if _begin_t <= 0.0 and foe["seen"] and not game_on:
			NetLayer.rpc("rpc_duel_ev", {"t": "begin",
				"poss": randi() % 2})
			_begin_t = 1.0e9
	elif not foe["seen"]:
		lbl_mid.text = Loc.t("duel.waiting")


func _my_move(delta: float) -> void:
	if dunk_phase != "" or charging:
		if charging and dunk_phase == "":
			var mv0: Vector2 = joystick.output * 0.25
			player_pos += mv0 * MOVE_SPEED * delta
		elif dunk_phase == "rise":
			var rim_x: Vector2 = RIM - Vector2(20.0, 0.0)
			var f: float = clampf(dunk_anim / maxf(dunk_rise_t, 0.05), 0.0, 1.0)
			player_pos = player_pos.lerp(rim_x, smoothstep(0.0, 0.62, f) * 0.5)
		_clamp_me()
		return
	var mv: Vector2 = joystick.output
	player_pos += mv * MOVE_SPEED * delta
	if absf(mv.x) > 0.12:
		facing = signf(mv.x)
	_clamp_me()


func _clamp_me() -> void:
	player_pos.x = clampf(player_pos.x, -110.0, Court.COURT_W * 0.5 - 34.0)
	player_pos.y = clampf(player_pos.y, -Court.COURT_H + 120.0, Court.COURT_H - 120.0)


func _charge_flow(delta: float) -> void:
	if charging:
		charge += delta
		if meter:
			meter.charge = clampf(charge / maxf(ideal, 0.01), 0.0, 1.15)


func _dunk_flow(delta: float) -> void:
	if dunk_phase == "":
		return
	dunk_anim += delta
	if dunk_phase == "hang":
		hang_swing_t += delta
		dunk_ball_t += delta
	elif dunk_phase == "drop":
		dunk_ball_t += delta
		if dunk_anim >= 0.5:
			dunk_phase = ""
			dust_t = 0.45
			dust_big = false
	match dunk_phase:
		"rise":
			if dunk_anim >= dunk_rise_t:
				dunk_phase = "hang"
				dunk_anim = 0.0
				hang_swing_t = 0.0
				dunk_ball_t = 0.0
				_dunk_throw()
		"hang":
			pass   # si scende quando il dito lascia il bottone
		"drop":
			pass
		_:
			pass


func _camera(delta: float) -> void:
	if not has_meta("cam"):
		return
	var cam: Camera2D = get_meta("cam")
	var fp: Vector2 = CourtStage.m_project(player_pos, Court.COURT_H)
	var want_x: float = fp.x
	var half_view: float = get_viewport_rect().size.x * 0.5 / CAM_ZOOM
	var floor_x: float = CourtStage.m_project(
		Vector2(Court.COURT_W * 0.5, 0.0), Court.COURT_H).x
	var limit: float = maxf(floor_x - half_view + 160.0, 80.0)
	want_x = clampf(want_x, -limit, limit)
	cam.position.x = lerpf(cam.position.x, want_x, clampf(4.0 * delta, 0.0, 1.0))
	cam.position.y = -40.0


# ------------------------------------------------------------------ tiro
func _i_have_ball() -> bool:
	return holder == 0 and not ball_live and not my_shot_live and dunk_phase == ""


func _shoot_down() -> void:
	if not game_on or over or not _i_have_ball():
		return
	if player_pos.distance_to(RIM) < DUNK_R:
		_start_dunk()
		return
	charging = true
	charge = 0.0
	ideal = clampf(0.42 + _distance_ft() * 0.012, 0.42, 0.78)
	var w: Dictionary = ShotSystem.shot_windows(_distance_ft(), hot)
	# DIFESA ADDOSSO: la finestra si restringe come nel fadeaway.
	var fd: Vector2 = (foe["pos"] as Vector2) - player_pos
	if fd.length() < CONTEST_R:
		w["perfect"] = float(w["perfect"]) * 0.70
		w["good"] = float(w["good"]) * 0.82
	meter.perfect_window = float(w["perfect"])
	meter.good_window = float(w["good"])
	meter.visible = true
	meter.charge = 0.0


func _start_dunk() -> void:
	dunk_phase = "rise"
	dunk_anim = 0.0
	dunk_ball_t = 0.0
	dunk_style = DunkStyle.pick()
	dunk_rise_t = DunkStyle.rise_time(dunk_style)


func _dunk_throw() -> void:
	net_wobble = 1.0
	Sfx.haptic(60)
	if court_art != null:
		court_art.net_bump(1, 1.0)
	Events.popup.emit("GREEN!", player_pos + Vector2(0, -95), Color(0.3, 1.0, 0.45), true)
	_fire_shot({"dunk": true, "made": true, "pts": 2,
		"style": dunk_style, "from": RIM})


func _drop_from_rim() -> void:
	if dunk_phase == "hang":
		dunk_phase = "drop"
		dunk_anim = 0.0
		Sfx.haptic(30)


func _shoot_up() -> void:
	if dunk_phase == "rise":
		return
	if dunk_phase == "hang":
		_drop_from_rim()
		return
	if not charging:
		return
	meter.visible = false
	if charge < 0.17:
		# tap veloce: pump fake, niente tiro
		charging = false
		charge = 0.0
		pump_t = 0.35
		if meter:
			meter.charge = 0.0
		return
	charging = false
	var w: Dictionary = ShotSystem.shot_windows(_distance_ft(), hot)
	var fd: Vector2 = (foe["pos"] as Vector2) - player_pos
	if fd.length() < CONTEST_R:
		w["perfect"] = float(w["perfect"]) * 0.70
		w["good"] = float(w["good"]) * 0.82
	var pw: float = float(w["perfect"])
	var gw: float = float(w["good"])
	var err: float = absf(charge - ideal)
	var zone: String
	var verdict: String
	var verdict_col: Color
	if err <= pw:
		zone = "green"
		verdict = "PERFECT"
		verdict_col = Color(0.35, 1.0, 0.45)
		Sfx.haptic(50)
		Events.popup.emit("GREEN!", player_pos + Vector2(0, -95), Color(0.3, 1.0, 0.45), true)
	elif err <= gw:
		zone = "yellow"
		verdict = "GOOD"
		verdict_col = Color(0.95, 0.85, 0.30)
	else:
		zone = "red"
		verdict = "EARLY" if charge < ideal else "LATE"
		verdict_col = Color(1.0, 0.45, 0.38)
	var made: bool
	if zone == "green":
		made = true
	elif zone == "yellow":
		made = randf() < 0.5
	else:
		made = false
	var ft: float = _distance_ft()
	var pts: int = 3 if ft > Court.THREE_FT else 2
	if meter:
		meter.show_release(verdict, verdict_col)
	shot_anim = 0.22
	# traiettoria coerente con il verdetto (stessa regola del campetto solo)
	var aim: Vector2
	if zone == "green":
		aim = RIM
	elif made:
		aim = RIM + Vector2(randf_range(-12.0, 12.0), randf_range(-6.0, 6.0))
	else:
		var away: float = signf(RIM.x - player_pos.x)
		if away == 0.0:
			away = 1.0
		if charge < ideal:
			aim = RIM + Vector2(-away * randf_range(70.0, 120.0), 30.0)
		else:
			aim = RIM + Vector2(away * randf_range(50.0, 90.0), -40.0)
	_fire_shot({"dunk": false, "made": made, "pts": pts, "zone": zone,
		"from": player_pos, "aim": aim})


func _fire_shot(d: Dictionary) -> void:
	## Il mio tiro: parte da qui, lo vedo SUBITO dal mio telefono.
	streak = streak + 1 if d.get("made", false) else 0
	if d.get("made", false):
		if streak >= 3 and not hot:
			hot = true
			Events.popup.emit("ON FIRE!", player_pos, Color(1.0, 0.55, 0.15), true)
	else:
		hot = false
		streak = 0
	if not d.get("dunk", false):
		_launch_ball(d["from"], d["aim"])
		my_shot_live = true
		flight_t = 0.0
	if NetLayer.role == "host":
		_host_apply_shot(0, d)
	else:
		NetLayer.rpc("rpc_duel_shot", d)


# ------------------------------------------------------------------ palla
func _launch_ball(from: Vector2, aim: Vector2) -> void:
	ball_pos = from
	ball_h = 55.0
	ball_live = true
	ball_settled = 0.0
	var dist: Vector2 = aim - from
	var flight: float = clampf(dist.length() / 430.0, 0.5, 1.6)
	ball_vel = dist / flight
	ball_vh = (RIM_HEIGHT - ball_h + 0.5 * GRAV * flight * flight) / flight
	ball_spin = -signf(dist.x) * 7.0
	prev_h = ball_h
	prev_pos = ball_pos
	holder = -1


func _step_ball(delta: float) -> void:
	if not ball_live:
		return
	var steps := 4
	var h: float = delta / float(steps)
	for _i in steps:
		prev_h = ball_h
		prev_pos = ball_pos
		ball_vh -= GRAV * h
		ball_pos += ball_vel * h
		ball_h += ball_vh * h
		_collide_rim()
		_collide_floor()
	ball_spin += ball_vel.x * 0.0004
	if ball_pos.x < -1300.0 or ball_pos.x > 1300.0 \
	or ball_pos.y < -Court.COURT_H or ball_pos.y > Court.COURT_H:
		ball_live = false


func _collide_rim() -> void:
	if ball_h <= RIM_HEIGHT and prev_h >= RIM_HEIGHT and ball_vh < 0.0:
		var d: Vector2 = ball_pos - RIM
		var dist: float = d.length()
		if dist < RIM_HALF - 6.0:
			# swish: dentro
			net_wobble = 1.0
			if court_art != null:
				court_art.net_bump(1, 0.7)
		elif dist < RIM_HALF + BALL_R + 4.0:
			var rn: Vector2 = d.normalized() if d.length() > 0.1 else Vector2(1, 0)
			ball_pos = RIM + rn * (RIM_HALF + BALL_R + 2.0)
			ball_vel = rn * randf_range(60.0, 130.0) \
				+ Vector2(randf_range(-40, 40), randf_range(-40, 40))
			ball_vh = randf_range(120.0, 320.0)
			Sfx.play("rim", -0.5, randf_range(0.95, 1.08))
			net_wobble = 0.7


func _collide_floor() -> void:
	if ball_h < 0.0:
		ball_h = 0.0
		if absf(ball_vh) > 90.0:
			ball_vh = -ball_vh * 0.45
			ball_vel *= 0.72
		else:
			ball_vh = 0.0
			ball_settled += 0.02
			ball_vel *= 0.94


func _host_ball(delta: float) -> void:
	## L'host simula la palla dei tiri di ENTRAMBI (quella del cliente la
	## riceve gia' risolta); il cliente simula solo il PROPRIO tiro, per
	## vederlo subito. Le due simulazioni partono dagli stessi dati.
	if NetLayer.role == "host":
		_step_ball(delta)
		if ball_live and ball_settled > 0.5:
			ball_live = false
		if not ball_live:
			my_shot_live = false
	elif my_shot_live:
		_step_ball(delta)
		if not ball_live:
			my_shot_live = false


func _resolve_flight(delta: float) -> void:
	## HOST: quando la palla muore, applica l'esito in attesa e comunica.
	if NetLayer.role != "host" or pending.is_empty():
		return
	flight_t += delta
	if flight_t < 3.5 and my_shot_live or (ball_live and flight_t < 3.5):
		return
	var d: Dictionary = pending
	pending = {}
	var by: int = int(d.get("by", 0))
	if bool(d.get("made", false)):
		var pts: int = int(d.get("pts", 2))
		if by == 0:
			score_me += pts
		else:
			score_foe += pts
		_ev_broadcast({"t": "score", "by": by, "pts": pts,
			"me": score_me, "foe": score_foe})
		if score_me >= WIN_SCORE or score_foe >= WIN_SCORE:
			var winner: int = 0 if score_me >= WIN_SCORE else 1
			_ev_broadcast({"t": "win", "w": winner, "me": score_me, "foe": score_foe})
			return
		# canestro: palla all'altro, si riparte
		_ev_broadcast({"t": "possess", "who": 1 - by, "check": true})
	else:
		# errore: la prende chi e' piu' vicino a dove si e' fermata
		var dme: float = player_pos.distance_to(ball_pos)
		var dfoe: float = (foe["pos"] as Vector2).distance_to(ball_pos)
		_ev_broadcast({"t": "possess", "who": 0 if dme <= dfoe else 1})
	_ev_apply({"t": "score_sync", "me": score_me, "foe": score_foe})


func _host_apply_shot(by: int, d: Dictionary) -> void:
	## Host: registra l'esito del tiro (suo o ricevuto dal cliente) e lancia
	## la sua copia della palla.
	if not bool(d.get("dunk", false)):
		_launch_ball(d["from"], d["aim"])
	pending = {"by": by, "made": d.get("made", false), "pts": d.get("pts", 2)}
	flight_t = 0.0
	if bool(d.get("dunk", false)):
		flight_t = 2.2    # la schiacciata si risolve da se': solo pausa
		ball_live = false
		ball_pos = RIM
		ball_h = RIM_HEIGHT


# ------------------------------------------------------------------ rete
func _send(delta: float) -> void:
	_send_t -= delta
	if _send_t > 0.0:
		return
	_send_t = 1.0 / SEND_HZ
	if not _net_ok:
		return
	var d := {
		"p": player_pos, "f": facing, "k": _my_kind(), "a": _my_amount(),
		"ph": dribble_t, "dp": dunk_phase, "ds": dunk_style, "da": dunk_anim,
		"ht": hang_swing_t, "ho": _hang_one(),
	}
	if NetLayer.role == "host":
		d["bl"] = ball_live
		d["bp"] = ball_pos
		d["bh"] = ball_h
		d["bs"] = ball_spin
		d["sm"] = score_me
		d["sf"] = score_foe
	NetLayer.rpc("rpc_duel_me", d)


func _my_kind() -> String:
	if dunk_phase == "hang":
		return Avatar.REACH
	if dunk_phase != "":
		return Avatar.DUNK
	if shot_anim > 0.0:
		return Avatar.SHOOT
	if pump_t > 0.0:
		return Avatar.SHOOT
	if charging:
		return Avatar.SHOOT
	if joystick and joystick.output.length() > 0.06:
		return Avatar.DRIBBLE
	return Avatar.DRIBBLE


func _my_amount() -> float:
	if dunk_phase == "hang":
		return 1.0
	if dunk_phase != "":
		return clampf(dunk_anim / maxf(dunk_rise_t, 0.05), 0.0, 1.0) \
			if dunk_phase == "rise" else 1.0 - clampf(dunk_anim / 0.5, 0.0, 1.0)
	if shot_anim > 0.0:
		return clampf(shot_anim / 0.22, 0.0, 1.0)
	if pump_t > 0.0:
		var k: float = 1.0 - pump_t / 0.35
		return 0.25 + 0.60 * (1.0 - absf(k * 2.0 - 1.0))
	if charging:
		return 1.0 - clampf(charge / maxf(ideal, 0.01), 0.0, 1.0) * 0.85
	return 0.0


func _hang_one() -> bool:
	if dunk_phase == "":
		return false
	return not bool(DunkStyle.sample(dunk_style, 1.0).get("both", false))


func _on_foe_state(d: Dictionary) -> void:
	foe["t_pos"] = d.get("p", foe["t_pos"])
	foe["facing"] = d.get("f", foe["facing"])
	foe["kind"] = d.get("k", Avatar.DRIBBLE)
	foe["amount"] = d.get("a", 0.0)
	foe["phase"] = d.get("ph", 0.0)
	foe["dp"] = d.get("dp", "")
	foe["ds"] = d.get("ds", "")
	foe["da"] = d.get("da", 0.0)
	foe["ht"] = d.get("ht", 0.0)
	foe["ho"] = d.get("ho", false)
	if NetLayer.role == "client":
		# la palla dell'host (quando non e' il mio tiro in locale)
		if not my_shot_live:
			ball_live = bool(d.get("bl", false))
			ball_pos = d.get("bp", ball_pos)
			ball_h = d.get("bh", ball_h)
			ball_spin = d.get("bs", ball_spin)
		var sm: int = int(d.get("sm", score_me))
		var sf: int = int(d.get("sf", score_foe))
		if sm != score_me or sf != score_foe:
			score_me = sm
			score_foe = sf
			_lbl_top_refresh()


func _on_foe_shot(d: Dictionary) -> void:
	## L'host riceve il tiro del cliente: lo applica.
	if NetLayer.role == "host":
		_host_apply_shot(1, d)
		if bool(d.get("dunk", false)):
			net_wobble = 1.0
			if court_art != null:
				court_art.net_bump(1, 1.0)


func _on_foe_look(d: Dictionary) -> void:
	foe["name"] = String(d.get("name", "?"))
	foe["look"] = d
	foe["seen"] = true
	foe_colours = {
		"skin": d.get("skin", Color(0.72, 0.53, 0.38)),
		"hair": d.get("hair", Color(0.16, 0.13, 0.12)),
		"jersey": d.get("jersey", Color(0.5, 0.2, 0.2)),
		"shorts": (d.get("jersey", Color(0.5, 0.2, 0.2)) as Color).darkened(0.45),
		"shoes": d.get("shoes", Color(0.9, 0.9, 0.92)),
		"num": str(int(d.get("num", 7))),
		"kit": false,
		"trim": Color(0.95, 0.95, 0.97),
	}
	_lbl_top_refresh()


func _on_ev(d: Dictionary) -> void:
	_ev_apply(d)


func _ev_broadcast(ev: Dictionary) -> void:
	## Host: esegue e spedisce.
	_ev_apply(ev)
	NetLayer.rpc("rpc_duel_ev", ev)


func _ev_apply(ev: Dictionary) -> void:
	var t: String = String(ev.get("t", ""))
	match t:
		"begin":
			game_on = true
			holder = int(ev.get("poss", 0))
			if holder == 0:
				_say(Loc.t("duel.yourball"))
			else:
				_say(Loc.t("duel.hisball") % String(foe.get("name", "?")))
			_lbl_top_refresh()
		"score":
			score_me = int(ev.get("me", score_me))
			score_foe = int(ev.get("foe", score_foe))
			_lbl_top_refresh()
			var by: int = int(ev.get("by", 0))
			if by == 0:
				_say("%s +%d" % [Loc.t("duel.basket"), int(ev.get("pts", 2))])
			else:
				_say("%s +%s" % [String(foe.get("name", "?")), int(ev.get("pts", 2))])
		"score_sync":
			score_me = int(ev.get("me", score_me))
			score_foe = int(ev.get("foe", score_foe))
			_lbl_top_refresh()
		"possess":
			holder = int(ev.get("who", 0))
			ball_live = false
			my_shot_live = false
			pending = {}
			if bool(ev.get("check", false)):
				_say(Loc.t("duel.check") % (String(foe.get("name", "?"))
					if holder == 1 else Loc.t("duel.you")))
		"win":
			over = true
			game_on = false
			var w: int = int(ev.get("w", 0))
			lbl_mid.text = (Loc.t("duel.youwin") if w == 0 else
				Loc.t("duel.hewins") % String(foe.get("name", "?"))) + \
				"  %d-%d" % [int(ev.get("me", 0)), int(ev.get("foe", 0))]
			var again: Button = get_meta("again") if has_meta("again") else null
			if again != null:
				again.visible = NetLayer.role == "host"
			btn_shoot.visible = false
		"restart":
			_restart()
		"start":
			pass
		_:
			pass


func _restart() -> void:
	score_me = 0
	score_foe = 0
	streak = 0
	hot = false
	over = false
	game_on = true
	ball_live = false
	my_shot_live = false
	pending = {}
	dunk_phase = ""
	charging = false
	meter.visible = false
	btn_shoot.visible = true
	var again: Button = get_meta("again") if has_meta("again") else null
	if again != null:
		again.visible = false
	player_pos = Vector2(RIM.x - 640.0, -140.0)
	foe["t_pos"] = Vector2(RIM.x - 640.0, 160.0)
	foe["pos"] = Vector2(RIM.x - 640.0, 160.0)
	holder = 0
	_lbl_top_refresh()
	_say(Loc.t("duel.yourball"))


func _tap_rematch() -> void:
	if NetLayer.role == "host":
		_ev_broadcast({"t": "restart"})


func _on_net_lost() -> void:
	Events.toast.emit(Loc.t("duel.lost"))
	NetLayer.close()
	SceneRouter.goto("res://src/scenes/MainMenu.tscn")


func _leave() -> void:
	NetLayer.close()
	SceneRouter.goto("res://src/scenes/MainMenu.tscn")


# ------------------------------------------------------------------ disegno
func _screen(p: Vector2) -> Vector2:
	return CourtStage.m_project(p, Court.COURT_H)


func _rim_screen() -> Vector2:
	return _screen(RIM) + Vector2(0.0, -RIM_HEIGHT)


func _distance_ft() -> float:
	return player_pos.distance_to(RIM) / Court.PX_PER_FT


func _draw() -> void:
	_draw_char(true)
	_draw_char(false)
	# palla in volo (o dell'host, per il cliente)
	if ball_live:
		var bs: Vector2 = _screen(ball_pos)
		var bpos := Vector2(bs.x, bs.y - ball_h)
		_draw_ball_at(bpos, BALL_R)
		if ball_h < RIM_HEIGHT + 30.0 and (ball_pos - RIM).length() < 70.0:
			HoopArt.draw_net_front(self, _rim_screen(), 22.0,
				22.0 * HoopArt.RIM_SQUASH, net_wobble, net_t, 0.0, -1.0)
	# nomi sopra la testa: ci si conosce, al campetto
	_draw_name(player_pos, Loc.t("duel.you"), Color(0.55, 0.85, 1.0))
	if foe["seen"]:
		_draw_name(foe["pos"], String(foe.get("name", "?")), Color(1.0, 0.82, 0.35))


func _draw_name(world: Vector2, txt: String, col: Color) -> void:
	var s: Vector2 = _screen(world)
	var h: float = 64.0 * Game.height_factor()
	var f: Font = ThemeDB.fallback_font
	draw_string(f, Vector2(s.x - 60.0, s.y - h - 26.0), txt,
		HORIZONTAL_ALIGNMENT_CENTER, 120.0, 15, col)


func _draw_ball_at(p: Vector2, r: float) -> void:
	draw_circle(p, r, Color(0.95, 0.55, 0.15))
	draw_arc(p, r, 0, TAU, 18, Color(0.35, 0.18, 0.07), 2.0)
	var a: float = ball_spin
	draw_line(p + Vector2(cos(a), sin(a)) * -r, p + Vector2(cos(a), sin(a)) * r,
		Color(0.35, 0.18, 0.07), 2.0)
	var b: float = a + PI * 0.5
	draw_arc(p, r * 0.86, b - 1.1, b + 1.1, 10, Color(0.35, 0.18, 0.07), 2.0)


## Disegna un giocatore (il mio o l'avversario) con l'Avatar condiviso:
## stesse pose, stesse proporzioni del campetto.
func _draw_char(mine: bool) -> void:
	var world: Vector2 = player_pos if mine else (foe["pos"] as Vector2)
	var f: float = facing if mine else float(foe.get("facing", -1.0))
	var kind: String = _my_kind() if mine else String(foe.get("kind", Avatar.DRIBBLE))
	var amount: float = _my_amount() if mine else float(foe.get("amount", 0.0))
	var phase: float = dribble_t if mine else float(foe.get("phase", 0.0))
	var dp: String = dunk_phase if mine else String(foe.get("dp", ""))
	var ds: String = dunk_style if mine else String(foe.get("ds", ""))
	var ht: float = hang_swing_t if mine else float(foe.get("ht", 0.0))
	var cols: Dictionary = Avatar.colours(true) if mine else foe_colours
	if not mine and cols.is_empty():
		cols = {"skin": Color(0.72, 0.53, 0.38), "hair": Color(0.16, 0.13, 0.12),
			"jersey": Color(0.45, 0.22, 0.22), "shorts": Color(0.28, 0.14, 0.14),
			"shoes": Color(0.9, 0.9, 0.92), "num": "7", "kit": false}
	var h: float = 64.0 * Game.height_factor() if mine \
		else 64.0 * float((foe.get("look") as Dictionary).get("hf", 1.0)) \
		if foe["seen"] else 64.0

	var hold_ball: bool = (holder == 0 and mine) or (holder == 1 and not mine)
	hold_ball = hold_ball and not ball_live and not my_shot_live and dp == ""

	var po: Dictionary = Avatar.pose(kind, phase, amount, "", false)
	po["hand"] = -1.0 if hand_left else 1.0
	var lift := 0.0
	var draw_base := world
	var slam: Dictionary = {}
	var hang_pivot := Vector2.ZERO
	var hang_theta := 0.0
	var hang_body := false
	var hang_one := _hang_one() if mine else bool(foe.get("ho", false))
	var hang_feet_off := Vector2.ZERO

	if dp == "rise":
		var rim_x: Vector2 = RIM - Vector2(20.0, 0.0)
		var fr: float = clampf((dunk_anim if mine else float(foe.get("da", 0.0))) / maxf(dunk_rise_t, 0.05), 0.0, 1.0)
		var hang_lift: float = maxf(RIM_HEIGHT - h * DunkStyle.REACH, 0.0)
		lift = sin(fr * PI * 0.5) * hang_lift
		draw_base = world.lerp(rim_x, smoothstep(0.0, 0.62, fr))
		slam = DunkStyle.sample(ds, fr)
		hold_ball = true
	elif dp == "hang":
		var rim_x2: Vector2 = RIM - Vector2(20.0, 0.0)
		var hd: float = -1.0 if hand_left else 1.0
		if hang_one:
			hang_pivot = _rim_screen() + Vector2(-11.0 - hd * h * 0.139,
				22.0 * HoopArt.RIM_SQUASH)
		else:
			hang_pivot = _rim_screen() + Vector2(-17.0, 22.0 * HoopArt.RIM_SQUASH * 0.9)
		hang_theta = sin(ht * 2.0) * 0.10
		hang_body = true
		hang_feet_off = Vector2(0.0, h * 1.20)
		if hang_one:
			hang_feet_off.x = -hd * h * 0.06
		lift = _screen(rim_x2).y - (hang_pivot.y + hang_feet_off.y)
		if mine:
			hang_lift_now = lift
		draw_base = rim_x2
		hold_ball = false
	elif dp == "drop":
		var fr2: float = clampf((dunk_anim if mine else float(foe.get("da", 0.0))) / 0.5, 0.0, 1.0)
		draw_base = (RIM - Vector2(20.0, 0.0)).lerp(world, fr2)
		lift = (1.0 - fr2) * maxf(hang_lift_now if mine else 60.0, 60.0)
		slam = DunkStyle.sample(ds, 1.0)
		hold_ball = false

	# ombra a terra
	var sh: Vector2 = _screen(world)
	var grow: float = 1.15 + clampf(lift / 240.0, 0.0, 0.35)
	var rw: float = 14.0 * grow
	var rh: float = 5.5 * grow
	var pts := PackedVector2Array()
	for i in 20:
		var ang: float = TAU * float(i) / 20.0
		pts.append(sh + Vector2(cos(ang) * rw, sin(ang) * rh))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.40))

	var screen: Vector2 = _screen(draw_base) - Vector2(0.0, lift)
	# polvere d'atterraggio (solo la mia: la sua arriva con le pose)
	if mine and dust_t > 0.0:
		var kk: float = clampf(1.0 - dust_t / 0.45, 0.0, 1.0)
		var da: float = (1.0 - kk) * 0.5
		for i in 6:
			var sd: float = -1.0 if i % 2 == 0 else 1.0
			draw_circle(screen + Vector2(sd * (14.0 + 30.0 * kk) * (0.4 + 0.6 * float((i + 1) % 3) / 2.0), -6.0 - (i % 2) * 5.0),
				lerpf(7.0, 2.5, kk), Color(0.85, 0.80, 0.68, da))
	if not slam.is_empty():
		po["dunk"] = slam
	if dp == "hang":
		po["hang"] = true
		po["hang_one"] = hang_one
		# mezza retina davanti, SOTTO il corpo appeso
		HoopArt.draw_net_front(self, _rim_screen(), 22.0,
			22.0 * HoopArt.RIM_SQUASH, net_wobble, net_t, 0.0, -1.0)
	if hang_body:
		draw_set_transform_matrix(Transform2D(hang_theta, hang_pivot))
		Avatar.draw_body(self, hang_feet_off, h, f, po, cols, false, false, mine, BALL_R)
		draw_set_transform_matrix(Transform2D())
	else:
		Avatar.draw_body(self, screen, h, f, po, cols, hold_ball, true, mine, BALL_R)
	# la palla della schiacciata che cade nella retina
	if dp == "hang" or dp == "drop":
		var fdt: float = clampf(dunk_ball_t * 1.7, 0.0, 1.0)
		_draw_ball_at(_rim_screen().lerp(_screen(RIM), fdt * fdt), BALL_R)
	# fiamme quando sono HOT
	if mine and hot and not bool(Settings.get_v("lowgfx", false)):
		Avatar.draw_flames(self, screen + Vector2(0.0, -h * 1.16),
			Time.get_ticks_msec() / 1000.0)
