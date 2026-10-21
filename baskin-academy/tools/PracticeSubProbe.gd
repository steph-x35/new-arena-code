extends Node
## Practice 5v5 has no bench roster. A tired player must not trigger a sub.
func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = false
	Game.profile["baskin_role"] = 5
	var ms = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	var court = ms.get_node("Court")
	court.set_process(false)
	court.set_physics_process(false)
	var p = court.players[1]
	p.is_user = false
	p.stamina = 0.0
	p.has_ball = false
	p.entering = false
	p.leaving = false
	court.ft_active = false
	court._coach_subs()
	var ok: bool = court.sub_pending.is_empty()
	var count: int = court.get_child_count()
	court._start_sub(p, 1)
	ok = ok and court.get_child_count() == count and court._sub_walk.is_empty()
	ok = ok and court.players.has(p) and not p.leaving
	print("PRACTICE SUB: ", "ALL OK" if ok else "FAILURES=1")
	ms.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if ok else 1)
