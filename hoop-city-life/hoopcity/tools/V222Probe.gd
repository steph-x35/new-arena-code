extends Node2D
func _ready() -> void:
	await get_tree().process_frame
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "1v1"
	Game.profile["next_opponent"] = "Riverton"
	var ms := preload("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	for i in 900:
		await get_tree().process_frame
		if ms.court.awaiting_check: break
	ms.court.confirm_check()
	for i in 5:
		await get_tree().process_frame
	var u = ms.court.user
	var c = ms.court
	var ball = c.ball
	# D1: palla nella mano (palleggio normale)
	c.give_ball(u)
	u.move_t = 0.0
	u.fake_t = 0.0
	u.fake_locked = false
	for i in 30:
		await get_tree().process_frame
	# contratto v2.22: posizione ESATTA del palmo (x stabile hd*h*0.30, y dal rimbalzo)
	var dx: float = absf(ball.global_position.x - (u.global_position.x + Vector2(Avatar.palms.get(u.get_instance_id(), Vector2.ZERO)).x))
	var dh: float = absf(ball.h - maxf(-Vector2(Avatar.palms.get(u.get_instance_id(), Vector2.ZERO)).y, 4.0))
	print("D1 in_mano=", dx < 2.0 and dh < 6.0, " dx=", dx, " dh=", dh)  # dh<6: lag 1 frame fisica-disegno
	# D2: la mano si muove (il palleggio anima la palla, non e' ferma)
	var hmin: float = ball.h
	var hmax: float = ball.h
	for i in 70:
		await get_tree().process_frame
		hmin = minf(hmin, ball.h)
		hmax = maxf(hmax, ball.h)
	print("D2 oscillazione=", hmax - hmin > 12.0, " range=", int(hmin), "-", int(hmax))
	# D3: spin = la palla avvolge (va oltre il lato opposto)
	u.cooldown_move = 0.0
	var x0: float = ball.global_position.x - u.global_position.x
	u.do_move("spin")
	var flipped := false
	for i in 30:
		await get_tree().process_frame
		var xr: float = ball.global_position.x - u.global_position.x
		if x0 > 0.0 and xr < -10.0:
			flipped = true
	print("D3 spin_wraps=", flipped)
	print("V222_OK=", dx < 2.0 and dh < 6.0 and (hmax - hmin) > 12.0 and flipped)
	get_tree().quit()
