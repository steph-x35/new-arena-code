extends Node2D
## DEV/CI. Riproduce il blocco segnalato sul telefono: la card BENVENUTO
## della prima partita che non avanza al tocco e tiene il gioco in pausa
## infinita. Inietta input VERO (Input.parse_input_event: stessa catena
## del device, mouse emulato incluso) nei tre scenari:
##   A) tocco semplice al centro
##   B) pollice sinistro TENUTO sull'area dello stick + tap dell'altro dito
##      — su Android il mouse emulato nasce solo dal tocco 0: era il bug
##   C) tocco semplice sulla meta' sinistra (zona stick, ex zona morta)
## Poi: auto-avanzamento senza tocchi (rete di sicurezza), ripartenza del
## 3-2-1, stick riattivato a gioco vivo, sequenza mai piu' ripetuta.
##   godot --headless --path . res://tools/TipTapProbe.tscn
## La CI legge TAPTAP OK=true/false.

var ms: Node
var fails := 0

func check(nm: String, cond: bool) -> void:
	if cond:
		print("  ok: ", nm)
	else:
		fails += 1
		print("  FAIL: ", nm)

func _ready() -> void:
	Engine.time_scale = 1.0
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = false
	Game.profile["next_opponent"] = "Eastport Dockers"
	Game.profile["next_home"] = true
	Game.profile["quarter_seconds"] = 60.0
	Game.profile["baskin_role"] = 5
	Game.profile["baskin_onboarded"] = false
	Game.profile["baskin_onboarding"] = true
	Game.set_team_kit(1, Game.club_kit("Eastport Dockers"))
	ms = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel = ms.get("_tip_panel")
	check("card benvenuto presente", panel != null and is_instance_valid(panel))
	check("sequenza partita da card 0", int(ms.get("_tip_step")) == 0)
	check("stick non reclama tocchi mentre la card e' aperta",
		ms.joystick != null and not bool(ms.joystick.enabled))
	_diag()
	if panel == null or not is_instance_valid(panel):
		_end()
		return
	# A) tocco semplice al centro (dito secondario: indice 1)
	await _tap(Vector2(640, 360), 1)
	check("A: tap centrale avanza la card", int(ms.get("_tip_step")) == 1)
	# B) pollice sinistro TENUTO sull'area stick + tap dell'altro dito:
	#    il tocco 0 "possiede" il mouse emulato, l'altro dito non genera
	#    nessun evento mouse — la card deve avanzare lo stesso.
	_touch(0, Vector2(300, 400), true)
	await get_tree().process_frame
	await _tap(Vector2(700, 380), 1)
	check("B: tap col pollice sullo stick avanza la card",
		int(ms.get("_tip_step")) == 2)
	_touch(0, Vector2(300, 400), false)
	await get_tree().process_frame
	# C) tocco sulla meta' sinistra (la zona che lo stick si mangiava)
	await _tap(Vector2(300, 400), 1)
	check("C: tap sulla zona stick avanza la card", int(ms.get("_tip_step")) == 3)
	# Rete di sicurezza: senza tocchi la card avanza da sola
	ms.set("_tip_auto", 0.05)
	await get_tree().create_timer(0.4).timeout
	check("auto-avanzamento senza tocchi (rete di sicurezza)",
		int(ms.get("_tip_step")) == 4)
	# Ultima card: al tocco la sequenza finisce e il 3-2-1 riparte
	await _tap(Vector2(640, 360), 1)
	check("fine sequenza al quinto tocco", int(ms.get("_tip_step")) == -1)
	check("pannello benvenuto rimosso", ms.get("_tip_panel") == null)
	check("flag prima-partita salvato (le card non tornano piu')",
		bool(Game.profile.get("baskin_onboarded", false)))
	# Il 3-2-1 conta fino a GO e il gioco diventa vivo: si puo' giocare.
	# POLLING (non istante fisso): sulla transizione GO! il play_live si
	# alza in fisica e lo stick viene riabilitato da _process nel frame
	# dopo — campionare un istante preciso beccava la transizione e
	# falliva a caso. Si aspetta di VEDERE un frame vivo con stick attivo.
	var went_live := false
	var live_and_on := false
	var waited := 0.0
	while waited < 12.0:
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
		var cc: Node = ms.get_node_or_null("Court")
		if cc == null:
			break
		if bool(cc.play_live):
			went_live = true
			if ms.joystick != null and bool(ms.joystick.enabled):
				live_and_on = true
				break
	check("partita viva dopo la card (GO! arrivato)", went_live)
	check("stick riattivato a gioco vivo", live_and_on)
	_end()

func _end() -> void:
	print("TAPTAP OK=" + str(fails == 0))
	get_tree().quit()

func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = idx
	ev.position = pos
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _tap(pos: Vector2, idx: int) -> void:
	## Un tap vero: pressione e rilascio, con la pausa che basta al debounce
	## perche' un tocco avanzi una card sola.
	await get_tree().create_timer(0.3).timeout
	_touch(idx, pos, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_touch(idx, pos, false)
	await get_tree().process_frame
	await get_tree().process_frame

func _diag() -> void:
	## Chi c'e' nell'HUD (dal basso verso l'alto): se un giorno un overlay
	## torna a mangiarsi i tocchi, qui si vede chi sta sopra.
	var hud: Control = ms.get_node("HUD/Root")
	print("  hud (dal basso):")
	for ch in hud.get_children():
		print("   - ", ch.name, " mf=", ch.mouse_filter,
			" vis=", ch.visible)
