extends Node2D
## DEV ONLY. Batch 8: la panchina che esulta dopo un canestro e il cronometro
## rosso negli ultimi 5 secondi, in partita.
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . res://tools/Batch8Shot.tscn
var court: Node2D
var dir := "/home/user"

func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = true
	Game.profile["baskin_role"] = 5
	var ms: Node = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	await get_tree().process_frame
	court = ms.get_node("Court")
	await get_tree().create_timer(9.0).timeout
	# la panchina di casa esulta, gli ospiti restano seduti
	court.bench_cheer[0] = 3.0
	court.bench_cheer[1] = 0.0
	# cronometro negli ultimi secondi
	court.play_live = true
	court.restarting = false
	court.ft_active = false
	court.shot_clock = 4.0
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir + "/_b8_match.png")
	print("saved _b8_match.png")
	# zoom: la panchina di sinistra (quella che esulta) e il cronometro
	var cam: Camera2D = ms.get_node("Camera2D")
	var vis: Node2D = ms.get_node("CourtVisual")
	var bench_w: Vector2 = vis.to_global(CourtStage.m_project(Vector2(-380.0, -(Court.COURT_H * 0.5 + 44.0)), Court.COURT_H))
	var scr: Vector2 = (bench_w - cam.global_position) * cam.zoom + get_viewport_rect().size * 0.5
	_crop(img, scr, Vector2(300, 150), 2.0, "_b8_bench_z.png")
	# il badge del cronometro apre la riga di stato
	var top := Vector2(img.get_width() * 0.5 - 120.0, 78.0)
	_crop(img, top, Vector2(420, 56), 2.4, "_b8_clock_z.png")
	get_tree().quit()

func _crop(img: Image, at: Vector2, size: Vector2, zoom: float, nm: String) -> void:
	var r := Rect2i(int(at.x - size.x * 0.5), int(at.y - size.y * 0.5), int(size.x), int(size.y))
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	var z := img.get_region(r)
	z.resize(int(z.get_width() * zoom), int(z.get_height() * zoom), Image.INTERPOLATE_LANCZOS)
	z.save_png(dir + "/" + nm)
	print("saved ", nm)
