extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = true
	Game.profile["next_opponent"] = Season.TEAMS.filter(func(t): return t != Season.my_team())[0]
	var pre = load("res://src/scenes/PregameWarmup.tscn").instantiate()
	add_child(pre)
	await get_tree().process_frame
	var ok: bool = pre.pregame_warmup and not pre.outdoor and pre.npcs.size() == 6
	ok = ok and pre.npcs[0]["team"] == 0 and pre.npcs[2]["team"] == 1
	ok = ok and pre.npcs[4]["state"] == "stretch" and pre.npcs[5]["state"] == "roller"
	ok = ok and pre.hud_layer.get_child(0).get_node_or_null("PlayMatch") != null
	var seen := {}
	for i in 600:
		pre._update_npcs(1.0 / 60.0)
		seen[String(pre.npcs[0]["state"])] = true
	ok = ok and seen.has("shoot") and seen.has("fall") and seen.has("collect") and seen.has("pass") and seen.has("wait")
	pre.player_pos = pre.RIM + Vector2(-165, 0)
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
