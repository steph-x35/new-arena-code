extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	var old: Array = []
	for d in range(1, 13):
		old.append({"day": d, "kind": "game" if d % 3 == 0 else "practice", "opponent": "Old rival" if d % 3 == 0 else "", "home": true, "done": d == 3, "skipped": false, "result": "80-70" if d == 3 else ""})
	Game.profile["schedule"] = old
	Game.profile["schedule_ten_games_v1"] = 1
	Game.profile["day"] = 4
	var cal: Array = Season.schedule()
	var count := 0
	for entry in cal:
		if entry["kind"] == "game": count += 1
	var ok: bool = count == 10 and cal.size() == 30 and cal[2]["result"] == "80-70" and bool(cal[2]["done"])
	ok = ok and Season.schedule().size() == 30 and Season.season_end_day() == 30
	var phone = load("res://src/ui/PhoneUI.tscn").instantiate()
	add_child(phone)
	await get_tree().process_frame
	phone.open_app("calendar")
	await get_tree().process_frame
	var visible_games := 0
	var last_visible := false
	for child in phone.body.get_children():
		if child is Label and String(child.text).contains("GARA "):
			visible_games += 1
			if String(child.text).contains("GARA 10/10"): last_visible = true
	ok = ok and visible_games == 10 and last_visible
	phone.queue_free()
	print("CALENDAR_COMPLETE_OK=", ok)
	get_tree().quit(0 if ok else 1)
