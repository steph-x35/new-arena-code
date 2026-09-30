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
		var near := false
		if ball != null:
			var dropping: bool = ball.dunk_drop > 0.0 \
				or (ball.h < Court.RIM_HEIGHT + 40.0 and ball.h > 2.0 \
				and ball.global_position.distance_to(hoop) < 90.0)
			near = dropping
		if not near:
			continue
		var foot: Vector2 = CourtStage.m_project(hoop, hh)
		HoopArt.draw_net_front(self, Vector2(foot.x, foot.y - vis.rim_height),
			22.0, 22.0 * HoopArt.RIM_SQUASH, vis.net_wobble[idx], vis.t)
