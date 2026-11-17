extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["team_practice_day"] = int(Game.profile.get("day", 1))
	Game.profile["team_practice_stage"] = "2v2"
	Game.profile["next_match_mode"] = "team_practice"
	Game.profile["match_is_fixture"] = false
	var game = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game._on_finished({})
	var session: Node = null
	for child in game.get_children():
		if child.has_method("_start_free_throws"): session = child
	var ok: bool = session != null
	if session == null:
		print("TEAM_SESSION_OK=false missing session")
		get_tree().quit(1)
		return
	session.set_physics_process(false)
	game.court.ball.set_physics_process(false)
	ok = ok and game.court.players.size() == 10 and session.attack.size() == 5 and session.defense.size() == 5
	ok = ok and session.PLAYS.size() == 5 and session.mode == "choose"
	# Actual passes, cut, return pass and final pass, all on the same court.
	session._start_play(2)
	session._action_down()
	game.court.ball._physics_process(2.0)
	session._step_pass()
	ok = ok and session.play_step == "cut" and session.passer.has_ball
	session.user.global_position = session.destination
	session._physics_process(0.01)
	game.court.ball._physics_process(2.0)
	session._step_pass()
	ok = ok and session.play_step == "pass_again" and session.user.has_ball
	session._action_down()
	game.court.ball._physics_process(2.0)
	session._step_pass()
	ok = ok and session.completed == 1 and session.mode == "choose"
	# One shot each: rotate the real five-player line and enable finish only
	# after the whole line has completed its turns.
	session._start_free_throws()
	for i in 5:
		for tick in 200:
			if session.ft_state != "walking": break
			session._step_free_throws(0.05)
		ok = ok and session.ft_state in ["user_ready", "npc_ready"]
		session._shoot_free_throw(true)
		session._step_free_throws(1.1)
		session._step_free_throws(0.6)
		ok = ok and session.ft_shots == i + 1
	ok = ok and session.finish.visible and session.shot_queue[0] == session.user
	ok = ok and game.court.get_parent() == game
	game.queue_free()
	print("TEAM_SESSION_OK=", ok)
	get_tree().quit(0 if ok else 1)
