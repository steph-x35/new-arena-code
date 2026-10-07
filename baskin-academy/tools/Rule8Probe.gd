extends Node2D
## DEV ONLY. Batch 8: consegna comoda al pivot, falli regolamentari (rimessa
## prima del bonus, tiri liberi dal 5o fallo), timeout che restituisce energie,
## panchina che festeggia, cronometro rosso negli ultimi 5 secondi.
##   godot --headless --path . res://tools/Rule8Probe.tscn
var court: Node2D
var fails := 0

func check(nm: String, cond: bool) -> void:
	print(("  ok: " if cond else "  FAIL: ") + nm)
	if not cond:
		fails += 1

func _role(team: int, r: int) -> BallPlayer:
	for p in court.players:
		if p.team == team and p.role == r:
			return p
	return null

func _pivot(team: int) -> BallPlayer:
	for p in court.players:
		if p.team == team and p.role <= 2 and p.role > 0:
			return p
	return null

func _clean() -> void:
	court.play_live = true
	court.restarting = false
	court.ft_active = false
	court.inbound_wait = 0.0
	court.shot_clock = 20.0

func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["baskin_role"] = 5
	Settings.set_v("difficulty", 1)
	court = preload("res://src/match/Court.gd").new()
	add_child(court)
	await get_tree().process_frame
	await get_tree().create_timer(8.0).timeout
	var u: BallPlayer = court.user

	# ---------------------------------------------------- 1. hand-off to the pivot
	# The errand into the area is a QUICK one (the referee gives the human a
	# couple of seconds): what has to work is that the pivot comes to meet him,
	# so the delivery fits inside that window and lands in his hands.
	_clean()
	var area: Vector2 = court.side_hoops[0]
	var piv: BallPlayer = _pivot(0)
	for p in court.players:
		if p.team == 1:
			p.global_position = Vector2(-950.0, 430.0)
	u.global_position = area + Vector2(0.0, 60.0)
	u.velocity = Vector2.ZERO
	u.area_loiter_t = 0.0
	piv.global_position = area + Vector2(0.0, -140.0)
	piv.velocity = Vector2.ZERO
	piv.no_pivot_return = false
	court.possession = 0
	court.give_ball(u)
	var spot: Vector2 = court.handoff_spot(piv, u)
	print("   pivot starts %.0f px from the hand-off spot (%.0f px from the man)"
		% [piv.global_position.distance_to(spot), piv.global_position.distance_to(u.global_position)])
	var t := 0.0
	var arrived := 0.0
	while t < 2.0:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
		u.velocity = Vector2.ZERO
		u.move_input = Vector2.ZERO
		u.global_position = area + Vector2(0.0, 60.0)
		u.area_loiter_t = 0.0                     # just arrived: still legal
		court.shot_clock = 20.0
		court.play_live = true
		court.restarting = false
		if not u.has_ball and court.ball.holder != u and not court.ball.live:
			court.give_ball(u)
		if piv.global_position.distance_to(spot) < 34.0 and arrived == 0.0:
			arrived = t
			break
	print("   the pivot is on his spot after %.2f s (referee's rope: ~2 s)" % arrived)
	check("the pivot comes to the hand-off spot in time", arrived > 0.0 and arrived < 1.6)
	check("his spot is inside his own area", court.in_side_area(spot))
	var allowed: bool = court.pass_allowed(u, piv)
	check("the delivery from inside the area is offered", allowed)
	u.area_loiter_t = 0.0
	var poss0: int = court.possession
	u.do_pass(piv)
	var t2 := 0.0
	while t2 < 1.2 and not piv.has_ball:
		await get_tree().process_frame
		t2 += get_process_delta_time()
	print("   hand-off flight %.2f s -- pivot has the ball: %s" % [t2, str(piv.has_ball)])
	check("the hand-off lands in the pivot's hands", piv.has_ball)
	check("no whistle on the delivery", court.possession == poss0 and not court.ft_active)

	# ---------------------------------------------------- 2. fouls: throw-in vs line
	_clean()
	var def5: BallPlayer = _role(1, 5)
	u.global_position = Vector2(-200.0, 300.0)
	def5.global_position = u.global_position + Vector2(40.0, 0.0)
	court.team_fouls[1] = 0
	court.call_foul(def5, u, 0)
	await get_tree().create_timer(0.2).timeout
	print("   foul #1 of the quarter -> fts=%s restart=%s poss=%d holder=%s"
		% [str(court.ft_active), str(court.restarting), court.possession,
		(court.ball.holder.team if court.ball.holder is BallPlayer else -1)])
	check("before the 5th team foul a non-shooting foul is a throw-in", not court.ft_active)
	check("the ball goes back to the team that was fouled", court.possession == 0)
	_clean()
	court.team_fouls[1] = 4
	court.call_foul(def5, u, 0)
	await get_tree().create_timer(0.2).timeout
	print("   foul #5 of the quarter (bonus) -> fts=%s (%d shots)"
		% [str(court.ft_active), court.ft_total])
	check("from the 5th team foul on, every foul is 2 free throws",
		court.ft_active and court.ft_total == 2)
	# a shooting foul is always on the line, bonus or not
	_clean()
	court._ft_keep_possession = false
	court.team_fouls[1] = 0
	court.call_foul(def5, u, 2)
	await get_tree().create_timer(0.2).timeout
	check("a foul on the shot is still 2 free throws", court.ft_active and court.ft_total == 2)
	_clean()
	court.team_fouls[1] = 0
	court.call_foul(def5, u, 3)
	await get_tree().create_timer(0.2).timeout
	check("a foul on a three-point attempt is 3 free throws", court.ft_active and court.ft_total == 3)
	_clean()

	# ---------------------------------------------------- 3. the timeout is a breather
	for p in court.players:
		if p.team == 0:
			p.stamina = 40.0
	var before: int = court.timeouts_left[0]
	var ok_timeout: bool = court.call_timeout(0)
	await get_tree().create_timer(0.1).timeout
	var mean := 0.0
	var nn := 0
	for p in court.players:
		if p.team == 0:
			mean += p.stamina
			nn += 1
	mean /= maxf(float(nn), 1.0)
	print("   timeout: stamina 40 -> %.0f, left %d -> %d" % [mean, before, court.timeouts_left[0]])
	check("a timeout is taken and counted", ok_timeout and court.timeouts_left[0] == before - 1)
	check("the timeout gives the legs back (+22)", mean > 59.0 and mean < 66.0)
	court.timeout_active = 0.0
	_clean()

	# ---------------------------------------------------- 4. the bench erupts
	var sc0: int = court.score[0]
	var b := Ball.new()
	add_child(b)
	b.shooter = u
	b.shot_hoop = court.attack_hoop_for(u)
	b.shot_value = 2
	b.is_free_throw = false
	b.shot_result_pending = true
	b.live = true
	court.bench_cheer[0] = 0.0
	court._score_basket(b)
	await get_tree().create_timer(0.1).timeout
	print("   score %d -> %d, bench cheer %.1f" % [sc0, court.score[0], court.bench_cheer[0]])
	check("a made basket lights up the scoring team's bench", court.bench_cheer[0] > 0.0)
	check("and only theirs", court.bench_cheer[1] <= 0.0)
	check("the basket is on the board", court.score[0] > sc0)
	b.queue_free()
	_clean()

	# ---------------------------------------------------- 5. HUD: red clock + seats
	court.queue_free()
	await get_tree().process_frame
	Game.profile["match_is_fixture"] = true      # con panchina disegnata
	var ms: Node = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	await get_tree().create_timer(2.0).timeout
	var ok_flash: bool = ms.has_method("_flash_clock")
	if ok_flash:
		# Il cronometro ha un badge dedicato: mostra sempre i secondi, rosso e
		# pulsante sotto i 5, discreto (bianco trasparente) fuori.
		ms._flash_clock(4, true)
		var red: Color = ms.lbl_shot.modulate
		var red_txt: String = ms.lbl_shot.text
		ms._flash_clock(18, true)
		var calm: Color = ms.lbl_shot.modulate
		var calm_txt: String = ms.lbl_shot.text
		print("   badge at 4 s: %s %s, at 18 s: %s %s"
			% [red_txt, str(red), calm_txt, str(calm)])
		check("the clock turns red in the last 5 seconds", red.r > 0.9 and red.g < 0.7)
		check("the last seconds are shown in the badge", red_txt == "04")
		check("outside them it goes quiet and white", calm.g > 0.9 and calm.b > 0.9 and calm.a < 0.9)
	var c2: Node = ms.get_node("Court")
	var seats: Array = c2.bench_seats_vis
	var tagged := 0
	for e in seats:
		if (e as Dictionary).has("team"):
			tagged += 1
	print("   bench seats: %d of %d carry a team tag" % [tagged, seats.size()])
	check("every seat knows which team it belongs to", seats.size() > 0 and tagged == seats.size())

	print("RULE8PROBE: ", "ALL OK" if fails == 0 else "FAILURES=%d" % fails)
	get_tree().quit()
