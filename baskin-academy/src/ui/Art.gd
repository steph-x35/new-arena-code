extends RefCounted
class_name Art
## HoopCity art direction, v1.8: one palette, one theme, one icon set.
##
## The identity comes from the logo: charcoal black, hardwood cream and a hot
## orange ball. Every screen pulls its colours from here so menus, HUD and
## courts finally look like the same game.

# ---------------------------------------------------------------- palette
const INK        := Color(0.078, 0.086, 0.110)   # near-black charcoal (menu bg)
const INK_SOFT   := Color(0.118, 0.129, 0.165)   # raised panels
const INK_LINE   := Color(0.220, 0.235, 0.280)   # hairlines / borders
const CREAM      := Color(0.965, 0.949, 0.906)   # paper white
const CREAM_DIM  := Color(0.760, 0.760, 0.780)   # secondary text
const ORANGE     := Color(0.949, 0.420, 0.114)   # the ball / primary accent
const ORANGE_HOT := Color(1.000, 0.560, 0.180)   # hover / highlights
const ORANGE_DK  := Color(0.720, 0.300, 0.080)   # pressed
const GREEN      := Color(0.478, 0.784, 0.310)   # stamina / positive
const RED        := Color(0.870, 0.290, 0.260)   # negative / defence
const BLUE       := Color(0.290, 0.560, 0.890)   # info / pass aim
const GOLD       := Color(0.980, 0.780, 0.260)   # perfect / rewards

# ------------------------------------------------------------ style boxes
static func sb_flat(col: Color, radius := 14, border := Color.TRANSPARENT,
		border_w := 0, pad := Vector2(18, 10)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.set_border_width_all(border_w)
		sb.border_color = border
	sb.content_margin_left = pad.x
	sb.content_margin_right = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_bottom = pad.y
	return sb

## The one true theme. Saved to res://src/ui/HoopTheme.tres by tools/MakeTheme
## and installed project-wide via gui/theme/custom, so EVERY Control (menus,
## shops, phone, dialogs) inherits the identity without touching each scene.
static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 24

	# --- Button: dark slab, orange edge on hover, solid orange when pressed.
	var bn := sb_flat(Color(0.129, 0.141, 0.180, 0.94), 14, Color(1, 1, 1, 0.10), 2)
	var bh := sb_flat(Color(0.176, 0.192, 0.243, 0.96), 14, ORANGE, 2)
	var bp := sb_flat(ORANGE_DK, 14, ORANGE_HOT, 2)
	var bd := sb_flat(Color(0.110, 0.118, 0.145, 0.70), 14, Color(1, 1, 1, 0.05), 2)
	for s in [["normal", bn], ["hover", bh], ["pressed", bp], ["disabled", bd],
			["focus", sb_flat(Color.TRANSPARENT, 14, ORANGE_HOT, 2)]]:
		th.set_stylebox(s[0], "Button", s[1])
	th.set_color("font_color", "Button", CREAM)
	th.set_color("font_hover_color", "Button", CREAM)
	th.set_color("font_pressed_color", "Button", CREAM)
	th.set_color("font_disabled_color", "Button", CREAM_DIM)
	th.set_font_size("font_size", "Button", 24)

	# --- Labels / headers
	th.set_color("font_color", "Label", CREAM)

	# --- Panels: the charcoal card look
	th.set_stylebox("panel", "PanelContainer",
		sb_flat(Color(0.098, 0.106, 0.137, 0.92), 16, Color(1, 1, 1, 0.07), 2, Vector2(20, 14)))
	th.set_stylebox("panel", "Panel", sb_flat(Color(0.098, 0.106, 0.137, 0.92), 16))

	# --- Progress (stamina, drill meters): dark track, orange fill
	th.set_stylebox("background", "ProgressBar",
		sb_flat(Color(0, 0, 0, 0.55), 10, Color(1, 1, 1, 0.12), 2, Vector2(6, 4)))
	th.set_stylebox("fill", "ProgressBar", sb_flat(GREEN, 10, Color.TRANSPARENT, 0, Vector2(6, 4)))

	# --- Scrollbars: slim, unobtrusive
	th.set_stylebox("scroll", "VScrollBar", sb_flat(Color(0, 0, 0, 0.35), 6))
	th.set_stylebox("grabber", "VScrollBar", sb_flat(Color(1, 1, 1, 0.28), 6))
	th.set_stylebox("scroll", "HScrollBar", sb_flat(Color(0, 0, 0, 0.35), 6))
	th.set_stylebox("grabber", "HScrollBar", sb_flat(Color(1, 1, 1, 0.28), 6))

	# --- OptionButton / LineEdit for the settings & creator screens
	for t in ["OptionButton"]:
		th.set_stylebox("normal", t, bn)
		th.set_stylebox("hover", t, bh)
		th.set_stylebox("pressed", t, bp)
		th.set_color("font_color", t, CREAM)
		th.set_color("font_hover_color", t, CREAM)
		th.set_font_size("font_size", t, 24)
	th.set_stylebox("normal", "LineEdit", sb_flat(Color(0, 0, 0, 0.45), 12, INK_LINE, 2))
	th.set_color("font_color", "LineEdit", CREAM)
	th.set_color("font_placeholder_color", "LineEdit", CREAM_DIM)
	th.set_stylebox("panel", "PopupMenu", sb_flat(INK_SOFT, 12))
	th.set_color("font_color", "PopupMenu", CREAM)
	th.set_color("font_hover_color", "PopupMenu", CREAM)
	th.set_stylebox("hover", "PopupMenu", sb_flat(ORANGE_DK, 8))
	return th

# ------------------------------------------------------------------ icons
## Minimal vector glyphs, drawn in the button's own rect so they scale with
## the pad. Keeps the touch controls readable without shipping a font atlas.
static func draw_icon(c: CanvasItem, kind: String, r: Rect2, col: Color) -> void:
	var cx := r.get_center()
	var s := minf(r.size.x, r.size.y) * 0.5
	var lw := maxf(s * 0.16, 2.0)
	match kind:
		"ball":
			c.draw_circle(cx, s * 0.78, col)
			var seam := col.lerp(Color.BLACK, 0.55)
			c.draw_arc(cx, s * 0.78, 0, TAU, 24, seam, lw * 0.7)
			c.draw_line(cx + Vector2(-s * 0.78, 0), cx + Vector2(s * 0.78, 0), seam, lw * 0.7)
			c.draw_arc(cx + Vector2(-s * 0.78, 0), s * 0.78, -0.9, 0.9, 12, seam, lw * 0.7)
			c.draw_arc(cx + Vector2(s * 0.78, 0), s * 0.78, PI - 0.9, PI + 0.9, 12, seam, lw * 0.7)
		"shoot":
			# ball + rising arc into a hoop line
			c.draw_circle(cx + Vector2(-s * 0.35, s * 0.35), s * 0.42, col)
			var pts := PackedVector2Array()
			for i in 13:
				var t := float(i) / 12.0
				pts.append(cx + Vector2(lerpf(-0.35, 0.55, t) * s,
					lerpf(0.35, -0.55, sin(t * PI * 0.62)) * s))
			c.draw_polyline(pts, col, lw * 0.8)
			c.draw_line(cx + Vector2(s * 0.28, -s * 0.62), cx + Vector2(s * 0.85, -s * 0.62), col, lw)
		"trick":
			# zig-zag dribble chevrons
			for k in [-1.0, 1.0]:
				var p := PackedVector2Array([
					cx + Vector2(-s * 0.62, k * s * 0.18),
					cx + Vector2(-s * 0.10, k * s * 0.62),
					cx + Vector2(s * 0.42, k * s * 0.18)])
				c.draw_polyline(p, col, lw)
		"pass":
			c.draw_polyline(PackedVector2Array([
				cx + Vector2(-s * 0.75, 0), cx + Vector2(s * 0.35, 0)]), col, lw)
			c.draw_colored_polygon(PackedVector2Array([
				cx + Vector2(s * 0.80, 0), cx + Vector2(s * 0.25, -s * 0.42),
				cx + Vector2(s * 0.25, s * 0.42)]), col)
		"pnr":
			# two dots + a screen bar
			c.draw_circle(cx + Vector2(-s * 0.40, s * 0.25), s * 0.26, col)
			c.draw_circle(cx + Vector2(s * 0.45, s * 0.25), s * 0.26, col)
			c.draw_rect(Rect2(cx.x - s * 0.12, cx.y - s * 0.75, s * 0.24, s * 0.85), col)
		"jump":
			c.draw_polyline(PackedVector2Array([
				cx + Vector2(-s * 0.55, s * 0.15), cx + Vector2(0, -s * 0.55),
				cx + Vector2(s * 0.55, s * 0.15)]), col, lw)
			c.draw_polyline(PackedVector2Array([
				cx + Vector2(-s * 0.55, s * 0.70), cx + Vector2(0, 0.0),
				cx + Vector2(s * 0.55, s * 0.70)]), col, lw * 0.8)
		"steal":
			# open hand reaching
			c.draw_circle(cx + Vector2(0, s * 0.35), s * 0.40, col)
			for k in [-0.52, -0.18, 0.18, 0.52]:
				c.draw_line(cx + Vector2(k * s, s * 0.10),
					cx + Vector2(k * s * 1.25, -s * 0.62), col, lw * 0.8)
		"defend":
			c.draw_colored_polygon(PackedVector2Array([
				cx + Vector2(0, -s * 0.75), cx + Vector2(s * 0.62, -s * 0.40),
				cx + Vector2(s * 0.55, s * 0.25), cx + Vector2(0, s * 0.78),
				cx + Vector2(-s * 0.55, s * 0.25), cx + Vector2(-s * 0.62, -s * 0.40)]), col)
		"check":
			c.draw_arc(cx, s * 0.72, 0, TAU, 24, col, lw)
			c.draw_polyline(PackedVector2Array([
				cx + Vector2(-s * 0.34, 0.0), cx + Vector2(-s * 0.08, s * 0.30),
				cx + Vector2(s * 0.38, -s * 0.28)]), col, lw * 0.9)
		"exit":
			c.draw_rect(Rect2(cx.x - s * 0.70, cx.y - s * 0.60, s * 0.85, s * 1.2), col, false, lw)
			c.draw_polyline(PackedVector2Array([
				cx + Vector2(-s * 0.05, 0), cx + Vector2(s * 0.75, 0)]), col, lw)
			c.draw_colored_polygon(PackedVector2Array([
				cx + Vector2(s * 0.80, 0), cx + Vector2(s * 0.40, -s * 0.35),
				cx + Vector2(s * 0.40, s * 0.35)]), col)
		"phone":
			c.draw_rect(Rect2(cx.x - s * 0.42, cx.y - s * 0.72, s * 0.84, s * 1.44), col, false, lw)
			c.draw_line(cx + Vector2(-s * 0.15, s * 0.48), cx + Vector2(s * 0.15, s * 0.48), col, lw * 0.8)
		"bolt":
			c.draw_colored_polygon(PackedVector2Array([
				cx + Vector2(s * 0.15, -s * 0.80), cx + Vector2(-s * 0.35, s * 0.10),
				cx + Vector2(-s * 0.02, s * 0.10), cx + Vector2(-s * 0.15, s * 0.80),
				cx + Vector2(s * 0.35, -s * 0.10), cx + Vector2(s * 0.02, -s * 0.10)]), col)
		"food":
			c.draw_circle(cx + Vector2(0, s * 0.10), s * 0.62, col)
			c.draw_circle(cx + Vector2(0, s * 0.10), s * 0.30, col.darkened(0.45))
		"heart":
			c.draw_colored_polygon(PackedVector2Array([
				cx + Vector2(0, s * 0.70), cx + Vector2(-s * 0.68, -s * 0.05),
				cx + Vector2(-s * 0.36, -s * 0.60), cx + Vector2(0, -s * 0.22),
				cx + Vector2(s * 0.36, -s * 0.60), cx + Vector2(s * 0.68, -s * 0.05)]), col)
		"coin":
			c.draw_circle(cx, s * 0.66, col)
			c.draw_arc(cx, s * 0.40, 0, TAU, 16, col.darkened(0.45), lw * 0.8)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + float(i) * PI / 5.0
				var rr := s * 0.72 if i % 2 == 0 else s * 0.32
				pts.append(cx + Vector2(cos(a) * rr, sin(a) * rr))
			c.draw_colored_polygon(pts, col)
		"clock":
			c.draw_arc(cx, s * 0.68, 0, TAU, 24, col, lw)
			c.draw_line(cx, cx + Vector2(0, -s * 0.42), col, lw * 0.9)
			c.draw_line(cx, cx + Vector2(s * 0.34, s * 0.12), col, lw * 0.9)
		"whistle":
			c.draw_circle(cx + Vector2(-s * 0.15, s * 0.15), s * 0.45, col)
			c.draw_rect(Rect2(cx.x - s * 0.15, cx.y - s * 0.45, s * 0.85, s * 0.42), col)
		"chat":
			c.draw_rect(Rect2(cx.x - s * 0.72, cx.y - s * 0.60, s * 1.44, s * 0.92), col, false, lw)
			c.draw_colored_polygon(PackedVector2Array([
				cx + Vector2(-s * 0.30, s * 0.30), cx + Vector2(-s * 0.04, s * 0.30),
				cx + Vector2(-s * 0.42, s * 0.72)]), col)
			for k in [-1, 0, 1]:
				c.draw_circle(cx + Vector2(k * s * 0.34, s * 0.14), s * 0.07 + lw * 0.4, col)
		"calendar":
			c.draw_rect(Rect2(cx.x - s * 0.70, cx.y - s * 0.55, s * 1.40, s * 1.15), col, false, lw)
			c.draw_rect(Rect2(cx.x - s * 0.70, cx.y - s * 0.55, s * 1.40, s * 0.26), col)
			for kx in [-0.38, 0.38]:
				c.draw_line(cx + Vector2(kx * s, -s * 0.76), cx + Vector2(kx * s, -s * 0.44), col, lw)
			for yy in [0.30, 0.62]:
				for kx2 in [-0.42, 0.0, 0.42]:
					c.draw_circle(cx + Vector2(kx2 * s, s * yy), s * 0.075 + lw * 0.3, col)
		"cart":
			c.draw_polyline(PackedVector2Array([
				cx + Vector2(-s * 0.80, -s * 0.55), cx + Vector2(-s * 0.48, -s * 0.55),
				cx + Vector2(-s * 0.22, s * 0.25), cx + Vector2(s * 0.62, s * 0.25),
				cx + Vector2(s * 0.82, -s * 0.35), cx + Vector2(-s * 0.38, -s * 0.35)]), col, lw)
			c.draw_circle(cx + Vector2(-s * 0.05, s * 0.64), s * 0.13, col)
			c.draw_circle(cx + Vector2(s * 0.48, s * 0.64), s * 0.13, col)
		"person":
			c.draw_arc(cx + Vector2(0, -s * 0.30), s * 0.34, 0, TAU, 20, col, lw)
			c.draw_polyline(PackedVector2Array([
				cx + Vector2(-s * 0.62, s * 0.75), cx + Vector2(-s * 0.50, s * 0.30),
				cx + Vector2(0, s * 0.12), cx + Vector2(s * 0.50, s * 0.30),
				cx + Vector2(s * 0.62, s * 0.75)]), col, lw)
		"chart":
			for k in 3:
				var hh: float = [0.45, 0.95, 0.68][k] * s
				var bx: float = cx.x + (k - 1) * s * 0.55 - s * 0.14
				c.draw_rect(Rect2(bx, cx.y + s * 0.70 - hh, s * 0.28, hh), col)
			c.draw_line(cx + Vector2(-s * 0.80, s * 0.74), cx + Vector2(s * 0.80, s * 0.74), col, lw * 0.8)
		"image":
			c.draw_rect(Rect2(cx.x - s * 0.75, cx.y - s * 0.60, s * 1.5, s * 1.2), col, false, lw)
			c.draw_circle(cx + Vector2(-s * 0.30, -s * 0.18), s * 0.12, col)
			c.draw_polyline(PackedVector2Array([
				cx + Vector2(-s * 0.55, s * 0.42), cx + Vector2(-s * 0.05, -s * 0.10),
				cx + Vector2(s * 0.25, s * 0.18), cx + Vector2(s * 0.60, -s * 0.18)]), col, lw * 0.9)
		_:
			c.draw_circle(cx, s * 0.6, col)

## Icon name per touch-pad action id (see MatchScene pad setup).
static func icon_for(action: String) -> String:
	match action:
		"SHOOT", "DUNK": return "shoot"
		"TRICK": return "trick"
		"PASS": return "pass"
		"P&R": return "pnr"
		"JUMP", "BLOCK": return "jump"
		"STEAL": return "steal"
		"DEFEND": return "defend"
		"CHECK": return "check"
	return "ball"
