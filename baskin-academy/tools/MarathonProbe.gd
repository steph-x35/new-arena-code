extends Node2D
## DEV/CI. LA MARATONA: una partita 5v5 completa, accelerata e headless.
## Quattro tempi, quiz dell'allenatore, palle a due, rimesse e fine partita
## compresi: cerca quello che i test corti non vedono (blocchi a meta'
## partita, contatori fuori scala, stati inconsistenti tra i tempi).
##   godot --headless --path . res://tools/MarathonProbe.tscn
## La CI lo gira a ogni push e legge MARATHON OK=true/false.

var ms: Node
var fails := 0

func check(nm: String, cond: bool) -> void:
	if cond:
		print("  ok: ", nm)
	else:
		fails += 1
		print("  FAIL: ", nm)

func _ready() -> void:
	Engine.time_scale = 3.0
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = false
	Game.profile["next_opponent"] = "Eastport Dockers"
	Game.profile["next_home"] = true
	Game.profile["quarter_seconds"] = 60.0
	Game.profile["baskin_role"] = 2
	Game.set_team_kit(1, Game.club_kit("Eastport Dockers"))
	var ps: PackedScene = load("res://src/match/MatchScene.tscn")
	ms = ps.instantiate()
	add_child(ms)
	await get_tree().process_frame
	ms.set("intro_left", 0.0)
	var court: Node = ms.get_node("Court")
	court.user.is_user = false
	var brain: Node = load("res://src/match/AIBrain.gd").new()
	court.user.add_child(brain)
	brain.setup(court.user, court)
	var t := 0.0
	var max_quarter := 0
	var live_frames := 0
	var dead_frames := 0
	while t < 360.0:
		var c: Node = ms.get_node_or_null("Court")
		if c == null:
			break
		if c.awaiting_check:
			c.confirm_check()
		max_quarter = maxi(max_quarter, int(c.quarter))
		if c.play_live:
			live_frames += 1
		else:
			dead_frames += 1
		_answer_quiz_if_open()
		if c.finished:
			break
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	var c: Node = ms.get_node_or_null("Court")
	if c == null:
		print("MARATHON OK=false  (Court scomparso)")
		get_tree().quit()
		return
	print("MARATHON t=", t, " quarter=", c.quarter, " finished=", c.finished,
		" score=", c.score, " attempts=", c.total_attempts,
		" makes=", c.total_makes)
	check("quattro tempi raggiunti (o partita finita)", max_quarter >= 4 or bool(c.finished))
	check("il gioco e' rimasto vivo", live_frames > 60)
	check("momenti morti mai dominanti (niente blocco)", dead_frames < live_frames * 3)
	check("punti segnati", int(c.score[0]) + int(c.score[1]) > 0)
	check("tiri tentati", int(c.total_attempts) > 10)
	# IL GIRONE: la sirena finale ha ruotato il calendario. Il probe parte
	# contro Eastport Dockers in casa: partita completata = prossimo club
	# del girone, in trasferta.
	if bool(c.finished):
		var nxt: String = String(Game.profile.get("next_opponent", ""))
		check("girone avanzato alla sirena (prossimo avversario valido)",
			nxt != "Eastport Dockers" and Game.club_rotation().has(nxt))
		check("casa/trasferta alternata", not bool(Game.profile.get("next_home", true)))
	print("MARATHON OK=" + str(fails == 0))
	get_tree().quit()

func _answer_quiz_if_open() -> void:
	## Il quiz dell'allenatore a fine tempo aspetta una risposta: senza
	## questa la maratona si fermerebbe al primo tempo.
	if ms == null:
		return
	var qp = ms.get("_quiz_panel")
	if qp == null or not is_instance_valid(qp):
		return
	if bool(ms.get("_quiz_answered")):
		return
	var btns: Array = qp.find_children("*", "Button", true, false)
	if btns.is_empty():
		return
	var b: Button = btns[0]
	b.pressed.emit()
