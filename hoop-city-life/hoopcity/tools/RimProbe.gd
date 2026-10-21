extends Node2D
var toasts: Array = []
func _ready() -> void:
	await get_tree().process_frame
	Events.toast.connect(func(t): toasts.append(String(t)))
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
	var h: Vector2 = c.hoop_for(u.team)
	var def = null
	for p in c.players:
		if p.team != u.team:
			def = p
			break
	def.ratings["block"] = 90
	def.height_f = 1.0
	var blocked := 0
	var scored := 0
	for t in 12:
		toasts.clear()
		# riporta il court a stato pulito: check-ball se serve, poi live
		for i in 120:
			await get_tree().process_frame
			if c.awaiting_check:
				c.confirm_check()
				break
		for i in 40:
			await get_tree().process_frame
		c.give_ball(u)
		u.stamina = 100.0
		u.global_position = h + Vector2(-60, 30)
		u.velocity = Vector2.ZERO
		u.facing = 1
		u.jumping = false
		u.hanging = false
		u.landing = 0.0
		# difensore saltato a tempo: finestra aperta, al ferro
		def.block_window = 1.15
		def.global_position = u.global_position + Vector2(50, -10)
		var s0: int = c.score[u.team]
		u.do_dunk()
		var got_toast: bool = false
		for i in 320:
			await get_tree().process_frame
			if "BLOCKED AT THE RIM!" in toasts:
				got_toast = true
			if got_toast or u.hanging:
				break
		var s1: int = c.score[u.team]
		if s1 > s0:
			scored += 1
		elif got_toast:
			blocked += 1
		def.block_window = 0.0
	print("R1 dunk_bloccati=", blocked, "/12  dunk_segnati=", scored, "/12  (attesi ~8-9 bloccati con block=90)")
	print("RIM_OK=", blocked >= 4)
	get_tree().quit()
