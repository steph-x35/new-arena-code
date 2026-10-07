extends Node2D
## Sideline official: stripes, whistle, runs only along one long sideline.

var side := 1.0          # -1 far sideline, +1 near
var t := 0.0
var pace := 1.0
var tossing := false     # true durante la palla a due: niente inseguimento palla
var toss_t := 0.0        # >0: braccio alzato con la palla in mano

func setup(sideline: float) -> void:
	side = sideline
	pace = randf_range(0.7, 1.15)
	z_index = 8
	position = Vector2(0.0, side * (Court.COURT_H * 0.5 + 28.0))
	set_process(true)

func _process(delta: float) -> void:
	toss_t = maxf(0.0, toss_t - delta)
	if tossing:
		queue_redraw()
		return
	t += delta * pace
	var span: float = Court.COURT_W * 0.42
	var want: float = position.x
	var parent := get_parent()
	if parent != null and parent.get("ball") != null and parent.ball != null:
		want = parent.ball.global_position.x
	elif parent != null and parent.get("user") != null and parent.user != null:
		want = parent.user.global_position.x
	want = clampf(want, -span, span)
	var dx: float = want - position.x
	position.x = move_toward(position.x, want, 240.0 * delta)
	position.y = side * (Court.COURT_H * 0.5 + 26.0)
	# Walk only when actually covering ground.
	if absf(dx) > 4.0:
		t += delta * 2.4
	queue_redraw()

func _draw() -> void:
	var ch: float = Court.COURT_H
	var proj: Vector2 = CourtStage.m_project(position, ch)
	var sc: float = CourtStage.m_scale(position.y, ch)
	draw_set_transform(proj - position, 0.0, Vector2.ONE * sc)
	var h := 46.0
	var facing: float = 1.0 if cos(t * 0.55) > 0.0 else -1.0
	# shadow
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, 4), Vector2(10, 4), Vector2(6, 8), Vector2(-6, 8)]), Color(0, 0, 0, 0.25))
	# legs
	var gait: float = sin(t * 6.0)
	for sx in [-1.0, 1.0]:
		var g: float = gait if sx < 0.0 else -gait
		var hip := Vector2(sx * 5.0, -h * 0.42)
		var foot := Vector2(sx * 5.0 + g * 8.0 * facing, -2.0)
		draw_line(hip, foot, Color(0.18, 0.16, 0.14), 5.0)
		draw_rect(Rect2(foot.x - 6.0, foot.y - 2.0, 12.0, 5.0), Color(0.08, 0.08, 0.09))
	# striped shirt
	var top := -h * 0.82
	var bot := -h * 0.38
	draw_rect(Rect2(-11.0, top, 22.0, bot - top), Color(0.96, 0.96, 0.97))
	for i in 5:
		if i % 2 == 0:
			draw_rect(Rect2(-11.0, top + i * 4.2, 22.0, 4.2), Color(0.08, 0.08, 0.09))
	# shorts
	draw_rect(Rect2(-10.0, bot - 2.0, 20.0, 10.0), Color(0.10, 0.10, 0.12))
	# arms + whistle (col toss: un braccio spara in alto con la palla)
	var sh := Vector2(0.0, top + 6.0)
	draw_line(sh + Vector2(-10, 0), sh + Vector2(-16, 14), Color(0.78, 0.60, 0.48), 4.0)
	if toss_t > 0.0:
		draw_line(sh + Vector2(10, 0), sh + Vector2(18, -26), Color(0.78, 0.60, 0.48), 4.0)
		draw_circle(sh + Vector2(18, -30), 5.0, Color(0.9, 0.62, 0.28))
	else:
		draw_line(sh + Vector2(10, 0), sh + Vector2(14, 8), Color(0.78, 0.60, 0.48), 4.0)
	var head := Vector2(0.0, top - 8.0)
	draw_circle(head, 8.0, Color(0.78, 0.58, 0.44))
	draw_arc(head, 8.0, PI, TAU, 10, Color(0.12, 0.09, 0.08), 5.0)
	# whistle in the mouth
	draw_rect(Rect2(facing * 4.0, head.y + 2.0, facing * 8.0, 3.5), Color(0.85, 0.85, 0.88))
	draw_circle(Vector2(facing * 12.0, head.y + 3.5), 2.2, Color(0.55, 0.55, 0.58))
