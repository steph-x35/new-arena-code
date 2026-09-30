extends Control
class_name PosterThumb
## A Control that paints a poster's real artwork, so the shop can show you
## exactly what you are buying before you buy it.

@export var poster_id := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	PosterArt.draw_poster(self, poster_id, Rect2(Vector2.ZERO, size), 0.0, true)
