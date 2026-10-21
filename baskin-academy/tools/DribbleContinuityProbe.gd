extends Node
var fails := 0
var checks := 0
func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: fails += 1
	print(("OK: " if ok else "FAIL: ") + label)
func _ready() -> void:
	var p := BallPlayer.new()
	p.visible = false
	p.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(p)
	for kind in ["crossover", "behind", "hand_switch", "between"]:
		p.has_ball = true
		p.hand_side = 1.0
		p.move_t = 0.0
		p.cooldown_move = 0.0
		p.fake_locked = false
		p._drib_cache.clear()
		var before: float = p.dribble_ball_offset()["x"]
		p.do_move(kind)
		var start: float = p._dribble_ball_offset_raw()["x"]
		check(kind + " starts at original hand", absf(start - before) < 0.1)
		p.move_t = 0.00001
		var end: float = p._dribble_ball_offset_raw()["x"]
		p.move_t = 0.0
		var after: float = p._dribble_ball_offset_raw()["x"]
		check(kind + " ends at new hand without sideways snap", absf(end - after) < 0.1)
	p.anim_t = 123.0
	p.move_t = 0.0
	p._dribble_phase = 1.0
	p.velocity = Vector2.ZERO
	p._press_t = 0.0
	var height_before: float = p._dribble_ball_offset_raw()["h"]
	p.velocity = Vector2(300, 0)
	check("speed change does not teleport bounce phase", absf(p._dribble_ball_offset_raw()["h"] - height_before) < 0.01)
	p._press_t = 0.3
	check("pressure change does not teleport ball height", absf(p._dribble_ball_offset_raw()["h"] - height_before) < 0.01)
	p._press_t = 0.0
	var travel := 0.0
	for i in 60:
		var old_phase: float = p._dribble_phase
		p._update_dribble_cycle(1.0 / 60.0)
		travel += fposmod(p._dribble_phase - old_phase, PI / 1.15)
	var cycles: float = travel * 1.15 / PI
	check("running dribble stays between 2.5 and 3.5 bounces per second", cycles > 2.5 and cycles < 3.5)
	p.queue_free()
	await get_tree().process_frame
	print("DRIBBLE CONTINUITY: %d checks, %d failures" % [checks, fails])
	get_tree().quit(0 if fails == 0 else 1)
