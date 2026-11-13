extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "1v1"
	var c := Court.new()
	add_child(c)
	await get_tree().process_frame
	c.set_process(false)
	c.set_physics_process(false)
	var attacker: BallPlayer = c.players.filter(func(p): return p.team == 0)[0]
	var defender: BallPlayer = c.players.filter(func(p): return p.team == 1)[0]
	defender.ratings["block"] = 99
	var blocked := false
	for i in 100:
		c.awaiting_check = false
		attacker.global_position = Vector2.ZERO
		defender.global_position = Vector2.ZERO
		defender.block_window = 10.0
		attacker.has_ball = true
		attacker.dunking = true
		c.on_dunk_started(attacker)
		if c.awaiting_check:
			blocked = true
			break
	var ok: bool = blocked and c.possession == 1 and c.ball.holder == defender and not attacker.has_ball and not attacker.dunking
	c.queue_free()
	Sfx.start_crowd()
	Sfx.stop_crowd()
	Sfx.start_crowd()
	ok = ok and Sfx.crowd.playing
	Sfx.stop_crowd()
	var builder = load("res://src/ui/AttributeBuilder.gd").new()
	add_child(builder)
	builder.build()
	builder._change("close", 1)
	ok = ok and builder.glow_styles["close"].shadow_color.a > 0.5
	var duel = load("res://src/scenes/DuelScene.tscn").instantiate()
	add_child(duel)
	await get_tree().process_frame
	duel.set_process(false)
	ok = ok and duel.npcs.size() == 3
	var styles := []
	for n in duel.npcs:
		styles.append(n["look"]["hst"])
	ok = ok and styles[0] != styles[1] and styles[1] != styles[2] and styles[0] != styles[2]
	duel.duel_on = true
	duel.duel_phase = "live"
	duel.i_attack = false
	duel._on_foe_shot({"dunk": true, "made": false})
	ok = ok and duel.duel_phase == "check" and duel.i_attack and not duel.ball_loose and not duel.fb_live
	print("COURT_POLISH_OK=", ok)
	get_tree().quit(0 if ok else 1)
