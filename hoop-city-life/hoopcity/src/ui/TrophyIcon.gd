extends Control
class_name TrophyIcon

## Icona COPPA disegnata sul canvas (v2.40.4): niente font emoji, niente
## texture importate — la stessa identica coppa dorata su ogni dispositivo.
## Utile come figlio di un Button (disegnata sopra il fondo del bottone).

func _draw() -> void:
	var gold := Color(0.96, 0.78, 0.26)
	var dark := Color(0.52, 0.40, 0.12)
	# manici
	draw_arc(Vector2(7, 11), 5.0, 0.5 * PI, 1.5 * PI, 16, gold, 3.0)
	draw_arc(Vector2(21, 11), 5.0, -0.5 * PI, 0.5 * PI, 16, gold, 3.0)
	# coppa
	var bowl := PackedVector2Array([Vector2(5, 5), Vector2(23, 5), Vector2(20, 15),
		Vector2(14, 19), Vector2(8, 15)])
	draw_colored_polygon(bowl, gold)
	draw_polyline(PackedVector2Array([Vector2(5, 5), Vector2(23, 5), Vector2(20, 15),
		Vector2(14, 19), Vector2(8, 15), Vector2(5, 5)]), dark, 1.4)
	# labbro
	draw_line(Vector2(4, 4), Vector2(24, 4), gold, 4.0)
	draw_line(Vector2(4, 4), Vector2(24, 4), dark, 0.8)
	# stelo e base
	draw_rect(Rect2(12, 19, 4, 4), gold)
	draw_rect(Rect2(8, 23, 12, 4), gold)
	draw_rect(Rect2(8, 23, 12, 4), dark, false, 1.0)
