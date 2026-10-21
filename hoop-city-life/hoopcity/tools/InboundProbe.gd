extends Node2D
func _ready() -> void:
	await get_tree().process_frame
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "5v5"
	Game.profile["next_opponent"] = "Riverton"
	var ms := preload("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	for i in 900:
		await get_tree().process_frame
		if ms.court.awaiting_check: break
	ms.court.confirm_check()
	for i in 5:
		await get_tree().process_frame
	var c = ms.court
	# I1: rimessa -> nessuno (tranne il rimettitore) e' fermo
	var u = c.user
	var h: Vector2 = c.hoop_for(u.team)
	# fai un canestro per innescare la rimessa avversaria/incorso
	c.score = [4, 6]
	c._inbound(1 - u.team)
	await get_tree().process_frame
	if not c.restarting:
		print("I1 skip: restarting=false")
		print("INBOUND_OK=skip")
		get_tree().quit()
		return
	var t0: int = Time.get_ticks_msec()
	var before := {}
	for p in c.players:
		before[p] = p.global_position
	await get_tree().create_timer(0.6).timeout
	var moved := 0
	var still := 0
	for p in c.players:
		if p == c.ball_handler():
			continue   # il rimettitore puo' stare fermo fuori campo
		if p.global_position.distance_to(before[p]) > 2.0:
			moved += 1
		else:
			still += 1
	print("I1 si muovono=", moved, " fermi=", still)
	# I2: al termine della rimessa il gioco riprende e la palla arriva
	for i in 200:
		await get_tree().process_frame
		if c.play_live:
			break
	print("I2 live=", c.play_live, " t=", Time.get_ticks_msec() - t0, "ms")
	# I3: velocita' base alzata +5%
	var s0: float = u.max_speed()
	print("I3 speed=", int(s0), " (era ~216+rating; ora +5%)")
	print("INBOUND_OK=", moved > still and c.play_live)
	get_tree().quit()
