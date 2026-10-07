extends Node2D

func _ready() -> void:
	var ps: PackedScene = load("res://src/scenes/KitPicker.tscn")
	var n: Node = ps.instantiate()
	add_child(n)
	await get_tree().process_frame
	await get_tree().process_frame
	var root: Control = n.get_node("UI/Root")
	print("root rect: ", root.get_global_rect())
	for c in root.get_children():
		var r: Rect2 = (c as Control).get_global_rect() if c is Control else Rect2()
		print("  ", c.get_class(), " name=", c.name, " rect=", r, " vis=", (c as Control).visible if c is Control else "-")
	get_tree().quit()
