extends Node
var checks := 0
var fails := 0
func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: fails += 1
	print(("OK: " if ok else "FAIL: ") + label)
func make_court() -> Court:
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = true
	Game.profile["baskin_role"] = 5
	var c := Court.new()
	c.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(c)
	c.jump_pending = false
	c.play_live = true
	c.restarting = false
	c.ft_active = false
	return c
func _ready() -> void:
	var c := make_court()
	var u := c.user
	var piv := c.pivot_player(0)
	var b := AIBrain.new()
	u.add_child(b)
	b.setup(u, c)
	u.global_position = c.side_hoops[0] + Vector2(0, -signf(c.side_hoops[0].y) * (Court.SIDE_AREA_R + 30))
	seed(321)
	var first := b._deliver_spot(piv)
	var stable := true
	for i in 100:
		if b._deliver_spot(piv) != first: stable = false
	check("delivery side remains stable across frames", stable)
	u.area_loiter_t = 2.5
	c._area_trespass_check(0.1)
	check("leaving side area resets loiter timer", u.area_loiter_t == 0.0)
	c.give_ball(u)
	u.is_user = false
	u.global_position = c.side_hoops[0] + Vector2(0, -signf(c.side_hoops[0].y) * 50)
	c.ball.global_position = u.global_position
	c._area_trespass_check(0.2)
	check("new visit counts only current visit", is_equal_approx(u.area_loiter_t, 0.2))
	c.give_ball(piv)
	u.global_position = c.side_hoops[0]
	b.state = AIBrain.S.ATK_OFF
	b._act(0.016)
	check("exit from hoop centre points into court", u.move_input.y * c.side_hoops[0].y < 0)
	# A simulated user remains the persistent user object even when AI driven.
	u.stamina = 0.0
	c._coach_subs()
	var user_requested := false
	for r in c.sub_pending:
		if r['out'] == u: user_requested = true
	check("generic coach never deletes persistent user", not user_requested)
	c.sub_pending.clear()
	var receiver: BallPlayer
	for pl in c.players:
		if pl.team == 0 and pl.role == 4: receiver = pl
	c.play_live = false
	c.restarting = true
	c._inbounder = u
	c._inbound_receiver = receiver
	c.give_ball(u)
	check("inbound receiver substitution can queue", c.request_sub(receiver, 2, false))
	c._process_live_subs(0.0)
	check("inbound receiver kept until release", c.sub_pending.size() == 1 and not receiver.leaving)
	c.queue_free()
	await get_tree().process_frame

	c = make_court()
	c.play_live = false
	c.timeout_active = 4.0
	c._deadball_watchdog(3.2)
	check("timeout is not a stuck possession", not c.restarting and c._dead_time == 0.0)
	c.queue_free()
	await get_tree().process_frame
	c = make_court()
	c.play_live = false
	c.countdown_hold = 3.5
	c._deadball_watchdog(3.1)
	check("countdown protected from premature restart", not c.restarting and c._dead_time == 0.0)
	c._deadball_watchdog(0.5)
	check("countdown protection expires", c.countdown_hold == 0.0)
	c._deadball_watchdog(3.1)
	check("genuine unexplained stop still recovered", c.restarting)
	c.queue_free()
	await get_tree().process_frame
	print("CONTINUITY: %d checks, %d failures" % [checks, fails])
	get_tree().quit(0 if fails == 0 else 1)
