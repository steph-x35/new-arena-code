extends Node2D
class_name Court
## Owns the rules: possession, shot clock, rebounds, fouls, inbounds, scoring.
## Also the referee for ball<->rim/backboard collisions.

## A FIBA court is 28 x 15 m. At PX_PER_FT = 19 that is 1746 x 935 px, a 1.87
## ratio. The old 1800x620 was 2.90 -- far too letterboxed to read as a real
## floor -- and a 1800 px width is 94.7 ft (an NBA court), which puts the corner
## three OUTSIDE the 6.75 m arc so the lines can never physically meet.
const COURT_W := 1746.0
const COURT_H := 935.0

# --- FIBA geometry in px, all derived from the scale above ----------------
const FIBA_ARC_R := 421.0        # 6.75 m three-point radius
const FIBA_CORNER_INSET := 56.0  # 0.90 m from the sideline
const FIBA_PAINT_W := 305.0      # 4.9 m key width
const FIBA_HOOP_INSET := 98.0    # 1.575 m from the baseline to rim centre
const FT_PX := 263.0             # rim to FT line (FIBA 4.225 m)
const FIBA_KEY_LEN := 362.0      # baseline to FT line (FIBA 5.80 m)
const FIBA_RESTRICTED := 78.0    # 1.25 m no-charge arc
const FIBA_CENTRE_R := 112.0     # 1.8 m centre circle
## FIBA three-point distance in feet (NBA is 23.75). Defined in ShotSystem,
## which is node-free and unit-testable; re-exported here for convenience.
const THREE_FT := ShotSystem.THREE_FT
const RIM_HEIGHT := 188.0          # px above the floor — the pole must read as 3.05 m tall
# A match player is drawn 56 px tall (~1.93 m). The rim is raised well above
# him so the 3.05 m height reads clearly even in the tilted side view: the
# pole, the board and the open ring visibly hang ABOVE the floor, and the
# player must JUMP to get his hand on the iron.
const PX_PER_FT := 19.0
## One basketball, one size: ~13% of a 54 px player (real 24 cm / 1.9 m).
const BALL_R := 7.0
const QUARTER_SECONDS := 120.0
const QUARTERS := 4

@export var team_size := 5          # 5v5, full sides

## 1v1 street rules: half court, first to `target_score`, make-it-take-it,
## and the ball must be cleared past the arc after a change of possession.
@export var one_on_one := false
@export var target_score := 11
var must_clear := false             # true until the new offense clears the arc

var ball: Ball
var players: Array[BallPlayer] = []
var user: BallPlayer

var score := [0, 0]
var user_streak := 0            # HEAT CHECK: canestri utente di fila
var user_heat := false          # in fuoco: finestra verde piu' larga
# --- broadcast book-keeping (fed by _add_score, read by the post-game card) ---
var _q_pts := [0, 0]        # points scored in the CURRENT quarter [team0, team1]
var _q_log := []            # finished quarters, [[h,a], ...]
var _run_team := -1         # side of the current scoring run (-1 = none)
var _run_pts := 0
var _run_q := 1
var _run_said := false      # the live commentary line for this run already fired
var _best_run := {}         # biggest completed run of the match
var possession := 0
var play_live := false
var shot_clock := 18.0
var quarter_len := 120.0               # configurable quarter length (profile)
var game_clock := 120.0
var quarter := 1
var momentum := 0.0                 # -1..1, swings with runs
var box := {"pts": 0, "ast": 0, "reb": 0, "stl": 0, "blk": 0, "tov": 0, "fga": 0, "fgm": 0, "tpa": 0, "tpm": 0}
var last_passer: BallPlayer = null
var last_pass_time := 0.0
var finished := false
var total_attempts := 0
var total_makes := 0
var _dead_time := 0.0               # watchdog accumulator, see _deadball_watchdog
var restarting := false             # true during a scripted inbound/check pause
var awaiting_check := false         # 1v1: CHECK button before the ball is live
var inbound_wait := 0.0             # >0: your inbound, call it or it auto-passes
var intermission := false           # between quarters: teams jog to huddles
var _voice_cd := {}                 # per-shout cooldowns
var _shoot_call := false            # one "shoot!" per possession
var _inbounder: BallPlayer = null
var _inbound_receiver: BallPlayer = null
var pnr_screening := false
var jump_pending := false      # true: al GO si esegue la palla a due
var _jump_run := false
var _jump_watch := 0.0
## The team-mate who actually set the screen (so the roll goes to HIM, not to
## whichever player the old loop happened to meet first -- that bug left the
## real screener planted forever while a random cutter "rolled").
var pnr_screener: BallPlayer = null
var pnr_timer := 0.0          ## screen window; expiry auto-rolls the screener
var pnr_roller: BallPlayer = null
var roller_t := 0.0
var aimed: BallPlayer = null        # teammate the joystick is pointing at

# --- v1.9: benches, coach rotation, timeouts --------------------------------
## True only for real fixtures (career game / quick game), never a scrimmage:
## benches are filled, the coach rotates you, the stands fill up.
var is_fixture := false
signal bench_changed(on_bench: bool)
var bench_roster := [[], []]        # reserve dicts per team {jersey, name}
var bench_seats_vis := []           # what CourtVisual draws: seated people
var bench_version := 0              # bumped so CourtVisual redraws
var user_on_court := true
var sub_partner: BallPlayer = null  # reserve currently playing the user's spot
var played_time := 0.0
var benched_time := 0.0
var eval_t := 0.0
var bench_request := false          # waiting for a safe moment to sub out
var unbench_request := false
var timeouts_left := [2, 2]
var script_idx := 0                    # guaranteed rotation: the coach ALWAYS
var script_plan := []                  # rests you at least twice per game
var timeout_active := 0.0           # real seconds of the stoppage
var timeout_team := 0
const USER_SEAT := 0                # the user's bench seat index (team 0)
const PARTNER_SEAT := 4             # where the sub walks in from

# --- free throws: a foul stops the clock and sends the fouled man to the line
var ft_active := false
var ft_shooter: BallPlayer = null
var ft_total := 0
var ft_left := 0
var ft_timer := 0.0                 # NPC routine timer, see _process

var hoops := [Vector2(-COURT_W * 0.5 + FIBA_HOOP_INSET, 0), Vector2(COURT_W * 0.5 - FIBA_HOOP_INSET, 0)]

func _ready() -> void:
	randomize()
	if Game.profile.has("next_match_mode") and String(Game.profile["next_match_mode"]) == "1v1":
		one_on_one = true
	if one_on_one:
		team_size = 1
		# Both players attack the SAME rim in a half-court game.
		hoops = [Vector2(COURT_W * 0.5 - FIBA_HOOP_INSET, 0), Vector2(COURT_W * 0.5 - FIBA_HOOP_INSET, 0)]
	_build_ball()
	_spawn_teams()
	if not one_on_one:
		_spawn_referees()
	quarter_len = float(Game.profile.get("quarter_seconds", 120.0))
	game_clock = quarter_len
	is_fixture = (not one_on_one) and bool(Game.profile.get("match_is_fixture", false))
	if is_fixture:
		_build_bench_roster()
		_refresh_bench_vis()
		var qs := quarter_len
		script_plan = [
			{"t": qs + 6.0, "a": 0},        # early Q2: planned rest
			{"t": qs + 61.0, "a": 1},       # back in before the half
			{"t": qs * 2.0 + 50.0, "a": 0}, # mid Q3 breath
			{"t": qs * 2.0 + 92.0, "a": 1}, # in for the stretch run
		]
	_tipoff()

var _refs: Array = []

func _spawn_referees() -> void:
	for s in [-1.0, 1.0]:
		var r := preload("res://src/match/Referee.gd").new()
		add_child(r)
		r.setup(s)
		_refs.append(r)

func _build_ball() -> void:
	ball = preload("res://src/match/Ball.gd").new()
	add_child(ball)

func _spawn_teams() -> void:
	for t in 2:
		for i in team_size:
			var p := preload("res://src/match/Player.gd").new()
			p.team = t
			p.jersey_num = 3 + i * 4 + t
			add_child(p)
			if t == 0 and i == 0:
				p.is_user = true
				p.hair_style_v = Game.hair_style()
				p.setup_from_profile()
				user = p
			else:
				_randomize_npc(p, t)
				var brain := preload("res://src/match/AIBrain.gd").new()
				p.add_child(brain)
				brain.setup(p, self)
			p.global_position = _formation_pos(t, i)
			players.append(p)

func _randomize_npc(p: BallPlayer, t: int) -> void:
	var lvl: int = 48 + int(Game.profile["level"]) * 2
	if bool(Game.profile.get("playoff", {}).get("live", false)):
		lvl += 8   # i playoff si giocano contro squadre al top
	for k in p.ratings:
		p.ratings[k] = clampi(lvl + randi_range(-12, 14), 30, 92)
	# The opposing CLUB has a style of play: ratings tilt gently toward it and
	# the roster draws from that club's name pool, so playing at the Foundry
	# against the Kings reads (and plays) differently than hosting the Tide.
	var pool := ["Ferro", "Vance", "Okoye", "Marek", "Silva", "Duarte", "Bran", "Kolo"]
	if t == 1:
		var opp: String = String(Game.profile.get("next_opponent", ""))
		var tilt: Array = {
			"run": ["speed", "stamina"], "lock": ["defense", "steal"],
			"inside": ["close", "rebound"], "grit": ["rebound", "block"],
		}.get(Season.style_of(opp), [])
		for k in tilt:
			p.ratings[k] = clampi(int(p.ratings[k]) + 6, 30, 95)
		var club_names: Array = Season.roster_names(opp)
		if not club_names.is_empty():
			pool = club_names
	p.display_name = pool.pick_random()
	p.height_f = randf_range(0.92, 1.14)
	p.mass_f = randf_range(0.85, 1.12)
	var skins := [Color(0.72, 0.53, 0.38), Color(0.55, 0.36, 0.26),
		Color(0.86, 0.69, 0.52), Color(0.40, 0.27, 0.19), Color(0.94, 0.79, 0.64)]
	var hairs := [Color(0.12, 0.09, 0.08), Color(0.30, 0.20, 0.12),
		Color(0.10, 0.10, 0.12), Color(0.55, 0.42, 0.24), Color(0.75, 0.70, 0.66)]
	p.skin_col = skins.pick_random()
	p.hair_col = hairs.pick_random()
	# Ogni NPC ha il PROPRIO taglio (pesato sul normale): non deve mai
	# comparire con lo stile scelto dal giocatore nel creator.
	p.hair_style_v = [0, 0, 0, 0, 1, 2, 3, 4, 5].pick_random()
	p.shoe_col = Items.random_wear_col("shoes")

func _formation_pos(t: int, i: int) -> Vector2:
	if one_on_one:
		# Offense checks up at the top of the key, defender between him and the rim.
		var rim: Vector2 = hoops[0]
		return rim + Vector2(-420.0 + t * 150.0, 40.0 if t == 0 else -40.0)
	var side := -1.0 if t == 0 else 1.0
	# Spread across the floor so five-a-side is not a huddle at half-court.
	var spots := [
		Vector2(side * 260.0, 0.0),
		Vector2(side * 520.0, -360.0),
		Vector2(side * 520.0, 360.0),
		Vector2(side * 760.0, -200.0),
		Vector2(side * 760.0, 200.0),
	]
	return spots[clampi(i, 0, spots.size() - 1)]

## In 1v1 the ball must be taken back past the arc after a change of possession,
## otherwise you could just camp under the rim and tip it in forever.
func _clear_distance_ok(p: BallPlayer) -> bool:
	return px_to_ft(p.global_position.distance_to(hoop_for(p.team))) >= 22.0

func _tipoff() -> void:
	if one_on_one:
		possession = 0
		play_live = false
		_check_ball(0)
		return
	# PALLA A DUE (jump ball): l'arbitro lancia al centro del cerchio, i due
	# più alti saltano e spalancano verso un compagno. Scrimmage e campionato
	# partono così; il possesso poi alterna a ogni quarto (vedi _end_quarter).
	jump_pending = true
	_build_jump_formation()
	play_live = false
	Events.toast.emit("TIP-OFF")

## Posizioni da palla a due: i due centri faccia a faccia sul cerchio, gli
## altri fuori dal cerchio lungo il perimetro della propria meta'.
func _build_jump_formation() -> void:
	var centers := []
	for t in 2:
		var squad := players.filter(func(p): return p.team == t)
		var best: BallPlayer = squad[0]
		for p in squad:
			if p.height_f > best.height_f:
				best = p
		centers.append(best)
	for t in 2:
		var c: BallPlayer = centers[t]
		c.global_position = Vector2((-1.0 + 2.0 * t) * 58.0, 0.0)
		c.velocity = Vector2.ZERO
		c.facing = -1.0 if t == 0 else 1.0
		var mates := players.filter(func(p): return p.team == t and p != c)
		for i in mates.size():
			var m: BallPlayer = mates[i]
			m.global_position = Vector2((-1.0 + 2.0 * t) * (330.0 + 120.0 * float(i / 2)),
				-260.0 + 170.0 * float(i % 2))
			m.velocity = Vector2.ZERO
			m.has_ball = false
	for p in players:
		p.has_ball = false
	ball.live = false
	ball.visible = false   # la palla appare nelle mani dell'arbitro

## La coreografia della palla a due: l'ARBITRO raggiunge il cerchio di centro
## campo, alza le mani con la palla, la lancia, i due centri saltano e il tip
## va a un compagno della squadra vincitrice (pesata su altezza e sagacia).
func _run_jump_ball() -> void:
	_jump_run = true
	play_live = false
	restarting = true
	# l'arbitro piu' vicino entra nel cerchio e si porta la palla
	var ref: Node = null
	for r in _refs:
		if is_instance_valid(r) and (ref == null or absf(r.position.x) < absf(ref.position.x)):
			ref = r
	if ref != null:
		ref.tossing = true
		var target := Vector2(0.0, float(ref.side) * (Court.COURT_H * 0.5 + 26.0) * 0.45)
		var walk := create_tween()
		walk.tween_property(ref, "position", target, 0.45)
		await get_tree().create_timer(0.45).timeout
		if not is_inside_tree():
			return
	await get_tree().create_timer(0.10).timeout
	if not is_inside_tree():
		return
	var c0: BallPlayer = players.filter(func(p): return p.team == 0)[0]
	var c1: BallPlayer = players.filter(func(p): return p.team == 1)[0]
	for t in 2:
		var squad := players.filter(func(p): return p.team == t)
		var best: BallPlayer = squad[0]
		for p in squad:
			if p.height_f > best.height_f:
				best = p
		if t == 0: c0 = best
		else: c1 = best
	if ref != null:
		ref.toss_t = 0.9
	ball.visible = true
	ball.live = false
	var hand: Vector2 = ref.position if ref != null else Vector2.ZERO
	ball.global_position = hand + Vector2(14.0, 6.0)
	ball.h = 52.0
	# lancio dall'alto delle mani dell'arbitro
	var toss := create_tween()
	toss.tween_method(func(v: float): ball.h = v, 52.0, Court.RIM_HEIGHT + 92.0, 0.55)
	c0.do_jump(true)
	c1.do_jump(true)
	Sfx.play("go", -4.0)
	await get_tree().create_timer(0.58).timeout
	if not is_inside_tree():
		return
	# vincitore pesato: altezza e sagacia valgono piu' della fortuna
	var q0: float = c0.height_f * (float(c0.ratings["close"]) + float(c0.ratings["block"]))
	var q1: float = c1.height_f * (float(c1.ratings["close"]) + float(c1.ratings["block"]))
	var win: BallPlayer = c0 if randf() < (q0 / maxf(q0 + q1, 1.0)) else c1
	var mates := players.filter(func(p): return p.team == win.team and p != win)
	var target: BallPlayer = mates[randi() % mates.size()] if mates.size() > 0 else win
	# tip verso il compagno: il tocco parte dall'apice
	ball.h = Court.RIM_HEIGHT + 60.0
	ball.live = false
	give_ball(target)
	possession = win.team
	shot_clock = 18.0
	Events.possession_changed.emit(possession)
	var club: String = Season.my_team() if win.team == 0 else String(Game.profile.get("next_opponent", ""))
	Events.toast.emit("JUMP BALL  ·  %s" % Season.short_name(club))
	
	restarting = false
	jump_pending = false
	_jump_run = false
	play_live = true
	# l'arbitro esce dal cerchio e torna sulla linea laterale
	if ref != null and is_instance_valid(ref):
		var back := create_tween()
		back.tween_property(ref, "position",
			Vector2(ref.position.x, float(ref.side) * (Court.COURT_H * 0.5 + 26.0)), 0.6)
		back.tween_callback(func(): ref.tossing = false)

func _reset_possession(full := false) -> void:
	shot_clock = 18.0
	var team_players := players.filter(func(p): return p.team == possession)
	var carrier: BallPlayer = team_players[0]
	for p in players:
		p.has_ball = false
		if full:
			p.global_position = _formation_pos(p.team, players.filter(func(x): return x.team == p.team).find(p))
	give_ball(carrier)
	Events.possession_changed.emit(possession)

func give_ball(p: BallPlayer) -> void:
	var changed_hands: bool = possession != p.team
	for q in players: q.has_ball = false
	p.has_ball = true
	ball.attach(p)
	possession = p.team
	# In 1v1 a change of possession means you must take it back past the arc.
	# 1v1: you MUST take it past the arc after any new touch (make, miss,
	# steal, rebound). Without this the AI camps under the rim forever.
	if one_on_one and not _clear_distance_ok(p):
		must_clear = true
	elif one_on_one and _clear_distance_ok(p):
		must_clear = false
	Events.possession_changed.emit(possession)

## Grab a loose ball. Makes the SHOOT button meaningful even without possession
## (rebounds, blocked shots) instead of being a dead input.
func try_grab(p: BallPlayer) -> bool:
	if ball.holder != null or p.stun > 0.0: return false
	var d := p.global_position.distance_to(ball.global_position)
	if d > 90.0 or ball.h > 210.0: return false
	# A shot still resolving above/at the ring is no one's rebound yet: let it
	# fall through for the bucket or bounce clear off the iron. Grabbing a
	# descending shot at the rim used to eat made baskets outright.
	if ball.shot_result_pending:
		var near_hoop: Vector2 = hoops[0] if ball.global_position.x < 0 else hoops[1]
		if ball.h > RIM_HEIGHT - 45.0:
			return false
		if ball.global_position.distance_to(near_hoop) < 58.0:
			return false
	give_ball(p)
	shot_clock = maxf(shot_clock, 14.0)
	_shoot_call = false
	if p.is_user: box["reb"] += 1
	Events.toast.emit("Loose ball!")
	return true

## The user calls for the ball. The handler passes if the lane is reasonable,
## which makes GET BALL useful even when the ball is nowhere near you.
func request_pass(to: BallPlayer) -> bool:
	if inbound_wait > 0.0 and to.team == possession and to != _inbounder:
		_finish_inbound(to)
		return true
	var h: BallPlayer = ball_handler()
	if h == null or h == to or h.team != to.team:
		return false
	# Call for it when you are open: team-mate gives it back.
	if pressure_on(to) > 0.78:
		Events.toast.emit("Covered — no lane")
		return false
	Events.toast.emit("BALL!")
	h.do_pass(to)
	return true

## The PASS button: pick the team-mate in the direction the joystick is held,
## weighting how open each one is. With no direction it defaults to the most
## open team-mate, so a tap always finds somebody.
func directed_pass(from: BallPlayer, dir: Vector2) -> bool:
	if from == null or not from.has_ball:
		return false
	update_pass_aim(from, dir)
	var best: BallPlayer = aimed
	if best == null:
		return false
	if pressure_on(best) > 0.85:
		Events.toast.emit("No lane!")
		return false
	from.do_pass(best)
	return true

## Pick and roll: nearest team-mate sprints to set a screen on the user's
## defender, then rolls to the rim. The user keeps the ball.
func start_pick_and_roll(from: BallPlayer) -> bool:
	if from == null or not from.has_ball or one_on_one:
		return false
	var screener: BallPlayer = null
	var bd := 1e9
	for p in players:
		if p == from or p.team != from.team:
			continue
		var d: float = p.global_position.distance_to(from.global_position)
		if d < bd:
			bd = d
			screener = p
	if screener == null:
		return false
	# The defender currently guarding the ball-handler is who we screen.
	var on_ball_def: BallPlayer = null
	var dd := 1e9
	for d in players:
		if d.team == from.team:
			continue
		var dist: float = d.global_position.distance_to(from.global_position)
		if dist < dd:
			dd = dist
			on_ball_def = d
	var brain: Node = null
	for c in screener.get_children():
		if c.has_method("begin_screen"):
			brain = c
			break
	if brain != null:
		brain.begin_screen(from)
		if on_ball_def != null and brain.has_method("set_screen_target"):
			brain.set_screen_target(on_ball_def)
	else:
		screener.do_cut()
	pnr_screening = true
	pnr_screener = screener
	pnr_timer = 5.0
	Events.toast.emit("SCREEN")
	return true

func release_pick_and_roll(from: BallPlayer) -> void:
	if from == null or one_on_one:
		return
	pnr_screening = false
	pnr_timer = 0.0
	var scr := pnr_screener
	pnr_screener = null
	if scr == null or not is_instance_valid(scr):
		return
	for c in scr.get_children():
		if c.has_method("begin_roll"):
			c.begin_roll()
			pnr_roller = scr
			roller_t = 3.5
			Events.toast.emit("ROLL")
			return

func update_pass_aim(from: BallPlayer, dir: Vector2) -> void:
	aimed = null
	if from == null or one_on_one:
		return
	var best: BallPlayer = null
	var best_score := -INF
	for p in players:
		if p == from or p.team != from.team:
			continue
		var to: Vector2 = p.global_position - from.global_position
		if to.length() < 20.0:
			continue
		var align := 0.0
		if dir.length() > 0.18 and to.length() > 1.0:
			align = dir.normalized().dot(to.normalized())
		else:
			align = -to.length() * 0.001
		if align > best_score:
			best_score = align
			best = p
	if best != null and (dir.length() < 0.18 or best_score > 0.15):
		aimed = best

func ball_handler() -> BallPlayer:
	for p in players:
		if p.has_ball: return p
	return null

# ------------------------------------------------------------------ clocks
## Team-mate voices: short barked calls, only ever in real games with other
## players on the floor (solo courts stay squeaks + net + dribble).
func _voice(_id: String, _cd: float) -> void:
	## Le voci sintetiche sono state rimosse (giudicate finte dal playtest):
	## il parlate resta solo nel toast/nuvole, non in audio.
	pass

func _process_voices(delta: float) -> void:
	for k in _voice_cd.keys():
		_voice_cd[k] = maxf(0.0, float(_voice_cd[k]) - delta)
	if not play_live or finished:
		return
	var h: BallPlayer = ball_handler()
	if h != null:
		var pr: float = pressure_on(h)
		if pr > 0.55:
			_voice("defense", 2.5)
		if pr > 0.80:
			_voice("pass", 3.0)
		if not _shoot_call and shot_clock < 6.5:
			_shoot_call = true
			_voice("shoot", 3.0)

func _physics_process(delta: float) -> void:
	_process_voices(delta)
	if intermission and not finished:
		# teams jog to their bench-side huddles while the cheerleaders dance
		for pi in players.size():
			var p: BallPlayer = players[pi]
			if p.entering or p.leaving:
				continue
			var side: float = -1.0 if p.team == 0 else 1.0
			var j: float = float(p.jersey_num % 5)
			var spot := Vector2(side * COURT_W * 0.26 + (j - 2.0) * 46.0,
				COURT_H * 0.30 + fmod(j, 2.0) * 46.0)
			var d: Vector2 = spot - p.global_position
			if d.length() > 18.0:
				p.global_position += d.normalized() * minf(300.0 * delta, d.length())
				p.velocity = d.normalized() * 240.0
				if absf(d.x) > 4.0:
					p.facing = signf(d.x)
			else:
				p.velocity = Vector2.ZERO
	if inbound_wait > 0.0:
		inbound_wait -= delta
		if inbound_wait <= 0.0:
			_finish_inbound(null)
	# La palla a due parte al GO di MatchScene; il watchdog copre i contesti
	# senza countdown (sim headless, tool) cosi' il gioco non resta mai a metà.
	if jump_pending and not _jump_run:
		_jump_watch += delta
		if (play_live and _jump_watch > 0.2) or _jump_watch > 6.0:
			_run_jump_ball()
	if not play_live or finished: return
	game_clock -= delta
	shot_clock -= delta
	# A screen that is never released must still resolve: the screener rolls
	# on his own after the window, so nobody stays planted for the whole game.
	if pnr_screening:
		pnr_timer -= delta
		if pnr_timer <= 0.0:
			release_pick_and_roll(ball_handler())
	if roller_t > 0.0:
		roller_t -= delta
		if roller_t <= 0.0:
			pnr_roller = null
	_deadball_watchdog(delta)
	if one_on_one and must_clear:
		var h := ball_handler()
		if h != null and h.team == possession and _clear_distance_ok(h):
			must_clear = false
			Events.toast.emit("Cleared - go!")
	if shot_clock <= 0.0:
		Events.toast.emit("Shot clock violation")
		_turnover_to(1 - possession)
	if game_clock <= 0.0:
		_end_quarter()
	_try_inflight_block()

## THE ANTI-FREEZE NET.
## Every path that ends a possession (make, miss, steal, block, out of bounds)
## is supposed to hand the ball to somebody. If any single one of them fails --
## an await that returned early, a rebound where every candidate was too far,
## a blocked ball that rolled into a corner -- the match silently becomes
## unplayable: nobody holds the ball, so no input does anything.
## Rather than trust every branch, we assert the invariant centrally:
## "within 3 seconds there is always either a holder or a ball in flight".
func _deadball_watchdog(delta: float) -> void:
	if ball == null: return
	if restarting:
		_dead_time = 0.0
		return
	var alive: bool = ball.holder != null or (ball.live and ball.vel.length() > 12.0) \
		or ball.shot_result_pending or ball.dunk_drop > 0.0
	if alive:
		_dead_time = 0.0
		return
	_dead_time += delta
	if _dead_time < 3.0: return
	_dead_time = 0.0
	push_warning("Dead ball recovered by watchdog")
	# Give it to whoever is closest to where the ball actually is.
	var best: BallPlayer = null
	var bd := 1e9
	for p in players:
		var d := p.global_position.distance_to(ball.global_position)
		if d < bd:
			bd = d
			best = p
	if best != null:
		give_ball(best)
		shot_clock = maxf(shot_clock, 14.0)
		Events.toast.emit("Loose ball recovered")
	else:
		# 1v1 strada: tiro SBAGLIATO = PALLA VIVA sul rimbalzo. Il check
		# resta solo dopo i PUNTI (make-it-take-it). Prima, senza nessuno
		# sotto il ferro, il tiro sbagliato finiva in check: assurdo.
		if one_on_one:
			var near: BallPlayer = null
			var nd := 1e9
			for q in players:
				var dd := q.global_position.distance_to(ball.global_position)
				if dd < nd:
					nd = dd
					near = q
			give_ball(near)
			shot_clock = maxf(shot_clock, 12.0)
			Events.toast.emit("Palla viva!")
		else:
			_restart_play(1 - possession)

## Single funnel for every point scored (baskets, dunks, free throws): keeps
## the quarter log, scoring runs and per-player points in one place, so the
## broadcast card at the end always agrees with the scoreboard.
func _add_score(p: BallPlayer, pts: int) -> void:
	score[p.team] += pts
	p.pts_total += pts
	_q_pts[p.team] += pts
	if _run_team != p.team:
		_end_run()
		_run_team = p.team
		_run_q = quarter
	_run_pts += pts
	if not _run_said and _run_pts >= 6:
		# Live callout: somebody is heating up.
		_run_said = true
		Events.run_update.emit({"live": true, "team": p.team, "pts": _run_pts, "q": _run_q})
	Events.score_changed.emit(score[0], score[1])

## Close the book on a scoring run: if it was long enough it becomes the
## match's headline run for the post-game card.
func _end_run() -> void:
	if _run_team >= 0 and _run_pts >= 8 \
	and (_best_run.is_empty() or _run_pts > int(_best_run.get("pts", 0))):
		_best_run = {"team": _run_team, "pts": _run_pts, "q": _run_q}
	_run_team = -1
	_run_pts = 0
	_run_said = false

## Snapshot the current quarter's points into the log (called on every
## quarter buzzer, including the last one before _finish()).
func _close_quarter_book() -> void:
	_q_log.append([int(_q_pts[0]), int(_q_pts[1])])
	_q_pts = [0, 0]
	_end_run()

func _end_quarter() -> void:
	if is_fixture and not user_on_court and not finished:
		unbench_user()
		benched_time = 0.0
	if one_on_one:
		# no quarters in a race to 11: the clock is just a safety valve
		game_clock = quarter_len
		return
	Sfx.play("buzzer")
	_close_quarter_book()
	quarter += 1
	if quarter > QUARTERS:
		_finish()
		return
	game_clock = quarter_len
	possession = 1 - possession
	_reset_possession(true)
	Events.quarter_ended.emit(quarter)
	Events.toast.emit("Q%d" % quarter)

func _finish() -> void:
	finished = true
	play_live = false
	var won: bool = score[0] > score[1]
	var res := box.duplicate()
	res["won"] = won
	res["score"] = score.duplicate()
	# Broadcast extras: quarter splits, the headline run, top scorer per team
	# and where the game was played. The card degrades gracefully if a key is
	# missing (1v1 has no quarters, old saves no tops).
	if not one_on_one:
		res["q"] = _q_log.duplicate(true)
	if not _best_run.is_empty():
		res["run"] = _best_run.duplicate()
	var tops := [{}, {}]
	for p in players:
		if not is_instance_valid(p):
			continue
		var t: int = p.team
		if p.pts_total > int(tops[t].get("pts", -1)):
			tops[t] = {"name": String(p.display_name), "jersey": int(p.jersey_num), "pts": int(p.pts_total)}
	res["tops"] = tops
	res["opp"] = String(Game.profile.get("next_opponent", ""))
	res["home"] = bool(Game.profile.get("next_home", true))
	res["arena"] = Season.match_arena()
	# Rewards are granted immediately so leaving on the final buzzer can never
	# lose them; the panel waits for the jingle a moment longer.
	Career.apply_match_result(res)
	Sfx.play("buzzer", 2.0)
	_finish_jingle(res, won)

func _finish_jingle(res: Dictionary, won: bool) -> void:
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree():
		return
	Sfx.play("victory" if won else "defeat", 1.0)
	Sfx.cheer(won)
	Events.match_finished.emit(res)

# ------------------------------------------------------------------ shooting
func behind_hoop(p: BallPlayer) -> bool:
	## Past the iron toward the baseline: you can stand there, you cannot shoot.
	var hoop: Vector2 = hoop_for(p.team)
	if hoop.x > 0.0:
		return p.global_position.x > hoop.x + 8.0
	return p.global_position.x < hoop.x - 8.0

func attempt_shot(shooter: BallPlayer, timing_err: float) -> void:
	if not shooter.has_ball or not play_live: return
	if behind_hoop(shooter):
		Events.toast.emit("No shot from behind the hoop")
		return
	var hoop := hoop_for(shooter.team)
	var dist_px := shooter.global_position.distance_to(hoop)
	var dist_ft := px_to_ft(dist_px)
	var contest := pressure_on(shooter)
	var open_catch := (Time.get_ticks_msec() / 1000.0 - last_pass_time) < 1.1 and last_passer != null

	# Shooting foul: a defender closing hard can catch the shooter on the arm.
	# The free throws match the attempt: two for a two, three for a three.
	var fouler := _shooting_foul_check(shooter, contest)
	if fouler != null:
		call_foul(fouler, shooter, 3 if dist_ft > THREE_FT else 2)
		return

	# FADE / REVERSE / HOOK: la famiglia dei tiri "scolpiti". In tutti e
	# tre il contest pesa meno (ti separi dal difensore) ma il timing peggiora.
	var hoop_dir: Vector2 = hoop - shooter.global_position
	var _floater_shot := false
	var going_away: bool = shooter.velocity.dot(hoop_dir.normalized()) < -60.0
	var back_to: bool = signf(float(shooter.facing)) != signf(hoop_dir.x) \
		and absf(hoop_dir.x) > 1.0   # spalle al canestro
	if going_away and dist_ft < 8.0 and not shooter.posting:
		contest *= 0.55
		timing_err *= 1.20
		Events.popup.emit("REVERSE", shooter.global_position, Color(0.8, 0.9, 1.0), true)
	elif back_to and dist_ft < (9.0 if shooter.posting else 12.0):
		# HOOK: archi la palla SOPRA il difensore: quasi zero contest,
		# ma il timing diventa molto piu severo. Da POST la finestra e'
		# piu' corta (9ft): oltre, il post gioca FADEAWAY.
		contest *= 0.45
		timing_err *= 1.30
		Events.popup.emit("HOOK", shooter.global_position, Color(1.0, 0.9, 0.6), true)
# STEPBACK 3: spaziati con lo stepback e archia da oltre l'arco
	# entro 0.9s: molto spazio (contest basso) ma timing difficile.
	elif shooter.stepback_t > 0.0 and going_away and dist_ft > THREE_FT:
		contest *= 0.75
		timing_err *= 1.25
		Events.popup.emit("STEPBACK 3", shooter.global_position, Color(1.0, 0.65, 0.35), true)
	# FLOATER: in corsa al ferro con un difensore addosso (6-16ft) la
	# palla va SOPRA: arco alto, quasi zero contest, difficile da stenzare.
	elif hoop_dir.length() > 40.0 and shooter.velocity.dot(hoop_dir.normalized()) > 120.0 \
	and dist_ft > 6.0 and dist_ft < 16.0 and _nearest_defender_dist(shooter) < 90.0:
		contest *= 0.5
		timing_err *= 1.15
		_floater_shot = true
		Events.popup.emit("FLOATER", shooter.global_position, Color(0.75, 0.90, 1.0), true)
	elif going_away:
		contest *= 0.62
		timing_err *= 1.15
		# FADEAWAY visibile: prima la terza branca della famiglia era muta
		# e il giocatore non capiva perche' il tiro fosse piu' difficile.
		Events.popup.emit("FADEAWAY", shooter.global_position, Color(0.72, 0.93, 0.72), true)
	elif shooter.combo_pullup:
		# COMBO PULL-UP (TRICK -> TIRA entro mezzo secondo): tiro in
		# slancio, si vede il popup, timing un filo piu' severo.
		timing_err *= 1.10
		Events.popup.emit("PULL-UP", shooter.global_position, Color(0.65, 0.85, 1.0), true)
	var res := ShotSystem.resolve({
		"dist_ft": dist_ft, "contest": contest, "timing_err": timing_err,
		"diff": Game.difficulty(),
		"stamina01": shooter.stamina01(), "momentum": momentum if shooter.team == 0 else -momentum,
		"a_close": shooter.ratings["close"], "a_mid": shooter.ratings["mid"], "a_three": shooter.ratings["three"],
		"badges": shooter.badges, "open_catch": open_catch,
		"moving": shooter.velocity.length() > 90.0,
	})

	shooter.combo_pullup = false   # la combo vive per un tiro solo
	total_attempts += 1
	# blocked?
	var blocker := _block_check(shooter, contest, _floater_shot)
	if blocker != null:
		Events.toast.emit("BLOCKED by #%d" % blocker.jersey_num)
		Sfx.play("block", -1.0)
		Sfx.ooh()
		Events.shake.emit(0.7)
		Events.popup.emit("BLOCK!", blocker.global_position, Color(1.0, 0.45, 0.3), true)
		res["made"] = false
		if shooter.is_user:
			_user_break_heat()
		ball.detach()
		ball.global_position = shooter.global_position
		ball.vel = (blocker.global_position - shooter.global_position).normalized() * 260.0
		ball.vh = 260.0
		ball.h = 90.0
		ball.shot_result_pending = true
		ball.shooter = shooter
		shooter.has_ball = false
		if shooter.is_user: box["fga"] += 1
		return

	shooter.has_ball = false
	shooter.stamina -= lerpf(2.0, 7.0, clampf(dist_ft / 26.0, 0.0, 1.0))

	# flight: longer shots hang longer -> readable arcs
	var flight: float = clampf(0.55 + dist_ft * 0.022, 0.55, 1.25)
	if _floater_shot:
		flight = minf(flight + 0.18, 1.4)
	var aim := hoop
	if not res["made"]:
		# A miss physically misses, and HOW it misses matches the timing on
		# the meter: an EARLY release dies short on the front iron, a LATE one
		# flies long off the back rim or the glass, and a GOOD release just
		# rattles out by an amount that shrinks as the make-chance rises.
		var to_hoop: float = signf(hoop.x - shooter.global_position.x)
		if absf(to_hoop) < 0.5:
			to_hoop = 1.0
		var t: int = res["timing"]
		var offx: float
		var offy: float
		if t == ShotSystem.Timing.EARLY:
			offx = -to_hoop * randf_range(30.0, 72.0)   # short, front rim
			offy = randf_range(4.0, 24.0)
		elif t == ShotSystem.Timing.LATE or t == ShotSystem.Timing.VERY_LATE:
			offx = to_hoop * randf_range(22.0, 60.0)    # long, back rim/board
			offy = randf_range(-32.0, -8.0)
		else:
			offx = randf_range(-1.0, 1.0) * lerpf(70.0, 16.0, res["p"])
			offy = randf_range(-1.0, 1.0) * 26.0
		var off := Vector2(offx, offy)
		# Un tiro mancato non arriva MAI dentro il ferro: sotto i 30 px di
		# distanza la geometria lo segnerebbe (finto canestro). O sbatte sul
		# ferro ed esce, o e' airball.
		if off.length() < 30.0:
			off = off.normalized() * randf_range(30.0, 46.0)
		aim += off
	ball.swish_clean = bool(res.get("swish", false))
	ball.shoot(shooter.global_position + Vector2(0, -50), aim, 520.0, flight, res["made"], shooter)
	ball.last_touch_team = shooter.team

	if shooter.is_user:
		box["fga"] += 1
		if res["points"] == 3: box["tpa"] += 1
		Career.on_user_shot(res)
		if bool(res["made"]):
			user_streak += 1
			if user_streak >= 3 and not user_heat:
				user_heat = true
				Events.popup.emit("ON FIRE!", shooter.global_position, Color(1.0, 0.55, 0.15), true)
				Sfx.play("crowd_cheer2", -6.0, randf_range(0.98, 1.06))
		else:
			_user_break_heat()
	Events.shot_taken.emit(ShotSystem.timing_name(res["timing"]) + " / " + res["quality"], res["made"], res["points"])
	if bool(res["made"]):
		if randf() < 0.55:
			_voice("nice", 2.0)
	else:
		if randf() < 0.50:
			_voice("rebound", 2.5)
	shot_clock = maxf(shot_clock, 2.0)

## A defender closing out on a shooter can commit a shooting foul. Rare at
## low contest, more likely when he is right in the shooter's landing space.
func _shooting_foul_check(shooter: BallPlayer, contest: float) -> BallPlayer:
	if contest < 0.40:
		return null
	for d in players:
		if d.team == shooter.team: continue
		var dist := d.global_position.distance_to(shooter.global_position)
		if dist > 80.0: continue
		var ch: float = 0.012 * contest * (1.0 - float(d.ratings["defense"]) / 130.0)
		if d.block_window > 0.0:
			ch *= 1.15
		if randf() < ch:
			return d
	return null

func _user_break_heat() -> void:
	if user_heat:
		Events.popup.emit("COLD", user.global_position, Color(0.7, 0.75, 0.85), false)
	user_streak = 0
	user_heat = false

func _nearest_defender_dist(shooter: BallPlayer) -> float:
	var best := 99999.0
	for d in players:
		if d.team == shooter.team:
			continue
		best = minf(best, d.global_position.distance_to(shooter.global_position))
	return best

func _block_check(shooter: BallPlayer, contest: float, floater := false) -> BallPlayer:
	for d in players:
		if d.team == shooter.team: continue
		var dist := d.global_position.distance_to(shooter.global_position)
		if dist > 95.0: continue
		# Timed BLOCK: jumping while the shot leaves the hand contests it
		# automatically (see contest_value_against x1.35), but an actual SWAT
		# still has to be earned -- close to the shooter, near the apex of the
		# jump, and with real block rating. Tuning 2.15: prima il timing
		# "giusto" non bloccava quasi MAI (88px, apex stretto, coeff basso):
		# ora salto + distanza + timing pagano davvero, scalati per diff.
		if d.block_window > 0.0 and dist < (70.0 if floater else 120.0) and d.air > 8.0:
			var apex_q: float = clampf(1.0 - absf(d.air / d.jump_height() - 0.5) / 0.6, 0.30, 1.25)
			var block_ch: float = clampf(
				(float(d.ratings["block"]) / 99.0) * d.height_f * 0.95
				* (1.15 - dist / 120.0) * apex_q, 0.05, 0.78)
			if floater:
				block_ch *= 0.4   # palla tirata SOPRA la mano: stenzata rara
			# La difficolta' pesa SOLO sull'AI che difende l'utente: a Incubo
			# il salto a tempo si paga, a Facile si perdona di piu'.
			if shooter.is_user:
				block_ch *= [0.75, 0.95, 1.15, 1.35][Game.difficulty()]
			if randf() < block_ch:
				if d.is_user: box["blk"] += 1
				return d
			# Judged once while airborne: do not roll again on the ground.
			continue
		# GROUNDED defender: only a serious in-his-jersey contest pokes the
		# release away; a mistimed jump's tail adds a small bonus.
		if contest < 0.28: continue
		var ch: float = (d.ratings["block"] / 99.0) * 0.18 * d.height_f * (1.0 - dist / 95.0)
		if d.block_window > 0.0:
			ch = minf(ch * 1.8, 0.40)
		if randf() < ch:
			if d.is_user: box["blk"] += 1
			return d
	return null

## Tell the court art to shake a basket. Safe no-op outside the match scene
## (solo and drills drive their own net wobble directly).
## Swat a shot already in the air: jump into the ball during the block window.
func _try_inflight_block() -> void:
	if ball == null or not ball.shot_result_pending or ball.holder != null:
		return
	for d in players:
		if d.block_window <= 0.0 or d.air < 6.0:
			continue
		var bp: Vector2 = ball.global_position
		var dist: float = d.global_position.distance_to(bp)
		if dist > 70.0:
			continue
		# Hand has to be near the ball's height.
		if absf(d.air + 70.0 - ball.h) > 90.0:
			continue
		# The ball must already be IN FLIGHT away from the shooter: meeting
		# it at his fingertips is the release-block dice in _block_check.
		# A geometrically-perfect jump used to be a guaranteed pin and games
		# drowned in endless swats.
		var travelled: float = 0.0
		if ball.shooter != null and is_instance_valid(ball.shooter):
			travelled = bp.distance_to(ball.shooter.global_position)
		if travelled < 60.0:
			continue
		# Volleyball-style pins at the apex are rare and skill-based.
		var apex_q: float = clampf(1.0 - absf(d.air / d.jump_height() - 0.6) / 0.6, 0.2, 1.2)
		var ch: float = clampf((float(d.ratings["block"]) / 99.0) * d.height_f
			* (1.0 - dist / 70.0) * apex_q * 0.6, 0.04, 0.5)
		if randf() >= ch:
			d.block_window = 0.0
			continue
		ball.shot_result_pending = false
		ball.live = true
		ball.shooter = null
		ball.vel = (d.global_position - bp).normalized() * -280.0
		ball.vh = 180.0
		d.block_window = 0.0
		if d.is_user:
			box["blk"] += 1
		Sfx.play("block", -0.5)
		Sfx.ooh()
		Events.shake.emit(0.8)
		Events.popup.emit("CHASEDOWN!", d.global_position, Color(1.0, 0.45, 0.3), true)
		Events.toast.emit("BLOCKED!")
		_net_bump(0 if bp.x < 0.0 else 1, 0.4)
		return

func _rim_fx(kind: String, at: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var vis: Node = parent.get_node_or_null("CourtVisual")
	if vis != null and vis.has_method("rim_fx"):
		vis.rim_fx(kind, at)

func _net_bump(idx: int, amt: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var vis: Node = parent.get_node_or_null("CourtVisual")
	if vis != null and vis.has_method("net_bump"):
		vis.net_bump(idx, amt)

func check_ball_collisions(b: Ball) -> void:
	if not b.shot_result_pending: return
	var hoop: Vector2 = hoops[0] if b.global_position.x < 0 else hoops[1]
	# backboard: vertical plane just behind the rim
	var board_x: float = hoop.x + (-42.0 if hoop.x < 0 else 42.0)
	if b.h > RIM_HEIGHT - 10 and b.h < RIM_HEIGHT + 90:
		if (hoop.x < 0 and b.global_position.x < board_x and b.vel.x < 0) \
		or (hoop.x > 0 and b.global_position.x > board_x and b.vel.x > 0):
			b.global_position.x = board_x
			b.vel.x = -b.vel.x * 0.55
			b.vel.y *= 0.8
			b.kill_analytic()
			Sfx.play("backboard", -7.0)
			Events.shake.emit(0.28)
			_net_bump(0 if hoop.x < 0 else 1, 0.35)
	# Street-court pattern: 2D distance to the ring, swept through the plane.
	var crossed_down := b.prev_h >= RIM_HEIGHT and b.h <= RIM_HEIGHT and b.vh < 0.0
	if crossed_down:
		var span := b.prev_h - b.h
		var f: float = 0.0 if span <= 0.0 else (b.prev_h - RIM_HEIGHT) / span
		var cx: float = lerpf(b.prev_pos.x, b.global_position.x, clampf(f, 0.0, 1.0))
		var cy: float = lerpf(b.prev_pos.y, b.global_position.y, clampf(f, 0.0, 1.0))
		var dist: float = Vector2(cx, cy).distance_to(hoop)
		# Una palla "rattled" ricade con deriva orizzontale: entro 48 px dal
		# ferro il canestro resta valido (il ferro la sputata dentro).
		if dist < 24.0 or (b.rattled and dist < 48.0):
			# RIM-RATTLE: capita che il tiro "giusto" prima sbatta sul ferro,
			# salti su ed entri comunque: suono del ferro, poi lo swish della
			# rete quando cade. Cosi' non ogni canestro e' pulito.
			# RIM-RATTLE sempre sui canestri ravvicinati: e' il momento
			# "firma" richiesto dall'utente e due round al 30-35% non lo ha
			# MAI visto. Salto alto (picco 69-114 px), ferro fortissimo,
			# shake forte: deve leggersi a colpo d'occhio.
			if not b.rattled:
				b.rattled = true
				var rn: Vector2 = (Vector2(cx, cy) - hoop).normalized()
				if rn.length() < 0.1:
					rn = Vector2(1, 0)
				b.kill_analytic()
				b.global_position = hoop - rn * 9.0
				b.vh = randf_range(500.0, 640.0)
				b.vel = rn * randf_range(30.0, 60.0) + Vector2(randf_range(-35, 35), randf_range(-35, 35))
				Sfx.play("rim", -0.5, randf_range(0.95, 1.08))
				Events.shake.emit(0.60)
				_rim_fx("rattle", hoop)
				_net_bump(0 if hoop.x < 0 else 1, 0.9)
				return
			_score_basket(b)
			return
		if dist < 42.0:
			var nrm: Vector2 = (Vector2(cx, cy) - hoop).normalized()
			if nrm.length() < 0.1:
				nrm = Vector2(1, 0)
			b.global_position = hoop + nrm * 44.0
			b.kill_analytic()
			b.vh = absf(b.vh) * Ball.REST_RIM
			b.vel = b.vel.bounce(nrm) * 0.55
			Sfx.play("rim", -3.5, randf_range(0.94, 1.06))
			Events.shake.emit(0.32)
			_net_bump(0 if hoop.x < 0 else 1, 0.85)
			_rim_fx("iron", hoop)
			Sfx.ooh()
			return
	# Brushing the net below the ring still moves it.
	if b.h < RIM_HEIGHT and b.h > RIM_HEIGHT - 130.0 \
	and b.global_position.distance_to(hoop) < 50.0:
		_net_bump(0 if hoop.x < 0 else 1, 0.45)

func dunk_hang_pos(p: BallPlayer) -> Vector2:
	## Grab the side of the iron that matches the approach: baseline, near
	## sideline or far sideline — not always the same front slot.
	var rim: Vector2 = hoop_for(p.team)
	var d: Vector2 = p.global_position - rim
	var off := Vector2.ZERO
	var end_sign: float = 1.0 if rim.x >= 0.0 else -1.0
	if end_sign * d.x > 10.0:
		off.x = end_sign * 16.0          # from behind / baseline
	else:
		off.x = -end_sign * 24.0         # from in front of the hoop
	if absf(d.y) > 22.0:
		off.y = signf(d.y) * 30.0        # near vs far side of the ring
	return rim + off

func on_dunk_started(p: BallPlayer) -> void:
	## A dunk is a guaranteed two unless it gets blocked at the rim. The ball
	## travels with the dunker instead of arcing, then drops through.
	var d := create_tween()
	var slot: Vector2 = dunk_hang_pos(p)
	# The flight lasts exactly as long as the animation of this dunk says it
	# does, so the body arrives at the iron at the same instant the pose slams
	# the ball down -- in the arena and on the street alike.
	d.tween_property(p, "global_position", slot, DunkStyle.rise_time(p.dunk_style))
	await d.finished
	if not is_instance_valid(p) or not p.has_ball:
		return
	# Contest check: a defender who jumped in time can still swat it.
	# Tuning 2.15: prima 4-42% fisso: l'AI saltava sul dunk (v2.13) e la
	# palla ENTRAVA UGUALE. Ora la stenzata al ferro e' reale e scala con
	# la difficolta' solo quando a subirla e' l'utente.
	for o in players:
		if o.team == p.team or not is_instance_valid(o):
			continue
		if o.block_window > 0.0 and o.global_position.distance_to(p.global_position) < 90.0:
			var stop: float = clampf(float(o.ratings["block"]) / 140.0, 0.05, 0.55)
			if p.is_user:
				stop *= [0.80, 1.00, 1.20, 1.40][Game.difficulty()]
			if randf() < stop:
				Events.toast.emit("BLOCKED AT THE RIM!")
				Events.popup.emit("BLOCK!", o.global_position, Color(1.0, 0.45, 0.3), true)
				Events.shake.emit(0.7)
				p.has_ball = false
				if o.is_user:
					box["blk"] += 1
				# Ball squirts loose away from the rim; whoever grabs it, gets it.
				if ball:
					ball.live = true
					ball.shot_result_pending = false
					ball.global_position = p.global_position + Vector2(-p.facing * 90.0, 0.0)
					ball.h = 120.0
					ball.vel = Vector2(-p.facing * 260.0, -80.0)
				return
	p.grab_rim()
	# Rim-rattler: the impact carries the whole stack -- shake, rim clang and
	# the loudest crowd pop in the game.
	Sfx.play("dunk", 1.0)
	Sfx.cheer(true)
	Events.shake.emit(1.0)
	Events.popup.emit("POSTER!", hoop_for(p.team), Color(1.0, 0.75, 0.2), true)
	# Actually put the ball THROUGH the ring. Before this the ball was simply
	# switched off at the moment of the dunk, so you saw the jump and then
	# nothing -- the ball never visibly went in.
	if ball:
		ball.live = false
		ball.detach()
		ball.dunk_drop = 1.0
		# start at the hand on the iron, land at the centre of the restricted
		# arc (the floor point under the rim): reads as "through the net".
		ball.dunk_from = ball.global_position
		ball.dunk_to = hoop_for(p.team)
		ball.h = Court.RIM_HEIGHT + 26.0
		# La rete CANTA anche sulla schiacciata: la palla passa attraverso.
		Sfx.play("swish", -1.0, randf_range(0.84, 0.90))
	_dunk_scored(p)

func _dunk_scored(p: BallPlayer) -> void:
	var pts: int = 1 if one_on_one else 2
	total_makes += 1
	_add_score(p, pts)
	momentum = clampf(momentum + (0.24 if p.team == 0 else -0.24), -1.0, 1.0)
	if p.is_user:
		box["pts"] += pts
		box["fgm"] += 1
		box["fga"] += 1
	Events.shot_taken.emit("DUNK %s" % DunkStyle.label(p.dunk_style), true, pts)
	_net_bump(0 if hoop_for(p.team).x < 0.0 else 1, 1.0)
	_rim_fx("swish", hoop_for(p.team))
	# La rete CANTA anche sulla schiacciata: swish piu' cupo e spinto.
	Sfx.play("swish", -1.5, randf_range(0.84, 0.92))
	Events.toast.emit("%s! +%d" % [DunkStyle.label(p.dunk_style), pts])
	p.has_ball = false
	# Hang on the rim until the player (or AI) lets go of dunk.
	var waited := 0.0
	while is_instance_valid(p) and p.hanging and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await get_tree().create_timer(0.45).timeout
	if not is_instance_valid(self):
		return
	if one_on_one and score[p.team] >= target_score:
		_finish()
		return
	if one_on_one:
		_check_ball(p.team)
		return
	_inbound(1 - p.team)

func _score_basket(b: Ball) -> void:
	# A free throw counts one and the FT sequence continues; there is no
	# rebound and no inbound between free throws.
	if b.is_free_throw:
		b.shot_result_pending = false
		# Keep the ball dropping through the iron and the net, same as a
		# live jumper — then count the point once it has gone through.
		var hoop: Vector2 = hoops[0] if b.global_position.x < 0 else hoops[1]
		b.live = false
		b.dunk_drop = 1.0
		b.global_position = hoop
		b.h = RIM_HEIGHT + 8.0
		Sfx.play("swish", -4.0)
		Sfx.cheer(false)
		Events.popup.emit("+1", hoop, Color(0.7, 1.0, 0.75), false)
		_net_bump(0 if hoop.x < 0 else 1, 1.0)
		_rim_fx("swish", hoop)
		b.is_free_throw = false
		_on_ft_result(true)
		return
	var shooter: BallPlayer = b.shooter
	var beyond_arc: bool = px_to_ft(shooter.global_position.distance_to(hoop_for(shooter.team))) > Court.THREE_FT
	# Street 1v1 scores 1s and 2s; full games score 2s and 3s.
	var pts: int = (2 if beyond_arc else 1) if one_on_one else (3 if beyond_arc else 2)
	total_makes += 1
	_add_score(shooter, pts)
	Sfx.play("swish", -1.5 if b.swish_clean else -3.5)
	Sfx.cheer(beyond_arc)
	Events.shake.emit(0.5 if beyond_arc else 0.32)
	Events.popup.emit("+%d%s" % [pts, "  THREE!" if beyond_arc and not one_on_one else ""],
		hoop_for(shooter.team),
		Color(0.45, 0.85, 1.0) if beyond_arc else Color(0.7, 1.0, 0.75),
		beyond_arc)
	Events.score_changed.emit(score[0], score[1])
	momentum = clampf(momentum + (0.18 if shooter.team == 0 else -0.18), -1.0, 1.0)
	if shooter.is_user:
		box["pts"] += pts
		box["fgm"] += 1
		if pts == 3: box["tpm"] += 1
	elif last_passer != null and last_passer.is_user and shooter.team == 0:
		box["ast"] += 1
	b.shot_result_pending = false
	b.live = false
	# Drop THROUGH the net like the street court, then inbound.
	var hoop: Vector2 = hoop_for(shooter.team)
	b.dunk_drop = 1.0
	b.global_position = hoop
	b.h = RIM_HEIGHT + 8.0
	_net_bump(0 if hoop.x < 0.0 else 1, 1.0)
	_rim_fx("swish", hoop)
	await get_tree().create_timer(0.55).timeout
	if not is_instance_valid(self) or finished:
		return
	if one_on_one:
		if score[shooter.team] >= target_score:
			_finish()
			return
		possession = shooter.team
		_check_ball(shooter.team)
		return
	_inbound(1 - shooter.team)

## 1v1 restart: both at the top of the key; CHECK delivers the ball.
func _check_ball(team: int) -> void:
	possession = team
	play_live = false
	restarting = true
	awaiting_check = true
	if finished:
		return
	shot_clock = 18.0
	var off: BallPlayer = players.filter(func(p): return p.team == team)[0]
	var def: BallPlayer = players.filter(func(p): return p.team != team)[0]
	var rim := hoop_for(team)
	off.global_position = rim + Vector2(-420.0, 0.0)
	def.global_position = rim + Vector2(-300.0, 0.0)
	off.velocity = Vector2.ZERO
	def.velocity = Vector2.ZERO
	for p in players:
		p.has_ball = false
	if ball:
		ball.detach()
		ball.live = false
		ball.global_position = off.global_position
		ball.h = 40.0
	must_clear = true
	Events.toast.emit("CHECK THE BALL  %d - %d" % [score[0], score[1]])
	if team == 1:
		# Palla dell'avversario: il check lo esegue LUI da solo, il bottone
		# CHECK resta solo per i tuoi palloni.
		await get_tree().create_timer(0.9).timeout
		if is_inside_tree() and awaiting_check and not finished:
			confirm_check()

func confirm_check() -> void:
	if not awaiting_check or finished:
		return
	awaiting_check = false
	restarting = false
	var offs: Array = players.filter(func(p): return p.team == possession)
	if offs.is_empty():
		return
	give_ball(offs[0])
	play_live = true
	must_clear = true
	Sfx.play("go")
	Sfx.add_hype(0.2)
	Events.toast.emit("GO!")

func resolve_missed_shot(b: Ball) -> void:
	b.shot_result_pending = false
	if b.is_free_throw:
		# A missed free throw has no rebound battle: the sequence continues.
		_rim_fx("iron" if b.global_position.distance_to(hoops[0] if b.global_position.x < 0 else hoops[1]) < 80.0 else "miss", b.global_position)
		b.is_free_throw = false
		_on_ft_result(false)
		return
	momentum = lerpf(momentum, 0.0, 0.2)
	_rim_fx("miss", b.global_position)
	# rebound: nearest players contest, weighted by rebound rating + height
	var best: BallPlayer = null
	var best_w := -1.0
	for p in players:
		var d := p.global_position.distance_to(b.global_position)
		if d > 260.0: continue
		var w: float = (p.ratings["rebound"] / 99.0) * p.height_f * (1.0 - d / 260.0) * randf_range(0.6, 1.4)
		if p.has_badge("glass_cleaner"): w *= 1.1
		if w > best_w:
			best_w = w
			best = p
	if best == null:
		_restart_play(1 - b.last_touch_team)
		return
	give_ball(best)
	shot_clock = 18.0
	if best.is_user: box["reb"] += 1
	Events.toast.emit("Rebound #%d" % best.jersey_num)

func _inbound(team: int) -> void:
	possession = team
	restarting = true
	play_live = false
	if finished: return
	var scored_hoop: Vector2 = hoop_for(1 - team)
	# the inbounder stands OUTSIDE the court, behind the baseline
	var baseline_x: float = signf(scored_hoop.x) * (COURT_W * 0.5 + 46.0)
	var mates: Array = players.filter(func(p): return p.team == team)
	var inbounder: BallPlayer = mates[mates.size() - 1]
	var receiver: BallPlayer = mates[0]
	inbounder.global_position = Vector2(baseline_x, 0.0)
	inbounder.velocity = Vector2.ZERO
	if receiver != inbounder:
		receiver.global_position = Vector2(baseline_x - signf(baseline_x) * 220.0, 0.0)
		receiver.velocity = Vector2.ZERO
	for p in players:
		p.has_ball = false
	give_ball(inbounder)
	Events.toast.emit("Inbound")
	_inbounder = inbounder
	_inbound_receiver = receiver
	# YOUR ball after a basket: the inbound is NOT automatic. Everyone keeps
	# moving, you can call for it where you want (PASS/SHOOT); after 3 s the
	# inbounder gives it to a team-mate on his own.
	var human_wait: bool = team == 0 and user != null and bool(user.is_user) \
		and user_on_court and user != inbounder and not one_on_one
	if human_wait:
		inbound_wait = 3.0
		Events.toast.emit(Loc.tx("Call it! (pass button)"))
		return
	await get_tree().create_timer(0.85).timeout
	_finish_inbound(null)

## Ends the inbound wait: pass to `caller` if he called for it, otherwise to
## the default receiver (a team-mate, never the inbounder himself).
func _finish_inbound(caller: BallPlayer) -> void:
	if finished or not restarting:
		return
	restarting = false
	inbound_wait = 0.0
	var target: BallPlayer = caller
	if target == null or target == _inbounder or not is_instance_valid(target):
		target = _inbound_receiver
	if _inbounder != null and is_instance_valid(_inbounder) \
	and target != null and is_instance_valid(target) and target != _inbounder:
		_inbounder.do_pass(target)
	shot_clock = 18.0
	play_live = true

# ------------------------------------------------------------------ passing / turnovers
func do_pass(from: BallPlayer, to: BallPlayer) -> void:
	last_passer = from
	last_pass_time = Time.get_ticks_msec() / 1000.0
	var speed: float = lerpf(560.0, 920.0, from.ratings["pass"] / 99.0)
	# Straight chest pass at the receiver's chest — never a lob into space.
	ball.pass_to(from.global_position + Vector2(0, -40), to.global_position + Vector2(0, -40), speed, from)
	# interception check along the lane — rare, only a hand right on the line
	for d in players:
		if d.team == from.team: continue
		var seg := to.global_position - from.global_position
		var t: float = clampf((d.global_position - from.global_position).dot(seg) / maxf(seg.length_squared(), 1.0), 0.0, 1.0)
		var closest := from.global_position + seg * t
		var off := d.global_position.distance_to(closest)
		if off < 18.0 and t > 0.25 and t < 0.75 \
		and randf() < (d.ratings["steal"] / 99.0) * 0.035 * (1.0 - off / 18.0):
			await get_tree().create_timer(0.18).timeout
			if finished: return
			give_ball(d)
			Events.toast.emit("Intercepted!")
			if from.is_user: box["tov"] += 1
			return
	await get_tree().create_timer(maxf(from.global_position.distance_to(to.global_position) / speed, 0.12)).timeout
	if finished or ball.holder != null: return
	give_ball(to)

func on_turnover(from: BallPlayer, to: BallPlayer) -> void:
	if from.is_user: box["tov"] += 1
	give_ball(to)
	Events.toast.emit("Turnover")

## Infrazione di passi dopo una finta (palla raccolta): annuncio e cambio
## possesso, stesso percorso del shot clock violation.
func travel_violation(p: BallPlayer) -> void:
	Events.toast.emit("Traveling!")
	_turnover_to(1 - p.team)

## Ripartenza palla ferma: nel 5v5 rimessa dalla linea, nell'1v1 SEMPRE
## check-ball (strada: nessuna rimessa, solo check dopo canestro/out).
func _restart_play(team: int) -> void:
	if one_on_one:
		_check_ball(team)
	else:
		_inbound(team)

func _turnover_to(team: int) -> void:
	possession = team
	_reset_possession(false)

func call_foul(defender: BallPlayer, victim: BallPlayer, pts_attempt := 0) -> void:
	Events.toast.emit("Foul on #%d" % defender.jersey_num)
	possession = victim.team
	if defender.is_user:
		stat_add("pf", 1)
	# Every foul sends the fouled man to the line: 2 shots, or 3 when the
	# contact came on a three-point attempt.
	var shots := 3 if pts_attempt >= 3 else 2
	_start_free_throws(victim, shots)

# ------------------------------------------------------------------ free throws
## The clock STOPS (play_live goes false), the fouled player walks to the
## middle of the free-throw line and takes his shots. Everything else on the
## floor freezes until the last one lands.
func _start_free_throws(victim: BallPlayer, shots: int) -> void:
	play_live = false
	restarting = true
	ft_active = true
	ft_shooter = victim
	ft_total = shots
	ft_left = shots
	ft_timer = 1.0
	var hoop := hoop_for(victim.team)
	var dir := -1.0 if hoop.x > 0.0 else 1.0
	victim.global_position = hoop + Vector2(dir * FT_PX, 0.0)
	victim.velocity = Vector2.ZERO
	victim.move_input = Vector2.ZERO
	# Everyone else steps out of the lane, so the line is clear.
	var side := 1.0
	for p in players:
		if p == victim:
			continue
		p.global_position = hoop + Vector2(dir * (FT_PX + 240.0), side * 180.0)
		p.velocity = Vector2.ZERO
		p.move_input = Vector2.ZERO
		side = -side
	if ball != null:
		ball.live = false
		ball.shot_result_pending = false
	give_ball(victim)
	Events.toast.emit("Free throws ×%d" % shots)

## The user's shot-meter release lands here; NPC shooters run a timed routine
## in _process instead.
func free_throw_release(shooter: BallPlayer, err: float) -> void:
	if not ft_active or shooter != ft_shooter:
		return
	_ft_shoot(err)

func _ft_shoot(err: float) -> void:
	if ball == null or ft_shooter == null or not ft_active:
		return
	var q := clampf(1.0 - absf(err) * 3.0, 0.0, 1.0)
	var made := randf() < clampf(q * (0.60 + float(ft_shooter.ratings["close"]) / 200.0), 0.05, 0.97)
	var hoop := hoop_for(ft_shooter.team)
	Sfx.play("shot_release", -8.0)
	ball.shoot(ft_shooter.global_position + Vector2(0, -50), hoop, 420.0, 0.75, made, ft_shooter)
	# Flag AFTER shoot(): shoot() resets the flag to false for every launch.
	ball.is_free_throw = true
	ft_shooter.has_ball = false
	if ft_shooter.is_user:
		stat_add("fta", 1)

## NPC free-throw routine: aim, breathe, release on a rhythm. The user's
## release is driven by the shot meter in MatchScene, so this does nothing
## while the fouled player is human.
func _process(delta: float) -> void:
	_process_bench_and_timeouts(delta)
	if not ft_active or finished:
		return
	if ft_shooter == null or not is_instance_valid(ft_shooter):
		_end_free_throws()
		return
	if ft_shooter.is_user:
		return
	ft_timer -= delta
	if ft_timer <= 0.0:
		ft_timer = 1.05
		var skill: float = float(ft_shooter.ratings["close"]) / 99.0
		_ft_shoot(randf_range(0.05, 0.30) * lerpf(1.4, 0.55, skill))

func _on_ft_result(made: bool) -> void:
	ft_left -= 1
	if made:
		_add_score(ft_shooter, 1)
		if ft_shooter.is_user:
			stat_add("pts", 1)
			stat_add("ftm", 1)
		Events.toast.emit("Free throw made")
	else:
		Events.toast.emit("Free throw miss")
	if ft_left <= 0:
		_end_free_throws()
	else:
		give_ball(ft_shooter)
		ft_timer = 0.9

func _end_free_throws() -> void:
	ft_active = false
	var shooter := ft_shooter
	ft_shooter = null
	if ball != null:
		ball.is_free_throw = false
	restarting = false
	if finished or shooter == null or not is_instance_valid(shooter):
		return
	play_live = true
	# The other team takes over after the last free throw.
	_restart_play(1 - shooter.team)

# ------------------------------------------------------------------ helpers
func hoop_for(team: int) -> Vector2:
	## The basket this team attacks.
	return hoops[1] if team == 0 else hoops[0]

func px_to_ft(px: float) -> float:
	return px / PX_PER_FT

func pressure_on(p: BallPlayer) -> float:
	var c := 0.0
	for d in players:
		if d.team == p.team: continue
		c = maxf(c, d.contest_value_against(p.global_position))
	return c

func pressure_dir(p: BallPlayer) -> Vector2:
	var v := Vector2.ZERO
	for d in players:
		if d.team == p.team: continue
		var off := d.global_position - p.global_position
		if off.length() < 140.0:
			v += off.normalized() * (1.0 - off.length() / 140.0)
	return v.limit_length(1.0)

func best_pass_option(from: BallPlayer) -> BallPlayer:
	var best: BallPlayer = null
	var best_score := -999.0
	for p in players:
		if p.team != from.team or p == from: continue
		var open := 1.0 - pressure_on(p)
		var hoop_d := px_to_ft(p.global_position.distance_to(hoop_for(p.team)))
		var s: float = open * 2.0 - hoop_d * 0.03 - from.global_position.distance_to(p.global_position) / 600.0
		if s > best_score:
			best_score = s
			best = p
	return best

func nearest_opponent_unmarked(d: BallPlayer) -> BallPlayer:
	var best: BallPlayer = null
	var bd := 1e9
	for p in players:
		if p.team == d.team: continue
		var dist := p.global_position.distance_to(d.global_position)
		if dist < bd:
			bd = dist
			best = p
	return best

# ------------------------------------------------------------------ man marking
## Man-to-man defence: every AI defender on `d`'s team is assigned exactly ONE
## opponent, and the assignment sticks (rebalanced about once a second). Before
## this each defender simply chased the nearest man, so three team-mates could
## all crowd one attacker while the other two ran free.
var _man_marks := {}              # defender instance_id -> opponent instance_id
var _man_team := -1
var _man_stamp := -10000

func man_mark_for(d: BallPlayer) -> BallPlayer:
	var now: int = Time.get_ticks_msec()
	if _man_team != d.team or now - _man_stamp > 900:
		_assign_man(d.team, now)
	var want: int = _man_marks.get(d.get_instance_id(), 0)
	if want == 0:
		return null
	for p in players:
		if p.get_instance_id() == want:
			return p
	return null

func _assign_man(team: int, now: int) -> void:
	_man_team = team
	_man_stamp = now
	_man_marks.clear()
	var defenders := []
	var opponents := []
	for p in players:
		if p.team == team:
			defenders.append(p)
		else:
			opponents.append(p)
	# Greedy closest-first pairing, so nobody double-teams and nobody runs free.
	var free_def: Array = defenders.duplicate()
	var free_opp: Array = opponents.duplicate()
	while not free_def.is_empty() and not free_opp.is_empty():
		var best_d: BallPlayer = null
		var best_o: BallPlayer = null
		var bd := 1e18
		for dd in free_def:
			var dref: BallPlayer = dd
			for oo in free_opp:
				var oref: BallPlayer = oo
				var dist: float = dref.global_position.distance_to(oref.global_position)
				if dist < bd:
					bd = dist
					best_d = dref
					best_o = oref
		_man_marks[best_d.get_instance_id()] = best_o.get_instance_id()
		free_def.erase(best_d)
		free_opp.erase(best_o)

func random_offensive_spot(team: int, p: BallPlayer) -> Vector2:
	var hoop := hoop_for(team)
	var side := signf(hoop.x)
	return Vector2(hoop.x - side * randf_range(160, 480), randf_range(-COURT_H * 0.42, COURT_H * 0.42))

func clamp_to_court(p: Node2D) -> void:
	# the inbounder may stand behind his baseline while the ball is dead
	var lim_x: float = COURT_W * 0.5 - 30.0
	if restarting and _inbounder != null and p == _inbounder:
		lim_x = COURT_W * 0.5 + 80.0
	p.global_position.x = clampf(p.global_position.x, -lim_x, lim_x)
	p.global_position.y = clampf(p.global_position.y, -COURT_H * 0.5, COURT_H * 0.5)

func stat_add(k: String, v: int) -> void:
	box[k] = box.get(k, 0) + v


# ============================================================ benches / subs
func _build_bench_roster() -> void:
	var names := ["Bench A", "Bench B", "Bench C", "Bench D", "Bench E"]
	var pool := ["Santos", "Keller", "Okafor", "Vidal", "Novak", "Amari",
		"Duarte", "Pelle", "Bruno", "Yusuf"]
	for t in 2:
		bench_roster[t].clear()
		for i in 5:
			bench_roster[t].append({
				"jersey": 21 + i * 2 + t,
				"name": pool.pick_random(),
			})

func seat_world(t: int, i: int) -> Vector2:
	var x: float = (-560.0 + i * 80.0) if t == 0 else (560.0 - i * 80.0)
	# Far sideline, centred around the scorer's table: benches left/right.
	return Vector2(x, -(COURT_H * 0.5 + 44.0))

func coach_world(t: int) -> Vector2:
	return Vector2(-660.0 if t == 0 else 660.0, -(COURT_H * 0.5 + 36.0))

## Snapshot for CourtVisual: every seated person + both coaches.
func _refresh_bench_vis() -> void:
	bench_seats_vis.clear()
	if not is_fixture:
		bench_version += 1
		return
	for t in 2:
		var col: Color = Game.team_colour(t)
		bench_seats_vis.append({"pos": coach_world(t), "col": col, "kind": "coach",
			"seed": t * 5 + 1})
		var n: int = bench_roster[t].size()
		for i in n:
			# team 0: seat 0 is the user's, seat 4 the sub's -- hide whoever
			# is currently walking (the live nodes draw those).
			if t == 0 and i == USER_SEAT:
				# Draw the user seated only once he has actually arrived
				# (while walking off, his live node is the visual).
				if not user_on_court and not user.leaving:
					bench_seats_vis.append({"pos": seat_world(0, i), "col": col,
						"kind": "user", "jersey": user.jersey_num, "seed": i * 3})
				continue
			if t == 0 and i == PARTNER_SEAT and sub_partner != null \
					and is_instance_valid(sub_partner) and not sub_partner.leaving:
				continue
			var r: Dictionary = bench_roster[t][i]
			bench_seats_vis.append({"pos": seat_world(t, i), "col": col,
				"kind": "player", "jersey": int(r["jersey"]), "seed": i * 3 + t})
	bench_version += 1

func impact_grade() -> float:
	var raw: float = float(box["pts"]) + float(box["ast"]) + float(box["reb"]) \
		+ 1.5 * (float(box["stl"]) + float(box["blk"])) - 2.0 * float(box["tov"])
	return raw / maxf(1.0, played_time / 60.0)

func _coach_eval() -> void:
	if finished:
		return
	var grade := impact_grade()
	if user_on_court:
		if user.stamina < 30.0 and played_time > 40.0:
			Events.toast.emit(Loc.tx("Coach: you are running on fumes -- rest!"))
			bench_user()
		elif played_time > 75.0 and grade < 1.2:
			Events.toast.emit(Loc.tx("Coach: to the bench! Make an impact out there"))
			bench_user()
	else:
		var deficit: int = int(score[1]) - int(score[0])
		if benched_time > 65.0 or deficit >= 8 or (user.stamina > 88.0 and benched_time > 30.0):
			Events.toast.emit(Loc.tx("Coach: you are back in -- make it count!"))
			unbench_user()

## Sub the USER off: he walks to the bench while his reserve walks on.
func bench_user() -> void:
	if not is_fixture or not user_on_court or finished:
		return
	# Only at a safe moment: never mid-shot, mid-FT or holding the rock.
	if ft_active or user.has_ball or user.shot_charge >= 0.0 \
			or (ball != null and ball.live and ball.shooter == user):
		bench_request = true
		return
	bench_request = false
	user_on_court = false
	var sub := preload("res://src/match/Player.gd").new()
	sub.team = 0
	add_child(sub)
	_randomize_npc(sub, 0)
	var r: Dictionary = bench_roster[0][PARTNER_SEAT]
	sub.jersey_num = int(r["jersey"])
	sub.display_name = String(r["name"])
	sub.global_position = seat_world(0, PARTNER_SEAT)
	sub.entering = true
	sub.bench_target = _formation_pos(0, 0)
	sub_partner = sub
	# the reserve waits on the sideline until you have actually walked off
	sub.set_meta("wait_sub", true)
	user.leaving = true
	user.bench_target = seat_world(0, USER_SEAT)
	_refresh_bench_vis()

## Send the USER back on: he walks in, the reserve walks off.
func unbench_user() -> void:
	if not is_fixture or user_on_court or finished:
		return
	if sub_partner == null or not is_instance_valid(sub_partner):
		user_on_court = true
		user.entering = false
		user.leaving = false
		user.visible = true
		bench_changed.emit(false)
		_refresh_bench_vis()
		return
	if ft_active or sub_partner.has_ball \
			or (ball != null and ball.live and ball.shooter == sub_partner):
		unbench_request = true
		return
	unbench_request = false
	sub_partner.leaving = true
	sub_partner.bench_target = seat_world(0, PARTNER_SEAT)
	user.visible = true
	user.global_position = seat_world(0, USER_SEAT)
	user.velocity = Vector2.ZERO
	user.entering = true
	user.bench_target = _formation_pos(0, 0)
	_refresh_bench_vis()

func _process_subs(delta: float) -> void:
	for p in [user, sub_partner]:
		if p == null or not is_instance_valid(p):
			continue
		if not (p.entering or p.leaving):
			continue
		if p.entering and p.has_meta("wait_sub"):
			# real subs enter once the outgoing player has reached the bench
			var out_gone: bool = (p == sub_partner and user != null and not user.leaving
				and not user_on_court) or (p == user and sub_partner == null)
			if p == user and sub_partner != null and is_instance_valid(sub_partner):
				out_gone = not sub_partner.leaving
			if not out_gone:
				continue
			p.remove_meta("wait_sub")
		var d: Vector2 = p.bench_target - p.global_position
		if d.length() > 24.0:
			p.global_position += d.normalized() * minf(330.0 * delta, d.length())
			p.velocity = d.normalized() * 300.0
			if absf(d.x) > 4.0:
				p.facing = signf(d.x)
			continue
		p.velocity = Vector2.ZERO
		if p.entering:
			p.entering = false
			if p == user:
				user_on_court = true
				if not players.has(user):
					players.append(user)
				_set_brains_active(user, true)
				bench_changed.emit(false)
				_refresh_bench_vis()
			elif p == sub_partner:
				if not players.has(p):
					players.append(p)
				var brain := preload("res://src/match/AIBrain.gd").new()
				p.add_child(brain)
				brain.setup(p, self)
		elif p.leaving:
			p.leaving = false
			if p == user:
				if players.has(user):
					players.erase(user)
				user.visible = false
				_set_brains_active(user, false)
				benched_time = 0.0
				bench_changed.emit(true)
				_refresh_bench_vis()
			elif p == sub_partner:
				if players.has(p):
					players.erase(p)
				sub_partner.queue_free()
				sub_partner = null
				_refresh_bench_vis()

# ================================================================== timeouts
func call_timeout(team: int) -> bool:
	if one_on_one or finished or timeout_active > 0.0 or restarting or ft_active:
		return false
	if timeouts_left[team] <= 0:
		Events.toast.emit(Loc.tx("No timeouts left!"))
		Sfx.play("beep", -6.0)
		return false
	timeouts_left[team] -= 1
	timeout_team = team
	timeout_active = 4.0
	play_live = false
	if ball != null and ball.live:
		ball.kill_analytic()
		ball.live = false
		ball.vel = Vector2.ZERO
		ball.shot_result_pending = false
	Sfx.add_hype(0.15)
	Events.toast.emit("TIMEOUT  -  " + Loc.tx("%d left") % timeouts_left[team])
	return true

func _resume_after_timeout() -> void:
	if finished:
		return
	var team := timeout_team
	possession = team
	shot_clock = 18.0
	must_clear = false
	var mates: Array = players.filter(func(q): return q.team == team)
	if mates.is_empty():
		_play_on()
		return
	var pg: BallPlayer = mates[0]
	for q in players:
		q.has_ball = false
	pg.global_position = Vector2(-140.0 if team == 0 else 140.0, 60.0)
	pg.velocity = Vector2.ZERO
	give_ball(pg)
	play_live = true
	Sfx.play("go")

func _play_on() -> void:
	play_live = true

func _process_bench_and_timeouts(delta: float) -> void:
	if finished:
		return
	if timeout_active > 0.0:
		timeout_active -= delta
		if timeout_active <= 0.0:
			_resume_after_timeout()
	_process_subs(delta)
	if not is_fixture or not play_live:
		return
	if user_on_court:
		played_time += delta
	else:
		benched_time += delta
		if user != null:
			user.stamina = minf(100.0, user.stamina + 9.0 * delta)
	eval_t += delta
	if eval_t >= 22.0:
		eval_t = 0.0
		_coach_eval()
	if bench_request and user_on_court:
		bench_user()
	if unbench_request and not user_on_court:
		unbench_user()
	# Scripted rotation: whatever the stats say, the coach rests you at least
	# twice a game and sends you back in -- minutes are earned, not given.
	if script_idx < script_plan.size():
		var elapsed: float = (quarter - 1) * quarter_len + (quarter_len - game_clock)
		while script_idx < script_plan.size() and elapsed >= float(script_plan[script_idx]["t"]):
			var a: int = int(script_plan[script_idx]["a"])
			script_idx += 1
			if a == 0 and user_on_court:
				Events.toast.emit(Loc.tx("Coach: planned rest -- to the bench"))
				bench_user()
			elif a == 1 and not user_on_court:
				Events.toast.emit(Loc.tx("Coach: back in, go get them!"))
				unbench_user()


## Pause/resume any AIBrain children (driven-user safety while benched).
func _set_brains_active(p: BallPlayer, on: bool) -> void:
	if p == null:
		return
	for c in p.get_children():
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("AIBrain.gd"):
			c.set_physics_process(on)
