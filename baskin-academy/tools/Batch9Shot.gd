extends Node2D
## DEV ONLY. Batch 9: palleggio (libero / marcato), incrocio, passo indietro,
## frenata con strisciata. Zoom sul giocatore.
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . res://tools/Batch9Shot.tscn
var court: Node2D
var ms: Node
var cam: Camera2D
var vis: Node2D
var u: BallPlayer
var dir := "/home/user"

func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["baskin_role"] = 5
	ms = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	await get_tree().process_frame
	court = ms.get_node("Court")
	cam = ms.get_node("Camera2D")
	vis = ms.get_node("CourtVisual")
	await get_tree().create_timer(9.0).timeout
	u = court.user
	# la partita resta viva, ma nessuno intralcia: gli altri tutti in un angolo
	for p in court.players:
		if p != u:
			p.global_position = Vector2(-820.0, 400.0)
			p.velocity = Vector2.ZERO
	court.play_live = true
	court.restarting = false
	court.ft_active = false
	court.shot_clock = 20.0
	u.global_position = Vector2(-220.0, 250.0)
	u.velocity = Vector2.ZERO
	u.move_input = Vector2.ZERO
	court.give_ball(u)

	# ---------------------------------------------- 1. palleggio libero (4 fasi)
	var shots := 0
	var t := 0.0
	var next_at := 0.0
	while t < 1.2 and shots < 3:
		await get_tree().process_frame
		t += get_process_delta_time()
		court.shot_clock = 20.0
		if t >= next_at:
			next_at = t + 0.16
			await RenderingServer.frame_post_draw
			_crop_user("_b9_drib_%d.png" % shots, 2.6)
			shots += 1

	# fotogramma intero: contesto di gioco con la palla nuova
	await RenderingServer.frame_post_draw
	var full := get_viewport().get_texture().get_image()
	full.save_png(dir + "/_b9_full.png")
	print("saved _b9_full.png")

	# zoom forte sul binomio mano/palla, in 3 fasi del rimbalzo
	var hs2 := 0
	next_at = 0.0
	t = 0.0
	while t < 1.0 and hs2 < 3:
		await get_tree().process_frame
		t += get_process_delta_time()
		court.shot_clock = 20.0
		if t >= next_at:
			next_at = t + 0.14
			await RenderingServer.frame_post_draw
			_crop_ball("_b9_zoom_%d.png" % hs2)
			hs2 += 1

	# ---------------------------------------------- 2. marcato addosso
	var d5: BallPlayer = null
	for p in court.players:
		if p.team == 1 and p.role == 5:
			d5 = p
	var hs := 0
	t = 0.0
	while t < 1.0 and hs < 2:
		await get_tree().process_frame
		t += get_process_delta_time()
		court.shot_clock = 20.0
		d5.global_position = u.global_position + Vector2(72.0, -6.0)
		if t > 0.35 and fmod(t, 0.3) < 0.02:
			await RenderingServer.frame_post_draw
			_crop_user("_b9_press_%d.png" % hs, 2.6)
			hs += 1
	d5.global_position = Vector2(-820.0, 400.0)

	# ---------------------------------------------- 3. incrocio (2 fasi)
	u.move_t = 0.0
	u.hand_side = 1.0
	u.do_move("crossover")
	var cs := 0
	t = 0.0
	while t < 0.5 and cs < 2:
		await get_tree().process_frame
		t += get_process_delta_time()
		court.shot_clock = 20.0
		if (cs == 0 and t > 0.14) or (cs == 1 and t > 0.34):
			await RenderingServer.frame_post_draw
			_crop_user("_b9_cross_%d.png" % cs, 2.8)
			cs += 1

	# ---------------------------------------------- 4. passo indietro
	u.move_t = 0.0
	u.do_move("stepback")
	t = 0.0
	var ss := false
	while t < 0.6 and not ss:
		await get_tree().process_frame
		t += get_process_delta_time()
		court.shot_clock = 20.0
		if t > 0.16:
			await RenderingServer.frame_post_draw
			_crop_user("_b9_step_0.png", 2.8)
			ss = true

	# ---------------------------------------------- 5. frenata con strisciata
	u.move_t = 0.0
	u.global_position = Vector2(-320.0, 250.0)
	court.give_ball(u)
	u.move_input = Vector2(1.0, 0.0)
	t = 0.0
	while t < 1.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		u.move_input = Vector2(1.0, 0.0)
	u.move_input = Vector2.ZERO
	t = 0.0
	var br := false
	while t < 0.4 and not br:
		await get_tree().process_frame
		t += get_process_delta_time()
		u.move_input = Vector2.ZERO
		if t > 0.08:
			await RenderingServer.frame_post_draw
			_crop_user("_b9_brake_0.png", 2.8)
			br = true
	print("BATCH9 SHOTS DONE")
	get_tree().quit()

func _crop_ball(nm: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var w: Vector2 = vis.to_global(CourtStage.m_project(court.ball.global_position, Court.COURT_H))
	var scr: Vector2 = (w - cam.global_position) * cam.zoom + get_viewport_rect().size * 0.5
	print("   z: ball.h=%.1f off=%s holder=%s uoff=%s cam_zoom=%s dscale=%.3f"
		% [court.ball.h, str(u.dribble_ball_offset()), str(court.ball.holder == u),
			str(u.drib_hint()), str(cam.zoom), CourtStage.m_scale(u.global_position.y, Court.COURT_H)])
	print("   z: crop centro=(%.0f,%.0f) fondo palla=(%.0f,%.0f) u=(%.0f,%.0f)"
		% [scr.x, scr.y, w.x, w.y,
			(u.global_position.x), (u.global_position.y)])
	var size := Vector2(150, 130)
	var r := Rect2i(int(scr.x - size.x * 0.5), int(scr.y - size.y * 0.5 + 46), int(size.x), int(size.y))
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	var z := img.get_region(r)
	z.resize(int(z.get_width() * 4), int(z.get_height() * 4), Image.INTERPOLATE_LANCZOS)
	z.save_png(dir + "/" + nm)
	print("saved ", nm)

func _crop_user(nm: String, zoom: float) -> void:
	var img := get_viewport().get_texture().get_image()
	var w: Vector2 = vis.to_global(CourtStage.m_project(u.global_position, Court.COURT_H))
	var scr: Vector2 = (w - cam.global_position) * cam.zoom + get_viewport_rect().size * 0.5
	var size := Vector2(190, 150)
	var r := Rect2i(int(scr.x - size.x * 0.5), int(scr.y - size.y * 0.5), int(size.x), int(size.y))
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	var z := img.get_region(r)
	z.resize(int(z.get_width() * zoom), int(z.get_height() * zoom), Image.INTERPOLATE_LANCZOS)
	z.save_png(dir + "/" + nm)
	print("saved ", nm)
