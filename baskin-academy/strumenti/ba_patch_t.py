#!/usr/bin/env python3
# Batch 13 (v1.14.0). Applica le modifiche ai sorgenti Godot.
#   1) DOPPIO PALLEGGIO: dopo la finta la palla e' raccolta; rimetterla a terra
#      (tasto TRICK/finta di palleggio) = infrazione, palla agli avversari.
#   2) CANESTRO CHE VIBRA: la schiacciata (e il ferro) fanno tremare il canestro.
#   3) RIMBALZO SUL TIRO LIBERO SBAGLIATO: sull'ULTIMO libero sbagliato la palla
#      resta viva (con la fila in area come nel regolamento).
#   4) Il canestro laterale lontano si legge meglio (ombra dietro il tabellone).
import io
import sys

ROOT = "/home/user/baskin_academy/"
edits = []


def edit(path, old, new, count=1):
    edits.append((path, old, new, count))


# ---------------------------------------------------------------- 1. Loc.gd
edit("src/core/Loc.gd",
     '''	"rule.v_area":     ["VIOLATION · OUTSIDE THE AREA", "INFRAZIONE · FUORI DALL'AREA"],''',
     '''	"rule.v_dbl":      ["VIOLATION · DOUBLE DRIBBLE", "INFRAZIONE · DOPPIO PALLEGGIO"],
	"rule.v_dbl.body": ["The fake GATHERS the ball (held in both hands): from that moment you may only pass or shoot. Dribbling again is a double dribble — the ball goes to the opponents.",
		"La finta RACCOGLIE la palla (ferma nelle mani): da li' in poi puoi solo passare o tirare. Se la rimetti a terra e palleggi e' doppio palleggio — palla agli avversari."],
	"rule.v_area":     ["VIOLATION · OUTSIDE THE AREA", "INFRAZIONE · FUORI DALL'AREA"],''')

# -------------------------------------------------------------- 2. Player.gd
edit("src/match/Player.gd",
     '''func do_move(kind: String) -> bool:
	## crossover / stepback / behind-the-back / hand switch / hesitation --
	## a short burst, a visible ball-handling animation, and a defender shake
	## chance. Returns false when the move could not be attempted.
	if cooldown_move > 0.0 or not has_ball:
		return false''',
     '''func do_move(kind: String) -> bool:
	## crossover / stepback / behind-the-back / hand switch / hesitation --
	## a short burst, a visible ball-handling animation, and a defender shake
	## chance. Returns false when the move could not be attempted.
	if cooldown_move > 0.0 or not has_ball:
		return false
	# DOPPIO PALLEGGIO: dopo la finta la palla e' RACCOLTA al petto. Metterla
	# di nuovo a terra per palleggiare e' infrazione (palla agli avversari):
	# da raccolta si puo' solo passare o tirare.
	if fake_locked and court != null and court.play_live:
		fake_locked = false
		travel_warn = 0.0
		court.double_dribble_violation(self)
		return false''')

# -------------------------------------------------------------- 3. Court.gd
# 3a. la vibrazione del canestro (rim_quake) accanto a _net_bump
edit("src/match/Court.gd",
     '''func _net_bump(idx: int, amt: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var vis: Node = parent.get_node_or_null("CourtVisual")
	if vis != null and vis.has_method("net_bump"):
		vis.net_bump(idx, amt)''',
     '''func _net_bump(idx: int, amt: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var vis: Node = parent.get_node_or_null("CourtVisual")
	if vis != null and vis.has_method("net_bump"):
		vis.net_bump(idx, amt)

## IL CANESTRO VIBRA: una scossa che fa tremare ferro, tabellone e retina per
## circa un secondo. La schiacciata la vuole al massimo, il ferro sfiorato un
## filo. La visura la disegna CourtVisual (quake_off), qui si dice solo quando.
func _rim_quake(idx: int, amt: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var vis: Node = parent.get_node_or_null("CourtVisual")
	if vis != null and vis.has_method("rim_quake"):
		vis.rim_quake(idx, amt)

## Scossa sul canestro piu' vicino a un punto del campo.
func _quake_at(at: Vector2, amt: float) -> void:
	_rim_quake(hoop_index_of(nearest_hoop(at)), amt)''')

# 3b. doppio palleggio (accanto a travel_violation)
edit("src/match/Court.gd",
     '''func travel_violation(p: BallPlayer) -> void:
	Events.toast.emit("Traveling!")
	_turnover_to(1 - p.team)''',
     '''func travel_violation(p: BallPlayer) -> void:
	Events.toast.emit("Traveling!")
	_turnover_to(1 - p.team)

## DOPPIO PALLEGGIO: la palla era RACCOLTA (finta) e viene rimessa a terra per
## palleggiare di nuovo. Non e' un fallo: e' un'infrazione, palla agli
## avversari, esattamente come i passi.
func double_dribble_violation(p: BallPlayer) -> void:
	Sfx.play("whistle_short")
	Events.toast.emit(Loc.t("rule.v_dbl"))
	Events.rule.emit("v_dbl")
	_turnover_to(1 - p.team)''')

# 3c. schiacciata -> scossa forte
edit("src/match/Court.gd",
     '''	Sfx.play("dunk", 1.0)
	Sfx.cheer(true)
	Events.shake.emit(1.0)''',
     '''	Sfx.play("dunk", 1.0)
	Sfx.cheer(true)
	Events.shake.emit(1.0)
	# Il canestro VIBRA: e' la richiesta "la schiacciata fa tremare il ferro".
	_rim_quake(hoop_index_of(hoop_for(p.team)), 1.0)''')

# 3d. schiacciata segnata: la scossa continua mentre e' appeso
edit("src/match/Court.gd",
     '''	_net_bump(hoop_index_of(hoop_for(p.team)), 1.0)
	_rim_fx("swish", hoop_for(p.team))
	# La rete CANTA anche sulla schiacciata: swish piu' cupo e spinto.''',
     '''	_net_bump(hoop_index_of(hoop_for(p.team)), 1.0)
	_rim_fx("swish", hoop_for(p.team))
	_rim_quake(hoop_index_of(hoop_for(p.team)), 1.0)
	# La rete CANTA anche sulla schiacciata: swish piu' cupo e spinto.''')

# 3e. ferro colpito (tabellone, ferro, rattle, swish, tiro libero)
edit("src/match/Court.gd",
     '''			Sfx.play("backboard", -7.0)
			Events.shake.emit(0.28)
			_net_bump(_hidx, 0.35)''',
     '''			Sfx.play("backboard", -7.0)
			Events.shake.emit(0.28)
			_net_bump(_hidx, 0.35)
			_rim_quake(_hidx, 0.30)''')
edit("src/match/Court.gd",
     '''				Events.shake.emit(0.60)
				_rim_fx("rattle", hoop)
				_net_bump(_hidx, 0.9)''',
     '''				Events.shake.emit(0.60)
				_rim_fx("rattle", hoop)
				_net_bump(_hidx, 0.9)
				_rim_quake(_hidx, 0.75)''')
edit("src/match/Court.gd",
     '''			Sfx.play("rim", -3.5, randf_range(0.94, 1.06))
			Events.shake.emit(0.32)
			_net_bump(_hidx, 0.85)
			_rim_fx("iron", hoop)''',
     '''			Sfx.play("rim", -3.5, randf_range(0.94, 1.06))
			Events.shake.emit(0.32)
			_net_bump(_hidx, 0.85)
			_rim_quake(_hidx, 0.45)
			_rim_fx("iron", hoop)''')
edit("src/match/Court.gd",
     '''		_net_bump(hoop_index_of(hoop), 1.0)
		_rim_fx("swish", hoop)
		b.is_free_throw = false
		_on_ft_result(true)''',
     '''		_net_bump(hoop_index_of(hoop), 1.0)
		_rim_fx("swish", hoop)
		_rim_quake(hoop_index_of(hoop), 0.55)
		b.is_free_throw = false
		_on_ft_result(true)''')
edit("src/match/Court.gd",
     '''	b.dunk_drop = 1.0
	b.global_position = hoop
	b.h = rim_height_of(hoop) + 8.0
	_net_bump(hoop_index_of(hoop), 1.0)
	_rim_fx("swish", hoop)''',
     '''	b.dunk_drop = 1.0
	b.global_position = hoop
	b.h = rim_height_of(hoop) + 8.0
	_net_bump(hoop_index_of(hoop), 1.0)
	_rim_fx("swish", hoop)
	_rim_quake(hoop_index_of(hoop), 0.55)''')

# 3f. fila del tiro libero (regolamento) + rimbalzo sull'ultimo sbagliato
edit("src/match/Court.gd",
     '''	# Everyone else steps out of the lane, so the line is clear. On a side
	# basket there is no lane to clear: the others wait around mid-court.
	var side := 1.0
	for p in players:
		if p == victim:
			continue
		if ft_side:
			p.global_position = Vector2(side * 300.0, -side * 200.0)
		else:
			p.global_position = hoop + Vector2(dir * (FT_PX + 240.0), side * 180.0)
		p.velocity = Vector2.ZERO
		p.move_input = Vector2.ZERO
		side = -side''',
     '''	# FILA DEL TIRO LIBERO (regolamento): due per squadra negli spazi della
	# corsia, gli altri fuori dall'arco. Serve perche' sull'ULTIMO libero
	# sbagliato la palla resta VIVA e il rimbalzo si gioca davvero.
	_line_up_for_free_throws(victim, hoop, dir, ft_side)''')

edit("src/match/Court.gd",
     '''func _end_free_throws() -> void:''',
     '''## Schieramento del tiro libero: due per squadra in corsia (i piu' vicini al
## canestro), gli altri dietro la linea da tre. Sul canestro laterale non c'e'
## corsia: due per squadra appena fuori dall'area piccola, gli altri a
## meta' campo.
func _line_up_for_free_throws(victim: BallPlayer, hoop: Vector2, dir: float,
		ft_side: bool) -> void:
	var slot := 0
	var far := 0
	var order := players.duplicate()
	order.sort_custom(func(a, b):
		return a.global_position.distance_to(hoop) < b.global_position.distance_to(hoop))
	var used := {0: 0, 1: 0}
	for p in order:
		if p == victim:
			continue
		p.velocity = Vector2.ZERO
		p.move_input = Vector2.ZERO
		if used[p.team] < 2:
			# due posti in corsia, uno per lato della linea
			var lane_side: float = -1.0 if used[p.team] == 0 else 1.0
			used[p.team] += 1
			if ft_side:
				var inward: float = 1.0 if hoop.y < 0.0 else -1.0
				p.global_position = hoop + Vector2(lane_side * (SIDE_AREA_R + 56.0),
					inward * (SIDE_AREA_R - 26.0 + lane_side * 16.0))
			else:
				p.global_position = hoop + Vector2(dir * (FT_PX - 150.0 + lane_side * 60.0),
					lane_side * (FIBA_PAINT_W * 0.5 - 34.0))
		else:
			slot += 1
			if ft_side:
				p.global_position = Vector2(320.0 * (1.0 if slot % 2 == 0 else -1.0),
					-220.0 * (1.0 if slot < 3 else -1.0))
			else:
				p.global_position = hoop + Vector2(dir * (FT_PX + 230.0 + 90.0 * float(far % 3)),
					-190.0 + 100.0 * float(slot % 4))
			far += 1

func _end_free_throws() -> void:''')

# 3g. ultimo tiro libero sbagliato: palla VIVA
edit("src/match/Court.gd",
     '''	if b.is_free_throw:
		# A missed free throw has no rebound battle: the sequence continues.
		_rim_fx("iron" if b.global_position.distance_to(nearest_hoop(b.global_position)) < 80.0 else "miss", b.global_position)
		b.is_free_throw = false
		_on_ft_result(false)
		return''',
     '''	if b.is_free_throw:
		var near_hoop: bool = b.global_position.distance_to(nearest_hoop(b.global_position)) < 80.0
		_rim_fx("iron" if near_hoop else "miss", b.global_position)
		b.is_free_throw = false
		# LIBERI SUCCESSIVI: la sequenza continua, niente rimbalzo.
		# ULTIMO LIBERO SBAGLIATO: la palla resta VIVA e si va a rimbalzo
		# (regolamento). Tranne il fallo "L", dove la palla torna comunque
		# alla squadra che ha subito il fallo.
		if ft_left > 1 or _ft_keep_possession or one_on_one:
			_on_ft_result(false)
			return
		_missed_last_free_throw(b)
		return''')

edit("src/match/Court.gd",
     '''func _end_free_throws() -> void:''',
     '''## L'ultimo tiro libero sbagliato non chiude il gioco: la palla e' viva.
## Si esce dalla sequenza e si lascia il rimbalzo al gioco (stesse regole del
## rimbalzo normale: chi arriva prima la prende, peso sulla vicinanza).
func _missed_last_free_throw(b: Ball) -> void:
	ft_left = maxi(0, ft_left - 1)
	ft_active = false
	ft_shooter = null
	restarting = false
	_ft_keep_possession = false
	play_live = true
	Events.toast.emit(Loc.t("t.ftlive"))
	var hoop: Vector2 = b.shot_hoop if b.shot_hoop.length() > 1.0 else nearest_hoop(b.global_position)
	_rim_quake(hoop_index_of(hoop), 0.5)
	var best: BallPlayer = null
	var best_w := -1.0
	for p in players:
		var d: float = p.global_position.distance_to(b.global_position)
		if d > 260.0:
			continue
		var near: float = pow(1.0 - d / 260.0, 1.6)
		var w: float = (p.ratings["rebound"] / 99.0) * p.height_f * near * randf_range(0.6, 1.4)
		if d < 55.0:
			w *= 1.35
		if p.has_badge("glass_cleaner"):
			w *= 1.1
		if w > best_w:
			best_w = w
			best = p
	if best == null:
		_restart_play(1 - b.last_touch_team)
		return
	give_ball(best)
	shot_clock = 24.0
	if best.is_user:
		Events.toast.emit("RIMBALZO!")

func _end_free_throws() -> void:''')

# ---------------------------------------------------------- 4. CourtVisual.gd
edit("src/match/CourtVisual.gd",
     '''func net_bump(idx: int, amt: float) -> void:
	var i := clampi(idx, 0, 3)
	net_wobble[i] = maxf(net_wobble[i], amt)
	queue_redraw()''',
     '''func net_bump(idx: int, amt: float) -> void:
	var i := clampi(idx, 0, 3)
	net_wobble[i] = maxf(net_wobble[i], amt)
	queue_redraw()

## IL CANESTRO VIBRA. Una scossa che si spegne in circa un secondo: la
## schiacciata la vuole al massimo (il ferro trema mentre sei appeso), il
## ferro sfiorato un filo.
func rim_quake(idx: int, amt: float) -> void:
	var i := clampi(idx, 0, 3)
	rim_shake[i] = maxf(rim_shake[i], amt)
	queue_redraw()

## Scostamento del canestro in questo istante (x,y in px). Zero quando e'
## fermo, cosi' il disegno non cambia di una virgola nel gioco normale.
func quake_off(idx: int) -> Vector2:
	var i := clampi(idx, 0, 3)
	var a: float = rim_shake[i]
	if a <= 0.0:
		return Vector2.ZERO
	return Vector2(sin(t * 37.0) * 5.0 * a, cos(t * 29.0) * 3.2 * a)''')

edit("src/match/CourtVisual.gd",
     '''var net_wobble := [0.0, 0.0, 0.0, 0.0]''',
     '''var net_wobble := [0.0, 0.0, 0.0, 0.0]
var rim_shake := [0.0, 0.0, 0.0, 0.0]    # canestro che vibra (schiacciata/ferro)''')

edit("src/match/CourtVisual.gd",
     '''	var live: bool = net_wobble[0] > 0.0 or net_wobble[1] > 0.0 or net_wobble[2] > 0.0 or net_wobble[3] > 0.0 or crowd_hype > 0.0 or fx_t > 0.0''',
     '''	var live: bool = net_wobble[0] > 0.0 or net_wobble[1] > 0.0 or net_wobble[2] > 0.0 or net_wobble[3] > 0.0 or rim_shake[0] > 0.0 or rim_shake[1] > 0.0 or rim_shake[2] > 0.0 or rim_shake[3] > 0.0 or crowd_hype > 0.0 or fx_t > 0.0''')

edit("src/match/CourtVisual.gd",
     '''	for i in net_wobble.size():
		net_wobble[i] = HoopArt.decay(net_wobble[i], delta)''',
     '''	for i in net_wobble.size():
		net_wobble[i] = HoopArt.decay(net_wobble[i], delta)
		rim_shake[i] = maxf(0.0, rim_shake[i] - delta * 1.15)''')

# il canestro classico trema (ferro + tabellone + retina insieme)
edit("src/match/CourtVisual.gd",
     '''		HoopArt.draw_hoop_unified(self, Vector2(rim_floor.x, rim_floor.y - rim_height),
			22.0, rim_floor.y + 6.0, -s, net_wobble[idx], t, lean, maxf(base_dx, 64.0))''',
     '''		var q: Vector2 = quake_off(idx)
		HoopArt.draw_hoop_unified(self, Vector2(rim_floor.x + q.x, rim_floor.y - rim_height + q.y),
			22.0, rim_floor.y + 6.0, -s, net_wobble[idx], t, lean, maxf(base_dx, 64.0))''')

edit("src/match/CourtVisual.gd",
     '''	var wob: float = net_wobble[widx] if widx < net_wobble.size() else 0.0
	NetFront.draw_side_basket(self, pos, 1.0, wob, t)''',
     '''	var wob: float = net_wobble[widx] if widx < net_wobble.size() else 0.0
	NetFront.draw_side_basket(self, pos, 1.0, wob, t, quake_off(widx))''')

# ------------------------------------------------------------- 5. NetFront.gd
edit("src/match/NetFront.gd",
     '''	var wob: float = vis.net_wobble[2 + si] if (vis != null and 2 + si < vis.net_wobble.size()) else 0.0
	draw_side_basket(self, pos, alpha, wob, vis.t if vis != null else 0.0)''',
     '''	var wob: float = vis.net_wobble[2 + si] if (vis != null and 2 + si < vis.net_wobble.size()) else 0.0
	draw_side_basket(self, pos, alpha, wob, vis.t if vis != null else 0.0,
		vis.quake_off(2 + si) if vis != null else Vector2.ZERO)''')

edit("src/match/NetFront.gd",
     '''static func draw_side_basket(ci: CanvasItem, pos: Vector2, alpha: float,
		wob: float, tt: float) -> void:
	var f: Vector2 = CourtStage.m_project(pos, Court.COURT_H)
	var rim := Vector2(f.x, f.y - Court.SIDE_RIM_HEIGHT)''',
     '''static func draw_side_basket(ci: CanvasItem, pos: Vector2, alpha: float,
		wob: float, tt: float, quake := Vector2.ZERO) -> void:
	var f: Vector2 = CourtStage.m_project(pos, Court.COURT_H) + quake
	var rim := Vector2(f.x, f.y - Court.SIDE_RIM_HEIGHT)''')

# il canestro lontano si legge meglio: un'ombra dietro il tabellone
edit("src/match/NetFront.gd",
     '''	# ---- VISTA FRONTALE (il canestro dall'altra parte del campo)
	ci.draw_line(f + Vector2(0, 10), Vector2(f.x + lean, rim.y - 30.0), steel, 7.0)''',
     '''	# ---- VISTA FRONTALE (il canestro dall'altra parte del campo)
	# Il maxi-schermo dell'arena e' chiaro e sta dietro questo canestro: una
	# ombra appena accennata dietro tabellone e retina lo fa leggere subito.
	ci.draw_rect(Rect2(f.x - 40.0, rim.y - 46.0, 80.0, 78.0),
		Color(0.05, 0.07, 0.12, 0.20 * alpha))
	ci.draw_line(f + Vector2(0, 10), Vector2(f.x + lean, rim.y - 30.0), steel, 7.0)''')

# applica
for path, old, new, count in edits:
    full = ROOT + path
    s = io.open(full, encoding="utf-8").read()
    n = s.count(old)
    if n < count:
        print("MISS %s (%d/%d): %s" % (path, n, count, old.strip().splitlines()[0][:70]))
        sys.exit(1)
    s = s.replace(old, new, count)
    io.open(full, "w", encoding="utf-8").write(s)

print("%d edit applicate" % len(edits))
