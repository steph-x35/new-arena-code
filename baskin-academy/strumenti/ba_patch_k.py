#!/usr/bin/env python3
"""Batch 5 patch (BA_K).

  1. illegal defence: only while DEFENDING, only when actually guarding, with a
     whistle cooldown (it had become oppressive).
  2. every change of possession = dead ball -> throw-in (steals, interceptions
     and defensive rebounds included).
  3. no illegal-defence whistle while my team attacks.
  4. NOBODY may cross the opponents' side area (a wall, not a whistle).
  5. the pivots live inside their own area: only role 2 steps out, and only with
     the ball, to shoot from beyond the line.
  6. side-area lines in white, like every other court line.
  7. AI play calling rewritten around expected value (chance x points).
  8. inbound: the ball rests in the thrower's hands, then a visible pass.
  9. no more "T" badge over the tutor in play.
 10. pivot mechanics re-checked against the rulebook.

Run once:  python3 strumenti/ba_patch_k.py
"""
import io, sys, os

ROOT = "/home/user/baskin_academy"
EDITS = 0

def edit(path, old, new, times=1, tag=""):
    global EDITS
    full = os.path.join(ROOT, path)
    s = io.open(full, encoding="utf-8").read()
    n = s.count(old)
    if n != times:
        # Idempotent: a re-run skips the edits an earlier partial run applied.
        if s.count(new) >= times:
            print("skip %-26s %s (already applied)" % (path, tag or ""))
            return
        print("FAIL %-26s anchor x%d (found %d): %s" % (path, times, n, tag or old[:50]))
        sys.exit(1)
    s = s.replace(old, new, times)
    io.open(full, "w", encoding="utf-8").write(s)
    EDITS += 1
    print("ok   %-26s %s" % (path, tag))

# ============================================================ Ball.gd (still ball)
edit("src/match/Ball.gd",
     "var holder: Node = null",
     "var holder: Node = null\nvar held_still := false       # inbound: the ball waits in the hands, no dribble",
     tag="held_still flag")

edit("src/match/Ball.gd",
     """	if holder != null:
		# A slam: the ball rides the hand all the way to the iron. Checked
		# before the dribble bob so the two can never fight over the ball.""",
     """	if holder != null:
		# A dead-ball inbound: the ball simply RESTS in the thrower's hands --
		# no dribble bob, no bounce, until the pass is released.
		if held_still:
			global_position = holder.global_position + Vector2(18.0 * holder.facing, 0.0)
			h = 49.0
			queue_redraw()
			return
		# A slam: the ball rides the hand all the way to the iron. Checked
		# before the dribble bob so the two can never fight over the ball.""",
     tag="still ball while inbounding")

# ============================================================ Player.gd (badge)
edit("src/match/Player.gd",
     """		var blab := "R%d" % role
		if variant != "":
			blab += " " + variant
		if is_tutor():
			blab = "T " + blab""",
     """		var blab := "R%d" % role
		if variant != "":
			blab += " " + variant""",
     tag="drop the T badge")

# ============================================================ CourtVisual: white
edit("src/match/CourtVisual.gd",
     """		_parc(hc, Court.SIDE_AREA_R, a0, a0 + PI, 40, Color(1.0, 0.82, 0.35, 0.95), 4.0)
		for i in 10:
			_parc(hc, Court.SIDE_AREA_R - Court.SIDE_AREA_BAND, a0 + i * (PI / 10.0) + 0.05,
				a0 + (i + 1) * (PI / 10.0) - 0.05, 5, Color(0.45, 0.85, 1.0, 0.8), 2.5)""",
     """		# White like every other line on the floor (it used to be orange and
		# blue, which made the areas read as a different court).
		_parc(hc, Court.SIDE_AREA_R, a0, a0 + PI, 40, line, 4.0)
		for i in 10:
			_parc(hc, Court.SIDE_AREA_R - Court.SIDE_AREA_BAND, a0 + i * (PI / 10.0) + 0.05,
				a0 + (i + 1) * (PI / 10.0) - 0.05, 5, Color(0.97, 0.97, 0.95, 0.85), 2.5)""",
     tag="white side-area arcs")

edit("src/match/CourtVisual.gd",
     """			_pline(hc + Vector2(cos(sa), sin(sa)) * 26.0,
				hc + Vector2(cos(sa), sin(sa)) * Court.SIDE_AREA_R,
				Color(1.0, 0.82, 0.35, 0.75), 2.5)""",
     """			_pline(hc + Vector2(cos(sa), sin(sa)) * 26.0,
				hc + Vector2(cos(sa), sin(sa)) * Court.SIDE_AREA_R,
				Color(0.97, 0.97, 0.95, 0.8), 2.5)""",
     tag="white sector lines")

# ============================================================ Court.gd
edit("src/match/Court.gd",
     "var _illegal_cd := 0.0",
     "var _illegal_cd := 0.0\nvar _ill_whistle_cd := 0.0          # \"L\" fouls: at most one every few seconds",
     tag="whistle cooldown var")

edit("src/match/Court.gd",
     """	_illegal_cd -= delta
	if _illegal_cd <= 0.0:""",
     """	_illegal_cd -= delta
	_ill_whistle_cd = maxf(0.0, _ill_whistle_cd - delta)
	if _illegal_cd <= 0.0:""",
     tag="cooldown decay")

# --- 1 + 3: the L check, far less trigger-happy and never while attacking
edit("src/match/Court.gd",
     """	var u := user
	if u == null or not u.is_user or u.has_ball or not user_on_court:
		return
	# A loose ball is not defence (Regola 8): no whistle while it is rolling.
	if ball == null or ball.holder == null:
		return
	var intent: bool = u.guarding or u.stance or u.block_window > 0.0 or u.steal_t > 0.0
	for a in players:
		if a.team == u.team:
			continue
		if not ill_guard(u, a):
			continue
		var d: float = u.global_position.distance_to(a.global_position)
		if d < 55.0 or (intent and d < 110.0):
			illegal_defense(u, a)
			return""",
     """	# THE \"L\" ONLY EXISTS ON DEFENCE. While OUR team has the ball nothing the
	# user does near an opponent is an illegal defence (crowding in the post,
	# setting a screen, running past a bigger man): the whistle was firing on
	# attackers, which is why it felt oppressive.
	if _ill_whistle_cd > 0.0 or possession == user.team:
		return
	var u := user
	if u == null or not u.is_user or u.has_ball or not user_on_court:
		return
	# A loose ball is not defence (Regola 8): no whistle while it is rolling.
	if ball == null or ball.holder == null or ball.holder.team == u.team:
		return
	# Standing still with room is legal by the rulebook (\"solo posizionandosi
	# con largo anticipo e rimanendo fermo\"): the whistle needs the ACT of
	# guarding, not mere proximity.
	var intent: bool = u.guarding or (u.stance and u.velocity.length() > 40.0) \\
		or u.block_window > 0.0 or u.steal_t > 0.0
	if ball.holder.team != u.team and not u.guarding:
		# If he is not the man on the ball, he must be actively guarding
		# somebody: a defender just running back is not committing anything.
		if not intent:
			return
	for a in players:
		if a.team == u.team:
			continue
		if not ill_guard(u, a):
			continue
		var d: float = u.global_position.distance_to(a.global_position)
		if d < 34.0 or (intent and d < 72.0):
			illegal_defense(u, a)
			return""",
     tag="L check relaxed")

edit("src/match/Court.gd",
     """func illegal_defense(d: BallPlayer, a: BallPlayer) -> void:
	team_fouls[d.team] += 1
	d.fouls += 1""",
     """func illegal_defense(d: BallPlayer, a: BallPlayer) -> void:
	team_fouls[d.team] += 1
	d.fouls += 1
	_ill_whistle_cd = 9.0""",
     tag="L whistle cooldown set")

# --- 4: opponents' area is a WALL, not a whistle (the L stays for marking)
edit("src/match/Court.gd",
     """			# EACH side area belongs to ONE team: the pivot of that team lives
			# and shoots there. Roles 3-5 may step in ONLY to hand the ball to
			# their own pivot — the opponents' area is off limits at all times,
			# and that is the \"L\" infraction (2 free throws + possession).
			var own: bool = int(hi) == q.team
			var handing: bool = own and q.team == possession and ball != null \\
				and ball.global_position.distance_to(hh) < 460.0
			if not handing:
				# A short grace covers the frame a turnover flips possession
				# while a defender is still on his way out of the area.
				q.area_loiter_t += delta
				if q.area_loiter_t > 0.8:
					q.area_loiter_t = 0.0
					# The fouled man is the team's role 3 when there is one (his
					# free throws go to the side basket, as Regola 8 wants),
					# otherwise the pivot whose area was invaded.
					var victim: BallPlayer = _role3_near(int(hi))
					if victim == null:
						victim = pivot_player(int(hi))
					if victim != null:
						illegal_defense(q, victim)
					return
				continue""",
     """			# EACH side area belongs to ONE team. Roles 3-5 may step into
			# their OWN area only to hand the ball to the pivot; the
			# opponents' area cannot be entered at all — that is enforced as a
			# wall by clamp_to_court(), so nobody is whistled for being pushed
			# out of it.
			var own: bool = int(hi) == q.team
			var handing: bool = own and q.team == possession and ball != null \\
				and ball.global_position.distance_to(hh) < 460.0
			if not handing:
				q.area_loiter_t = 0.0
				continue""",
     tag="trespass: wall instead of L")

# --- 4 + 5: the containment: opponents' areas blocked, pivots leashed in
edit("src/match/Court.gd",
     """	if not one_on_one and p is BallPlayer and p != _inbounder and not intermission \\
	and not (ft_active and ft_shooter == p):
		var bp: BallPlayer = p as BallPlayer
		if bp.role > 2 or bp.entering or bp.leaving:
			return
		# Role 1 never leaves his area. Role 2 lives there too but steps out
		# past the dashed line to shoot, so his leash is the area's apron.
		var hh: Vector2 = side_hoops[bp.team]
		var rr: float = (SIDE_AREA_R - 24.0) if bp.role == 1 else SIDE_PIVOT_RANGE
		var off: Vector2 = bp.global_position - hh
		if off.length() > rr:
			bp.global_position = hh + off.normalized() * rr""",
     """	if not one_on_one and p is BallPlayer and p != _inbounder and not intermission \\
	and not (ft_active and ft_shooter == p):
		var bp: BallPlayer = p as BallPlayer
		if bp.entering or bp.leaving:
			return
		# NOBODY crosses the opponents' side area: it is the other pivot's
		# floor. Enforced as a wall (a soft push out, every frame) so it is
		# impossible to enter instead of being whistled after the fact.
		for hi in side_hoops.size():
			if int(hi) == bp.team:
				continue
			var oh: Vector2 = side_hoops[hi]
			var roff: Vector2 = bp.global_position - oh
			var rlim: float = SIDE_AREA_R + 6.0
			if roff.length() < rlim:
				var push: Vector2 = roff.normalized() if roff.length() > 1.0 \\
					else Vector2(0.0, signf(oh.y))
				bp.global_position = oh + push * rlim
		if bp.role > 2:
			return
		# THE PIVOTS LIVE IN THEIR AREA. Role 1 never leaves it; role 2 leaves
		# it only WITH THE BALL, and only to step past the dashed line for the
		# shot the rules require from outside (so he cannot wander the floor).
		var hh: Vector2 = side_hoops[bp.team]
		var rr: float = SIDE_AREA_R - 24.0
		if bp.role == 2 and bp.has_ball:
			rr = SIDE_PIVOT_RANGE
		var off: Vector2 = bp.global_position - hh
		if off.length() > rr:
			bp.global_position = hh + off.normalized() * rr""",
     tag="walls + pivot leash")

# --- 2: one funnel for every change of possession
edit("src/match/Court.gd",
     """func on_turnover(from: BallPlayer, to: BallPlayer) -> void:
	if from.is_user: box[\"tov\"] += 1
	give_ball(to)
	Events.toast.emit(\"Turnover\")""",
     """func on_turnover(from: BallPlayer, to: BallPlayer) -> void:
	if from.is_user: box[\"tov\"] += 1
	give_ball(to)
	# A steal is a change of possession: whistle, then throw it in. Every
	# restart in the game looks the same (baskin rule 4).
	_possession_restart(to.team, \"Turnover\")

## ANY change of possession is a dead ball: the new attacking team throws the
## ball in from the sideline/baseline. Used by steals, interceptions and
## defensive rebounds, so play always restarts the same way.
func _possession_restart(team: int, reason := \"Turnover\") -> void:
	if one_on_one or finished or ft_active or restarting or inbound_wait > 0.0:
		return
	Events.toast.emit(reason)
	_inbound(team, _side_near_ball())

## Loose ball picked up by the OTHER team: hand it over with a throw-in.
func _after_loose_grab(p: BallPlayer, prev_team: int) -> void:
	if p == null or one_on_one or finished or not play_live or ft_active or restarting:
		return
	if prev_team == p.team:
		return
	_possession_restart(p.team, \"Turnover\")""",
     tag="possession restart funnel")

edit("src/match/Court.gd",
     """	if not one_on_one and p.role > 2 and in_side_area(p.global_position):
		Events.toast.emit(Loc.t(\"match.area.reach\"))
		return false
	give_ball(p)""",
     """	if not one_on_one and p.role > 2 and in_side_area(p.global_position):
		Events.toast.emit(Loc.t(\"match.area.reach\"))
		return false
	var prev_team: int = possession
	give_ball(p)""",
     tag="try_grab: remember possession")

edit("src/match/Court.gd",
     """	shot_clock = maxf(shot_clock, 14.0)
	_shoot_call = false
	if p.is_user: box[\"reb\"] += 1
	Events.toast.emit(\"Loose ball!\")
	return true""",
     """	shot_clock = maxf(shot_clock, 14.0)
	_shoot_call = false
	if p.is_user: box[\"reb\"] += 1
	Events.toast.emit(\"Loose ball!\")
	# A DEFENSIVE rebound is a change of possession like any other: whistle
	# and throw it in (an offensive rebound stays live).
	_after_loose_grab(p, prev_team)
	return true""",
     tag="try_grab: restart after a steal of the ball")

edit("src/match/Court.gd",
     """			give_ball(d)
			Events.toast.emit(\"Intercepted!\")
			if from.is_user: box[\"tov\"] += 1
			return""",
     """			give_ball(d)
			if from.is_user: box[\"tov\"] += 1
			_possession_restart(d.team, \"Intercepted!\")
			return""",
     tag="interception restarts")

edit("src/match/Court.gd",
     """	if best != null:
		give_ball(best)
		shot_clock = maxf(shot_clock, 14.0)
		Events.toast.emit(\"Loose ball recovered\")""",
     """	if best != null:
		var prev: int = possession
		give_ball(best)
		shot_clock = maxf(shot_clock, 14.0)
		Events.toast.emit(\"Loose ball recovered\")
		_after_loose_grab(best, prev)""",
     tag="watchdog recovery restarts")

# --- 8: the inbound ball sits still, then flies in
edit("src/match/Court.gd",
     """	for p in players:
		p.has_ball = false
	give_ball(inbounder)
	Events.toast.emit(\"Inbound\")""",
     """	if ball != null:
		ball.live = false
		ball.shot_result_pending = false
	give_ball(inbounder)
	# The ball RESTS in the thrower's hands (no dribble bob) until the pass
	# actually leaves: a dead ball must look dead.
	if ball != null:
		ball.held_still = true
	Events.toast.emit(\"Inbound\")""",
     tag="inbound: still ball")

edit("src/match/Court.gd",
     """	if _inbounder != null and is_instance_valid(_inbounder) \\
	and target != null and is_instance_valid(target) and target != _inbounder:
		_inbound_feed = true
		_inbounder.do_pass(target)
	shot_clock = 24.0
	play_live = true""",
     """	if _inbounder != null and is_instance_valid(_inbounder) \\
	and target != null and is_instance_valid(target) and target != _inbounder:
		# The throw itself: hold, then a real flight into the court. The ball
		# has to be SEEN leaving the hands and reaching the man inside.
		if ball != null:
			ball.held_still = false
		play_live = true
		_inbound_feed = true
		await get_tree().create_timer(0.35).timeout
		if finished or not is_instance_valid(_inbounder) or not is_instance_valid(target):
			return
		_inbounder.do_pass(target)
		shot_clock = 24.0
		return
	if ball != null:
		ball.held_still = false
	shot_clock = 24.0
	play_live = true""",
     tag="inbound: visible throw")

# --- public helper for the AI's expected-value maths
edit("src/match/Court.gd",
     """## Point value of a made basket under baskin rules.
func _baskin_points(s: BallPlayer, hoop: Vector2) -> int:""",
     """## What a made basket is worth for this player at this hoop (public: the AI
## play caller prices its options with it).
func baskin_points_for(s: BallPlayer, hoop: Vector2) -> int:
	return _baskin_points(s, hoop)

## Point value of a made basket under baskin rules.
func _baskin_points(s: BallPlayer, hoop: Vector2) -> int:""",
     tag="public points helper")

# ============================================================ AIBrain: EV play call
edit("src/match/AIBrain.gd",
     """func _pick_play(hoop: Vector2) -> void:
	var pressure: float = court.pressure_on(p)
	var dist_ft: float = court.px_to_ft(p.global_position.distance_to(hoop))
	var room: float = 1.0 - pressure
	var w := {}
	# 1) FEED THE PIVOT — the reason a baskin offence exists at all.
	var piv: BallPlayer = _pivot_mate()
	if piv != null and piv.period_makes < 3:
		w[\"deliver\"] = 0.35 + court.pivot_feed_urge(p.team) * 1.05
	# 2) GO TO THE RIM (and dunk it): legs, room, and a clock worth using.
	# A defender right on his chest is not an invitation to drive into him.
	w[\"drive\"] = 0.18 + room * 1.05 \\
		+ (0.50 if p.can_dunk() else 0.0) \\
		+ (0.35 if p.role == 5 else 0.0) \\
		+ clampf(1.0 - dist_ft / 30.0, 0.0, 1.0) * 0.35
	# 3) SHOOT: only what this role is allowed to shoot, and only if it is open.
	var look: float = room * 1.15
	match p.role:
		3:
			look += 0.15
		5:
			look += 0.25 if p.period_shots < 2 else -0.45
		4:
			look += 0.05
	if dist_ft < 30.0 and court.baskin_ai_shoot_allowed(p, hoop):
		w[\"shoot\"] = maxf(0.15, look)
	# 4) SWING IT: a team-mate who is genuinely open.
	# No hot-potato: a man who has just received the ball is not going to give
	# it straight back, which is what turned possessions into pass ping-pong.
	if _best_feed(pressure) != null \\
	and (Time.get_ticks_msec() / 1000.0 - court.last_pass_time) > 1.6:
		w[\"pass\"] = 0.18 + room * 0.24
	# Nobody in front of him and a live clock: attack. This is what turns a
	# role-5 handler into a driver and, at the iron, into a slam.
	if pressure < 0.38 and dist_ft < 24.0:
		w[\"drive\"] = float(w.get(\"drive\", 0.0)) + 0.55
	# Clock pressure overrides taste: get a shot up.
	if used_clock() > 16.0 or court.shot_clock < 5.0:
		w[\"shoot\"] = float(w.get(\"shoot\", 0.0)) + 1.4
		w[\"drive\"] = float(w.get(\"drive\", 0.0)) + 0.9
		w[\"deliver\"] = float(w.get(\"deliver\", 0.0)) * 0.35
	var total := 0.0
	for k in w:
		total += float(w[k])
	if total <= 0.0:
		_begin_play(\"drive\", hoop)
		return
	var roll: float = randf() * total
	for k in w:
		roll -= float(w[k])
		if roll <= 0.0:
			_begin_play(k, hoop)
			return
	_begin_play(\"drive\", hoop)""",
     """func _pick_play(hoop: Vector2) -> void:
	## A possession is a DECISION, not a dice roll. Every option is priced by
	## what it is really worth — the chance of it working times the points it
	## brings — with what this ROLE is allowed to do and what the defence is
	## giving him. A little noise keeps two possessions from looking alike.
	var pressure: float = court.pressure_on(p)
	var room: float = 1.0 - pressure
	var dist_ft: float = court.px_to_ft(p.global_position.distance_to(hoop))
	var ev := {}
	# 1) SHOOT: the quality of THIS shot for THIS player, worth what a make at
	# THIS hoop pays his role (a role 3 scores 3 at the classic rim, 2 at the
	# side one; role 5 over the arc = 3).
	if dist_ft < 31.0 and court.baskin_ai_shoot_allowed(p, hoop):
		var q: float = _shot_quality(dist_ft, pressure)
		var pts: float = float(court.baskin_points_for(p, hoop))
		ev[\"shoot\"] = q * pts * 1.12 - 0.12
		# A role 5 has three shots a period: he must not burn one from deep.
		if p.role == 5 and dist_ft > 24.0:
			ev[\"shoot\"] = float(ev[\"shoot\"]) - 0.35
		# A role 4 needs the full stop, which a contest takes away.
		if p.role == 4 and pressure > 0.55:
			ev[\"shoot\"] = float(ev[\"shoot\"]) - 0.30
	# 2) DRIVE: going at the rim. Room decides everything — a drive into a
	# chest is a turnover, and a role 3 cannot finish with a third tempo.
	var drive_ev: float = room * 0.95 + clampf(1.0 - dist_ft / 34.0, 0.0, 1.0) * 0.45
	if p.role == 4:
		drive_ev *= 0.78
	if p.role == 3:
		drive_ev *= 0.72
	if p.can_dunk():
		drive_ev += 0.55
	if room < 0.30:
		drive_ev -= 1.0
	ev[\"drive\"] = maxf(drive_ev, 0.0)
	# 3) DELIVER: the pivot is the reason a baskin offence exists. Priced at
	# what HIS shot is worth, and it climbs while the team ignores him.
	var piv: BallPlayer = _pivot_mate()
	if piv != null and piv.period_makes < 3:
		var urge: float = court.pivot_feed_urge(p.team)
		var pv: float = 2.6 if piv.role == 2 else 2.3
		ev[\"deliver\"] = (0.50 + urge * 1.20) * (1.0 - court.pressure_on(piv) * 0.45) * (pv / 2.6)
	# 4) SWING IT: a team-mate who is genuinely open — never the man who just
	# gave it to us (that is the ping-pong the old weights produced).
	var mate: BallPlayer = _best_feed(pressure)
	if mate != null and (Time.get_ticks_msec() / 1000.0 - court.last_pass_time) > 1.2:
		ev[\"pass\"] = 0.28 + (1.0 - court.pressure_on(mate)) * 0.42
	# 5) THE CLOCK: with the possession dying the best available shot wins.
	if court.shot_clock < 6.5 or used_clock() > 17.0:
		ev[\"shoot\"] = float(ev.get(\"shoot\", 0.0)) + 1.6
		ev[\"drive\"] = float(ev.get(\"drive\", 0.0)) + 0.9
		ev[\"deliver\"] = float(ev.get(\"deliver\", 0.0)) * 0.30
		ev[\"pass\"] = float(ev.get(\"pass\", 0.0)) * 0.25
	var total := 0.0
	var best := \"\"
	for k in ev:
		var v: float = maxf(float(ev[k]) * randf_range(0.88, 1.12), 0.0)
		ev[k] = v
		total += v
		if v > float(ev.get(best, -1.0)) or best == \"\":
			best = k
	if total <= 0.0:
		_begin_play(\"drive\", hoop)
		return
	var roll: float = randf() * total
	for k in ev:
		roll -= float(ev[k])
		if roll <= 0.0:
			_begin_play(k, hoop)
			return
	_begin_play(best, hoop)

## Crude make-% for this player from here, contested: the same rating curve the
## shot system uses, squeezed by the man in his face and by the distance.
func _shot_quality(dist_ft: float, pressure: float) -> float:
	var r: float = ShotSystem.rating_for_distance(
		float(p.ratings.get(\"close\", 50)), float(p.ratings.get(\"mid\", 50)),
		float(p.ratings.get(\"three\", 50)), dist_ft)
	var q: float = clampf((r - 28.0) / 62.0, 0.08, 0.90)
	q *= lerpf(1.0, 0.52, clampf(pressure, 0.0, 1.0))
	q *= lerpf(1.0, 0.70, clampf(dist_ft / 32.0, 0.0, 1.0))
	return clampf(q, 0.04, 0.90)""",
     tag="AI expected-value play call")

print("\nBA_K: %d edits applied" % EDITS)
