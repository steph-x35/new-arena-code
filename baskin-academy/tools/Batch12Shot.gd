extends Node2D
## DEV ONLY. Batch 12 (v1.13.0): il palleggio (mano sopra la palla, gomito
## piegato, corsa della mano), il canestro laterale rigirato vicino e quello
## frontale lontano, gli anelli di difesa (azzurro = il tuo uomo, rosso = fallo
## "L" in arrivo). Solo immagini: la verifica dei numeri e' Rule12Probe.
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . res://tools/Batch12Shot.tscn
var court: Node2D
var ms: Node
var cam: Camera2D
var vis: Node2D
var dir := "/home/user"

func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = true
	Game.profile["baskin_role"] = 5
	ms = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	await get_tree().process_frame
	court = ms.get_node("Court")
	cam = ms.get_node("Camera2D")
	vis = ms.get_node("CourtVisual")
	await get_tree().create_timer(9.0).timeout
	var u: BallPlayer = court.user
	for p in court.players:
		if p != u:
			p.global_position = Vector2(-840.0, 400.0)
	court.play_live = true
	court.restarting = false
	court.ft_active = false
	court.shot_clock = 20.0
	u.global_position = Vector2(-300.0, 300.0)
	u.velocity = Vector2.ZERO
	court.give_ball(u)

	# ------------------------------------------- 1. il palleggio, fase per fase
	var t := 0.0
	var next_at := 0.0
	var shot := 0
	while t < 1.15 and shot < 4:
		await get_tree().process_frame
		t += get_process_delta_time()
		court.shot_clock = 20.0
		u.velocity = Vector2.ZERO
		if t >= next_at:
			next_at = t + 0.26
			await RenderingServer.frame_post_draw
			var off: Vector2 = u.drib_hint()
			var ball: Ball = court.ball
			var hb0: float = 64.0 * u.height_f
			var hand: Vector2 = Avatar.drib_hand_at(0.0, 0.0, hb0, off,
				Court.BALL_R, u.hand_side, true)
			print("   palleggio %d: palla a %.0f px, mano a %.0f px (h corpo %.0f)"
				% [shot, off.y * hb0, -hand.y, hb0])
			# LA PROVA DECISIVA: la palla VERA in partita contro il palmo
			# disegnato, proiettati sullo schermo con lo stesso stadio.
			var bs: Vector2 = CourtStage.m_project(ball.global_position, ball.h)
			var ps: Vector2 = CourtStage.m_project(u.global_position + Vector2(hand.x, 0.0), -hand.y)
			print("      palla vera %s | palmo disegnato %s | scarto dx=%.1f dy=%.1f"
				% [str(bs.round()), str(ps.round()),
					absf(bs.x - ps.x), bs.y - ps.y])
			_crop_img(get_viewport().get_texture().get_image(),
				_screen(u.global_position, 64.0 * u.height_f * 0.42),
				Vector2(300, 320), 1.9, "_b12_drib_%d.png" % shot)
			# stretto su spalla-braccio-palla: si deve vedere il GOMITO piegato
			_crop_img(get_viewport().get_texture().get_image(),
				_screen(u.global_position + Vector2(u.hand_side * 6.0, 0.0),
					64.0 * u.height_f * 0.46),
				Vector2(170, 190), 3.2, "_b12_dribz_%d.png" % shot)
			_crop_img(get_viewport().get_texture().get_image(),
				_screen(u.global_position + Vector2(u.hand_side * 8.0, 0.0),
					64.0 * u.height_f * 0.50),
				Vector2(120, 140), 4.2, "_b12_dribq_%d.png" % shot)
			shot += 1

	# ------------------------------------------- 2. canestro laterale vicino
	# Il tabellone lontano sta IN ALTO: l'intro e i pannelli del punteggio lo
	# coprirebbero, quindi si spengono solo per queste due foto.
	ms.intro_left = 0.0
	if ms.intro_panel != null:
		ms.intro_panel.visible = false
	ms.hud.visible = false
	# Il canestro LONTANO proietta in alto, dove l'HUD e il tabellone
	# dell'arena lo coprono: la telecamera (ferma li' per la foto) si abbassa
	# di 300 px solo per quell'inquadratura.
	ms.set_process(false)
	await get_tree().process_frame
	var cam0: Vector2 = cam.global_position
	var near_i := 0 if court.side_hoops[0].y > 0.0 else 1
	var far_i := 1 - near_i
	for si in [near_i, far_i]:
		var sp: Vector2 = court.side_hoops[si]
		var shift: float = 0.0 if si == near_i else -300.0
		cam.global_position.y = cam0.y + shift
		await get_tree().process_frame
		var sc := _screen(sp, Court.SIDE_RIM_HEIGHT + 30.0)
		print("   canestro %s: schermo %s dietro=%s" % ["vicino" if si == near_i else "lontano",
			str(sc.round()), str(NetFront.side_hoop_faces_away(sp))])
		await RenderingServer.frame_post_draw
		_crop_img(get_viewport().get_texture().get_image(), sc,
			Vector2(320, 300), 1.9, "_b12_hoop_%s.png" % ("near" if si == near_i else "far"))
		_crop_img(get_viewport().get_texture().get_image(), sc,
			Vector2(170, 190), 3.4, "_b12_hoopz_%s.png" % ("near" if si == near_i else "far"))

	cam.global_position = cam0
	ms.set_process(true)
	ms.hud.visible = true
	# ------------------------------------------- 3. gli anelli di difesa
	# Via i cervelli IA e i giocatori che non servono: la scena resta quella
	# che imposto, cosi' l'anello e' per forza di chi dico io.
	for p in court.players:
		for c in p.get_children():
			if c.get_script() != null and String(c.get_script().resource_path).ends_with("AIBrain.gd"):
				c.queue_free()
	await get_tree().process_frame
	var r5: BallPlayer = null
	var r3: BallPlayer = null
	for p in court.players:
		if p.team != u.team:
			if p.role == 5 and r5 == null:
				r5 = p
			elif p.role == 3 and r3 == null:
				r3 = p
	print("   uomini: legale %s, illegale %s" % [str(r5), str(r3)])
	_clear(u)
	u.global_position = Vector2(-300.0, 300.0)
	u.guarding = false
	if r5 != null:
		r5.global_position = Vector2(-200.0, 300.0)
		court.give_ball(r5)
		for i in 4:
			await get_tree().process_frame
			u.global_position = Vector2(-300.0, 300.0)     # DIFENDI premuto
			u.guarding = true
		await RenderingServer.frame_post_draw
		print("   legale: guard_target=%s (r5) ill_mark=%s"
			% [str(court.guard_target), str(court.ill_mark)])
		_crop_img(get_viewport().get_texture().get_image(),
			_screen(Vector2(-250.0, 300.0), 64.0 * u.height_f * 0.35),
			Vector2(360, 280), 2.0, "_b12_ring_legal.png")
	if r3 != null:
		# il portatore diventa un RUOLO 3 (che io, ruolo 5, non posso marcare):
		# l'anello azzurro va sul MIO uomo, quello rosso sul ruolo 3 addosso
		court.give_ball(r3)
		for i in 5:
			await get_tree().process_frame
			u.global_position = Vector2(-300.0, 300.0)     # 38 px dal ruolo 3
			u.guarding = true
			r3.global_position = Vector2(-262.0, 300.0)
			r3.velocity = Vector2.ZERO
			if r5 != null:
				r5.global_position = Vector2(-110.0, 340.0)
		await RenderingServer.frame_post_draw
		print("   illegale: guard_target=%s (deve essere un ruolo 5) ill_mark=%s (ruolo 3)"
			% [str(court.guard_target), str(court.ill_mark)])
		_crop_img(get_viewport().get_texture().get_image(),
			_screen(Vector2(-240.0, 315.0), 64.0 * u.height_f * 0.35),
			Vector2(460, 330), 1.7, "_b12_ring_illegal.png")

	# ------------------------------------------- 4. quadro intero
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/_b12_full.png")
	print("BATCH12 SHOTS DONE")
	get_tree().quit()

func _clear(u: BallPlayer) -> void:
	for p in court.players:
		if p != u:
			p.global_position = Vector2(-840.0, 400.0)
			p.velocity = Vector2.ZERO

func _screen(w: Vector2, lift := 0.0) -> Vector2:
	var gp: Vector2 = vis.to_global(CourtStage.m_project(w, Court.COURT_H) + Vector2(0.0, -lift))
	return (gp - cam.global_position) * cam.zoom + get_viewport_rect().size * 0.5

func _crop_img(img: Image, at: Vector2, size: Vector2, zoom: float, nm: String) -> void:
	var r := Rect2i(int(at.x - size.x * 0.5), int(at.y - size.y * 0.5), int(size.x), int(size.y))
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x < 8 or r.size.y < 8:
		print("   (fuori schermo: ", nm, ")")
		return
	var z := img.get_region(r)
	z.resize(int(z.get_width() * zoom), int(z.get_height() * zoom), Image.INTERPOLATE_LANCZOS)
	z.save_png(dir + "/" + nm)
	print("saved ", nm)
