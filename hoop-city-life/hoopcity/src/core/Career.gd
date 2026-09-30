extends Node
## Progressione carriera v2.3: XP, attributi, soldi, reputazione,
## reazioni social e FORMA RECENTE.
## Autoloaded come `Career`.
##
## NUOVO v2.3:
##   - forma recente (rolling 3 partite) influenza reazioni social e pay
##   - pay scalato per reputazione (non piu' fisso $80-300)
##   - reazioni social piu' ricche (8 rami invece di 3)
##   - fatigue post-partita con dirty che entra nella prossima match
##   - on_injury_game() per partite giocate da infortunato

var streak_makes := 0

func on_user_shot(res: Dictionary) -> void:
	if res["made"]:
		streak_makes += 1
		if streak_makes == 3:
			Events.toast.emit("ON FIRE!")
			Sfx.cheer(true)
		elif streak_makes == 6:
			Events.toast.emit("UNSTOPPABLE!")
			Sfx.cheer(true)
	else:
		if streak_makes >= 3:
			Events.toast.emit("Streak over")
		streak_makes = 0
	Game.add_xp(3 if res["made"] else 1, "shot")

func grade_from_score(s: float) -> String:
	if s >= 0.9: return "A+"
	if s >= 0.8: return "A"
	if s >= 0.68: return "B"
	if s >= 0.55: return "C"
	if s >= 0.4: return "D"
	return "F"

## v2.3: indice di forma basato sulle ultime 3 partite (0.0 = freddo, 1.0 = fuoco).
func recent_form() -> float:
	var last: Array = Game.profile.get("last_games", [])
	if last.is_empty(): return 0.5
	var total := 0.0
	var count := mini(last.size(), 3)
	for i in count:
		var g: Dictionary = last[i]
		var pts: int = int(g.get("pts", 0))
		var won: bool = bool(g.get("won", false))
		total += clampf((pts * 0.025) + (0.20 if won else 0.0), 0.0, 0.55)
	return clampf(total / float(count), 0.0, 1.0)

func apply_match_result(res: Dictionary) -> void:
	streak_makes = 0
	var pts: int = res.get("pts", 0)
	var perf := clampf((pts * 1.0 + res.get("ast", 0) * 1.6 + res.get("reb", 0) * 1.2
		+ res.get("stl", 0) * 2.0 + res.get("blk", 0) * 2.0 - res.get("tov", 0) * 1.8) / 45.0, 0.0, 1.2)
	var grade := grade_from_score(perf)
	var xp := int(60 + perf * 260 + (60 if res.get("won", false) else 0))
	Game.add_xp(xp, "match")

	# v2.3: pay scalato per rep + forma
	var rep: int = int(Game.profile.get("rep", 0))
	var rep_mult: float = 1.0 + clampf(rep / 50.0, 0.0, 1.2)  # max x2.2 a rep 60
	var pay := int((80 + perf * 220 + (60 if res.get("won", false) else 0)) * rep_mult)
	Game.add_money(pay)
	Game.add_rep(int(round(perf * 6.0)) + (2 if res.get("won", false) else -1))
	# v2.3: fatica pesante dopo una partita; si smaltisce dormendo/riposando
	Game.add_energy(-30.0)
	Game.add_hunger(-16.0)
	Game.advance_time(120)

	var s: Dictionary = Game.profile["season"]
	s["games"] += 1
	if res.get("won", false): s["wins"] += 1
	for k in ["pts", "ast", "reb", "stl", "blk", "tov", "fgm", "fga", "tpm", "tpa"]:
		s[k] = int(s.get(k, 0)) + int(res.get(k, 0))
	var hi: Dictionary = s.get("high", {})
	if typeof(hi) != TYPE_DICTIONARY: hi = {}
	for k in ["pts", "ast", "reb", "stl", "blk"]:
		hi[k] = maxi(int(hi.get(k, 0)), int(res.get(k, 0)))
	s["high"] = hi
	Game.profile["last_games"].push_front({
		"day": Game.profile["day"], "pts": pts, "ast": res.get("ast", 0),
		"reb": res.get("reb", 0), "grade": grade, "won": res.get("won", false),
		"score": res.get("score", [0, 0]),
		"opp": Season.short_name(String(res.get("opp", "")))
	})
	if Game.profile["last_games"].size() > 20:
		Game.profile["last_games"].resize(20)

	_apply_contract()
	_update_sgoals(res)
	_playoff_result(bool(res.get("won", false)))
	_social_reaction(pts, res.get("won", false), grade, perf)
	Contacts.on_game_played(pts, grade, bool(res.get("won", false)))
	club_interest(pts)
	# v2.3: eventuale trigger carriera legato alla performance
	CareerEvents.maybe_queue()
	SaveSystem.save_game()

## ------------------------------------------------------------------ v2.6
## CONTRATTO: stipendio a ogni partita ufficiale, countdown gare, rinnovo
## scaduto con offerte (resta o trasferimento) proporzionate alla rep.
func _apply_contract() -> void:
	var c: Dictionary = Game.profile.get("contract", {})
	if c.is_empty():
		c = {"club": Season.my_team(), "weekly": 140, "games_left": 10}
		Game.profile["contract"] = c
	if String(c.get("club", "")) != Season.my_team():
		return                      # contratto della societa' precedente
	var left := int(c.get("games_left", 0))
	if left <= 0:
		return
	c["games_left"] = left - 1
	var w := int(c.get("weekly", 0))
	if w > 0:
		Game.add_money(w)           # stipendio silenzioso: lo vedi in camerino
	if int(c["games_left"]) == 0:
		_make_offers()
		Contacts.receive(Contacts.AGENT,
			"Contratto scaduto. Ho sul tavolo le offerte: vieni in camerino (Arena > Contratto) e scegli.")

## Tre offerte: il rinnovo col club attuale + (a rep alta) due club che
## puntano su di te. Bonus alla firma piu' stipendio settimanale.
func _make_offers() -> void:
	var rep: int = int(Game.profile.get("rep", 0))
	var stay_week := 140 + rep * 7
	var offers: Array = [{"club": Season.my_team(), "weekly": stay_week,
		"bonus": 200 + rep * 6, "games": 12}]
	if rep >= 40:
		var pool: Array = Season.TEAMS.filter(func(t): return t != Season.my_team())
		pool.shuffle()
		for t in pool.slice(0, 2):
			offers.append({"club": t, "weekly": stay_week + 90 + rep * 3,
				"bonus": 500 + rep * 12, "games": 12})
	Game.profile["offers"] = offers

func accept_offer(i: int) -> void:
	var offers: Array = Game.profile.get("offers", [])
	if i < 0 or i >= offers.size():
		return
	var o: Dictionary = offers[i]
	Game.add_money(int(o.get("bonus", 0)))
	Game.profile["team"] = String(o["club"])
	Game.profile["contract"] = {"club": String(o["club"]),
		"weekly": int(o["weekly"]), "games_left": int(o.get("games", 12))}
	Game.profile["offers"] = []
	Contacts.receive(Contacts.AGENT, "Firmato per %s: %d$/settimana. Ora vai la' e giustificalo in campo."
		% [String(o["club"]), int(o["weekly"])])
	if String(o["club"]) != Season.my_team():
		Game.add_rep(2)

## ------------------------------------------------------------------ OBIETTIVI STAGIONE
## Tre traguardi generati sulla rep: vittorie, punti totali, partita grossa.
## Il progresso si legge DALLE statistiche di stagione (niente doppi contatori).
func _ensure_sgoals() -> void:
	var g: Array = Game.profile.get("sgoals", [])
	if not g.is_empty():
		return
	var rep: int = int(Game.profile.get("rep", 0))
	g = [
		{"id": "wins", "target": 6 + int(rep / 20.0),
			"reward": 400, "done": false,
			"desc": "Vinci %d partite in stagione" % (6 + int(rep / 20.0))},
		{"id": "pts", "target": 120 + rep * 2,
			"reward": 320, "done": false,
			"desc": "Segna %d punti in stagione" % (120 + rep * 2)},
		{"id": "big", "target": 20 + int(rep / 10.0),
			"reward": 260, "done": false,
			"desc": "Una partita da %d+ punti" % (20 + int(rep / 10.0))},
	]
	Game.profile["sgoals"] = g

func _update_sgoals(res: Dictionary) -> void:
	_ensure_sgoals()
	var s: Dictionary = Game.profile["season"]
	for g in Game.profile["sgoals"]:
		if bool(g.get("done", false)):
			continue
		var prog := 0
		match String(g["id"]):
			"wins": prog = int(s.get("wins", 0))
			"pts":  prog = int(s.get("pts", 0))
			"big":  prog = int(res.get("pts", 0))   # valuta la singola partita
		var hit := prog >= int(g["target"])
		if String(g["id"]) == "big":
			hit = int(res.get("pts", 0)) >= int(g["target"])
		if hit:
			g["done"] = true
			Game.add_money(int(g["reward"]))
			Game.add_xp(120, "goal")
			Game.add_rep(2)
			Events.toast.emit("%s  ·  +%d$" % [Loc.tx("STAGIONE: obiettivo centrato!"), int(g["reward"])])
			Contacts.receive(Contacts.COACH, "Obiettivo centrato: %s. Questo e' il modo di lavorare." % String(g["desc"]))

func sgoal_progress(g: Dictionary) -> int:
	var s: Dictionary = Game.profile["season"]
	match String(g["id"]):
		"wins": return int(s.get("wins", 0))
		"pts":  return int(s.get("pts", 0))
	return 0

## ------------------------------------------------------------------ v2.7 STAGIONE & PLAYOFF
## Chiamato dai giorni che passano e dalla fine di ogni partita: alla fine
## dei 60 giorni chiude la regular season e (se qualificato) apre i playoff.
func check_season() -> void:
	if not bool(Game.profile.get("season_active", true)):
		return
	if int(Game.profile.get("day", 1)) <= Season.SEASON_DAYS:
		return
	end_regular_season()

func end_regular_season() -> void:
	Game.profile["season_active"] = false
	var s: Dictionary = Game.profile["season"]
	var wins: int = int(s.get("wins", 0))
	var games: int = int(s.get("games", 0))
	var prize := 300 + wins * 60
	Game.add_money(prize)
	if games >= 8 and wins >= 8:
		var po: Dictionary = {"round": 1, "live": false,
			"opp": Season.TEAMS.filter(func(t): return t != Season.my_team()).pick_random()}
		Game.profile["playoff"] = po
		Contacts.receive(Contacts.AGENT, "SEI NEI PLAYOFF! Primo turno: %s. Vai in Arena quando sei pronto."
			% String(po["opp"]))
		Contacts.receive(Contacts.COACH, "Regular season chiusa: %d vittorie su %d. Ora si gioca tutto." % [wins, games])
		_give_awards(games, wins)
	else:
		Game.profile["playoff"] = {}
		Contacts.receive(Contacts.COACH, "Stagione finita: %d vittorie su %d. Il premio societa' e' stato pagato, ma l'anno prossimo si punta ai playoff." % [wins, games])
		_give_awards(games, wins)
		_start_new_season()
	Events.toast.emit("%s  ·  +%d$" % [Loc.tx("FINE STAGIONE"), prize])

## PREMIAZIONI individuali: MVP (vittorie+media punti) e capocannoniere.
## I premi pagano (add_money scala gia' con la difficolta) e restano nel
## palmares del telefono per sempre.
func _give_awards(games: int, wins: int) -> void:
	if games < 8:
		return
	var s: Dictionary = Game.profile["season"]
	var ppg: float = float(int(s.get("pts", 0))) / float(games)
	var sn: int = int(Game.profile.get("season_n", 1))
	if ppg >= 24.0:
		Game.profile.get("awards", []).append({"n": sn, "type": "punteggio", "ppg": snappedf(ppg, 0.1)})
		Game.add_money(500)
		Game.add_rep(2)
		Events.toast.emit("%s  ·  +%d$" % [Loc.tx("CAPOCANNONIERE"), 500])
		Contacts.receive(Contacts.BEST, "Primo marcatore del campione! %d punti a partita, frate'." % int(round(ppg)))
	if wins >= 12 and ppg >= 20.0:
		Game.profile.get("awards", []).append({"n": sn, "type": "mvp", "ppg": snappedf(ppg, 0.1)})
		Game.add_money(800)
		Game.add_rep(3)
		Events.toast.emit("%s  ·  +%d$" % [Loc.tx("MVP STAGIONE"), 800])
		Contacts.receive(Contacts.COACH, "MVP della stagione. Adesso non mollare in allenamento.")

func _save_archive() -> void:
	var s: Dictionary = Game.profile["season"]
	Game.profile.get("season_archive", []).append({
		"n": int(Game.profile.get("season_n", 1)), "games": int(s.get("games", 0)),
		"wins": int(s.get("wins", 0)), "pts": int(s.get("pts", 0)),
		"high_pts": int(s.get("high", {}).get("pts", 0)),
	})

## Arena -> PLAYOFF: prepara la partita del turno corrente.
func playoff_ready() -> bool:
	var po: Dictionary = Game.profile.get("playoff", {})
	return not po.is_empty() and int(po.get("round", 0)) >= 1 and int(po.get("round", 0)) <= 3 \
		and not bool(po.get("live", false))

func playoff_round_name() -> String:
	return ["", "Quarti di finale", "Semifinale", "FINALE"][clampi(int(Game.profile["playoff"].get("round", 1)), 1, 3)]

func playoff_tip_off() -> void:
	var po: Dictionary = Game.profile.get("playoff", {})
	po["live"] = true
	Game.profile["playoff"] = po
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = false
	Game.profile["next_opponent"] = String(po["opp"])
	Game.profile["next_home"] = true
	Game.set_team_kit(1, Season.kit_for(String(po["opp"])))
	SceneRouter.goto("res://src/match/MatchScene.tscn")

func _playoff_result(won: bool) -> void:
	var po: Dictionary = Game.profile.get("playoff", {})
	if po.is_empty() or not bool(po.get("live", false)):
		return
	po["live"] = false
	if won:
		var rd := int(po.get("round", 1))
		var prize: int = [0, 250, 400, 1500][clampi(rd, 1, 3)]
		Game.add_money(prize)
		if rd >= 3:
			# SCUDETTO: trofeo, festa, rep.
			Game.profile["trophies"] = int(Game.profile.get("trophies", 0)) + 1
			Game.add_rep(5)
			Game.add_xp(400, "championship")
			Game.profile["followers"] = int(Game.profile.get("followers", 250)) + 250
			Game.profile["celebrate"] = true   # la festa ti accoglie in citta
			Contacts.receive(Contacts.BEST, "CAMPIONI!! Non ci credo, sto urlando da solo in casa!")
			Contacts.receive(Contacts.SIS, "MAMMA STA PIANGENDO FELICE. TI VOGLIO BENE.")
			Events.toast.emit("%s  ·  +%d$" % [Loc.tx("CAMPIONI!"), prize])
			_start_new_season()
		else:
			po["round"] = rd + 1
			po["opp"] = Season.TEAMS.filter(func(t): return t != Season.my_team()).pick_random()
			Game.profile["playoff"] = po
			Events.toast.emit("%s  ·  +%d$" % [Loc.tx("PASSATO IL TURNO"), prize])
			Contacts.receive(Contacts.AGENT, "Turno superato. Il prossimo: %s. Si torna in Arena." % String(po["opp"]))
	else:
		Game.profile["playoff"] = {}
		Contacts.receive(Contacts.AGENT, "Eliminati. Fa' male, ma la squadra ti ha visto: a modo tuo la riprendiamo.")
		_start_new_season()

## Nuova stagione: archivio, seed nuovo (calendario diverso), obiettivi e
## contatori azzerrati. La forma recente resta: sei sempre tu.
func _start_new_season() -> void:
	_save_archive()
	Game.profile["season_n"] = int(Game.profile.get("season_n", 1)) + 1
	Game.profile["season"] = {"games": 0, "wins": 0, "pts": 0, "ast": 0, "reb": 0,
		"stl": 0, "blk": 0, "tov": 0, "fgm": 0, "fga": 0, "tpm": 0, "tpa": 0,
		"high": {"pts": 0, "ast": 0, "reb": 0, "stl": 0, "blk": 0}}
	Game.profile["sgoals"] = []
	Game.profile["schedule"] = []          # rigenerato con il nuovo seed
	Game.profile["seed"] = int(Game.profile.get("seed", 12345)) + 7919
	Game.profile["day"] = 1
	Game.profile["season_active"] = true
	Game.profile["playoff"] = {}
	Contacts.receive(Contacts.COACH, "Nuova stagione, quaderno pulito. %s parte da qui." % Season.my_team())

## Salto rapido (bottone TEST nelle impostazioni): porta alla prossima gara
## giocabile con energia pronta, cosi' stagione e playoff si provano senza
## attendere i giorni in citta'.
func skip_to_game() -> void:
	var day: int = int(Game.profile.get("day", 1))
	if day > Season.SEASON_DAYS and bool(Game.profile.get("season_active", true)):
		end_regular_season()
	if Career.playoff_ready():
		Events.toast.emit(Loc.tx("C'e' un PLAYOFF da giocare: vai in Arena"))
		SaveSystem.save_game()
		return
	var target := -1
	for e in Season.schedule():
		var d: int = int(e["day"])
		if d >= day and String(e.get("kind", "")) == "game" and not bool(e.get("done", false)):
			target = d
			break
	if target < 0:
		target = mini(day + 3, Season.SEASON_DAYS)
	Game.profile["day"] = target
	Game.profile["minutes"] = 540
	Game.profile["battery"] = maxf(float(Game.profile.get("battery", 0.0)), 80.0)
	Game.profile["energy"] = maxf(float(Game.profile.get("energy", 0.0)), 80.0)
	Game._roll_weather()
	Career.check_season()
	Events.day_advanced.emit(Game.profile["day"])
	SaveSystem.save_game()
	Events.toast.emit(Loc.tx("Giorno %d  ·  gara pronta in Arena") % target)

## ------------------------------------------------------------------ v2.7 AGENTE
## Estensione contratto in corsa: +8 gare con ingaggio rinegoziato sulla
## forma recente. Una volta per contratto.
func extend_contract() -> void:
	var c: Dictionary = Game.profile.get("contract", {})
	if c.is_empty() or bool(c.get("extended", false)) or int(c.get("games_left", 0)) <= 0:
		return
	var bonus_form: int = int(recent_form() * 90.0)
	c["weekly"] = int(c.get("weekly", 140)) + 20 + bonus_form
	c["games_left"] = int(c.get("games_left", 0)) + 8
	c["extended"] = true
	Game.profile["contract"] = c
	Contacts.receive(Contacts.AGENT, "Esteso: %d$/partita per altre 8 gare. La forma ha parlato." % int(c["weekly"]))

## Quando brilli, i club chiedono di te: flavour dall'agente (raro).
func club_interest(pts: int) -> void:
	var rep: int = int(Game.profile.get("rep", 0))
	if rep < 30 or pts < 22:
		return
	var today: int = int(Game.profile.get("day", 0))
	if int(Game.profile.get("last_interest_day", -9)) >= today - 6:
		return
	Game.profile["last_interest_day"] = today
	var t: String = Season.TEAMS.filter(func(x): return x != Season.my_team()).pick_random()
	Contacts.receive(Contacts.AGENT, "Rumore di corridoio: il %s ha chiesto di te dopo la partita da %d. Continua cosi' e parliamo sul serio." % [t, pts])

func _social_reaction(pts: int, won: bool, grade: String, perf: float) -> void:
	var name: String = Game.profile["name"]
	var rep: int = int(Game.profile.get("rep", 0))
	var form: float = recent_form()
	# Post partita: tono dipende da reputazione + forma + punti
	if pts >= 30:
		Game.add_social_post("@HoopWire",
			"%s ESPLODE con %d punti. Questo e' un momento." % [name, pts],
			600 + rep * 40)
		if rep >= 20:
			Game.add_social_post("@CityHighlights",
				"HIGHLIGHTS: %d pts, grade %s. Dove vuole arrivare %s?" % [pts, grade, name],
				300 + rep * 20)
		# Agente contatta per deal scarpe solo ad alta rep
		if rep > 25:
			Contacts.receive(Contacts.AGENT,
				"Volt Athletics hanno visto i tuoi %d. Vogliono parlare appena possibile. Non rispondere a nessuno prima di me." % pts)
	elif pts >= 22:
		Game.add_social_post("@CityHoopsDaily",
			"%d punti per %s. Grade %s. %s" % [pts, name, grade,
			"La citt\u00e0 inizia a sentire il nome." if form > 0.6 else "Deve essere continuo."],
			120 + rep * 10)
	elif pts >= 14:
		var tone := "Serata solida." if won else "Non basta: serve di pi\u00f9."
		Game.add_social_post("@CityHoopsDaily",
			"%d punti, grade %s per %s. %s" % [pts, grade, name, tone],
			80 + rep * 7)
	elif pts >= 8:
		Game.add_social_post("@BenchTakes",
			"Notte silenziosa per %s. %s" % [name, "Forse stanchezza." if form < 0.3 else "Puo' fare di meglio."],
			20 + rep * 2)
	else:
		Game.add_social_post("@BenchTakes",
			"Dove era %s stanotte?" % name, 10 + rep)
	if won:
		Game.add_social_post(Season.handle(), "W. Sul prossimo. \ud83d\udcaa", 150 + rep * 5)
	if not won and perf < 0.4:
		# Il coach commenta pubblicamente solo le serate davvero dure
		Game.add_social_post("@CoachOfficial",
			"Abbiamo bisogno di risposte. Dal 1.", 80)

func apply_drill_result(drill: String, score01: float) -> void:
	var grade := grade_from_score(score01)
	Contacts.on_drill(drill, grade)
	var xp := int(25 + score01 * 130)
	Game.add_xp(xp, "drill_" + drill)
	if drill == "weights":
		Game.add_energy(-22.0); Game.add_hunger(-14.0); Game.advance_time(75)
	elif drill == "cardio":
		Game.add_energy(-18.0); Game.add_hunger(-16.0); Game.advance_time(85)
	else:
		Game.add_energy(-16.0); Game.add_hunger(-6.0); Game.advance_time(60)
	if score01 >= 0.68:
		var pool: Array = {
			"shooting": ["three", "mid", "close"],
			"freethrow": ["close", "mid"],
			"handling": ["handle", "accel", "speed"],
			"defense": ["defense", "steal", "block"],
			"weights": ["rebound", "block", "close", "stamina"],
			"cardio": ["stamina", "speed", "accel"],
		}.get(drill, ["stamina"])
		var a: String = pool.pick_random()
		if Game.attr(a) < 99 and randf() < score01:
			Game.profile["attrs"][a] += 1
			Events.attribute_up.emit(a, Game.profile["attrs"][a])
			Events.toast.emit("%s +1" % a.to_upper())
		# (Il progresso perfect3 resta legato SOLO ai rilasci PERFECT veri
		# del drill, come voluto: niente doppio conteggio dal voto sessione.)
	Game.check_badges()
	SaveSystem.save_game()
	Events.toast.emit("Drill grade: %s  (+%d XP)" % [grade, xp])
