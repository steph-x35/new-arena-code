extends RefCounted
class_name ShotSystem
## Pure, testable shot resolution. No node access -> easy to unit test and to reuse
## for the gym drills and for simulating AI-only possessions.

## FIBA three-point distance, 6.75 m. Lives HERE rather than on Court because
## this module is deliberately node-free so it can be unit tested on its own --
## reaching for Court.THREE_FT made Court (and therefore the Game autoload) a
## compile-time dependency and broke the standalone test.
## Court re-exports this as Court.THREE_FT.
const THREE_FT := 22.15

enum Timing { EARLY, GOOD, PERFECT, LATE, VERY_LATE }

const PERFECT_WINDOW := 0.055   # seconds around the ideal release
const GOOD_WINDOW := 0.16

static func timing_from_error(err: float) -> int:
	var a := absf(err)
	if a <= PERFECT_WINDOW: return Timing.PERFECT
	if a <= GOOD_WINDOW: return Timing.GOOD if err < 0 else Timing.GOOD
	if err < 0: return Timing.EARLY
	return Timing.LATE if a < 0.34 else Timing.VERY_LATE

static func timing_name(t: int) -> String:
	match t:
		Timing.PERFECT: return "PERFECT"
		Timing.GOOD: return "GOOD"
		Timing.EARLY: return "EARLY"
		Timing.LATE: return "LATE"
		_: return "VERY LATE"

static func timing_mod(t: int) -> float:
	match t:
		Timing.PERFECT: return 1.0
		Timing.GOOD: return 0.68
		Timing.EARLY: return 0.24
		Timing.LATE: return 0.20
		_: return 0.05

## The release windows tighten with distance. Up close they are the standard
## PERFECT/GOOD bands; from deep out (past ~24 ft, i.e. once you are standing
## around half court) the green band visibly shrinks and the shot genuinely
## gets harder to time. Returns {"perfect": s, "good": s} in seconds.
static func shot_windows(dist_ft: float, heat := false) -> Dictionary:
	var pw := PERFECT_WINDOW
	var gw := GOOD_WINDOW
	if dist_ft > 24.0:
		var over: float = dist_ft - 24.0
		pw = maxf(0.016, pw - over * 0.0042)
		gw = maxf(0.05, gw - over * 0.0082)
	if heat:
		# HEAT CHECK (da Hoop City): 3 canestri di fila allargano la finestra.
		# Il contratto resta: rosso=mai, giallo=50/50, verde=100% — il verde
		# e' piu' largo.
		pw *= 1.18
		gw *= 1.15
	return {"perfect": pw, "good": gw}

## Base shooting rating for a distance, in feet-equivalent.
static func rating_for_distance(a_close: float, a_mid: float, a_three: float, dist_ft: float) -> float:
	if dist_ft <= 8.0: return a_close
	if dist_ft <= 15.0: return lerpf(a_close, a_mid, (dist_ft - 8.0) / 7.0)
	if dist_ft <= THREE_FT: return lerpf(a_mid, a_three, (dist_ft - 15.0) / (THREE_FT - 15.0))
	return a_three

## Returns {"p": float, "made": bool, "timing": int, "quality": String}
static func resolve(p: Dictionary) -> Dictionary:
	# expected keys: dist_ft, contest (0..1), timing_err, stamina01, momentum,
	#                a_close, a_mid, a_three, badges (Array), open_catch (bool), moving (bool)
	var t := timing_from_error(float(p.get("timing_err", 0.0)))
	var rating := rating_for_distance(p.a_close, p.a_mid, p.a_three, p.dist_ft)

	# 1) base make% from rating, anchored to real shot-type expectations.
	#    Rim shots are high-percentage for everyone; jumpers depend far more on skill.
	var floor_p: float
	var ceil_p: float
	if p.dist_ft <= 5.0:
		floor_p = 0.55; ceil_p = 0.88        # layups/dunks: skill matters less
	elif p.dist_ft <= 15.0:
		floor_p = 0.36; ceil_p = 0.66
	else:
		floor_p = 0.28; ceil_p = 0.60        # NBA-ish: elite open 3 lands near 45-50%
	var base := lerpf(floor_p, ceil_p, clampf((rating - 35.0) / 60.0, 0.0, 1.0))

	# 2) distance penalty on top of the rating curve. Quadratic past the arc so
	#    heaves collapse toward zero instead of staying coin-flips.
	var dist_pen := 0.0
	if p.dist_ft > THREE_FT:
		var over: float = p.dist_ft - THREE_FT
		dist_pen = over * 0.014 + over * over * 0.0022
		if "deep_range" in p.get("badges", []):
			dist_pen *= 0.55
	elif p.dist_ft > 15.0:
		dist_pen = (p.dist_ft - 15.0) * 0.006

	# 3) contest: a hand in the face is the single biggest factor
	var contest_pen: float = float(p.get("contest", 0.0)) * lerpf(0.42, 0.22, clampf((rating - 40.0) / 55.0, 0.0, 1.0))

	# 4) fatigue
	var fatigue_pen := (1.0 - clampf(float(p.get("stamina01", 1.0)), 0.0, 1.0)) * 0.20

	# 5) timing
	var timing_factor := timing_mod(t)

	# 6) bonuses
	var bonus := 0.0
	if p.get("open_catch", false) and "catch_and_shoot" in p.get("badges", []) and float(p.get("contest", 0)) < 0.3:
		bonus += 0.055
	if p.get("moving", false):
		bonus -= 0.05
	bonus += clampf(float(p.get("momentum", 0.0)), -1.0, 1.0) * 0.035

	var prob := (base - dist_pen - contest_pen - fatigue_pen + bonus)
	# timing scales how much of your ceiling you actually reach
	prob = lerpf(prob * 0.18, prob, timing_factor)
	prob = clampf(prob, 0.02, 0.95)

	# REGOLA FERREA del meter (richiesta dell'utente): VERDE = 100%,
	# GIALLO = 50/50, ROSSO = MAI. Il colore che vedi e' il verdetto, senza
	# formule che lasciano entrare i rossi. Lo skill/contest conta dentro le
	# fasce (tirare contests resta piu' difficile perchE' il verde e' stretto),
	# ma il colore deciso dal timing decide SEMPRE l'esito.
	var made := false
	var swish := false
	if t == Timing.PERFECT:
		made = true
		swish = true
	elif t == Timing.GOOD:
		made = randf() < 0.5
	var quality := "OPEN"
	var c := float(p.get("contest", 0.0))
	if c > 0.66: quality = "HEAVILY CONTESTED"
	elif c > 0.33: quality = "CONTESTED"

	return {"p": prob, "made": made, "timing": t, "quality": quality,
			"swish": swish,
			"points": 3 if p.dist_ft > THREE_FT else 2}
