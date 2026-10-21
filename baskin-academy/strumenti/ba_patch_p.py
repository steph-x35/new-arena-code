#!/usr/bin/env python3
"""BA_PATCH_P - batch 9: animazioni e realismo di palleggio e movimenti.

1) PALLEGGIO coerente: mano e palla usano GLI STESSI numeri (una sola fonte:
   Player.dribble_ball_offset), quindi il palmo sta sempre sulla palla.
2) RIMBALZO vero: curva parabolica (la palla tocca il pavimento e risale),
   non piu' un seno troncato.
3) PALLEGGIO SITUAZIONALE: palla bassa e ritmo piu' rapido quando sei marcato
   addosso; palla piu' alta quando sei libero; ritmo legato alla corsa.
4) MOVE: incrocio basso (sotto il ginocchio) con la mano che cambia al momento
   del passaggio, stepback con palla RACCOLTA sul piede perno, esitazione con
   palla tenuta e poi esplosione.
5) CORSA: frenata con strisciata (dust) quando ti fermi in corsa, inclinazione
   del corpo in accelerazione.

Idempotente, con anchor verificati.
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

# ----------------------------------------------------------------- Avatar.gd --
edit("src/ui/Avatar.gd",
'''static func pose(kind := IDLE, phase := 0.0, amount := 0.0,''',
'''## Quanto e' in alto la palla in un palleggio, 0 = a terra, 1 = in mano.
## Curva PARABOLICA (una palla che rimbalza non segue un seno troncato: tocca
## il pavimento, sale, si ferma un istante in mano e ricade). Un'unica fonte
## per il palmo disegnato E per la palla vera in partita: cosi' la mano e la
## palla non possono piu' andare fuori tempo (prima usavano due orologi
## diversi, ed era il motivo per cui il palleggio sembrava finto).
static func drib_frac(ph: float, rate := 1.0) -> float:
	var u: float = fposmod(ph * 1.15 * rate, PI) / PI
	return 4.0 * u * (1.0 - u)

static func pose(kind := IDLE, phase := 0.0, amount := 0.0,''',
    "shared bounce curve")

edit("src/ui/Avatar.gd",
'''		elif kind == DRIBBLE and strong:
			# Hand rides the ball: bounce and palm stay glued.
			var br0: float = h * 0.105 if ball_r < 0.0 else ball_r
			var bounce: float = absf(sin(ph * 1.15))
			hand = Vector2(base.x + hd * h * 0.30, floor_y - bounce * h * 0.55 - br0)''',
'''		elif kind == DRIBBLE and strong:
			# Hand rides the ball: bounce and palm stay glued.
			var br0: float = h * 0.105 if ball_r < 0.0 else ball_r
			var off: Vector2 = p.get("ball_off", Vector2.ZERO)
			if off != Vector2.ZERO:
				# Il chiamante (la partita) ha gia' deciso dove sta la palla:
				# il palmo si mette SOPRA quella palla, non a caso.
				hand = Vector2(base.x + off.x * h, floor_y - off.y * h - br0)
			else:
				var bounce: float = drib_frac(ph)
				hand = Vector2(base.x + hd * h * 0.30, floor_y - bounce * h * 0.55 - br0)''',
    "palm follows the real ball")

edit("src/ui/Avatar.gd",
'''		RUN:
			# dribbling on the move: the ball bounces, never glued to the hand
			bp = Vector2(base.x + hd * h * 0.30,
				floor_y - absf(sin(ph * 1.15)) * h * 0.55 - br)''',
'''		RUN:
			# dribbling on the move: the ball bounces, never glued to the hand
			var offr: Vector2 = p.get("ball_off", Vector2.ZERO)
			if offr != Vector2.ZERO:
				bp = Vector2(base.x + offr.x * h, floor_y - offr.y * h)
			else:
				bp = Vector2(base.x + hd * h * 0.30,
					floor_y - drib_frac(ph) * h * 0.55 - br)''',
    "avatar ball matches too")

edit("src/ui/Avatar.gd",
'''	# Body stays PLUMB. Only the head/face looks left or right.
	lean = 0.0''',
'''	# Body stays PLUMB. Only the head/face looks left or right.
	lean = 0.0
	# In corsa il corpo si inclina nella direzione del movimento (quanto lo
	# decide la partita: `lean_f` e' una frazione dell'altezza, -1..1). Fermo
	# resta dritto: nessuna posa da supereroe.
	lean = float(p.get("lean_f", 0.0)) * h''',
    "body lean")

# ----------------------------------------------------------------- Player.gd --
edit("src/match/Player.gd",
'''func dribble_ball_offset() -> Dictionary:
	# Same bounce the avatar palm uses (anim_t * 1.6), so the ball sits IN the hand.
	var hs: float = hand_side if absf(hand_side) > 0.1 else 1.0
	var hb: float = 64.0 * height_f''',
'''## Quanto e' "stretto" il palleggio adesso: marcato addosso = palla bassa e
## ritmo rapido (si protegge), libero = palla alta e ritmo tranquillo, in corsa
## il ritmo sale con la velocita'. Questi due numeri sono usati sia dal
## disegno del palmo (Avatar) sia dalla palla vera: una sola verita'.
func drib_hint() -> Vector2:
	var hb: float = 64.0 * height_f
	var rate: float = 1.0 + clampf(velocity.length() / 900.0, 0.0, 0.35)
	if _press_t > 0.0:
		rate *= 1.22
	_press_t = maxf(0.0, _press_t - 0.016)
	var off: Dictionary = dribble_ball_offset()
	return Vector2(float(off["x"]) / hb, float(off["h"]) / hb)

func dribble_ball_offset() -> Dictionary:
	# UNA SOLA FONTE: questo offset e' anche quello che il disegno del palmo
	# usa (vedi drib_hint -> Avatar "ball_off"), quindi mano e palla non
	# possono piu' andare fuori tempo.
	var hs: float = hand_side if absf(hand_side) > 0.1 else 1.0
	var hb: float = 64.0 * height_f''',
    "dribble hint helper")

edit("src/match/Player.gd",
'''	var bounce: float = absf(sin(dribble_clock * 6.0))
	var side := hs * hb * 0.34
	var hh := bounce * hb * 0.55 + Court.BALL_R''',
'''	# RIMBALZO VERO + SITUAZIONE: la palla scende fino al pavimento e risale
	# (parabola), con l'altezza che dipende da quanto sei marcato e dalla corsa.
	var rate: float = 1.0 + clampf(velocity.length() / 900.0, 0.0, 0.35)
	var scale := 1.0
	if _press_t > 0.0:
		scale = 0.58            # marcato: palla bassa, protetta
		rate *= 1.22
	elif velocity.length() > 250.0:
		scale = 0.86            # in corsa piena: un filo piu' bassa
	var bounce: float = Avatar.drib_frac(anim_t, rate)
	var side := hs * hb * 0.34
	var hh := bounce * hb * 0.55 * scale + Court.BALL_R''',
    "real bounce + pressure")

edit("src/match/Player.gd",
'''			"crossover":
				# scambio di mano con overshoot: la palla scatta oltre la gamba
				side = lerpf(side, -side, smoothstep(0.0, 1.0, f)) * (1.0 + 0.18 * low)
				hh = 27.0 + low * 40.0''',
'''			"crossover":
				# INCROCIO BASSO: la palla passa sotto il ginocchio, con un
				# filo di overshoot sulla mano nuova, esattamente come un
				# incrocio vero (alto si ruba).
				side = lerpf(side, -side, smoothstep(0.0, 1.0, f)) * (1.0 + 0.18 * low)
				hh = Court.BALL_R + 2.0 + low * 26.0''',
    "low crossover")

edit("src/match/Player.gd",
'''			"stepback":
				side *= 0.7
				hh = 19.0 + low * 31.0''',
'''			"stepback":
				# Il passo indietro si fa con la palla RACCOLTA in mano (il
				# palleggio si ferma sul piede perno), poi riparte bassa.
				side *= 0.7
				hh = lerpf(hb * 0.46, Court.BALL_R + 6.0, clampf((f - 0.45) / 0.55, 0.0, 1.0))''',
    "stepback collects the ball")

edit("src/match/Player.gd",
'''			"hesi":
				hh = 16.0''',
'''			"hesi":
				# ESITAZIONE: un istante con la palla in mano (la pausa che
				# congela il difensore), poi via bassa e veloce.
				hh = lerpf(hb * 0.44, Court.BALL_R + 8.0, clampf(f / 0.55, 0.0, 1.0))''',
    "hesitation hold")

edit("src/match/Player.gd",
'''var move_t := 0.0                     # >0 while a crossover/stepback animates''',
'''var _press_t := 0.0                   # >0 mentre sei marcato addosso (palleggio basso)
var skid_t := 0.0                     # >0 mentre strisci in frenata
var move_t := 0.0                     # >0 while a crossover/stepback animates''',
    "player state")

edit("src/match/Player.gd",
'''	if wish.length() < 0.05:
		a *= 1.6   # deceleration/friction is faster than acceleration
	velocity = velocity.move_toward(target, a * delta)''',
'''	# FRENATA: chi corre e si ferma di colpo STRISCIA sul parquet (e alza
	# polvere), invece di inchiodarsi come se avesse le radici. Piu' veloce
	# eri, piu' la strisciata si vede.
	var braking: bool = wish.length() < 0.05 and velocity.length() > 150.0
	if braking:
		a *= lerpf(1.0, 0.42, clampf(velocity.length() / 260.0, 0.0, 1.0))
		skid_t = 0.22
		if _skid_cd <= 0.0:
			_skid_cd = 0.5
			dust_by = 0.0
			dust_big = false
			dust_t = maxf(dust_t, 0.30)
			Sfx.squeak()
	else:
		a *= 1.6   # deceleration/friction is faster than acceleration
		skid_t = maxf(0.0, skid_t - delta)
	velocity = velocity.move_toward(target, a * delta)''',
    "braking skid")

edit("src/match/Player.gd",
'''	# A pass is on its way to me: I turn to meet it, so it arrives in the hands''',
'''	_skid_cd = maxf(0.0, _skid_cd - delta)
	if not braking_guard():
		pass
	# A pass is on its way to me: I turn to meet it, so it arrives in the hands''',
    "skid cooldown tick")

edit("src/match/Player.gd",
'''func ball_anchor() -> Vector2:''',
'''var _skid_cd := 0.0

## Marca di pattinata: due righe scure ai piedi, per la mezza secondo che dura
## la frenata. Disegnata sotto il corpo, come le tracce sul parquet.
func _draw_skid(proj_from: Vector2, dscale: float) -> void:
	if skid_t <= 0.0:
		return
	var k: float = clampf(skid_t / 0.22, 0.0, 1.0)
	var col := Color(0.28, 0.22, 0.16, 0.28 * k)
	draw_set_transform(proj_from - position, 0.0, Vector2(1.0, 0.55) * dscale)
	for s in [-1.0, 1.0]:
		draw_line(Vector2(s * 7.0, -1.0), Vector2(s * 7.0 - facing * 26.0 * k, -1.0), col, 2.4)

func ball_anchor() -> Vector2:''',
    "skid marks")

# the pose gets the lean + the ball offsets
edit("src/match/Player.gd",
'''	var po: Dictionary = Avatar.pose(kind, phase, amount, dunk_trick, walking)
	po["hand"] = hand_side''',
'''	var po: Dictionary = Avatar.pose(kind, phase, amount, dunk_trick, walking)
	po["hand"] = hand_side
	# Il palmo disegnato usa ESATTAMENTE la posizione della palla vera (stessi
	# numeri), quindi la mano sta sulla palla anche durante i move.
	if has_ball and not (hanging or dunking):
		po["ball_off"] = drib_hint()
	# Inclinazione del corpo: in accelerazione si va "in avanti", in frenata
	# indietro. E' una frazione dell'altezza disegnata.
	po["lean_f"] = lean_frac()''',
    "pose extras")

edit("src/match/Player.gd",
'''func _body_h() -> float:''',
'''## Quanto inclinare il corpo (frazione dell'altezza, -1..1): chi accelera si
## porta avanti, chi frena si raddrizza e si appoggia indietro.
func lean_frac() -> float:
	if stance or hanging or dunking or air > 6.0:
		return 0.0
	var v: float = velocity.length()
	if v < 40.0:
		return 0.0
	var dir: float = signf(velocity.x) if absf(velocity.x) > 4.0 else facing
	var push: float = clampf(v / maxf(max_speed(), 1.0), 0.0, 1.0)
	if skid_t > 0.0:
		dir = -dir
		push *= 0.8
	return dir * push * 0.055

func _body_h() -> float:''',
    "lean helper")

# the skid drawing goes right before the ball/figures
edit("src/match/Player.gd",
'''	Avatar.draw_body(self, feet, h, facing, po, cols, false, air_draw < 12.0 and not dunking, is_user,''',
'''	_draw_skid(feet, 1.0)
	Avatar.draw_body(self, feet, h, facing, po, cols, false, air_draw < 12.0 and not dunking, is_user,''',
    "draw the skid")

print("BA_PATCH_P: %d edit applicate" % n)
