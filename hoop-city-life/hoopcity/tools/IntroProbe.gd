extends Node2D
## Verifica la FINESTRA NOVITA' (v2.40.3): deve uscire quando l'intro si
## asseda (subito dopo lo splash di Godot), UNA volta sola per versione.
## Stampa INTRO OK=true/false — la CI lo trasforma in verde/rosso.

func _count_panels() -> int:
	var count := 0
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is GamePanel:
			count += 1
		for c in n.get_children():
			stack.append(c)
	return count

func _clear_news_layers() -> void:
	for c in get_tree().root.get_children():
		if c is CanvasLayer and c.layer == 100:
			c.queue_free()
	await get_tree().process_frame

func _ready() -> void:
	await get_tree().process_frame
	Game.profile = Game.default_profile()
	var intro = load("res://src/scenes/IntroScene.tscn").instantiate()
	add_child(intro)
	for i in 10:
		await get_tree().process_frame
	intro._finish_now()
	for i in 10:
		await get_tree().process_frame
	var n1: int = _count_panels()
	var seen: bool = String(Game.profile.get("changelog_seen", "")) == Game.VERSION
	print("INTRO pass1: pannelli=", n1, " flag=", seen)
	intro.queue_free()
	await _clear_news_layers()
	var intro2 = load("res://src/scenes/IntroScene.tscn").instantiate()
	add_child(intro2)
	for i in 10:
		await get_tree().process_frame
	intro2._finish_now()
	for i in 10:
		await get_tree().process_frame
	var n2: int = _count_panels()
	print("INTRO pass2: pannelli=", n2, " (atteso 0: una volta sola)")
	var ok: bool = n1 == 1 and seen and n2 == 0
	print("INTRO OK=", ok)
	get_tree().quit()
