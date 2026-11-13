extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	var ok := true
	for mode in ["1v1", "full"]:
		Game.profile["next_match_mode"] = mode
		Game.profile["match_is_fixture"] = false
		var c := Court.new()
		add_child(c)
		await get_tree().process_frame
		c.set_physics_process(false)
		var p: BallPlayer = c.user
		p.dribble_phase = 0.8
		p.hand_side = 1.0
		p.move_t = 0.0
		var offset: Dictionary = p.dribble_ball_offset()
		var h: float = 64.0 * p.height_f
		ok = ok and absf(float(offset["x"]) - h * 0.30) < 0.01
		ok = ok and absf(float(offset["h"]) - (absf(sin(0.8 * 1.15)) * h * 0.55 + Court.BALL_R)) < 0.01
		p.move_kind = "hand_switch"
		p.move_t = p.move_duration * 0.5
		offset = p.dribble_ball_offset()
		ok = ok and absf(float(offset["x"])) < 0.01 and absf(float(offset["h"]) - h * 0.26) < 0.01
		var ball: Ball = c.ball
		ball.set_physics_process(false)
		ball.detach()
		ball.practice_shot = true
		ball.shot_result_pending = true
		ball.global_position = Vector2(Court.COURT_W * 0.5 - 25.0, 200.0)
		ball.h = 40.0
		ball.vh = -100.0
		ball.vel = Vector2(300.0, 30.0)
		for frame in 400:
			ball._physics_process(1.0 / 60.0)
		ok = ok and absf(ball.global_position.x) <= Court.COURT_W * 0.5 - Court.BALL_R + 0.01
		ok = ok and ball.h == 0.0 and ball.vel.length() < 1.0 and ball.holder == null and not ball.shot_result_pending
		c._deadball_watchdog(4.0)
		ok = ok and ball.holder == null
		c.queue_free()
		await get_tree().process_frame
	var duel = load("res://src/scenes/DuelScene.tscn").instantiate()
	add_child(duel)
	await get_tree().process_frame
	var edge: Array = duel._bound_loose_ball(Vector2(2000.0, 20.0), Vector2(300.0, 20.0))
	ok = ok and edge[0].x <= Court.COURT_W * 0.5 - duel.BALL_R and edge[1].x == 0.0
	var previous: int = int(Settings.get_v("floor_style", 0))
	Settings.set_v("floor_style", 1)
	ok = ok and CourtStage.floor_colours()["base"] == CourtStage.floor_colours(1)["base"]
	ok = ok and CourtStage.floor_colours(0)["base"] != CourtStage.floor_colours()["base"]
	Settings.set_v("floor_style", previous)
	print("DRIBBLE_PHYSICS_OK=", ok)
	get_tree().quit(0 if ok else 1)
