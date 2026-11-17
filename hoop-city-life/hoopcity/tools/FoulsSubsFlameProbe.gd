extends Node

var fouls_seen := 0
func _on_foul() -> void:
	fouls_seen += 1

func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = true
	var c := Court.new()
	add_child(c)
	await get_tree().process_frame
	c.set_physics_process(false)
	c.set_process(false)
	for p in c.players:
		p.set_physics_process(false)
		for brain in p.get_children(): brain.set_physics_process(false)
	c.ball.set_physics_process(false)
	Events.foul_called.connect(_on_foul)
	var opponent: BallPlayer = c.players[5]
	c.call_foul(opponent, c.user, 0)
	var ok: bool = fouls_seen == 1 and not c.ft_active and c.inbound_wait > 0.0
	c.call_foul(opponent, c.user, 3)
	ok = ok and c.ft_active and c.ft_left == 3 and c.ft_shooter == c.user
	var locations: Array = []
	for p in c.players:
		if p != c.user: locations.append(p.global_position)
	ok = ok and locations.size() == 9 and locations[0] != locations[1]
	c._on_ft_result(false)
	ok = ok and c.ft_active and c.ft_left == 2
	c.ft_left = 1
	c.ball.is_free_throw = true
	c.ball.rattled = true
	c.ball.live = true
	c.ball.shooter = c.user
	c.resolve_missed_shot(c.ball)
	ok = ok and not c.ft_active and c.play_live and c.ball.holder == null and c.ball.live
	c.call_foul(opponent, c.user, 2)
	c.ft_left = 1
	c.ball.is_free_throw = true
	c.ball.rattled = false
	c.resolve_missed_shot(c.ball)
	ok = ok and not c.ft_active and c.restarting and c.possession == 1
	# During a substitution, the departing player must not receive the inbound.
	c.user_on_court = false
	c.user.leaving = true
	c._inbound(0)
	ok = ok and c._inbounder != c.user and c._inbound_receiver != c.user
	c.user.leaving = false
	c.user_on_court = true
	c.user_heat = true
	c.ball.shoot(Vector2.ZERO, c.hoop_for(0), 420.0, 0.8, false, c.user)
	c.user_heat = false
	c._physics_process(0.0)
	ok = ok and c.ball.shot_flame and c.ball.flame
	c.ball.attach(opponent)
	ok = ok and not c.ball.shot_flame
	Events.foul_called.disconnect(_on_foul)
	c.queue_free()
	print("FOULS_SUBS_FLAME_OK=", ok)
	get_tree().quit(0 if ok else 1)
