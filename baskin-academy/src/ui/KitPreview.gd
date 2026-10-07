extends Control
class_name KitPreview
## Live look at the two kits side by side, drawn with the same jersey shape the
## shop uses, so what you pick is what you will see on court.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.12, 0.17))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.12), false, 2.0)
	var f := ThemeDB.fallback_font
	for team in 2:
		var c := Vector2(size.x * (0.28 + team * 0.44), size.y * 0.48)
		_jersey(c, Game.team_colour(team), 1.7)
		draw_string(f, Vector2(c.x - 54.0, size.y - 18.0),
			"YOU" if team == 0 else "THEM", HORIZONTAL_ALIGNMENT_CENTER, 108, 18,
			Color(1, 1, 1, 0.7))

func _jersey(c: Vector2, col: Color, s: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-16, -16) * s, c + Vector2(-8, -20) * s, c + Vector2(8, -20) * s,
		c + Vector2(16, -16) * s, c + Vector2(22, -6) * s, c + Vector2(15, -2) * s,
		c + Vector2(15, 20) * s, c + Vector2(-15, 20) * s, c + Vector2(-15, -2) * s,
		c + Vector2(-22, -6) * s]), col)
	draw_arc(c + Vector2(0, -18) * s, 7.0 * s, 0, PI, 12, col.darkened(0.35), 3.0)
