extends Node2D
func _check(title: String, size: Vector2) -> bool:
	var p := GamePanel.new().build(title, size)
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	p._relayout()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	
	var ok: bool = p.card.position.x >= 7.9 and p.card.position.y >= 7.9 \
		and p.card.position.x + p.card.size.x <= vp.x + 0.6 \
		and p.card.position.y + p.card.size.y <= vp.y + 0.6
	print("  ", title, " card=", p.card.position, "+", p.card.size, " in ", vp, " -> ", ok)
	var ok2: bool = ok
	p.free()
	await get_tree().process_frame
	return ok2
func _ready() -> void:
	await get_tree().process_frame
	Game.profile = Game.default_profile()
	var all_ok := true
	for sz in [Vector2i(1280, 720), Vector2i(2280, 1080), Vector2i(2400, 1080)]:
		get_window().size = sz
		await get_tree().process_frame
		await get_tree().process_frame
		var vp: Vector2 = get_viewport().get_visible_rect().size
		print("WINDOW ", sz, " -> viewport logico ", vp)
		all_ok = await _check("Bed", Vector2(860, 620)) and all_ok
		all_ok = await _check("Panel default", Vector2(900, 760)) and all_ok
	get_window().size = Vector2i(1280, 720)
	print("PHONE_OK=", all_ok)
	get_tree().quit()
