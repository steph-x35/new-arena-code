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
const SIDE_RIM_HIGH := 136.0    # canestro laterale ALTO: 2,20 m (reg. 2,00-2,20) — ruolo 2
const SIDE_RIM_LOW := 74.0     # canestro laterale BASSO: 1,20 m (reg. 1,00-1,20) — ruolo 1
const SIDE_AREA_R := 150.0        # side-area semicircle on the sideline (r = 3 m)
const SIDE_DASH_R := 185.0        # DASHED arc 0,7 m beyond the area (r = 3,70 m):
                                  # the 2R and the role-3 free throws shoot from behind it
const SIDE_INBOUND_MARKS := 100.0  # restart 2 m beyond the side area (fig. 2)
const SIDE_PIVOT_RANGE := 226.0    # how far role 2 may wander out with the ball (~4,5 m)
## Rev.19 fig. 2: the 3 m semicircle is split into FIVE sectors whose widths
## along the arc are 200/150/70/150/200 cm (770 cm total). The CENTRAL wedge
## (70 cm, straight in front of the hoop) is the role-2 TWO-point sector;
## every other wedge is a THREE-point sector.
const SIDE_SEC_C_HALF := PI * (70.0 / 770.0) * 0.5      # central sector half-angle (~8.2 deg)
const SIDE_SEC_LAT_MID := PI * ((70.0 + 150.0) * 0.5 / 770.0)  # mid of a 150 cm wedge (~25.7 deg)
const RIM_HEIGHT := 188.0          # px above the floor — the pole must read as 3.05 m tall
# A match player is drawn 56 px tall (~1.93 m). The rim is raised well above
# him so the 3.05 m height reads clearly even in the tilted side view: the
# pole, the board and the open ring visibly hang ABOVE the floor, and the
# player must JUMP to get his hand on the iron.
const PX_PER_FT := 19.0
## One basketball, one size: 7 px like Hoop City (a 54 px player reads ~1.9 m,
## so the ball is ~24 cm across -- regulation). It was 5.5 and looked like a
## marble in the player's hand.
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
var team_fouls := [0, 0]   # defensive fouls this quarter
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
var shot_clock := 24.0
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
# NBA-JAM heat check (da Hoop City): 3 canestri consecutivi dell'UTENTE =
# ON FIRE: finestra del metro piu' larga e palla in fiamme. Solo l'utente:
# l'IA non prende bonus nascosti (GAMEPLAY-IA).
var user_heat := false
var user_streak := 0
var _clutch_slowmo := false      # bullet-time sul tiro decisivo (da Hoop City)
var countdown_hold := 0.0          # bounded presentation pause; never disables recovery forever
var _dead_time := 0.0               # watchdog accumulator, see _deadball_watchdog
var _ghost_t := 0.0                 # ghost-holder accumulator (ball in nobody's hands)
var restarting := false             # true during a scripted inbound/check pause
var awaiting_check := false         # 1v1: CHECK button before the ball is live
var inbound_wait := 0.0             # >0: your inbound, call it or it auto-passes
var intermission := false           # between quarters: teams jog to huddles
var _voice_cd := {}                 # per-shout cooldowns
var _shoot_call := false            # one "shoot!" per possession
var _inbounder: BallPlayer = null
var _inbound_feed := false   # the next do_pass is the inbound feed: always legal
var _inbound_receiver: BallPlayer = null
var pnr_screening := false
var jump_pending := false      # true: al GO si esegue la palla a due
var _qb_inbound := false       # quarters 2-4 open with a baseline inbound
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
var side_hoops := [Vector2(0, -COURT_H * 0.5), Vector2(0, COURT_H * 0.5)]   # baskin: team 0 far, team 1 near
var pivot_bench := [[], []]       # reserve pivots per team (same role as the starter)
var rebound_watch := 0.0          # >0: a pivot's shot is up for a rebound
var rebound_hoop := Vector2.ZERO  # which side basket is involved
var rebound_pivot: BallPlayer = null
var rebound_team := -1
var _illegal_cd := 0.0
var _ill_whistle_cd := 0.0          # "L" fouls: at most one every few seconds
var _ill_dwell := 0.0               # da quanto stai addosso a un uomo illegale
var guard_target: BallPlayer = null # l'uomo che il tasto DIFENDI ti manda a prendere
var ill_mark: BallPlayer = null     # l'uomo che stai marcando ILLEGALMENTE adesso
## PANCHINA VIVA: >0 mentre la panchina della squadra festeggia un canestro.
var bench_cheer := [0.0, 0.0]
# --- sostituzioni dal vivo (v1.15) -----------------------------------------
var sub_pending := []               # richieste di cambio in attesa di palla morta
var _sub_walk := []                 # [uscito, entrato, posto] che stanno camminando
var sub_seat_cd := {}               # cooldown per posto in panchina
const SUB_GAP := 22.0               # secondi prima di riusare lo stesso posto
## TIME INFRACTIONS (Regola 8 baskin): 3" in the key, 5" closely guarded.
var _key_time := {}                 # player id -> seconds spent in the key
var _key_warn_cd := 0.0
var _guard_clock := 0.0             # the handler, guarded and standing still
var _guard_warn_cd := 0.0
var _ft_keep_possession := false  # illegal defense: victim team keeps the ball
var _ends_swapped := false         # after Q2 the teams change ends
var ft_side := false               # this FT series is shot at a small side basket

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
	_build_pivot_bench()
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
			add_child(p)
			if t == 0 and i == 0:
				p.is_user = true
				p.hair_style_v = Game.hair_style()
				p.setup_from_profile()
				user = p
			else:
				_randomize_npc(p, t, i)
				var brain := preload("res://src/match/AIBrain.gd").new()
				p.add_child(brain)
				brain.setup(p, self)
			p.global_position = _formation_pos(t, i)
			var want: int = clampi(int(Game.profile.get("baskin_role", 5)), 1, 5) if not one_on_one else 5
			p.role = _lineup_plan(t, want)[i]
			_apply_role_kit(p)
			if p.role <= 2 and not one_on_one:
				p.global_position = pivot_home(t)
			players.append(p)

## BASKIN rule 1: ONE pivot on the floor at a time. A legal five is
## pivot (role 1 or role 2) + role 3 + role 4 + two role 5 (sum well under 23).
## Team 0 fields the wheelchair pivot unless the player asked for role 2.
func team_pivot_role(t: int) -> int:
	if one_on_one:
		return 0
	if t != 0:
		return 2
	return 2 if clampi(int(Game.profile.get("baskin_role", 5)), 1, 5) == 2 else 1

## Role printed on each shirt, seat by seat (seat 0 is the user's in team 0).
func _lineup_plan(t: int, want: int) -> Array:
	var pivot: int = team_pivot_role(t)
	var rest: Array = [pivot, 3, 4, 5, 5]
	if t != 0:
		return rest
	# The player owns seat 0: give him exactly the role he asked for and
	# reshuffle the other four seats so the five stays legal.
	if want <= 2:
		rest = [3, 4, 5, 5, 5]
	elif want == 3:
		rest = [pivot, 4, 5, 5, 3]
	elif want == 4:
		rest = [pivot, 3, 5, 5, 4]
	var plan: Array = [want]
	for k in 4:
		plan.append(rest[k])
	return plan

func _randomize_npc(p: BallPlayer, t: int, seat := -1) -> void:
	var lvl: int = 48 + int(Game.profile["level"]) * 2
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
		}.get(Game.club_style(opp), [])
		for k in tilt:
			p.ratings[k] = clampi(int(p.ratings[k]) + 6, 30, 95)
		var club_names: Array = Game.club_roster(opp)
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
	# Squadra mista: due donne fisse per squadra (seats 1 and 3), le altre
	# sorteggiate. Le donne portano coda o capelli lunghi, gli uomini un
	# taglio corto normale — niente piu' chiome a caso su tutti.
	p.gender = 1 if (seat == 1 or seat == 3) else (0 if seat >= 0 else (1 if randf() < 0.35 else 0))
	if seat < 0 and randf() < 0.35:
		p.gender = 1
	p.hair_style_v = [6, 7].pick_random() if p.gender == 1 else [0, 0, 0, 1, 4].pick_random()
	p.shoe_col = [Color(0.90, 0.90, 0.92), Color(0.12, 0.12, 0.14),
		Color(0.75, 0.20, 0.20), Color(0.20, 0.35, 0.75), Color(0.90, 0.72, 0.18)].pick_random()

func _formation_pos(t: int, i: int) -> Vector2:
	if one_on_one:
		# Offense checks up at the top of the key, defender between him and the rim.
		var rim: Vector2 = hoops[0]
		return rim + Vector2(-420.0 + t * 150.0, 40.0 if t == 0 else -40.0)
	var side := -1.0 if t == 0 else 1.0
	if _ends_swapped:
		side = -side
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
	_inbound_epoch += 1
	_inbound_preparing = false
	_inbound_requested = false
	inbound_wait = 0.0
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
		var best: BallPlayer = null
		for p in squad:
			if p.role != 5:
				continue
			if best == null or p.height_f > best.height_f:
				best = p
		if best == null:
			best = squad[0]
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
		var best: BallPlayer = null
		for p in squad:
			if p.role != 5:
				continue
			if best == null or p.height_f > best.height_f:
				best = p
		if best == null:
			best = squad[0]
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
	shot_clock = 24.0
	Events.possession_changed.emit(possession)
	var club: String = Game.club_my_team() if win.team == 0 else String(Game.profile.get("next_opponent", ""))
	Events.toast.emit("JUMP BALL  ·  %s" % Game.club_short(club))
	if not one_on_one:
		Events.rule.emit("tip")
	
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
	if _clutch_slowmo:
		_clutch_slowmo = false
		Engine.time_scale = 1.0
	shot_clock = 24.0
	var team_players := players.filter(func(p): return p.team == possession)
	# The ball never teleports to a pivot: only a role 3-5 can carry it.
	var carrier: BallPlayer = null
	for tp in team_players:
		if (tp as BallPlayer).role > 2:
			carrier = tp
			break
	if carrier == null:
		carrier = team_players[0]
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
	p.dribble_t = 0.0
	# Rev.19: quando la palla arriva al pivot di ruolo 2 lui sceglie in quale
	# dei tre settori spostarsi per tirare (centrale = 2, laterale = 3).
	if p.role == 2 and not one_on_one:
		var roll := randf()
		pivot_sector[p.team] = 0 if roll < 0.25 else (1 if roll < 0.625 else -1)
	p.received_in_side_area = in_side_area(p.global_position)
	if changed_hands:
		p.pivot_attempts = 0
	# BASKIN: the pivot's clock starts when the ball reaches him by hand —
	# 10 s for role 1 and for the 2T, 7 s for the 2R.
	for q in players:
		q.no_pivot_return = false
	if p.role <= 2 and last_passer != null and last_passer != p \
	and last_passer.team == p.team \
	and (Time.get_ticks_msec() / 1000.0 - last_pass_time) < 1.4:
		# He took it from a team-mate who came in to hand it over: that mate
		# is the tutor, and the ball may not go straight back to him.
		p.tutor = last_passer
	if p.role == 1:
		p.pivot_clock = 10.0
	elif p.role == 2:
		p.pivot_clock = 7.0 if p.variant == "2R" else 10.0
	else:
		p.pivot_clock = 0.0
	if p.role <= 2:
		pivot_last_touch[p.team] = Time.get_ticks_msec() / 1000.0

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
		var near_hoop: Vector2 = nearest_hoop(ball.global_position)
		var pick_rh: float = ball.shot_rim_h if ball.shot_rim_h > 0.0 else rim_height_of(near_hoop)
		if ball.h > pick_rh - 45.0:
			return false
		if ball.global_position.distance_to(near_hoop) < 58.0:
			return false
	# BASKIN: a loose ball lying inside a small side area belongs to the pivot
	# alone — roles 3-5 reaching in would commit an infraction.
	if not one_on_one and p.role > 2 and in_side_area(p.global_position):
		Events.toast.emit(Loc.t("match.area.reach"))
		return false
	var prev_team: int = possession
	give_ball(p)
	# Rebounds: the pivot who grabbed his OWN miss may not shoot again, he
	# must move the ball out to the rebounders.
	if p.role <= 2:
		if rebound_watch > 0.0 and ball.shooter != null and ball.shooter == p:
			p.own_miss_rebound = true
			p.pivot_clock = 10.0 if p.wheelchair else 5.0
	shot_clock = maxf(shot_clock, 14.0)
	_shoot_call = false
	if p.is_user: box["reb"] += 1
	Events.toast.emit("Loose ball!")
	# A DEFENSIVE rebound is a change of possession like any other: whistle
	# and throw it in (an offensive rebound stays live).
	_after_loose_grab(p, prev_team)
	return true

## The user calls for the ball. The handler passes if the lane is reasonable,
## which makes GET BALL useful even when the ball is nowhere near you.
func request_pass(to: BallPlayer) -> bool:
	if (inbound_wait > 0.0 or _inbound_preparing) and to.team == possession and to != _inbounder:
		_finish_inbound(to)
		return true
	var h: BallPlayer = ball_handler()
	if h == null or h == to or h.team != to.team:
		return false
	# Call for it when you are open: team-mate gives it back.
	if to.role <= 2 and not in_side_area(h.global_position):
		Events.toast.emit(Loc.t("match.deliver.need_area"))
		return false
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
	if restarting and not ft_active and from == _inbounder:
		_finish_inbound(best)
		return true
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
		if p == from or p.team != from.team or p.role <= 2 or p.is_user or p.entering or p.leaving:
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
	var from_inside: bool = in_side_area(from.global_position)
	for p in players:
		if p == from or p.team != from.team:
			continue
		# BASKIN: the pivot takes the ball ONLY from a hand inside the area,
		# so from the outside he is not even a passing option (no highlight).
		if p.role <= 2 and not from_inside:
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
	_deadball_watchdog(delta)
	# THE GHOST-HOLDER NET. If the ball is still attached to somebody who does
	# not own it any more, NOBODY can grab it (try_grab refuses while a holder
	# exists), ball_handler() sees nobody and the possession rots on the shot
	# clock. Two causes are fixed upstream (refused pass, blocked dunk); this
	# net catches any future one within half a second.
	# A pass is CAUGHT, not chased: the ball homes to the hands, and the moment
	# it is there the receiver takes it (the magnet closes the pass).
	if play_live and ball != null and ball.live and is_instance_valid(ball.pass_target) \
	and ball.pass_target is BallPlayer:
		var pt: BallPlayer = ball.pass_target
		if pt.ball_anchor().distance_to(ball.global_position) < 26.0 and ball.h < 175.0:
			var pf: BallPlayer = ball.pass_from if is_instance_valid(ball.pass_from) and ball.pass_from is BallPlayer else null
			ball.pass_target = null
			_catch_pass(pf, pt)
	if play_live and ball != null and is_instance_valid(ball.holder) and ball.holder is BallPlayer and not ball.holder.has_ball:
		_ghost_t += delta
		if _ghost_t > 0.4:
			_ghost_t = 0.0
			var gh: BallPlayer = ball.holder
			gh.has_ball = true
			gh.possession_time = 0.0
			possession = gh.team
	else:
		_ghost_t = 0.0
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
	_baskin_clocks(delta)
	_time_infractions(delta)
	_charge_check(delta)
	bench_cheer[0] = maxf(0.0, bench_cheer[0] - delta)
	bench_cheer[1] = maxf(0.0, bench_cheer[1] - delta)
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
## Who touched the ball last (1v1 and dead starts included).
func last_touch_team() -> int:
	if ball != null and ball.shooter != null and is_instance_valid(ball.shooter):
		return ball.shooter.team
	if ball != null:
		return int(ball.last_touch_team)
	return possession

func _deadball_watchdog(delta: float) -> void:
	if ball == null: return
	if countdown_hold > 0.0:
		countdown_hold = maxf(0.0, countdown_hold - delta)
		_dead_time = 0.0
		return
	if restarting:
		_dead_time = 0.0
		return
	# Ball dead and NOBODY restarting: an interrupted inbound (a whistle in the
	# middle of it) used to leave the match frozen with `play_live` off for
	# ever. Whistle it back into play from the sideline.
	if not play_live:
		if finished or ft_active or intermission or timeout_active > 0.0 or inbound_wait > 0.0 \
		or jump_pending or awaiting_check:
			_dead_time = 0.0
			return
		_dead_time += delta
		if _dead_time < 3.0:
			return
		_dead_time = 0.0
		push_warning("Stuck possession recovered by watchdog")
		Events.toast.emit("Restart")
		_restart_play(possession)
		return
	# A holder who does NOT own the ball is not a live possession: without
	# `and has_ball` a ghost holder kept the watchdog convinced the ball was
	# being played, for the whole shot clock.
	var alive: bool = (ball.holder != null and ball.holder.has_ball) \
		or (ball.live and ball.vel.length() > 12.0) \
		or ball.shot_result_pending or ball.dunk_drop > 0.0
	if alive:
		_dead_time = 0.0
		return
	# Out of bounds: a ball rolling off the court can never be reached (the
	# players are clamped inside), so it used to keep the possession alive for
	# the whole shot clock. Whistle it out and throw it in from the sideline.
	var oob: bool = absf(ball.global_position.x) > COURT_W * 0.5 + 46.0 \
		or absf(ball.global_position.y) > COURT_H * 0.5 + 46.0
	if oob and ball.holder == null:
		_dead_time += delta
		if _dead_time < 1.2:
			return
		_dead_time = 0.0
		Events.toast.emit("Out of bounds")
		_restart_play(1 - last_touch_team())
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
		var prev: int = possession
		give_ball(best)
		shot_clock = maxf(shot_clock, 14.0)
		Events.toast.emit("Loose ball recovered")
		_after_loose_grab(best, prev)
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
	if _clutch_slowmo:
		_clutch_slowmo = false
		Engine.time_scale = 1.0
	_inbound_epoch += 1
	_inbound_preparing = false
	_inbound_requested = false
	inbound_wait = 0.0
	if is_fixture and not user_on_court and not finished:
		unbench_user()
		benched_time = 0.0
	if one_on_one:
		# no quarters in a race to 11: the clock is just a safety valve
		game_clock = quarter_len
		return
	Sfx.play("buzzer")
	_close_quarter_book()
	for p in players:
		p.period_makes = 0
		p.period_shots = 0
		p.pivot_attempts = 0
		p.pivot_clock = 0.0
	quarter += 1
	team_fouls = [0, 0]
	if quarter > QUARTERS:
		_finish()
		return
	game_clock = quarter_len
	# CHANGE ENDS at half time: the two baskets swap, so the teams keep
	# attacking the SAME physical basket... no: they switch, and everybody is
	# mirrored to the other half before the new quarter tips off.
	if quarter == 3 and not _ends_swapped:
		_ends_swapped = true
		hoops.reverse()
		side_hoops.reverse()
		_man_team = -1
		_man_stamp = -10000
		for p in players:
			p.global_position = Vector2(-p.global_position.x, -p.global_position.y)
			p.velocity = Vector2.ZERO
		for t in 2:
			for bp in pivot_bench[t]:
				bp.global_position = Vector2(-bp.global_position.x, -bp.global_position.y)
		Events.toast.emit(Loc.t("t.change_ends"))
	possession = 1 - possession
	_qb_inbound = true
	play_live = false
	restarting = false
	shot_clock = 24.0
	for p in players:
		p.has_ball = false
	ball.holder = null
	ball.live = false
	ball.visible = false
	Events.quarter_ended.emit(quarter)
	Events.toast.emit("T%d" % quarter)

func _finish() -> void:
	if _clutch_slowmo:
		_clutch_slowmo = false
		Engine.time_scale = 1.0
	_inbound_epoch += 1
	_inbound_preparing = false
	_inbound_requested = false
	inbound_wait = 0.0
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
	res["arena"] = Game.scrim_arena()
	# The profile (kits, opponent, settings) is saved on the final buzzer so
	# the pre-match screen reopens exactly as it was left.
	SaveSystem.save_game()
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
	var hoop := attack_hoop_for(shooter)
	if not one_on_one:
		var bk := _baskin_shot_check(shooter, hoop)
		if bk != "":
			_violation(shooter, bk)
			return
	shooter.period_shots += 1
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

	# FADE / REVERSE / HOOK / STEPBACK / FLOATER / PULL-UP: la famiglia dei
	# tiri "scolpiti" di Hoop City. In tutti il contest pesa meno (ti separi
	# dal difensore) ma il timing peggiora. Il popup dice QUALE tiro stai
	# giocando, cosi' il giocatore capisce perche' e' piu' difficile.
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
		# ma il timing diventa molto piu' severo. Da POST la finestra e'
		# piu' corta (9ft): oltre, il post gioca FADEAWAY.
		contest *= 0.45
		timing_err *= 1.30
		Events.popup.emit("HOOK", shooter.global_position, Color(1.0, 0.9, 0.6), true)
	elif shooter.stepback_t > 0.0 and going_away \
	and (dist_ft > THREE_FT or is_side_hoop(hoop)):
		# STEPBACK: spaziati con lo stepback e tira nello spazio creato
		# entro 0.9s: molto spazio (contest basso) ma timing difficile.
		contest *= 0.75
		timing_err *= 1.25
		Events.popup.emit("STEPBACK", shooter.global_position, Color(1.0, 0.65, 0.35), true)
	elif hoop_dir.length() > 40.0 and shooter.velocity.dot(hoop_dir.normalized()) > 120.0 \
	and dist_ft > 6.0 and dist_ft < 16.0 and _nearest_defender_dist(shooter) < 90.0:
		# FLOATER: in corsa al ferro con un difensore addosso (6-16ft) la
		# palla va SOPRA: arco alto, quasi zero contest, difficile da stoppare.
		contest *= 0.5
		timing_err *= 1.15
		_floater_shot = true
		Events.popup.emit("FLOATER", shooter.global_position, Color(0.75, 0.90, 1.0), true)
	elif going_away:
		contest *= 0.62
		timing_err *= 1.15
		Events.popup.emit("FADEAWAY", shooter.global_position, Color(0.72, 0.93, 0.72), true)
	elif shooter.combo_pullup:
		# COMBO PULL-UP (TRICK -> TIRA entro mezzo secondo): tiro in
		# slancio, si vede il popup, timing un filo piu' severo.
		timing_err *= 1.10
		Events.popup.emit("PULL-UP", shooter.global_position, Color(0.65, 0.85, 1.0), true)
	shooter.combo_pullup = false   # la combo vive per un tiro solo

	var res := ShotSystem.resolve({
		"dist_ft": dist_ft, "contest": contest, "timing_err": timing_err,
		"diff": int(Settings.get_v("difficulty", 1)),
		"stamina01": shooter.stamina01(), "momentum": momentum if shooter.team == 0 else -momentum,
		"a_close": shooter.ratings["close"], "a_mid": shooter.ratings["mid"], "a_three": shooter.ratings["three"],
		"badges": shooter.badges, "open_catch": open_catch,
		"moving": shooter.velocity.length() > 90.0,
	})

	total_attempts += 1
	if shooter.variant == "1S" and randf() < 0.85:
		res["made"] = true   # the slide shot almost always drops
	# blocked?
	var blocker := _block_check(shooter, contest)
	if blocker != null:
		Events.toast.emit("BLOCKED by #%d" % blocker.jersey_num)
		Sfx.play("block", -1.0)
		Sfx.ooh()
		Events.shake.emit(0.7)
		Events.popup.emit("BLOCK!", blocker.global_position, Color(1.0, 0.45, 0.3), true)
		res["made"] = false
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
	var bpts: int = _baskin_points(shooter, hoop) if not one_on_one else int(res["points"])
	ball.shot_hoop = hoop
	ball.shot_is_side = is_side_hoop(hoop)
	ball.shot_value = bpts
	ball.shoot(shooter.global_position + Vector2(0, -50), aim, 480.0, flight, res["made"], shooter, rim_height_of(hoop, shooter.role))
	ball.last_touch_team = shooter.team

	# Bullet-time / Slow-mo (da Hoop City): al buzzer o su un tiro clutch
	# decisivo nei finali il tempo si ferma per mezzo respiro.
	var is_clutch_shot: bool = play_live and not one_on_one \
	and (game_clock <= 2.8 or shot_clock <= 1.2 \
	or (quarter >= QUARTERS and absf(score[0] - score[1]) <= 3 and game_clock <= 6.0))
	if is_clutch_shot and Engine.time_scale <= 1.05:
		_clutch_slowmo = true
		Engine.time_scale = 0.45
		Events.popup.emit("CLUTCH!", shooter.global_position + Vector2(0, -70),
			Color(1.0, 0.85, 0.2), true)

	if shooter.is_user:
		box["fga"] += 1
		if bpts == 3: box["tpa"] += 1
		# HEAT CHECK (da Hoop City): terzo canestro di fila = ON FIRE,
		# uno sbagliato = COLD e la serie riparte da zero.
		if bool(res["made"]):
			user_streak += 1
			if user_streak >= 3 and not user_heat:
				user_heat = true
				Events.popup.emit("ON FIRE!", shooter.global_position,
					Color(1.0, 0.55, 0.15), true)
				Sfx.cheer(true)
		else:
			_user_break_heat()
	Events.shot_taken.emit(ShotSystem.timing_name(res["timing"]) + " / " + res["quality"], res["made"], bpts)
	if bool(res["made"]):
		if randf() < 0.55:
			_voice("nice", 2.0)
	else:
		if randf() < 0.50:
			_voice("rebound", 2.5)
		# BASKIN: after the pivot's shot the ball is alive around his area —
		# two rebounders per team from outside, the pivot may step in.
		if shooter.role <= 2 and is_side_hoop(hoop) and not one_on_one:
			_open_pivot_rebound(shooter)
	shot_clock = maxf(shot_clock, 2.0)

func _nearest_defender_dist(shooter: BallPlayer) -> float:
	var best := 99999.0
	for d in players:
		if d.team == shooter.team:
			continue
		var dd: float = d.global_position.distance_to(shooter.global_position)
		best = minf(best, dd)
	return best

## A defender closing out on a shooter can commit a shooting foul. Rare at
## low contest, more likely when he is right in the shooter's landing space.
func _shooting_foul_check(shooter: BallPlayer, contest: float) -> BallPlayer:
	if contest < 0.40:
		return null
	for d in players:
		if d.team == shooter.team: continue
		var dist := d.global_position.distance_to(shooter.global_position)
		if dist > 80.0: continue
		var ch: float = 0.14 * contest * (1.0 - float(d.ratings["defense"]) / 130.0)
		if d.block_window > 0.0:
			ch *= 1.5
		if randf() < ch:
			return d
	return null

func _block_check(shooter: BallPlayer, contest: float) -> BallPlayer:
	for d in players:
		if d.team == shooter.team: continue
		var dist := d.global_position.distance_to(shooter.global_position)
		if dist > 95.0: continue
		# Timed BLOCK: jumping while the shot leaves the hand contests it
		# automatically (see contest_value_against x1.35), but an actual SWAT
		# still has to be earned -- close to the shooter, near the apex of the
		# jump, and with real block rating. A guaranteed swat at 88 px made
		# every gather a turnover.
		if d.block_window > 0.0 and dist < 88.0 and d.air > 8.0:
			var apex_q: float = clampf(1.0 - absf(d.air / d.jump_height() - 0.55) / 0.55, 0.2, 1.2)
			var block_ch: float = clampf(
				(float(d.ratings["block"]) / 99.0) * d.height_f * 0.72
				* (1.15 - dist / 95.0) * apex_q, 0.05, 0.72)
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
		_net_bump(hoop_index_of(nearest_hoop(bp)), 0.4)
		return

func _rim_fx(kind: String, at: Vector2, rh := -1.0) -> void:
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

## IL CANESTRO VIBRA: una scossa che fa tremare ferro, tabellone e retina per
## circa un secondo. La schiacciata la vuole al massimo, il ferro sfiorato un
## filo. La visura la disegna CourtVisual (quake_off), qui si dice solo quando.
func _rim_quake(idx: int, amt: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var vis: Node = parent.get_node_or_null("CourtVisual")
	if vis != null and vis.has_method("rim_quake"):
		vis.rim_quake(idx, amt)

## Scossa sul canestro piu' vicino a un punto del campo.
func _quake_at(at: Vector2, amt: float) -> void:
	_rim_quake(hoop_index_of(nearest_hoop(at)), amt)

func check_ball_collisions(b: Ball) -> void:
	if not b.shot_result_pending: return
	var hoop: Vector2 = hoops[0]
	var _bd := 1e18
	for _h in [hoops[0], hoops[1], side_hoops[0], side_hoops[1]]:
		var _dd: float = b.global_position.distance_to(_h)
		if _dd < _bd:
			_bd = _dd
			hoop = _h
	var _rim_h: float = b.shot_rim_h if b.shot_rim_h > 0.0 else rim_height_of(hoop)
	var _hidx: int = hoop_index_of(hoop)
	# backboard: vertical plane just behind the rim
	var board_x: float = hoop.x + (-42.0 if hoop.x < 0 else 42.0)
	if not is_side_hoop(hoop) and b.h > RIM_HEIGHT - 10 and b.h < RIM_HEIGHT + 90:
		if (hoop.x < 0 and b.global_position.x < board_x and b.vel.x < 0) \
		or (hoop.x > 0 and b.global_position.x > board_x and b.vel.x > 0):
			b.global_position.x = board_x
			b.vel.x = -b.vel.x * 0.55
			b.vel.y *= 0.8
			b.kill_analytic()
			Sfx.play("backboard", -7.0)
			Events.shake.emit(0.28)
			_net_bump(_hidx, 0.35)
			_rim_quake(_hidx, 0.30)
	# Street-court pattern: 2D distance to the ring, swept through the plane.
	var crossed_down := b.prev_h >= _rim_h and b.h <= _rim_h and b.vh < 0.0
	if crossed_down:
		var span := b.prev_h - b.h
		var f: float = 0.0 if span <= 0.0 else (b.prev_h - _rim_h) / span
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
				_rim_fx("rattle", hoop, _rim_h)
				_net_bump(_hidx, 0.9)
				_rim_quake(_hidx, 0.75)
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
			_net_bump(_hidx, 0.85)
			_rim_quake(_hidx, 0.45)
			_rim_fx("iron", hoop, _rim_h)
			Sfx.ooh()
			return
	# Brushing the net below the ring still moves it.
	if b.h < _rim_h and b.h > _rim_h - 130.0 \
	and b.global_position.distance_to(hoop) < 50.0:
		_net_bump(_hidx, 0.45)

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
	for o in players:
		if o.team == p.team or not is_instance_valid(o):
			continue
		if o.block_window > 0.0 and o.global_position.distance_to(p.global_position) < 90.0:
			var stop: float = clampf(float(o.ratings["block"]) / 180.0, 0.04, 0.42)
			if randf() < stop:
				Events.toast.emit("BLOCKED AT THE RIM!")
				p.has_ball = false
				if o.is_user:
					box["blk"] += 1
				# Ball squirts loose away from the rim; whoever grabs it, gets it.
				if ball:
					# GHOST HOLDER: without detach() the ball stayed attached
					# to the blocked dunker (he no longer owns it), so it kept
					# snapping back to his hand and nobody could pick it up.
					ball.detach()
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
	# Il canestro VIBRA: e' la richiesta "la schiacciata fa tremare il ferro".
	_rim_quake(hoop_index_of(hoop_for(p.team)), 1.0)
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
	p.period_shots += 1
	_add_score(p, pts)
	momentum = clampf(momentum + (0.24 if p.team == 0 else -0.24), -1.0, 1.0)
	if p.is_user:
		box["pts"] += pts
		box["fgm"] += 1
		box["fga"] += 1
	Events.shot_taken.emit("DUNK %s" % DunkStyle.label(p.dunk_style), true, pts)
	_net_bump(hoop_index_of(hoop_for(p.team)), 1.0)
	_rim_fx("swish", hoop_for(p.team))
	_rim_quake(hoop_index_of(hoop_for(p.team)), 1.0)
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
		var hoop: Vector2 = nearest_hoop(b.global_position)
		b.live = false
		b.dunk_drop = 1.0
		b.global_position = hoop
		b.h = RIM_HEIGHT + 8.0
		Sfx.play("swish", -4.0)
		Sfx.cheer(false)
		Events.popup.emit("+1", hoop, Color(0.7, 1.0, 0.75), false)
		_net_bump(hoop_index_of(hoop), 1.0)
		_rim_fx("swish", hoop, b.shot_rim_h if b.shot_rim_h > 0.0 else -1.0)
		_rim_quake(hoop_index_of(hoop), 0.55)
		b.is_free_throw = false
		_on_ft_result(true)
		return
	var shooter: BallPlayer = b.shooter
	var hoop: Vector2 = b.shot_hoop if b.shot_hoop.length() > 1.0 else hoop_for(shooter.team)
	var beyond_arc: bool = false if is_side_hoop(hoop) else px_to_ft(shooter.global_position.distance_to(hoop)) > Court.THREE_FT
	# Baskin values ride on the ball (set at release); 1v1 keeps 1s and 2s.
	var pts: int = (2 if beyond_arc else 1) if one_on_one else b.shot_value
	var was_user: bool = shooter.is_user
	shooter.period_makes += 1
	if not one_on_one:
		Events.rule.emit("r%d_make" % shooter.role)
		if shooter.role <= 2 and shooter.period_makes >= 3:
			_substitute_pivot(shooter)
	total_makes += 1
	_add_score(shooter, pts)
	bench_cheer[shooter.team] = 3.0        # la sua panchina si alza
	Sfx.play("swish", -1.5 if b.swish_clean else -3.5)
	Sfx.cheer(beyond_arc)
	Events.shake.emit(0.5 if beyond_arc else 0.32)
	var pop_extra := ""
	if beyond_arc and not one_on_one:
		pop_extra = "  THREE!"
	elif not one_on_one and shooter.role == 2 and is_side_hoop(hoop):
		pop_extra = "  " + (Loc.t("pop.central") if pts == 2 else Loc.t("pop.lateral"))
	Events.popup.emit("+%d%s" % [pts, pop_extra],
		hoop,
		Color(0.45, 0.85, 1.0) if beyond_arc else Color(0.7, 1.0, 0.75),
		beyond_arc)
	Events.score_changed.emit(score[0], score[1])
	momentum = clampf(momentum + (0.18 if shooter.team == 0 else -0.18), -1.0, 1.0)
	if was_user:
		box["pts"] += pts
		box["fgm"] += 1
		if pts == 3: box["tpm"] += 1
	elif last_passer != null and last_passer.is_user and shooter.team == 0:
		box["ast"] += 1
	b.shot_result_pending = false
	b.live = false
	# Drop THROUGH the net like the street court, then inbound.
	b.dunk_drop = 1.0
	b.global_position = hoop
	b.h = rim_height_of(hoop, shooter.role) + 8.0
	_net_bump(hoop_index_of(hoop), 1.0)
	_rim_fx("swish", hoop, rim_height_of(hoop, shooter.role))
	_rim_quake(hoop_index_of(hoop), 0.55)
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
	_inbound(1 - shooter.team, hoop)

## 1v1 restart: both at the top of the key; CHECK delivers the ball.
func _check_ball(team: int) -> void:
	possession = team
	play_live = false
	restarting = true
	awaiting_check = true
	if finished:
		return
	shot_clock = 24.0
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
		var near_hoop: bool = b.global_position.distance_to(nearest_hoop(b.global_position)) < 80.0
		_rim_fx("iron" if near_hoop else "miss", b.global_position)
		b.is_free_throw = false
		# LIBERI SUCCESSIVI: la sequenza continua, niente rimbalzo.
		# ULTIMO LIBERO SBAGLIATO: la palla resta VIVA e si va a rimbalzo
		# (regolamento). Tranne il fallo "L", dove la palla torna comunque
		# alla squadra che ha subito il fallo.
		if ft_left > 1 or _ft_keep_possession or one_on_one:
			_on_ft_result(false)
			return
		_missed_last_free_throw(b)
		return
	if b.shooter != null and is_instance_valid(b.shooter) and b.shooter.role <= 2 and not one_on_one:
		# BASKIN: a pivot's miss stays ALIVE: two players per team crash the
		# board from outside the semicircle while the pivot may step in. If
		# nobody can take it, the ball goes back outside the small areas.
		_open_pivot_rebound(b.shooter)
		return
	if b.shooter != null and is_instance_valid(b.shooter) and b.shooter.variant == "2T" and not one_on_one:
		var tut := tutor_of(b.shooter.team)
		if tut != null and tut != b.shooter:
			give_ball(tut)
			shot_clock = maxf(shot_clock, 14.0)
			Events.toast.emit(Loc.t("t.tutor"))
			Events.rule.emit("tutor")
			return
	momentum = lerpf(momentum, 0.0, 0.2)
	_rim_fx("miss", b.global_position)
	# rebound: nearest players contest, weighted by rebound rating + height
	# Chi e' ARRIVATO per primo ha diritto a prenderla: la distanza conta piu'
	# della valutazione (che resta), e chi e' gia' sul punto di caduta ha un
	# premio. E' la ragione per cui il rimbalzo si anticipa: la palla dice dove
	# arriva, tu ci vai, la palla e' tua.
	var best: BallPlayer = null
	var best_w := -1.0
	for p in players:
		var d := p.global_position.distance_to(b.global_position)
		if d > 260.0: continue
		var near: float = pow(1.0 - d / 260.0, 1.6)
		var w: float = (p.ratings["rebound"] / 99.0) * p.height_f * near * randf_range(0.6, 1.4)
		if d < 55.0: w *= 1.35
		if p.has_badge("glass_cleaner"): w *= 1.1
		if w > best_w:
			best_w = w
			best = p
	if best == null:
		_restart_play(1 - b.last_touch_team)
		return
	give_ball(best)
	shot_clock = 24.0
	if best.is_user:
		box["reb"] += 1
		# Preso da te: si legge subito, come per la schiacciata.
		Events.popup.emit(Loc.t("pop.rebound"), best.global_position,
			Color(0.60, 0.88, 1.0), false)
		Sfx.add_hype(0.05)
	Events.toast.emit(Loc.t("t.rebound") % best.jersey_num)

## A pivot's shot is up for grabs: the two closest role 3-5 of each team
## are the rebounders (four in all, per the regulation), the pivot may enter.
func _open_pivot_rebound(shooter: BallPlayer) -> void:
	rebound_watch = 4.5
	rebound_hoop = side_hoops[shooter.team]
	rebound_pivot = shooter
	rebound_team = shooter.team

## Counts down the rebound window around a side basket. A ball that nobody
## can recover is dead: the pivot shoots it (role 1) or it goes back to the
## opponents, thrown in OUTSIDE the small side areas.
func _area_rebound_tick(delta: float) -> void:
	if rebound_watch <= 0.0:
		return
	if ball == null:
		rebound_watch = 0.0
		return
	if ball.holder != null:
		rebound_watch = 0.0
		return
	if not play_live:
		return
	rebound_watch -= delta
	if rebound_watch > 0.0:
		return
	rebound_watch = 0.0
	_pivot_dead_ball()

func _pivot_dead_ball() -> void:
	var team: int = rebound_team if rebound_team >= 0 else possession
	var piv: BallPlayer = pivot_player(team)
	# A ball lying in the pivot's area is HIS ball when he is a role 1: the
	# regulation gives him a shot at it.
	if piv != null and piv.role == 1 and play_live:
		give_ball(piv)
		shot_clock = maxf(shot_clock, 14.0)
		Events.toast.emit(Loc.t("match.area.loose"))
		return
	if piv != null and piv.role == 2 and play_live:
		# A role-2 pivot's dead ball is a jump ball at centre court (rule: the
		# ball may not simply be handed back to a role 2 lying in his area).
		Events.toast.emit(Loc.t("match.area.loose2"))
		_tipoff()
		_jump_watch = 7.0    # the watchdog starts the toss on the next frame
		return
	# Otherwise the ball is dead and the opponents restart outside the area.
	_inbound(1 - team, rebound_hoop if rebound_hoop.length() > 1.0 else side_hoops[team])

signal inbound_transition(duration: float)
const INBOUND_FADE_IN := 0.12
const INBOUND_FADE_OUT := 0.18
var _inbound_epoch := 0
var _inbound_preparing := false
var _inbound_requested := false
var _inbound_caller: BallPlayer = null

func _inbound(team: int, from_hoop: Vector2 = Vector2.ZERO) -> void:
	if finished: return
	_inbound_epoch += 1
	var epoch := _inbound_epoch
	possession = team
	restarting = true
	play_live = false
	inbound_wait = 0.0
	_inbound_preparing = true
	_inbound_requested = false
	_inbound_caller = null
	_inbounder = null
	_inbound_receiver = null
	# Fade first, then arrange the restart under cover. No extra delay on CALL.
	for pl in players:
		pl.has_ball = false
		pl.velocity = Vector2.ZERO
	if ball != null:
		ball.detach()
		ball.live = false
		ball.kill_analytic()
		ball.shot_result_pending = false
		ball.dunk_drop = 0.0
	inbound_transition.emit(INBOUND_FADE_IN + INBOUND_FADE_OUT)
	await get_tree().create_timer(INBOUND_FADE_IN).timeout
	if epoch != _inbound_epoch or finished or not restarting: return
	var mates: Array = players.filter(func(p): return p.team == team and not p.leaving)
	if mates.is_empty():
		_inbound_preparing = false
		restarting = false
		return
	# The inbounder is never a pivot: he must stay in his own area, and the
	# ball may not be thrown to a pivot from a restart anyway.
	var inbounder: BallPlayer = null
	var receiver: BallPlayer = null
	for k in range(mates.size() - 1, -1, -1):
		if (mates[k] as BallPlayer).role > 2:
			inbounder = mates[k]
			break
	if inbounder == null:
		inbounder = mates[mates.size() - 1]
	for m in mates:
		if m != inbounder and (m as BallPlayer).role > 2:
			receiver = m
			break
	if receiver == null:
		receiver = mates[0]
	if from_hoop.length() > 1.0 and is_side_hoop(from_hoop):
		# BASKIN: the restart after a side basket / a pivot's action is thrown
		# in from the sideline, 2 m BEYOND the small side area (rule fig. 2),
		# never from mid-court inside the pivot's own area.
		var sy: float = signf(from_hoop.y)
		var sx: float = 1.0
		if ball != null and absf(ball.global_position.x) > 30.0:
			sx = signf(ball.global_position.x)
		var in_x: float = sx * (SIDE_AREA_R + SIDE_INBOUND_MARKS)
		inbounder.global_position = Vector2(in_x, sy * (COURT_H * 0.5 + 44.0))
		inbounder.velocity = Vector2.ZERO
		if receiver != inbounder:
			receiver.global_position = Vector2(in_x - sx * 120.0, sy * (COURT_H * 0.5 - 92.0))
			receiver.velocity = Vector2.ZERO
	else:
		var scored_hoop: Vector2 = hoop_for(1 - team)
		# the inbounder stands OUTSIDE the court, behind the baseline
		var baseline_x: float = signf(scored_hoop.x) * (COURT_W * 0.5 + 46.0)
		inbounder.global_position = Vector2(baseline_x, 0.0)
		inbounder.velocity = Vector2.ZERO
		if receiver != inbounder:
			receiver.global_position = Vector2(baseline_x - signf(baseline_x) * 220.0, 0.0)
			receiver.velocity = Vector2.ZERO
	if ball != null:
		ball.live = false
		ball.shot_result_pending = false
	give_ball(inbounder)
	# The ball RESTS in the thrower's hands (no dribble bob, no bounce, no
	# leftover dunk drop) until the pass actually leaves — baseline throw-ins
	# included, which is where the ball used to keep bouncing.
	if ball != null:
		ball.held_still = true
		ball.dunk_drop = 0.0
		ball.vel = Vector2.ZERO
		ball.vh = 0.0
		ball.live = false
		ball.visible = true
	Events.toast.emit("Inbound")
	_inbounder = inbounder
	_inbound_receiver = receiver
	_place_inbound_defense()
	await get_tree().create_timer(INBOUND_FADE_OUT).timeout
	if epoch != _inbound_epoch or finished or not restarting: return
	_inbound_preparing = false
	var human_wait: bool = team == 0 and is_instance_valid(user) and user.is_user 		and user_on_court and user != inbounder and not one_on_one
	inbound_wait = 3.0 if human_wait else 0.55
	if _inbound_requested:
		_finish_inbound(_inbound_caller if is_instance_valid(_inbound_caller) else null)
	elif human_wait:
		Events.toast.emit(Loc.tx("Call it! (pass button)"))

## Stay close to the receiver and goal-side, with a LIMITED shade toward the
## ball. Lerp(whole court, .18) used to pull the defender far off his shooter.
func inbound_defense_target(d: BallPlayer) -> Vector2:
	var mk: BallPlayer = man_mark_for(d)
	var basket: Vector2 = hoop_for(1 - d.team)
	var aim: Vector2 = basket.lerp(ball.global_position, 0.30)
	if mk != null:
		basket = attack_hoop_for(mk)
		aim = mk.global_position + (basket - mk.global_position).normalized() * 52.0
		aim += (ball.global_position - mk.global_position).normalized() * 12.0
	# No defender enters a pivot's protected side area to reach his mark.
	for hh in side_hoops:
		var away: Vector2 = aim - hh
		if away.length() < SIDE_AREA_R + 24.0:
			if away.length() < 1.0: away = Vector2(0.0, -signf(hh.y))
			aim = hh + away.normalized() * (SIDE_AREA_R + 24.0)
	aim.x = clampf(aim.x, -COURT_W * 0.5 + 32.0, COURT_W * 0.5 - 32.0)
	aim.y = clampf(aim.y, -COURT_H * 0.5 + 20.0, COURT_H * 0.5 - 20.0)
	return aim

func _place_inbound_defense() -> void:
	_assign_man(1 - possession, Time.get_ticks_msec())
	for d in players:
		if d.team == possession or d.role <= 2 or d.is_user or d.entering or d.leaving:
			continue
		d.global_position = inbound_defense_target(d)
		d.velocity = Vector2.ZERO
		d.move_input = Vector2.ZERO
		d.stance = true
		clamp_to_court(d)

## Ends the inbound wait: pass to `caller` if he called for it, otherwise to
## the default receiver (a team-mate, never the inbounder himself).
func _finish_inbound(caller: BallPlayer) -> void:
	if finished or not restarting or ft_active:
		return
	if _inbound_preparing:
		_inbound_requested = true
		_inbound_caller = caller if is_instance_valid(caller) else null
		return
	var target: BallPlayer = caller if is_instance_valid(caller) else null
	if target == null or target == _inbounder or target.team != possession or target.role <= 2:
		target = _inbound_receiver if is_instance_valid(_inbound_receiver) else null
	if target == null or target.role <= 2 or target == _inbounder or target.leaving:
		target = null
		for candidate in players:
			if candidate.team == possession and candidate != _inbounder and candidate.role > 2 and not candidate.leaving:
				target = candidate
				break
	if not is_instance_valid(_inbounder) or target == null or not _inbounder.has_ball:
		# Recover a replaced/removed participant through a fresh, tokened restart.
		_inbound(possession)
		return
	inbound_wait = 0.0
	restarting = false
	_inbound_requested = false
	_inbound_caller = null
	ball.held_still = false
	_inbound_feed = true
	play_live = true
	shot_clock = 24.0
	# Immediate release; only the visible flight takes time, not a .35s await.
	_inbounder.do_pass(target)

# ------------------------------------------------------------------ passing / turnovers
## May this pass leave the hand at all? Kept SEPARATE from do_pass so the
## caller can refuse it BEFORE taking the ball out of the passer's hands --
## see the ghost-holder bug in Player.do_pass.
func pass_allowed(from: BallPlayer, to: BallPlayer, notify := true) -> bool:
	if from == null or to == null or from == to:
		return false
	# Baskin: the pivot's ball must be CARRIED into the area and handed over.
	# From the outside the pass is not offered at all — no whistle, no pass.
	if not one_on_one and to.role <= 2 and play_live \
	and not restarting and inbound_wait <= 0.0 and not ft_active \
	and not in_side_area(from.global_position):
		if notify and from.is_user:
			Events.toast.emit(Loc.t("match.deliver.need_area"))
		return false
	# Just fed by the pivot? Then the ball goes to another team-mate first.
	if not one_on_one and to.role <= 2 and from.no_pivot_return:
		if notify and from.is_user:
			Events.toast.emit(Loc.t("match.deliver.two_man"))
		return false
	# The pivot may not hand it straight back to the tutor who just fed him.
	if not one_on_one and from.role <= 2 and from.tutor != null and to == from.tutor:
		if notify and from.is_user:
			Events.toast.emit(Loc.t("match.deliver.two_man"))
		return false
	return true

func do_pass(from: BallPlayer, to: BallPlayer) -> void:
	if not pass_allowed(from, to):
		return
	var feed := _inbound_feed
	_inbound_feed = false
	last_passer = from
	last_pass_time = Time.get_ticks_msec() / 1000.0
	var speed: float = lerpf(500.0, 820.0, from.ratings["pass"] / 99.0)
	if feed: speed = maxf(speed, 1100.0)
	var gap: float = from.global_position.distance_to(to.global_position)
	# Da vicino, dentro l'area laterale, non e' un passaggio lanciato ma una
	# CONSEGNA: rapida, bassa, di mano in mano (Ball la disegna piu' bassa).
	if to.role <= 2 and gap < 190.0:
		speed = 430.0
		if from.is_user:
			Events.toast.emit(Loc.t("t.handoff"))
	# Straight chest pass, pointed at the receiver's HANDS. The ball keeps
	# re-aiming there every frame while it flies (Ball._physics_process), so a
	# man on the run is met where he actually is, and the pass is taken in the
	# hands instead of chased -- fluid, direct, magnetic.
	ball.pass_to(from.ball_anchor(), to.ball_anchor(), speed, from, to)
	ball.pass_target = to
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
			if from.is_user: box["tov"] += 1
			_possession_restart(d.team, "Intercepted!")
			return
	await get_tree().create_timer(maxf(from.global_position.distance_to(to.global_position) / speed, 0.12) + 0.30).timeout
	if finished or ball.holder != null: return
	# The receiver can leave the court while this coroutine is suspended.
	# Also reject a stale timer belonging to an earlier pass.
	if not is_instance_valid(to) or ball.pass_target != to or ball.pass_from != from:
		return
	_catch_pass(from if is_instance_valid(from) else null, to)

## The ball arrives in the receiver's hands. The catch is booked HERE (both by
## the magnet net that watches the hands and by the timed fallback), so every
## rule that rides on a pass is applied once, in one place: the receiver may
## not hand it straight back to the pivot's tutor, the ball must first go to
## somebody else.
func _catch_pass(from: BallPlayer, to: BallPlayer) -> void:
	if to == null or not is_instance_valid(to) or to.has_ball:
		return
	if ball == null or ball.holder != null or finished:
		return
	give_ball(to)
	if from != null:
		to.no_pivot_return = from.role <= 2
		if to.role <= 2:
			# The mate who handed it in is the pivot's tutor: the pivot may not
			# give it straight back, the ball must go to somebody else first.
			from.no_pivot_return = true
		from.own_miss_rebound = false

func on_turnover(from: BallPlayer, to: BallPlayer) -> void:
	if from.is_user: box["tov"] += 1
	give_ball(to)
	# A steal is a change of possession: whistle, then throw it in. Every
	# restart in the game looks the same (baskin rule 4).
	_possession_restart(to.team, "Turnover")

## ANY change of possession is a dead ball: the new attacking team throws the
## ball in from the sideline/baseline. Used by steals, interceptions and
## defensive rebounds, so play always restarts the same way.
func _possession_restart(team: int, reason := "Turnover") -> void:
	if one_on_one or finished or ft_active or restarting or inbound_wait > 0.0:
		return
	Events.toast.emit(reason)
	_inbound(team, _side_near_ball())

## Loose ball picked up by the OTHER team: hand it over with a throw-in.
func _after_loose_grab(p: BallPlayer, prev_team: int) -> void:
	if p == null or one_on_one or finished or not play_live or ft_active or restarting:
		return
	if prev_team == p.team:
		return
	_possession_restart(p.team, "Turnover")

## Infrazione di passi dopo una finta (palla raccolta): annuncio e cambio
## possesso, stesso percorso del shot clock violation.
func travel_violation(p: BallPlayer) -> void:
	Events.toast.emit("Traveling!")
	_turnover_to(1 - p.team)

## DOPPIO PALLEGGIO: la palla era RACCOLTA (finta) e viene rimessa a terra per
## palleggiare di nuovo. Non e' un fallo: e' un'infrazione, palla agli
## avversari, esattamente come i passi.
func double_dribble_violation(p: BallPlayer) -> void:
	Sfx.play("whistle_short")
	Events.toast.emit(Loc.t("rule.v_dbl"))
	Events.rule.emit("v_dbl")
	_turnover_to(1 - p.team)

## Ripartenza palla ferma: nel 5v5 rimessa dalla linea, nell'1v1 SEMPRE
## check-ball (strada: nessuna rimessa, solo check dopo canestro/out).
func _restart_play(team: int) -> void:
	if one_on_one:
		_check_ball(team)
	else:
		_inbound(team, _side_near_ball())

## Dead ball by a side basket (a role 1/2 shot, a stuck ball in the area):
## the restart comes from that sideline, never from inside the area.
func _side_near_ball() -> Vector2:
	if ball == null:
		return Vector2.ZERO
	for h in side_hoops:
		if ball.global_position.distance_to(h) < 300.0:
			return h
	return Vector2.ZERO

## FALLO IN ATTACCO (carica). Regola: chi attacca non puo' andare addosso a un
## difensore che ha gia' preso posizione. Serve un contatto FRONTALE, con
## l'attaccante lanciato e il difensore fermo in posizione di difesa: cosi' non
## fischia mai su un semplice avvicinamento. Fuori dall'arco sotto il canestro
## (non-sfondamento) e fuori dalle aree laterali del pivot.
## Calibrazione 1.19: prima servivano 34px di distanza (meno del contatto
## fisico dei corpi) e uno scatto a 195: per questo uscivano 0-2 a partita.
## Ora il contatto e' a braccio disteso (52px), lo scatto a 170 e la
## traiettoria leggermente piu' tollerante (0.45): restano falli rari,
## ma nella partita IA si vedono.
var _charge_cd := 0.0
var charges := [0, 0]              # falli in attacco fischiati, per squadra

func _charge_check(delta: float) -> void:
	_charge_cd = maxf(0.0, _charge_cd - delta)
	if _charge_cd > 0.0 or ft_active or inbound_wait > 0.0:
		return
	var h: BallPlayer = ball_handler()
	if h == null or not h.has_ball or h.jumping or h.dunking or h.hanging:
		return
	# Chi sta tirando, palleggiando in un move o appena arrivato non carica.
	if h.shot_charge >= 0.0 or h.ai_windup_t >= 0.0 or h.move_t > 0.0 or h.stun > 0.0:
		return
	var spd: float = h.velocity.length()
	if spd < 170.0:
		return
	if in_side_area(h.global_position):
		return                              # aree del pivot: contatto normale
	var run: Vector2 = h.velocity / spd
	var rim: Vector2 = attack_hoop_for(h)
	for d in get_tree().get_nodes_in_group("team_%d" % (1 - h.team)):
		var dv: BallPlayer = d
		var to: Vector2 = dv.global_position - h.global_position
		var dist: float = to.length()
		if dist > 52.0 or dist < 1.0:
			continue                      # contatto a braccio disteso
		if to.normalized().dot(run) < 0.45:
			continue                      # non e' sulla traiettoria
		if dv.velocity.length() > 95.0:
			continue                      # si sta muovendo: non ha posizione
		if not dv.stance:
			continue                      # non sta difendendo: niente carica
		if not one_on_one and dv.global_position.distance_to(rim) < FIBA_RESTRICTED:
			continue                      # arco di non-sfondamento
		_charge_cd = 2.0
		call_charge(h, dv)
		return

## Fallo in attacco: conta come fallo personale e di squadra, ma la punizione e'
## il possesso agli avversari (niente tiri liberi: si punisce l'attacco).
func call_charge(offender: BallPlayer, defender: BallPlayer) -> void:
	team_fouls[offender.team] += 1
	charges[offender.team] += 1
	Sfx.play("whistle_short")
	Events.rule.emit("foul")
	Events.toast.emit(Loc.t("t.foul.charge"))
	Events.popup.emit("FALLO IN ATTACCO", offender.global_position, Color(1.0, 0.55, 0.25), false)
	if offender.is_user:
		stat_add("pf", 1)
		stat_add("tov", 1)
		Events.shake.emit(0.35)
	possession = defender.team
	_turnover_to(defender.team)

func _turnover_to(team: int) -> void:
	possession = team
	_reset_possession(false)

func _user_break_heat() -> void:
	if user_heat:
		Events.popup.emit("COLD", user.global_position, Color(0.7, 0.75, 0.85), false)
	user_streak = 0
	user_heat = false

func call_foul(defender: BallPlayer, victim: BallPlayer, pts_attempt := 0) -> void:
	team_fouls[defender.team] += 1
	Sfx.play("whistle_short")
	Events.toast.emit(Loc.t("match.foul.toast") % defender.jersey_num)
	Events.rule.emit("foul")
	possession = victim.team
	if defender.is_user:
		stat_add("pf", 1)
	# REGOLAMENTO: prima del 5o fallo di squadra un fallo NON sul tiro si
	# riprende con una rimessa, non con i tiri liberi. Dal 5o in poi (bonus)
	# ogni fallo vale 2 tiri; un fallo sul tiro vale sempre 2 o 3 tiri.
	var bonus: bool = team_fouls[defender.team] >= 5
	if pts_attempt <= 0 and not bonus:
		Events.toast.emit(Loc.t("t.foul.inbound"))
		_possession_restart(victim.team, "Foul")
		return
	if pts_attempt <= 0:
		Events.toast.emit(Loc.t("t.foul.bonus"))
	var shots := 3 if pts_attempt >= 3 else 2
	_start_free_throws(victim, shots)

# ------------------------------------------------------------------ free throws
## The clock STOPS (play_live goes false), the fouled player walks to the
## middle of the free-throw line and takes his shots. Everything else on the
## floor freezes until the last one lands.
func _start_free_throws(victim: BallPlayer, shots: int) -> void:
	_inbound_epoch += 1
	_inbound_preparing = false
	_inbound_requested = false
	inbound_wait = 0.0
	play_live = false
	restarting = true
	ft_active = true
	ft_shooter = victim
	ft_total = shots
	ft_left = shots
	ft_timer = 1.0
	# Regola 8: when the fouled man is a role 3 the free throws are taken at
	# the HIGH side basket from the dashed line (the 2R's spot). A pivot who
	# is fouled shoots at his own side basket, from his usual spot.
	ft_side = not one_on_one and victim.role <= 3
	var hoop: Vector2 = hoop_for(victim.team)
	var dir := -1.0 if hoop.x > 0.0 else 1.0
	if ft_side:
		hoop = side_hoops[victim.team]
		if victim.role == 3:
			var inward: float = 1.0 if hoop.y < 0.0 else -1.0
			victim.global_position = hoop + Vector2(0.0, inward * (SIDE_AREA_R + 44.0))
		else:
			victim.global_position = pivot_shot_spot(victim.team, victim)
		victim.facing = 1.0 if hoop.x >= 0.0 else -1.0
	else:
		victim.global_position = hoop + Vector2(dir * FT_PX, 0.0)
	victim.velocity = Vector2.ZERO
	victim.move_input = Vector2.ZERO
	# FILA DEL TIRO LIBERO (regolamento): due per squadra negli spazi della
	# corsia, gli altri fuori dall'arco. Serve perche' sull'ULTIMO libero
	# sbagliato la palla resta VIVA e il rimbalzo si gioca davvero.
	_line_up_for_free_throws(victim, hoop, dir, ft_side)
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
	var hoop: Vector2 = side_hoops[ft_shooter.team] if ft_side else hoop_for(ft_shooter.team)
	Sfx.play("shot_release", -8.0)
	ball.shoot(ft_shooter.global_position + Vector2(0, -50), hoop, 400.0, 0.75, made, ft_shooter,
		rim_height_of(hoop, ft_shooter.role))
	# Flag AFTER shoot(): shoot() resets the flag to false for every launch.
	ball.is_free_throw = true
	ball.shot_hoop = hoop
	ball.shot_is_side = ft_side
	ft_shooter.has_ball = false
	if ft_shooter.is_user:
		stat_add("fta", 1)

## NPC free-throw routine: aim, breathe, release on a rhythm. The user's
## release is driven by the shot meter in MatchScene, so this does nothing
## while the fouled player is human.
func _process(delta: float) -> void:
	_process_bench_and_timeouts(delta)
	# Palla in fiamme mentre l'utente in fuoco la tiene o l'ha appena tirata.
	if ball != null and user != null:
		ball.flame = user_heat and (ball.holder == user \
			or (ball.live and ball.shooter == user))
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

## Schieramento del tiro libero: due per squadra in corsia (i piu' vicini al
## canestro), gli altri dietro la linea da tre. Sul canestro laterale non c'e'
## corsia: due per squadra appena fuori dall'area piccola, gli altri a
## meta' campo.
func _line_up_for_free_throws(victim: BallPlayer, hoop: Vector2, dir: float,
		ft_side: bool) -> void:
	# REGOLAMENTO: quattro posti in corsia, due per squadra, uno per lato. Chi
	# DIFENDE sta nel posto piu' vicino alla linea di fondo, chi attacca subito
	# dopo (e' l'ordine vero). Gli altri restano fuori dall'arco. Serve perche'
	# sull'ULTIMO libero sbagliato la palla resta viva e il rimbalzo si gioca.
	var order := players.duplicate()
	order.sort_custom(func(a, b):
		return a.global_position.distance_to(hoop) < b.global_position.distance_to(hoop))
	var off_slot := 0
	var def_slot := 0
	var far := 0
	for p in order:
		if p == victim:
			continue
		p.velocity = Vector2.ZERO
		p.move_input = Vector2.ZERO
		var attacking: bool = p.team == victim.team
		var slot_i: int = off_slot if attacking else def_slot
		if slot_i < 2 and p.role > 2:
			var lane_side: float = -1.0 if slot_i == 0 else 1.0
			if ft_side:
				# Sul canestro laterale non c'e' corsia: due per squadra appena
				# fuori dall'area piccola.
				var inward: float = 1.0 if hoop.y < 0.0 else -1.0
				p.global_position = hoop + Vector2(
					lane_side * (SIDE_AREA_R + (72.0 if attacking else 36.0)),
					inward * (SIDE_AREA_R - 30.0))
			else:
				p.global_position = hoop + Vector2(
					dir * (FT_PX - (188.0 if not attacking else 104.0)),
					lane_side * (FIBA_PAINT_W * 0.5 - 34.0))
			if attacking:
				off_slot += 1
			else:
				def_slot += 1
		else:
			var side: float = 1.0 if p.team == 0 else -1.0
			if ft_side:
				p.global_position = Vector2(side * (300.0 + 120.0 * float(far % 3)),
					-side * 220.0)
			else:
				p.global_position = hoop + Vector2(
					dir * (FT_PX + 250.0 + 110.0 * float(far % 3)),
					side * (150.0 + 80.0 * float(far / 3)))
			far += 1

## L'ultimo tiro libero sbagliato non chiude il gioco: la palla e' viva.
## Si esce dalla sequenza e si lascia il rimbalzo al gioco (stesse regole del
## rimbalzo normale: chi arriva prima la prende, peso sulla vicinanza).
func _missed_last_free_throw(b: Ball) -> void:
	ft_left = maxi(0, ft_left - 1)
	ft_active = false
	ft_shooter = null
	restarting = false
	_ft_keep_possession = false
	play_live = true
	Events.toast.emit(Loc.t("t.ftlive"))
	var hoop: Vector2 = b.shot_hoop if b.shot_hoop.length() > 1.0 else nearest_hoop(b.global_position)
	_rim_quake(hoop_index_of(hoop), 0.5)
	var best: BallPlayer = null
	var best_w := -1.0
	for p in players:
		var d: float = p.global_position.distance_to(b.global_position)
		if d > 260.0:
			continue
		var near: float = pow(1.0 - d / 260.0, 1.6)
		var w: float = (p.ratings["rebound"] / 99.0) * p.height_f * near * randf_range(0.6, 1.4)
		if d < 55.0:
			w *= 1.35
		if p.has_badge("glass_cleaner"):
			w *= 1.1
		if w > best_w:
			best_w = w
			best = p
	if best == null:
		_restart_play(1 - b.last_touch_team)
		return
	give_ball(best)
	shot_clock = 24.0
	if best.is_user:
		box["reb"] += 1
		Events.popup.emit(Loc.t("pop.rebound"), best.global_position,
			Color(0.60, 0.88, 1.0), false)
		Sfx.add_hype(0.05)
	Events.toast.emit(Loc.t("t.rebound") % best.jersey_num)

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
	if _ft_keep_possession:
		_ft_keep_possession = false
		_restart_play(shooter.team)
	else:
		# The other team takes over after the last free throw.
		_restart_play(1 - shooter.team)

# ------------------------------------------------------------------ helpers
func hoop_for(team: int) -> Vector2:
	## The basket this team attacks.
	return hoops[1] if team == 0 else hoops[0]

# ------------------------------------------------------------------ baskin
## Baskin: 4 hoops, 5 roles. Roles 1-2 attack their team's SIDE basket,
## roles 4-5 the classic baskets, role 3 either. Scoring and shot rules
## follow the official baskin ruleset, simplified for teaching.
func is_side_hoop(h: Vector2) -> bool:
	return absf(h.y) > COURT_H * 0.25

func rim_height_of(h: Vector2, role := 0) -> float:
	# DOPPIO CANESTRO LATERALE (regolamento): il ruolo 1 tira in quello BASSO
	# (1,20 m), il ruolo 2 in quello ALTO (2,20 m). Gli altri: 3,05 m.
	if is_side_hoop(h):
		return SIDE_RIM_LOW if role == 1 else SIDE_RIM_HIGH
	return RIM_HEIGHT

func hoop_index_of(h: Vector2) -> int:
	if is_side_hoop(h):
		return 2 if h.y < 0.0 else 3
	return 0 if h.x < 0.0 else 1

func nearest_hoop(pos: Vector2) -> Vector2:
	var best: Vector2 = hoops[0]
	var bd := 1e18
	for h in [hoops[0], hoops[1], side_hoops[0], side_hoops[1]]:
		var d: float = pos.distance_to(h)
		if d < bd:
			bd = d
			best = h
	return best

func attack_hoop_for(p: BallPlayer) -> Vector2:
	if one_on_one:
		return hoop_for(p.team)
	match p.role:
		1, 2:
			# Both pivots live and shoot at their own side basket.
			return side_hoops[p.team]
		_:
			# Roles 3-5 attack the opponents' classic basket. Role 3 used to
			# take the hoop NEAREST to him: standing in his own half that was
			# his own rim, so he ran the wrong way and the whole team ended up
			# camped on a baseline.
			return hoop_for(p.team)

func in_side_area(pos: Vector2) -> bool:
	for h in side_hoops:
		if pos.distance_to(h) < SIDE_AREA_R:
			return true
	return false

## Roles 2-3 must shoot at the side baskets from OUTSIDE the painted area
## (continuous line, 3 m). Rev.19: a 2R shoots from behind the DASHED arc,
## 0,7 m FARTHER OUT (3,70 m) — not closer. Role 1 shoots from inside his area.
func shot_must_clear_area(s: BallPlayer, hoop: Vector2) -> bool:
	if not is_side_hoop(hoop):
		return false
	if s.role != 2 and s.role != 3:
		return false   # role 1 shoots from INSIDE his area (official baskin)
	var r := SIDE_DASH_R if s.variant == "2R" else SIDE_AREA_R
	return s.global_position.distance_to(hoop) < r

## True when the shooter already stands beyond the line his role must shoot
## from (continuous 3 m, dashed 3,70 m for a 2R). The AI pivot uses it to
## keep stepping out instead of planting inside the line.
func pivot_beyond_line(s: BallPlayer, hoop: Vector2) -> bool:
	var r := SIDE_DASH_R if s.variant == "2R" else SIDE_AREA_R
	return s.global_position.distance_to(hoop) >= r

## Which sector of a side area a floor position falls in, radially from the
## hoop: TRUE = the central 70 cm wedge straight in front of the basket (the
## role-2 two-point sector). Angles outside the semicircle count as lateral.
func in_central_sector(pos: Vector2, hoop: Vector2) -> bool:
	var off: Vector2 = pos - hoop
	if off.length() < 1.0:
		return true
	var inward := Vector2(0.0, -signf(hoop.y))   # perpendicular, into the court
	return absf(inward.angle_to(off)) <= SIDE_SEC_C_HALF

func tutor_of(team: int) -> BallPlayer:
	for p in players:
		if p.team == team and p.role == 3:
			return p
	return null

## The team's pivot on the floor (role 1 or role 2), if any.
func pivot_player(team: int, role_only: int = 0) -> BallPlayer:
	for p in players:
		if p.team == team and p.role <= 2 and (role_only == 0 or p.role == role_only):
			return p
	return null

## Where the pivot takes his shot from: role 1 shoots INSIDE his area; role 2
## steps out past his line INTO ONE OF THE SECTORS (Rev.19: "si sposta in uno
## dei tre settori"): the central wedge is worth 2, a lateral wedge 3. Which
## one he fancies is rolled when the ball reaches him (see give_ball).
var pivot_sector := [0, 0]   # per team: -1 left lateral, 0 central, +1 right
func pivot_shot_spot(team: int, p: BallPlayer) -> Vector2:
	if p == null or p.role <= 1:
		return pivot_home(team)
	var h: Vector2 = side_hoops[team]
	var inward := Vector2(0.0, -signf(h.y))
	var dist: float = (SIDE_DASH_R + 26.0) if p.variant == "2R" else (SIDE_AREA_R + 26.0)
	var dir: Vector2 = inward.rotated(SIDE_SEC_LAT_MID * float(pivot_sector[team]))
	return h + dir * dist

func pivot_spot(team: int) -> Vector2:
	var h: Vector2 = side_hoops[team]
	return h + Vector2(0.0, (-1.0 if h.y > 0.0 else 1.0) * (SIDE_AREA_R + 60.0))

## Where the pivot should stand to TAKE a hand-off: next to his team-mate, on
## the side away from the nearest defender, and always INSIDE the side area
## (a delivery from outside the area is not legal ball to a pivot).
func handoff_spot(piv: BallPlayer, holder: BallPlayer) -> Vector2:
	var h: Vector2 = side_hoops[piv.team]
	var inward: Vector2 = (h - pivot_home(piv.team)).normalized()
	var side: Vector2 = Vector2(-inward.y, inward.x)
	# Which side of the holder is free? The one with the defender farther away.
	var best := side
	var best_d := -1.0
	for sgn in [1.0, -1.0]:
		var cand: Vector2 = holder.global_position + side * sgn * 42.0
		var near := 9999.0
		for d in players:
			if d.team != piv.team:
				near = minf(near, d.global_position.distance_to(cand))
		if near > best_d:
			best_d = near
			best = side * sgn
	var spot: Vector2 = holder.global_position + best * 42.0
	# never outside his own area (the delivery would be illegal there)
	var out: Vector2 = spot - h
	if out.length() > SIDE_AREA_R - 26.0:
		spot = h + out.normalized() * (SIDE_AREA_R - 26.0)
	return spot

## Where the pivot lives: right at the back of his own side area, so the
## basket stands between him and the court (he is "behind the basket", the
## rim in front of him) — how a baskin pivot actually positions.
func pivot_home(team: int) -> Vector2:
	var h: Vector2 = side_hoops[team]
	return h + Vector2(0.0, (1.0 if h.y < 0.0 else -1.0) * 26.0)

## What a made basket is worth for this player at this hoop (public: the AI
## play caller prices its options with it).
func baskin_points_for(s: BallPlayer, hoop: Vector2) -> int:
	return _baskin_points(s, hoop)

## Point value of a made basket under baskin rules.
func _baskin_points(s: BallPlayer, hoop: Vector2) -> int:
	var side := is_side_hoop(hoop)
	match s.role:
		1:
			return 3 if s.pivot_attempts <= 1 else 2
		2:
			# Rev.19: dal canestro laterale alto il valore dipende dal SETTORE
			# di tiro: centrale (70 cm) = 2 punti, laterale = 3 punti.
			# Al canestro tradizionale (caso limite) vale 3.
			if side:
				return 2 if in_central_sector(s.global_position, hoop) else 3
			return 3
		3:
			if side:
				return 2
			return 2 if s.received_in_side_area else 3
		_:
			return 3 if px_to_ft(s.global_position.distance_to(hoop)) > THREE_FT else 2

## Pre-shot legality: "" = shoot, otherwise the rule key of the violation.
func _baskin_shot_check(s: BallPlayer, hoop: Vector2) -> String:
	if s.role <= 2 and s.own_miss_rebound:
		return "v_reb2"
	if s.role == 5 and s.period_shots >= 3:
		return "v_lim5"
	if s.role <= 4 and s.period_makes >= 3:
		return "v_lim3"
	if shot_must_clear_area(s, hoop):
		return "v_area"
	var spd: float = s.velocity.length()
	if s.role == 2 and s.variant == "" and s.dribble_t < 0.6:
		return "v_dribble2"
	if s.role == 3:
		if s.dribble_t < 0.7:
			return "v_dribble3"
		if spd > 130.0 and px_to_ft(s.global_position.distance_to(hoop)) < 10.0:
			return "v_layup3"
	if s.role == 4 and spd > 60.0:
		return "v_stop4"
	if s.role <= 2:
		s.pivot_attempts += 1
	return ""

## The PERMANENT limits only: role ceilings and area legality. The transient
## gates (dribbles taken, full stop reached) are things the AI can still fix by
## moving, so the play caller must not treat them as "no shot available".
func baskin_ai_shoot_allowed(p: BallPlayer, hoop: Vector2) -> bool:
	if one_on_one:
		return true
	if p.role <= 2 and p.own_miss_rebound:
		return false
	if p.role == 5 and p.period_shots >= 3:
		return false
	if p.role <= 4 and p.period_makes >= 3:
		return false
	if shot_must_clear_area(p, hoop):
		return false
	return true

## Same gates for the AI's pull-the-trigger decision.
func baskin_ai_may_shoot(p: BallPlayer, hoop: Vector2) -> bool:
	if one_on_one:
		return true
	if p.role == 5 and p.period_shots >= 3:
		return false
	if p.role <= 4 and p.period_makes >= 3:
		return false
	if shot_must_clear_area(p, hoop):
		return false
	var spd: float = p.velocity.length()
	if p.role == 2 and p.variant == "" and p.dribble_t < 0.6:
		return false
	if p.role == 3:
		if p.dribble_t < 0.7:
			return false
		if spd > 130.0 and px_to_ft(p.global_position.distance_to(hoop)) < 10.0:
			return false
	if p.role == 4 and spd > 60.0:
		return false
	return true

## 3 SECONDS and 5 SECONDS, the two time infractions baskin actually calls
## (Regola 8). The key rule only ever counts the ATTACKING side, only while the
## ball is in play and held (a shot in the air stops the count), and never for
## the pivots (roles 1-2 live in their side area, which is not the key).
func _time_infractions(delta: float) -> void:
	if one_on_one or finished or not play_live or restarting or ft_active:
		return
	var h := ball_handler()
	_key_warn_cd = maxf(0.0, _key_warn_cd - delta)
	_guard_warn_cd = maxf(0.0, _guard_warn_cd - delta)
	# --- 3 SECONDS in the key -------------------------------------------------
	var live_hold: bool = h != null
	for p in players:
		if p.role <= 2 or p.team != possession:
			continue
		var key_x: float = COURT_W * 0.5 - FIBA_KEY_LEN
		var hoop_x: float = signf(attack_hoop_for(p).x)
		var in_key: bool = live_hold and absf(p.global_position.x) > key_x \
			and signf(p.global_position.x) == hoop_x \
			and absf(p.global_position.y) < FIBA_PAINT_W * 0.5
		if not in_key:
			_key_time.erase(p.get_instance_id())
			continue
		var t: float = float(_key_time.get(p.get_instance_id(), 0.0)) + delta
		_key_time[p.get_instance_id()] = t
		if t > 2.0 and t < 3.0 and _key_warn_cd <= 0.0 and p.is_user:
			_key_warn_cd = 1.0
			Events.toast.emit(Loc.t("t.three_sec_warn"))
		if t >= 3.0:
			_key_time.clear()
			_violation(p, "v_3sec")
			return
	# --- 5 SECONDS, closely guarded ------------------------------------------
	if h != null and h.role > 2:
		var guarded := false
		for d in players:
			if d.team != h.team and d.global_position.distance_to(h.global_position) < 110.0:
				guarded = true
				break
		# The count is about a man who is not PLAYING: passing, shooting or
		# moving the ball on resets it (his own movement counts as playing).
		var stalled: bool = h.velocity.length() < 90.0 and h.move_t <= 0.0 \
			and h.fake_t <= 0.0 and h.shot_charge < 0.0
		if guarded and stalled:
			_guard_clock += delta
			if _guard_clock > 4.0 and _guard_warn_cd <= 0.0 and h.is_user:
				_guard_warn_cd = 1.0
				Events.toast.emit(Loc.t("t.five_sec_warn"))
			if _guard_clock >= 5.0:
				_guard_clock = 0.0
				_violation(h, "v_5sec")
		else:
			_guard_clock = 0.0
	else:
		_guard_clock = 0.0

func _violation(p: BallPlayer, key: String) -> void:
	Sfx.play("whistle_short")
	Events.toast.emit(Loc.t("rule." + key))
	Events.rule.emit(key)
	_turnover_to(1 - p.team)

func _baskin_clocks(delta: float) -> void:
	if one_on_one or finished:
		return
	var h := ball_handler()
	if h != null and h.role <= 2 and h.pivot_clock > 0.0 and play_live \
	and not restarting and not ft_active:
		h.pivot_clock -= delta
		if h.pivot_clock <= 0.0:
			_violation(h, "v_pivot5s")
			return
	_area_rebound_tick(delta)
	_area_trespass_check(delta)
	_ill_whistle_cd = maxf(0.0, _ill_whistle_cd - delta)
	_update_guard_target()
	_illegal_defense_check(delta)

## Rule 5: roles 3-5 may step into a small side area only to hand the ball
## to a pivot (and must leave right after). Loitering there during a live
## action is an infraction: the ball goes to the opponents.
## A role-3 team-mate to take the free throws for a trespassing defender
## (Regola 8: when the fouled player is a role 3, HE shoots the free throws).
func _role3_near(team: int) -> BallPlayer:
	var best: BallPlayer = null
	var bd := 1e9
	for p in players:
		if p.team != team or p.role != 3:
			continue
		var d: float = p.global_position.distance_to(side_hoops[team])
		if d < bd:
			bd = d
			best = p
	return best

func _area_trespass_check(delta: float) -> void:
	if one_on_one or finished or ft_active or reclass_guard():
		return
	for q in players:
		if q.role <= 2 or q.entering or q.leaving:
			continue
		var in_delivery_area := false
		for hi in side_hoops.size():
			var hh: Vector2 = side_hoops[hi]
			if q.global_position.distance_to(hh) >= SIDE_AREA_R:
				continue
			# EACH side area belongs to ONE team. Roles 3-5 may step into
			# their OWN area only to hand the ball to the pivot; the
			# opponents' area cannot be entered at all — that is enforced as a
			# wall by clamp_to_court(), so nobody is whistled for being pushed
			# out of it.
			var own: bool = int(hi) == q.team
			var handing: bool = own and q.team == possession and ball != null \
				and ball.global_position.distance_to(hh) < 460.0
			if not handing:
				q.area_loiter_t = 0.0
				continue
			in_delivery_area = true
			q.area_loiter_t += delta
			# A hand-off is a quick errand: the human is whistled soon, the AI
			# gets a longer rope (it now walks out by itself, see AIBrain).
			var lim: float = (3.4 if q.has_ball else 2.8) if not q.is_user else (2.2 if q.has_ball else 1.2)
			if q.area_loiter_t > lim:
				q.area_loiter_t = 0.0
				_violation(q, "v_area_in")
				return
		if not in_delivery_area:
			q.area_loiter_t = 0.0

func reclass_guard() -> bool:
	return restarting or not play_live

## L'UOMO CHE IL TASTO DIFENDI TI MANDA A PRENDERE. Con DIFENDI premuto il
## gioco ti posiziona: se il portatore di palla e' un uomo che PUOI marcare lo
## prendi lui, altrimenti vai sul tuo uomo (se e' legale), altrimenti resti in
## aiuto. Serve a non portarti addosso a un uomo illegale (fallo L) mentre stai
## solo difendendo: prima il tasto ti incollava al portatore di palla comunque
## fosse, e il fischio arrivava per colpa del gioco.
func _update_guard_target() -> void:
	guard_target = null
	if not play_live or restarting or ft_active or finished:
		return
	var u := user
	if u == null or not u.is_user or u.has_ball or not user_on_court:
		return
	if ball == null or ball.holder == null or ball.holder.team == u.team:
		return
	if one_on_one:
		guard_target = ball.holder
		return
	var h: BallPlayer = ball_handler()
	if h != null and h.team != u.team and not ill_guard(u, h):
		guard_target = h
		return
	var m: BallPlayer = man_mark_for(u)
	if m != null and m.team != u.team and not ill_guard(u, m):
		guard_target = m

## Illegal defense is the human's lesson: AI assignments are always legal
## (see _assign_man), so only the user's marking is whistled.
## Il fischio riguarda SOLO l'uomo che stai davvero addosso: camminare accanto
## a un ruolo piu' basso, aiutare un compagno o difendere il tuo uomo mentre un
## altro passа vicino non e' un fallo L (era la ragione per cui sembrava
## oppressivo: bastava avvicinarsi a chiunque per essere fischiati).
func _illegal_defense_check(delta: float) -> void:
	ill_mark = null
	if not play_live or restarting or ft_active or finished or one_on_one:
		_ill_dwell = 0.0
		return
	# THE "L" ONLY EXISTS ON DEFENCE. While OUR team has the ball nothing the
	# user does near an opponent is an illegal defence (crowding in the post,
	# setting a screen, running past a bigger man): the whistle was firing on
	# attackers, which is why it felt oppressive.
	if possession == user.team:
		_ill_dwell = 0.0
		return
	var u := user
	if u == null or not u.is_user or u.has_ball or not user_on_court:
		_ill_dwell = 0.0
		return
	# A loose ball is not defence (Regola 8): no whistle while it is rolling.
	if ball == null or ball.holder == null or ball.holder.team == u.team:
		_ill_dwell = 0.0
		return
	# WALKING PAST IS NOT A FOUL. The whistle only ever fires while the DEFEND
	# button is held (or while he is actually going for the ball): just running
	# by a lower role, standing near him or crossing his path is clean.
	if not (u.guarding or u.steal_t > 0.0 or u.block_window > 0.0):
		_ill_dwell = 0.0
		return
	# L'uomo che sto addosso ADESSO: il piu' vicino, entro il contatto.
	var man: BallPlayer = null
	var bd := 46.0
	for a in players:
		if a.team == u.team:
			continue
		var d: float = u.global_position.distance_to(a.global_position)
		if d < bd:
			bd = d
			man = a
	if man == null or not ill_guard(u, man):
		# Il contatto si ALLENTA, non si azzera di colpo: se il difensore e
		# l'uomo illegale si sfiorano per un istante (o la distanza oscilla
		# intorno al contatto) l'insistenza accumulata non va persa.
		_ill_dwell = maxf(0.0, _ill_dwell - delta * 1.5)
		return
	ill_mark = man            # per il segno rosso: "questo non puoi marcarlo"
	if shot_clock > 22.5 or _ill_whistle_cd > 0.0:
		_ill_dwell = 0.0
		return
	# STARE ADDOSSO UN ATTIMO E' OK. Il fischio arriva se insisti: cosi' un
	# contatto di passaggio non diventa un fallo.
	_ill_dwell += delta
	if _ill_dwell < 0.30:
		return
	_ill_dwell = 0.0
	illegal_defense(u, man)

## May this defender legally take that man? Baskin Regola 8: the LOWER role
## may guard the higher one, never the other way round. Role numbers grow with
## ability, so a role 5 may only take another 5, a role 4 a 4 or a 5, and so
## on. Two special cases: the role-2 pivot is guarded by an opposing ROLE 3
## only, the role-1 pivot is never guarded at all.
func ill_guard(d: BallPlayer, a: BallPlayer) -> bool:
	if d == null or a == null or d.team == a.team:
		return false
	if a.role <= 1:
		return true
	if a.role == 2:
		return d.role != 3
	return d.role > a.role

## The "L" foul: 2 free throws for the man who was marked illegally, then his
## team keeps the ball. Counted on the defender (5 fouls = out) and, when the
## victim is a role 3, shot at the HIGH side basket from the dashed line.
func illegal_defense(d: BallPlayer, a: BallPlayer) -> void:
	team_fouls[d.team] += 1
	d.fouls += 1
	_ill_whistle_cd = 9.0
	Sfx.play("whistle_short")
	Events.toast.emit(Loc.t("toast.foul_l") % d.jersey_num)
	Events.rule.emit("v_illegal")
	if d.is_user:
		stat_add("pf", 1)
	_ft_keep_possession = true
	_start_free_throws(a, 2)

func _apply_role_kit(p: BallPlayer) -> void:
	p.jersey_num = p.role   # the shirt number IS the baskin role
	p.wheelchair = (p.role == 1)
	p.variant = ""
	if p.role == 2 and p.team == 0:
		p.variant = "2T"
	elif p.role == 2 and p.team == 1:
		p.variant = "2R"
	elif p.role == 1 and p.team == 1:
		p.variant = "1S"
	if p.is_user:
		return
	if p.role == 1:
		for k in ["speed", "accel", "defense", "steal"]:
			p.ratings[k] = clampi(int(p.ratings[k]) - 15, 25, 99)
	elif p.role == 5:
		for k in ["close", "mid", "three"]:
			p.ratings[k] = clampi(int(p.ratings[k]) + 5, 30, 99)

## The user picks his role before tip-off; the team-mate who had it swaps.
## Only ONE pivot per team: asking for role 1-2 stands the AI pivot down.
func assign_user_role(r: int) -> void:
	if user == null or user.role == r:
		return
	var old: int = user.role
	if r <= 2:
		for p in players:
			if p.team == 0 and p != user and p.role <= 2:
				p.role = 5
				p.wheelchair = false
				_apply_role_kit(p)
		user.role = r
		_apply_role_kit(user)
		user.global_position = pivot_home(0)
		user.queue_redraw()
		return
	var other: BallPlayer = null
	for p in players:
		if p.team == 0 and p != user and p.role == r:
			other = p
			break
	user.role = r
	_apply_role_kit(user)
	if other != null:
		other.role = old
		_apply_role_kit(other)
	user.queue_redraw()

func _build_pivot_bench() -> void:
	if one_on_one:
		return
	for t in 2:
		for k in 2:
			var p := preload("res://src/match/Player.gd").new()
			p.team = t
			p.role = team_pivot_role(t)
			add_child(p)
			_randomize_npc(p, t)
			_apply_role_kit(p)
			p.visible = false
			p.set_physics_process(false)
			p.global_position = Vector2(-300.0 + 600.0 * k,
				(1.0 if t == 0 else -1.0) * (COURT_H * 0.5 + 90.0))
			pivot_bench[t].append(p)

func _strip_brain(p: BallPlayer) -> void:
	for c in p.get_children():
		if c is AIBrain:
			p.remove_child(c)
			c.queue_free()

func _add_brain(p: BallPlayer) -> void:
	var b := preload("res://src/match/AIBrain.gd").new()
	p.add_child(b)
	b.setup(p, self)

## 3 makes in one period: the pivot MUST leave; another role 1 rotates in.
## If the user was the pivot, he keeps playing as the incoming pivot.
func _substitute_pivot(out: BallPlayer) -> void:
	var team: int = out.team
	if pivot_bench[team].is_empty():
		out.period_makes = 0
		return
	_strip_brain(out)
	var inn: BallPlayer = pivot_bench[team].pop_back()
	pivot_bench[team].push_front(out)
	players.erase(out)
	out.visible = false
	out.set_physics_process(false)
	out.has_ball = false
	out.global_position = Vector2(0.0,
		(1.0 if team == 0 else -1.0) * (COURT_H * 0.5 + 90.0))
	if out.is_user:
		out.is_user = false
		inn.is_user = true
		inn.hair_style_v = Game.hair_style()
		inn.setup_from_profile()
		user = inn
	else:
		_add_brain(inn)
	players.append(inn)
	inn.jersey_num = inn.role   # the shirt number IS the baskin role
	inn.visible = true
	inn.set_physics_process(true)
	inn.global_position = pivot_home(team)
	inn.velocity = Vector2.ZERO
	inn.own_miss_rebound = false
	inn.no_pivot_return = false
	inn.period_makes = 0
	inn.period_shots = 0
	inn.pivot_attempts = 0
	inn.pivot_clock = 0.0
	inn.queue_redraw()
	Events.toast.emit(Loc.t("rule.r1_sub"))
	Events.rule.emit("r1_sub")

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
		if p.team != from.team or p == from or p.entering or p.leaving: continue
		if not pass_allowed(from, p, false): continue
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
	# BASKIN: you may only guard an equal-or-higher role, and NEVER the
	# pivot (role 1). Defenders who cannot legally mark anyone play help.
	if not one_on_one:
		free_opp = free_opp.filter(func(o): return o.role > 2)
	# EACH DEFENDER TAKES HIS OWN ROLE (5 on 5, 4 on 4, 3 on 3): the pairing
	# starts by matching equal role numbers, and only the leftovers fall back
	# to the general rule (the lower role may take a higher one).
	if not one_on_one:
		for dd in defenders.duplicate():
			var dref0: BallPlayer = dd
			var best_o0: BallPlayer = null
			var bd0 := 1e18
			for oo in free_opp:
				var oref0: BallPlayer = oo
				if oref0.role != dref0.role:
					continue
				var dist0: float = dref0.global_position.distance_to(oref0.global_position)
				if dist0 < bd0:
					bd0 = dist0
					best_o0 = oref0
			if best_o0 != null:
				_man_marks[dref0.get_instance_id()] = best_o0.get_instance_id()
				free_def.erase(dref0)
				free_opp.erase(best_o0)
	while not free_def.is_empty() and not free_opp.is_empty():
		var best_d: BallPlayer = null
		var best_o: BallPlayer = null
		var bd := 1e18
		for dd in free_def:
			var dref: BallPlayer = dd
			for oo in free_opp:
				var oref: BallPlayer = oo
				# BASKIN (Regola 8): the LOWER role takes the higher one, never
				# the other way round — the assignments the AI plays by must be
				# the same ones the referee whistles the human for.
				if not one_on_one and dref.role > oref.role:
					continue
				var dist: float = dref.global_position.distance_to(oref.global_position)
				if dist < bd:
					bd = dist
					best_d = dref
					best_o = oref
		if best_d == null:
			break
		_man_marks[best_d.get_instance_id()] = best_o.get_instance_id()
		free_def.erase(best_d)
		free_opp.erase(best_o)

## Off-ball real estate: every role gets its own lane so five players spread
## over the attacking half instead of queueing on the same spot.
func random_offensive_spot(team: int, p: BallPlayer) -> Vector2:
	if not one_on_one and p.role <= 2:
		return pivot_home(team) + Vector2(randf_range(-24.0, 24.0), randf_range(-16.0, 16.0))
	var hoop: Vector2 = attack_hoop_for(p)
	var side := signf(hoop.x)
	# distance from the rim, measured back toward half court
	var lane: float
	match p.role:
		3:
			lane = randf_range(250.0, 470.0)   # wings and top of the key
		4:
			lane = randf_range(120.0, 340.0)   # elbows, short corners
		_:
			lane = randf_range(150.0, 400.0)   # role 5: blocks and corners
	var y: float = randf_range(-1.0, 1.0) * COURT_H * 0.40
	var spot := Vector2(hoop.x - side * lane, y)
	# Never park inside a small side area (that is the pivot's floor).
	for h in side_hoops:
		if spot.distance_to(h) < SIDE_AREA_R + 70.0:
			spot = h + (spot - h).normalized() * (SIDE_AREA_R + 70.0)
	return spot

## One cutter at a time: a queue of four men crashing the rim is not an
## offence. Whoever claims it keeps it for `dur` seconds.
var cutter_owner_id := 0
var cutter_until := 0.0

func claim_cutter(p: BallPlayer, dur: float) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if cutter_owner_id != 0 and now < cutter_until:
		var owner: BallPlayer = null
		for q in players:
			if q.get_instance_id() == cutter_owner_id:
				owner = q
		if owner != null and owner != p and not owner.has_ball:
			return false
	cutter_owner_id = p.get_instance_id()
	cutter_until = now + dur
	return true

## 0..1: how long the team has ignored its pivot. The AI uses it to make sure
## the ball actually reaches the small area during a possession — but only as
## ONE of several reads, never as a script.
var pivot_last_touch := [-99.0, -99.0]

## A delivery that never arrives cools the urge down instead of leaving the
## team walking the ball at the small area for the whole possession.
func note_delivery_failed(team: int) -> void:
	pivot_last_touch[team] = Time.get_ticks_msec() / 1000.0 - 6.0

func pivot_feed_urge(team: int) -> float:
	if pivot_player(team) == null:
		return 0.0
	var now := Time.get_ticks_msec() / 1000.0
	if pivot_last_touch[team] < 0.0:
		return 0.45     # a fresh match, not an obsession
	return clampf((now - pivot_last_touch[team]) / 24.0, 0.0, 1.0)

func clamp_to_court(p: Node2D) -> void:
	# the inbounder may stand out of bounds while the ball is dead
	var lim_x: float = COURT_W * 0.5 - 30.0
	var lim_y: float = COURT_H * 0.5
	# The thrower stands OUT of bounds: during the restart and during the beat
	# of stillness before the throw (play_live is still off), otherwise the
	# clamp yanks him onto the sideline mid-throw.
	if not play_live and _inbounder != null and p == _inbounder:
		lim_x = COURT_W * 0.5 + 80.0
		lim_y = COURT_H * 0.5 + 80.0
	p.global_position.x = clampf(p.global_position.x, -lim_x, lim_x)
	p.global_position.y = clampf(p.global_position.y, -lim_y, lim_y)
	# Baskin: role 1 lives inside his own side area and NEVER leaves it —
	# live or dead ball. Only the bench walk, the FT line and the huddle
	# break are exempt (the inbounder is never a pivot anyway).
	if not one_on_one and p is BallPlayer and p != _inbounder and not intermission \
	and not (ft_active and ft_shooter == p):
		var bp: BallPlayer = p as BallPlayer
		if bp.entering or bp.leaving:
			return
		# NOBODY crosses the opponents' side area: it is the other pivot's
		# floor. Enforced as a wall (a soft push out, every frame) so it is
		# impossible to enter instead of being whistled after the fact.
		for hi in side_hoops.size():
			if int(hi) == bp.team:
				continue
			var oh: Vector2 = side_hoops[hi]
			var roff: Vector2 = bp.global_position - oh
			var rlim: float = SIDE_AREA_R + 6.0
			if roff.length() < rlim:
				var push: Vector2 = roff.normalized() if roff.length() > 1.0 \
					else Vector2(0.0, signf(oh.y))
				bp.global_position = oh + push * rlim
		if bp.role > 2:
			return
		# THE PIVOTS LIVE IN THEIR AREA. Role 1 never leaves it; role 2 leaves
		# it only WITH THE BALL, and only to step past the dashed line for the
		# shot the rules require from outside (so he cannot wander the floor).
		var hh: Vector2 = side_hoops[bp.team]
		var rr: float = SIDE_AREA_R - 24.0
		if bp.role == 2 and bp.has_ball:
			rr = SIDE_PIVOT_RANGE
		var off: Vector2 = bp.global_position - hh
		if off.length() > rr:
			bp.global_position = hh + off.normalized() * rr

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
			"seed": t * 5 + 1, "team": t})
		var n: int = bench_roster[t].size()
		for i in n:
			# team 0: seat 0 is the user's, seat 4 the sub's -- hide whoever
			# is currently walking (the live nodes draw those).
			if t == 0 and i == USER_SEAT:
				# Draw the user seated only once he has actually arrived
				# (while walking off, his live node is the visual).
				if not user_on_court and not user.leaving:
					bench_seats_vis.append({"pos": seat_world(0, i), "col": col,
						"kind": "user", "jersey": user.jersey_num, "seed": i * 3,
						"team": 0})
				continue
			if t == 0 and i == PARTNER_SEAT and sub_partner != null \
					and is_instance_valid(sub_partner) and not sub_partner.leaving:
				continue
			var r: Dictionary = bench_roster[t][i]
			bench_seats_vis.append({"pos": seat_world(t, i), "col": col,
				"kind": "player", "jersey": int(r["jersey"]), "seed": i * 3 + t,
				"team": t})
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

## ------------------------------------------------- sostituzioni dal vivo
## Posti di panchina utilizzabili adesso (il posto dell'utente e quello del suo
## cambio automatico restano fuori, e un posto appena usato ha un cooldown).
func _reserved_for_inbound(p: BallPlayer) -> bool:
	# The receiving player is part of the restart before ball.pass_target exists.
	return restarting and not play_live and not ft_active and (p == _inbounder or p == _inbound_receiver)

func available_sub_seats() -> Array:
	# Senza panchina (scrimmage/sonda) non esistono posti: restituire [] qui
	# evita che la UI indicizzi bench_roster vuoto (crash al tasto CAMBIO).
	if not is_fixture:
		return []
	var out := []
	var busy := {}
	for w in _sub_walk:
		busy[int(w[2])] = true
	for i in 5:
		if i == USER_SEAT:
			continue
		if i == PARTNER_SEAT and sub_partner != null and is_instance_valid(sub_partner):
			continue
		if busy.has(i) or float(sub_seat_cd.get(i, 0.0)) > 0.0:
			continue
		out.append(i)
	return out

## Chiede un cambio. Per un compagno (o un avversario, se lo chiede il suo
## allenatore) il cambio si esegue alla prima PALLA MORTA. Per l'utente passa
## dal percorso gia' esistente (l'allenatore lo richiama).
func request_sub(p: BallPlayer, seat: int, by_user := true) -> bool:
	if not is_fixture or finished or p == null or seat < 0 or seat >= 5:
		return false
	if p == user:
		if not user_on_court:
			return false
		bench_user()
		Events.toast.emit(Loc.t("t.sub.self"))
		return true
	if not players.has(p) or p.role <= 0 or p == sub_partner:
		return false
	if seat == USER_SEAT:
		return false
	# un solo cambio in coda per posto e per squadra
	for r in sub_pending:
		if int(r["seat"]) == seat:
			return false
		if r["out"] != null and is_instance_valid(r["out"]) and r["out"].team == p.team:
			return false
	if float(sub_seat_cd.get(seat, 0.0)) > 0.0:
		return false
	sub_pending.append({"out": p, "seat": seat, "team": p.team})
	if by_user:
		Events.toast.emit(Loc.t("t.sub.req") % [p.jersey_num,
			int(bench_roster[0][seat]["jersey"]) if p.team == 0
			else int(bench_roster[1][seat]["jersey"])])
	return true

## Il cambio vero e proprio: chi esce cammina verso il suo posto, chi entra
## arriva dalla panchina con lo STESSO RUOLO e la STESSA fisionomia (la
## formazione deve restare regolamentare: due donne in campo, un solo pivot).
func _start_sub(out_p: BallPlayer, seat: int) -> void:
	# Validate before creating a player: practice games have no bench roster.
	if not is_fixture or not is_instance_valid(out_p) or out_p == user or out_p == sub_partner:
		return
	var team: int = out_p.team
	if team < 0 or team >= bench_roster.size() or seat < 0 or seat >= bench_roster[team].size():
		return
	var inn: BallPlayer = preload("res://src/match/Player.gd").new()
	inn.team = team
	add_child(inn)
	_randomize_npc(inn, team)
	inn.gender = out_p.gender
	inn.hair_style_v = out_p.hair_style_v
	inn.hair_col = out_p.hair_col
	inn.height_f = out_p.height_f
	inn.mass_f = out_p.mass_f
	inn.role = out_p.role
	inn.variant = out_p.variant
	_apply_role_kit(inn)
	var r: Dictionary = bench_roster[team][seat]
	inn.jersey_num = int(r["jersey"])
	inn.display_name = String(r["name"])
	inn.global_position = seat_world(team, seat)
	inn.entering = true
	inn.set_meta("wait_sub", true)
	inn.bench_target = _formation_pos(team, seat)
	out_p.leaving = true
	out_p.bench_target = seat_world(team, seat)
	if players.has(out_p):
		players.erase(out_p)          # e' fuori: non conta piu' in campo
	sub_seat_cd[seat] = SUB_GAP
	_sub_walk.append([out_p, inn, seat])
	_refresh_bench_vis()
	Events.toast.emit(Loc.t("t.sub.done") % [inn.jersey_num, out_p.jersey_num])
	if team == 0:
		Events.rule.emit("sub")

## Camminata dei cambi: chi esce va a sedersi, chi entra aspetta che l'altro sia
## arrivato e poi prende il suo posto in campo (con il cervello IA).
func _process_live_subs(delta: float) -> void:
	for k in sub_seat_cd.keys():
		sub_seat_cd[k] = maxf(0.0, float(sub_seat_cd[k]) - delta)
	# 1) richieste in coda: si eseguono a palla morta
	if not sub_pending.is_empty() and not ft_active and not finished:
		var dead: bool = (not play_live) or restarting or inbound_wait > 0.0 or awaiting_check
		if dead:
			var req: Dictionary = sub_pending[0]
			var op = req["out"]
			if op == null or not is_instance_valid(op) or not players.has(op) \
			or op.entering or op.leaving:
				sub_pending.pop_front()      # non piu' possibile: lascia perdere
			elif op.has_ball or op.jumping or op.hanging or ball.pass_target == op or _reserved_for_inbound(op):
				pass                          # ASPETTA: e' nel mezzo di un'azione
			else:
				sub_pending.pop_front()
				_start_sub(op, int(req["seat"]))
	# 2) chi cammina
	for w in _sub_walk.duplicate():
		var o = w[0]
		var n = w[1]
		var done := true
		if n != null and is_instance_valid(n):
			if n.entering and n.has_meta("wait_sub"):
				done = false
				if o == null or not is_instance_valid(o) or not o.leaving:
					n.remove_meta("wait_sub")
			if n.entering or n.leaving:
				done = false
				var dn: Vector2 = n.bench_target - n.global_position
				if dn.length() > 24.0:
					n.global_position += dn.normalized() * minf(330.0 * delta, dn.length())
					n.velocity = dn.normalized() * 300.0
					if absf(dn.x) > 4.0:
						n.facing = signf(dn.x)
				else:
					n.velocity = Vector2.ZERO
					n.entering = false
					if not players.has(n):
						players.append(n)
					var brain := preload("res://src/match/AIBrain.gd").new()
					n.add_child(brain)
					brain.setup(n, self)
		if o != null and is_instance_valid(o):
			if o.leaving:
				done = false
				var dv: Vector2 = o.bench_target - o.global_position
				if dv.length() > 24.0:
					o.global_position += dv.normalized() * minf(330.0 * delta, dv.length())
					o.velocity = dv.normalized() * 300.0
					if absf(dv.x) > 4.0:
						o.facing = signf(dv.x)
				else:
					o.velocity = Vector2.ZERO
					o.leaving = false
					if players.has(o):
						players.erase(o)
					if o.has_ball and ball != null:
						ball.detach()
						ball.live = true
						o.has_ball = false
					o.queue_free()
		if done:
			_sub_walk.erase(w)

## L'allenatore cambia chi non ha piu' gambe (vale per entrambe le squadre: si
## vede anche nella partita IA).
func _coach_subs() -> void:
	if not is_fixture or one_on_one or finished or ft_active:
		return
	for p in players.duplicate():
		if p == null or not is_instance_valid(p) or p.role <= 0 or p.is_user or p == user or p == sub_partner:
			continue
		if p.leaving or p.entering or p.has_ball or p.stamina > 18.0:
			continue
		var busy := false
		for r in sub_pending:
			if r["out"] != null and is_instance_valid(r["out"]) and r["out"].team == p.team:
				busy = true
		for w in _sub_walk:
			if w[0] != null and is_instance_valid(w[0]) and w[0].team == p.team:
				busy = true
		if busy:
			continue
		var seats: Array = []
		if p.team == 0:
			seats = available_sub_seats()
		else:
			for i in 5:
				if float(sub_seat_cd.get(i, 0.0)) <= 0.0:
					seats.append(i)
			for w in _sub_walk:
				if w[0] != null and is_instance_valid(w[0]) and w[0].team == p.team:
					var used: int = int(w[2])
					if seats.has(used):
						seats.erase(used)
		if seats.is_empty():
			continue
		sub_pending.append({"out": p, "seat": int(seats[0]), "team": p.team})

## Sub the USER off: he walks to the bench while his reserve walks on.
func bench_user() -> void:
	if not is_fixture or not user_on_court or finished:
		return
	# Only at a safe moment: never mid-shot, mid-FT or holding the rock.
	if ft_active or _reserved_for_inbound(user) or user.has_ball or user.shot_charge >= 0.0 \
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
	if ft_active or _reserved_for_inbound(sub_partner) or sub_partner.has_ball \
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
	_process_live_subs(delta)
	_coach_subs()
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
	# UN TIMEOUT E' UN RESPIRO: le gambe tornano. 4 secondi di pausa valgono
	# energie, altrimenti il pulsante era solo una pausa senza senso.
	for q in players:
		if q.team == team:
			q.stamina = minf(100.0, q.stamina + 22.0)
	Events.toast.emit(Loc.t("t.timeout.breather"))
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
	shot_clock = 24.0
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

func consume_quarter_opening() -> bool:
	if _qb_inbound:
		_qb_inbound = false
		return true
	return false

func start_quarter_inbound() -> void:
	## Quarters 2-4 open like real basketball: formation, then the ball
	## re-enters from the baseline.
	for p in players:
		var squad := players.filter(func(x): return x.team == p.team)
		p.global_position = _formation_pos(p.team, squad.find(p))
		if p.role <= 2:
			p.global_position = pivot_home(p.team)
		p.velocity = Vector2.ZERO
		p.move_input = Vector2.ZERO
		p.has_ball = false
	ball.visible = true
	_inbound(possession)
