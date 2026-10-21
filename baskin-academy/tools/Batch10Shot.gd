extends Node2D
## DEV ONLY. Batch 10: tiro (palla nella tasca e in salita), follow-through,
## posizione difensiva, rimbalzo a due mani, badge BONUS nell'HUD.
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . res://tools/Batch10Shot.tscn
var court: Node2D
var ms: Node
var cam: Camera2D
var vis: Node2D
var u: BallPlayer
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
	u = court.user
	for p in court.players:
		if p != u:
			p.global_position = Vector2(-840.0, 400.0)
			p.velocity = Vector2.ZERO
	court.play_live = true
	court.restarting = false
	court.ft_active = false
	court.shot_clock = 20.0
	u.global_position = Vector2(-180.0, 250.0)
	u.velocity = Vector2.ZERO
	u.move_input = Vector2.ZERO
	u.facing = 1.0
	court.give_ball(u)
	await get_tree().create_timer(0.3).timeout

	# ------------------------------------------- 1. tiro: tasca e salita (4 fasi)
	u.shot_charge = 0.0
	var t := 0.0
	var n := 0
	var marks := [0.02, 0.16, 0.30, 0.44]
	for mk in marks:
		while t < float(mk):
			await get_tree().process_frame
			t += get_process_delta_time()
			court.shot_clock = 20.0
			u.facing = 1.0
			u.velocity = Vector2.ZERO
			u.shot_charge += get_process_delta_time() * 0.42
		await RenderingServer.frame_post_draw
		_crop("_b10_shot_%d.png" % n, 2.4)
		print("   fase %d: carica %.2f, palla a %.0f px" % [n, u.shot_charge, court.ball.h])
		n += 1
	# rilascio + follow-through
	u.shot_charge = u.shot_ideal
	u.do_shot_release()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_crop("_b10_release.png", 2.4)
	await get_tree().create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	_crop("_b10_follow.png", 2.4)

	# ------------------------------------------- 2. posizione difensiva
	court.give_ball(u)
	u.global_position = Vector2(-180.0, 250.0)
	var foe: BallPlayer = null
	for p in court.players:
		if p.team == 1:
			foe = p
			break
	u.has_ball = false
	court.ball.holder = null
	court.ball.live = false
	court.give_ball(foe)
	foe.global_position = Vector2(-180.0, 250.0)
	u.global_position = foe.global_position + Vector2(54.0, 4.0)
	u.guarding = true
	u.stance = true
	u.move_input = Vector2.ZERO
	u.velocity = Vector2.ZERO
	t = 0.0
	while t < 0.6:
		await get_tree().process_frame
		t += get_process_delta_time()
		court.shot_clock = 20.0
		u.guarding = true
		foe.velocity = Vector2.ZERO
	await RenderingServer.frame_post_draw
	_crop("_b10_defend.png", 2.4)
	# in scivolata (laterale): il corpo pende dalla parte del movimento
	t = 0.0
	while t < 0.5:
		await get_tree().process_frame
		t += get_process_delta_time()
		court.shot_clock = 20.0
		u.guarding = true
		u.velocity = Vector2(220.0, 0.0)
		u.move_input = Vector2(1.0, 0.0)
	await RenderingServer.frame_post_draw
	_crop("_b10_slide.png", 2.4)

	# ------------------------------------------- 3. rimbalzo: due mani in alto
	u.guarding = false
	u.global_position = Vector2(-120.0, 250.0)
	t = 0.0
	while t < 0.6:
		await get_tree().process_frame
		t += get_process_delta_time()
		court.shot_clock = 20.0
		u.velocity = Vector2.ZERO
	# a mezz'aria con le mani in alto: posa di rimbalzo (fisica in pausa, o la
	# caduta rimette l'omino a terra prima del disegno)
	u.set_physics_process(false)
	u.jumping = true
	u.air = 84.0
	u.queue_redraw()
	print("   rimbalzo: air=%.0f" % u.air)
	await RenderingServer.frame_post_draw
	_crop_img(get_viewport().get_texture().get_image(),
		_screen_pos(u.global_position) + Vector2(0, -70), Vector2(230, 190), 2.4,
		"_b10_rebound.png")
	await RenderingServer.frame_post_draw
	u.air = 0.0
	u.jumping = false
	u.set_physics_process(true)

	# ------------------------------------------- 4. badge BONUS nell'HUD
	court.team_fouls[1] = 5
	court.shot_clock = 12.0
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var full := get_viewport().get_texture().get_image()
	full.save_png(dir + "/_b10_full.png")
	var top := Vector2(full.get_width() * 0.5 - 120.0, 78.0)
	_crop_img(full, top, Vector2(460, 56), 2.4, "_b10_hud.png")
	print("BATCH10 SHOTS DONE")
	get_tree().quit()

func _crop(nm: String, zoom: float) -> void:
	_crop_img(get_viewport().get_texture().get_image(),
		_screen_pos(u.global_position), Vector2(210, 170), zoom, nm)

func _screen_pos(w: Vector2) -> Vector2:
	var gp: Vector2 = vis.to_global(CourtStage.m_project(w, Court.COURT_H))
	return (gp - cam.global_position) * cam.zoom + get_viewport_rect().size * 0.5

func _crop_img(img: Image, at: Vector2, size: Vector2, zoom: float, nm: String) -> void:
	var r := Rect2i(int(at.x - size.x * 0.5), int(at.y - size.y * 0.5), int(size.x), int(size.y))
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	var z := img.get_region(r)
	z.resize(int(z.get_width() * zoom), int(z.get_height() * zoom), Image.INTERPOLATE_LANCZOS)
	z.save_png(dir + "/" + nm)
	print("saved ", nm)
