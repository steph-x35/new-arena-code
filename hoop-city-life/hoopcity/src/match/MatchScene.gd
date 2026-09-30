extends Node2D
## Glue: court + camera + touch HUD. This is the playable match screen.

@onready var court: Court = $Court
@onready var cam: Camera2D = $Camera2D

## Broadcast camera settings. Vertical position never changes; the camera only
## slides sideways, and only once the player leaves a central dead zone.
## CAM_ZOOM is set as high as it can go while BOTH baskets still fit on
## screen, so the court reads much larger than before; the camera then slides
## within the band that keeps both rims visible, giving the "moving view"
## without ever cutting a hoop off the edge.
const CAM_ZOOM := 0.97
const CAM_HEIGHT := -88.0    # court band, tilted up so the far bench row shows
const CAM_DEADZONE := 40.0   # px of free movement before the camera reacts
const CAM_FOLLOW := 3.6      # how quickly it catches up once it does move
@onready var hud: Control = $HUD/Root

var joystick: VirtualJoystick
var meter: ShotMeter
var btn_shoot: TouchButton
var btn_crossover: TouchButton
var btn_pass: TouchButton
var btn_block: TouchButton
var btn_check: TouchButton
var btn_steal: TouchButton
var btn_guard: TouchButton
var btn_post: TouchButton
var _last_move_ms := -100000   # ultimo TRICK riuscito: per la combo PULL-UP
var btn_pnr: TouchButton
var btn_timeout: Button
var bench_panel: PanelContainer
var sim_to_return := false
var _phase_offence := true
var _phase_init := false
var _phase_hold := 0.0        # debounce: a phase must persist before it sticks
var lbl_score: Label
var lbl_clock: Label
var momentum_left: ColorRect
var momentum_right: ColorRect
var lbl_toast: Label
var lbl_banner: Label
var lbl_countdown: Label
var stamina_bar: ProgressBar
## Broadcast pass: intro card, commentator line, jumbotron hook.
var intro_panel: Control
var intro_left := 0.0
var goal := {}               # obiettivo di partita corrente (MatchGoals)
var goal_done := false
var goal_lbl: Label          # ticker live in alto sotto il punteggio
var lbl_comm: Label
var commentary: Node
## 3-2-1 before tip-off, so you can read who you are guarding.
var tip_left := 3.0
## Between-quarters break: the cheerleaders dance ON the court for 10 seconds.
var intermission_left := 0.0
var _hinted := false          # one-time controls hint when the ball goes live
var _trick_tap_ms := -999     # last TRICK press: double tap = SPIN MOVE
var _neutral_trick_i := 0     # (storico) non piu usato: fermo = HESI come nel court solo
var _perf_checked := false
var _shake := 0.0
var _last_count := ""

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.10, 0.11, 0.14))
	_build_hud()
	_setup_broadcast()
	Events.score_changed.connect(_on_score)
	Events.toast.connect(_on_toast)
	Events.shot_taken.connect(_on_shot_taken)
	Events.match_finished.connect(_on_finished)
	Events.quarter_ended.connect(_on_quarter_ended)
	Events.shake.connect(_on_shake)
	Events.popup.connect(_on_popup)
	Sfx.start_crowd()
	Sfx.set_match_live(true)
	if court.is_fixture:
		Sfx.court_jazz(true)   # low jazz bed under the crowd, user's call
	else:
		Sfx.stop_music()       # 1v1 / scrimmage: parquet and nothing else
	# Cheerleaders dance under the far stands all game, and run onto the court
	# between quarters.
	var vis = $CourtVisual
	if vis != null:
		vis.show_cheer = true
		# Benches/scorer's table follow the match state; the stands get people
		# ONLY for a real league game -- scrimmages and 1v1 play in an empty
		# bowl. The crowd is baked into the static layer, so rebake it.
		vis.court = court
		# Il caos delle tribune vale per OGNI partita, anche scrimmage e 1v1:
		# gente sui gradoni, swell e fischi dall'inizio alla fine.
		vis.crowd_on = true
		vis.request_rebake()
	court.bench_changed.connect(_on_bench_changed)
	# Near half of each net, painted OVER the ball so a make reads as dropping
	# through the mesh instead of sliding across its front.
	var nf = preload("res://src/match/NetFront.gd").new()
	nf.vis = $CourtVisual
	nf.z_index = 90
	add_child(nf)
	# Hold play for the countdown: nobody moves until "GO!".
	court.play_live = false
	tip_left = 3.0

func _maybe_perf_check() -> void:
	# Auto-rilevamento anche in PARTITA: un dispositivo puo' tenere il menu
	# e affogare nel match (10 avatar + folla). Una sola volta, dopo 4s.
	if _perf_checked or court == null or not court.play_live:
		return
	_perf_checked = true
	get_tree().create_timer(4.0).timeout.connect(func():
		if Engine.get_frames_per_second() < 25 \
		and not bool(Settings.get_v("lowgfx", false)):
			Settings.set_v("target_fps", 30)
			Settings.set_v("lowgfx", true)
			Events.toast.emit("Modalita performance attiva (30 fps)"))

func _process(delta: float) -> void:
	_maybe_perf_check()
	var u := court.user
	if u == null or stamina_bar == null: return
	_update_goal_tracker()
	# ---- broadcast intro: the tip-off countdown waits for the card. A tap
	#      skips straight to the 3-2-1.
	if intro_left > 0.0:
		intro_left -= delta
		if intro_left <= 0.0:
			_intro_done()
		return
	# ---- between-quarters: cheerleaders dance on the court for 10 seconds,
	#      then the 3-2-1 countdown brings the next quarter in.
	if intermission_left > 0.0:
		intermission_left -= delta
		# The cheerleaders are the show here: hide the big countdown so it
		# cannot sit on top of the dancers.
		lbl_countdown.text = ""
		lbl_countdown.modulate.a = 0.0
		if intermission_left <= 0.0:
			intermission_left = 0.0
			court.intermission = false
			lbl_countdown.text = ""
			var cv = $CourtVisual
			if cv != null:
				cv.cheer_on_court = false
			court.play_live = false
			tip_left = 3.0
		return
	# ---- 3-2-1-GO countdown before the ball is live
	if tip_left > 0.0:
		tip_left -= delta
		if tip_left <= 0.0:
			if court.one_on_one:
				court.play_live = false
				Events.toast.emit("CHECK THE BALL")
				Sfx.play("whistle_short")
			else:
				court.play_live = true
				Events.toast.emit("GO!")
				Sfx.play("go")
				Sfx.cheer(false)
			lbl_countdown.text = "GO!" if not court.one_on_one else "CHECK"
			var tw := create_tween()
			tw.tween_interval(0.7)
			tw.tween_property(lbl_countdown, "modulate:a", 0.0, 0.3)
			_last_count = "GO!"
		else:
			var n := "%d" % int(ceil(tip_left))
			lbl_countdown.text = n
			lbl_countdown.modulate.a = 1.0
			if n != _last_count:
				Sfx.play("beep")
			_last_count = n
	# ---- one-time control hint once the ball is genuinely live
	if not _hinted and court.play_live and tip_left <= 0.0 and not court.ft_active:
		_hinted = true
		_show_first_hint()
	# ---- broadcast camera
	# It used to chase a blend of the player AND the ball, in unprojected
	# coordinates, while everything was DRAWN projected. The ball bounces every
	# dribble, so the view shook constantly and drifted 540px vertically -- that
	# is the wobble that made the match unplayable.
	#
	# Now it behaves like a television camera on a rail: locked vertically,
	# sliding left and right only, following the PLAYER (never the ball), and
	# working in the same projected space the court is drawn in.
	var ch: float = Court.COURT_H
	# Follow YOUR man while he plays; when he is benched (or you simulated
	# ahead) the camera follows the BALL, and the cheer routine at the
	# intermission gets the centre frame -- the match never plays off-screen.
	var follow_pos: Vector2 = u.global_position
	if intermission_left > 0.0:
		follow_pos = Vector2.ZERO
	elif not court.user_on_court or not u.visible:
		follow_pos = court.ball.global_position if court.ball != null else u.global_position
	var target_x: float = CourtStage.m_project(follow_pos, ch).x
	# The camera may slide, but both rims must never leave the screen. The
	# bound is therefore the rim position, not the painted floor: at this zoom
	# there is a small band of travel around the centre line.
	var half_view: float = get_viewport_rect().size.x * 0.5 / CAM_ZOOM
	# Zoomed to a bit more than half-court: follow the player, keep a rim
	# of floor around the edges instead of forcing both baskets on screen.
	var floor_x: float = CourtStage.m_project(
		Vector2(Court.COURT_W * 0.5, 0.0), Court.COURT_H).x
	var limit: float = maxf(floor_x - half_view + 160.0, 80.0)
	target_x = clampf(target_x, -limit, limit)
	# A small dead zone so jostling for position does not swing the whole screen.
	var dx: float = target_x - cam.global_position.x
	if absf(dx) > CAM_DEADZONE:
		var want: float = target_x - signf(dx) * CAM_DEADZONE
		cam.global_position.x = lerpf(cam.global_position.x, want,
			clampf(CAM_FOLLOW * delta, 0.0, 1.0))
	# Height is FIXED. The court is a fixed-height band on screen, so there is
	# nothing for the camera to track vertically.
	cam.global_position.y = CAM_HEIGHT
	cam.zoom = Vector2.ONE * CAM_ZOOM
	# Game-feel shake from dunks, blocks and iron. Offset (never the follow
	# target), decaying quickly so it never interferes with readability.
	if _shake > 0.001:
		var s: float = _shake * 26.0
		cam.offset = Vector2(randf_range(-s, s), randf_range(-s * 0.7, s * 0.7))
		cam.zoom = Vector2.ONE * CAM_ZOOM * (1.0 + _shake * 0.015)
		_shake = maxf(0.0, _shake - delta * 3.4)
	else:
		cam.offset = cam.offset.lerp(Vector2.ZERO, clampf(delta * 12.0, 0.0, 1.0))

	stamina_bar.value = u.stamina
	# POST hint (una sola volta): palla in mano in area -> il bottone esiste.
	if u.has_ball and not court.ft_active and not bool(Game.profile.get("post_hint_m", false)) \
	and court.px_to_ft(u.global_position.distance_to(court.hoop_for(u.team))) < 18.0:
		Game.profile["post_hint_m"] = true
		Events.toast.emit("POST: TIRA = fade · TRICK = drop step")

	# Attack / defence follows who owns the ball as a TEAM, not whether this
	# one player is holding it. Keying it to u.has_ball meant that any time a
	# team-mate had the ball your pad flipped to the defensive set, so the big
	# button was BLOCK -- which only jumps. That is why SHOOT "did nothing" and
	# the player just hopped on the spot.
	var want_phase: bool = _phase_offence
	var h: BallPlayer = court.ball_handler()
	if h != null:
		want_phase = h.team == u.team
	elif court.ball == null or not (court.ball.live and court.ball.shooter == null):
		# A genuinely loose ball keeps the attacking pad, so the primary button
		# stays available as the grab button. A PASS in flight (live, no
		# shooter) falls through with `want_phase` unchanged -- the pad holds
		# still while the ball travels instead of fluttering attack/defence.
		want_phase = true
	# Debounce: a phase only sticks after it has held for a moment, so the pad
	# never flips back and forth while two players scrap for the ball.
	if _phase_init and want_phase != _phase_offence:
		_phase_hold += delta
		if _phase_hold < 0.30:
			want_phase = _phase_offence
		else:
			_phase_hold = 0.0
	else:
		_phase_hold = 0.0
	_set_phase(want_phase)
	# Free throws: only TIRA. Every other match moment keeps the SAME pad —
	# attack and defence buttons stay put for the whole game.
	if court.ft_active:
		_show_btn(btn_crossover, false)
		_show_btn(btn_pass, false)
		_show_btn(btn_block, false)
		_show_btn(btn_steal, false)
		_show_btn(btn_guard, false)
		_show_btn(btn_pnr, false)
		_show_btn(btn_shoot, true)
	else:
		_apply_pad(_phase_offence)
	if btn_check:
		var show_check: bool = court.one_on_one and court.awaiting_check \
			and court.possession == 0 and tip_left <= 0.0
		_show_btn(btn_check, show_check)
		if show_check:
			_show_btn(btn_shoot, false)
			_show_btn(btn_crossover, false)
			_show_btn(btn_pass, false)
			_show_btn(btn_pnr, false)
			_show_btn(btn_block, false)
			_show_btn(btn_steal, false)
			_show_btn(btn_guard, false)
	if not court.user_on_court:
		for b in [btn_shoot, btn_crossover, btn_pass, btn_pnr, btn_block, btn_steal, btn_guard, btn_check]:
			_show_btn(b, false)
		if joystick != null:
			joystick.visible = false
	elif joystick != null and not joystick.visible:
		joystick.visible = true
	if btn_timeout:
		btn_timeout.visible = not court.one_on_one and not court.finished
		var tl: String = Loc.t("match.timeout") + " (%d)" % court.timeouts_left[0]
		if btn_timeout.text != tl:
			btn_timeout.text = tl
		btn_timeout.disabled = court.timeouts_left[0] <= 0 or court.timeout_active > 0.0
	if btn_shoot:
		var want: String = Loc.t("match.dunk") if (u.hanging or u.can_dunk()) else Loc.t("match.shoot")
		if btn_shoot.text != want:
			btn_shoot.text = want
	if btn_guard:
		btn_guard.accent = Color(0.30, 0.85, 0.45) if u.guarding else Color(0.92, 0.55, 0.16)
	if court.one_on_one:
		lbl_clock.text = "1v1 · %d   ·   %s" % [court.target_score,
			Loc.t("match.shotclk") % "%02d" % int(ceil(court.shot_clock))]
	else:
		lbl_clock.text = "Q%d  %02d:%02d   ·   %s" % [court.quarter,
			int(court.game_clock) / 60, int(court.game_clock) % 60,
			Loc.t("match.shotclk") % "%02d" % int(ceil(court.shot_clock))]
	# Momentum meter: positive m runs your way. Each half grows from the
	# centre seam, so the bar physically tips with the game's flow.
	var m: float = clampf(court.momentum, -1.0, 1.0)
	var full := 150.0
	momentum_left.custom_minimum_size = Vector2(full * clampf(m, 0.0, 1.0), 8.0)
	momentum_right.custom_minimum_size = Vector2(full * clampf(-m, 0.0, 1.0), 8.0)
	momentum_right.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	momentum_left.size_flags_horizontal = Control.SIZE_SHRINK_END

	# shot meter
	if u.shot_charge >= 0.0:
		meter.visible = true
		meter.frozen = false
		meter.charge = u.shot_charge
		meter.ideal = u.shot_ideal
		meter.max_charge = u.MAX_CHARGE
		meter.contest = court.pressure_on(u)
	elif not meter.frozen:
		meter.visible = false
		meter.contest = 0.0
	# The green band tightens with distance (from half court it is a sliver),
	# and it always matches what the sim scores.
	var mft: float = court.px_to_ft(u.global_position.distance_to(court.hoop_for(u.team)))
	var mw: Dictionary = ShotSystem.shot_windows(mft)
	meter.perfect_window = float(mw["perfect"])
	meter.good_window = float(mw["good"])
	_place_meter()
	if not court.one_on_one and u.has_ball:
		court.update_pass_aim(u, u.move_input)
	else:
		court.aimed = null

func _show_first_hint() -> void:
	await get_tree().create_timer(1.8).timeout
	Events.toast.emit("Hold SHOOT to score - tap SHOOT to PUMP FAKE - TRICK shakes your man")

func _place_meter() -> void:
	## The arc sits directly above the shooter's HEAD -- not above the SHOOT
	## button -- and it follows him in the air, so a jumper or a slam still
	## reads with the meter over the man and not stuck on the floor below him.
	if meter == null or court == null or court.user == null:
		return
	var u: BallPlayer = court.user
	var body: float = 64.0 * Game.height_factor()
	# In the air the figure is drawn lifted by `air`; on the rim he hangs at
	# the reach height. Mirror exactly what Player._draw uses.
	var rise: float = u.air
	if u.hanging:
		rise = maxf(court.RIM_HEIGHT - body * DunkStyle.REACH, 0.0)
	var world: Vector2 = CourtStage.m_project(u.global_position, Court.COURT_H)
	world.y -= body + 36.0 + rise
	var vp: Vector2 = get_viewport_rect().size
	var scr: Vector2 = (world - cam.global_position) * cam.zoom + vp * 0.5
	meter.size = Vector2(120, 78)
	var msz: Vector2 = meter.size
	# The arc is drawn from the BOTTOM-CENTRE of the control, so that is the
	# point pinned above the head -- and the clamp keeps the whole arc on
	# screen even when the shooter is up against the top sideline.
	var pos: Vector2 = scr - Vector2(msz.x * 0.5, msz.y)
	pos.x = clampf(pos.x, 8.0, maxf(vp.x - msz.x - 8.0, 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(vp.y - msz.y - 8.0, 8.0))
	meter.position = pos

# ------------------------------------------------------------------ HUD
func _build_hud() -> void:
	joystick = VirtualJoystick.new()
	joystick.set_anchors_preset(Control.PRESET_FULL_RECT)
	joystick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	joystick.sensitivity = float(Settings.get_v("joystick_sensitivity", 1.0))
	joystick.moved.connect(func(v): if court.user: court.user.move_input = v)
	# joystick only listens on the left half
	var left := Control.new()
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.anchor_right = 0.45
	left.add_child(joystick)
	hud.add_child(left)

	# Scoreboard. A broadcast-style centre pill: team colour chips and names
	# flanking the score, clock + shot clock under it, momentum seam below.
	# Anchored across the FULL width with centred text rather than pinned to
	# the centre with a hand-guessed negative offset -- that offset assumed a
	# label width that no longer matched once the text grew, so the score and
	# clock drifted off the top of the screen.
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	holder.offset_bottom = 96
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(holder)
	var board := PanelContainer.new()
	holder.add_child(board)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.062, 0.086, 0.82)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.949, 0.420, 0.114, 0.45)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	board.add_theme_stylebox_override("panel", sb)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(vb)

	var trow := HBoxContainer.new()
	trow.alignment = BoxContainer.ALIGNMENT_CENTER
	trow.add_theme_constant_override("separation", 14)
	trow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(trow)
	for team in [0, 1]:
		var chip := Panel.new()
		var cs := StyleBoxFlat.new()
		cs.bg_color = Game.team_colour(team)
		cs.set_corner_radius_all(5)
		chip.add_theme_stylebox_override("panel", cs)
		chip.custom_minimum_size = Vector2(14, 34)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trow.add_child(chip)
		var tn := Label.new()
		# Real club abbreviations, not generic HOME/AWAY: the scoreboard reads
		# like a broadcast score bug from the first frame.
		var club: String = Season.my_team() if team == 0 \
			else String(Game.profile.get("next_opponent", "Practice Squad"))
		tn.text = Season.short_name(club)
		tn.add_theme_font_size_override("font_size", 20)
		tn.add_theme_color_override("font_color", Color(0.965, 0.949, 0.906, 0.75))
		tn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trow.add_child(tn)
		if team == 0:
			lbl_score = Label.new()
			lbl_score.text = "0 - 0"
			lbl_score.add_theme_font_size_override("font_size", 42)
			lbl_score.add_theme_color_override("font_color", Color(0.965, 0.949, 0.906))
			lbl_score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
			trow.add_child(lbl_score)

	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_theme_constant_override("separation", 10)
	crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(crow)
	lbl_clock = Label.new()
	lbl_clock.text = "Q1  02:00   shot 24"
	lbl_clock.add_theme_font_size_override("font_size", 20)
	lbl_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_clock.add_theme_color_override("font_color", Color(0.965, 0.949, 0.906, 0.80))
	lbl_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crow.add_child(lbl_clock)

	# Momentum bar: the sim already tracks runs of play (-1..1) and feeds it
	# into shot probability; this is the player-facing half -- blue surging
	# when you are on a run, red when the opponent is.
	var mrow := HBoxContainer.new()
	mrow.alignment = BoxContainer.ALIGNMENT_CENTER
	mrow.add_theme_constant_override("separation", 0)
	mrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	momentum_left = ColorRect.new()
	momentum_right = ColorRect.new()
	momentum_left.size = Vector2(150, 8)
	momentum_right.size = Vector2(150, 8)
	momentum_left.color = Game.team_colour(0)
	momentum_right.color = Game.team_colour(1)
	mrow.add_child(momentum_left)
	mrow.add_child(momentum_right)
	vb.add_child(mrow)

	# Centre the pill by hand once its content size is known (and on every
	# viewport change): anchoring guesses used to drift off-screen.
	var centre_board := func():
		board.position = Vector2((holder.size.x - board.size.x) * 0.5, 0.0)
	board.resized.connect(centre_board)
	holder.resized.connect(centre_board)
	board.ready.connect(func(): centre_board.call())

	lbl_toast = Label.new()
	lbl_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lbl_toast.offset_top = 132
	lbl_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl_toast.add_theme_font_size_override("font_size", 28)
	lbl_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_toast.modulate.a = 0.0
	hud.add_child(lbl_toast)

	# Big centre-screen callout for slams and other highlights.
	lbl_banner = Label.new()
	# Full-width strip with centred text: anchoring a fixed-width label to the
	# centre put its LEFT edge at the middle of the screen.
	lbl_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lbl_banner.offset_top = 200
	lbl_banner.custom_minimum_size = Vector2(0, 90)
	lbl_banner.add_theme_font_size_override("font_size", 68)
	lbl_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_banner.modulate.a = 0.0
	hud.add_child(lbl_banner)

	# Way out. A match with no exit meant force-quitting the app to leave.
	# Way out: a compact icon slab, not a grey default button eating the
	# corner of the court. A match with no exit meant force-quitting to leave.
	var quit_btn := Button.new()
	quit_btn.text = Loc.t("match.exit")
	quit_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	quit_btn.position = Vector2(18, 14)
	quit_btn.custom_minimum_size = Vector2(96, 50)
	quit_btn.add_theme_font_size_override("font_size", 18)
	quit_btn.pressed.connect(_confirm_exit)
	hud.add_child(quit_btn)

	# Timeout call button, top right (5v5 only).
	btn_timeout = Button.new()
	btn_timeout.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_timeout.position = Vector2(-206, 14)
	btn_timeout.custom_minimum_size = Vector2(188, 50)
	btn_timeout.add_theme_font_size_override("font_size", 17)
	btn_timeout.pressed.connect(_call_timeout)
	hud.add_child(btn_timeout)

	# Bench overlay: shown while the coach has you on the pine.
	bench_panel = PanelContainer.new()
	bench_panel.set_anchors_preset(Control.PRESET_CENTER)
	bench_panel.offset_left = -270
	bench_panel.offset_right = 270
	bench_panel.offset_top = -96
	bench_panel.offset_bottom = 96
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.06, 0.07, 0.10, 0.93)
	bs.set_corner_radius_all(16)
	bs.set_border_width_all(2)
	bs.border_color = Color(0.949, 0.420, 0.114, 0.55)
	bs.content_margin_left = 18; bs.content_margin_right = 18
	bs.content_margin_top = 12; bs.content_margin_bottom = 12
	bench_panel.add_theme_stylebox_override("panel", bs)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 10)
	bench_panel.add_child(bv)
	var bt := Label.new()
	bt.text = Loc.t("match.bench.title")
	bt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bt.add_theme_font_size_override("font_size", 26)
	bv.add_child(bt)
	var bsu := Label.new()
	bsu.text = Loc.t("match.bench.sub")
	bsu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bsu.add_theme_font_size_override("font_size", 15)
	bsu.modulate = Color(1, 1, 1, 0.72)
	bv.add_child(bsu)
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_theme_constant_override("separation", 14)
	bv.add_child(bh)
	var bw := Button.new()
	bw.text = Loc.t("match.bench.watch")
	bw.custom_minimum_size = Vector2(200, 56)
	bw.pressed.connect(func(): bench_panel.visible = false)
	bh.add_child(bw)
	var bsm := Button.new()
	bsm.text = Loc.t("match.bench.sim")
	bsm.custom_minimum_size = Vector2(240, 56)
	bsm.pressed.connect(_sim_to_return)
	bh.add_child(bsm)
	bench_panel.visible = false
	hud.add_child(bench_panel)

	stamina_bar = ProgressBar.new()
	stamina_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	stamina_bar.position = Vector2(46, -44)
	stamina_bar.custom_minimum_size = Vector2(300, 16)
	stamina_bar.max_value = 100
	stamina_bar.show_percentage = false
	hud.add_child(stamina_bar)
	var st_icon := Control.new()
	st_icon.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	st_icon.position = Vector2(16, -48)
	st_icon.custom_minimum_size = Vector2(24, 24)
	st_icon.size = Vector2(24, 24)
	st_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st_icon.draw.connect(func():
		Art.draw_icon(st_icon, "bolt", Rect2(Vector2.ZERO, st_icon.size), Art.GREEN))
	hud.add_child(st_icon)

	# Shot meter: a custom-drawn arc right above the SHOOT button, where the
	# player's eyes already are. A ProgressBar bottom-left was unreadable while
	# your thumb was on the other side of the screen.
	meter = ShotMeter.new()
	meter.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# Sits fully inside the screen: at -250 its right edge ran 50 px past the
	# viewport and the green band was clipped off.
	meter.position = Vector2(-330, -700)
	meter.size = Vector2(300, 190)
	meter.visible = false
	hud.add_child(meter)

	# action buttons, thumb-reachable on the right.
	# TouchButton (not Button) because Godot's Button loses the release event
	# under multi-touch -> the shot charge would hang forever. See TouchButton.gd.
	# TIRA relabels itself to DUNK when you are under the rim with the ball,
	# so the primary button is always the action the situation calls for.
	#
	# The pad is three actions per phase -- no overlap, no dead buttons:
	#   attack : TIRA (-> DUNK next to the rim) / CROSSOVER / PASS
	#   defence: STOPPATA / STEAL / DIFESA
	#
	# Triangle pad (not a row). Attack and defence SWAP the same 3 slots so
	# they never overlap. P&R sits above the triangle on offence only.
	#         P&R
	#    TRICK    PASS
	#        SHOOT
	#    STEAL    GUARD
	#        JUMP
	# BOTTOM_RIGHT offsets: x+w and y+h must stay negative so nothing clips
	# off the right / bottom. Tight triangle, all three circles touching.
	const SZ_P := Vector2(128, 128)
	const SZ_S := Vector2(108, 108)
	const SLOT_PRIMARY := Vector2(-196, -152)
	const SLOT_LEFT    := Vector2(-292, -258)
	const SLOT_RIGHT   := Vector2(-128, -258)
	const SLOT_PNR     := Vector2(-214, -372)

	btn_shoot  = _button("SHOOT", SLOT_PRIMARY, SZ_P, _shoot_down, _shoot_up)
	btn_crossover = _button("TRICK", SLOT_LEFT, SZ_S, _dribble_move, Callable())
	btn_pass = _button("PASS", SLOT_RIGHT, SZ_S, _pass, Callable())
	btn_pnr = _button("P&R", SLOT_PNR, SZ_S, _pnr_tap, Callable())

	btn_block = _button("JUMP", SLOT_PRIMARY, SZ_P, _block, Callable())
	btn_check = _button("CHECK", Vector2(-214, -500), SZ_P, _do_check, Callable())
	btn_check.visible = false
	btn_steal = _button("STEAL", SLOT_LEFT, SZ_S, _steal, Callable())
	btn_guard = _button("DEFEND", SLOT_RIGHT, SZ_S, _guard_down, _guard_up)
	# POST UP (1v1: slot del PASS; 5v5: slot del P&R entro 14ft): mette le
	# spalle al canestro. Da li': SHOOT = fadeaway/hook, TRICK = drop step.
	btn_post = _button("POST", SLOT_RIGHT, SZ_S, _post_tap, Callable())
	btn_post.accent = Color(0.980, 0.780, 0.260)
	btn_post.visible = false
	btn_post.set_process_input(false)
	# Defence reads cooler in green, checks in gold: the pad colour tells you
	# which phase you are in before you read a single letter.
	btn_block.accent = Color(0.870, 0.290, 0.260)
	btn_steal.accent = Color(0.870, 0.290, 0.260)
	btn_guard.accent = Color(0.870, 0.290, 0.260)
	btn_check.accent = Color(0.980, 0.780, 0.260)
	btn_pnr.accent = Color(0.290, 0.560, 0.890)
	btn_pass.accent = Color(0.290, 0.560, 0.890)

	# 3-2-1 countdown, big and centred.
	lbl_countdown = Label.new()
	lbl_countdown.set_anchors_preset(Control.PRESET_CENTER)
	lbl_countdown.position = Vector2(-160, -160)
	lbl_countdown.custom_minimum_size = Vector2(320, 160)
	lbl_countdown.add_theme_font_size_override("font_size", 120)
	lbl_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_countdown.text = ""
	hud.add_child(lbl_countdown)

	_set_phase(true)

func _set_phase(offence: bool) -> void:
	if btn_shoot == null:
		return
	_phase_offence = offence
	_phase_init = true
	if court != null and court.ft_active:
		return
	_apply_pad(offence)

func _show_btn(b: TouchButton, on: bool) -> void:
	if b == null:
		return
	if b.visible and not on and b.has_method("force_release"):
		b.force_release()
	b.visible = on
	b.set_process_input(on)

func _apply_pad(offence: bool) -> void:
	## Triangle of 3 shared slots, swapped by phase. P&R extra on offence.
	if btn_shoot == null:
		return
	var team_off: bool = offence
	var five: bool = court == null or not court.one_on_one
	_show_btn(btn_shoot, team_off)
	_show_btn(btn_crossover, team_off)  # 1v1 and 5v5 — same TRICK as street
	_show_btn(btn_pass, team_off and five)
	_show_btn(btn_pnr, team_off and five)
	_show_btn(btn_block, not team_off)
	_show_btn(btn_steal, not team_off)
	_show_btn(btn_guard, not team_off)
	# POST UP: sempre in 1v1 (slot libero del PASS), in 5v5 solo vicino al
	# ferro e al posto del P&R. Serve palla in mano.
	var pu: BallPlayer = court.user if court != null else null
	var near_rim: bool = pu != null and pu.has_ball and court != null \
		and court.px_to_ft(pu.global_position.distance_to(court.hoop_for(pu.team))) < 18.0
	# PARITA' COURT SOLO: il POST e' SEMPRE visibile in attacco, con o
	# senza palla, in 1v1 (slot destro) come in scrimmage (in alto a
	# sinistra, senza coprire il P&R). Come il bottone del court libero.
	var show_post: bool = team_off and pu != null
	_show_btn(btn_post, show_post)
	if show_post:
		# (slot sono const locali a _setup_hud: qui valori letterali)
		btn_post.position = Vector2(-128, -258) if not five else Vector2(-414, -372)

func _label(t: String, pos: Vector2, sz: int, al: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", sz)
	l.horizontal_alignment = al
	l.position = pos
	hud.add_child(l)
	return l

const PAD_LOC := {
	"SHOOT": "match.shoot", "DUNK": "match.dunk", "TRICK": "match.trick",
	"PASS": "match.pass", "P&R": "match.pnr", "JUMP": "match.jump",
	"STEAL": "match.steal", "DEFEND": "match.defend", "CHECK": "match.check",
	"POST": "match.post",
}

func _button(txt: String, pos: Vector2, sz: Vector2, on_down: Callable, on_up: Callable) -> TouchButton:
	var b := TouchButton.new()
	b.icon = Art.icon_for(txt)
	b.text = Loc.t(PAD_LOC.get(txt, ""), txt)
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.position = pos
	b.custom_minimum_size = sz
	b.size = sz
	b.hold_mode = on_up.is_valid()
	hud.add_child(b)
	if on_up.is_valid():
		b.pressed_down.connect(on_down)
		b.released.connect(on_up)
	else:
		# tap action: fire on press, ignore the release
		b.pressed_down.connect(on_down)
	return b

# ------------------------------------------------------------------ actions
func _shoot_down() -> void:
	var u := court.user
	if u == null: return
	u.dunk_held = true
	if u.hanging:
		return
	if not u.has_ball:
		# No ball in your hands. Try to grab a loose one; if it is out of
		# reach, either call for the pass (team-mate has it) or drive at the
		# handler (opponent has it). The button always does something.
		if court.try_grab(u):
			return
		var h: BallPlayer = court.ball_handler()
		if h == null:
			# loose ball somewhere: sprint at it
			u.chase(court.ball.global_position)
		elif h.team == u.team:
			court.request_pass(u)
		else:
			u.chase(h.global_position)
		return
	# COMBO PULL-UP: un TRICK seguito da TIRA entro mezzo secondo = tiro
	# in slancio (popup visibile, timing leggermente piu' severo).
	u.combo_pullup = u.has_ball and Time.get_ticks_msec() - _last_move_ms < 500 \
		and not court.ft_active
	# Da POST niente auto-dunk: SHOOT gioca hook/fade. Per lo schiacciato
	# si esce prima dalla post (secondo tap su POST).
	if u.can_dunk() and not u.posting:
		# Close enough to throw it down: skip the meter entirely.
		u.do_dunk()
		return
	# At the free-throw line the routine is always the same: charge the meter
	# toward the fixed ideal and release.
	if court.behind_hoop(u):
		Events.toast.emit("No shot from behind the hoop")
		return
	if court.ft_active and court.ft_shooter == u:
		u.shot_charge = 0.0
		u.shot_ideal = 0.5
		return
	u.shot_charge = 0.0
	u.fake_locked = false   # il tiro parte dal gather: niente infrazione di passi
	# ideal release depends on distance: longer shots have a later release point
	var ft := court.px_to_ft(u.global_position.distance_to(court.hoop_for(u.team)))
	u.shot_ideal = clampf(0.42 + ft * 0.012, 0.42, 0.78)

func _shoot_up() -> void:
	var u := court.user
	if u == null: return
	u.dunk_held = false
	# Drop from the rim only once we are actually hanging.
	if u.hanging:
		u.release_rim()
		return
	if u.shot_charge < 0.0: return
	# A quick TAP sells a pump fake -- the on-ball defender may bite and jump,
	# opening the drive or the real jumper. A HOLD rides the meter to release.
	# Free throws always shoot. A tap that could not become a fake (move
	# cooldown) is swallowed rather than dumped as an accidental early shot.
	if not court.ft_active and u.has_ball and u.shot_charge < 0.17:
		if u.do_pump_fake():
			Events.toast.emit("PUMP FAKE")
		else:
			u.shot_charge = -1.0
		return
	# COMBO FADE: TIRA rilasciato con lo stick che punta VIA dal canestro
	# (o da POST): hop indietro -> famiglia fade con animazione.
	if u.has_ball and not court.ft_active and not u.jumping:
		var to_hoop: Vector2 = court.hoop_for(u.team) - u.global_position
		if u.posting or (to_hoop.length() > 60.0 \
		and u.move_input.dot(to_hoop.normalized()) < -0.45):
			_post_shoot_hop(u)
	u.do_shot_release()

func _post_shoot_hop(u: BallPlayer) -> void:
	## FADE: hop indietro prima del rilascio, cosi' il tiro parte davvero
	## "andando via" e la famiglia fade/hook si attiva con ANIMAZIONE.
	## Due entrate: da POST (bottone) o COMBO stick indietro al rilascio.
	if not u.has_ball:
		return
	var h: Vector2 = court.hoop_for(u.team)
	var away: Vector2 = u.global_position - h
	if away.length() > 1.0:
		u.velocity = away.normalized() * 300.0
	else:
		u.velocity = Vector2(-u.facing * 300.0, 0)

func _do_check() -> void:
	if court:
		court.confirm_check()

func _block() -> void:
	var u := court.user
	if u == null: return
	# Over a loose ball STOPPATA snatches it instead of jumping.
	if court.ball != null and court.ball.holder == null:
		if not court.try_grab(u):
			u.chase(court.ball.global_position)
		return
	u.do_jump(true)

func _post_tap() -> void:
	## POST UP: spalle al canestro. Da li' SHOOT gioca la famiglia
	## fade/hook (hop indietro automatico) e TRICK fa il drop step.
	var u := court.user
	if u == null or not u.has_ball or court.finished or court.awaiting_check:
		return
	if u.jumping or u.hanging or court.ft_active:
		return
	u.posting = not u.posting
	if u.posting:
		var h: Vector2 = court.hoop_for(u.team)
		var hx: float = h.x - u.global_position.x
		if absf(hx) > 1.0:
			u.facing = -signf(hx)
		u.velocity *= 0.3
		Events.popup.emit("POST", u.global_position, Color(0.98, 0.78, 0.26), false)
		if not bool(Game.profile.get("post_hint", false)):
			Game.profile["post_hint"] = true
			Events.toast.emit("POST: TIRA = fade · TRICK = drop step")

func _steal() -> void:       if court.user: court.user.try_steal()

func _pnr_tap() -> void:
	var u := court.user
	if u == null or court.one_on_one:
		return
	if not u.has_ball:
		_dribble_move()
		return
	if court.pnr_screening:
		court.release_pick_and_roll(u)
		if btn_pnr:
			btn_pnr.text = "P&R"
	else:
		court.start_pick_and_roll(u)
		if btn_pnr:
			btn_pnr.text = "ROLL"

## PASS: send the ball to the team-mate in the direction the joystick is held.
func _pass() -> void:
	var u := court.user
	if u == null or court.one_on_one:
		return
	if not u.has_ball:
		# No ball: call it back if you are open.
		court.request_pass(u)
		return
	court.directed_pass(u, u.move_input)

func _guard_down() -> void:
	## DIFESA works WHILE HELD: press to stick to your man, release to drop it.
	var u := court.user
	if u == null:
		return
	if not u.guarding:
		u.guarding = true
		Events.toast.emit("DEFENSE ON — stay in front of your man")

## DOPPIO TAP sullo schermo (meta' destra, fuori da bottoni e joystick) =
## SPIN MOVE: il gesto diretto richiesto dall'utente, vale in 5v5 e 1v1.
var _spin_tap_ms := -100000
var _last_touch_ms := -100000

func _input(e: InputEvent) -> void:
	# _input (non _unhandled_input): i tocchi vengono osservati PRIMA della
	# GUI, cosi' il doppio tap funziona anche sopra SHOOT/TRICK e non puo'
	# piu' essere mangiato da nessun Control. Non consumiamo l'evento.
	var pressed: bool = (e is InputEventScreenTouch and e.pressed) \
		or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT)
	if not pressed:
		return
	var now_ms: int = Time.get_ticks_msec()
	if e is InputEventScreenTouch:
		_last_touch_ms = now_ms
	elif now_ms - _last_touch_ms < 80:
		return   # mouse sintetico generato dal tocco Android: non contarlo due volte
	var vp := get_viewport().get_visible_rect().size
	if e.position.x < vp.x * 0.5:
		return   # meta' sinistra: zona joystick
	if now_ms - _spin_tap_ms < 300:
		_spin_tap_ms = -100000
		var u := court.user
		if u != null and u.has_ball and u.do_move("spin"):
			Events.toast.emit("SPIN MOVE")
	else:
		_spin_tap_ms = now_ms

## Ticker dell'obiettivo + completamento live (l'obiettivo legato alla
## vittoria si giudica solo a fine partita).
func _update_goal_tracker() -> void:
	if goal_lbl == null or goal.is_empty() or court.finished:
		return
	goal_lbl.text = "%s · %s" % [Loc.tx("GOAL"), MatchGoals.live_text(goal, court.box, court.score[0], court.score[1])]
	if not goal_done and String(goal["stat"]) != "opp_lt" \
	and MatchGoals.is_done(goal, court.box, court.score[0], court.score[1], false):
		goal_done = true
		goal_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55))
		Events.toast.emit("%s  ·  +%d XP" % [Loc.tx("GOAL COMPLETE"), int(goal["xp"])])

func _guard_up() -> void:
	if court.user:
		court.user.guarding = false

func _dribble_move() -> void:
	## CROSSOVER reads the joystick so the SAME button plays five moves:
	##   neutral   -> crossover (or a hesitation when standing still)
	##   SU        -> behind the back
	##   GIU       -> cambio mano (hand switch)
	##   indietro  -> stepback (pulls away from the hoop)
	## Each one gets its own body-and-ball animation in Player/ Ball.
	var u := court.user
	if u == null:
		return
	if u.has_ball:
		# DOPPIO TAP su TRICK = SPIN MOVE: due pressioni ravvicinate girano il
		# giocatore di 360 gradi attorno al difensore, qualunque sia lo stick.
		var now_ms: int = Time.get_ticks_msec()
		var double_tap: bool = now_ms - _trick_tap_ms < 270
		_trick_tap_ms = now_ms
		if double_tap and u.do_move("spin"):
			Events.toast.emit("SPIN MOVE")
			return
		# Single tap: stick-direction mapping + alternato da fermo, cosi'
		# lo stesso bottone non ripete sempre lo stesso gesto:
		#   still        -> CROSSOVER / TRA LE GAMBE (a rotazione)
		#   stick DOWN   -> hand switch
		#   stick LEFT   -> stepback (hops AWAY from the rim)
		#   stick UP     -> behind the back
		#   otherwise    -> crossover
		var mi: Vector2 = u.move_input
		var kind := "crossover"
		# In area, correndo a canestro, TRICK diventa EUROSTEP: aggiri il
		# difensore con il passo laterale invece del crossover secco.
		if u.court != null:
			var hoop: Vector2 = u.court.hoop_for(u.team)
			var dft: float = u.court.px_to_ft(u.global_position.distance_to(hoop))
			var driving: Vector2 = (hoop - u.global_position).normalized()
			if dft < 14.0 and u.velocity.dot(driving) > 120.0:
				kind = "euro"
		# PARITA' COURT SOLO: niente stick = HESITATION (nel solo non
		# esiste l'alternanza crossover/tra le gambe).
		if mi.length() < 0.25:
			kind = "hesi"
		# POST: entro 12ft con le SPALLE al canestro, TRICK = drop step
		# (giro attorno al difensore verso il ferro). In modalita' POST
		# (bottone) il drop step parte a qualunque distanza utile.
		var hoop_pos: Vector2 = u.court.hoop_for(u.team)
		var to_rim: Vector2 = hoop_pos - u.global_position
		if u.posting \
		or (court.px_to_ft(to_rim.length()) < 12.0 \
		and signf(float(u.facing)) != signf(to_rim.x) and absf(to_rim.x) > 1.0):
			kind = "dropstep"
		elif mi.y > 0.35:
			kind = "hand_switch"
		elif mi.x < -0.35:
			kind = "stepback"
		elif mi.y < -0.35:
			kind = "behind"
		if u.do_move(kind):
			_last_move_ms = Time.get_ticks_msec()
			Events.toast.emit({
				"crossover": "CROSSOVER",
				"stepback": "STEPBACK",
				"behind": "BEHIND THE BACK",
				"hand_switch": "HAND SWITCH",
				"hesi": "HESITATION",
				"between": "THROUGH THE LEGS",
				"euro": "EUROSTEP",
				"dropstep": "DROP STEP",
			}.get(kind, "MOVE"))
		return
	# No ball: CROSSOVER becomes an explosive cut, so the button is never dead.
	# Previously do_move() simply returned and pressing it did nothing at all.
	u.do_cut()

# ------------------------------------------------------------------ events
# ------------------------------------------------------------------ broadcast
## Everything that makes tonight feel like a broadcast: club-coloured floor,
## live commentary, the jumbotron hook and the intro card.
func _setup_broadcast() -> void:
	# Commentary line, bottom centre, its own lane away from toasts.
	lbl_comm = Label.new()
	lbl_comm.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lbl_comm.offset_top = -104.0
	lbl_comm.offset_bottom = -64.0
	lbl_comm.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lbl_comm.add_theme_font_size_override("font_size", 22)
	lbl_comm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_comm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_comm.modulate.a = 0.0
	hud.add_child(lbl_comm)
	commentary = preload("res://src/match/Commentary.gd").new()
	commentary.setup(court, _on_comment)
	add_child(commentary)
	# The maple leans toward whoever owns the building tonight.
	var vis = $CourtVisual
	if vis != null:
		var home: bool = bool(Game.profile.get("next_home", true))
		var club: String = Season.my_team() if home \
			else String(Game.profile.get("next_opponent", ""))
		var kcol: Color = Color(Game.KITS[Season.kit_for(club)]["col"])
		vis.floor_tint = Color(kcol.r, kcol.g, kcol.b, 0.10)
		vis.jumbo_say(Loc.t("jumbo.welcome") % Season.match_arena(), 4.2)
	_build_intro()

## The pre-match card: arena, matchup, records, styles. Pure ceremony — the
## countdown starts the moment it leaves the screen.
func _build_intro() -> void:
	var opp: String = String(Game.profile.get("next_opponent", "Practice Squad"))
	var fixture: bool = bool(Game.profile.get("match_is_fixture", false)) and not court.one_on_one
	intro_panel = Control.new()
	intro_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	intro_panel.gui_input.connect(_intro_input)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_panel.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -420
	v.offset_right = 420
	v.offset_top = -300
	v.offset_bottom = 300
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_panel.add_child(v)
	var arena: String = Season.arena_of(opp) if court.one_on_one else Season.match_arena()
	_big(v, "  " + arena, 24, Color(1.0, 0.82, 0.30))
	_big(v, Loc.t("bc.tonight"), 40, Color(0.965, 0.949, 0.906, 0.5))
	# Matchup row: colour chips flanking both full club names.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	_club(row, Season.my_team(), 0)
	var vs := Label.new()
	vs.text = Loc.t("bc.vs")
	vs.add_theme_font_size_override("font_size", 30)
	vs.modulate = Color(1, 1, 1, 0.45)
	vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(vs)
	_club(row, opp, 1)
	if fixture:
		var r0: Dictionary = Season.record(Season.my_team())
		var r1: Dictionary = Season.record(opp)
		_big(v, "%s   %s" % [Loc.t("bc.record") % [r0["w"], r0["l"]],
			Loc.t("bc.record") % [r1["w"], r1["l"]]], 24, Color(0.965, 0.949, 0.906, 0.6))
		var s0: String = Loc.t("bc.style." + Season.style_of(Season.my_team()))
		var s1: String = Loc.t("bc.style." + Season.style_of(opp))
		_big(v, "%s  vs  %s" % [s0, s1], 20, Color(0.6, 0.9, 1.0, 0.7))
	else:
		_big(v, Loc.t("bc.challenger") if court.one_on_one else Loc.t("bc.scrimmage"),
			24, Color(0.6, 0.9, 1.0, 0.7))
	# OBIETTIVO DI PARTITA: sorteggio individuale, taglio duro; lo completi
	# -> XP extra pagati nel post-game.
	goal = MatchGoals.pick(court.one_on_one, String(Game.profile.get("last_goal", "")))
	Game.profile["last_goal"] = String(goal["id"])
	goal_done = false
	_big(v, Loc.tx("MATCH GOAL") + "  ·  +%d XP" % int(goal["xp"]), 19, Color(1.0, 0.62, 0.25))
	_big(v, MatchGoals.fmt(goal), 26, Color(1.0, 0.86, 0.48))
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 26)
	v.add_child(pad)
	# La difficolta' scelta SI VEDE a ogni kickoff: nessun dubbio che valga
	# anche per l'1v1.
	var dnames: Array = Game.DIFF_NAMES
	var dcol: Color = Color(1, 1, 1, 0.5)
	if Game.difficulty() >= 2:
		dcol = Color(1.0, 0.55, 0.45)
	_big(v, "%s  %s" % [Loc.tx("Difficolta"), String(dnames[Game.difficulty()])],
		19, dcol)
	_big(v, Loc.t("bc.tap"), 19, Color(1, 1, 1, 0.35))
	hud.add_child(intro_panel)
	intro_left = 5.2 if fixture else 3.6
	# Ticker dell'obiettivo: visibile per tutta la partita sotto il punteggio.
	goal_lbl = Label.new()
	# A destra sotto i bottoni: al centro copriva il punteggio.
	goal_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	goal_lbl.position = Vector2(-640, 70)
	goal_lbl.custom_minimum_size = Vector2(600, 0)
	goal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	goal_lbl.add_theme_font_size_override("font_size", 17)
	goal_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	hud.add_child(goal_lbl)

func _club(row: HBoxContainer, cname: String, team: int) -> void:
	var chip := Panel.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Game.team_colour(team)
	cs.set_corner_radius_all(6)
	chip.add_theme_stylebox_override("panel", cs)
	chip.custom_minimum_size = Vector2(16, 46)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chip)
	_big(row, cname, 34, Color(0.965, 0.949, 0.906))

func _big(parent: Node, t: String, size: int, col: Color) -> void:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)

func _intro_input(ev: InputEvent) -> void:
	var tapped: bool = (ev is InputEventScreenTouch and ev.pressed) \
		or (ev is InputEventMouseButton and ev.pressed)
	if tapped and intro_left > 0.0:
		intro_left = 0.0
		_intro_done()

func _intro_done() -> void:
	if intro_panel == null:
		return
	var panel := intro_panel
	intro_panel = null
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 0.0, 0.35)
	tw.tween_callback(panel.queue_free)
	tip_left = 3.0

## The commentator's lane: one line at a time, then it fades.
func _on_comment(txt: String) -> void:
	if lbl_comm == null:
		return
	lbl_comm.text = "  " + txt
	lbl_comm.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(lbl_comm, "modulate:a", 0.0, 0.6)

## Short jumbotron messages on the big plays.
func _jumbo(key: String, secs := 2.6) -> void:
	var vis = $CourtVisual
	if vis != null:
		vis.jumbo_say(Loc.t(key), secs)

func _on_quarter_ended(q: int) -> void:
	## NBA-style break: the play stops and the cheerleaders run onto the court
	## for a ten-second routine before the next quarter tips off.
	intermission_left = 5.0
	court.play_live = false
	court.intermission = true
	var vis = $CourtVisual
	if vis != null:
		vis.cheer_on_court = true
		_big_banner(Loc.tx("END Q%d" % q), Color(1.0, 0.85, 0.35))
		_jumbo(["jumbo.noise", "jumbo.dance", "jumbo.defense"].pick_random(), 3.5)

func _on_score(h: int, a: int) -> void:
	lbl_score.text = "%d - %d" % [h, a]

func _on_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func _on_popup(text: String, world_pos: Vector2, col: Color, big: bool) -> void:
	# Never drop floating words on top of the shooter's own head while the
	# shot meter is up: they hid the meter exactly when you needed to read it.
	if court != null and court.user != null:
		var u: BallPlayer = court.user
		var shooting: bool = u.shot_charge >= 0.0 or u.shot_anim > 0.0 \
			or (meter != null and meter.visible)
		if shooting and world_pos.distance_to(u.global_position) < 190.0:
			return
	var ft: Node2D = preload("res://src/match/FloatingText.gd").new()
	add_child(ft)
	ft.setup(world_pos, text, col, big)

func _call_timeout() -> void:
	if court == null:
		return
	court.call_timeout(0)

func _on_bench_changed(on_bench: bool) -> void:
	if bench_panel != null:
		bench_panel.visible = on_bench
	if not on_bench and sim_to_return:
		sim_to_return = false
		Engine.time_scale = 1.0

func _sim_to_return() -> void:
	sim_to_return = true
	Engine.time_scale = 6.0
	if bench_panel != null:
		bench_panel.visible = false

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Sfx.set_match_live(false)
	Sfx.stop_crowd()

func _on_shot_taken(quality: String, made: bool, pts: int) -> void:
	## Freeze the meter on the verdict so the player can actually read their timing.
	if quality.begins_with("DUNK"):
		# Matches how Court emits it: "DUNK WINDMILL", "DUNK 360", ... The old
		# equality test never fired, so slams lost their big banner.
		_big_banner(Loc.tx("DUNK!"), Color(1.0, 0.78, 0.20))
		_jumbo("jumbo.slam")
		return
	if made and pts >= 3:
		_jumbo("jumbo.three")
	var head: String = quality.split(" / ")[0]
	var col := Color(0.5, 1.0, 0.55) if head == "PERFECT" else Color(1, 0.85, 0.4)
	if head.begins_with("VERY") or head == "LATE" or head == "EARLY":
		col = Color(1, 0.5, 0.4)
	if meter: meter.show_release(head, col)
	# No floating/toast words for the shot verdict: they covered the meter
	# at the exact moment the player reads it. The frozen dot + score popup
	# carry the feedback now.
	if made:
		_on_toast("+%d" % pts)

## A large, short-lived callout across the middle of the screen, for the
## moments that deserve more than a one-line toast.
func _big_banner(text: String, col: Color) -> void:
	if lbl_banner == null:
		return
	lbl_banner.text = text
	lbl_banner.modulate = col
	lbl_banner.scale = Vector2.ONE * 1.5
	lbl_banner.pivot_offset = lbl_banner.size * 0.5
	var tw := create_tween()
	tw.tween_property(lbl_banner, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_property(lbl_banner, "modulate:a", 0.0, 0.4)

func _on_toast(t: String) -> void:
	lbl_toast.text = Loc.tx(t)
	lbl_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(lbl_toast, "modulate:a", 0.0, 0.5)

func _on_finished(res: Dictionary) -> void:
	# Verdetto FINALE sull'obiettivo (qui si giudica anche quello legato alla
	# vittoria) e pagamento dell'XP extra: la busta base e' gia' di Career.
	if not goal.is_empty():
		var sc: Array = res.get("score", [0, 0])
		goal_done = MatchGoals.is_done(goal, court.box, int(sc[0]), int(sc[1]), bool(res.get("won", false)))
		if goal_done:
			Game.add_xp(int(goal["xp"]), "goal")
			Events.toast.emit("%s  ·  +%d XP" % [Loc.tx("GOAL COMPLETE"), int(goal["xp"])])
		res["goal"] = goal
		res["goal_done"] = goal_done
	var panel := preload("res://src/ui/PostGame.tscn").instantiate()
	panel.result = res
	hud.add_child(panel)

func _confirm_exit() -> void:
	## Walking out mid-game forfeits it, so ask first rather than dumping the
	## player back to the city on a mis-tap.
	var p := GamePanel.new().build("Leave the game?", Vector2(720, 380))
	hud.add_child(p)
	p.add_text("You are walking out with the game unfinished. No XP, no pay, and your coach will notice.",
		22, Color(1, 1, 1, 0.8))
	p.add_text("")
	p.add_button("Quit to the city", func():
		Events.toast.emit("You walked out on the game")
		Game.profile["rep"] = maxi(0, int(Game.profile["rep"]) - 2)
		SaveSystem.save_game()
		SceneRouter.goto("res://src/scenes/CityScene.tscn"))
	p.add_button("Keep playing", func(): p.close())
