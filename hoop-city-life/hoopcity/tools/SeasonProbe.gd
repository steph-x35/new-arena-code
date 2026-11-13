extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	var cal: Array = Season.schedule()
	var games := 0
	for e in cal:
		if e["kind"] == "game": games += 1
	var ok := cal.size() == 30 and games == 10 and Season.season_end_day() == 30
	# A legacy 60-day calendar is not truncated or regenerated.
	cal.append({"day": 60, "kind": "game", "done": true, "result": "legacy"})
	ok = ok and Season.season_end_day() == 60 and cal.back()["result"] == "legacy"
	Game.profile["day"] = 3
	Game.profile["match_day"] = 3
	Season._on_day(4)
	ok = ok and not bool(Season.entry_for(3)["done"])
	Season.mark_done(3, "90-80")
	ok = ok and bool(Season.entry_for(3)["done"]) and Season.entry_for(3)["result"] == "90-80"
	print("SEASON_PROBE_OK=", ok)
	get_tree().quit(0 if ok else 1)
