extends Node2D
## DEV ONLY: measures the AI's mix — drives, jumpers, pivot hand-offs, slams —
## over a long AI-vs-AI run.
##   godot --headless --path . res://tools/BalanceProbe.tscn [seconds]
var ms: Node
var court: Node
var plays := {}
var recv := [0, 0]
var pshots := [0, 0]
var _had := [false, false]
var _shots := [0, 0]
var slams := 0
func _ready() -> void:
	Engine.time_scale = 3.0
	var secs := 120.0
	for a in OS.get_cmdline_args():
		if String(a).is_valid_float():
			secs = float(a)
	Game.profile["next_match_mode"] = "full"
	Game.profile["quarter_seconds"] = 400.0
	Game.profile["baskin_role"] = 5
	ms = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	await get_tree().process_frame
	court = ms.get_node("Court")
	court.user.is_user = false
	var b: Node = load("res://src/match/AIBrain.gd").new()
	court.user.add_child(b)
	b.setup(court.user, court)
	# Slams are announced as "DUNK <style>" on shot_taken (the toast carries
	# the style name, so watching for "SLAM" counted nothing).
	Events.shot_taken.connect(func(_lbl, _made, _pts):
		if String(_lbl).begins_with("DUNK"):
			slams += 1)
	var t := 0.0
	while t < secs:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		var h: BallPlayer = court.ball_handler()
		if h != null and h.role > 2:
			for c in h.get_children():
				if c is AIBrain:
					var rk: String = c.role
					if rk in ["drive", "deliver", "three", "mid", "spot", "pass", "side"]:
						plays[rk] = int(plays.get(rk, 0)) + 1
		for team in 2:
			var piv: BallPlayer = court.pivot_player(team)
			if piv == null:
				continue
			if piv.has_ball and not _had[team]:
				recv[team] += 1
			_had[team] = piv.has_ball
			if piv.period_shots > _shots[team]:
				pshots[team] += piv.period_shots - _shots[team]
				_shots[team] = piv.period_shots
	var sorted := plays.keys()
	sorted.sort_custom(func(x, y): return int(plays[x]) > int(plays[y]))
	var mix := ""
	for k in sorted:
		mix += "%s=%d " % [k, plays[k]]
	print("BALANCE plays: ", mix)
	print("BALANCE pivot receipts=", recv, " pivot shots=", pshots, " slams=", slams)
	print("BALANCE score=", court.score, " attempts=", court.total_attempts, " makes=", court.total_makes,
		" quarter=", court.quarter)
	print("BALANCE fouls=", court.team_fouls, " charges=", court.charges)
	get_tree().quit()
