extends Node2D
## DEV ONLY. Verifies baskin rules headless.
##   godot --headless --path . res://tools/BaskinProbe.tscn

var fails := 0
var court: Node2D
var rule_keys: Array = []

func check(nm: String, cond: bool) -> void:
	if cond:
		print("  ok: ", nm)
	else:
		fails += 1
		print("  FAIL: ", nm)

func by_role(team: int, role: int) -> BallPlayer:
	for p in court.players:
		if p.team == team and int(p.role) == role:
			return p
	return null

func roles_of(team: int) -> Array:
	var r := []
	for p in court.players:
		if p.team == team:
			r.append(int(p.role))
	r.sort()
	return r

func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["quarter_seconds"] = 120.0
	Game.profile["baskin_role"] = 5
	Events.rule.connect(func(k): rule_keys.append(k))
	court = preload("res://src/match/Court.gd").new()
	add_child(court)
	await get_tree().process_frame
	# 1. ONE pivot per team: role 1 or 2, plus 3/4/5/5
	check("10 players", court.players.size() == 10)
	check("t0 legal five", roles_of(0) == [1, 3, 4, 5, 5])
	check("t1 legal five", roles_of(1) == [2, 3, 4, 5, 5])
	check("one pivot t0", court.players.filter(func(p): return p.team == 0 and p.role <= 2).size() == 1)
	check("one pivot t1", court.players.filter(func(p): return p.team == 1 and p.role <= 2).size() == 1)
	check("user default role 5", court.user.role == 5)
	check("t1 pivot is 2R", court.pivot_player(1).variant == "2R")
	check("t0 pivot is 1", court.pivot_player(0).role == 1)
	check("pivot bench 2+2", court.pivot_bench[0].size() == 2 and court.pivot_bench[1].size() == 2)
	check("bench matches pivot role", court.pivot_bench[1][0].role == 2 and court.pivot_bench[0][0].role == 1)
	var c0: BallPlayer = null
	for p in court.players:
		if p.team == 0 and p.role == 5 and p.global_position.distance_to(Vector2(-58, 0)) < 1.0:
			c0 = p
	check("jump center t0 is role5", c0 != null)
	# 2. attack hoops
	var r1: BallPlayer = court.pivot_player(0)
	var r2p: BallPlayer = court.pivot_player(1)
	check("r1 attacks team side", court.attack_hoop_for(r1) == court.side_hoops[0])
	check("r2 pivot attacks his side", court.attack_hoop_for(r2p) == court.side_hoops[1])
	check("r5 attacks main", court.attack_hoop_for(by_role(0, 5)) == court.hoop_for(0))
	check("r4 attacks main", court.attack_hoop_for(by_role(1, 4)) == court.hoop_for(1))
	# 3. pure helpers
	check("side rim 94", court.rim_height_of(court.side_hoops[0]) == 94.0)
	check("main rim 188", court.rim_height_of(court.hoop_for(0)) == 188.0)
	check("hoop idx", court.hoop_index_of(court.hoops[0]) == 0 and court.hoop_index_of(court.side_hoops[1]) == 3)
	check("nearest hoop", court.nearest_hoop(Vector2(0, -400)) == court.side_hoops[0])
	check("pivot spot outside area", not court.in_side_area(court.pivot_spot(0)))
	check("pivot home inside area", court.in_side_area(court.pivot_home(0)))
	check("r1 shot spot inside", court.in_side_area(court.pivot_shot_spot(0, r1)))
	check("r2 shot spot outside", not court.in_side_area(court.pivot_shot_spot(1, r2p)))
	# 4. point values
	r1.pivot_attempts = 0
	check("r1 1st=3", court._baskin_points(r1, court.side_hoops[0]) == 3)
	r1.pivot_attempts = 2
	check("r1 2nd=2", court._baskin_points(r1, court.side_hoops[0]) == 2)
	check("r2 pivot side=3", court._baskin_points(r2p, court.side_hoops[1]) == 3)
	var r3 := by_role(0, 3)
	r3.received_in_side_area = false
	check("r3 side=2", court._baskin_points(r3, court.side_hoops[0]) == 2)
	check("r3 main=3", court._baskin_points(r3, court.hoop_for(0)) == 3)
	r3.received_in_side_area = true
	check("r3 main recv-side=2", court._baskin_points(r3, court.hoop_for(0)) == 2)
	var r5 := by_role(0, 5)
	r5.global_position = court.hoop_for(0) + Vector2(-100, 0)
	check("r5 close=2", court._baskin_points(r5, court.hoop_for(0)) == 2)
	r5.global_position = Vector2.ZERO
	check("r5 deep=3", court._baskin_points(r5, court.hoop_for(0)) == 3)
	# 5. shot checks
	for p in [r3, by_role(1, 4), r5]:
		p.global_position = Vector2(200, 100)
		p.velocity = Vector2.ZERO
		p.dribble_t = 1.0
		p.period_makes = 0
		p.period_shots = 0
	r5.period_shots = 3
	check("r5 limit", court._baskin_shot_check(r5, court.hoop_for(0)) == "v_lim5")
	r5.period_shots = 0
	check("r5 legal", court._baskin_shot_check(r5, court.hoop_for(0)) == "")
	r3.period_makes = 3
	check("r3 makes limit", court._baskin_shot_check(r3, court.hoop_for(0)) == "v_lim3")
	r3.period_makes = 0
	r3.dribble_t = 0.0
	check("r3 dribble", court._baskin_shot_check(r3, court.hoop_for(0)) == "v_dribble3")
	r3.dribble_t = 1.0
	r3.velocity = Vector2(200, 0)
	r3.global_position = court.hoop_for(0) + Vector2(-80, 0)
	check("r3 layup", court._baskin_shot_check(r3, court.hoop_for(0)) == "v_layup3")
	var r4 := by_role(1, 4)
	r4.velocity = Vector2(100, 0)
	check("r4 stop", court._baskin_shot_check(r4, court.hoop_for(1)) == "v_stop4")
	r4.velocity = Vector2.ZERO
	check("r4 planted", court._baskin_shot_check(r4, court.hoop_for(1)) == "")
	# pivot shots
	r1.global_position = court.pivot_home(0)
	r1.pivot_attempts = 0
	r1.own_miss_rebound = false
	check("r1 shoots inside", court._baskin_shot_check(r1, court.side_hoops[0]) == "")
	check("r1 attempt counted", r1.pivot_attempts == 1)
	r1.own_miss_rebound = true
	check("no re-shoot off own miss", court._baskin_shot_check(r1, court.side_hoops[0]) == "v_reb2")
	r1.own_miss_rebound = false
	r2p.dribble_t = 1.0
	r2p.global_position = court.side_hoops[1] + Vector2(0, -60)
	check("r2 pivot inside area illegal", court._baskin_shot_check(r2p, court.side_hoops[1]) == "v_area")
	r2p.global_position = court.pivot_shot_spot(1, r2p)
	check("r2 pivot legal outside", court._baskin_shot_check(r2p, court.side_hoops[1]) == "")
	# 6. legal marking both teams
	var legal := true
	for t in [0, 1]:
		court._assign_man(t, Time.get_ticks_msec())
		for did in court._man_marks:
			var dd: BallPlayer = null
			var oo: BallPlayer = null
			for p in court.players:
				if p.get_instance_id() == did:
					dd = p
				if p.get_instance_id() == int(court._man_marks[did]):
					oo = p
			# the AI must mark by the SAME rule the referee whistles the human
			# for (Regola 8: the lower role takes the higher one, pivots never)
			if dd == null or oo == null or oo.role <= 2 or court.ill_guard(dd, oo):
				legal = false
	check("marks legal", legal)
	# 7. role swap: user takes the pivot
	court.assign_user_role(2)
	check("user now r2", court.user.role == 2 and court.user.variant == "2T")
	check("one pivot after pick", court.players.filter(func(p): return p.team == 0 and p.role <= 2).size() == 1)
	check("t0 still legal five", roles_of(0) == [2, 3, 4, 5, 5])
	court.assign_user_role(1)
	check("user now r1", court.user.role == 1 and court.user.wheelchair)
	check("one pivot t0 again", court.players.filter(func(p): return p.team == 0 and p.role <= 2).size() == 1)
	court.assign_user_role(5)
	check("user back to r5", court.user.role == 5)
	# 8. AI pivot sub
	var pr: BallPlayer = court.pivot_player(1)
	var prole: int = pr.role
	pr.period_makes = 3
	court._substitute_pivot(pr)
	check("10 after sub", court.players.size() == 10)
	var npr: BallPlayer = court.pivot_player(1)
	check("new pivot placed", npr != null and npr.global_position.distance_to(court.pivot_home(1)) < 1.0)
	check("new pivot same role", npr != null and npr.role == prole)
	check("new pivot makes reset", npr.period_makes == 0)
	check("bench still 2", court.pivot_bench[1].size() == 2)
	check("sub reset own-miss flag", not npr.own_miss_rebound and not npr.no_pivot_return)
	# Unit scenarios below must not race live AI decisions or the initial jump.
	court.jump_pending = false
	court._jump_run = false
	for pl in court.players:
		for child in pl.get_children():
			if child is AIBrain: child.set_physics_process(false)
	# 9. delivery: only by hand, from inside (never whistled)
	var dlv_p := by_role(0, 5)
	court.play_live = true
	court.restarting = false
	court.inbound_wait = 0.0
	court.ft_active = false
	var live_piv: BallPlayer = court.pivot_player(0)
	dlv_p.global_position = Vector2(500, 300)
	court.give_ball(dlv_p)
	var poss0: int = court.possession
	dlv_p.do_pass(live_piv)
	await get_tree().create_timer(0.35).timeout
	check("far feed refused", court.possession == poss0 and not live_piv.has_ball)
	check("no whistle for far feed", court.possession == poss0)
	court.update_pass_aim(dlv_p, (live_piv.global_position - dlv_p.global_position).normalized())
	check("far pivot not aimed", court.aimed != live_piv)
	# clear the lane: defenders on the line can intercept (random) and a user
	# standing next to a lower role would draw an illegal-defence whistle
	for opp in court.players:
		if opp.team == 1:
			opp.global_position = Vector2(-820, 420)
	court.ft_active = false
	court.ft_shooter = null
	court.ft_left = 0
	court.restarting = false
	court.inbound_wait = 0.0
	court.play_live = true
	dlv_p.global_position = court.pivot_home(0) + Vector2(40, 8)
	dlv_p.move_input = Vector2.ZERO
	court.give_ball(dlv_p)
	court.update_pass_aim(dlv_p, (live_piv.global_position - dlv_p.global_position).normalized())
	check("inside pivot aimed", court.aimed == live_piv)
	print("DBG gate live=", court.play_live, " rest=", court.restarting, " wait=", court.inbound_wait,
		" ft=", court.ft_active, " inA=", court.in_side_area(dlv_p.global_position),
		" flag=", dlv_p.no_pivot_return, " pivrole=", live_piv.role, " dlvrole=", dlv_p.role,
		" dlvhas=", dlv_p.has_ball, " pivhas=", live_piv.has_ball)
	dlv_p.do_pass(live_piv)
	await get_tree().create_timer(0.45).timeout
	check("inside feed arrives", live_piv.has_ball)
	check("pivot clock on receipt", live_piv.pivot_clock > 8.0)
	check("tutor recorded", live_piv.tutor == dlv_p)
	# the pivot may not hand it straight back to the tutor who fed him
	court.do_pass(live_piv, dlv_p)
	check("give-back refused", court.ball.holder == live_piv)
	# 10. pivot's miss: live rebound, then the dead ball goes to the pivot
	live_piv.own_miss_rebound = false
	live_piv.tutor = null
	court.ball.shooter = live_piv
	court.ball.is_free_throw = false
	court.ball.holder = null
	court.play_live = true
	court.resolve_missed_shot(court.ball)
	check("pivot miss opens rebound", court.rebound_watch > 0.0 and court.rebound_pivot == live_piv)
	check("no instant sideline whistle", not court.restarting)
	# role 3-5 cannot reach into the area for that ball
	var r3b := by_role(1, 3)
	r3b.global_position = court.side_hoops[0] + Vector2(20, 20)
	court.ball.global_position = court.side_hoops[0] + Vector2(10, 10)
	court.ball.h = 30.0
	court.ball.holder = null
	check("outsider may not grab in area", not court.try_grab(r3b))
	r3b.global_position = court.side_hoops[0] + Vector2(200, 0)
	court.ball.global_position = court.side_hoops[0] + Vector2(196, 0)
	check("outsider may grab from outside", court.try_grab(r3b))
	# 11. ball stranded in the area belongs to the pivot
	court.ball.holder = null
	court.ball.global_position = court.side_hoops[0] + Vector2(20, -20)
	court.play_live = true
	court.rebound_watch = 0.05
	court.rebound_team = 0
	court.rebound_hoop = court.side_hoops[0]
	court._area_rebound_tick(0.1)
	check("dead area ball to pivot", live_piv.has_ball)
	court.rebound_watch = 0.0
	# 11b. a dead ball in the area with a ROLE-2 pivot is a jump ball
	court.play_live = true
	court.ball.holder = null
	court.ball.global_position = court.side_hoops[1] + Vector2(15, -15)
	court.rebound_watch = 0.05
	court.rebound_team = 1
	court.rebound_hoop = court.side_hoops[1]
	court.jump_pending = false
	court._jump_run = false
	court._area_rebound_tick(0.1)
	check("role2 dead ball -> jump ball", court.jump_pending or court._jump_run)
	court.jump_pending = false
	court._jump_run = false
	court.rebound_watch = 0.0
	court.play_live = true
	# 12. pivot miss when the pivot is a role 2: no re-shoot in 5s window
	live_piv.own_miss_rebound = false
	court.ball.shooter = live_piv
	court.resolve_missed_shot(court.ball)
	check("rebound window again", court.rebound_watch > 0.0)
	# 13. restart after the pivot's basket: lateral, 2 m BEYOND the area
	var pv: BallPlayer = court.pivot_player(0)
	court.ball.shooter = pv
	court.ball.shot_hoop = court.side_hoops[0]
	court.ball.shot_value = 3
	court.ball.shot_result_pending = false
	court.ball.live = false
	# La rimessa laterale dipende da DOVE sta la palla (quale area e' vicina):
	# pinnata sull'area alta il test e' deterministico.
	court.ball.global_position = court.side_hoops[0]
	court._score_basket(court.ball)
	await get_tree().create_timer(0.9).timeout
	check("restart is opponents' ball", court.possession == 1)
	check("inbounder not a pivot", court._inbounder != null and court._inbounder.role > 2)
	check("receiver not a pivot", court._inbound_receiver == null or court._inbound_receiver.role > 2)
	# Await the transition's setup point, not a machine-speed-dependent frame.
	var settle := 0.0
	while court._inbound_preparing and settle < 1.0:
		await get_tree().create_timer(0.02).timeout
		settle += 0.02
	if not is_instance_valid(court._inbounder):
		check("inbound setup completed", false)
		get_tree().quit(1)
		return
	var ibx: float = absf(court._inbounder.global_position.x)
	check("inbound beyond the area", ibx > Court.SIDE_AREA_R + 90.0)
	check("inbound on the sideline", absf(court._inbounder.global_position.y) > Court.COURT_H * 0.5)
	check("inbound outside pivot area", not court.in_side_area(court._inbounder.global_position))
	# 14. area trespass: a role 3 camping in the area is whistled
	court.restarting = false
	court.play_live = true
	court.ft_active = false
	var camp := by_role(1, 3)
	camp.global_position = court.side_hoops[1] + Vector2(10, -10)
	camp.area_loiter_t = 0.0
	court.ball.global_position = court.side_hoops[1] + Vector2(0, -120)
	court.ball.holder = null
	court.try_grab(camp)   # put him on the ball so the limit is the strict one
	var poss_before: int = camp.team
	for i in 40:
		court._area_trespass_check(0.1)
		if court.possession != poss_before:
			break
	check("area camping whistled", court.possession != poss_before)
	check("rule signal v_area_in", "v_area_in" in rule_keys)
	# 15a. clocks + who carries the ball out of a dead ball
	court.play_live = true
	court.restarting = false
	court.ft_active = false
	court.give_ball(live_piv)
	check("role 1 clock is 10s", live_piv.pivot_clock == 10.0)
	court.give_ball(court.pivot_player(1))
	check("2R clock is 7s", court.pivot_player(1).pivot_clock == 7.0)
	court.possession = 0
	court._reset_possession(false)
	check("dead ball never handed to a pivot", court.ball_handler() != null and court.ball_handler().role > 2)
	# 15. clocks + clamp
	court.play_live = true
	court.restarting = false
	court.ft_active = false
	court.inbound_wait = 0.0
	court.give_ball(court.pivot_player(0))
	court.pivot_player(0).pivot_clock = 0.01
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("pivot clock turnover", court.possession == 1)
	check("rule signal pivot clock", "v_pivot5s" in rule_keys)
	var clamped: BallPlayer = court.pivot_player(1)
	court.play_live = false
	clamped.global_position = Vector2(500, 300)
	court.clamp_to_court(clamped)
	check("r2 clamped to his apron", clamped.global_position.distance_to(court.side_hoops[1]) \
		<= Court.SIDE_PIVOT_RANGE + 1.0)
	live_piv.global_position = Vector2(500, 300)
	court.clamp_to_court(live_piv)
	check("r1 clamped dead ball", court.in_side_area(live_piv.global_position))
	clamped.global_position = court.side_hoops[1] + Vector2(0, -60)
	court.clamp_to_court(clamped)
	check("r2 apron respected", court.in_side_area(clamped.global_position))
	check("r2 may stand past the line", not clamped.global_position.is_equal_approx(court.pivot_home(1)))
	# 16. Loc keys EN+IT
	var keys := ["tip", "r1_make", "r1_sub", "r2_make", "r3_make", "r4_make", "r5_make",
		"v_dribble2", "v_dribble3", "v_layup3", "v_stop4", "v_area", "v_lim5", "v_lim3",
		"v_pivot5s", "v_illegal", "tutor", "foul", "v_deliver", "v_area_in", "v_reb2"]
	var extra := ["match.deliver.need_area", "match.deliver.two_man", "match.area.reach", "match.area.loose",
		"role.1.d", "role.2.d", "rules.score", "rules.viol"]
	var locok := true
	for lg in ["en", "it"]:
		Loc.set_lang(lg)
		for k in keys:
			if Loc.t("rule." + k) == "" or Loc.t("rule." + k + ".body") == "":
				locok = false
		for k in extra:
			if Loc.t(k) == "":
				locok = false
	check("Loc EN+IT complete", locok)
	var roleok := true
	for r in [1, 2, 3, 4, 5]:
		for lg in ["en", "it"]:
			Loc.set_lang(lg)
			if Loc.t("role.%d" % r) == "" or Loc.t("role.%d.d" % r) == "" or Loc.t("role.%d.hint" % r) == "":
				roleok = false
	check("role strings EN+IT", roleok)
	Loc.set_lang("en")
	check("jerseys are roles", court.players.all(func(p): return p.jersey_num == p.role))
	check("pivot home centred", absf(court.pivot_home(0).x) < 1.0)
	# 17. fouls still work
	var sh := by_role(0, 5)
	var df := by_role(1, 5)
	df.global_position = sh.global_position + Vector2(40, 0)
	var fhits := 0
	for i in 200:
		if court._shooting_foul_check(sh, 0.8) != null:
			fhits += 1
	check("foul rate sane", fhits >= 3)
	court.call_foul(df, sh, 2)
	check("foul to the line", court.ft_active and court.ft_shooter == sh and court.ft_total == 2)
	check("rule signal foul", "foul" in rule_keys)
	print("BASKIN PROBE: ", "ALL OK" if fails == 0 else "FAILURES=%d" % fails)
	get_tree().quit()
