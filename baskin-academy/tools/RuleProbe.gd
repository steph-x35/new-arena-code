extends Node2D
## DEV ONLY. Batch 5: the "L" whistle is quiet on offence and not oppressive on
## defence, every change of possession is a throw-in, the opponents' side area
## is a wall, the pivots stay home, the inbound ball is still and then flies.
##   godot --headless --path . res://tools/RuleProbe.tscn
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
	var opp3 := _role(1, 3)
	var opp4 := _role(1, 4)
	# park everybody so nothing else interferes
	for p in court.players:
		p.global_position = Vector2(-800.0 + 80.0 * p.role, 300.0 * (1.0 if p.team == 0 else -1.0))
		p.velocity = Vector2.ZERO

	# ---------------------------------------------------------- 1. no L on offence
	_clean()
	court.possession = 0
	court.give_ball(_role(0, 4))
	u.global_position = opp3.global_position + Vector2(20.0, 0.0)   # crowding a role 3
	u.guarding = true
	u.stance = true
	var t := 0.0
	while t < 2.5:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	check("no L whistle while MY team attacks", not court.ft_active and u.fouls == 0)

	# ---------------------------------------------------------- 2. quiet on defence
	_clean()
	court.give_ball(opp4)                # they attack: we defend
	court.shot_clock = 20.0
	court._ill_whistle_cd = 0.0
	u.guarding = false
	u.stance = false
	t = 0.0
	while t < 2.0:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		court.shot_clock = 20.0
		if court.ball_handler() == null or court.ball_handler().team == u.team:
			court.give_ball(opp4)      # keep a live opponent possession
		u.velocity = Vector2.ZERO
		u.global_position = opp3.global_position + Vector2(45.0, 0.0)   # near, not guarding
	check("standing near a role 3 is not a whistle", u.fouls == 0)
	# now really guard him: stuck to him at contact distance, DEFENCE held
	u.guarding = true
	t = 0.0
	while t < 5.0 and u.fouls == 0:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		# The whistle is blocked while the ball is dead (a steal, an inbound, a
		# free throw in progress): pin the live possession, like the referee
		# would keep the game running, and let the cooldown expire.
		court.shot_clock = 20.0
		court._ill_whistle_cd = 0.0
		court.restarting = false
		court.inbound_wait = 0.0
		court.play_live = true
		u.guarding = true
		if court.ball_handler() == null or court.ball_handler().team == u.team:
			court.give_ball(opp4)
		u.global_position = opp3.global_position + Vector2(24.0, 0.0)
	print("   whistled after %.1f s" % t)
	check("marking a role 3 as a role 5 IS the L foul", u.fouls > 0)
	check("L gives 2 free throws at the side basket", court.ft_active and court.ft_side)
	t = 0.0
	while t < 25.0 and court.ft_active:
		await get_tree().create_timer(0.1).timeout
		t += 0.1

	# ---------------------------------------------------------- 3. throw-in on a steal
	_clean()
	court.give_ball(_role(1, 4))
	var t0: int = court.possession
	var stealer: BallPlayer = _role(0, 5)
	if stealer == u and _role(0, 3) != null:
		stealer = _role(0, 3)
	stealer.global_position = _role(1, 4).global_position + Vector2(24.0, 0.0)
	court.on_turnover(_role(1, 4), stealer)
	await get_tree().create_timer(0.4).timeout
	check("steal -> dead ball, restarting", court.restarting or court.inbound_wait > 0.0)
	check("steal -> the ball is thrown in by the OTHER team", court.possession == 0 and court.possession != t0)
	var ib: BallPlayer = court._inbounder
	check("a thrower is set", ib != null and ib.team == 0)

	# ---------------------------------------------------------- 4. inbound ball is still
	if ib != null:
		var h0: float = court.ball.h
		var p0: Vector2 = court.ball.global_position
		var moved := 0.0
		t = 0.0
		while t < 0.25:
			await get_tree().process_frame
			t += get_process_delta_time()
			moved = maxf(moved, (court.ball.global_position - p0).length())
		check("inbound ball does not bounce (held still)", court.ball.held_still and moved < 30.0)
		print("   still-ball drift over 0.25 s: ", snappedf(moved, 1.0), " px (h ", snappedf(h0, 1.0), ")")
	# let the throw happen and watch the ball fly
	var flew := false
	var flight_px := 0.0
	var prev: Vector2 = court.ball.global_position
	t = 0.0
	while t < 3.0 and not flew:
		await get_tree().process_frame
		t += get_process_delta_time()
		if court.ball.live and court.ball.holder == null:
			flew = true
		if flew:
			flight_px = (court.ball.global_position - prev).length()
		prev = court.ball.global_position
	check("the inbound is a visible pass into the court", flew)
	print("   throw seen at t=", snappedf(t, 2.0), " s, ball ", (court.ball.holder != null))

	# ---------------------------------------------------------- 5. opponents' area is a wall
	_clean()
	var area: Vector2 = court.side_hoops[1]          # team 1's area, we are team 0
	u.global_position = area                            # teleport him inside
	await get_tree().physics_frame
	await get_tree().physics_frame
	u.global_position = area
	await get_tree().physics_frame
	check("nobody crosses the opponents' area (wall)", u.global_position.distance_to(area) >= Court.SIDE_AREA_R)
	var fouls_before: int = u.fouls
	court.possession = 1                                 # even when they attack
	u.global_position = area
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("wall holds while defending too", u.global_position.distance_to(area) >= Court.SIDE_AREA_R)
	check("and it is NOT a whistle", u.fouls == fouls_before)

	# ---------------------------------------------------------- 6. pivots live in their area
	_clean()
	var piv2: BallPlayer = court.pivot_player(1)
	var piv1: BallPlayer = court.pivot_player(0)
	if piv2 != null:
		court.give_ball(_role(1, 4))                     # not his ball
		piv2.global_position = court.side_hoops[1] + Vector2(0.0, 420.0)   # run away up court
		await get_tree().physics_frame
		await get_tree().physics_frame
		piv2.global_position = court.side_hoops[1] + Vector2(0.0, 420.0)
		await get_tree().physics_frame
		check("role 2 without the ball is leashed inside the area",
			piv2.global_position.distance_to(court.side_hoops[1]) <= Court.SIDE_AREA_R)
	if piv1 != null:
		piv1.global_position = court.side_hoops[0] + Vector2(0.0, -420.0)
		await get_tree().physics_frame
		piv1.global_position = court.side_hoops[0] + Vector2(0.0, -420.0)
		await get_tree().physics_frame
		check("role 1 is leashed inside the area",
			piv1.global_position.distance_to(court.side_hoops[0]) <= Court.SIDE_AREA_R)

	# ---------------------------------------------------------- 7. pivot rules recap
	check("role 2 shoots from OUTSIDE the area (step-out spot)",
		court.pivot_shot_spot(1, piv2).distance_to(court.side_hoops[1]) > Court.SIDE_AREA_R)
	check("role 1 shoots from INSIDE his area",
		court.pivot_shot_spot(0, piv1).distance_to(court.side_hoops[0]) < Court.SIDE_AREA_R)
	var p2: BallPlayer = court.pivot_player(1, 2)

	# ------------------------------------------------- 8. pivot mechanics recap
	_clean()
	var r2: BallPlayer = court.pivot_player(1, 2)
	var r1: BallPlayer = court.pivot_player(0, 1)
	if r2 != null:
		court.give_ball(_role(1, 4))
		court.give_ball(r2)                     # the hand-off lands
		var want: float = 7.0 if r2.variant == "2R" else 10.0
		check("2R pivot clock is 7 s (10 s for the 2T)", is_equal_approx(r2.pivot_clock, want))
		check("the clock only starts on the hand-off", r2.pivot_clock > 0.0)
	if r1 != null:
		court.give_ball(_role(0, 4))
		court.give_ball(r1)
		check("role 1 clock is 10 s", is_equal_approx(r1.pivot_clock, 10.0))
	# the ball may NOT be passed to a pivot from outside his area
	court.ball.detach()
	for q in court.players:
		q.has_ball = false
	var feeder: BallPlayer = _role(0, 4)
	if feeder != null and r1 != null:
		feeder.global_position = Vector2(300.0, 0.0)
		court.give_ball(feeder)
		check("feeding the pivot from outside is refused", not court.pass_allowed(feeder, r1))
		feeder.global_position = court.pivot_home(0)
		check("the hand-off from inside the area is allowed", court.pass_allowed(feeder, r1))
	# own miss: the pivot must pass out, never shoot again
	if r1 != null:
		r1.own_miss_rebound = true
		check("pivot off his own miss cannot shoot", court._baskin_shot_check(r1, court.side_hoops[0]) == "v_reb2")
		r1.own_miss_rebound = false
	# 3 makes and the pivot is substituted
	if r1 != null:
		r1.period_makes = 3
		var before_id: int = r1.get_instance_id()
		court._substitute_pivot(r1)
		var now_piv: BallPlayer = court.pivot_player(0)
		check("after 3 makes the pivot is replaced", now_piv != null and now_piv.get_instance_id() != before_id)

	print("RULEPROBE: ", "ALL OK" if fails == 0 else "FAILURES=%d" % fails)
	get_tree().quit()
