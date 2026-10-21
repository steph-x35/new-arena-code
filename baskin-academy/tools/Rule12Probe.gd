extends Node2D
## DEV ONLY. Batch 12 (v1.13.0): la mano sta SOPRA la palla (stessa x), il
## braccio non si allunga (gomito piegato, mano entro la portata), il canestro
## laterale vicino e' rigirato (vista da dietro), il tasto DIFENDI manda
## sull'uomo legale e il fallo "L" fischia solo se insisti su un uomo illegale.
##   godot --headless --path . res://tools/Rule12Probe.tscn
var court: Node2D
var fails := 0

func check(nm: String, cond: bool) -> void:
	print(("  ok: " if cond else "  FAIL: ") + nm)
	if not cond:
		fails += 1

func _foe(r: int) -> BallPlayer:
	for p in court.players:
		if p.team == 1 and p.role == r:
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
	for p in court.players:
		for c in p.get_children():
			if c.get_script() != null and String(c.get_script().resource_path).ends_with("AIBrain.gd"):
				c.queue_free()
	await get_tree().process_frame
	_clean()
	var hb: float = 64.0 * u.height_f

	# ------------------------------------------------- 1. mano sopra la palla
	for p in court.players:
		p.global_position = Vector2(-900.0, 430.0)
		p.velocity = Vector2.ZERO
	u.global_position = Vector2(-300.0, 300.0)
	u.move_input = Vector2.ZERO
	court.give_ball(u)
	var dx_max := 0.0
	var gap_max := 0.0
	var low_palm := 9999.0
	var ball_low := 9999.0
	var ball_high := 0.0
	var hand_low := 9999.0
	var hand_high := -9999.0
	var arm_max := 0.0
	var bent := 0
	var samples := 0
	var t := 0.0
	while t < 1.6:
		await get_tree().process_frame
		t += get_process_delta_time()
		_clean()
		u.velocity = Vector2.ZERO
		var off: Vector2 = u.drib_hint()
		ball_high = maxf(ball_high, off.y * hb)
		var b = Avatar.drib_hand_at(0.0, 0.0, hb, off,
			Court.BALL_R, u.hand_side, true)     # base (0,0): tutto relativo
		var ball_c := Vector2(off.x * hb, -off.y * hb)
		ball_low = minf(ball_low, -ball_c.y)
		dx_max = maxf(dx_max, absf(float(b.x) - ball_c.x))
		gap_max = maxf(gap_max, float(b.y) - (ball_c.y - Court.BALL_R))
		low_palm = minf(low_palm, -float(b.y))
		# braccio e spalla ESATTAMENTE come li disegna Avatar: la posa del
		# palleggio (crouch) e' la stessa, quindi il test misura il disegno.
		var sh := Vector2(0.135 * hb * signf(off.x),
			-hb * 0.80 + hb * 0.6 * Avatar.drib_crouch() + hb * 0.04)
		var d: float = (b - sh).length()
		arm_max = maxf(arm_max, d)
		hand_low = minf(hand_low, -float(b.y))
		hand_high = maxf(hand_high, -float(b.y))
		var al: Vector2 = Avatar.arm_len()
		var el: Vector2 = Avatar.drib_elbow_at(sh, b, hb, signf(off.x))
		# quanto il gomito esce dalla linea spalla-mano (0 = braccio dritto)
		var line: Vector2 = (b - sh).normalized()
		var perp: float = absf((el - sh).cross(line))
		if perp > 1.5:
			bent += 1
		samples += 1
	var al2: Vector2 = Avatar.arm_len()
	var reach: float = (al2.x + al2.y) * hb
	print("   palleggio: %d campioni, scarto x mano/palla %.1f px, salita mano %.1f px"
		% [samples, dx_max, gap_max])
	print("   braccio: spalla-mano max %.0f px su %.0f disponibili (h=%.0f), gomito piegato %d/%d"
		% [arm_max, reach, hb, bent, samples])
	print("   palla: altezza minima %.1f px (a terra = raggio 5.5)" % ball_low)
	print("   palla: da %.1f a %.1f px di altezza" % [ball_low, ball_high])
	print("   mano: corsa %.1f px (da %.1f a %.1f, h=%.0f)" % [hand_high - hand_low, hand_low, hand_high, hb])
	check("HAND: the palm is exactly ABOVE the ball (same x)", dx_max < 1.0)
	check("HAND: the palm is always ABOVE the ball", gap_max > -Court.BALL_R)
	check("ARM: the hand never goes past the arm's reach (no stretched arm)",
		arm_max <= reach - 0.5)
	check("ARM: and the elbow is really BENT (not a straight line)",
		bent > samples * 0.5)
	check("DRIBBLE: the palm still travels with the bounce (a real stroke)",
		hand_high - hand_low > hb * 0.15)
	check("DRIBBLE: and the ball still reaches the floor", ball_low < 12.0)

	# ------------------------------------------------- 2. canestro laterale
	for p in court.players:
		p.global_position = Vector2(-900.0, 430.0)
	# il canestro vicino alla telecamera si vede da dietro, quello lontano no
	check("SIDE HOOP: the near basket is turned around (we see the backboard)",
		NetFront.side_hoop_faces_away(Vector2(0.0, Court.COURT_H * 0.5)))
	check("SIDE HOOP: the far one keeps its front view",
		not NetFront.side_hoop_faces_away(Vector2(0.0, -Court.COURT_H * 0.5)))

	# ------------------------------------------------- 3. difesa: chi marcare
	var r5: BallPlayer = _foe(5)
	var r3: BallPlayer = _foe(3)
	check("the match has a role 5 and a role 3 opponent", r5 != null and r3 != null)
	u.global_position = Vector2(-300.0, 300.0)
	u.has_ball = false
	court.ball.holder = null
	court.ball.live = false
	court.give_ball(r5)
	r5.global_position = Vector2(-200.0, 300.0)
	u.guarding = true
	await get_tree().process_frame
	await get_tree().process_frame
	print("   portatore ruolo 5: guard_target=%s (%s)"
		% [str(court.guard_target), "RUOLO 5" if court.guard_target == r5 else "?"])
	check("DEFENCE: with a role-5 ball-handler you take HIM", court.guard_target == r5)
	# ora il portatore e' un ruolo 3 (che io, ruolo 5, non posso marcare)
	court.give_ball(r3)
	r3.global_position = Vector2(-240.0, 300.0)
	r5.global_position = Vector2(-420.0, 300.0)
	await get_tree().process_frame
	await get_tree().process_frame
	print("   portatore ruolo 3: guard_target=%s" % str(court.guard_target))
	check("DEFENCE: with an illegal ball-handler you are sent to YOUR man, not to him",
		court.guard_target != r3)
	check("DEFENCE: and it is a legal man (role 5 or nobody)",
		court.guard_target == null or court.guard_target.role == 5)

	# ------------------------------------------------- 4. fallo L: solo insistendo
	u.guarding = true
	u.global_position = r3.global_position + Vector2(20.0, 0.0)
	var f0: int = court.team_fouls[0]
	var t2 := 0.0
	var mark_seen := false
	while t2 < 0.18:
		await get_tree().process_frame
		t2 += get_process_delta_time()
		_clean()
		u.global_position = r3.global_position + Vector2(20.0, 0.0)
		u.guarding = true
		if court.ill_mark == r3:
			mark_seen = true
	print("   addosso a un ruolo 3 per 0.18 s: fischio=%s segno=%s"
		% [str(court.team_fouls[0] != f0), str(mark_seen)])
	check("L: at a glance there is no whistle (a brush is not a foul)",
		court.team_fouls[0] == f0)
	check("L: but the red mark shows up at once (you can see it coming)", mark_seen)
	t2 = 0.0
	while t2 < 0.5:
		await get_tree().process_frame
		t2 += get_process_delta_time()
		_clean()
		u.global_position = r3.global_position + Vector2(20.0, 0.0)
		u.guarding = true
	print("   insistendo: falli squadra %d -> %d" % [f0, court.team_fouls[0]])
	check("L: insisting on an illegal man IS whistled", court.team_fouls[0] > f0)

	# controprova: addosso al TUO uomo (ruolo 5) non si fischia mai
	await get_tree().create_timer(9.5).timeout           # passa il cooldown
	court.give_ball(r5)
	r5.global_position = Vector2(-300.0, 300.0)
	u.guarding = true
	var f1: int = court.team_fouls[0]
	t2 = 0.0
	while t2 < 0.8:
		await get_tree().process_frame
		t2 += get_process_delta_time()
		_clean()
		u.global_position = r5.global_position + Vector2(18.0, 0.0)
		u.guarding = true
		r5.velocity = Vector2.ZERO
	print("   addosso al ruolo 5 per 0.8 s: falli %d -> %d" % [f1, court.team_fouls[0]])
	check("NO L FOUL: guarding your own role is always legal",
		court.team_fouls[0] == f1)

	# controprova 2: PASSIVO (nessun joystick) l'assist ti porta via dall'uomo
	# illegale e NON si fischia mai -- e' la garanzia "non oppressivo".
	court.give_ball(r3)
	r5.global_position = Vector2(-160.0, 300.0)
	u.global_position = r3.global_position + Vector2(20.0, 0.0)
	u.guarding = true
	u.move_input = Vector2.ZERO
	var f2: int = court.team_fouls[0]
	var d3_before: float = u.global_position.distance_to(r3.global_position)
	t2 = 0.0
	while t2 < 0.9:
		await get_tree().process_frame
		t2 += get_process_delta_time()
		_clean()
		r3.global_position = Vector2(-220.0, 300.0)
		r3.velocity = Vector2.ZERO
		u.guarding = true
		u.move_input = Vector2.ZERO
	print("   passivo addosso al ruolo 3: distanza %.0f -> %.0f px, falli %d -> %d"
		% [d3_before, u.global_position.distance_to(r3.global_position), f2, court.team_fouls[0]])
	check("L: if you DO NOT insist (no stick) you are moved off him",
		u.global_position.distance_to(r3.global_position) > d3_before + 25.0)
	check("L: and no whistle comes for a man you are leaving", court.team_fouls[0] == f2)
	u.move_input = Vector2.ZERO

	print("RULE12PROBE: ", "ALL OK" if fails == 0 else "FAILURES=%d" % fails)
	get_tree().quit()
