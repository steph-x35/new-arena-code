extends Node2D
## DEV ONLY. Loads the full 5v5 indoor MatchScene headless, skips the broadcast
## intro card (which normally waits for a tap), drives the user slot with an
## AIBrain and reports whether the game actually runs.
##   godot --headless --path . res://tools/MatchTest.tscn [seconds]

var ms: Node

func _ready() -> void:
	Engine.time_scale = 3.0
	var secs := 25.0
	var args := OS.get_cmdline_args()
	for i in args.size():
		if String(args[i]).is_valid_float():
			secs = float(args[i])
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = false
	Game.profile["next_opponent"] = "Eastport Dockers"
	Game.profile["next_home"] = true
	Game.profile["quarter_seconds"] = 120.0
	Game.profile["baskin_role"] = 2
	Game.set_team_kit(1, Game.club_kit("Eastport Dockers"))
	var ps: PackedScene = load("res://src/match/MatchScene.tscn")
	ms = ps.instantiate()
	add_child(ms)
	await get_tree().process_frame
	# Skip the intro card: it waits for the player to tap it.
	ms.set("intro_left", 0.0)
	# role comes from the profile now (RolePicker screen); the in-match
	# picker is skipped.
	var court: Node = ms.get_node("Court")
	print("ROLES t0 ", court.players.filter(func(p): return p.team == 0).map(func(p): return [p.role, p.variant]),
		" t1 ", court.players.filter(func(p): return p.team == 1).map(func(p): return [p.role, p.variant]))
	print("MODE full  teams ", court.players.size(), "  fixture ", court.is_fixture)
	court.user.is_user = false
	var brain: Node = load("res://src/match/AIBrain.gd").new()
	court.user.add_child(brain)
	brain.setup(court.user, court)
	Events.toast.connect(func(t): print("[toast] ", t))
	await _run(secs)

func _run(secs: float) -> void:
	var t := 0.0
	while t < secs:
		var c: Node = ms.get_node_or_null("Court")
		if c != null and c.awaiting_check and t > 2.0:
			c.confirm_check()
		await get_tree().create_timer(0.05).timeout
		t += 0.05
		if int(t) != int(t - 0.05):
			print("t=%4.1f live=%s poss=%d clock=%.1f score=%s" % [
				t, c.play_live, c.possession, c.game_clock, str(c.score)])
	var c: Node = ms.get_node("Court")
	print("MATCH TEST OK  score ", c.score, " attempts ", c.total_attempts,
		" makes ", c.total_makes, " quarter ", c.quarter, " finished ", c.finished)
	get_tree().quit()
