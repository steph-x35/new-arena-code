extends Control
class_name ItemIcon
## Draws a small stylised icon for a food / clothing item, procedurally.
## No image assets needed, and it scales cleanly on any screen density.

@export var item_id := ""
@export var kind := "food"     # food | wear
var count := 0
var selected := false
var hovered := false

func setup(id: String, k := "food", n := 0) -> ItemIcon:
	item_id = id
	kind = k
	count = n
	custom_minimum_size = Vector2(104, 104)
	mouse_filter = Control.MOUSE_FILTER_STOP
	return self

func _ready() -> void:
	mouse_entered.connect(func(): hovered = true; queue_redraw())
	mouse_exited.connect(func(): hovered = false; queue_redraw())

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var d: Dictionary
	if kind == "food":
		d = Items.food(item_id)
	elif kind == "furniture":
		d = Items.furniture(item_id)
	else:
		d = Items.wear(item_id)
	if d.is_empty(): return
	var col: Color = d.get("col", Color.WHITE)

	# tile
	var bg := Color(0.15, 0.17, 0.23)
	if selected: bg = Color(0.22, 0.30, 0.42)
	elif hovered: bg = Color(0.19, 0.22, 0.30)
	draw_rect(r, bg, true)
	draw_rect(r, col.darkened(0.2) if selected else Color(1, 1, 1, 0.10), false, 2.0)

	var c := size * 0.5 + Vector2(0, -8)
	if kind == "food":
		_draw_food(String(d.get("shape", "bar")), c, col)
	elif kind == "furniture":
		_draw_furniture(String(item_id).trim_prefix("ft_"), c, col)
	else:
		_draw_wear(String(d.get("slot", "jersey")), c, col)

	# count badge
	if count > 1:
		var bp := Vector2(size.x - 20, 18)
		draw_circle(bp, 14, Color(0.10, 0.12, 0.16))
		draw_circle(bp, 14, col)
		draw_string(ThemeDB.fallback_font, bp + Vector2(-7, 6), str(count),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.08, 0.09, 0.12))

	# name
	draw_string(ThemeDB.fallback_font, Vector2(4, size.y - 8), Loc.tx(String(d.get("name", ""))),
		HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 14, Color(1, 1, 1, 0.8))

func _draw_food(shape: String, c: Vector2, col: Color) -> void:
	match shape:
		"egg":
			for o in [Vector2(-11, 2), Vector2(11, 0)]:
				draw_colored_polygon(_ellipse(c + o, Vector2(11, 14)), col)
				draw_circle(c + o + Vector2(0, 2), 5, Color(0.98, 0.78, 0.25))
		"carton":
			draw_rect(Rect2(c.x - 14, c.y - 20, 28, 38), col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-14, -20), c + Vector2(0, -30), c + Vector2(14, -20)]), col.darkened(0.15))
			draw_rect(Rect2(c.x - 10, c.y - 6, 20, 14), Color(0.35, 0.55, 0.85))
		"plate":
			draw_colored_polygon(_ellipse(c + Vector2(0, 6), Vector2(28, 12)), Color(0.92, 0.92, 0.95))
			draw_colored_polygon(_ellipse(c + Vector2(-8, 2), Vector2(13, 8)), col)
			draw_colored_polygon(_ellipse(c + Vector2(10, 4), Vector2(11, 7)), Color(0.95, 0.95, 0.9))
		"bowl":
			draw_colored_polygon(_ellipse(c + Vector2(0, -4), Vector2(24, 9)), col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-24, -4), c + Vector2(24, -4),
				c + Vector2(15, 16), c + Vector2(-15, 16)]), Color(0.88, 0.90, 0.94))
		"bar":
			draw_rect(Rect2(c.x - 22, c.y - 9, 44, 20), col)
			draw_rect(Rect2(c.x - 22, c.y - 9, 44, 7), col.lightened(0.25))
		"can":
			draw_rect(Rect2(c.x - 12, c.y - 20, 24, 38), col)
			draw_colored_polygon(_ellipse(c + Vector2(0, -20), Vector2(12, 4)), col.lightened(0.35))
			draw_rect(Rect2(c.x - 12, c.y - 4, 24, 8), Color(1, 1, 1, 0.25))
		"cup":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-13, -18), c + Vector2(13, -18),
				c + Vector2(9, 18), c + Vector2(-9, 18)]), col)
			draw_colored_polygon(_ellipse(c + Vector2(0, -18), Vector2(13, 4)), col.lightened(0.3))
			draw_line(c + Vector2(6, -26), c + Vector2(10, -6), Color(0.95, 0.95, 1.0), 3)
		"pizza":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -20), c + Vector2(20, 16), c + Vector2(-20, 16)]), Color(0.95, 0.82, 0.45))
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -14), c + Vector2(15, 13), c + Vector2(-15, 13)]), col)
			for o in [Vector2(0, 0), Vector2(-7, 8), Vector2(7, 7)]:
				draw_circle(c + o, 3.2, Color(0.75, 0.18, 0.18))
		"bottle":
			draw_rect(Rect2(c.x - 9, c.y - 12, 18, 30), col)
			draw_rect(Rect2(c.x - 5, c.y - 24, 10, 12), col.lightened(0.2))
			draw_rect(Rect2(c.x - 6, c.y - 27, 12, 5), Color(0.3, 0.5, 0.7))
		_:
			draw_circle(c, 18, col)

## Simple silhouettes for the furniture shop: one distinct shape per piece.
func _draw_furniture(k: String, c: Vector2, col: Color) -> void:
	match k:
		"shower":
			draw_rect(Rect2(c.x - 22, c.y - 26, 44, 52), col, false, 4)
			draw_line(c + Vector2(-8, 14), c + Vector2(0, -2), Color(0.4, 0.8, 1.0), 4)
		"bed":
			draw_rect(Rect2(c.x - 26, c.y - 12, 52, 22), col, true)
			draw_rect(Rect2(c.x - 30, c.y - 22, 14, 22), col.darkened(0.3), true)
		"sofa":
			draw_rect(Rect2(c.x - 26, c.y - 8, 52, 22), col, true)
			draw_rect(Rect2(c.x - 26, c.y - 26, 52, 18), col.darkened(0.25), true)
		"rug":
			draw_colored_polygon(_ellipse(c + Vector2(0, 8), Vector2(30, 12)), col)
			draw_colored_polygon(_ellipse(c + Vector2(0, 8), Vector2(20, 8)), col.lightened(0.2))
		"wardrobe":
			draw_rect(Rect2(c.x - 18, c.y - 30, 36, 60), col, true)
			draw_line(Vector2(c.x, c.y - 30), Vector2(c.x, c.y + 30), Color(0, 0, 0, 0.3), 2)
		"armchair":
			draw_rect(Rect2(c.x - 20, c.y - 6, 40, 24), col, true)
			draw_rect(Rect2(c.x - 20, c.y - 22, 40, 16), col.darkened(0.25), true)
		"lamp":
			draw_line(c + Vector2(0, 12), c + Vector2(0, -26), col.darkened(0.4), 4)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-14, -22), c + Vector2(14, -22), c + Vector2(0, -34)]), col)
		"plant":
			draw_rect(Rect2(c.x - 8, c.y + 2, 16, 18), Color(0.62, 0.44, 0.30), true)
			draw_circle(c + Vector2(0, -8), 14, col)
		"tv":
			draw_rect(Rect2(c.x - 24, c.y - 18, 48, 32), col, true)
			draw_rect(Rect2(c.x - 8, c.y + 14, 16, 12), Color(0.3, 0.3, 0.35), true)
		"shelf":
			draw_rect(Rect2(c.x - 20, c.y - 28, 40, 56), col, true)
			for i in 3:
				draw_line(Vector2(c.x - 20, c.y - 14 + i * 14), Vector2(c.x + 20, c.y - 14 + i * 14), Color(0, 0, 0, 0.25), 2)
		"desk":
			draw_rect(Rect2(c.x - 24, c.y - 14, 48, 10), col, true)
			draw_rect(Rect2(c.x - 20, c.y - 4, 8, 20), col.darkened(0.3), true)
			draw_rect(Rect2(c.x + 12, c.y - 4, 8, 20), col.darkened(0.3), true)
		"table":
			draw_rect(Rect2(c.x - 24, c.y - 10, 48, 9), col, true)
			draw_rect(Rect2(c.x - 20, c.y - 1, 7, 22), col.darkened(0.3), true)
			draw_rect(Rect2(c.x + 13, c.y - 1, 7, 22), col.darkened(0.3), true)
		_:
			draw_circle(c, 20, col)

## Every clothing slot gets its OWN silhouette. Shorts and shoes used to share
## one shapeless blob, so the shop showed the same picture for both.
func _draw_wear(slot: String, c: Vector2, col: Color) -> void:
	var d: Dictionary = Items.wear(item_id)
	var pattern: String = String(d.get("pattern", "plain"))
	match slot:
		"jersey":
			var body := PackedVector2Array([
				c + Vector2(-16, -16), c + Vector2(-8, -20), c + Vector2(8, -20),
				c + Vector2(16, -16), c + Vector2(22, -6), c + Vector2(15, -2),
				c + Vector2(15, 20), c + Vector2(-15, 20), c + Vector2(-15, -2),
				c + Vector2(-22, -6)])
			draw_colored_polygon(body, col)
			_pattern(pattern, Rect2(c + Vector2(-15, -18), Vector2(30, 38)), col)
			draw_arc(c + Vector2(0, -18), 7, 0, PI, 10, col.darkened(0.35), 3)
		"shorts":
			# waistband, two legs and the gap between them -- unmistakably shorts
			draw_rect(Rect2(c.x - 19, c.y - 16, 38, 8), col.darkened(0.28))
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-19, -8), c + Vector2(-2, -8),
				c + Vector2(-3, 20), c + Vector2(-18, 20)]), col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(2, -8), c + Vector2(19, -8),
				c + Vector2(18, 20), c + Vector2(3, 20)]), col)
			_pattern(pattern, Rect2(c + Vector2(-19, -8), Vector2(38, 28)), col)
		"shoes":
			# side-on sneaker: sole, upper, collar and a lace flash
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-22, 6), c + Vector2(-18, -8), c + Vector2(-6, -11),
				c + Vector2(6, -1), c + Vector2(22, 5), c + Vector2(22, 12),
				c + Vector2(-22, 12)]), col)
			draw_rect(Rect2(c.x - 23, c.y + 10, 46, 7), Color(0.94, 0.94, 0.96))
			draw_rect(Rect2(c.x - 23, c.y + 15, 46, 3), col.darkened(0.45))
			draw_line(c + Vector2(-15, -2), c + Vector2(-3, -6), Color(1, 1, 1, 0.75), 2)
			draw_line(c + Vector2(-13, 3), c + Vector2(-1, -1), Color(1, 1, 1, 0.75), 2)
			_pattern(pattern, Rect2(c + Vector2(-22, -10), Vector2(44, 20)), col)
		"hat":
			# a cap seen from the side: dome plus a peak
			draw_colored_polygon(_ellipse(c + Vector2(0, 2), Vector2(20, 15)), col)
			draw_rect(Rect2(c.x - 20, c.y + 1, 40, 6), col.darkened(0.22))
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(16, 2), c + Vector2(34, 6), c + Vector2(34, 10),
				c + Vector2(15, 8)]), col.darkened(0.32))
			_pattern(pattern, Rect2(c + Vector2(-20, -13), Vector2(40, 15)), col)
		"glasses":
			# two lenses joined by a bridge, with arms
			for e in [-1.0, 1.0]:
				draw_colored_polygon(_ellipse(c + Vector2(e * 13, 0), Vector2(11, 9)),
					Color(col, 0.85))
				draw_arc(c + Vector2(e * 13, 0), 11, 0, TAU, 18, col.darkened(0.4), 2.5)
			draw_line(c + Vector2(-3, -1), c + Vector2(3, -1), col.darkened(0.4), 3)
			draw_line(c + Vector2(-24, -2), c + Vector2(-32, 4), col.darkened(0.4), 3)
			draw_line(c + Vector2(24, -2), c + Vector2(32, 4), col.darkened(0.4), 3)
		_:
			# accessory: a band / strap, clearly not a garment
			draw_arc(c + Vector2(0, 2), 17, PI * 0.15, PI * 0.85, 20, col, 9)
			draw_arc(c + Vector2(0, 2), 17, PI * 1.15, PI * 1.85, 20, col.darkened(0.2), 9)
			draw_circle(c + Vector2(0, 2), 6, Color(1, 1, 1, 0.18))

## Stripes and other patterns painted inside the garment's bounding box, so the
## same colour can appear as several genuinely different items.
func _pattern(kind: String, box: Rect2, col: Color) -> void:
	var ink: Color = col.lightened(0.55) if col.get_luminance() < 0.5 else col.darkened(0.42)
	match kind:
		"stripes":
			var y: float = box.position.y + 5.0
			while y < box.end.y - 2.0:
				draw_rect(Rect2(box.position.x, y, box.size.x, 3.5), ink)
				y += 9.0
		"vstripe":
			var x: float = box.position.x + 6.0
			while x < box.end.x - 3.0:
				draw_rect(Rect2(x, box.position.y, 3.5, box.size.y), ink)
				x += 10.0
		"side":
			# a single racing stripe down each edge
			draw_rect(Rect2(box.position.x + 2.0, box.position.y, 4.0, box.size.y), ink)
			draw_rect(Rect2(box.end.x - 6.0, box.position.y, 4.0, box.size.y), ink)
		"band":
			draw_rect(Rect2(box.position.x, box.get_center().y - 4.0,
				box.size.x, 8.0), ink)
		"checks":
			var cy: float = box.position.y
			var row := 0
			while cy < box.end.y:
				var cx: float = box.position.x + (7.0 if row % 2 else 0.0)
				while cx < box.end.x:
					draw_rect(Rect2(cx, cy, 6.0, 6.0), ink)
					cx += 14.0
				cy += 7.0
				row += 1
		_:
			pass

func _ellipse(c: Vector2, r: Vector2) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		p.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return p
