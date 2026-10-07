extends Node2D
## DEV ONLY. Batch 6 checks: role-matched defence, throw-in pass into the hands,
## "L" only while the DEFEND button is held, the pivot behind the side basket,
## the change of ends at half time, the tighter defence on a role-5 driver, the
## defensive set on a throw-in and the dust thud after a slam.
##   godot --headless --path . res://tools/Rule6Probe.tscn
var court: Node2D
var fails := 0

func check(nm: String, cond: bool) -> void:
	print(("  ok: " if cond else "  FAIL: ") + nm)
	if not cond:
		fails += 1

func _clean() -> void:
	court.play_live = true
	court.restarting = false
	court.ft_active = false
	court.inbound_wait = 0.0
	court.jump_pending = false
	court.awaiting_check = false

func _role(team: int, r: int) -> BallPlayer:
	for p in court.players:
		if p.team == team and p.role == r:
			return p
	return null

func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["baskin_role"] = 5
	court = preload("res://src/match/Court.gd").new()
	add_child(court)
	await get_tree().process_frame
	await get_tree().create_timer(8.0).timeout
	var u: BallPlayer = court.user

	# ---------------------------------------------------------- 1. role-matched defence
	court._assign_man(1, Time.get_ticks_msec())
	var matched := true
	var pairs := ""
	var unpaired := 0
	var marks := 0
	for did in court._man_marks:
		var dd: BallPlayer = null
		var oo: BallPlayer = null
		for p in court.players:
			if p.get_instance_id() == did:
				dd = p
			if p.get_instance_id() == int(court._man_marks[did]):
				oo = p
		marks += 1
		if dd != null and oo != null:
			pairs += "%d->%d " % [dd.role, oo.role]
			if dd.role != oo.role:
				matched = false
		else:
			unpaired += 1
	print("   assignments: ", pairs, " (", marks, " marks)")
	check("every defender takes his OWN role", matched and unpaired == 0)
	# Every defender on the floor holds a mark: nobody is left free to roam.
	var defenders := 0
	var marked := 0
	for p in court.players:
		if p.team == 1 and p.role > 2:      # the pivots play their own area
			defenders += 1
			if court._man_marks.has(p.get_instance_id()):
				marked += 1
	print("   ", marked, "/", defenders, " defenders have a man")
	check("nobody defends nobody", marked == defenders)

	# ------------------------------------------------- 2. the pass, magnet & direct
	_clean()
	for p in court.players:
		p.global_position = Vector2(-700.0, 320.0 if p.team == 0 else -320.0)
		p.velocity = Vector2.ZERO
	var a: BallPlayer = _role(0, 4)
	var b: BallPlayer = _role(0, 5)
	a.global_position = Vector2(-260.0, 180.0)
	b.global_position = Vector2(180.0, 180.0)
	court.give_ball(a)
	for p in court.players:
		if p != a:
			p.has_ball = false
	var b_at_pass: Vector2 = b.global_position
	var flew2 := false
	var min_h := 999.0
	var near_hand := 9999.0
	var rev := 0
	var stall := 0
	var dir_prev := Vector2.ZERO
	var prev: Vector2 = court.ball.global_position
	a.do_pass(b)
	var t := 0.0
	while t < 3.0 and not b.has_ball:
		await get_tree().process_frame
		var d := get_process_delta_time()
		t += d
		b.move_input = Vector2(0.0, -1.0)          # he keeps running away
		if court.ball.holder == null and court.ball.live:
			flew2 = true
			min_h = minf(min_h, court.ball.h)
			near_hand = minf(near_hand, b.ball_anchor().distance_to(court.ball.global_position))
			var step: Vector2 = court.ball.global_position - prev
			if step.length() > 0.5:
				var dir := step.normalized()
				if dir_prev != Vector2.ZERO and dir.dot(dir_prev) < -0.5:
					rev += 1
					print("      reversal at t=%.2f ball=%s" % [t, str(court.ball.global_position.round())])
				dir_prev = dir
			elif t > 0.15:
				stall += 1
			prev = court.ball.global_position
	print("   flight %.2f s -- in the air: %s, lowest point %.0f px, closest to the hands %.0f px"
		% [t, str(flew2), min_h, near_hand])
	print("   reversals: %d, frames parked mid-flight: %d" % [rev, stall])
	check("the pass is really thrown (the ball leaves his hands)", flew2)
	check("the pass is caught in the receiver's hands",
		b.has_ball and court.ball.holder == b)
	check("MAGNET: the ball is taken AT the hands (within the 46 px snap), never on the floor",
		near_hand < 40.0 and min_h > 30.0)
	check("FLUID: the ball never doubles back and never hovers", rev <= 1 and stall == 0)
	var lead: float = (b.global_position - b_at_pass).dot(Vector2(0.0, -1.0))
	print("   the receiver ran %.0f px and the ball met him there (ball at %s)"
		% [lead, str(court.ball.global_position.round())])
	# "Trova l'uomo in corsa": basta il distacco (ha corso davvero) piu' il
	# fatto che la palla gli sia arrivata ADDOSSO (near_hand, misurato durante
	# il volo). Non si confronta piu' l'ancora a cattura avvenuta: li' il
	# ricevitore puo' essere gia' girato verso chi ha passato e l'ancora e' un
	#'altra, il che faceva fallire il test a caso.
	check("DIRECT: it finds him on the run (he moved, the ball still caught up)",
		lead > 40.0 and near_hand < 40.0)

	# ---------------------------------------------------------- 3. inbound from the baseline
	_clean()
	court.possession = 0
	court._inbound(0, Vector2.ZERO)            # classic (baseline) throw-in
	await get_tree().create_timer(0.3).timeout
	check("baseline throw-in: the ball rests in the thrower's hands", court.ball.held_still and court.ball.holder != null)
	var moved := 0.0
	var p0: Vector2 = court.ball.global_position
	t = 0.0
	while t < 0.2:
		await get_tree().process_frame
		t += get_process_delta_time()
		moved = maxf(moved, (court.ball.global_position - p0).length())
	check("baseline throw-in: no bounce (still ball)", moved < 26.0)
	var flew := false
	t = 0.0
	while t < 3.5 and not flew:
		await get_tree().process_frame
		t += get_process_delta_time()
		if court.ball.live and court.ball.holder == null:
			flew = true
	check("baseline throw-in: the pass is seen in flight", flew)

	# ---------------------------------------------------------- 4. L only while DEFEND is held
	_clean()
	court.give_ball(_role(1, 4))
	court.shot_clock = 20.0
	court._ill_whistle_cd = 0.0
	u.guarding = false
	u.stance = true
	var opp3: BallPlayer = _role(1, 3)
	t = 0.0
	while t < 2.5:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		court.shot_clock = 20.0
		if court.ball_handler() == null or court.ball_handler().team == u.team:
			court.give_ball(_role(1, 4))
		u.global_position = opp3.global_position + Vector2(22.0, 0.0)   # right on him!
	check("walking into a role 3 without DEFEND is legal", u.fouls == 0)
	u.guarding = true
	t = 0.0
	while t < 5.0 and u.fouls == 0:
		await get_tree().process_frame      # il contatto va tenuto (dwell 0.30 s)
		t += get_process_delta_time()
		court.shot_clock = 20.0
		court._ill_whistle_cd = 0.0
		u.guarding = true
		if court.ball_handler() == null or court.ball_handler().team == u.team:
			court.give_ball(_role(1, 4))
		u.global_position = opp3.global_position + Vector2(22.0, 0.0)
		u.move_input = (opp3.global_position - u.global_position).normalized()
	print("   whistled after %.1f s of holding DEFEND" % t)
	check("holding DEFEND is the L foul", u.fouls > 0)
	t = 0.0
	while t < 25.0 and court.ft_active:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	u.guarding = false
	u.move_input = Vector2.ZERO

	# ---------------------------------------------------------- 5. pivot behind the basket
	var home0: Vector2 = court.pivot_home(0)
	var home1: Vector2 = court.pivot_home(1)
	check("pivot (top area) stands BEHIND the rim, next to the sideline",
		home0.y > court.side_hoops[0].y and home0.distance_to(court.side_hoops[0]) < 40.0)
	check("pivot (bottom area) stands BEHIND the rim",
		home1.y < court.side_hoops[1].y and home1.distance_to(court.side_hoops[1]) < 40.0)
	check("his shooting spot is still outside the area (role 2)",
		court.pivot_shot_spot(1, _role(1, 2)).distance_to(court.side_hoops[1]) > Court.SIDE_AREA_R)

	# ---------------------------------------------------------- 6. change of ends
	_clean()
	var before3: Vector2 = court.attack_hoop_for(_role(0, 3))
	check("not switched yet", not court._ends_swapped)
	court.quarter = 2
	court.game_clock = 0.0
	court._end_quarter()
	await get_tree().create_timer(0.2).timeout
	check("half time switches the ends", court._ends_swapped and court.quarter == 3)
	check("the classic basket is now the other one",
		court.attack_hoop_for(_role(0, 3)).distance_to(before3) > 100.0)
	check("the side baskets switched too",
		court.side_hoops[0].y > court.side_hoops[1].y)
	check("the own-area moors switched with them",
		signf(court.pivot_home(0).y) == -signf(home0.y))
	# ...and the match simply carries on into Q3.
	var pts: int = court.score[0] + court.score[1]
	t = 0.0
	while t < 12.0 and not court.play_live:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	var live_ok: bool = false
	t = 0.0
	while t < 6.0 and not live_ok:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		if court.play_live and court.ball_handler() != null:
			live_ok = true
	check("the match goes on into the 3rd quarter", live_ok and court.quarter == 3)
	check("the score was not wiped", court.score[0] + court.score[1] >= pts)

	# ---------------------------------------------------------- 7. tougher on a role 5
	_clean()
	for p in court.players:
		p.global_position = Vector2(-700.0, 420.0)
		p.velocity = Vector2.ZERO
	var piv5: BallPlayer = _role(0, 5)          # an AI role-5 attacker
	var hoop5: Vector2 = court.attack_hoop_for(piv5)
	piv5.global_position = hoop5 + Vector2(-side_sign(hoop5) * 330.0, 0.0)
	var guard: BallPlayer = _role(1, 5)
	guard.global_position = piv5.global_position + Vector2(-side_sign(hoop5) * 150.0, 0.0)
	court.give_ball(piv5)
	court._assign_man(1, Time.get_ticks_msec())     # marcature fresche
	u.move_input = Vector2.ZERO
	var gap0: float = guard.global_position.distance_to(piv5.global_position)
	var gap_min := 999.0
	var gap1 := gap0
	t = 0.0
	while t < 2.2:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
		gap1 = guard.global_position.distance_to(piv5.global_position)
		gap_min = minf(gap_min, gap1)
	print("   defender closed from %.0f to %.0f px (best %.0f)" % [gap0, gap1, gap_min])
	check("the man on a role-5 driver sits tight (< 80 px)", gap_min < 80.0)

	# ---------------------------------------------------------- 8. defensive set on a throw-in
	_clean()
	# Plausible pre-restart geometry: both teams spread around the middle.
	for p in court.players:
		var rr: float = float(p.role - 3)
		p.global_position = Vector2(rr * 150.0 - 60.0, 150.0 * (1.0 if p.team == 1 else -1.0))
		p.velocity = Vector2.ZERO
	court.possession = 0
	court._inbound(0, Vector2.ZERO)
	# The basket the defending team (1) protects: the one team 0 attacks.
	var basket_def: Vector2 = court.attack_hoop_for(_role(0, 5))
	await get_tree().create_timer(0.25).timeout      # let the set actually run
	var err0 := _set_error(basket_def)
	var d_before := _mean_to(basket_def, 1)
	# Watch the dead-ball window: the set must show while the ball is dead.
	var t_dead := 0.0
	while t_dead < 3.0 and (court.restarting or court.inbound_wait > 0.0):
		await get_tree().create_timer(0.05).timeout
		t_dead += 0.05
	var err1 := _set_error(basket_def)
	var d_after := _mean_to(basket_def, 1)
	print("   throw-in set ran %.2f s -- mean distance to the iron %.0f -> %.0f"
		% [t_dead, d_before, d_after])
	print("   distance to the set spot: %.0f -> %.0f px" % [err0, err1])
	check("the dead ball is long enough to set up", t_dead > 0.2)
	check("they hold the new close-marking throw-in set", err1 / maxf(float(_set_count()), 1.0) < 80.0)
	var spread := _set_worst(basket_def)
	var off_n: int = _set_count()
	print("   off his set spot: mean %.0f px, worst %.0f px (%d men)"
		% [err1 / maxf(float(off_n), 1.0), spread, off_n])
	check("the set pulls everyone onto his man's line to the iron",
		err1 / maxf(float(off_n), 1.0) < 110.0 and spread < 240.0)
	var ok_side := 0
	var men := 0
	for p in court.players:
		if p.team != 1 or p.role <= 2:
			continue
		var mk: BallPlayer = court.man_mark_for(p)
		if mk == null:
			continue
		men += 1
		if p.global_position.distance_to(basket_def) < mk.global_position.distance_to(basket_def) + 6.0:
			ok_side += 1
	print("   ", ok_side, "/", men, " defenders are between their man and the iron")
	check("the man on the ball side is between his man and the iron", ok_side >= 1)
	# The role 5 in particular: when the ball is at his end, HE is on it.
	var a5: BallPlayer = _role(0, 5)
	var d5: BallPlayer = _role(1, 5)
	if a5 != null and d5 != null:
		print("   role 5: defender %.0f px from the iron, attacker %.0f"
			% [d5.global_position.distance_to(basket_def), a5.global_position.distance_to(basket_def)])
		check("the role 5 defends his own basket, in front of his man",
			d5.global_position.distance_to(basket_def)
				< a5.global_position.distance_to(basket_def) + 20.0)

	# ---------------------------------------------------------- 9. slam landing dust
	_clean()
	var slammer: BallPlayer = _role(0, 5)
	var hb: Vector2 = court.attack_hoop_for(slammer)
	slammer.global_position = hb + Vector2(-side_sign(hb) * 90.0, 0.0)
	slammer.velocity = Vector2.ZERO
	slammer.air = 90.0
	slammer.hanging = true
	slammer.dust_big = false
	slammer.release_rim()
	var landed := false
	t = 0.0
	while t < 2.0 and not landed:
		await get_tree().process_frame
		t += get_process_delta_time()
		if slammer.dust_t > 0.0 and slammer.dust_big:
			landed = true       # la polvere del SALTO, non quella della frenata
	check("coming down from the rim kicks up the dust", landed and slammer.dust_big)
	print("   dust_t=%.2f big=%s" % [slammer.dust_t, str(slammer.dust_big)])

	print("RULE6PROBE: ", "ALL OK" if fails == 0 else "FAILURES=%d" % fails)
	get_tree().quit()

## Sum of each defender's distance to the spot the throw-in set wants him on:
## between his man and the iron, shaded toward the ball.
func _set_error(basket: Vector2) -> float:
	var ball: Vector2 = court.ball.global_position
	var total := 0.0
	for p in court.players:
		if p.team != 1 or p.role <= 2:
			continue
		var mk: BallPlayer = court.man_mark_for(p)
		if mk == null:
			continue
		var aim: Vector2 = court.inbound_defense_target(p)
		total += p.global_position.distance_to(aim)
	return total

func _set_count() -> int:
	var n := 0
	for p in court.players:
		if p.team == 1 and p.role > 2 and court.man_mark_for(p) != null:
			n += 1
	return n

func _set_worst(basket: Vector2) -> float:
	var ball: Vector2 = court.ball.global_position
	var worst := 0.0
	for p in court.players:
		if p.team != 1 or p.role <= 2:
			continue
		var mk: BallPlayer = court.man_mark_for(p)
		if mk == null:
			continue
		var aim: Vector2 = court.inbound_defense_target(p)
		worst = maxf(worst, p.global_position.distance_to(aim))
	return worst

func _mean_to(basket: Vector2, team: int) -> float:
	var total := 0.0
	var n := 0
	for p in court.players:
		if p.team == team:
			total += p.global_position.distance_to(basket)
			n += 1
	return total / maxf(n, 1)

func side_sign(v: Vector2) -> float:
	return -1.0 if v.x < 0.0 else 1.0

