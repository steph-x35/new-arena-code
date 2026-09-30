extends Node
## Central item database (autoload `Items`). Food, drinks and clothing.
## Every entry carries what it does AND how to draw it, so the UI stays pretty
## without needing any image assets.

const FOOD := {
	"eggs":        {"name": "Eggs",          "hunger": 18, "energy": 6,  "price": 6,
					"buff": ["stamina", 1.04, 240], "col": Color(0.97, 0.93, 0.80), "shape": "egg",
					"desc": "Cheap protein. Good before a morning session."},
	"milk":        {"name": "Milk",          "hunger": 12, "energy": 5,  "price": 5,
					"buff": ["stamina", 1.03, 180], "col": Color(0.95, 0.96, 0.98), "shape": "carton",
					"desc": "Cold, simple, does the job."},
	"chicken":     {"name": "Chicken & rice","hunger": 48, "energy": 18, "price": 18,
					"buff": ["all", 1.05, 480],     "col": Color(0.86, 0.68, 0.42), "shape": "plate",
					"desc": "The staple. Full recovery meal, long buff."},
	"pasta":       {"name": "Pasta bowl",    "hunger": 42, "energy": 22, "price": 14,
					"buff": ["stamina", 1.08, 420], "col": Color(0.95, 0.82, 0.45), "shape": "bowl",
					"desc": "Carb load. Great the night before a game."},
	"salad":       {"name": "Green salad",   "hunger": 22, "energy": 10, "price": 9,
					"buff": ["speed", 1.04, 300],   "col": Color(0.45, 0.78, 0.42), "shape": "bowl",
					"desc": "Light. Keeps you quick."},
	"protein_bar": {"name": "Protein bar",   "hunger": 14, "energy": 10, "price": 8,
					"buff": ["stamina", 1.06, 240], "col": Color(0.60, 0.42, 0.26), "shape": "bar",
					"desc": "Pocket fuel. Eat on the way out."},
	"energy_drink":{"name": "Energy drink",  "hunger": -2, "energy": 34, "price": 12,
					"buff": ["speed", 1.09, 120],   "col": Color(0.35, 0.85, 0.95), "shape": "can",
					"desc": "Big energy spike, tiny crash later."},
	"smoothie":    {"name": "Berry smoothie","hunger": 24, "energy": 20, "price": 11,
					"buff": ["all", 1.03, 240],     "col": Color(0.78, 0.35, 0.62), "shape": "cup",
					"desc": "Recovery in a glass."},
	"pizza":       {"name": "Pizza slice",   "hunger": 38, "energy": 14, "price": 10,
					"buff": ["stamina", 0.97, 180], "junk": true, "health": -12,
					"col": Color(0.90, 0.55, 0.25), "shape": "pizza",
					"desc": "Tastes great. Coach would not approve."},
	"fruit":       {"name": "Fruit salad",   "hunger": 16, "energy": 14, "price": 7,
					"buff": ["accel", 1.04, 240],  "col": Color(0.98, 0.62, 0.30), "shape": "bowl",
					"desc": "Zuccheri buoni: energia immediata senza pesare."},
	"water":       {"name": "Water bottle",  "hunger": 4,  "energy": 12, "price": 3,
					"buff": ["all", 1.02, 180],     "col": Color(0.55, 0.80, 0.95), "shape": "bottle",
					"desc": "Hydration is free performance."},

	# --- breakfast & light bites ---
	"oatmeal":     {"name": "Oatmeal",       "hunger": 30, "energy": 16, "price": 7,
					"buff": ["stamina", 1.06, 360], "col": Color(0.85, 0.78, 0.62), "shape": "bowl",
					"desc": "Slow-release fuel. Boring, effective."},
	"banana":      {"name": "Banana",        "hunger": 10, "energy": 9,  "price": 2,
					"buff": ["stamina", 1.03, 150], "col": Color(0.96, 0.85, 0.30), "shape": "bar",
					"desc": "Cramp insurance for two bucks."},
	"yogurt":      {"name": "Greek yogurt",  "hunger": 16, "energy": 8,  "price": 5,
					"buff": ["all", 1.02, 200],     "col": Color(0.97, 0.96, 0.92), "shape": "cup",
					"desc": "Protein without the heaviness."},
	"sandwich":    {"name": "Turkey sandwich","hunger": 34,"energy": 15, "price": 11,
					"buff": ["stamina", 1.05, 300], "col": Color(0.88, 0.74, 0.50), "shape": "plate",
					"desc": "Lunch that will not slow you down."},

	# --- serious meals ---
	"steak":       {"name": "Steak dinner",  "hunger": 55, "energy": 22, "price": 32,
					"buff": ["all", 1.07, 600],     "col": Color(0.62, 0.28, 0.24), "shape": "plate",
					"desc": "Expensive, but the buff runs all day."},
	"salmon":      {"name": "Salmon bowl",   "hunger": 46, "energy": 24, "price": 26,
					"buff": ["all", 1.06, 540],     "col": Color(0.94, 0.55, 0.42), "shape": "bowl",
					"desc": "Clean recovery. Pros eat this."},
	"burrito":     {"name": "Big burrito",   "hunger": 50, "energy": 20, "price": 13,
					"buff": ["stamina", 1.04, 300], "col": Color(0.80, 0.68, 0.42), "shape": "bar",
					"desc": "Cheap and enormous. Sits heavy."},
	"burger":      {"name": "Double burger", "hunger": 52, "energy": 16, "price": 15,
					"buff": ["speed", 0.95, 240],   "junk": true, "health": -15,
					"col": Color(0.72, 0.45, 0.24), "shape": "plate",
					"desc": "Fills you up, weighs you down."},
	"ramen":       {"name": "Ramen",         "hunger": 40, "energy": 18, "price": 12,
					"buff": ["stamina", 1.05, 330], "col": Color(0.90, 0.72, 0.38), "shape": "bowl",
					"desc": "Late-night comfort food."},
	"sushi":       {"name": "Sushi set",     "hunger": 38, "energy": 20, "price": 28,
					"buff": ["speed", 1.06, 420],   "col": Color(0.94, 0.62, 0.58), "shape": "plate",
					"desc": "Light but satisfying. Keeps you sharp."},

	# --- drinks ---
	"coffee":      {"name": "Coffee",        "hunger": 0,  "energy": 26, "price": 4,
					"buff": ["accel", 1.05, 150],   "col": Color(0.36, 0.24, 0.17), "shape": "cup",
					"desc": "Wakes you up. Wears off fast."},
	"green_tea":   {"name": "Green tea",     "hunger": 2,  "energy": 14, "price": 4,
					"buff": ["all", 1.03, 260],     "col": Color(0.55, 0.75, 0.45), "shape": "cup",
					"desc": "Calm focus, no crash."},
	"orange_juice":{"name": "Orange juice",  "hunger": 12, "energy": 18, "price": 6,
					"buff": ["stamina", 1.04, 210], "col": Color(0.98, 0.62, 0.18), "shape": "carton",
					"desc": "Sugar and vitamins in one glass."},
	"sports_drink":{"name": "Sports drink",  "hunger": 6,  "energy": 28, "price": 7,
					"buff": ["stamina", 1.07, 240], "col": Color(0.45, 0.85, 0.55), "shape": "bottle",
					"desc": "Electrolytes. Best mid-session."},
	"choc_milk":   {"name": "Chocolate milk","hunger": 20, "energy": 20, "price": 6,
					"buff": ["all", 1.04, 300],     "col": Color(0.48, 0.32, 0.22), "shape": "carton",
					"desc": "The classic recovery drink. Actually works."},
	"espresso":    {"name": "Espresso",      "hunger": 0,  "energy": 18, "price": 2,
					"buff": ["accel", 1.06, 120],  "col": Color(0.24, 0.15, 0.10), "shape": "cup",
					"desc": "Il rito italiano: scatto secco, breve."},
	"lemonade":    {"name": "Lemonade",      "hunger": 5,  "energy": 10, "price": 4,
					"buff": ["stamina", 1.03, 240], "col": Color(0.95, 0.90, 0.40), "shape": "cup",
					"desc": "Fresca e salina: perfetta nei pomeriggi d'estate."},
	"iced_tea":    {"name": "Iced tea",      "hunger": 4,  "energy": 9,  "price": 3,
					"buff": ["all", 1.02, 200],    "col": Color(0.85, 0.70, 0.30), "shape": "bottle",
					"desc": "Leggera, dissetante, mai pesante."},
	"mate":        {"name": "Mate",          "hunger": 0,  "energy": 22, "price": 5,
					"buff": ["accel", 1.04, 200],  "col": Color(0.55, 0.62, 0.30), "shape": "cup",
					"desc": "Energia lunga da erba mate: il sottofondista dei campi sudamericani."},
	"soda":        {"name": "Soda",          "hunger": 6,  "energy": 16, "price": 3,
					"buff": ["stamina", 0.96, 150], "junk": true, "health": -8,
					"col": Color(0.75, 0.25, 0.30), "shape": "can",
					"desc": "Quick lift, then a slump."},

	# --- supplements ---
	"protein_shake":{"name": "Protein shake","hunger": 22, "energy": 16, "price": 14,
					"buff": ["all", 1.05, 420],     "col": Color(0.85, 0.80, 0.68), "shape": "cup",
					"desc": "Built for lifting days."},
	"creatine":    {"name": "Creatine",      "hunger": 0,  "energy": 6,  "price": 22,
					"buff": ["all", 1.06, 720],     "col": Color(0.92, 0.92, 0.95), "shape": "can",
					"desc": "Long, steady boost. Stack it with weights."},
	"recovery_kit":{"name": "Recovery kit",  "hunger": 8,  "energy": 45, "price": 45,
					"buff": ["all", 1.08, 480],     "col": Color(0.40, 0.85, 0.80), "shape": "can",
					"desc": "Ice, salts and rest. Resets a rough day."},

	# --- junk food: cheap and tasty, but it hurts your health ---
	"fries":       {"name": "Loaded fries",  "hunger": 34, "energy": 10, "price": 7,
					"buff": ["speed", 0.94, 180],   "junk": true, "health": -14,
					"col": Color(0.95, 0.78, 0.30), "shape": "plate",
					"desc": "Greasy, salty, gone in a minute. Not a meal."},
	"donut":       {"name": "Glazed donut",  "hunger": 20, "energy": 12, "price": 4,
					"buff": ["speed", 0.93, 120],   "junk": true, "health": -10,
					"col": Color(0.88, 0.60, 0.70), "shape": "plate",
					"desc": "Pure sugar. A morning spike, then a crash."},
	"hotdog":      {"name": "Street hotdog", "hunger": 30, "energy": 8,  "price": 6,
					"buff": ["stamina", 0.95, 150], "junk": true, "health": -13,
					"col": Color(0.75, 0.48, 0.26), "shape": "plate",
					"desc": "From a cart on the corner. Delicious and wrong."},
	"candy_bar":   {"name": "Candy bar",     "hunger": 12, "energy": 14, "price": 3,
					"buff": ["accel", 0.96, 90],    "junk": true, "health": -7,
					"col": Color(0.72, 0.40, 0.85), "shape": "bar",
					"desc": "A two-minute sugar rush."},
	"milkshake":   {"name": "Milkshake",     "hunger": 26, "energy": 18, "price": 8,
					"buff": ["speed", 0.95, 150],   "junk": true, "health": -11,
					"col": Color(0.92, 0.72, 0.82), "shape": "cup",
					"desc": "Dessert pretending to be a drink."},
	"avocado":     {"name": "Avocado toast", "hunger": 28, "energy": 14, "price": 9,
					"buff": ["stamina", 1.04, 240], "col": Color(0.45, 0.62, 0.28), "shape": "plate",
					"desc": "Green fuel. Light and filling."},
	"poke":        {"name": "Poke bowl",     "hunger": 44, "energy": 22, "price": 19,
					"buff": ["speed", 1.05, 360],   "col": Color(0.90, 0.45, 0.38), "shape": "bowl",
					"desc": "Fresh fish, rice, crunch. Game-day lunch."},
	"waffles":     {"name": "Protein waffles","hunger": 32, "energy": 16, "price": 10,
					"buff": ["stamina", 1.04, 240], "col": Color(0.92, 0.74, 0.42), "shape": "plate",
					"desc": "Breakfast that actually sticks."},
	"wrap":        {"name": "Chicken wrap",  "hunger": 36, "energy": 16, "price": 11,
					"buff": ["accel", 1.03, 240],   "col": Color(0.82, 0.62, 0.38), "shape": "bar",
					"desc": "Eat it walking to the gym."},
	"curry":       {"name": "Chicken curry", "hunger": 50, "energy": 20, "price": 16,
					"buff": ["all", 1.05, 420],     "col": Color(0.86, 0.52, 0.22), "shape": "bowl",
					"desc": "Warm, heavy, long buff."},
	"iced_latte":  {"name": "Iced latte",    "hunger": 4,  "energy": 22, "price": 5,
					"buff": ["accel", 1.04, 160],   "col": Color(0.62, 0.48, 0.36), "shape": "cup",
					"desc": "Cold coffee. Fast first step."},
	"kombucha":    {"name": "Kombucha",      "hunger": 4,  "energy": 10, "price": 6,
					"buff": ["all", 1.02, 180],     "col": Color(0.78, 0.52, 0.28), "shape": "bottle",
					"desc": "Gut check in a bottle."},
	"coconut":     {"name": "Coconut water", "hunger": 8,  "energy": 16, "price": 5,
					"buff": ["stamina", 1.05, 200], "col": Color(0.88, 0.92, 0.86), "shape": "carton",
					"desc": "Natural electrolytes."},
	"bcaa":        {"name": "BCAA drink",    "hunger": 0,  "energy": 12, "price": 16,
					"buff": ["stamina", 1.08, 360], "col": Color(0.95, 0.45, 0.55), "shape": "bottle",
					"desc": "Sips between sets."},
	"nachos":      {"name": "Nachos",        "hunger": 36, "energy": 10, "price": 8,
					"buff": ["speed", 0.93, 160],   "junk": true, "health": -13,
					"col": Color(0.95, 0.72, 0.28), "shape": "plate",
					"desc": "Game on TV. Not a meal."},
	"ice_cream":   {"name": "Ice cream",     "hunger": 18, "energy": 12, "price": 5,
					"buff": ["stamina", 0.96, 90],  "junk": true, "health": -8,
					"col": Color(0.98, 0.90, 0.78), "shape": "cup",
					"desc": "Treat yourself. Coach sighs."},
}

const WEAR := {
	"plain_tee":     {"name": "Plain tee",     "price": 0,   "col": Color(0.22, 0.24, 0.28), "slot": "jersey"},
	"plain_shorts":  {"name": "Plain shorts",  "price": 0,   "col": Color(0.18, 0.18, 0.22), "slot": "shorts"},
	"game_kit":      {"name": "Game kit",      "price": 280, "col": Color(0.16, 0.45, 0.85), "slot": "jersey",
					  "pattern": "side", "desc": "Official match jersey. Wear it in the city — 1v1 and scrimmage always use the team kit."},
	"game_kit_away": {"name": "Away game kit", "price": 260, "col": Color(0.92, 0.92, 0.95), "slot": "jersey",
					  "pattern": "side", "desc": "White away kit you can wear off the court."},
	# Stylized NBA-inspired city jerseys (names are original, colours nod at teams).
	"nba_lakers":   {"name": "Sunset Kings",   "price": 320, "col": Color(0.55, 0.18, 0.72), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.95, 0.78, 0.18), "desc": "Purple & gold city cut."},
	"nba_celtics":  {"name": "Garden Green",   "price": 320, "col": Color(0.05, 0.45, 0.28), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.95, 0.95, 0.92), "desc": "Shamrock-green home."},
	"nba_bulls":    {"name": "Windy Red",      "price": 320, "col": Color(0.78, 0.08, 0.12), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.12, 0.12, 0.12), "desc": "Chi-town red."},
	"nba_knicks":   {"name": "Garden Orange",  "price": 300, "col": Color(0.14, 0.22, 0.55), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.92, 0.42, 0.12), "desc": "Blue & orange."},
	"nba_heat":     {"name": "Vice Night",     "price": 320, "col": Color(0.55, 0.05, 0.18), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.95, 0.55, 0.12), "desc": "Wine & gold heat."},
	"nba_warriors": {"name": "Bay Gold",       "price": 340, "col": Color(0.12, 0.28, 0.62), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.95, 0.78, 0.18), "desc": "Royal blue splash."},
	"nba_spurs":    {"name": "Alamo Silver",   "price": 280, "col": Color(0.72, 0.74, 0.78), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.18, 0.18, 0.22), "desc": "Silver & black."},
	"nba_suns":     {"name": "Desert Sun",     "price": 300, "col": Color(0.92, 0.42, 0.08), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.35, 0.12, 0.55), "desc": "Orange & purple."},
	"nba_mavs":     {"name": "Lone Star",      "price": 300, "col": Color(0.05, 0.35, 0.72), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.85, 0.88, 0.92), "desc": "Royal Dallas blue."},
	"nba_nuggets":  {"name": "Mile High",      "price": 300, "col": Color(0.08, 0.18, 0.42), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.95, 0.72, 0.12), "desc": "Navy & gold."},
	"nba_bucks":    {"name": "Deer Green",     "price": 300, "col": Color(0.10, 0.42, 0.22), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.85, 0.88, 0.20), "desc": "Forest cream."},
	"nba_sixers":   {"name": "Liberty Blue",   "price": 300, "col": Color(0.05, 0.28, 0.62), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.82, 0.12, 0.18), "desc": "Blue & red."},
	"nba_nets":     {"name": "Borough Black",  "price": 280, "col": Color(0.10, 0.10, 0.12), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.92, 0.92, 0.94), "desc": "Black & white."},
	"nba_raptors":  {"name": "North Red",      "price": 300, "col": Color(0.72, 0.08, 0.16), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.18, 0.18, 0.20), "desc": "Raptor red."},
	"nba_cavs":     {"name": "Wine Land",      "price": 300, "col": Color(0.48, 0.08, 0.16), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.95, 0.72, 0.18), "desc": "Wine & gold."},
	"nba_thunder":  {"name": "Storm Blue",     "price": 300, "col": Color(0.05, 0.45, 0.78), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.92, 0.35, 0.12), "desc": "OKC sky."},
	"nba_wolves":   {"name": "North Woods",    "price": 280, "col": Color(0.08, 0.22, 0.42), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.10, 0.55, 0.38), "desc": "Blue & green."},
	"nba_pels":     {"name": "Bayou Navy",     "price": 280, "col": Color(0.05, 0.16, 0.38), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.72, 0.12, 0.22), "desc": "Navy & red."},
	"nba_kings":    {"name": "River Purple",   "price": 280, "col": Color(0.42, 0.22, 0.68), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.72, 0.74, 0.78), "desc": "Royal purple."},
	"nba_clips":    {"name": "Harbor Red",     "price": 300, "col": Color(0.78, 0.12, 0.22), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.12, 0.28, 0.62), "desc": "Red & blue."},
	"nba_hawks":    {"name": "Peach Red",      "price": 280, "col": Color(0.82, 0.12, 0.18), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.95, 0.95, 0.95), "desc": "Atlanta red."},
	"nba_hornets":  {"name": "Queen Teal",     "price": 280, "col": Color(0.08, 0.62, 0.68), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.18, 0.12, 0.42), "desc": "Teal sting."},
	"nba_pacers":   {"name": "Hoosier Navy",   "price": 280, "col": Color(0.05, 0.18, 0.42), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.95, 0.72, 0.12), "desc": "Navy & gold."},
	"nba_magic":    {"name": "Orlando Blue",   "price": 280, "col": Color(0.05, 0.38, 0.72), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.85, 0.88, 0.92), "desc": "Magic blue."},
	"nba_jazz":     {"name": "Wasatch Navy",   "price": 280, "col": Color(0.05, 0.12, 0.32), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.95, 0.72, 0.18), "desc": "Navy & gold."},
	"nba_grizz":    {"name": "River Beale",    "price": 280, "col": Color(0.35, 0.52, 0.72), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.12, 0.18, 0.32), "desc": "Beale Street blue."},
	"nba_rockets":  {"name": "Space Red",      "price": 300, "col": Color(0.78, 0.08, 0.16), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.72, 0.74, 0.78), "desc": "H-town red."},
	"nba_blazers":  {"name": "Rose City",      "price": 300, "col": Color(0.72, 0.08, 0.16), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.12, 0.12, 0.14), "desc": "Red & black."},
	"nba_wiz":      {"name": "Capitol Blue",   "price": 280, "col": Color(0.05, 0.22, 0.55), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.78, 0.12, 0.18), "desc": "Navy & red."},
	"nba_pistons":  {"name": "Motor City",     "price": 280, "col": Color(0.78, 0.12, 0.18), "slot": "jersey", "nba": true, "pattern": "side", "accent": Color(0.12, 0.22, 0.55), "desc": "Red & blue."},
	"team_home":     {"name": "Team jersey",   "price": 90,  "col": Color(0.16, 0.45, 0.85), "slot": "jersey"},
	"street_hoodie": {"name": "Street hoodie", "price": 90,  "col": Color(0.28, 0.28, 0.34), "slot": "jersey"},
	"gold_tee":      {"name": "Gold tee",      "price": 140, "col": Color(0.87, 0.72, 0.24), "slot": "jersey"},
	"red_jacket":    {"name": "Red jacket",    "price": 180, "col": Color(0.80, 0.25, 0.24), "slot": "jersey"},
	"basic_shoes":   {"name": "Basic sneakers","price": 0,   "col": Color(0.90, 0.90, 0.92), "slot": "shoes"},
	"elite_shoes":   {"name": "Elite runners", "price": 260, "col": Color(0.20, 0.85, 0.70), "slot": "shoes",
					  "buff": ["speed", 1.05]},
	"court_kings":   {"name": "Court Kings",   "price": 420, "col": Color(0.95, 0.45, 0.15), "slot": "shoes",
					  "buff": ["accel", 1.06]},

	# --- more tops ---
	"team_away":     {"name": "Away jersey",   "price": 60,  "col": Color(0.92, 0.92, 0.95), "slot": "jersey"},
	"black_tee":     {"name": "Black tee",     "price": 45,  "col": Color(0.14, 0.14, 0.17), "slot": "jersey"},
	"tank_top":      {"name": "Cutoff tank",   "price": 55,  "col": Color(0.30, 0.68, 0.55), "slot": "jersey",
					  "buff": ["stamina", 1.02]},
	"warmup_jacket": {"name": "Warmup jacket", "price": 210, "col": Color(0.20, 0.32, 0.60), "slot": "jersey",
					  "buff": ["stamina", 1.04]},
	"retro_jersey":  {"name": "Retro jersey",  "price": 320, "col": Color(0.75, 0.55, 0.20), "slot": "jersey",
					  "buff": ["all", 1.03]},

	# --- shorts ---
	"team_shorts":   {"name": "Team shorts",   "price": 0,   "col": Color(0.18, 0.40, 0.75), "slot": "shorts"},
	"mesh_shorts":   {"name": "Mesh shorts",   "price": 40,  "col": Color(0.35, 0.35, 0.40), "slot": "shorts",
					  "buff": ["speed", 1.02]},
	"compression":   {"name": "Compression",   "price": 130, "col": Color(0.12, 0.12, 0.16), "slot": "shorts",
					  "buff": ["stamina", 1.05]},
	"street_cargo":  {"name": "Cargo shorts",  "price": 75,  "col": Color(0.52, 0.48, 0.36), "slot": "shorts"},

	# --- more shoes ---
	"canvas_lows":   {"name": "Canvas lows",   "price": 70,  "col": Color(0.85, 0.82, 0.74), "slot": "shoes"},
	"grip_hi":       {"name": "Grip hi-tops",  "price": 340, "col": Color(0.22, 0.26, 0.35), "slot": "shoes",
					  "buff": ["defense", 1.05]},
	"air_zoom":      {"name": "Skyline Zooms", "price": 520, "col": Color(0.90, 0.20, 0.45), "slot": "shoes",
					  "buff": ["speed", 1.07]},

	# --- accessories: a whole new slot ---
	"headband":      {"name": "Headband",      "price": 25,  "col": Color(0.88, 0.24, 0.24), "slot": "acc",
					  "buff": ["stamina", 1.02]},
	"wristbands":    {"name": "Wristbands",    "price": 20,  "col": Color(0.95, 0.95, 0.95), "slot": "acc",
					  "buff": ["handle", 1.02]},
	"arm_sleeve":    {"name": "Arm sleeve",    "price": 65,  "col": Color(0.18, 0.18, 0.22), "slot": "acc",
					  "buff": ["mid", 1.04]},
	"knee_brace":    {"name": "Knee brace",    "price": 110, "col": Color(0.35, 0.35, 0.38), "slot": "acc",
					  "buff": ["defense", 1.04]},
	"gold_chain":    {"name": "Gold chain",    "price": 380, "col": Color(0.95, 0.80, 0.25), "slot": "acc",
					  "buff": ["all", 1.02]},
	"shooting_glove":{"name": "Shooting glove","price": 240, "col": Color(0.25, 0.30, 0.42), "slot": "acc",
					  "buff": ["three", 1.06]},

	# --- patterned kit. Same slots, but stripes and blocks so the racks are
	# full of genuinely different-looking gear rather than colour swatches.
	"stripe_jersey": {"name": "Striped jersey", "price": 95,  "col": Color(0.18, 0.42, 0.78), "slot": "jersey", "pattern": "stripes"},
	"hoops_tee":     {"name": "Hooped tee",     "price": 85,  "col": Color(0.86, 0.34, 0.28), "slot": "jersey", "pattern": "stripes"},
	"pinstripe":     {"name": "Pinstripe top",  "price": 165, "col": Color(0.14, 0.16, 0.24), "slot": "jersey", "pattern": "vstripe",
					  "buff": ["mid", 1.03]},
	"block_jersey":  {"name": "Colour block",   "price": 175, "col": Color(0.30, 0.62, 0.45), "slot": "jersey", "pattern": "band"},
	"check_shirt":   {"name": "Checked shirt",  "price": 120, "col": Color(0.62, 0.30, 0.32), "slot": "jersey", "pattern": "checks"},
	"gold_stripe":   {"name": "Gold-trim top",  "price": 290, "col": Color(0.20, 0.20, 0.26), "slot": "jersey", "pattern": "side",
					  "buff": ["three", 1.04]},

	"stripe_shorts": {"name": "Striped shorts", "price": 65,  "col": Color(0.22, 0.24, 0.32), "slot": "shorts", "pattern": "side"},
	"retro_shorts":  {"name": "Retro shorts",   "price": 110, "col": Color(0.80, 0.72, 0.35), "slot": "shorts", "pattern": "stripes"},
	"team_stripe":   {"name": "Team stripes",   "price": 145, "col": Color(0.16, 0.38, 0.72), "slot": "shorts", "pattern": "vstripe",
					  "buff": ["speed", 1.03]},
	"camo_shorts":   {"name": "Camo shorts",    "price": 130, "col": Color(0.38, 0.42, 0.30), "slot": "shorts", "pattern": "checks"},

	"stripe_lows":   {"name": "Striped lows",   "price": 190, "col": Color(0.92, 0.92, 0.94), "slot": "shoes", "pattern": "side"},
	"twotone_hi":    {"name": "Two-tone highs", "price": 380, "col": Color(0.25, 0.45, 0.85), "slot": "shoes", "pattern": "band",
					  "buff": ["accel", 1.04]},
	"flash_runner":  {"name": "Flash runners",  "price": 450, "col": Color(0.95, 0.72, 0.15), "slot": "shoes", "pattern": "stripes",
					  "buff": ["speed", 1.05]},

	"stripe_band":   {"name": "Striped band",   "price": 35,  "col": Color(0.30, 0.55, 0.85), "slot": "acc", "pattern": "stripes"},

	# --- hats
	"cap_navy":      {"name": "Navy cap",       "price": 45,  "col": Color(0.16, 0.22, 0.42), "slot": "hat"},
	"cap_red":       {"name": "Red cap",        "price": 45,  "col": Color(0.78, 0.22, 0.20), "slot": "hat"},
	"cap_white":     {"name": "White cap",      "price": 50,  "col": Color(0.92, 0.92, 0.94), "slot": "hat"},
	"cap_stripe":    {"name": "Striped cap",    "price": 70,  "col": Color(0.22, 0.48, 0.38), "slot": "hat", "pattern": "stripes"},
	"beanie_grey":   {"name": "Grey beanie",    "price": 40,  "col": Color(0.45, 0.46, 0.50), "slot": "hat"},
	"beanie_gold":   {"name": "Gold beanie",    "price": 95,  "col": Color(0.85, 0.68, 0.22), "slot": "hat",
					  "buff": ["stamina", 1.03]},
	"bucket_camo":   {"name": "Camo bucket",    "price": 110, "col": Color(0.40, 0.44, 0.32), "slot": "hat", "pattern": "checks"},
	"visor_black":   {"name": "Black visor",    "price": 60,  "col": Color(0.15, 0.15, 0.18), "slot": "hat"},

	# --- glasses
	"shades_black":  {"name": "Black shades",   "price": 55,  "col": Color(0.12, 0.12, 0.15), "slot": "glasses"},
	"shades_amber":  {"name": "Amber shades",   "price": 75,  "col": Color(0.80, 0.55, 0.20), "slot": "glasses"},
	"shades_blue":   {"name": "Blue mirrors",   "price": 120, "col": Color(0.25, 0.55, 0.85), "slot": "glasses"},
	"shades_rose":   {"name": "Rose tint",      "price": 90,  "col": Color(0.86, 0.42, 0.52), "slot": "glasses"},
	"specs_clear":   {"name": "Clear frames",   "price": 65,  "col": Color(0.70, 0.74, 0.80), "slot": "glasses"},
	"specs_tort":    {"name": "Tortoiseshell",  "price": 130, "col": Color(0.42, 0.26, 0.14), "slot": "glasses",
					  "buff": ["pass", 1.03]},
	"goggles_sport": {"name": "Sport goggles",  "price": 180, "col": Color(0.20, 0.60, 0.55), "slot": "glasses",
					  "buff": ["defense", 1.04]},
	"shades_gold":   {"name": "Gold aviators",  "price": 240, "col": Color(0.90, 0.76, 0.30), "slot": "glasses",
					  "buff": ["all", 1.02]},
	"captain_band":  {"name": "Captain armband","price": 150, "col": Color(0.85, 0.68, 0.20), "slot": "acc", "pattern": "band",
					  "buff": ["all", 1.02]},
	"neon_tee":      {"name": "Neon tee",       "price": 80,  "col": Color(0.20, 0.95, 0.45), "slot": "jersey"},
	"purple_hoodie": {"name": "Purple hoodie",  "price": 160, "col": Color(0.42, 0.22, 0.62), "slot": "jersey",
					  "buff": ["stamina", 1.03]},
	"camo_jersey":   {"name": "Camo jersey",    "price": 190, "col": Color(0.38, 0.44, 0.28), "slot": "jersey", "pattern": "checks"},
	"white_home":    {"name": "Home whites",    "price": 110, "col": Color(0.94, 0.94, 0.96), "slot": "jersey", "pattern": "side"},
	"split_shorts":  {"name": "Split shorts",   "price": 85,  "col": Color(0.18, 0.18, 0.22), "slot": "shorts", "pattern": "band",
					  "buff": ["accel", 1.03]},
	"pastel_shorts": {"name": "Pastel shorts",  "price": 55,  "col": Color(0.72, 0.82, 0.90), "slot": "shorts"},
	"pro_lows":      {"name": "Pro lows",       "price": 280, "col": Color(0.12, 0.12, 0.14), "slot": "shoes",
					  "buff": ["handle", 1.04]},
	"pastel_mids":   {"name": "Pastel mids",    "price": 210, "col": Color(0.85, 0.72, 0.90), "slot": "shoes"},
	"ice_hi":        {"name": "Ice hi-tops",    "price": 390, "col": Color(0.70, 0.88, 0.95), "slot": "shoes",
					  "buff": ["block", 1.04]},
	"cap_lime":      {"name": "Lime cap",       "price": 50,  "col": Color(0.55, 0.90, 0.25), "slot": "hat"},
	"beanie_navy":   {"name": "Navy beanie",    "price": 48,  "col": Color(0.14, 0.20, 0.40), "slot": "hat"},
	"snap_gold":     {"name": "Gold snapback",  "price": 130, "col": Color(0.88, 0.72, 0.18), "slot": "hat",
					  "buff": ["all", 1.02]},
	"shades_lime":   {"name": "Lime shades",    "price": 85,  "col": Color(0.45, 0.92, 0.30), "slot": "glasses"},
	"shades_ice":    {"name": "Ice shades",     "price": 140, "col": Color(0.70, 0.90, 1.0), "slot": "glasses"},
	"specs_round":   {"name": "Round specs",    "price": 95,  "col": Color(0.22, 0.22, 0.26), "slot": "glasses"},
	"sweatband":     {"name": "Sweatband",      "price": 18,  "col": Color(0.92, 0.92, 0.94), "slot": "acc"},
	"ankle_tape":    {"name": "Ankle tape",     "price": 35,  "col": Color(0.95, 0.90, 0.70), "slot": "acc",
					  "buff": ["accel", 1.02]},
	"mouthguard":    {"name": "Mouthguard",     "price": 40,  "col": Color(0.20, 0.75, 0.45), "slot": "acc",
					  "buff": ["defense", 1.03]},
}

## Home furniture, sold at Home & Hearth next to Fit & Kicks. Every piece is
## placed in the second floor of your flat as soon as you buy it.
const FURNITURE := {
	"ft_shower":   {"name": "Shower",       "price": 250, "col": Color(0.42, 0.68, 0.82)},
	"ft_bed":      {"name": "Bed",          "price": 300, "col": Color(0.78, 0.40, 0.38)},
	"ft_sofa":     {"name": "Sofa",         "price": 220, "col": Color(0.45, 0.55, 0.70)},
	"ft_rug":      {"name": "Rug",          "price": 90,  "col": Color(0.80, 0.55, 0.35)},
	"ft_wardrobe": {"name": "Wardrobe",     "price": 180, "col": Color(0.55, 0.42, 0.30)},
	"ft_armchair": {"name": "Armchair",     "price": 120, "col": Color(0.60, 0.75, 0.45)},
	"ft_lamp":     {"name": "Floor lamp",   "price": 60,  "col": Color(0.90, 0.82, 0.40)},
	"ft_plant":    {"name": "Plant",        "price": 40,  "col": Color(0.35, 0.65, 0.40)},
	"ft_tv":       {"name": "TV",           "price": 200, "col": Color(0.30, 0.34, 0.42)},
	"ft_shelf":    {"name": "Bookshelf",    "price": 150, "col": Color(0.52, 0.38, 0.26)},
	"ft_desk":     {"name": "Desk",         "price": 170, "col": Color(0.62, 0.52, 0.38)},
	"ft_table":    {"name": "Dining table", "price": 140, "col": Color(0.58, 0.44, 0.30)},
}

func furniture(id: String) -> Dictionary:
	return FURNITURE.get(id, {})

## Wear items grouped by slot, for shop tabs and the wardrobe UI.
func wear_by_slot(slot: String) -> Array:
	var out: Array = []
	for id in WEAR:
		var it: Dictionary = WEAR[id]
		if slot == "nba":
			if bool(it.get("nba", false)):
				out.append(id)
		elif String(it.get("slot", "")) == slot and not bool(it.get("nba", false)):
			out.append(id)
	return out

## Drinks read better on their own shelf than mixed in with meals.
const DRINKS := ["water", "milk", "energy_drink", "coffee", "green_tea",
	"orange_juice", "sports_drink", "choc_milk", "soda", "smoothie",
	"iced_latte", "kombucha", "coconut", "bcaa",
	"espresso", "lemonade", "iced_tea", "mate"]

const SUPPLEMENTS := ["protein_bar", "protein_shake", "creatine", "recovery_kit", "bcaa"]

func is_drink(id: String) -> bool:
	return id in DRINKS

func meals() -> Array:
	var out: Array = []
	for id in FOOD:
		if not (id in DRINKS) and not (id in SUPPLEMENTS):
			out.append(id)
	return out

## The greasy aisle: everything flagged as junk food.
func junk() -> Array:
	var out: Array = []
	for id in FOOD:
		if bool(FOOD[id].get("junk", false)):
			out.append(id)
	return out

func food(id: String) -> Dictionary:
	return FOOD.get(id, {})

func wear(id: String) -> Dictionary:
	return WEAR.get(id, {})

func random_wear_col(slot: String) -> Color:
	var ids: Array = wear_by_slot(slot)
	if ids.is_empty():
		return Color(0.90, 0.90, 0.92)
	var w: Dictionary = wear(String(ids.pick_random()))
	if w.has("col"):
		return Color(w["col"])
	return Color(0.90, 0.90, 0.92)

func owned_count(id: String) -> int:
	return int(Game.profile["inventory"].get(id, 0))

func add(id: String, n := 1) -> void:
	var inv: Dictionary = Game.profile["inventory"]
	inv[id] = int(inv.get(id, 0)) + n
	if inv[id] <= 0:
		inv.erase(id)

## Eat a food item: applies hunger, energy and its buff. Returns a report string.
func consume(id: String) -> String:
	if owned_count(id) <= 0:
		return ""
	var f: Dictionary = food(id)
	if f.is_empty():
		return ""
	add(id, -1)
	Game.add_hunger(float(f["hunger"]))
	Game.add_energy(float(f["energy"]))
	var b: Array = f.get("buff", [])
	if b.size() == 3:
		Game.add_buff("food_" + id, String(b[0]), float(b[1]), int(b[2]))
	# Junk food tastes great and costs little -- but it bites back on your
	# health, which only sleep and clean living rebuild.
	var hp: float = float(f.get("health", 0.0))
	# Food and drinks never restore more than +5 health. Junk still hurts.
	if hp > 5.0:
		hp = 5.0
	elif hp == 0.0 and not bool(f.get("junk", false)):
		hp = 3.0
	if hp != 0.0:
		Game.add_health(hp)
	Game.advance_time(15)
	SaveSystem.save_game()
	if hp < 0.0:
		Events.toast.emit("%s  🍔 junk food  ❤%+.0f" % [f["name"], hp])
	return "%s  +%d food  +%d energy" % [f["name"], f["hunger"], f["energy"]]
