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
var btn_pnr: TouchButton
var _last_move_ms := -100000              # per la combo TRICK->TIRA (pull-up)
var btn_timeout: Button
var bench_panel: PanelContainer
var sim_to_return := false
var _phase_offence := true
var _phase_init := false
var _phase_hold := 0.0        # debounce: a phase must persist before it sticks
var lbl_score: Label
var lbl_clock: Label
var lbl_shot: Label           # badge del cronometro dei 24 s (rosso sotto i 5)
var lbl_bonus: Label          # badge "BONUS": quale squadra e' in bonus
var _bonus_seen := [false, false]
var momentum_left: ColorRect
var momentum_right: ColorRect
var lbl_toast: Label
var lbl_banner: Label
var lbl_countdown: Label
var stamina_bar: ProgressBar
var rule_panel: PanelContainer
var rule_title: Label
var rule_body: Label
var rule_why: Label                        # la terza riga: IL PERCHE'
var _rule_t := 0.0
var _viol_counts := {}                     # fischi del tempo corrente (riepilogo)
var role_panel: Control
var _role_pending := true
var rules_btn: Button
var pivot_chip: Label                 # "SETTORE CENTRALE · 2 PUNTI" for the user pivot
var _chip_last := "" 
var btn_sub: Button                  # il tasto CAMBIO (sostituzioni dal vivo)
var sub_panel: PanelContainer        # pannello IN CAMPO / PANCHINA
var sub_court_box: VBoxContainer     # chi e' in campo (si ricostruisce all'apertura)
var sub_bench_box: VBoxContainer     # chi e' in panchina
var sub_hint: Label
var _sub_pick: BallPlayer = null     # chi hai scelto di togliere
var rules_panel: PanelContainer
var _rules_open := false
## Broadcast pass: intro card, commentator line, jumbotron hook.
var intro_panel: Control
var intro_left := 0.0
var lbl_comm: Label
var commentary: Node
## 3-2-1 before tip-off, so you can read who you are guarding.
var tip_left := 3.0
## Between-quarters break: the cheerleaders dance ON the court for 10 seconds.
var intermission_left := 0.0
var inbound_veil: ColorRect
var inbound_caption: Label
var inbound_tween: Tween
var _hinted := false          # one-time controls hint when the ball goes live
var _trick_tap_ms := -999     # last TRICK press: double tap = SPIN MOVE
var _neutral_trick_i := 0     # alternato crossover/tra-le-gambe da fermi
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
	Events.rule.connect(_on_rule)
	_build_inbound_transition()
	court.inbound_transition.connect(_on_inbound_transition)
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
	court.countdown_hold = tip_left + 0.5

func _process(delta: float) -> void:
	var u := court.user
	if u == null or stamina_bar == null: return
	if _role_pending:
		return
	_update_rule_card(delta)
	_update_pivot_chip()
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
			court.countdown_hold = tip_left + 0.5
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
				Events.toast.emit("GO!")
				Sfx.play("go")
				Sfx.cheer(false)
				if court.consume_quarter_opening():
					court.start_quarter_inbound()
				else:
					court.play_live = true
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

	# Attack / defence follows who owns the ball as a TEAM, not whether this
	# one player is holding it. Keying it to u.has_ball meant that any time a
	# team-mate had the ball your pad flipped to the defensive set, so the big
	# button was BLOCK -- which only jumps. That is why SHOOT "did nothing" and
	# the player just hopped on the spot.
	var want_phase: bool = _phase_offence
	var h: BallPlayer = court.ball_handler()
	if h != null:
		want_phase = h.team == u.team
	elif court.ball != null and court.ball.live and court.ball.shooter != null:
		# A shot in the air: the shooting team still owns the ball.
		want_phase = court.ball.shooter.team == u.team
	else:
		# Dead ball, inbound, rebound scramble: the POSSESSION decides. This
		# used to force the attacking pad, so while you were defending — a
		# restart, a loose ball, a missed shot — the buttons flipped to
		# SHOOT/PASS and the defensive set vanished.
		want_phase = court.possession == u.team
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
	if btn_sub:
		btn_sub.visible = court.is_fixture and not court.one_on_one \
			and not court.finished and not court.ft_active \
			and sub_panel != null and not sub_panel.visible
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
		lbl_clock.text = "1v1 · primi a %d" % court.target_score
	else:
		var ru: BallPlayer = court.user
		var rinfo := ""
		if ru != null:
			if ru.role == 5:
				rinfo = "   ·   R5 %d/3 %s" % [ru.period_shots, Loc.t("hud.shots")]
			else:
				rinfo = "   ·   R%d %d/3 %s" % [ru.role, ru.period_makes, Loc.t("hud.makes")]
		var hhp: BallPlayer = court.ball_handler()
		if hhp != null and hhp.has_ball and hhp.pivot_clock > 0.0:
			rinfo += "   ·   " + Loc.t("hud.pivotclk") % int(ceil(hhp.pivot_clock))
		lbl_clock.text = ("T%d  %02d:%02d%s" % [court.quarter,
			int(court.game_clock) / 60, int(court.game_clock) % 60, rinfo]
			+ "   ·   " + Loc.t("match.fouls") % [court.team_fouls[0], court.team_fouls[1]])
	_sync_bonus_badge()
	# Gli ultimi 5 secondi del cronometro si VEDONO (rosso) e si SENTONO (un
	# beep per secondo): prima scadevano in silenzio mentre guardavi la palla.
	var sc_left: int = int(ceil(court.shot_clock))
	_flash_clock(sc_left, court.play_live and not court.ft_active)
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
	var mft: float = court.px_to_ft(u.global_position.distance_to(court.attack_hoop_for(u)))
	var mw: Dictionary = ShotSystem.shot_windows(mft, court.user_heat)
	meter.perfect_window = float(mw["perfect"])
	meter.good_window = float(mw["good"])
	_place_meter()
	if not court.one_on_one and u.has_ball:
		court.update_pass_aim(u, u.move_input)
	else:
		court.aimed = null

func _show_first_hint() -> void:
	await get_tree().create_timer(1.8).timeout
	var r := court.user.role if court != null and court.user != null else 5
	Events.toast.emit(Loc.t("role.%d.hint" % r))
	# Second beat: tell a first-timer where the quick rules card lives.
	await get_tree().create_timer(2.8).timeout
	if court != null and is_instance_valid(court) and not court.finished:
		Events.toast.emit(Loc.t("rules.firsthint"))

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
		var club: String = Game.club_my_team() if team == 0 \
			else String(Game.profile.get("next_opponent", "Practice Squad"))
		tn.text = Game.club_short(club)
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
	# Il CRONOMETRO ha il suo badge: negli ultimi 5 secondi diventa rosso e
	# pulsa, senza tingere di rosso tutta la riga di stato (che deve restare
	# leggibile: tempo, parziali, falli).
	lbl_shot = Label.new()
	lbl_shot.text = ""
	lbl_shot.add_theme_font_size_override("font_size", 26)
	lbl_shot.add_theme_color_override("font_color", Color(0.965, 0.949, 0.906, 0.80))
	lbl_shot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_shot.custom_minimum_size = Vector2(76, 0)
	lbl_shot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crow.add_child(lbl_shot)
	crow.move_child(lbl_shot, 0)
	# BADGE DEL BONUS: dal 5o fallo di squadra ogni fallo vale 2 tiri liberi per
	# chi lo subisce. Il badge mostra la squadra IN BONUS (quella che tira) e
	# resta nascosto finche' nessuna ci arriva: niente rumore per niente.
	lbl_bonus = Label.new()
	lbl_bonus.text = ""
	lbl_bonus.add_theme_font_size_override("font_size", 22)
	lbl_bonus.add_theme_color_override("font_color", Color(0.965, 0.949, 0.906, 0.80))
	lbl_bonus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_bonus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_bonus.custom_minimum_size = Vector2(150, 0)
	lbl_bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_bonus.visible = false
	crow.add_child(lbl_bonus)
	crow.move_child(lbl_bonus, 1)

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

	# "What is my shot worth right now?" — the pivot's value chip, dead centre
	# under the score bug. It teaches the sector rule without a tutorial.
	pivot_chip = Label.new()
	pivot_chip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	pivot_chip.position = Vector2(0, 100)
	pivot_chip.custom_minimum_size = Vector2(0, 30)
	pivot_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pivot_chip.add_theme_font_size_override("font_size", 21)
	pivot_chip.add_theme_color_override("font_color", Color(1.0, 0.84, 0.40))
	pivot_chip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	pivot_chip.add_theme_constant_override("shadow_offset_y", 2)
	pivot_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_chip.visible = false
	hud.add_child(pivot_chip)

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

	# SOSTITUZIONI DAL VIVO: il tasto apre la panchina (solo 5v5).
	btn_sub = Button.new()
	btn_sub.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_sub.position = Vector2(-206, 70)
	btn_sub.custom_minimum_size = Vector2(188, 46)
	btn_sub.add_theme_font_size_override("font_size", 17)
	btn_sub.text = Loc.t("match.sub")
	btn_sub.pressed.connect(_open_subs)
	hud.add_child(btn_sub)

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

	# SOSTITUZIONI: pannello con le due liste (in campo / panchina).
	sub_panel = PanelContainer.new()
	sub_panel.set_anchors_preset(Control.PRESET_CENTER)
	sub_panel.offset_left = -430
	sub_panel.offset_right = 430
	sub_panel.offset_top = -230
	sub_panel.offset_bottom = 230
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.06, 0.07, 0.10, 0.95)
	ss.set_corner_radius_all(16)
	ss.set_border_width_all(2)
	ss.border_color = Color(0.949, 0.420, 0.114, 0.55)
	ss.content_margin_left = 18; ss.content_margin_right = 18
	ss.content_margin_top = 12; ss.content_margin_bottom = 12
	sub_panel.add_theme_stylebox_override("panel", ss)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	sub_panel.add_child(sv)
	var st := Label.new()
	st.text = Loc.t("match.sub.title")
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.add_theme_font_size_override("font_size", 24)
	sv.add_child(st)
	sub_hint = Label.new()
	sub_hint.text = Loc.t("match.sub.hint")
	sub_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_hint.add_theme_font_size_override("font_size", 15)
	sub_hint.modulate = Color(1, 1, 1, 0.78)
	sv.add_child(sub_hint)
	var sh := HBoxContainer.new()
	sh.alignment = BoxContainer.ALIGNMENT_CENTER
	sh.add_theme_constant_override("separation", 26)
	sv.add_child(sh)
	var col_a := VBoxContainer.new()
	col_a.add_theme_constant_override("separation", 6)
	sh.add_child(col_a)
	var la := Label.new()
	la.text = Loc.t("match.sub.oncourt")
	la.add_theme_font_size_override("font_size", 17)
	col_a.add_child(la)
	sub_court_box = VBoxContainer.new()
	sub_court_box.add_theme_constant_override("separation", 6)
	col_a.add_child(sub_court_box)
	var col_b := VBoxContainer.new()
	col_b.add_theme_constant_override("separation", 6)
	sh.add_child(col_b)
	var lb := Label.new()
	lb.text = Loc.t("match.sub.bench")
	lb.add_theme_font_size_override("font_size", 17)
	col_b.add_child(lb)
	sub_bench_box = VBoxContainer.new()
	sub_bench_box.add_theme_constant_override("separation", 6)
	col_b.add_child(sub_bench_box)
	var scl := Button.new()
	scl.text = Loc.t("match.sub.close")
	scl.custom_minimum_size = Vector2(0, 48)
	scl.pressed.connect(func(): sub_panel.visible = false)
	sv.add_child(scl)
	sub_panel.visible = false
	hud.add_child(sub_panel)

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

	_build_rule_card()
	_build_role_picker()
	_build_rules_ref()
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
	if court._inbound_preparing or court.inbound_wait > 0.0:
		if u == court._inbounder:
			court._finish_inbound(null)
		else:
			court.request_pass(u)
		return
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
	# COMBO PULL-UP (da Hoop City): un TRICK seguito da TIRA entro mezzo
	# secondo = tiro in slancio (popup visibile, timing leggermente severo).
	u.combo_pullup = u.has_ball and Time.get_ticks_msec() - _last_move_ms < 500 \
		and not court.ft_active
	if u.can_dunk():
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
	var ft := court.px_to_ft(u.global_position.distance_to(court.attack_hoop_for(u)))
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
	u.do_shot_release()

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

## ---------------------------------------------------- sostituzioni dal vivo
## Il pannello dei cambi: a sinistra chi e' in campo, a destra chi aspetta in
## panchina. Scegli chi esce, poi chi entra: il cambio si esegue alla prima
## palla morta, con i due che si incrociano a piedi.
func _open_subs() -> void:
	if court == null or court.finished:
		return
	if court.available_sub_seats().is_empty() and _sub_pick == null:
		Events.toast.emit(Loc.t("t.sub.none"))
		return
	if rules_panel != null and rules_panel.visible:
		rules_panel.visible = false
		_rules_open = false
	_sub_pick = null
	_fill_subs()
	sub_panel.visible = true

func _fill_subs() -> void:
	for b in sub_court_box.get_children():
		b.queue_free()
	for b in sub_bench_box.get_children():
		b.queue_free()
	if court == null:
		return
	for p in court.players:
		if p.team != 0:
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(250, 46)
		b.add_theme_font_size_override("font_size", 16)
		b.text = "R%d  #%d  %s   %d%%" % [p.role, p.jersey_num,
			p.display_name, int(round(p.stamina))]
		if p.is_user:
			b.text += "  (you)"
		var who: BallPlayer = p
		b.pressed.connect(func():
			_sub_pick = who
			sub_hint.text = Loc.t("match.sub.hint2") % who.jersey_num)
		sub_court_box.add_child(b)
	var seats: Array = court.available_sub_seats()
	if seats.is_empty():
		var l := Label.new()
		l.text = Loc.t("t.sub.none")
		l.add_theme_font_size_override("font_size", 15)
		sub_bench_box.add_child(l)
	for seat in seats:
		var r: Dictionary = court.bench_roster[0][seat]
		var b := Button.new()
		b.custom_minimum_size = Vector2(210, 46)
		b.add_theme_font_size_override("font_size", 16)
		b.text = "#%d  %s" % [int(r["jersey"]), String(r["name"])]
		var sd: int = int(seat)
		b.pressed.connect(func():
			if _sub_pick == null:
				sub_hint.text = Loc.t("match.sub.pick")
				return
			if court.request_sub(_sub_pick, sd):
				sub_panel.visible = false
			else:
				sub_hint.text = Loc.t("t.sub.none"))
		sub_bench_box.add_child(b)
	sub_hint.text = Loc.t("match.sub.hint")

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
		if mi.length() < 0.25:
			_neutral_trick_i += 1
			kind = "crossover" if _neutral_trick_i % 2 == 0 else "between"
		elif mi.y > 0.35:
			kind = "hand_switch"
		elif mi.x < -0.35:
			kind = "stepback"
		elif mi.y < -0.35:
			kind = "behind"
		elif mi.x > 0.35:
			kind = "euro"      # EUROSTEP a due tempi (da Hoop City)
		if u.do_move(kind):
			_last_move_ms = Time.get_ticks_msec()
			Events.toast.emit({
				"crossover": "CROSSOVER",
				"stepback": "STEPBACK",
				"behind": "BEHIND THE BACK",
				"hand_switch": "HAND SWITCH",
				"hesi": "HESITATION",
				"between": "THROUGH THE LEGS",
				"euro": "EURO STEP",
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
		var club: String = Game.club_my_team() if home \
			else String(Game.profile.get("next_opponent", ""))
		var kcol: Color = Color(Game.KITS[Game.club_kit(club)]["col"])
		vis.floor_tint = Color(kcol.r, kcol.g, kcol.b, 0.10)
		vis.jumbo_say(Loc.t("jumbo.welcome") % Game.scrim_arena(), 4.2)
	# The pre-match card with the club names is gone: the players asked for it
	# to be taken out, so the 3-2-1 countdown starts the moment the court loads.
	intro_panel = null
	intro_left = 0.0

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
	var arena: String = Game.club_arena(opp) if court.one_on_one else Game.scrim_arena()
	_big(v, "  " + arena, 24, Color(1.0, 0.82, 0.30))
	_big(v, Loc.t("bc.tonight"), 40, Color(0.965, 0.949, 0.906, 0.5))
	# Matchup row: colour chips flanking both full club names.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	_club(row, Game.club_my_team(), 0)
	var vs := Label.new()
	vs.text = Loc.t("bc.vs")
	vs.add_theme_font_size_override("font_size", 30)
	vs.modulate = Color(1, 1, 1, 0.45)
	vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(vs)
	_club(row, opp, 1)
	if fixture:
		var s0: String = Loc.t("bc.style." + Game.club_style(Game.club_my_team()))
		var s1: String = Loc.t("bc.style." + Game.club_style(opp))
		_big(v, "%s  vs  %s" % [s0, s1], 20, Color(0.6, 0.9, 1.0, 0.7))
	else:
		_big(v, Loc.t("bc.challenger") if court.one_on_one else Loc.t("bc.scrimmage"),
			24, Color(0.6, 0.9, 1.0, 0.7))
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 26)
	v.add_child(pad)
	_big(v, Loc.t("bc.tap"), 19, Color(1, 1, 1, 0.35))
	hud.add_child(intro_panel)
	intro_left = 5.2 if fixture else 3.6

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
	court.countdown_hold = tip_left + 0.5

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
		_big_banner(Loc.t("match.endperiod") % maxi(1, q - 1), Color(1.0, 0.85, 0.35))
		_jumbo(["jumbo.noise", "jumbo.dance", "jumbo.defense"].pick_random(), 3.5)
	# RIEPILOGO DIDATTICO: i fischi del tempo appena finito, contati. Resta
	# su 9 secondi (le card normali 6,5): e' il momento in cui il giocatore
	# riflette su cosa e' andato storto -- e REGOLE e' a un tocco.
	if not _viol_counts.is_empty() and rule_title != null:
		var parts: PackedStringArray = []
		var keys := _viol_counts.keys()
		keys.sort()
		for k in keys:
			parts.append("%d× %s" % [int(_viol_counts[k]), Loc.t("rule." + k, k)])
		rule_title.text = Loc.t("rules.whistle_h") % maxi(1, q - 1)
		rule_body.text = " · ".join(parts) + "\n" + Loc.t("rules.whistle_hint")
		if rule_why != null:
			rule_why.text = ""
		rule_panel.visible = true
		rule_panel.modulate.a = 1.0
		_rule_t = 9.0
		_viol_counts.clear()

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

var _clock_beep := -1
## Il badge del cronometro: mostra gli ultimi secondi in grande, rosso e
## pulsante, e suona un beep per secondo. Fuori dagli ultimi 5 secondi resta
## discreto, cosi' la riga di stato non urla quando non c'e' niente da dire.
## Chi e' in bonus tira i liberi: il badge lo dice a chiare lettere, nel colore
## della squadra che VANTAGGIA (quella che subisce i falli). La prima volta che
## una squadra ci arriva lo dice anche a voce, perche' cambia le regole in campo.
func _sync_bonus_badge() -> void:
	if lbl_bonus == null or court == null:
		return
	var in_pen := [false, false]     # squadra che ha commesso il 5o fallo
	for t in 2:
		if court.team_fouls[t] >= 5:
			in_pen[t] = true
			if not _bonus_seen[t]:
				_bonus_seen[t] = true
				var who: String = _team_short(1 - t)   # chi tira i liberi
				Events.toast.emit(Loc.t("t.bonus.team") % who)
	# I falli di squadra si azzerano a ogni quarto: anche l'avviso deve poter
	# tornare a suonare (altrimenti la seconda volta nessuno te lo dice).
	for t in 2:
		if not in_pen[t]:
			_bonus_seen[t] = false
	# BONUS (t) = la squadra t e' in bonus, cioe' TIRA i liberi se subisce fallo.
	var valide: Array = []
	for t in 2:
		if in_pen[1 - t]:
			valide.append(t)
	if valide.is_empty():
		lbl_bonus.visible = false
		return
	var names := ""
	for t in valide:
		names += _team_short(t) if names == "" else "·" + _team_short(t)
	lbl_bonus.text = Loc.t("hud.bonus") % names
	var col: Color = Game.team_colour(int(valide[0]))
	if valide.size() == 2:
		col = Color(1.0, 0.78, 0.30)
	var pulse: float = 0.80 + 0.20 * absf(sin(Time.get_ticks_msec() / 420.0))
	lbl_bonus.modulate = Color(col.r, col.g, col.b, 0.62 + 0.38 * pulse)
	lbl_bonus.visible = true

func _team_short(team: int) -> String:
	var club: String = Game.club_my_team() if team == 0 \
		else String(Game.profile.get("next_opponent", "Practice Squad"))
	return Game.club_short(club)

func _flash_clock(secs: int, running: bool) -> void:
	if lbl_shot == null:
		return
	var urgent: bool = running and secs <= 5 and secs > 0
	lbl_shot.text = "%02d" % maxi(secs, 0)
	if not urgent:
		lbl_shot.modulate = Color(1, 1, 1, 0.62)
		_clock_beep = -1
		return
	var pulse: float = 0.75 + 0.25 * absf(sin(Time.get_ticks_msec() / 160.0))
	lbl_shot.modulate = Color(1.0, 0.30 + 0.18 * pulse, 0.26, pulse)
	if secs != _clock_beep:
		_clock_beep = secs
		Sfx.play("beep", -9.0)

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
	if made:
		Sfx.haptic(50)
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
	var panel := preload("res://src/ui/PostGame.tscn").instantiate()
	panel.result = res
	hud.add_child(panel)

func _confirm_exit() -> void:
	## Walking out mid-game abandons it, so ask first rather than dumping the
	## player back to the menu on a mis-tap.
	if rules_panel != null and rules_panel.visible:
		rules_panel.visible = false
		_rules_open = false
	var p := GamePanel.new().build(Loc.t("exit.title"), Vector2(720, 380))
	hud.add_child(p)
	p.add_text(Loc.t("exit.body"), 22, Color(1, 1, 1, 0.8))
	p.add_text("")
	p.add_button(Loc.t("exit.confirm"), func():
		Events.toast.emit(Loc.t("exit.toast"))
		SaveSystem.save_game()
		SceneRouter.goto(SceneRouter.MENU))
	p.add_button(Loc.t("exit.keep"), func(): p.close())

# ---------------------------------------------------------- baskin teaching
func _build_inbound_transition() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 25
	add_child(layer)
	inbound_veil = ColorRect.new()
	inbound_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inbound_veil.color = Color(0.025, 0.045, 0.07, 0.96)
	inbound_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inbound_veil.modulate.a = 0.0
	layer.add_child(inbound_veil)
	inbound_caption = Label.new()
	inbound_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inbound_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inbound_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inbound_caption.add_theme_font_size_override("font_size", 28)
	inbound_caption.add_theme_color_override("font_color", Color(1.0, 0.78, 0.40))
	inbound_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inbound_veil.add_child(inbound_caption)

func _on_inbound_transition(_duration: float) -> void:
	if is_instance_valid(inbound_tween): inbound_tween.kill()
	inbound_caption.text = Loc.t("match.inbound.transition")
	inbound_veil.modulate.a = 0.0
	inbound_tween = create_tween()
	inbound_tween.tween_property(inbound_veil, "modulate:a", 1.0, Court.INBOUND_FADE_IN).set_trans(Tween.TRANS_SINE)
	inbound_tween.tween_property(inbound_veil, "modulate:a", 0.0, Court.INBOUND_FADE_OUT).set_trans(Tween.TRANS_SINE)

func _build_rule_card() -> void:
	## The contextual rule explainer: top-right, shows the rule behind every
	## whistle and every basket, in the player's language.
	rule_panel = PanelContainer.new()
	rule_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rule_panel.offset_left = -396.0
	rule_panel.offset_right = -12.0
	rule_panel.offset_top = 76.0
	rule_panel.offset_bottom = 260.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.12, 0.88)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.82, 0.35, 0.6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	rule_panel.add_theme_stylebox_override("panel", sb)
	rule_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule_panel.add_child(vb)
	rule_title = Label.new()
	rule_title.add_theme_font_size_override("font_size", 21)
	rule_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
	rule_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(rule_title)
	rule_body = Label.new()
	rule_body.add_theme_font_size_override("font_size", 17)
	rule_body.add_theme_color_override("font_color", Color(0.93, 0.94, 0.97))
	rule_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_body.custom_minimum_size = Vector2(356, 0)
	rule_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(rule_body)
	# IL PERCHE' della regola (didattica): piu' piccolo, color sabbia, e
	# invisibile quando la regola non ha un perche' scritto.
	rule_why = Label.new()
	rule_why.add_theme_font_size_override("font_size", 14)
	rule_why.add_theme_color_override("font_color", Color(1.0, 0.72, 0.45, 0.95))
	rule_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_why.custom_minimum_size = Vector2(356, 0)
	rule_why.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(rule_why)
	rule_panel.visible = false
	rule_panel.modulate.a = 0.0
	hud.add_child(rule_panel)

func _on_rule(key: String) -> void:
	if rule_title == null:
		return
	rule_title.text = Loc.t("rule." + key, key)
	rule_body.text = Loc.t("rule." + key + ".body", "")
	if rule_why != null:
		rule_why.text = Loc.t("rule." + key + ".why", "")
	rule_panel.visible = true
	rule_panel.modulate.a = 1.0
	_rule_t = 6.5
	# Il fischio si sente ANCHE in mano; e ogni violazione finisce nel
	# riepilogo di fine tempo (imparare dai propri errori).
	if key.begins_with("v_"):
		Sfx.haptic(50)
		_viol_counts[key] = int(_viol_counts.get(key, 0)) + 1

func _update_rule_card(delta: float) -> void:
	if rule_panel == null or not rule_panel.visible:
		return
	_rule_t -= delta
	if _rule_t <= 0.0:
		rule_panel.visible = false
	elif _rule_t < 1.0:
		rule_panel.modulate.a = _rule_t

func _build_role_picker() -> void:
	## The role is chosen on the pre-match screen; this picker is only a
	## fallback when no role was stored (old saves, direct scene runs).
	var pr := clampi(int(Game.profile.get("baskin_role", 0)), 0, 5)
	if pr >= 1:
		_role_pending = false
		return
	role_panel = Control.new()
	role_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	role_panel.add_child(dim)
	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.offset_left = -330
	pc.offset_right = 330
	pc.offset_top = -300
	pc.offset_bottom = 300
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.12, 0.97)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.82, 0.35, 0.65)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	pc.add_theme_stylebox_override("panel", sb)
	role_panel.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)
	var title := Label.new()
	title.text = Loc.t("role.pick")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
	vb.add_child(title)
	for r in [1, 2, 3, 4, 5]:
		var b := Button.new()
		b.text = Loc.t("role.%d" % r) + "\n" + Loc.t("role.%d.d" % r)
		b.custom_minimum_size = Vector2(580, 84)
		b.add_theme_font_size_override("font_size", 17)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var rr: int = r
		b.pressed.connect(func(): _pick_role(rr))
		vb.add_child(b)
	hud.add_child(role_panel)

func _pick_role(r: int) -> void:
	court.assign_user_role(r)
	_role_pending = false
	if role_panel != null:
		role_panel.visible = false
	Sfx.play("go", -4.0)

func _build_rules_ref() -> void:
	## Top-left RULES button + scrollable rules reference. The game keeps
	## running: it is a quick reference, not a pause menu.
	rules_btn = Button.new()
	rules_btn.text = Loc.t("rules.btn")
	# A SINISTRA (playtest: a destra si confondeva con TIMEOUT e CAMBIO),
	# sotto ESCI.
	rules_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rules_btn.position = Vector2(18, 72)
	rules_btn.custom_minimum_size = Vector2(96, 50)
	rules_btn.add_theme_font_size_override("font_size", 18)
	rules_btn.pressed.connect(_toggle_rules)
	hud.add_child(rules_btn)
	rules_panel = PanelContainer.new()
	# Il pannello sta SOPRA ogni altro controllo dell'HUD (z_index alto):
	# prima i bottoni aggiunti dopo lo disegnavano attraversato.
	rules_panel.z_index = 60
	rules_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rules_panel.offset_left = 12.0
	rules_panel.offset_top = 130.0
	rules_panel.offset_right = 430.0
	rules_panel.offset_bottom = 640.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.12, 0.93)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.45, 0.85, 1.0, 0.6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	rules_panel.add_theme_stylebox_override("panel", sb)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(390, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rules_panel.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)
	_rules_line(vb, Loc.t("rules.title"), 24, Color(1.0, 0.85, 0.40))
	_rules_line(vb, Loc.t("rules.court_h"), 18, Color(0.55, 0.85, 1.0))
	_rules_line(vb, Loc.t("rules.court"), 15, Color(0.93, 0.94, 0.97))
	for r in [1, 2, 3, 4, 5]:
		_rules_line(vb, Loc.t("role.%d" % r), 18, Color(1.0, 0.86, 0.45))
		_rules_line(vb, Loc.t("role.%d.d" % r), 15, Color(0.93, 0.94, 0.97))
	_rules_line(vb, Loc.t("rules.score_h"), 18, Color(0.55, 0.85, 1.0))
	_rules_line(vb, Loc.t("rules.score"), 15, Color(0.93, 0.94, 0.97))
	_rules_line(vb, Loc.t("rules.viol_h"), 18, Color(0.55, 0.85, 1.0))
	_rules_line(vb, Loc.t("rules.viol"), 15, Color(0.93, 0.94, 0.97))
	_rules_line(vb, Loc.t("rules.hint"), 14, Color(1, 1, 1, 0.55))
	rules_panel.visible = false
	hud.add_child(rules_panel)

## Live "shot value" readout for the human pivot: role 1 sees which attempt
## he is on (3 then 2), role 2 sees the sector he stands in (central 2 /
## lateral 3) or a prompt to step out, role 3 near the side area sees the 2.
func _update_pivot_chip() -> void:
	if pivot_chip == null or court == null or court.user == null:
		return
	var u: BallPlayer = court.user
	var txt := ""
	if not court.one_on_one and u.has_ball and not court.ft_active and not u.own_miss_rebound:
		var hoop: Vector2 = court.side_hoops[u.team]
		if u.role == 1:
			txt = Loc.t("chip.r1a") if u.pivot_attempts == 0 else Loc.t("chip.r1b")
		elif u.role == 2:
			var need: float = Court.SIDE_DASH_R if u.variant == "2R" else Court.SIDE_AREA_R
			if u.global_position.distance_to(hoop) < need:
				txt = Loc.t("chip.r2out")
			elif court.in_central_sector(u.global_position, hoop):
				txt = Loc.t("chip.r2c")
			else:
				txt = Loc.t("chip.r2l")
		elif u.role == 3 and u.global_position.distance_to(hoop) < 360.0:
			txt = Loc.t("chip.r3")
	if txt != _chip_last:
		_chip_last = txt
		pivot_chip.text = txt
		pivot_chip.visible = txt != ""

func _rules_line(parent: Control, text: String, sz: int, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(362, 0)
	parent.add_child(l)

func _toggle_rules() -> void:
	_rules_open = not _rules_open
	if rules_panel != null:
		rules_panel.visible = _rules_open
	Sfx.play("go", -8.0)
