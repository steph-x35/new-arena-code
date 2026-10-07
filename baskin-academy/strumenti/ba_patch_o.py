#!/usr/bin/env python3
"""BA_PATCH_O - batch 8.

1) CONSEGNA AL PIVOT comoda: il pivot della tua squadra ti viene incontro
   quando sei dentro la sua area con la palla, e la consegna da vicino e'
   un hand-off rapido a due mani (non un passaggio lanciato).
2) FALLI regolamentari: prima del 5o fallo di squadra un fallo NON sul tiro
   si riprende con una rimessa, non con i tiri liberi (bonus dal 5o in poi).
3) TIMEOUT che serve: 4 secondi di respiro che restituiscono energie.
4) PANCHINA VIVA: la panchina della squadra che segna si alza e festeggia.
5) CRONOMETRO: negli ultimi 5 secondi e' rosso e suona il beep di countdown.

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

# ------------------------------------------------------------------ Loc.gd ---
edit("src/core/Loc.gd",
'''	"rule.v_3sec":     ["3 SECONDS · you may not camp in the key", "3 SECONDI · non si sosta nell'area"],''',
'''	"rule.v_3sec":     ["3 SECONDS · you may not camp in the key", "3 SECONDI · non si sosta nell'area"],
	"t.foul.inbound":  ["FOUL · throw-in", "FALLO · rimessa"],
	"t.foul.bonus":    ["FOUL · bonus: 2 free throws", "FALLO · bonus: 2 tiri liberi"],
	"t.handoff":       ["Hand-off!", "Consegna!"],
	"t.timeout.breather": ["TIMEOUT · legs back", "TIMEOUT · gambe recuperate"],''',
    "batch-8 strings")

# ----------------------------------------------------------------- Court.gd ---
edit("src/match/Court.gd",
'''var _ill_whistle_cd := 0.0          # "L" fouls: at most one every few seconds''',
'''var _ill_whistle_cd := 0.0          # "L" fouls: at most one every few seconds
## PANCHINA VIVA: >0 mentre la panchina della squadra festeggia un canestro.
var bench_cheer := [0.0, 0.0]''',
    "bench cheer state")

edit("src/match/Court.gd",
'''	_baskin_clocks(delta)
	_time_infractions(delta)''',
'''	_baskin_clocks(delta)
	_time_infractions(delta)
	bench_cheer[0] = maxf(0.0, bench_cheer[0] - delta)
	bench_cheer[1] = maxf(0.0, bench_cheer[1] - delta)''',
    "bench cheer decay")

edit("src/match/Court.gd",
'''func call_foul(defender: BallPlayer, victim: BallPlayer, pts_attempt := 0) -> void:
	team_fouls[defender.team] += 1
	Sfx.play("whistle_short")
	Events.toast.emit(Loc.t("match.foul.toast") % defender.jersey_num)
	Events.rule.emit("foul")
	possession = victim.team
	if defender.is_user:
		stat_add("pf", 1)
	# Every foul sends the fouled man to the line: 2 shots, or 3 when the
	# contact came on a three-point attempt.
	var shots := 3 if pts_attempt >= 3 else 2
	_start_free_throws(victim, shots)''',
'''func call_foul(defender: BallPlayer, victim: BallPlayer, pts_attempt := 0) -> void:
	team_fouls[defender.team] += 1
	Sfx.play("whistle_short")
	Events.toast.emit(Loc.t("match.foul.toast") % defender.jersey_num)
	Events.rule.emit("foul")
	possession = victim.team
	if defender.is_user:
		stat_add("pf", 1)
	# REGOLAMENTO: prima del 5o fallo di squadra un fallo NON sul tiro si
	# riprende con una rimessa, non con i tiri liberi. Dal 5o in poi (bonus)
	# ogni fallo vale 2 tiri; un fallo sul tiro vale sempre 2 o 3 tiri.
	var bonus: bool = team_fouls[defender.team] >= 5
	if pts_attempt <= 0 and not bonus:
		Events.toast.emit(Loc.t("t.foul.inbound"))
		_possession_restart(victim.team, "Foul")
		return
	if pts_attempt <= 0:
		Events.toast.emit(Loc.t("t.foul.bonus"))
	var shots := 3 if pts_attempt >= 3 else 2
	_start_free_throws(victim, shots)''',
    "foul: throw-in before the bonus")

edit("src/match/Court.gd",
'''	timeouts_left[team] -= 1
	timeout_team = team
	timeout_active = 4.0
	play_live = false''',
'''	timeouts_left[team] -= 1
	timeout_team = team
	timeout_active = 4.0
	play_live = false
	# UN TIMEOUT E' UN RESPIRO: le gambe tornano. 4 secondi di pausa valgono
	# energie, altrimenti il pulsante era solo una pausa senza senso.
	for q in players:
		if q.team == team:
			q.stamina = minf(100.0, q.stamina + 22.0)
	Events.toast.emit(Loc.t("t.timeout.breather"))''',
    "timeout breather")

edit("src/match/Court.gd",
'''	total_makes += 1
	_add_score(shooter, pts)''',
'''	total_makes += 1
	_add_score(shooter, pts)
	bench_cheer[shooter.team] = 3.0        # la sua panchina si alza''',
    "bench cheer on a basket")

edit("src/match/Court.gd",
'''## Where the pivot lives: right at the back of his own side area, so the''',
'''## Where the pivot should stand to TAKE a hand-off: next to his team-mate, on
## the side away from the nearest defender, and always INSIDE the side area
## (a delivery from outside the area is not legal ball to a pivot).
func handoff_spot(piv: BallPlayer, holder: BallPlayer) -> Vector2:
	var h: Vector2 = side_hoops[piv.team]
	var inward: Vector2 = (h - pivot_home(piv.team)).normalized()
	var side: Vector2 = Vector2(-inward.y, inward.x)
	# Which side of the holder is free? The one with the defender farther away.
	var best := side
	var best_d := -1.0
	for sgn in [1.0, -1.0]:
		var cand: Vector2 = holder.global_position + side * sgn * 42.0
		var near := 9999.0
		for d in players:
			if d.team != piv.team:
				near = minf(near, d.global_position.distance_to(cand))
		if near > best_d:
			best_d = near
			best = side * sgn
	var spot: Vector2 = holder.global_position + best * 42.0
	# never outside his own area (the delivery would be illegal there)
	var out: Vector2 = spot - h
	if out.length() > SIDE_AREA_R - 26.0:
		spot = h + out.normalized() * (SIDE_AREA_R - 26.0)
	return spot

## Where the pivot lives: right at the back of his own side area, so the''',
    "handoff spot helper")

edit("src/match/Court.gd",
'''				if not user_on_court and not user.leaving:
					bench_seats_vis.append({"pos": seat_world(0, i), "col": col,
						"kind": "user", "jersey": user.jersey_num, "seed": i * 3})''',
'''				if not user_on_court and not user.leaving:
					bench_seats_vis.append({"pos": seat_world(0, i), "col": col,
						"kind": "user", "jersey": user.jersey_num, "seed": i * 3,
						"team": 0})''',
    "bench seat team 1")

edit("src/match/Court.gd",
'''			bench_seats_vis.append({"pos": seat_world(t, i), "col": col,
				"kind": "player", "jersey": int(r["jersey"]), "seed": i * 3 + t})''',
'''			bench_seats_vis.append({"pos": seat_world(t, i), "col": col,
				"kind": "player", "jersey": int(r["jersey"]), "seed": i * 3 + t,
				"team": t})''',
    "bench seat team 2")

edit("src/match/Court.gd",
'''		bench_seats_vis.append({"pos": coach_world(t), "col": col, "kind": "coach",
			"seed": t * 5 + 1})''',
'''		bench_seats_vis.append({"pos": coach_world(t), "col": col, "kind": "coach",
			"seed": t * 5 + 1, "team": t})''',
    "bench seat team 3")

# ------------------------------------------------------------- AIBrain.gd ----
edit("src/match/AIBrain.gd",
'''	think_t -= delta
	shot_cd = maxf(0.0, shot_cd - delta)''',
'''	# CONSEGNA: se un mio compagno ha la palla DENTRO la mia area laterale, io
	# pivot gli vengo incontro per riceverla (la palla al pivot si consegna
	# solo da dentro l'area, quindi starsene fermi sulla mia mattonella non
	# serviva a niente). Se ha la palla un avversario, non c'e' niente da fare.
	if p.role <= 2 and not court.one_on_one:
		var hb: BallPlayer = court.ball_handler()
		if hb != null and hb.team == p.team and hb != p \\
		and court.in_side_area(hb.global_position) and court.in_side_area(p.global_position):
			var spot: Vector2 = court.handoff_spot(p, hb)
			var dv: Vector2 = spot - p.global_position
			p.move_input = dv.normalized() if dv.length() > 10.0 else Vector2.ZERO
			p.stance = dv.length() < 70.0
			if absf(hb.global_position.x - p.global_position.x) > 6.0:
				p.facing = signf(hb.global_position.x - p.global_position.x)
			return
	think_t -= delta
	shot_cd = maxf(0.0, shot_cd - delta)''',
    "pivot comes to the hand-off")

# ------------------------------------------------------------ MatchScene.gd ---
edit("src/match/MatchScene.gd",
'''			Loc.t("match.shotclk") % "%02d" % int(ceil(court.shot_clock)), rinfo]
			+ "   ·   " + Loc.t("match.fouls") % [court.team_fouls[0], court.team_fouls[1]])''',
'''			Loc.t("match.shotclk") % "%02d" % int(ceil(court.shot_clock)), rinfo]
			+ "   ·   " + Loc.t("match.fouls") % [court.team_fouls[0], court.team_fouls[1]])
	# Gli ultimi 5 secondi del cronometro si VEDONO (rosso) e si SENTONO (un
	# beep per secondo): prima scadevano in silenzio mentre guardavi la palla.
	var sc_left: int = int(ceil(court.shot_clock))
	_flash_clock(sc_left, court.play_live and not court.ft_active)''',
    "clock countdown call")

edit("src/match/MatchScene.gd",
'''func _call_timeout() -> void:''',
'''var _clock_beep := -1
## Red clock + one beep per second under 5 s, and a clean white clock as soon as
## the possession changes (the clock jumps back up).
func _flash_clock(secs: int, running: bool) -> void:
	var urgent: bool = running and secs <= 5 and secs > 0
	lbl_clock.modulate = Color(1.0, 0.42, 0.36) if urgent else Color(1, 1, 1)
	if not urgent:
		_clock_beep = -1
		return
	if secs != _clock_beep:
		_clock_beep = secs
		Sfx.play("beep", -9.0)

func _call_timeout() -> void:''',
    "clock flash helper")

# ------------------------------------------------------------ CourtVisual.gd ---
edit("src/match/CourtVisual.gd",
'''		if kind == "coach":
			_npc_standing(sp2, Color(0.13, 0.15, 0.22), SKINS[seed_i], HAIRS[seed_i],
				1.0, lean, crowd_hype > 0.50)
		else:
			# seated ON the bench box, lifted by its height
			_npc_seated(sp2 + Vector2(0.0, -15.0), entry["col"], SKINS[seed_i],
				HAIRS[(seed_i + 2) % HAIRS.size()], 1.0, lean, crowd_hype > 0.75)''',
'''		var seat_team: int = int(entry.get("team", -1))
		var team_cheer: bool = seat_team >= 0 and seat_team < court.bench_cheer.size() \\
			and float(court.bench_cheer[seat_team]) > 0.0
		if kind == "coach":
			_npc_standing(sp2, Color(0.13, 0.15, 0.22), SKINS[seed_i], HAIRS[seed_i],
				1.0, lean, crowd_hype > 0.50 or team_cheer)
		else:
			# seated ON the bench box, lifted by its height. When their team
			# scores, the whole bench is UP on its feet: arms in the air and a
			# little hop, while the other bench stays seated.
			var hop: float = 0.0
			if team_cheer:
				hop = 7.0 * absf(sin(Time.get_ticks_msec() / 95.0))
			_npc_seated(sp2 + Vector2(0.0, -15.0 - hop), entry["col"], SKINS[seed_i],
				HAIRS[(seed_i + 2) % HAIRS.size()], 1.0, lean,
				crowd_hype > 0.75 or team_cheer)''',
    "bench erupts")

# ----------------------------------------------------------------- Ball.gd ----
edit("src/match/Ball.gd",
'''var _pa_hump := 16.0
var _pa_dist0 := 1.0''',
'''var _pa_hump := 16.0
var _pa_dist0 := 1.0
var _pa_hs := 55.0                # where the ball leaves the hand
var _pa_he := 49.0                # where it is taken in the hand''',
    "hand-off heights")

edit("src/match/Ball.gd",
'''	_pa_hump = clampf(8.0 + d.length() * 0.030, 8.0, 30.0)''',
'''	_pa_hump = clampf(8.0 + d.length() * 0.030, 8.0, 30.0)
	_pa_hs = 55.0
	_pa_he = 49.0
	if to_player is BallPlayer and to_player.role <= 2 and d.length() < 190.0:
		# CONSEGNA (hand-off): la palla passa di mano in mano, bassa e subito.
		_pa_hump = 5.0
		_pa_hs = 49.0
		_pa_he = 46.0''',
    "hand-off arc")

edit("src/match/Ball.gd",
'''		h = lerpf(55.0, 49.0, prog) + _pa_hump * sin(PI * prog)''',
'''		h = lerpf(_pa_hs, _pa_he, prog) + _pa_hump * sin(PI * prog)''',
    "hand-off height in flight")

# ---------------------------------------------------------------- Court.gd ----
edit("src/match/Court.gd",
'''	var speed: float = lerpf(500.0, 820.0, from.ratings["pass"] / 99.0)''',
'''	var speed: float = lerpf(500.0, 820.0, from.ratings["pass"] / 99.0)
	var gap: float = from.global_position.distance_to(to.global_position)
	# Da vicino, dentro l'area laterale, non e' un passaggio lanciato ma una
	# CONSEGNA: rapida, bassa, di mano in mano (Ball la disegna piu' bassa).
	if to.role <= 2 and gap < 190.0:
		speed = 430.0
		if from.is_user:
			Events.toast.emit(Loc.t("t.handoff"))''',
    "hand-off in do_pass")

print("BA_PATCH_O: %d edit applicate" % n)
