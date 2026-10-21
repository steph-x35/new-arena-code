extends Control
class_name Hotspot
## A clickable object inside a room. Draws a soft glow + label when you get near
## it with the pointer, so the world reads as interactive rather than as a menu.

signal activated

var label_text := ""
var pulse := 0.0
var hovered := false
var enabled := true

func setup(rect: Rect2, text: String) -> Hotspot:
	position = rect.position
	size = rect.size
	label_text = text
	mouse_filter = Control.MOUSE_FILTER_STOP
	return self

func _ready() -> void:
	mouse_entered.connect(func(): hovered = true)
	mouse_exited.connect(func(): hovered = false)
	gui_input.connect(_on_input)
	set_process(true)

func _on_input(e: InputEvent) -> void:
	if not enabled: return
	if (e is InputEventScreenTouch and e.pressed) \
	or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		activated.emit()
		accept_event()

func _process(delta: float) -> void:
	pulse = fmod(pulse + delta, TAU)
	queue_redraw()

func _draw() -> void:
	if not enabled: return
	var breathe := 0.5 + 0.5 * sin(pulse * 2.0)
	var a := 0.10 + breathe * 0.10
	if hovered: a = 0.34
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(1.0, 0.92, 0.55, a * 0.5), true)
	draw_rect(r, Color(1.0, 0.90, 0.45, a + 0.25), false, 3.0)
	# corner ticks, like a viewfinder
	var L := 14.0
	var col := Color(1.0, 0.93, 0.6, 0.55 + a)
	for corner in [[Vector2(0,0), Vector2(1,0), Vector2(0,1)],
					[Vector2(size.x,0), Vector2(-1,0), Vector2(0,1)],
					[Vector2(0,size.y), Vector2(1,0), Vector2(0,-1)],
					[Vector2(size.x,size.y), Vector2(-1,0), Vector2(0,-1)]]:
		draw_line(corner[0], corner[0] + corner[1] * L, col, 3)
		draw_line(corner[0], corner[0] + corner[2] * L, col, 3)
	if label_text != "":
		var f := ThemeDB.fallback_font
		var w := f.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 18
		var lp := Vector2(size.x * 0.5 - w * 0.5, -14)
		draw_rect(Rect2(lp, Vector2(w, 30)), Color(0.06, 0.07, 0.10, 0.88), true)
		draw_rect(Rect2(lp, Vector2(w, 30)), Color(1, 0.9, 0.5, 0.5), false, 1.5)
		draw_string(f, lp + Vector2(9, 21), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color(1, 0.96, 0.85))
