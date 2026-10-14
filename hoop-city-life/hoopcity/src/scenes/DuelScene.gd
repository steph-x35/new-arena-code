extends Node2D
## SFIDA UN AMICO — il campetto condiviso (passo 2, versione "tiri insieme").
##
## Due telefoni, un campetto: si gioca libero, palla ciascuno — e dalla
## v2.45.0 c'e' anche la SFIDA 1V1: una palla sola, canestri da 2 e da 3
## dietro la linea, chi subisce riparte in attacco, rimbalzo libero con
## uscita dalla linea, a 11/15/21 come lo scelgono i due che giocano.
## Ogni telefono e' padrone del PROPRIO giocatore e della PROPRIA palla:
## il tiro lo decidi tu, sul tuo orologio (il verde non soffre di rete),
## e la palla dell'altro la vedi arrivare a 30 Hz.

const RIM := Vector2(Court.COURT_W * 0.5 - Court.FIBA_HOOP_INSET, 0.0)
const RIM_HEIGHT := Court.RIM_HEIGHT
const RIM_HALF := 42.0
const GRAV := 1800.0
const BALL_R := Court.BALL_R
const CAM_ZOOM := 1.04
const MOVE_SPEED := 255.0
const LEFT_RIM := Vector2(-Court.COURT_W * 0.5 + Court.FIBA_HOOP_INSET, 0.0)
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
var posting := false          # POST UP: spalle al canestro
var euro_t := 0.0             # EUROSTEP: 1 tempo laterale, 2 verso il ferro
var euro_side := Vector2.ZERO
var euro_finish := false
var fade_pending := false     # FADEAWAY: levetta indietro mentre carichi
var fade_t := 0.0
var fade_dir := Vector2.ZERO
var _family_tag := ""
var npcs: Array = []          # i bambini dall'altro lato del campo

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
# La palla dell'altro non viaggia a pezzi: il suo tiro (partenza+arrivo)
# arriva con un messaggio e la simulo QUI, con la mia stessa fisica —
# parabola fluida identica alla mia, e i suoi effetti li vedo e li sento.
var fb_live := false
var fb_pos := Vector2.ZERO
var fb_h := 0.0
var fb_vel := Vector2.ZERO
var fb_vh := 0.0
var fb_spin := 0.0
var fb_prev_h := 0.0
var fb_prev_pos := Vector2.ZERO
var fb_through := false
var fb_rattled := false
var fb_ghost := false
var fb_settled := 0.0

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
var through_rim := false      # la palla e' gia' passata nel canestro
var ball_rattled := false     # ha gia' sbattuto sul ferro (rattle)
var ball_ghost := false       # tiro verde: passa pulito, niente ferro

var net_wobble := 0.0
var net_t := 0.0
var _send_t := 0.0
var _msg_t := 0.0
var _look_t := 0.0   # invia l'aspetto ogni 1,2 s: se arriva mentre l'altro
                      # sta ancora caricando la scena, il prossimo passa

# ---- SFIDA 1V1 (v2.45.0): una palla sola, punteggio e possesso.
# Il gioco libero resta esattamente com'e': il 1v1 vive dietro duel_on, e
# ogni decisione la prende chi la vive (come i tiri) e la spedisce con
# gli eventi reliable — nessun arbitro, la rete fa da testimone.
var duel_on := false             # partita in corso
var duel_phase := ""             # "" | count | live | over
var duel_target := 11            # a quanti punti si vince
var my_score := 0
var foe_score := 0
var i_attack := false            # la palla e' mia (o tocca a me ripartire)
var ball_loose := false          # palla viva a terra: rimbalzo di chi la prende
var my_rebound := false          # il tiro sbagliato e' il mio (fisica ball_*)
var must_clear := false          # devo uscire dalla linea prima di tirare
var _win := false
var _count_t := 0.0
var _loose_t := 0.0
var _pick_ok := false            # la mia palla ha toccato ferro/terra: si puo' prendere
var _fb_pick_ok := false         # idem per la palla dell'altro
var _took_at := 0                # quando ho preso l'ultimo rimbalzo (gara di contemporaneita')
var _pending_target := 11        # target della sfida ricevuta, in attesa di risposta
var btn_sfida: Button
var btn_end: Button
var btn_trick: TouchButton
var btn_post: TouchButton
var _panel: CanvasLayer = null
var _free_sent_at := 0        # quando ho chiuso la partita (le gare di click non contano)
var _def_held := false        # DIFENDI premuto: braccia su, contest se vicino
var _base_pw := 0.0           # finestra del metro senza contest (per restringerla live)
var _base_gw := 0.0
var _contested := false       # il difensore e' addosso mentre carico
var _blocked := false         # SALTO dell'altro a pochi passi: stoppata
var _jump_t := 0.0            # il mio SALTO (braccia alte in aria)
var ball_holder := -1         # LIBERO: di chi e' la palla (0 io, 1 lui, -1 a terra)
var btn_guard: TouchButton


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
	_spawn_npcs()
	_net_ok = (NetLayer.state == NetLayer.State.CONNECTED) \
		or (NetLayer.role == "host" and NetLayer._has_peer)
	NetLayer.duel_state.connect(_on_foe_state)
	NetLayer.duel_shot_rx.connect(_on_foe_shot)
	NetLayer.duel_ev_rx.connect(_on_foe_ev)
	NetLayer.duel_look_rx.connect(_on_foe_look)
	NetLayer.disconnected.connect(_on_net_lost)
	if not _net_ok:
		lbl_mid.text = Loc.t("duel.nolink")
		return
	# NEL LIBERO la palla e' UNA e di chi la prende: parte in mano a chi
	# ospita il campo (stesso valore su tutti e due i telefoni).
	ball_holder = 0 if NetLayer.role == "host" else 1
	# scambio aspetto: l'altro ti deve vedere COME SEI
	NetLayer.rpc("rpc_duel_look", _my_look())


func _exit_tree() -> void:
	if NetLayer.duel_state.is_connected(_on_foe_state):
		NetLayer.duel_state.disconnect(_on_foe_state)
	if NetLayer.duel_shot_rx.is_connected(_on_foe_shot):
		NetLayer.duel_shot_rx.disconnect(_on_foe_shot)
	if NetLayer.duel_ev_rx.is_connected(_on_foe_ev):
		NetLayer.duel_ev_rx.disconnect(_on_foe_ev)
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

	# IL PAD DEL 1V1 INDORE, STESSE CASELLE: primario in basso, TRICK a
	# sinistra, POST (attacco) o DIFENDI (difesa) a destra. Il primario
	# cambia con la fase: TIRA, SALTO (in difesa), PRENDI PALLA (libero).
	var slot_primary := Vector2(-196.0, -152.0)
	var slot_left := Vector2(-292.0, -258.0)
	var slot_right := Vector2(-128.0, -258.0)
	btn_shoot = TouchButton.new()
	btn_shoot.text = "SHOOT"
	btn_shoot.hold_mode = true
	btn_shoot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_shoot.position = slot_primary
	btn_shoot.custom_minimum_size = Vector2(128, 128)
	btn_shoot.size = Vector2(128, 128)
	btn_shoot.pressed_down.connect(_shoot_down)
	btn_shoot.released.connect(_shoot_up)
	root.add_child(btn_shoot)

	btn_trick = TouchButton.new()
	btn_trick.text = "TRICK"
	btn_trick.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_trick.position = slot_left
	btn_trick.custom_minimum_size = Vector2(108, 108)
	btn_trick.size = Vector2(108, 108)
	btn_trick.pressed_down.connect(_do_trick)
	root.add_child(btn_trick)

	btn_post = TouchButton.new()
	btn_post.text = "POST"
	btn_post.accent = Color(0.980, 0.780, 0.260)
	btn_post.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_post.position = slot_right
	btn_post.custom_minimum_size = Vector2(108, 108)
	btn_post.size = Vector2(108, 108)
	btn_post.pressed_down.connect(_post_tap)
	root.add_child(btn_post)

	# DIFENDI: stessa casella del POST, ma in difesa — come l'indoor, dove
	# attacco e difesa si scambiano le stesse tre caselle.
	btn_guard = TouchButton.new()
	btn_guard.text = Loc.t("duel.def")
	btn_guard.hold_mode = true
	btn_guard.accent = Color(0.870, 0.290, 0.260)
	btn_guard.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_guard.position = slot_right
	btn_guard.custom_minimum_size = Vector2(108, 108)
	btn_guard.size = Vector2(108, 108)
	btn_guard.pressed_down.connect(_guard_down)
	btn_guard.released.connect(_guard_up)
	btn_guard.visible = false
	root.add_child(btn_guard)

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

	# SFIDA 1V1: visibile solo quando c'e' l'amico sul campo (e nessuna
	# partita in corso) — lo decide _duel_tick a ogni frame.
	var sfida := Button.new()
	sfida.text = Loc.t("duel.sfida")
	sfida.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sfida.position = Vector2(-110, 22)
	sfida.custom_minimum_size = Vector2(220, 56)
	sfida.add_theme_font_size_override("font_size", 22)
	sfida.pressed.connect(_sfida_panel)
	sfida.visible = false
	root.add_child(sfida)
	btn_sfida = sfida

	# FINE PARTITA (solo mentre il 1v1 e' in corso): si chiude e si torna
	# a tirare insieme, senza lasciare il campo.
	var fine := Button.new()
	fine.text = Loc.t("duel.end")
	fine.set_anchors_preset(Control.PRESET_CENTER_TOP)
	fine.position = Vector2(-110, 22)
	fine.custom_minimum_size = Vector2(220, 56)
	fine.add_theme_font_size_override("font_size", 22)
	fine.pressed.connect(_end_match)
	fine.visible = false
	root.add_child(fine)
	btn_end = fine


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
	_jump_t = maxf(0.0, _jump_t - delta)
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			lbl_mid.text = ""
	# l'avversario scivola verso l'ultima posizione ricevuta
	if court_art != null:
		court_art.solo_hang = (dunk_phase == "hang")
	var tp: Vector2 = foe["t_pos"]
	foe["pos"] = (foe["pos"] as Vector2).lerp(tp, clampf(14.0 * delta, 0.0, 1.0))
	# EUROSTEP: due tempi — laterale, poi esplosione verso il ferro — e
	# chiusura automatica (schiacciata se vicino, layup se no)
	if euro_t > 0.0:
		euro_t = maxf(0.0, euro_t - delta)
		if euro_t > 0.30:
			player_pos += euro_side * 430.0 * delta
		else:
			player_pos += (RIM - player_pos).normalized() * 470.0 * delta
		_clamp_me()
		if euro_t <= 0.0 and euro_finish:
			euro_finish = false
			if _can_dunk():
				_start_dunk()
			else:
				charging = true
				ideal = clampf(0.42 + _distance_ft() * 0.012, 0.42, 0.78)
				charge = ideal + randf_range(-0.006, 0.006)
				_family_tag = "EUROSTEP"
				_shoot_up()
	# FADEAWAY: dopo il rilascio scivoli all'indietro con la schienata
	if fade_t > 0.0:
		fade_t = maxf(0.0, fade_t - delta)
		if shot_anim > 0.0:
			player_pos += fade_dir * 55.0 * delta
			_clamp_me()
	_update_npcs(delta)
	_step_foe_ball(delta)
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
	_duel_tick(delta)
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
		if duel_on and duel_phase == "live" and not i_attack and not ball_loose:
			want = Loc.t("duel.jump")
		elif not duel_on and not _pad_holding() and not ball_live:
			want = Loc.t("duel.grab")
		elif dunk_phase == "hang":
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
	player_pos += mv * (155.0 if posting else MOVE_SPEED) * delta
	if absf(mv.x) > 0.12 and not posting:
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
	## Il confine e' il RETTANGOLO DIPINTO del campo (come nel campetto
	## solo): niente girovagare fuori dal parquet.
	var m := 40.0
	player_pos.x = clampf(player_pos.x, -Court.COURT_W * 0.5 + m, Court.COURT_W * 0.5 - m)
	player_pos.y = clampf(player_pos.y, -Court.COURT_H * 0.5 + m, Court.COURT_H * 0.5 - m)


func _charge_flow(delta: float) -> void:
	if charging:
		charge += delta
		if meter:
			meter.charge = clampf(charge / maxf(ideal, 0.01), 0.0, 1.15)
			# CONTEST: il difensore con le braccia alzate addosso al tiratore
			# restringe la finestra IN DIRETTA — difendersi serve davvero.
			if duel_on:
				var fpos2: Vector2 = foe["pos"] as Vector2
				var near: bool = fpos2.distance_to(player_pos) < 150.0
				_contested = bool(foe.get("ct", false)) and near
				_blocked = bool(foe.get("jm", false)) and near
				var mult: float = 0.50 if _blocked else (0.68 if _contested else 1.0)
				meter.perfect_window = _base_pw * mult
				meter.good_window = _base_gw * (0.70 if _blocked else (0.85 if _contested else 1.0))


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
			# TONFO: polvere grande + suono sordo, come nei match.
			dust_big = true
			dust_t = 0.70
			Sfx.play("body", -6.0, randf_range(0.90, 1.0))
	if dunk_phase == "rise" and dunk_anim >= dunk_rise_t:
		_dunk_throw()
		# La rete canta ESATTAMENTE una volta: al momento della schiacciata.
		Sfx.play("swish", -1.0, randf_range(0.84, 0.90))
		dunk_phase = "hang"
		dunk_anim = 0.0
		hang_swing_t = 0.0
		dunk_ball_t = 0.0
		# l'aggancio al ferro: il clangore che resta (via il cigolio da v2.41.2)
		Sfx.play("rim", -6.0, 0.72)
		Sfx.haptic(45)


func _do_trick() -> void:
	## TRICK come nel campetto solo: verso il ferro diventa EUROSTEP,
	## dal post e' un DROP STEP, altrimenti la mossa la decide il joystick.
	if not _i_have_ball() or (duel_on and must_clear):
		return
	if trick_t > 0.0 or dunk_phase != "" or ball_live or charging or euro_t > 0.0:
		return
	# EUROSTEP: corri verso il ferro entro 14 ft e TRICK diventa il passo
	# laterale a due tempi (chiusura automatica a schiacciata/layup).
	var to_rim: Vector2 = RIM - player_pos
	var mv_e: Vector2 = joystick.output if joystick != null else Vector2.ZERO
	if not posting and to_rim.length() / Court.PX_PER_FT < 14.0 \
	and mv_e.dot(to_rim.normalized()) > 0.50:
		euro_t = 0.52
		euro_finish = true
		var rn: Vector2 = to_rim.normalized()
		euro_side = Vector2(-rn.y, rn.x)
		if mv_e.dot(euro_side) < 0.0:
			euro_side = -euro_side
		hand_left = not hand_left
		facing = 1.0
		Sfx.squeak()
		_say("EUROSTEP", 1.2)
		return
	# POST: TRICK = DROP STEP, scatto attorno al difensore verso il ferro.
	if posting:
		var hr: Vector2 = (RIM - player_pos).normalized()
		var sd: Vector2 = Vector2(-hr.y, hr.x)
		if sd.dot(Vector2(facing, 0)) < 0.0:
			sd = -sd
		player_pos += sd * 95.0 + hr * 40.0
		_clamp_me()
		hand_left = not hand_left
		posting = false
		if absf(hr.x) > 0.2:
			facing = signf(hr.x)
		trick_kind = "dropstep"
		trick_t = 0.45
		Sfx.squeak()
		_say("DROP STEP", 1.2)
		return
	# TRICK col joystick: hesi, cambio mano, stepback, spin, crossover
	var mv: Vector2 = joystick.output if joystick != null else Vector2.ZERO
	if mv.length() < 0.25:
		trick_kind = "hesi"
	elif mv.y > 0.35:
		trick_kind = "hand_switch"
		hand_left = not hand_left
	elif mv.x < -0.35:
		trick_kind = "stepback"
		player_pos += (player_pos - RIM).normalized() * 70.0
		_clamp_me()
	elif mv.y < -0.35:
		trick_kind = "spin"
	else:
		trick_kind = ["cross", "behind"].pick_random()
	trick_t = 0.45

func _post_tap() -> void:
	## POST UP: spalle al canestro. TIRA = fade/hook, TRICK = drop step.
	if not _i_have_ball():
		return
	if charging or dunk_phase != "" or ball_live or euro_t > 0.0:
		return
	posting = not posting
	if posting:
		var hx: float = RIM.x - player_pos.x
		if absf(hx) > 1.0:
			facing = -signf(hx)
		_say("POST", 1.2)


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
	if duel_on and (duel_phase != "live" or not i_attack or ball_loose):
		return false
	if not duel_on and (ball_holder != 0 or ball_loose):
		return false
	return not ball_live and dunk_phase == ""


func _pad_holding() -> bool:
	## Ho la palla in mano (per i tasti): nel 1v1 quando attacco, nel
	## libero quando la palla e' mia.
	if duel_on:
		return duel_phase == "live" and i_attack and not ball_loose and not ball_live
	return _net_ok and ball_holder == 0 and not ball_loose and not ball_live


func _do_jump() -> void:
	## SALTO: come la stoppata dell'indoor — scatti con le braccia alte.
	## Se sei addosso al tiratore mentre carica, la sua finestra si stringe
	## forte e i suoi gialli finiscono coperti.
	if _jump_t > 0.0:
		return
	_jump_t = 0.45
	Sfx.haptic(20)


func _guard_down() -> void:
	_def_held = true


func _guard_up() -> void:
	_def_held = false


func _try_grab_ball() -> void:
	## PRENDI PALLA: la presa del rimbalzo col bottone (raggio piu' largo
	## di quello del camminarci sopra).
	if not ball_loose:
		return
	if my_rebound and ball_live and _pick_ok and ball_h < 110.0 \
	and player_pos.distance_to(ball_pos) < 130.0:
		_take_ball(true, true)
	elif not my_rebound and fb_live and _fb_pick_ok and fb_h < 110.0 \
	and player_pos.distance_to(fb_pos) < 130.0:
		_take_ball(false, true)


func _shoot_down() -> void:
	if duel_on and duel_phase == "live" and not i_attack and not ball_loose:
		_do_jump()           # in difesa il primario e' SALTO, come indoor
		return
	if not duel_on and not _pad_holding():
		_try_grab_ball()     # libero senza palla: PRENDI PALLA
		return
	if not _net_ok or not _i_have_ball():
		if duel_on and i_attack and must_clear:
			_say(Loc.t("duel.clear"), 1.1)
		return
	if duel_on and must_clear:
		_say(Loc.t("duel.clear"), 1.1)
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
	# FADEAWAY: levetta INDIETRO mentre carichi -> schienata: la finestra
	# si stringe, ma la mossa e' tua.
	fade_pending = false
	var mv_f: Vector2 = joystick.output if joystick != null else Vector2.ZERO
	if not posting and mv_f.dot((player_pos - RIM).normalized()) > 0.40 \
	and _distance_ft() > 8.0:
		fade_pending = true
		meter.perfect_window *= 0.72
		meter.good_window *= 0.85
	_base_pw = meter.perfect_window
	_base_gw = meter.good_window
	_contested = false


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
	if duel_on:
		my_score += 2
		_duel_scored()
	else:
		ball_holder = 0


func _drop_from_rim() -> void:
	if dunk_phase == "hang":
		dunk_phase = "drop"
		dunk_anim = 0.0
		Sfx.haptic(30)


func _shoot_up() -> void:
	_def_held = false
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
	# POST: TIRA = HOOK da vicino, FADEAWAY da lontano (con l'hop indietro)
	if _family_tag != "EUROSTEP":
		_family_tag = ""
	if posting:
		_family_tag = "HOOK!" if _distance_ft() < 9.0 else "FADEAWAY!"
		posting = false
		var away: Vector2 = player_pos - RIM
		if away.length() > 1.0:
			player_pos += away.normalized() * 46.0
			_clamp_me()
	if fade_pending:
		_family_tag = "FADEAWAY!"
		fade_t = 0.75
		fade_dir = (player_pos - RIM).normalized()
		fade_pending = false
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
		if _blocked:
			made = false
			Events.popup.emit(Loc.t("duel.blocked"), player_pos + Vector2(0, -110),
				Color(0.87, 0.29, 0.26), true)
		else:
			made = randf() < (0.30 if _contested else 0.5)
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
		_say((_family_tag + "  " if _family_tag != "" else "") + "+%d  ·  x%d" % [pts, streak])
	else:
		hot = false
		streak = 0
	if made:
		if duel_on:
			my_score += pts
			_duel_scored()
		else:
			ball_holder = 0    # libero: canestro, la palla resta a chi ha tirato
	else:
		ball_loose = true
		my_rebound = true
		_loose_t = 0.0
		_pick_ok = false
		ball_holder = -1
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
	ball_ghost = (zone == "green")
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
	through_rim = false
	ball_rattled = false


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
		_collide_backboard()
		_collide_floor()
	ball_spin += ball_vel.x * 0.0004
	if not ball_loose:
		if ball_pos.x < -1300.0 or ball_pos.x > 1300.0 \
		or ball_pos.y < -Court.COURT_H or ball_pos.y > Court.COURT_H:
			ball_live = false
		if ball_settled > 0.6:
			ball_live = false


func _collide_rim() -> void:
	## Stessa fisica del campetto solo: il punto esatto in cui la palla
	## attraversa l'altezza del ferro decide swish, rattle o ferro e poi.
	if ball_h <= RIM_HEIGHT and prev_h >= RIM_HEIGHT and ball_vh < 0.0:
		_pick_ok = true
		var span: float = prev_h - ball_h
		var f: float = 0.0 if span <= 0.0 else (prev_h - RIM_HEIGHT) / span
		var cx: float = lerpf(prev_pos.x, ball_pos.x, clampf(f, 0.0, 1.0))
		var cy: float = lerpf(prev_pos.y, ball_pos.y, clampf(f, 0.0, 1.0))
		var d: Vector2 = Vector2(cx, cy) - RIM
		var dist: float = d.length()
		if dist < RIM_HALF - 6.0 or (ball_rattled and dist < RIM_HALF + 6.0):
			# RIM-RATTLE (30% dei tiri riusciti): ferro fortissimo, pop sopra
			# il ferro, poi swish — il momento firma del campetto.
			if not ball_rattled and not through_rim and not ball_ghost \
			and randf() < 0.30:
				ball_rattled = true
				var rn_s: Vector2 = (ball_pos - RIM).normalized()
				if rn_s.length() < 0.1:
					rn_s = Vector2(1, 0)
				ball_pos = RIM + rn_s * 9.0
				ball_vh = randf_range(500.0, 640.0)
				ball_vel = rn_s * randf_range(30.0, 55.0) \
					+ Vector2(randf_range(-25, 25), randf_range(-25, 25))
				Sfx.play("rim", -0.5, randf_range(0.95, 1.08))
				net_wobble = 0.9
				Events.shake.emit(0.60)
				if court_art != null:
					if court_art.has_method("rim_fx"):
						court_art.rim_fx("rattle", RIM)
					if court_art.has_method("net_bump"):
						court_art.net_bump(1, 0.9)
				return
			if not through_rim:
				# DENTRO: la RETINA TRATTIENE la palla — la rallenta, cosi'
				# si vede passare dentro la rete, col suo swish.
				through_rim = true
				net_wobble = 1.0
				Sfx.play("swish", -2.5)
				Sfx.haptic(35)
				if court_art != null:
					court_art.net_bump(1, 1.0)
					if court_art.has_method("rim_fx"):
						court_art.rim_fx("swish", RIM)
				ball_vh *= 0.55
				ball_vel *= 0.5
				return
		if dist < RIM_HALF + 14.0 and not ball_ghost:
			var nrm: Vector2 = d.normalized() if dist > 0.01 else Vector2(1, 0)
			ball_pos = RIM + nrm * (RIM_HALF + 12.0)
			ball_vel = ball_vel.bounce(nrm) * 0.5
			net_wobble = maxf(net_wobble, 0.85)
			Sfx.play("rim", -5.0)
			if court_art != null:
				court_art.net_bump(1, 0.85)
				if court_art.has_method("rim_fx"):
					court_art.rim_fx("iron", RIM)
			ball_spin *= -0.6
			return
	# sfiorare la rete senza passare la muove comunque
	var d2: Vector2 = ball_pos - RIM
	if ball_h < RIM_HEIGHT and ball_h > RIM_HEIGHT - 130.0 \
	and d2.length() < RIM_HALF + 26.0:
		net_wobble = maxf(net_wobble, 0.45)
		if court_art != null:
			court_art.net_bump(1, 0.45)

func _collide_backboard() -> void:
	## Il tabellone: piano verticale appena dietro il ferro.
	var bx: float = RIM.x + 42.0
	if ball_h > RIM_HEIGHT - 30.0 and ball_h < RIM_HEIGHT + 90.0:
		if ball_pos.x > bx and ball_vel.x > 0.0:
			ball_pos.x = bx
			ball_vel.x = -absf(ball_vel.x) * 0.55
			ball_vel.y *= 0.8
			net_wobble = maxf(net_wobble, 0.35)
			if court_art != null and court_art.has_method("rim_fx"):
				court_art.rim_fx("iron", RIM)


func _collide_floor() -> void:
	if ball_h < 0.0:
		ball_h = 0.0
		_pick_ok = true
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
		"ct": _def_held,
		"jm": _jump_t > 0.05,
	}
	NetLayer.rpc("rpc_duel_me", d)


func _my_kind() -> String:
	if dunk_phase == "hang":
		return Avatar.REACH
	if dunk_phase != "":
		return Avatar.DUNK
	if shot_anim > 0.0 or pump_t > 0.0 or charging:
		return Avatar.SHOOT
	if _jump_t > 0.09:
		return Avatar.REACH
	var no_ball: bool = (duel_on and (not i_attack or ball_loose) and duel_phase != "over") \
		or (not duel_on and (ball_holder != 0 or ball_loose))
	if no_ball:
		if duel_on and not ball_loose and not i_attack \
		and (_def_held or (foe["pos"] as Vector2).distance_to(player_pos) < 300.0):
			return Avatar.DEFEND
		return Avatar.RUN if _my_walking() else Avatar.IDLE
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
	var prev_dp: String = String(foe.get("dp", ""))
	foe["t_pos"] = d.get("p", foe["t_pos"])
	foe["facing"] = d.get("f", foe["facing"])
	foe["kind"] = d.get("k", Avatar.DRIBBLE)
	foe["amount"] = d.get("a", 0.0)
	foe["phase"] = d.get("ph", 0.0)
	foe["walk"] = d.get("w", false)
	foe["dp"] = d.get("dp", "")
	if String(foe["dp"]) == "hang" and prev_dp != "hang":
		# si e' appeso al ferro: il clangore dell'aggancio, anche per lui
		Sfx.play("rim", -6.0, 0.72)
	foe["ds"] = d.get("ds", "")
	foe["da"] = d.get("da", 0.0)
	foe["ht"] = d.get("ht", 0.0)
	foe["ho"] = d.get("ho", false)
	foe["dbt"] = d.get("dbt", 0.0)
	foe["hot"] = d.get("hot", false)
	foe["tk"] = d.get("tk", "")
	foe["ta"] = d.get("ta", 0.0)
	foe["ct"] = d.get("ct", false)
	foe["jm"] = d.get("jm", false)
	foe["live"] = true
	# (la palla dell'altro non viaggia nello stato: la simula il suo tiro)


func _on_foe_shot(d: Dictionary) -> void:
	## Il tiro dell'altro: la palla la simulo QUI con la stessa parabola
	## (fluida come la mia), e il suo verdetto lo vedo: GREEN, canestro
	## o errore, con popup sopra di lui.
	var fpos: Vector2 = foe["pos"]
	if bool(d.get("dunk", false)):
		net_wobble = 1.0
		if court_art != null:
			court_art.net_bump(1, 1.0)
		Sfx.play("swish", -1.0, randf_range(0.84, 0.90))
		Events.popup.emit("GREEN!", fpos + Vector2(0, -95), Color(0.3, 1.0, 0.45), true)
		if duel_on:
			foe_score += 2
			_duel_foe_scored()
		else:
			ball_holder = 1
		return
	var zone: String = String(d.get("zone", ""))
	if zone == "green":
		Events.popup.emit("GREEN!", fpos + Vector2(0, -95), Color(0.3, 1.0, 0.45), true)
	elif bool(d.get("made", false)):
		Events.popup.emit("+%d" % int(d.get("pts", 2)), fpos + Vector2(0, -80),
			Color(1.0, 0.82, 0.35), true)
	else:
		Events.popup.emit("MISS!", fpos + Vector2(0, -80), Color(1.0, 0.45, 0.38), false)
	if bool(d.get("made", false)):
		if duel_on:
			foe_score += int(d.get("pts", 2))
			_duel_foe_scored()
		else:
			ball_holder = 1      # libero: la palla resta a chi ha segnato
	else:
		ball_loose = true
		my_rebound = false
		_loose_t = 0.0
		_fb_pick_ok = false
		ball_holder = -1
	_foe_launch(d.get("from", fpos), d.get("aim", RIM), zone == "green")


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
	if duel_on:
		_duel_update_top()
	else:
		lbl_top.text = "%s  ·  %s" % [Loc.t("duel.you"), foe["name"]]


func _on_net_lost() -> void:
	Events.toast.emit(Loc.t("duel.lost"))
	NetLayer.close()
	SceneRouter.goto("res://src/scenes/MainMenu.tscn")


func _leave() -> void:
	NetLayer.close()
	SceneRouter.goto("res://src/scenes/MainMenu.tscn")


# ------------------------------------------------------------------ 1v1
## La SFIDA 1V1: tutto quello che accade lo decide chi lo vive (come i
## tiri) e viaggia sui soliti eventi reliable — la rete fa da testimone.
## Una palla sola: canestri da 2, da 3 dietro la linea, chi subisce
## riparte in attacco. Errore = rimbalzo libero: chi lo prende attacca,
## e se prendeva in difesa prima deve uscire dalla linea.

func _duel_tick(delta: float) -> void:
	if btn_sfida != null:
		btn_sfida.visible = _net_ok and bool(foe.get("seen", false)) and not duel_on
	if btn_end != null:
		btn_end.visible = duel_on and duel_phase != "over"
	# Il pad come l'indoor: in attacco TIRA/TRICK/POST, in difesa
	# SALTO (primario) e DIFENDI (destra). Nel libero, senza palla,
	# il primario diventa PRENDI PALLA.
	var defending := duel_on and duel_phase == "live" and not i_attack and not ball_loose
	var holding := _pad_holding()
	if btn_trick != null:
		btn_trick.visible = holding
	if btn_post != null:
		btn_post.visible = holding
	if btn_guard != null:
		btn_guard.visible = defending
	if not duel_on:
		# CAMPO LIBERO: la palla e' UNA — il rimbalzo a terra e' di tutti
		# e due, chi ci arriva prima se la prende (e l'altro la vede sparire).
		if ball_loose:
			_loose_t += delta
			if my_rebound and ball_live and _pick_ok and ball_h < 90.0 \
			and player_pos.distance_to(ball_pos) < 70.0:
				_take_ball(true, true)
			elif not my_rebound and fb_live and _fb_pick_ok and fb_h < 90.0 \
			and player_pos.distance_to(fb_pos) < 70.0:
				_take_ball(false, true)
			elif _loose_t > 8.0:
				_take_ball(true, true)
		return
	if duel_phase == "count":
		_count_t -= delta
		if _count_t <= 0.0:
			duel_phase = "live"
			_duel_update_top()
			_say(Loc.t("duel.go"), 0.9)
			Sfx.haptic(30)
		else:
			lbl_mid.text = str(clampi(int(ceil(_count_t)), 1, 3))
			_msg_t = 0.0
		return
	if duel_phase != "live":
		return
	if i_attack and must_clear and _distance_ft() > Court.THREE_FT + 0.25:
		must_clear = false
		_duel_update_top()
		_say(Loc.t("duel.cleared"), 1.3)
	if ball_loose:
		_loose_t += delta
		if my_rebound and ball_live and _pick_ok and ball_h < 90.0 \
		and player_pos.distance_to(ball_pos) < 56.0:
			_take_ball(true)
		elif not my_rebound and fb_live and _fb_pick_ok and fb_h < 90.0 \
		and player_pos.distance_to(fb_pos) < 56.0:
			_take_ball(false)
		elif _loose_t > 8.0 and not i_attack:
			_take_ball(false)


func _duel_start(target: int, first_role: String) -> void:
	_hide_panels()
	duel_on = true
	duel_phase = "count"
	duel_target = target
	my_score = 0
	foe_score = 0
	hot = false
	streak = 0
	charging = false
	charge = 0.0
	posting = false
	euro_t = 0.0
	fade_t = 0.0
	trick_t = 0.0
	ball_loose = false
	ball_live = false
	fb_live = false
	must_clear = false
	_pick_ok = false
	_fb_pick_ok = false
	_loose_t = 0.0
	_count_t = 3.0
	i_attack = (NetLayer.role == first_role)
	var atk := Vector2(RIM.x - 500.0, -240.0)
	var dfn := Vector2(RIM.x - 180.0, -60.0)
	player_pos = atk if i_attack else dfn
	facing = 1.0
	foe["pos"] = dfn if i_attack else atk
	foe["t_pos"] = foe["pos"]
	if meter != null:
		meter.visible = false
	_duel_update_top()


func _duel_update_top() -> void:
	if not duel_on:
		return
	lbl_top.text = "%s %d · %d %s   ·   a %d" % [
		Loc.t("duel.you"), my_score, foe_score,
		String(foe.get("name", "?")), duel_target]
	if duel_phase == "live":
		lbl_top.text += "   ·   " + (Loc.t("duel.mine") if i_attack else Loc.t("duel.def"))


func _duel_scored() -> void:
	## Ho segnato io: cambio palla (chi subisce attacca) e se serve e' finita.
	i_attack = false
	must_clear = false
	ball_loose = false
	_duel_update_top()
	if my_score >= duel_target:
		_duel_end(true)


func _duel_foe_scored() -> void:
	## Ha segnato lui: palla mia, ma prima devo uscire dalla linea.
	i_attack = true
	must_clear = true
	ball_loose = false
	_duel_update_top()
	if foe_score >= duel_target:
		_duel_end(false)


func _take_ball(off: bool, free := false) -> void:
	## Ho preso il rimbalzo. off = rimbalzo OFFENSIVO (il mio tiro
	## sbagliato): posso rimettere subito; in difesa, prima esco dalla linea.
	## free = nel campo libero: nessuna regola, la palla e' mia e via.
	ball_loose = false
	ball_live = false
	fb_live = false
	_pick_ok = false
	_fb_pick_ok = false
	_loose_t = 0.0
	_took_at = int(Time.get_ticks_msec())
	if free:
		ball_holder = 0
		_say(Loc.t("duel.takefree"), 1.2)
		NetLayer.rpc("rpc_duel_ev", {"ev": "take", "free": true})
		return
	i_attack = true
	must_clear = not off
	_duel_update_top()
	_say(Loc.t("duel.takeoff") if off else Loc.t("duel.takedef"), 1.5)
	NetLayer.rpc("rpc_duel_ev", {"ev": "take", "off": off})


func _duel_end(win: bool) -> void:
	duel_phase = "over"
	_win = win
	charging = false
	ball_loose = false
	if meter != null:
		meter.visible = false
	_duel_update_top()
	_show_end()
	Sfx.haptic(60 if win else 30)


func _on_foe_ev(d: Dictionary) -> void:
	match String(d.get("ev", "")):
		"challenge":
			_pending_target = int(d.get("target", 11))
			_show_accept()
		"decline":
			_hide_panels()
			_say(Loc.t("duel.declined"), 2.0)
		"start":
			if duel_on and duel_phase != "over":
				return
			if int(Time.get_ticks_msec()) - _free_sent_at < 1200:
				return   # ho appena chiuso: vince il ritorno ai tiri liberi
			_duel_start(int(d.get("target", 11)), String(d.get("first", "host")))
		"take":
			if not ball_loose and int(Time.get_ticks_msec()) - _took_at < 400:
				return   # due prese nello stesso istante: vale la prima arrivata
			ball_loose = false
			ball_live = false
			fb_live = false
			_loose_t = 0.0
			if bool(d.get("free", false)):
				ball_holder = 1
				_say(Loc.t("duel.takefoe"), 1.2)
				return
			i_attack = false
			must_clear = false
			_duel_update_top()
			_say(Loc.t("duel.takefoe"), 1.5)
		"rematch":
			if duel_phase != "over":
				return
			_duel_start(int(d.get("target", duel_target)), String(d.get("role", "host")))
		"free":
			if not duel_on:
				return
			_duel_free()


func _end_match() -> void:
	## Chiudo la partita e torno ai tiri liberi — lo dico anche all'altro,
	## cosi' entrambi si ritrovano a tirare insieme sullo stesso campo.
	_free_sent_at = int(Time.get_ticks_msec())
	NetLayer.rpc("rpc_duel_ev", {"ev": "free"})
	_duel_free()


func _duel_free() -> void:
	## Si torna a tirare insieme, come sempre: campo condiviso libero.
	duel_on = false
	duel_phase = ""
	ball_loose = false
	ball_live = false
	fb_live = false
	must_clear = false
	charging = false
	_pick_ok = false
	_fb_pick_ok = false
	_loose_t = 0.0
	ball_holder = 0 if NetLayer.role == "host" else 1
	if meter != null:
		meter.visible = false
	lbl_top.text = "%s  ·  %s" % [Loc.t("duel.you"), String(foe.get("name", "?"))]
	_say(Loc.t("duel.freeon"), 2.5)


# ------------------------------------------------------------------ 1v1 UI
func _panel_layer(dim: bool) -> VBoxContainer:
	_hide_panels()
	_panel = CanvasLayer.new()
	_panel.layer = 40
	add_child(_panel)
	if dim:
		var cr := ColorRect.new()
		cr.color = Color(0, 0, 0, 0.45)
		cr.set_anchors_preset(Control.PRESET_FULL_RECT)
		_panel.add_child(cr)
	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.custom_minimum_size = Vector2(620, 0)
	_panel.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	pc.add_child(vb)
	return vb


func _panel_text(vb: VBoxContainer, txt: String, size := 26, col := Color.WHITE) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)


func _panel_btn(parent: Container, txt: String, cb: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 68)
	b.add_theme_font_size_override("font_size", 22)
	if accent:
		b.modulate = Color(1.0, 0.75, 0.35)
	parent.add_child(b)
	b.pressed.connect(cb)
	return b


func _hide_panels() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null


func _sfida_panel() -> void:
	if not _net_ok or duel_on:
		return
	var vb := _panel_layer(false)
	_panel_text(vb, Loc.t("duel.pick"), 27, Color(1.0, 0.82, 0.35))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	for t in [11, 15, 21]:
		var b := _panel_btn(hb, "A %d" % t, _send_challenge.bind(t), true)
		b.custom_minimum_size = Vector2(150, 72)
	_panel_btn(vb, Loc.t("common.back"), _hide_panels)


func _send_challenge(t: int) -> void:
	_hide_panels()
	NetLayer.rpc("rpc_duel_ev", {"ev": "challenge", "target": t})
	_say(Loc.t("duel.sent"), 2.5)


func _show_accept() -> void:
	if duel_on:
		return
	var vb := _panel_layer(true)
	_panel_text(vb, "%s  %s  %d" % [
		String(foe.get("name", "?")), Loc.t("duel.wants"), _pending_target], 27)
	_panel_text(vb, Loc.t("duel.rules"), 17, Color(1, 1, 1, 0.65))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	_panel_btn(hb, Loc.t("duel.accept"), _accept_challenge, true)
	_panel_btn(hb, Loc.t("duel.decline"), _decline_challenge)


func _accept_challenge() -> void:
	_hide_panels()
	var first := "host" if randf() < 0.5 else "client"
	NetLayer.rpc("rpc_duel_ev", {"ev": "start", "target": _pending_target, "first": first})
	_duel_start(_pending_target, first)


func _decline_challenge() -> void:
	_hide_panels()
	NetLayer.rpc("rpc_duel_ev", {"ev": "decline"})


func _show_end() -> void:
	var vb := _panel_layer(true)
	_panel_text(vb, Loc.t("duel.win") if _win else Loc.t("duel.lose"), 46,
		Color(0.45, 1.0, 0.5) if _win else Color(1.0, 0.55, 0.45))
	_panel_text(vb, "%d  ·  %d" % [my_score, foe_score], 34, Color(1, 1, 1, 0.8))
	if _win:
		_panel_text(vb, Loc.t("duel.waitrematch"), 16, Color(1, 1, 1, 0.5))
	else:
		_panel_text(vb, Loc.t("duel.rematch.hint"), 16, Color(1, 1, 1, 0.5))
		_panel_btn(vb, Loc.t("duel.rematch"), _rematch, true)
	_panel_btn(vb, Loc.t("duel.free"), _end_match)
	_panel_btn(vb, Loc.t("duel.leave"), _leave)


func _rematch() -> void:
	NetLayer.rpc("rpc_duel_ev", {"ev": "rematch", "role": NetLayer.role,
		"target": duel_target})
	_duel_start(duel_target, NetLayer.role)


# ------------------------------------------------------------------ disegno
func _screen(p: Vector2) -> Vector2:
	return CourtStage.m_project(p, Court.COURT_H)


func _rim_screen() -> Vector2:
	return _screen(RIM) + Vector2(0.0, -RIM_HEIGHT)


func _distance_ft() -> float:
	return player_pos.distance_to(RIM) / Court.PX_PER_FT


func _draw() -> void:
	_draw_three_flash()
	_draw_npcs()
	_draw_char(true)
	if foe["seen"] or foe["live"]:
		_draw_char(false)
	# LA MIA PALLA IN VOLO: parabola, ferro e retina (v2.43.3: nella
	# riscrittura era rimasta fuori dal disegno — il tiro partiva, il
	# verdetto usciva, ma la palla non si vedeva mai).
	if ball_live:
		var bs: Vector2 = _screen(ball_pos)
		_draw_ball_at(Vector2(bs.x, bs.y - ball_h), BALL_R, ball_spin)
		# la mezza retina DAVANTI alla palla che sta passando: si legge come
		# "dentro la rete" (lo stesso trucco del campetto solo)
		if ball_h < RIM_HEIGHT + 30.0 and (ball_pos - RIM).length() < 70.0:
			HoopArt.draw_net_front(self, _rim_screen(), 22.0,
				22.0 * HoopArt.RIM_SQUASH, net_wobble, net_t, 0.0, -1.0)
	# la palla dell'altro (quando e' in volo): simulata qui, fluida
	if fb_live:
		var fbs: Vector2 = _screen(fb_pos)
		_draw_ball_at(Vector2(fbs.x, fbs.y - fb_h), BALL_R, fb_spin)
		if fb_h < RIM_HEIGHT + 30.0 and (fb_pos - RIM).length() < 70.0:
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


func _draw_ball_at(p: Vector2, r: float, spin := 0.0) -> void:
	draw_circle(p, r, Color(0.95, 0.55, 0.15))
	draw_arc(p, r, 0, TAU, 18, Color(0.35, 0.18, 0.07), 2.0)
	var a: float = spin
	draw_line(p + Vector2(cos(a), sin(a)) * -r, p + Vector2(cos(a), sin(a)) * r,
		Color(0.35, 0.18, 0.07), 2.0)
	var b: float = a + PI * 0.5
	draw_arc(p, r * 0.86, b - 1.1, b + 1.1, 10, Color(0.35, 0.18, 0.07), 2.0)


## Disegna un giocatore (il mio o l'altro) con l'Avatar condiviso: stesse
## pose, stesse proporzioni, camminata e trick compresi.
func _draw_char(mine: bool) -> void:
	var world: Vector2 = player_pos if mine else (foe["pos"] as Vector2)
	if mine and _jump_t > 0.0:
		# il SALTO: stacco da terra a arco, come la stoppata dell'indoor
		world.y -= 90.0 * sin(PI * (1.0 - _jump_t / 0.45))
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
		hold_ball = not ball_live and dp == "" and trick_t <= 0.0 \
			and ((not duel_on and ball_holder == 0 and not ball_loose) \
			or (duel_on and i_attack and not ball_loose and duel_phase != "over"))
	else:
		hold_ball = not fb_live and dp == "" and tk == "" \
			and ((not duel_on and ball_holder == 1 and not ball_loose) \
			or (duel_on and (not i_attack) and not ball_loose and duel_phase != "over"))

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


# ------------------------------------------------------------ I BAMBINI
func _spawn_npcs() -> void:
	## I bambini dall'altro lato del campo: giocano per i fatti loro al
	## canestro sinistro, come nel campetto solo.
	var homes := [Vector2(-560.0, -150.0), Vector2(-330.0, 140.0), Vector2(-640.0, 60.0)]
	var cols := [Color(0.16, 0.45, 0.85), Color(0.72, 0.20, 0.22), Color(0.20, 0.55, 0.30)]
	for i in homes.size():
		npcs.append({
			"pos": homes[i],
			"state": "wait",
			"t": randf_range(1.0, 4.5),
			"made": false,
			"target": homes[i],
			"col": cols[i % cols.size()],
		})

func _update_npcs(delta: float) -> void:
	for n in npcs:
		match String(n["state"]):
			"wait":
				n["t"] -= delta
				if n["t"] <= 0.0:
					n["state"] = "shoot"
					n["t"] = 0.0
					n["made"] = randf() < 0.55
			"shoot":
				n["t"] += delta / 0.9
				if n["t"] >= 1.0:
					if n["made"]:
						net_wobble = 1.0
						if court_art != null:
							court_art.net_bump(0, 1.0)
					else:
						net_wobble = maxf(net_wobble, 0.5)
						if court_art != null:
							court_art.net_bump(0, 0.6)
					n["state"] = "chase"
					n["t"] = 0.0
					n["target"] = Vector2(randf_range(-720.0, -260.0), randf_range(-220.0, 220.0))
			"chase":
				var to: Vector2 = n["target"] - n["pos"]
				if to.length() < 14.0:
					n["state"] = "wait"
					n["t"] = randf_range(2.0, 5.0)
				else:
					n["pos"] += to.normalized() * 95.0 * delta

func _draw_three_flash() -> void:
	## La linea dei tre LAMPEGGIA finche' chi ha subito canestro non e'
	## uscito: si capisce al volo cosa bisogna fare.
	if not (duel_on and duel_phase == "live" and i_attack and must_clear):
		return
	var radius: float = Court.THREE_FT * Court.PX_PER_FT
	var col: Color = Color(1.0, 0.62, 0.20, 0.40 + 0.45 * absf(sin(net_t * 5.0)))
	var pts: PackedVector2Array = []
	var n := 40
	for i in range(n + 1):
		var a: float = PI * 0.5 + PI * float(i) / float(n)
		pts.append(CourtStage.m_project(RIM + Vector2(cos(a), sin(a)) * radius, Court.COURT_H))
	draw_polyline(pts, col, 7.0, true)


func _draw_npcs() -> void:
	for n in npcs:
		var s: Vector2 = _screen(n["pos"])
		var h: float = 64.0 * Game.height_factor() * 0.92
		var kind := Avatar.DRIBBLE
		var amount := 0.0
		if n["state"] == "shoot":
			kind = Avatar.SHOOT
			amount = clampf(n["t"], 0.0, 1.0)
		elif n["state"] == "chase":
			kind = Avatar.RUN
		Avatar.draw_body(self, s, h, -1.0,
			Avatar.pose(kind, dribble_t, amount),
			Avatar.colours(false, n["col"]), n["state"] == "wait")
		if n["state"] == "shoot":
			var t: float = clampf(n["t"], 0.0, 1.0)
			var from: Vector2 = s + Vector2(-10.0, -h * 0.4)
			var rim_s: Vector2 = _screen(LEFT_RIM) + Vector2(0.0, -RIM_HEIGHT)
			var bp: Vector2 = from.lerp(rim_s, t)
			bp.y -= sin(t * PI) * 150.0
			_draw_ball_at(bp, BALL_R)


# -------------------------------------------------- LA PALLA DELL'ALTRO
func _foe_launch(from: Vector2, aim: Vector2, ghost: bool) -> void:
	## Stessa parabola esatta del mio tiro: parte da dove ha tirato lui e
	## passa per l'arrivo che ha deciso il SUO verdetto.
	fb_pos = from
	fb_h = 55.0
	fb_live = true
	fb_settled = 0.0
	fb_through = false
	fb_rattled = false
	fb_ghost = ghost
	var dist: Vector2 = aim - from
	var flight: float = clampf(dist.length() / 430.0, 0.5, 1.6)
	fb_vel = dist / flight
	fb_vh = (RIM_HEIGHT - fb_h + 0.5 * GRAV * flight * flight) / flight
	fb_spin = -signf(dist.x) * 7.0
	fb_prev_h = fb_h
	fb_prev_pos = fb_pos

func _step_foe_ball(delta: float) -> void:
	if not fb_live:
		return
	var steps := 4
	var hstep: float = delta / float(steps)
	for _i in steps:
		fb_prev_h = fb_h
		fb_prev_pos = fb_pos
		fb_vh -= GRAV * hstep
		fb_pos += fb_vel * hstep
		fb_h += fb_vh * hstep
		_foe_ball_rim()
		_foe_ball_backboard()
		_foe_ball_floor()
	fb_spin += fb_vel.x * 0.0004
	if not ball_loose:
		if fb_pos.x < -1300.0 or fb_pos.x > 1300.0 \
		or fb_pos.y < -Court.COURT_H or fb_pos.y > Court.COURT_H:
			fb_live = false
		if fb_settled > 0.6:
			fb_live = false

func _foe_ball_rim() -> void:
	## L'attraversamento della retina della SUA palla, coi miei occhi:
	## swish, rattle e ferro — tutto quello che vedo del mio tiro.
	if fb_h <= RIM_HEIGHT and fb_prev_h >= RIM_HEIGHT and fb_vh < 0.0:
		_fb_pick_ok = true
		var span: float = fb_prev_h - fb_h
		var f: float = 0.0 if span <= 0.0 else (fb_prev_h - RIM_HEIGHT) / span
		var cx: float = lerpf(fb_prev_pos.x, fb_pos.x, clampf(f, 0.0, 1.0))
		var cy: float = lerpf(fb_prev_pos.y, fb_pos.y, clampf(f, 0.0, 1.0))
		var d: Vector2 = Vector2(cx, cy) - RIM
		var dist: float = d.length()
		if dist < RIM_HALF - 6.0 or (fb_rattled and dist < RIM_HALF + 6.0):
			if not fb_rattled and not fb_through and not fb_ghost \
			and randf() < 0.30:
				fb_rattled = true
				var rn_s: Vector2 = (fb_pos - RIM).normalized()
				if rn_s.length() < 0.1:
					rn_s = Vector2(1, 0)
				fb_pos = RIM + rn_s * 9.0
				fb_vh = randf_range(500.0, 640.0)
				fb_vel = rn_s * randf_range(30.0, 55.0) \
					+ Vector2(randf_range(-25, 25), randf_range(-25, 25))
				Sfx.play("rim", -0.5, randf_range(0.95, 1.08))
				net_wobble = 0.9
				Events.shake.emit(0.60)
				if court_art != null:
					if court_art.has_method("rim_fx"):
						court_art.rim_fx("rattle", RIM)
					if court_art.has_method("net_bump"):
						court_art.net_bump(1, 0.9)
				return
			if not fb_through:
				fb_through = true
				net_wobble = 1.0
				Sfx.play("swish", -2.5)
				if court_art != null:
					court_art.net_bump(1, 1.0)
					if court_art.has_method("rim_fx"):
						court_art.rim_fx("swish", RIM)
				fb_vh *= 0.55
				fb_vel *= 0.5
				return
		if dist < RIM_HALF + 14.0 and not fb_ghost:
			var nrm: Vector2 = d.normalized() if dist > 0.01 else Vector2(1, 0)
			fb_pos = RIM + nrm * (RIM_HALF + 12.0)
			fb_vel = fb_vel.bounce(nrm) * 0.5
			net_wobble = maxf(net_wobble, 0.85)
			Sfx.play("rim", -5.0)
			if court_art != null:
				court_art.net_bump(1, 0.85)
				if court_art.has_method("rim_fx"):
					court_art.rim_fx("iron", RIM)
			fb_spin *= -0.6
			return
	var d2: Vector2 = fb_pos - RIM
	if fb_h < RIM_HEIGHT and fb_h > RIM_HEIGHT - 130.0 \
	and d2.length() < RIM_HALF + 26.0:
		net_wobble = maxf(net_wobble, 0.45)
		if court_art != null:
			court_art.net_bump(1, 0.45)

func _foe_ball_backboard() -> void:
	var bx: float = RIM.x + 42.0
	if fb_h > RIM_HEIGHT - 30.0 and fb_h < RIM_HEIGHT + 90.0:
		if fb_pos.x > bx and fb_vel.x > 0.0:
			fb_pos.x = bx
			fb_vel.x = -absf(fb_vel.x) * 0.55
			fb_vel.y *= 0.8
			net_wobble = maxf(net_wobble, 0.35)
			if court_art != null and court_art.has_method("rim_fx"):
				court_art.rim_fx("iron", RIM)

func _foe_ball_floor() -> void:
	if fb_h < 0.0:
		fb_h = 0.0
		_fb_pick_ok = true
		if absf(fb_vh) > 90.0:
			fb_vh = -fb_vh * 0.45
			fb_vel *= 0.72
		else:
			fb_vh = 0.0
			fb_settled += 0.02
			fb_vel *= 0.94
