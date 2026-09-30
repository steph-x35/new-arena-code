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
	# H1: finestra verde piu' larga con heat
	var w0: Dictionary = ShotSystem.shot_windows(10.0, false)
	var w1: Dictionary = ShotSystem.shot_windows(10.0, true)
	var h1: bool = float(w1["perfect"]) > float(w0["perfect"]) * 1.15
	print("H1 window=", h1, " pw=", float(w0["perfect"]), "->", float(w1["perfect"]))
	# H2: 3 canestri (timing perfetto = verde 100%) -> ON FIRE
	c.give_ball(u)
	u.global_position = h + Vector2(-90, 0)
	u.velocity = Vector2.ZERO
	for t in 3:
		u.shot_charge = 0.5
		u.shot_ideal = 0.5
		popups.clear()
		c.attempt_shot(u, 0.0)
		await get_tree().process_frame
		for i in 50:
			await get_tree().process_frame
			if c.awaiting_check:
				c.confirm_check()
				break
		c.give_ball(u)
		u.velocity = Vector2.ZERO
	print("H2 heat=", c.user_heat, " streak=", c.user_streak, " popup=", "ON FIRE!" in popups)
	# H3: un errore spegne (rosso = mai)
	c.give_ball(u)
	u.global_position = h + Vector2(-400, 0)
	u.shot_charge = 0.5
	u.shot_ideal = 0.5
	popups.clear()
	c.attempt_shot(u, 0.30)   # err enorme = rosso = mai
	await get_tree().process_frame
	print("H3 cold=", not c.user_heat and c.user_streak == 0, " popup=", "COLD" in popups)
	print("V221_OK=", h1 and c.user_streak == 0 and not c.user_heat)
	get_tree().quit()
