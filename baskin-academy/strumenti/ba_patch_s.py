#!/usr/bin/env python3
"""BA_PATCH_S - batch 12 (v1.13.0).

1) PALLEGGIO ATTACCATO ALLA MANO: la palla scende VICINO alla gamba (non piu'
   mezza larghezza di corpo di lato), il palmo sta SOPRA la palla (stessa x),
   e il braccio non si allunga mai come un bastone: gomito piegato con IK a
   due segmenti, mano che si ferma a meta' coscia quando la palla e' a terra.
2) CANESTRO LATERALE RIGIRATO: quello vicino alla telecamera mostra il RETRO
   del tabellone (palo e staffa davanti, tabellone di faccia, ferro che spunta
   sotto), quello lontano resta come prima.
3) DIFESA E FALLO "L": il tasto DIFENDI non ti porta piu' addosso a un uomo
   che non puoi marcare (ti manda sul TUO uomo, o in aiuto), il fischio parte
   solo se stai DAVVERO addosso a un uomo illegale e ci resti un attimo, e a
   schermo si vede chi devi marcare (anello azzurro) e chi no (anello rosso).
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
        for i, ln in enumerate(old.split("\n")):
            print("   ", i, repr(ln))
        sys.exit(1)
    s = s.replace(old, new, count)
    io.open(p, "w", encoding="utf-8").write(s)
    n += 1
    print("ok  ", path, tag)

# ================================================== 1. PALLEGGIO E BRACCIO
# la palla scende vicino alla gamba, non a mezza larghezza di corpo
edit("src/match/Player.gd",
'''	var bounce: float = Avatar.drib_frac(anim_t, rate)
	var side := hs * hb * 0.34''',
'''	var bounce: float = Avatar.drib_frac(anim_t, rate)
	# La palla scende BESIDE THE FOOT, non a mezza larghezza di corpo di lato:
	# da li' la mano ci arriva con il gomito piegato (prima stava cosi' larga
	# che il braccio sembrava un bastone).
	var side := hs * hb * 0.19''',
    "ball near the leg")

# IK a due segmenti: il gomito e' sempre piegato
edit("src/ui/Avatar.gd",
'''## Numeri della posizione difensiva, in frazioni dell'altezza del corpo: la
## STESSA fonte per il disegno e per i test (cosi' non si testano fantasmi).''',
'''## Gomito di un braccio a DUE segmenti (spalla -> gomito -> mano) che deve
## arrivare a `hand`: il gomito si piega SEMPRE (mai una linea dritta, che era
## il difetto "braccio allungato"), e piega dal lato `side`. Se la mano e'
## troppo lontana l'arto si distende, ma i chiamanti la tengono a portata.
static func arm_elbow(sh: Vector2, hand: Vector2, ul: float, fl: float,
		side: float) -> Vector2:
	var v: Vector2 = hand - sh
	var d: float = maxf(v.length(), 1.0)
	var u: Vector2 = v / d
	var reach: float = clampf(d, absf(ul - fl) + 1.0, ul + fl - 1.0)
	var cosb: float = clampf((ul * ul + reach * reach - fl * fl) / (2.0 * ul * reach),
		-1.0, 1.0)
	var b: float = acos(cosb) * (1.0 if side >= 0.0 else -1.0)
	var cs: float = cos(b)
	var sn: float = sin(b)
	var ru := Vector2(u.x * cs - u.y * sn, u.x * sn + u.y * cs)
	return sh + ru * ul

## Fin dove arriva la mano del palleggiatore, in frazioni dell'altezza: sotto
## questa quota il braccio sarebbe steso. La stessa quota la usano il disegno
## della mano e il test, cosi' il palleggio non puo' piu' "allungarsi".
static func drib_hand_min() -> float:
	return 0.30

## Numeri della posizione difensiva, in frazioni dell'altezza del corpo: la
## STESSA fonte per il disegno e per i test (cosi' non si testano fantasmi).''',
    "arm ik helper")

# la mano del palleggiatore: sopra la palla, stessa x, e braccio piegato
edit("src/ui/Avatar.gd",
'''		elif kind == DRIBBLE and strong:
			# Hand rides the ball: bounce and palm stay glued.
			var br0: float = h * 0.105 if ball_r < 0.0 else ball_r
			var off: Vector2 = p.get("ball_off", Vector2.ZERO)
			if off != Vector2.ZERO:
				# Il chiamante (la partita) ha gia' deciso dove sta la palla:
				# il palmo si posa SOPRA quella palla (a un raggio di mano dal
				# centro), quindi non possono piu' andare fuori tempo.
				hand = Vector2(base.x + off.x * h,
					maxf(floor_y - h * 0.03, floor_y - off.y * h - br0 * 1.45))
			else:
				var bounce: float = drib_frac(ph)
				hand = Vector2(base.x + hd * h * 0.30, floor_y - bounce * h * 0.55 - br0)
			elbow = Vector2(lerpf(sh_p.x, hand.x, 0.42) + sx * h * 0.05,
				lerpf(sh_p.y, hand.y, 0.40) + h * 0.03)''',
'''		elif kind == DRIBBLE and strong:
			# LA MANO STA SOPRA LA PALLA, sempre: stessa x della palla, palmo
			# appoggiato sul pallone. Quando la palla e' a terra la mano NON la
			# segue fino in fondo (sarebbe un braccio steso): si ferma dove
			# arriva il braccio e la palla rimbalza SOTTO di lei.
			var br0: float = h * 0.105 if ball_r < 0.0 else ball_r
			var off: Vector2 = p.get("ball_off", Vector2.ZERO)
			var hand_min: float = floor_y - h * drib_hand_min()
			if off != Vector2.ZERO:
				var ball_x: float = base.x + off.x * h
				var ball_y: float = floor_y - off.y * h
				hand = Vector2(ball_x, maxf(ball_y - br0 * 1.35, hand_min))
			else:
				var bounce: float = drib_frac(ph)
				var bx2: float = base.x + hd * h * 0.19
				hand = Vector2(bx2, maxf(floor_y - bounce * h * 0.40 - br0 * 2.35,
					hand_min))
			elbow = arm_elbow(sh_p, hand, h * 0.20, h * 0.22, sx)''',
    "hand over the ball, bent elbow")

# ================================================== 2. CANESTRO LATERALE
edit("src/match/NetFront.gd",
'''## A low side basket: pole, glass, ring and net, all at `alpha`.
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
	draw_arc(Vector2(rim.x + sway, rim.y + 24.0), 7.0, 0, TAU, 12, netc, 1.6)''',
'''## Il canestro laterale VICINO alla telecamera si vede da DIETRO (il pivot ci
## sta dietro): si vede il RETRO del tabellone, con palo e staffa davanti e il
## ferro che spunta sotto. Quello lontano resta in vista frontale.
static func side_hoop_faces_away(pos: Vector2) -> bool:
	return pos.y > 0.0

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
	if side_hoop_faces_away(pos):
		# ---- VISTA DA DIETRO (rigirato di 180 gradi): quello che si vede e' il
		# tabellone. Il palo sale DAVANTI al tabellone, la staffa lo aggancia,
		# il ferro resta dietro e spunta appena sotto il bordo basso.
		var back := Color(0.60, 0.67, 0.76, 0.80 * alpha)
		var back2 := Color(0.45, 0.52, 0.60, 0.85 * alpha)
		var board := Rect2(f.x - 34.0, rim.y - 40.0, 68.0, 32.0)
		# palo portante, dal parquet al centro del tabellone (davanti a tutto)
		draw_line(f + Vector2(0, 10), Vector2(f.x, rim.y - 24.0), steel, 9.0)
		draw_line(f + Vector2(0, 10), Vector2(f.x, rim.y - 24.0),
			Color(0.52, 0.55, 0.60, alpha), 4.0)
		# staffa di sostegno del ferro
		draw_line(Vector2(f.x, rim.y - 24.0), Vector2(f.x, rim.y - 6.0), steel, 6.0)
		# il RETRO del tabellone: pannello pieno, con il bordo e le viti
		draw_rect(board, back)
		draw_rect(board, back2, false, 3.0)
		for vx in [-26.0, 26.0]:
			draw_circle(Vector2(f.x + vx, rim.y - 34.0), 2.6, back2)
			draw_circle(Vector2(f.x + vx, rim.y - 12.0), 2.6, back2)
		# la retina si vede sotto il ferro, un po' accorciata (prospettiva)
		var netb := Color(0.93, 0.94, 0.96, 0.85 * alpha)
		for k in 6:
			var a3 := PI * float(k) / 5.0
			draw_line(Vector2(rim.x + cos(a3) * 18.0, rim.y - 1.0),
				Vector2(rim.x + sway * 0.6 + cos(a3) * 9.0, rim.y + 20.0), netb, 1.5)
		draw_arc(Vector2(rim.x + sway * 0.6, rim.y + 20.0), 9.0, 0, TAU, 12, netb, 1.5)
		# il ferro visto da dietro: spunta sotto il tabellone, solo il bordo
		# vicino e' visibile (l'anello anteriore e' dietro il tabellone).
		draw_arc(Vector2(rim.x, rim.y + 1.0), 20.0, 0.0, PI, 22, orange, 5.0)
		draw_arc(Vector2(rim.x, rim.y + 1.0), 20.0, 0.12 * PI, 0.88 * PI, 20,
			Color(1.0, 0.55, 0.20, alpha), 2.0)
		return
	# ---- VISTA FRONTALE (il canestro dall'altra parte del campo)
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
	draw_arc(Vector2(rim.x + sway, rim.y + 24.0), 7.0, 0, TAU, 12, netc, 1.6)''',
    "side hoop back view")

# ================================================== 3. DIFESA E FALLO "L"
edit("src/match/Court.gd",
'''var _illegal_cd := 0.0
var _ill_whistle_cd := 0.0          # "L" fouls: at most one every few seconds''',
'''var _illegal_cd := 0.0
var _ill_whistle_cd := 0.0          # "L" fouls: at most one every few seconds
var _ill_dwell := 0.0               # da quanto stai addosso a un uomo illegale
var guard_target: BallPlayer = null # l'uomo che il tasto DIFENDI ti manda a prendere
var ill_mark: BallPlayer = null     # l'uomo che stai marcando ILLEGALMENTE adesso''',
    "guard vars")

edit("src/match/Court.gd",
'''	_area_rebound_tick(delta)
	_area_trespass_check(delta)
	_illegal_cd -= delta
	_ill_whistle_cd = maxf(0.0, _ill_whistle_cd - delta)
	if _illegal_cd <= 0.0:
		_illegal_cd = 0.6
		_illegal_defense_check()''',
'''	_area_rebound_tick(delta)
	_area_trespass_check(delta)
	_ill_whistle_cd = maxf(0.0, _ill_whistle_cd - delta)
	_update_guard_target()
	_illegal_defense_check(delta)''',
    "per-frame guard update")

edit("src/match/Court.gd",
'''## Illegal defense is the human's lesson: AI assignments are always legal
## (see _assign_man), so only the user's marking is whistled.
func _illegal_defense_check() -> void:
	if not play_live or restarting or ft_active or finished:
		return
	if shot_clock > 22.5:
		return   # fresh possession: no cheap whistles off the inbound
	# THE "L" ONLY EXISTS ON DEFENCE. While OUR team has the ball nothing the
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
	# WALKING PAST IS NOT A FOUL. The whistle only ever fires while the DEFEND
	# button is held (or while he is actually going for the ball): just running
	# by a lower role, standing near him or crossing his path is clean.
	if not (u.guarding or u.steal_t > 0.0 or u.block_window > 0.0):
		return
	var intent: bool = true
	for a in players:
		if a.team == u.team:
			continue
		if not ill_guard(u, a):
			continue
		var d: float = u.global_position.distance_to(a.global_position)
		if d < 40.0 or (intent and d < 80.0):
			illegal_defense(u, a)
			return''',
'''## L'UOMO CHE IL TASTO DIFENDI TI MANDA A PRENDERE. Con DIFENDI premuto il
## gioco ti posiziona: se il portatore di palla e' un uomo che PUOI marcare lo
## prendi lui, altrimenti vai sul tuo uomo (se e' legale), altrimenti resti in
## aiuto. Serve a non portarti addosso a un uomo illegale (fallo L) mentre stai
## solo difendendo: prima il tasto ti incollava al portatore di palla comunque
## fosse, e il fischio arrivava per colpa del gioco.
func _update_guard_target() -> void:
	guard_target = null
	if not play_live or restarting or ft_active or finished:
		return
	var u := user
	if u == null or not u.is_user or u.has_ball or not user_on_court:
		return
	if ball == null or ball.holder == null or ball.holder.team == u.team:
		return
	if one_on_one:
		guard_target = ball.holder
		return
	var h: BallPlayer = ball_handler()
	if h != null and h.team != u.team and not ill_guard(u, h):
		guard_target = h
		return
	var m: BallPlayer = man_mark_for(u)
	if m != null and m.team != u.team and not ill_guard(u, m):
		guard_target = m

## Illegal defense is the human's lesson: AI assignments are always legal
## (see _assign_man), so only the user's marking is whistled.
## Il fischio riguarda SOLO l'uomo che stai davvero addosso: camminare accanto
## a un ruolo piu' basso, aiutare un compagno o difendere il tuo uomo mentre un
## altro passа vicino non e' un fallo L (era la ragione per cui sembrava
## oppressivo: bastava avvicinarsi a chiunque per essere fischiati).
func _illegal_defense_check(delta: float) -> void:
	ill_mark = null
	if not play_live or restarting or ft_active or finished or one_on_one:
		_ill_dwell = 0.0
		return
	# THE "L" ONLY EXISTS ON DEFENCE. While OUR team has the ball nothing the
	# user does near an opponent is an illegal defence (crowding in the post,
	# setting a screen, running past a bigger man): the whistle was firing on
	# attackers, which is why it felt oppressive.
	if possession == user.team:
		_ill_dwell = 0.0
		return
	var u := user
	if u == null or not u.is_user or u.has_ball or not user_on_court:
		_ill_dwell = 0.0
		return
	# A loose ball is not defence (Regola 8): no whistle while it is rolling.
	if ball == null or ball.holder == null or ball.holder.team == u.team:
		_ill_dwell = 0.0
		return
	# WALKING PAST IS NOT A FOUL. The whistle only ever fires while the DEFEND
	# button is held (or while he is actually going for the ball): just running
	# by a lower role, standing near him or crossing his path is clean.
	if not (u.guarding or u.steal_t > 0.0 or u.block_window > 0.0):
		_ill_dwell = 0.0
		return
	# L'uomo che sto addosso ADESSO: il piu' vicino, entro il contatto.
	var man: BallPlayer = null
	var bd := 46.0
	for a in players:
		if a.team == u.team:
			continue
		var d: float = u.global_position.distance_to(a.global_position)
		if d < bd:
			bd = d
			man = a
	if man == null or not ill_guard(u, man):
		_ill_dwell = 0.0
		return
	ill_mark = man            # per il segno rosso: "questo non puoi marcarlo"
	if shot_clock > 22.5 or _ill_whistle_cd > 0.0:
		_ill_dwell = 0.0
		return
	# STARE ADDOSSO UN ATTIMO E' OK. Il fischio arriva se insisti: cosi' un
	# contatto di passaggio non diventa un fallo.
	_ill_dwell += delta
	if _ill_dwell < 0.30:
		return
	_ill_dwell = 0.0
	illegal_defense(u, man)''',
    "illegal defence rework")

# il gioco non ti porta piu' addosso a chi non puoi marcare
edit("src/match/Player.gd",
'''	# DEFENSE: with GUARD held, glue to the ball-handler and stay between him
	# and the basket. The user can then jump to block or reach in to steal.
	if guarding and is_user and not has_ball:
		var h: BallPlayer = court.ball_handler() if court != null else null
		if h != null and h.team != team:
			var own_hoop: Vector2 = court.attack_hoop_for(h)
			var gp: Vector2 = h.global_position + (own_hoop - h.global_position).normalized() * 46.0
			var gd: Vector2 = gp - global_position
			wish = gd.normalized() if gd.length() > 9.0 else Vector2.ZERO
			stance = gd.length() < 95.0
		else:
			guarding = false''',
'''	# DEFENSE: with GUARD held you take the man the game gives you -- the
	# ball-handler when you may legally take him, otherwise your own man, and
	# when you have nobody legal you help (between the ball and our basket)
	# instead of walking into an "L" foul.
	if guarding and is_user and not has_ball:
		if court == null:
			guarding = false
		else:
			var tgt: BallPlayer = court.guard_target
			if tgt != null and tgt.team != team:
				var own_hoop: Vector2 = court.attack_hoop_for(tgt)
				var gp: Vector2 = tgt.global_position \\
					+ (own_hoop - tgt.global_position).normalized() * 46.0
				var gd: Vector2 = gp - global_position
				wish = gd.normalized() if gd.length() > 9.0 else Vector2.ZERO
				stance = gd.length() < 95.0
			elif court.ball != null and court.ball.holder != null \\
					and court.ball.holder.team != team:
				# NESSUN UOMO LEGALE: aiuto, senza addosso a nessuno.
				var mine: Vector2 = court.hoop_for(team)
				var bp: Vector2 = court.ball.global_position
				var help: Vector2 = mine.lerp(bp, 0.58)
				var hd: Vector2 = help - global_position
				wish = hd.normalized() if hd.length() > 24.0 else Vector2.ZERO
				stance = hd.length() < 140.0
			else:
				guarding = false''',
    "guard picks a legal man")

# a schermo: chi devi marcare e chi no
edit("src/match/Player.gd",
'''	if court != null and court.aimed == self:
		draw_set_transform(proj - position, 0.0, Vector2(1.0, 0.55) * dscale)
		draw_circle(Vector2.ZERO, 38.0, Color(0.20, 0.55, 1.0, 0.42))
		draw_arc(Vector2.ZERO, 38.0, 0.0, TAU, 28, Color(0.45, 0.75, 1.0, 0.9), 3.0)
		draw_set_transform(proj - position, 0.0, Vector2(1.0 - squash * 0.5, 1.0 + squash) * dscale)''',
'''	if court != null and court.aimed == self:
		draw_set_transform(proj - position, 0.0, Vector2(1.0, 0.55) * dscale)
		draw_circle(Vector2.ZERO, 38.0, Color(0.20, 0.55, 1.0, 0.42))
		draw_arc(Vector2.ZERO, 38.0, 0.0, TAU, 28, Color(0.45, 0.75, 1.0, 0.9), 3.0)
		draw_set_transform(proj - position, 0.0, Vector2(1.0 - squash * 0.5, 1.0 + squash) * dscale)
	# CHI PUOI MARCARE: un anello ai piedi dell'uomo che il tasto DIFENDI ti
	# manda a prendere (azzurro), e uno ROSSO su quello che non puoi marcare:
	# cosi' il fallo "L" non arriva mai per sbaglio.
	if court != null and court.guard_target == self:
		draw_set_transform(proj - position, 0.0, Vector2(1.0, 0.55) * dscale)
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 26, Color(0.45, 0.85, 1.0, 0.85), 3.0)
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 22, Color(0.45, 0.85, 1.0, 0.45), 2.0)
		draw_set_transform(proj - position, 0.0, Vector2(1.0 - squash * 0.5, 1.0 + squash) * dscale)
	elif court != null and court.ill_mark == self:
		draw_set_transform(proj - position, 0.0, Vector2(1.0, 0.55) * dscale)
		var pl: float = 0.55 + 0.45 * absf(sin(anim_t * 4.0))
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 26, Color(1.0, 0.35, 0.28, 0.55 + 0.4 * pl), 4.0)
		draw_set_transform(proj - position, 0.0, Vector2(1.0 - squash * 0.5, 1.0 + squash) * dscale)''',
    "guard rings")

print("BA_PATCH_S: %d edit applicate" % n)
