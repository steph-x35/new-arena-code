extends SceneTree
## Regenerates the project-wide theme from Art.make_theme():
##   godot --headless --path . --script res://tools/MakeTheme.gd
func _init() -> void:
	var th: Theme = Art.make_theme()
	var err := ResourceSaver.save(th, "res://src/ui/HoopTheme.tres")
	print("THEME SAVED err=", err)
	quit(0)
