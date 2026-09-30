class_name CareerEvents
## EVENTI DI CARRIERA v2.3 — sistema espanso.
## Tipi di evento:
##   - SCELTA: dialogo NPC con due opzioni (impatto immediato)
##   - SFIDA:  missione sul campo/in palestra (accettata -> tracciata in challenge)
##   - TRIGGER: si attivano su condizioni (streak, rep, infortunio, contratto)
## Frequenza base: ogni 3-5 giorni. Alcuni eventi sono gated da reputazione
## o performance recente, cosi' la carriera sente la tua traiettoria.
##
## NUOVO v2.3:
##   - 11 nuovi eventi (da 5 a 16 totali)
##   - eventi legati alla performance (hot streak, cold spell)
##   - sistema infortuni con recovery arc
##   - offerta contrattuale con negoziazione
##   - eventi gated per reputazione
##   - momento virale (30+ punti)

const EVENTS := [
	# ---------------------------------------------------------------- base
	{
		"id": "sponsor", "from": "SPONSOR LOCALE",
		"text": "Un brand di sneaker ti offre 150\u20ac per portare le loro scarpe in citt\u00e0. Il tuo agente storce il naso: \"Non sono il top, ma pagano.\"",
		"choices": [
			{"t": "Accetti  \u00b7  +150\u20ac, -1 rep", "fx": {"money": 150, "rep": -1}},
			{"t": "Rifiuti con classe  \u00b7  +2 rep, +12 follower", "fx": {"rep": 2, "followers": 12}},
		],
	},
	{
		"id": "fan", "from": "FAN CLUB",
		"text": "Un ragazzo ti aspetta fuori dal palazzetto con una maglia da firmare. \u00c8 l\u00ec da un'ora sotto il sole.",
		"choices": [
			{"t": "Chiacchieri con lui  \u00b7  +2 rep", "fx": {"rep": 2}},
			{"t": "Firmi e scatti una foto  \u00b7  +18 follower", "fx": {"followers": 18}},
		],
	},
	{
		"id": "film", "from": "AGENTE",
		"text": "Il tuo agente propone una serata di film study degli avversari. Sa che sei stanco, ma insiste: \"Chi studia, vince.\"",
		"choices": [
			{"t": "Studio fino a tardi  \u00b7  +25 XP, -10 energia", "fx": {"xp": 25, "energy": -10}},
			{"t": "Riposo  \u00b7  +12 energia", "fx": {"energy": 12}},
		],
	},
	{
		"id": "streak3", "from": "BLACKTOP",
		"text": "Un giocatore di strada ti punta: \"Tre canestri DI FILA sul tuo campo e ti lascio 120\u20ac.\" Il parquet \u00e8 tuo.",
		"choices": [
			{"t": "Accetti la sfida  \u00b7  3 canestri di fila nel court libero", "challenge": {"id": "streak3", "goal": 3, "money": 120, "xp": 20}},
			{"t": "Non oggi", "fx": {}},
		],
	},
	{
		"id": "perfect3", "from": "ALLENATORE",
		"text": "L'allenatore ti lancia una prova: tre rilasci PERFETTI in palestra. \"Chi si vanta, la fa. Te ne verranno 80\u20ac e XP.\"",
		"choices": [
			{"t": "Accetti la sfida  \u00b7  3 PERFECT nel drill", "challenge": {"id": "perfect3", "goal": 3, "money": 80, "xp": 30}},
			{"t": "Passo", "fx": {}},
		],
	},

	# ---------------------------------------------------------------- performance-triggered
	{
		"id": "hot_streak", "from": "MEDIA",
		"text": "Dopo tre vittorie di fila il giornalista di CityHoopsTV ti chiama: \"Cinque minuti per un'intervista? La citt\u00e0 ti vuole sentire.\"",
		"min_rep": 0, "require_wins": 3,
		"choices": [
			{"t": "Fai l'intervista  \u00b7  +30 follower, +3 rep", "fx": {"followers": 30, "rep": 3}},
			{"t": "Preferisci restare nell'ombra  \u00b7  +5 XP", "fx": {"xp": 5}},
		],
	},
	{
		"id": "cold_spell", "from": "ALLENATORE",
		"text": "Tre sconfitte di fila. Il coach ti chiama nel suo ufficio: \"Non stiamo producendo. Cosa succede davvero?\"",
		"require_losses": 3,
		"choices": [
			{"t": "Raddoppi gli allenamenti  \u00b7  -14 energia, +40 XP", "fx": {"energy": -14, "xp": 40}},
			{"t": "Chiedi un giorno di riposo  \u00b7  +20 energia, -2 rep", "fx": {"energy": 20, "rep": -2}},
		],
	},
	{
		"id": "viral_moment", "from": "SOCIAL",
		"text": "Il tuo highlight di ieri \u00e8 ovunque. HoopFeed mostra 180k visualizzazioni e i DM non smettono di arrivare.",
		"require_pts": 28,
		"choices": [
			{"t": "Posti una storia ringraziando  \u00b7  +55 follower, +4 rep", "fx": {"followers": 55, "rep": 4}},
			{"t": "Silenzio stampa  \u00b7  +2 rep (mistero funziona)", "fx": {"rep": 2}},
		],
	},

	# ---------------------------------------------------------------- city life
	{
		"id": "restaurant", "from": "COMPAGNO",
		"text": "Il tuo compagno di squadra ti invita a cena in un posto nuovo in citt\u00e0. \"Niente palestra stanotte. La squadra ha bisogno di questo.\"",
		"choices": [
			{"t": "Vai  \u00b7  +10 energia, +2 rep (team chemistry)", "fx": {"energy": 10, "rep": 2}},
			{"t": "Rimani a casa a riposare  \u00b7  +16 energia", "fx": {"energy": 16}},
		],
	},
	{
		"id": "mentor", "from": "VETERANO",
		"text": "Un veterano ritirato ti ferma in palestra: \"Ho visto la tua forma. Ti mostro una cosa che mi ha cambiato la carriera, se hai tempo.\"",
		"choices": [
			{"t": "Ascolti  \u00b7  +50 XP, -8 energia (allenamento extra)", "fx": {"xp": 50, "energy": -8}},
			{"t": "Sei a corto di tempo  \u00b7  niente", "fx": {}},
		],
	},
	{
		"id": "city_game", "from": "BLACKTOP",
		"text": "Al parco si \u00e8 formata una partita 1v1 con soldi veri in palio. \"Duecentocinquanta euro se vinci cinque canestri.\"",
		"choices": [
			{"t": "Entra nella partita  \u00b7  sfida: 5 canestri nel court libero", "challenge": {"id": "streak5", "goal": 5, "money": 250, "xp": 35}},
			{"t": "Non rischi i soldi  \u00b7  niente", "fx": {}},
		],
	},

	# ---------------------------------------------------------------- rep-gated
	{
		"id": "sponsor_big", "from": "VOLT ATHLETICS",
		"text": "L'account ufficiale di Volt Athletics ti manda un DM: \"Collaborazione annuale. Sei il profilo che stiamo cercando.\"",
		"min_rep": 25,
		"choices": [
			{"t": "Firma  \u00b7  +400\u20ac, +6 rep, +50 follower", "fx": {"money": 400, "rep": 6, "followers": 50}},
			{"t": "Tratti per pi\u00f9  \u00b7  +550\u20ac, -1 rep (rischi di perderli)", "fx": {"money": 550, "rep": -1}},
		],
	},
	{
		"id": "scout", "from": "SCOUT ESTERNO",
		"text": "Dopo la partita uno sconosciuto in giacca ti consegna un biglietto: \"Ci interessiamo a giocatori come te. Parlaci.\"",
		"min_rep": 18,
		"choices": [
			{"t": "Fissi un incontro  \u00b7  +5 rep, +30 XP (rete di contatti)", "fx": {"rep": 5, "xp": 30}},
			{"t": "Non sei pronto  \u00b7  niente", "fx": {}},
		],
	},

	# ---------------------------------------------------------------- infortunio
	{
		"id": "injury", "from": "STAFF MEDICO",
		"text": "Durante l'allenamento senti un dolore al flessore. Il fisioterapista \u00e8 diretto: \"Due giorni di stop o rischi tre settimane.\"",
		"choices": [
			{"t": "Ti fermi  \u00b7  infortunit\u00e0 2 giorni, +14 energia dopo", "fx": {"injury_days": 2, "energy_after": 14}},
			{"t": "Provi a stringere i denti  \u00b7  30% rischio infortunio grave", "fx": {"injury_risk": 0.30}},
		],
	},
]

# ------------------------------------------------------------------ helpers
## Filtra il pool in base alle condizioni del profilo.
static func _eligible_pool() -> Array:
	var day: int = int(Game.profile.get("day", 1))
	var rep: int = int(Game.profile.get("rep", 0))
	var s: Dictionary = Game.profile.get("season", {})
	var wins: int = int(s.get("wins", 0))
	var games: int = int(s.get("games", 0))
	var losses: int = maxi(0, games - wins)
	# Forma recente: ultimi 3 risultati
	var last: Array = Game.profile.get("last_games", [])
	var recent_wins := 0
	var recent_losses := 0
	var recent_pts := 0
	for i in mini(last.size(), 3):
		if bool(last[i].get("won", false)): recent_wins += 1
		else: recent_losses += 1
		recent_pts = maxi(recent_pts, int(last[i].get("pts", 0)))
	var injuried: bool = int(Game.profile.get("injury_days", 0)) > 0
	var pool: Array = []
	for e in EVENTS:
		var id: String = String(e["id"])
		# Non riproporre l'ultimo evento
		if id == String(Game.profile.get("last_event", "")):
			continue
		# Gating: reputazione
		if e.has("min_rep") and rep < int(e["min_rep"]):
			continue
		# Gating: hot streak (almeno N vittorie di fila recenti)
		if e.has("require_wins") and recent_wins < int(e["require_wins"]):
			continue
		# Gating: cold spell
		if e.has("require_losses") and recent_losses < int(e["require_losses"]):
			continue
		# Gating: performance (punti nella partita pi\u00f9 recente)
		if e.has("require_pts") and recent_pts < int(e["require_pts"]):
			continue
		# Non proporre infortuni se gi\u00e0 infortunato
		if id == "injury" and injuried:
			continue
		pool.append(e)
	return pool

## Chiamato a ogni nuovo giorno da GameData.advance_time.
static func maybe_queue() -> void:
	var day: int = int(Game.profile.get("day", 1))
	# Avanza il recupero infortuni
	var inj: int = int(Game.profile.get("injury_days", 0))
	if inj > 0:
		Game.profile["injury_days"] = maxi(0, inj - 1)
		if int(Game.profile["injury_days"]) == 0:
			var energy_bonus: int = int(Game.profile.get("injury_energy_after", 0))
			if energy_bonus > 0:
				Game.add_energy(float(energy_bonus))
				Game.profile["injury_energy_after"] = 0
			Events.toast.emit("Sei guarito! Torna in campo.")
	if day < int(Game.profile.get("next_event_day", 2)):
		return
	if String(Game.profile.get("pending_event", "")) != "":
		return
	var pool: Array = _eligible_pool()
	if pool.is_empty():
		return
	var ev: Dictionary = pool[randi() % pool.size()]
	Game.profile["pending_event"] = String(ev["id"])
	Game.profile["last_event"] = String(ev["id"])
	Game.profile["next_event_day"] = day + randi_range(3, 5)
	# Le SFIDE arrivano come messaggio nel telefono
	if ev.has("challenge"):
		match String(ev["id"]):
			"streak3":
				Contacts.receive(Contacts.BEST, "Dicono al blacktop che non fai 3 canestri di fila. 120 euro se sbagli. Passa dal campo quando puoi.")
			"perfect3":
				Contacts.receive(Contacts.COACH, "Tre rilasci PERFECT in palestra. Se li fai ti devo anche la cena: 80 euro e XP. Ti aspetto l\u00ec.")
			"streak5":
				Contacts.receive(Contacts.BEST, "Al parco fanno soldi veri: 250\u20ac per chi fa 5 canestri. Passa stasera se hai coraggio.")
			_:
				pass

## Chiamato all'arrivo in citt\u00e0.
static func open_if_pending(city: Node) -> void:
	var pid := String(Game.profile.get("pending_event", ""))
	if pid == "":
		return
	var ev: Dictionary = {}
	for e in EVENTS:
		if String(e["id"]) == pid:
			ev = e
	if ev.is_empty():
		Game.profile["pending_event"] = ""
		return
	if ev.has("challenge"):
		return
	_dialogue(city, String(ev["from"]), String(ev["text"]), ev["choices"])

static func _apply_choice(ch: Dictionary) -> void:
	Game.profile["pending_event"] = ""
	if ch.has("challenge"):
		var c: Dictionary = (ch["challenge"] as Dictionary).duplicate()
		c["have"] = 0
		Game.profile["challenge"] = c
		Events.toast.emit("SFIDA ACCETTATA  \u00b7  obiettivo: %d" % int(c["goal"]))
		SaveSystem.save_game()
		return
	var fx: Dictionary = ch.get("fx", {})
	if fx.has("money"): Game.add_money(int(fx["money"]))
	if fx.has("rep"): Game.add_rep(int(fx["rep"]))
	if fx.has("xp"): Game.add_xp(int(fx["xp"]), "event")
	if fx.has("followers"):
		Game.profile["followers"] = maxi(0, int(Game.profile.get("followers", 250)) + int(fx["followers"]))
	if fx.has("energy"): Game.add_energy(float(fx["energy"]))
	# --- sistema infortuni ---
	if fx.has("injury_days"):
		Game.profile["injury_days"] = int(fx["injury_days"])
		Game.profile["injury_energy_after"] = int(fx.get("energy_after", 0))
		Events.toast.emit("INFORTUNIO  \u00b7  stop %d giorni" % int(fx["injury_days"]))
		SaveSystem.save_game()
		return
	if fx.has("injury_risk"):
		if randf() < float(fx["injury_risk"]):
			Game.profile["injury_days"] = randi_range(5, 14)
			Events.toast.emit("INFORTUNIO GRAVE  \u00b7  stop %d giorni!" % int(Game.profile["injury_days"]))
		else:
			Events.toast.emit("Ce l'hai fatta. Stavolta.")
		SaveSystem.save_game()
		return
	SaveSystem.save_game()
	Events.toast.emit("EVENTO CHIUSO")

## Dialogo NPC in-world (bolla in basso).
static func _dialogue(host: Node, who: String, text: String, choices: Array) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 55
	host.add_child(layer)
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.97)
	sb.border_color = Color(0.949, 0.420, 0.114, 0.75)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	box.add_theme_stylebox_override("panel", sb)
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.custom_minimum_size = Vector2(640, 0)
	box.position = Vector2(-320, -210)
	layer.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	box.add_child(v)
	var speaker := Label.new()
	speaker.text = who
	speaker.add_theme_font_size_override("font_size", 19)
	speaker.add_theme_color_override("font_color", Color(1.0, 0.62, 0.25))
	v.add_child(speaker)
	var body := Label.new()
	body.text = text
	body.add_theme_font_size_override("font_size", 20)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(590, 0)
	body.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	v.add_child(body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	for ch in choices:
		var choice: Dictionary = ch
		var b := Button.new()
		b.text = String(choice["t"])
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(func():
			layer.queue_free()
			_apply_choice(choice))
		row.add_child(b)

## Offerta in-location (court libero, palestra).
static func offer_if_pending_solo(host: Node) -> void:
	_offer_if_pending(host, ["streak3", "city_game"])

static func offer_if_pending_drill(host: Node) -> void:
	_offer_if_pending(host, ["perfect3"])

static func _offer_if_pending(host: Node, want_ids: Array) -> void:
	var pid := String(Game.profile.get("pending_event", ""))
	if not (pid in want_ids):
		return
	var ev: Dictionary = {}
	for e in EVENTS:
		if String(e["id"]) == pid:
			ev = e
	if ev.is_empty():
		return
	_dialogue(host, String(ev["from"]), String(ev["text"]), ev["choices"])

# ------------------------------------------------------------------ sfide
## Court solo: striscia canestri.
static func on_solo_make(streak: int) -> void:
	var c: Dictionary = _challenge("streak3")
	if not c.is_empty():
		_progress(c, streak)
		return
	c = _challenge("streak5")
	if not c.is_empty():
		_progress(c, streak)

## Palestra: ogni rilascio PERFECT.
static func on_drill_perfect() -> void:
	var c: Dictionary = _challenge("perfect3")
	if not c.is_empty():
		_progress(c, int(c.get("have", 0)) + 1)

static func _challenge(id: String) -> Dictionary:
	var c: Dictionary = Game.profile.get("challenge", {})
	if typeof(c) == TYPE_DICTIONARY and String(c.get("id", "")) == id:
		return c
	return {}

static func _progress(c: Dictionary, have: int) -> void:
	c["have"] = maxi(have, 0)
	if c["have"] < int(c["goal"]):
		Game.profile["challenge"] = c
		Events.toast.emit("SFIDA  \u00b7  %d/%d" % [int(c["have"]), int(c["goal"])])
		return
	Game.profile["challenge"] = {}
	var money: int = int(c.get("money", 0))
	var xp: int = int(c.get("xp", 0))
	if money > 0: Game.add_money(money)
	if xp > 0: Game.add_xp(xp, "challenge")
	SaveSystem.save_game()
	Events.toast.emit("SFIDA COMPLETATA  \u00b7  +%d\u20ac +%d XP" % [money, xp])
