extends Node2D
## DEV ONLY. Prediction remains for AI; the visible landing marker was removed in 1.17.
## The ball predicts where it lands, l'IA va sul punto di caduta vero, e sul
## ferro ci vanno solo i due piu' vicini per squadra.
##   godot --headless --path . res://tools/Rule11Probe.tscn
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
	for p in court.players:
		for c in p.get_children():
			if c.get_script() != null and String(c.get_script().resource_path).ends_with("AIBrain.gd"):
				c.queue_free()
	await get_tree().process_frame
	_clean()
	var ball: Ball = court.ball

	# ------------------------------------------------- 1. la palla non "sa" nulla
	for p in court.players:
		p.global_position = Vector2(-900.0, 430.0)
	u.global_position = Vector2(0.0, 300.0)
	court.give_ball(u)
	await get_tree().process_frame
	check("PREDICTION: a ball in someone's hands has no landing spot",
		not ball.landing_spot().is_finite())

	# ------------------------------------------------- 2. previsione del volo
	# Tiro vero, verso il canestro: la previsione deve cadere dove la palla
	# cade DAVVERO (non dove sta adesso).
	ball.detach()
	ball.live = true
	ball.shot_result_pending = false
	ball.global_position = Vector2(-300.0, 200.0)
	ball.h = 120.0
	ball.vel = Vector2(260.0, 40.0)
	ball.vh = 320.0
	var pred: Vector2 = ball.landing_spot()
	check("PREDICTION: a loose ball in the air has a landing spot", pred.is_finite())
	check("and it is AHEAD of the ball, not under it",
		pred.distance_to(ball.global_position) > 60.0)
	var t := 0.0
	var mid_pred: float = pred.distance_to(ball.global_position)
	while t < 2.5 and ball.h > 0.5:
		await get_tree().process_frame
		t += get_process_delta_time()
		ball.vh += 0.0
	var real: Vector2 = ball.global_position
	var err: float = real.distance_to(pred)
	print("   volo: preventivato %s, atterrata %s (scarto %.0f px, %.2f s)"
		% [str(pred.round()), str(real.round()), err, t])
	check("PREDICTION: the ball lands within 30 px of the prediction", err < 30.0)
	check("and the prediction was not just 'where it is now'", mid_pred > 60.0)

	# The user requested no landing circle. Prediction stays for AI, not drawing.
	var source := FileAccess.get_file_as_string("res://src/match/Ball.gd")
	var draw_source := source.substr(source.find("func _draw()"))
	check("MARKER: drawing no longer uses a landing prediction", not draw_source.contains("landing_spot()"))

	# ------------------------------------------------- 4. chi va sul ferro
	# Partita vera: palla libera in aria sopra meta' campo, e guardo chi si
	# muove verso il punto di caduta. Sul ferro ci vanno i due piu' vicini per
	# squadra, non tutti e dieci.
	court.queue_free()
	await get_tree().process_frame
	Game.profile["match_is_fixture"] = true
	var ms: Node = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	await get_tree().create_timer(3.0).timeout
	court = ms.get_node("Court")
	# L'INTRO (card "PALLA A DUE", 5.2 s) tiene la partita ferma: senza
	# saltarla l'IA non reagisce alla palla libera e il test misura il nulla.
	ms.intro_left = 0.0
	if ms.intro_panel != null:
		ms.intro_panel.visible = false
	_clean()
	await get_tree().create_timer(0.5).timeout
	_clean()
	var spot := Vector2(120.0, 120.0)
	var bb: Ball = court.ball
	bb.detach()
	bb.live = true
	bb.shot_result_pending = false
	bb.global_position = spot
	bb.h = 260.0
	bb.vel = Vector2(90.0, 30.0)
	bb.vh = 120.0
	var land: Vector2 = bb.landing_spot()
	var before := {}
	for p in court.players:
		before[p.get_instance_id()] = p.global_position.distance_to(land)
	var t3 := 0.0
	while t3 < 1.3:
		await get_tree().process_frame
		t3 += get_process_delta_time()
		if bb.holder != null:
			break
	var movers := 0
	var closest := []
	for p in court.players:
		var d0: float = before[p.get_instance_id()]
		var d1: float = p.global_position.distance_to(land)
		if d0 - d1 > 30.0:
			movers += 1
		if d1 < 150.0:
			closest.append(p.get_instance_id())
	print("   palla libera: %d giocatori su %d si sono mossi sul punto di caduta"
		% [movers, court.players.size()])
	var per_team := [0, 0]
	var det := ""
	for p in court.players:
		var d0: float = before[p.get_instance_id()]
		var d1: float = p.global_position.distance_to(land)
		if d1 < 150.0:
			per_team[p.team] += 1
		det += "  T%d#%d %.0f->%.0f
" % [p.team, p.jersey_num, d0, d1]
	print(det)
	print("   vicini al punto di caduta: %d (squadra 0: %d, squadra 1: %d)"
		% [per_team[0] + per_team[1], per_team[0], per_team[1]])
	check("REBOUND: NOT everybody swarms the ball (at most 5 of 10 move)",
		movers >= 1 and movers <= 5)

	print("RULE11PROBE: ", "ALL OK" if fails == 0 else "FAILURES=%d" % fails)
	get_tree().quit()
