extends Node2D
## Mini-job: rhythm-tap crate loading. Pay scales with accuracy.

@onready var root: Control = $UI/Root
var running := false
var target_t := 0.0
var t := 0.0
var hits := 0
var misses := 0
var rounds := 0
var lbl: Label
var bar: ProgressBar

func _ready() -> void:
	UIKit.header(root, Loc.tx("LOADING DOCKS"), Loc.tx("Tap when the marker is in the green zone. 12 crates."))
	var v := UIKit.column(root, Vector2(60, 200))
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(600, 40)
	bar.max_value = 1.0
	bar.step = 0.001
	bar.show_percentage = false
	v.add_child(bar)
	lbl = UIKit.label(v, "Ready.")
	UIKit.big_button(v, Loc.tx("START SHIFT"), _start)
	UIKit.big_button(v, Loc.tx("LOAD CRATE"), _tap)
	UIKit.big_button(v, Loc.tx("Leave"), func(): SceneRouter.goto("res://src/scenes/CityScene.tscn"))
	UIKit.back_and_phone(root)

func _start() -> void:
	if Game.profile["energy"] < 15:
		Events.toast.emit(Loc.tx("Too tired."))
		return
	running = true; hits = 0; misses = 0; rounds = 0; t = 0.0
	lbl.text = Loc.tx("Shift started!")

func _process(delta: float) -> void:
	if not running: return
	t = fmod(t + delta * 0.9, 1.0)
	bar.value = t

func _tap() -> void:
	if not running: return
	rounds += 1
	if t > 0.55 and t < 0.78:
		hits += 1
		lbl.text = Loc.tx("Good load! %d/%d") % [hits, rounds]
	else:
		misses += 1
		lbl.text = Loc.tx("Dropped it. %d/%d") % [hits, rounds]
	if rounds >= 12:
		_end()

func _end() -> void:
	running = false
	var acc := float(hits) / 12.0
	var pay := int(70 + acc * 160)
	Game.add_money(pay)
	Game.add_energy(-22)
	Game.add_hunger(-12)
	Game.advance_time(180)
	Game.add_xp(int(10 + acc * 20), "job")
	lbl.text = Loc.tx("Shift done. Accuracy %d%% -> +%d$") % [int(acc * 100), pay]
	SaveSystem.save_game()
