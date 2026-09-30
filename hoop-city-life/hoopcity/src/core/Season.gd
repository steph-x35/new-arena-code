extends Node
## League calendar. Autoloaded as `Season`.
##
## The schedule is generated once per career and stored in the profile, so the
## calendar you read on the phone is the same one the world actually runs on.
##
## Day kinds:
##   "game"     - league fixture. Playing it is the point of the career.
##   "practice" - team practice. SKIPPABLE, but skipping costs followers and rep
##                and the coach notices.
##   "weights"  - scheduled lifting day. Free-form: do it whenever you like.
##   "rest"     - nothing booked.

const TEAMS := [
	"Riverside Ravens", "Eastport Dockers", "Foundry Hill Kings", "Lakeside Current",
	"Northgate Wolves", "Old Mill Saints", "Bayview Tide", "Cedar Park Rangers",
]
const DEFAULT_TEAM := "Riverside Ravens"
const SEASON_DAYS := 60

# ------------------------------------------------------------------ club identity
## Who each club IS, beyond a name: scoreboard abbreviation, colours it wears,
## the building it plays in, how it plays, and the name pool of its roster.
## This is what makes an away day at the Foundry feel different from a home
## game at the Pavilion. The user's club keeps the kit picked in the kit
## picker; identity kits pre-fill the OPPONENT side before tip-off.
const TEAM_META := {
	"Riverside Ravens":   {"short": "RAV", "kit": "royal",    "arena": "Riverside Pavilion", "style": "run",
		"names": ["Ferro", "Vance", "Okoye", "Duarte", "Silva"]},
	"Eastport Dockers":   {"short": "DOC", "kit": "teal",     "arena": "Harbour Yard",       "style": "inside",
		"names": ["Marek", "Kolo", "Bran", "Osei", "Pike"]},
	"Foundry Hill Kings": {"short": "FDK", "kit": "gold",     "arena": "The Foundry",        "style": "grit",
		"names": ["Anvil", "Rooke", "Doss", "Ivers", "Callo"]},
	"Lakeside Current":   {"short": "CUR", "kit": "forest",   "arena": "The Boathouse",      "style": "run",
		"names": ["Reed", "Fisk", "Mabry", "Otto", "Voss"]},
	"Northgate Wolves":   {"short": "NWV", "kit": "charcoal", "arena": "Northgate Den",      "style": "lock",
		"names": ["Skar", "Vane", "Holt", "Rime", "Bruck"]},
	"Old Mill Saints":    {"short": "OMS", "kit": "orange",   "arena": "Millhouse Garden",   "style": "lock",
		"names": ["Abel", "Cruz", "Mora", "Petit", "Sanna"]},
	"Bayview Tide":       {"short": "BVT", "kit": "purple",   "arena": "Pier 9 Arena",       "style": "run",
		"names": ["Nero", "Salt", "Ito", "Maro", "Quist"]},
	"Cedar Park Rangers": {"short": "CPR", "kit": "scarlet",  "arena": "Cedar Grove",        "style": "grit",
		"names": ["Wood", "Fenn", "Aro", "Tilo", "Garn"]},
	"Practice Squad":     {"short": "PRA", "kit": "white",    "arena": "Riverside Pavilion", "style": "none", "names": []},
	"The Challenger":     {"short": "CHL", "kit": "pink",     "arena": "Streetball Cage",    "style": "none", "names": []},
}

func _meta(team: String) -> Dictionary:
	if TEAM_META.has(team):
		return TEAM_META[team]
	return {"short": team.left(3).to_upper(), "kit": "scarlet", "arena": team,
		"style": "none", "names": []}

func short_name(team: String) -> String:
	return String(_meta(team)["short"])

func arena_of(team: String) -> String:
	return String(_meta(team)["arena"])

func style_of(team: String) -> String:
	return String(_meta(team)["style"])

func roster_names(team: String) -> Array:
	return _meta(team)["names"]

## The kit a club wears. The user's club always wears what was picked in the
## kit picker; everyone else wears club colours — unless that would clash
## with ours, in which case the first different kit in the catalogue wins.
func kit_for(team: String) -> String:
	if team == my_team():
		return Game.team_kit(0)
	var k := String(_meta(team)["kit"])
	if k == Game.team_kit(0):
		for cand in Game.KITS.keys():
			if String(cand) != Game.team_kit(0):
				k = String(cand)
				break
	return k

## League record (W-L) for a club, derived deterministically from the career
## seed over the games actually played so far — stable within a save, and it
## slowly fills in as the season goes on.
func record(team: String) -> Dictionary:
	var games := 0
	for e in schedule():
		if String(e.get("kind", "")) == "game" and bool(e.get("done", false)):
			games += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|%s" % [int(Game.profile.get("seed", 12345)), team])
	var w := 0
	for i in games:
		if rng.randf() < 0.55:
			w += 1
	return {"w": w, "l": games - w}

## The building tonight's match is played in, honouring next_home.
func match_arena() -> String:
	var opp := String(Game.profile.get("next_opponent", ""))
	var home := bool(Game.profile.get("next_home", true))
	return arena_of(my_team() if home else opp)

## The side you play for. Chosen once in the character creator and remembered
## in the profile; every screen that names "your team" reads it from here.
func my_team() -> String:
	return String(Game.profile.get("team", DEFAULT_TEAM))

## The social handle of your club, e.g. "@TeamRiverside".
func handle() -> String:
	return "@Team" + my_team().split(" ")[0]

func _ready() -> void:
	Events.day_advanced.connect(_on_day)

# ------------------------------------------------------------------ schedule
func schedule() -> Array:
	if not Game.profile.has("schedule") or Game.profile["schedule"].is_empty():
		Game.profile["schedule"] = _generate()
	return Game.profile["schedule"]

func _generate() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Game.profile.get("seed", 12345))
	var out := []
	var opponents: Array = TEAMS.filter(func(t): return t != my_team())
	var oi: int = 0
	for day in range(1, SEASON_DAYS + 1):
		var kind := "rest"
		var opp := ""
		# Fixtures every 3rd day, practice the day before, weights in between.
		if day % 3 == 0:
			kind = "game"
			opp = String(opponents[oi % opponents.size()])
			oi += 1
		elif day % 3 == 1:
			kind = "practice"
		else:
			kind = "weights"
		out.append({
			"day": day, "kind": kind, "opponent": opp,
			"home": (oi % 2) == 0,
			"done": false, "skipped": false, "result": "",
		})
	return out

func entry_for(day: int) -> Dictionary:
	for e in schedule():
		if int(e["day"]) == day:
			return e
	return {}

func today() -> Dictionary:
	return entry_for(int(Game.profile.get("day", 1)))

func upcoming(count := 10) -> Array:
	var day: int = int(Game.profile.get("day", 1))
	var out := []
	for e in schedule():
		if int(e["day"]) >= day and out.size() < count:
			out.append(e)
	return out

# ------------------------------------------------------------------ followers
func followers() -> int:
	return int(Game.profile.get("followers", 250))

func add_followers(n: int) -> void:
	Game.profile["followers"] = maxi(followers() + n, 0)
	Events.followers_changed.emit(followers())

# ------------------------------------------------------------------ actions
func mark_done(day: int, result := "") -> void:
	var e := entry_for(day)
	if e.is_empty():
		return
	e["done"] = true
	e["result"] = result
	SaveSystem.save_game()

func attend_practice() -> void:
	var e := today()
	if e.is_empty() or String(e["kind"]) != "practice" or bool(e["done"]):
		return
	e["done"] = true
	# Showing up is rewarded, quietly but consistently.
	var gain: int = 40 + int(Game.profile.get("rep", 0)) * 2
	add_followers(gain)
	Game.add_rep(1)
	Game.add_xp(70, "practice")
	Game.add_energy(-18.0)
	Game.add_hunger(-8.0)
	Game.advance_time(90)
	Events.toast.emit("Practice done. +%d followers" % gain)
	SaveSystem.save_game()

func skip_practice(silent := false) -> void:
	var e := today()
	if e.is_empty() or String(e["kind"]) != "practice" or bool(e["done"]):
		return
	e["done"] = true
	e["skipped"] = true
	# The penalty the player asked for: followers drop and reputation suffers.
	var loss: int = 60 + int(followers() * 0.04)
	add_followers(-loss)
	Game.add_rep(-2)
	Game.profile["skipped_practices"] = int(Game.profile.get("skipped_practices", 0)) + 1
	if not silent:
		Events.toast.emit("Skipped practice. -%d followers" % loss)
	Contacts.receive(Contacts.COACH,
		"You weren't at practice today. That's noted. Don't make it a habit.")
	var n: int = int(Game.profile["skipped_practices"])
	if n == 3:
		Contacts.receive(Contacts.COACH,
			"Third one. Miss another and you're coming off the bench.")
	SaveSystem.save_game()

func _on_day(_d: int) -> void:
	## Anything left undone yesterday is resolved automatically: a practice you
	## never attended counts as skipped.
	var prev: int = int(Game.profile.get("day", 1)) - 1
	var e := entry_for(prev)
	if e.is_empty() or bool(e["done"]):
		return
	if String(e["kind"]) == "practice":
		e["done"] = true
		e["skipped"] = true
		var loss: int = 60 + int(followers() * 0.04)
		add_followers(-loss)
		Game.add_rep(-2)
		Game.profile["skipped_practices"] = int(Game.profile.get("skipped_practices", 0)) + 1
		Contacts.receive(Contacts.COACH, "Missed practice yesterday. Where were you?")
	elif String(e["kind"]) == "game":
		e["done"] = true
		e["skipped"] = true
		add_followers(-int(followers() * 0.10))
		Game.add_rep(-4)
		Contacts.receive(Contacts.COACH, "You no-showed a league game. We had to play a man down.")

func label_for(e: Dictionary) -> String:
	match String(e.get("kind", "rest")):
		"game":
			var vs: String = "vs" if bool(e.get("home", true)) else "@"
			return "GAME  %s %s" % [vs, String(e.get("opponent", ""))]
		"practice":
			return "Team practice"
		"weights":
			return "Weight room (free)"
		_:
			return "Rest day"
