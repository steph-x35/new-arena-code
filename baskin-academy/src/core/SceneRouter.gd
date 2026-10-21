extends Node
## Centralized navigation. Autoloaded as `SceneRouter`.

const MENU := "res://src/scenes/MainMenu.tscn"
## The courts keep only crowd + SFX: no lounge music over a live game.
const COURT_SCENES := ["MatchScene"]

func goto(path: String) -> void:
	SaveSystem.save_game()
	get_tree().change_scene_to_file(path)
	var is_court := false
	for c in COURT_SCENES:
		if c in path:
			is_court = true
	if not is_court:
		_play_life_deferred()

func _play_life_deferred() -> void:
	await get_tree().process_frame
	Sfx.play_life()
