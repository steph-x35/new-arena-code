extends RefCounted
class_name CourtStage
## THE court. One perspective half-court used everywhere -- solo shooting and
## full games alike -- so the venue never changes shape between modes. The only
## thing that varies is the surrounding: an indoor arena in wood, or an outdoor
## street court with trees and graffiti.
##
## Geometry is defined once here, in a simple two-point perspective: the
## baseline sits at the FAR end (small), the near edge of the court is at the
## bottom of the screen (large). `depth01` is 0 at the baseline and 1 at the
## near edge, and `squash()` converts a depth into the horizontal scale at that
## depth, which is what makes lines converge correctly.

## Court dimensions in the drawing space. The half court is 50 ft wide by
## 47 ft deep; we keep that ratio so the paint and the arc land where they
## should relative to the hoop.
const HALF_W_FT := 25.0        # from centre line of court to sideline
const DEPTH_FT := 47.0         # baseline to half-court
const PAINT_HALF_FT := 8.0     # the key is 16 ft wide
const PAINT_DEEP_FT := 19.0    # free-throw line is 19 ft from the baseline
const ARC_FT := 22.15          # three point radius, matching ShotSystem
const RIM_FROM_BASE_FT := 5.25 # rim centre sits 63 inches off the baseline

## Screen anchors. BASE_Y is the far baseline, NEAR_Y the closest floor line.
const BASE_Y := -60.0
const NEAR_Y := 300.0
const BASE_HALF_W := 300.0     # half width of the court AT the baseline
const NEAR_HALF_W := 900.0     # half width at the near edge -- the perspective
const CENTRE_X := 0.0

## Where the rim hangs, in screen space. The backboard stands on the baseline,
## so the rim is slightly in front of it and well above the floor.
const RIM_Y := -250.0
const RIM_HALF := 42.0

static func depth_of_ft(ft: float) -> float:
	## Convert "feet from the baseline" into 0..1 depth.
	return clampf(ft / DEPTH_FT, 0.0, 1.0)

static func y_at(d: float) -> float:
	## Screen Y for a depth. Non-linear so the near floor spreads out, which is
	## what a real camera does.
	var e: float = pow(clampf(d, 0.0, 1.0), 0.86)
	return lerpf(BASE_Y, NEAR_Y, e)

static func half_w_at(d: float) -> float:
	var e: float = pow(clampf(d, 0.0, 1.0), 0.86)
	return lerpf(BASE_HALF_W, NEAR_HALF_W, e)

static func scale_at(d: float) -> float:
	## How big a player standing at this depth should be drawn.
	return half_w_at(d) / BASE_HALF_W * 0.42

## Map a court position -- x in feet either side of the centre, ft from the
## baseline -- onto the screen.
static func to_screen(x_ft: float, from_base_ft: float) -> Vector2:
	var d: float = depth_of_ft(from_base_ft)
	var hw: float = half_w_at(d)
	return Vector2(CENTRE_X + (x_ft / HALF_W_FT) * hw, y_at(d))

## Inverse: which court position is under this screen point. Used to keep the
## player's movement honest in perspective.
static func to_court(p: Vector2) -> Vector2:
	var e: float = clampf((p.y - BASE_Y) / (NEAR_Y - BASE_Y), 0.0, 1.0)
	var d: float = pow(e, 1.0 / 0.86)
	var hw: float = half_w_at(d)
	return Vector2((p.x - CENTRE_X) / maxf(hw, 1.0) * HALF_W_FT, d * DEPTH_FT)

# --------------------------------------------------------------- environment
## Indoor arena: wood panelling, banners, a lit ceiling. Drawn behind the floor.
static func draw_indoor_backdrop(c: CanvasItem, w: float, h: float) -> void:
	var top: float = -h * 0.5
	# deep wood back wall
	c.draw_rect(Rect2(-w * 0.5, top, w, BASE_Y - top + 40.0), Color(0.30, 0.19, 0.12))
	# vertical panelling
	var x: float = -w * 0.5
	while x < w * 0.5:
		c.draw_line(Vector2(x, top), Vector2(x, BASE_Y + 40.0),
			Color(0.24, 0.15, 0.09, 0.55), 3.0)
		x += 78.0
	# horizontal rails
	for k in 3:
		var y: float = top + 60.0 + k * 70.0
		c.draw_line(Vector2(-w * 0.5, y), Vector2(w * 0.5, y),
			Color(0.38, 0.25, 0.15, 0.7), 5.0)
	# stand of seats above the baseline
	c.draw_rect(Rect2(-w * 0.5, BASE_Y - 120.0, w, 120.0), Color(0.16, 0.18, 0.26))
	for row in 3:
		var sy: float = BASE_Y - 108.0 + row * 36.0
		var sx: float = -w * 0.5 + 20.0
		while sx < w * 0.5:
			c.draw_rect(Rect2(sx, sy, 26.0, 24.0), Color(0.22, 0.26, 0.38))
			# a sprinkling of spectators
			if int(sx + row * 37.0) % 3 == 0:
				c.draw_circle(Vector2(sx + 13.0, sy + 6.0), 9.0,
					Color.from_hsv(fmod(absf(sx) * 0.011 + row * 0.2, 1.0), 0.35, 0.62))
			sx += 34.0
	# lit ceiling strip
	c.draw_rect(Rect2(-w * 0.5, top, w, 26.0), Color(0.95, 0.94, 0.86, 0.30))

## Street court: sky, trees, a graffiti wall, chain fence. Same court, different
## world around it.
static func draw_street_backdrop(c: CanvasItem, w: float, h: float, t: float) -> void:
	var top: float = -h * 0.5
	# sky
	c.draw_rect(Rect2(-w * 0.5, top, w, BASE_Y - top + 40.0), Color(0.55, 0.72, 0.86))
	# distant blocks
	for k in 9:
		var bx: float = -w * 0.5 + k * (w / 9.0)
		var bh: float = 90.0 + fmod(float(k) * 53.0, 70.0)
		c.draw_rect(Rect2(bx, BASE_Y - bh - 60.0, w / 9.0 - 12.0, bh),
			Color(0.40, 0.44, 0.52))
	# graffiti wall behind the baseline
	c.draw_rect(Rect2(-w * 0.5, BASE_Y - 96.0, w, 96.0), Color(0.62, 0.60, 0.56))
	var tags := [Color(0.86, 0.25, 0.30), Color(0.25, 0.55, 0.82), Color(0.95, 0.72, 0.20)]
	for k in 7:
		var gx: float = -w * 0.5 + 40.0 + k * (w / 7.0)
		var col: Color = tags[k % tags.size()]
		c.draw_circle(Vector2(gx, BASE_Y - 52.0), 22.0, Color(col, 0.75))
		c.draw_line(Vector2(gx - 26.0, BASE_Y - 26.0), Vector2(gx + 30.0, BASE_Y - 70.0),
			Color(col.darkened(0.2), 0.8), 6.0)
	# trees either side
	for sx in [-w * 0.42, w * 0.40]:
		c.draw_rect(Rect2(sx - 10.0, BASE_Y - 150.0, 20.0, 120.0), Color(0.34, 0.24, 0.16))
		for k in 4:
			var sway: float = sin(t * 0.7 + k) * 5.0
			c.draw_circle(Vector2(sx + sway + (k % 2) * 30.0 - 15.0,
				BASE_Y - 165.0 - k * 22.0), 40.0 - k * 4.0, Color(0.20, 0.45, 0.24))
	# chain-link fence across the back
	var fx: float = -w * 0.5
	while fx < w * 0.5:
		c.draw_line(Vector2(fx, BASE_Y - 96.0), Vector2(fx + 18.0, BASE_Y),
			Color(0.75, 0.78, 0.80, 0.30), 1.5)
		c.draw_line(Vector2(fx + 18.0, BASE_Y - 96.0), Vector2(fx, BASE_Y),
			Color(0.75, 0.78, 0.80, 0.30), 1.5)
		fx += 18.0

# --------------------------------------------------------------- the floor
static func draw_floor(c: CanvasItem, indoor: bool) -> void:
	## Parquet in perspective for the arena, asphalt for the street. Boards run
	## across the court and get closer together toward the baseline, which is
	## what sells the depth.
	var steps := 34
	for k in steps:
		var d0: float = float(k) / steps
		var d1: float = float(k + 1) / steps
		var y0: float = y_at(d0)
		var y1: float = y_at(d1)
		var w0: float = half_w_at(d0)
		var w1: float = half_w_at(d1)
		var shade: float = 0.86 + 0.14 * float(k % 2)
		var col: Color
		if indoor:
			# warm maple, alternating plank tone
			col = Color(0.80, 0.60, 0.36) * shade
			col.a = 1.0
		else:
			col = Color(0.44, 0.46, 0.50) * shade
			col.a = 1.0
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(-w0, y0), Vector2(w0, y0),
			Vector2(w1, y1), Vector2(-w1, y1)]), col)

	if indoor:
		# long plank seams running INTO the screen, converging on the vanishing
		# point -- the strongest perspective cue on the floor.
		for i in range(-9, 10):
			var f: float = float(i) / 9.0
			c.draw_line(
				Vector2(f * BASE_HALF_W, y_at(0.0)),
				Vector2(f * NEAR_HALF_W, y_at(1.0)),
				Color(0.62, 0.44, 0.24, 0.30), 2.0)

## All the painted markings, in the same perspective as the floor.
static func draw_lines(c: CanvasItem, paint: Color) -> void:
	var line := Color(0.97, 0.96, 0.92, 0.92)

	# --- the key: a trapezoid, wider at the near end because of perspective
	var d_ft_top: float = 0.0
	var d_ft_bot: float = PAINT_DEEP_FT
	var tl: Vector2 = to_screen(-PAINT_HALF_FT, d_ft_top)
	var tr: Vector2 = to_screen(PAINT_HALF_FT, d_ft_top)
	var br: Vector2 = to_screen(PAINT_HALF_FT, d_ft_bot)
	var bl: Vector2 = to_screen(-PAINT_HALF_FT, d_ft_bot)
	c.draw_colored_polygon(PackedVector2Array([tl, tr, br, bl]), paint)
	for pair in [[tl, tr], [tr, br], [br, bl], [bl, tl]]:
		c.draw_line(pair[0], pair[1], line, 4.0)

	# --- free-throw circle, an ellipse squashed by the perspective
	var ft_c: Vector2 = to_screen(0.0, PAINT_DEEP_FT)
	var ft_rx: float = (6.0 / HALF_W_FT) * half_w_at(depth_of_ft(PAINT_DEEP_FT))
	var circ := PackedVector2Array()
	for k in 41:
		var a: float = TAU * float(k) / 40.0
		circ.append(ft_c + Vector2(cos(a) * ft_rx, sin(a) * ft_rx * 0.34))
	for k in circ.size() - 1:
		c.draw_line(circ[k], circ[k + 1], line, 3.0)

	# --- three point line: straight along the corners, then the arc, all of it
	# projected point by point so it curves the way the floor does.
	var arc := PackedVector2Array()
	var rim_ft := RIM_FROM_BASE_FT
	for k in 61:
		var a: float = PI * float(k) / 60.0
		var x_ft: float = cos(a) * ARC_FT
		var y_ft: float = rim_ft + sin(a) * ARC_FT
		# clamp into the corners, as the real line does
		x_ft = clampf(x_ft, -HALF_W_FT + 3.0, HALF_W_FT - 3.0)
		arc.append(to_screen(x_ft, clampf(y_ft, 0.0, DEPTH_FT)))
	for k in arc.size() - 1:
		c.draw_line(arc[k], arc[k + 1], line, 4.0)
	# the two corner straights down to the baseline
	c.draw_line(to_screen(-HALF_W_FT + 3.0, 0.0), arc[arc.size() - 1], line, 4.0)
	c.draw_line(to_screen(HALF_W_FT - 3.0, 0.0), arc[0], line, 4.0)

	# --- baseline and sidelines
	c.draw_line(to_screen(-HALF_W_FT, 0.0), to_screen(HALF_W_FT, 0.0), line, 5.0)
	c.draw_line(to_screen(-HALF_W_FT, 0.0), to_screen(-HALF_W_FT, DEPTH_FT), line, 5.0)
	c.draw_line(to_screen(HALF_W_FT, 0.0), to_screen(HALF_W_FT, DEPTH_FT), line, 5.0)
	# half-court line at the near edge
	c.draw_line(to_screen(-HALF_W_FT, DEPTH_FT), to_screen(HALF_W_FT, DEPTH_FT), line, 5.0)

	# --- restricted area under the rim
	var ra := PackedVector2Array()
	for k in 25:
		var a2: float = PI * float(k) / 24.0
		ra.append(to_screen(cos(a2) * 4.0, rim_ft + sin(a2) * 4.0))
	for k in ra.size() - 1:
		c.draw_line(ra[k], ra[k + 1], Color(1, 1, 1, 0.5), 3.0)


# ============================================================ MATCH PROJECTION
## The full-court match keeps its simulation in honest top-down coordinates --
## x along the length, y across the width -- because the AI, the passing lanes
## and the collision maths all depend on it. The tilt you see is applied at
## DRAW time only, by these three functions. Nothing in the simulation ever
## learns that the camera is angled.
##
## y = -H/2 is the FAR sideline (small, high on screen)
## y = +H/2 is the NEAR sideline (large, low on screen)

const M_SQUASH := 0.40        # how much the width flattens: a LOW camera
const M_FAR_SCALE := 0.74     # size of a player on the far sideline
const M_NEAR_SCALE := 1.16    # size of a player on the near sideline
const M_LIFT := 60.0          # how far the far side rides up the screen

## 0 at the far sideline, 1 at the near sideline.
static func m_depth(y: float, court_h: float) -> float:
	return clampf((y + court_h * 0.5) / maxf(court_h, 1.0), 0.0, 1.0)

## Project a top-down court point into the tilted view.
static func m_project(p: Vector2, court_h: float) -> Vector2:
	var d: float = m_depth(p.y, court_h)
	# Width narrows hard with distance, so the far sideline is clearly shorter
	# than the near one and the two baselines lean inward -- the court reads as
	# a deep, slanted floor instead of a flat strip.
	var wide: float = lerpf(0.76, 1.16, d)
	return Vector2(p.x * wide, p.y * M_SQUASH - M_LIFT * (1.0 - d))

## How big something standing at this depth should be drawn.
static func m_scale(y: float, court_h: float) -> float:
	return lerpf(M_FAR_SCALE, M_NEAR_SCALE, m_depth(y, court_h))


# ====================================================== SHARED HORIZONTAL COURT
## THE court, drawn once, used by every mode: scrimmage, 1v1, the street court
## and the gym drills. It is always the same full horizontal floor in the same
## perspective -- only the surroundings change (indoor arena vs outdoor park),
## and whether there are other players on it.
##
## `env` is "arena" or "street".
static func draw_full_court(c: CanvasItem, w: float, h: float, env: String,
		t := 0.0) -> void:
	if env == "street":
		_full_street_backdrop(c, w, h, t)
	else:
		_full_arena_backdrop(c, w, h)
	_full_floor(c, w, h, env)

static func _full_arena_backdrop(c: CanvasItem, w: float, h: float) -> void:
	# tiered seating and a dark bowl behind the far sideline
	var far_y: float = m_project(Vector2(0.0, -h * 0.5), h).y
	c.draw_rect(Rect2(-w, far_y - 900.0, w * 2.0, 900.0), Color(0.07, 0.08, 0.13))
	for row in 5:
		var ry: float = far_y - 60.0 - row * 58.0
		c.draw_rect(Rect2(-w, ry, w * 2.0, 46.0),
			Color(0.14, 0.16, 0.24).lerp(Color(0.20, 0.23, 0.33), float(row) / 4.0))
		var sx: float = -w
		while sx < w:
			if int(absf(sx) + row * 31.0) % 4 != 0:
				c.draw_circle(Vector2(sx + 14.0, ry + 20.0), 11.0,
					Color.from_hsv(fmod(absf(sx) * 0.007 + row * 0.17, 1.0), 0.34, 0.60))
			sx += 30.0
	# advertising hoarding along the front of the stand
	c.draw_rect(Rect2(-w, far_y - 58.0, w * 2.0, 56.0), Color(0.11, 0.16, 0.30))

static func _full_street_backdrop(c: CanvasItem, w: float, h: float,
		t: float) -> void:
	var far_y: float = m_project(Vector2(0.0, -h * 0.5), h).y
	# sky and city block
	c.draw_rect(Rect2(-w, far_y - 900.0, w * 2.0, 900.0), Color(0.53, 0.71, 0.86))
	var bx: float = -w
	var i := 0
	while bx < w:
		var bh: float = 150.0 + fmod(float(i) * 97.0, 220.0)
		c.draw_rect(Rect2(bx, far_y - 120.0 - bh, 150.0, bh),
			Color(0.38, 0.42, 0.50).lerp(Color(0.30, 0.33, 0.42), fmod(float(i) * 0.3, 1.0)))
		bx += 175.0
		i += 1
	# trees behind the fence — foliage follows season (dry + drop in autumn)
	var fol: float = WeatherArt.foliage()
	var leaf: Color = WeatherArt.leaf_color()
	var tx: float = -w + 120.0
	while tx < w:
		c.draw_rect(Rect2(tx - 9.0, far_y - 190.0, 18.0, 120.0), Color(0.32, 0.23, 0.15))
		if fol > 0.05:
			for k in 3:
				c.draw_circle(Vector2(tx + sin(t * 0.6 + k) * 5.0 + (k - 1) * 26.0,
					far_y - 210.0 - k * 20.0), (42.0 - k * 6.0) * lerpf(0.35, 1.0, fol),
					Color(leaf.r, leaf.g, leaf.b, fol))
			if WeatherArt.season() == "autumn":
				for k in 5:
					var ly: float = far_y - 210.0 + fmod(t * 50.0 + float(k) * 37.0 + tx, 180.0)
					c.draw_circle(Vector2(tx + sin(t + k) * 30.0, ly), 3.0, Color(0.62, 0.32, 0.10, 0.7))
		else:
			for k in 4:
				var a: float = -2.4 + k * 0.55
				c.draw_line(Vector2(tx, far_y - 190.0),
					Vector2(tx + cos(a) * 40.0, far_y - 190.0 + sin(a) * 30.0),
					Color(0.32, 0.23, 0.15), 3.0)
			if WeatherArt.season() == "winter" or WeatherArt.weather() == "snow":
				c.draw_circle(Vector2(tx, far_y - 200.0), 16.0, Color(0.94, 0.96, 1.0, 0.7))
		tx += 380.0
	WeatherArt.draw_sky_weather(c, Vector2(-w, far_y - 900.0), Vector2(w * 2.0, 900.0), t)
	if WeatherArt.weather() == "snow" or WeatherArt.season() == "winter":
		c.draw_rect(Rect2(-w, far_y - 40.0, w * 2.0, 50.0), Color(0.92, 0.94, 0.98, 0.40))
	# graffiti wall + chain fence
	c.draw_rect(Rect2(-w, far_y - 120.0, w * 2.0, 120.0), Color(0.60, 0.58, 0.55))
	var tags := [Color(0.86, 0.25, 0.30), Color(0.25, 0.55, 0.82), Color(0.95, 0.72, 0.20)]
	var gx: float = -w + 90.0
	var gi := 0
	while gx < w:
		# al centro del muro no tag casuali: lì vive il piece col nome della
		# carriera (disegnato da SoloCourt sopra il backdrop)
		if absf(gx) < 230.0:
			gx += 300.0
			gi += 1
			continue
		var col: Color = tags[gi % tags.size()]
		c.draw_circle(Vector2(gx, far_y - 66.0), 26.0, Color(col, 0.7))
		c.draw_line(Vector2(gx - 32.0, far_y - 30.0), Vector2(gx + 36.0, far_y - 96.0),
			Color(col.darkened(0.25), 0.75), 7.0)
		gx += 300.0
		gi += 1
	var fx: float = -w
	while fx < w:
		c.draw_line(Vector2(fx, far_y - 120.0), Vector2(fx + 20.0, far_y),
			Color(0.78, 0.80, 0.82, 0.28), 1.5)
		c.draw_line(Vector2(fx + 20.0, far_y - 120.0), Vector2(fx, far_y),
			Color(0.78, 0.80, 0.82, 0.28), 1.5)
		fx += 20.0

static func _full_floor(c: CanvasItem, w: float, h: float, env: String) -> void:
	var wood: bool = env != "street"
	var base: Color = Color(0.86, 0.68, 0.42) if wood else Color(0.44, 0.46, 0.50)
	# floor slab, projected
	c.draw_colored_polygon(PackedVector2Array([
		m_project(Vector2(-w * 0.5, -h * 0.5), h),
		m_project(Vector2(w * 0.5, -h * 0.5), h),
		m_project(Vector2(w * 0.5, h * 0.5), h),
		m_project(Vector2(-w * 0.5, h * 0.5), h)]), base)
	# planking / asphalt grain running across the court
	var plank := 26.0
	var y: float = -h * 0.5
	var row := 0
	while y < h * 0.5:
		var y2: float = minf(y + plank, h * 0.5)
		if row % 2 == 0:
			var tone: Color = Color(0.83, 0.64, 0.39) if wood else Color(0.42, 0.44, 0.48)
			c.draw_colored_polygon(PackedVector2Array([
				m_project(Vector2(-w * 0.5, y), h), m_project(Vector2(w * 0.5, y), h),
				m_project(Vector2(w * 0.5, y2), h), m_project(Vector2(-w * 0.5, y2), h)]),
				tone)
		y = y2
		row += 1
