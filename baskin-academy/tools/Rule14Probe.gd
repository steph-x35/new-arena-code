extends Node2D
## DEV ONLY. Batch 14 (v1.15.0): SOSTITUZIONI DAL VIVO.
##   - il cambio si esegue alla prima PALLA MORTA, non mentre si gioca
##   - chi entra ha lo STESSO RUOLO e la stessa fisionomia (formazione legale:
##     due donne in campo, un solo pivot)
##   - chi esce cammina in panchina, chi entra cammina in campo
##   - il cambio di chi ha la palla aspetta (non si perde)
##   - l'utente puo' chiedere il cambio per se stesso (percorso esistente)
##   - l'allenatore cambia chi non ha piu' gambe
##   - i posti di panchina si liberano col cooldown, il posto dell'utente mai
##   godot --headless --path . res://tools/Rule14Probe.tscn
var court: Node2D
var ms: Node
var fails := 0

func check(nm: String, cond: bool) -> void:
	print(("  ok: " if cond else "  FAIL: ") + nm)
	if not cond:
		fails += 1

func _clean() -> void:
	court.play_live = true
	court.restarting = false
	court.ft_active = false
	court.inbound_wait = 0.0
	court.shot_clock = 20.0

func _team(t: int) -> Array:
	var out := []
	for p in court.players:
		if p.team == t:
			out.append(p)
	return out

func _women(t: int) -> int:
	var n := 0
	for p in _team(t):
		if p.gender == 1:
			n += 1
	return n

func _pivots(t: int) -> int:
	var n := 0
	for p in _team(t):
		if p.role <= 2:
			n += 1
	return n

func _by_role(t: int, r: int, skip: BallPlayer) -> BallPlayer:
	for p in _team(t):
		if p.role == r and p != skip and not p.is_user:
			return p
	return null

func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = true
	Game.profile["baskin_role"] = 5
	ms = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	await get_tree().process_frame
	court = ms.get_node("Court")
	ms.intro_left = 0.0
	if ms.intro_panel != null:
		ms.intro_panel.visible = false
	await get_tree().create_timer(2.5).timeout

	# ------------------------------------------------- 1. chi si puo' cambiare
	var seats: Array = court.available_sub_seats()
	print("   posti di panchina disponibili: ", seats)
	check("PANCHINA: ci sono posti liberi", seats.size() >= 3)
	check("PANCHINA: il posto dell'utente non si usa per un compagno",
		not seats.has(court.USER_SEAT))
	# il compagno da cambiare: un ruolo 4 (non l'utente)
	var out1: BallPlayer = _by_role(0, 4, null)
	check("c'e' un compagno ruolo 4 da cambiare", out1 != null)
	var j_out: int = out1.jersey_num
	var women_before: int = _women(0)
	var pivots_before: int = _pivots(0)
	var n_before: int = _team(0).size()

	# ------------------------------------------------- 2. palla viva: aspetta
	_clean()
	check("CAMBIO: la richiesta viene accettata", court.request_sub(out1, int(seats[0])))
	check("CAMBIO: la richiesta resta in coda", court.sub_pending.size() == 1)
	var t := 0.0
	while t < 0.6:
		await get_tree().process_frame
		t += get_process_delta_time()
		_clean()          # palla VIVA: il cambio non deve avvenire
	check("CAMBIO: a palla viva NON si cambia", _team(0).has(out1))
	check("CAMBIO: la richiesta e' ancora in coda", court.sub_pending.size() == 1)

	# ------------------------------------------------- 3. palla morta: si cambia
	court.restarting = true
	var t2 := 0.0
	var changed := false
	while t2 < 4.0 and not changed:
		await get_tree().process_frame
		t2 += get_process_delta_time()
		court.restarting = true
		if not _team(0).has(out1):
			changed = true
	print("   cambio eseguito dopo %.1f s di palla morta" % t2)
	check("CAMBIO: a palla morta il giocatore esce", changed and not _team(0).has(out1))
	# aspetta che il sostituto sia arrivato in campo
	var t3 := 0.0
	var inn: BallPlayer = null
	while t3 < 4.0 and inn == null:
		await get_tree().process_frame
		t3 += get_process_delta_time()
		court.restarting = true
		for p in _team(0):
			if p.jersey_num != j_out and p.role == 4 and p.global_position.distance_to(
					court.seat_world(0, int(seats[0]))) < 900.0 and not p.entering and not p.leaving:
				inn = p
	print("   sostituto in campo dopo %.1f s: %s" % [t3, str(inn)])
	check("CAMBIO: il sostituto entra in campo", inn != null)
	if inn != null:
		check("CAMBIO: entra con lo STESSO RUOLO (4)", inn.role == 4)
		check("CAMBIO: entra con la maglia della panchina",
			inn.jersey_num != j_out)
		check("CAMBIO: stessa fisionomia (formazione legale)", inn.gender == out1.gender)
	_clean()
	check("CAMBIO: la squadra resta in cinque", _team(0).size() == n_before)
	check("CAMBIO: nessun giocatore fantasma in campo", court.players.size() == 10)
	check("CAMBIO: restano due donne in campo", _women(0) == women_before)
	check("CAMBIO: resta un solo pivot", _pivots(0) == pivots_before)
	check("CAMBIO: il posto usato va in cooldown",
		not court.available_sub_seats().has(int(seats[0])))

	# ------------------------------------------------- 4. chi ha la palla aspetta
	var out2: BallPlayer = _by_role(0, 5, null)
	check("c'e' un secondo compagno da cambiare", out2 != null)
	if out2 != null:
		_clean()
		court.give_ball(out2)
		var seats2: Array = court.available_sub_seats()
		check("CAMBIO: si puo' chiedere anche per chi ha la palla",
			court.request_sub(out2, int(seats2[0])))
		# Due fotogrammi di PALLA MORTA mentre lui tiene la palla: il cambio
		# non deve strappargliela di mano, deve aspettare.
		court.play_live = false
		court.restarting = true
		await get_tree().process_frame
		court.play_live = false
		court.restarting = true
		await get_tree().process_frame
		print("      (ha la palla=%s, in campo=%s, in coda=%d)"
			% [str(court.ball.holder == out2), str(court.players.has(out2)),
				court.sub_pending.size()])
		check("CAMBIO: chi ha la palla NON esce (si aspetta)",
			court.players.has(out2) and court.ball.holder == out2
			and court.sub_pending.size() >= 1)
		# molla la palla a un compagno: il cambio si esegue subito
		var mate: BallPlayer = _by_role(0, 3, out2)
		var t5 := 0.0
		while t5 < 3.0 and court.players.has(out2):
			await get_tree().process_frame
			t5 += get_process_delta_time()
			court.play_live = false
			court.restarting = true
			if mate != null and court.ball.holder == out2:
				court.give_ball(mate)
		check("CAMBIO: appena molla la palla il cambio si esegue",
			not _team(0).has(out2))
		_clean()

	# ------------------------------------------------- 5. il cambio per l'utente
	var u: BallPlayer = court.user
	var sub_seat: int = int(court.PARTNER_SEAT)
	if court.available_sub_seats().has(sub_seat) or true:
		var ok_self: bool = court.request_sub(u, sub_seat)
		court.restarting = true
		var t6 := 0.0
		while t6 < 8.0 and (court.user_on_court or court.sub_partner == null \
				or not court.players.has(court.sub_partner)):
			await get_tree().process_frame
			t6 += get_process_delta_time()
			court.restarting = true
			if court.user.has_ball:
				court.give_ball(_by_role(0, 3, court.user))
		print("   cambio per l'utente: richiesta=%s, fuori dal campo=%s"
			% [str(ok_self), str(not court.user_on_court)])
		check("CAMBIO PER TE: la richiesta viene accettata", ok_self)
		check("CAMBIO PER TE: scendi in panchina", not court.user_on_court)
		check("CAMBIO PER TE: il tuo sostituto e' in campo",
			court.sub_partner != null and court.players.has(court.sub_partner))

	# ------------------------------------------------- 6. l'allenatore cambia
	_clean()
	await get_tree().create_timer(1.0).timeout
	var gassed: BallPlayer = _by_role(1, 4, null)
	check("c'e' un avversario ruolo 4", gassed != null)
	if gassed != null:
		gassed.stamina = 4.0
		var t7 := 0.0
		while t7 < 8.0 and (court.players.has(gassed) or _team(1).size() != 5):
			await get_tree().process_frame
			t7 += get_process_delta_time()
			court.play_live = false        # palla morta: l'allenatore puo' cambiare
		print("   allenatore: il ruolo 4 stanco e' uscito dopo %.1f s" % t7)
		check("ALLENATORE: chi non ha gambe viene cambiato",
			not court.players.has(gassed))
		check("ALLENATORE: la squadra resta in cinque", _team(1).size() == 5)

	print("RULE14PROBE: ", "ALL OK" if fails == 0 else "FAILURES=%d" % fails)
	get_tree().quit()
