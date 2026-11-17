extends Node
func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = false
	var game = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.set_process(false)
	var c: Court = game.court
	c.jump_pending = false
	c.play_live = true
	c.set_process(false)
	c.set_physics_process(false)
	c.ball.set_physics_process(false)
	for p in c.players:
		p.set_physics_process(false)
		for brain in p.get_children(): brain.set_physics_process(false)
		if p.team == 1: p.global_position = Vector2(0, 450)
	var u: BallPlayer = c.user
	var hoop: Vector2 = c.hoop_for(0)
	u.global_position = hoop + Vector2(165, 0)
	u.move_input = Vector2.LEFT
	c.give_ball(u)
	game._shoot_down()
	print("LAYUP_START ", u.layup_t, " dunk ", u.dunking, " ball ", u.has_ball, " pos ", u.global_position)
	var ok: bool = u.layup_t > 0.0 and not u.dunking and u.has_ball
	await get_tree().create_timer(0.3).timeout
	print("LAYUP_RELEASE ", c.ball.shot_result_pending, " bank ", c.ball.layup_bank, " holder ", u.has_ball, " live ", c.play_live)
	ok = ok and c.ball.shot_result_pending and c.ball.layup_bank and not u.has_ball
	# Force a made bank shot and step the real ball and collision routines.
	c.play_live = true
	c.give_ball(u)
	var aim: Vector2 = hoop + Vector2(signf(hoop.x) * 50.0, 0)
	c.ball.shoot(u.global_position + Vector2(0, -50), aim, 520.0, 0.65, true, u)
	c.ball.layup_bank = true
	u.has_ball = false
	var banked := false
	for frame in 100:
		c.ball._physics_process(1.0 / 60.0)
		if not c.ball.layup_bank: banked = true
		if c.ball.dunk_drop > 0.0: break
	print("LAYUP_RESULT banked=", banked, " score=", c.score, " h=", c.ball.h, " pos=", c.ball.global_position, " drop=", c.ball.dunk_drop)
	ok = ok and banked and c.score[0] == 2 and c.ball.dunk_drop > 0.0
	game.queue_free()
	print("LAYUP_OK=", ok)
	get_tree().quit(0 if ok else 1)
