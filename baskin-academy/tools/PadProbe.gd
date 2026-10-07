extends Node2D
## DEV ONLY: the attack/defence pad must follow the POSSESSION, never the ball.
var ms: Node
var court: Node
var fails := 0
func check(nm: String, cond: bool) -> void:
	print(("  ok: " if cond else "  FAIL: ") + nm)
	if not cond:
		fails += 1
func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["baskin_role"] = 5
	ms = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	court = ms.get_node("Court")
	check("no pre-match card", ms.get("intro_panel") == null or not ms.get("intro_panel"))
	# my ball, live
	court.play_live = true
	court.restarting = false
	court.give_ball(court.players[0])
	await get_tree().create_timer(0.6).timeout
	check("attack pad with my ball", ms.get("_phase_offence") == true)
	# opponents' ball, live
	court.give_ball(court.pivot_player(1) if court.pivot_player(1) != null else court.players[5])
	await get_tree().create_timer(0.6).timeout
	check("defence pad with their ball", ms.get("_phase_offence") == false)
	# THEIR ball, dead: inbound for them (this used to flip to attack)
	court.ball.detach()
	court.ball.holder = null
	for p in court.players:
		p.has_ball = false
	court.possession = 1
	court.play_live = false
	court.restarting = true
	await get_tree().create_timer(0.8).timeout
	check("defence pad on THEIR dead ball", ms.get("_phase_offence") == false)
	# a loose ball during MY possession. Nobody must reach it while we wait,
	# otherwise an AI legitimately picks it up and the pad follows the new
	# handler instead of the possession.
	court.restarting = false
	court.possession = 0
	court.play_live = true
	for p in court.players:
		p.global_position = Vector2(-900.0 if p.team == 0 else 900.0, 380.0 * (1.0 if p.role % 2 == 0 else -1.0))
		p.velocity = Vector2.ZERO
	court.ball.global_position = Vector2.ZERO
	await get_tree().create_timer(0.8).timeout
	var h_loose: BallPlayer = court.ball_handler()
	print("   loose-ball state: handler=", ("none" if h_loose == null else str(h_loose.role) + "/" + str(h_loose.team)),
		" possession=", court.possession)
	check("attack pad on my loose ball", ms.get("_phase_offence") == true)
	print("PADPROBE: ", "ALL OK" if fails == 0 else "FAILURES=%d" % fails)
	get_tree().quit()
