extends Node2D
## DEV ONLY entry: hands control to a root-level driver (survives scene
## changes) and jumps to the real MainMenu.
##   godot --headless --path . res://tools/FlowTest.tscn

func _ready() -> void:
	var d: Node = preload("res://tools/FlowTestDriver.gd").new()
	d.name = "FlowDriver"
	get_tree().root.add_child.call_deferred(d)
	await get_tree().process_frame
	SceneRouter.goto(SceneRouter.MENU)
