extends Node

var downs := 0
var ups := 0

func key(code: Key, down: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	return event

func _ready() -> void:
	var joy := VirtualJoystick.new()
	add_child(joy)
	var button := TouchButton.new()
	button.text = "TIRA"
	button.pressed_down.connect(func(): downs += 1)
	button.released.connect(func(): ups += 1)
	add_child(button)
	await get_tree().process_frame
	joy._input(key(KEY_RIGHT, true))
	var ok := joy.output == Vector2.RIGHT
	joy._input(key(KEY_UP, true))
	ok = ok and joy.output.x > 0.7 and joy.output.y < -0.7
	joy._input(key(KEY_RIGHT, false))
	joy._input(key(KEY_UP, false))
	ok = ok and joy.output == Vector2.ZERO
	button._input(key(KEY_SPACE, true))
	button._input(key(KEY_SPACE, false))
	ok = ok and downs == 1 and ups == 1 and not button._held
	button.hide()
	button._input(key(KEY_SPACE, true))
	ok = ok and downs == 1
	print("KEYBOARD_OK=", ok)
	get_tree().quit(0 if ok else 1)
