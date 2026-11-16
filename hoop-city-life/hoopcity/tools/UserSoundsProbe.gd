extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = false
	var c := Court.new()
	add_child(c)
	await get_tree().process_frame
	var ok: bool = Sfx._streams.get("buzzer") is AudioStreamMP3 and Sfx.DEFENSE_CHANTS.size() == 2
	Sfx.set_match_live(true)
	c.play_live = true
	c.possession = 1
	c._defense_chant_cooldown = 0.0
	c._process_defense_chant(3.1)
	ok = ok and Sfx.defense_chant.playing and c._defense_chant_left > 0.0
	c.possession = 0
	c._process_defense_chant(0.1)
	ok = ok and not Sfx.defense_chant.playing
	c.possession = 1
	c.one_on_one = true
	c._defense_chant_cooldown = 0.0
	c._process_defense_chant(4.0)
	ok = ok and not Sfx.defense_chant.playing
	Sfx.set_match_live(false)
	c.queue_free()
	print("USER_SOUNDS_OK=", ok)
	get_tree().quit(0 if ok else 1)
