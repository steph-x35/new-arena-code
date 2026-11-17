extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["team_practice_day"] = int(Game.profile.get("day", 1))
	Game.profile["team_practice_stage"] = "2v2"
	Game.profile["next_match_mode"] = "team_practice"
	Game.profile["match_is_fixture"] = false
	var game = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	var c: Court = game.court
	var scorer: BallPlayer = c.user
	c.give_ball(scorer)
	scorer.hanging = true
	c.ball.detach()
	c.ball.dunk_drop = 1.0
	c._dunk_scored(scorer)
	var ok: bool = not c.play_live and c.restarting and not c.try_grab(c.players[1])
	await get_tree().create_timer(0.9).timeout
	ok = ok and c.inbound_wait > 0.0 and c.possession == 1 and not c.play_live
	await get_tree().create_timer(3.3).timeout
	ok = ok and c.play_live and not c.restarting and c.ball_handler() != null
	game.queue_free()
	print("PRACTICE_DUNK_RESTART_OK=", ok)
	get_tree().quit(0 if ok else 1)
