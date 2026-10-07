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
	var court: Node = get_parent().get_node_or_null("Court") if get_parent() != null else null
	var hh: float = Court.COURT_H
	var ball: Node = court.ball if court != null else null
	# BASKIN SIDE BASKETS, IN FRONT OF EVERYTHING: the rim belongs in front of
	# the player standing behind it, and fades to show him through.
	for si in [0, 1]:
		var sp: Vector2 = court.side_hoops[si] if court != null \
			else Vector2(0.0, -Court.COURT_H * 0.5 if si == 0 else Court.COURT_H * 0.5)
		var near_body := false
		if court != null:
			for q in court.players:
				if q.global_position.distance_to(sp) < 130.0:
					near_body = true
					break
		_draw_side_basket(sp, si, 0.42 if near_body else 1.0)
		# THE BALL GOES BEHIND THE SIDE NET TOO: while it drops through a side
		# basket, the front half of that mini net is painted over it, exactly
		# like the classic rims.
		if court != null and ball != null and _ball_dropping_through(ball, sp):
			var hh2: float = Court.COURT_H
			var fp: Vector2 = CourtStage.m_project(sp, hh2)
			var rr := Vector2(fp.x, fp.y - Court.SIDE_RIM_HEIGHT)
			HoopArt.draw_net_front(self, rr, 20.0, 7.0,
				vis.net_wobble[2 + si] if (vis != null and 2 + si < vis.net_wobble.size()) else 0.0,
				vis.t if vis != null else 0.0)
	if vis == null:
		return
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
			22.0, 22.0 * HoopArt.RIM_SQUASH, vis.net_wobble[idx], vis.t,
			clampf(vis.rim_bend[idx], 0.0, 1.0), -s)

## Is the ball on its way through this side basket? Same rule the classic rims
## use: it is near the ring, it is low, and it is coming down.
func _ball_dropping_through(b: Node, hoop: Vector2) -> bool:
	if b == null:
		return false
	var h: float = float(b.get("h"))
	var vh: float = float(b.get("vh"))
	if h > Court.SIDE_RIM_HEIGHT + 40.0 or h < 0.0 or vh > 20.0:
		return false
	return b.global_position.distance_to(hoop) < 84.0

## Il canestro laterale VICINO alla telecamera si vede da DIETRO (il pivot ci
## sta dietro): si vede il RETRO del tabellone, con palo e staffa davanti e il
## ferro che spunta sotto. Quello lontano resta in vista frontale.
static func side_hoop_faces_away(pos: Vector2) -> bool:
	return pos.y > 0.0

## A low side basket: pole, glass, ring and net, all at `alpha`.
func _draw_side_basket(pos: Vector2, si: int, alpha: float) -> void:
	var wob: float = vis.net_wobble[2 + si] if (vis != null and 2 + si < vis.net_wobble.size()) else 0.0
	draw_side_basket(self, pos, alpha, wob, vis.t if vis != null else 0.0,
		vis.quake_off(2 + si) if vis != null else Vector2.ZERO,
		(vis.board_quake_off(2 + si) - vis.quake_off(2 + si)) if vis != null else Vector2.ZERO)

## UNA SOLA FONTE del canestro laterale (usata da NetFront sopra i giocatori e
## da CourtVisual per il disegno di base): statica su CanvasItem, cosi' le due
## copie non possono piu' divergere (la vecchia copia in CourtVisual disegnava
## la vista frontale anche sul canestro rigirato).
static func draw_side_basket(ci: CanvasItem, pos: Vector2, alpha: float,
		wob: float, tt: float, quake := Vector2.ZERO, board_off := Vector2.ZERO) -> void:
	var f: Vector2 = CourtStage.m_project(pos, Court.COURT_H) + quake
	var rim := Vector2(f.x, f.y - Court.SIDE_RIM_HEIGHT)
	# bf = ancora del TABELLONE (palo + pannello): insegue il ferro in ritardo
	var bf := f + board_off
	var sway: float = sin(tt * 9.0) * 8.0 * wob
	var steel := Color(0.36, 0.38, 0.42, alpha)
	var orange := Color(0.92, 0.36, 0.10, alpha)
	var glass := Color(0.78, 0.88, 0.96, 0.42 * alpha)
	var lean: float = -10.0 if pos.y < 0.0 else 10.0
	if side_hoop_faces_away(pos):
		# ---- VISTA DA DIETRO (rigirato di 180 gradi): quello che si vede e' il
		# tabellone. Il palo sale DAVANTI al tabellone, la staffa lo aggancia,
		# il ferro resta dietro e spunta appena sotto il bordo basso.
		var back := Color(0.60, 0.67, 0.76, 0.80 * alpha)
		var back2 := Color(0.45, 0.52, 0.60, 0.85 * alpha)
		var board := Rect2(bf.x - 34.0, rim.y - 40.0, 68.0, 32.0)
		# pannello scuro DI STACCO: il tabellone si legge anche contro il
		# maxi-schermo luminoso dell'arena (migliora la vecchia ombra)
		ci.draw_rect(Rect2(bf.x - 40.0, rim.y - 46.0, 80.0, 44.0),
			Color(0.04, 0.05, 0.09, 0.40 * alpha))
		# palo portante, dal parquet al centro del tabellone (davanti a tutto)
		ci.draw_line(bf + Vector2(0, 10), Vector2(bf.x, rim.y - 24.0), steel, 9.0)
		ci.draw_line(bf + Vector2(0, 10), Vector2(bf.x, rim.y - 24.0),
			Color(0.52, 0.55, 0.60, alpha), 4.0)
		# staffa di sostegno del ferro
		ci.draw_line(Vector2(bf.x, rim.y - 24.0), Vector2(bf.x, rim.y - 6.0), steel, 6.0)
		# il RETRO del tabellone: pannello pieno, con il bordo e le viti
		ci.draw_rect(board, back)
		ci.draw_rect(board, back2, false, 3.0)
		for vx in [-26.0, 26.0]:
			ci.draw_circle(Vector2(bf.x + vx, rim.y - 34.0), 2.6, back2)
			ci.draw_circle(Vector2(bf.x + vx, rim.y - 12.0), 2.6, back2)
		# la retina si vede sotto il ferro, un po' accorciata (prospettiva)
		var netb := Color(0.93, 0.94, 0.96, 0.85 * alpha)
		for k in 6:
			var a3 := PI * float(k) / 5.0
			ci.draw_line(Vector2(rim.x + cos(a3) * 18.0, rim.y - 1.0),
				Vector2(rim.x + sway * 0.6 + cos(a3) * 9.0, rim.y + 20.0), netb, 1.5)
		ci.draw_arc(Vector2(rim.x + sway * 0.6, rim.y + 20.0), 9.0, 0, TAU, 12, netb, 1.5)
		# il ferro visto da dietro: spunta sotto il tabellone, solo il bordo
		# vicino e' visibile (l'anello anteriore e' dietro il tabellone).
		ci.draw_arc(Vector2(rim.x, rim.y + 1.0), 20.0, 0.0, PI, 22, orange, 5.0)
		ci.draw_arc(Vector2(rim.x, rim.y + 1.0), 20.0, 0.12 * PI, 0.88 * PI, 20,
			Color(1.0, 0.55, 0.20, alpha), 2.0)
		return
	# ---- VISTA FRONTALE (il canestro dall'altra parte del campo)
	# Il maxi-schermo dell'arena e' chiaro e sta dietro questo canestro:
	# ombra PIU' DECISA (era troppo accennata) + cornice scura attorno al
	# vetro: il canestro laterale lontano si legge subito.
	ci.draw_rect(Rect2(bf.x - 44.0, rim.y - 50.0, 88.0, 86.0),
		Color(0.04, 0.05, 0.09, 0.42 * alpha))
	ci.draw_line(bf + Vector2(0, 10), Vector2(bf.x + lean, rim.y - 30.0), steel, 7.0)
	ci.draw_line(Vector2(bf.x + lean, rim.y - 30.0), Vector2(bf.x, rim.y - 8.0), steel, 5.0)
	ci.draw_rect(Rect2(bf.x - 33.0, rim.y - 41.0, 66.0, 36.0), Color(0.05, 0.06, 0.10, 0.85 * alpha), false, 3.0)
	ci.draw_rect(Rect2(bf.x - 30.0, rim.y - 38.0, 60.0, 30.0), glass)
	ci.draw_rect(Rect2(bf.x - 30.0, rim.y - 38.0, 60.0, 30.0), Color(0.94, 0.97, 1.0, 0.9 * alpha), false, 2.0)
	ci.draw_rect(Rect2(bf.x - 11.0, rim.y - 26.0, 22.0, 14.0), orange, false, 2.5)
	var ring := PackedVector2Array()
	for i in 25:
		var a := TAU * float(i) / 24.0
		ring.append(rim + Vector2(cos(a) * 20.0, sin(a) * 7.0))
	ci.draw_polyline(ring, orange, 4.0)
	var netc := Color(0.93, 0.94, 0.96, 0.92 * alpha)
	for k in 6:
		var a2 := PI * float(k) / 5.0
		ci.draw_line(rim + Vector2(cos(a2) * 20.0, sin(a2) * 7.0),
			Vector2(rim.x + sway + cos(a2) * 7.0, rim.y + 24.0), netc, 1.6)
	ci.draw_arc(Vector2(rim.x + sway, rim.y + 24.0), 7.0, 0, TAU, 12, netc, 1.6)
