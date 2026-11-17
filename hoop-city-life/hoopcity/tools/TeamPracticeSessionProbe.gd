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
	var voices: AudioStreamPlayer = game.get_node_or_null("PracticeVoices")
	var audio_ok: bool = voices != null and voices.playing and voices.bus == "Voice" and voices.stream is AudioStreamOggVorbis and voices.stream.loop
	var bg = game.get_node_or_null("PracticeBackground")
	var background_ok: bool = bg != null and bg.actors.size() == 6
	game.court.pnr_screener = game.court.players[1]
	game.court.pnr_screening = true
	game._on_finished({})
	var session: Node = null
	for child in game.get_children():
		if child.has_method("_start_free_throws"): session = child
	var ok: bool = session != null and background_ok and audio_ok and game.court.pnr_screener == null
	ok = ok and voices.playing and game.get_node_or_null("PracticeVoices") == voices
	if session == null:
		print("TEAM_SESSION_OK=false missing session")
		get_tree().quit(1)
		return
	session.set_physics_process(false)
	game.court.ball.set_physics_process(false)
	ok = ok and game.court.players.size() == 10 and session.attack.size() == 5 and session.defense.size() == 5
	ok = ok and session.PLAYS.size() == 5 and session.mode == "choose"
	var numbers := {}
	for p in game.court.players:
		ok = ok and not numbers.has(p.jersey_num)
		numbers[p.jersey_num] = true
		if p != session.user: ok = ok and p.has_meta("practice_colour")
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
	ok = ok and session.play_step == "finish_shot" and session.completed == 0
	session._physics_process(1.4)
	ok = ok and session.completed == 1 and session.mode == "choose"
	# The human may finish a drill with their own shot or a dunk.
	session._start_play(0)
	game.court.give_ball(session.user)
	session.play_step = "pass_again"
	session.user.global_position = Vector2(300, 0)
	session._play_shoot_down()
	session.play_charge = session.user.shot_ideal
	session._play_shoot_up()
	ok = ok and session.finish_made and session.finish_by_user and not session.finish_dunk
	session._physics_process(1.4)
	ok = ok and session.completed == 2 and session.mode == "choose"
	session._start_play(1)
	game.court.give_ball(session.user)
	session.play_step = "pass_again"
	session.user.global_position = game.court.hoop_for(0) + Vector2(-60, 0)
	session._play_shoot_down()
	ok = ok and session.finish_dunk
	session._physics_process(1.4)
	ok = ok and session.completed == 3
	# One shot each: rotate the real five-player line and enable finish only
	# after the whole line has completed its turns.
	session._start_free_throws()
	for i in 5:
		for tick in 200:
			if session.ft_state != "walking": break
			session._step_free_throws(0.05)
		ok = ok and session.ft_state in ["user_ready", "npc_ready"]
		if session.shot_queue[0] == session.user:
			session._action_down()
			session._step_free_throws(0.5)
			ok = ok and session.meter.visible and session.user.shot_charge > 0.0
			session._action_up()
			ok = ok and session.ft_made and session.ft_end == game.court.hoop_for(0)
		else:
			session._shoot_free_throw(true)
		session._step_free_throws(1.1)
		session._step_free_throws(0.6)
		ok = ok and session.ft_state == "rebound"
		if session.shot_queue[0] == session.user:
			session.user.global_position = session.ft_land
			session._step_free_throws(0.05)
			ok = ok and session.ft_state == "pass_ball"
			session._action_down()
		else:
			session._step_free_throws(5.0)
			session._step_free_throws(0.05)
		game.court.ball._physics_process(2.0)
		session._step_free_throws(0.05)
		ok = ok and session.ft_shots == i + 1
	ok = ok and Vector2(session.ambient_balls[0]["pos"]).x < 0.0
	ok = ok and session.finish.visible and session.shot_queue[0] == session.user
	ok = ok and game.court.get_parent() == game
	game.queue_free()
	print("TEAM_SESSION_OK=", ok)
	get_tree().quit(0 if ok else 1)
