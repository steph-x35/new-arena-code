extends Node
## Deterministic input and save regression checks; no real career is overwritten.
var fails := 0
var checks := 0

func check(label: String, ok: bool) -> void:
	checks += 1
	print(("OK: " if ok else "FAIL: ") + label)
	if not ok: fails += 1

func touch(index: int, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.pressed = pressed
	e.position = Vector2(20, 20)
	return e

func _ready() -> void:
	var parent := Control.new()
	add_child(parent)
	var button := TouchButton.new()
	button.size = Vector2(100, 100)
	parent.add_child(button)
	button._input(touch(2, true))
	check("button claims touch", button._held)
	parent.hide()
	button._input(touch(2, false))
	check("hidden parent releases button", not button._held and button._touch == -1)
	parent.show()
	button.force_release()
	button._input(touch(2, true))
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = false
	button._input(mouse)
	check("mouse release cannot steal active touch", button._held)
	button.force_release()

	var joy := VirtualJoystick.new()
	joy.size = Vector2(100, 100)
	parent.add_child(joy)
	joy._input(touch(3, true))
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = Vector2(90, 20)
	joy._input(drag)
	check("joystick moves", joy.output.x > 0.0)
	parent.hide()
	check("hidden joystick resets movement", joy.touch_index == -1 and joy.output == Vector2.ZERO)
	joy._input(touch(4, true))
	check("hidden joystick ignores new touches", joy.touch_index == -1)
	parent.show()
	joy._end()
	joy._input(touch(3, true))
	joy._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("focus loss resets joystick", joy.output == Vector2.ZERO and joy.touch_index == -1)
	parent.queue_free()

	var merged: Dictionary = SaveSystem._merge_defaults({"attrs": "broken", "season": {"high": null}, "money": null, "name": 42, "energy": 87.5, "custom": "keep"})
	check("wrong dictionary type restored", merged.attrs is Dictionary)
	check("nested null restored", merged.season.high is Dictionary)
	check("wrong string type restored", merged.name is String)
	check("missing and null values restored", merged.money == 200 and merged.has("xp"))
	check("valid numbers and extra fields preserved", merged.energy == 87.5 and merged.custom == "keep")
	var original := Game.profile.duplicate(true)
	Game.profile = Game.default_profile()
	check("save new slot", SaveSystem.save_game("reliability_probe"))
	Game.profile.name = "Updated"
	check("replace existing slot", SaveSystem.save_game("reliability_probe"))
	Game.profile.name = "Unsaved"
	check("load replaced slot", SaveSystem.load_game("reliability_probe") and Game.profile.name == "Updated")
	SaveSystem.delete_save("reliability_probe")
	Game.profile = original
	print("RELIABILITY: %d checks, %d failures" % [checks, fails])
	get_tree().quit(0 if fails == 0 else 1)
