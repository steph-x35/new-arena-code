extends Node
## Tiny helper library so every screen gets consistent, thumb-sized mobile UI.
## Autoloaded as `UIKit`.
##
## LAYOUT RULE (learned the hard way): never stack buttons at absolute
## coordinates. A vertical list of 9 buttons at 112px each needs 1008px, which
## simply does not exist on a 720px-tall landscape screen -- the last items
## (including "START CAREER") ended up unreachable off the bottom edge.
## `column()` now returns a SCROLLABLE, height-clamped container, and
## `grid_menu()` lays big choices out in landscape-friendly columns.

const BTN_H := 92
const FONT_BODY := 24
const FONT_TITLE := 44
const TOP_SAFE := 168        ## y below the header where content may start
const BOTTOM_SAFE := 24      ## keep this much clear at the bottom

func vp(parent: Control) -> Vector2:
	## Usable viewport size, with a sane fallback before the tree is ready.
	var s: Vector2 = parent.get_viewport_rect().size
	if s.x < 100.0 or s.y < 100.0:
		return Vector2(1280, 720)
	return s

func header(parent: Control, title: String, subtitle := "") -> VBoxContainer:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	parent.add_child(bg)

	var v := VBoxContainer.new()
	v.position = Vector2(56, 40)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", FONT_TITLE)
	v.add_child(t)
	if subtitle != "":
		var s := Label.new()
		s.text = subtitle
		s.add_theme_font_size_override("font_size", 20)
		s.modulate = Color(1, 1, 1, 0.65)
		v.add_child(s)
	parent.add_child(v)
	return v

## A vertical list that is guaranteed to stay on screen: it is clamped to the
## viewport height and scrolls if the content is taller.
## `reserve_bottom` keeps room for a pinned action button below the list.
func column(parent: Control, pos: Vector2, width := 620, reserve_bottom := 0.0) -> VBoxContainer:
	var size := vp(parent)
	var scroll := ScrollContainer.new()
	scroll.position = pos
	scroll.custom_minimum_size = Vector2(width,
		maxf(size.y - pos.y - BOTTOM_SAFE - reserve_bottom, 120.0))
	scroll.size = scroll.custom_minimum_size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	parent.add_child(scroll)

	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(width, 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 14)
	scroll.add_child(v)
	return v

## Landscape-first menu: spreads entries across as many columns as it takes to
## fit the height, so nothing ever runs off the bottom.
## `entries` = [{"text": String, "sub": String, "cb": Callable, "dim": bool}]
func grid_menu(parent: Control, pos: Vector2, entries: Array, col_w := 560.0) -> HBoxContainer:
	var size := vp(parent)
	var avail_h: float = maxf(size.y - pos.y - BOTTOM_SAFE, BTN_H)
	var per_col: int = maxi(int(avail_h / float(BTN_H + 14)), 1)

	var cols := HBoxContainer.new()
	cols.position = pos
	cols.add_theme_constant_override("separation", 26)
	parent.add_child(cols)

	var current: VBoxContainer = null
	for i in entries.size():
		if i % per_col == 0:
			current = VBoxContainer.new()
			current.add_theme_constant_override("separation", 14)
			current.custom_minimum_size = Vector2(col_w, 0)
			cols.add_child(current)
		var e: Dictionary = entries[i]
		var b := big_button(current, String(e.get("text", "")), e.get("cb", Callable()),
			String(e.get("sub", "")), col_w)
		if bool(e.get("dim", false)):
			b.modulate = Color(1, 1, 1, 0.45)
	return cols

## Styled menu buttons (v1.19): "primary" is the one big orange action,
## "ghost" the quiet secondary ones -- the default grey Godot button read as
## unfinished on a title screen, which is exactly what the first screen must
## never look like.
func menu_button(parent: Control, text: String, cb: Callable, kind := "ghost",
		width := 250.0) -> Button:
	var b := Button.new()
	b.text = text
	var primary := kind == "primary"
	b.custom_minimum_size = Vector2(width, 92.0 if primary else 64.0)
	b.add_theme_font_size_override("font_size", 30 if primary else 22)
	b.clip_text = true
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		if primary:
			sb.bg_color = {"normal": Art.ORANGE, "hover": Art.ORANGE_HOT,
				"pressed": Art.ORANGE_DK,
				"focus": Art.ORANGE}[state]
		else:
			sb.bg_color = {"normal": Color(1, 1, 1, 0.045),
				"hover": Color(1, 1, 1, 0.10), "pressed": Color(1, 1, 1, 0.03),
				"focus": Color(1, 1, 1, 0.045)}[state]
			sb.set_border_width_all(2)
			sb.border_color = Color(Art.CREAM.r, Art.CREAM.g, Art.CREAM.b,
				0.6 if state == "hover" else 0.35)
		b.add_theme_stylebox_override(state, sb)
	var ink := Color(0.10, 0.07, 0.04)
	if primary:
		for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			b.add_theme_color_override(k, ink)
		b.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
	else:
		b.add_theme_color_override("font_color", Art.CREAM)
		b.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.45))
		b.add_theme_color_override("font_pressed_color", Art.CREAM_DIM)
	if cb.is_valid():
		b.pressed.connect(cb)
	parent.add_child(b)
	return b

func big_button(parent: Control, text: String, cb: Callable, subtitle := "", width := 600.0) -> Button:
	var b := Button.new()
	b.text = text if subtitle == "" else "%s\n%s" % [text, subtitle]
	b.custom_minimum_size = Vector2(width, BTN_H)
	b.add_theme_font_size_override("font_size", FONT_BODY)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = true
	if cb.is_valid():
		b.pressed.connect(cb)
	parent.add_child(b)
	return b

## Compact row of small buttons - ideal for +/- adjusters that would otherwise
## each eat a full-height row.
func adjuster(parent: Control, label_text: String, minus: Callable, plus: Callable) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var l := Label.new()
	l.text = label_text
	l.add_theme_font_size_override("font_size", FONT_BODY)
	l.custom_minimum_size = Vector2(330, 76)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)

	var bm := Button.new()
	bm.text = "-"
	bm.custom_minimum_size = Vector2(92, 76)
	bm.add_theme_font_size_override("font_size", 34)
	bm.pressed.connect(minus)
	row.add_child(bm)

	var bp := Button.new()
	bp.text = "+"
	bp.custom_minimum_size = Vector2(92, 76)
	bp.add_theme_font_size_override("font_size", 34)
	bp.pressed.connect(plus)
	row.add_child(bp)
	return l

func label(parent: Control, text: String, size := FONT_BODY) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func back_and_phone(root: Control, back_scene := "res://src/scenes/CityScene.tscn") -> void:
	# Sotto la barra di stato (54px) e BEN separati: i due bottoni prima
	# si sovrapponevano ai chip del StatusBar e tra loro.
	var b := Button.new()
	b.text = Loc.t("common.back", "BACK")
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b.position = Vector2(-348, 64)
	b.custom_minimum_size = Vector2(130, 62)
	b.add_theme_font_size_override("font_size", 20)
	b.clip_text = true
	b.pressed.connect(func(): SceneRouter.goto(back_scene))
	root.add_child(b)

	var p := Button.new()
	p.text = Loc.t("common.phone", "PHONE")
	p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	p.position = Vector2(-178, 64)
	p.custom_minimum_size = Vector2(130, 62)
	p.add_theme_font_size_override("font_size", 20)
	p.clip_text = true
	p.pressed.connect(func(): SceneRouter.open_phone())
	root.add_child(p)
