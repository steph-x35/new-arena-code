#!/usr/bin/env python3
# Batch 14 (v1.15.0). SOSTITUZIONI DAL VIVO.
#   - Court: richieste di cambio (utente o allenatore IA), esecuzione alla prima
#     palla morta, giocatore che entra con lo STESSO ruolo e la stessa fisionomia
#     (formazione regolamentare: due donne, un pivot), uscita/in entrata a piedi.
#   - MatchScene: tasto CAMBIO + pannello IN CAMPO / PANCHINA.
#   - Loc: stringhe del pannello e degli avvisi.
import io
import sys

ROOT = "/home/user/baskin_academy/"
edits = []


def edit(path, old, new, count=1):
    edits.append((path, old, new, count))


# ----------------------------------------------------------------- Loc.gd
edit("src/core/Loc.gd",
     '''	"t.rebound":       ["Rebound #%d", "Rimbalzo #%d"],''',
     '''	"t.rebound":       ["Rebound #%d", "Rimbalzo #%d"],
	"t.sub.req":       ["Sub: #%d off, #%d on — at the next dead ball",
		"Cambio: fuori #%d, dentro #%d — alla prossima palla morta"],
	"t.sub.done":      ["SUB: #%d in for #%d", "CAMBIO: entra #%d per #%d"],
	"t.sub.self":      ["Sub for YOU: the coach will call you back",
		"Cambio per te: l'allenatore ti richiama in campo"],
	"t.sub.none":      ["Nobody to sub right now", "Nessun cambio disponibile adesso"],''')

# ---------------------------------------------------------- MatchScene.gd
edit("src/match/MatchScene.gd",
     '''	# Bench overlay: shown while the coach has you on the pine.''',
     '''	# SOSTITUZIONI DAL VIVO: il tasto apre la panchina (solo 5v5).
	btn_sub = Button.new()
	btn_sub.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_sub.position = Vector2(-206, 70)
	btn_sub.custom_minimum_size = Vector2(188, 46)
	btn_sub.add_theme_font_size_override("font_size", 17)
	btn_sub.text = Loc.t("match.sub")
	btn_sub.pressed.connect(_open_subs)
	hud.add_child(btn_sub)

	# Bench overlay: shown while the coach has you on the pine.''')

edit("src/match/MatchScene.gd",
     '''	if btn_timeout:
		btn_timeout.visible = not court.one_on_one and not court.finished''',
     '''	if btn_sub:
		btn_sub.visible = not court.one_on_one and not court.finished \\
			and not court.ft_active and sub_panel != null and not sub_panel.visible
	if btn_timeout:
		btn_timeout.visible = not court.one_on_one and not court.finished''')

edit("src/match/MatchScene.gd",
     '''var rules_btn: Button''',
     '''var rules_btn: Button
var btn_sub: Button                  # il tasto CAMBIO (sostituzioni dal vivo)
var sub_panel: PanelContainer        # pannello IN CAMPO / PANCHINA
var sub_court_box: VBoxContainer     # chi e' in campo (si ricostruisce all'apertura)
var sub_bench_box: VBoxContainer     # chi e' in panchina
var sub_hint: Label
var _sub_pick: BallPlayer = null     # chi hai scelto di togliere''')

edit("src/match/MatchScene.gd",
     '''func _guard_down() -> void:''',
     '''## ---------------------------------------------------- sostituzioni dal vivo
## Il pannello dei cambi: a sinistra chi e' in campo, a destra chi aspetta in
## panchina. Scegli chi esce, poi chi entra: il cambio si esegue alla prima
## palla morta, con i due che si incrociano a piedi.
func _open_subs() -> void:
	if court == null or court.finished:
		return
	if court.available_sub_seats().is_empty() and _sub_pick == null:
		Events.toast.emit(Loc.t("t.sub.none"))
		return
	_sub_pick = null
	_fill_subs()
	sub_panel.visible = true

func _fill_subs() -> void:
	for b in sub_court_box.get_children():
		b.queue_free()
	for b in sub_bench_box.get_children():
		b.queue_free()
	if court == null:
		return
	for p in court.players:
		if p.team != 0:
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(250, 46)
		b.add_theme_font_size_override("font_size", 16)
		b.text = "R%d  #%d  %s   %d%%" % [p.role, p.jersey_num,
			p.display_name, int(round(p.stamina))]
		if p.is_user:
			b.text += "  (you)"
		var who: BallPlayer = p
		b.pressed.connect(func():
			_sub_pick = who
			sub_hint.text = Loc.t("match.sub.hint2") % who.jersey_num)
		sub_court_box.add_child(b)
	var seats: Array = court.available_sub_seats()
	if seats.is_empty():
		var l := Label.new()
		l.text = Loc.t("t.sub.none")
		l.add_theme_font_size_override("font_size", 15)
		sub_bench_box.add_child(l)
	for seat in seats:
		var r: Dictionary = court.bench_roster[0][seat]
		var b := Button.new()
		b.custom_minimum_size = Vector2(210, 46)
		b.add_theme_font_size_override("font_size", 16)
		b.text = "#%d  %s" % [int(r["jersey"]), String(r["name"])]
		var sd: int = int(seat)
		b.pressed.connect(func():
			if _sub_pick == null:
				sub_hint.text = Loc.t("match.sub.pick")
				return
			if court.request_sub(_sub_pick, sd):
				sub_panel.visible = false
			else:
				sub_hint.text = Loc.t("t.sub.none"))
		sub_bench_box.add_child(b)
	sub_hint.text = Loc.t("match.sub.hint")

func _guard_down() -> void:''')

edit("src/match/MatchScene.gd",
     '''	sub_panel.visible = false
	hud.add_child(bench_panel)''',
     '''	sub_panel.visible = false
	hud.add_child(bench_panel)

	# SOSTITUZIONI: pannello con le due liste (in campo / panchina).
	sub_panel = PanelContainer.new()
	sub_panel.set_anchors_preset(Control.PRESET_CENTER)
	sub_panel.offset_left = -430
	sub_panel.offset_right = 430
	sub_panel.offset_top = -230
	sub_panel.offset_bottom = 230
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.06, 0.07, 0.10, 0.95)
	ss.set_corner_radius_all(16)
	ss.set_border_width_all(2)
	ss.border_color = Color(0.949, 0.420, 0.114, 0.55)
	ss.content_margin_left = 18; ss.content_margin_right = 18
	ss.content_margin_top = 12; ss.content_margin_bottom = 12
	sub_panel.add_theme_stylebox_override("panel", ss)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	sub_panel.add_child(sv)
	var st := Label.new()
	st.text = Loc.t("match.sub.title")
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.add_theme_font_size_override("font_size", 24)
	sv.add_child(st)
	sub_hint = Label.new()
	sub_hint.text = Loc.t("match.sub.hint")
	sub_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_hint.add_theme_font_size_override("font_size", 15)
	sub_hint.modulate = Color(1, 1, 1, 0.78)
	sv.add_child(sub_hint)
	var sh := HBoxContainer.new()
	sh.alignment = BoxContainer.ALIGNMENT_CENTER
	sh.add_theme_constant_override("separation", 26)
	sv.add_child(sh)
	var col_a := VBoxContainer.new()
	col_a.add_theme_constant_override("separation", 6)
	sh.add_child(col_a)
	var la := Label.new()
	la.text = Loc.t("match.sub.oncourt")
	la.add_theme_font_size_override("font_size", 17)
	col_a.add_child(la)
	sub_court_box = VBoxContainer.new()
	sub_court_box.add_theme_constant_override("separation", 6)
	col_a.add_child(sub_court_box)
	var col_b := VBoxContainer.new()
	col_b.add_theme_constant_override("separation", 6)
	sh.add_child(col_b)
	var lb := Label.new()
	lb.text = Loc.t("match.sub.bench")
	lb.add_theme_font_size_override("font_size", 17)
	col_b.add_child(lb)
	sub_bench_box = VBoxContainer.new()
	sub_bench_box.add_theme_constant_override("separation", 6)
	col_b.add_child(sub_bench_box)
	var scl := Button.new()
	scl.text = Loc.t("match.sub.close")
	scl.custom_minimum_size = Vector2(0, 48)
	scl.pressed.connect(func(): sub_panel.visible = false)
	sv.add_child(scl)
	sub_panel.visible = false
	hud.add_child(sub_panel)''')

# ------------------------------------------------------------------ Loc: extra
edit("src/core/Loc.gd",
     '''	"t.sub.none":      ["Nobody to sub right now", "Nessun cambio disponibile adesso"],''',
     '''	"t.sub.none":      ["Nobody to sub right now", "Nessun cambio disponibile adesso"],
	"match.sub":           ["SUBS", "CAMBIO"],
	"match.sub.title":     ["SUBSTITUTIONS", "SOSTITUZIONI"],
	"match.sub.hint":      ["Pick who comes OFF on the left, then who goes IN on the right. The swap happens at the next dead ball.",
		"Scegli chi ESCE a sinistra, poi chi ENTRA a destra. Il cambio avviene alla prima palla morta."],
	"match.sub.hint2":     ["#%d selected: now pick who goes in", "#%d scelto: ora scegli chi entra"],
	"match.sub.pick":      ["First pick who comes off (left)", "Prima scegli chi esce (a sinistra)"],
	"match.sub.oncourt":   ["ON COURT", "IN CAMPO"],
	"match.sub.bench":     ["BENCH", "PANCHINA"],
	"match.sub.close":     ["CLOSE", "CHIUDI"],''')

# ---------------------------------------------------------------- Court.gd
edit("src/match/Court.gd",
     '''var bench_cheer := [0.0, 0.0]''',
     '''var bench_cheer := [0.0, 0.0]
# --- sostituzioni dal vivo (v1.15) -----------------------------------------
var sub_pending := []               # richieste di cambio in attesa di palla morta
var _sub_walk := []                 # [uscito, entrato, posto] che stanno camminando
var sub_seat_cd := {}               # cooldown per posto in panchina
const SUB_GAP := 22.0               # secondi prima di riusare lo stesso posto''')

edit("src/match/Court.gd",
     '''## Sub the USER off: he walks to the bench while his reserve walks on.''',
     '''## ------------------------------------------------- sostituzioni dal vivo
## Posti di panchina utilizzabili adesso (il posto dell'utente e quello del suo
## cambio automatico restano fuori, e un posto appena usato ha un cooldown).
func available_sub_seats() -> Array:
	var out := []
	var busy := {}
	for w in _sub_walk:
		busy[int(w[2])] = true
	for i in 5:
		if i == USER_SEAT:
			continue
		if i == PARTNER_SEAT and sub_partner != null and is_instance_valid(sub_partner):
			continue
		if busy.has(i) or float(sub_seat_cd.get(i, 0.0)) > 0.0:
			continue
		out.append(i)
	return out

## Chiede un cambio. Per un compagno (o un avversario, se lo chiede il suo
## allenatore) il cambio si esegue alla prima PALLA MORTA. Per l'utente passa
## dal percorso gia' esistente (l'allenatore lo richiama).
func request_sub(p: BallPlayer, seat: int, by_user := true) -> bool:
	if not is_fixture or finished or p == null or seat < 0 or seat >= 5:
		return false
	if p == user:
		if not user_on_court:
			return false
		bench_user()
		Events.toast.emit(Loc.t("t.sub.self"))
		return true
	if not players.has(p) or p.role <= 0:
		return false
	if seat == USER_SEAT:
		return false
	# un solo cambio in coda per posto e per squadra
	for r in sub_pending:
		if int(r["seat"]) == seat:
			return false
		if r["out"] != null and is_instance_valid(r["out"]) and r["out"].team == p.team:
			return false
	if float(sub_seat_cd.get(seat, 0.0)) > 0.0:
		return false
	sub_pending.append({"out": p, "seat": seat, "team": p.team})
	if by_user:
		Events.toast.emit(Loc.t("t.sub.req") % [p.jersey_num,
			int(bench_roster[0][seat]["jersey"]) if p.team == 0
			else int(bench_roster[1][seat]["jersey"])])
	return true

## Il cambio vero e proprio: chi esce cammina verso il suo posto, chi entra
## arriva dalla panchina con lo STESSO RUOLO e la STESSA fisionomia (la
## formazione deve restare regolamentare: due donne in campo, un solo pivot).
func _start_sub(out_p: BallPlayer, seat: int) -> void:
	var team: int = out_p.team
	var inn: BallPlayer = preload("res://src/match/Player.gd").new()
	inn.team = team
	add_child(inn)
	_randomize_npc(inn, team)
	inn.gender = out_p.gender
	inn.hair_style_v = out_p.hair_style_v
	inn.hair_col = out_p.hair_col
	inn.height_f = out_p.height_f
	inn.mass_f = out_p.mass_f
	inn.role = out_p.role
	inn.variant = out_p.variant
	_apply_role_kit(inn)
	var r: Dictionary = bench_roster[team][seat]
	inn.jersey_num = int(r["jersey"])
	inn.display_name = String(r["name"])
	inn.global_position = seat_world(team, seat)
	inn.entering = true
	inn.set_meta("wait_sub", true)
	inn.bench_target = _formation_pos(team, seat)
	out_p.leaving = true
	out_p.bench_target = seat_world(team, seat)
	if players.has(out_p):
		players.erase(out_p)          # e' fuori: non conta piu' in campo
	sub_seat_cd[seat] = SUB_GAP
	_sub_walk.append([out_p, inn, seat])
	_refresh_bench_vis()
	Events.toast.emit(Loc.t("t.sub.done") % [inn.jersey_num, out_p.jersey_num])
	if team == 0:
		Events.rule.emit("sub")

## Camminata dei cambi: chi esce va a sedersi, chi entra aspetta che l'altro sia
## arrivato e poi prende il suo posto in campo (con il cervello IA).
func _process_live_subs(delta: float) -> void:
	for k in sub_seat_cd.keys():
		sub_seat_cd[k] = maxf(0.0, float(sub_seat_cd[k]) - delta)
	# 1) richieste in coda: si eseguono a palla morta
	if not sub_pending.is_empty() and not ft_active and not finished:
		var dead: bool = (not play_live) or restarting or inbound_wait > 0.0 or awaiting_check
		if dead:
			var req: Dictionary = sub_pending[0]
			var op = req["out"]
			if op == null or not is_instance_valid(op) or not players.has(op) \\
			or op.entering or op.leaving or op.has_ball or op.jumping or op.hanging:
				sub_pending.pop_front()      # non piu' possibile: lascia perdere
			else:
				sub_pending.pop_front()
				_start_sub(op, int(req["seat"]))
	# 2) chi cammina
	for w in _sub_walk.duplicate():
		var o = w[0]
		var n = w[1]
		var done := true
		if n != null and is_instance_valid(n):
			if n.entering and n.has_meta("wait_sub"):
				done = false
				if o == null or not is_instance_valid(o) or not o.leaving:
					n.remove_meta("wait_sub")
			if n.entering or n.leaving:
				done = false
				var dn: Vector2 = n.bench_target - n.global_position
				if dn.length() > 24.0:
					n.global_position += dn.normalized() * minf(330.0 * delta, dn.length())
					n.velocity = dn.normalized() * 300.0
					if absf(dn.x) > 4.0:
						n.facing = signf(dn.x)
				else:
					n.velocity = Vector2.ZERO
					n.entering = false
					if not players.has(n):
						players.append(n)
					var brain := preload("res://src/match/AIBrain.gd").new()
					n.add_child(brain)
					brain.setup(n, self)
		if o != null and is_instance_valid(o):
			if o.leaving:
				done = false
				var do_: Vector2 = o.bench_target - o.global_position
				if do_.length() > 24.0:
					o.global_position += do_.normalized() * minf(330.0 * delta, do_.length())
					o.velocity = do_.normalized() * 300.0
					if absf(do_.x) > 4.0:
						o.facing = signf(do_.x)
					continue
				o.velocity = Vector2.ZERO
				o.leaving = false
				if players.has(o):
					players.erase(o)
				if o.has_ball and ball != null:
					ball.detach()
					ball.live = true
					o.has_ball = false
				o.queue_free()
		if done:
			_sub_walk.erase(w)

## L'allenatore cambia chi non ha piu' gambe (vale per entrambe le squadre: si
## vede anche nella partita IA).
func _coach_subs() -> void:
	if one_on_one or finished or ft_active or not play_live:
		return
	for p in players.duplicate():
		if p == null or not is_instance_valid(p) or p.role <= 0 or p.is_user:
			continue
		if p.leaving or p.entering or p.has_ball or p.stamina > 18.0:
			continue
		var busy := false
		for r in sub_pending:
			if r["out"] != null and is_instance_valid(r["out"]) and r["out"].team == p.team:
				busy = true
		for w in _sub_walk:
			if w[0] != null and is_instance_valid(w[0]) and w[0].team == p.team:
				busy = true
		if busy:
			continue
		var seats: Array = available_sub_seats()
		if p.team > 0:
			seats = []
			for i in 5:
				if float(sub_seat_cd.get(i, 0.0)) <= 0.0:
					seats.append(i)
			for w in _sub_walk:
				if int(w[2]) in seats and w[0] != null and is_instance_valid(w[0]) \\
				and w[0].team == p.team:
					seats.erase(int(w[2]))
		if seats.is_empty():
			continue
		sub_pending.append({"out": p, "seat": int(seats[0]), "team": p.team})

## Sub the USER off: he walks to the bench while his reserve walks on.''')

edit("src/match/Court.gd",
     '''func _process_subs(delta: float) -> void:''',
     '''func _process_subs(delta: float) -> void:
	_process_live_subs(delta)
	_coach_subs()''')

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
