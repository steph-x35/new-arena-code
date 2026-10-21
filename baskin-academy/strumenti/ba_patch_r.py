#!/usr/bin/env python3
"""BA_PATCH_R - batch 11 (v1.12.0).

1) RIMBALZO ANTICIPABILE: la palla sa dire dove arrivera' a terra (previsione
   fisica con lo stesso modello del volo) e lo disegna con un anello sul
   parquet quando e' in aria. Vale per tutti (giocatore e IA): non e' un
   vantaggio, e' una lettura.
2) RIMBALZO GIOCATO COME SI DEVE: solo i due piu' vicini al punto di caduta
   per squadra vanno sul ferro; gli altri restano sul proprio uomo (difesa) o
   sulla propria posizione (attacco) invece di correre tutti dietro la palla.
   L'IA usa la previsione vera, non piu' una stima grezza.
3) Rimbalzo preso da te: popup "RIMBALZO!" per leggerlo subito.
4) Pulizia: via il vecchio `dribble_clock` (non piu' usato dal batch 9) e il
   timer "marcato addosso" non resta piu' appeso quando perdi la palla.
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

# ===================================================== Ball.gd: previsione
edit("src/match/Ball.gd",
'''func kill_analytic() -> void:''',
'''## Palla VIVA e libera (rimbalzo, palla vagante)... oppure no.
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

func kill_analytic() -> void:''',
    "landing prediction")

edit("src/match/Ball.gd",
'''var prev_h := 0.0
var prev_pos := Vector2.ZERO''',
'''var prev_h := 0.0
var prev_pos := Vector2.ZERO
var _land_cache := Vector2.ZERO
var _land_at := -1                 # fotogramma fisico della previsione
var _land_ok := false''',
    "landing cache vars")

# ===================================================== Ball.gd: segno a terra
edit("src/match/Ball.gd",
'''	var c := Vector2(0, -h)
	draw_circle(c, r, Color(0.85, 0.42, 0.12))''',
'''	# SEGNO A TERRA: quando la palla e' in aria e libera (rimbalzo, palla
	# vagante) un anello tratteggiato mostra DOVE arrivera'. Serve a
	# anticipare: ci vai prima, la prendi. E' informazione, non aiuto: la
	# stessa previsione la usano gli avversari. Svanisce mentre la palla
	# scende e sparisce appena qualcuno la prende.
	if is_loose() and h > 70.0:
		var land: Vector2 = landing_spot()
		if land.is_finite():
			var dl: Vector2 = land - position
			var air_k: float = clampf((h - 70.0) / 90.0, 0.0, 1.0)
			var col := Color(1.0, 0.97, 0.88, 0.16 + 0.24 * air_k)
			var rr: float = 26.0 + 8.0 * air_k
			# anello appiattito: il pavimento e' inclinato, un cerchio pieno
			# sembrerebbe un pallone sgonfio.
			for i in 12:
				var a0: float = TAU * i / 12.0
				var a1: float = a0 + TAU / 17.0
				draw_line(dl + Vector2(cos(a0) * rr, sin(a0) * rr * 0.5),
					dl + Vector2(cos(a1) * rr, sin(a1) * rr * 0.5), col, 2.2)
			draw_circle(dl, 2.4, col)
	var c := Vector2(0, -h)
	draw_circle(c, r, Color(0.85, 0.42, 0.12))''',
    "landing ring")

# ===================================================== AIBrain: rimbalzo vero
edit("src/match/AIBrain.gd",
'''func _rebound(delta: float) -> void:
	var ball: Ball = court.ball
	var land: Vector2 = ball.global_position + ball.vel * 0.38''',
'''func _rebound(delta: float) -> void:
	var ball: Ball = court.ball
	# Dove arrivera' DAVVERO (previsione fisica condivisa). Se la palla e'
	# ancora alta la previsione e' quella che conta: e' la differenza fra
	# anticipare un rimbalzo e rincorrerlo.
	var land: Vector2 = ball.global_position + ball.vel * 0.38
	var pred: Vector2 = ball.landing_spot()
	if pred.is_finite():
		land = pred
	# RIMBALZO GIOCATO: sul ferro ci vanno i DUE piu' vicini al punto di
	# caduta della mia squadra. Gli altri tengono il proprio uomo (difesa) o
	# la propria posizione (attacco): correre in cinque dietro alla palla e'
	# quello che fa sembrare il rimbalzo una rissa da cortile.
	var mine: int = 0
	for m in court.players:
		if m.team != p.team or m == p or not is_instance_valid(m):
			continue
		if m.global_position.distance_to(land) < p.global_position.distance_to(land):
			mine += 1
	if mine >= 2:
		if p.team != court.possession:
			_defend_off_ball(delta)
		else:
			_attack_off_ball(delta)
		return''',
    "rebound crashers")

# ===================================================== Court: feedback rimbalzo
edit("src/match/Court.gd",
'''	give_ball(best)
	shot_clock = 24.0
	if best.is_user: box["reb"] += 1
	Events.toast.emit("Rebound #%d" % best.jersey_num)''',
'''	give_ball(best)
	shot_clock = 24.0
	if best.is_user:
		box["reb"] += 1
		# Preso da te: si legge subito, come per la schiacciata.
		Events.popup.emit(Loc.t("pop.rebound"), best.global_position,
			Color(0.60, 0.88, 1.0), false)
		Sfx.add_hype(0.05)
	Events.toast.emit("Rebound #%d" % best.jersey_num)''',
    "user rebound popup")

edit("src/core/Loc.gd",
'''	"t.foul.charge":   ["OFFENSIVE FOUL · the ball goes the other way", "FALLO IN ATTACCO · palla agli avversari"],''',
'''	"t.foul.charge":   ["OFFENSIVE FOUL · the ball goes the other way", "FALLO IN ATTACCO · palla agli avversari"],
	"pop.rebound":     ["REBOUND!", "RIMBALZO!"],''',
    "loc rebound")

# ===================================================== Player: pulizia
edit("src/match/Player.gd",
'''var anim_t := 0.0                     # free-running clock for run/dribble cycles
var dribble_clock := 0.0              # ritmo del palleggio: COSTANTE, non scala con la corsa''',
'''var anim_t := 0.0                     # free-running clock for run/dribble cycles''',
    "drop dribble_clock")

edit("src/match/Player.gd",
'''	anim_t += delta * (5.2 + velocity.length() * 0.028)
	dribble_clock += delta * 0.55   # ritmo ancora piu' lento e rilassato''',
'''	anim_t += delta * (5.2 + velocity.length() * 0.028)''',
    "drop dribble_clock tick")

edit("src/match/Player.gd",
'''	else:
		possession_time = 0.0
	if shot_charge >= 0.0:''',
'''	else:
		possession_time = 0.0
		# Senza palla non sei "marcato addosso": il timer deve scadere, non
		# restare appeso al valore dell'ultima azione.
		_press_t = maxf(0.0, _press_t - delta)
	if shot_charge >= 0.0:''',
    "press decay")

print("BA_PATCH_R: %d edit applicate" % n)
