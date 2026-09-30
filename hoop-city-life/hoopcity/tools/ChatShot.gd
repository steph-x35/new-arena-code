extends Node2D
func _ready() -> void:
	await get_tree().process_frame
	Game.profile = Game.default_profile()
	Game.profile["battery"] = 100.0
	# contatti: coach sbloccato di default (rep 0)? sblocca tutti a forza
	for cid in ["coach", "best", "mom", "agent"]:
		if Contacts.PEOPLE.has(cid):
			Contacts.send(cid, "Domani alle 9 allenamento con la prima squadra dei Devils, non fare tardi!")
			Contacts.receive(cid, "Ok mister, porto anche le nuove scarpe e la fascia di capitano, ci vediamo in campo!")
			Contacts.send(cid, "Perfetto. E ricordati di mangiare prima, che poi sveni a meta' partita come domenica scorsa.")
			Contacts.receive(cid, "Ehehe promesso! A domani allora.")
			Contacts.send(cid, "Porta acqua e asciugamano.")
	var phone = preload("res://src/ui/PhoneUI.gd").new()
	add_child(phone)
	await get_tree().process_frame
	await get_tree().process_frame
	get_window().size = Vector2i(2280, 1080)
	await get_tree().process_frame
	await get_tree().process_frame
	phone.open_app("messages")
	await get_tree().process_frame
	await get_tree().process_frame
	# lista contatti
	var img1: Image = get_viewport().get_texture().get_image()
	img1.save_png("/home/user/chat_list.png")
	# thread view: apri il primo thread con messaggi
	phone.open_thread = "coach"
	phone._refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var img2: Image = get_viewport().get_texture().get_image()
	img2.save_png("/home/user/chat_thread.png")
	print("SHOT pix=", img1.get_width(), "x", img1.get_height(), " mean=", img1.get_used_rect().get_area())
	get_tree().quit()
