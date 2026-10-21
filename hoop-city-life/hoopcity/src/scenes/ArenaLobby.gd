extends Node2D
## The arena concourse. Walking in must NEVER drop you straight into a game --
## that was the old behaviour and it made fixtures feel random. Here you see
## today's schedule, and you can only tip off when the calendar actually says
## there is a game today. Everything else is closed doors and a countdown.

@onready var root: Control = $UI/Root

const COST := 25

func _ready() -> void:
	Game.profile["last_building"] = "arena"
	_build()

func _build() -> void:
	UIKit.header(root, Loc.tx("RIVERSIDE ARENA"), Loc.tx("Home of the Ravens."))
	root.add_child(preload("res://src/ui/StatusBar.gd").new())

	Career.check_season()
	var v := UIKit.column(root, Vector2(60, 190))
	var e: Dictionary = Season.today()
	var day: int = int(Game.profile.get("day", 1))
	var energy: float = float(Game.profile["energy"])

	var kind: String = String(e.get("kind", "rest")) if not e.is_empty() else Loc.tx("rest")
	var played: bool = bool(e.get("done", false))

	if kind == "game" and not played:
		var opp: String = String(e.get("opponent", "Visitors"))
		var home: bool = bool(e.get("home", true))
		UIKit.big_button(v, Loc.tx("▶  TIP OFF vs %s") % opp.to_upper(),
			(func(): _tip_off(e)) if energy >= float(COST) else Callable(),
			("%s · day %d · %d energy" % [Loc.tx("HOME") if home else Loc.tx("AWAY"), day, COST])
				if energy >= float(COST)
				else Loc.tx("NEED %d ENERGY (you have %d) · rest first") % [COST, int(energy)])
		if energy < float(COST):
			# disable the button we just made
			for c in v.get_children():
				if c is Button and c.text.begins_with("▶"):
					c.disabled = true
	elif kind == "game" and played:
		UIKit.big_button(v, Loc.tx("Today's game is finished"), Callable(),
			"Result: %s · come back tomorrow" % String(e.get("result", "played")))
		for c in v.get_children():
			if c is Button:
				c.disabled = true
	else:
		# No fixture today: say so plainly and show when the next one is.
		var nxt: Dictionary = _next_game(day)
		var when: String = Loc.tx("no game scheduled")
		if not nxt.is_empty():
			var d: int = int(nxt["day"])
			when = Loc.tx("Next game: day %d vs %s  (in %d day%s)") % [
				d, String(nxt.get("opponent", "?")), d - day,
				"" if d - day == 1 else Loc.tx("s")]
		UIKit.big_button(v, Loc.tx("NO GAME TODAY"), Callable(), when)
		for c in v.get_children():
			if c is Button:
				c.disabled = true

	# PLAYOFF: visibile solo se la regular season e' finita e sei vivo.
	if Career.playoff_ready():
		UIKit.big_button(v, Loc.tx("PLAYOFF: %s") % Career.playoff_round_name(),
			func(): Career.playoff_tip_off(),
			Loc.tx("vs %s") % String(Game.profile["playoff"]["opp"]))
	# Always available: look at the schedule.
	UIKit.big_button(v, Loc.tx("📅  Season schedule"),
		func(): _show_schedule(), Loc.tx("sweep.176"))
	UIKit.big_button(v, Loc.tx("💼  Contract & goals"), func(): _show_contract(), _contract_sub())
	UIKit.big_button(v, Loc.tx("Leave"),
		func(): SceneRouter.goto("res://src/scenes/CityScene.tscn"))
	UIKit.back_and_phone(root)

func _contract_sub() -> String:
	var c: Dictionary = Game.profile.get("contract", {})
	var left := int(c.get("games_left", 0))
	var offers: Array = Game.profile.get("offers", [])
	if left <= 0 and not offers.is_empty():
		return Loc.tx("SCADUTO: scegli la nuova squadra!")
	if left <= 1:
		return Loc.tx("in scadenza")
	return Loc.tx("%d$/partita  ·  %d gare") % [int(c.get("weekly", 0)), left]

func _show_contract() -> void:
	Career._ensure_sgoals()
	var p: GamePanel = GamePanel.new().build("💼  Contract & goals", Vector2(920, 640))
	$UI.add_child(p)
	var c: Dictionary = Game.profile.get("contract", {})
	var left := int(c.get("games_left", 0))
	var offers: Array = Game.profile.get("offers", [])
	# --- contratto
	p.add_text("%s  ·  %d$/partita  ·  %d gare rimaste" % [
		Season.my_team(), int(c.get("weekly", 0)), maxi(left, 0)], 23,
		Color(1.0, 0.88, 0.4) if left <= 1 else Color(0.95, 0.95, 0.9))
	if left <= 0 and not offers.is_empty():
		p.add_text(Loc.tx("Il contratto e' SCADUTO: le offerte sono sul tavolo."), 21, Color(1.0, 0.6, 0.45))
		for i in offers.size():
			var o: Dictionary = offers[i]
			var is_stay: bool = String(o["club"]) == Season.my_team()
			var label: String = "%s  ·  %d$/partita  ·  bonus %d$" % [
				String(o["club"]) + (Loc.tx("  (resta)") if is_stay else ""),
				int(o["weekly"]), int(o["bonus"])]
			var idx := i
			p.add_button(label, func():
				Career.accept_offer(idx)
				p.close()
				Events.toast.emit(Loc.tx("Firmato!")), true)
	else:
		p.add_text(Loc.tx("Ogni partita ufficiale paga lo stipendio. A scadenza arrivano nuove offerte (piu' ricche con rep alta)."),
			19, Color(1, 1, 1, 0.55))
		if not bool(c.get("extended", false)) and left > 0 and left <= 4:
			p.add_button(Loc.tx("Estendi contratto  ·  +8 gare, ingaggio rinegoziato sulla forma"), func():
				Career.extend_contract()
				p.close()
				Events.toast.emit(Loc.tx("Contratto esteso")), true)
	p.add_text("", 8)
	# --- obiettivi stagione
	p.add_text(Loc.tx("Obiettivi stagione"), 24, Color(0.6, 0.9, 1.0))
	for g in Game.profile.get("sgoals", []):
		var prog := Career.sgoal_progress(g)
		if String(g["id"]) == "big":
			prog = int(g["target"]) if bool(g.get("done", false)) else 0
		var bar: String = "✓" if bool(g.get("done", false)) else "%d/%d" % [mini(prog, int(g["target"])), int(g["target"])]
		var col: Color = Color(0.5, 1.0, 0.55) if bool(g.get("done", false)) else Color(0.9, 0.9, 0.85)
		p.add_text("%s   %s   ·  premio %d$" % [String(g["desc"]), bar, int(g["reward"])], 20, col)
	p.add_text("")
	p.add_button(Loc.tx("Close"), func(): p.close())

func _next_game(from_day: int) -> Dictionary:
	for e in Season.schedule():
		if int(e["day"]) >= from_day and String(e.get("kind", "")) == "game" \
		and not bool(e.get("done", false)):
			return e
	return {}

func _tip_off(e: Dictionary) -> void:
	if float(Game.profile["energy"]) < float(COST):
		Events.toast.emit(Loc.tx("Too tired -- you need %d energy") % COST)
		return
	var opp: String = String(e.get("opponent", "Visitors"))
	var home: bool = bool(e.get("home", true))
	Game.advance_time(30)
	# Straight into the game. The animated intro caused more trouble than it
	# was worth, so the fixture details go to the match itself and the
	# scoreboard shows who you are playing.
	Game.profile["next_match_mode"] = "full"
	Game.profile["match_is_fixture"] = true
	Game.profile["next_opponent"] = opp
	Game.profile["next_home"] = home
	# Club colours travel with the club: the visitors never show up in our
	# last-picked practice kit.
	Game.set_team_kit(1, Season.kit_for(opp))
	SceneRouter.goto("res://src/match/MatchScene.tscn")

func _show_schedule() -> void:
	var p: GamePanel = GamePanel.new().build("📅  Schedule", Vector2(900, 620))
	$UI.add_child(p)
	var day: int = int(Game.profile.get("day", 1))
	for e in Season.upcoming(9):
		var d: int = int(e["day"])
		var kind: String = String(e.get("kind", "rest"))
		var line: String = "Day %d · %s" % [d, Season.label_for(e)]
		var col := Color(1, 1, 1, 0.75)
		if d == day:
			line = "TODAY · " + Season.label_for(e)
			col = Color(1, 0.88, 0.4)
		if kind == "game":
			col = Color(0.6, 0.9, 1.0) if d != day else col
		p.add_text(line, 22, col)
	p.add_text("")
	p.add_button(Loc.tx("Close"), func(): p.close())
