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
var settle_t := 0.0           # pivot: compulsory plant before the release
var settled := false
var play_age := 0.0           # seconds the current play has been running
var delivery_side := 0.0       # one approach side per delivery, not a coin flip per frame
var hold_wo_shot := 0.0       # pivot: planted on his spot but unable to shoot

var skill := 0.5               # 0..1: sale con rep e livello (carriera reale)
## DIFFICOLTA' SCELTA DALL'UTENTE (Impostazioni). Questi moltiplicatori sono
## l'unica parte di skill che NON dipende dalla carriera: cosi' "Facile" e
## "Forte" cambiano davvero la partita (chiusure, rubi, raddoppi, falli) e non
## sono solo un'etichetta.
var diff := 1
var d_steal := 1.0
var d_commit := 1.0
var d_foul := 1.0
var d_help := 1.0
var d_noise := 0.12
var d_react := 0.0
var foul_cd := 0.0             # contact fouls: no whistle every second

## Quanto e' facile per questo difensore commettere un fallo di contatto, in
## pratica: la probabilita' al secondo e' (0.04 + aggressione * 0.05) * d_foul.
func d_foul_real() -> float:
	return (0.04 + aggression * 0.05) * d_foul
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
	skill = clampf(0.30 + rep_v * 0.55 + float(Game.profile.get("level", 1)) * 0.012
		+ float(p.ratings.get("defense", 50)) / 400.0, 0.30, 0.96)
	diff = int(Settings.get_v("difficulty", Game.profile.get("difficulty", 1)))
	match diff:
		0:
			skill = clampf(skill * 0.62 - 0.06, 0.16, 0.62)
			d_steal = 0.55
			d_commit = 0.75
			d_foul = 0.60
			d_help = 0.70
			d_noise = 0.45
			d_react = 0.07
		2:
			skill = clampf(skill * 0.45 + 0.55, 0.60, 0.99)
			d_steal = 1.35
			d_commit = 1.25
			d_foul = 1.15
			d_help = 1.10
			d_noise = 0.10
			d_react = -0.03
	aggression = lerpf(aggression, clampf(aggression * 0.7 + skill * 0.5, 0.3, 0.9), 0.6)
	spot = p.global_position

func _physics_process(delta: float) -> void:
	if p != null and (p.entering or p.leaving):
		return
	if p == null or court == null or not court.play_live:
		# THROW-IN DEFENCE: every defender gets between his man and the basket
		# they are defending, ON THE SIDE THE BALL COMES FROM. Standing around
		# mid-court instead handed the thrower an open road to the rim. Runs for
		# every dead ball (sideline, baseline, after a steal), not just while
		# the human waits to call for it.
		if court != null and p != null and not court.one_on_one \
		and (court.restarting or court.inbound_wait > 0.0) \
		and p.team != int(court.possession):
			if court._inbound_preparing:
				p.move_input = Vector2.ZERO
				return
			if p.role <= 2:
				p.move_input = Vector2.ZERO
				return
			var aim: Vector2 = court.inbound_defense_target(p)
			var dvec: Vector2 = aim - p.global_position
			p.move_input = dvec.normalized() if dvec.length() > 18.0 else Vector2.ZERO
			p.stance = dvec.length() < 90.0
			if absf(dvec.x) > 4.0:
				p.facing = signf(dvec.x)
		elif p != null:
			p.move_input = Vector2.ZERO
		return
	# CONSEGNA: se un mio compagno ha la palla DENTRO la mia area laterale, io
	# pivot gli vengo incontro per riceverla (la palla al pivot si consegna
	# solo da dentro l'area, quindi starsene fermi sulla mia mattonella non
	# serviva a niente). Se ha la palla un avversario, non c'e' niente da fare.
	if p.role <= 2 and not court.one_on_one:
		var hb: BallPlayer = court.ball_handler()
		if hb != null and hb.team == p.team and hb != p \
		and court.in_side_area(hb.global_position) and court.in_side_area(p.global_position):
			var spot: Vector2 = court.handoff_spot(p, hb)
			var dv: Vector2 = spot - p.global_position
			p.move_input = dv.normalized() if dv.length() > 10.0 else Vector2.ZERO
			p.stance = dv.length() < 70.0
			if absf(hb.global_position.x - p.global_position.x) > 6.0:
				p.facing = signf(hb.global_position.x - p.global_position.x)
			return
	think_t -= delta
	shot_cd = maxf(0.0, shot_cd - delta)
	if think_t <= 0.0:
		think_t = lerpf(0.20, 0.10, clampf(float(p.ratings.get("defense", 50)) / 99.0, 0.0, 1.0)) + d_react
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

func _cancel_pnr() -> void:
	pnr_t = 0.0
	pnr_hold = false
	pnr_from = null
	screen_on = null
	role = "spot"
	spot = Vector2.ZERO
	play_age = 0.0
	p.stance = false
	if court.pnr_screener == p:
		court.pnr_screener = null
		court.pnr_screening = false
		court.pnr_timer = 0.0
	if court.pnr_roller == p:
		court.pnr_roller = null
		court.roller_t = 0.0

func _act(delta: float) -> void:
	# A screen/roll is an off-ball offensive job, never a defensive one.
	# Receiving the pass ends the roll too: read the shot or next pass now.
	if pnr_t > 0.0 and (p.has_ball or p.team != court.possession
		or p.role <= 2 or not is_instance_valid(pnr_from)
		or not court.players.has(pnr_from) or pnr_from.leaving
		or court.ball.shot_result_pending):
		_cancel_pnr()
		_decide()
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
	# A DEFENDER never steps inside a small side area: that is the pivot's
	# floor and the referee whistles anybody who camps there (rule 5). Keeping
	# the AI out also lets a carrier deliver the ball, which is the whole
	# point of the rule.
	if not court.one_on_one and p.team != court.possession and not p.has_ball:
		for hh in court.side_hoops:
			if p.global_position.distance_to(hh) < Court.SIDE_AREA_R + 6.0:
				var back: Vector2 = hh + Vector2(0.0, -signf(hh.y)) * (Court.SIDE_AREA_R + 30.0) - p.global_position
				p.move_input = back.normalized()
				p.stance = true
				return
	# Rule 5: roles 3-5 may only step into a small side area to hand the ball
	# in. Everybody else walks straight back out (and the referee does whistle).
	if p.role > 2 and not court.one_on_one and not p.has_ball:
		for hh in court.side_hoops:
			if p.global_position.distance_to(hh) < Court.SIDE_AREA_R - 4.0:
				var out_dir: Vector2 = hh + Vector2(0.0, -signf(hh.y)) * (Court.SIDE_AREA_R + 30.0) - p.global_position
				p.move_input = out_dir.normalized()
				p.stance = false
				return
	if p.role <= 2 and not court.one_on_one and state != S.ATK_ON:
		_pivot_hold(delta)
		return
	match state:
		S.ATK_ON: _attack_on_ball(delta)
		S.ATK_OFF: _attack_off_ball(delta)
		S.DEF_ON: _defend_on_ball(delta)
		S.DEF_OFF: _defend_off_ball(delta)
		S.REBOUND: _rebound(delta)
		_: p.move_input = Vector2.ZERO
	# The pivots live in their own area and are never guarded: spacing must not
	# shove them off their spot (it reset the plant and the shot never left).
	if p.role > 2:
		_apply_spacing()

func _apply_spacing() -> void:
	# Keep five-a-side from collapsing into a huddle.
	if court == null or p == null:
		return
	if p.has_ball:
		return   # the handler picks his own road to the rim
	var push := Vector2.ZERO
	for o in court.players:
		if o == p:
			continue
		# A carrier walking in to hand the ball over must not be shoved off the
		# pivot (the referee would whistle HIM for the entry, not the pivot).
		if role == "deliver" and o.role <= 2:
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
		if m.team != p.team or m == p or m.entering or m.leaving:
			continue
		if not court.pass_allowed(p, m, false):
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
		if m.role <= 2 and m.period_makes < 3 and not court.one_on_one \
		and court.in_side_area(p.global_position) and randf() < 0.5:
			v = maxf(v, 0.72)              # hand it over — only from inside
		if my_pressure > 0.68 and open_m > (1.0 - my_pressure) + 0.22:
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
		if m.team != p.team or m == p or m.role <= 2 or m.is_user or m.entering or m.leaving:
			continue
		var d: float = m.global_position.distance_to(p.global_position)
		if d < bd:
			for c in m.get_children():
				if c is AIBrain and c.pnr_t <= 0.0:
					bd = d
					best = c
	return best

# ------------------------------------------------------------------ offense
func _attack_on_ball(delta: float) -> void:
	var hoop: Vector2 = court.attack_hoop_for(p)
	if p.role <= 2 and not court.one_on_one:
		_pivot_attack(delta, hoop)
		return
	var to_hoop: Vector2 = hoop - p.global_position
	var dist_ft: float = court.px_to_ft(to_hoop.length())
	var pressure: float = court.pressure_on(p)
	if court.one_on_one and court.must_clear:
		p.move_input = (p.global_position - hoop).normalized()
		return
	if court.has_method("behind_hoop") and court.behind_hoop(p):
		p.move_input = (Vector2.ZERO - p.global_position).normalized()
		return
	if p.role <= 2 and dist_ft > 26.0 and not court.one_on_one:
		var mate0: BallPlayer = court.best_pass_option(p)
		if mate0 != null:
			p.do_pass(mate0)
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
	if role == "deliver" and not court.one_on_one:
		var piv := _pivot_mate()
		if piv == null or piv.period_makes >= 3 or used_clock() > 19.0 or court.shot_clock < 6.0:
			# A delivery that is running out of clock is abandoned: the referee
			# would whistle a violation with the ball still in the carrier's
			# hands.
			if piv != null and used_clock() > 15.0:
				court.note_delivery_failed(p.team)
			role = "drive"
			spot = Vector2.ZERO
		elif court.in_side_area(p.global_position) and p.global_position.distance_to(piv.global_position) < 150.0:
			p.do_pass(piv)
			shot_cd = 0.6
			spot = Vector2.ZERO
			return
		else:
			# Stand BESIDE the pivot, never on him: walking onto his spot made
			# the spacing shove the carrier back out of the area and the
			# hand-off never happened.
			spot = _deliver_spot(piv)
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
	# ---- read the floor and CALL A PLAY -------------------------------------
	# The handler weighs the four things a baskin offence actually does:
	# carry the ball to the pivot, attack the rim (and slam it), take the open
	# shot, or swing it to a free team-mate. Nothing is scripted: each play is
	# re-read when the last one finishes or after a few seconds of nothing.
	play_age += delta
	# A delivery is a trip across the floor, not a spot-up: it gets its own
	# clock, otherwise the carrier re-picks his play mid-walk and the ball
	# never reaches the small area (that is why hand-offs came out at four a
	# match). It still expires if it drags on.
	if spot.length() < 1.0 or (play_age > 7.0 and role != "deliver") or play_age > 15.0:
		if role == "deliver" and play_age > 15.0 and not court.in_side_area(p.global_position):
			court.note_delivery_failed(p.team)
		play_age = 0.0
		spot = Vector2.ZERO
		_pick_play(hoop)
	var used: float = 24.0 - court.shot_clock
	var at_spot: bool = p.global_position.distance_to(spot) < 48.0
	var clock_death: bool = court.shot_clock < 5.5 or (p.role <= 2 and p.pivot_clock > 0.0 and p.pivot_clock < 3.5)
	var can_fire: bool = p.cooldown_move <= 0.0 and shot_cd <= 0.0 and not (court.has_method("behind_hoop") and court.behind_hoop(p))
	# Buzzer beater: the 24-second clock overrides move cooldowns so the AI
	# always gets the heave away instead of taking a violation.
	if clock_death and shot_cd <= 0.0 and not (court.has_method("behind_hoop") and court.behind_hoop(p)):
		can_fire = true
	# Finish at the rim FIRST, independent of the jumper's cooldowns: a drive
	# that arrives at the iron with legs underneath it goes up and slams. This
	# used to sit behind `can_fire`, so a handler who reached the rim mid-move
	# simply never pulled the trigger and the slam never happened.
	if dist_ft < 7.0 and p.can_dunk() \
	and not (court.has_method("behind_hoop") and court.behind_hoop(p)) \
	and (role == "drive" or used > 4.0 or pressure < 0.75):
		p.do_dunk()
		shot_cd = 1.6
		spot = Vector2.ZERO
		return
	if can_fire:
		var pull: bool = false
		if clock_death:
			# Buzzer: heave it from anywhere inside 42 ft instead of eating a
			# shot-clock violation (the old 30 ft cap left handlers stranded
			# past the arc with the clock dying).
			pull = dist_ft < 42.0
		elif role == "three" and at_spot and dist_ft > 20.5 and dist_ft < 28.0 and pressure < lerpf(0.74, 0.56, skill):
			pull = true
		elif role == "mid" and at_spot and dist_ft > 9.0 and dist_ft < 21.0 and pressure < lerpf(0.60, 0.44, skill):
			pull = true
		elif role == "side" and at_spot and pressure < 0.60:
			pull = true
		elif role == "drive":
			# A drive finishes AT THE RIM. The old generic rule below fired on
			# him at 26 ft, so every drive ended as a deep jumper and a role-5
			# driver never got close enough to dunk.
			if dist_ft < 8.5 and used > 4.0:
				pull = true       # at the iron: layup or slam
			elif dist_ft < 11.5 and pressure > 0.42 and used > 3.0:
				pull = true       # body on him: pull up short instead of
				                  # wrestling for the whole shot clock
			elif used >= 12.0:
				pull = true       # the drive stalled: get something up
		elif used >= 9.0 and dist_ft < 25.0 and pressure < 0.65:
			pull = true
		if pull and court.baskin_ai_may_shoot(p, hoop):
			# Release quality follows the rating of the shot being taken: a
			# sharpshooter's threes and a finisher's mid-rangers both gather
			# cleanly; weaker hands miss the window more often.
			var skill_key: String = "three" if dist_ft > ShotSystem.THREE_FT else "mid"
			var err: float = randfn(0.0, lerpf(0.13, 0.028,
				clampf(float(p.ratings[skill_key]) / 99.0 * (0.65 + skill * 0.5), 0.0, 1.0)))
			# TELEGRAPHED gather instead of an instant release, so a watching
			# defender can close out and the shot can be read and blocked.
			p.begin_ai_shot(err, clampf(0.42 + dist_ft * 0.011, 0.42, 0.8))
			shot_cd = 1.5
			spot = Vector2.ZERO
			return
		if pull and not court.baskin_ai_may_shoot(p, hoop):
			if court.shot_must_clear_area(p, hoop):
				p.move_input = (p.global_position - hoop).normalized()
				return
			if p.role == 4 or (p.role == 3 and p.velocity.length() > 130.0):
				p.move_input = Vector2.ZERO   # plant the stop, shoot next read
				return
			if (p.role == 5 and p.period_shots >= 3) or (p.role <= 4 and p.period_makes >= 3):
				var mate2: BallPlayer = court.best_pass_option(p)
				if mate2 != null:
					p.do_pass(mate2)
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
			if role == "drive" and ndist < 72.0 and pressure > 0.30 and randf() < 0.22:
				# Only to beat a body that is actually in the way: the AI used
				# to spam crossovers at 112 px, so a drive spent its whole life
				# inside a move animation and crawled up the floor.
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
	var dir: Vector2 = ((tgt - p.global_position).normalized() - lane * 0.40)
	if dir.length() < 0.05:
		dir = tgt - p.global_position
	p.move_input = dir.normalized() if p.global_position.distance_to(tgt) > 22.0 else Vector2.ZERO

func _attack_off_ball(delta: float) -> void:
	cut_t -= delta
	if not court.one_on_one and court.tutor_of(p.team) == p:
		for m in court.players:
			if m.team == p.team and m.variant == "2T" and m.has_ball:
				var tt: Vector2 = m.global_position + Vector2(64.0, 44.0)
				var dd := tt - p.global_position
				p.move_input = dd.normalized() if dd.length() > 16.0 else Vector2.ZERO
				return
	var hoop: Vector2 = court.attack_hoop_for(p)
	if cut_t <= 0.0:
		cut_t = randf_range(2.2, 4.6)
		var pick: String = ["spot", "spot", "cutter", "screener"].pick_random()
		if p.role <= 2:
			pick = "spot"   # the pivot lives at his side basket
		elif pick == "cutter" and not court.claim_cutter(p, cut_t):
			pick = "spot"   # somebody is already going to the rim
		role = pick
		spot = court.random_offensive_spot(p.team, p)
	var target := spot
	match role:
		"cutter":
			# Backdoor cut when my defender is ball-watching — attack the RIM
			# side of the iron, never the baseline behind it.
			target = hoop - Vector2(signf(hoop.x) * 55.0, 0.0) \
				+ Vector2(randf_range(-40, 40), randf_range(-55, 55))
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
	var own_hoop: Vector2 = court.attack_hoop_for(bh)
	var gathering: bool = bh.has_method("is_gathering") and bh.is_gathering()
	var d0: float = p.global_position.distance_to(bh.global_position)
	# --- pump fake: sell out and bite. Aggressive, slow-footed defenders bite
	# harder; lockdown feet stay grounded and contest for real.
	if bh.fake_t > 0.0:
		if not _fake_seen and d0 < 135.0:
			_fake_seen = true
			var bite_ch: float = (0.30 + aggression * 0.55) * (1.25 - float(p.ratings["defense"]) / 150.0)
			if randf() < bite_ch:
				p.do_jump(true, 120.0)
				p.bite_recovery = 0.55
				if bh.is_user:
					Events.toast.emit("Defender bit the fake!")
	else:
		_fake_seen = false
	# sit between the handler and the basket; close out SHORT as he gathers,
	# but only hug him inside the arc -- a perimeter shooter is contested from
	# a step away instead of being handed a free 24 % contact trip.
	var shooter_range: float = bh.global_position.distance_to(court.hoop_for(bh.team))
	var gap: float = lerpf(78.0, 58.0, skill)
	# A ROLE 5 must not walk to the rim: he is the strongest attacker on the
	# floor, so the man on him sits closer and the help collapses (a role 5
	# driving through five defenders is what made penetration too easy).
	var big5: bool = bh.role == 5
	if big5:
		gap = lerpf(58.0, 40.0, skill)
		if shooter_range < 330.0:
			gap -= 8.0
	# Facile sta un passo piu' larga, Forte un passo piu' addosso.
	gap += lerpf(9.0, -4.0, float(diff) / 2.0)
	if gathering:
		# Close-out reale: dentro l'arco si sta addosso, fuori un passo.
		gap = lerpf(56.0, 42.0, skill) if shooter_range < 220.0 else lerpf(84.0, 66.0, skill)
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
	# --- timed jump to contest the release (or meet a dunker at the rim)
	if gathering and not _jumped_gather and not p.jumping and not p.hanging:
		var prog: float = bh.gather_progress()
		var at_rim: bool = bh.dunking or bh.hanging
		var want := false
		if at_rim and d0 < 120.0:
			want = true
		elif d0 < 110.0 and shooter_range < 560.0:
			# Jump LATE and only part of the time: an early commit is exactly
			# what a pump fake punishes, and a clean contest is not a clean
			# block. Better defenders time and commit more reliably.
			var threshold: float = lerpf(0.50, 0.38, skill) if shooter_range < 220.0 else lerpf(0.62, 0.50, skill)
			# Salta piu' spesso con skill alta: il finto perde morsi ma il
			# tiratore libero non esiste piu' ai livelli alti.
			var commit: float = clampf(lerpf(0.30, 0.78,
				clampf(float(p.ratings["defense"]) / 99.0 * (0.6 + skill * 0.6), 0.0, 1.0)) * d_commit, 0.0, 1.0)
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
	var steal_ch: float = (0.006 + aggression * 0.010) * lerpf(0.7, 1.5, skill) * d_steal
	if big5:
		steal_ch *= 1.8      # hands on the ball against a role-5 drive
	if d0 < 46.0 and randf() < steal_ch:
		p.try_steal()
		return
	# CONTACT FOULS. A defender who keeps his hands on a man going at the rim
	# gets whistled: the opponent fouls YOU too, and you go to the line. Rate
	# small and spaced out (foul_cd) so a quarter is not a parade to the line,
	# and scaled by the difficulty the user picked.
	foul_cd = maxf(0.0, foul_cd - delta)
	if foul_cd <= 0.0 and d0 < 64.0 and not bh.hanging and not bh.jumping:
		var contact: bool = bh.velocity.length() > 160.0 or bh.shot_charge >= 0.0 \
			or bh.dunking or bh.move_t > 0.0
		if contact and randf() < (0.04 + aggression * 0.05) * d_foul * delta:
			foul_cd = 7.0
			court.call_foul(p, bh)
			return

func _defend_off_ball(delta: float) -> void:
	if mark == null:
		mark = court.man_mark_for(p)
		if mark == null:
			# BASKIN help: no legal mark, so shade between ball and own hoop.
			var hh: Vector2 = court.hoop_for(1 - p.team)
			var bp2: Vector2 = court.ball.global_position
			var help2: Vector2 = hh.lerp(bp2, 0.35)
			var d2 := help2 - p.global_position
			p.move_input = d2.normalized() if d2.length() > 14.0 else Vector2.ZERO
			p.stance = true
			return
	var own_hoop: Vector2 = court.attack_hoop_for(mark)
	var ball_pos: Vector2 = court.ball.global_position
	# deny line: one third toward the ball, two thirds on the man
	var cutting: bool = mark.move_t > 0.0 or mark.velocity.length() > 140.0
	var deny_k: float = 0.32 if cutting else 0.22   # sul taglio si sta sul linea
	var help: Vector2 = mark.global_position.lerp(own_hoop, deny_k)
	help = help.lerp(ball_pos, 0.20)
	# HELP ON THE DRIVE: a role-5 attacker going at the rim drags the nearest
	# off-ball defenders into the paint, so the lane closes.
	var bh2: BallPlayer = court.ball_handler()
	if bh2 != null and bh2.team != p.team:
		# SENSIBLE HELP: only for a real threat at the rim (a big man, a driver,
		# a finish in progress) and only if my OWN man is near enough that
		# leaving him is not a gift. A helper who abandons a shooter 8 m out to
		# babysit the iron gives up open jumpers for nothing.
		var hoop2: Vector2 = court.hoop_for(bh2.team)
		var to_rim: float = bh2.global_position.distance_to(hoop2)
		var threat: bool = bh2.role >= 4 or bh2.dunking or bh2.hanging \
			or bh2.velocity.length() > 170.0 or bh2.shot_charge >= 0.0
		var my_man_d: float = mark.global_position.distance_to(hoop2)
		var own_gate: float = clampf((430.0 - my_man_d) / 240.0, 0.0, 1.0)
		if threat and to_rim < 300.0 and own_gate > 0.0:
			var sag: Vector2 = hoop2.lerp(bh2.global_position, 0.42)
			var k: float = clampf((300.0 - to_rim) / 300.0, 0.0, 0.62) * own_gate * d_help
			help = help.lerp(sag, clampf(k, 0.0, 0.70))
	var d := help - p.global_position
	p.move_input = d.normalized() if d.length() > 14.0 else Vector2.ZERO
	p.stance = d.length() < 70.0

func _rebound(delta: float) -> void:
	var ball: Ball = court.ball
	# Dove arrivera' DAVVERO (previsione fisica condivisa). Se la palla e'
	# ancora alta la previsione e' quella che conta: e' la differenza fra
	# anticipare un rimbalzo e rincorrerlo.
	var land: Vector2 = ball.global_position + ball.vel * 0.38
	var pred: Vector2 = ball.landing_spot()
	if pred.is_finite():
		land = pred
	# RIMBALZO GIOCATO: sul ferro ci vanno i DUE piu' vicini al punto di
	# caduta della mia squadra. Gli altri tengono il proprio uomo (difesa) o
	# la propria posizione (attacco): correre in cinque dietro alla palla e'
	# quello che fa sembrare il rimbalzo una rissa da cortile.
	var mine: int = 0
	for m in court.players:
		if m.team != p.team or m == p or not is_instance_valid(m):
			continue
		if m.global_position.distance_to(land) < p.global_position.distance_to(land):
			mine += 1
	if mine >= 2:
		if p.team != court.possession:
			_defend_off_ball(delta)
		else:
			_attack_off_ball(delta)
		return
	# BASKIN: around the pivot's basket only the pivot may enter the area.
	# Everyone else crashes the board from OUTSIDE the semicircle.
	if not court.one_on_one and p.role > 2:
		for hh in court.side_hoops:
			if land.distance_to(hh) < Court.SIDE_AREA_R + 46.0:
				var outp: Vector2 = land - hh
				if outp.length() < 0.1:
					outp = Vector2(0.0, -signf(hh.y))
				land = hh + outp.normalized() * (Court.SIDE_AREA_R + 26.0)
				break
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

# ------------------------------------------------------------------ baskin pivot
func _pivot_hold(_delta: float) -> void:
	## Both pivots live inside their own small side area and wait for the
	## delivery: no cuts, no screens, no rebound crashes — but a loose ball
	## in THEIR area is theirs to recover (baskin: the pivot's ball).
	var home: Vector2 = court.pivot_home(p.team)
	var ball: Ball = court.ball
	var bd: float = ball.global_position.distance_to(court.side_hoops[p.team])
	if ball.holder == null and bd < Court.SIDE_AREA_R:
		var d0: Vector2 = ball.global_position - p.global_position
		p.move_input = d0.normalized() if d0.length() > 24.0 else Vector2.ZERO
		p.stance = false
		if d0.length() < 78.0:
			court.try_grab(p)
		return
	var d: Vector2 = home - p.global_position
	p.move_input = d.normalized() if d.length() > 30.0 else Vector2.ZERO
	var bx: float = ball.global_position.x - p.global_position.x
	if absf(bx) > 4.0:
		p.facing = signf(bx)
	p.stance = false
	if ball.holder == null and p.global_position.distance_to(ball.global_position) < 70.0:
		court.try_grab(p)

func _pivot_attack(delta: float, hoop: Vector2) -> void:
	## With the ball the pivot walks to his shooting spot, PLANTS — the stop
	## before the shot is compulsory in baskin — and only then rises. Nobody
	## releases on the catch any more.
	if p.own_miss_rebound:
		# His own rebound: the rule says pass it out to the rebounders.
		var out_m: BallPlayer = court.best_pass_option(p)
		p.move_input = Vector2.ZERO
		if out_m != null and shot_cd <= 0.0:
			p.do_pass(out_m)
			shot_cd = 0.8
		return
	var spot: Vector2 = court.pivot_shot_spot(p.team, p)
	var d: Vector2 = spot - p.global_position
	# A role-2 pivot shoots from BEHIND the line: if he is still inside the
	# area he keeps stepping out. Without this he planted inside, the shot was
	# refused as illegal and the possession died on the shot clock.
	if p.role == 2 and court.in_side_area(p.global_position):
		p.move_input = d.normalized() if d.length() > 10.0 else Vector2.ZERO
		settle_t = 0.0
		settled = false
		hold_wo_shot = 0.0
		return
	if d.length() > 64.0:
		p.move_input = d.normalized()
		settle_t = 0.0
		settled = false
		hold_wo_shot = 0.0
		return
	# Inside the arrival ring: ease onto the spot instead of freezing a step
	# short of it (the old code zeroed the input on the very next line, so he
	# could never close the last 26 px).
	p.move_input = Vector2.ZERO if d.length() <= 20.0 else d.normalized() * 0.6
	var bx: float = hoop.x - p.global_position.x
	if absf(bx) > 6.0:
		p.facing = signf(bx)
	p.stance = false
	if not settled:
		if settle_t <= 0.0:
			settle_t = randf_range(1.15, 1.9)
			if p.pivot_clock > 0.0 and p.pivot_clock < 4.5:
				settle_t = minf(settle_t, 0.55)
			p.fake_t = 0.30
		settle_t -= delta
		if p.pivot_clock > 0.0 and p.pivot_clock < 0.7:
			settle_t = 0.0            # the clock beats the routine
		if settle_t > 0.0:
			return
		settled = true
	if shot_cd <= 0.0:
		if court.baskin_ai_may_shoot(p, hoop):
			p.begin_ai_shot(randfn(0.0, 0.05), 0.6)
			shot_cd = 2.2
			settled = false
			hold_wo_shot = 0.0
		else:
			# He is standing on his spot with the ball and cannot shoot (role
			# ceiling, clock, area line): give it up rather than eat a whistle.
			hold_wo_shot += delta
			var low_clock: bool = p.pivot_clock > 0.0 and p.pivot_clock < 3.0
			if low_clock or hold_wo_shot > 2.5:
				var mate: BallPlayer = court.best_pass_option(p)
				if mate != null:
					p.do_pass(mate)
					shot_cd = 1.0
					settled = false
					hold_wo_shot = 0.0
	else:
		hold_wo_shot = 0.0

## Where a team-mate stands to hand the ball to the pivot: just beside him,
## still INSIDE the small side area (so the delivery is legal) with a step
## clear of his body.
func _deliver_spot(piv: BallPlayer) -> Vector2:
	var h: Vector2 = court.side_hoops[p.team]
	var n: Vector2 = h - court.pivot_home(p.team)          # inward normal
	n = n.normalized() if n.length() > 0.1 else Vector2(0.0, -signf(h.y))
	var tangent := Vector2(-n.y, n.x)
	if delivery_side == 0.0:
		delivery_side = 1.0 if (p.global_position - piv.global_position).dot(tangent) >= 0.0 else -1.0
	var side: Vector2 = tangent * 68.0 * delivery_side
	return piv.global_position + side - n * 16.0

## The handler's read. Weights, not a lottery: the pivot's claim grows the
## longer the team ignores him, a clean lane to the iron and a live shot clock
## push toward the rim, an open look pushes toward the jumper, and a genuinely
## free team-mate opens the pass.
func _pick_play(hoop: Vector2) -> void:
	## A possession is a DECISION, not a dice roll. Every option is priced by
	## what it is really worth — the chance of it working times the points it
	## brings — with what this ROLE is allowed to do and what the defence is
	## giving him. A little noise keeps two possessions from looking alike.
	var pressure: float = court.pressure_on(p)
	var room: float = 1.0 - pressure
	var dist_ft: float = court.px_to_ft(p.global_position.distance_to(hoop))
	var ev := {}
	# 1) SHOOT: the quality of THIS shot for THIS player, worth what a make at
	# THIS hoop pays his role (a role 3 scores 3 at the classic rim, 2 at the
	# side one; role 5 over the arc = 3).
	if dist_ft < 31.0 and court.baskin_ai_shoot_allowed(p, hoop):
		var q: float = _shot_quality(dist_ft, pressure)
		var pts: float = float(court.baskin_points_for(p, hoop))
		ev["shoot"] = q * pts * 1.12 - 0.12
		# A role 5 has three shots a period: he must not burn one from deep.
		if p.role == 5 and dist_ft > 24.0:
			ev["shoot"] = float(ev["shoot"]) - 0.35
		# A role 4 needs the full stop, which a contest takes away.
		if p.role == 4 and pressure > 0.55:
			ev["shoot"] = float(ev["shoot"]) - 0.30
	# 2) DRIVE: going at the rim. Room decides everything — a drive into a
	# chest is a turnover, and a role 3 cannot finish with a third tempo.
	var drive_ev: float = room * 0.95 + clampf(1.0 - dist_ft / 34.0, 0.0, 1.0) * 0.45
	if p.role == 4:
		drive_ev *= 0.78
	if p.role == 3:
		drive_ev *= 0.72
	if p.can_dunk():
		drive_ev += 0.55
	if room < 0.30:
		drive_ev -= 1.0
	ev["drive"] = maxf(drive_ev, 0.0)
	# 3) DELIVER: the pivot is the reason a baskin offence exists. Priced at
	# what HIS shot is worth, and it climbs while the team ignores him.
	var piv: BallPlayer = _pivot_mate()
	if piv != null and piv.period_makes < 3:
		var urge: float = court.pivot_feed_urge(p.team)
		var pv: float = 2.6 if piv.role == 2 else 2.3
		ev["deliver"] = (0.50 + urge * 1.20) * (1.0 - court.pressure_on(piv) * 0.45) * (pv / 2.6)
	# 4) SWING IT: a team-mate who is genuinely open — never the man who just
	# gave it to us (that is the ping-pong the old weights produced).
	var mate: BallPlayer = _best_feed(pressure)
	if mate != null and (Time.get_ticks_msec() / 1000.0 - court.last_pass_time) > 1.2:
		ev["pass"] = 0.28 + (1.0 - court.pressure_on(mate)) * 0.42
	# 5) THE CLOCK: with the possession dying the best available shot wins.
	if court.shot_clock < 6.5 or used_clock() > 17.0:
		ev["shoot"] = float(ev.get("shoot", 0.0)) + 1.6
		ev["drive"] = float(ev.get("drive", 0.0)) + 0.9
		ev["deliver"] = float(ev.get("deliver", 0.0)) * 0.30
		ev["pass"] = float(ev.get("pass", 0.0)) * 0.25
	var total := 0.0
	var best := ""
	for k in ev:
		# La lettura e' piu' o meno precisa a seconda della difficolta': a
		# "Facile" il computer sbaglia le scelte, a "Forte" quasi mai.
		var v: float = maxf(float(ev[k]) * randf_range(1.0 - d_noise, 1.0 + d_noise), 0.0)
		ev[k] = v
		total += v
		if v > float(ev.get(best, -1.0)) or best == "":
			best = k
	if total <= 0.0:
		_begin_play("drive", hoop)
		return
	var roll: float = randf() * total
	for k in ev:
		roll -= float(ev[k])
		if roll <= 0.0:
			_begin_play(k, hoop)
			return
	_begin_play(best, hoop)

## Crude make-% for this player from here, contested: the same rating curve the
## shot system uses, squeezed by the man in his face and by the distance.
func _shot_quality(dist_ft: float, pressure: float) -> float:
	var r: float = ShotSystem.rating_for_distance(
		float(p.ratings.get("close", 50)), float(p.ratings.get("mid", 50)),
		float(p.ratings.get("three", 50)), dist_ft)
	var q: float = clampf((r - 28.0) / 62.0, 0.08, 0.90)
	q *= lerpf(1.0, 0.52, clampf(pressure, 0.0, 1.0))
	q *= lerpf(1.0, 0.70, clampf(dist_ft / 32.0, 0.0, 1.0))
	return clampf(q, 0.04, 0.90)

func used_clock() -> float:
	return 24.0 - court.shot_clock

func _begin_play(kind: String, hoop: Vector2) -> void:
	var side: float = signf(hoop.x)
	if side == 0.0:
		side = 1.0
	match kind:
		"deliver":
			var piv2: BallPlayer = _pivot_mate()
			if piv2 == null or piv2.period_makes >= 3:
				_begin_play("drive", hoop)
				return
			role = "deliver"
			delivery_side = 0.0
			spot = _deliver_spot(piv2)
		"pass":
			var mate: BallPlayer = _best_feed(court.pressure_on(p))
			role = "spot"
			spot = Vector2.ZERO
			if mate != null:
				p.do_pass(mate)
				shot_cd = 0.6
		"shoot":
			role = "three"
			if dist_ft_to(hoop) < 16.0:
				role = "mid"
				spot = hoop + Vector2(-side * randf_range(210.0, 320.0), randf_range(-170.0, 170.0))
			elif dist_ft_to(hoop) < 26.0:
				spot = hoop + Vector2(-side * randf_range(180.0, 260.0), randf_range(-210.0, 210.0))
			else:
				spot = hoop + Vector2(-side * 430.0, randf_range(-330.0, 330.0))
		_:
			role = "drive"
			# Finish ON the iron: a driver who stops two steps short settles
			# for a floater (and a role-5 driver never gets his slam).
			spot = hoop + Vector2(-side * randf_range(28.0, 58.0), randf_range(-45.0, 45.0))

func dist_ft_to(t: Vector2) -> float:
	return court.px_to_ft(p.global_position.distance_to(t))

func _pivot_mate() -> BallPlayer:
	for m in court.players:
		if m.team == p.team and m.role <= 2:
			return m
	return null
