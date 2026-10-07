extends Node2D
## DEV ONLY. Due scatti del batch 7: la scelta della difficolta' nelle
## Impostazioni, e la palla che passa DIETRO la rete del canestro laterale.
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . res://tools/Batch7Shot.tscn
var court: Node2D
var dir := "/home/user"

func _ready() -> void:
	# --- 1. Impostazioni, riga della difficolta'
	Game.profile["next_match_mode"] = "full"
	var st: Node = load("res://src/scenes/SettingsScene.tscn").instantiate()
	add_child(st)
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/_b7_settings.png")
	print("saved _b7_settings.png")
	st.queue_free()
	await get_tree().process_frame

	# --- 2. la palla dentro la rete del canestro laterale
	Game.profile["baskin_role"] = 5
	var ms: Node = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	await get_tree().process_frame
	court = ms.get_node("Court")
	await get_tree().create_timer(9.0).timeout
	var h: Vector2 = court.side_hoops[1]
	for p in court.players:
		if p.team == 1:
			p.global_position = Vector2(-900.0, 430.0)
	court.play_live = true
	court.restarting = false
	court.ft_active = false
	court.inbound_wait = 0.0
	court.shot_clock = 20.0
	# the ball, on its way down through the little rim
	var b: Ball = court.ball
	b.holder = null
	b.live = true
	b.held_still = false
	b.pass_arc = 0.0
	b.dunk_drop = 0.0
	b.global_position = h + Vector2(0.0, 4.0)
	b.h = Court.SIDE_RIM_HEIGHT - 24.0
	b.vh = -150.0
	b.vel = Vector2.ZERO
	var t := 0.0
	while t < 0.30:
		await get_tree().process_frame
		t += get_process_delta_time()
		b.global_position = h + Vector2(0.0, 4.0)
		b.h = maxf(Court.SIDE_RIM_HEIGHT - 24.0 - 90.0 * t, 6.0)
		b.vh = -150.0
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir + "/_b7_side_net.png")
	var vis: Node2D = ms.get_node("CourtVisual")
	var lay: Dictionary = vis.side_hoop_layout(h, 1)
	var rim: Vector2 = lay["rim"]
	var cam: Camera2D = ms.get_node("Camera2D")
	var scr: Vector2 = (vis.to_global(rim) - cam.global_position) * cam.zoom + get_viewport_rect().size * 0.5
	var r := Rect2i(int(scr.x - 170), int(scr.y - 120), 340, 240)
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	var z := img.get_region(r)
	z.resize(z.get_width() * 3, z.get_height() * 3, Image.INTERPOLATE_LANCZOS)
	z.save_png(dir + "/_b7_side_net_z.png")
	print("saved _b7_side_net.png (zoom at %s)" % str(scr.round()))
	get_tree().quit()
