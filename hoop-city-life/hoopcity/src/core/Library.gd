extends Node
## Page & Print: posters you hang at home, and short books you actually read.
##
## Posters are pure decoration -- they change the wall art in the apartment and
## give a small daily mood lift. Books are read a chapter at a time and grant a
## real, permanent reward when finished, so reading is a slow alternative to
## grinding drills.

signal poster_changed
signal book_finished(id: String)

const POSTERS := {
	"court_dawn": {
		"name": "Court at Dawn", "price": 60, "kind": "photo",
		"desc": "Empty playground, low sun, long shadows.",
		"a": Color(0.92, 0.62, 0.30), "b": Color(0.20, 0.24, 0.38), "mood": 1.0},
	"city_grid": {
		"name": "City Grid", "price": 75, "kind": "geometric",
		"desc": "The skyline reduced to clean blocks of colour.",
		"a": Color(0.25, 0.55, 0.75), "b": Color(0.12, 0.14, 0.22), "mood": 1.0},
	"rise_up": {
		"name": "RISE UP", "price": 90, "kind": "typographic",
		"desc": "Two words, very large. Surprisingly effective.",
		"a": Color(0.95, 0.78, 0.20), "b": Color(0.14, 0.12, 0.16), "mood": 1.5},
	"the_ring": {
		"name": "The Ring", "price": 110, "kind": "photo",
		"desc": "A rim shot from directly underneath.",
		"a": Color(0.90, 0.35, 0.18), "b": Color(0.10, 0.11, 0.15), "mood": 1.5},
	"blueprint": {
		"name": "Court Blueprint", "price": 130, "kind": "geometric",
		"desc": "Full-court markings drafted in white on blue.",
		"a": Color(0.35, 0.60, 0.88), "b": Color(0.08, 0.18, 0.34), "mood": 2.0},
	"champions": {
		"name": "Champions 1987", "price": 180, "kind": "typographic",
		"desc": "A vintage title banner. Nobody asks whose.",
		"a": Color(0.85, 0.70, 0.35), "b": Color(0.30, 0.10, 0.12), "mood": 2.5},
	"night_run": {
		"name": "Night Run", "price": 150, "kind": "photo",
		"desc": "Floodlit asphalt, rain, one player.",
		"a": Color(0.45, 0.70, 0.95), "b": Color(0.06, 0.08, 0.14), "mood": 2.0},
	"mountain": {
		"name": "The Long Climb", "price": 100, "kind": "geometric",
		"desc": "Peaks in flat colour. A reminder about patience.",
		"a": Color(0.55, 0.75, 0.62), "b": Color(0.14, 0.20, 0.24), "mood": 1.5},
}

## Short books. `chapters` is how many reading sessions it takes; each session
## costs time and gives a little XP, and finishing grants `reward`.
const BOOKS := {
	"footwork": {
		"name": "Footwork First", "price": 45, "chapters": 3, "minutes": 40,
		"desc": "A coach's notes on balance, pivots and landing softly.",
		"reward": {"attr": "accel", "amount": 1},
		"blurb": "Everything you do on offence starts from the floor up."},
	"quiet_mind": {
		"name": "The Quiet Mind", "price": 55, "chapters": 4, "minutes": 35,
		"desc": "Staying calm at the free-throw line when it matters.",
		"reward": {"attr": "mid", "amount": 1},
		"blurb": "Pressure is only attention you have not yet organised."},
	"read_defence": {
		"name": "Reading Defences", "price": 70, "chapters": 4, "minutes": 45,
		"desc": "How to see a double team one pass before it arrives.",
		"reward": {"attr": "pass", "amount": 1},
		"blurb": "The pass that breaks a trap is decided before the trap forms."},
	"iron_hours": {
		"name": "Iron Hours", "price": 60, "chapters": 3, "minutes": 50,
		"desc": "A season in the weight room, told honestly.",
		"reward": {"attr": "stamina", "amount": 1},
		"blurb": "Nobody is watching at six in the morning. That is the point."},
	"handles": {
		"name": "Handles", "price": 50, "chapters": 3, "minutes": 35,
		"desc": "Ball control drills you can do in a corridor.",
		"reward": {"attr": "handle", "amount": 1},
		"blurb": "If you have to look at the ball, it is not yours yet."},
	"the_long_game": {
		"name": "The Long Game", "price": 85, "chapters": 4, "minutes": 40,
		"desc": "Careers, setbacks, and what happens after the noise.",
		"reward": {"rep": 4},
		"blurb": "The players who last are rarely the ones who peak first."},
}

func _ready() -> void:
	Events.day_advanced.connect(_on_day)

# ------------------------------------------------------------------ storage
func _store() -> Dictionary:
	if not Game.profile.has("library"):
		Game.profile["library"] = {
			"posters": [],       # ids owned
			"hung": "",          # id currently on the wall
			"books": {},         # id -> chapters read
		}
	return Game.profile["library"]

func posters_owned() -> Array:
	return _store()["posters"]

func hung() -> String:
	return String(_store().get("hung", ""))

func owns_poster(id: String) -> bool:
	return id in posters_owned()

func buy_poster(id: String) -> bool:
	var p: Dictionary = POSTERS.get(id, {})
	if p.is_empty() or owns_poster(id):
		return false
	if int(Game.profile["money"]) < int(p["price"]):
		Events.toast.emit(Loc.tx("Not enough money"))
		return false
	Game.add_money(-int(p["price"]))
	posters_owned().append(id)
	_store()["hung"] = id          # hang it straight away
	poster_changed.emit()
	Events.toast.emit(Loc.tx("Bought %s -- now on your wall") % String(p["name"]))
	return true

func hang(id: String) -> void:
	if id != "" and not owns_poster(id):
		return
	_store()["hung"] = id
	poster_changed.emit()
	Events.toast.emit(Loc.tx("Wall updated"))

## Total daily mood from the poster on display.
func mood_bonus() -> float:
	var id: String = hung()
	if id == "" or not POSTERS.has(id):
		return 0.0
	return float(POSTERS[id].get("mood", 0.0))

# ------------------------------------------------------------------ books
func books_owned() -> Dictionary:
	return _store()["books"]

func owns_book(id: String) -> bool:
	return books_owned().has(id)

func progress(id: String) -> int:
	return int(books_owned().get(id, 0))

func is_finished(id: String) -> bool:
	var b: Dictionary = BOOKS.get(id, {})
	if b.is_empty():
		return false
	return progress(id) >= int(b["chapters"])

func buy_book(id: String) -> bool:
	var b: Dictionary = BOOKS.get(id, {})
	if b.is_empty() or owns_book(id):
		return false
	if int(Game.profile["money"]) < int(b["price"]):
		Events.toast.emit(Loc.tx("Not enough money"))
		return false
	Game.add_money(-int(b["price"]))
	books_owned()[id] = 0
	Events.toast.emit(Loc.tx("Bought %s") % String(b["name"]))
	return true

## Read one chapter. Costs time and a little energy; finishing pays out.
func read_chapter(id: String) -> String:
	var b: Dictionary = BOOKS.get(id, {})
	if b.is_empty() or not owns_book(id):
		return Loc.tx("You do not own that book.")
	if is_finished(id):
		return "You have already finished %s." % String(b["name"])
	if float(Game.profile["energy"]) < 6.0:
		return "Too tired to take anything in."
	var done: int = progress(id) + 1
	books_owned()[id] = done
	Game.advance_time(int(b["minutes"]))
	Game.add_energy(-6.0)
	Game.add_xp(18, "reading")
	if done >= int(b["chapters"]):
		var rw: Dictionary = b.get("reward", {})
		var msg: String = "Finished %s." % String(b["name"])
		if rw.has("attr"):
			# Attributes are raised directly; finishing a book is earned, not
			# a spent skill point.
			var a: String = String(rw["attr"])
			var amt: int = int(rw.get("amount", 1))
			Game.profile["attrs"][a] = mini(int(Game.profile["attrs"].get(a, 50)) + amt, 99)
			Events.attribute_up.emit(a, int(Game.profile["attrs"][a]))
			Game.check_badges()
			msg += "  +%d %s" % [amt, a.to_upper()]
		if rw.has("rep"):
			Game.add_rep(int(rw["rep"]))
			msg += "  +%d rep" % int(rw["rep"])
		book_finished.emit(id)
		SaveSystem.save_game()
		return msg
	SaveSystem.save_game()
	return "Read chapter %d of %d." % [done, int(b["chapters"])]

func _on_day(_d: int) -> void:
	# A poster you like makes the flat a nicer place to wake up in.
	var m: float = mood_bonus()
	if m > 0.0:
		Game.add_energy(m)
