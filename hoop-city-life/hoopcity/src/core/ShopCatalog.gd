extends Node
## Shared item catalog (autoload `ShopCatalog`) so the store and the phone agree.

const ITEMS := [
	{"id": "meal_box",     "name": "Hot meal box",    "price": 22},
	{"id": "protein_bar",  "name": "Protein bar",     "price": 8},
	{"id": "energy_drink", "name": "Energy drink",    "price": 12},
	{"id": "recovery_kit", "name": "Recovery kit",    "price": 45},
]

static func find(id: String) -> Dictionary:
	for i in ITEMS:
		if i["id"] == id: return i
	return {}
