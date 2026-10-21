extends Node2D
## Verifica automatica della CAMERA DELLA SCHIACCIATA (v2.40.2): lo zoom
## deve partire davvero durante l'appesa al ferro, in ENTRAMBE le scene di
## gioco (arena MatchScene e campetto SoloCourt), e tornare al distacco.
## Stampa HANGCAM OK=true/false — la CI lo trasforma in verde/rosso.

func _ready() -> void:
	await get_tree().process_frame
	Game.profile = Game.default_profile()
	var ok_match := false
	var ok_solo := false
	# --- ARENA (MatchScene)
	var m = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(m)
	for i in 10:
		await get_tree().process_frame
	if m.court != null and m.court.players.size() > 0:
		m.intro_left = 0.0
		for i in 5:
			await get_tree().process_frame
		var base_zoom: float = m.cam.zoom.x
		var hp = m.court.players[0]
		hp.hanging = true
		hp.hang_t = 0.0
		for i in 40:
			await get_tree().process_frame
			hp.hang_t = 0.0      # niente auto-rilascio durante il test
		var hang_zoom: float = m.cam.zoom.x
		hp.hanging = false
		for i in 120:
			await get_tree().process_frame
		var rest_zoom: float = m.cam.zoom.x
		print("ARENA base=", base_zoom, " hang=", hang_zoom, " riposo=", rest_zoom)
		ok_match = hang_zoom > base_zoom * 1.08 and rest_zoom < base_zoom * 1.02
	m.queue_free()
	await get_tree().process_frame
	# --- CAMPETTO (SoloCourt)
	var s = load("res://src/scenes/SoloCourt.tscn").instantiate()
	add_child(s)
	for i in 20:
		await get_tree().process_frame
	var scam: Camera2D = s.get_meta("cam", null)
	if scam != null:
		var base2: float = scam.zoom.x
		for i in 40:
			s.dunk_phase = "hang"   # tenuto forzato per tutto il campionamento
			s.hang_swing_t = 0.4
			await get_tree().process_frame
		var hang2: float = scam.zoom.x
		s.dunk_phase = ""
		for i in 120:
			await get_tree().process_frame
		var rest2: float = scam.zoom.x
		print("SOLO base=", base2, " hang=", hang2, " riposo=", rest2)
		ok_solo = hang2 > base2 * 1.08 and rest2 < base2 * 1.02
	s.queue_free()
	await get_tree().process_frame
	print("HANGCAM OK=", ok_match and ok_solo, " (arena=", ok_match, " campetto=", ok_solo, ")")
	get_tree().quit()
