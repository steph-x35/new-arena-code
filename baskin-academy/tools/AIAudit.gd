extends Node
## Integration telemetry. Counts events, not time spent in each play label.
var passes := 0
var rules := {}
var previous_pass := -1.0
var freeze_logged := false
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var run_seed := int(args[0]) if args.size() > 0 else 41
	var seconds := float(args[1]) if args.size() > 1 else 180.0
	Engine.time_scale = 3.0
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = true
	Game.profile["quarter_seconds"] = 120.0
	Game.profile["baskin_role"] = 5
	Settings.data["difficulty"] = 1
	var ms = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	var court = ms.get_node("Court")
	# Court._ready randomizes the global generator; seed subsequent gameplay.
	seed(run_seed)
	ms.intro_left = 0.0
	if is_instance_valid(ms.intro_panel): ms.intro_panel.hide()
	court.user.is_user = false
	var brain := AIBrain.new()
	court.user.add_child(brain)
	brain.setup(court.user, court)
	Events.rule.connect(func(key): rules[key] = int(rules.get(key, 0)) + 1)
	var elapsed := 0.0
	var live_time := 0.0
	while elapsed < seconds and not court.finished:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		elapsed += dt
		if court._dead_time >= 2.8 and not freeze_logged:
			freeze_logged = true
			print("DEAD_STATE ", JSON.stringify({"t": elapsed, "live": court.play_live,
				"restart": court.restarting, "timeout": court.timeout_active,
				"quarter_pending": court._qb_inbound, "intermission": court.intermission,
				"intro": ms.intro_left, "tip": ms.tip_left, "holder": is_instance_valid(court.ball.holder)}))
		if court._dead_time < 1.0: freeze_logged = false
		if court.awaiting_check: court.confirm_check()
		if court.play_live: live_time += dt
		if court.last_pass_time > 0.0 and court.last_pass_time != previous_pass:
			passes += 1
		previous_pass = court.last_pass_time
	print("AI_AUDIT ", JSON.stringify({"seed": run_seed, "seconds": elapsed,
		"live_seconds": live_time, "passes": passes, "attempts": court.total_attempts,
		"makes": court.total_makes, "score": court.score, "rules": rules, "quarter": court.quarter}))
	ms.queue_free()
	await get_tree().process_frame
	get_tree().quit()
