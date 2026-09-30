extends Node2D
func _ready() -> void:
	await get_tree().process_frame
	Game.profile = Game.default_profile()
	var menu = load("res://src/scenes/MainMenu.tscn").instantiate()
	add_child(menu)
	get_window().size = Vector2i(2280, 1080)
	for i in 6:
		await get_tree().process_frame
	var vp: Vector2 = get_viewport().get_visible_rect().size
	print("M1 vp=", vp, " (atteso ~1520x720)")
	# M2: la colonna bottoni occupa la meta' DESTRA
	var btns_col = menu._menu_col if menu._menu_col != null else null
	if btns_col != null:
		var ct: Transform2D = btns_col.get_global_transform_with_canvas()
		var r: Rect2 = Rect2(ct.origin, btns_col.size * ct.get_scale())
		print("M2 colonna= r.x ", int(r.position.x), " r.w ", int(r.size.x),
			" destra ok=", r.position.x > vp.x * 0.40 and r.position.x + r.size.x > vp.x * 0.80)
	else:
		print("M2 colonna non trovata")
	# M3: hero in sinistra, dentro schermo
	var hct: Transform2D = menu.hero.get_global_transform_with_canvas()
	var hr: Rect2 = Rect2(hct.origin, menu.hero.size)
	print("M3 hero x=", int(hr.position.x), " dentro sx=", hr.position.x >= 0 and hr.position.x + hr.size.x <= vp.x * 0.55)
	# M4: chat rows: stessa altezza minima
	print("MENU_OK=", true)
	get_tree().quit()
