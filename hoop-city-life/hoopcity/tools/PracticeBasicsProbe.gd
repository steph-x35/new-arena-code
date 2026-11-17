extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["team_practice_stage"] = "2v2"
	Game.profile["next_match_mode"] = "team_practice"
	Game.profile["match_is_fixture"] = false
	var scene = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	scene.set_process(false)
	var c: Court = scene.court
	c.set_process(false)
	c.set_physics_process(false)
	for p in c.players:
		p.set_physics_process(false)
		for brain in p.get_children(): brain.set_physics_process(false)
	var ok: bool = c.team_size == 2 and c.hoops[0] == c.hoops[1] and c.play_live
	ok = ok and scene.intro_panel == null and scene.tip_left == 0.0 and c._refs.is_empty()
	for p in c.players: ok = ok and p.global_position.x >= 0.0
	var teammate: BallPlayer = c.players[1]
	var defender: BallPlayer = c.players[2]
	var brain: AIBrain = teammate.get_child(0)
	c.give_ball(c.user)
	brain.begin_screen(c.user)
	brain.set_screen_target(defender)
	var direction: Vector2 = (c.user.global_position - defender.global_position).normalized()
	teammate.global_position = defender.global_position + direction * 70.0
	brain._do_pnr(0.1)
	ok = ok and brain.screen_planted and teammate.velocity == Vector2.ZERO
	var set_at: Vector2 = teammate.global_position
	defender.global_position += Vector2(200, 140)
	brain._do_pnr(0.5)
	ok = ok and teammate.global_position == set_at and teammate.move_input == Vector2.ZERO
	brain.begin_roll()
	ok = ok and not brain.screen_planted and brain.role == "roller"
	c.play_live = true
	c.give_ball(c.user)
	var distance: float = c.user.global_position.distance_to(teammate.global_position)
	c.user.do_pass(teammate)
	ok = ok and c.ball._pass_duration <= maxf(distance / 700.0, 0.12) + 0.01
	scene.queue_free()
	print("PRACTICE_BASICS_OK=", ok)
	get_tree().quit(0 if ok else 1)
