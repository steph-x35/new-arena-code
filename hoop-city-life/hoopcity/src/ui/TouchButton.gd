extends Control
class_name TouchButton
## A button that is SAFE under multi-touch.
##
## Godot's built-in Button tracks a single implicit pointer. On a phone you are
## holding the joystick with the left thumb while tapping SHOOT with the right:
## the second finger's release frequently never reaches the Button, so
## `button_up` never fires. For a hold-to-charge shot meter that means the
## charge never terminates -> the meter sticks on screen and the player can
## never shoot again. That is the "everything freezes when I tap shoot" bug.
##
## This control binds to ONE specific touch index and guarantees a release:
## it listens on _input (not _gui_input) so it still sees the finger lift even
## if it drifts outside the button's rect.

signal pressed_down()
signal released()

@export var text := ""
@export var icon := ""                 ## Art glyph id; falls back to icon_for(text)
@export var accent := Color(0.92, 0.55, 0.16)
@export var hold_mode := false        ## true = emits pressed_down/released, false = tap only

var _touch := -1                       # active touch index, -1 = idle
var _held := false
var _flash := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # we do our own hit testing
	set_process_input(true)
	set_process(true)

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
		queue_redraw()

func _hit(p: Vector2) -> bool:
	return get_global_rect().has_point(p)

func _input(event: InputEvent) -> void:
	# The two pads (attack/defence) share the same screen slots, and one of
	# them is always hidden. A hidden Control still received _input, so both
	# STOPPATA and TIRA fired on the same tap and the player just hopped.
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch == -1 and _hit(event.position):
				_claim(event.index)
				get_viewport().set_input_as_handled()
		elif event.index == _touch:
			_release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch:
		pass
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _touch == -1 and _hit(event.position):
				_claim(0)
				get_viewport().set_input_as_handled()
		elif _touch != -1:
			_release()
			get_viewport().set_input_as_handled()

func _claim(idx: int) -> void:
	_touch = idx
	_held = true
	_flash = 1.0
	pass  # niente suoni dei tasti: il gioco parla con il campo, non coi click
	queue_redraw()
	pressed_down.emit()

func _release() -> void:
	_touch = -1
	_held = false
	queue_redraw()
	released.emit()

func _notification(what: int) -> void:
	# If the app loses focus mid-hold, force the release so nothing hangs.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _held:
		_release()

func force_release() -> void:
	if _held: _release()

func _draw() -> void:
	# v1.8 pad look: a smoked-glass disc with an orange ring, a vector glyph
	# and a small caption. Idle pads stay translucent so the court shows
	# through; a held pad floods with the accent colour.
	var r := Rect2(Vector2.ZERO, size)
	var rad := size.x * 0.5
	var c := size * 0.5
	var base := Color(0.078, 0.086, 0.110, 0.52)
	if _held:
		base = accent.darkened(0.45)
	base = base.lerp(accent, _flash * 0.30)
	draw_circle(c, rad, base)
	# inner sheen so the disc reads as glass, not a hole
	draw_arc(c, rad * 0.72, PI * 1.05, PI * 1.95, 18, Color(1, 1, 1, 0.10), rad * 0.16)
	draw_arc(c, rad - 1.5, 0, TAU, 44,
		accent.lerp(Color.WHITE, 0.30 if _held else 0.0), maxf(3.0, rad * 0.055))
	var glyph := icon if icon != "" else Art.icon_for(text)
	var icon_col := Color(1, 1, 1, 0.96) if _held else accent.lerp(Color.WHITE, 0.55)
	Art.draw_icon(self, glyph, Rect2(c - Vector2(rad * 0.46, rad * 0.62),
		Vector2(rad * 0.92, rad * 0.92)), icon_col)
	var f := ThemeDB.fallback_font
	var fs := maxi(int(size.x * 0.145), 12)
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(c.x - tw * 0.5, c.y + rad * 0.78),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92))

