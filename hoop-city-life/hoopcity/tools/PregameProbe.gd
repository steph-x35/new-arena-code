extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = true
	Game.profile["next_opponent"] = Season.TEAMS.filter(func(t): return t != Season.my_team())[0]
	var pre = load("res://src/scenes/PregameWarmup.tscn").instantiate()
	add_child(pre)
	await get_tree().process_frame
	var ok: bool = pre.pregame_warmup and not pre.outdoor and pre.npcs.size() == 9
	ok = ok and pre.npcs[0]["team"] == 0 and pre.npcs[2]["team"] == 1
	ok = ok and pre.npcs[4]["state"] == "stretch" and pre.npcs[5]["state"] == "roller"
	ok = ok and pre.npcs.filter(func(n): return n["team"] == 0).size() == 4
	ok = ok and pre.npcs.filter(func(n): return n["team"] == 1).size() == 5
	ok = ok and pre.npcs[0]["helper_home"].x > pre.RIM.x
	ok = ok and pre.npcs[2]["helper_home"].x < pre.LEFT_RIM.x
	var root: Control = pre.hud_layer.get_child(0)
	ok = ok and root.get_node_or_null("PlayMatch") != null
	var banner: Control = root.get_node_or_null("WarmupBanner")
	ok = ok and banner != null and banner.anchor_left > 0.0 and banner.anchor_right < 1.0
	var shooter: Dictionary = pre.npcs[0]
	shooter["state"] = "wait"
	shooter["t"] = -4.0
	shooter["helper"] = Vector2(shooter["helper_home"]) + Vector2(-100.0, 0)
	pre._update_npcs(0.1)
	ok = ok and bool(shooter["helper_moving"]) and float(shooter["helper_face"]) > 0.0 and float(shooter["helper_step"]) > 0.0
	for i in 90: pre._update_npcs(1.0 / 60.0)
	ok = ok and not bool(shooter["helper_moving"]) and Vector2(shooter["helper"]).distance_to(shooter["helper_home"]) < 0.01
	var seen := {}
	for i in 600:
		pre._update_npcs(1.0 / 60.0)
		seen[String(pre.npcs[0]["state"])] = true
	ok = ok and seen.has("shoot") and seen.has("fall") and seen.has("collect") and seen.has("pass") and seen.has("wait")
	# A real loose player ball is collected only when the helper reaches it.
	pre.solo_loose = true
	pre.ball_live = true
	pre._pick_ok = true
	pre.ball_h = 0.0
	pre.ball_pos = pre.RIM + Vector2(-40, 0)
	pre.user_helper_pos = pre.USER_HELPER_HOME
	pre._update_npcs(0.1)
	ok = ok and not pre.ball_recall and pre.user_helper_pos != pre.USER_HELPER_HOME and pre.user_helper_moving and pre.user_helper_face < 0.0
	for i in 150:
		pre._update_npcs(1.0 / 60.0)
		if pre.ball_recall: break
	ok = ok and pre.ball_recall
	pre.ball_recall = false
	pre.ball_live = false
	pre.solo_loose = false
	pre._update_npcs(0.1)
	ok = ok and pre.user_helper_moving and pre.user_helper_face > 0.0
	for i in 150: pre._update_npcs(1.0 / 60.0)
	ok = ok and not pre.user_helper_moving and pre.user_helper_pos.distance_to(pre.USER_HELPER_HOME) < 0.01
	pre.player_pos = pre.RIM + Vector2(-130, 0)
	pre._shoot_down()
	ok = ok and pre.layup_left > 0.0 and pre.dunk_phase == ""
	pre._process(0.4)
	ok = ok and pre.layup_bank and pre.ball_live
	pre.shot_made = true
	for i in 120:
		pre._step_ball(1.0 / 60.0)
		if pre.scored_this_shot: break
	ok = ok and not pre.layup_bank and pre.scored_this_shot
	var energy: float = float(Game.profile.get("energy", 0.0))
	var dunks: int = int(Game.profile.get("stat_dunks", 0))
	var xp = Game.profile.get("xp", 0)
	pre._drain_energy(-3.0)
	pre._dunk_throw()
	ok = ok and float(Game.profile.get("energy", 0.0)) == energy
	ok = ok and int(Game.profile.get("stat_dunks", 0)) == dunks and Game.profile.get("xp", 0) == xp
	pre.queue_free()
	await get_tree().process_frame
	var match_scene = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(match_scene)
	await get_tree().process_frame
	var court: Court = match_scene.court
	court.set_physics_process(false)
	match_scene.set_process(false)
	var before := court.game_clock
	court._physics_process(8.0)
	ok = ok and court.pre_tip_ceremony and court.jump_pending and not court._jump_run and court.game_clock == before
	match_scene._intro_done()
	ok = ok and match_scene.lineup_panel != null and match_scene.lineup_left > 0.0
	ok = ok and match_scene.lineup_panel.squad.size() == 5 and court.pre_tip_ceremony
	match_scene._finish_lineup()
	ok = ok and match_scene.lineup_team == 1 and match_scene.lineup_panel.squad.size() == 5 and court.pre_tip_ceremony
	match_scene._finish_lineup()
	ok = ok and not court.pre_tip_ceremony and match_scene.tip_left == 3.0 and court.jump_pending
	print("PREGAME_OK=", ok)
	get_tree().quit(0 if ok else 1)
