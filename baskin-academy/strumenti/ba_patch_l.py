#!/usr/bin/env python3
"""Batch 6 patch (BA_L).

  1. defence: every AI defender takes the opponent of HIS OWN role.
  2. throw-ins from the baseline too: ball still in hand, visible pass.
  3. passes are led to the receiver and caught in his hands.
  4. the "L" whistle fires ONLY while the DEFEND button is held (or on a
     steal/block attempt); walking past somebody is legal.
  5. the pivot lives BEHIND the side basket, and the basket is drawn in front
     of him, fading out while a player passes it.
  6. CHANGE ENDS after the second quarter.
  7. tougher defence against a role-5 handler (drives were too easy).
  8. proper defensive positions at every throw-in (bodies between the ball and
     the basket they defend, role 5 included).
  9. a dust thud under the feet of a player coming down from a dunk.

Run once:  python3 strumenti/ba_patch_l.py
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
        if s.count(new) >= times:
            print("skip %-24s %s (already applied)" % (path, tag or ""))
            return
        print("FAIL %-24s anchor x%d (found %d): %s" % (path, times, n, tag or old[:50]))
        sys.exit(1)
    s = s.replace(old, new, times)
    io.open(full, "w", encoding="utf-8").write(s)
    EDITS += 1
    print("ok   %-24s %s" % (path, tag))

# ============================================================ 3. passes to hands
edit("src/match/Ball.gd",
     "var shooter: Node = null",
     "var shooter: Node = null\nvar pass_target: Node = null      # the man this pass is meant for (caught in his hands)",
     tag="pass_target")

edit("src/match/Ball.gd",
     """func attach(p: Node) -> void:
	holder = p
	held_still = false""",
     """func attach(p: Node) -> void:
	holder = p
	pass_target = null
	held_still = false""",
     tag="attach clears target")

edit("src/match/Ball.gd",
     """func detach() -> void:
	holder = null
	held_still = false
	live = true""",
     """func detach() -> void:
	holder = null
	held_still = false
	live = true
	pass_target = null""",
     tag="detach clears target")

edit("src/match/Court.gd",
     """	last_passer = from
	last_pass_time = Time.get_ticks_msec() / 1000.0
	var speed: float = lerpf(500.0, 820.0, from.ratings["pass"] / 99.0)
	# Straight chest pass at the receiver's chest — never a lob into space.
	ball.pass_to(from.global_position + Vector2(0, -40), to.global_position + Vector2(0, -40), speed, from)""",
     """	last_passer = from
	last_pass_time = Time.get_ticks_msec() / 1000.0
	var speed: float = lerpf(500.0, 820.0, from.ratings["pass"] / 99.0)
	# Straight chest pass, LED to where the receiver is going: aiming at his
	# current spot meant a moving man had to chase the ball, and half of them
	# never caught it at all. The ball now meets him in the hands.
	var t_flight: float = maxf(from.global_position.distance_to(to.global_position) / speed, 0.12)
	var lead: Vector2 = to.global_position + to.velocity * t_flight * 0.85
	ball.pass_to(from.global_position + Vector2(0, -40), lead + Vector2(0, -40), speed, from)
	ball.pass_target = to""",
     tag="led passes + target")

edit("src/match/Court.gd",
     """	if play_live and ball != null and ball.holder is BallPlayer and not ball.holder.has_ball:""",
     """	# A pass is CAUGHT, not chased: when the ball reaches the man it was aimed
	# at, it lands in his hands.
	if play_live and ball != null and ball.live and ball.pass_target is BallPlayer \\
	and is_instance_valid(ball.pass_target):
		var pt: BallPlayer = ball.pass_target
		if pt.global_position.distance_to(ball.global_position) < 54.0 and ball.h < 165.0:
			ball.pass_target = null
			give_ball(pt)
	if play_live and ball != null and ball.holder is BallPlayer and not ball.holder.has_ball:""",
     tag="auto-catch in flight")

# ============================================================ 4. L only when guarding
edit("src/match/Court.gd",
     """	# Standing still with room is legal by the rulebook ("solo posizionandosi
	# con largo anticipo e rimanendo fermo"): the whistle needs the ACT of
	# guarding, not mere proximity.
	var spd: float = u.velocity.length()
	var intent: bool = u.guarding or (u.stance and spd > 40.0) \\
		or u.block_window > 0.0 or u.steal_t > 0.0
	if ball.holder.team != u.team and not u.guarding and not intent and spd < 60.0:
		# Neither guarding nor moving: he is just standing there, which the
		# rulebook allows ("posizionandosi con largo anticipo e rimanendo
		# fermo"). Only intent or a real body contact is whistled below.
		return""",
     """	# WALKING PAST IS NOT A FOUL. The whistle only ever fires while the DEFEND
	# button is held (or while he is actually going for the ball): just running
	# by a lower role, standing near him or crossing his path is clean.
	if not (u.guarding or u.steal_t > 0.0 or u.block_window > 0.0):
		return
	var intent: bool = true""",
     tag="L only while guarding")

edit("src/match/Court.gd",
     """		var d: float = u.global_position.distance_to(a.global_position)
		if d < 34.0 or (intent and d < 72.0):
			illegal_defense(u, a)
			return""",
     """		var d: float = u.global_position.distance_to(a.global_position)
		if d < 40.0 or (intent and d < 80.0):
			illegal_defense(u, a)
			return""",
     tag="L ranges")

# ============================================================ 1. role-matched marks
edit("src/match/Court.gd",
     """	# Greedy closest-first pairing, so nobody double-teams and nobody runs free.
	var free_def: Array = defenders.duplicate()
	var free_opp: Array = opponents.duplicate()
	# BASKIN: you may only guard an equal-or-higher role, and NEVER the
	# pivot (role 1). Defenders who cannot legally mark anyone play help.
	if not one_on_one:
		free_opp = free_opp.filter(func(o): return o.role > 2)""",
     """	# Greedy closest-first pairing, so nobody double-teams and nobody runs free.
	var free_def: Array = defenders.duplicate()
	var free_opp: Array = opponents.duplicate()
	# BASKIN: you may only guard an equal-or-higher role, and NEVER the
	# pivot (role 1). Defenders who cannot legally mark anyone play help.
	if not one_on_one:
		free_opp = free_opp.filter(func(o): return o.role > 2)
	# EACH DEFENDER TAKES HIS OWN ROLE (5 on 5, 4 on 4, 3 on 3): the pairing
	# starts by matching equal role numbers, and only the leftovers fall back
	# to the general rule (the lower role may take a higher one).
	if not one_on_one:
		for dd in defenders.duplicate():
			var dref0: BallPlayer = dd
			var best_o0: BallPlayer = null
			var bd0 := 1e18
			for oo in free_opp:
				var oref0: BallPlayer = oo
				if oref0.role != dref0.role:
					continue
				var dist0: float = dref0.global_position.distance_to(oref0.global_position)
				if dist0 < bd0:
					bd0 = dist0
					best_o0 = oref0
			if best_o0 != null:
				_man_marks[dref0.get_instance_id()] = best_o0.get_instance_id()
				free_def.erase(dref0)
				free_opp.erase(best_o0)""",
     tag="same-role pairing first")

# ============================================================ 5. pivot behind the basket
edit("src/match/Court.gd",
     """func pivot_home(team: int) -> Vector2:
	## Where role 1 lives: INSIDE his own side area, waiting for the pass.
	var h: Vector2 = side_hoops[team]
	return h + Vector2(0.0, (1.0 if h.y < 0.0 else -1.0) * SIDE_AREA_R * 0.45)""",
     """func pivot_home(team: int) -> Vector2:
	## Where the pivot lives: right at the back of his own side area, so the
	## basket stands between him and the court (he is "behind the basket", the
	## rim in front of him) — how a baskin pivot actually positions.
	var h: Vector2 = side_hoops[team]
	return h + Vector2(0.0, (1.0 if h.y < 0.0 else -1.0) * 26.0)""",
     tag="pivot home behind the rim")

# ============================================================ 6. change ends
edit("src/match/Court.gd",
     "var _ft_keep_possession := false  # illegal defense: victim team keeps the ball",
     "var _ft_keep_possession := false  # illegal defense: victim team keeps the ball\nvar _ends_swapped := false         # after Q2 the teams change ends",
     tag="ends flag")

edit("src/match/Court.gd",
     """	game_clock = quarter_len
	possession = 1 - possession
	_qb_inbound = true""",
     """	game_clock = quarter_len
	# CHANGE ENDS at half time: the two baskets swap, so the teams keep
	# attacking the SAME physical basket... no: they switch, and everybody is
	# mirrored to the other half before the new quarter tips off.
	if quarter == 3 and not _ends_swapped:
		_ends_swapped = true
		hoops.reverse()
		side_hoops.reverse()
		_man_team = -1
		_man_stamp = -10000
		for p in players:
			p.global_position = Vector2(-p.global_position.x, -p.global_position.y)
			p.velocity = Vector2.ZERO
		for t in 2:
			for bp in pivot_bench[t]:
				bp.global_position = Vector2(-bp.global_position.x, -bp.global_position.y)
		Events.toast.emit(Loc.tx("CHANGE ENDS"))
	possession = 1 - possession
	_qb_inbound = true""",
     tag="halftime switch")

edit("src/match/Court.gd",
     """	var side := -1.0 if t == 0 else 1.0
	# Spread across the floor so five-a-side is not a huddle at half-court.""",
     """	var side := -1.0 if t == 0 else 1.0
	if _ends_swapped:
		side = -side
	# Spread across the floor so five-a-side is not a huddle at half-court.""",
     tag="formation respects the switch")

# ============================================================ 2. inbound: still ball (baseline too)
edit("src/match/Court.gd",
     """	# The ball RESTS in the thrower's hands (no dribble bob) until the pass
	# actually leaves: a dead ball must look dead.
	if ball != null:
		ball.held_still = true""",
     """	# The ball RESTS in the thrower's hands (no dribble bob, no bounce, no
	# leftover dunk drop) until the pass actually leaves — baseline throw-ins
	# included, which is where the ball used to keep bouncing.
	if ball != null:
		ball.held_still = true
		ball.dunk_drop = 0.0
		ball.vel = Vector2.ZERO
		ball.vh = 0.0
		ball.live = false
		ball.visible = true""",
     tag="baseline inbound still ball")

# ============================================================ 8. defensive set at throw-ins
edit("src/match/AIBrain.gd",
     """	if p == null or court == null or not court.play_live: 
		# Rimessa chiamata: la difesa NON si congela. Ogni difensore ombreggia
		# il suo mark a meta' strada tra lui e il nostro canestro, cosi' il
		# rilascio non puo' diventare un cherry-pick senza contrasto.
		if court != null and p != null and court.inbound_wait > 0.0 \\
		and p.team != int(court.possession) and not court.one_on_one:
			var mk: BallPlayer = court.man_mark_for(p)
			if mk != null:
				var goal: Vector2 = (mk.global_position + court.attack_hoop_for(mk)) * 0.5
				var dvec: Vector2 = goal - p.global_position
				p.move_input = dvec.normalized() if dvec.length() > 26.0 else Vector2.ZERO
				if absf(dvec.x) > 4.0:
					p.facing = signf(dvec.x)
		elif p != null:
			p.move_input = Vector2.ZERO
		return""",
     """	if p == null or court == null or not court.play_live:
		# THROW-IN DEFENCE: every defender gets between his man and the basket
		# they are defending, ON THE SIDE THE BALL COMES FROM. Standing around
		# mid-court instead handed the thrower an open road to the rim. Runs for
		# every dead ball (sideline, baseline, after a steal), not just while
		# the human waits to call for it.
		if court != null and p != null and not court.one_on_one \\
		and (court.restarting or court.inbound_wait > 0.0) \\
		and p.team != int(court.possession):
			var mk: BallPlayer = court.man_mark_for(p)
			var basket: Vector2 = court.hoop_for(1 - p.team)
			var aim: Vector2 = court.ball.global_position.lerp(basket, 0.45)
			if mk != null:
				# body between the man and the rim, shaded toward the ball
				aim = mk.global_position + (basket - mk.global_position).normalized() * 46.0
				aim = aim.lerp(court.ball.global_position, 0.18)
			var dvec: Vector2 = aim - p.global_position
			p.move_input = dvec.normalized() if dvec.length() > 18.0 else Vector2.ZERO
			p.stance = dvec.length() < 90.0
			if absf(dvec.x) > 4.0:
				p.facing = signf(dvec.x)
		elif p != null:
			p.move_input = Vector2.ZERO
		return""",
     tag="throw-in defensive set")

# ============================================================ 7. harder vs role 5
edit("src/match/AIBrain.gd",
     """	var shooter_range: float = bh.global_position.distance_to(court.hoop_for(bh.team))
	var gap: float = lerpf(78.0, 58.0, skill)
	if gathering:""",
     """	var shooter_range: float = bh.global_position.distance_to(court.hoop_for(bh.team))
	var gap: float = lerpf(78.0, 58.0, skill)
	# A ROLE 5 must not walk to the rim: he is the strongest attacker on the
	# floor, so the man on him sits closer and the help collapses (a role 5
	# driving through five defenders is what made penetration too easy).
	var big5: bool = bh.role == 5
	if big5:
		gap = lerpf(58.0, 40.0, skill)
		if shooter_range < 330.0:
			gap -= 8.0
	if gathering:""",
     tag="tight on role 5")

edit("src/match/AIBrain.gd",
     """	if d0 < 46.0 and randf() < (0.006 + aggression * 0.010) * lerpf(0.7, 1.5, skill):
		p.try_steal()""",
     """	var steal_ch: float = (0.006 + aggression * 0.010) * lerpf(0.7, 1.5, skill)
	if big5:
		steal_ch *= 1.8      # hands on the ball against a role-5 drive
	if d0 < 46.0 and randf() < steal_ch:
		p.try_steal()""",
     tag="steal rate on role 5")

edit("src/match/AIBrain.gd",
     """	var own_hoop: Vector2 = court.attack_hoop_for(mark)
	var ball_pos: Vector2 = court.ball.global_position
	# deny line: one third toward the ball, two thirds on the man
	var cutting: bool = mark.move_t > 0.0 or mark.velocity.length() > 140.0
	var deny_k: float = 0.32 if cutting else 0.22   # sul taglio si sta sul linea
	var help: Vector2 = mark.global_position.lerp(own_hoop, deny_k)
	help = help.lerp(ball_pos, 0.20)""",
     """	var own_hoop: Vector2 = court.attack_hoop_for(mark)
	var ball_pos: Vector2 = court.ball.global_position
	# deny line: one third toward the ball, two thirds on the man
	var cutting: bool = mark.move_t > 0.0 or mark.velocity.length() > 140.0
	var deny_k: float = 0.32 if cutting else 0.22   # sul taglio si sta sul linea
	var help: Vector2 = mark.global_position.lerp(own_hoop, deny_k)
	help = help.lerp(ball_pos, 0.20)
	# HELP ON THE DRIVE: a role-5 attacker going at the rim drags the nearest
	# off-ball defenders into the paint, so the lane closes.
	var bh2: BallPlayer = court.ball_handler()
	if bh2 != null and bh2.role == 5 and bh2.team != p.team:
		var to_rim: float = bh2.global_position.distance_to(court.hoop_for(bh2.team))
		if to_rim < 300.0:
			var sag: Vector2 = court.hoop_for(bh2.team).lerp(bh2.global_position, 0.42)
			help = help.lerp(sag, clampf((300.0 - to_rim) / 300.0, 0.0, 0.62))""",
     tag="help collapse on role 5")

# ============================================================ 9. dunk landing dust
edit("src/match/Player.gd",
     "var dust_t := 0.0              # >0 while landing puffs are expanding",
     "var dust_t := 0.0              # >0 while landing puffs are expanding\nvar dust_big := false          # a slam landing: a real THUD under the feet\nvar _air_was_dunk := false     # this jump ended with a dunk",
     tag="dust flags")

edit("src/match/Player.gd",
     """func release_rim() -> void:
	if not hanging:
		return
	hanging = false
	jumping = true
	air_v = -60.0""",
     """func release_rim() -> void:
	if not hanging:
		return
	hanging = false
	jumping = true
	air_v = -60.0
	# The drop off the rim is the landing that kicks up the dust: remember it,
	# the puff is fired when the feet actually hit the floor.
	_air_was_dunk = true""",
     tag="remember the slam")

edit("src/match/Player.gd",
     """		if jumping:
			dust_t = 0.45   # only puff when feet actually came back down
		jumping = false""",
     """		if jumping:
			# A slam landing is heavier: bigger, longer dust + a rumble.
			dust_big = _air_was_dunk
			dust_t = 0.8 if dust_big else 0.45
			if dust_big and court != null:
				Events.shake.emit(0.4)
				Sfx.play("dunk", -6.0, 0.8)
		_air_was_dunk = false
		jumping = false""",
     tag="slam landing puff")

edit("src/match/Player.gd",
     """	# Landing dust: a flat puff that sweeps out sideways as it fades.
	if dust_t > 0.0:
		var k: float = 1.0 - dust_t / 0.45
		var da: float = (1.0 - k) * 0.5
		var spread: float = lerpf(12.0, 52.0, k)
		draw_set_transform(proj - position, 0.0, Vector2(1.0, 0.55) * dscale)
		for i in 6:
			var a0: float = -PI * 0.15 - i * 0.22
			var side := -1.0 if i % 2 == 0 else 1.0
			var px: float = side * spread * (0.4 + 0.6 * float((i + 1) % 3) / 2.0)
			var py: float = -6.0 - (i % 2) * 5.0
			draw_circle(Vector2(px, py), lerpf(7.0, 2.5, k), Color(0.85, 0.82, 0.72, da))
		draw_set_transform(proj - position, 0.0, Vector2(1.0 - squash * 0.5, 1.0 + squash) * dscale)""",
     """	# Landing dust: a flat puff that sweeps out sideways as it fades. After a
	# slam it is a full THUD: a wide ground ring plus a ring of grains.
	if dust_t > 0.0:
		var dur: float = 0.8 if dust_big else 0.45
		var k: float = 1.0 - dust_t / dur
		var da: float = (1.0 - k) * (0.62 if dust_big else 0.5)
		var spread: float = lerpf(12.0, 130.0 if dust_big else 52.0, k)
		draw_set_transform(proj - position, 0.0, Vector2(1.0, 0.55) * dscale)
		if dust_big:
			# the shock ring on the floor, right under the feet
			draw_arc(Vector2.ZERO, lerpf(10.0, 96.0, k), 0.0, TAU, 26,
				Color(0.88, 0.85, 0.75, da * 0.85), lerpf(6.0, 1.5, k))
			var grains: int = 14
			for i in grains:
				var a1: float = TAU * float(i) / float(grains) + 0.3
				var rr: float = spread * (0.55 + 0.45 * float((i * 7) % 5) / 4.0)
				draw_circle(Vector2(cos(a1) * rr, sin(a1) * rr * 0.45 - 4.0),
					lerpf(6.0, 1.6, k), Color(0.86, 0.83, 0.73, da))
		else:
			for i in 6:
				var a0: float = -PI * 0.15 - i * 0.22
				var side := -1.0 if i % 2 == 0 else 1.0
				var px: float = side * spread * (0.4 + 0.6 * float((i + 1) % 3) / 2.0)
				var py: float = -6.0 - (i % 2) * 5.0
				draw_circle(Vector2(px, py), lerpf(7.0, 2.5, k), Color(0.85, 0.82, 0.72, da))
		draw_set_transform(proj - position, 0.0, Vector2(1.0 - squash * 0.5, 1.0 + squash) * dscale)""",
     tag="dunk thud drawing")

# ============================================================ 5b. hoop drawn in front
edit("src/match/CourtVisual.gd",
     """	# BASKIN side baskets: low rims standing on the two sidelines.
	for si in [0, 1]:
		var shpos: Vector2 = court.side_hoops[si] if court != null else Vector2(0.0, -H * 0.5 if si == 0 else H * 0.5)
		_draw_side_hoop(shpos, 2 + si)""",
     """	# BASKIN side baskets are drawn by NetFront, ON TOP of the players: the
	# rim must read as being in front of the pivot standing behind it (and it
	# fades while a body passes it).""",
     tag="side hoops move in front")

edit("src/match/CourtVisual.gd",
     """func _draw_side_hoop(pos: Vector2, widx: int) -> void:
	# Baskin side basket: a low rim on the sideline with its own mini net.
	var f: Vector2 = _p(pos)""",
     """func side_hoop_layout(pos: Vector2, widx: int) -> Dictionary:
	# Geometry of a baskin side basket, shared with NetFront (which paints it
	# in front of the players). Returns the projected foot + rim centres.
	var f: Vector2 = _p(pos)
	var rim := Vector2(f.x, f.y - Court.SIDE_RIM_HEIGHT)
	return {"foot": f, "rim": rim, "wob": net_wobble[widx] if widx < net_wobble.size() else 0.0, "t": t}

func _draw_side_hoop(pos: Vector2, widx: int) -> void:
	# Baskin side basket: a low rim on the sideline with its own mini net.
	var f: Vector2 = _p(pos)""",
     tag="side hoop layout helper")

# NetFront paints the side baskets in front, fading near a body.
edit("src/match/NetFront.gd",
     """	for s in [-1.0, 1.0]:
		var hx: float = s * (Court.COURT_W * 0.5 - Court.FIBA_HOOP_INSET)""",
     """	# BASKIN SIDE BASKETS, IN FRONT OF EVERYTHING: the rim belongs in front of
	# the player standing behind it, and fades to show him through.
	for si in [0, 1]:
		var sp: Vector2 = court.side_hoops[si] if court != null \\
			else Vector2(0.0, -Court.COURT_H * 0.5 if si == 0 else Court.COURT_H * 0.5)
		var near_body := false
		if court != null:
			for q in court.players:
				if q.global_position.distance_to(sp) < 130.0:
					near_body = true
					break
		_draw_side_basket(sp, si, 0.42 if near_body else 1.0)
	for s in [-1.0, 1.0]:
		var hx: float = s * (Court.COURT_W * 0.5 - Court.FIBA_HOOP_INSET)""",
     tag="NetFront draws side baskets")

edit("src/match/NetFront.gd",
     """		var foot: Vector2 = CourtStage.m_project(hoop, hh)
		HoopArt.draw_net_front(self, Vector2(foot.x, foot.y - vis.rim_height),
			22.0, 22.0 * HoopArt.RIM_SQUASH, vis.net_wobble[idx], vis.t)""",
     """		var foot: Vector2 = CourtStage.m_project(hoop, hh)
		HoopArt.draw_net_front(self, Vector2(foot.x, foot.y - vis.rim_height),
			22.0, 22.0 * HoopArt.RIM_SQUASH, vis.net_wobble[idx], vis.t)

## A low side basket: pole, glass, ring and net, all at `alpha`.
func _draw_side_basket(pos: Vector2, si: int, alpha: float) -> void:
	var f: Vector2 = CourtStage.m_project(pos, Court.COURT_H)
	var rim := Vector2(f.x, f.y - Court.SIDE_RIM_HEIGHT)
	var wob: float = vis.net_wobble[2 + si] if (vis != null and 2 + si < vis.net_wobble.size()) else 0.0
	var sway: float = sin(Time.get_ticks_msec() / 1000.0 * 9.0) * 8.0 * wob
	var steel := Color(0.36, 0.38, 0.42, alpha)
	var orange := Color(0.92, 0.36, 0.10, alpha)
	var glass := Color(0.78, 0.88, 0.96, 0.42 * alpha)
	var lean: float = -10.0 if pos.y < 0.0 else 10.0
	draw_line(f + Vector2(0, 10), Vector2(f.x + lean, rim.y - 30.0), steel, 7.0)
	draw_line(Vector2(f.x + lean, rim.y - 30.0), Vector2(f.x, rim.y - 8.0), steel, 5.0)
	draw_rect(Rect2(f.x - 30.0, rim.y - 38.0, 60.0, 30.0), glass)
	draw_rect(Rect2(f.x - 30.0, rim.y - 38.0, 60.0, 30.0), Color(0.94, 0.97, 1.0, 0.9 * alpha), false, 2.0)
	draw_rect(Rect2(f.x - 11.0, rim.y - 26.0, 22.0, 14.0), orange, false, 2.5)
	var ring := PackedVector2Array()
	for i in 25:
		var a := TAU * float(i) / 24.0
		ring.append(rim + Vector2(cos(a) * 20.0, sin(a) * 7.0))
	draw_polyline(ring, orange, 4.0)
	var netc := Color(0.93, 0.94, 0.96, 0.92 * alpha)
	for k in 6:
		var a2 := PI * float(k) / 5.0
		draw_line(rim + Vector2(cos(a2) * 20.0, sin(a2) * 7.0),
			Vector2(rim.x + sway + cos(a2) * 7.0, rim.y + 24.0), netc, 1.6)
	draw_arc(Vector2(rim.x + sway, rim.y + 24.0), 7.0, 0, TAU, 12, netc, 1.6)""",
     tag="side basket painter")

print("\nBA_L: %d edits applied" % EDITS)
