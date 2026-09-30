extends Node2D
## Team practice facility. Every button here states what it does, what it
## costs, and -- crucially -- says so when you cannot afford it.
##
## The old menu emitted a toast ("Too tired to play") that nothing in this
## scene was listening for, so pressing SCRIMMAGE on low energy did absolutely
## nothing with no explanation. Costs are now printed on the buttons, the
## unaffordable ones are visibly disabled with the reason, and a StatusBar
## shows energy so you can see why.

@onready var root: Control = $UI/Root

const COST_SCRIMMAGE := 25
const COST_1V1 := 15
const COST_DRILL := 16
const COST_FT := 12

func _ready() -> void:
	# Entrando qui di corsa dalla palestra last_building restava "gym" e il
	# court solo apriva l'outdoor: ogni edificio aggiorna il proprio id.
	Game.profile["last_building"] = "court"
	Sfx.stop_music()   # solo/1v1 courts: squeaks, swish and bounces only
	_build()

func _build() -> void:
	UIKit.header(root, Loc.tx("TEAM COURT"), Loc.tx("Practice with the squad or run a scrimmage."))
	# A status bar so energy/time/money are visible -- and so Events.toast has
	# somewhere to appear in this scene at all.
	var bar := preload("res://src/ui/StatusBar.gd").new()
	root.add_child(bar)

	var e: float = float(Game.profile["energy"])
	var v := UIKit.column(root, Vector2(60, 190))

	# ---- competitive games
	_action(v, "SCRIMMAGE (full game)",
		"5v5 · four quarters · full match engine", COST_SCRIMMAGE, e,
		func(): _play("full", COST_SCRIMMAGE))

	_action(v, "1v1 · FIRST TO 11",
		"Half court · make-it-take-it · clear the arc", COST_1V1,	e,
		func(): _play("1v1", COST_1V1))

	# ---- free practice
	UIKit.big_button(v, Loc.tx("SHOOT AROUND (solo)"),
		func(): SceneRouter.goto("res://src/scenes/SoloCourt.tscn"),
		"Free · no clock, no defender, no energy cost")

	# ---- today's scheduled practice
	var ev: Dictionary = Season.today()
	if not ev.is_empty() and String(ev.get("kind", "")) == "practice" \
	and not bool(ev.get("done", false)):
		UIKit.big_button(v, Loc.tx("TEAM PRACTICE (today)"),
			func():
				Season.attend_practice()
				_rebuild(),
			"Coach is expecting you · +followers, +rep")

	# ---- court work: every basketball exercise lives HERE, on the court
	# that has the hoops and the paint, not in the weight room. Ordered as a
	# single clear list so the whole on-court curriculum is in one place.
	UIKit.label(v, Loc.tx("COURT WORK"), 24)
	_action(v, "Spot Shooting",
		"Beat the close-out · three / mid / close", COST_DRILL, e,
		func(): _drill("shooting"))
	_action(v, "Cone Dribbling",
		"Slalom through the cones · handle / accel / speed", COST_DRILL, e,
		func(): _drill("handling"))
	_action(v, "Lateral Slides",
		"Stay in front of your man · defence / steal / block", COST_DRILL, e,
		func(): _drill("defense"))
	_action(v, "Free Throw Session",
		"Same routine, straight on · close / mid touch", COST_FT, e,
		func(): _drill("freethrow"))

	UIKit.big_button(v, Loc.tx("Leave"),
		func(): SceneRouter.goto("res://src/scenes/CityScene.tscn"))
	UIKit.back_and_phone(root)

## A button that shows its energy cost and explains itself when unavailable,
## instead of silently refusing.
func _action(parent: Control, title: String, why: String, cost: int,
		energy: float, cb: Callable) -> void:
	var affordable: bool = energy >= float(cost)
	var sub: String = "%s · %d energy" % [why, cost]
	if not affordable:
		sub = "NEED %d ENERGY (you have %d) · eat or sleep first" % [cost, int(energy)]
	var b := UIKit.big_button(parent, title, cb if affordable else Callable(), sub)
	if not affordable:
		b.disabled = true
		b.tooltip_text = "Rest at home or eat to restore energy."

func _rebuild() -> void:
	## Rebuild the menu so costs, energy and the practice entry stay in sync.
	if not is_inside_tree():
		return
	for c in root.get_children():
		c.queue_free()
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_build()

func _play(mode: String, cost: int) -> void:
	if Game.profile["energy"] < float(cost):
		# Defensive: the button should already be disabled, but never fail mute.
		Events.toast.emit(Loc.tx("Too tired -- you need %d energy") % cost)
		_rebuild()
		return
	# Everything tips off through the broadcast intro, so a scrimmage feels
	# like a fixture rather than a menu jump.
	var opponent := "Practice Squad"
	var e: Dictionary = Season.today()
	if not e.is_empty() and String(e.get("kind", "")) == "game" \
	and not bool(e.get("done", false)):
		opponent = String(e.get("opponent", opponent))
	if mode == "1v1":
		opponent = "The Challenger"
	# Pick the kits first: a scrimmage is your game, so you choose what both
	# sides wear before tipping off.
	Game.profile["next_match_mode"] = mode
	# A scrimmage is practice: empty benches, empty stands, no rotations.
	Game.profile["match_is_fixture"] = false
	Game.profile["next_opponent"] = opponent
	Game.profile["next_home"] = true
	# A real club shows up in its own colours; the Practice Squad wears white.
	Game.set_team_kit(1, Season.kit_for(opponent))
	Game.profile["next_kit_return"] = "res://src/scenes/TeamCourt.tscn"
	SceneRouter.goto("res://src/scenes/KitPicker.tscn")

func _drill(kind: String) -> void:
	var cost: int = COST_FT if kind == "freethrow" else COST_DRILL
	if Game.profile["energy"] < float(cost):
		Events.toast.emit(Loc.tx("Too tired -- you need %d energy") % cost)
		_rebuild()
		return
	Game.profile["pending_drill"] = {
		"kind": kind,
		"lift": "bench",
		"machine": "bike",
		"return": "res://src/scenes/TeamCourt.tscn",
	}
	SceneRouter.goto("res://src/scenes/DrillScene.tscn")

## Show / hide the whole menu, CanvasLayer included.
func _set_menu_visible(on: bool) -> void:
	visible = on
	for c in get_children():
		if c is CanvasLayer:
			c.visible = on
