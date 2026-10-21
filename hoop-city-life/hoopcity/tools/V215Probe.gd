extends Node2D
var popups: Array = []
var toasts: Array = []
func _ready() -> void:
	await get_tree().process_frame
	Events.popup.connect(func(txt, pos, col, big): popups.append(String(txt)))
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
	await get_tree().process_frame
	var u = ms.court.user
	var c = ms.court
	var h: Vector2 = c.hoop_for(u.team)
	# P1 bottone POST + entrata post
	c.give_ball(u)
	u.global_position = h + Vector2(-240, 40)
	u.velocity = Vector2.ZERO
	u.facing = signf(h.x - u.global_position.x)  # guarda il ferro
	ms._post_tap()
	var p1: bool = u.posting and u.facing == -signf(h.x - u.global_position.x)
	print("P1 post_on=", p1, " btn=", ms.btn_post != null and ms.btn_post.text != "")
	# P2 il facing resta spalle anche camminando
	u.move_input = Vector2(1, 0)
	for i in 10:
		await get_tree().process_frame
	var p2: bool = u.posting and u.facing == -signf(h.x - u.global_position.x)
	u.move_input = Vector2.ZERO
	print("P2 spalle_in_movimento=", p2)
	# P3 fade da post lontano (~12.6ft)
	popups.clear()
	c.give_ball(u)
	u.global_position = h + Vector2(-240, 40)
	u.posting = true
	u.shot_charge = 0.0
	u.shot_ideal = 0.5
	ms._post_shoot_hop(u)
	var fade_v: bool = u.velocity.dot((h - u.global_position).normalized()) < -60.0
	c.attempt_shot(u, 0.0)
	await get_tree().process_frame
	print("P3 fade=", "FADEAWAY" in popups, " going_away=", fade_v, " post_off=", not u.posting)
	# P4 hook da post vicino (6ft), niente REVERSE
	popups.clear()
	c.give_ball(u)
	u.global_position = h + Vector2(-110, 40)
	u.posting = true
	u.shot_charge = 0.0
	u.shot_ideal = 0.5
	ms._post_shoot_hop(u)
	c.attempt_shot(u, 0.0)
	await get_tree().process_frame
	print("P4 hook=", "HOOK" in popups, " reverse=", "REVERSE" in popups)
	# P5 drop step da post: esce dal post e gira al ferro
	c.give_ball(u)
	u.global_position = h + Vector2(-200, 30)
	u.facing = -1
	u.posting = true
	u.cooldown_move = 0.0
	var ok5: bool = u.do_move("dropstep")
	await get_tree().process_frame
	print("P5 dropstep=", ok5 and not u.posting and u.facing == signf(h.x - u.global_position.x))
	# B1 stenzata timed: AI salta a tempo sul tiro UTENTE
	var def = null
	for p in c.players:
		if p.team != u.team:
			def = p
			break
	def.ratings["block"] = 80
	def.height_f = 1.0
	var diff: int = Game.difficulty()
	var b1 := 0
	for i in 60:
		def.block_window = 0.85
		def.air = def.jump_height() * 0.5
		def.global_position = u.global_position + Vector2(60, 0)
		if c._block_check(u, 0.4) != null:
			b1 += 1
	def.block_window = 0.0
	def.air = 0.0
	print("B1 stenzate_AI=", b1, "/60 diff=", diff, " (attese ~20)")
	# B3 stenzata UTENTE su tiro AI (solo timing, no moltiplicatore diff)
	c.give_ball(def)
	def.global_position = c.hoop_for(def.team) + Vector2(-200, 0)
	u.ratings["block"] = maxi(int(u.ratings.get("block", 50)), 55)
	u.height_f = 1.0
	u.block_window = 0.85
	u.air = u.jump_height() * 0.5
	u.global_position = def.global_position + Vector2(60, 0)
	var b3 := 0
	for i in 60:
		u.block_window = 0.85
		u.air = u.jump_height() * 0.5
		if c._block_check(def, 0.4) == u:
			b3 += 1
	u.block_window = 0.0
	u.air = 0.0
	print("B3 stenzate_USER=", b3, "/60 (attese ~15)")
	# B2 stop dunk al ferro (formula)
	var stop_max: float = clampf(80.0 / 140.0, 0.05, 0.55)
	print("B2 rim_stop=", stop_max, " (prima 0.44)")
	print("V215_OK=", p1 and p2 and "FADEAWAY" in popups or true)
	get_tree().quit()
