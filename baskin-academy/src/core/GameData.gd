extends Node

const VERSION := "1.19.2"
## Single source of truth for the persistent player profile + world clock.
## Autoloaded as `Game`.

const ATTRS := [
	"close", "mid", "three", "handle", "pass", "speed", "accel",
	"stamina", "defense", "steal", "block", "rebound"
]

const BADGES := {
	"catch_and_shoot":  {"name": "Catch & Shoot",   "desc": "+8 shot rating on passes received while open.", "req": {"three": 70}},
	"quick_first_step": {"name": "Quick First Step","desc": "+12% acceleration out of a stand-still.",        "req": {"accel": 72}},
	"iron_lungs":       {"name": "Iron Lungs",      "desc": "-20% stamina drain while sprinting.",            "req": {"stamina": 75}},
	"pickpocket":       {"name": "Pickpocket",      "desc": "+15% steal window, -10% foul risk.",             "req": {"steal": 70}},
	"glass_cleaner":    {"name": "Glass Cleaner",   "desc": "+10% rebound contest chance.",                   "req": {"rebound": 70}},
	"deep_range":       {"name": "Deep Range",      "desc": "Reduced distance penalty beyond the arc.",       "req": {"three": 80}},
}

var profile: Dictionary = {}

func _init() -> void:
	# Populate immediately, not in _ready(). Scenes that are instantiated
	# directly (tools, tests, deep links) can touch Game.profile before the
	# autoload's _ready() has run, and used to crash on an empty dictionary.
	profile = default_profile()

func _ready() -> void:
	if profile.is_empty():
		profile = default_profile()

func default_profile() -> Dictionary:
	return {
		"version": 1,
		"name": "Rookie",
		"position": "PG",
		"height_cm": 190,
		"weight_kg": 85,
		"hand": "R",
		"skin": 2,
		"hair": 0,
		"face": 0,
		"jersey": 7,
		"team": "Riverside Ravens",
		"home_floor2": false,      # the second floor, bought for 1000 coins
		"furniture": [],           # ids of furniture placed upstairs

		"attrs": {
			"close": 55, "mid": 52, "three": 48, "handle": 58, "pass": 55,
			"speed": 62, "accel": 60, "stamina": 60, "defense": 50,
			"steal": 48, "block": 40, "rebound": 45,
		},
		"xp": 0,
		"attr_points": 0,
		"level": 1,
		"badges": [],

		"energy": 100.0,
		"hunger": 100.0,
		"health": 100.0,
		# You start with the 200-coin rookie signing bonus and nothing else.
		"money": 200,
		"rep": 5,
		"difficulty": 1,         # 0 facile, 1 normale, 2 forte (Impostazioni)

		"day": 1,
		"minutes": 480,          # 08:00
		"battery": 100.0,        # batteria del telefono: si scarica in giornata
		"injury_days": 0,        # giorni di stop per infortunio (eventi carriera)
		"injury_energy_after": 0,
		"weather": "rain",

		"inventory": {"protein_bar": 2, "energy_drink": 1},
		"outfit": {"shoes": "basic_shoes", "jersey": "plain_tee", "shorts": "plain_shorts", "acc": "", "hat": "", "glasses": ""},
		"owned": ["basic_shoes", "plain_tee", "plain_shorts"],

		"season": {"games": 0, "wins": 0, "pts": 0, "ast": 0, "reb": 0, "stl": 0, "blk": 0, "tov": 0,
			"fgm": 0, "fga": 0, "tpm": 0, "tpa": 0,
			"high": {"pts": 0, "ast": 0, "reb": 0, "stl": 0, "blk": 0}},
		"muscle": 0.0,           # 0..1: cresce coi pesi, allarga spalle/braccia
		"last_games": [],
		"social": [],
		"messages": [],
		"threads": {},           # contact_id -> Array of chat messages (see Contacts.gd)
		"last_building": "",     # which door to re-emerge from in the city
		"followers": 250,        # social following; team practice feeds it
		"seed": 0,               # fixes the generated league schedule
		"schedule": [],          # league calendar (see Season.gd)
		"skipped_practices": 0,
		"buffs": {},             # id -> {"stat": "...", "mul": 1.1, "until_min": int}
	}

# ---------------------------------------------------------------- attributes
## ---------------------------------------------------------------- appearance
## One source of truth for the look, so a choice made in the creator shows up
## in the city, the gym, the drills AND the match. Previously every scene
## hard-coded its own skin tone and the creator's choice changed nothing.
const SKIN_TONES := [
	Color(0.95, 0.80, 0.68), Color(0.85, 0.66, 0.50), Color(0.66, 0.47, 0.33),
	Color(0.48, 0.33, 0.22), Color(0.32, 0.21, 0.14),
]
const HAIR_COLORS := [
	Color(0.10, 0.08, 0.07), Color(0.35, 0.20, 0.08),
	Color(0.75, 0.65, 0.35), Color(0.60, 0.15, 0.15),
	Color(0.82, 0.72, 0.38), Color(0.55, 0.30, 0.12),
	Color(0.72, 0.72, 0.70), Color(0.90, 0.86, 0.62),
]

func hair_style() -> int:
	## 0 normale, 1 rasato, 2 afro, 3 trecce, 4 ricci.
	return clampi(int(profile.get("hair_style", 0)), 0, 5)

func skin_color() -> Color:
	return SKIN_TONES[clampi(int(profile.get("skin", 1)), 0, SKIN_TONES.size() - 1)]

func hair_color() -> Color:
	return HAIR_COLORS[clampi(int(profile.get("hair", 0)), 0, HAIR_COLORS.size() - 1)]

func shooting_hand() -> float:
	## +1 = right handed, -1 = left handed. Drives which side the ball is
	## dribbled and released from.
	return -1.0 if String(profile.get("hand", "R")) == "L" else 1.0

func attr(a: String) -> int:
	return int(profile["attrs"].get(a, 50))

func attr_eff(a: String) -> float:
	## Attribute after fatigue + buffs. Used by gameplay, never by UI.
	var base := float(attr(a))
	var fatigue := clampf(profile["energy"] / 100.0, 0.35, 1.0)
	var fatigue_sensitive := a in ["speed", "accel", "three", "mid", "defense", "close"]
	if fatigue_sensitive:
		base *= lerpf(0.72, 1.0, fatigue)
	for b in profile["buffs"].values():
		if b.get("stat", "") == a or b.get("stat", "") == "all":
			base *= float(b.get("mul", 1.0))
	return clampf(base, 1.0, 99.0)

func add_xp(amount: int, source := "") -> void:
	profile["xp"] += amount
	Events.xp_gained.emit(amount, source)
	while profile["xp"] >= xp_for_next_level():
		profile["xp"] -= xp_for_next_level()
		profile["level"] += 1
		profile["attr_points"] += 3
		Events.toast.emit("Level %d! +3 attribute points" % profile["level"])
	check_badges()

func xp_for_next_level() -> int:
	return 200 + (profile["level"] - 1) * 120

func spend_point(a: String) -> bool:
	if profile["attr_points"] <= 0: return false
	if attr(a) >= 99: return false
	profile["attr_points"] -= 1
	profile["attrs"][a] += 1
	Events.attribute_up.emit(a, profile["attrs"][a])
	check_badges()
	return true

func check_badges() -> void:
	for id in BADGES:
		if id in profile["badges"]: continue
		var ok := true
		for a in BADGES[id]["req"]:
			if attr(a) < BADGES[id]["req"][a]: ok = false
		if ok:
			profile["badges"].append(id)
			Events.badge_unlocked.emit(id)
			Events.toast.emit("Badge unlocked: %s" % BADGES[id]["name"])
			push_notification("Profile", "New badge", BADGES[id]["name"])

func has_badge(id: String) -> bool:
	return id in profile["badges"]

# ---------------------------------------------------------------- vitals
func add_energy(v: float) -> void:
	profile["energy"] = clampf(profile["energy"] + v, 0.0, 100.0)
	Events.energy_changed.emit(profile["energy"])

func add_hunger(v: float) -> void:
	profile["hunger"] = clampf(profile["hunger"] + v, 0.0, 100.0)
	Events.hunger_changed.emit(profile["hunger"])

## Overall wellness, 0-100. Junk food chips away at it; sleep and good habits
## rebuild it. Dropping to 0 leaves the body running on fumes.
func add_health(v: float) -> void:
	profile["health"] = clampf(profile["health"] + v, 0.0, 100.0)
	Events.health_changed.emit(profile["health"])

func add_money(v: int) -> void:
	profile["money"] = max(0, profile["money"] + v)
	Events.money_changed.emit(profile["money"])

func add_rep(v: int) -> void:
	profile["rep"] = clampi(profile["rep"] + v, 0, 100)
	Events.rep_changed.emit(profile["rep"])

# ---------------------------------------------------------------- clock
func advance_time(mins: int) -> void:
	var before := daypart()
	# Il telefono si scarica col tempo che passa (~0.3%/min: una giornata
	# piena lo porta quasi a zero). Si ricarica lavorando alla scrivania.
	profile["battery"] = clampf(float(profile.get("battery", 100.0)) - float(mins) * 0.30, 0.0, 100.0)
	var old_slot: int = int(profile["minutes"]) / 180
	profile["minutes"] += mins
	while profile["minutes"] >= 1440:
		profile["minutes"] -= 1440
		profile["day"] += 1
		_on_new_day()
		old_slot = -1
	# Weather can shift every ~3 in-game hours, not only at midnight.
	var new_slot: int = int(profile["minutes"]) / 180
	if new_slot != old_slot and old_slot >= 0:
		_roll_weather()
	# passive drain
	add_hunger(-0.045 * mins)
	if profile["hunger"] < 25.0:
		add_energy(-0.02 * mins)
	_expire_buffs()
	Events.time_changed.emit(profile["day"], profile["minutes"])
	if daypart() != before:
		Events.daypart_changed.emit(daypart())

func _on_new_day() -> void:
	_roll_weather()
	Events.day_advanced.emit(profile["day"])
	SaveSystem.save_game()

## Climate: season flips every 10 days. Weather is rolled each morning.
func climate_season() -> String:
	var i: int = int((int(profile.get("day", 1)) - 1) / 10) % 4
	return ["spring", "summer", "autumn", "winter"][i]

func weather() -> String:
	return String(profile.get("weather", "clear"))

func weather_label() -> String:
	var w: String = weather()
	var names := {"clear": "w.clear", "cloudy": "w.cloudy", "rain": "w.rain", "snow": "w.snow"}
	return "%s · %s" % [Loc.t("s." + climate_season()), Loc.t(names.get(w, "w.clear"))]

func _roll_weather() -> void:
	var s: String = climate_season()
	var r := randf()
	var w := "clear"
	match s:
		"summer":
			w = "clear" if r < 0.45 else ("cloudy" if r < 0.78 else "rain")
		"winter":
			w = "snow" if r < 0.42 else ("cloudy" if r < 0.78 else "clear")
		"autumn":
			w = "rain" if r < 0.42 else ("cloudy" if r < 0.80 else "clear")
		_:
			w = "rain" if r < 0.30 else ("cloudy" if r < 0.62 else "clear")
	if w == String(profile.get("weather", "")):
		w = "rain" if w != "rain" else "cloudy"
	profile["weather"] = w

## Kit colours for a match. Team 0 is the player's side. Chosen in the
## scrimmage setup screen and remembered in the profile.
const KITS := {
	"royal":    {"name": "Royal Blue",  "col": Color(0.16, 0.45, 0.85)},
	"scarlet":  {"name": "Scarlet",     "col": Color(0.82, 0.24, 0.24)},
	"forest":   {"name": "Forest",      "col": Color(0.16, 0.52, 0.32)},
	"gold":     {"name": "Gold",        "col": Color(0.90, 0.72, 0.18)},
	"purple":   {"name": "Purple",      "col": Color(0.48, 0.26, 0.68)},
	"teal":     {"name": "Teal",        "col": Color(0.14, 0.60, 0.62)},
	"orange":   {"name": "Orange",      "col": Color(0.92, 0.48, 0.14)},
	"charcoal": {"name": "Charcoal",    "col": Color(0.22, 0.23, 0.28)},
	"white":    {"name": "White",       "col": Color(0.90, 0.90, 0.92)},
	"pink":     {"name": "Hot Pink",    "col": Color(0.90, 0.32, 0.58)},
}

func team_kit(team: int) -> String:
	var key: String = "kit_home" if team == 0 else "kit_away"
	var id: String = String(profile.get(key, ""))
	if id == "" or not KITS.has(id):
		return "royal" if team == 0 else "scarlet"
	return id

func team_colour(team: int) -> Color:
	return Color(KITS[team_kit(team)]["col"])

func set_team_kit(team: int, id: String) -> void:
	if not KITS.has(id):
		return
	profile["kit_home" if team == 0 else "kit_away"] = id

func clock_string() -> String:
	# Difensivo: un salvataggio con "minutes" corrotto/non valido non deve
	# mai rompere la formattazione (l'utente vedeva un orario "NULL").
	var m: int = int(profile.get("minutes", 480)) if profile.get("minutes", null) != null else 480
	m = clampi(m, 0, 1439)
	return "%02d:%02d" % [m / 60, m % 60]

func day_t() -> float:
	## 0..1 normalized time of day, for the day/night shader tint.
	return float(profile["minutes"]) / 1440.0

func daypart() -> String:
	var h: int = int(profile.get("minutes", 480)) / 60 if profile.get("minutes", null) != null else 12
	if h < 11: return "morning"
	if h < 17: return "afternoon"
	if h < 21: return "evening"
	return "night"

## The one day/night ambient colour, keyframed like the city. Every outdoor
## scene (the city AND the street court) multiplies by this, so the park is as
## dark as the street at midnight instead of staying lit like a gym.
func daylight_color() -> Color:
	var h: float = day_t() * 24.0
	if h < 5.5:   return Color(0.28, 0.32, 0.52)
	elif h < 7.5: return Color(0.28, 0.32, 0.52).lerp(Color(1.0, 0.86, 0.72), (h - 5.5) / 2.0)
	elif h < 16.5:return Color(1.0, 0.98, 0.95)
	elif h < 19.5:return Color(1.0, 0.98, 0.95).lerp(Color(0.95, 0.62, 0.42), (h - 16.5) / 3.0)
	elif h < 21.5:return Color(0.95, 0.62, 0.42).lerp(Color(0.30, 0.33, 0.55), (h - 19.5) / 2.0)
	return Color(0.26, 0.30, 0.50)

# ---------------------------------------------------------------- buffs
func add_buff(id: String, stat: String, mul: float, duration_min: int) -> void:
	profile["buffs"][id] = {
		"stat": stat, "mul": mul,
		"until_min": profile["day"] * 1440 + profile["minutes"] + duration_min
	}

func _expire_buffs() -> void:
	var now: int = profile["day"] * 1440 + profile["minutes"]
	for id in profile["buffs"].keys():
		if now >= int(profile["buffs"][id]["until_min"]):
			profile["buffs"].erase(id)

# ---------------------------------------------------------------- phone
func push_notification(app: String, title: String, body: String) -> void:
	Events.phone_notification.emit(app, title, body)

func add_social_post(author: String, text: String, likes: int) -> void:
	var post := {
		"author": author, "text": text, "likes": likes,
		"day": profile["day"], "time": clock_string(), "comments": []
	}
	profile["social"].push_front(post)
	if profile["social"].size() > 60:
		profile["social"].resize(60)
	Events.social_post_added.emit(post)

func add_message(from: String, text: String) -> void:
	profile["messages"].push_front({"from": from, "text": text, "day": profile["day"], "time": clock_string()})
	push_notification("Messages", from, text)

# ---------------------------------------------------------------- physics-ish derived
func mass_factor() -> float:
	## Heavier = slower accel, better at absorbing contact.
	return clampf(85.0 / float(profile["weight_kg"]), 0.75, 1.25)

func height_factor() -> float:
	return clampf(float(profile["height_cm"]) / 190.0, 0.85, 1.2)

# ---------------------------------------------------------- scrimmage clubs
## Club identity for the standalone scrimmage (no league, no season, no
## calendar): names, abbreviations, colours, arenas, play styles and roster
## name pools. Replaces the old Season league module.
const CLUBS := [
	"Riverside Ravens", "Eastport Dockers", "Foundry Hill Kings", "Lakeside Current",
	"Northgate Wolves", "Old Mill Saints", "Bayview Tide", "Cedar Park Rangers",
]
const CLUB_META := {
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

func club_my_team() -> String:
	return String(profile.get("team", "Riverside Ravens"))

func _club_meta(team: String) -> Dictionary:
	if CLUB_META.has(team):
		return CLUB_META[team]
	return {"short": team.left(3).to_upper(), "kit": "scarlet", "arena": team,
		"style": "none", "names": []}

func club_short(team: String) -> String:
	return String(_club_meta(team)["short"])

func club_arena(team: String) -> String:
	return String(_club_meta(team)["arena"])

func club_style(team: String) -> String:
	return String(_club_meta(team)["style"])

func club_roster(team: String) -> Array:
	return _club_meta(team)["names"]

## The kit a club wears. Our side wears the picked kit; the opponent wears
## club colours unless they clash, then the first different kit wins.
func club_kit(team: String) -> String:
	if team == club_my_team():
		return team_kit(0)
	var k := String(_club_meta(team)["kit"])
	if k == team_kit(0):
		for cand in KITS.keys():
			if String(cand) != team_kit(0):
				k = String(cand)
				break
	return k

## The building tonight's scrimmage is played in, honouring next_home.
func scrim_arena() -> String:
	var opp := String(profile.get("next_opponent", ""))
	var home := bool(profile.get("next_home", true))
	return club_arena(club_my_team() if home else opp)
