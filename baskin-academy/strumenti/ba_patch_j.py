#!/usr/bin/env python3
"""Batch 4 patch (BA_J) — hair by gender, side-area trespass = L, foul "L"
per the rulebook, role-3 free throws at the side basket.
Anchor-based: every edit asserts its anchor, so a drifted file fails loudly
instead of silently corrupting. Run once:  python3 strumenti/ba_patch_j.py
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
        print("FAIL %-28s anchor x%d (found %d): %s" % (path, times, n, tag or old[:60]))
        sys.exit(1)
    s = s.replace(old, new, times)
    io.open(full, "w", encoding="utf-8").write(s)
    EDITS += 1
    print("ok   %-28s %s" % (path, tag))

# ---------------------------------------------------------------- Player.gd
edit("src/match/Player.gd",
     "var has_ball := false",
     "var has_ball := false\nvar gender := 0                 # 0 = M, 1 = F (drives the hair cut + crowd art)\nvar fouls := 0                  # personal fouls, the \"L\" ones included",
     tag="gender + fouls fields")

# ---------------------------------------------------------------- Avatar.gd
edit("src/ui/Avatar.gd",
     """			# radice piena sopra la testa
			c.draw_circle(head_c + Vector2(0, -head_r * 0.55), head_r * 0.72, hair)
		_:   # normale""",
     """			# radice piena sopra la testa
			c.draw_circle(head_c + Vector2(0, -head_r * 0.55), head_r * 0.72, hair)
		6:   # coda: cap e coda legata dietro la nuca, elastico e punta
			c.draw_arc(head_c, head_r * 1.02, PI * 1.02, TAU - PI * 0.02, 18, hair, head_r * 0.56)
			if back:
				c.draw_circle(head_c, head_r * 0.99, hair)
				c.draw_arc(head_c, head_r * 1.0, 0, TAU, 20, hair.darkened(0.15), head_r * 0.18)
			var tail_x: float = head_c.x - sdir * head_r * 0.92
			c.draw_circle(Vector2(tail_x, head_c.y - head_r * 0.12), head_r * 0.30, hair.darkened(0.08))
			var tail_tip := Vector2(tail_x - sdir * head_r * 0.22, head_c.y + head_r * 1.85)
			c.draw_line(Vector2(tail_x, head_c.y), tail_tip, hair, head_r * 0.34)
			c.draw_circle(tail_tip, head_r * 0.20, hair)
			c.draw_circle(Vector2(tail_x, head_c.y - head_r * 0.05), head_r * 0.14, hair.darkened(0.35))
		7:   # lunghi: ciocche ai lati che scendono oltre le spalle
			for sx2 in [-1.0, 1.0]:
				c.draw_line(Vector2(head_c.x + sx2 * head_r * 0.80, head_c.y - head_r * 0.40),
					Vector2(head_c.x + sx2 * head_r * 0.94, head_c.y + head_r * 1.80),
					hair, head_r * 0.50)
			c.draw_arc(head_c, head_r * 1.05, PI * 1.02, TAU - PI * 0.02, 18, hair, head_r * 0.58)
			if back:
				c.draw_circle(head_c, head_r * 1.0, hair)
				c.draw_arc(head_c, head_r * 1.02, 0, TAU, 20, hair.darkened(0.15), head_r * 0.2)
		_:   # normale""",
     tag="hair styles 6 coda / 7 lunghi")

# ---------------------------------------------------------------- Court.gd
edit("src/match/Court.gd",
     "var _ft_keep_possession := false  # illegal defense: victim team keeps the ball",
     "var _ft_keep_possession := false  # illegal defense: victim team keeps the ball\nvar ft_side := false               # this FT series is shot at a small side basket",
     tag="ft_side flag")

edit("src/match/Court.gd",
     """func _randomize_npc(p: BallPlayer, t: int) -> void:
	var lvl: int = 48 + int(Game.profile["level"]) * 2""",
     """func _randomize_npc(p: BallPlayer, t: int, seat := -1) -> void:
	var lvl: int = 48 + int(Game.profile["level"]) * 2""",
     tag="_randomize_npc seat")

edit("src/match/Court.gd",
     """	# Ogni NPC ha il PROPRIO taglio (pesato sul normale): non deve mai
	# comparire con lo stile scelto dal giocatore nel creator.
	p.hair_style_v = [0, 0, 0, 0, 1, 2, 3, 4, 5].pick_random()""",
     """	# Squadra mista: due donne fisse per squadra (seats 1 and 3), le altre
	# sorteggiate. Le donne portano coda o capelli lunghi, gli uomini un
	# taglio corto normale — niente piu' chiome a caso su tutti.
	p.gender = 1 if (seat == 1 or seat == 3) else (0 if seat >= 0 else (1 if randf() < 0.35 else 0))
	if seat < 0 and randf() < 0.35:
		p.gender = 1
	p.hair_style_v = [6, 7].pick_random() if p.gender == 1 else [0, 0, 0, 1, 4].pick_random()""",
     tag="mixed-gender hair")

edit("src/match/Court.gd",
     """			else:
				_randomize_npc(p, t)
				var brain := preload("res://src/match/AIBrain.gd").new()""",
     """			else:
				_randomize_npc(p, t, i)
				var brain := preload("res://src/match/AIBrain.gd").new()""",
     tag="spawn seat")

# ------------------------------------------------------- L foul: the checker
edit("src/match/Court.gd",
     """		if a.role != 1 and u.role >= a.role:
			continue
		var d: float = u.global_position.distance_to(a.global_position)
		if d < 55.0 or (intent and d < 110.0):
			illegal_defense(u, a)
			return""",
     """		if not ill_guard(u, a):
			continue
		var d: float = u.global_position.distance_to(a.global_position)
		if d < 55.0 or (intent and d < 110.0):
			illegal_defense(u, a)
			return""",
     tag="illegal_defense_check rule")

edit("src/match/Court.gd",
     """	var u := user
	if u == null or not u.is_user or u.has_ball or not user_on_court:
		return
	var intent: bool = u.guarding or u.stance or u.block_window > 0.0 or u.steal_t > 0.0""",
     """	var u := user
	if u == null or not u.is_user or u.has_ball or not user_on_court:
		return
	# A loose ball is not defence (Regola 8): no whistle while it is rolling.
	if ball == null or ball.holder == null:
		return
	var intent: bool = u.guarding or u.stance or u.block_window > 0.0 or u.steal_t > 0.0""",
     tag="no whistle on loose ball")

edit("src/match/Court.gd",
     """## Penalty: 2 free throws for the victim, then his team keeps the ball.
func illegal_defense(d: BallPlayer, a: BallPlayer) -> void:
	Sfx.play("whistle_short")
	Events.toast.emit(Loc.t("rule.v_illegal"))
	Events.rule.emit("v_illegal")
	_ft_keep_possession = true
	_start_free_throws(a, 2)""",
     """## May this defender legally take that man? Baskin Regola 8: the LOWER role
## may guard the higher one, never the other way round. Role numbers grow with
## ability, so a role 5 may only take another 5, a role 4 a 4 or a 5, and so
## on. Two special cases: the role-2 pivot is guarded by an opposing ROLE 3
## only, the role-1 pivot is never guarded at all.
func ill_guard(d: BallPlayer, a: BallPlayer) -> bool:
	if d == null or a == null or d.team == a.team:
		return false
	if a.role <= 1:
		return true
	if a.role == 2:
		return d.role != 3
	return d.role > a.role

## The "L" foul: 2 free throws for the man who was marked illegally, then his
## team keeps the ball. Counted on the defender (5 fouls = out) and, when the
## victim is a role 3, shot at the HIGH side basket from the dashed line.
func illegal_defense(d: BallPlayer, a: BallPlayer) -> void:
	team_fouls[d.team] += 1
	d.fouls += 1
	Sfx.play("whistle_short")
	Events.toast.emit(Loc.t("rule.v_illegal") % d.jersey_num)
	Events.rule.emit("v_illegal")
	if d.is_user:
		stat_add("pf", 1)
	_ft_keep_possession = true
	_start_free_throws(a, 2)""",
     tag="L foul penalty + ill_guard")

# ------------------------------------------------------- area trespass -> L
edit("src/match/Court.gd",
     """	for q in players:
		if q.role <= 2 or q.entering or q.leaving:
			continue
		# Only the ATTACKING team can be whistled here. A defender who trails
		# his man into the area used to be punished too, which handed the ball
		# straight back to the offence and could loop forever: the defenders
		# are now kept outside by the defensive AI (see AIBrain) and the human
		# has his own illegal-defence whistle.
		if q.team != possession:
			continue
		var near := false
		for hh in side_hoops:
			if q.global_position.distance_to(hh) < SIDE_AREA_R \\
			and ball != null and ball.global_position.distance_to(hh) < 460.0:
				near = true
				break
		if not near:
			q.area_loiter_t = 0.0
			continue
		q.area_loiter_t += delta
		# A hand-off is a quick errand: the human is whistled soon, the AI gets
		# a longer rope (it now walks out by itself, see AIBrain).
		var lim: float = (3.4 if q.has_ball else 2.8) if not q.is_user else (2.2 if q.has_ball else 1.2)
		if q.area_loiter_t > lim:
			q.area_loiter_t = 0.0
			_violation(q, "v_area_in")
			return""",
     """	for q in players:
		if q.role <= 2 or q.entering or q.leaving:
			continue
		for hi in side_hoops.size():
			var hh: Vector2 = side_hoops[hi]
			if q.global_position.distance_to(hh) >= SIDE_AREA_R:
				continue
			# EACH side area belongs to ONE team: the pivot of that team lives
			# and shoots there. Roles 3-5 may step in ONLY to hand the ball to
			# their own pivot — the opponents' area is off limits at all times,
			# and that is the "L" infraction (2 free throws + possession).
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
				continue
			q.area_loiter_t += delta
			# A hand-off is a quick errand: the human is whistled soon, the AI
			# gets a longer rope (it now walks out by itself, see AIBrain).
			var lim: float = (3.4 if q.has_ball else 2.8) if not q.is_user else (2.2 if q.has_ball else 1.2)
			if q.area_loiter_t > lim:
				q.area_loiter_t = 0.0
				_violation(q, "v_area_in")
				return""",
     tag="opponents' area = L")

edit("src/match/Court.gd",
     """func _area_trespass_check(delta: float) -> void:""",
     """## A role-3 team-mate to take the free throws for a trespassing defender
## (Regola 8: when the fouled player is a role 3, HE shoots the free throws).
func _role3_near(team: int) -> BallPlayer:
	var best: BallPlayer = null
	var bd := 1e9
	for p in players:
		if p.team != team or p.role != 3:
			continue
		var d: float = p.global_position.distance_to(side_hoops[team])
		if d < bd:
			bd = d
			best = p
	return best

func _area_trespass_check(delta: float) -> void:""",
     tag="_role3_near helper")

# ------------------------------------------------------- free throws: hoops
edit("src/match/Court.gd",
     """	var hoop := hoop_for(victim.team)
	var dir := -1.0 if hoop.x > 0.0 else 1.0
	victim.global_position = hoop + Vector2(dir * FT_PX, 0.0)""",
     """	# Regola 8: when the fouled man is a role 3 the free throws are taken at
	# the HIGH side basket from the dashed line (the 2R's spot). A pivot who
	# is fouled shoots at his own side basket, from his usual spot.
	ft_side = not one_on_one and victim.role <= 3
	var hoop := hoop_for(victim.team)
	var dir := -1.0 if hoop.x > 0.0 else 1.0
	if ft_side:
		hoop = side_hoops[victim.team]
		if victim.role == 3:
			var inward: float = 1.0 if hoop.y < 0.0 else -1.0
			victim.global_position = hoop + Vector2(0.0, inward * (SIDE_AREA_R + 44.0))
		else:
			victim.global_position = pivot_shot_spot(victim.team, victim)
		victim.facing = 1.0 if hoop.x >= 0.0 else -1.0
	else:
		victim.global_position = hoop + Vector2(dir * FT_PX, 0.0)""",
     tag="FT spot by role")

edit("src/match/Court.gd",
     """	var hoop := hoop_for(ft_shooter.team)
	Sfx.play("shot_release", -8.0)
	ball.shoot(ft_shooter.global_position + Vector2(0, -50), hoop, 400.0, 0.75, made, ft_shooter)
	# Flag AFTER shoot(): shoot() resets the flag to false for every launch.
	ball.is_free_throw = true""",
     """	var hoop := side_hoops[ft_shooter.team] if ft_side else hoop_for(ft_shooter.team)
	Sfx.play("shot_release", -8.0)
	ball.shoot(ft_shooter.global_position + Vector2(0, -50), hoop, 400.0, 0.75, made, ft_shooter,
		rim_height_of(hoop))
	# Flag AFTER shoot(): shoot() resets the flag to false for every launch.
	ball.is_free_throw = true
	ball.shot_hoop = hoop
	ball.shot_is_side = ft_side""",
     tag="FT at the right hoop")

edit("src/match/Court.gd",
     """	# Everyone else steps out of the lane, so the line is clear.
	var side := 1.0
	for p in players:
		if p == victim:
			continue
		p.global_position = hoop + Vector2(dir * (FT_PX + 240.0), side * 180.0)""",
     """	# Everyone else steps out of the lane, so the line is clear. On a side
	# basket there is no lane to clear: the others wait around mid-court.
	var side := 1.0
	for p in players:
		if p == victim:
			continue
		if ft_side:
			p.global_position = Vector2(side * 300.0, -side * 200.0)
		else:
			p.global_position = hoop + Vector2(dir * (FT_PX + 240.0), side * 180.0)""",
     tag="FT step-aside (side)")

# ---------------------------------------------------------------- Loc.gd
edit("src/core/Loc.gd",
     '''	"rule.v_illegal":  ["ILLEGAL DEFENSE", "DIFESA ILLEGALE"],
	"rule.v_illegal.body": ["You may only guard an equal or HIGHER role — and NEVER the pivot (role 1). Penalty: 2 free throws + possession.",
	                   "Puoi marcare solo un ruolo PARI o SUPERIORE — e MAI il pivot (ruolo 1). Penalitè: 2 tiri liberi + possesso."],''',
     '''	"rule.v_illegal":  ["FOUL L · ILLEGAL DEFENCE", "FALLO L · DIFESA IRREGOLARE"],
	"rule.v_illegal.body": ["You may only guard a man of the SAME role or HIGHER (a role 4 takes a 4, 5 or 6... a role 5 only takes a 5); the role-2 pivot is taken by an opposing role 3, the role-1 pivot is never guarded. Counted as an \\"L\\" foul: 2 free throws + possession. A fouled role 3 shoots them at the high side basket, from the dashed line.",
	                   "Si può marcare solo un ruolo PARI o SUPERIORE (il ruolo 4 prende il 4, il 5 o il 6... il ruolo 5 prende solo il 5); il pivot ruolo 2 lo prende un ruolo 3 avversario, il pivot ruolo 1 non è mai marcato. È fallo \\"L\\": 2 tiri liberi + possesso. Se a subirlo è un ruolo 3, i tiri si battono al canestro laterale alto dalla linea tratteggiata."],''',
     tag="L foul strings")

edit("src/core/Loc.gd",
     '"R2/R3: prima 2 palleggi · R3: niente terzo tempo · R4: arresto completo · Tiri laterali da FUORI area · Max 3 canestri (R1–R4), max 3 tiri (R5) · Marca solo ruoli pari/superiori, MAI il pivot. · Fallo sul tiratore: liberi. · Palla al pivot solo da DENTRO l\'area."],',
     '"R2/R3: prima 2 palleggi · R3: niente terzo tempo · R4: arresto completo · Tiri laterali da FUORI area · Max 3 canestri (R1–R4), max 3 tiri (R5) · Il ruolo INFERIORE marca il superiore, mai il contrario (il 5 solo il 5): altrimenti fallo L, 2 liberi · Mai il pivot. · Fallo sul tiratore: liberi. · Palla al pivot solo da DENTRO l\'area."],',
     tag="rulebook line")

print("\nBA_J: %d edits applied" % EDITS)
