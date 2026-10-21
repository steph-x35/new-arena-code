extends Control
class_name PlayerPreview
## Big live mannequin for the character creator: skin, hair, handedness, and a
## silhouette that really changes shape with height and weight.
##
## The creator used to reuse the tiny 3x-scaled city sprite tucked in a corner,
## so you could not judge your skin tone or build until you were already walking
## around the city. This is a proper, readable figure sized to the panel.

var idle := 0.0

func _ready() -> void:
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	idle += delta
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y

	# stage backdrop
	var bg := Rect2(Vector2.ZERO, size)
	draw_rect(bg, Color(0.07, 0.09, 0.13))
	draw_rect(bg, Color(1, 1, 1, 0.10), false, 2.0)
	# floor pool of light
	var floor_y: float = h - 54.0
	for i in 5:
		draw_circle(Vector2(w * 0.5, floor_y), 150.0 - i * 22.0,
			Color(0.45, 0.62, 0.95, 0.035))
	draw_line(Vector2(18, floor_y), Vector2(w - 18, floor_y), Color(1, 1, 1, 0.16), 2.0)

	# Draw the SHARED avatar, at a size that fills the stage. This is the same
	# figure the city, the gym and the match use, so what you pick here is
	# exactly what you get -- the preview cannot drift from the real game.
	var cm: float = float(Game.profile.get("height_cm", 195))
	var kg: float = float(Game.profile.get("weight_kg", 90))
	var tall01: float = clampf((cm - 175.0) / 45.0, 0.0, 1.0)
	var body_h: float = lerpf(h * 0.62, h * 0.80, tall01)
	var bob: float = sin(idle * 1.6) * 2.0
	var pc: Dictionary = Avatar.colours(true)
	pc["muscle"] = float(Game.profile.get("muscle", 0.0))
	pc["hst"] = Game.hair_style()
	Avatar.draw_body(self, Vector2(w * 0.5, floor_y + bob), body_h, 1.0,
		Avatar.pose(Avatar.IDLE, idle), pc, true, false, true)

	var f := ThemeDB.fallback_font
	# --- read-outs pinned to the stage
	draw_string(f, Vector2(16, 26), "%s  ·  %s-handed" % [
		String(Game.profile.get("position", "PG")), String(Game.profile.get("hand", "R"))],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(1, 0.88, 0.45))
	draw_string(f, Vector2(16, h - 22), "%d cm   %d kg" % [int(cm), int(kg)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.72))
	# a height ruler so the size change is unmissable
	draw_line(Vector2(w - 26, floor_y), Vector2(w - 26, floor_y - body_h * 1.12),
		Color(1, 1, 1, 0.22), 2.0)
	for i in 5:
		var ty: float = floor_y - body_h * 1.12 * (i / 4.0)
		draw_line(Vector2(w - 32, ty), Vector2(w - 20, ty), Color(1, 1, 1, 0.22), 2.0)

func _wear_col(slot: String, fallback: Color) -> Color:
	## Same lookup the match and city avatars use, so the preview cannot drift
	## away from what you actually see in game.
	var outfit: Dictionary = Game.profile.get("outfit", {})
	var id: String = String(outfit.get(slot, ""))
	if id == "":
		return fallback
	var w: Dictionary = Items.wear(id)
	if w.is_empty() or not w.has("col"):
		return fallback
	return Color(w["col"])

func _ellipse(c: Vector2, r: Vector2) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 18:
		var a: float = TAU * i / 18.0
		p.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return p
