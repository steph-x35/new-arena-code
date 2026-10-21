extends Node2D
func _ready() -> void:
	await get_tree().process_frame
	Game.profile = Game.default_profile()
	Game.profile["battery"] = 100.0
	for cid in Contacts.PEOPLE:
		Contacts.send(cid, "Domani alle 9 allenamento con la prima squadra, non fare tardi!")
		Contacts.receive(cid, "Ok, porto le scarpe nuove e la fascia di capitano, a domani in campo!")
		break
	var phone = preload("res://src/ui/PhoneUI.gd").new()
	add_child(phone)
	await get_tree().process_frame
	await get_tree().process_frame
	get_window().size = Vector2i(2280, 1080)
	await get_tree().process_frame
	# Biden both: lista e thread
	phone.open_app("messages")
	await get_tree().process_frame
	phone.open_thread = Contacts.PEOPLE.keys()[0]
	phone._refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	# C1: il frame sta dentro lo schermo
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var fr: Vector2 = phone.frame.get_global_rect().size
	var c1: bool = fr.x <= vp.x and fr.y <= vp.y
	print("C1 frame_in_screen=", c1, " frame=", fr, " vp=", vp)
	# C2: le bolle non collassano e non sforano il frame
	var bad := 0
	var count := 0
	for b in phone.body.get_children():
		if b is PanelContainer:
			count += 1
			var bw: float = b.size.x if b.size.x > 0 else 120.0
			var mw: float = phone.frame.size.x
			var inner = b.get_child(0)
			for lbl in inner.get_children():
				if lbl is Label and lbl.custom_minimum_size.x > 0.0:
					if lbl.custom_minimum_size.x < 100.0 or lbl.custom_minimum_size.x > mw - 90.0:
						bad += 1
	print("C2 bolle=", count, " fuori_range=", bad)
	# C3: scia palla RIMOSSA ovunque
	var bi = FileAccess.open("res://src/match/Ball.gd", FileAccess.READ).get_as_text()
	var si = FileAccess.open("res://src/scenes/SoloCourt.gd", FileAccess.READ).get_as_text()
	var c3: bool = not bi.contains("draw_polyline") and not si.contains("draw_polyline") \
		and not bi.contains("trail.append") and not si.contains("trail.append")
	print("C3 scia_rimossa=", c3)
	print("CHAT_OK=", c1 and bad == 0 and c3)
	get_tree().quit()
