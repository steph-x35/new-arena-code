extends Node2D
## Loads the FULL MatchScene (HUD + camera + net + court) headless, confirms
## check balls, and lets the brain-driven "user" slot play for a while to
## prove the whole ms screen builds and runs without script errors.
##   godot --headless res://tools/SceneSmoke.tscn [seconds]

var ms: Node

func _ready() -> void:
	Engine.time_scale = 2.0
	var secs := 12.0
	var args := OS.get_cmdline_args()
	for i in args.size():
		var a: String = args[i]
		if a.is_valid_float() and (i == 0 or not String(args[i - 1]).begins_with("--")):
			secs = float(a)
	Game.profile["next_match_mode"] = "1v1"
	var ps: PackedScene = load("res://src/match/MatchScene.tscn")
	ms = ps.instantiate()
	add_child(ms)
	# Let the brain also drive the human slot so the whole pad cycles.
	var court: Node = ms.get_node("Court")
	# NPC free-throw routine drives the line (a human needs the meter).
	court.user.is_user = false
	var BrainScript: Script = load("res://src/match/AIBrain.gd")
	var brain: Node = BrainScript.new()
	court.user.add_child(brain)
	brain.setup(court.user, court)
	print("MatchScene instantiated, children: ", ms.get_child_count())
	Events.toast.connect(func(t): print("[toast] ", t))
	_run(secs)

func _run(secs: float) -> void:
	var t := 0.0
	while t < secs:
		var c: Node = ms.get_node_or_null("Court")
		# Wait out the 3-2-1 tip countdown before ever confirming CHECK,
		# otherwise the test consumes the check early and play never resumes.
		if c != null and c.awaiting_check and t > 4.0:
			c.confirm_check()
		await get_tree().create_timer(0.05).timeout
		t += 0.05
		if int(t * 4) != int((t - 0.05) * 4):
			print("t=%4.1f live=%s await=%s poss=%d shotc=%.1f holder=%s" % [
				t, c.play_live, c.awaiting_check, c.possession, c.shot_clock,
				str(c.ball_handler().team) if c.ball_handler() else "none"])
	if ms:
		var c: Node = ms.get_node("Court")
		print("SMOKE OK  score ", c.score, " attempts ", c.total_attempts,
			" makes ", c.total_makes, " finished ", c.finished)
	get_tree().quit()
