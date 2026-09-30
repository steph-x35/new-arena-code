extends Node2D
var racism := 0
func _ready() -> void:
	await get_tree().process_frame
	Game.profile = Game.default_profile()
	# --- SOLO: forma d'onda del palmo (la verita' da copiare)
	var solo = load("res://src/scenes/SoloCourt.tscn").instantiate()
	add_child(solo)
	for i in 30:
		await get_tree().process_frame
	var solo_ys: Array = []
	var solo_xs: Array = []
	for i in 70:
		await get_tree().process_frame
		var pm: Vector2 = Avatar.palms.get(solo.get_instance_id(), Vector2.INF)
		if pm != Vector2.INF:
			solo_ys.append(-pm.y)
			solo_xs.append(pm.x)
	solo.free()
	var s_y0: float = solo_ys.min()
	var s_y1: float = solo_ys.max()
	var s_x: float = solo_xs.max() - solo_xs.min()
	print("SOLO palm: y ", int(s_y0), "-", int(s_y1), "  x_range ", s_x)
	# --- MATCH: stesso campione
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
	ms.court.give_ball(u)
	var m_ys: Array = []
	var m_xs: Array = []
	for i in 70:
		await get_tree().process_frame
		var pm2: Vector2 = Avatar.palms.get(u.get_instance_id(), Vector2.INF)
		if pm2 != Vector2.INF:
			m_ys.append(-pm2.y)
			m_xs.append(pm2.x)
	var m_y0: float = m_ys.min()
	var m_y1: float = m_ys.max()
	var m_x: float = m_xs.max() - m_xs.min()
	print("MATCH palm: y ", int(m_y0), "-", int(m_y1), "  x_range ", m_x)
	var dy: float = absf((m_y1 - m_y0) - (s_y1 - s_y0))
	var parita: bool = dy < 6.0 and m_x < 3.0 and s_x < 3.0
	print("PARITY_OK=", parita, " (|range delta|=", dy, ")")
	# --- scia visibile: alpha massimo fantasma
	print("TRAIL_OK: cap 10, alpha max ", 0.10 + 0.30 * (10.0/11.0), " r max ", Court.BALL_R * (0.48 + 0.42 * (10.0/11.0)))
	get_tree().quit()
