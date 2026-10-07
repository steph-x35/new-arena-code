extends Node2D
## DEV ONLY. Checks batch 4: the "L" foul (who may guard whom), the side-area
## trespass infraction, the role-3 free throws at the HIGH side basket, and the
## mixed-team hair assignment.
##   godot --headless --path . res://tools/LProbe.tscn
var court: Node2D
var fails := 0

func check(nm: String, cond: bool) -> void:
	print(("  ok: " if cond else "  FAIL: ") + nm)
	if not cond:
		fails += 1

func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["baskin_role"] = 5          # the human is a role 5
	court = preload("res://src/match/Court.gd").new()
	add_child(court)
	await get_tree().process_frame
	await get_tree().create_timer(8.0).timeout   # let the tip-off play out

	var u: BallPlayer = court.user
	check("user is a role 5", u.role == 5)

	# ---------------------------------------------------------------- 1. who may guard whom
	# role numbers grow with ability: the LOWER role takes the higher one.
	check("5 may NOT take a 3", court.ill_guard(u, _opp_role(3)))
	check("5 takes another 5", not court.ill_guard(u, _opp_role(5)))
	check("3 takes the role-2 pivot (rule)", not court.ill_guard(_own_role(3), _opp_role(2)))
	check("5 may not take the role-2 pivot", court.ill_guard(u, _opp_role(2)))
	# the role-1 pivot is team 0's (the human asked for role 5): a defender may not take him
	check("nobody takes the role-1 pivot", court.ill_guard(_opp_role(3), _own_role(1)))

	# ---------------------------------------------------------------- 2. hair
	var women := [0, 0]
	var men := [0, 0]
	var bad_cut := 0
	for p in court.players:
		if p.gender == 1:
			women[p.team] += 1
			if p.hair_style_v != 6 and p.hair_style_v != 7:
				bad_cut += 1
		else:
			men[p.team] += 1
			if p.hair_style_v not in [0, 1, 4]:
				bad_cut += 1
	check("at least 2 women per team on the floor", women[0] >= 2 and women[1] >= 2)
	check("men and women both present", men[0] > 0 and men[1] > 0)
	check("every cut matches the gender", bad_cut == 0)
	print("   women=", women, " men=", men)

	# ---------------------------------------------------------------- 3. role 5 on a role 3 = L
	var victim: BallPlayer = _opp_role(3)
	var holder: BallPlayer = _opp_role(4)
	_clean_state()
	court.give_ball(holder)
	u.global_position = victim.global_position + Vector2(26.0, 0.0)
	u.stance = true
	u.guarding = true          # the human HOLDS the DEFENCE button to mark
	court.shot_clock = 20.0
	court._ill_whistle_cd = 0.0
	var t := 0.0
	while t < 3.0 and not court.ft_active:
		await get_tree().process_frame          # contatto CONTINUO (0.30 s)
		t += get_process_delta_time()
		court.shot_clock = 20.0
		court.possession = 1
		u.global_position = victim.global_position + Vector2(26.0, 0.0)
		u.guarding = true
		# INTENZIONE: il joystick spinge addosso all'uomo illegale
		u.move_input = (victim.global_position - u.global_position).normalized()
	check("whistle: L foul called", court.ft_active)
	check("the fouled man shoots", court.ft_shooter == victim)
	check("2 free throws", court.ft_total == 2)
	check("shot at the SIDE basket", court.ft_side)
	check("fouled role 3 keeps the ball after", court._ft_keep_possession)
	check("the defender is booked", u.fouls >= 1)
	var side_hoop: Vector2 = court.side_hoops[victim.team]
	var d_ft: float = court.px_to_ft(court.ft_shooter.global_position.distance_to(side_hoop))
	check("shooting from ~4 m (dashed line, outside the area)", d_ft > 8.5 and d_ft < 14.0)
	print("   ft spot distance from the side basket: ", snappedf(court.ft_shooter.global_position.distance_to(side_hoop), 1.0), " px")
	# the arc must be aimed at the SIDE basket (the net/rim path reads
	# ball.shot_hoop): watch the first release frame by frame.
	var sc_before: int = court.score[victim.team]
	var seen_hoop := Vector2.ZERO
	var seen_side := false
	var t2 := 0.0
	while t2 < 4.0 and seen_hoop == Vector2.ZERO:
		await get_tree().process_frame
		t2 += get_process_delta_time()
		if court.ball != null and court.ball.shot_result_pending:
			seen_hoop = court.ball.shot_hoop
			seen_side = court.ball.shot_is_side
	check("the shot is aimed at the side basket", seen_hoop == side_hoop)
	check("shot flagged as a side-basket shot", seen_side)
	# let the series finish and check possession goes back to the victim team
	t = 0.0
	while t < 30.0 and court.ft_active:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	check("free throws finished", not court.ft_active)
	check("victim team keeps possession", court.possession == victim.team)
	print("   free throws scored: ", court.score[victim.team] - sc_before, " of 2")

	# ------------------------------------------- 4. opponents' area: a WALL
	# Batch 5: entering the opponents' area is impossible (no whistle): the
	# court pushes you out, so the L foul only ever comes from marking.
	_clean_state()
	var area: Vector2 = court.side_hoops[1]
	var fouls_before: int = u.fouls
	court.give_ball(_opp_role(4))
	u.global_position = area
	await get_tree().physics_frame
	await get_tree().physics_frame
	u.global_position = area
	await get_tree().physics_frame
	check("cannot cross the opponents' area", u.global_position.distance_to(area) >= Court.SIDE_AREA_R)
	check("no whistle for it", u.fouls == fouls_before)

	print("LPROBE: ", "ALL OK" if fails == 0 else "FAILURES=%d" % fails)
	get_tree().quit()

func _clean_state() -> void:
	court.play_live = true
	court.restarting = false
	court.ft_active = false
	court.inbound_wait = 0.0
	court.awaiting_check = false
	court.jump_pending = false

func _opp_role(r: int) -> BallPlayer:
	for p in court.players:
		if p.team == 1 and p.role == r:
			return p
	return null

func _own_role(r: int) -> BallPlayer:
	for p in court.players:
		if p.team == 0 and p.role == r:
			return p
	return null
