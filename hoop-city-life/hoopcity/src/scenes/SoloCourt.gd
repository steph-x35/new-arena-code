extends Node2D
## The outdoor court, alone. No clock, no opponent: walk the FULL court and
## shoot at the right-hand hoop. The floor, the lines, the hoops and the ball
## all live in ONE honest rectangle -- the same court-space the scrimmage uses
## (Court.COURT_W x COURT_H), drawn through the match's own CourtVisual with
## the same CourtStage.m_project tilt. No invisible trapezoid, no shrinking
## player: the character keeps a constant size anywhere on the floor, and the
## movement boundary IS the court's own painted rectangle.

const SPOT_XP := 6
## The hoop you shoot at, in court space: the right-hand rim.
const RIM := Vector2(Court.COURT_W * 0.5 - Court.FIBA_HOOP_INSET, 0.0)
const LEFT_RIM := Vector2(-Court.COURT_W * 0.5 + Court.FIBA_HOOP_INSET, 0.0)
const RIM_HEIGHT := Court.RIM_HEIGHT
const RIM_HALF := 42.0
const GRAV := 1800.0
const BALL_R := Court.BALL_R
const DUNK_FT := 6.5   # si parte dalla semicirconferenza sotto canestro
const CAM_ZOOM := 1.04

var joystick: VirtualJoystick
var player_pos := Vector2(280.0, 0.0)      # court space, ~26 ft out
var facing := 1.0
var posting := false          # POST UP: spalle al canestro, come in partita
var euro_t := 0.0             # EUROSTEP: 1 tempo laterale, 2 verso il ferro, poi finish
var euro_side := Vector2.ZERO
var euro_finish := false
var fade_pending := false     # FADEAWAY: levetta indietro mentre carichi il tiro
var fade_t := 0.0
var fade_dir := Vector2.ZERO
var _family_tag := ""        # FADEAWAY / HOOK: etichetta della famiglia sul risultato
var dribble_t := 0.0

# shot state
var charging := false
var charge := 0.0
var pump_t := 0.0              # quick-tap pump fake: rise and settle, no shot
var _sq_t := 0.0               # squeak cooldown
var _prev_mv := Vector2.ZERO
var _drib_t := 0.0             # dribble thud cadence
var ideal := 0.55
var shot_anim := 0.0
var shot_made := false
var net_wobble := 0.0
var net_t := 0.0
var ball_from := Vector2.ZERO
var ball_to := Vector2.ZERO

# dunk state: rise to the rim, throw it down, HANG until the button is released
var dunk_anim := 0.0        # progress within the current phase
var dust_t := 0.0           # nuvolette all'atterraggio
var dust_big := false       # atterraggio da slam
var dunk_phase := ""        # "" | "rise" | "hang" | "drop"
var hang_swing_t := 0.0    # tempo appeso: oscilla dx/sx come un pendolo
var hang_lift_now := 0.0   # lift reale dell'hang (il corpo e' piu' basso del rise)
var dunk_style := ""        # DunkStyle: windmill / spin360 / tomahawk ...
var dunk_rise_t := 0.70     # seconds of the rise, from DunkStyle (per style)
var dunk_ball_t := 0.0      # time since the throw-down, drives the ball drop
var want_hang := false

## Real ball physics in court space + a height axis, exactly like a match.
var ball_pos := Vector2.ZERO
var ball_vel := Vector2.ZERO
var ball_h := 0.0
var ball_vh := 0.0
var ball_live := false
var ball_spin := 0.0
var ball_settled := 0.0
var ball_ghost_rim := false
var through_rim := false
var scored_this_shot := false
var ball_rattled := false       # ferro gia' suonato su questo tiro
var prev_pos := Vector2.ZERO
var prev_h := 0.0

# session
const SESSION_SECONDS := 120.0
const RESET_DELAY := 2.0
var session_left := SESSION_SECONDS
var session_over := false
var reset_timer := -1.0
var session_score := 0
var makes := 0
var attempts := 0
var streak := 0
var best_streak := 0
var hot := false               # HEAT CHECK: 3 canestri di fila

# ── HALF-COURT GREEN CHALLENGE ──────────────────────────────────────
# 60 secondi, spawn casuale oltre la linea di metà campo, contano SOLO
# i rilasci GREEN (da quella distanza la finestra perfetta è una fessura).
# Il record personale resta salvato nel profilo: è la sfida da battere.
const HC_SECONDS := 60.0
const HC_MIN_FT := 34.0          # più vicino di così il green non vale
var hc_mode := false
var hc_greens := 0
var hc_best := 0
var btn_hc: Button
var hc_expanded := false   # quadratino -> tap -> bottone pieno -> tap -> parte

# street-court bystanders who shoot at the left hoop, so the park feels alive
var npcs: Array = []

var lbl_top: Label
var lbl_mid: Label
var btn_shoot: TouchButton
var btn_crossover: TouchButton
var btn_post: TouchButton
var hand_left := true
var trick_t := 0.0
var trick_kind := ""
var meter: ShotMeter
var hud_layer: CanvasLayer
var court_art: Node2D
var outdoor := true
var night_tint: CanvasModulate

func _exit_tree() -> void:
	Sfx.stop_amb()
	Sfx.stop_music()   # la ritmica vive SOLO dentro il court indoor

func _ready() -> void:
	Sfx.stop_music()   # solo/1v1 courts: squeaks, swish and bounces only
	outdoor = String(Game.profile.get("last_building", "park")) != "court"
	hand_left = Game.shooting_hand() < 0.0
	hc_best = int(Game.profile.get("hc_best", 0))
	# Same packed CourtVisual as 1v1 — Script.new() never painted the floor
	# on device, which is why shoot-around was a blank brown/grey sheet.
	court_art = $CourtVisual
	court_art.z_index = -10
	court_art.visible = true
	# Se c'e' una sfida in attesa, un NPC ti viene incontro con il dialogo.
	CareerEvents.offer_if_pending_solo(self)
	# Outdoor: ambiente (registrazione utente 60s). Indoor: SOLO qui parte
	# la MUSICA RITMICA dell'utente (3'12" in loop), richiesta esplicita:
	# mai in citta', mai nell'outdoor, mai nei match.
	if outdoor:
		Sfx.start_amb()
	else:
		Sfx.play_music("music_rhythm")
	court_art.modulate = Color.WHITE
	if court_art.has_method("apply_env"):
		court_art.apply_env("street" if outdoor else "arena")
	else:
		court_art.env = "street" if outdoor else "arena"
		court_art.queue_redraw()
	night_tint = null
	var cam: Camera2D = $Camera2D
	cam.zoom = Vector2.ONE * CAM_ZOOM
	cam.position = Vector2(0.0, -40.0)
	cam.enabled = true
	cam.make_current()
	set_meta("cam", cam)
	# Esterno = PARCO: erba, non piu' il fondo azzurro.
	RenderingServer.set_default_clear_color(
		Color(0.30, 0.44, 0.23) if outdoor else Color(0.10, 0.11, 0.14))
	_build_hud()
	if outdoor:
		_spawn_npcs()
	set_process(true)
	queue_redraw()

## Court space -> screen space, identical to how the court art is drawn.
func _screen(p: Vector2) -> Vector2:
	return CourtStage.m_project(p, Court.COURT_H)

func _rim_screen() -> Vector2:
	return _screen(RIM) + Vector2(0.0, -RIM_HEIGHT)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_layer = layer
	layer.layer = 30
	if outdoor:
		var rain_l := CanvasLayer.new()
		rain_l.layer = 8
		add_child(rain_l)
		var rain_c := Control.new()
		rain_c.set_anchors_preset(Control.PRESET_FULL_RECT)
		rain_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rain_c.set_script(preload("res://src/city/CityWeatherHud.gd"))
		rain_l.add_child(rain_c)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	joystick = VirtualJoystick.new()
	joystick.set_anchors_preset(Control.PRESET_FULL_RECT)
	joystick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Joystick only listens on the LEFT half, so the right-hand action buttons
	# can never be swallowed by it (and it can never hijack their touches).
	var left := Control.new()
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.anchor_right = 0.5
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(joystick)
	root.add_child(left)

	lbl_top = Label.new()
	lbl_top.add_theme_font_size_override("font_size", 24)
	lbl_top.position = Vector2(28, 22)
	root.add_child(lbl_top)

	lbl_mid = Label.new()
	lbl_mid.add_theme_font_size_override("font_size", 40)
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

	btn_crossover = TouchButton.new()
	btn_crossover.text = "TRICK"
	btn_crossover.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_crossover.position = Vector2(-416, -172)
	btn_crossover.custom_minimum_size = Vector2(118, 118)
	btn_crossover.size = Vector2(118, 118)
	btn_crossover.pressed_down.connect(_do_trick)
	root.add_child(btn_crossover)

	# POST UP: anche nel court solo, cosi' le mosse si provano senza
	# aspettare una partita. Spalle al canestro: TIRA = fade/hook,
	# TRICK = drop step.
	btn_post = TouchButton.new()
	btn_post.text = "POST"
	btn_post.accent = Color(0.980, 0.780, 0.260)
	btn_post.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_post.position = Vector2(-416, -320)
	btn_post.custom_minimum_size = Vector2(118, 118)
	btn_post.size = Vector2(118, 118)
	btn_post.pressed_down.connect(_post_tap)
	root.add_child(btn_post)

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
	leave.text = "< Leave"
	leave.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	leave.position = Vector2(-150, 24)
	leave.custom_minimum_size = Vector2(140, 60)
	leave.add_theme_font_size_override("font_size", 22)
	leave.pressed.connect(_leave)
	root.add_child(leave)

	# HALF-COURT GREEN CHALLENGE: di base e' solo un QUADRATINO 🏆 sotto
	# Leave (piu' visuale); un tap lo APRE col nome intero, il tap seguente
	# FA PARTIRE la sfida. Si richiude da solo dopo 6 secondi o a sfida finita.
	btn_hc = Button.new()
	btn_hc.text = "🏆"
	btn_hc.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_hc.position = Vector2(-66, 92)
	btn_hc.size = Vector2(56, 56)
	btn_hc.custom_minimum_size = Vector2(56, 56)
	btn_hc.add_theme_font_size_override("font_size", 24)
	btn_hc.pressed.connect(_toggle_hc)
	root.add_child(btn_hc)

func _hc_expand() -> void:
	## quadratino -> bottone pieno col nome; si richiude da solo in 6 secondi
	hc_expanded = true
	if btn_hc:
		btn_hc.text = "🏆 SFIDA METÀ CAMPO"
		btn_hc.position = Vector2(-312, 92)
		btn_hc.size = Vector2(302, 56)
		btn_hc.custom_minimum_size = Vector2(302, 56)
		btn_hc.add_theme_font_size_override("font_size", 19)
	get_tree().create_timer(6.0).timeout.connect(_hc_auto_collapse)

func _hc_auto_collapse() -> void:
	if hc_expanded and not hc_mode:
		_hc_collapse()

func _hc_collapse() -> void:
	hc_expanded = false
	if btn_hc:
		btn_hc.disabled = false
		btn_hc.text = "🏆"
		_hc_shrink()

func _hc_shrink() -> void:
	if btn_hc:
		btn_hc.position = Vector2(-66, 92)
		btn_hc.size = Vector2(56, 56)
		btn_hc.custom_minimum_size = Vector2(56, 56)
		btn_hc.add_theme_font_size_override("font_size", 24)

func _leave() -> void:
	SaveSystem.save_game()
	SceneRouter.goto("res://src/scenes/CityScene.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave()


## A few regulars shooting at the far hoop, so the street court feels like a
## pickup run instead of an empty slab.
func _spawn_npcs() -> void:
	var homes := [Vector2(-560.0, -150.0), Vector2(-330.0, 140.0), Vector2(-640.0, 60.0)]
	var cols := [Color(0.16, 0.45, 0.85), Color(0.72, 0.20, 0.22), Color(0.20, 0.55, 0.30)]
	for i in homes.size():
		npcs.append({
			"pos": homes[i],
			"state": "wait",          # wait -> shoot -> chase -> wait
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

func _process(delta: float) -> void:
	dribble_t += delta * 4.2
	net_t += delta
	net_wobble = HoopArt.decay(net_wobble, delta)
	trick_t = maxf(trick_t - delta, 0.0)
	dust_t = maxf(dust_t - delta, 0.0)
	if dunk_phase == "hang":
		hang_swing_t += delta
	else:
		hang_swing_t = 0.0
	if has_meta("cam"):
		var cam: Camera2D = get_meta("cam")
		var want_x: float = CourtStage.m_project(player_pos, Court.COURT_H).x
		var half_view: float = get_viewport_rect().size.x * 0.5 / CAM_ZOOM
		var floor_x: float = CourtStage.m_project(
			Vector2(Court.COURT_W * 0.5, 0.0), Court.COURT_H).x
		var limit: float = maxf(floor_x - half_view + 160.0, 80.0)
		want_x = clampf(want_x, -limit, limit)
		cam.position.x = lerpf(cam.position.x, want_x, clampf(4.0 * delta, 0.0, 1.0))
		cam.position.y = -40.0
		cam.zoom = Vector2.ONE * CAM_ZOOM
	if outdoor:
		_update_npcs(delta)
		# Fade the whole park with the day/night cycle, like the city street.
		if night_tint != null:
			var c: Color = Game.daylight_color()
			# Floodlights keep the floor readable: never go fully black.
			c = c.lerp(Color(0.72, 0.70, 0.62), 0.55)
			night_tint.color = night_tint.color.lerp(c, 2.0 * delta)

	if not session_over:
		session_left -= delta
		if session_left <= 0.0:
			session_left = 0.0
			_end_session()

	var was_live: bool = ball_live
	_step_ball(delta)
	if was_live and not ball_live:
		reset_timer = RESET_DELAY
	if reset_timer > 0.0:
		reset_timer -= delta
		if reset_timer <= 0.0:
			reset_timer = -1.0
			ball_ghost_rim = false
			through_rim = false
			# HALF-COURT: ogni tentativo finito = nuovo spot oltre la metà.
			if hc_mode and not session_over:
				_hc_teleport()

	# PIEGA DEL FERRO: lo Street Court appendi al ferro destro -> court_art
	court_art.solo_hang = (dunk_phase == "hang")
	# EUROSTEP: due tempi — laterale, poi esplosione verso il ferro — e
	# chiusura automatica (schiacciata se sei abbastanza vicino, layup se no).
	if euro_t > 0.0:
		euro_t = maxf(0.0, euro_t - delta)
		if euro_t > 0.30:
			player_pos += euro_side * 430.0 * delta
		else:
			player_pos += (RIM - player_pos).normalized() * 470.0 * delta
		if euro_t <= 0.0 and euro_finish:
			euro_finish = false
			if not session_over:
				if can_dunk():
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
	pump_t = maxf(0.0, pump_t - delta)
	#Solo parquet life: squeaks on hard cuts, dribble thuds while handling.
	_sq_t -= delta
	var mv_now: Vector2 = joystick.output if joystick else Vector2.ZERO
	if mv_now.length() > 0.55 and _prev_mv.length() > 0.30 \
			and mv_now.normalized().dot(_prev_mv.normalized()) < 0.68 and _sq_t <= 0.0:
		_sq_t = randf_range(0.35, 0.7)
		Sfx.squeak()
	_prev_mv = mv_now
	if not ball_live and dunk_phase == "" and shot_anim <= 0.0 and not charging:
		_drib_t -= delta
		if _drib_t <= 0.0:
			_drib_t = 0.42
			Sfx.dribble_thud()
	if shot_anim > 0.0:
		shot_anim += delta
		if shot_anim > 0.9:
			shot_anim = 0.0
	elif not charging and dunk_phase == "":
		var mv: Vector2 = joystick.output
		player_pos += mv * (155.0 if posting else 255.0) * delta
		# The movement boundary IS the court's painted rectangle.
		var m := 40.0
		player_pos.x = clampf(player_pos.x, -Court.COURT_W * 0.5 + m, Court.COURT_W * 0.5 - m)
		player_pos.y = clampf(player_pos.y, -Court.COURT_H * 0.5 + m, Court.COURT_H * 0.5 - m)
		if absf(mv.x) > 0.15:
			facing = signf(mv.x)
		# In post il facing resta SUL FERRO contrario (spalle), stick a parte.
		if posting:
			var phx: float = RIM.x - player_pos.x
			if absf(phx) > 1.0:
				facing = -signf(phx)
		if mv.length() > 0.05 and Engine.get_frames_drawn() % 60 == 0:
			Game.advance_time(1)

	if charging:
		charge += delta
		if charge > 2.2:
			_shoot_up()

	# dunk phase machine: rise -> throw-down -> hang (until release) -> drop
	if dunk_phase != "":
		dunk_anim += delta
		dunk_ball_t += delta
		if dunk_phase == "rise" and dunk_anim >= dunk_rise_t:
			_dunk_throw()
			# La rete canta ESATTAMENTE una volta: al momento della schiacciata.
			Sfx.play("swish", -1.0, randf_range(0.84, 0.90))
			if want_hang:
				dunk_phase = "hang"
			else:
				dunk_phase = "drop"
			dunk_anim = 0.0
		elif dunk_phase == "drop" and dunk_anim >= 0.5:
			dunk_phase = ""
			dunk_anim = 0.0
			dunk_ball_t = 0.0
			# TONFO: polvere grande + suono sordo, come nei match.
			dust_big = true
			dust_t = 0.70
			Sfx.play("body", -6.0, randf_range(0.90, 1.0))

	var ft: float = _distance_ft()
	var tag: String = "  ·  DUNK READY" if (can_dunk() and dunk_phase == "") else ""
	if hc_mode:
		lbl_top.text = "🏆 HALF-COURT   ⏱ 0:%02d   GREEN %d   RECORD %d   %.0f ft" % [
			int(session_left), hc_greens, hc_best, ft]
	else:
		lbl_top.text = "⏱ %d:%02d   SCORE %d   %d/%d   streak %d (best %d)   %.0f ft%s" % [
			int(session_left) / 60, int(session_left) % 60, session_score,
			makes, attempts, streak, best_streak, ft, tag]
	lbl_top.modulate = Color(1, 0.45, 0.4) if session_left <= 15.0 else Color(1, 1, 1)
	if btn_shoot:
		var want: String = "SHOOT"
		if dunk_phase == "hang":
			want = "LET GO"
		elif dunk_phase == "rise":
			want = "DUNK!"
		elif can_dunk():
			want = "DUNK"
		if btn_shoot.text != want:
			btn_shoot.text = want
	if meter:
		if charging:
			meter.visible = true
			meter.frozen = false
			meter.charge = charge
			meter.ideal = ideal
		elif not meter.frozen:
			meter.visible = false
		# The meter lives ABOVE THE SHOOTER'S HEAD, always: this was defined
		# but never called, so the arc sat parked in the top-left corner of the
		# screen while the player shot from wherever he happened to be.
		_place_meter()
	queue_redraw()

func _meter_lift() -> float:
	## How high off the floor the drawn figure currently is, so the meter rides
	## up with a jump or a slam instead of being left behind on the ground.
	if dunk_phase == "":
		return 0.0
	var h: float = 64.0 * Game.height_factor()
	var reach: float = maxf(RIM_HEIGHT - h * DunkStyle.REACH, 0.0)
	if dunk_phase == "rise":
		var f: float = clampf(dunk_anim / maxf(dunk_rise_t, 0.05), 0.0, 1.0)
		return sin(f * PI * 0.5) * reach
	return reach

func _place_meter() -> void:
	## Keeps the arc directly above the shooter's head, in this scene's screen
	## space, whatever the camera is doing -- and clamps it inside the viewport
	## so the green band is never half off the screen near the top sideline.
	if meter == null or not has_meta("cam"):
		return
	var cam: Camera2D = get_meta("cam")
	var h: float = 64.0 * Game.height_factor()
	var world: Vector2 = _screen(player_pos) - Vector2(0.0, h + 36.0 + _meter_lift())
	var vp: Vector2 = get_viewport_rect().size
	var scr: Vector2 = (world - cam.position) * cam.zoom + vp * 0.5
	meter.size = Vector2(120, 78)
	var msz: Vector2 = meter.size
	# The arc is drawn from the BOTTOM-CENTRE of the control, so that is the
	# point pinned above the head -- and the clamp keeps the whole arc on
	# screen even when the shooter is up against the top sideline.
	var pos: Vector2 = scr - Vector2(msz.x * 0.5, msz.y)
	pos.x = clampf(pos.x, 8.0, maxf(vp.x - msz.x - 8.0, 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(vp.y - msz.y - 8.0, 8.0))
	meter.position = pos

func _distance_ft() -> float:
	## Real distance on the court, in feet, straight from the rim.
	return player_pos.distance_to(RIM) / Court.PX_PER_FT

func _post_tap() -> void:
	if session_over or charging or dunk_phase != "" or ball_live:
		return
	posting = not posting
	if posting:
		var hx: float = RIM.x - player_pos.x
		if absf(hx) > 1.0:
			facing = -signf(hx)
		lbl_mid.text = "POST"
		lbl_mid.modulate = Color(0.98, 0.78, 0.26)
		if not bool(Game.profile.get("post_hint_solo", false)):
			Game.profile["post_hint_solo"] = true
			Events.toast.emit("POST: TIRA = fade · TRICK = drop step")

func _do_trick() -> void:
	if session_over or charging or dunk_phase != "" or ball_live or euro_t > 0.0:
		return
	# EUROSTEP: corri verso il ferro entro 14 ft e TRICK diventa il passo
	# laterale a due tempi (con chiusura a schiacciata/layup automatica).
	var to_rim: Vector2 = RIM - player_pos
	var mv_e: Vector2 = joystick.output if joystick != null else Vector2.ZERO
	if to_rim.length() / Court.PX_PER_FT < 14.0 and mv_e.dot(to_rim.normalized()) > 0.50:
		euro_t = 0.52
		euro_finish = true
		var rn: Vector2 = to_rim.normalized()
		euro_side = Vector2(-rn.y, rn.x)
		if mv_e.dot(euro_side) < 0.0:
			euro_side = -euro_side
		hand_left = not hand_left
		facing = 1.0
		Sfx.squeak()
		lbl_mid.text = "EUROSTEP"
		lbl_mid.modulate = Color(0.6, 0.86, 1.0)
		return
	# POST: TRICK = DROP STEP, identico al match: scatto attorno al
	# difensore (qui fantasma) verso il ferro, cambio mano, si esce dal post.
	if posting:
		var hr: Vector2 = (RIM - player_pos).normalized()
		var sd: Vector2 = Vector2(-hr.y, hr.x)
		if sd.dot(Vector2(facing, 0)) < 0.0:
			sd = -sd
		player_pos += sd * 95.0 + hr * 40.0
		var m := 40.0
		player_pos.x = clampf(player_pos.x, -Court.COURT_W * 0.5 + m, Court.COURT_W * 0.5 - m)
		player_pos.y = clampf(player_pos.y, -Court.COURT_H * 0.5 + m, Court.COURT_H * 0.5 - m)
		hand_left = not hand_left
		posting = false
		if absf(hr.x) > 0.2:
			facing = signf(hr.x)
		trick_kind = "dropstep"
		trick_t = 0.45
		Sfx.squeak()
		_drain_energy(-0.5)
		lbl_mid.text = "DROP STEP"
		lbl_mid.modulate = Color(0.6, 0.86, 1.0)
		return
	# Same joystick mapping as the match: TRICK + stick direction.
	var mv: Vector2 = joystick.output if joystick else Vector2.ZERO
	if mv.length() < 0.25:
		trick_kind = "hesi"
	elif mv.y > 0.35:
		trick_kind = "hand_switch"
		hand_left = not hand_left
	elif mv.x < -0.35:
		trick_kind = "stepback"
		var away: Vector2 = (player_pos - RIM).normalized()
		player_pos += away * 70.0
		var m := 40.0
		player_pos.x = clampf(player_pos.x, -Court.COURT_W * 0.5 + m, Court.COURT_W * 0.5 - m)
		player_pos.y = clampf(player_pos.y, -Court.COURT_H * 0.5 + m, Court.COURT_H * 0.5 - m)
	elif mv.y < -0.35:
		trick_kind = "behind"
		hand_left = not hand_left
		if absf(mv.x) > 0.15:
			facing = signf(mv.x)
	else:
		trick_kind = "crossover"
		hand_left = not hand_left
		if absf(mv.x) > 0.15:
			facing = signf(mv.x)
	trick_t = 0.45
	Sfx.squeak()
	_drain_energy(-0.5)
	lbl_mid.text = {"crossover": "TRICK", "stepback": "STEPBACK",
		"behind": "BEHIND THE BACK", "hand_switch": "HAND SWITCH",
		"hesi": "HESITATION", "dropstep": "DROP STEP"}.get(trick_kind, "MOVE")
	lbl_mid.modulate = Color(0.6, 0.86, 1.0)

## DOPPIO TAP sullo schermo (meta' destra) = SPIN MOVE, come in partita.
var _spin_tap_ms := -100000
var _last_touch_ms := -100000

func _input(e: InputEvent) -> void:
	# Come in partita: _input vede il doppio tap PRIMA della GUI.
	var pressed: bool = (e is InputEventScreenTouch and e.pressed) \
		or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT)
	if not pressed:
		return
	var now_ms: int = Time.get_ticks_msec()
	if e is InputEventScreenTouch:
		_last_touch_ms = now_ms
	elif now_ms - _last_touch_ms < 80:
		return   # mouse sintetico del tocco: non contarlo due volte
	var vp := get_viewport().get_visible_rect().size
	if e.position.x < vp.x * 0.5:
		return
	if now_ms - _spin_tap_ms < 300:
		_spin_tap_ms = -100000
		_try_spin()
	else:
		_spin_tap_ms = now_ms

func _try_spin() -> void:
	# Stessa famiglia dei trick da pulsante: giro su se stessi, palla che
	# avvolge il corpo (Avatar pose "spin"), scatto in avanti.
	if session_over or charging or dunk_phase != "" or ball_live or trick_t > 0.0:
		return
	trick_kind = "spin"
	trick_t = 0.45
	Sfx.squeak()
	hand_left = not hand_left
	player_pos.x = clampf(player_pos.x + facing * 55.0,
		-Court.COURT_W * 0.5 + 40.0, Court.COURT_W * 0.5 - 40.0)
	_drain_energy(-0.5)
	lbl_mid.text = "SPIN MOVE"
	lbl_mid.modulate = Color(0.6, 0.86, 1.0)

func can_dunk() -> bool:
	if hc_mode:
		return false       # nella sfida si vince solo col GREEN, niente scorciatoie
	if _distance_ft() > DUNK_FT:
		return false
	return float(Game.profile.get("energy", 10)) > 1.0

## ── HALF-COURT GREEN CHALLENGE ──────────────────────────────────────
## La sfida ha un INIZIO (bottone) e una FINE (tempo scaduto): dal pannello
## risultati si riprova o si torna al tiro libero. Mai "spegnerla" a metà.
func _toggle_hc() -> void:
	if hc_mode:
		Events.toast.emit("Sfida in corso! Finisci i 60 secondi ⏱")
		return
	if ball_live or charging or dunk_phase != "":
		Events.toast.emit("Finisci prima il tiro!")
		return
	if not hc_expanded:
		_hc_expand()
		return
	hc_mode = true
	hc_greens = 0
	makes = 0
	attempts = 0
	streak = 0
	hot = false
	session_score = 0
	session_over = false
	shot_anim = 0.0
	dunk_phase = ""
	ball_live = false
	ball_settled = 0.0
	ball_ghost_rim = false
	through_rim = false
	lbl_mid.text = ""
	session_left = HC_SECONDS
	Events.toast.emit("SFIDA METÀ CAMPO: 60 secondi, contano solo i GREEN 🟢")
	_hc_teleport()
	hc_expanded = false
	if btn_hc:
		btn_hc.text = "⏱"
		btn_hc.disabled = true
		_hc_shrink()

## La sfida è una modalità skill pura: zero consumo di energia, altrimenti
## chi si allena sui green si ritrova senza gambe per il resto della carriera
## (e il dunk, che richiede energia, spariva da tutti i court).
func _drain_energy(v: float) -> void:
	if hc_mode:
		return
	Game.add_energy(v)

func _hc_teleport() -> void:
	## Spot casuale oltre la linea di metà campo: da lì la banda verde è
	## una fessura, e la distanza è la difficoltà della sfida.
	# box SPAWN VISIBILE: sempre dentro lo schermo, sempre oltre metà campo
	# e sempre oltre l'arco (36ft+): posizione leggibile e green sempre valido
	player_pos = Vector2(randf_range(-380.0, -260.0), randf_range(-220.0, 220.0))
	facing = 1.0
	# la camera SALTA subito sul giocatore: zero secondi col nome tagliato
	if has_meta("cam"):
		var cam: Camera2D = get_meta("cam")
		cam.position.x = CourtStage.m_project(player_pos, Court.COURT_H).x
	ball_live = false
	ball_settled = 0.0
	ball_ghost_rim = false
	through_rim = false

func _shoot_down() -> void:
	if shot_anim > 0.0 or dunk_phase != "":
		return
	if can_dunk() and not posting:
		_start_dunk()
		return
	charging = true
	charge = 0.0
	ideal = clampf(0.42 + _distance_ft() * 0.012, 0.42, 0.78)
	# The green band tightens with distance and matches the scoring windows.
	var w: Dictionary = ShotSystem.shot_windows(_distance_ft(), hot)
	meter.perfect_window = float(w["perfect"])
	meter.good_window = float(w["good"])
	# FADEAWAY: levetta INDIETRO mentre carichi -> schienata (stile Kobe):
	# il tiro è più difficile (finestra stretta) ma la mossa è tua.
	fade_pending = false
	var mv_f: Vector2 = joystick.output if joystick != null else Vector2.ZERO
	if mv_f.dot((player_pos - RIM).normalized()) > 0.40 and _distance_ft() > 8.0:
		fade_pending = true
		meter.perfect_window = float(w["perfect"]) * 0.72
		meter.good_window = float(w["good"]) * 0.85

## Dunk: drive at the rim, rise to the iron, throw it down -- then HANG there
## until the dunk button is released.
func _start_dunk() -> void:
	dunk_phase = "rise"
	dunk_anim = 0.0
	dunk_ball_t = 0.0
	want_hang = true
	shot_made = true
	# Same catalogue the scrimmage and the 1v1 use -- a windmill on the street
	# court is the same windmill as in the arena.
	dunk_style = DunkStyle.pick()
	dunk_rise_t = DunkStyle.rise_time(dunk_style)

func _dunk_throw() -> void:
	attempts += 1
	makes += 1
	streak += 1
	best_streak = maxi(best_streak, streak)
	net_wobble = 1.0
	Sfx.haptic(60)
	if court_art != null:
		court_art.net_bump(1, 1.0)
	Events.shot_taken.emit("DUNK %s" % DunkStyle.label(dunk_style), true, 2)
	Game.add_xp(SPOT_XP + 4, "solo_shots")
	_drain_energy(-1.6)
	session_score += 2
	dunk_ball_t = 0.0
	lbl_mid.text = "%s!  x%d" % [DunkStyle.label(dunk_style), streak]
	lbl_mid.modulate = Color(1.0, 0.75, 0.25)

func _drop_from_rim() -> void:
	if dunk_phase == "hang":
		dunk_phase = "drop"
		dunk_anim = 0.0

func _shoot_up() -> void:
	# Dunk button release: stop hanging and come down (or skip the hang if the
	# finger was already off while rising).
	if dunk_phase == "rise":
		# Keep hanging when we reach the rim even if the tap was short.
		return
	if dunk_phase == "hang":
		_drop_from_rim()
		return
	if not charging:
		return
	if fade_pending:
		_family_tag = "FADEAWAY"
		fade_t = 0.75
		fade_dir = (player_pos - RIM).normalized()
		fade_pending = false
	if session_over:
		charging = false
		return
	# A quick TAP sells a pump fake everywhere, solo courts included.
	if charge < 0.17 and dunk_phase == "":
		charging = false
		charge = 0.0
		pump_t = 0.35
		if meter:
			meter.charge = 0.0
		return
	charging = false
	attempts += 1
	# FADE DA POST: hop indietro, il tiro parte "andando via". Sotto i 9ft
	# la famiglia diventa HOOK, oltre FADEAWAY (stessa soglia del match).
	_family_tag = ""
	if posting:
		# la soglia HOOK/FADE si misura PRIMA dell'hop (come in partita,
		# dove l'hop e' solo velocita': la distanza al rilascio e' quella)
		_family_tag = "HOOK!" if _distance_ft() < 9.0 else "FADEAWAY!"
		posting = false
		var away: Vector2 = player_pos - RIM
		if away.length() > 1.0:
			player_pos += away.normalized() * 46.0

	var w: Dictionary = ShotSystem.shot_windows(_distance_ft(), hot)
	var pw: float = float(w["perfect"])
	var gw: float = float(w["good"])
	var err: float = absf(charge - ideal)
	var timing: float
	var verdict: String
	var verdict_col: Color
	var zone: String
	if err <= pw:
		zone = "green"
		timing = 1.0; verdict = "PERFECT"; verdict_col = Color(0.35, 1.0, 0.45)
		Sfx.haptic(50)
		Events.popup.emit("GREEN!", player_pos + Vector2(0, -95), Color(0.3, 1.0, 0.45), true)
	elif err <= gw:
		zone = "yellow"
		timing = 0.66; verdict = "GOOD"; verdict_col = Color(0.95, 0.85, 0.30)
	else:
		zone = "red"
		timing = 0.18
		verdict = "EARLY" if charge < ideal else "LATE"
		verdict_col = Color(1.0, 0.45, 0.38)

	var ft: float = _distance_ft()
	var skill: float = float(Game.attr_eff("three" if ft > Court.THREE_FT else ("mid" if ft > 15.0 else "close")))
	var base: float
	if ft <= 5.0:
		base = lerpf(0.55, 0.88, skill / 99.0)
	elif ft <= 15.0:
		base = lerpf(0.32, 0.60, skill / 99.0)
	else:
		base = lerpf(0.24, 0.56, clampf((skill - 35.0) / 60.0, 0.0, 1.0))
	if ft > Court.THREE_FT:
		var over: float = ft - Court.THREE_FT
		base -= over * 0.014 + over * over * 0.0022
	# Stessa regola del match: verde 100%, giallo 50/50, rosso MAI.
	if zone == "green":
		shot_made = true
	elif zone == "yellow":
		shot_made = randf() < 0.5
	else:
		shot_made = false

	if shot_made:
		makes += 1
		streak += 1
		if streak >= 3 and not hot:
			hot = true
			Events.popup.emit("ON FIRE!", player_pos, Color(1.0, 0.55, 0.15), true)
		best_streak = maxi(best_streak, streak)
		CareerEvents.on_solo_make(streak)
		Game.add_xp(SPOT_XP, "solo_shots")
		var pts: int = 3 if _distance_ft() > Court.THREE_FT else 2
		session_score += pts
		lbl_mid.text = (_family_tag + "  " if _family_tag != "" else "") + "+%d  ·  x%d" % [pts, streak]
	else:
		if hot:
			hot = false
			Events.popup.emit("COLD", player_pos, Color(0.7, 0.75, 0.85), false)
		streak = 0
		lbl_mid.text = ""
	# HALF-COURT CHALLENGE: conta SOLO il green da oltre la linea.
	if hc_mode:
		if zone == "green" and ft >= HC_MIN_FT:
			hc_greens += 1
			session_score = hc_greens
			if hc_greens > hc_best:
				lbl_mid.text = "GREEN %d   ·   NEW RECORD! 🏆" % hc_greens
			else:
				lbl_mid.text = "GREEN %d   ·   RECORD %d" % [hc_greens, hc_best]
		elif zone == "green":
			Events.popup.emit("TOO CLOSE!", player_pos + Vector2(0, -70), Color(1.0, 0.75, 0.2), false)
			lbl_mid.text = "TOO CLOSE — serve da oltre la metà!"
	lbl_mid.modulate = verdict_col
	if meter:
		meter.show_release(verdict, verdict_col)

	_drain_energy(-0.35)
	shot_anim = 0.001
	ball_from = player_pos

	var aim: Vector2
	if zone == "green":
		aim = RIM
	elif zone == "yellow":
		# GIALLO: se entra la vedi cadere DENTRO (swish); se fallisce sbatte
		# sul ferro ed esce — mai un finto canestro o un ferro muto.
		if shot_made:
			aim = RIM + Vector2(randf_range(-12.0, 12.0), randf_range(-6.0, 6.0))
		else:
			var nrm_y: Vector2 = (RIM - player_pos).normalized()
			if nrm_y.length() < 0.1:
				nrm_y = Vector2(1, 0)
			aim = RIM + nrm_y * randf_range(RIM_HALF + 6.0, RIM_HALF + 12.0)
	else:
		# ROSSO: mai dentro. Corto (airball davanti) o lungo (dietro).
		var away: float = signf(RIM.x - player_pos.x)
		if away == 0.0:
			away = 1.0
		if charge < ideal:
			aim = RIM + Vector2(-away * randf_range(70.0, 120.0), 30.0)
		else:
			aim = RIM + Vector2(away * randf_range(50.0, 90.0), -40.0)
	_launch_ball(ball_from, aim)
	ball_ghost_rim = (zone == "green")

	if attempts % 12 == 0:
		SaveSystem.save_game()

## Fire the ball from `from` so its arc passes through `aim` at rim height.
## The parabola is exact (no drag), so a green release always drops in.
func _launch_ball(from: Vector2, aim: Vector2) -> void:
	ball_pos = from
	ball_h = 55.0
	ball_live = true
	ball_settled = 0.0
	scored_this_shot = false
	through_rim = false
	ball_rattled = false
	prev_h = ball_h
	prev_pos = ball_pos
	var dist: Vector2 = aim - from
	var flight: float = clampf(dist.length() / 430.0, 0.5, 1.6)
	ball_vel = dist / flight
	ball_vh = (RIM_HEIGHT - ball_h + 0.5 * GRAV * flight * flight) / flight
	ball_spin = -signf(dist.x) * 7.0

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

	if ball_pos.x < -1300.0 or ball_pos.x > 1300.0 \
	or ball_pos.y < -Court.COURT_H or ball_pos.y > Court.COURT_H:
		ball_live = false
	if ball_settled > 1.1:
		ball_live = false

## The ring is a circle in the court plane at rim height. Crossing down
## through its middle scores; clipping its edge clangs the iron and snaps the
## net without scoring.
func _collide_rim() -> void:
	if ball_h <= RIM_HEIGHT and prev_h >= RIM_HEIGHT and ball_vh < 0.0:
		var span: float = prev_h - ball_h
		var f: float = 0.0 if span <= 0.0 else (prev_h - RIM_HEIGHT) / span
		var cx: float = lerpf(prev_pos.x, ball_pos.x, clampf(f, 0.0, 1.0))
		var cy: float = lerpf(prev_pos.y, ball_pos.y, clampf(f, 0.0, 1.0))
		var d: Vector2 = Vector2(cx, cy) - RIM
		var dist: float = d.length()
		if dist < RIM_HALF - 6.0 or (ball_rattled and dist < RIM_HALF + 6.0):
			# RIM-RATTLE: anche il court libero deve avere il suo momento
			# firma (30%): ferro fortissimo, pop sopra il ferro, poi swish.
			if not ball_rattled and not through_rim and randf() < 0.30:
				ball_rattled = true
				var rn_s: Vector2 = (ball_pos - RIM).normalized()
				if rn_s.length() < 0.1:
					rn_s = Vector2(1, 0)
				ball_pos = RIM + rn_s * 9.0
				ball_vh = randf_range(500.0, 640.0)
				ball_vel = rn_s * randf_range(30.0, 55.0) + Vector2(randf_range(-25, 25), randf_range(-25, 25))
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
				through_rim = true
				scored_this_shot = true
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
		if dist < RIM_HALF + 14.0 and not ball_ghost_rim:
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
	# brushing the net without going through still moves it
	var d2: Vector2 = ball_pos - RIM
	if ball_h < RIM_HEIGHT and ball_h > RIM_HEIGHT - 130.0 \
	and d2.length() < RIM_HALF + 26.0:
		net_wobble = maxf(net_wobble, 0.45)
		if court_art != null:
			court_art.net_bump(1, 0.45)

## Backboard: a vertical plane just behind the rim (the court is to the left,
## so the glass sits to the right of the ring).
func _collide_backboard() -> void:
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
	if ball_h <= 0.0:
		ball_h = 0.0
		if absf(ball_vh) > 60.0:
			ball_vh = -absf(ball_vh) * 0.58
			ball_vel *= 0.86
		else:
			ball_vh = 0.0
			ball_vel *= 0.90
			ball_settled += 0.016

func _end_session() -> void:
	if session_over:
		return
	session_over = true
	charging = false
	# HALF-COURT: aggiorna il record personale del profilo.
	var hc_new_record := false
	if hc_mode and hc_greens > hc_best:
		hc_best = hc_greens
		Game.profile["hc_best"] = hc_best
		hc_new_record = true
	SaveSystem.save_game()
	var p: GamePanel = GamePanel.new().build("⏱  TIME", Vector2(760, 560))
	hud_layer.add_child(p)
	var pct: int = int(round(100.0 * float(makes) / maxf(float(attempts), 1.0)))
	if hc_mode:
		p.add_text("GREEN  %d" % hc_greens, 46, Color(0.3, 1.0, 0.45))
		if hc_new_record:
			p.add_text("🏆 NEW RECORD!  (record: %d)" % hc_best, 28, Color(1, 0.88, 0.35))
		else:
			p.add_text("Record da battere:  %d" % hc_best, 24, Color(1, 1, 1, 0.8))
	else:
		p.add_text("SCORE  %d" % session_score, 46, Color(1, 0.88, 0.35))
		p.add_text("%d of %d shots made  ·  %d%%" % [makes, attempts, pct], 24)
		p.add_text("Best streak: %d" % best_streak, 22, Color(1, 1, 1, 0.7))
	p.add_text("")
	if hc_mode:
		# Crescita organica: il punteggio finisce negli appunti, pronto da
		# incollare su WhatsApp/TikTok — è il gioco che si pubblicita da solo.
		var _share := func() -> void:
			DisplayServer.clipboard_set("🟢 %d GREEN in 60 secondi nella SFIDA METÀ CAMPO di Hoop City Life 🏀\nRiesci a battermi? Gratis, solo Android 👉 https://github.com/steph-x35/new-arena-code/releases" % hc_greens)
			Events.toast.emit("Copiato! Incollalo su WhatsApp o TikTok 📋")
		p.add_button("🏁 SFIDA GLI AMICI (copia messaggio)", _share, true)
	p.add_button("Riprova (60 secondi)" if hc_mode else "Shoot again (2 more minutes)", func():
		if hc_mode:
			session_left = HC_SECONDS
			hc_greens = 0
			_hc_teleport()
		else:
			session_left = SESSION_SECONDS
		session_over = false
		session_score = 0
		makes = 0
		attempts = 0
		streak = 0
		p.close(), true)
	if hc_mode:
		p.add_button("Torno a tirare", func():
			hc_mode = false
			session_left = SESSION_SECONDS
			session_over = false
			session_score = 0
			makes = 0
			attempts = 0
			streak = 0
			hot = false
			if btn_hc:
				btn_hc.text = "🏆 SFIDA METÀ CAMPO"
				btn_hc.disabled = false
			p.close())
	p.add_button("Leave", func(): _leave())

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	_draw_graffiti()
	_draw_npcs()
	_draw_player()
	if outdoor:
		_draw_park()

## GRAFFITI: il nome della carriera sul MURO in fondo — BIANCO E NERO,
## lettere gonfiate ma ROVINATE e trasandate: usura (la vernice si è
## consumata a chiazze) e GRAFFI netti che attraversano le lettere.
## Più piccolo del bubble candy che c'era prima. Deterministico sul nome.
const GRAF_FILL := Color(0.92, 0.92, 0.90)    # BIANCO sporco: vernice sbiadita
const GRAF_LINE := Color(0.06, 0.06, 0.07)    # NERO: contorno consumato
const GRAF_OVERLAP := 0.78                    # le lettere si SOPRAPPPONGONO

func _draw_graffiti() -> void:
	if not outdoor:
		return
	var tag: String = String(Game.profile.get("name", "")).to_upper().strip_edges()
	if tag == "":
		return
	var base: Vector2 = _screen(Vector2(0.0, -Court.COURT_H * 0.5))
	base.y -= 52.0
	var f: Font = ThemeDB.fallback_font
	var size := 42
	var widths: Array = []
	var total := _graf_measure(tag, f, size, widths)
	if total > 470.0:
		size = int(42.0 * 470.0 / total)
		widths = []
		total = _graf_measure(tag, f, size, widths)
	# 1) NUBE grigia spenta dietro il piece: il muro che sbuca dove la
	#    vernice si è consumata
	for k in 5:
		var hx := float(abs(hash(tag + "n" + str(k))))
		draw_circle(Vector2(base.x + (hx * 0.0000001 - 0.5) * total * 0.9,
			base.y - 16.0 + fmod(hx * 0.0000003, 22.0) - 11.0),
			22.0 + fmod(hx * 0.000002, 12.0), Color(0.58, 0.58, 0.60, 0.28))
	var x := -total * 0.5
	for i in tag.length():
		var ch := tag[i]
		var h1 := float(abs(hash(ch + str(i))))    # pseudo-random STABILE
		var rot := fmod(h1 * 0.00000013, 0.20) - 0.10
		var dy := fmod(h1 * 0.0000007, 11.0) - 5.5
		var cw: float = widths[i]
		draw_set_transform(Vector2(base.x + x + cw * 0.5, base.y + dy), rot, Vector2(1.0, 1.06))
		var half := Vector2(-cw * 0.5, 0)
		# 2) CONTORNO nero spesso ma ROVINATO: 10 passate, alcune sconnesse
		for k in 10:
			var a := TAU * float(k) / 10.0
			var wob: float = 3.6 + (0.9 if k % 3 == 0 else 0.0)
			draw_string(f, half + Vector2(cos(a), sin(a)) * wob,
				ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, GRAF_LINE)
		# 3) RIEMPIMENTO bianco sporco, gonfio
		for k in 6:
			var a := TAU * float(k) / 6.0
			draw_string(f, half + Vector2(cos(a), sin(a)) * 1.9,
				ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, GRAF_FILL)
		draw_string(f, half, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, GRAF_FILL)
		# 4) USURA: chiazze trasparenti, la vernice consumata dagli anni
		for k in 2:
			var h2 := float(abs(hash(ch + "w" + str(i) + str(k))))
			var ux: float = half.x + 2.0 + fmod(h2 * 0.0000009, maxf(cw - 6.0, 2.0))
			var uy: float = -size * (0.55 + fmod(h2 * 0.0000004, 0.30))
			draw_rect(Rect2(ux, uy, 5.0 + fmod(h2 * 0.000002, 9.0),
				4.0 + fmod(h2 * 0.000003, 7.0)), Color(0.45, 0.45, 0.47, 0.30))
		# 5) GRAFFI: segni netti che attraversano la lettera
		for k in 3:
			var h3 := float(abs(hash(ch + "s" + str(i) + str(k))))
			var gx: float = half.x + 1.0 + fmod(h3 * 0.0000007, maxf(cw - 2.0, 2.0))
			var gy: float = -size * (0.25 + fmod(h3 * 0.0000005, 0.45))
			var ga: float = fmod(h3 * 0.00000011, 1.2) - 0.6
			var gl: float = 6.0 + fmod(h3 * 0.000002, 9.0)
			draw_line(Vector2(gx, gy), Vector2(gx + cos(ga) * gl, gy + sin(ga) * gl),
				Color(0.10, 0.10, 0.11, 0.55), 1.6)
		x += cw * GRAF_OVERLAP
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Larghezze per lettera + totale (il graffiti avanza lettera per lettera).
func _graf_measure(tag: String, f: Font, size: int, out: Array) -> float:
	var total := 0.0
	for i in tag.length():
		var cw: float = f.get_string_size(tag[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 6.0
		out.append(cw)
		total += cw
	return total

## Primo piano del parco: panchine e cestini lungo il bordo in basso,
## disegnati come se fossero vicino alla telecamera.
func _draw_park() -> void:
	## La fascia d'erba VERA sta qui: sotto il bordo vicino del campo
	## (schermo y ~192, il bordocampo finisce ~187) fino al fondo schermo
	## (~306). Le vecchie panchine stavano a y=700: mai state sullo schermo!
	## Copriamo tutto il pan orizzontale della camera (x -1060..1060).
	var g_top := 192.0
	var g_bot := 334.0
	var tt: float = Time.get_ticks_msec() / 1000.0
	# base a due tonalita' sovrapposte: niente piu' tinta unica
	draw_rect(Rect2(-1060.0, g_top, 2120.0, g_bot - g_top), Color(0.27, 0.42, 0.21))
	draw_rect(Rect2(-1060.0, g_top + 34.0, 2120.0, g_bot - g_top - 34.0),
		Color(0.24, 0.40, 0.20))
	# bordo scuro di transizione col campo
	draw_rect(Rect2(-1060.0, g_top, 2120.0, 5.0), Color(0.17, 0.29, 0.15))
	# chiazze disomogenee di verde: il prato vero non e' piatto
	for k in 44:
		var hx := float(abs(hash("patch" + str(k))))
		var px2: float = -1050.0 + fmod(hx * 0.0000001, 2100.0)
		var py2: float = g_top + 8.0 + fmod(hx * 0.0000003, g_bot - g_top - 12.0)
		var tone: Color = Color(0.20 + fmod(hx, 5.0) * 0.018,
			0.36 + fmod(hx, 7.0) * 0.02, 0.16 + fmod(hx, 3.0) * 0.012, 0.60)
		draw_circle(Vector2(px2, py2), 8.0 + fmod(hx * 0.000002, 16.0), tone)
	# CIUFFI: 160 tufts da 3 fili, un terzo ONDEGGIA col vento, il resto fermo
	for k in 160:
		var hb := float(abs(hash("blade" + str(k))))
		var bx2: float = -1050.0 + fmod(hb * 0.0000001, 2100.0)
		var by2: float = g_top + 14.0 + fmod(hb * 0.0000004, g_bot - g_top - 16.0)
		var hgt: float = 6.0 + fmod(hb * 0.000003, 7.0)
		var lean2: float = fmod(hb * 0.0000005, 3.0) - 1.5
		var col2: Color = Color(0.29 + fmod(hb, 6.0) * 0.022,
			0.45 + fmod(hb, 4.0) * 0.022, 0.20 + fmod(hb, 3.0) * 0.014)
		for b in 3:
			var sway: float = 0.0
			if fmod(hb * 0.0000001, 3.0) < 1.0:      # un ciuffo su tre ondeggia
				sway = sin(tt * 1.7 + bx2 * 0.05 + float(b)) * 2.0
			draw_line(Vector2(bx2 + float(b) * 2.6 - 2.6, by2),
				Vector2(bx2 + float(b) * 2.6 - 2.6 + lean2 + sway, by2 - hgt + float(b)),
				col2, 1.4)
	# DUE panchine distanziate, DAVANTI a chi guarda (sempre in campo visivo
	# quando la camera e' ferma: x -330 / +330, vista +/-615)
	for bx in [-330.0, 330.0]:
		var by := 302.0
		# ombra a terra
		draw_rect(Rect2(bx - 70.0, by - 3.0, 140.0, 6.0), Color(0.13, 0.22, 0.11, 0.5))
		# gambe metalliche
		draw_rect(Rect2(bx - 56.0, by - 26.0, 8.0, 26.0), Color(0.30, 0.30, 0.34))
		draw_rect(Rect2(bx + 48.0, by - 26.0, 8.0, 26.0), Color(0.30, 0.30, 0.34))
		# seduta: due listelli di legno
		draw_rect(Rect2(bx - 66.0, by - 34.0, 132.0, 8.0), Color(0.58, 0.42, 0.26))
		draw_rect(Rect2(bx - 66.0, by - 25.0, 132.0, 7.0), Color(0.52, 0.37, 0.22))
		# schienale: due listelli + montanti
		draw_rect(Rect2(bx - 66.0, by - 62.0, 132.0, 8.0), Color(0.58, 0.42, 0.26))
		draw_rect(Rect2(bx - 66.0, by - 52.0, 132.0, 7.0), Color(0.52, 0.37, 0.22))
		draw_rect(Rect2(bx - 58.0, by - 62.0, 7.0, 30.0), Color(0.42, 0.30, 0.18))
		draw_rect(Rect2(bx + 51.0, by - 62.0, 7.0, 30.0), Color(0.42, 0.30, 0.18))
	# due cestini ai bordi (visibili quando la camera scorre)
	for tx in [-720.0, 720.0]:
		var ty := 306.0
		draw_rect(Rect2(tx - 20.0, ty - 50.0, 40.0, 50.0), Color(0.16, 0.30, 0.22),
			false, 0.0)
		draw_polygon(PackedVector2Array([
			Vector2(tx - 20.0, ty - 50.0), Vector2(tx + 20.0, ty - 50.0),
			Vector2(tx + 15.0, ty), Vector2(tx - 15.0, ty)]),
			PackedColorArray([Color(0.16, 0.30, 0.22), Color(0.16, 0.30, 0.22),
				Color(0.11, 0.22, 0.16), Color(0.11, 0.22, 0.16)]))
		draw_rect(Rect2(tx - 24.0, ty - 58.0, 48.0, 10.0), Color(0.13, 0.26, 0.19))
		draw_circle(Vector2(tx + 6.0, ty - 60.0), 7.0, Color(0.65, 0.62, 0.55))
		draw_circle(Vector2(tx - 8.0, ty - 62.0), 5.0, Color(0.72, 0.70, 0.62))

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

func _draw_player() -> void:
	var base := player_pos
	# Constant size anywhere on the floor: no perspective shrink.
	var h: float = 64.0 * Game.height_factor()

	var kind := Avatar.IDLE
	var amount := 0.0
	var phase: float = dribble_t
	var draw_base: Vector2 = base
	var lift := 0.0
	var carry: bool = true
	# Dunk pose from the shared catalogue, so the street court plays the same
	# slams as the arena. Empty for every other animation.
	var slam: Dictionary = {}
	var grip_at := Vector2(1e9, 1e9)

	if dunk_phase != "":
		var rim_x: Vector2 = RIM - Vector2(20.0, 0.0)
		# Feet lift that puts the outstretched hand ON the iron: the same
		# DunkStyle.REACH the pose and the ball are built from.
		var hang_lift: float = maxf(RIM_HEIGHT - h * DunkStyle.REACH, 0.0)
		match dunk_phase:
			"rise":
				var f: float = clampf(dunk_anim / maxf(dunk_rise_t, 0.05), 0.0, 1.0)
				lift = sin(f * PI * 0.5) * hang_lift
				draw_base = player_pos.lerp(rim_x, smoothstep(0.0, 0.62, f))
				kind = Avatar.DUNK
				amount = f
				carry = true
				slam = DunkStyle.sample(dunk_style, f)
			"hang":
				draw_base = rim_x
				lift = hang_lift
				kind = Avatar.DUNK
				amount = 1.0
				carry = false
				slam = DunkStyle.sample(dunk_style, 1.0)
			"drop":
				var f: float = clampf(dunk_anim / 0.5, 0.0, 1.0)
				draw_base = rim_x.lerp(player_pos, f)
				lift = (1.0 - f) * maxf(hang_lift_now, 60.0)
				kind = Avatar.DUNK
				amount = 1.0 - f
				carry = false
				slam = DunkStyle.sample(dunk_style, 1.0)
	elif shot_anim > 0.0:
		kind = Avatar.SHOOT
		amount = clampf(shot_anim / 0.22, 0.0, 1.0)
	elif pump_t > 0.0:
		# pump fake: a quick triangle rise and settle with the ball held
		kind = Avatar.SHOOT
		var k: float = 1.0 - pump_t / 0.35
		amount = 0.25 + 0.60 * (1.0 - absf(k * 2.0 - 1.0))
	elif charging:
		kind = Avatar.SHOOT
		amount = 1.0 - clampf(charge / maxf(ideal, 0.01), 0.0, 1.0) * 0.85
	elif trick_t > 0.0:
		kind = Avatar.DRIBBLE
		phase = dribble_t * 1.9
		amount = trick_t / 0.45
	elif joystick.output.length() > 0.06:
		kind = Avatar.DRIBBLE
		phase = dribble_t
	else:
		kind = Avatar.DRIBBLE

	# Read slightly bigger when attacking the rim or rising into a jumper.
	# Street-court height — no extra scale.

	var screen: Vector2 = _screen(draw_base) - Vector2(0.0, lift)
	# POLVERE d'atterraggio (come nei match): grande dopo uno slam.
	if dust_t > 0.0:
		var dur: float = 0.70 if dust_big else 0.45
		var kk: float = clampf(1.0 - dust_t / dur, 0.0, 1.0)
		var da: float = (1.0 - kk) * (0.65 if dust_big else 0.5)
		var spr: float = lerpf(16.0, 78.0, kk) if dust_big else lerpf(14.0, 50.0, kk)
		var low: bool = bool(Settings.get_v("lowgfx", false))
		var nn: int = (5 if dust_big else 3) if low else (10 if dust_big else 6)
		for i in nn:
			var sd: float = -1.0 if i % 2 == 0 else 1.0
			var px: float = screen.x + sd * spr * (0.4 + 0.6 * float((i + 1) % 3) / 2.0)
			var py: float = screen.y - 6.0 - (i % 2) * (7.0 if dust_big else 5.0)
			var rr: float = lerpf(9.0, 2.5, kk) if dust_big else lerpf(7.0, 2.5, kk)
			draw_circle(Vector2(px, py), rr, Color(0.85, 0.80, 0.68, da))
	# OMBRA REALE durante la schiacciata: a terra, scorre al centro della
	# semicirconferenza sotto il ferro e cresce con l'altezza.
	if dunk_phase != "":
		var sh_world: Vector2 = player_pos.lerp(RIM, clampf(dunk_anim / maxf(dunk_rise_t, 0.05), 0.0, 1.0)) \
			if dunk_phase == "rise" else RIM
		var sh_base: Vector2 = _screen(sh_world)
		var grow: float = 1.15 + clampf(lift / 240.0, 0.0, 0.35)
		var rw: float = 14.0 * grow
		var rh: float = 5.5 * grow
		var pts: PackedVector2Array = []
		for i in 20:
			var ang: float = TAU * float(i) / 20.0
			pts.append(sh_base + Vector2(cos(ang) * rw, sin(ang) * rh))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.40))
	# SCIA PALLA in volo (stessa del match): fantasmi che svaniscono.
	# Scia rimossa su richiesta utente.
	var hold_ball: bool = carry and not ball_live and trick_t <= 0.0
	var walking: bool = joystick.output.length() > 0.12 and dunk_phase == "" and shot_anim <= 0.0 and not charging
	var dunk_trick := dunk_style if dunk_phase != "" else (trick_kind if trick_t > 0.0 else "")
	var po: Dictionary = Avatar.pose(kind, phase, amount, dunk_trick, walking)
	if fade_t > 0.0:
		po["lean_back"] = clampf(fade_t / 0.75, 0.0, 1.0)
	if dunk_phase == "hang":
		po["hang"] = true
		if grip_at.x < 1e8:
			# RELATIVO ai piedi del disegno: le mani vanno al punto esatto
			# del ferro qualunque sia la posa del corpo (era il bug delle
			# braccia lunghissime: coordinate assolute prese come offset).
			po["grip_at"] = grip_at - screen
	po["hand"] = -1.0 if hand_left else 1.0
	# SPIN MOVE: la rotazione del corpo come in partita (passa di schiena
	# alla telecamera mentre gira, come lo yaw dei giocatori del match).
	if trick_t > 0.0 and trick_kind == "spin":
		po["yaw"] = 2.2 * (1.0 - trick_t / 0.45)
	if pump_t > 0.0:
		po["fake"] = true
	if not slam.is_empty():
		# The slam owns the pose, including the turn of a 360 or a reverse.
		po["dunk"] = slam
	elif dunk_phase == "hang" and player_pos.y < -20.0:
		po["back"] = true
	if joystick and joystick.output.y < -0.22 and dunk_phase == "":
		po["back"] = true
	Avatar.draw_body(self, screen, h, facing, po, Avatar.colours(true), hold_ball,
		dunk_phase == "", true, BALL_R)
	# HEAT CHECK: stesse lingue di fuoco del match (helper condiviso).
	if hot and not bool(Settings.get_v("lowgfx", false)):
		Avatar.draw_flames(self, screen + Vector2(0.0, -h * 1.16), Time.get_ticks_msec() / 1000.0)

	if trick_t > 0.0:
		var f: float = 1.0 - trick_t / 0.45
		var from_side: float = 1.0 if hand_left else -1.0
		var to_side: float = -from_side
		var sway: float = lerpf(from_side, to_side, smoothstep(0.0, 1.0, f))
		var low: float = sin(f * PI)
		var bp := screen + Vector2(sway * h * 0.34, -h * 0.16 - low * h * 0.10)
		if trick_kind == "behind":
			bp.y = screen.y - h * 0.30 + low * h * 0.06
		_draw_ball_at(bp, BALL_R)

	if ball_live:
		var bs: Vector2 = _screen(ball_pos)
		var bpos := Vector2(bs.x, bs.y - ball_h)
		# NBA JAM HEAT: palla in fiamme quando sei HOT (3 canestri di fila)
		if hot and not bool(Settings.get_v("lowgfx", false)):
			Avatar.draw_ball_flames(self, bpos, BALL_R, Time.get_ticks_msec() / 1000.0, Vector2(ball_vel.x, ball_vel.y * 0.5 - ball_vh))
		_draw_ball_at(bpos, BALL_R)

	# Dunk ball dropping through the net while the player hangs.
	if dunk_phase == "hang" or dunk_phase == "drop":
		# the made dunk drops through the net and lands at the centre of the
		# short baseline, under the stanchion -- not at the dunker's feet
		var f: float = clampf(dunk_ball_t * 1.7, 0.0, 1.0)
		var rim_s: Vector2 = _rim_screen()
		var floor_s: Vector2 = _screen(RIM)   # centre of the restricted arc
		_draw_ball_at(rim_s.lerp(floor_s, f * f), BALL_R)

	# The near half of the net, painted OVER the ball when it is dropping
	# through the basket, so the ball reads as passing BEHIND the mesh.
	var near_net := false
	if ball_live and ball_h < RIM_HEIGHT + 30.0 and (ball_pos - RIM).length() < 70.0:
		near_net = true
	elif dunk_phase == "hang" or dunk_phase == "drop":
		near_net = true
	if near_net:
		HoopArt.draw_net_front(self, _rim_screen(), 22.0, 22.0 * HoopArt.RIM_SQUASH,
			net_wobble, net_t, clampf(court_art.rim_bend[1], 0.0, 1.0), -1.0)

func _draw_ball_at(p: Vector2, r: float) -> void:
	draw_circle(p, r, Color(0.95, 0.55, 0.15))
	draw_arc(p, r, 0, TAU, 18, Color(0.35, 0.18, 0.07), 2.0)
	var a: float = ball_spin
	draw_line(p + Vector2(cos(a), sin(a)) * -r, p + Vector2(cos(a), sin(a)) * r,
		Color(0.35, 0.18, 0.07), 2.0)
	var b: float = a + PI * 0.5
	draw_arc(p, r * 0.86, b - 1.1, b + 1.1, 10, Color(0.35, 0.18, 0.07), 2.0)
