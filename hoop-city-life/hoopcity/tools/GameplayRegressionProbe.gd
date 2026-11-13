extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "1v1"
	var c := Court.new()
	add_child(c)
	await get_tree().process_frame
	var cpu: BallPlayer = c.players.filter(func(p): return p.team == 1)[0]
	c.awaiting_check = false
	c.restarting = false
	c.play_live = true
	c.give_ball(cpu)
	# Una presa durante una vecchia animazione non perde piu' il possessore.
	c.ball.dunk_drop = 0.8
	c.ball.attach(cpu)
	var ok := c.ball.dunk_drop == 0.0 and c.ball.holder == cpu
	c.must_clear = false
	cpu.global_position = c.hoop_for(1) + Vector2(-430, 100)
	# L'avversario deve costruire un'azione e arrivare a un tiro.
	Engine.time_scale = 5.0
	var before: int = c.total_attempts + c.total_makes
	await get_tree().create_timer(22.0).timeout
	var actions: int = c.total_attempts + c.total_makes - before
	ok = ok and actions > 0
	Engine.time_scale = 1.0
	c.queue_free()
	await get_tree().process_frame

	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = false
	var scrimmage := Court.new()
	add_child(scrimmage)
	await get_tree().process_frame
	scrimmage.jump_pending = false
	scrimmage.play_live = true
	scrimmage.restarting = false
	var handler: BallPlayer = scrimmage.players.filter(func(p): return p.team == 1)[0]
	scrimmage.give_ball(handler)
	handler.global_position = scrimmage.hoop_for(1) + Vector2(300.0, 0.0)
	Engine.time_scale = 5.0
	await get_tree().create_timer(22.0).timeout
	var scrim_actions: int = scrimmage.total_attempts + scrimmage.total_makes
	ok = ok and scrim_actions > 0
	if scrimmage.ball.holder != null:
		ok = ok and scrimmage.ball.holder.has_ball
	Engine.time_scale = 1.0
	scrimmage.queue_free()
	await get_tree().process_frame
	var scene = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	var court: Court = scene.court
	court.play_live = true
	court.restarting = false
	court.jump_pending = false
	var user: BallPlayer = court.user
	user.global_position = court.hoop_for(0) + Vector2(-400, 0)
	court.give_ball(user)
	scene._trick_tap_ms = -10000
	scene.joystick.output = Vector2(0, -1)
	scene._dribble_move()
	ok = ok and user.move_kind == "behind" and user.move_t > 0.0
	user.move_t = 0.0
	user.cooldown_move = 0.0
	scene._trick_tap_ms = 0
	scene.joystick.output = Vector2(0, 1)
	scene._dribble_move()
	ok = ok and user.move_kind == "hand_switch" and user.move_t > 0.0
	# Un canestro resta visibile nella retina prima della rimessa.
	var ball: Ball = court.ball
	ball.detach()
	ball.shooter = user
	ball.swish_clean = true
	ball.global_position = court.hoop_for(0)
	court._score_basket(ball)
	ok = ok and ball.dunk_drop > 0.0 and not court.play_live and ball.dunk_from == ball.dunk_to
	await get_tree().create_timer(0.35).timeout
	ok = ok and ball.dunk_drop > 0.0 and ball.h < Court.RIM_HEIGHT + 26.0 and ball.h > 0.0
	await get_tree().create_timer(0.5).timeout
	ok = ok and ball.dunk_drop == 0.0 and ball.holder != null

	# Le finestre di tiro e la rapidita' rispondono agli attributi.
	var low := ShotSystem.shot_windows(23.0, false, 35.0)
	var high := ShotSystem.shot_windows(23.0, false, 95.0)
	ok = ok and float(high["perfect"]) > float(low["perfect"])
	Game.profile["attrs"]["speed"] = 30
	var slow: float = Game.speed_factor()
	Game.profile["attrs"]["speed"] = 99
	ok = ok and Game.speed_factor() > slow
	print("GAMEPLAY_REGRESSION_OK=", ok, " CPU_actions=", actions, " scrimmage_actions=", scrim_actions)
	get_tree().quit(0 if ok else 1)
