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
	c.give_ball(u)
	# R1: ritmo del braccio = 4.2 costante (anche correndo)
	u.move_input = Vector2(1, 0)
	for i in 30:
		await get_tree().process_frame
	var rate: float = u.dribble_phase
	for i in 60:
		await get_tree().process_frame
	rate = (u.dribble_phase - rate) / ((60.0) / 60.0)
	print("R1 ritmo=", rate, " (target 4.2, running)")
	u.move_input = Vector2.ZERO
	# R2: palla ancora in mano dopo le modifiche
	for i in 10:
		await get_tree().process_frame
	var dx: float = absf(c.ball.global_position.x - (u.global_position.x + Avatar.last_palm.x))
	print("R2 in_mano=", dx < 2.5, " dx=", dx)
	# R3: draw_flames gira senza errori
	Avatar.draw_flames(self, Vector2.ZERO, 1.0)
	print("R3 flames_ok=", true)
	print("V223_OK=", absf(rate - 4.2) < 0.3 and dx < 2.5)
	get_tree().quit()
