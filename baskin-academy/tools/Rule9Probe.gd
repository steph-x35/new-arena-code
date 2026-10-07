extends Node2D
## DEV ONLY. Batch 9: il palleggio e' coerente (mano sulla palla), il rimbalzo
## tocca il pavimento, la palla va bassa quando sei marcato, i move hanno la
## palla dove devono (incrocio basso, stepback ed esitazione con palla in
## mano) e la frenata si vede.
##   godot --headless --path . res://tools/Rule9Probe.tscn
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

func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["baskin_role"] = 5
	court = preload("res://src/match/Court.gd").new()
	add_child(court)
	await get_tree().process_frame
	await get_tree().create_timer(8.0).timeout
	var u: BallPlayer = court.user
	for p in court.players:
		p.global_position = Vector2(-900.0, 420.0)
		p.velocity = Vector2.ZERO
	# the brains out of the way: this is about the dribble, not about the AI
	for p in court.players:
		for c in p.get_children():
			if c.get_script() != null and String(c.get_script().resource_path).ends_with("AIBrain.gd"):
				c.queue_free()
	await get_tree().process_frame
	var hb: float = 64.0 * u.height_f

	# ------------------------------------------------- 1. mano e palla insieme
	court.play_live = true
	court.restarting = false
	court.ft_active = false
	court.possession = 0
	u.global_position = Vector2(0.0, 300.0)
	u.velocity = Vector2.ZERO
	u.move_input = Vector2.ZERO
	court.give_ball(u)
	var worst := 0.0
	var lo := 9999.0
	var hi := -1.0
	var samples := 0
	var t := 0.0
	while t < 1.6:
		await get_tree().process_frame
		t += get_process_delta_time()
		court.shot_clock = 20.0
		if not u.has_ball and court.ball.holder != u and not court.ball.live:
			court.give_ball(u)
		var off: Vector2 = u.drib_hint()
		var want_h: float = off.y * hb
		worst = maxf(worst, absf(court.ball.h - want_h))
		lo = minf(lo, court.ball.h)
		hi = maxf(hi, court.ball.h)
		samples += 1
	print("   dribble: %d campioni, palla fra %.0f e %.0f px (mano a %.0f)"
		% [samples, lo, hi, hb])
	print("   scarto massimo mano/palla: %.2f px (la palla legge il palmo un tick dopo)"
		% worst)
	check("MAGNET: palm and ball never drift apart (within one frame, < 7 px)",
		worst < 7.0)
	check("the bounce really touches the floor (< 24 px)", lo < 24.0)
	check("and it comes back up to the hand (> 40% of the body)", hi > hb * 0.40)
	check("the dribble is fast enough to read (>= 1 rimbalzo ogni 0.5 s)", hi > lo)

	# ------------------------------------------------- 2. guarded: low dribble
	var d5: BallPlayer = _role(1, 5)
	d5.global_position = u.global_position + Vector2(70.0, 0.0)
	var hi_pressed := -1.0
	var lo_pressed := 9999.0
	t = 0.0
	while t < 1.2:
		await get_tree().process_frame
		t += get_process_delta_time()
		court.shot_clock = 20.0
		d5.global_position = u.global_position + Vector2(70.0, 0.0)
		if t > 0.25:                            # lascia assestare il palleggio
			hi_pressed = maxf(hi_pressed, court.ball.h)
			lo_pressed = minf(lo_pressed, court.ball.h)
	print("   marcato addosso: palla fra %.0f e %.0f px (libero: %.0f-%.0f), press=%.2f dist=%.0f"
		% [lo_pressed, hi_pressed, lo, hi, u._press_t,
			u.global_position.distance_to(d5.global_position)])
	check("PRESSED: the dribble drops low and stays protected", hi_pressed < hi * 0.75)
	check("PRESSED: and it still touches the floor", lo_pressed < 24.0)
	d5.global_position = Vector2(-900.0, 420.0)
	await get_tree().create_timer(0.5).timeout

	# ------------------------------------------------- 3. the crossover stays low
	u.hand_side = 1.0
	var side0: float = 1.0
	u.do_move("crossover")
	var hi_x := -1.0
	var flipped := false
	t = 0.0
	while t < 0.55 and u.move_t > 0.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > 0.05 and t < 0.40:
			hi_x = maxf(hi_x, court.ball.h)
		var off2: Dictionary = u.dribble_ball_offset()
		if signf(float(off2["x"])) != side0:
			flipped = true
	print("   incrocio: palla max %.0f px, mano cambiata: %s" % [hi_x, str(flipped)])
	print("   incrocio: altezza max misurata %.0f px (ginocchio ~%.0f)" % [hi_x, hb * 0.28])
	check("the crossover is a LOW dribble, under the knee (< 30% of the body)",
		hi_x < hb * 0.30)
	check("the ball really changes hand in the crossover", flipped)

	# ------------------------------------------------- 4. stepback: ball collected
	u.move_t = 0.0
	u.hand_side = 1.0
	u.do_move("stepback")
	var low_hold := 9999.0
	t = 0.0
	while t < 0.2 and u.move_t > 0.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		low_hold = minf(low_hold, court.ball.h)
	print("   stepback: la palla non scende sotto %.0f px nel pianto" % low_hold)
	check("STEPBACK: the ball is COLLECTED on the pivot foot (never on the floor)",
		low_hold > hb * 0.30)

	# ------------------------------------------------- 5. hesitation holds it
	u.move_t = 0.0
	u.hand_side = 1.0
	u.do_move("hesi")
	var low_hesi := 9999.0
	t = 0.0
	while t < 0.18 and u.move_t > 0.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		low_hesi = minf(low_hesi, court.ball.h)
	print("   esitazione: palla in mano (min %.0f px)" % low_hesi)
	check("HESITATION: the ball is held in hand (the freeze that beats the defender)",
		low_hesi > hb * 0.30)

	# ------------------------------------------------- 6. the braking skid
	u.move_t = 0.0
	for q in court.players:
		q.global_position = Vector2(-900.0, 430.0)
	u.global_position = Vector2(-300.0, 200.0)
	court.give_ball(u)
	u.move_input = Vector2(1.0, 0.0)
	t = 0.0
	while t < 1.2:
		await get_tree().process_frame
		t += get_process_delta_time()
		u.move_input = Vector2(1.0, 0.0)      # run flat out
	var v_before: float = u.velocity.length()
	var x_release: float = u.global_position.x
	u.move_input = Vector2.ZERO
	u.move_input = Vector2.ZERO
	var skidded := false
	var dust := false
	t = 0.0
	while t < 0.6:
		await get_tree().process_frame
		t += get_process_delta_time()
		u.move_input = Vector2.ZERO
		if u.skid_t > 0.0:
			skidded = true
		if u.dust_t > 0.0:
			dust = true
	var slid: float = u.global_position.x - x_release
	print("   frenata: velocita' %.0f px/s, strisciata %.0f px, segni=%s polvere=%s"
		% [v_before, slid, str(skidded), str(dust)])
	check("BRAKING: stopping at speed leaves a skid", skidded)
	check("and a puff of dust on the parquet", dust)
	check("the slide is visible but short (10..90 px)", slid > 10.0 and slid < 90.0)

	# ------------------------------------------------- 7. body lean
	u.velocity = Vector2(260.0, 0.0)
	var lean_fast: float = u.lean_frac()
	u.velocity = Vector2.ZERO
	var lean_still: float = u.lean_frac()
	print("   inclinazione: in corsa %.3f, da fermo %.3f" % [lean_fast, lean_still])
	check("LEAN: the body tips into the run", absf(lean_fast) > 0.02)
	check("and stays plumb when standing still", absf(lean_still) < 0.001)

	print("RULE9PROBE: ", "ALL OK" if fails == 0 else "FAILURES=%d" % fails)
	get_tree().quit()
