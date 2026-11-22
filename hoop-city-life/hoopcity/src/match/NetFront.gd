extends Node2D
class_name NetFront
## Draws the near (camera-side) half of each net OVER the ball whenever a ball
## is dropping through the basket, so the ball reads as passing BEHIND the mesh
## instead of sliding across the front of it. The full net stays on CourtVisual
## (behind the players and ball); this node is a sibling of the Court with a
## higher z_index, so it is the only thing painted on top.

var vis: Node2D = null    # the CourtVisual whose net_wobble/t we mirror

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if vis == null:
		return
	var court: Node = get_parent().get_node_or_null("Court") if get_parent() != null else null
	var hh: float = Court.COURT_H
	var ball: Node = court.ball if court != null else null
	for s in [-1.0, 1.0]:
		var hx: float = s * (Court.COURT_W * 0.5 - Court.FIBA_HOOP_INSET)
		var hoop := Vector2(hx, 0.0)
		var idx: int = 0 if s < 0.0 else 1
		# Same as street court: near mesh only while the ball is dropping
		# through THIS rim, so it reads as going behind the net.
		if ball == null or ball.global_position.distance_to(hoop) >= 55.0:
			continue
		# Do not paint a net over an airball or a miss beside the basket.
		var through: bool = ball.dunk_drop > 0.0 or (ball.shot_result_pending and ball.vh < 0.0 and ball.h <= Court.RIM_HEIGHT and ball.h > Court.RIM_HEIGHT - 45.0)
		if not through:
			continue
		var foot: Vector2 = CourtStage.m_project(hoop, hh)
		# The full hoop moves slightly on impact; the foreground must follow it.
		var wobble: float = vis.net_wobble[idx]
		var shake: float = sin(vis.t * 47.0) * wobble * 22.0 * 0.22
		var bounce: float = absf(sin(vis.t * 29.0)) * wobble * 22.0 * 0.12
		var net_rim := Vector2(foot.x + shake, foot.y - vis.rim_height - bounce)
		var ball_depth: float = clampf((Court.RIM_HEIGHT - ball.h) / 36.0, 0.0, 1.0)
		HoopArt.draw_net_front(self, net_rim,
			22.0, 22.0 * HoopArt.RIM_SQUASH, wobble, vis.t,
			clampf(vis.rim_bend[idx], 0.0, 1.0), -s, ball_depth)
