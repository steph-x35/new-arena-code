extends Node
## Centralized navigation + phone overlay. Autoloaded as `SceneRouter`.

var phone_instance: Node = null

const COURT_SCENES := ["MatchScene", "DrillScene", "GymScene", "SoloCourt", "TeamCourt"]

func goto(path: String) -> void:
	SaveSystem.save_game()
	get_tree().change_scene_to_file(path)
	# Jazz everywhere in the life sim; the courts keep only crowd + SFX.
	var is_court := false
	for c in COURT_SCENES:
		if c in path:
			is_court = true
	if not is_court:
		_play_life_deferred()

func _play_life_deferred() -> void:
	await get_tree().process_frame
	Sfx.play_life()

func open_phone() -> void:
	if phone_instance != null and is_instance_valid(phone_instance):
		return
	phone_instance = preload("res://src/ui/PhoneUI.tscn").instantiate()
	get_tree().root.add_child(phone_instance)

func close_phone() -> void:
	if phone_instance and is_instance_valid(phone_instance):
		phone_instance.queue_free()
	phone_instance = null
