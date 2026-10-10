extends Object
class_name Drills

## Catalogo degli ALLENAMENTI (v1.20.0): l'id vive in Game.profile["next_drill"]
## e guida Court (ruolo utente, chi parte con la palla) e MatchScene (banner con
## obiettivo e progresso). "hoop" dice quale canestro vale per l'esercizio:
## "side" = laterale, "classic" = tradizionale; mancante = non si segna, si consegna.

const LIST := [
	{"id": "pivot_shot", "role": 1, "target": 5, "hoop": "side",
		"loc": "drill.pivot_shot"},
	{"id": "pivot_delivery", "role": 4, "target": 3,
		"loc": "drill.pivot_delivery"},
	{"id": "r2_dribble", "role": 2, "target": 3, "hoop": "side",
		"loc": "drill.r2_dribble"},
	{"id": "r4_stop", "role": 4, "target": 3, "hoop": "classic",
		"loc": "drill.r4_stop"},
]

static func cfg(id: String) -> Dictionary:
	for d in LIST:
		if String(d["id"]) == id:
			return d
	return {}
