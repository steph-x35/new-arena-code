extends Node2D
## DEV ONLY: an AI role-5 handler must be able to DRIVE and SLAM on his own.
var court: Node2D
var fails := 0
func check(nm: String, cond: bool) -> void:
	print(("  ok: " if cond else "  FAIL: ") + nm)
	if not cond:
		fails += 1
func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["baskin_role"] = 5
	court = preload("res://src/match/Court.gd").new()
	add_child(court)
	await get_tree().process_frame
	await get_tree().create_timer(8.0).timeout      # tip-off plays out
	var p5: BallPlayer = null
	for p in court.players:
		if p.team == 0 and p.role == 5 and p != court.user:
			p5 = p
			break
	var hoop: Vector2 = court.attack_hoop_for(p5)
	court.play_live = true
	court.restarting = false
	court.ft_active = false
	court.inbound_wait = 0.0
	court.shot_clock = 24.0
	# defenders out of the picture: this tests the AI's own decision, not
	# whether a body got in the way
	for o in court.players:
		if o.team == 1:
			o.global_position = Vector2(-150, 420)
	p5.global_position = hoop + Vector2(380, 40)     # 20 ft out
	p5.velocity = Vector2.ZERO
	p5.stamina = 100.0
	p5.period_shots = 0
	court.give_ball(p5)
	var s0: int = court.score[0]
	var t := 0.0
	var slammed := false
	var drove := false
	var min_d := 99.0
	while t < 8.0:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
		if p5.has_ball:
			min_d = minf(min_d, court.px_to_ft(p5.global_position.distance_to(hoop)))
			if p5.dunking or p5.hanging:
				slammed = true
			for c in p5.get_children():
				if c is AIBrain and c.role == "drive":
					drove = true
		if p5.period_shots > 0 or not p5.has_ball:
			break
		if court.score[0] != s0:
			break
	check("AI attacked on its own", p5.period_shots > 0 or slammed)
	check("AI reached the iron", min_d < 8.0)
	check("AI slammed it", slammed)
	check("points on the board", court.score[0] > s0)
	print("DUNKPROBE: ", "ALL OK" if fails == 0 else "FAILURES=%d" % fails, " min_d_ft=", snappedf(min_d, 1.0))
	get_tree().quit()
