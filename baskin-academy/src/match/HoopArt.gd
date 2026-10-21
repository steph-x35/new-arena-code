extends RefCounted
class_name HoopArt
## THE single source of truth for how a basket looks and how the net reacts.
##
## The rim used to be re-drawn by hand in CourtVisual, SoloCourt and DrillScene,
## so animating the net in one place left the other two static -- that is why
## the swish never showed up in the scrimmage or the drills. Everything that
## draws a hoop now calls in here.
##
## `wobble` is 0..1: 1.0 right after the ball drops through, decaying to 0.
## `phase` is a free-running time value used for the swing oscillation.

## How long the net keeps swinging after a make, in seconds. Long enough that
## you actually register it -- 0.85 s was over before the eye caught it.
const SWING_TIME := 1.4

## How flat the rim's ellipse reads. 1.0 = a perfect circle (camera straight
## down); this is the side view: a wide, open ellipse you can see INTO, which
## is what makes the ring feel 3D and lets the ball visibly drop through it.
const RIM_SQUASH := 0.46

## Padded dunk package at the foot of the pole: crash pad + short run-up so
## every court has a visible dunk zone under the iron.
static func draw_dunk_package(c: CanvasItem, pole_foot: Vector2, rim_floor: Vector2,
		face: float, rim_h: float) -> void:
	var _unused := pole_foot.lerp(rim_floor, 0.55)
	# Unused rim_h kept so callers can pass the real height.
	var _h: float = rim_h
	var _f: float = face

static func decay(wobble: float, delta: float) -> float:
	## Shared decay curve so every scene's net settles at the same rate.
	return maxf(0.0, wobble - delta / SWING_TIME)

# ---------------------------------------------------------------- net
static func draw_net(c: CanvasItem, rim: Vector2, r: float,
		wobble := 0.0, phase := 0.0, depth := 46.0,
		col := Color(1, 1, 1, 0.85)) -> void:
	## A real criss-cross mesh drawn as a cone of rings. When `wobble` is high
	## the lower rings swing sideways and the cone stretches, which reads as the
	## net snapping after a made shot.
	var rows := 5
	var cols := 9
	# The whole motion scales with the rim, so it stays just as visible on the
	# small match hoops as on the big head-on ones. Fixed pixel amounts read as
	# "barely twitching" once the court is zoomed out.
	var amp: float = r * 0.85
	# Snap: the net is yanked down hard on impact, then springs back.
	var snap: float = pow(wobble, 0.55)
	var d: float = depth + snap * r * 1.15
	var grid := []
	for row in rows + 1:
		var f: float = float(row) / rows
		# The cone billows outward as the ball punches through it.
		var bulge: float = 1.0 + snap * 0.42 * sin(f * PI)
		var ring_r: float = lerpf(r, r * 0.42, f) * bulge
		var y: float = rim.y + d * f
		# Lower rings swing further and lag behind the ones above them.
		var swing: float = sin(phase * 17.0 - f * 2.6) * amp * wobble * f
		var ring := []
		for i in cols:
			var a: float = PI * float(i) / float(cols - 1)
			ring.append(Vector2(rim.x - cos(a) * ring_r + swing,
				y + sin(a) * ring_r * 0.28))
		grid.append(ring)

	for i in cols:
		for row in rows:
			c.draw_line(grid[row][i], grid[row + 1][i], col, 1.9)
	for row in rows + 1:
		var faint := Color(col.r, col.g, col.b, col.a * 0.62)
		for i in cols - 1:
			c.draw_line(grid[row][i], grid[row][i + 1], faint, 1.5)
	var diag := Color(col.r, col.g, col.b, col.a * 0.40)
	for row in rows:
		for i in cols - 1:
			c.draw_line(grid[row][i], grid[row + 1][i + 1], diag, 1.2)

static func draw_chain_net(c: CanvasItem, rim: Vector2, r: float,
		wobble := 0.0, phase := 0.0) -> void:
	## Outdoor courts get a steel chain net: same motion, colder colour.
	draw_net(c, rim, r, wobble, phase, 52.0, Color(0.86, 0.89, 0.95, 0.95))

# ---------------------------------------------------------------- full hoops
static func draw_hoop_front(c: CanvasItem, rim: Vector2, scale := 1.0,
		wobble := 0.0, phase := 0.0, chain := false) -> void:
	## Head-on basket for the drill court and the solo court: glass backboard,
	## orange square, rim in perspective, net below.
	var bw: float = 190.0 * scale
	var bh: float = 118.0 * scale
	var top: float = rim.y - 132.0 * scale

	# backboard
	c.draw_rect(Rect2(rim.x - bw * 0.5, top, bw, bh), Color(0.86, 0.92, 1.0, 0.30))
	c.draw_rect(Rect2(rim.x - bw * 0.5, top, bw, bh), Color(0.93, 0.96, 1.0, 0.92),
		false, 4.0 * scale)
	# the shooter's aim square
	var sw: float = 70.0 * scale
	var sh: float = 54.0 * scale
	c.draw_rect(Rect2(rim.x - sw * 0.5, rim.y - sh - 6.0 * scale, sw, sh),
		Color(0.95, 0.35, 0.15, 0.95), false, 4.0 * scale)
	# bottom padding
	c.draw_rect(Rect2(rim.x - bw * 0.5, top + bh, bw, 9.0 * scale),
		Color(0.75, 0.16, 0.16))

	# rim, an ellipse so it reads as a circle seen from slightly above
	var rr: float = 44.0 * scale
	var pts := PackedVector2Array()
	for i in 25:
		var a: float = TAU * i / 24.0
		pts.append(Vector2(rim.x + cos(a) * rr, rim.y + sin(a) * rr * 0.26))
	for i in pts.size() - 1:
		c.draw_line(pts[i], pts[i + 1], Color(0.97, 0.44, 0.12), 6.0 * scale)

	if chain:
		draw_chain_net(c, rim, rr, wobble, phase)
	else:
		draw_net(c, rim, rr, wobble, phase, 52.0 * scale)

## Playground hoop drawn in true side profile: ground pole, offset support arm,
## edge-on backboard standing above the rim, and the rim itself as a bar with
## its red mounting bracket. `dir` is the direction the rim faces (-1 = the
## court is to the left of the pole, which is the usual layout).
## Head-on hoop for the perspective court: pole rising behind the baseline, a
## fan-shaped backboard facing the camera, the ring as an ellipse you can see
## into, and the net hanging below it.
## THE basket. A three-quarter side view: ground pole behind the baseline, a
## support arm reaching forward, the backboard turned slightly towards the
## camera, the ring as an open ellipse you can see into, and the net hanging
## from it. Used by every court in the game -- only the surroundings differ.
##
## `rim` is the CENTRE OF THE OPENING (the point a ball must drop through).
## `face` is +1 when the court lies to the RIGHT of the pole and -1 when it
## lies to the left, so the whole assembly mirrors correctly at each end.
static func draw_hoop_unified(c: CanvasItem, rim: Vector2, rim_half: float,
	floor_y: float, face: float, wobble := 0.0, phase := 0.0,
	lean := 0.0, base_dx := 98.0, board_off := Vector2.ZERO,
	rim_bend := 0.0) -> void:
	## Real hoop: pole plants at the CENTRE of the short baseline, then an L
	## gooseneck bolts to the BACK of the glass. The ring sits centred on that
	## board. The orange shooter's square is painted ON the glass, parallel to
	## it, centred above the iron — never a filled red pad.

	var steel := Color(0.36, 0.38, 0.42)
	var steel_hi := Color(0.52, 0.54, 0.58)
	var steel_lo := Color(0.22, 0.23, 0.26)
	var orange := Color(0.92, 0.36, 0.10)
	var orange_dk := Color(0.55, 0.18, 0.05)
	var glass := Color(0.78, 0.88, 0.96, 0.38)
	var glass_edge := Color(0.94, 0.97, 1.0, 0.95)

	var shake: float = sin(phase * 47.0) * wobble * rim_half * 0.22
	var bounce: float = absf(sin(phase * 29.0)) * wobble * rim_half * 0.12
	var rx: float = rim.x + shake
	var ry: float = rim.y - bounce

	# Board sits a hair behind the ring (away from court). Rim is centred on it.
	# board_off: lo scostamento DEL SOLO TABELLONE (palo e vetro) quando
	# insegue la scossa del ferro in ritardo — il ferro resta dove sta.
	var board_x: float = rx - face * rim_half * 0.55 + board_off.x
	var bh: float = rim_half * 2.55
	var b_bottom: float = ry - rim_half * 0.18 + board_off.y
	var b_top: float = b_bottom - bh

	# Pole FOOT = centre of the short baseline (caller passes that offset).
	var pole_x: float = rx - face * maxf(base_dx, rim_half * 2.15) + board_off.x
	var pw: float = rim_half * 0.50   # FIBA stanchion: a thick padded column
	var elbow_y: float = b_top + bh * 0.42
	var p_bot_x: float = pole_x + lean * (floor_y - b_bottom)
	var p_elb_x: float = pole_x + lean * (elbow_y - b_bottom)

	var along := Vector2(lean, 1.0)
	var al: float = along.length()
	if al > 0.001:
		along /= al
	var half_span: float = rim_half * 1.70
	var tl := Vector2(board_x, b_top) - along * half_span
	var tr := Vector2(board_x, b_top) + along * half_span
	var br := Vector2(board_x, b_bottom) + along * half_span
	var bl := Vector2(board_x, b_bottom) - along * half_span
	var board_mid := (tl + tr + br + bl) * 0.25

	# Shadow at the pole foot.
	var sh_w: float = rim_half * 1.35
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(p_bot_x - sh_w, floor_y),
		Vector2(p_bot_x + sh_w * 0.5, floor_y),
		Vector2(p_bot_x + sh_w * 0.12, floor_y + rim_half * 0.32),
		Vector2(p_bot_x - sh_w * 0.28, floor_y + rim_half * 0.32)]),
		Color(0.08, 0.07, 0.06, 0.26))

	# Padded base pad, like the big FIBA stanchion feet: dark block + lit top.
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(p_bot_x - rim_half * 1.25, floor_y - rim_half * 0.85),
		Vector2(p_bot_x + rim_half * 1.05, floor_y - rim_half * 0.85),
		Vector2(p_bot_x + rim_half * 1.25, floor_y + rim_half * 0.16),
		Vector2(p_bot_x - rim_half * 1.45, floor_y + rim_half * 0.16)]),
		Color(0.10, 0.12, 0.20))
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(p_bot_x - rim_half * 1.25, floor_y - rim_half * 0.85),
		Vector2(p_bot_x + rim_half * 1.05, floor_y - rim_half * 0.85),
		Vector2(p_bot_x + rim_half * 0.95, floor_y - rim_half * 1.02),
		Vector2(p_bot_x - rim_half * 1.35, floor_y - rim_half * 1.02)]),
		Color(0.18, 0.21, 0.32))
	# Base plate.
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(p_bot_x - rim_half * 0.72, floor_y - 2.0),
		Vector2(p_bot_x + rim_half * 0.72, floor_y - 2.0),
		Vector2(p_bot_x + rim_half * 0.58, floor_y + rim_half * 0.14),
		Vector2(p_bot_x - rim_half * 0.46, floor_y + rim_half * 0.14)]), steel_lo)

	# Vertical pole.
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(p_bot_x - pw, floor_y), Vector2(p_bot_x + pw * 0.4, floor_y),
		Vector2(p_elb_x + pw * 0.4, elbow_y), Vector2(p_elb_x - pw, elbow_y)]), steel)
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(p_bot_x + pw * 0.4, floor_y), Vector2(p_bot_x + pw, floor_y),
		Vector2(p_elb_x + pw, elbow_y), Vector2(p_elb_x + pw * 0.4, elbow_y)]), steel_lo)
	c.draw_line(Vector2(p_bot_x - pw * 0.5, floor_y), Vector2(p_elb_x - pw * 0.5, elbow_y),
		steel_hi, maxf(rim_half * 0.045, 1.4))

	# L-arm: from the elbow, horizontal, bolted to the BACK of the board.
	var back_pt: Vector2 = board_mid + Vector2(-face * rim_half * 0.28, -rim_half * 0.08)
	var arm_h: float = rim_half * 0.50
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(p_elb_x - pw, elbow_y - arm_h * 0.35),
		Vector2(p_elb_x + pw, elbow_y + arm_h * 0.35),
		Vector2(back_pt.x + face * rim_half * 0.08, back_pt.y + arm_h * 0.35),
		Vector2(back_pt.x - face * rim_half * 0.08, back_pt.y - arm_h * 0.35)]), steel_hi)
	# diagonal brace + counterweight box behind the column top
	c.draw_line(Vector2(p_elb_x - face * pw * 0.4, elbow_y + rim_half * 0.9),
		back_pt + Vector2(-face * rim_half * 0.35, rim_half * 0.10), steel_lo,
		maxf(rim_half * 0.14, 3.0))
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(p_elb_x - face * rim_half * 0.95 - pw, elbow_y - rim_half * 0.75),
		Vector2(p_elb_x - face * rim_half * 0.95 + pw * 1.4, elbow_y - rim_half * 0.75),
		Vector2(p_elb_x - face * rim_half * 0.95 + pw * 1.4, elbow_y + rim_half * 0.35),
		Vector2(p_elb_x - face * rim_half * 0.95 - pw, elbow_y + rim_half * 0.35)]), steel_lo)

	# Glass board, parallel to the short baseline.
	var thick := Vector2(-face * rim_half * 0.20, -rim_half * 0.08)
	c.draw_colored_polygon(PackedVector2Array([
		tr, tr + thick, br + thick, br]), Color(0.86, 0.90, 0.96, 0.88))
	c.draw_colored_polygon(PackedVector2Array([tl, tr, br, bl]), glass)
	c.draw_polyline(PackedVector2Array([tl, tr, br, bl, tl]), glass_edge, maxf(rim_half * 0.08, 2.6))

	# Shooter's square ON the glass: parallelogram following the board, centred
	# above the rim. Outline only — like a real backboard.
	var sq_span: float = half_span * 0.42
	var sq_top_y: float = b_top + bh * 0.22
	var sq_bot_y: float = b_bottom - rim_half * 0.06
	var sq_tl := Vector2(board_x, sq_top_y) - along * sq_span
	var sq_tr := Vector2(board_x, sq_top_y) + along * sq_span
	var sq_br := Vector2(board_x, sq_bot_y) + along * sq_span
	var sq_bl := Vector2(board_x, sq_bot_y) - along * sq_span
	c.draw_polyline(PackedVector2Array([sq_tl, sq_tr, sq_br, sq_bl, sq_tl]),
		orange, maxf(rim_half * 0.10, 2.8))

	# Rim centred on the board (same along-centre as the square).
	draw_net_perspective(c, Vector2(rx, ry), rim_half, rim_half * RIM_SQUASH,
		wobble, phase, rim_bend, face)
	# Short orange bracket from the bottom-centre of the glass to the ring.
	var hitch := (bl + br) * 0.5
	c.draw_colored_polygon(PackedVector2Array([
		hitch + along * rim_half * 0.12,
		hitch - along * rim_half * 0.12,
		Vector2(rx, ry)]), orange_dk)
	_draw_ring_3d(c, Vector2(rx, ry), rim_half, rim_half * RIM_SQUASH,
		orange, orange_dk, rim_bend, face)

## A solid parallelepiped: a front face in `col`, a shaded side face and a lit
## top face, extruded toward the viewer by `d3`. `x` is the left edge of the
## front face, `top` and `bottom` its vertical span, `w` its width.
static func _box3d(c: CanvasItem, x: float, top: float, bottom: float,
		w: float, col: Color, d3: Vector2) -> void:
	var ft := PackedVector2Array([Vector2(x, top), Vector2(x + w, top),
		Vector2(x + w, bottom), Vector2(x, bottom)])
	c.draw_colored_polygon(ft, col)
	var sd := PackedVector2Array([Vector2(x + w, top), Vector2(x + w + d3.x, top + d3.y),
		Vector2(x + w + d3.x, bottom + d3.y), Vector2(x + w, bottom)])
	c.draw_colored_polygon(sd, col.darkened(0.32))
	var tp := PackedVector2Array([Vector2(x, top), Vector2(x + d3.x, top + d3.y),
		Vector2(x + w + d3.x, top + d3.y), Vector2(x + w, top)])
	c.draw_colored_polygon(tp, col.lightened(0.22))

## A steel ring drawn in true perspective: a thin dark back arc (seen through
## the opening) plus a solid front band whose inner wall is shadowed, so the
## hoop reads as a 3D torus rather than a flat line.
static func _draw_ring_3d(c: CanvasItem, centre: Vector2, rx: float, ry: float,
		orange: Color, dark: Color, bend := 0.0, pdir := -1.0) -> void:
	var N := 40
	## BEND: mensola vera — la piega PARTE DALL'ATTACCO COL TABELLONE
	## (peso 0 lì, il supporto resta fisso) e cresce fino al fronte libero
	## dove tira chi si appende. Il lato del supporto resta su.
	var bend_amt: float = bend * ry * 1.15
	# --- far (upper) arc: the back of the ring, visible through the hole
	# (il lato del giocatore scende anche qui, ma a meta': il ferro e' un pezzo solo)
	var far := PackedVector2Array()
	for k in N + 1:
		var a: float = PI + PI * float(k) / float(N)   # PI .. TAU (top half)
		var pt: Vector2 = centre + Vector2(cos(a) * rx, sin(a) * ry)
		var sd: float = pow((1.0 + cos(a) * pdir) * 0.5, 1.35) * bend_amt * 0.45
		far.append(Vector2(pt.x + pdir * sd * 0.12, pt.y + sd))
	for k in N:
		c.draw_line(far[k], far[k + 1], dark, maxf(rx * 0.12, 3.0))

	# --- near (lower) band: a filled annulus = the front half of the rim
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for k in N + 1:
		var a: float = PI * float(k) / float(N)        # 0 .. PI (bottom half)
		var sd: float = pow((1.0 + cos(a) * pdir) * 0.5, 1.35) * bend_amt
		var po: Vector2 = centre + Vector2(cos(a) * rx, sin(a) * ry)
		outer.append(Vector2(po.x + pdir * sd * 0.15, po.y + sd))
		var pi2: Vector2 = centre + Vector2(cos(a) * rx * 0.66, sin(a) * ry * 0.66)
		inner.append(Vector2(pi2.x + pdir * sd * 0.15, pi2.y + sd))
	var band := PackedVector2Array()
	for p in outer:
		band.append(p)
	for k in range(N, -1, -1):
		band.append(inner[k])
	c.draw_colored_polygon(band, orange)
	# the shadowed inside of the rim, right at the hole's edge
	for k in N:
		c.draw_line(inner[k], inner[k + 1], dark.darkened(0.15), maxf(rx * 0.06, 2.0))
	# a crisp darker lip under the front edge, so the near band reads solid
	for k in N:
		c.draw_line(outer[k], outer[k + 1], dark, maxf(rx * 0.05, 2.0))
	# a highlight along the top of the near band catches the light
	for k in N / 2:
		c.draw_line(outer[k], outer[k + 1], orange.lightened(0.30),
			maxf(rx * 0.045, 1.5))

static func draw_hoop_perspective(c: CanvasItem, rim: Vector2, rim_half: float,
		floor_y: float, wobble := 0.0, phase := 0.0) -> void:
	var dark := Color(0.16, 0.16, 0.17)
	var edge := Color(0.05, 0.05, 0.06)
	var red := Color(0.62, 0.09, 0.09)
	var glass := Color(0.82, 0.90, 0.95, 0.55)

	# --- support: post behind the board, arm coming forward
	c.draw_rect(Rect2(rim.x - 16.0, rim.y - 230.0, 32.0, floor_y - rim.y + 210.0),
		dark)
	c.draw_rect(Rect2(rim.x - 16.0, rim.y - 230.0, 32.0, floor_y - rim.y + 210.0),
		edge, false, 3.0)

	# --- backboard, seen straight on
	var bw := rim_half * 4.0
	var bh := rim_half * 2.6
	var bx := rim.x - bw * 0.5
	var by := rim.y - bh - 14.0
	c.draw_rect(Rect2(bx, by, bw, bh), glass)
	c.draw_rect(Rect2(bx, by, bw, bh), Color(0.95, 0.97, 1.0, 0.95), false, 5.0)
	# the shooter's square
	var sw := rim_half * 1.6
	var sh := rim_half * 1.1
	c.draw_rect(Rect2(rim.x - sw * 0.5, rim.y - sh - 16.0, sw, sh),
		Color(0.95, 0.30, 0.16), false, 5.0)
	# padded underside
	c.draw_rect(Rect2(bx, by + bh, bw, 10.0), red)

	# --- the ring as an open ellipse: you see through it, which is what makes
	# the ball visibly drop INTO the basket rather than behind it.
	var ry := rim_half * 0.34
	var back := PackedVector2Array()
	var front := PackedVector2Array()
	for k in 33:
		var a: float = PI + PI * float(k) / 32.0
		back.append(Vector2(rim.x + cos(a) * rim_half, rim.y + sin(a) * ry))
	for k in 33:
		var a2: float = TAU - PI * float(k) / 32.0
		front.append(Vector2(rim.x + cos(a2) * rim_half, rim.y + sin(a2) * ry))
	# net first, so the ring sits over it
	draw_net_perspective(c, rim, rim_half, ry, wobble, phase)
	for k in back.size() - 1:
		c.draw_line(back[k], back[k + 1], red.darkened(0.25), 6.0)
	for k in front.size() - 1:
		c.draw_line(front[k], front[k + 1], Color(0.95, 0.35, 0.12), 7.0)
	# bracket back to the board
	c.draw_line(Vector2(rim.x, rim.y - ry), Vector2(rim.x, by + bh + 8.0), red, 8.0)

## Net for the head-on hoop: a cone of mesh hanging under the ring.
static func draw_net_perspective(c: CanvasItem, rim: Vector2, rx: float,
		ry: float, wobble := 0.0, phase := 0.0, bend := 0.0, pdir := -1.0) -> void:
	var rows := 7
	var cols := 14
	var snap: float = pow(wobble, 0.55)
	var depth: float = rx * 1.25 + snap * rx * 0.45
	var col := Color(0.93, 0.94, 0.97, 0.85)
	# La RETE SEGUE IL FERRO piegato: agganciata in cima (offset pieno),
	# la pieca si smorza verso l'orlo raccolto (la maglia non e' rigida).
	var bend_amt: float = bend * ry * 1.15
	var grid := []
	for row in rows + 1:
		var f: float = float(row) / rows
		# Billow slightly below the rim, the way a real net kicks out where the
		# ball first punches through, then taper to the gathered bottom.
		var shrink: float = lerpf(1.0, 0.46, f) * (1.0 + 0.12 * sin(f * PI))
		var y: float = rim.y + depth * f
		var swing: float = sin(phase * 15.0 - f * 2.4) * rx * 0.5 * wobble * f
		var ring := []
		for k in cols:
			var a: float = TAU * float(k) / cols
			var sd: float = pow((1.0 + cos(a) * pdir) * 0.5, 1.35) \
				* bend_amt * (1.0 - f * 0.55)
			ring.append(Vector2(rim.x + cos(a) * rx * shrink + swing + pdir * sd * 0.12,
				y + sin(a) * ry * shrink + sd))
		grid.append(ring)
	# top hem: the loops that hook over the ring
	for k in cols:
		var nx: int = (k + 1) % cols
		c.draw_line(grid[0][k], grid[0][nx], col, 2.0)
	for row in rows:
		for k in cols:
			var nx2: int = (k + 1) % cols
			c.draw_line(grid[row][k], grid[row + 1][nx2], col, 1.6)
			c.draw_line(grid[row][nx2], grid[row + 1][k], col, 1.6)
	for k in cols:
		var nx3: int = (k + 1) % cols
		c.draw_line(grid[rows][k], grid[rows][nx3], col.darkened(0.15), 1.8)

## The near (camera-side) half of the net only. Drawn OVER the ball when it is
## dropping through the basket, so the ball reads as passing BEHIND the mesh
## instead of sliding across the front of it. Same geometry as
## draw_net_perspective -- only the bottom arcs of each ring are painted.
static func draw_net_front(c: CanvasItem, rim: Vector2, rx: float,
		ry: float, wobble := 0.0, phase := 0.0, bend := 0.0, pdir := -1.0) -> void:
	var rows := 7
	var snap: float = pow(wobble, 0.55)
	var depth: float = rx * 1.25 + snap * rx * 0.45
	var col := Color(0.96, 0.97, 1.0, 1.0)
	# ANCHE la mezza rete davanti segue il ferro piegato (stessa mensola).
	var bend_amt: float = bend * ry * 1.15
	for row in rows + 1:
		var f: float = float(row) / rows
		if f < 0.12:
			continue
		var shrink: float = lerpf(1.0, 0.46, f) * (1.0 + 0.12 * sin(f * PI))
		var y: float = rim.y + depth * f
		var swing: float = sin(phase * 15.0 - f * 2.4) * rx * 0.5 * wobble * f
		var prev := Vector2.INF
		for k in 9:
			var a: float = PI * float(k) / 8.0     # bottom half of the ring
			var sd: float = pow((1.0 + cos(a) * pdir) * 0.5, 1.35) \
				* bend_amt * (1.0 - f * 0.55)
			var pt := Vector2(rim.x + cos(a) * rx * shrink + swing + pdir * sd * 0.12,
				y + sin(a) * ry * shrink + sd)
			if prev != Vector2.INF:
				c.draw_line(prev, pt, col, 3.2)
			prev = pt
	# gathered hem, so the bottom of the basket reads as closed
	var hem_f := 1.0
	var hem_shrink: float = lerpf(1.0, 0.46, hem_f) * (1.0 + 0.12 * sin(hem_f * PI))
	var hy: float = rim.y + depth * hem_f
	var hswing: float = sin(phase * 15.0 - hem_f * 2.4) * rx * 0.5 * wobble * hem_f
	var hem_prev := Vector2.INF
	for k in 13:
		var a: float = PI * float(k) / 12.0
		var pt := Vector2(rim.x + cos(a) * rx * hem_shrink + hswing,
			hy + sin(a) * ry * hem_shrink)
		if hem_prev != Vector2.INF:
			c.draw_line(hem_prev, pt, col.darkened(0.15), 2.0)
		hem_prev = pt

static func draw_hoop_profile(c: CanvasItem, rim: Vector2, dir: float,
		floor_y: float, wobble := 0.0, phase := 0.0, scale := 1.0) -> void:
	## `rim` is the CENTRE OF THE OPENING -- the point the ball must drop
	## through -- and `dir` points from the rim toward the court, i.e. -1 when
	## the playing surface lies to the left of the pole. Everything hangs off
	## those two facts so the art and the physics can never disagree.
	var dark := Color(0.16, 0.16, 0.17)
	var edge := Color(0.05, 0.05, 0.06)
	var red := Color(0.55, 0.06, 0.06)
	var glass := Color(0.80, 0.88, 0.92)
	var half: float = 42.0 * scale        # matches SoloCourt.RIM_HALF

	# Board sits just BEHIND the ring (away from the court); the pole is
	# further back still.
	var bx: float = rim.x - dir * (half + 16.0 * scale)
	var pole_x: float = rim.x - dir * 210.0 * scale
	var pole_w: float = 44.0 * scale

	# --- base plate
	c.draw_rect(Rect2(pole_x - 58.0 * scale, floor_y - 28.0 * scale,
		116.0 * scale, 28.0 * scale), dark)
	c.draw_rect(Rect2(pole_x - 58.0 * scale, floor_y - 28.0 * scale,
		116.0 * scale, 28.0 * scale), edge, false, 3.0 * scale)

	# --- tapered pole up to the arm
	var top_y: float = rim.y - 30.0 * scale
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(pole_x - pole_w * 0.40, top_y),
		Vector2(pole_x + pole_w * 0.40, top_y),
		Vector2(pole_x + pole_w * 0.66, floor_y - 22.0 * scale),
		Vector2(pole_x - pole_w * 0.66, floor_y - 22.0 * scale)]), dark)
	c.draw_line(Vector2(pole_x - pole_w * 0.40, top_y),
		Vector2(pole_x - pole_w * 0.66, floor_y - 22.0 * scale), edge, 3.0 * scale)
	c.draw_line(Vector2(pole_x + pole_w * 0.40, top_y),
		Vector2(pole_x + pole_w * 0.66, floor_y - 22.0 * scale), edge, 3.0 * scale)

	# --- support arm running from the pole forward to the board
	var arm_y: float = rim.y - 34.0 * scale
	var arm_h: float = 40.0 * scale
	var a0: float = minf(bx, pole_x)
	var a1: float = maxf(bx, pole_x)
	c.draw_rect(Rect2(a0, arm_y - arm_h * 0.5, a1 - a0, arm_h), dark)
	c.draw_rect(Rect2(a0, arm_y - arm_h * 0.5, a1 - a0, arm_h), edge, false, 3.0 * scale)

	# --- backboard seen edge-on: a tall glass slab standing above the ring
	var bw: float = 20.0 * scale
	var bh: float = 168.0 * scale
	c.draw_rect(Rect2(bx - bw * 0.5, rim.y - bh, bw, bh), glass)
	c.draw_rect(Rect2(bx - bw * 0.5, rim.y - bh, bw, bh), edge, false, 3.0 * scale)
	# dark backing plate where the board bolts onto the arm
	var pw: float = 30.0 * scale
	c.draw_rect(Rect2(bx - dir * bw * 0.5 - pw * 0.5 - dir * pw * 0.5,
		rim.y - 62.0 * scale, pw, 132.0 * scale), dark)
	c.draw_rect(Rect2(bx - dir * bw * 0.5 - pw * 0.5 - dir * pw * 0.5,
		rim.y - 62.0 * scale, pw, 132.0 * scale), edge, false, 3.0 * scale)

	# --- red bracket wedge under the ring, tying it back to the board
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(bx, rim.y - 4.0 * scale),
		Vector2(bx, rim.y + 40.0 * scale),
		Vector2(rim.x + dir * half * 0.30, rim.y + 4.0 * scale)]), red)

	# --- the ring: a bar spanning the opening, drawn from the board forward
	var x0: float = minf(rim.x - dir * half, rim.x + dir * half)
	c.draw_rect(Rect2(x0, rim.y - 8.0 * scale, half * 2.0, 15.0 * scale), red)
	c.draw_rect(Rect2(x0, rim.y - 8.0 * scale, half * 2.0, 15.0 * scale),
		edge, false, 3.0 * scale)

	# --- net hanging from the centre of the ring
	draw_net_profile(c, Vector2(rim.x, rim.y + 7.0 * scale), half * 0.92,
		wobble, phase, 104.0 * scale)

## Net drawn in side profile: a criss-cross curtain hanging under the rim bar,
## narrowing toward the bottom. Swings as a whole when the ball disturbs it.
static func draw_net_profile(c: CanvasItem, top: Vector2, half_w: float,
		wobble := 0.0, phase := 0.0, depth := 92.0,
		col := Color(0.10, 0.10, 0.12)) -> void:
	var rows := 6
	var cols := 5
	var snap: float = pow(wobble, 0.55)
	var d: float = depth + snap * depth * 0.28
	var grid := []
	for row in rows + 1:
		var f: float = float(row) / rows
		var w: float = lerpf(half_w, half_w * 0.52, f)
		var y: float = top.y + d * f
		var swing: float = sin(phase * 17.0 - f * 2.6) * half_w * 1.5 * wobble * f
		var ring := []
		for i in cols:
			var u: float = -1.0 + 2.0 * float(i) / float(cols - 1)
			ring.append(Vector2(top.x + u * w + swing, y))
		grid.append(ring)
	# diagonals both ways = the diamond mesh in the reference image
	for row in rows:
		for i in cols - 1:
			c.draw_line(grid[row][i], grid[row + 1][i + 1], col, 2.0)
			c.draw_line(grid[row][i + 1], grid[row + 1][i], col, 2.0)
	# bottom hem
	for i in cols - 1:
		c.draw_line(grid[rows][i], grid[rows][i + 1], col, 2.0)

static func draw_hoop_side(c: CanvasItem, rim: Vector2, s: float,
		wobble := 0.0, phase := 0.0) -> void:
	## Side-on basket for the top-down match court. `s` is -1 for the left
	## basket and +1 for the right one.
	var bx: float = rim.x + s * 34.0
	# backboard seen edge-on
	var x0: float = minf(bx - s * 5.0, bx + s * 5.0)
	c.draw_rect(Rect2(x0, rim.y - 96.0, 10.0, 150.0), Color(0.86, 0.92, 1.0, 0.30))
	c.draw_rect(Rect2(x0, rim.y - 96.0, 10.0, 150.0), Color(0.92, 0.95, 1.0, 0.85), false, 3.0)
	var sx: float = minf(bx - s * 4.0, bx + s * 4.0)
	c.draw_rect(Rect2(sx, rim.y - 54.0, 8.0, 52.0), Color(0.95, 0.35, 0.15, 0.9), false, 4.0)
	c.draw_rect(Rect2(minf(bx - s * 6.0, bx + s * 6.0), rim.y + 46.0, 12.0, 10.0),
		Color(0.75, 0.16, 0.16))

	# connector + rim
	c.draw_line(Vector2(bx, rim.y), Vector2(rim.x + s * 10.0, rim.y),
		Color(0.95, 0.40, 0.10), 6.0)
	var pts := PackedVector2Array()
	for i in 25:
		var a: float = TAU * i / 24.0
		pts.append(Vector2(rim.x + cos(a) * 30.0, rim.y + sin(a) * 11.0))
	for i in pts.size() - 1:
		c.draw_line(pts[i], pts[i + 1], Color(0.97, 0.44, 0.12), 5.0)

	draw_net(c, rim, 30.0, wobble, phase, 44.0)
