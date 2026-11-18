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
	# Legacy 60-day save: preserve played games and results, cap future fixtures.
	Game.profile = Game.default_profile()
	var legacy: Array = []
	for d in range(1, 61):
		legacy.append({"day": d, "kind": "game" if d % 3 == 0 else "rest", "done": d == 3, "result": "90-80" if d == 3 else "", "opponent": "Opponent"})
	Game.profile["day"] = 10
	Game.profile["schedule"] = legacy
	Game.profile.erase("schedule_ten_games_v1")
	var migrated: Array = Season.schedule()
	var count := 0
	for entry in migrated:
		if entry["kind"] == "game": count += 1
	ok = ok and count == 10 and migrated[2]["result"] == "90-80" and bool(migrated[2]["done"])
	print("SEASON_PROBE_OK=", ok)
	get_tree().quit(0 if ok else 1)
