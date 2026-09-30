extends Node2D
## Headless AI-vs-AI match simulator, run as a throwaway main scene:
##   godot --headless res://tools/SimRunner.tscn [games] [--full] [--scale N]
## Both slots -- including the "user" player -- get an AIBrain, so the whole
## match engine (wind-ups, close-outs, blocks, check ball, watchdog) is
## exercised without a human. Prints per-game stats and quits.

var _mode := "1v1"
var _games := 3
var _target := 2

func _ready() -> void:
	var scale := 10.0
	var args := OS.get_cmdline_args()
	for i in args.size():
		var a: String = args[i]
		if a.begins_with("--"):
			continue
		if a.is_valid_int() and (i == 0 or not String(args[i - 1]).begins_with("--")):
			_games = int(a)
	if "--full" in args:
		_mode = "full"
	var ti := args.find("--target")
	if ti >= 0 and ti + 1 < args.size() and args[ti + 1].is_valid_int():
		_target = int(args[ti + 1])
	var si := args.find("--scale")
	if si >= 0 and si + 1 < args.size() and args[si + 1].is_valid_float():
		scale = float(args[si + 1])
	Engine.time_scale = scale
	# Cranking Engine.time_scale alone also cranks the PHYSICS delta, which
	# turns the ball's ballistic arc into swiss cheese (a made shot can miss
	# the rim by 100+ px at scale 12). Raising the tick rate with the scale
	# keeps every integration step at a honest 1/60 s, so sim results reflect
	# what a phone at 60 fps actually sees.
	ProjectSettings.set_setting("physics/common/physics_ticks_per_second", int(60 * scale))
	ProjectSettings.set_setting("physics/common/max_physics_steps_per_frame", 512)
	print("=== SIM MODE ", _mode, " x", _games, " scale ", scale, " ===")
	_run()

func _make_court() -> Node:
	Game.profile["next_match_mode"] = _mode
	var CourtScript: Script = load("res://src/match/Court.gd")
	var court := Node2D.new()
	court.set_script(CourtScript)
	add_child(court)
	# Drive the user slot with a brain too.
	var BrainScript: Script = load("res://src/match/AIBrain.gd")
	# Equal-footing balance tests: the "user" slot is driven by a brain and
	# stripped of its human speed/stat perks so both teams are symmetric.
	court.user.is_user = false
	var b: Node = BrainScript.new()
	court.user.add_child(b)
	b.setup(court.user, court)
	# Shot audit: [total, makes], plus a sample of the timing labels.
	var audit := {"total": 0, "made_roll": 0, "labels": {}, "fate": {}}
	court.set_meta("audit", audit)
	Events.shot_taken.connect(func(label: String, made: bool, _pts: int):
		audit["total"] += 1
		if made: audit["made_roll"] += 1
		var head: String = label.split(" / ")[0]
		audit["labels"][head] = int(audit["labels"].get(head, 0)) + 1)
	Events.score_changed.connect(func(_a: int, _b: int):
		audit["fate"]["basket"] = int(audit["fate"].get("basket", 0)) + 1)
	Events.toast.connect(func(t: String):
		var key: String = "other"
		for k in ["BLOCKED", "Rebound", "Dead ball", "Loose ball", "Shot clock"]:
			if String(t).begins_with(k):
				key = k
				break
		audit["fate"][key] = int(audit["fate"].get(key, 0)) + 1)
	return court

func _run() -> void:
	for g in _games:
		var court: Node = _make_court()
		if court.one_on_one:
			# Short race by default for fast logic tests; --target N plays a
			# full-length 1v1 so slams and late-game behaviour can be measured.
			court.set("target_score", _target)
		var sim := 0.0
		var max_sim := 300.0 if court.one_on_one else 520.0
		while not court.finished and sim < max_sim:
			if court.awaiting_check:
				court.confirm_check()
			await get_tree().create_timer(0.05).timeout
			sim += 0.05
		await get_tree().process_frame
		var audit: Dictionary = court.get_meta("audit")
		var status := "FINISHED" if court.finished else "TIMEOUT(%.0fs)" % max_sim
		print("game %d: %s  score %d-%d  attempts %d makes %d" % [
			g + 1, status, court.score[0], court.score[1],
			court.total_attempts, court.total_makes])
		print("   shots events: ", JSON.stringify(audit))
		print("   user box: ", JSON.stringify(court.box))
		court.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	print("=== SIM DONE ===")
	get_tree().quit()
