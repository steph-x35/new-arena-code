extends Node
class_name AIBrain
## Finite state machine driving one non-user BallPlayer.
## States: IDLE / ATTACK_ON_BALL / ATTACK_OFF_BALL / DEFEND_ON_BALL / DEFEND_OFF_BALL / REBOUND

enum S { IDLE, ATK_ON, ATK_OFF, DEF_ON, DEF_OFF, REBOUND }

var p: BallPlayer
var court: Node2D
var state: int = S.IDLE
var think_t := 0.0
var think_every := 0.18
var mark: BallPlayer = null
var spot := Vector2.ZERO
var role := "spot"          # spot / cutter / screener / roller
var pass_t := 0.0           # cooldown between pass-decision evaluations
var cut_t := 0.0
var pnr_t := 0.0
var pnr_from: BallPlayer = null
var pnr_hold := false
var screen_on: BallPlayer = null
var aggression := 0.5
var shot_cd := 0.0
var want_drive := true
var _jumped_gather := false   # one contest jump per opponent gather
var _fake_seen := false       # one bite chance per pump fake

var skill := 0.5               # 0..1: sale con rep e livello (carriera reale)
var _bites := 0               # finte morsiccate in QUESTA possessione
var _last_poss := -1
var _chase_t := 0.0           # cooldown dello scatto d'inseguimento
var _last_mark_move := ""      # memoria dei move dell'attaccante
var _last_mark_move_t := -10.0
var _move_rep := 0

func setup(player: BallPlayer, c: Node2D) -> void:
	p = player
	court = c
	aggression = randf_range(0.35, 0.75)
	# Gli avversari crescono con la carriera: rep alta = difese attive,
	# scelte pulite, tiro piu' selettivo. Il 1v1 di strada resta tosto.
	var rep_v: float = clampf(float(Game.profile.get("rep", 0)) / 60.0, 0.0, 1.0)
	skill = clampf((0.40 + rep_v * 0.62 + float(Game.profile.get("level", 1)) * 0.012
		+ float(p.ratings.get("defense", 50)) / 400.0) * Game.diff_mult(),
		Game.diff_floor(), 0.99)
	if bool(Game.profile.get("playoff", {}).get("live", false)):
		skill = clampf(skill + 0.05, 0.0, 0.99)   # playoff: niente regali
	aggression = lerpf(aggression, clampf(aggression * 0.7 + skill * 0.5, 0.3, 0.9), 0.6)
	# Nel DUELLO l'avversario e' sempre un gradino piu cattivo: anche a
	# profilo nuovo con INCUBO difende da veterano.
	if court.one_on_one:
		skill = clampf(skill + 0.04, Game.diff_floor(), 0.99)
		aggression = clampf(aggression + 0.05, 0.0, 0.95)
	spot = p.global_position

func _physics_process(delta: float) -> void:
	if p != null and (p.entering or p.leaving):
		return
	# Gioco fermo (countdown, check 1v1, pausa fischietto): non eseguire azioni o rebound
	if p == null or court == null or not court.play_live:
		# Durante la rimessa 5v5 la difesa ombreggia il proprio uomo
		if court != null and p != null and court.inbound_wait > 0.0 \
		and p.team != int(court.possession) and not court.one_on_one:
			var mk: BallPlayer = court.man_mark_for(p)
			if mk != null:
				var goal: Vector2 = (mk.global_position + court.hoop_for(p.team)) * 0.5
				var dvec: Vector2 = goal - p.global_position
				p.move_input = dvec.normalized() if dvec.length() > 26.0 else Vector2.ZERO
				if absf(dvec.x) > 4.0:
					p.facing = signf(dvec.x)
		elif p != null:
			p.move_input = Vector2.ZERO
		return
	think_t -= delta
	shot_cd = maxf(0.0, shot_cd - delta)
	if think_t <= 0.0:
		think_t = lerpf(0.20, 0.10, clampf(float(p.ratings.get("defense", 50)) / 99.0, 0.0, 1.0))
		_decide()
	_act(delta)

func _decide() -> void:
	var ball: Ball = court.ball
	if ball.live and ball.shot_result_pending:
		state = S.REBOUND
		return
	var bh: BallPlayer = court.ball_handler()
	if bh == null:
		state = S.REBOUND
		return
	if bh.team == p.team:
		state = S.ATK_ON if bh == p else S.ATK_OFF
	else:
		# Man-to-man: my team-mates and I each take ONE opponent and stay on
		# him. The guy who drew the ball-handler plays on-ball defence; the
		# rest deny their own man instead of all chasing the same one.
		mark = court.man_mark_for(p)
		state = S.DEF_ON if mark == bh else S.DEF_OFF

func begin_screen(baller: BallPlayer) -> void:
	pnr_from = baller
	pnr_t = 99.0
	pnr_hold = true
	role = "screener"

func set_screen_target(d: BallPlayer) -> void:
	screen_on = d

func begin_roll() -> void:
	pnr_hold = false
	pnr_t = 3.0
	role = "roller"
	screen_on = null

func run_pick_and_roll(baller: BallPlayer) -> void:
	begin_screen(baller)
	pnr_t = 2.4
	pnr_hold = false

func _act(delta: float) -> void:
	_chase_t = maxf(0.0, _chase_t - delta)
	if court.possession != _last_poss:
		_last_poss = int(court.possession)
		_bites = 0   # nuova azione: la memoria delle finte riparte
	if pnr_t > 0.0:
		pnr_t -= delta
		_do_pnr(delta)
		# Screen held its angle long enough: slip into the paint on my own so
		# an AI-called pick still produces a roll (the user flow releases via
		# the P&R button instead).
		if role == "screener" and not pnr_hold and pnr_t < 1.0:
			begin_roll()
			court.pnr_roller = p
			court.roller_t = 3.5
		# A planted screen must stay still — spacing would shove him off the
		# defender and the pick would never form.
		if not pnr_hold and role != "screener":
			_apply_spacing()
		return
	match state:
		S.ATK_ON: _attack_on_ball(delta)
		S.ATK_OFF: _attack_off_ball(delta)
		S.DEF_ON: _defend_on_ball(delta)
		S.DEF_OFF: _defend_off_ball(delta)
		S.REBOUND: _rebound(delta)
		_: p.move_input = Vector2.ZERO
	_apply_spacing()

func _apply_spacing() -> void:
	# Keep five-a-side from collapsing into a huddle.
	if court == null or p == null:
		return
	var push := Vector2.ZERO
	for o in court.players:
		if o == p:
			continue
		var off: Vector2 = p.global_position - o.global_position
		var d: float = off.length()
		if d < 110.0 and d > 0.5:
			push += off.normalized() * (1.0 - d / 110.0)
	if push.length() > 0.05:
		p.move_input = (p.move_input + push * 1.35).normalized() if (p.move_input + push).length() > 0.08 else push.normalized()

## Pass-decision scoring: openness first, rim proximity second, the roller
## third. Returns a mate only when the pass is genuinely worth taking.
func _best_feed(my_pressure: float) -> BallPlayer:
	var hoop: Vector2 = court.hoop_for(p.team)
	var best: BallPlayer = null
	var best_v := 0.0
	for m in court.players:
		if m.team != p.team or m == p:
			continue
		if court.has_method("behind_hoop") and court.behind_hoop(m):
			continue
		var open_m: float = 1.0 - court.pressure_on(m)
		if open_m < 0.45:
			continue                       # covered: no gift turnovers
		var d_ft: float = court.px_to_ft(m.global_position.distance_to(hoop))
		var v := 0.0
		if d_ft < 8.0 and open_m > 0.55:
			v = 0.80 + open_m * 0.2        # open man under the rim: feed him NOW
		if court.pnr_roller == m and open_m > 0.50:
			v = maxf(v, 0.90)              # the roll is the whole point of the pick
		if my_pressure > 0.68 and open_m > my_pressure + 0.22:
			v = maxf(v, 0.45)              # escape the squeeze into an open hand
		if v > best_v:
			best_v = v
			best = m
	if best != null and randf() < best_v:
		return best
	return null

func _nearest_mate_brain() -> Node:
	var best: Node = null
	var bd := 1e9
	for m in court.players:
		if m.team != p.team or m == p:
			continue
		var d: float = m.global_position.distance_to(p.global_position)
		if d < bd:
			for c in m.get_children():
				if c.has_method("run_pick_and_roll"):
					bd = d
					best = c
	return best

# ------------------------------------------------------------------ offense
func _attack_on_ball(delta: float) -> void:
	var hoop: Vector2 = court.hoop_for(p.team)
	var to_hoop: Vector2 = hoop - p.global_position
	var dist_ft: float = court.px_to_ft(to_hoop.length())
	var pressure: float = court.pressure_on(p)
	if court.one_on_one and court.must_clear:
		p.move_input = (p.global_position - hoop).normalized()
		return
	if court.has_method("behind_hoop") and court.behind_hoop(p):
		p.move_input = (Vector2.ZERO - p.global_position).normalized()
		return
	# --- Feed the open man, above all at the rim -------------------------
	# A team-mate standing uncovered under the basket MUST get the ball:
	# before this layer the handler only passed while suffocating, so easy
	# buckets under the iron were simply never offered.
	if not court.one_on_one and p.ai_windup_t < 0.0:
		pass_t -= delta
		if pass_t <= 0.0:
			pass_t = randf_range(0.30, 0.55)
			var mate := _best_feed(pressure)
			if mate != null:
				p.do_pass(mate)
				shot_cd = 0.6
				spot = Vector2.ZERO
				return
		# AI ball-handlers call their own pick & roll when squeezed.
		if not court.pnr_screening and pressure > 0.55 and randf() < delta * 0.30:
			var scr := _nearest_mate_brain()
			if scr != null:
				scr.run_pick_and_roll(p)
				Events.toast.emit("SCREEN")
				return
	# Mid-gather the AI plants; the wind-up then releases on its own. A smart
	# handler who finds a defender all over his look puts it back down and
	# resets instead of hoisting into a guaranteed contest.
	if p.ai_windup_t >= 0.0:
		p.move_input = Vector2.ZERO
		# A defender who closes out hard kills the look: put it back down and
		# re-pick the play (often a drive) instead of hoisting a brick. Only
		# bail out EARLY -- once the gather is committed you rise into the
		# contest -- and never bail inside the final shot-clock seconds.
		if p.gather_progress() < 0.35 and court.shot_clock > 6.0 \
		and pressure > 0.78 and randf() < 0.6:
			p.cancel_ai_shot()
			shot_cd = 0.8
			spot = Vector2.ZERO
		return
	# Pick a real basketball play instead of always crashing the rim.
	if spot.length() < 1.0:
		var r: float = randf()
		if r < 0.28:
			role = "three"
			var side: float = -1.0 if randf() < 0.5 else 1.0
			spot = hoop + Vector2(-signf(hoop.x) * 430.0, side * randf_range(180.0, 360.0))
		elif r < 0.55:
			role = "mid"
			spot = hoop + Vector2(-signf(hoop.x) * randf_range(220.0, 320.0), randf_range(-160.0, 160.0))
		else:
			role = "drive"
			spot = hoop + Vector2(-signf(hoop.x) * 70.0, randf_range(-40.0, 40.0))
	var used: float = 24.0 - court.shot_clock
	var at_spot: bool = p.global_position.distance_to(spot) < 48.0
	var clock_death: bool = court.shot_clock < 3.5
	var can_fire: bool = p.cooldown_move <= 0.0 and shot_cd <= 0.0 and not (court.has_method("behind_hoop") and court.behind_hoop(p))
	# Buzzer beater: the 24-second clock overrides move cooldowns so the AI
	# always gets the heave away instead of taking a violation.
	if clock_death and shot_cd <= 0.0 and not (court.has_method("behind_hoop") and court.behind_hoop(p)):
		can_fire = true
	# Finish at the rim FIRST, independent of the jumper's cooldowns: a drive
	# that arrives at the iron with legs underneath it goes up and slams. This
	# used to sit behind `can_fire`, so a handler who reached the rim mid-move
	# simply never pulled the trigger and the slam never happened.
	if dist_ft < 6.5 and p.can_dunk() \
	and not (court.has_method("behind_hoop") and court.behind_hoop(p)) \
	and (role == "drive" or used > 5.0 or pressure < 0.72):
		p.do_dunk()
		shot_cd = 1.6
		spot = Vector2.ZERO
		return
	if can_fire:
		var pull: bool = false
		if clock_death:
			pull = dist_ft < 30.0
		elif role == "three" and at_spot and dist_ft > 21.0 and dist_ft < 27.0 and pressure < lerpf(0.70, 0.52, skill):
			pull = true
		elif role == "mid" and at_spot and dist_ft > 10.0 and dist_ft < 20.0 and pressure < lerpf(0.55, 0.40, skill):
			pull = true
		elif role == "drive" and dist_ft < 8.0 and used > 6.0:
			pull = true
		elif used >= 11.0 and dist_ft < 24.0 and pressure < 0.5:
			pull = true
		if pull:
			# Release quality follows the rating of the shot being taken: a
			# sharpshooter's threes and a finisher's mid-rangers both gather
			# cleanly; weaker hands miss the window more often.
			var skill_key: String = "three" if dist_ft > ShotSystem.THREE_FT else "mid"
			var err: float = randfn(0.0, lerpf(0.12, 0.024,
				clampf(float(p.ratings[skill_key]) / 99.0 * (0.70 + skill * 0.5), 0.0, 1.0)))
			# TELEGRAPHED gather instead of an instant release, so a watching
			# defender can close out and the shot can be read and blocked.
			p.begin_ai_shot(err, clampf(0.42 + dist_ft * 0.011, 0.42, 0.8))
			shot_cd = 1.5
			spot = Vector2.ZERO
			return
	# Beat the on-ball defender with the handle before driving on. Drives throw
	# crossovers and behind-the-back moves, spot-up men jab into a stepback to
	# make room, and an occasional hesitation freezes the defender's feet.
	if p.cooldown_move <= 0.0:
		var nd: BallPlayer = null
		var ndist := 1e9
		for d in court.players:
			if d.team == p.team:
				continue
			var dd: float = d.global_position.distance_to(p.global_position)
			if dd < ndist:
				ndist = dd
				nd = d
		if nd != null:
			var move := ""
			if role == "drive" and ndist < 112.0 and randf() < 0.60:
				move = ["crossover", "behind", "crossover"].pick_random()
			elif (role == "mid" or role == "three") and at_spot and ndist < 92.0 and randf() < 0.55:
				move = "stepback"
			elif ndist < 140.0 and randf() < 0.10:
				move = "hesi"
			if move != "" and p.do_move(move):
				return
	if pressure > 0.78 and not court.one_on_one:
		var mate: BallPlayer = court.best_pass_option(p)
		if mate != null and randf() < 0.38:
			p.do_pass(mate)
			return
	# 1v1: il bravo usa la FINTA prima del tiro quando il difensore e'
	# addosso, e spara veloce se il difensore vola.
	if court.one_on_one and pressure > 0.50 and shot_cd <= 0.0 \
	and p.cooldown_move <= 0.0 and p.ai_windup_t < 0.0 and randf() < 0.30:
		p.do_pump_fake()
		shot_cd = 0.7
		return
	var tgt: Vector2 = spot if spot.length() > 1.0 else hoop
	var lane: Vector2 = court.pressure_dir(p)
	var dir: Vector2 = ((tgt - p.global_position).normalized() - lane * 0.55)
	if dir.length() < 0.05:
		dir = tgt - p.global_position
	p.move_input = dir.normalized() if p.global_position.distance_to(tgt) > 22.0 else Vector2.ZERO

func _attack_off_ball(delta: float) -> void:
	cut_t -= delta
	var hoop: Vector2 = court.hoop_for(p.team)
	if cut_t <= 0.0:
		cut_t = randf_range(2.0, 4.5)
		role = ["spot", "cutter", "screener"].pick_random()
		spot = court.random_offensive_spot(p.team, p)
	var target := spot
	match role:
		"cutter":
			# backdoor cut when my defender is ball-watching
			target = hoop + Vector2(randf_range(-45, 45), randf_range(-25, 25))
		"screener":
			var bh: BallPlayer = court.ball_handler()
			if bh != null:
				target = bh.global_position + (hoop - bh.global_position).normalized() * 55.0
	var d := target - p.global_position
	p.move_input = d.normalized() if d.length() > 18.0 else Vector2.ZERO

# ------------------------------------------------------------------ defense
func _do_pnr(_delta: float) -> void:
	var hoop: Vector2 = court.hoop_for(p.team)
	if pnr_from == null or not is_instance_valid(pnr_from):
		pnr_t = 0.0
		pnr_hold = false
		return
	if pnr_hold or role == "screener":
		# Walk to the defender, then PLANT. A good screen is a still body.
		var tgt: Vector2
		if screen_on != null and is_instance_valid(screen_on):
			var between: Vector2 = (pnr_from.global_position - screen_on.global_position)
			if between.length() < 4.0:
				between = Vector2(-pnr_from.facing, 0.0)
			tgt = screen_on.global_position + between.normalized() * 18.0
		else:
			tgt = pnr_from.global_position + Vector2(-pnr_from.facing * 28.0, 0.0)
		var d: Vector2 = tgt - p.global_position
		if d.length() > 16.0:
			p.move_input = d.normalized()
		else:
			p.move_input = Vector2.ZERO
			p.velocity *= 0.35
			p.stance = true
	else:
		# Roll: dive into the paint, under the rim.
		var paint: Vector2 = hoop + Vector2(-signf(hoop.x) * 70.0, 0.0)
		var d2: Vector2 = paint - p.global_position
		p.move_input = d2.normalized() if d2.length() > 16.0 else Vector2.ZERO

func _defend_on_ball(delta: float) -> void:
	var bh: BallPlayer = court.ball_handler()
	if bh == null: return
	# the basket I am protecting is the one my opponents attack
	var own_hoop: Vector2 = court.hoop_for(1 - p.team)
	var gathering: bool = bh.has_method("is_gathering") and bh.is_gathering()
	var d0: float = p.global_position.distance_to(bh.global_position)
	# --- pump fake: sell out and bite. Aggressive, slow-footed defenders bite
	# harder; lockdown feet stay grounded and contest for real.
	if bh.fake_t > 0.0:
		if not _fake_seen and d0 < 135.0:
			_fake_seen = true
			_bites += 1
			var bite_ch: float = (0.30 + aggression * 0.55) * (1.25 - float(p.ratings["defense"]) / 150.0)
			# I bravi non volano e dopo il primo morso in azione imparano:
			# ogni finta successiva ha molta meno presa.
			bite_ch *= lerpf(1.0, 0.38, skill)
			bite_ch *= pow(0.55, _bites - 1)
			if randf() < bite_ch:
				p.do_jump(true, 120.0)
				p.bite_recovery = lerpf(0.55, 0.26, skill)
				if bh.is_user:
					Events.toast.emit("Defender bit the fake!")
	else:
		_fake_seen = false
	# sit between the handler and the basket; close out SHORT as he gathers,
	# but only hug him inside the arc -- a perimeter shooter is contested from
	# a step away instead of being handed a free 24 % contact trip.
	var shooter_range: float = bh.global_position.distance_to(court.hoop_for(bh.team))
	var gap: float = lerpf(76.0, 52.0, skill)
	if court.one_on_one:
		gap *= lerpf(1.0, 0.80, skill)   # nel duello il bravo si ascuga ancora di piu
		gap *= lerpf(1.0, 0.92, float(Game.difficulty()) / 3.0)   # INCUBO: ancora addosso
	if gathering:
		# Close-out reale: dentro l'arco si sta addosso, fuori un passo.
		gap = lerpf(54.0, 38.0, skill) if shooter_range < 220.0 else lerpf(80.0, 62.0, skill)
	# Un attaccante che ripete sempre lo stesso move si legge: il difensore
	# esperto DA TERRA e allarga, invece di farsi shook ancora. La memoria
	# svanisce in 3 secondi: non e' un bias permanente.
	var now_s: float = Time.get_ticks_msec() / 1000.0
	if now_s - _last_mark_move_t > 3.0:
		_move_rep = 0
	if bh.move_t > 0.0 and bh.move_kind != "":
		if bh.move_kind == _last_mark_move and _move_rep >= 1:
			gap += 30.0 * skill   # perde l'equilibrio la PRIMA volta, non la quarta
		if bh.move_kind != _last_mark_move:
			_last_mark_move = bh.move_kind
			_move_rep = 0
		else:
			_move_rep += 1
		_last_mark_move_t = now_s
	var guard_pos: Vector2 = bh.global_position + (own_hoop - bh.global_position).normalized() * gap
	var d := guard_pos - p.global_position
	p.move_input = d.normalized() if d.length() > 8.0 else Vector2.ZERO
	p.stance = d.length() < 100.0 or (gathering and d0 < 175.0)
	# --- INSEGUIMENTO: quando il portatore attacca il ferro, il difensore
	# scatta da dietro invece di restare piantato sul trick.
	if _chase_t <= 0.0 and d0 < 320.0 \
	and (bh.dunking or (bh.has_method("is_gathering") and bh.is_gathering()
		and bh.global_position.distance_to(court.hoop_for(bh.team)) < 210.0)):
		p.chase(bh.global_position + (own_hoop - bh.global_position).normalized() * 26.0)
		_chase_t = 0.32
	# --- timed jump to contest the release (or meet a dunker at the rim)
	# VUOTO CHIUSO: la schiacciata NON e' un gather, quindi prima il
	# difensore non saltava MAI a contrastare un dunker: canestro libero.
	# Ora reagisce al dunk in corso (chance per difficolta: 45/70/90%).
	if bh.dunking and not p.jumping and not p.hanging and d0 < 150.0 \
	and randf() < lerpf(0.45, 0.92, float(Game.difficulty()) / 3.0):
		p.do_jump(true, 160.0)
		_jumped_gather = true
	if gathering and not _jumped_gather and not p.jumping and not p.hanging:
		var prog: float = bh.gather_progress()
		var at_rim: bool = bh.dunking or bh.hanging
		var want := false
		if at_rim and d0 < lerpf(120.0, 185.0, skill) + float(Game.difficulty()) * 6.0:
			want = true   # nel duello arriva al ferro anche da piu lontano
		elif d0 < 110.0 and shooter_range < 560.0:
			# Jump LATE and only part of the time: an early commit is exactly
			# what a pump fake punishes, and a clean contest is not a clean
			# block. Better defenders time and commit more reliably.
			var threshold: float = lerpf(0.50, 0.38, skill) if shooter_range < 220.0 else lerpf(0.62, 0.50, skill)
			# Salta piu' spesso con skill alta: il finto perde morsi ma il
			# tiratore libero non esiste piu' ai livelli alti.
			var commit: float = lerpf(0.34, 0.86, clampf(float(p.ratings["defense"]) / 99.0 * (0.65 + skill * 0.55), 0.0, 1.0))
			if prog > threshold:
				want = randf() < commit
		if want:
			p.do_jump(true, 150.0)
			_jumped_gather = true
	if not gathering and bh.fake_t <= 0.0:
		_jumped_gather = false
	# contest / steal
	if bh.shot_charge >= 0.0 and d0 < 80.0:
		p.stance = true
	if d0 < 46.0 and randf() < (0.006 + aggression * 0.010) * lerpf(0.75, 1.7, skill) \
		* lerpf(1.0, 1.30, float(Game.difficulty()) / 3.0):
		p.try_steal()
	# INCUBO nel duello: se fai un trick DENTRO il suo raggio te lo paga
	# spesso: la palla viene pescata di braccio durante la mossa.
	if court.one_on_one and Game.difficulty() == 3 \
	and bh.move_t > 0.0 and d0 < 68.0 and randf() < 0.10:
		p.try_steal()

func _defend_off_ball(delta: float) -> void:
	if mark == null:
		mark = court.man_mark_for(p)
		if mark == null: return
	var own_hoop: Vector2 = court.hoop_for(1 - p.team)
	var ball_pos: Vector2 = court.ball.global_position
	# deny line: one third toward the ball, two thirds on the man
	var cutting: bool = mark.move_t > 0.0 or mark.velocity.length() > 140.0
	var deny_k: float = 0.32 if cutting else 0.22   # sul taglio si sta sul linea
	var help: Vector2 = mark.global_position.lerp(own_hoop, deny_k)
	help = help.lerp(ball_pos, 0.20)
	var d := help - p.global_position
	p.move_input = d.normalized() if d.length() > 14.0 else Vector2.ZERO
	p.stance = d.length() < 70.0

func _rebound(delta: float) -> void:
	var ball: Ball = court.ball
	var land: Vector2 = ball.global_position + ball.vel * 0.38
	# Scatolamento: se un avversario e' piu' vicino alla palla, mettiti FRA
	# lui e il punto di caduta invece di rincorrere insieme a lui.
	var opp: BallPlayer = null
	var od := 1e9
	for o in court.players:
		if o.team == p.team: continue
		var dd: float = o.global_position.distance_to(land)
		if dd < od:
			od = dd
			opp = o
	if opp != null and opp.global_position.distance_to(land) < p.global_position.distance_to(land):
		land = land.lerp(opp.global_position, 0.35)
	var d := land - p.global_position
	p.move_input = d.normalized() if d.length() > 12.0 else Vector2.ZERO
	# Actually pick the thing up. Without this the AI crowds a loose ball
	# forever and only the watchdog ever ends the possession.
	if ball.holder == null and d.length() < 70.0:
		court.try_grab(p)
