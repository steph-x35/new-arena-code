extends Node2D
var ms: Node
var c: Court
func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = true
	Game.profile["baskin_role"] = 5
	ms = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	c = ms.get_node("Court")
	c.process_mode = Node.PROCESS_MODE_DISABLED
	c.jump_pending = false
	c.play_live = true
	c.restarting = false
	ms.intro_left = 0.0
	ms.tip_left = 0.0
	if ms.intro_panel != null: ms.intro_panel.hide()
	var u := c.user
	for pl in c.players:
		pl.global_position = Vector2(-800, 250)
	u.global_position = Vector2(-150, 200)
	u.velocity = Vector2.ZERO
	c.give_ball(u)
	c.ball.visible = true
	for i in 4:
		u._dribble_phase = [0.05, 0.65, 1.4, 2.4][i]
		u._drib_cache.clear()
		c.ball._physics_process(0.0)
		u.queue_redraw()
		c.ball.queue_redraw()
		await get_tree().create_timer(0.12).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var vis: Node2D = ms.get_node("CourtVisual")
		var cam: Camera2D = ms.get_node("Camera2D")
		var gp: Vector2 = vis.to_global(CourtStage.m_project(u.global_position, Court.COURT_H) + Vector2(0,-32))
		var at := (gp - cam.global_position) * cam.zoom + get_viewport_rect().size * 0.5
		var rect := Rect2i(int(at.x)-100,int(at.y)-100,200,200).intersection(Rect2i(0,0,img.get_width(),img.get_height()))
		var crop := img.get_region(rect)
		crop.resize(600,600,Image.INTERPOLATE_LANCZOS)
		crop.save_png("/home/user/verifiche-1.17/arm-%d.png" % i)
	ms._on_rule("v_illegal")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/user/verifiche-1.17/rule.png")
	c._inbound(0, c.side_hoops[1])
	await get_tree().create_timer(0.10).timeout
	await RenderingServer.frame_post_draw
	print("VEIL OPACITY ",ms.inbound_veil.modulate.a," size ",ms.inbound_veil.size)
	get_viewport().get_texture().get_image().save_png("/home/user/verifiche-1.17/fade.png")
	await get_tree().create_timer(0.26).timeout
	c.ball._physics_process(0.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/user/verifiche-1.17/inbound.png")
	ms.queue_free()
	await get_tree().process_frame
	get_tree().quit()
