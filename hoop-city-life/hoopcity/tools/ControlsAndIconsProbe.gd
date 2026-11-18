extends Node

func _ready() -> void:
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "1v1"
	Game.profile["match_is_fixture"] = false
	SceneRouter.friendly_1v1 = true
	var game = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.set_process(false)
	var court: Court = game.court
	court.set_physics_process(false)
	court.call_foul(court.players[1], court.user, 2)
	var ok: bool = not court.ft_active and court.awaiting_check
	court.confirm_check()
	game._apply_pad(true)
	ok = ok and game.btn_shoot.visible and game.btn_crossover.visible and game.btn_post.visible
	game._apply_pad(false)
	ok = ok and game.btn_block.visible and game.btn_steal.visible and game.btn_guard.visible
	game.queue_free()
	await get_tree().process_frame
	FoodReward._show(10.0, 5.0, -2.0)
	ok = ok and FoodReward.icons is HBoxContainer and FoodReward.icons.get_child_count() == 3
	FoodReward._close()
	Game.add_social_post("@probe", "hello", 2)
	var phone = load("res://src/ui/PhoneUI.tscn").instantiate()
	add_child(phone)
	await get_tree().process_frame
	phone.open_app("social")
	await get_tree().process_frame
	var like: Button = null
	for row in phone.body.get_children():
		if row is HBoxContainer and row.get_child_count() > 0 and row.get_child(0) is Button:
			like = row.get_child(0)
			break
	if like == null:
		ok = false
	else:
		like.pressed.emit()
		ok = ok and bool(Game.profile["social"][0].get("liked_by_player", false)) and like.text.contains("3")
		like.pressed.emit()
		ok = ok and not bool(Game.profile["social"][0].get("liked_by_player", true)) and like.text.contains("2")
	phone.queue_free()
	print("CONTROLS_AND_ICONS_OK=", ok)
	get_tree().quit(0 if ok else 1)
