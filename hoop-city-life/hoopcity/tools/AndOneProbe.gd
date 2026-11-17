extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = false
	var c := Court.new()
	add_child(c)
	await get_tree().process_frame
	c.set_process(false)
	c.set_physics_process(false)
	c.ball.set_physics_process(false)
	for p in c.players:
		p.set_physics_process(false)
		for brain in p.get_children(): brain.set_physics_process(false)
	var shooter: BallPlayer = c.user
	var defender: BallPlayer = c.players[5]
	var hoop: Vector2 = c.hoop_for(0)
	# A made two counts once, then gives exactly one free throw.
	shooter.global_position = hoop + Vector2(-200, 0)
	c.ball.shoot(shooter.global_position, hoop, 420.0, 0.8, true, shooter)
	c._begin_shooting_foul(defender, shooter, 2)
	var ok: bool = not c.play_live and c.pending_foul_shots == 2
	c._score_basket(c.ball)
	ok = ok and c.score[0] == 2 and c.box["fga"] == 1 and c.box["fgm"] == 1
	await get_tree().create_timer(0.8).timeout
	ok = ok and c.ft_active and c.ft_left == 1 and c.ft_shooter == shooter
	c._on_ft_result(true)
	ok = ok and c.score[0] == 3 and not c.ft_active and c.possession == 1
	# A made three likewise gives just one, even if the shooter is moved later.
	shooter.global_position = hoop + Vector2(-500, 0)
	c.ball.shoot(shooter.global_position, hoop, 420.0, 0.8, true, shooter)
	c._begin_shooting_foul(defender, shooter, 3)
	c._score_basket(c.ball)
	await get_tree().create_timer(0.8).timeout
	ok = ok and c.score[0] == 6 and c.ft_left == 1 and c.box["tpa"] == 1 and c.box["tpm"] == 1
	c._on_ft_result(false)
	# A missed shot on a shooting foul counts no FGA and awards 2 or 3.
	var fga: int = c.box["fga"]
	for shots in [2, 3]:
		c.ball.shoot(shooter.global_position, hoop, 420.0, 0.8, false, shooter)
		c._begin_shooting_foul(defender, shooter, shots)
		c.resolve_missed_shot(c.ball)
		ok = ok and c.ft_active and c.ft_left == shots and c.box["fga"] == fga and c.pending_foul_shooter == null
		c._end_free_throws()
	c.queue_free()
	print("AND_ONE_OK=", ok)
	get_tree().quit(0 if ok else 1)
