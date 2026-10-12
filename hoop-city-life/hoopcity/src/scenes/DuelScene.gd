extends Node2D
## SFIDA UN AMICO — il campetto condiviso (passo 2, versione "tiri insieme").
##
## Due telefoni, un campetto, palla ciascuno: si cammina, si palleggia, si
## tira insieme. Niente punteggio, niente possesso: e' il riscaldamento
## a due del campetto. L'1v1 coi punti e' il passo dopo.
## Ogni telefono e' padrone del PROPRIO giocatore e della PROPRIA palla:
## il tiro lo decidi tu, sul tuo orologio (il verde non soffre di rete),
## e la palla dell'altro la vedi arrivare a 30 Hz.

const RIM := Vector2(Court.COURT_W * 0.5 - Court.FIBA_HOOP_INSET, 0.0)
const RIM_HEIGHT := Court.RIM_HEIGHT
const RIM_HALF := 42.0
const GRAV := 1800.0
const BALL_R := Court.BALL_R
const CAM_ZOOM := 1.04
const MOVE_SPEED := 310.0
const SEND_HZ := 30.0
const DUNK_R := 132.0          # ~7 piedi dal ferro

var joystick: VirtualJoystick
var meter: ShotMeter
var btn_shoot: TouchButton
var lbl_top: Label
var lbl_mid: Label
var court_art: Node
var _net_ok := false

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
var trick_t := 0.0
var trick_kind := ""

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
	"walk": false, "dp": "", "ds": "", "da": 0.0, "ht": 0.0, "ho": false,
	"dbt": 0.0, "hot": false, "tk": "", "ta": 0.0,
	"name": "?", "look": {}, "seen": false, "live": false,
}
var foe_colours := {}
var foe_ball := {"live": false, "pos": Vector2.ZERO, "h": 0.0, "spin": 0.0}

# ---- la mia palla (sempre mia: torna in mano da sola)
var ball_pos := Vector2.ZERO
var ball_h := 0.0
var ball_vel := Vector2.ZERO
var ball_vh := 0.0
var ball_live := false
var ball_spin := 0.0
var ball_settled := 0.0
var prev_h := 0.0
var prev_pos := Vector2.ZERO

var net_wobble := 0.0
var net_t := 0.0
var _send_t := 0.0
var _msg_t := 0.0
var _look_t := 0.0   # invia l'aspetto ogni 1,2 s: se arriva mentre l'altro
                      # sta ancora caricando la scena, il prossimo passa


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
	NetLayer.duel_look_rx.connect(_on_foe_look)
	NetLayer.disconnected.connect(_on_net_lost)
	if not _net_ok:
		lbl_mid.text = Loc.t("duel.nolink")
		return
	# scambio aspetto: l'altro ti deve vedere COME SEI
	NetLayer.rpc("rpc_duel_look", _my_look())


func _exit_tree() -> void:
	if NetLayer.duel_state.is_connected(_on_foe_state):
		NetLayer.duel_state.disconnect(_on_foe_state)
	if NetLayer.duel_shot_rx.is_connected(_on_foe_shot):
		NetLayer.duel_shot_rx.disconnect(_on_foe_shot)
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

	var btn_trick := TouchButton.new()
	btn_trick.text = "TRICK"
	btn_trick.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_trick.position = Vector2(-416, -172)
	btn_trick.custom_minimum_size = Vector2(118, 118)
	btn_trick.size = Vector2(118, 118)
	btn_trick.pressed_down.connect(_do_trick)
	root.add_child(btn_trick)

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
	trick_t = maxf(0.0, trick_t - delta)
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			lbl_mid.text = ""
	# l'avversario scivola verso l'ultima posizione ricevuta
	var tp: Vector2 = foe["t_pos"]
	foe["pos"] = (foe["pos"] as Vector2).lerp(tp, clampf(14.0 * delta, 0.0, 1.0))
	if _net_ok:
		_my_move(delta)
		_dunk_flow(delta)
		_charge_flow(delta)
		_step_ball(delta)
		_look_t -= delta
		if _look_t <= 0.0:
			_look_t = 1.2
			NetLayer.rpc("rpc_duel_look", _my_look())
	_camera(delta)
	_send(delta)
	# METRO DEL TIRO: come nel campetto — vive SOPRA la testa del tiratore,
	# segue il salto, e dopo il rilascio resta congelato un attimo col
	# verdetto (e' cosi' che si impara il timing).
	if meter:
		if charging:
			meter.visible = true
			meter.frozen = false
			meter.charge = charge
			meter.ideal = ideal
		elif not meter.frozen:
			meter.visible = false
		_place_meter()
	if btn_shoot:
		var want: String = "SHOOT"
		if dunk_phase == "hang":
			want = "LET GO"
		elif dunk_phase == "rise":
			want = "DUNK!"
		elif _can_dunk():
			want = "DUNK"
		if btn_shoot.text != want:
			btn_shoot.text = want
	queue_redraw()


func _my_move(delta: float) -> void:
	if dunk_phase == "rise":
		var rim_x: Vector2 = RIM - Vector2(20.0, 0.0)
		var f: float = clampf(dunk_anim / maxf(dunk_rise_t, 0.05), 0.0, 1.0)
		player_pos = player_pos.lerp(rim_x, smoothstep(0.0, 0.62, f) * 0.5)
		_clamp_me()
		return
	if charging or dunk_phase != "":
		if charging and dunk_phase == "":
			player_pos += joystick.output * 0.25 * MOVE_SPEED * delta
		_clamp_me()
		return
	var mv: Vector2 = joystick.output
	player_pos += mv * MOVE_SPEED * delta
	if absf(mv.x) > 0.12:
		facing = signf(mv.x)
	_clamp_me()


func _can_dunk() -> bool:
	return player_pos.distance_to(RIM) < DUNK_R and dunk_phase == ""


func _meter_lift() -> float:
	## Quanto il tiratore e' sollevato da terra: il metro gli sale accanto
	## durante una schiacciata invece di restare giu'.
	if dunk_phase == "":
		return 0.0
	var h: float = 64.0 * Game.height_factor()
	var reach: float = maxf(RIM_HEIGHT - h * DunkStyle.REACH, 0.0)
	if dunk_phase == "rise":
		var f: float = clampf(dunk_anim / maxf(dunk_rise_t, 0.05), 0.0, 1.0)
		return sin(f * PI * 0.5) * reach
	return reach


func _place_meter() -> void:
	## L'arco resta direttamente sopra la testa di chi tira, e resta tutto
	## dentro lo schermo anche da fondocampo.
	if meter == null or not has_meta("cam"):
		return
	var cam: Camera2D = get_meta("cam")
	var h: float = 64.0 * Game.height_factor()
	var world: Vector2 = _screen(player_pos) - Vector2(0.0, h + 36.0 + _meter_lift())
	var vp: Vector2 = get_viewport_rect().size
	var scr: Vector2 = (world - cam.position) * cam.zoom + vp * 0.5
	meter.size = Vector2(120, 78)
	var msz: Vector2 = meter.size
	var pos: Vector2 = scr - Vector2(msz.x * 0.5, msz.y)
	pos.x = clampf(pos.x, 8.0, maxf(vp.x - msz.x - 8.0, 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(vp.y - msz.y - 8.0, 8.0))
	meter.position = pos


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
	if dunk_phase == "rise" and dunk_anim >= dunk_rise_t:
		dunk_phase = "hang"
		dunk_anim = 0.0
		hang_swing_t = 0.0
		dunk_ball_t = 0.0
		_dunk_throw()


func _do_trick() -> void:
	## TRICK: crossover, dietro la schiena o spin — a caso, come nel
	## campetto solo. Solo a palla in mano.
	if trick_t > 0.0 or dunk_phase != "" or ball_live or charging:
		return
	trick_kind = ["cross", "behind", "spin"].pick_random()
	trick_t = 0.45


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
	return not ball_live and dunk_phase == ""


func _shoot_down() -> void:
	if not _net_ok or not _i_have_ball():
		return
	if _can_dunk():
		_start_dunk()
		return
	charging = true
	charge = 0.0
	ideal = clampf(0.42 + _distance_ft() * 0.012, 0.42, 0.78)
	var w: Dictionary = ShotSystem.shot_windows(_distance_ft(), hot)
	meter.perfect_window = float(w["perfect"])
	meter.good_window = float(w["good"])


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
	streak += 1
	if streak >= 3 and not hot:
		hot = true
		Events.popup.emit("ON FIRE!", player_pos, Color(1.0, 0.55, 0.15), true)
	NetLayer.rpc("rpc_duel_shot", {"dunk": true, "made": true, "pts": 2,
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
	# tap veloce: pump fake, niente tiro
	if charge < 0.17:
		charging = false
		charge = 0.0
		pump_t = 0.35
		if meter:
			meter.charge = 0.0
		return
	charging = false
	var w: Dictionary = ShotSystem.shot_windows(_distance_ft(), hot)
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
	# streak: come nel campetto, solo i canestri contano
	if made:
		streak += 1
		if streak >= 3 and not hot:
			hot = true
			Events.popup.emit("ON FIRE!", player_pos, Color(1.0, 0.55, 0.15), true)
		_say("+%d  ·  x%d" % [pts, streak])
	else:
		hot = false
		streak = 0
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
	_launch_ball(player_pos, aim)
	NetLayer.rpc("rpc_duel_shot", {"dunk": false, "made": made, "pts": pts,
		"zone": zone, "from": player_pos, "aim": aim})


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
	if ball_settled > 0.6:
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


# ------------------------------------------------------------------ rete
func _send(delta: float) -> void:
	_send_t -= delta
	if _send_t > 0.0 or not _net_ok:
		return
	_send_t = 1.0 / SEND_HZ
	var d := {
		"p": player_pos, "f": facing, "k": _my_kind(), "a": _my_amount(),
		"ph": dribble_t, "w": _my_walking(), "dp": dunk_phase, "ds": dunk_style,
		"da": dunk_anim, "ht": hang_swing_t, "ho": _hang_one(),
		"dbt": dunk_ball_t, "hot": hot,
		"tk": trick_kind if trick_t > 0.0 else "",
		"ta": trick_t / 0.45,
		"bl": ball_live, "bp": ball_pos, "bh": ball_h, "bs": ball_spin,
	}
	NetLayer.rpc("rpc_duel_me", d)


func _my_kind() -> String:
	if dunk_phase == "hang":
		return Avatar.REACH
	if dunk_phase != "":
		return Avatar.DUNK
	if shot_anim > 0.0 or pump_t > 0.0 or charging:
		return Avatar.SHOOT
	return Avatar.DRIBBLE


func _my_amount() -> float:
	if dunk_phase == "hang":
		return 1.0
	if dunk_phase == "rise":
		return clampf(dunk_anim / maxf(dunk_rise_t, 0.05), 0.0, 1.0)
	if dunk_phase == "drop":
		return 1.0 - clampf(dunk_anim / 0.5, 0.0, 1.0)
	if shot_anim > 0.0:
		return clampf(shot_anim / 0.22, 0.0, 1.0)
	if pump_t > 0.0:
		var k: float = 1.0 - pump_t / 0.35
		return 0.25 + 0.60 * (1.0 - absf(k * 2.0 - 1.0))
	if charging:
		return 1.0 - clampf(charge / maxf(ideal, 0.01), 0.0, 1.0) * 0.85
	if trick_t > 0.0:
		return trick_t / 0.45
	return 0.0


func _my_walking() -> bool:
	return joystick != null and joystick.output.length() > 0.12 \
		and dunk_phase == "" and shot_anim <= 0.0 and not charging


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
	foe["walk"] = d.get("w", false)
	foe["dp"] = d.get("dp", "")
	foe["ds"] = d.get("ds", "")
	foe["da"] = d.get("da", 0.0)
	foe["ht"] = d.get("ht", 0.0)
	foe["ho"] = d.get("ho", false)
	foe["dbt"] = d.get("dbt", 0.0)
	foe["hot"] = d.get("hot", false)
	foe["tk"] = d.get("tk", "")
	foe["ta"] = d.get("ta", 0.0)
	foe["live"] = true
	foe_ball["live"] = bool(d.get("bl", false))
	foe_ball["pos"] = d.get("bp", foe_ball["pos"])
	foe_ball["h"] = d.get("bh", foe_ball["h"])
	foe_ball["spin"] = d.get("bs", foe_ball["spin"])


func _on_foe_shot(d: Dictionary) -> void:
	## Il tiro dell'altro: la palla viaggia gia' coi suoi stati; qui arrivano
	## solo gli effetti del verdetto (la retina che si muove se ha segnato).
	if bool(d.get("made", false)):
		net_wobble = 1.0
		if court_art != null:
			court_art.net_bump(1, 1.0)


func _on_foe_look(d: Dictionary) -> void:
	foe["name"] = String(d.get("name", "?"))
	foe["look"] = d
	foe["seen"] = true
	var j: Color = d.get("jersey", Color(0.5, 0.2, 0.2))
	foe_colours = {
		"skin": d.get("skin", Color(0.72, 0.53, 0.38)),
		"hair": d.get("hair", Color(0.16, 0.13, 0.12)),
		"jersey": j,
		"shorts": j.darkened(0.45),
		"shoes": d.get("shoes", Color(0.9, 0.9, 0.92)),
		"num": str(int(d.get("num", 7))),
		"kit": false,
		"trim": Color(0.95, 0.95, 0.97),
	}
	lbl_top.text = "%s  ·  %s" % [Loc.t("duel.you"), foe["name"]]


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
	if foe["seen"] or foe["live"]:
		_draw_char(false)
	# la palla dell'altro (quando e' in volo)
	if (foe["seen"] or foe["live"]) and bool(foe_ball["live"]):
		var fbs: Vector2 = _screen(foe_ball["pos"])
		_draw_ball_at(Vector2(fbs.x, fbs.y - float(foe_ball["h"])), BALL_R,
			float(foe_ball["spin"]))
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


func _draw_ball_at(p: Vector2, r: float, spin := 0.0) -> void:
	draw_circle(p, r, Color(0.95, 0.55, 0.15))
	draw_arc(p, r, 0, TAU, 18, Color(0.35, 0.18, 0.07), 2.0)
	var a: float = spin
	draw_line(p + Vector2(cos(a), sin(a)) * -r, p + Vector2(cos(a), sin(a)) * r,
		Color(0.35, 0.18, 0.07), 2.0)
	var b: float = a + PI * 0.5
	draw_arc(p, r * 0.86, b - 1.1, b + 1.1, 10, Color(0.35, 0.18, 0.07), 2.0)
	# retina davanti alla palla quando passa nel ferro
	if ball_near_rim(p):
		HoopArt.draw_net_front(self, _rim_screen(), 22.0,
			22.0 * HoopArt.RIM_SQUASH, net_wobble, net_t, 0.0, -1.0)


func ball_near_rim(p: Vector2) -> bool:
	return p.distance_to(_rim_screen()) < 60.0


## Disegna un giocatore (il mio o l'altro) con l'Avatar condiviso: stesse
## pose, stesse proporzioni, camminata e trick compresi.
func _draw_char(mine: bool) -> void:
	var world: Vector2 = player_pos if mine else (foe["pos"] as Vector2)
	var f: float = facing if mine else float(foe.get("facing", -1.0))
	var kind: String = _my_kind() if mine else String(foe.get("kind", Avatar.DRIBBLE))
	var amount: float = _my_amount() if mine else float(foe.get("amount", 0.0))
	var phase: float = dribble_t if mine else float(foe.get("phase", 0.0))
	var walking: bool = _my_walking() if mine else bool(foe.get("walk", false))
	var dp: String = dunk_phase if mine else String(foe.get("dp", ""))
	var ds: String = dunk_style if mine else String(foe.get("ds", ""))
	var da: float = dunk_anim if mine else float(foe.get("da", 0.0))
	var ht: float = hang_swing_t if mine else float(foe.get("ht", 0.0))
	var dbt: float = dunk_ball_t if mine else float(foe.get("dbt", 0.0))
	var tk: String = (trick_kind if trick_t > 0.0 else "") if mine \
		else String(foe.get("tk", ""))
	var ta: float = (trick_t / 0.45) if mine else float(foe.get("ta", 0.0))
	var cols: Dictionary = Avatar.colours(true) if mine else foe_colours
	if not mine and cols.is_empty():
		cols = {"skin": Color(0.72, 0.53, 0.38), "hair": Color(0.16, 0.13, 0.12),
			"jersey": Color(0.45, 0.22, 0.22), "shorts": Color(0.28, 0.14, 0.14),
			"shoes": Color(0.9, 0.9, 0.92), "num": "7", "kit": false}
	var h: float = 64.0 * Game.height_factor() if mine \
		else 64.0 * float((foe.get("look") as Dictionary).get("hf", 1.0))

	var hold_ball: bool
	if mine:
		hold_ball = not ball_live and dp == "" and trick_t <= 0.0
	else:
		hold_ball = not bool(foe_ball["live"]) and dp == "" and tk == ""

	var po: Dictionary = Avatar.pose(kind, phase, amount, tk, walking)
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
		var fr: float = clampf(da / maxf(dunk_rise_t, 0.05), 0.0, 1.0)
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
		var fr2: float = clampf(da / 0.5, 0.0, 1.0)
		draw_base = (RIM - Vector2(20.0, 0.0)).lerp(world, fr2)
		lift = (1.0 - fr2) * maxf(hang_lift_now if mine else 60.0, 60.0)
		slam = DunkStyle.sample(ds, 1.0)
		hold_ball = false

	# SPIN MOVE: il corpo gira di schiena mentre ruota
	if tk == "spin" and ta > 0.0:
		po["yaw"] = 2.2 * (1.0 - ta)

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
		var da2: float = (1.0 - kk) * 0.5
		for i in 6:
			var sd: float = -1.0 if i % 2 == 0 else 1.0
			draw_circle(screen + Vector2(sd * (14.0 + 30.0 * kk) * (0.4 + 0.6 * float((i + 1) % 3) / 2.0), -6.0 - (i % 2) * 5.0),
				lerpf(7.0, 2.5, kk), Color(0.85, 0.80, 0.68, da2))
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
	# TRICK: la palla passa da una mano all'altra (come nel campetto solo)
	if tk != "" and ta > 0.0:
		var ftk: float = 1.0 - ta
		var from_side: float = 1.0 if hand_left else -1.0
		if not mine:
			from_side = -1.0
		var to_side: float = -from_side
		var sway: float = lerpf(from_side, to_side, smoothstep(0.0, 1.0, ftk))
		var low: float = sin(ftk * PI)
		var bp := screen + Vector2(sway * h * 0.34, -h * 0.16 - low * h * 0.10)
		if tk == "behind":
			bp.y = screen.y - h * 0.30 + low * h * 0.06
		_draw_ball_at(bp, BALL_R)
	# la palla della schiacciata che cade nella retina
	if dp == "hang" or dp == "drop":
		var fdt: float = clampf(dbt * 1.7, 0.0, 1.0)
		_draw_ball_at(_rim_screen().lerp(_screen(RIM), fdt * fdt), BALL_R)
	# fiamme quando e' HOT (le mie in locale, le sue dal suo stato)
	var is_hot: bool = hot if mine else bool(foe.get("hot", false))
	if is_hot and not bool(Settings.get_v("lowgfx", false)):
		Avatar.draw_flames(self, screen + Vector2(0.0, -h * 1.16),
			Time.get_ticks_msec() / 1000.0)
