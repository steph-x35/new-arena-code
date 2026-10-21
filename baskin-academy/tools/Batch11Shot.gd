extends Node2D
## DEV ONLY. Batch 11: il segno a terra del rimbalzo (palla in aria) e la
## reazione del ferro. Zoom sul punto di caduta.
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . res://tools/Batch11Shot.tscn
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
	# la partita vive, ma nessuno intralcia il quadro
	for p in court.players:
		if p != u:
			p.global_position = Vector2(-840.0, 400.0)
	court.play_live = true
	court.restarting = false
	court.ft_active = false
	court.shot_clock = 20.0
	u.global_position = Vector2(-260.0, 250.0)
	court.give_ball(u)
	await get_tree().create_timer(0.3).timeout

	# ------------------------------------------- 1. palla libera in aria
	# (finta schiacciata mancata dall'altra parte: palla vagante alta)
	var bb: Ball = court.ball
	bb.detach()
	bb.live = true
	bb.shot_result_pending = false
	bb.global_position = Vector2(-200.0, 200.0)
	bb.h = 210.0
	bb.vel = Vector2(120.0, 40.0)
	bb.vh = 60.0
	var shot := 0
	var t := 0.0
	var next_at := 0.0
	while t < 1.1 and shot < 3:
		await get_tree().process_frame
		t += get_process_delta_time()
		court.shot_clock = 20.0
		if t >= next_at:
			next_at = t + 0.28
			bb.queue_redraw()
			await RenderingServer.frame_post_draw
			_crop_ball("_b11_loose_%d.png" % shot, 2.2)
			print("   segno a terra: h=%.0f previsione=%s"
				% [bb.h, str(bb.landing_spot().round())])
			shot += 1

	# ------------------------------------------- 2. il ferro che reagisce
	# (rimbalzo sul ferro: anello arancione + scintille, e la rete che si muove)
	var hz: Vector2 = court.hoops[0]
	var hi := 0
	for i in 2:
		var sp: Vector2 = _screen(court.hoops[i], 150.0)
		if sp.x > 80.0 and sp.x < 1200.0 and sp.y > 60.0 and sp.y < 660.0:
			hz = court.hoops[i]
			hi = i
	print("   ferro inquadrato: %s (indice %d)" % [str(hz), hi])
	court._rim_fx("iron", hz)
	court._net_bump(hi, 1.0)
	await RenderingServer.frame_post_draw
	_crop_floor("_b11_iron.png", hz, 1.8)
	court._rim_fx("swish", hz)
	court._net_bump(hi, 1.0)
	await RenderingServer.frame_post_draw
	_crop_floor("_b11_swish.png", hz, 1.8)

	# ------------------------------------------- 3. quadro intero
	await RenderingServer.frame_post_draw
	var full := get_viewport().get_texture().get_image()
	full.save_png(dir + "/_b11_full.png")
	print("BATCH11 SHOTS DONE")
	get_tree().quit()

func _screen(w: Vector2, lift := 0.0) -> Vector2:
	var gp: Vector2 = vis.to_global(CourtStage.m_project(w, Court.COURT_H) + Vector2(0.0, -lift))
	return (gp - cam.global_position) * cam.zoom + get_viewport_rect().size * 0.5

func _crop_ball(nm: String, zoom: float) -> void:
	var bb: Ball = court.ball
	var at: Vector2 = _screen(bb.global_position, bb.h * 0.30)
	_crop_img(get_viewport().get_texture().get_image(), at + Vector2(10, 40),
		Vector2(340, 260), zoom, nm)

func _crop_floor(nm: String, at: Vector2, zoom: float) -> void:
	_crop_img(get_viewport().get_texture().get_image(),
		_screen(at, 150.0), Vector2(320, 260), zoom, nm)

func _crop_img(img: Image, at: Vector2, size: Vector2, zoom: float, nm: String) -> void:
	var r := Rect2i(int(at.x - size.x * 0.5), int(at.y - size.y * 0.5), int(size.x), int(size.y))
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	var z := img.get_region(r)
	z.resize(int(z.get_width() * zoom), int(z.get_height() * zoom), Image.INTERPOLATE_LANCZOS)
	z.save_png(dir + "/" + nm)
	print("saved ", nm)
