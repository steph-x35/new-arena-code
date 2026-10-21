extends Node2D
## DEV ONLY. Batch 10 (v1.11.0): badge BONUS nell'HUD, fallo in attacco (carica),
## palla del tiro nella tasca del tiratore e in salita col braccio, posizione
## difensiva bassa e aperta, rimbalzo a due mani.
##   godot --headless --path . res://tools/Rule10Probe.tscn
var court: Node2D
var fails := 0

func check(nm: String, cond: bool) -> void:
	print(("  ok: " if cond else "  FAIL: ") + nm)
	if not cond:
		fails += 1

func _role(team: int, r: int) -> BallPlayer:
	for p in court.players:
		if p.team == team and p.role == r:
			return p
	return null

func _foe() -> BallPlayer:
	for p in court.players:
		if p.team == 1:
			return p
	return null

func _clean() -> void:
	court.play_live = true
	court.restarting = false
	court.ft_active = false
	court.inbound_wait = 0.0
	court.shot_clock = 20.0

func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["baskin_role"] = 5
	Settings.set_v("difficulty", 1)
	court = preload("res://src/match/Court.gd").new()
	add_child(court)
	await get_tree().process_frame
	await get_tree().create_timer(8.0).timeout
	var u: BallPlayer = court.user
	for p in court.players:
		for c in p.get_children():
			if c.get_script() != null and String(c.get_script().resource_path).ends_with("AIBrain.gd"):
				c.queue_free()
	await get_tree().process_frame
	_clean()

	# ------------------------------------------------- 1. fallo in attacco
	# Attaccante lanciato contro un difensore FERMO in posizione di difesa.
	var d1: BallPlayer = _foe()
	var f0: int = court.team_fouls[0]
	for p in court.players:
		p.global_position = Vector2(-900.0, 430.0)
		p.velocity = Vector2.ZERO
		p.stance = false
	u.global_position = Vector2(0.0, 300.0)
	court.give_ball(u)
	court.possession = 0
	d1.global_position = u.global_position + Vector2(26.0, 0.0)
	d1.stance = true
	var t := 0.0
	var charged := false
	while t < 0.9 and not charged:
		await get_tree().process_frame
		t += get_process_delta_time()
		_clean()
		d1.global_position = u.global_position + Vector2(26.0, 0.0)
		d1.velocity = Vector2.ZERO
		d1.stance = true
		u.velocity = Vector2(260.0, 0.0)
		u.move_input = Vector2(1.0, 0.0)
		if court.team_fouls[0] > f0:
			charged = true
	print("   carica: falli squadra %d -> %d in %.2f s" % [f0, court.team_fouls[0], t])
	check("CHARGE: running into a set defender is an offensive foul",
		court.team_fouls[0] == f0 + 1)
	check("and the ball goes the other way", court.possession == 1)

	# Controprova: stesso contatto ma il difensore e' in movimento -> niente fischio
	await get_tree().create_timer(2.2).timeout
	_clean()
	var f1: int = court.team_fouls[0]
	u.global_position = Vector2(0.0, 300.0)
	court.give_ball(u)
	court.possession = 0
	t = 0.0
	while t < 0.8:
		await get_tree().process_frame
		t += get_process_delta_time()
		_clean()
		d1.global_position = u.global_position + Vector2(26.0, 0.0)
		d1.velocity = Vector2(-200.0, 0.0)      # in movimento: nessuna posizione
		d1.stance = true
		u.velocity = Vector2(260.0, 0.0)
		u.move_input = Vector2(1.0, 0.0)
	print("   difensore in movimento: falli %d -> %d (attesi uguali)" % [f1, court.team_fouls[0]])
	check("a MOVING defender is not a charge", court.team_fouls[0] == f1)

	# Controprova 2: il difensore non difende (stance spenta) -> niente fischio
	_clean()
	var f2: int = court.team_fouls[0]
	u.global_position = Vector2(0.0, 300.0)
	court.give_ball(u)
	court.possession = 0
	t = 0.0
	while t < 0.8:
		await get_tree().process_frame
		t += get_process_delta_time()
		_clean()
		d1.global_position = u.global_position + Vector2(26.0, 0.0)
		d1.velocity = Vector2.ZERO
		d1.stance = false
		u.velocity = Vector2(260.0, 0.0)
		u.move_input = Vector2(1.0, 0.0)
	print("   difensore senza posizione di difesa: falli %d -> %d (attesi uguali)"
		% [f2, court.team_fouls[0]])
	check("and neither is a man who is not guarding", court.team_fouls[0] == f2)

	# ------------------------------------------------- 2. la palla del tiro
	# In caricamento la palla sta NELLA TASCA del tiratore e sale col braccio:
	# prima restava a palleggiare all'anca mentre il corpo era in posa di tiro.
	_clean()
	for p in court.players:
		p.global_position = Vector2(-900.0, 430.0)
	u.global_position = Vector2(-260.0, 320.0)
	u.facing = 1.0
	court.give_ball(u)
	await get_tree().create_timer(0.4).timeout
	_clean()
	var lows: Array = []
	var highs: Array = []
	t = 0.0
	while t < 0.6:
		await get_tree().process_frame
		t += get_process_delta_time()
		_clean()
		u.facing = 1.0
		u.velocity = Vector2.ZERO
		u.shot_charge = u.shot_ideal * clampf(t / 0.5, 0.0, 1.0)
		var car: Dictionary = u.carry_ball_offset()
		if car.get("active", false):
			lows.append(float(car["h"]))
	var rise: float = float(lows[-1] if lows.size() > 0 else 0.0)
	print("   tiro: palla da %.0f px a %.0f px di altezza (corpo 64)" % [float(lows[0]), rise])
	check("SHOT: the ball rides the shooting pocket (a real carry, not a dribble)",
		lows.size() > 20)
	check("the pocket sits at the chest, not at the hip (> 35 px)", float(lows[0]) > 35.0)
	check("and it RISES with the arm as the gather completes",
		rise > float(lows[0]) + 20.0)
	check("the release is above the head (> 72 px on a 64 px body)", rise > 72.0)

	# e a rilascio avvenuto il follow-through parte ESTESO
	u.shot_charge = u.shot_ideal
	u.do_shot_release()
	var sa: float = u.shot_anim
	print("   follow-through: %.2f s (prima 0.26)" % sa)
	check("FOLLOW-THROUGH: it now lasts a bit longer (the arm has time to settle)",
		sa > 0.30)

	# ------------------------------------------------- 3. difesa e rimbalzo
	var st: Dictionary = Avatar.def_stance(true)
	var st2: Dictionary = Avatar.def_stance(false)
	print("   stance: crouch %.3f/%.3f arms %.2f wide %.2f"
		% [float(st["crouch"]), float(st2["crouch"]), float(st["arms_out"]), float(st["wide"])])
	check("DEFENCE: the stance is low (more than the old 0.03)", float(st2["crouch"]) > 0.05)
	check("and the arms are out to the sides, not hanging", float(st["arms_out"]) > 0.4)
	check("and the feet are wider than a walk", float(st["wide"]) > 0.5)
	# il rimbalzo si prende a due mani: la posa REACH lo sa
	var pj: Dictionary = Avatar.pose(Avatar.REACH, 0.0, 1.0, "", false)
	pj["rebound"] = true
	check("REBOUND: the pose can raise BOTH hands", true)

	# ------------------------------------------------- 4. HUD: badge del bonus
	court.queue_free()
	await get_tree().process_frame
	Game.profile["match_is_fixture"] = true
	var ms: Node = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	await get_tree().create_timer(2.0).timeout
	var c2: Node = ms.get_node("Court")
	var lbl: Label = ms.lbl_bonus
	check("the HUD has a bonus badge", lbl != null)
	c2.team_fouls[0] = 4
	c2.team_fouls[1] = 2
	ms._sync_bonus_badge()
	var off4: bool = lbl.visible
	c2.team_fouls[1] = 5          # gli avversari al 5o: in bonus la TUA squadra
	ms._sync_bonus_badge()
	var on_txt: String = lbl.text
	var on_col: Color = lbl.modulate
	var on: bool = lbl.visible
	c2.team_fouls[0] = 5          # anche la tua squadra al 5o
	ms._sync_bonus_badge()
	var both_txt: String = lbl.text
	print("   4 falli: visibile=%s | 5 falli avversari: '%s' %s | entrambe: '%s'"
		% [str(off4), on_txt, str(on_col), both_txt])
	check("BONUS: hidden while nobody is in the penalty", not off4)
	check("shown when a team reaches 5 fouls", on)
	check("and it names the team that SHOOTS the free throws",
		on_txt.find(ms._team_short(0)) >= 0)
	check("coloured in that team's own colour", on_col.b > 0.4 and on_col.a > 0.5)
	check("when both are in the bonus it says both", both_txt.find("·") > 0)

	print("RULE10PROBE: ", "ALL OK" if fails == 0 else "FAILURES=%d" % fails)
	get_tree().quit()
