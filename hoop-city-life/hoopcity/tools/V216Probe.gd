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
	var h: Vector2 = c.hoop_for(u.team)
	# F1: fade da POST -> fade_t animazione
	c.give_ball(u)
	u.global_position = h + Vector2(-240, 40)
	u.posting = true
	u.shot_charge = 0.5
	u.shot_ideal = 0.5
	ms._post_shoot_hop(u)
	u.do_shot_release()
	var f1: bool = u.fade_t > 0.4 and not u.posting
	print("F1 fade_anim=", f1, " fade_t=", u.fade_t)
	# F2: COMBO stick indietro -> hop + FADEAWAY popup
	for i in 40:
		await get_tree().process_frame
	c.give_ball(u)
	u.global_position = h + Vector2(-300, 40)
	u.posting = false
	u.move_input = Vector2(-1, 0)   # stick VIA dal ferro
	u.shot_charge = 0.5
	u.shot_ideal = 0.5
	popups.clear()
	ms._shoot_up()
	await get_tree().process_frame
	var f2: bool = "FADEAWAY" in popups and u.fade_t > 0.0
	print("F2 combo_fade=", f2, " popups=", popups)
	u.move_input = Vector2.ZERO
	# F3: COMBO TRICK -> TIRA = PULL-UP popup
	for i in 40:
		await get_tree().process_frame
	c.give_ball(u)
	u.global_position = h + Vector2(-350, 0)
	u.velocity = Vector2.ZERO
	ms._last_move_ms = Time.get_ticks_msec()   # come dopo un TRICK
	popups.clear()
	ms._shoot_down()          # press: registra la combo PULL-UP
	u.shot_charge = 0.5       # (meter caricato istantaneo nel probe)
	u.shot_ideal = 0.5
	ms._shoot_up()
	await get_tree().process_frame
	var f3: bool = "PULL-UP" in popups
	print("F3 pullup=", f3, " popups=", popups)
	# F4: folla match piu' ALTA di prima (caos arena)
	Sfx.set_match_live(true)
	Sfx.set_hype(0.5)
	await get_tree().create_timer(0.7).timeout
	var f4: bool = Sfx.crowd.playing and Sfx.crowd.volume_db > -11.0
	print("F4 crowd=", f4, " playing=", Sfx.crowd.playing, " db=", Sfx.crowd.volume_db)
	print("V216_OK=", f1 and f2 and f3 and f4)
	get_tree().quit()
