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
	var h: Vector2 = c.hoop_for(u.team)
	# L1: laterale STABILE durante il palleggio (no dx/sx)
	c.give_ball(u)
	for i in 20:
		await get_tree().process_frame
	var offs: Array = []
	for i in 50:
		await get_tree().process_frame
		offs.append(ball.global_position.x - u.global_position.x)
	var mn: float = offs.min()
	var mx: float = offs.max()
	print("L1 laterale=", mx - mn < 2.0, " range=", mn, "-", mx, " (target ~11 fisso)")
	# L2: scia in volo
	u.global_position = h + Vector2(-500, 0)
	u.shot_charge = 0.5
	u.shot_ideal = 0.5
	c.attempt_shot(u, 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in 12:
		await get_tree().process_frame
	print("L2 scia=", ball.trail.size(), " punti (attesi >3)")
	# L3: ripresa in mano = scia svanita
	c.give_ball(u)
	for i in 5:
		await get_tree().process_frame
	print("L3 clear=", ball.trail.is_empty())
	print("V224_OK=", mx - mn < 2.0 and ball.trail.is_empty())
	get_tree().quit()
