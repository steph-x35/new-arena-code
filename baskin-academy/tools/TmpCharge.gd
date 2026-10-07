extends Node2D
## DEV ONLY (temporaneo): con soglie realistiche, la carica puo' accadere?
var court: Node2D
var ms: Node
var stats := {"frames": 0, "drive125": 0, "contact40": 0, "on_traj": 0,
	"def_still": 0, "def_stance": 0, "charge": 0}
var samples := []
func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = true
	Game.profile["baskin_role"] = 5
	Settings.set_v("difficulty", 1)
	ms = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	await get_tree().process_frame
	court = ms.get_node("Court")
	ms.intro_left = 0.0
	if ms.intro_panel != null: ms.intro_panel.visible = false
	var t := 0.0
	while t < 150.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		var h: BallPlayer = court.ball_handler()
		stats["frames"] += 1
		if h == null or not h.has_ball or h.jumping or h.dunking or h.hanging:
			continue
		if h.shot_charge >= 0.0 or h.ai_windup_t >= 0.0 or h.move_t > 0.0 or h.stun > 0.0:
			continue
		var spd: float = h.velocity.length()
		if spd < 125.0 or court.in_side_area(h.global_position):
			continue
		stats["drive125"] += 1
		var run: Vector2 = h.velocity / spd
		var rim: Vector2 = court.attack_hoop_for(h)
		for d in court.players:
			if d.team == h.team:
				continue
			var to: Vector2 = d.global_position - h.global_position
			var dist: float = to.length()
			if dist > 40.0 or dist < 1.0:
				continue
			stats["contact40"] += 1
			var dot: float = to.normalized().dot(run)
			if dot < 0.35:
				continue
			stats["on_traj"] += 1
			var dv: float = d.velocity.length()
			if dv > 85.0:
				continue
			stats["def_still"] += 1
			if not d.stance:
				continue
			stats["def_stance"] += 1
			var d_rim: float = d.global_position.distance_to(rim)
			if d_rim < Court.FIBA_RESTRICTED:
				continue
			stats["charge"] += 1
			if samples.size() < 8:
				samples.append("dist=%.0f dot=%.2f spd=%.0f def_spd=%.0f rim=%.0f"
					% [dist, dot, spd, dv, d_rim])
	print("   frames=%d  guida>=125: %d  contatto<=40px: %d  in traiettoria: %d"
		% [stats["frames"], stats["drive125"], stats["contact40"], stats["on_traj"]])
	print("   difensore fermo: %d  in stance: %d  FUORI arco: %d (cariche: %s)"
		% [stats["def_still"], stats["def_stance"], stats["charge"], str(court.charges)])
	for s in samples:
		print("      ", s)
	get_tree().quit()
