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
	# M1: STEPBACK 3 — oltre l'arco, stepback attivo, in fuga dal ferro
	c.give_ball(u)
	u.global_position = h + Vector2(-560, 60)   # oltre i 3 punti
	u.velocity = Vector2(-180, 0)               # via dal ferro
	u.facing = -1
	u.stepback_t = 0.9
	u.shot_charge = 0.5
	u.shot_ideal = 0.5
	popups.clear()
	c.attempt_shot(u, 0.0)
	await get_tree().process_frame
	var m1: bool = "STEPBACK 3" in popups
	print("M1 stepback3=", m1, " popups=", popups)
	# M2: FLOATER — in corsa al ferro, difensore addosso, 10ft
	for i in 40:
		await get_tree().process_frame
	var def = null
	for p in c.players:
		if p.team != u.team:
			def = p
			break
	c.give_ball(u)
	u.global_position = h + Vector2(-190, 20)
	u.velocity = Vector2(200, 0)                # verso il ferro
	u.facing = 1
	u.stepback_t = 0.0
	u.combo_pullup = false
	def.global_position = u.global_position + Vector2(60, -10)
	def.block_window = 0.0
	u.shot_charge = 0.5
	u.shot_ideal = 0.5
	popups.clear()
	c.attempt_shot(u, 0.0)
	await get_tree().process_frame
	var m2: bool = "FLOATER" in popups
	print("M2 floater=", m2, " popups=", popups)
	# M3: floater hard to block (blocco x0.4, raggio 70)
	def.ratings["block"] = 99
	def.height_f = 1.0
	def.global_position = u.global_position + Vector2(50, 0)
	u.global_position = h + Vector2(-190, 20)
	var bf := 0
	for i in 50:
		def.block_window = 1.15
		def.air = def.jump_height() * 0.5
		if c._block_check(u, 0.3, true) != null:
			bf += 1
	var bn := 0
	for i in 50:
		def.block_window = 1.15
		def.air = def.jump_height() * 0.5
		if c._block_check(u, 0.3, false) != null:
			bn += 1
	def.block_window = 0.0
	def.air = 0.0
	print("M3 blocchi_floater=", bf, "/50 vs normali=", bn, "/50 (ratio atteso ~0.4)")
	# M4: stepback_t decade
	u.stepback_t = 0.9
	for i in 60:
		await get_tree().process_frame
	print("M4 stepback_decay=", u.stepback_t < 0.5)
	print("V220_OK=", m1 and m2 and bf < bn and u.stepback_t < 0.5)
	get_tree().quit()
