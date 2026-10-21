extends Node2D
## DEV ONLY. Batch 14 (v1.15.0): il pannello SOSTITUZIONI aperto e un cambio in
## corso (chi esce a piedi verso la panchina, chi entra verso il campo).
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . res://tools/Batch14Shot.tscn
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
	await get_tree().create_timer(0.5).timeout

	# ------------------------------------------- 1. il pannello dei cambi
	ms._open_subs()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("   pannello aperto: %s" % str(ms.sub_panel.visible))
	print("   in campo: %d voci, panchina: %d voci"
		% [ms.sub_court_box.get_child_count(), ms.sub_bench_box.get_child_count()])
	get_viewport().get_texture().get_image().save_png(dir + "/_b14_panel.png")
	print("saved _b14_panel.png")
	ms.sub_panel.visible = false

	# ------------------------------------------- 2. un cambio in corso
	var out_p: BallPlayer = null
	for p in court.players:
		if p.team == 0 and p.role == 4 and not p.is_user:
			out_p = p
	var seats: Array = court.available_sub_seats()
	print("   cambio: fuori #%d, posto %s" % [out_p.jersey_num, str(seats)])
	court.request_sub(out_p, int(seats[0]))
	# palla morta per un istante: parte la camminata
	var t := 0.0
	while t < 6.0 and not court.players.has(out_p) == false:
		await get_tree().process_frame
		t += get_process_delta_time()
		court.play_live = false
		court.restarting = true
		if court._sub_walk.size() > 0 and t > 0.6:
			break
	# inquadratura sulla panchina: i due si incrociano
	ms.set_process(false)
	ms.hud.visible = false
	cam.global_position = Vector2(0.0, ms.CAM_HEIGHT - 120.0)
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var walk: Array = court._sub_walk
	if not walk.is_empty():
		var a: Vector2 = walk[0][0].global_position
		var b: Vector2 = walk[0][1].global_position
		print("   in cammino: uscito %s, entrato %s" % [str(a.round()), str(b.round())])
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir + "/_b14_walk.png")
	print("saved _b14_walk.png")
	# zoom sul tratto panchina-campo: i due si incrociano li'
	if not walk.is_empty():
		var a: Vector2 = walk[0][0].global_position
		var b: Vector2 = walk[0][1].global_position
		var at: Vector2 = (a + b) * 0.5
		_crop_img(img, _screen(at, 40.0), Vector2(460, 340), 1.8, "_b14_walkz.png")
	print("BATCH14 SHOTS DONE")
	get_tree().quit()

func _screen(w: Vector2, lift := 0.0) -> Vector2:
	var gp: Vector2 = vis.to_global(CourtStage.m_project(w, Court.COURT_H) + Vector2(0.0, -lift))
	return (gp - cam.global_position) * cam.zoom + get_viewport_rect().size * 0.5

func _crop_img(img: Image, at: Vector2, size: Vector2, zoom: float, nm: String) -> void:
	var r := Rect2i(int(at.x - size.x * 0.5), int(at.y - size.y * 0.5), int(size.x), int(size.y))
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x < 8 or r.size.y < 8:
		return
	var z := img.get_region(r)
	z.resize(int(z.get_width() * zoom), int(z.get_height() * zoom), Image.INTERPOLATE_LANCZOS)
	z.save_png(dir + "/" + nm)
	print("saved ", nm)
