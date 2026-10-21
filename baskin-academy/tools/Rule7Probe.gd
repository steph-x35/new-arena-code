extends Node2D
## DEV ONLY. Batch 7: difficulty really changes the opponents, they foul you
## too, help defence is sensible, and the two time rules are called.
##   godot --headless --path . res://tools/Rule7Probe.tscn
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

func _clean() -> void:
	court.play_live = true
	court.restarting = false
	court.ft_active = false
	court.inbound_wait = 0.0
	court.jump_pending = false
	court.awaiting_check = false
	court.shot_clock = 20.0

func _brain(pl: BallPlayer) -> Node:
	for c in pl.get_children():
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("AIBrain.gd"):
			return c
	return null

func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["baskin_role"] = 5
	Settings.set_v("difficulty", 2)
	court = preload("res://src/match/Court.gd").new()
	add_child(court)
	await get_tree().process_frame
	await get_tree().create_timer(8.0).timeout
	var u: BallPlayer = court.user

	# ------------------------------------------------- 1. difficulty is felt
	var hard_sk := []
	for p in court.players:
		if p.team == 1:
			var c := _brain(p)
			if c != null:
				hard_sk.append(c.skill)
	Settings.set_v("difficulty", 0)
	var easy_sk := []
	for p in court.players:
		if p.team == 1:
			var c2 := _brain(p)
			if c2 != null:
				c2.setup(p, court)                 # re-read the setting
				easy_sk.append(c2.skill)
	Settings.set_v("difficulty", 2)
	for p in court.players:
		if p.team == 1:
			var c3 := _brain(p)
			if c3 != null:
				c3.setup(p, court)
	var hsum := 0.0
	for v in hard_sk:
		hsum += float(v)
	var esum := 0.0
	for v in easy_sk:
		esum += float(v)
	var hard_mean: float = hsum / maxf(float(hard_sk.size()), 1.0)
	var easy_mean: float = esum / maxf(float(easy_sk.size()), 1.0)
	print("   AI skill: hard %.2f vs easy %.2f" % [hard_mean, easy_mean])
	check("Forte: the opponents are sharper than at Facile", hard_mean > easy_mean + 0.25)
	check("Facile is genuinely weak (skill < 0.62)", easy_mean < 0.62)

	# ------------------------------------------------- 2. the AI fouls YOU
	_clean()
	for p in court.players:
		p.global_position = Vector2(-820.0, 380.0)
		p.velocity = Vector2.ZERO
	var attacker: BallPlayer = _role(0, 4)
	var hoopA: Vector2 = court.attack_hoop_for(attacker)
	var spot: Vector2 = hoopA + Vector2(-300.0 if hoopA.x > 0.0 else 300.0, 0.0)
	attacker.global_position = spot
	var guard: BallPlayer = _role(1, 4)      # he is the one who MARKS that role
	var guard_brain := _brain(guard)
	# The mechanism is what we test, not the balance: crank the defender's foul
	# tendency up so the whistle has to come in a couple of seconds. The real
	# value (checked below) is a couple of hundredths per second of contact.
	guard_brain.d_foul = 30.0
	# Siamo dentro il bonus (5o fallo di squadra): cosi' il fallo di contatto
	# vale DUE tiri liberi. Prima del bonus il regolamento prevede la rimessa
	# (coperto da Rule8Probe).
	court.team_fouls[1] = 4
	var f0: int = court.team_fouls[1]
	var t := 0.0
	var seen_foul := false
	while t < 12.0 and not seen_foul:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
		court.give_ball(attacker)
		attacker.global_position = spot
		attacker.velocity = Vector2(-220.0, 0.0)
		attacker.move_input = Vector2(-1.0, 0.0)
		attacker.shot_charge = 0.40          # he is going up: real contact
		guard.global_position = spot + Vector2(38.0, 4.0)
		guard.velocity = Vector2.ZERO
		guard_brain.foul_cd = 0.0
		court.shot_clock = 20.0
		court.play_live = true
		court.restarting = false
		if court.ft_active or court.team_fouls[1] > f0:
			seen_foul = true
	print("   contact foul after %.1f s (team fouls %d), free throws: %s"
		% [t, court.team_fouls[1], str(court.ft_active)])
	check("an opponent CAN foul you on the drive", seen_foul)
	check("inside the bonus the foul sends you to the line (2 free throws)",
		court.ft_active and court.ft_total == 2)
	guard_brain.d_foul = 1.15
	_clean()
	print("   real foul tendency: %.2f per second of contact" % guard_brain.d_foul_real())
	check("the real foul rate stays rare (< 0.2 per second of contact)",
		guard_brain.d_foul_real() < 0.2)
	var tt := 0.0
	while tt < 8.0 and court.ft_active:
		await get_tree().create_timer(0.1).timeout
		tt += 0.1

	# ------------------------------------------------- 3. sensible help
	_clean()
	for p in court.players:
		p.global_position = Vector2(-820.0, 380.0)
		p.velocity = Vector2.ZERO
	# my man is a shooter parked far from the rim: I must NOT sag off him
	var shoot_man: BallPlayer = _role(1, 4)
	var helper: BallPlayer = _role(0, 5)
	var driver: BallPlayer = _role(1, 5)
	var hoopC: Vector2 = court.attack_hoop_for(driver)
	shoot_man.global_position = hoopC + Vector2(-150.0 if hoopC.x > 0.0 else 150.0, 0.0)
	driver.global_position = hoopC + Vector2(-30.0 if hoopC.x > 0.0 else 30.0, 0.0)
	helper.global_position = hoopC + Vector2(-700.0, -260.0)
	court.give_ball(driver)
	var gap_man := 0.0
	var t7 := 0.0
	while t7 < 2.4:
		await get_tree().create_timer(0.05).timeout
		t7 += 0.05
		shoot_man.global_position = hoopC + Vector2(-150.0 if hoopC.x > 0.0 else 150.0, 0.0)
		shoot_man.velocity = Vector2.ZERO
		driver.velocity = Vector2(-200.0, 0.0)
		court.shot_clock = 20.0
		court.play_live = true
		court.restarting = false
		gap_man = helper.global_position.distance_to(shoot_man.global_position)
	print("   helper stands %.0f px from his own man (rim is %.0f away)"
		% [gap_man, hoopC.distance_to(shoot_man.global_position)])
	check("no suicide help: he does not abandon a shooter far from the rim",
		gap_man < 470.0)

	# ------------------------------------------------- 4. 3 seconds in the key
	# From here on the brains are switched off: a player who wanders off on his
	# own would reset the clocks under test.
	for p in court.players:
		for c in p.get_children():
			if c.get_script() != null and String(c.get_script().resource_path).ends_with("AIBrain.gd"):
				c.queue_free()
	await get_tree().process_frame
	_clean()
	for p in court.players:
		p.global_position = Vector2(-900.0, 400.0)
		p.velocity = Vector2.ZERO
	var big: BallPlayer = _role(0, 4)
	var hoopB: Vector2 = court.attack_hoop_for(big)
	big.global_position = hoopB + Vector2(-40.0 if hoopB.x > 0.0 else 40.0, 0.0)   # in the key
	court.possession = 0
	court.give_ball(big)
	var poss0: int = court.possession
	var t3 := 0.0
	var called := false
	while t3 < 4.6 and not called:
		await get_tree().create_timer(0.05).timeout
		t3 += 0.05
		big.move_input = Vector2.ZERO
		big.global_position = hoopB + Vector2(-40.0 if hoopB.x > 0.0 else 40.0, 0.0)
		court.shot_clock = 20.0
		if court.possession != poss0:
			called = true
	print("   3-second rule after %.1f s, possession now %d" % [t3, court.possession])
	check("camping in the key is whistled after ~3 s", called and t3 < 4.2)
	check("the ball goes to the other team", court.possession == 1)

	# ------------------------------------------------- 5. 5 seconds guarded
	_clean()
	for p in court.players:
		p.global_position = Vector2(-900.0, 400.0)
		p.velocity = Vector2.ZERO
	var holder: BallPlayer = _role(0, 4)
	holder.global_position = Vector2(0.0, 300.0)
	var def5: BallPlayer = _role(1, 4)
	court.possession = 0
	court.give_ball(holder)
	poss0 = court.possession
	var t5 := 0.0
	var called5 := false
	while t5 < 7.0 and not called5:
		await get_tree().create_timer(0.05).timeout
		t5 += 0.05
		holder.move_input = Vector2.ZERO
		holder.velocity = Vector2.ZERO
		holder.global_position = Vector2(0.0, 300.0)
		def5.global_position = holder.global_position + Vector2(70.0, 0.0)
		court.shot_clock = 20.0
		if court.possession != poss0:
			called5 = true
	print("   5-second rule after %.1f s, possession now %d" % [t5, court.possession])
	check("standing still while closely guarded is whistled after ~5 s",
		called5 and t5 < 6.6 and t5 > 3.4)
	# ...and it is NOT called if he keeps playing (moving the ball resets it)
	_clean()
	for p in court.players:
		p.global_position = Vector2(-900.0, 400.0)
		p.velocity = Vector2.ZERO
	court.possession = 0
	court.give_ball(holder)
	poss0 = court.possession
	var t6 := 0.0
	while t6 < 6.0:
		await get_tree().create_timer(0.05).timeout
		t6 += 0.05
		holder.move_input = Vector2(1.0, 0.0)
		holder.velocity = Vector2(210.0, 0.0)
		holder.global_position = Vector2(-600.0 + t6 * 60.0, 200.0)
		def5.global_position = holder.global_position + Vector2(70.0, 0.0)
		court.shot_clock = 20.0
	check("a man who keeps moving is never whistled", court.possession == poss0)

	# ------------------------------------------------- 6. the side net in front
	var ball := Ball.new()
	add_child(ball)
	ball.global_position = court.side_hoops[0] + Vector2(0.0, 6.0)
	ball.h = Court.SIDE_RIM_HEIGHT - 20.0
	ball.vh = -120.0
	var nf = preload("res://src/match/NetFront.gd").new()
	add_child(nf)
	var dropping: bool = nf._ball_dropping_through(ball, court.side_hoops[0])
	ball.global_position = Vector2(700.0, 300.0)
	var far_away: bool = nf._ball_dropping_through(ball, court.side_hoops[0])
	ball.global_position = court.side_hoops[0] + Vector2(0.0, 6.0)
	ball.h = Court.SIDE_RIM_HEIGHT + 200.0
	var high: bool = nf._ball_dropping_through(ball, court.side_hoops[0])
	print("   side net: dropping=%s, far=%s, high=%s" % [str(dropping), str(far_away), str(high)])
	check("the side net is drawn in front while the ball drops through it",
		dropping and not far_away and not high)

	print("RULE7PROBE: ", "ALL OK" if fails == 0 else "FAILURES=%d" % fails)
	get_tree().quit()
