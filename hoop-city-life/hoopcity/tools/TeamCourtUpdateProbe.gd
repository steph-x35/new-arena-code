extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	var day := Season.today()
	var before := Season.followers()
	Season.attend_practice()
	var ok := not bool(day.get("done", false)) and Season.followers() == before
	var creator = load("res://src/scenes/CharacterCreator.tscn").instantiate()
	add_child(creator)
	await get_tree().process_frame
	var rating := Game.attr("three")
	var block := Game.attr("block")
	creator._adj_h(10)
	ok = ok and Game.attr("three") < rating and Game.attr("block") > block
	creator._adj_h(-10)
	ok = ok and Game.attr("three") == rating and Game.attr("block") == block
	creator.queue_free()
	await get_tree().process_frame
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "full"
	var c := Court.new()
	add_child(c)
	await get_tree().process_frame
	var markers := 0
	for p in c.players:
		if p.team == 1 and c.man_mark_for(p) == c.user: markers += 1
	ok = ok and markers == 1
	c.play_live = true
	c.give_ball(c.user)
	c.user.shot_charge = 0.1
	c.user.move_input = Vector2.RIGHT
	c.user.velocity = Vector2(200, 0)
	c.user._physics_process(0.016)
	ok = ok and c.user.velocity.length() < 0.1
	c.queue_free()
	await get_tree().process_frame
	Game.profile["last_building"] = "court"
	var solo = load("res://src/scenes/SoloCourt.tscn").instantiate()
	add_child(solo)
	await get_tree().process_frame
	ok = ok and not solo.outdoor and solo.npcs.size() == 2
	print("TEAM_COURT_UPDATE_OK=", ok)
	get_tree().quit(0 if ok else 1)
