extends Control
## Animated, original Hoop City matchup graphics behind the actual match info.
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var t := clampf(elapsed / 0.65, 0.0, 1.0)
	var ease := 1.0 - pow(1.0 - t, 3.0)
	var y := h * 0.34
	var height := h * 0.23
	var left: Color = Game.team_colour(0).darkened(0.34)
	var right: Color = Game.team_colour(1).darkened(0.34)
	left.a = 0.78
	right.a = 0.78
	var slide: float = (1.0 - ease) * w * 0.48
	draw_colored_polygon(PackedVector2Array([
		Vector2(-slide, y), Vector2(w * 0.49 - slide, y),
		Vector2(w * 0.45 - slide, y + height), Vector2(-slide, y + height)]), left)
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.55 + slide, y), Vector2(w + slide, y),
		Vector2(w + slide, y + height), Vector2(w * 0.51 + slide, y + height)]), right)
	# A narrow gold line ties the stage to Hoop City's existing palette.
	draw_rect(Rect2(0, y + height, w, 3), Color(1.0, 0.65, 0.25, ease * 0.75))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(w * 0.05, h * 0.10), "HOOP CITY  /  GAME NIGHT", HORIZONTAL_ALIGNMENT_LEFT, w * 0.9, int(clampf(h * 0.03, 16, 23)), Color(1, 0.78, 0.4, ease))
	draw_string(font, Vector2(w * 0.05, h * 0.91), "TIP-OFF  •  " + Season.match_arena().to_upper(), HORIZONTAL_ALIGNMENT_CENTER, w * 0.9, int(clampf(h * 0.025, 14, 20)), Color(1, 1, 1, ease * 0.55))
