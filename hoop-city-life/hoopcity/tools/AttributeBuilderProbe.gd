extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.ensure_attribute_builder()
	Game.profile["attr_points"] = 95
	var base_close: int = Game.attr("close")
	var base_dunk: int = Game.attr("dunk")
	var base_mid: int = Game.attr("mid")
	var changed: bool = Game.allocate_attribute("close", 99 - base_close)
	var ok: bool = changed and Game.attr("close") == 99
	ok = ok and Game.attr("dunk") > base_dunk and Game.attr("mid") > base_mid
	ok = ok and int(Game.profile["attr_points"]) >= 0
	Game.allocate_attribute("close", 0)
	ok = ok and int(Game.profile["attr_points"]) == 95
	ok = ok and Game.attr("close") == base_close and Game.attr("dunk") == base_dunk
	Game.allocate_attribute("three", 5)
	Game.add_attribute_bonus("three", 1)
	var saved: int = Game.attr("three")
	SaveSystem.save_game("attribute_probe")
	Game.profile = Game.default_profile()
	ok = ok and SaveSystem.load_game("attribute_probe") and Game.attr("three") == saved
	Game.allocate_attribute("three", 0)
	ok = ok and Game.attr("three") == 49
	SaveSystem.delete_save("attribute_probe")
	print("ATTRIBUTE_BUILDER_OK=", ok)
	get_tree().quit(0 if ok else 1)
