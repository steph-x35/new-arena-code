extends Node

func _ready() -> void:
	var ok := BallPlayer.user_steal_outcome(1, 0.09) == "steal" and BallPlayer.user_steal_outcome(1, 0.10) == "miss"
	ok = ok and BallPlayer.user_steal_outcome(2, 0.29) == "steal" and BallPlayer.user_steal_outcome(2, 0.30) == "miss"
	ok = ok and BallPlayer.user_steal_outcome(3, 0.49) == "steal" and BallPlayer.user_steal_outcome(3, 0.50) == "foul"
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = false
	var c := Court.new()
	add_child(c)
	await get_tree().process_frame
	c.set_physics_process(false)
	c.jump_pending = false
	for p in c.players:
		p.set_physics_process(false)
		for brain in p.get_children():
			if brain is Node: brain.set_physics_process(false)
		if p.team == 1: p.global_position = Vector2(0, 600)
	c.ball.set_physics_process(false)
	c._inbound(0)
	var target: BallPlayer = c.user
	c.inbound_elapsed = 2.0
	c._finish_inbound(target)
	var flight: float = c.ball._pass_duration
	target.global_position += Vector2(130, 50)
	c.ball._physics_process(flight * 0.5)
	ok = ok and c.ball.h > 50.0 and c.ball.holder == null
	c.ball._physics_process(flight * 0.5)
	ok = ok and c.ball.global_position.distance_to(target.global_position) < 1.0
	await get_tree().create_timer(flight + 0.1).timeout
	ok = ok and c.ball.holder == target
	# Loose ball under the player's feet is picked up without pressing shoot.
	c.ball.detach()
	target.has_ball = false
	c.ball.global_position = target.global_position
	c.ball.h = 5.0
	c.ball.shot_result_pending = false
	c.ball.shooter = null
	c.ball.dunk_drop = 0.0
	c._physics_process(0.01)
	ok = ok and c.ball.holder == target
	# The screener is identifiable from the beginning of the play.
	ok = ok and c.start_pick_and_roll(target) and c.pnr_screener != null
	target.user_steal_attempts = 2
	c._inbound(1)
	ok = ok and target.user_steal_attempts == 0
	c.queue_free()
	await get_tree().process_frame
	Game.profile["hunger"] = 50.0
	Game.profile["energy"] = 50.0
	Game.profile["health"] = 50.0
	Items.add("avocado", 1)
	var msg: String = Items.consume("avocado")
	ok = ok and msg != "" and Game.profile["energy"] > 50.0 and Game.profile["health"] > 50.0
	ok = ok and FoodReward.overlay != null
	FoodReward._close()
	var w40 := ShotSystem.shot_windows(23.0, false, 40.0)
	var w99 := ShotSystem.shot_windows(23.0, false, 99.0)
	ok = ok and float(w99["perfect"]) > float(w40["perfect"])
	print("MATCH_IMPROVEMENTS_OK=", ok)
	get_tree().quit(0 if ok else 1)
