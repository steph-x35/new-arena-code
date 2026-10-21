extends Node
var checks := 0
var fails := 0
var transitions := 0
func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: fails += 1
	print(("OK: " if ok else "FAIL: ") + label)
func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = true
	Game.profile["baskin_role"] = 5
	var ms = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	var c: Court = ms.get_node("Court")
	c.process_mode = Node.PROCESS_MODE_DISABLED
	ms.intro_left = 0.0
	ms.tip_left = 0.0
	if ms.intro_panel != null: ms.intro_panel.hide()
	c.jump_pending = false
	c.restarting = false
	c.play_live = true
	var old_lang := Loc.lang
	for lang in ["it", "en"]:
		Loc.lang = lang
		ms._on_rule("v_illegal")
		check(lang + " foul card has no unresolved placeholder", not ms.rule_title.text.contains("%") and not ms.rule_title.text.contains("&amp;"))
		check(lang + " foul toast names the actual jersey", (Loc.t("toast.foul_l") % 5).contains("#5"))
		var clean := true
		for key in Loc.STR:
			if String(key).begins_with("rule."):
				if Loc.t(key).contains("%") or Loc.t(key).contains("&amp;"): clean = false
		check(lang + " all rule-card strings are plain text", clean)
	Loc.lang = old_lang
	var sh := Vector2(8.6, -45.2)
	var hand := Vector2(12.2, -22)
	var elbow := Avatar.drib_elbow_at(sh, hand, 64.0, 1.0)
	var curve := Avatar.drib_arm_curve(sh, elbow, hand)
	check("rounded arm keeps shoulder and hand attached", curve[0].is_equal_approx(sh) and curve[-1].is_equal_approx(hand))
	check("rounded arm still bends at anatomical elbow", curve[8].distance_to(elbow) < 0.01)
	var a := (curve[8] - curve[7]).normalized()
	var b := (curve[9] - curve[8]).normalized()
	check("no sharp elbow corner", a.dot(b) > 0.9)
	var source := FileAccess.get_file_as_string("res://src/match/Ball.gd")
	check("landing ring removed from ball renderer", not source.substr(source.find("func _draw()")).contains("landing_spot()"))
	check("transition overlay does not steal touches", ms.inbound_veil.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	c.inbound_transition.connect(func(_duration): transitions += 1)
	var u := c.user
	for pl in c.players:
		pl.global_position = Vector2(-800, 0)
	u.global_position = c.hoop_for(0) + Vector2(-220, 100)
	# Let the initial scene load settle before sampling a 120ms tween.
	await get_tree().create_timer(0.1).timeout
	c._inbound(0, c.side_hoops[1])
	check("fade happens before inbound positioning", c._inbound_preparing and c._inbounder == null and transitions == 1)
	await get_tree().create_timer(0.06).timeout
	check("fade actually animates opacity", ms.inbound_veil.modulate.a > 0.05)
	await get_tree().create_timer(0.30).timeout
	check("fade completes before call window", not c._inbound_preparing and c.inbound_wait > 0)
	check("short transition ends transparent", ms.inbound_veil.modulate.a < 0.01)
	var guard: BallPlayer = null
	for pl in c.players:
		if pl.team == 1 and c.man_mark_for(pl) == u: guard = pl
	check("lateral inbound: caller already has a legal defender", guard != null and not c.ill_guard(guard, u) and guard.global_position.distance_to(u.global_position) < 80.0)
	check("CALL is accepted", c.request_pass(u))
	check("CALL releases ball in same frame", c.play_live and not c.restarting and c.ball.holder == null and c.ball.pass_target == u and c.ball.live)
	check("second CALL cannot start another release", not c.request_pass(u))
	# Force the catch using the same physical flight, without any AI interventions.
	var flight := 0.0
	while c.ball.holder == null and flight < 1.0:
		c.ball._physics_process(1.0 / 60.0)
		c._physics_process(1.0 / 60.0)
		flight += 1.0 / 60.0
	print("  lateral pass flight: ", flight)
	check("released pass reaches caller in under one second", c.ball.holder == u and flight < 1.0)
	# Early taps are queued, not lost. A newer restart invalidates the old timer.
	c._inbound(0)
	c.request_pass(u)
	check("early CALL queued during fade", c._inbound_requested and not c.play_live)
	await get_tree().create_timer(0.36).timeout
	check("queued CALL releases when fade ends", c.ball.pass_target == u and c.play_live)
	c._inbound(0)
	c._inbound(1)
	await get_tree().create_timer(0.36).timeout
	check("new restart wins over stale fade callback", c.possession == 1 and c._inbounder.team == 1 and not c._inbound_preparing)
	ms.queue_free()
	await get_tree().process_frame
	print("INBOUND UX: %d checks, %d failures" % [checks, fails])
	get_tree().quit(0 if fails == 0 else 1)
