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
var shooter: Node = null
var shot_result_pending := false
var rattled := false               # true: ha gia' toccato il ferro su questo tiro
var made_flag := false
var swish_clean := false   # nothing but net (louder swish)
var last_touch_team := 0
var is_free_throw := false   # this shot counts one and skips normal possession
var prev_h := 0.0
var prev_pos := Vector2.ZERO
var _dribble_falling := true
var flame := false        # NBA JAM: la palla brucia quando il tiratore è HOT

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
	live = false
	_ana = false
	shooter = null
	shot_result_pending = false
	is_free_throw = false
	vel = Vector2.ZERO
	vh = 0.0
	h = 49.0
	last_touch_team = p.team

func detach() -> void:
	holder = null
	live = true

func shoot(from: Vector2, target: Vector2, apex: float, flight_time: float, made: bool, by: Node) -> void:
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
	var rim_h: float = court.RIM_HEIGHT
	_ana_vh0 = (rim_h - h + (G / k) * flight_time) / fT - G / k
	vel = _ana_v0
	vh = _ana_vh0
	_ana = true
	_ana_t = 0.0
	_ana_T = flight_time
	_ana_from = from
	_ana_h0 = h
	prev_h = h
	prev_pos = global_position

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

func pass_to(from: Vector2, target: Vector2, speed: float, by: Node) -> void:
	global_position = from
	h = 55.0
	shooter = null
	shot_result_pending = false
	rattled = false
	detach()
	var d := target - from
	var t: float = maxf(d.length() / speed, 0.12)
	vel = d / t
	vh = (0.5 * G * t * t) * 0.15 / t   # slight loft on the pass
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
		if holder.move_t > 0.0 or holder.fake_t > 0.0 or holder.fake_locked:
			# TRICK/FINTA: i percorsi dedicati (spin che avvolge, crossover
			# con overshoot, palla tenuta al petto in finta).
			var off: Dictionary = holder.dribble_ball_offset()
			global_position = holder.global_position + Vector2(off["x"], 0)
			h = off["h"]
		elif Avatar.palms.has(holder.get_instance_id()):
			# COPIA VERA del court solo: posizione ESATTA del palmo (x laterale
			# ~hd*h*0.30 STABILE, y dal rimbalzo della mano) registrata per-owner.
			var _pm: Vector2 = Avatar.palms[holder.get_instance_id()]
			global_position = holder.global_position + Vector2(_pm.x, 0)
			h = maxf(-_pm.y, 4.0)
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
	# Scia rimossa su richiesta utente: solo la palla vera.

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
	# SCIA: fantasmi dei punti precedenti (stessa proiezione della palla)
	# Scia rimossa su richiesta utente: solo la palla vera.
	var proj: Vector2 = CourtStage.m_project(position, ch)
	var dscale: float = CourtStage.m_scale(position.y, ch)
	# shadow on the floor sells the height
	var shadow_scale := clampf(1.0 - h / 400.0, 0.35, 1.0)
	draw_set_transform(proj - position, 0.0, Vector2.ONE * dscale)
	var r: float = Court.BALL_R
	draw_ellipse_filled(Vector2(0, 0), Vector2(r * 0.92 * shadow_scale, r * 0.35 * shadow_scale), Color(0, 0, 0, 0.28 * shadow_scale))
	var c := Vector2(0, -h)
	# STESSA PALLA del court solo (Avatar): stessa tinta, stesse cuciture.
	draw_circle(c, r, Color(0.95, 0.55, 0.15))
	draw_arc(c, r, 0, TAU, 16, Color(0.35, 0.18, 0.07), maxf(r * 0.14, 1.0))
	draw_line(c + Vector2(-r, 0), c + Vector2(r, 0),
		Color(0.35, 0.18, 0.07), maxf(r * 0.11, 1.0))
	draw_line(c + Vector2(0, -r), c + Vector2(0, r), Color(0.15, 0.09, 0.05), 1.2)
	# NBA JAM HEAT: palla in fiamme mentre il giocatore HOT la tiene o l'ha tirata
	if flame and not bool(Settings.get_v("lowgfx", false)):
		Avatar.draw_flames(self, c + Vector2(0.0, r * 0.35), Time.get_ticks_msec() / 1000.0)

func draw_ellipse_filled(pos: Vector2, radii: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(pos + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, col)
