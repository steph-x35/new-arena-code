extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["team_practice_day"] = int(Game.profile.get("day", 1))
	Game.profile["team_practice_stage"] = "2v2"
	Game.profile["next_match_mode"] = "team_practice"
	Game.profile["match_is_fixture"] = false
	var before := Season.followers()
	var court := Court.new()
	add_child(court)
	await get_tree().process_frame
	var ok := court.team_size == 2 and court.players.size() == 4 and court.quarter_len == 60.0
	court._end_quarter()
	ok = ok and court.finished and Season.followers() == before and not bool(Season.today().get("done", false))
	court.queue_free()
	await get_tree().process_frame
	Game.profile["team_practice_stage"] = "plays"
	Game.profile["pending_drill"] = {"kind": "plays"}
	var drill = load("res://src/scenes/DrillScene.tscn").instantiate()
	add_child(drill)
	await get_tree().process_frame
	ok = ok and drill.play_step == 0 and drill.running
	drill._play_pass()
	drill._proc_plays(0.6)
	ok = ok and drill.play_step == 1
	drill.runner_pos = drill.play_target
	drill._proc_plays(0.01)
	drill._proc_plays(0.6)
	ok = ok and drill.play_step == 3
	drill._play_pass()
	drill._proc_plays(0.6)
	ok = ok and drill.play_round == 1 and drill.play_step == 0
	ok = ok and Season.followers() == before and not bool(Season.today().get("done", false))
	drill.queue_free()
	print("PRACTICE_FLOW_OK=", ok)
	get_tree().quit(0 if ok else 1)
