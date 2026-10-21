#!/usr/bin/env python3
"""BA_PATCH_Q - batch 10 (v1.11.0).

1) BONUS nell'HUD: badge che dice quale squadra e' in bonus (5 falli di
   squadra) + avviso una volta sola quando ci si arriva.
2) FALLI IN ATTACCO (carica): chi va addosso a un difensore fermo che difende
   commette fallo in attacco -> palla agli avversari. Nessun fischio dentro
   l'arco sotto il canestro (regola del non-sfondamento) ne' nelle aree
   laterali del pivot.
3) TIRO: la palla va nella "tasca" del tiratore e SALE con il braccio (prima
   restava a palleggiare all'anca mentre il corpo era in posa di tiro), il
   follow-through parte dall'estensione piena e si distende (era invertito),
   la mano di appoggio accompagna la palla.
4) DIFESA e RIMBALZO: posizione difensiva piu' bassa con le braccia larghe e
   scivolamento laterale; rimbalzo preso a due mani sopra la testa.
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

# ===================================================== Loc.gd (testi bilingue)
edit("src/core/Loc.gd",
'''	"t.foul.bonus":    ["FOUL · bonus: 2 free throws", "FALLO · bonus: 2 tiri liberi"],''',
'''	"t.foul.bonus":    ["FOUL · bonus: 2 free throws", "FALLO · bonus: 2 tiri liberi"],
	"t.foul.charge":   ["OFFENSIVE FOUL · the ball goes the other way", "FALLO IN ATTACCO · palla agli avversari"],
	"t.bonus.team":    ["%s reached 5 team fouls · from now on free throws", "%s arrivata a 5 falli di squadra · da ora si tira dalla lunetta"],''',
    "loc foul texts")

edit("src/core/Loc.gd",
'''	"hud.pivotclk":      ["PIVOT %ds", "PIVOT %ds"],''',
'''	"hud.pivotclk":      ["PIVOT %ds", "PIVOT %ds"],
	"hud.bonus":         ["BONUS %s", "BONUS %s"],''',
    "loc hud bonus")

# ===================================================== MatchScene.gd (HUD)
edit("src/match/MatchScene.gd",
'''var lbl_shot: Label           # badge del cronometro dei 24 s (rosso sotto i 5)''',
'''var lbl_shot: Label           # badge del cronometro dei 24 s (rosso sotto i 5)
var lbl_bonus: Label          # badge "BONUS": quale squadra e' in bonus
var _bonus_seen := [false, false]''',
    "bonus state")

edit("src/match/MatchScene.gd",
'''	crow.add_child(lbl_shot)
	crow.move_child(lbl_shot, 0)''',
'''	crow.add_child(lbl_shot)
	crow.move_child(lbl_shot, 0)
	# BADGE DEL BONUS: dal 5o fallo di squadra ogni fallo vale 2 tiri liberi per
	# chi lo subisce. Il badge mostra la squadra IN BONUS (quella che tira) e
	# resta nascosto finche' nessuna ci arriva: niente rumore per niente.
	lbl_bonus = Label.new()
	lbl_bonus.text = ""
	lbl_bonus.add_theme_font_size_override("font_size", 22)
	lbl_bonus.add_theme_color_override("font_color", Color(0.965, 0.949, 0.906, 0.80))
	lbl_bonus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_bonus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_bonus.custom_minimum_size = Vector2(150, 0)
	lbl_bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_bonus.visible = false
	crow.add_child(lbl_bonus)
	crow.move_child(lbl_bonus, 1)''',
    "bonus label")

edit("src/match/MatchScene.gd",
'''	# Gli ultimi 5 secondi del cronometro si VEDONO (rosso) e si SENTONO (un
	# beep per secondo): prima scadevano in silenzio mentre guardavi la palla.''',
'''	_sync_bonus_badge()
	# Gli ultimi 5 secondi del cronometro si VEDONO (rosso) e si SENTONO (un
	# beep per secondo): prima scadevano in silenzio mentre guardavi la palla.''',
    "bonus sync call")

edit("src/match/MatchScene.gd",
'''func _flash_clock(secs: int, running: bool) -> void:''',
'''## Chi e' in bonus tira i liberi: il badge lo dice a chiare lettere, nel colore
## della squadra che VANTAGGIA (quella che subisce i falli). La prima volta che
## una squadra ci arriva lo dice anche a voce, perche' cambia le regole in campo.
func _sync_bonus_badge() -> void:
	if lbl_bonus == null or court == null:
		return
	var in_pen := [false, false]     # squadra che ha commesso il 5o fallo
	for t in 2:
		if court.team_fouls[t] >= 5:
			in_pen[t] = true
			if not _bonus_seen[t]:
				_bonus_seen[t] = true
				var who: String = _team_short(1 - t)   # chi tira i liberi
				Events.toast.emit(Loc.t("t.bonus.team") % who)
	# BONUS (t) = la squadra t e' in bonus, cioe' TIRA i liberi se subisce fallo.
	var valide: Array = []
	for t in 2:
		if in_pen[1 - t]:
			valide.append(t)
	if valide.is_empty():
		lbl_bonus.visible = false
		return
	var names := ""
	for t in valide:
		names += _team_short(t) if names == "" else "·" + _team_short(t)
	lbl_bonus.text = Loc.t("hud.bonus") % names
	var col: Color = Game.team_colour(int(valide[0]))
	if valide.size() == 2:
		col = Color(1.0, 0.78, 0.30)
	var pulse: float = 0.80 + 0.20 * absf(sin(Time.get_ticks_msec() / 420.0))
	lbl_bonus.modulate = Color(col.r, col.g, col.b, 0.62 + 0.38 * pulse)
	lbl_bonus.visible = true

func _team_short(team: int) -> String:
	var club: String = Game.club_my_team() if team == 0 \\
		else String(Game.profile.get("next_opponent", "Practice Squad"))
	return Game.club_short(club)

func _flash_clock(secs: int, running: bool) -> void:''',
    "bonus badge logic")

# ===================================================== Court.gd (fallo in attacco)
edit("src/match/Court.gd",
'''func _turnover_to(team: int) -> void:''',
'''## FALLO IN ATTACCO (carica). Regola: chi attacca non puo' andare addosso a un
## difensore che ha gia' preso posizione. Serve un contatto FRONTALE, con
## l'attaccante lanciato e il difensore fermo in posizione di difesa: cosi' non
## fischia mai su un semplice avvicinamento. Fuori dall'arco sotto il canestro
## (non-sfondamento) e fuori dalle aree laterali del pivot.
var _charge_cd := 0.0

func _charge_check(delta: float) -> void:
	_charge_cd = maxf(0.0, _charge_cd - delta)
	if _charge_cd > 0.0 or ft_active or inbound_wait > 0.0:
		return
	var h: BallPlayer = ball_handler()
	if h == null or not h.has_ball or h.jumping or h.dunking or h.hanging:
		return
	# Chi sta tirando, palleggiando in un move o appena arrivato non carica.
	if h.shot_charge >= 0.0 or h.ai_windup_t >= 0.0 or h.move_t > 0.0 or h.stun > 0.0:
		return
	var spd: float = h.velocity.length()
	if spd < 195.0:
		return
	if in_side_area(h.global_position) or in_side_area(h.global_position):
		return
	var run: Vector2 = h.velocity / spd
	var rim: Vector2 = attack_hoop_for(h)
	for d in get_tree().get_nodes_in_group("team_%d" % (1 - h.team)):
		var dv: BallPlayer = d
		var to: Vector2 = dv.global_position - h.global_position
		var dist: float = to.length()
		if dist > 34.0 or dist < 1.0:
			continue
		if to.normalized().dot(run) < 0.55:
			continue                      # non e' sulla traiettoria
		if dv.velocity.length() > 85.0:
			continue                      # si sta muovendo: non ha posizione
		if not dv.stance:
			continue                      # non sta difendendo: niente carica
		if not one_on_one and dv.global_position.distance_to(rim) < FIBA_RESTRICTED:
			continue                      # arco di non-sfondamento
		_charge_cd = 2.0
		call_charge(h, dv)
		return

## Fallo in attacco: conta come fallo personale e di squadra, ma la punizione e'
## il possesso agli avversari (niente tiri liberi: si punisce l'attacco).
func call_charge(offender: BallPlayer, defender: BallPlayer) -> void:
	team_fouls[offender.team] += 1
	Sfx.play("whistle_short")
	Events.rule.emit("foul")
	Events.toast.emit(Loc.t("t.foul.charge"))
	Events.popup.emit("FALLO IN ATTACCO", offender.global_position, Color(1.0, 0.55, 0.25), false)
	if offender.is_user:
		stat_add("pf", 1)
		stat_add("tov", 1)
		Events.shake.emit(0.35)
	possession = defender.team
	_turnover_to(defender.team)

func _turnover_to(team: int) -> void:''',
    "charge foul")

edit("src/match/Court.gd",
'''	_baskin_clocks(delta)
	_time_infractions(delta)''',
'''	_baskin_clocks(delta)
	_time_infractions(delta)
	_charge_check(delta)''',
    "charge in loop")

# ===================================================== Player.gd (palla del tiro)
edit("src/match/Player.gd",
'''	if not (dunking and not hanging):
		return {"active": false}''',
'''	# TIRO: la palla sta nella "tasca" del tiratore e sale con il braccio fino
	# al rilascio. Prima restava a palleggiare all'anca mentre il corpo era in
	# posa di tiro: era il difetto che faceva sembrare finto ogni tiro.
	if not (dunking and not hanging):
		var q: float = gather_progress()
		if has_ball and (shot_charge >= 0.0 or ai_windup_t >= 0.0 or fake_t > 0.0):
			var hb0: float = _body_h()
			var hs0: float = 1.0 if (hand_side if absf(hand_side) > 0.1 else 1.0) >= 0.0 else -1.0
			var qq: float = clampf(q, 0.0, 1.0)
			if fake_t > 0.0:
				qq = 0.62           # la finta: palla su, pronta, ma non si stacca
			var crouch0: float = (1.0 - qq) * hb0 * 0.11
			var lift0: float = qq * hb0 * 0.13
			var sh_y0: float = -lift0 - hb0 * 0.80 + crouch0 * 0.6
			var hand_y: float = sh_y0 + hb0 * 0.04 - hb0 * 0.42 * qq
			return {"active": true, "x": hs0 * hb0 * 0.20, "h": air - hand_y}
		return {"active": false}''',
    "shot ball carry")

# follow-through: parte dall'estensione piena e si distende
edit("src/match/Player.gd",
'''	elif shot_anim > 0.0:
		# Follow-through: a short rise, the arm extending up, then settling --
		# the same release animation as the solo court's shot-around.
		var f: float = 1.0 - clampf(shot_anim / 0.26, 0.0, 1.0)
		kind = Avatar.SHOOT
		amount = 0.25 + f * 0.75
		air_draw += sin(f * PI) * h * 0.30''',
'''	elif shot_anim > 0.0:
		# FOLLOW-THROUGH: il braccio e' gia' ESTESO quando la palla parte, poi
		# si distende e ricade. Prima era al contrario (si abbassava subito e
		# risaliva: il tiro sembrava un saluto). Lo stacco si vede salire e
		# scendere, e a terra ci si arriva prima dell'ultimo frame.
		var f: float = 1.0 - clampf(shot_anim / FOLLOW_U, 0.0, 1.0)
		kind = Avatar.SHOOT
		amount = lerpf(1.0, 0.42, smoothstep(0.0, 1.0, f))
		air_draw += h * 0.30 * sin(clampf(f / 0.62, 0.0, 1.0) * PI)''',
    "follow through")

edit("src/match/Player.gd",
'''const MOVE_DUR''',
'''const FOLLOW_U := 0.34              # durata del follow-through del tiro
const MOVE_DUR''',
    "follow const")

edit("src/match/Player.gd",
'''	shot_anim = 0.26''',
'''	shot_anim = FOLLOW_U''',
    "shot_anim ft")

edit("src/match/Player.gd",
'''		shot_charge = -1.0
		shot_anim = 0.26
		return''',
'''		shot_charge = -1.0
		shot_anim = FOLLOW_U
		return''',
    "ft follow")

# ===================================================== Avatar.gd (pose)
edit("src/ui/Avatar.gd",
'''		DEFEND:
			crouch = h * 0.03
			arm_up = 0.22
			lean = 0.0''',
'''		DEFEND:
			# POSIZIONE DIFENSIVA: baricentro basso, gambe larghe, braccia
			# aperte. In scivolata il corpo pende dalla parte del movimento
			# (si spinge col piede opposto), da fermo sta centrato.
			crouch = h * (0.075 if walking else 0.055)
			arm_up = 0.0
			arms_out = 0.62 if walking else 0.5
			wide = 1.0
			lean = float(p.get("slide", 0.0)) * h * 0.045''',
    "defend pose")

edit("src/ui/Avatar.gd",
'''		SHOOT:
			# amount 0..1: 0 = gathered low, 1 = full extension on release
			crouch = (1.0 - amt) * h * 0.11
			lift = amt * h * 0.13
			arm_up = amt''',
'''		SHOOT:
			# amount 0..1: 0 = gathered low, 1 = full extension on release.
			# Il rilascio e' sopra la testa e la mano di appoggio accompagna
			# la palla fin quasi al rilascio, poi si stacca.
			crouch = (1.0 - amt) * h * 0.13
			lift = amt * h * 0.13
			arm_up = amt
			if amt > 0.02:
				off_hand = clampf(1.0 - smoothstep(0.72, 0.95, amt), 0.0, 1.0)''',
    "shoot pose")

edit("src/ui/Avatar.gd",
'''		REACH:
			arm_up = 1.0
			lift = amt * h * 0.5''',
'''		REACH:
			# RIMBALZO: due mani in alto, aperte, per prendere la palla al
			# punto piu' alto (una sola mano sembrava un saluto).
			arm_up = 1.0
			both_up = bool(p.get("rebound", false))
			lift = amt * h * 0.5''',
    "reach pose")

edit("src/ui/Avatar.gd",
'''	var arm_up := 0.0        # 0 = down, 1 = fully extended overhead
	var lean := 0.0''',
'''	var arm_up := 0.0        # 0 = down, 1 = fully extended overhead
	var arms_out := 0.0      # braccia aperte di lato (posizione difensiva)
	var wide := 0.0          # stance larga (gambe divaricate)
	var off_hand := 0.0      # quanto la mano debole accompagna la palla
	var both_up := false     # tutte e due le mani in alto (rimbalzo)
	var lean := 0.0''',
    "pose vars")

# le gambe si allargano con `wide`
edit("src/ui/Avatar.gd",
'''		var hipp := Vector2(base.x + sx * hip_w * 0.55 + lean, hip_y)''',
'''		var hipp := Vector2(base.x + sx * hip_w * (0.55 + 0.55 * wide) + lean, hip_y)''',
    "wide legs")

edit("src/ui/Avatar.gd",
'''		var knee := Vector2(hipp.x + sx * hip_w * 0.22 + gait * h * 0.10 * facing,''',
'''		var knee := Vector2(hipp.x + sx * hip_w * (0.22 + 0.42 * wide) + gait * h * 0.10 * facing,''',
    "wide knees")

# braccia: aperte in difesa, mano debole che accompagna la palla
edit("src/ui/Avatar.gd",
'''		var up: float = arm_up if strong else arm_up * 0.75''',
'''		var up: float = arm_up if (strong or both_up) else arm_up * 0.75
		if not strong and off_hand > 0.01:
			var brh: float = h * 0.105 if ball_r < 0.0 else ball_r
			var off: Vector2 = p.get("ball_off", Vector2.ZERO)
			var bxy: Vector2 = ball_pos if has_ball_pos else Vector2(base.x, floor_y - h * 0.7)
			hand = Vector2(bxy.x - sdir * brh * 1.5, bxy.y + brh * 0.4 * off_hand)
			elbow = Vector2(lerpf(sh_p.x, hand.x, 0.45), lerpf(sh_p.y, hand.y, 0.42) + h * 0.02)
			c.draw_line(sh_p, elbow, skin, lw * 0.85)
			c.draw_line(elbow, hand, skin, lw * 0.78)
			continue''',
    "off hand on ball")

# le braccia possono essere APERTE (difesa) invece che su o giu'
edit("src/ui/Avatar.gd",
'''		elif up > 0.01:''',
'''		elif arms_out > 0.01 and strong:
			# POSIZIONE DIFENSIVA: braccio di lato, palmo aperto verso
			# l'attaccante, gomito morbido.
			hand = Vector2(base.x + sx * h * (0.26 + 0.10 * arms_out) + lean,
				sh_y + h * (0.22 - 0.16 * arms_out))
			elbow = Vector2(lerpf(sh_p.x, hand.x, 0.42), lerpf(sh_p.y, hand.y, 0.40) - h * 0.04)
		elif up > 0.01:''',
    "wide arms branch")

edit("src/ui/Avatar.gd",
'''		elif up > 0.01:
			elbow = Vector2(sh_p.x + sx * h * 0.10, sh_y - h * 0.10 * up + h * 0.10 * (1.0 - up))
			hand = Vector2(sh_p.x + sx * h * 0.06, sh_y - h * 0.42 * up)''',
'''		elif up > 0.01:
			elbow = Vector2(sh_p.x + sx * h * 0.10, sh_y - h * 0.10 * up + h * 0.10 * (1.0 - up))
			hand = Vector2(sh_p.x + sx * h * 0.06, sh_y - h * 0.44 * up)''',
    "higher release")

print("BA_PATCH_Q: %d edit applicate" % n)
