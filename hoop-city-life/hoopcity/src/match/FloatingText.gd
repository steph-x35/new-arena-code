extends Node2D
## Short-lived world-space score/combo callout. Position is given in flat court
## coordinates; _draw projects it like every other court entity, so the text
## tracks the camera and sits at the right depth on the tilted floor.

var text := ""
var col := Color.WHITE
var life := 1.0
var max_life := 1.0
var big := false
var rise := 90.0

func setup(p: Vector2, t: String, c: Color, is_big: bool) -> void:
	text = t
	col = c
	big = is_big
	max_life = 1.5 if big else 1.0
	life = max_life
	global_position = p
	z_index = 60

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var f: float = 1.0 - life / max_life
	var dscale: float = CourtStage.m_scale(global_position.y, Court.COURT_H)
	var proj: Vector2 = CourtStage.m_project(global_position, Court.COURT_H)
	proj.y -= rise * f + Court.RIM_HEIGHT * 0.5
	var fs: int = 54 if big else 34
	var alpha: float = clampf(life / (max_life * 0.35), 0.0, 1.0)
	# pop scale
	var sc: float = dscale
	if f < 0.18:
		sc *= lerpf(0.4, 1.0, f / 0.18)
	elif f > 0.7:
		sc *= 1.0 - (f - 0.7) * 0.25
	var font := ThemeDB.fallback_font
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var origin := Vector2(-w * 0.5, fs * 0.35)
	draw_set_transform(proj, 0.0, Vector2.ONE * sc)
	for ox in [-2.0, 2.0]:
		for oy in [-2.0, 2.0]:
			draw_string(font, origin + Vector2(ox, oy) / sc, text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85 * alpha))
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		Color(col.r, col.g, col.b, alpha * col.a))
	draw_set_transform_matrix(Transform2D.IDENTITY)
