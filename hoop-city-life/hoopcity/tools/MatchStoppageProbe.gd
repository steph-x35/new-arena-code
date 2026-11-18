extends Node
var calls := []

func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = false
	var c := Court.new()
	add_child(c)
	await get_tree().process_frame
	c.set_process(false)
	c.set_physics_process(false)
	c.jump_pending = false
	c.give_ball(c.user)
	c.play_live = true
	# A request during a dunk does not stop the live action or consume a TO.
	var left: int = c.timeouts_left[0]
	c.user.dunking = true
	c.user.hanging = true
	var ok: bool = c.call_timeout(0) and c.timeout_requested == 0 and c.play_live and c.timeouts_left[0] == left
	# Opponent scores: now the request is granted, poses are cleared, then
	# the team entitled to the inbound retains possession after the timeout.
	c._inbound(0)
	ok = ok and c.timeout_active > 0.0 and not c.play_live and not c.user.dunking and not c.user.hanging and c.timeouts_left[0] == left - 1
	c.timeout_active = 0.0
	c._resume_after_timeout()
	ok = ok and c.restarting and c.possession == 0 and not c.request_pass(c.user)
	c.inbound_elapsed = 2.0
	ok = ok and c.request_pass(c.user) and c.play_live
	# Quarter change clears interrupted jump, dunk and shot charge.
	c.user.dunking = true
	c.user.hanging = true
	c.user.shot_charge = 0.7
	c._end_quarter()
	ok = ok and not c.user.dunking and not c.user.hanging and c.user.shot_charge < 0.0 and c.user.air == 0.0
	# A crossover hits the floor halfway and transfers to the other hand.
	c.give_ball(c.user)
	c.user.cooldown_move = 0.0
	c.user.do_move("hand_switch")
	c.user.move_t = c.user.move_duration * 0.5
	var off: Dictionary = c.user.dribble_ball_offset()
	ok = ok and absf(float(off["h"]) - Court.BALL_R) < 0.01
	c.violation_called.connect(func(reason): calls.append(reason))
	c.travel_violation(c.user)
	ok = ok and calls.size() == 1 and c.restarting
	c.queue_free()
	print("MATCH_STOPPAGE_OK=", ok)
	get_tree().quit(0 if ok else 1)
