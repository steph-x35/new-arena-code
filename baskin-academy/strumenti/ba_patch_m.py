#!/usr/bin/env python3
"""BA_PATCH_M - "il passaggio deve essere fluido, come una calamita, diretto".

Riscrive il passaggio guidato del batch L in un passaggio MAGNETICO:
 - parte dalle mani del passatore e punta SEMPRE alle mani del compagno,
   ricalcolando la mira a ogni frame (nessun anticipo sbagliato, nessuna
   palla che passa dietro o davanti al ricevitore);
 - linea tesa: piccola gobba (8-30 px) invece del pallonetto, "diretto";
 - arrivo ammortizzato: la palla si posa nella mano e resta lì finché la
   presa scatta (nessun rimbalzo a terra, nessun pop);
 - il ricevitore si gira verso la palla che arriva (presa "calamita");
 - la presa è registrata da Court._catch_pass(), che conserva le regole del
   pivot (niente resa immediata al tutor).

Idempotente e con anchor verificati.
"""
import io, sys

ROOT = "/home/user/baskin_academy/"
n = 0
def edit(path, old, new, tag, count=1):
    global n
    p = ROOT + path
    s = io.open(p, encoding="utf-8").read()
    if new in s:
        print("skip", path, tag)
        return
    if old not in s:
        print("MISS", path, tag)
        sys.exit(1)
    s = s.replace(old, new, count)
    io.open(p, "w", encoding="utf-8").write(s)
    n += 1
    print("ok  ", path, tag)

# ----------------------------------------------------------------- Ball.gd ---
edit("src/match/Ball.gd",
'''var pass_target: Node = null      # the man this pass is meant for (caught in his hands)
## GUIDED PASS ARC (>0 while a pass is in the air). Euler gravity gave the
## ball a 3 px loft, so every pass dipped into the floor and bounced its way
## to the receiver. A pass now follows an explicit arc from hand height to
## hand height, so it arrives in the team-mate's hands -- flat ground, no
## rebound, at any distance and at any frame rate.
var pass_arc := 0.0
var _pa_from := Vector2.ZERO
var _pa_to := Vector2.ZERO
var _pa_t := 0.0
var _pa_T := 1.0''',
'''var pass_target: Node = null      # the man this pass is meant for (caught in his hands)
var pass_from: Node = null        # who threw it (the catcher books the rules)
## MAGNET PASS (>0 while a pass is in the air). The ball is steered, every
## frame, at the receiver's HANDS: a man on the run is met exactly where he
## is, the line stays tight (a small hump, no lob) and the ball comes to rest
## in the palm -- never on the floor, never past him. Euler gravity used to
## give a 3 px loft, so passes bounced their way to the receiver.
var pass_arc := 0.0
var _pa_from := Vector2.ZERO
var _pa_to := Vector2.ZERO
var _pa_who: Node = null          # him the ball is homing to
var _pa_speed := 620.0
var _pa_t := 0.0
var _pa_T := 1.0
var _pa_hump := 16.0
var _pa_dist0 := 1.0''', "pass fields")

edit("src/match/Ball.gd",
'''func pass_to(from: Vector2, target: Vector2, speed: float, by: Node) -> void:''',
'''func pass_to(from: Vector2, target: Vector2, speed: float, by: Node, to_player: Node = null) -> void:''',
    "pass_to signature")

edit("src/match/Ball.gd",
'''	vel = d / t
	vh = 0.0
	# GUIDED ARC: hand height -> hand height, with a modest hump that grows
	# with the distance. The ball never touches the floor, so the receiver
	# takes it cleanly in the hands instead of chasing a bouncing ball.
	pass_arc = clampf(26.0 + d.length() * 0.055, 26.0, 92.0)
	_pa_from = from
	_pa_to = target
	_pa_t = 0.0
	_pa_T = t
	last_touch_team = by.team''',
'''	vel = d / t
	vh = 0.0
	# DIRECT: a chest pass, not a lob. The hump only clears the hand it leaves
	# and the hand it reaches; it grows a little with the distance.
	_pa_from = from
	_pa_to = target
	_pa_who = to_player
	_pa_speed = speed
	_pa_dist0 = maxf(from.distance_to(target), 1.0)
	_pa_hump = clampf(8.0 + d.length() * 0.030, 8.0, 30.0)
	_pa_t = 0.0
	_pa_T = t
	pass_arc = 1.0
	pass_from = by
	last_touch_team = by.team''', "pass_to body")

edit("src/match/Ball.gd",
'''	if pass_arc > 0.0:
		# A pass in the air: ride the exact curve, no gravity, no floor.
		_pa_t += delta
		var f: float = clampf(_pa_t / maxf(_pa_T, 0.05), 0.0, 1.0)
		global_position = _pa_from.lerp(_pa_to, f)
		h = 55.0 + 4.0 * pass_arc * f * (1.0 - f)
		prev_pos = global_position
		prev_h = h
		if f >= 1.0:
			# Nobody caught it: it drops the last few px and becomes loose.
			pass_arc = 0.0
			vh = -40.0
		queue_redraw()
		return''',
'''	if pass_arc > 0.0:
		# MAGNET: no gravity, no floor. The ball is steered at the receiver's
		# hands, so it meets him in the run and never slips past.
		_pa_t += delta
		var aim: Vector2 = _pa_to
		if _pa_who is BallPlayer and is_instance_valid(_pa_who) and not _pa_who.has_ball:
			# Where his hands are NOW, with a whisker of lead so the ball closes
			# the gap on a running man instead of trailing him.
			aim = _pa_who.ball_anchor() + _pa_who.velocity * 0.10
			_pa_to = aim
		var dvec: Vector2 = aim - global_position
		var dist: float = dvec.length()
		# FLUID: soft release out of the thrower's hand, and the step is capped
		# at the distance left, so the ball lands ON the hand without overshoot.
		var ease_in: float = clampf(_pa_t / 0.06, 0.25, 1.0)
		var step: float = minf(_pa_speed * ease_in * delta, dist)
		if dist > 0.001:
			global_position += dvec / dist * step
		var prog: float = clampf(_pa_t / maxf(_pa_T, 0.05), 0.0, 1.0)
		h = lerpf(55.0, 49.0, prog) + _pa_hump * sin(PI * prog)
		prev_pos = global_position
		prev_h = h
		if _pa_t > _pa_T + 0.45:
			# Nobody took it (he was blocked off, the ball was refused): it drops.
			pass_arc = 0.0
			_pa_who = null
			pass_from = null
			vh = -30.0
		queue_redraw()
		return''', "magnet physics")

edit("src/match/Ball.gd",
'''func attach(p: Node) -> void:
	holder = p
	pass_target = null
	pass_arc = 0.0''',
'''func attach(p: Node) -> void:
	holder = p
	pass_target = null
	pass_from = null
	pass_arc = 0.0
	_pa_who = null''', "attach clears arc")

edit("src/match/Ball.gd",
'''func detach() -> void:
	holder = null
	held_still = false
	live = true
	pass_target = null
	pass_arc = 0.0''',
'''func detach() -> void:
	holder = null
	held_still = false
	live = true
	pass_target = null
	pass_arc = 0.0
	_pa_who = null''', "detach clears arc")

edit("src/match/Ball.gd",
'''		if held_still:
			global_position = holder.global_position + Vector2(18.0 * holder.facing, 0.0)
			h = 49.0''',
'''		if held_still:
			# Dead ball: it simply rests IN his hands (the same point a pass
			# homes to, so "in hand" and "caught" are the same spot).
			if holder.has_method("ball_anchor"):
				global_position = holder.ball_anchor()
			else:
				global_position = holder.global_position + Vector2(18.0 * holder.facing, 0.0)
			h = 49.0''', "held_still anchor")

# --------------------------------------------------------------- Player.gd ---
edit("src/match/Player.gd",
'''func _body_h() -> float:''',
'''func ball_anchor() -> Vector2:
	## Where the ball sits in this man's hands: in front of the chest, on the
	## side he is looking at. Passes home here and a dead ball rests here, so
	## the catch is seamless -- no pop, no snap, no bounce on the floor.
	return global_position + Vector2(facing * _body_h() * 0.30, 0.0)

func _body_h() -> float:''', "ball_anchor")

edit("src/match/Player.gd",
'''	cooldown_move = maxf(0.0, cooldown_move - delta)
	if court == null or not court.play_live:''',
'''	cooldown_move = maxf(0.0, cooldown_move - delta)
	# A pass is on its way to me: I turn to meet it, so it arrives in the hands
	# in front of the chest instead of behind the hip. (The AI only: the user's
	# facing is his own business.) This is what makes the catch read as a
	# magnet rather than the ball landing on a man who is looking elsewhere.
	if court != null and court.ball != null and not is_user:
		var inc: Ball = court.ball
		if inc.live and inc.pass_target == self \\
		and absf(inc.global_position.x - global_position.x) > 8.0:
			facing = signf(inc.global_position.x - global_position.x)
	if court == null or not court.play_live:''', "turn to meet the pass")

# --------------------------------------------------------------- Court.gd ----
edit("src/match/Court.gd",
'''	# A pass is CAUGHT, not chased: when the ball reaches the man it was aimed
	# at, it lands in his hands.
	if play_live and ball != null and ball.live and ball.pass_target is BallPlayer \\
	and is_instance_valid(ball.pass_target):
		var pt: BallPlayer = ball.pass_target
		if pt.global_position.distance_to(ball.global_position) < 62.0 and ball.h < 175.0:
			ball.pass_target = null
			give_ball(pt)''',
'''	# A pass is CAUGHT, not chased: the ball homes to the hands, and the moment
	# it is there the receiver takes it (the magnet closes the pass).
	if play_live and ball != null and ball.live and ball.pass_target is BallPlayer \\
	and is_instance_valid(ball.pass_target):
		var pt: BallPlayer = ball.pass_target
		if pt.ball_anchor().distance_to(ball.global_position) < 58.0 and ball.h < 175.0:
			var pf: BallPlayer = ball.pass_from if ball.pass_from is BallPlayer else null
			ball.pass_target = null
			_catch_pass(pf, pt)''', "magnet auto-catch")

edit("src/match/Court.gd",
'''	var speed: float = lerpf(500.0, 820.0, from.ratings["pass"] / 99.0)
	# Straight chest pass, LED to where the receiver is going: aiming at his
	# current spot meant a moving man had to chase the ball, and half of them
	# never caught it at all. The ball now meets him in the hands.
	var t_flight: float = maxf(from.global_position.distance_to(to.global_position) / speed, 0.12)
	var lead: Vector2 = to.global_position + to.velocity * t_flight * 0.85
	ball.pass_to(from.global_position + Vector2(0, -40), lead + Vector2(0, -40), speed, from)
	ball.pass_target = to''',
'''	var speed: float = lerpf(500.0, 820.0, from.ratings["pass"] / 99.0)
	# Straight chest pass, pointed at the receiver's HANDS. The ball keeps
	# re-aiming there every frame while it flies (Ball._physics_process), so a
	# man on the run is met where he actually is, and the pass is taken in the
	# hands instead of chased -- fluid, direct, magnetic.
	ball.pass_to(from.ball_anchor(), to.ball_anchor(), speed, from, to)
	ball.pass_target = to''', "do_pass aim")

edit("src/match/Court.gd",
'''	await get_tree().create_timer(maxf(from.global_position.distance_to(to.global_position) / speed, 0.12)).timeout
	if finished or ball.holder != null: return
	give_ball(to)
	# The rule against an immediate give-back to the pivot: the receiver must
	# first move the ball on to somebody else.
	to.no_pivot_return = from.role <= 2
	if to.role <= 2:
		# The mate who handed it in is the pivot's tutor: the pivot may not
		# give it straight back, the ball must go to somebody else first.
		from.no_pivot_return = true
		from.own_miss_rebound = false''',
'''	await get_tree().create_timer(maxf(from.global_position.distance_to(to.global_position) / speed, 0.12) + 0.30).timeout
	if finished or ball.holder != null: return
	_catch_pass(from, to)

## The ball arrives in the receiver's hands. The catch is booked HERE (both by
## the magnet net and by the timed fallback) so the rules that ride on a pass
## are applied once and in one place: the receiver may not hand it straight
## back to the pivot's tutor, the ball must go to somebody else first.
func _catch_pass(from: BallPlayer, to: BallPlayer) -> void:
	if to == null or not is_instance_valid(to) or to.has_ball:
		return
	if ball == null or ball.holder != null or finished:
		return
	give_ball(to)
	to.no_pivot_return = from != null and from.role <= 2
	if to.role <= 2 and from != null:
		from.no_pivot_return = true
		from.own_miss_rebound = false''', "catch booking")

print("BA_PATCH_M: %d edit applicate" % n)
