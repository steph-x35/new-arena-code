extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["last_building"] = "court"
	var solo = load("res://src/scenes/SoloCourt.tscn").instantiate()
	add_child(solo)
	await get_tree().process_frame
	var ok: bool = solo.npcs.size() == 2
	var n: Dictionary = solo.npcs[0]
	n["state"] = "shoot"
	n["t"] = 0.25
	solo.talk_index = 0
	solo.talking = true
	solo._update_npcs(0.5)
	ok = ok and float(n["t"]) == 0.25
	solo.talking = false
	solo._update_npcs(1.0)
	ok = ok and n["state"] == "fall"
	solo._update_npcs(1.0)
	ok = ok and n["state"] == "chase"
	solo.solo_loose = true
	solo.ball_live = true
	solo.ball_recall = false
	solo._shoot_down()
	ok = ok and solo.solo_loose and not solo.ball_recall
	# A real scoring crossing in Solo triggers a visible, settling response,
	# independent of whether the ball has already left the net.
	solo.ball_live = true
	solo.through_rim = false
	solo.prev_h = solo.RIM_HEIGHT + 2.0
	solo.ball_h = solo.RIM_HEIGHT - 2.0
	solo.prev_pos = solo.RIM
	solo.ball_pos = solo.RIM
	solo.ball_vel = Vector2(220.0, 0.0)
	solo.ball_vh = -300.0
	solo._collide_rim()
	solo._step_net_contact(0.15)
	ok = ok and solo.through_rim and solo.court_art.solo_net_contact.x > 0.5 and solo.court_art.solo_net_contact.y > 0.9
	solo.ball_live = false
	solo._step_net_contact(0.2)
	ok = ok and solo.court_art.solo_net_contact.x > 1.0 and solo.court_art.solo_net_contact.x < 2.0
	solo._step_net_contact(0.25)
	ok = ok and solo.court_art.solo_net_contact.x < 0.0 and Sfx.DUNK_HAPTIC_MS == 260
	solo.queue_free()
	await get_tree().process_frame
	Game.profile["next_match_mode"] = "1v1"
	var match_scene = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(match_scene)
	await get_tree().process_frame
	ok = ok and match_scene.court.one_on_one and match_scene.court._refs.is_empty()
	ok = ok and not match_scene.get_node("CourtVisual").crowd_on and not match_scene.get_node("CourtVisual").show_cheer and not Sfx.crowd.playing
	print("CHILL_COURT_OK=", ok)
	get_tree().quit(0 if ok else 1)
