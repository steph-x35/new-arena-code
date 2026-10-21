extends Node
## Deterministic decision scenarios, separate from stochastic match telemetry.
var fails := 0
var checks := 0
func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: fails += 1
	print(("OK: " if ok else "FAIL: ") + label)
func brain_for(pl: BallPlayer, c: Court) -> AIBrain:
	for child in pl.get_children():
		if child is AIBrain: return child
	var b := AIBrain.new()
	pl.add_child(b)
	b.setup(pl, c)
	return b
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
	var roster: Array = c.players.duplicate()
	var handler: BallPlayer = c.user
	handler.is_user = false
	var mate: BallPlayer
	var pivot: BallPlayer
	var enemy: BallPlayer
	for pl in roster:
		if pl.team == 0 and pl.role == 4: mate = pl
		if pl.team == 0 and pl.role <= 2: pivot = pl
		if pl.team == 1 and pl.role == 5: enemy = pl
	var hb := brain_for(handler, c)
	var mb := brain_for(mate, c)
	var pb := brain_for(pivot, c)
	handler.global_position = Vector2.ZERO
	mate.global_position = Vector2(100, 120)
	c.players = [handler, mate]
	c.pnr_roller = null
	seed(12345)
	var escapes := 0
	for i in 100:
		if hb._best_feed(0.95) == mate: escapes += 1
	check("pressure 95%: open perimeter outlet is considered", escapes > 0)
	var unnecessary := 0
	for i in 100:
		if hb._best_feed(0.1) != null: unnecessary += 1
	check("no automatic perimeter ping-pong without pressure", unnecessary == 0)

	# Even a tactically tempting roll must not bypass pivot delivery rules.
	c.players = [handler, pivot]
	pivot.global_position = c.pivot_home(0)
	c.pnr_roller = pivot
	var illegal := 0
	for i in 100:
		if hb._best_feed(0.95) == pivot: illegal += 1
	check("feed selection excludes illegal delivery from outside area", illegal == 0)
	check("fallback pass does not propose an illegal pivot delivery", c.best_pass_option(handler) == null)
	c.pnr_roller = null
	# Eligible player farther away than the pivot must still set the screen.
	c.players = [handler, pivot, mate]
	pivot.global_position = Vector2(15, 0)
	mate.global_position = Vector2(150, 0)
	check("AI chooses field player rather than nearby pivot to screen", hb._nearest_mate_brain() == mb)
	c.give_ball(handler)
	check("human pick-and-roll also excludes pivot", c.start_pick_and_roll(handler) and c.pnr_screener == mate)
	# Reset screen flags so this test cannot mask the next one.
	mb.pnr_t = 0.0
	mb.pnr_hold = false
	pb.pnr_t = 0.0
	pb.pnr_hold = false
	c.pnr_screening = false
	c.pnr_screener = null
	c.players = [handler, pivot]
	check("no legal screener: no pick-and-roll offered", not c.start_pick_and_roll(handler))

	c.players = [handler, mate, enemy]
	c.give_ball(handler)
	mb.begin_screen(handler)
	c.pnr_screening = true
	c.pnr_screener = mate
	c.pnr_timer = 5.0
	c.give_ball(enemy)
	mb._act(0.016)
	check("turnover cancels screen and returns to defence", mb.pnr_t <= 0.0 and mb.state in [AIBrain.S.DEF_ON, AIBrain.S.DEF_OFF])
	check("turnover clears shared screen state", not c.pnr_screening and c.pnr_screener == null)

	c.give_ball(handler)
	mb.begin_screen(handler)
	mb.begin_roll()
	c.pnr_roller = mate
	c.roller_t = 3.5
	c.give_ball(mate)
	mb._act(0.016)
	check("roller receiving ball switches to on-ball attack", mb.pnr_t <= 0.0 and mb.state == AIBrain.S.ATK_ON and c.pnr_roller == null)
	c.players = roster
	print("AI TEAMWORK: %d checks, %d failures" % [checks, fails])
	c.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if fails == 0 else 1)
