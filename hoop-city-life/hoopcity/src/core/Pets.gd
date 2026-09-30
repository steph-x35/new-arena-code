extends Node
## Pet ownership: buying animals, their needs, and the mess they make.
##
## Pets live in the apartment. They wander, they keep you company (a small
## daily energy/mood bonus), and they soil the floor if you ignore them. Cleaning
## up and feeding is what keeps the bonus alive -- an untended pet stops helping.

## Each species has its own body plan (see ApartmentRoom._draw_pet_*), its own
## upkeep and its own personality. `shape` selects the drawing routine.
const SPECIES := {
	"dog": {
		"name": "Dog", "price": 320, "shape": "dog",
		"desc": "Loyal and loud. Best company, but needs the most cleaning.",
		"mess_hours": 7.0, "hunger_rate": 1.4, "company": 5.0,
		"col": Color(0.66, 0.47, 0.26), "size": 1.0},
	"cat": {
		"name": "Cat", "price": 240, "shape": "cat",
		"desc": "Independent. Uses the tray, so far less to mop up.",
		"mess_hours": 14.0, "hunger_rate": 0.9, "company": 3.5,
		"col": Color(0.42, 0.42, 0.47), "size": 0.78},
	"parrot": {
		"name": "Parrot", "price": 180, "shape": "bird",
		"desc": "Perches on the shelf and repeats your post-game quotes.",
		"mess_hours": 11.0, "hunger_rate": 0.7, "company": 2.5,
		"col": Color(0.20, 0.72, 0.36), "size": 0.62},
	"turtle": {
		"name": "Turtle", "price": 120, "shape": "turtle",
		"desc": "A domed shell on four stumpy legs. Almost no upkeep.",
		"mess_hours": 26.0, "hunger_rate": 0.35, "company": 1.5,
		"col": Color(0.34, 0.52, 0.30), "size": 0.60},
	"rabbit": {
		"name": "Rabbit", "price": 150, "shape": "rabbit",
		"desc": "Long ears, hops everywhere, chews what it should not.",
		"mess_hours": 9.0, "hunger_rate": 1.0, "company": 3.0,
		"col": Color(0.82, 0.78, 0.72), "size": 0.60},
	"hamster": {
		"name": "Hamster", "price": 70, "shape": "hamster",
		"desc": "A pocket-sized ball of fur. Cheap, tidy, tiny company.",
		"mess_hours": 20.0, "hunger_rate": 0.5, "company": 1.2,
		"col": Color(0.86, 0.68, 0.36), "size": 0.55},
	"snake": {
		"name": "Corn Snake", "price": 260, "shape": "snake",
		"desc": "Coils on the warm patch by the window. Never barks.",
		"mess_hours": 30.0, "hunger_rate": 0.25, "company": 2.0,
		"col": Color(0.78, 0.42, 0.24), "size": 0.70},
	"fish": {
		"name": "Fish Tank", "price": 110, "shape": "fish",
		"desc": "A lit tank on the stand. Calming, and it never soils a floor.",
		"mess_hours": 999.0, "hunger_rate": 0.4, "company": 1.8,
		"col": Color(0.30, 0.62, 0.88), "size": 0.55},
	"lizard": {
		"name": "Gecko", "price": 200, "shape": "lizard",
		"desc": "Wide feet, flat body, basks under the lamp all day.",
		"mess_hours": 24.0, "hunger_rate": 0.4, "company": 2.2,
		"col": Color(0.55, 0.68, 0.34), "size": 0.55},
	"puppy": {
		"name": "Puppy", "price": 380, "shape": "dog",
		"desc": "All the loyalty of a dog, twice the mess. Grows on you.",
		"mess_hours": 5.0, "hunger_rate": 1.8, "company": 5.5,
		"col": Color(0.30, 0.27, 0.25), "size": 0.72},
}

## Beds, bowls and toys. Accessories raise the company bonus and slow the mess.
const ACCESSORIES := {
	"bed_basic":  {"name": "Wicker Basket", "price": 60,  "company": 1.0, "mess_mult": 1.0,  "kind": "bed"},
	"bed_plush":  {"name": "Plush Lounger", "price": 180, "company": 2.5, "mess_mult": 1.0,  "kind": "bed"},
	"tray":       {"name": "Litter Tray",   "price": 70,  "company": 0.0, "mess_mult": 0.45, "kind": "hygiene"},
	"puppy_pad":  {"name": "Floor Pads",    "price": 40,  "company": 0.0, "mess_mult": 0.65, "kind": "hygiene"},
	"toy_rope":   {"name": "Rope Toy",      "price": 35,  "company": 1.0, "mess_mult": 1.0,  "kind": "toy"},
	"scratcher":  {"name": "Scratch Post",  "price": 90,  "company": 1.5, "mess_mult": 1.0,  "kind": "toy"},
	"food_bag":   {"name": "Food Sack x10", "price": 50,  "company": 0.0, "mess_mult": 1.0,  "kind": "food"},
}

func _ready() -> void:
	Events.day_advanced.connect(_on_day)

# ------------------------------------------------------------------ state
func _state() -> Dictionary:
	## Lazily create the pet block so old save files keep loading.
	if not Game.profile.has("pets"):
		Game.profile["pets"] = {"owned": [], "accessories": [], "food": 0, "messes": []}
	var p: Dictionary = Game.profile["pets"]
	for k in ["owned", "accessories", "messes"]:
		if not p.has(k):
			p[k] = []
	if not p.has("food"):
		p["food"] = 0
	return p

func owned() -> Array:
	return _state()["owned"]

func accessories() -> Array:
	return _state()["accessories"]

func food() -> int:
	return int(_state()["food"])

func messes() -> Array:
	return _state()["messes"]

func has_accessory(id: String) -> bool:
	return id in accessories()

# ------------------------------------------------------------------ buying
func can_buy_pet(species: String) -> bool:
	return SPECIES.has(species) and Game.profile["money"] >= SPECIES[species]["price"]

func buy_pet(species: String, pet_name: String) -> bool:
	if not can_buy_pet(species):
		return false
	var price: int = int(SPECIES[species]["price"])
	Game.add_money(-price)
	_state()["owned"].append({
		"species": species,
		"name": pet_name if pet_name != "" else String(SPECIES[species]["name"]),
		"hunger": 100.0,       # 100 = full
		"since_mess": 0.0,     # hours since it last soiled the floor
		"x": randf_range(0.25, 0.75),
	})
	Events.toast.emit("%s joined you at home" % pet_name)
	SaveSystem.save_game()
	return true

func buy_accessory(id: String) -> bool:
	if not ACCESSORIES.has(id):
		return false
	var price: int = int(ACCESSORIES[id]["price"])
	if Game.profile["money"] < price:
		return false
	Game.add_money(-price)
	if id == "food_bag":
		_state()["food"] = food() + 10
		Events.toast.emit("+10 pet food")
	else:
		if has_accessory(id):
			return false
		_state()["accessories"].append(id)
		Events.toast.emit("%s delivered to your flat" % ACCESSORIES[id]["name"])
	SaveSystem.save_game()
	return true

# ------------------------------------------------------------------ care
func feed(index: int) -> bool:
	var list: Array = owned()
	if index < 0 or index >= list.size():
		return false
	if food() <= 0:
		Events.toast.emit("No pet food left")
		return false
	_state()["food"] = food() - 1
	list[index]["hunger"] = 100.0
	Events.toast.emit("%s fed" % list[index]["name"])
	SaveSystem.save_game()
	return true

func clean(index: int) -> bool:
	## Mop up one mess. Takes 10 minutes of your day.
	var m: Array = messes()
	if index < 0 or index >= m.size():
		return false
	m.remove_at(index)
	Game.advance_time(10)
	Events.toast.emit("Cleaned up")
	SaveSystem.save_game()
	return true

func clean_all() -> int:
	var n: int = messes().size()
	if n == 0:
		return 0
	_state()["messes"] = []
	Game.advance_time(8 * n)
	Events.toast.emit("Floor clean again")
	SaveSystem.save_game()
	return n

## The daily payoff. A fed pet on a clean floor lifts your energy; a hungry one
## on a filthy floor drags it down. This is why the chores matter.
func company_bonus() -> float:
	var list: Array = owned()
	if list.is_empty():
		return 0.0
	var total := 0.0
	for p in list:
		var sp: Dictionary = SPECIES.get(String(p["species"]), {})
		if sp.is_empty():
			continue
		var care: float = clampf(float(p["hunger"]) / 100.0, 0.0, 1.0)
		total += float(sp["company"]) * care
	for a in accessories():
		total += float(ACCESSORIES[a]["company"])
	# Filth cancels the benefit fast.
	total -= float(messes().size()) * 2.5
	return clampf(total, -8.0, 14.0)

func mess_multiplier() -> float:
	var m := 1.0
	for a in accessories():
		m = minf(m, float(ACCESSORIES[a]["mess_mult"]))
	return m

## Called by Game.advance_time via the hour tick: pets get hungrier and
## eventually soil the floor.
func tick_hours(hours: float) -> void:
	var list: Array = owned()
	if list.is_empty():
		return
	var mult: float = mess_multiplier()
	for p in list:
		var sp: Dictionary = SPECIES.get(String(p["species"]), {})
		if sp.is_empty():
			continue
		p["hunger"] = clampf(float(p["hunger"]) - float(sp["hunger_rate"]) * hours, 0.0, 100.0)
		p["since_mess"] = float(p["since_mess"]) + hours
		var due: float = float(sp["mess_hours"]) / maxf(mult, 0.05)
		# A starving animal cannot hold on as long.
		if float(p["hunger"]) < 25.0:
			due *= 0.6
		if p["since_mess"] >= due and messes().size() < 6:
			p["since_mess"] = 0.0
			messes().append({"x": randf_range(0.15, 0.85),
				"kind": "wet" if randf() < 0.4 else "solid"})

func _on_day(_d: int) -> void:
	var b: float = company_bonus()
	if b > 0.0:
		Game.add_energy(b)
		Events.toast.emit("Your pets kept you going (+%d energy)" % int(b))
	elif b < 0.0:
		Game.add_energy(b)
		Events.toast.emit("The flat is a mess (%d energy)" % int(b))
