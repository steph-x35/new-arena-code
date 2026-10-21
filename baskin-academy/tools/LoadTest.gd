extends Node2D
## DEV ONLY (tools/ is excluded from the export): instantiates every screen of
## this build headless, so a stripped project can be checked before shipping.
##   godot --headless --path . res://tools/LoadTest.tscn

func _ready() -> void:
	var scenes := [
		"res://src/scenes/MainMenu.tscn",
		"res://src/scenes/KitPicker.tscn",
		"res://src/scenes/SettingsScene.tscn",
	]
	for p in scenes:
		var ps: PackedScene = load(p)
		if ps == null:
			print("FAILED TO LOAD ", p)
			continue
		var n: Node = ps.instantiate()
		add_child(n)
		await get_tree().process_frame
		await get_tree().process_frame
		print("OK  ", p, "  children=", n.get_child_count())
		n.queue_free()
		await get_tree().process_frame
	# The match needs its own smoke test (it starts a live game): see SceneSmoke.
	print("LOAD TEST DONE")
	get_tree().quit()
