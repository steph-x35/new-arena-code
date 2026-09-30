extends Node2D
func _ready() -> void:
	await get_tree().process_frame
	Game.profile = Game.default_profile()
	get_window().size = Vector2i(2280, 1080)
	for i in 4:
		await get_tree().process_frame
	var gym = load("res://src/scenes/GymScene.tscn").instantiate()
	add_child(gym)
	for i in 6:
		await get_tree().process_frame
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var s: float = gym.scale.x
	var pos: Vector2 = gym.position
	print("G1 scale=", s, " pos=", pos, " vp=", vp)
	# G2: ogni hotspot e' INTERAMENTE dentro lo schermo
	var out := 0
	var tot := 0
	for h in gym.hotspots.get_children():
		if h is Hotspot:
			tot += 1
			var ct: Transform2D = h.get_global_transform_with_canvas()
			var r: Rect2 = Rect2(ct.origin, h.size * ct.get_scale())
			if r.position.x < -0.0 or r.position.y < -0.0 \
			or r.position.x + r.size.x > vp.x + 0.6 or r.position.y + r.size.y > vp.y + 0.6:
				out += 1
				print("  FUORI: ", r, " pos_root=", pos, " layer_t=", gym.spot_layer.transform)
	print("G2 spot dentro=", tot - out, "/", tot)
	print("RF_OK=", s <= (720.0 / 900.0) + 0.001 and out == 0 and tot > 0)
	get_tree().quit()
