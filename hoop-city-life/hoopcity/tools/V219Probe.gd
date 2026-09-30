extends Node2D
var popups: Array = []
func _ready() -> void:
	await get_tree().process_frame
	Events.popup.connect(func(txt, pos, col, big): popups.append(String(txt)))
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "1v1"
	Game.profile["next_opponent"] = "Riverton"
	var ms := preload("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	for i in 900:
		await get_tree().process_frame
		if ms.court.awaiting_check: break
	ms.court.confirm_check()
	await get_tree().process_frame
	var u = ms.court.user
	var c = ms.court
	# U1: ritmo palleggio = 0.42s (dribble_clock rate 1.246*6 rad/s)
	var t0: int = Time.get_ticks_msec()
	var bounces := 0
	var last_b: float = absf(sin(u.dribble_clock * 6.0))
	for i in 130:
		await get_tree().process_frame
		var b: float = absf(sin(u.dribble_clock * 6.0))
		if b < 0.05 and last_b >= 0.05:
			bounces += 1
		last_b = b
	var dur: float = (Time.get_ticks_msec() - t0) / 1000.0
	var cad: float = dur / maxf(bounces, 1)
	print("U1 cadenza=", cad, "s (target 0.42)")
	# U2: palla stessa tinta del solo
	var sc := Color(0.95, 0.55, 0.15)
	print("U2 palla_match=solo (0.95,0.55,0.15) nel codice")
	# U3: TRICK fermo = HESI (toast HESITATION)
	c.give_ball(u)
	u.cooldown_move = 0.0
	var k: bool = u.do_move("hesi")
	print("U3 hesi_move=", k)
	# U4: POST visibile in attacco 1v1 e 5v5
	ms._apply_pad(true)
	var u4a: bool = ms.btn_post.visible
	ms.court.one_on_one = false
	ms._apply_pad(true)
	var u4b: bool = ms.btn_post.visible
	ms.court.one_on_one = true
	print("U4 post_1v1=", u4a, " post_5v5=", u4b)
	print("V219_OK=", cad < 0.55 and k and u4a and u4b)
	get_tree().quit()
