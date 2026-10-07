extends Node
var checks := 0
var fails := 0
func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: fails += 1
	print(("OK: " if ok else "FAIL: ") + label)
func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = true
	Game.profile["baskin_role"] = 5
	var c := Court.new()
	c.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(c)
	c.play_live = true
	c.restarting = false
	c.inbound_wait = 0.0
	c.ft_active = false
	var sender: BallPlayer = c.user
	sender.is_user = false
	var receiver: BallPlayer
	for pl in c.players:
		if pl.team == 0 and pl.role == 4: receiver = pl
	c.give_ball(sender)
	sender.global_position = Vector2.ZERO
	receiver.global_position = Vector2(200, 0)
	sender.has_ball = false
	c.do_pass(sender, receiver)
	c.play_live = false
	check("substitution request accepted", c.request_sub(receiver, 2, false))
	c._process_live_subs(0.0)
	check("receiver is not substituted during incoming pass", c.sub_pending.size() == 1 and not receiver.leaving and c._sub_walk.is_empty())
	c.sub_pending.clear()
	# Force the exceptional case anyway: deletion before the catch timer fires.
	c.players.erase(receiver)
	receiver.free()
	c.ball._physics_process(0.016)
	check("removed receiver turns homing pass into loose ball", c.ball.pass_arc == 0.0 and c.ball.pass_target == null and c.ball.holder == null)
	await get_tree().create_timer(1.0).timeout
	check("expired catch timer cannot resurrect removed receiver", c.ball.holder == null)
	# A valid pass can still be superseded by another play before its timer.
	var replacement := BallPlayer.new()
	replacement.team = 0
	replacement.role = 4
	c.add_child(replacement)
	c.players.append(replacement)
	replacement.global_position = Vector2(150, 0)
	c.play_live = true
	c.do_pass(sender, replacement)
	c.ball.pass_target = null
	await get_tree().create_timer(1.0).timeout
	check("stale timer cannot catch a superseded pass", c.ball.holder == null and not replacement.has_ball)
	print("AI PASS LIFETIME: %d checks, %d failures" % [checks, fails])
	c.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if fails == 0 else 1)
