extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["last_building"] = "court"
	var solo = load("res://src/scenes/SoloCourt.tscn").instantiate()
	add_child(solo)
	await get_tree().process_frame
	var n: Dictionary = solo.npcs[0]
	n["state"] = "chase"
	n["pos"] = Vector2(-700, 0)
	n["target"] = n["pos"]
	solo._update_npcs(0.01)
	var ok: bool = n["state"] == "relocate" and Vector2(n["target"]).distance_to(n["pos"]) > 25.0
	var old: Vector2 = n["pos"]
	solo._update_npcs(0.2)
	ok = ok and Vector2(n["pos"]).distance_to(old) > 1.0 and n["state"] == "relocate"
	n["state"] = "rebound"
	n["pos"] = solo.RIM + Vector2(-90, 65)
	solo.player_pos = Vector2(-300, 200)
	solo.solo_loose = false
	solo._update_npcs(0.5)
	ok = ok and Vector2(n["pos"]).distance_to(solo.RIM + Vector2(-90, 65)) < 1.0
	SceneRouter.friendly_1v1 = true
	SceneRouter.friendly_look = n["look"].duplicate(true)
	var expected: Color = n["look"]["jersey"]
	solo.queue_free()
	await get_tree().process_frame
	Game.profile["next_match_mode"] = "1v1"
	Game.profile["match_is_fixture"] = false
	var game = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	var opponent: BallPlayer = game.court.players[1]
	ok = ok and game.court.friendly_1v1 and game.court.awaiting_check and not game.court.play_live
	ok = ok and game.intro_panel == null and game.intro_left == 0.0 and game.tip_left == 0.0
	ok = ok and opponent.stance and opponent.friendly_look["jersey"] == expected
	game.court.confirm_check()
	ok = ok and game.court.play_live and not game.court.awaiting_check
	game.queue_free()
	await get_tree().process_frame
	ok = ok and not SceneRouter.friendly_1v1
	print("FRIENDLY_COURT_OK=", ok)
	get_tree().quit(0 if ok else 1)
