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
