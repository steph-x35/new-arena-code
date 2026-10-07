extends Node2D
## DEV ONLY. Batch 13 (v1.14.0): la fila del tiro libero (due per squadra in
## corsia), il canestro che vibra, il canestro laterale lontano con l'ombra che
## lo stacca dal maxi-schermo.
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . res://tools/Batch13Shot.tscn
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
	ms.intro_left = 0.0
	if ms.intro_panel != null:
		ms.intro_panel.visible = false
	ms.set_process(false)
	ms.hud.visible = false          # foto pulite: solo campo e giocatori
	var u: BallPlayer = court.user
	var vp: Vector2 = get_viewport_rect().size

	# ------------------------------------------- 1. fila del tiro libero
	court.play_live = true
	court.restarting = false
	var victim: BallPlayer = null
	for p in court.players:
		if p.team == u.team and p.role == 5:
			victim = p
	if victim == null:
		victim = u
	var hoop: Vector2 = court.hoop_for(victim.team)
	court._start_free_throws(victim, 2)
	for p in court.players:
		p.set_physics_process(false)      # la fila non si sposta per la foto
	# inquadratura: la telecamera si mette davanti alla corsia
	var dir0: float = -1.0 if hoop.x > 0.0 else 1.0
	cam.global_position = Vector2(hoop.x + dir0 * 250.0, ms.CAM_HEIGHT)
	await _settle()
	_crop_img(get_viewport().get_texture().get_image(),
		Vector2(vp.x * 0.5 + 62.0, vp.y * 0.5 + 25.0), Vector2(820, 480), 1.2,
		"_b13_ftline.png")
	print("   fila: %s" % str(court.players.map(func(p):
		return "T%d r%d (%d,%d)" % [p.team, p.role, int(p.global_position.x),
			int(p.global_position.y)])))

	for p in court.players:
		p.set_physics_process(true)
	# ------------------------------------------- 2. il canestro che vibra
	court.ft_active = false
	court.restarting = false
	court.play_live = true
	vis.rim_shake[court.hoop_index_of(hoop)] = 0.0
	cam.global_position = Vector2(hoop.x + dir0 * 250.0, ms.CAM_HEIGHT)
	await _settle()
	var hoop_scr: Vector2 = _screen(hoop, 100.0)
	_crop_img(get_viewport().get_texture().get_image(), hoop_scr,
		Vector2(340, 320), 2.0, "_b13_quake_a.png")
	vis.rim_shake[court.hoop_index_of(hoop)] = 1.0
	# due scatti durante la scossa: si vede il canestro scostato
	for k in 2:
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var q: Vector2 = vis.quake_off(court.hoop_index_of(hoop))
		print("   scossa %d: scostamento %s" % [k, str(q.round())])
		_crop_img(get_viewport().get_texture().get_image(), hoop_scr,
			Vector2(340, 320), 2.0, "_b13_quake_%s.png" % ("b" if k == 0 else "c"))

	# ------------------------------------------- 3. canestro laterale lontano
	vis.rim_shake[court.hoop_index_of(hoop)] = 0.0
	var far_i := 1 if court.side_hoops[0].y > 0.0 else 0
	var sp: Vector2 = court.side_hoops[far_i]
	cam.global_position = Vector2(0.0, ms.CAM_HEIGHT - 300.0)
	await _settle()
	print("   canestro lontano: %s dietro=%s" % [str(sp), str(NetFront.side_hoop_faces_away(sp))])
	_crop_img(get_viewport().get_texture().get_image(), _screen(sp, Court.SIDE_RIM_HEIGHT + 20.0),
		Vector2(340, 300), 1.9, "_b13_farhoop.png")
	# ------------------------------------------- 4. quadro intero
	ms.hud.visible = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/_b13_full.png")
	print("BATCH13 SHOTS DONE")
	get_tree().quit()

## Aspetta che la telecamera (che ha lo smoothing) si sia assestata dove
## l'abbiamo messa: solo allora _screen() dice dove finisce davvero il ferro.
func _settle() -> void:
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

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
