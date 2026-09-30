extends Node2D
## Drawn ABOVE the player so the canopy covers him when he hits the map end.

func _ready() -> void:
	z_index = 40
	set_process(false)
	queue_redraw()

func _draw() -> void:
	var leaf := Color(0.16, 0.44, 0.18)
	var trunk := Color(0.28, 0.16, 0.08)
	for x in [-1688.0, 2520.0]:
		for i in 9:
			var y: float = 28.0 + float(i) * 38.0
			var r: float = 46.0 + float(i % 3) * 8.0
			draw_rect(Rect2(x - 8.0, y, 16.0, 70.0), trunk)
			draw_circle(Vector2(x, y - 8.0), r, leaf)
			draw_circle(Vector2(x - 22.0, y + 16.0), r * 0.7, leaf.darkened(0.10))
			draw_circle(Vector2(x + 20.0, y + 12.0), r * 0.65, leaf.lightened(0.06))
		for i in 5:
			var hy: float = 200.0 + float(i) * 28.0
			draw_circle(Vector2(x, hy), 34.0 + float(i % 2) * 8.0, leaf.darkened(0.12))
