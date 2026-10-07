#!/usr/bin/env python3
"""BA_PATCH_N - batch 7: IA (difficolta', falli avversari, raddoppi sensati,
difensore che non si incolla al ferro) + realismo/regolamento (3 secondi in
area, 5 secondi marcato stretto, rete laterale davanti alla palla).

Idempotente, anchor verificati.
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

# ------------------------------------------------------------- GameData.gd ---
edit("src/core/GameData.gd",
'''		"money": 200,
		"rep": 5,''',
'''		"money": 200,
		"rep": 5,
		"difficulty": 1,         # 0 facile, 1 normale, 2 forte (Impostazioni)''',
    "difficulty in the profile")

# ------------------------------------------------------------------ Loc.gd ---
edit("src/core/Loc.gd",
'''	"t.change_ends":   ["CHANGE ENDS", "CAMBIO CAMPO"],''',
'''	"t.change_ends":   ["CHANGE ENDS", "CAMBIO CAMPO"],
	"settings.difficulty": ["DIFFICULTY", "DIFFICOLTÀ"],
	"settings.diff0":  ["Easy", "Facile"],
	"settings.diff1":  ["Normal", "Normale"],
	"settings.diff2":  ["Hard", "Forte"],
	"settings.diff.hint": ["Easy: sleepy opponents. Hard: they close out, double up and punish you.",
	                       "Facile: avversari distratti. Forte: chiudono, raddoppiano e ti puniscono."],
	"rule.v_3sec":     ["3 SECONDS · you may not camp in the key", "3 SECONDI · non si sosta nell'area"],
	"rule.v_5sec":     ["5 SECONDS · closely guarded", "5 SECONDI · marcato stretto"],
	"t.three_sec_warn": ["3 sec!", "3 secondi!"],
	"t.five_sec_warn":  ["5 sec -- move it!", "5 secondi -- falla girare!"],''',
    "settings + time-rule strings")

# --------------------------------------------------------- SettingsScene.gd ---
edit("src/scenes/SettingsScene.gd",
'''	_section(v, Loc.t("settings.controls"))''',
'''	_section(v, Loc.t("settings.difficulty"))
	_diff_row(v)
	var hint := Label.new()
	hint.text = Loc.t("settings.diff.hint")
	hint.add_theme_font_size_override("font_size", 18)
	hint.modulate = Color(1, 1, 1, 0.7)
	v.add_child(hint)

	_section(v, Loc.t("settings.controls"))''',
    "difficulty section")

edit("src/scenes/SettingsScene.gd",
'''func _lang_row(v: VBoxContainer) -> void:''',
'''## Three buttons, one setting: how hard the opponents really are. It is read by
## every AIBrain (skill, close-outs, steals, doubling) so it changes the match,
## not a label.
func _diff_row(v: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	for i in 3:
		var b := Button.new()
		b.text = Loc.t("settings.diff%d" % i)
		b.custom_minimum_size = Vector2(220, 62)
		b.add_theme_font_size_override("font_size", 22)
		b.set_meta("diff", i)
		b.pressed.connect(func():
			Settings.set_v("difficulty", i)
			Game.profile["difficulty"] = i
			Sfx.play("ui_tap", -6.0)
			_paint_diff(row))
		row.add_child(b)
	_paint_diff(row)

func _paint_diff(row: HBoxContainer) -> void:
	var cur: int = int(Settings.get_v("difficulty", 1))
	for b in row.get_children():
		if b is Button:
			var i: int = int(b.get_meta("diff"))
			var on: bool = i == cur
			b.modulate = Color(1.0, 0.85, 0.30) if on else Color(1, 1, 1, 0.72)
			b.text = ("%s  \\u2713" % Loc.t("settings.diff%d" % i)) if on else Loc.t("settings.diff%d" % i)

func _lang_row(v: VBoxContainer) -> void:''',
    "difficulty row")

# ---------------------------------------------------------------- AIBrain.gd ---
edit("src/match/AIBrain.gd",
'''var skill := 0.5               # 0..1: sale con rep e livello (carriera reale)''',
'''var skill := 0.5               # 0..1: sale con rep e livello (carriera reale)
## DIFFICOLTA' SCELTA DALL'UTENTE (Impostazioni). Questi moltiplicatori sono
## l'unica parte di skill che NON dipende dalla carriera: cosi' "Facile" e
## "Forte" cambiano davvero la partita (chiusure, rubi, raddoppi, falli) e non
## sono solo un'etichetta.
var diff := 1
var d_steal := 1.0
var d_commit := 1.0
var d_foul := 1.0
var d_help := 1.0
var d_noise := 0.12
var d_react := 0.0
var foul_cd := 0.0             # contact fouls: no whistle every second''',
    "difficulty knobs")

edit("src/match/AIBrain.gd",
'''	skill = clampf(0.30 + rep_v * 0.55 + float(Game.profile.get("level", 1)) * 0.012
		+ float(p.ratings.get("defense", 50)) / 400.0, 0.30, 0.96)''',
'''	skill = clampf(0.30 + rep_v * 0.55 + float(Game.profile.get("level", 1)) * 0.012
		+ float(p.ratings.get("defense", 50)) / 400.0, 0.30, 0.96)
	diff = int(Settings.get_v("difficulty", Game.profile.get("difficulty", 1)))
	match diff:
		0:
			skill = clampf(skill * 0.62 - 0.06, 0.16, 0.62)
			d_steal = 0.55
			d_commit = 0.75
			d_foul = 0.60
			d_help = 0.70
			d_noise = 0.45
			d_react = 0.07
		2:
			skill = clampf(skill * 0.45 + 0.55, 0.60, 0.99)
			d_steal = 1.35
			d_commit = 1.25
			d_foul = 1.15
			d_help = 1.10
			d_noise = 0.10
			d_react = -0.03''',
    "difficulty applied in setup")

edit("src/match/AIBrain.gd",
'''		think_t = lerpf(0.20, 0.10, clampf(float(p.ratings.get("defense", 50)) / 99.0, 0.0, 1.0))''',
'''		think_t = lerpf(0.20, 0.10, clampf(float(p.ratings.get("defense", 50)) / 99.0, 0.0, 1.0)) + d_react''',
    "reaction time")

edit("src/match/AIBrain.gd",
'''	if big5:
		gap = lerpf(58.0, 40.0, skill)
		if shooter_range < 330.0:
			gap -= 8.0''',
'''	if big5:
		gap = lerpf(58.0, 40.0, skill)
		if shooter_range < 330.0:
			gap -= 8.0
	# Facile sta un passo piu' larga, Forte un passo piu' addosso.
	gap += lerpf(9.0, -4.0, float(diff) / 2.0)''',
    "close-out by difficulty")

edit("src/match/AIBrain.gd",
'''	var steal_ch: float = (0.006 + aggression * 0.010) * lerpf(0.7, 1.5, skill)
	if big5:
		steal_ch *= 1.8      # hands on the ball against a role-5 drive
	if d0 < 46.0 and randf() < steal_ch:
		p.try_steal()''',
'''	var steal_ch: float = (0.006 + aggression * 0.010) * lerpf(0.7, 1.5, skill) * d_steal
	if big5:
		steal_ch *= 1.8      # hands on the ball against a role-5 drive
	if d0 < 46.0 and randf() < steal_ch:
		p.try_steal()
		return
	# CONTACT FOULS. A defender who keeps his hands on a man going at the rim
	# gets whistled: the opponent fouls YOU too, and you go to the line. Rate
	# small and spaced out (foul_cd) so a quarter is not a parade to the line,
	# and scaled by the difficulty the user picked.
	foul_cd = maxf(0.0, foul_cd - delta)
	if foul_cd <= 0.0 and d0 < 40.0 and not bh.hanging and not bh.jumping:
		var contact: bool = bh.velocity.length() > 160.0 or bh.shot_charge >= 0.0 \\
			or bh.dunking or bh.move_t > 0.0
		if contact and randf() < (0.05 + aggression * 0.06) * d_foul * delta:
			foul_cd = 7.0
			court.call_foul(p, bh)
			return''',
    "AI contact fouls")

edit("src/match/AIBrain.gd",
'''			var commit: float = lerpf(0.30, 0.78, clampf(float(p.ratings["defense"]) / 99.0 * (0.6 + skill * 0.6), 0.0, 1.0))''',
'''			var commit: float = clampf(lerpf(0.30, 0.78,
				clampf(float(p.ratings["defense"]) / 99.0 * (0.6 + skill * 0.6), 0.0, 1.0)) * d_commit, 0.0, 1.0)''',
    "block commit by difficulty")

edit("src/match/AIBrain.gd",
'''	var bh2: BallPlayer = court.ball_handler()
	if bh2 != null and bh2.role == 5 and bh2.team != p.team:
		var to_rim: float = bh2.global_position.distance_to(court.hoop_for(bh2.team))
		if to_rim < 300.0:
			var sag: Vector2 = court.hoop_for(bh2.team).lerp(bh2.global_position, 0.42)
			help = help.lerp(sag, clampf((300.0 - to_rim) / 300.0, 0.0, 0.62))''',
'''	var bh2: BallPlayer = court.ball_handler()
	if bh2 != null and bh2.team != p.team:
		# SENSIBLE HELP: only for a real threat at the rim (a big man, a driver,
		# a finish in progress) and only if my OWN man is near enough that
		# leaving him is not a gift. A helper who abandons a shooter 8 m out to
		# babysit the iron gives up open jumpers for nothing.
		var hoop2: Vector2 = court.hoop_for(bh2.team)
		var to_rim: float = bh2.global_position.distance_to(hoop2)
		var threat: bool = bh2.role >= 4 or bh2.dunking or bh2.hanging \\
			or bh2.velocity.length() > 170.0 or bh2.shot_charge >= 0.0
		var my_man_d: float = mark.global_position.distance_to(hoop2)
		var own_gate: float = clampf((430.0 - my_man_d) / 240.0, 0.0, 1.0)
		if threat and to_rim < 300.0 and own_gate > 0.0:
			var sag: Vector2 = hoop2.lerp(bh2.global_position, 0.42)
			var k: float = clampf((300.0 - to_rim) / 300.0, 0.0, 0.62) * own_gate * d_help
			help = help.lerp(sag, clampf(k, 0.0, 0.70))''',
    "sensible help")

edit("src/match/AIBrain.gd",
'''		var v: float = maxf(float(ev[k]) * randf_range(0.88, 1.12), 0.0)''',
'''		# La lettura e' piu' o meno precisa a seconda della difficolta': a
		# "Facile" il computer sbaglia le scelte, a "Forte" quasi mai.
		var v: float = maxf(float(ev[k]) * randf_range(1.0 - d_noise, 1.0 + d_noise), 0.0)''',
    "EV noise by difficulty")

# ----------------------------------------------------------------- Court.gd ---
edit("src/match/Court.gd",
'''var _ill_whistle_cd := 0.0          # "L" fouls: at most one every few seconds''',
'''var _ill_whistle_cd := 0.0          # "L" fouls: at most one every few seconds
## TIME INFRACTIONS (Regola 8 baskin): 3" in the key, 5" closely guarded.
var _key_time := {}                 # player id -> seconds spent in the key
var _key_warn_cd := 0.0
var _guard_clock := 0.0             # the handler, guarded and standing still
var _guard_warn_cd := 0.0''',
    "time-rule state")

edit("src/match/Court.gd",
'''	_baskin_clocks(delta)''',
'''	_baskin_clocks(delta)
	_time_infractions(delta)''',
    "time-rule tick")

edit("src/match/Court.gd",
'''func _violation(p: BallPlayer, key: String) -> void:''',
'''## 3 SECONDS and 5 SECONDS, the two time infractions baskin actually calls
## (Regola 8). The key rule only ever counts the ATTACKING side, only while the
## ball is in play and held (a shot in the air stops the count), and never for
## the pivots (roles 1-2 live in their side area, which is not the key).
func _time_infractions(delta: float) -> void:
	if one_on_one or finished or not play_live or restarting or ft_active:
		return
	var h := ball_handler()
	_key_warn_cd = maxf(0.0, _key_warn_cd - delta)
	_guard_warn_cd = maxf(0.0, _guard_warn_cd - delta)
	# --- 3 SECONDS in the key -------------------------------------------------
	var live_hold: bool = h != null
	for p in players:
		if p.role <= 2 or p.team != possession:
			continue
		var key_x: float = COURT_W * 0.5 - FIBA_KEY_LEN
		var hoop_x: float = signf(attack_hoop_for(p).x)
		var in_key: bool = live_hold and absf(p.global_position.x) > key_x \\
			and signf(p.global_position.x) == hoop_x \\
			and absf(p.global_position.y) < FIBA_PAINT_W * 0.5
		if not in_key:
			_key_time.erase(p.get_instance_id())
			continue
		var t: float = float(_key_time.get(p.get_instance_id(), 0.0)) + delta
		_key_time[p.get_instance_id()] = t
		if t > 2.0 and t < 3.0 and _key_warn_cd <= 0.0 and p.is_user:
			_key_warn_cd = 1.0
			Events.toast.emit(Loc.t("t.three_sec_warn"))
		if t >= 3.0:
			_key_time.clear()
			_violation(p, "v_3sec")
			return
	# --- 5 SECONDS, closely guarded ------------------------------------------
	if h != null and h.role > 2:
		var guarded := false
		for d in players:
			if d.team != h.team and d.global_position.distance_to(h.global_position) < 110.0:
				guarded = true
				break
		# The count is about a man who is not PLAYING: passing, shooting or
		# moving the ball on resets it (his own movement counts as playing).
		var stalled: bool = h.velocity.length() < 90.0 and h.move_t <= 0.0 \\
			and h.fake_t <= 0.0 and h.shot_charge < 0.0
		if guarded and stalled:
			_guard_clock += delta
			if _guard_clock > 4.0 and _guard_warn_cd <= 0.0 and h.is_user:
				_guard_warn_cd = 1.0
				Events.toast.emit(Loc.t("t.five_sec_warn"))
			if _guard_clock >= 5.0:
				_guard_clock = 0.0
				_violation(h, "v_5sec")
		else:
			_guard_clock = 0.0
	else:
		_guard_clock = 0.0

func _violation(p: BallPlayer, key: String) -> void:''',
    "time infractions")

# -------------------------------------------------------------- NetFront.gd ---
edit("src/match/NetFront.gd",
'''		_draw_side_basket(sp, si, 0.42 if near_body else 1.0)''',
'''		_draw_side_basket(sp, si, 0.42 if near_body else 1.0)
		# THE BALL GOES BEHIND THE SIDE NET TOO: while it drops through a side
		# basket, the front half of that mini net is painted over it, exactly
		# like the classic rims.
		if court != null and ball != null and _ball_dropping_through(ball, sp):
			var hh2: float = Court.COURT_H
			var fp: Vector2 = CourtStage.m_project(sp, hh2)
			var rr := Vector2(fp.x, fp.y - Court.SIDE_RIM_HEIGHT)
			HoopArt.draw_net_front(self, rr, 20.0, 7.0,
				vis.net_wobble[2 + si] if (vis != null and 2 + si < vis.net_wobble.size()) else 0.0,
				vis.t if vis != null else 0.0)''',
    "side net in front of the ball")

edit("src/match/NetFront.gd",
'''## A low side basket: pole, glass, ring and net, all at `alpha`.''',
'''## Is the ball on its way through this side basket? Same rule the classic rims
## use: it is near the ring, it is low, and it is coming down.
func _ball_dropping_through(b: Node, hoop: Vector2) -> bool:
	if b == null:
		return false
	var h: float = float(b.get("h"))
	var vh: float = float(b.get("vh"))
	if h > Court.SIDE_RIM_HEIGHT + 40.0 or h < 0.0 or vh > 20.0:
		return false
	return b.global_position.distance_to(hoop) < 84.0

## A low side basket: pole, glass, ring and net, all at `alpha`.''',
    "side net helper")

print("BA_PATCH_N: %d edit applicate" % n)
