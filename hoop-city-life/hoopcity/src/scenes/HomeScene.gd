extends Node2D
## Wrapper that scales the 1600x900 apartment art to fit any phone screen,
## keeping the hotspots aligned with the drawing.

var room: Node2D

func _ready() -> void:
	Game.profile["last_building"] = "home"
	room = preload("res://src/scenes/ApartmentRoom.gd").new()
	room.is_floor2 = bool(Game.profile.get("home_view_floor2", false))
	add_child(room)
	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var vp := get_viewport_rect().size
	var s: float = minf(vp.x / 1600.0, vp.y / 900.0)
	room.scale = Vector2(s, s)
	room.position = (vp - Vector2(1600, 900) * s) * 0.5
	# keep the clickable layer locked onto the art (HUD layer stays screen-space)
	if room.spot_layer:
		room.spot_layer.transform = Transform2D(0.0, Vector2.ONE * s, 0.0, room.position)
