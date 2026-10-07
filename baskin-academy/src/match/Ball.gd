extends Node2D
class_name Ball
## 2D side-view ball with a faked third axis (height above floor).
## pos.x/pos.y = floor plane in screen space; `h` = height in px above the floor line.
## This lets a side-view 2D game keep believable arcs, rim/backboard bounces and
## rebounds without a full 3D physics engine.

const G := 1800.0          # px/s^2
const AIR := 0.06          # drag
const REST_FLOOR := 0.62   # restitution
const REST_RIM := 0.45

var vel := Vector2.ZERO    # planar velocity
var h := 0.0               # height
var vh := 0.0              # vertical velocity
var live := false          # in flight (nobody holding it)
var holder: Node = null
var flame := false                 # heat check: la palla dell'utente in fuoco brucia
var held_still := false       # inbound: the ball waits in the hands, no dribble
var shooter: Node = null
var pass_target: Node = null      # the man this pass is meant for (caught in his hands)
var pass_from: Node = null        # who threw it (the catcher books the rules)
## MAGNET PASS (>0 while a pass is in the air). The ball is steered, every
## frame, at the receiver's HANDS: a man on the run is met exactly where he
## is, the line stays tight (a small hump, no lob) and the ball comes to rest
## in the palm -- never on the floor, never past him. Euler gravity used to
## give a 3 px loft, so passes bounced their way to the receiver.
var pass_arc := 0.0
var _pa_from := Vector2.ZERO
var _pa_to := Vector2.ZERO
var _pa_tracking := false     # distinguishes an expired receiver from a point-only pass
var _pa_who: Node = null          # him the ball is homing to
var _pa_speed := 620.0
var _pa_t := 0.0
var _pa_T := 1.0
var _pa_hump := 16.0
var _pa_dist0 := 1.0
var _pa_hs := 55.0                # where the ball leaves the hand
var _pa_he := 49.0                # where it is taken in the hand
var shot_result_pending := false
var rattled := false               # true: ha gia' toccato il ferro su questo tiro
var made_flag := false
var swish_clean := false   # nothing but net (louder swish)
var last_touch_team := 0
var is_free_throw := false   # this shot counts one and skips normal possession
var shot_hoop := Vector2.ZERO   # exact basket this shot is going at (baskin: 4 hoops)
var shot_is_side := false
var shot_rim_h := -1.0          # altezza del ferro di QUESTO tiro (ruolo 1 basso / 2 alto)
var shot_value := 2             # baskin point value, set by Court.attempt_shot
var prev_h := 0.0
var prev_pos := Vector2.ZERO
var _land_cache := Vector2.ZERO
var _land_at := -1                 # fotogramma fisico della previsione
var _land_ok := false
var _dribble_falling := true

## Closed-form ballistic flight. Integrating the arc with Euler steps made
## the landing point depend on the physics delta: at coarse steps (fast sim,
## or a phone dropping frames) a "made" shot could miss the rim by 100+ px.
## Sampling the analytic curve instead is exact at ANY delta.
var _ana := false
var _ana_t := 0.0
var _ana_T := 1.0
var _ana_from := Vector2.ZERO
var _ana_v0 := Vector2.ZERO
var _ana_h0 := 0.0
var _ana_vh0 := 0.0

@onready var court: Node2D = get_parent()

func _ready() -> void:
	z_index = 40

func attach(p: Node) -> void:
	holder = p
	pass_target = null
	pass_from = null
	pass_arc = 0.0
	_pa_who = null
	held_still = false
	live = false
	_ana = false
	shooter = null
	shot_result_pending = false
	is_free_throw = false
	vel = Vector2.ZERO
	vh = 0.0
	h = 49.0
	last_touch_team = p.team
	shot_hoop = Vector2.ZERO
	shot_is_side = false
	shot_rim_h = -1.0
	shot_value = 2

func detach() -> void:
	holder = null
	held_still = false
	live = true
	pass_target = null
	pass_arc = 0.0
	_pa_who = null

func shoot(from: Vector2, target: Vector2, apex: float, flight_time: float, made: bool, by: Node, rim_h := -1.0) -> void:
	## Solve a ballistic arc that lands on the rim in `flight_time` seconds.
	global_position = from
	h = 67.0
	shooter = by
	made_flag = made
	shot_result_pending = true
	is_free_throw = false
	detach()
	# Closed-form solution with linear drag k=AIR:
	#   x(t) = from + v0 * (1 - e^-kt) / k
	#   h(t) = h0 + (vh0 + G/k)(1 - e^-kt)/k - (G/k) t
	# Solve v0 and vh0 so that x(T) = target and h(T) = rim, exactly.
	var k := AIR
	var fT := (1.0 - exp(-k * flight_time)) / k
	_ana_v0 = (target - from) / fT
	var want_h: float = rim_h if rim_h > 0.0 else court.RIM_HEIGHT
	shot_rim_h = want_h
	_ana_vh0 = (want_h - h + (G / k) * flight_time) / fT - G / k
	vel = _ana_v0
	vh = _ana_vh0
	_ana = true
	_ana_t = 0.0
	_ana_T = flight_time
	_ana_from = from
	_ana_h0 = h
	prev_h = h
	prev_pos = global_position

## Palla VIVA e libera (rimbalzo, palla vagante)... oppure no.
func is_loose() -> bool:
	return holder == null and live and pass_arc <= 0.0 and dunk_drop <= 0.0

## DOVE ARRIVERA' A TERRA, se nessuno la tocca. Integra in avanti lo STESSO
## modello con cui la palla vola (gravita' + attrito d'aria, o l'arco
## analitico quando e' un tiro), quindi la previsione e' quella che si vedra'
## davvero. E' quello che rende un rimbalzo ANTICIPABILE: gli altri la leggono
## per andarci, il gioco ci disegna il segno a terra. Una volta per fotogramma
## (la chiedono in tanti, il conto si fa una volta sola).
func landing_spot() -> Vector2:
	if not is_loose():
		return Vector2.INF
	var stamp: int = Engine.get_physics_frames()
	if _land_at == stamp:
		return _land_cache if _land_ok else Vector2.INF
	_land_at = stamp
	_land_ok = false
	if h <= 1.0 and vh <= 0.0:
		_land_cache = global_position
		_land_ok = true
		return _land_cache
	var dt := 1.0 / 60.0
	var t := 0.0
	var p: Vector2 = global_position
	var ph: float = h
	if _ana:
		while t < 2.6:
			t += dt
			var g: float = (1.0 - exp(-AIR * t)) / AIR
			p = _ana_from + _ana_v0 * g
			ph = _ana_h0 + (_ana_vh0 + G / AIR) * g - (G / AIR) * t
			if ph <= 0.0:
				break
	else:
		var v: Vector2 = vel
		var pv: float = vh
		while t < 2.6 and ph > 0.0:
			t += dt
			v *= (1.0 - AIR * dt)
			p += v * dt
			pv -= G * dt
			ph += pv * dt
	_land_cache = p
	_land_ok = true
	return p

func kill_analytic() -> void:
	## After any rim/board interaction the ball switches back to plain
	## Euler physics: bounces and loose-ball rolls do not need arc exactness.
	if _ana:
		_ana = false

## Counts 1 -> 0 while the ball is drawn dropping through the ring after a
## dunk. Without this the ball was simply switched off at the moment of the
## slam, so it never visibly went in.
var dunk_drop := 0.0
## Through-the-net fall after a slam: drifts from the rim to the centre of
## the short baseline, so the ball lands under the stanchion (correct
## perspective) instead of piling up at the dunker's feet.
var dunk_from := Vector2.ZERO
var dunk_to := Vector2.ZERO

func pass_to(from: Vector2, target: Vector2, speed: float, by: Node, to_player: Node = null) -> void:
	global_position = from
	h = 55.0
	shooter = null
	shot_result_pending = false
	rattled = false
	detach()
	var d := target - from
	var t: float = maxf(d.length() / speed, 0.12)
	vel = d / t
	vh = 0.0
	# DIRECT: a chest pass, not a lob. The hump only clears the hand it leaves
	# and the hand it reaches; it grows a little with the distance.
	_pa_from = from
	_pa_to = target
	_pa_who = to_player
	_pa_tracking = is_instance_valid(to_player)
	_pa_speed = speed
	_pa_dist0 = maxf(from.distance_to(target), 1.0)
	_pa_hump = clampf(8.0 + d.length() * 0.030, 8.0, 30.0)
	_pa_hs = 55.0
	_pa_he = 49.0
	if to_player is BallPlayer and to_player.role <= 2 and d.length() < 190.0:
		# CONSEGNA (hand-off): la palla passa di mano in mano, bassa e subito.
		_pa_hump = 5.0
		_pa_hs = 49.0
		_pa_he = 46.0
	_pa_t = 0.0
	_pa_T = t
	pass_arc = 1.0
	pass_from = by
	last_touch_team = by.team

func _physics_process(delta: float) -> void:
	# The ball falling through the net after a dunk. It owns its position for
	# this short window, so it runs before anything else.
	if dunk_drop > 0.0:
		z_index = 8
		holder = null
		dunk_drop = maxf(dunk_drop - delta * 1.7, 0.0)
		var f: float = 1.0 - dunk_drop            # 0 at the rim, 1 on the floor
		h = maxf(lerpf(Court.RIM_HEIGHT + 26.0, 0.0, f * f), 0.0)
		if dunk_to != dunk_from:
			global_position = dunk_from.lerp(dunk_to, f * f)
		queue_redraw()
		return
	z_index = 40
	if holder != null:
		# A dead-ball inbound: the ball simply RESTS in the thrower's hands --
		# no dribble bob, no bounce, until the pass is released.
		if held_still:
			# Dead ball: it simply rests IN his hands (the same point a pass
			# homes to, so "in hand" and "caught" are the same spot).
			if holder.has_method("ball_anchor"):
				global_position = holder.ball_anchor()
			else:
				global_position = holder.global_position + Vector2(18.0 * holder.facing, 0.0)
			h = 49.0
			queue_redraw()
			return
		# A slam: the ball rides the hand all the way to the iron. Checked
		# before the dribble bob so the two can never fight over the ball.
		if holder.has_method("carry_ball_offset"):
			var carry: Dictionary = holder.carry_ball_offset()
			if bool(carry.get("active", false)):
				global_position = holder.global_position + Vector2(carry["x"], 0.0)
				h = carry["h"]
				queue_redraw()
				return
		# dribble bob: readable, tells the eye the ball is being handled.
		# During a crossover/stepback/behind-the-back the holder's offset
		# animates the ball through the move, so it never just bounces in
		# place while the body teleports around it.
		if holder.has_method("dribble_ball_offset"):
			var off: Dictionary = holder.dribble_ball_offset()
			global_position = holder.global_position + Vector2(off["x"], 0)
			h = off["h"]
		else:
			var side := 22.0 * (1.0 if holder.facing >= 0 else -1.0)
			global_position = holder.global_position + Vector2(side, 0)
			h = 27.0 + abs(sin(Time.get_ticks_msec() / 130.0)) * 42.0 * holder.dribble_intensity
		# Thud exactly at the bottom of the dribble arc. The holder controls
		# h directly (no physics), so we watch the sign change of the height.
		if _dribble_falling and h >= prev_h:
			Sfx.dribble_thud()
			_dribble_falling = false
		elif h < prev_h:
			_dribble_falling = true
		queue_redraw()
		return
	if not live:
		return
	if pass_arc > 0.0 and _pa_tracking and not is_instance_valid(_pa_who):
		pass_arc = 0.0
		_pa_who = null
		pass_target = null
		pass_from = null
		vh = -30.0
	if pass_arc > 0.0:
		# MAGNET: no gravity, no floor. The ball is steered at the receiver's
		# hands, so it meets him in the run and never slips past.
		_pa_t += delta
		var aim: Vector2 = _pa_to
		if is_instance_valid(_pa_who) and _pa_who is BallPlayer and not _pa_who.has_ball:
			# Where his hands are NOW, with a whisker of lead so the ball closes
			# the gap on a running man instead of trailing him. Far away the
			# aim BENDS after the hands (the hands themselves swing when he
			# turns, and snapping the target would make the ball jink); inside
			# arm's reach the target is the palm exactly, so it lands in it.
			var lead: Vector2 = _pa_who.velocity * 0.10
			# Il vantaggio non deve mai superare la presa: la palla va NELLE
			# mani, non davanti a lui (con un uomo veloce finiva 25 px avanti
			# e la presa non scattava piu').
			if lead.length() > 12.0:
				lead = lead.normalized() * 12.0
			var want: Vector2 = _pa_who.ball_anchor() + lead
			if global_position.distance_to(want) < 46.0:
				_pa_to = want
			else:
				_pa_to = _pa_to.lerp(want, clampf(delta * 9.0, 0.08, 1.0))
			aim = _pa_to
		var dvec: Vector2 = aim - global_position
		var dist: float = dvec.length()
		# FLUID: soft release out of the thrower's hand, and the step is capped
		# at the distance left, so the ball lands ON the hand without overshoot.
		var ease_in: float = clampf(_pa_t / 0.06, 0.25, 1.0)
		var step: float = minf(_pa_speed * ease_in * delta, dist)
		if dist > 0.001:
			global_position += dvec / dist * step
		var prog: float = clampf(_pa_t / maxf(_pa_T, 0.05), 0.0, 1.0)
		h = lerpf(_pa_hs, _pa_he, prog) + _pa_hump * sin(PI * prog)
		prev_pos = global_position
		prev_h = h
		if _pa_t > _pa_T + 0.45:
			# Nobody took it (he was blocked off, the ball was refused): it drops.
			pass_arc = 0.0
			_pa_who = null
			pass_from = null
			vh = -30.0
		queue_redraw()
		return

	prev_h = h
	prev_pos = global_position
	if _ana:
		_ana_t += delta
		var k := AIR
		var e := exp(-k * _ana_t)
		var f := (1.0 - e) / k
		global_position = _ana_from + _ana_v0 * f
		h = _ana_h0 + (_ana_vh0 + G / k) * f - (G / k) * _ana_t
		vel = _ana_v0 * e
		vh = (_ana_vh0 + G / k) * e - G / k
		if _ana_t > _ana_T + 0.6:
			_ana = false
	else:
		vel *= (1.0 - AIR * delta)
		global_position += vel * delta
		vh -= G * delta
		h += vh * delta

	court.check_ball_collisions(self)

	if h <= 0.0:
		h = 0.0
		if absf(vh) < 60.0:
			vh = 0.0
			vel *= 0.86
			if vel.length() < 25.0:
				vel = Vector2.ZERO
		else:
			Sfx.bounce(clampf(absf(vh) / 900.0, 0.7, 1.25))
			vh = -vh * REST_FLOOR
			vel *= 0.88
		if shot_result_pending:
			court.resolve_missed_shot(self)
	queue_redraw()

func _draw() -> void:
	# Projected like the players so the ball sits in the same tilted world.
	var ch: float = Court.COURT_H
	var proj: Vector2 = CourtStage.m_project(position, ch)
	var dscale: float = CourtStage.m_scale(position.y, ch)
	# shadow on the floor sells the height
	var shadow_scale := clampf(1.0 - h / 400.0, 0.35, 1.0)
	draw_set_transform(proj - position, 0.0, Vector2.ONE * dscale)
	var r: float = Court.BALL_R
	draw_ellipse_filled(Vector2(0, 0), Vector2(r * 0.92 * shadow_scale, r * 0.35 * shadow_scale), Color(0, 0, 0, 0.28 * shadow_scale))
	# No landing marker: the prediction remains available to AI only.
	var c := Vector2(0, -h)
	# STESSA PALLA di Hoop City: tinta piu' calda e cuciture spesse che si
	# legano da lontano (prima era un'arancia spenta con fili sottili).
	draw_circle(c, r, Color(0.95, 0.55, 0.15))
	draw_arc(c, r, 0, TAU, 16, Color(0.35, 0.18, 0.07), maxf(r * 0.14, 1.0))
	draw_line(c + Vector2(-r, 0), c + Vector2(r, 0),
		Color(0.35, 0.18, 0.07), maxf(r * 0.11, 1.0))
	draw_line(c + Vector2(0, -r), c + Vector2(0, r), Color(0.15, 0.09, 0.05), 1.2)
	# HEAT CHECK: palla in fiamme mentre il giocatore HOT la tiene o l'ha tirata
	if flame and not bool(Settings.get_v("lowgfx", false)):
		Avatar.draw_ball_flames(self, c, r, Time.get_ticks_msec() / 1000.0,
			Vector2(vel.x, vel.y * 0.5 - vh))

func draw_ellipse_filled(pos: Vector2, radii: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(pos + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, col)
