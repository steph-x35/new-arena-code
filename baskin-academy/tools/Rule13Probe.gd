extends Node2D
## DEV ONLY. Batch 13 (v1.14.0): doppio palleggio (palla raccolta dopo la finta
## e poi rimessa a terra), canestro che VIBRA sulla schiacciata e sul ferro,
## rimbalzo vivo sull'ULTIMO tiro libero sbagliato (con la fila in corsia).
##   godot --headless --path . res://tools/Rule13Probe.tscn
var court: Node2D
var ms: Node
var vis: Node2D
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

func _role(team: int, r: int) -> BallPlayer:
	for p in court.players:
		if p.team == team and p.role == r:
			return p
	return null

func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = true
	Game.profile["baskin_role"] = 5
	ms = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	await get_tree().process_frame
	court = ms.get_node("Court")
	vis = ms.get_node("CourtVisual")
	ms.intro_left = 0.0
	if ms.intro_panel != null:
		ms.intro_panel.visible = false
	await get_tree().create_timer(2.0).timeout
	var u: BallPlayer = court.user
	for p in court.players:
		for c in p.get_children():
			if c.get_script() != null and String(c.get_script().resource_path).ends_with("AIBrain.gd"):
				c.queue_free()
	await get_tree().process_frame

	# ------------------------------------------------- 1. doppio palleggio
	_clean()
	for p in court.players:
		p.global_position = Vector2(-900.0, 430.0)
		p.velocity = Vector2.ZERO
	u.global_position = Vector2(-300.0, 300.0)
	u.move_input = Vector2.ZERO
	court.give_ball(u)
	var mine: int = u.team
	check("controllo: senza finta il palleggio si puo' fare", u.do_move("crossover"))
	u.cooldown_move = 0.0
	await get_tree().create_timer(0.4).timeout
	_clean()
	court.give_ball(u)
	check("la finta si fa", u.do_pump_fake())
	check("dopo la finta la palla e' RACCOLTA (fake_locked)", u.fake_locked)
	var pos0: int = court.possession
	var moved: bool = u.do_move("crossover")
	await get_tree().process_frame
	print("   do_move dopo la finta: %s | possesso %d -> %d | palla a %s"
		% [str(moved), pos0, court.possession, str(court.ball.holder)])
	check("DOPPIO PALLEGGIO: il move viene rifiutato", not moved)
	check("DOPPIO PALLEGGIO: il possesso passa agli avversari", court.possession != mine)
	check("DOPPIO PALLEGGIO: la palla e' in mano a un avversario",
		court.ball.holder != null and court.ball.holder.team != mine)
	check("DOPPIO PALLEGGIO: il lock dei passi e' stato sciolto", not u.fake_locked)

	# ------------------------------------------------- 2. canestro che vibra
	_clean()
	vis.rim_shake[0] = 0.0
	court._rim_quake(0, 1.0)
	await get_tree().process_frame
	var amp0: float = vis.rim_shake[0]
	var off0: float = vis.quake_off(0).length()
	# La scossa OSCILLA: si campiona su piu' fotogrammi e si guarda
	# l'escursione (un solo confronto a due campioni puo' cadere in fase).
	var off_min := 999.0
	var off_max := -999.0
	for i in 14:
		await get_tree().process_frame
		var o: float = vis.quake_off(0).length()
		off_min = minf(off_min, o)
		off_max = maxf(off_max, o)
	print("   scossa: ampiezza %.2f, primo scostamento %.1f px, escursione %.1f..%.1f px"
		% [amp0, off0, off_min, off_max])
	check("CANESTRO: la scossa viene registrata", amp0 > 0.9)
	check("CANESTRO: il canestro TREMA davvero (escursione > 1.5 px)",
		off_max > 2.0 and off_max - off_min > 1.5)
	await get_tree().create_timer(1.6).timeout
	check("CANESTRO: la vibrazione si spegne da sola", vis.rim_shake[0] <= 0.0
		and vis.quake_off(0) == Vector2.ZERO)
	# la schiacciata la innesca davvero (percorso di gioco, non solo l'API)
	vis.rim_shake[0] = 0.0
	vis.rim_shake[1] = 0.0
	var slammer: BallPlayer = _role(0, 5)
	var hb: Vector2 = court.hoop_for(slammer.team)
	var hidx: int = court.hoop_index_of(hb)
	slammer.has_ball = true
	slammer.hanging = false
	court._dunk_scored(slammer)
	await get_tree().process_frame
	print("   schiacciata: scossa sul canestro %d = %.2f" % [hidx, vis.rim_shake[hidx]])
	check("SCHIACCIATA: fa vibrare il canestro", vis.rim_shake[hidx] > 0.5)
	# e anche il ferro sfiorato
	vis.rim_shake[hidx] = 0.0
	court._quake_at(hb, 0.45)
	await get_tree().process_frame
	check("FERRO: anche il ferro colpito fa vibrare il canestro",
		vis.rim_shake[hidx] > 0.4)

	# ------------------------------------------------- 3. rimbalzo sul libero
	_clean()
	var victim: BallPlayer = _role(0, 5)
	for p in court.players:
		p.global_position = Vector2(-800.0, 400.0)
		p.has_ball = false
	court._start_free_throws(victim, 2)
	check("liberi: la sequenza parte", court.ft_active and court.ft_total == 2)
	var hoop: Vector2 = court.hoop_for(victim.team)
	var dir: float = -1.0 if hoop.x > 0.0 else 1.0
	# fila: due per squadra in corsia (fra ferro e linea dei liberi, dentro la
	# larghezza dell'area), gli altri oltre l'arco.
	var in_lane := [0, 0]
	var outside := 0
	var spots := {}
	var stacked := 0
	for p in court.players:
		if p == victim:
			continue
		var rel: Vector2 = p.global_position - hoop
		var lane_x: bool = dir * rel.x > 40.0 and dir * rel.x < Court.FT_PX
		if lane_x and absf(rel.y) < Court.FIBA_PAINT_W * 0.5:
			in_lane[p.team] += 1
			# i quattro posti devono essere tutti diversi (era il difetto:
			# le due squadre finivano sullo stesso punto)
			var key: String = "%d_%d" % [int(p.global_position.x / 12.0), int(p.global_position.y / 12.0)]
			if spots.has(key):
				stacked += 1
			spots[key] = true
		elif absf(rel.x) > Court.FT_PX + 150.0:
			outside += 1
	print("   fila del tiro libero: %d/%d in corsia (%d posti distinti), %d fuori dall'arco"
		% [in_lane[0], in_lane[1], spots.size(), outside])
	check("LIBERI: due per squadra in corsia", in_lane[0] == 2 and in_lane[1] == 2)
	check("LIBERI: i quattro posti sono tutti diversi", stacked == 0)
	check("LIBERI: gli altri restano fuori", outside >= 3)
	# primo libero sbagliato: la sequenza continua
	var bb: Ball = court.ball
	bb.global_position = hoop + Vector2(dir * 30.0, 0.0)
	bb.shot_hoop = hoop
	bb.last_touch_team = victim.team
	bb.is_free_throw = true
	bb.shot_result_pending = true
	court.resolve_missed_shot(bb)
	await get_tree().process_frame
	print("   primo sbagliato: ft_active=%s, liberi rimasti=%d, palla a %s"
		% [str(court.ft_active), court.ft_left, str(court.ball.holder)])
	check("LIBERI: il primo sbagliato non manda a rimbalzo", court.ft_active and court.ft_left == 1)
	check("LIBERI: la palla torna al tiratore", court.ball.holder == victim)
	# ultimo libero sbagliato: palla VIVA, rimbalzo vero
	bb = court.ball
	bb.global_position = hoop + Vector2(dir * 26.0, 6.0)
	bb.shot_hoop = hoop
	bb.last_touch_team = victim.team
	bb.is_free_throw = true
	bb.shot_result_pending = true
	court.resolve_missed_shot(bb)
	await get_tree().process_frame
	print("   ultimo sbagliato: ft_active=%s, play_live=%s, palla a %s, possesso %d"
		% [str(court.ft_active), str(court.play_live), str(court.ball.holder), court.possession])
	check("ULTIMO LIBERO: la palla e' VIVA (si va a rimbalzo)",
		not court.ft_active and court.play_live)
	check("ULTIMO LIBERO: qualcuno l'ha presa", court.ball.holder != null)
	check("ULTIMO LIBERO: il cronometro riparte da 24", court.shot_clock > 20.0)

	# controprova: sul fallo "L" la palla torna comunque alla squadra che l'ha
	# subito, anche se l'ultimo libero e' sbagliato
	_clean()
	for p in court.players:
		p.global_position = Vector2(-800.0, 400.0)
		p.has_ball = false
	court._start_free_throws(victim, 2)
	court.ft_left = 1
	court._ft_keep_possession = true
	bb = court.ball
	bb.global_position = hoop + Vector2(dir * 26.0, 6.0)
	bb.shot_hoop = hoop
	bb.last_touch_team = victim.team
	bb.is_free_throw = true
	bb.shot_result_pending = true
	court.resolve_missed_shot(bb)
	await get_tree().process_frame
	print("   fallo L, ultimo sbagliato: possesso=%d (vittima squadra %d)"
		% [court.possession, victim.team])
	check("FALLO L: dopo i liberi la palla resta alla squadra che li ha tirati",
		court.possession == victim.team)

	print("RULE13PROBE: ", "ALL OK" if fails == 0 else "FAILURES=%d" % fails)
	get_tree().quit()
