extends Control
class_name VirtualJoystick
## Floating touch joystick, multi-touch safe.
##
## Previously used _gui_input, which only delivers events while the finger stays
## inside the control's rect. Drag your thumb past the edge (constantly, when
## sprinting) and the joystick stopped receiving drags AND never saw the release,
## so `move_input` stayed latched at the last vector and the player kept walking.
## Now it claims a touch index on _input and tracks it to wherever it goes.

signal moved(vec: Vector2)

@export var radius := 110.0
@export var dead_zone := 0.16
@export var sensitivity := 1.0

var touch_index := -1
var origin := Vector2.ZERO
var knob := Vector2.ZERO
var output := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)

func _hit(p: Vector2) -> bool:
	return get_global_rect().has_point(p)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if touch_index == -1 and _hit(event.position):
				touch_index = event.index
				origin = event.position
				knob = origin
				output = Vector2.ZERO
				queue_redraw()
				get_viewport().set_input_as_handled()
		elif event.index == touch_index:
			_end()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == touch_index:
		knob = event.position
		var d: Vector2 = (knob - origin) / radius * sensitivity
		if d.length() < dead_zone: d = Vector2.ZERO
		output = d.limit_length(1.0)
		moved.emit(output)
		queue_redraw()
		get_viewport().set_input_as_handled()

func _end() -> void:
	touch_index = -1
	output = Vector2.ZERO
	moved.emit(output)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and touch_index != -1:
		_end()

func _draw() -> void:
	if touch_index == -1: return
	var o := origin - global_position
	draw_circle(o, radius, Color(1, 1, 1, 0.07))
	draw_arc(o, radius, 0, TAU, 40, Color(1, 1, 1, 0.26), 4.0)
	draw_circle(o + output * radius, 36, Color(1, 1, 1, 0.34))
	draw_arc(o + output * radius, 36, 0, TAU, 24, Color(1, 1, 1, 0.5), 2.0)
