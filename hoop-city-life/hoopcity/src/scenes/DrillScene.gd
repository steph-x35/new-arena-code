extends Node2D
## Three real minigames sharing one shell: timer, score, grade, XP payout.
## kind = "shooting" | "handling" | "defense"

var drill_kind := "shooting"
var time_left := 30.0
var score := 0.0
var max_score := 1.0
var running := true
var combo := 0

# shooting
var spots: Array = []
var current_spot := 0
var meter := 0.0
var meter_dir := 1.0
var meter_ideal := 0.55
var ghost_def := 0.0

# handling
var cones: Array = []
var court_art: Node2D
var hand_left := true           # which hand the ball is in
var cross_flash := 0.0          # brief highlight when you cross over
var dribble_phase := 0.0
var runner_pos := Vector2.ZERO
var cone_index := 0
var window_open := false
var window_t := 0.0

# defense
var attacker_x := 0.0
var attacker_target := 0.0
var defender_x := 0.0
var hold_quality := 0.0
var contest_ready := false

# weights (bench press): a rep is a full down-up cycle. You tap at the bottom to
# drive the bar up. Tap in the green "drive zone" for a clean rep; tap early or
# late and the form breaks. Fatigue makes the bar heavier and the zone smaller,
# so late reps genuinely demand better timing -- skill, not clicking.
var bar_t := 0.0                # 0 = racked/top, 1 = chest
var bar_dir := 1.0
var reps := 0
var bad_reps := 0
var fatigue := 0.0
var rep_flash := 0.0
var lift_kind := "bench"        # bench | squat | power_clean
var machine_kind := "bike"      # bike | treadmill
## Cardio: hold your effort inside a target band that keeps moving. Tap to
## push harder, let go to ease off -- effort always drifts back down.
var effort := 0.4               # 0..1, what you are actually doing
var target := 0.5               # centre of the band to sit in
var band := 0.16                # half-width of the band
var in_band_time := 0.0
var total_time := 0.0
var pushing := false
var cadence := 0.0              # visual: pedal / stride phase

## One ball, one size, wherever it is in the gym: the same radius whether he
## is dribbling it or letting it fly, so the ball does not visibly shrink and
## grow between poses. Kept in the same proportion to the player as the match
## and solo balls (about 0.21x the player's height), so the ball is THE SAME
## dimension relative to its man in every environment.
const DRILL_BALL_R := 7.0    # same Court.BALL_R as every other court
const DRILL_BODY_H := 64.0   # same match / street-court figure height

func _court_body_h() -> float:
	return 64.0 * Game.height_factor()
const DRILL_RIM_H := 188.0   # Court.RIM_HEIGHT — same hoop as 1v1 / scrimmage

## Shot animation state: the shooter dips, rises and follows through, and the
## ball flies on a visible arc. Without this the shooting drill was a coloured
## ring and a slider with nobody actually playing basketball.
var shot_anim := 0.0            # 0 = idle, counts up while the shot plays out
var shot_made := false
var net_wobble := 0.0           # shared net reaction, same as match and solo
var ball_rattled := false       # il ferro e' gia' stato suonato su questo tiro
var net_t := 0.0
var ball_from := Vector2.ZERO
var ball_to := Vector2.ZERO
var dribble_t := 0.0
var ball_live := false
var ball_court := Vector2.ZERO
var ball_h := 0.0
var ball_v := Vector2.ZERO
var ball_vh := 0.0
var ball_prev_h := 0.0
var ball_prev := Vector2.ZERO
const DRILL_GRAV := 1800.0
const DRILL_RIM_HALF := 42.0

var joystick: VirtualJoystick
var lbl_top: Label
var lbl_mid: Label
var shot_meter: ShotMeter
var charging := false
var charge := 0.0

func _ready() -> void:
	Sfx.stop_music()   # solo/1v1 courts: squeaks, swish and bounces only
	var pd = Game.profile.get("pending_drill", null)
	if pd is Dictionary and not pd.is_empty():
		drill_kind = String(pd.get("kind", drill_kind))
		lift_kind = String(pd.get("lift", lift_kind))
		machine_kind = String(pd.get("machine", machine_kind))
	# L'allenatore ti propone la sfida di persona, sotto forma di dialogo.
	CareerEvents.offer_if_pending_drill(self)
	var hud := CanvasLayer.new()
	hud.layer = 20
	add_child(hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	# Never cover the court/gym art with a HUD ColorRect — that was the solid
	# brown sheet. Clear-color only, so Node2D paint is visible.
	if drill_kind in ["weights", "cardio"]:
		RenderingServer.set_default_clear_color(Color(0.18, 0.19, 0.22))
	else:
		RenderingServer.set_default_clear_color(Color(0.14, 0.11, 0.09))

	lbl_top = Label.new()
	lbl_top.add_theme_font_size_override("font_size", 30)
	lbl_top.position = Vector2(40, 30)
	root.add_child(lbl_top)

	lbl_mid = Label.new()
	lbl_mid.add_theme_font_size_override("font_size", 46)
	lbl_mid.set_anchors_preset(Control.PRESET_CENTER)
	lbl_mid.position = Vector2(-250, -180)
	lbl_mid.custom_minimum_size = Vector2(500, 0)
	lbl_mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(lbl_mid)

	joystick = VirtualJoystick.new()
	joystick.set_anchors_preset(Control.PRESET_FULL_RECT)
	joystick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The joystick only listens on the LEFT half, so the drill's action button
	# on the right can never be swallowed by it.
	var left := Control.new()
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.anchor_right = 0.5
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(joystick)
	root.add_child(left)

	if drill_kind == "cardio":
		var hb := TouchButton.new()
		hb.text = Loc.tx("HOLD")
		hb.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		hb.position = Vector2(-220, -220)
		hb.custom_minimum_size = Vector2(180, 180)
		hb.size = Vector2(180, 180)
		hb.hold_mode = true
		hb.pressed_down.connect(_cardio_down)
		hb.released.connect(_cardio_up)
		root.add_child(hb)
	elif drill_kind in ["shooting", "freethrow"]:
		var hb := TouchButton.new()
		hb.text = Loc.tx("SHOOT")
		hb.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		hb.position = Vector2(-220, -220)
		hb.custom_minimum_size = Vector2(180, 180)
		hb.size = Vector2(180, 180)
		hb.hold_mode = true
		hb.pressed_down.connect(_shoot_down)
		hb.released.connect(_shoot_up)
		root.add_child(hb)
		shot_meter = ShotMeter.new()
		shot_meter.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		shot_meter.position = Vector2(-320, -360)
		# Same arc, same size as the street court and the scrimmage: the meter
		# is one piece of UI wherever it shows up.
		shot_meter.custom_minimum_size = Vector2(120, 78)
		shot_meter.size = Vector2(120, 78)
		shot_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shot_meter.visible = false
		root.add_child(shot_meter)
	else:
		var b := Button.new()
		b.text = {"handling": "TRICK", "defense": "CONTEST",
			"weights": "DRIVE"}.get(drill_kind, "GO")
		b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		b.position = Vector2(-220, -220)
		b.custom_minimum_size = Vector2(180, 180)
		b.pressed.connect(_action)
		root.add_child(b)

	var q := Button.new()
	q.text = Loc.tx("QUIT")
	q.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	q.position = Vector2(-160, 30)
	q.custom_minimum_size = Vector2(120, 70)
	q.pressed.connect(_leave_drill)
	root.add_child(q)

	if drill_kind != "weights" and drill_kind != "cardio":
		_build_shared_court()
	# Frame the court work exactly like the scrimmage: the full rectangle with
	# both baskets on screen. The weight room and cardio keep their close-up.
	var cam := get_node_or_null("Camera2D")
	if cam != null:
		if drill_kind in ["shooting", "freethrow", "handling", "defense"]:
			cam.position = Vector2(0.0, -40.0)
			cam.zoom = Vector2.ONE * 1.04
		else:
			cam.position = Vector2.ZERO
			cam.zoom = Vector2.ONE * 0.72
		cam.enabled = true
		cam.make_current()
	_setup()

## The match court, instantiated as scenery for the ball drills -- the SAME
## full rectangle the scrimmage plays on, both baskets and all the lines.
func _build_shared_court() -> void:
	court_art = preload("res://src/match/CourtVisual.tscn").instantiate()
	court_art.rim_height = DRILL_RIM_H
	court_art.z_index = -10
	add_child(court_art)
	court_art.position = Vector2.ZERO
	if court_art.has_method("apply_env"):
		court_art.apply_env("arena")
	else:
		court_art.env = "arena"
		court_art.queue_redraw()

## Court space -> the drill's flat drawing space: the same projection the
## CourtVisual uses, so a point ON the court draws ON the court.
func _drill_screen(court_pos: Vector2) -> Vector2:
	return CourtStage.m_project(court_pos, Court.COURT_H)

func _place_shot_meter() -> void:
	## The meter sits above the SHOOTER'S HEAD here too -- the same arc, in the
	## same place, as the street court and the scrimmage. It used to be pinned
	## to the bottom-right corner over the SHOOT button, so the eye had to
	## leave the player to read its own timing.
	if shot_meter == null:
		return
	var court_p: Vector2 = runner_pos
	if drill_kind != "shooting" and not spots.is_empty():
		court_p = spots[current_spot]
	var body: float = _court_body_h()
	var world: Vector2 = _drill_screen(court_p) - Vector2(0.0, body + 34.0)
	var vp: Vector2 = get_viewport_rect().size
	var scr: Vector2 = world
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		scr = (world - cam.position) * cam.zoom + vp * 0.5
	var msz: Vector2 = shot_meter.size
	var pos: Vector2 = scr - Vector2(msz.x * 0.5, msz.y)
	pos.x = clampf(pos.x, 8.0, maxf(vp.x - msz.x - 8.0, 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(vp.y - msz.y - 8.0, 8.0))
	shot_meter.position = pos

## Where the rim's centre and top edge sit in the drill's drawing space.
func _drill_rim() -> Vector2:
	var base: Vector2 = _drill_screen(Vector2(Court.COURT_W * 0.5 - Court.FIBA_HOOP_INSET, 0.0))
	return base + Vector2(0.0, -DRILL_RIM_H)

func _setup() -> void:
	time_left = 30.0
	match drill_kind:
		"shooting":
			# Logical spots, not a random scatter: real shot locations around
			# the right-hand basket (free-throw line, both wings at the arc,
			# both corners, a short-corner jumper and the top of the key). Each
			# one is a point ON the court, projected through the same tilt as
			# the shared CourtVisual, so the circles sit on the painted floor.
			var rim := Vector2(Court.COURT_W * 0.5 - Court.FIBA_HOOP_INSET, 0.0)
			var court_spots: Array = [
				rim + Vector2(-290.0, 0.0),     # free-throw line, straight on
				rim + Vector2(-298.0, 297.0),   # right wing, three
				rim + Vector2(-250.0, 390.0),   # right corner three
				rim + Vector2(-120.0, 260.0),   # right short corner (midrange)
				rim + Vector2(-298.0, -297.0),  # left wing, three
				rim + Vector2(-250.0, -390.0),  # left corner three
				rim + Vector2(-420.0, 0.0),     # top of the key, three
			]
			for p in court_spots:
				spots.append(p)
			runner_pos = court_spots[0]
			max_score = 12.0
		"handling":
			# A straight line of cones you weave through, alternating sides,
			# laid out across the full court rectangle.
			for i in 8:
				cones.append(Vector2(-620.0 + i * 160.0, 0.0))
			runner_pos = Vector2(-820.0, 0)
			hand_left = true
			max_score = 8.0
		"defense":
			attacker_x = 0.0
			defender_x = 0.0
			max_score = 45.0
		"freethrow":
			# A free-throw session: every shot from the same stripe, straight
			# on, uncontested. You keep the routine and the meter keeps its
			# ideal -- a make is a make, no close-out to beat.
			var rim := Vector2(Court.COURT_W * 0.5 - Court.FIBA_HOOP_INSET, 0.0)
			spots = [rim + Vector2(-290.0, 0.0)]
			runner_pos = spots[0]
			current_spot = 0
			meter_ideal = 0.5
			ghost_def = 0.0
			time_left = 30.0
			max_score = 10.0
		"cardio":
			time_left = 30.0
			effort = 0.35
			target = 0.5
			# The bike is a steady grind; the treadmill throws pace changes.
			band = 0.17 if machine_kind == "bike" else 0.13
			max_score = 1.0
		"weights":
			time_left = 30.0
			bar_t = 0.0
			bar_dir = 1.0
			# Each lift is a different rhythm problem, not just a reskin.
			match lift_kind:
				"squat":       max_score = 15.0   # slower, deeper, punishing
				"power_clean": max_score = 20.0   # fast tempo, tiny window
				"deadlift":    max_score = 18.0   # heavy pull off the floor
				"box_jump":    max_score = 20.0   # plyo: explode onto the box
				"med_slam":    max_score = 20.0   # plyo: explosive ball slam
				_:             max_score = 18.0   # bench

func _process(delta: float) -> void:
	if not running: return
	time_left -= delta
	if time_left <= 0.0:
		_finish()
		return
	match drill_kind:
		"shooting": _proc_shooting(delta)
		"freethrow": _proc_shooting(delta)
		"handling": _proc_handling(delta)
		"defense": _proc_defense(delta)
		"weights": _proc_weights(delta)
		"cardio": _proc_cardio(delta)
	cross_flash = maxf(cross_flash - delta * 3.0, 0.0)
	if drill_kind == "weights":
		lbl_top.text = Loc.tx("%s   %.1fs   reps %d   missed %d   combo x%d") % [
			lift_kind.to_upper().replace("_", " "), time_left, reps, bad_reps, combo]
	elif drill_kind == "cardio":
		var pct: int = int(100.0 * in_band_time / maxf(total_time, 0.001))
		lbl_top.text = Loc.tx("%s   %.1fs   in the zone %d%%") % [
			machine_kind.to_upper(), time_left, pct]
	else:
		lbl_top.text = Loc.tx("%s   %.1fs   score %.0f/%.0f   combo x%d") % [
			drill_kind.to_upper(), time_left, score, max_score, combo]
	_follow_cam(delta)
	queue_redraw()

func _follow_cam(delta: float) -> void:
	var cam := get_node_or_null("Camera2D")
	if cam == null:
		return
	if drill_kind in ["weights", "cardio"]:
		cam.position = Vector2.ZERO
		return
	var court_p := Vector2.ZERO
	match drill_kind:
		"shooting", "handling":
			court_p = runner_pos
		"freethrow":
			court_p = spots[current_spot] if not spots.is_empty() else Vector2.ZERO
		"defense":
			court_p = Vector2(defender_x, 60.0)
	var want_x: float = CourtStage.m_project(court_p, Court.COURT_H).x
	var half_view: float = get_viewport_rect().size.x * 0.5 / 1.04
	var floor_x: float = CourtStage.m_project(Vector2(Court.COURT_W * 0.5, 0.0), Court.COURT_H).x
	var limit: float = maxf(floor_x - half_view + 160.0, 80.0)
	want_x = clampf(want_x, -limit, limit)
	cam.position.x = lerpf(cam.position.x, want_x, clampf(4.0 * delta, 0.0, 1.0))
	cam.position.y = -40.0
	cam.zoom = Vector2.ONE * 1.04

# ------------------------------------------------------------------ cardio
## Hold your effort inside the moving target band. Tapping HOLD raises effort;
## releasing lets it fall. The band drifts (bike) or jumps (treadmill), so you
## have to keep adjusting instead of holding one button down.
func _proc_cardio(delta: float) -> void:
	total_time += delta
	cadence += delta * (2.0 + effort * 9.0)

	# effort responds to the button, and always decays
	if pushing:
		effort = minf(effort + delta * 0.62, 1.0)
	else:
		effort = maxf(effort - delta * 0.48, 0.0)

	# the target moves
	if machine_kind == "bike":
		# a long, slow swell: a steady endurance effort
		target = 0.52 + sin(total_time * 0.55) * 0.26
	else:
		# interval training: the pace steps up and down without warning
		var step: int = int(total_time / 5.0)
		var seedv: float = fmod(float(step) * 12.9898, 1.0)
		target = 0.34 + fmod(seedv * 43758.5453, 1.0) * 0.52
		target = clampf(target, 0.20, 0.88)

	if absf(effort - target) <= band:
		in_band_time += delta
		combo = mini(combo + 1, 999)
		if lbl_mid:
			lbl_mid.text = ""
	else:
		combo = 0
		if lbl_mid:
			lbl_mid.text = Loc.tx("PUSH HARDER") if effort < target else Loc.tx("EASE OFF")
			lbl_mid.modulate = Color(1.0, 0.62, 0.35)
	# score is simply the share of the session spent in the zone
	score = in_band_time

func _cardio_down() -> void:
	pushing = true

func _cardio_up() -> void:
	pushing = false

# ---------------------------------------------------------------- shooting
func _proc_shooting(delta: float) -> void:
	dribble_t += delta * 4.2
	net_t += delta
	net_wobble = HoopArt.decay(net_wobble, delta)
	if shot_anim > 0.0 or ball_live:
		shot_anim += delta
		_step_drill_ball(delta)
		return
	if drill_kind == "shooting":
		var mv: Vector2 = joystick.output
		runner_pos += mv * 255.0 * delta
		runner_pos.x = clampf(runner_pos.x, -Court.COURT_W * 0.5 + 40.0, Court.COURT_W * 0.5 - 40.0)
		runner_pos.y = clampf(runner_pos.y, -Court.COURT_H * 0.5 + 40.0, Court.COURT_H * 0.5 - 40.0)
		if mv.length() > 0.12:
			dribble_t += delta * 4.2
		ghost_def = 0.0
	if charging:
		charge = minf(charge + delta, 1.4)
		if shot_meter:
			shot_meter.visible = true
			shot_meter.charge = charge
			shot_meter.ideal = 0.6
			_place_shot_meter()
		if charge >= 1.4:
			_shoot_up()

func _next_spot() -> void:
	if spots.is_empty():
		return
	current_spot = (current_spot + 1) % spots.size()
	meter = 0.0
	meter_dir = 1.0
	# A free throw is the same routine every time: the ideal never wanders.
	meter_ideal = 0.5 if drill_kind == "freethrow" else randf_range(0.42, 0.68)
	ghost_def = 0.0

func _on_spot() -> bool:
	if spots.is_empty():
		return false
	return runner_pos.distance_to(spots[current_spot]) < 42.0

func _shoot_down() -> void:
	if shot_anim > 0.0:
		return
	if drill_kind == "shooting" and not _on_spot():
		lbl_mid.text = Loc.tx("WALK ONTO THE CIRCLE")
		lbl_mid.modulate = Color(1.0, 0.75, 0.30)
		return
	charging = true
	charge = 0.0
	if shot_meter:
		shot_meter.visible = true
		shot_meter.frozen = false
		shot_meter.charge = 0.0
		_place_shot_meter()

func _shoot_up() -> void:
	if not charging:
		return
	charging = false
	_shoot_release()

func _shoot_release() -> void:
	if shot_anim > 0.0:
		return
	if drill_kind == "shooting" and not _on_spot():
		lbl_mid.text = Loc.tx("WALK ONTO THE CIRCLE")
		lbl_mid.modulate = Color(1.0, 0.75, 0.30)
		return
	var err := absf(charge - 0.6)
	if shot_meter:
		var qn := "MISS"
		var qc := Color(1.0, 0.4, 0.3)
		if err < 0.06:
			qn = "PERFECT"; qc = Color(0.3, 1.0, 0.4)
		elif err < 0.14:
			qn = "GOOD"; qc = Color(0.85, 0.95, 0.3)
		shot_meter.show_release(qn, qc)
	# Stessa regola del meter: PERFECT 100%, GOOD 50/50, oltre = MAI.
	var made := false
	if err < 0.06:
		made = true
	elif err < 0.14:
		made = randf() < 0.5
	if made:
		combo += 1
		score += 1.0 + minf(combo, 5) * 0.15
		if err < 0.06:
			CareerEvents.on_drill_perfect()
		lbl_mid.text = (Loc.tx("PERFECT!") if err < 0.06 else Loc.tx("SWISH")) + "  x%d" % combo
	else:
		combo = 0
		score = maxf(0.0, score - 0.2)
		lbl_mid.text = Loc.tx("MISS")
	# Kick off the shot animation; the next spot is set when it finishes.
	shot_made = made
	shot_anim = 0.001
	Sfx.play("shot_release", -5.0)
	var from_c: Vector2 = runner_pos if drill_kind == "shooting" else spots[current_spot]
	var rim_c := Vector2(Court.COURT_W * 0.5 - Court.FIBA_HOOP_INSET, 0.0)
	# Aim coerente: canestro -> cade dentro; mancanza -> ferro ed esce
	# (44-52 px: nel ramo clang, fuori dal raggio swish) o airball se rosso.
	var aim: Vector2
	if made:
		aim = rim_c + Vector2(randf_range(-12, 12), randf_range(-6, 6))
	elif err < 0.14:
		var dir_c: Vector2 = (rim_c - from_c).normalized()
		if dir_c.length() < 0.1:
			dir_c = Vector2(1, 0)
		aim = rim_c + dir_c * randf_range(44.0, 52.0)
	else:
		var dir_c2: Vector2 = (from_c - rim_c).normalized()
		if dir_c2.length() < 0.1:
			dir_c2 = Vector2(1, 0)
		aim = rim_c + dir_c2 * randf_range(66.0, 110.0)
	_launch_drill_ball(from_c, aim)

func _launch_drill_ball(from: Vector2, aim: Vector2) -> void:
	ball_live = true
	ball_rattled = false
	ball_court = from
	ball_h = 55.0
	ball_prev = from
	ball_prev_h = ball_h
	var to: Vector2 = aim - from
	var flight: float = clampf(0.55 + to.length() / Court.PX_PER_FT * 0.022, 0.55, 1.25)
	ball_v = to / flight
	ball_vh = (DRILL_RIM_H - ball_h + 0.5 * DRILL_GRAV * flight * flight) / flight

func _step_drill_ball(delta: float) -> void:
	if not ball_live:
		return
	var h: float = delta
	ball_prev = ball_court
	ball_prev_h = ball_h
	ball_vh -= DRILL_GRAV * h
	ball_h += ball_vh * h
	ball_court += ball_v * h
	var rim_c := Vector2(Court.COURT_W * 0.5 - Court.FIBA_HOOP_INSET, 0.0)
	if ball_h <= DRILL_RIM_H and ball_prev_h >= DRILL_RIM_H and ball_vh < 0.0:
		var span: float = ball_prev_h - ball_h
		var f: float = 0.0 if span <= 0.0 else (ball_prev_h - DRILL_RIM_H) / span
		var cx: float = lerpf(ball_prev.x, ball_court.x, clampf(f, 0.0, 1.0))
		var cy: float = lerpf(ball_prev.y, ball_court.y, clampf(f, 0.0, 1.0))
		var dist: float = Vector2(cx, cy).distance_to(rim_c)
		if dist < DRILL_RIM_HALF - 6.0 or (ball_rattled and dist < DRILL_RIM_HALF + 6.0):
			# RIM-RATTLE anche in palestra: il drill ha un motore di tiro
			# separato da Court, quindi prima non poteva MAI uscire qui.
			if not ball_rattled and randf() < 0.30:
				ball_rattled = true
				ball_court = rim_c + (Vector2(cx, cy) - rim_c).normalized() * 9.0
				ball_vh = sqrt(2.0 * DRILL_GRAV * randf_range(60.0, 90.0))
				ball_v = Vector2(randf_range(-25, 25), randf_range(-25, 25))
				Sfx.play("rim", -0.5, randf_range(0.95, 1.08))
				net_wobble = 0.9
				if court_art and court_art.has_method("rim_fx"):
					court_art.rim_fx("rattle", rim_c)
				if court_art and court_art.has_method("net_bump"):
					court_art.net_bump(1, 0.9)
				return
			net_wobble = 1.0
			Sfx.play("swish", -3.0, randf_range(0.94, 1.04))
			Sfx.haptic(35)
			if court_art and court_art.has_method("net_bump"):
				court_art.net_bump(1, 1.0)
			ball_court = rim_c
			ball_v = Vector2.ZERO
			ball_vh = -80.0
		elif dist < DRILL_RIM_HALF + 14.0:
			Sfx.play("rim", -6.0)
			net_wobble = 0.85
			var nrm: Vector2 = (Vector2(cx, cy) - rim_c).normalized()
			if nrm.length() < 0.1:
				nrm = Vector2(1, 0)
			ball_court = rim_c + nrm * (DRILL_RIM_HALF + 12.0)
			ball_vh = absf(ball_vh) * 0.35
			ball_v = ball_v.bounce(nrm) * 0.55
	if ball_h <= 0.0:
		ball_h = 0.0
		ball_live = false
		shot_anim = 0.0
		_next_spot()

# ---------------------------------------------------------------- handling
## Cone slalom, rebuilt. The old version was nonsense: you scored by pressing a
## button while merely standing NEAR a cone, and the cone was consumed whether
## you had dribbled round it or run straight through it.
##
## Now it is a real slalom. You must physically pass each cone on the correct
## SIDE -- alternating left, right, left -- and change hands as you go. Passing
## on the wrong side, or clipping the cone, costs you. Nothing is scored by
## standing still.
func _proc_handling(delta: float) -> void:
	var mv: Vector2 = joystick.output
	runner_pos += mv * 330.0 * delta
	runner_pos.x = clampf(runner_pos.x, -Court.COURT_W * 0.5 + 60.0, Court.COURT_W * 0.5 - 60.0)
	runner_pos.y = clampf(runner_pos.y, -Court.COURT_H * 0.5 + 60.0, Court.COURT_H * 0.5 - 60.0)
	if mv.length() > 0.1:
		dribble_phase += delta * (6.0 + mv.length() * 5.0)

	if cone_index >= cones.size():
		return
	var cone: Vector2 = cones[cone_index]
	# Which side must this one be taken on? Alternating, starting left.
	var want_left: bool = (cone_index % 2) == 0
	var dx: float = runner_pos.x - cone.x
	var dy: float = runner_pos.y - cone.y

	# clipped it
	if absf(dx) < 24.0 and absf(dy) < 30.0:
		combo = 0
		score = maxf(0.0, score - 0.5)
		lbl_mid.text = Loc.tx("CLIPPED THE CONE")
		lbl_mid.modulate = Color(1.0, 0.45, 0.4)
		cone_index += 1
		hand_left = not hand_left
		return

	# passed it: judge the side we went round and the hand we used
	if dx > 30.0:
		var side_left: bool = dy < 0.0
		if side_left == want_left:
			if hand_left == want_left:
				# right side AND the correct hand protecting the ball
				combo += 1
				score += 1.0
				lbl_mid.text = Loc.tx("CLEAN x%d") % combo
				lbl_mid.modulate = Color(0.45, 1.0, 0.55)
			else:
				score += 0.4
				combo = 0
				lbl_mid.text = Loc.tx("WRONG HAND")
				lbl_mid.modulate = Color(1.0, 0.85, 0.35)
		else:
			combo = 0
			lbl_mid.text = Loc.tx("WRONG SIDE")
			lbl_mid.modulate = Color(1.0, 0.45, 0.4)
		cone_index += 1

	window_open = absf(dx) < 150.0

## The action button is the crossover: it switches the dribbling hand.
func _handling_move() -> void:
	hand_left = not hand_left
	cross_flash = 1.0
	lbl_mid.text = Loc.tx("CROSSOVER")
	lbl_mid.modulate = Color(0.6, 0.85, 1.0)

# ---------------------------------------------------------------- defense
func _proc_defense(delta: float) -> void:
	if randf() < delta * 1.4:
		attacker_target = randf_range(-420, 420)
	attacker_x = move_toward(attacker_x, attacker_target, 320.0 * delta)
	defender_x += joystick.output.x * 300.0 * delta
	defender_x = clampf(defender_x, -520, 520)
	var gap := absf(defender_x - attacker_x)
	if gap < 60.0:
		score += delta * (1.0 - gap / 60.0) * 2.0
		hold_quality = 1.0 - gap / 60.0
		lbl_mid.text = Loc.tx("ON THE HIP")
	else:
		hold_quality = 0.0
		lbl_mid.text = Loc.tx("BEATEN") if gap > 160 else ""
	contest_ready = gap < 80.0

func _defense_contest() -> void:
	if contest_ready:
		score += 3.0
		combo += 1
		lbl_mid.text = "x%d" % combo
	else:
		score = maxf(0.0, score - 1.0)
		combo = 0
		lbl_mid.text = Loc.tx("AIR SWIPE")

# ---------------------------------------------------------------- weights
## Drive zone: the window near the bottom of the rep where pressing actually
## moves the bar. It shrinks as fatigue builds, so the last reps are the test.
func _drive_zone() -> float:
	var base: float = {"squat": 0.28, "power_clean": 0.24, "deadlift": 0.26,
		"box_jump": 0.34, "med_slam": 0.32}.get(lift_kind, 0.30)
	var tight: float = {"squat": 0.13, "power_clean": 0.11, "deadlift": 0.13,
		"box_jump": 0.20, "med_slam": 0.18}.get(lift_kind, 0.13)
	return lerpf(base, tight, fatigue)

func _proc_weights(delta: float) -> void:
	# The bar descends on its own; fatigue slows the whole tempo, which is what
	# makes late reps harder to time rather than merely slower.
	var fast: float = {"squat": 0.72, "power_clean": 1.10, "deadlift": 0.70,
		"box_jump": 0.80, "med_slam": 0.85}.get(lift_kind, 0.95)
	var slow: float = {"squat": 0.48, "power_clean": 0.72, "deadlift": 0.46,
		"box_jump": 0.55, "med_slam": 0.58}.get(lift_kind, 0.62)
	var tempo: float = lerpf(fast, slow, fatigue)
	bar_t += bar_dir * delta * tempo
	if bar_t >= 1.0:
		bar_t = 1.0
		bar_dir = -1.0
		# reached the chest without a drive -> the rep stalls out
		if not _in_drive_zone():
			pass
	elif bar_t <= 0.0:
		bar_t = 0.0
		bar_dir = 1.0
	rep_flash = maxf(0.0, rep_flash - delta * 2.5)
	# recovering between reps slowly bleeds fatigue back
	fatigue = clampf(fatigue - delta * 0.02, 0.0, 1.0)

func _in_drive_zone() -> bool:
	return bar_t >= 1.0 - _drive_zone()

func _weights_press() -> void:
	if _in_drive_zone() and bar_dir > 0.0:
		# clean rep: closer to the very bottom = better form = more credit
		var depth: float = (bar_t - (1.0 - _drive_zone())) / maxf(_drive_zone(), 0.001)
		reps += 1
		combo += 1
		# La fatica lascia il segno: il fisico cresce di poco a ogni ripetuta
		# e si vede su spalle/braccia del personaggio (Avatar cols["muscle"]).
		Game.profile["muscle"] = clampf(float(Game.profile.get("muscle", 0.0)) + 0.004, 0.0, 1.0)
		var quality: float = 0.6 + depth * 0.4
		score += quality * (1.0 + minf(combo, 6) * 0.08)
		fatigue = clampf(fatigue + 0.055, 0.0, 1.0)
		bar_dir = -1.0
		rep_flash = 1.0
		lbl_mid.text = (Loc.tx("DEEP REP!") if depth > 0.65 else Loc.tx("GOOD REP")) + "  x%d" % combo
	else:
		bad_reps += 1
		combo = 0
		score = maxf(0.0, score - 0.4)
		fatigue = clampf(fatigue + 0.03, 0.0, 1.0)
		lbl_mid.text = Loc.tx("TOO HIGH - let it come down") if bar_t < 0.5 else Loc.tx("FORM BREAK")

# ---------------------------------------------------------------- shell
func _action() -> void:
	match drill_kind:
		"shooting": _shoot_release()
		"freethrow": _shoot_release()
		"handling": _handling_move()
		"defense": _defense_contest()
		"weights": _weights_press()

func _finish() -> void:
	running = false
	var s01: float
	if drill_kind == "cardio":
		# Share of the session spent inside the target band.
		s01 = clampf(in_band_time / maxf(total_time, 0.001), 0.0, 1.2)
	else:
		s01 = clampf(score / max_score, 0.0, 1.2)
	Career.apply_drill_result(drill_kind, s01)
	lbl_mid.text = Loc.tx("GRADE %s") % Career.grade_from_score(s01)
	await get_tree().create_timer(2.0).timeout
	_leave_drill()

func _leave_drill() -> void:
	running = false
	var back: String = "res://src/scenes/GymScene.tscn"
	var pd = Game.profile.get("pending_drill", null)
	if pd is Dictionary:
		back = String(pd.get("return", back))
	Game.profile.erase("pending_drill")
	if drill_kind in ["shooting", "handling", "defense", "freethrow"]:
		back = "res://src/scenes/TeamCourt.tscn"
	SceneRouter.goto(back)

func _draw() -> void:
	if drill_kind == "weights":
		# rubber gym floor, not a hardwood court
		draw_rect(Rect2(-900, -320, 1800, 640), Color(0.20, 0.21, 0.25))
		draw_rect(Rect2(-900, 120, 1800, 200), Color(0.16, 0.17, 0.21))
		_draw_weights()
		return
	if drill_kind == "cardio":
		draw_rect(Rect2(-900, -320, 1800, 640), Color(0.20, 0.21, 0.25))
		draw_rect(Rect2(-900, 120, 1800, 200), Color(0.16, 0.17, 0.21))
		_draw_cardio()
		return
	# Ball work happens on THE court. The floor itself is drawn by the shared
	# CourtVisual built in _ready(), so a drill is played on exactly the same
	# horizontal court as a scrimmage.
	pass
	match drill_kind:
		"shooting", "freethrow":
			# One live circle. Walk onto it (green) before you can shoot.
			if not spots.is_empty():
				var sc: Vector2 = _drill_screen(spots[current_spot])
				var on: bool = drill_kind != "shooting" or _on_spot()
				var col: Color = Color(0.25, 0.95, 0.40) if on else Color(1.0, 0.88, 0.20)
				draw_arc(sc, 28, 0, TAU, 24, col, 4)
				draw_circle(sc, 22, Color(col.r, col.g, col.b, 0.18 if on else 0.08))
			_draw_shooter()
		"handling":
			for i in cones.size():
				var done: bool = i < cone_index
				var col: Color = Color(0.38, 0.38, 0.40) if done else Color(1, 0.55, 0.1)
				var sc: Vector2 = _drill_screen(cones[i])
				draw_colored_polygon(PackedVector2Array([
					sc + Vector2(-22, 22), sc + Vector2(22, 22),
					sc + Vector2(0, -33)]), col)
				if not done:
					# Show which side this cone must be taken on: a lit gate.
					var want_left: bool = (i % 2) == 0
					var gy: float = -104.0 if want_left else 104.0
					var glow: float = 0.65 if i == cone_index else 0.22
					draw_line(sc + Vector2(0, gy * 0.35),
						sc + Vector2(0, gy), Color(0.35, 1.0, 0.55, glow), 5.0)
					draw_circle(sc + Vector2(0, gy), 18.0,
						Color(0.35, 1.0, 0.55, glow))
			# which hand the ball is in, so the crossover is readable
			var f := ThemeDB.fallback_font
			draw_string(f, Vector2(-820, -290),
				"BALL IN %s HAND" % (Loc.tx("LEFT") if hand_left else Loc.tx("RIGHT")),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
				Color(0.6, 0.85, 1.0).lerp(Color(1, 1, 1), cross_flash))
			var rs: Vector2 = _drill_screen(runner_pos)
			_draw_dribbler(rs)
		"defense":
			var att_s: Vector2 = _drill_screen(Vector2(attacker_x, -60))
			var def_s: Vector2 = _drill_screen(Vector2(defender_x, 60))
			_draw_stick(att_s, Color(0.85, 0.3, 0.3), true)
			_draw_stick(def_s, Color(0.3, 0.7, 1.0), false)
			draw_line(def_s, att_s,
				Color(0.3, 1, 0.5, 0.6) if hold_quality > 0 else Color(1, 0.3, 0.3, 0.4), 3)

## The player character in the shooting drill: dips into the shot as the meter
## charges, extends on release, then holds the follow-through. The ball leaves
## his hand and arcs to the rim.
func _draw_shooter() -> void:
	## Shared avatar, so the man in the gym is the man in the city.
	var court_p: Vector2 = runner_pos if drill_kind == "shooting" else spots[current_spot]
	var base: Vector2 = _drill_screen(court_p)
	var amount: float = 0.0
	var kind: String = Avatar.IDLE
	if shot_anim > 0.0:
		amount = clampf(shot_anim / 0.22, 0.0, 1.0)
		kind = Avatar.SHOOT
	elif drill_kind == "shooting" and joystick.output.length() > 0.12:
		kind = Avatar.RUN
	else:
		amount = 1.0 - clampf(meter, 0.0, 1.0) * 0.8
		kind = Avatar.SHOOT if drill_kind == "freethrow" else Avatar.IDLE
	var hh: float = _court_body_h() * (1.08 if shot_anim > 0.0 else 1.0)
	var lc: Dictionary = Avatar.colours(true)
	lc["muscle"] = float(Game.profile.get("muscle", 0.0))
	lc["hst"] = Game.hair_style()
	Avatar.draw_body(self, base, hh, 1.0,
		Avatar.pose(kind, dribble_t, amount),
		lc, shot_anim <= 0.0 and not ball_live, true, true, DRILL_BALL_R)

	if ball_live:
		var p: Vector2 = _drill_screen(ball_court) + Vector2(0.0, -ball_h)
		draw_circle(p, DRILL_BALL_R, Color(0.95, 0.55, 0.15))
		draw_arc(p, DRILL_BALL_R, 0, TAU, 14, Color(0.35, 0.18, 0.07), 2)
		if ball_h < DRILL_RIM_H + 20.0 and ball_court.distance_to(Vector2(Court.COURT_W * 0.5 - Court.FIBA_HOOP_INSET, 0.0)) < 70.0:
			HoopArt.draw_net_front(self, _drill_rim(), 22.0, 22.0 * HoopArt.RIM_SQUASH,
				net_wobble, net_t)

## Dribbling drill avatar: legs cycle while moving and the ball actually
## bounces off the floor beside him.
func _draw_dribbler(pos: Vector2) -> void:
	var facing: float = signf(joystick.output.x) if absf(joystick.output.x) > 0.1 else 1.0
	var moving: bool = joystick.output.length() > 0.1
	# The ball is drawn by the caller on the hand that is actually dribbling,
	# so the avatar itself carries no ball here (no doubled-up basketballs).
	Avatar.draw_body(self, pos, _court_body_h(), facing,
		Avatar.pose(Avatar.DRIBBLE if moving else Avatar.DRIBBLE, dribble_t, 0.0, "", moving),
		Avatar.colours(true), true, true, true, DRILL_BALL_R)

## Defence drill figures. The defender sits in a wide stance with arms out,
## the attacker carries the ball -- readable at a glance instead of two discs.
func _draw_stick(pos: Vector2, col: Color, is_attacker: bool) -> void:
	## Attacker carries the ball; defender sits in a stance with active hands.
	var cols: Dictionary = Avatar.colours(is_attacker, col)
	if not is_attacker:
		cols["jersey"] = col
	var facing: float = 1.0
	var po: Dictionary = Avatar.pose(Avatar.DRIBBLE if is_attacker else Avatar.DEFEND, dribble_t, 0.0, "", true)
	if not is_attacker and joystick != null and joystick.output.y < -0.22:
		po["back"] = true
	Avatar.draw_body(self, pos, _court_body_h(), facing, po,
		cols, is_attacker, true, true, DRILL_BALL_R)

func _ell(c: Vector2, r: Vector2) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		p.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return p

## Side view of a bench press. The bar's vertical travel IS the timing meter,
## so the player reads the game state from the lift itself rather than from a
## separate abstract bar somewhere else on screen.
## Exercise bike / treadmill, plus the effort bar you are trying to hold inside
## the moving target band.
func _draw_cardio() -> void:
	var f := ThemeDB.fallback_font
	var base := Vector2(-120.0, 80.0)
	var col := Color(0.62, 0.65, 0.72)
	var dark := Color(0.24, 0.26, 0.32)

	if machine_kind == "bike":
		# frame
		draw_line(base + Vector2(-90, 60), base + Vector2(-40, -60), dark, 14.0)
		draw_line(base + Vector2(-40, -60), base + Vector2(80, -30), dark, 14.0)
		draw_line(base + Vector2(-40, -60), base + Vector2(-10, 40), dark, 12.0)
		draw_rect(Rect2(base + Vector2(-130, 58), Vector2(210, 16)), dark)
		# saddle + bars
		draw_rect(Rect2(base + Vector2(-70, -76), Vector2(64, 18)), col)
		draw_line(base + Vector2(80, -30), base + Vector2(80, -108), dark, 12.0)
		draw_line(base + Vector2(52, -108), base + Vector2(108, -108), col, 10.0)
		# flywheel, spinning with cadence
		var wheel := base + Vector2(-10, 40)
		draw_circle(wheel, 46.0, dark)
		draw_circle(wheel, 38.0, Color(0.34, 0.36, 0.44))
		for k in 6:
			var a: float = cadence + TAU * float(k) / 6.0
			draw_line(wheel, wheel + Vector2(cos(a), sin(a)) * 36.0, col, 3.0)
		# rider
		var pedal := wheel + Vector2(cos(cadence), sin(cadence)) * 22.0
		_draw_cardio_rider(base + Vector2(-38, -78), pedal, base + Vector2(80, -108))
	else:
		# treadmill: deck, uprights, console, scrolling belt
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-150, 70), base + Vector2(150, 70),
			base + Vector2(120, 40), base + Vector2(-120, 40)]), dark)
		var belt_y: float = 55.0
		for k in 14:
			var bx: float = fmod(float(k) * 40.0 - fmod(cadence * 60.0, 40.0), 280.0)
			draw_line(base + Vector2(-140 + bx, belt_y - 8),
				base + Vector2(-140 + bx, belt_y + 8), Color(0.16, 0.17, 00.17, 0.21), 3.0)
		draw_line(base + Vector2(-120, 40), base + Vector2(-140, -90), dark, 12.0)
		draw_rect(Rect2(base + Vector2(-190, -120), Vector2(110, 34)), Color(0.18, 0.20, 0.26))
		draw_rect(Rect2(base + Vector2(-190, -120), Vector2(110 * effort, 34)),
			Color(0.30, 0.75, 0.95, 0.8))
		Avatar.draw_body(self, base + Vector2(20, 70), 150.0, 1.0,
			Avatar.pose(Avatar.RUN, cadence), Avatar.colours(true), false, true, true)

	# ---- effort bar with the moving target band
	var bar := Rect2(-360, -250, 720, 46)
	draw_rect(bar, Color(0.10, 0.11, 0.15))
	# the band you must sit inside
	var b0: float = clampf(target - band, 0.0, 1.0)
	var b1: float = clampf(target + band, 0.0, 1.0)
	draw_rect(Rect2(bar.position.x + bar.size.x * b0, bar.position.y,
		bar.size.x * (b1 - b0), bar.size.y), Color(0.25, 0.85, 0.40, 0.55))
	# your current effort
	var inb: bool = absf(effort - target) <= band
	draw_rect(Rect2(bar.position.x + bar.size.x * effort - 7.0, bar.position.y - 8.0,
		14.0, bar.size.y + 16.0),
		Color(0.45, 1.0, 0.55) if inb else Color(1.0, 0.55, 0.35))
	draw_rect(bar, Color(1, 1, 1, 0.30), false, 3.0)
	draw_string(f, Vector2(bar.position.x, bar.position.y - 18.0),
		"HOLD to push  ·  stay in the green", HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
		Color(1, 1, 1, 0.65))

func _draw_cardio_rider(hip: Vector2, foot: Vector2, hands: Vector2) -> void:
	var skin := Game.skin_color()
	var cols: Dictionary = Avatar.colours(true)
	var kit: Color = cols["jersey"]
	var hair: Color = cols["hair"]
	var knee: Vector2 = hip.lerp(foot, 0.5) + Vector2(26, -6)
	draw_line(hip, knee, kit, 11.0)
	draw_line(knee, foot, skin, 9.0)
	draw_line(hip, hip + Vector2(6, -46), kit, 15.0)
	var sh := hip + Vector2(6, -46)
	draw_line(sh, hands, skin, 8.0)
	var head_c := sh + Vector2(10, -20)
	draw_circle(head_c, 16.0, skin)
	draw_arc(head_c, 16.0, PI, TAU, 16, hair, 16.0 * 0.62)
	Avatar.draw_accessories(self, head_c, 16.0, 1.0, false)

func _draw_cardio_runner(feet: Vector2, stride: float) -> void:
	var skin := Game.skin_color()
	var cols: Dictionary = Avatar.colours(true)
	var kit: Color = cols["jersey"]
	var hair: Color = cols["hair"]
	var hip := feet + Vector2(0, -74)
	draw_line(hip, feet + Vector2(stride, 0), kit, 11.0)
	draw_line(hip, feet + Vector2(-stride * 0.8, -8), skin, 10.0)
	draw_line(hip, hip + Vector2(0, -46), kit, 16.0)
	var sh := hip + Vector2(0, -46)
	draw_line(sh, sh + Vector2(-stride * 0.7, 24), skin, 8.0)
	draw_line(sh, sh + Vector2(stride * 0.7, 24), skin, 8.0)
	var head_c := sh + Vector2(0, -20)
	draw_circle(head_c, 17.0, skin)
	draw_arc(head_c, 17.0, PI, TAU, 16, hair, 17.0 * 0.62)
	Avatar.draw_accessories(self, head_c, 17.0, 1.0, false)

func _draw_weights() -> void:
	## Each lift gets its OWN animation. This used to always draw a bench press
	## no matter which exercise you picked, so squat and power clean looked
	## identical to bench even though their timing already differed.
	match lift_kind:
		"squat":
			_draw_squat()
		"power_clean":
			_draw_power_clean()
		"deadlift":
			_draw_deadlift()
		"box_jump":
			_draw_box_jump()
		"med_slam":
			_draw_med_slam()
		_:
			_draw_bench()
	_draw_timing_bar()
	_draw_fatigue_bar()

## Barra di timing in basso: vedi la ZONA giusta (verde) e il cursore della
## barra scendere. Premere dentro il verde = ripetizione pulita. Niente piu'
## click a caso nella pliometria.
func _draw_timing_bar() -> void:
	var track := Rect2(-260, 250, 520, 18)
	draw_rect(track, Color(0, 0, 0, 0.55))
	var zone := _drive_zone()
	var zx := track.position.x + track.size.x * (1.0 - zone)
	var zr := Rect2(zx, track.position.y, track.size.x * zone, track.size.y)
	var pulse := 0.55 + 0.25 * sin(Time.get_ticks_msec() / 90.0) if _in_drive_zone() else 0.38
	draw_rect(zr, Color(0.40, 0.95, 0.45, pulse))
	var cx: float = track.position.x + track.size.x * clampf(bar_t, 0.0, 1.0)
	draw_rect(Rect2(cx - 4, track.position.y - 6, 8, track.size.y + 12), Color(1, 1, 1, 0.95))
	draw_rect(track, Color(1, 1, 1, 0.35), false, 2)

## Common furniture: the fatigue read-out shared by all three lifts.
func _draw_fatigue_bar() -> void:
	draw_rect(Rect2(-330, -290, 660, 24), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(-330, -290, 660 * fatigue, 24),
		Color(0.95, 0.72, 0.20).lerp(Color(0.95, 0.25, 0.20), fatigue))
	draw_rect(Rect2(-330, -290, 660, 24), Color(1, 1, 1, 0.30), false, 2)
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(-330, -300), "FATIGUE  (zone shrinks as you tire)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(1, 1, 1, 0.75))
	draw_string(f, Vector2(-330, -320),
		{"squat": "BACK SQUAT", "power_clean": "POWER CLEAN",
		"deadlift": "DEADLIFT", "box_jump": "BOX JUMP",
		"med_slam": "MED BALL SLAM"}.get(lift_kind, "BENCH PRESS"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.88, 0.45))

## Draws a loaded barbell centred on `y`, spanning `half` either side.
func _draw_barbell(y: float, half: float, flash: float, plate_r := 58.0) -> void:
	var bar_col := Color(0.78, 0.80, 0.85).lerp(Color(0.5, 1.0, 0.6), flash)
	draw_rect(Rect2(-half - 90.0, y - 7, (half + 90.0) * 2.0, 14), bar_col)
	for sx in [-half + 24.0, -half + 66.0, half - 66.0, half - 24.0]:
		draw_rect(Rect2(sx - 14, y - plate_r, 28, plate_r * 2.0), Color(0.15, 0.16, 0.20))
		draw_rect(Rect2(sx - 14, y - plate_r, 28, plate_r * 2.0), Color(0.48, 0.50, 0.58), false, 2)
	for sx in [-half + 88.0, half - 88.0]:
		draw_rect(Rect2(sx - 7, y - 20, 14, 40), Color(0.55, 0.57, 0.64))

## Green band showing where on the bar's travel a press actually counts.
func _draw_zone(from_y: float, to_y: float, x_half: float) -> void:
	var zone := _drive_zone()
	var zone_edge: float = lerpf(from_y, to_y, 1.0 - zone)
	var good: bool = _in_drive_zone() and bar_dir > 0.0
	draw_rect(Rect2(-x_half, minf(zone_edge, to_y), x_half * 2.0, absf(to_y - zone_edge)),
		Color(0.25, 0.85, 0.40, 0.34 if good else 0.16))
	draw_line(Vector2(-x_half, zone_edge), Vector2(x_half, zone_edge),
		Color(0.35, 1.0, 0.5, 0.9), 3)

# ------------------------------------------------------------------ BENCH
## Side view of a bench press: the bar travels down to the chest and you drive
## it back up. bar_t 0 = racked, 1 = at the chest.
func _draw_bench() -> void:
	var bench_y := 150.0
	var chest_y := 40.0
	var top_y := -190.0

	# rack uprights, set OUTSIDE the plate line so the bar reads clearly
	for sx in [-430.0, 430.0]:
		draw_rect(Rect2(sx - 15, top_y - 50, 30, bench_y + 70 - top_y), Color(0.30, 0.10, 0.12))
		draw_rect(Rect2(sx - 30, top_y - 56, 60, 18), Color(0.42, 0.14, 0.16))
		# rack hooks
		draw_rect(Rect2(sx - 34, top_y - 6, 26, 12), Color(0.38, 0.13, 0.15))

	# bench pad + upright post under it
	draw_rect(Rect2(-190, bench_y, 380, 30), Color(0.13, 0.14, 0.18))
	draw_rect(Rect2(-190, bench_y, 380, 8), Color(0.22, 0.24, 0.30))
	draw_rect(Rect2(-24, bench_y + 30, 48, 96), Color(0.10, 0.11, 0.14))
	draw_rect(Rect2(-70, bench_y + 120, 140, 12), Color(0.16, 0.17, 0.21))

	# --- lifter, animated. The chest rises to meet the bar and the whole body
	# strains at the bottom of the rep, so you can read the effort from the
	# FIGURE, not just from the bar's position.
	var effort: float = bar_t                      # 0 racked, 1 at the chest
	var strain: float = effort * (0.55 + fatigue * 0.45)
	var skin := Game.skin_color().lerp(Color(0.93, 0.55, 0.45), strain * 0.5)
	# The lifter wears what the player equipped, exactly like every other scene.
	var cols: Dictionary = Avatar.colours(true)
	var shirt: Color = cols["jersey"].lerp(cols["jersey"].lightened(0.15), rep_flash)
	var shorts: Color = cols["shorts"]
	var shoe: Color = cols["shoes"]
	var hair: Color = cols["hair"]

	# chest lifts slightly under load, hips dig into the pad
	var chest_lift: float = -6.0 * effort
	draw_rect(Rect2(-150, bench_y - 34 + chest_lift, 290, 36), shirt)       # torso
	# head tilts back as the bar comes down
	var head_c := Vector2(-178 - 6.0 * effort, bench_y - 16 + chest_lift)
	draw_circle(head_c, 28, skin)
	draw_arc(head_c, 28, PI, TAU, 16, hair, 28 * 0.62)
	# equipped hat & glasses, in profile
	Avatar.draw_accessories(self, head_c, 28.0, 1.0, false)
	# clenched jaw / grimace at the bottom
	if effort > 0.55:
		draw_line(head_c + Vector2(-12, 8), head_c + Vector2(2, 8),
			Color(0.35, 0.18, 0.15, effort), 3)
	draw_rect(Rect2(140, bench_y - 30, 70, 30), shorts)                    # hips

	# legs drive into the floor: knees splay and heels press down under load
	var knee_x: float = 246.0 + 10.0 * effort
	var knee_y: float = bench_y + 34.0 - 6.0 * effort
	draw_line(Vector2(198, bench_y - 14 + chest_lift), Vector2(knee_x, knee_y), skin, 16)
	draw_line(Vector2(knee_x, knee_y), Vector2(238 + 6.0 * effort, bench_y + 108), skin, 15)
	draw_rect(Rect2(224 + 6.0 * effort, bench_y + 106, 46, 14), shoe)

	# the bar: y interpolates between racked height and the chest
	var by: float = lerpf(top_y, chest_y, bar_t)

	# drive zone, drawn where it actually is on the bar's travel
	var zone := _drive_zone()
	var zone_top: float = lerpf(top_y, chest_y, 1.0 - zone)
	var good: bool = _in_drive_zone() and bar_dir > 0.0
	# Narrow band centred on the bar: reads as "where to press", not as a
	# giant slab of colour swallowing the whole rack.
	draw_rect(Rect2(-215, zone_top, 430, chest_y - zone_top),
		Color(0.25, 0.85, 0.40, 0.34 if good else 0.16))
	draw_line(Vector2(-215, zone_top), Vector2(215, zone_top),
		Color(0.35, 1.0, 0.5, 0.9), 3)
	if good:
		draw_line(Vector2(-215, chest_y), Vector2(215, chest_y), Color(0.4, 1.0, 0.55, 0.7), 2)

	var flash: float = rep_flash
	for sx in [-90.0, 90.0]:
		var shoulder := Vector2(sx * 0.75, bench_y - 30 + chest_lift)
		var hand := Vector2(sx, by)
		var elbow := shoulder.lerp(hand, 0.5) + Vector2(signf(sx) * (16.0 + 26.0 * effort), 10.0)
		draw_line(shoulder, elbow, skin, 16)
		draw_line(elbow, hand, skin, 14)
		draw_circle(elbow, 8.0, skin)
		draw_circle(hand, 7.0, skin)

	# barbell + plates, inside the uprights
	var bar_col := Color(0.78, 0.80, 0.85).lerp(Color(0.5, 1.0, 0.6), flash)
	draw_rect(Rect2(-390, by - 7, 780, 14), bar_col)
	for sx in [-300.0, -258.0, 258.0, 300.0]:
		draw_rect(Rect2(sx - 14, by - 58, 28, 116), Color(0.15, 0.16, 0.20))
		draw_rect(Rect2(sx - 14, by - 58, 28, 116), Color(0.48, 0.50, 0.58), false, 2)
	# collars
	for sx in [-236.0, 236.0]:
		draw_rect(Rect2(sx - 7, by - 20, 14, 40), Color(0.55, 0.57, 0.64))

# ------------------------------------------------------------------ SQUAT
## Front-on back squat: the bar sits across the shoulders and the whole body
## sinks. bar_t 0 = standing tall, 1 = deep in the hole.
func _draw_squat() -> void:
	var floor_y := 250.0
	var depth: float = bar_t                    # 0 standing, 1 bottom
	var strain: float = depth * (0.55 + fatigue * 0.45)
	var cols: Dictionary = Avatar.colours(true)
	var skin: Color = cols["skin"]
	var shirt: Color = cols["jersey"]
	var shoe: Color = cols["shoes"]
	var hair: Color = cols["hair"]

	# power rack
	for sx in [-300.0, 300.0]:
		draw_rect(Rect2(sx - 16, -240, 32, floor_y + 240), Color(0.30, 0.10, 0.12))
		for i in 8:
			draw_rect(Rect2(sx - 22, -200 + i * 50, 44, 8), Color(0.42, 0.14, 0.16))
	draw_rect(Rect2(-360, floor_y, 720, 26), Color(0.16, 0.17, 0.21))

	# The lifter drops straight down; hips travel further than the shoulders.
	var stand_hip := floor_y - 200.0
	var hip_y: float = stand_hip + depth * 120.0
	var shoulder_y: float = hip_y - 118.0 + depth * 16.0
	var knee_y: float = floor_y - 96.0 + depth * 18.0
	var knee_out: float = 44.0 + depth * 34.0   # knees track outward as he sinks

	# legs (front view: two thick columns splaying under load)
	for sx in [-1.0, 1.0]:
		draw_line(Vector2(sx * 30, hip_y), Vector2(sx * knee_out, knee_y), skin, 26)
		draw_line(Vector2(sx * knee_out, knee_y), Vector2(sx * (knee_out + 6), floor_y - 6), skin, 24)
		draw_rect(Rect2(sx * (knee_out + 6) - 26, floor_y - 12, 52, 16), shoe)
	# torso leans forward slightly at depth
	draw_rect(Rect2(-46, shoulder_y, 92, hip_y - shoulder_y + 10), shirt)
	# head
	var head_c := Vector2(0, shoulder_y - 30 + depth * 4.0)
	draw_circle(head_c, 30, skin)
	draw_arc(head_c, 30, PI, TAU, 16, hair, 30 * 0.62)
	Avatar.draw_accessories(self, head_c, 30.0, 0.0, true)
	if depth > 0.55:
		draw_line(head_c + Vector2(-11, 10), head_c + Vector2(11, 10),
			Color(0.35, 0.18, 0.15, depth), 3)

	# bar rides on the shoulders, arms gripping wide
	var by: float = shoulder_y - 6.0
	for sx in [-1.0, 1.0]:
		draw_line(Vector2(sx * 40, shoulder_y + 6), Vector2(sx * 150, by + 10), skin, 15)
	_draw_zone(stand_hip - 118.0, stand_hip + 120.0 - 118.0 + 16.0, 250.0)
	_draw_barbell(by, 200.0, rep_flash, 62.0)

# ------------------------------------------------------------------ CLEAN
## Power clean: an explosive pull from the floor to a front-rack catch.
## bar_t 0 = bar on the floor, 1 = racked at the collarbone.
func _draw_power_clean() -> void:
	var floor_y := 250.0
	var pull: float = bar_t                     # 0 floor, 1 caught
	var strain: float = pull * (0.5 + fatigue * 0.5)
	var skin := Game.skin_color().lerp(Color(0.93, 0.55, 0.45), strain * 0.5)
	var cols: Dictionary = Avatar.colours(true)
	var shirt: Color = cols["jersey"].lerp(cols["jersey"].lightened(0.15), rep_flash)
	var shoe: Color = cols["shoes"]
	var hair: Color = cols["hair"]

	draw_rect(Rect2(-420, floor_y, 840, 26), Color(0.16, 0.17, 0.21))
	# chalk dust puff on the catch
	if rep_flash > 0.1:
		for i in 9:
			var a: float = TAU * i / 9.0
			draw_circle(Vector2(cos(a) * (40 + 60 * (1.0 - rep_flash)),
				floor_y - 30 + sin(a) * 22), 7.0 * rep_flash, Color(1, 1, 1, 0.28 * rep_flash))

	# The body uncoils: deep hinge at the floor, tall and upright at the catch.
	var hip_y: float = floor_y - 90.0 - pull * 88.0
	var shoulder_y: float = hip_y - 70.0 - pull * 52.0
	var knee_bend: float = (1.0 - pull) * 40.0
	var lean: float = (1.0 - pull) * 46.0       # torso pitched over the bar

	for sx in [-1.0, 1.0]:
		var knee := Vector2(sx * (38 + knee_bend * 0.5), floor_y - 84.0 + knee_bend * 0.4)
		draw_line(Vector2(sx * 26, hip_y), knee, skin, 25)
		draw_line(knee, Vector2(sx * 34, floor_y - 6), skin, 23)
		draw_rect(Rect2(sx * 34 - 26, floor_y - 12, 52, 16), shoe)
	# torso, leaning forward low and standing up as the bar rises
	draw_colored_polygon(PackedVector2Array([
		Vector2(-44 - lean * 0.2, hip_y), Vector2(44 - lean * 0.2, hip_y),
		Vector2(40 + lean * 0.5, shoulder_y), Vector2(-40 + lean * 0.5, shoulder_y)]), shirt)
	var head_c := Vector2(lean * 0.6, shoulder_y - 30)
	draw_circle(head_c, 29, skin)
	draw_arc(head_c, 29, PI, TAU, 16, hair, 29 * 0.62)
	Avatar.draw_accessories(self, head_c, 29.0, 0.0, true)

	# bar path: straight up the shins to the front rack
	var by: float = lerpf(floor_y - 30.0, shoulder_y + 6.0, pull)
	# elbows whip through and point forward at the catch
	for sx in [-1.0, 1.0]:
		var hand := Vector2(sx * 96, by)
		var elbow_fwd: float = pull * 46.0
		var elbow := Vector2(sx * (78 - pull * 20.0), lerpf(hip_y - 10.0, shoulder_y + 26.0, pull))
		draw_line(Vector2(sx * 38, shoulder_y + 12), elbow, skin, 15)
		draw_line(elbow, hand + Vector2(0, -elbow_fwd * 0.1), skin, 13)
		draw_circle(hand, 8.0, skin)
	_draw_zone(floor_y - 30.0, shoulder_y + 6.0, 260.0)
	_draw_barbell(by, 210.0, rep_flash, 60.0)

# ------------------------------------------------------------------ DEADLIFT
## Side view of a deadlift: the athlete hinges down to a bar on the floor and
## pulls it up to a standing lockout. bar_t 0 = bar on the floor, 1 = locked.
func _draw_deadlift() -> void:
	var floor_y := 250.0
	var pull: float = bar_t
	var strain: float = pull * (0.5 + fatigue * 0.5)
	var skin := Game.skin_color().lerp(Color(0.93, 0.55, 0.45), strain * 0.5)
	var cols: Dictionary = Avatar.colours(true)
	var shirt: Color = cols["jersey"].lerp(cols["jersey"].lightened(0.15), rep_flash)
	var shoe: Color = cols["shoes"]
	var hair: Color = cols["hair"]

	draw_rect(Rect2(-420, floor_y, 840, 26), Color(0.16, 0.17, 0.21))
	# The body uncoils from a deep hinge to a tall lockout.
	var hip_y: float = floor_y - 62.0 - pull * 58.0
	var shoulder_y: float = hip_y - 46.0 - pull * 58.0
	var lean: float = (1.0 - pull) * 62.0      # torso pitched over the bar
	var sh_x: float = -lean * 0.7
	# legs (profile), knees straightening as the bar rises
	var knee := Vector2(22.0, floor_y - 88.0 + (1.0 - pull) * 26.0)
	draw_line(Vector2(6.0, hip_y), knee, skin, 22)
	draw_line(knee, Vector2(24.0, floor_y - 6.0), skin, 20)
	draw_rect(Rect2(2.0, floor_y - 12.0, 46.0, 16.0), shoe)
	# torso, leaning forward low and standing tall at lockout
	draw_colored_polygon(PackedVector2Array([
		Vector2(-30.0 + sh_x, hip_y), Vector2(34.0 + sh_x, hip_y),
		Vector2(30.0 + sh_x + lean * 0.4, shoulder_y), Vector2(-34.0 + sh_x + lean * 0.4, shoulder_y)]), shirt)
	var head_c := Vector2(sh_x + lean * 0.5, shoulder_y - 26.0)
	draw_circle(head_c, 26.0, skin)
	draw_arc(head_c, 26.0, PI, TAU, 16, hair, 26.0 * 0.62)
	Avatar.draw_accessories(self, head_c, 26.0, -1.0, false)
	# arms hang straight down to the bar
	var by: float = lerpf(floor_y - 24.0, hip_y - 40.0, pull)
	for sx in [-1.0, 1.0]:
		var sh := Vector2(sx * 20.0 + sh_x + lean * 0.4, shoulder_y)
		var hand := Vector2(sx * 34.0, by)
		draw_line(sh, hand, skin, 16)
		draw_circle(hand, 7.0, skin)
	_draw_zone(floor_y - 24.0, hip_y - 40.0, 240.0)
	_draw_barbell(by, 190.0, rep_flash, 56.0)

# ------------------------------------------------------------------ BOX JUMP
func _draw_box_jump() -> void:
	var floor_y := 250.0
	var box_h: float = 40.0 + fatigue * 8.0
	draw_rect(Rect2(-420, floor_y, 840, 26), Color(0.16, 0.17, 0.21))
	for i in 3:
		var bw: float = 170.0 - i * 30.0
		var bx: float = 60.0 + i * 14.0
		var by: float = floor_y - (i + 1) * box_h
		draw_rect(Rect2(bx, by, bw, box_h),
			Color(0.22, 0.24, 0.30).lerp(Color(0.35, 0.38, 0.46), float(i) / 2.0))
		draw_rect(Rect2(bx, by, bw, box_h), Color(0.90, 0.70, 0.20, 0.5), false, 3.0)
	var depth: float = bar_t
	var lift: float = (1.0 - depth) * box_h * 3.0 * clampf(rep_flash / 0.4, 0.0, 1.0)
	var feet := Vector2(-40.0, floor_y - lift)
	var kind: String = Avatar.DUNK if lift > 8.0 else (Avatar.DEFEND if depth > 0.25 else Avatar.IDLE)
	Avatar.draw_body(self, feet, 168.0, 1.0,
		Avatar.pose(kind, cadence, clampf(lift / 80.0, 0.0, 1.0)),
		Avatar.colours(true), false, true, true)
	_draw_zone(floor_y - 150.0, floor_y - 88.0, 250.0)

# ------------------------------------------------------------------ MED SLAM
## Basketball-specific plyo: an explosive medicine-ball slam. bar_t 0 = ball
## overhead, 1 = slammed to the floor between the feet.
func _draw_med_slam() -> void:
	var floor_y := 250.0
	var slam: float = bar_t
	draw_rect(Rect2(-420, floor_y, 840, 26), Color(0.16, 0.17, 0.21))
	Avatar.draw_body(self, Vector2(0.0, floor_y), 168.0, 1.0,
		Avatar.pose(Avatar.SHOOT, cadence, 1.0 - slam),
		Avatar.colours(true), false, true, true)
	var by: float = lerpf(floor_y - 280.0, floor_y - 40.0, slam)
	var mr: float = 34.0
	draw_circle(Vector2(0.0, by - mr * 0.5), mr, Color(0.30, 0.34, 0.44))
	draw_arc(Vector2(0.0, by - mr * 0.5), mr, 0, TAU, 20, Color(0.12, 0.14, 0.20), 3.0)
	_draw_zone(floor_y - 280.0, floor_y - 40.0, 250.0)

