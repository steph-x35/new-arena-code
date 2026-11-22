extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = false
	var c := Court.new()
	add_child(c)
	await get_tree().process_frame
	c.set_physics_process(false)
	c.ball.set_physics_process(false)
	for player in c.players: player.set_physics_process(false)
	var ball: Ball = c.ball
	var shooter: BallPlayer = c.user
	shooter.has_ball = false
	# A long analytic airball hits the floor and must leave the analytic arc,
	# rise again, and slow down instead of being recomputed into the corner.
	ball.shoot(Vector2(100, 0), Vector2(500, 230), 300.0, 0.7, false, shooter)
	var hit := false
	var rose := false
	for i in 600:
		ball._physics_process(1.0 / 60.0)
		if ball.h == 0.0 and ball.vh > 100.0:
			hit = true
			if ball._ana: break
		if hit and ball.h > 20.0: rose = true
	var ok: bool = hit and rose and not ball._ana and ball.h == 0.0 and ball.vel.length() < 1.0
	# Edge contact sends a loose practice ball inward, not along both edges.
	ball.detach()
	ball.practice_shot = true
	ball.shot_result_pending = false
	ball.global_position = Vector2(Court.COURT_W * 0.5 - Court.BALL_R - 1, 0)
	ball.h = 60.0
	ball.vh = -50.0
	ball.vel = Vector2(300, 20)
	ball._physics_process(1.0 / 60.0)
	ok = ok and ball.vel.x < 0.0 and absf(ball.global_position.x) <= Court.COURT_W * 0.5 - Court.BALL_R
	# Pickup is the only way to end a physical rebound in a match.
	c.is_fixture = true
	ball.shot_result_pending = true
	ball.practice_shot = false
	ball.shooter = shooter
	ball.h = 0.0
	ball.vh = 220.0
	c.resolve_missed_shot(ball)
	ok = ok and ball.holder == null and ball.live and ball.vh == 220.0
	# A made shot must begin at the rim without teleporting upward, then
	# visibly descend through the net before reaching the floor.
	ball.dunk_from = c.hoop_for(0)
	ball.dunk_to = ball.dunk_from
	ball.global_position = ball.dunk_from
	ball.h = Court.RIM_HEIGHT
	ball.dunk_drop = 1.0
	ball.live = false
	ball._physics_process(1.0 / 60.0)
	ok = ok and ball.h <= Court.RIM_HEIGHT and ball.h > Court.RIM_HEIGHT - 2.0
	for i in 12: ball._physics_process(1.0 / 60.0)
	ok = ok and ball.h < Court.RIM_HEIGHT - 10.0 and ball.h > Court.RIM_HEIGHT - 45.0
	for i in 40: ball._physics_process(1.0 / 60.0)
	ok = ok and ball.dunk_drop == 0.0 and ball.h == 0.0
	# A restrained bend follows the entry direction; the rim remains fixed.
	var still: Vector2 = HoopArt.net_knot(Vector2.ZERO, 22.0, 8.0, 0.0, 0.0, 0.0, -1.0, 0.7, 0.0, Vector2(-1, 0))
	var right: Vector2 = HoopArt.net_knot(Vector2.ZERO, 22.0, 8.0, 0.0, 0.0, 0.0, -1.0, 0.7, 0.0, Vector2(0.7, 1))
	var left: Vector2 = HoopArt.net_knot(Vector2.ZERO, 22.0, 8.0, 0.0, 0.0, 0.0, -1.0, 0.7, 0.0, Vector2(0.7, -1))
	var anchored: Vector2 = HoopArt.net_knot(Vector2.ZERO, 22.0, 8.0, 0.0, 0.0, 0.0, -1.0, 0.0, 0.0, Vector2(0.7, 1))
	var relaxed: Vector2 = HoopArt.net_knot(Vector2.ZERO, 22.0, 8.0, 0.0, 0.0, 0.0, -1.0, 0.7, 0.0, Vector2(2.0, 1))
	ok = ok and right.x > left.x and right.x - left.x < 16.0 and anchored.is_equal_approx(Vector2(22, 0)) and relaxed.is_equal_approx(still)
	ball.dunk_drop = 1.0 - 0.11 * 1.7
	ball.h = Court.RIM_HEIGHT - 18.0
	ball.net_entry_velocity = -320.0
	ok = ok and ball.net_contact().is_equal_approx(Vector2(0.5, -1.0))
	c.queue_free()
	print("BALL_BOUNCE_OK=", ok, " hit=", hit, " rose=", rose)
	get_tree().quit(0 if ok else 1)
