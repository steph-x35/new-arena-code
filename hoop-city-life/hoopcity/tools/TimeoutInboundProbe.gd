extends Node2D

func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "full"
	var c := Court.new()
	add_child(c)
	await get_tree().process_frame
	c.set_process(false)
	c.set_physics_process(false)
	c.jump_pending = false
	c._inbound(1)
	var ok: bool = c.restarting and not c.play_live and c.inbound_wait >= 2.0 and c.ball.holder == c._inbounder
	c.restarting = false
	c.inbound_wait = 0.0
	c.give_ball(c.user)
	c.play_live = true
	var started: bool = c.call_timeout(0)
	var before: float = c.user.global_position.distance_to(c.seat_world(0, 0))
	c._process_bench_and_timeouts(1.0)
	var after: float = c.user.global_position.distance_to(c.seat_world(0, 0))
	ok = ok and started and after < before and not c.play_live
	c.timeout_active = 0.0
	c._resume_after_timeout()
	ok = ok and c.restarting and not c.play_live and c.inbound_wait >= 2.0 and c.ball.holder == c._inbounder
	print("TIMEOUT_INBOUND_OK=", ok)
	get_tree().quit(0 if ok else 1)
