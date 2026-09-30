extends RefCounted
class_name PosterArt
## Draws a poster's actual artwork. Shared by the shop preview and the wall in
## the flat, so what you see before buying is exactly what you hang up.

static func draw_poster(c: CanvasItem, id: String, r: Rect2,
		night := 0.0, framed := true) -> void:
	var lib: Node = Engine.get_main_loop().root.get_node_or_null("Library")
	if lib == null or not lib.POSTERS.has(id):
		c.draw_rect(r, Color(0.30, 0.30, 0.36))
		c.draw_rect(r, Color(0, 0, 0, 0.3), false, 3.0)
		return
	var p: Dictionary = lib.POSTERS[id]
	var a: Color = Color(p["a"]).lerp(Color(0.35, 0.35, 0.42), night * 0.7)
	var b: Color = Color(p["b"]).lerp(Color(0.20, 0.20, 0.26), night * 0.7)
	var kind: String = String(p.get("kind", "photo"))

	c.draw_rect(r, b)
	match kind:
		"typographic":
			c.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.34,
				r.size.x, r.size.y * 0.30), a)
			var f := ThemeDB.fallback_font
			var fs: int = maxi(int(r.size.x * 0.16), 9)
			c.draw_string(f, r.position + Vector2(6.0, r.size.y * 0.56),
				String(p["name"]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER,
				r.size.x - 12.0, fs, b.lightened(0.85))
		"geometric":
			for k in 4:
				var h: float = r.size.y * 0.13
				c.draw_rect(Rect2(r.position.x + r.size.x * 0.07,
					r.position.y + r.size.y * 0.16 + k * (h + r.size.y * 0.045),
					r.size.x * 0.86, h), a.lerp(b, k * 0.22))
			c.draw_circle(r.position + Vector2(r.size.x * 0.72, r.size.y * 0.78),
				r.size.x * 0.16, a.lightened(0.25))
		_:
			c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, r.size.y * 0.58), a)
			c.draw_circle(r.position + Vector2(r.size.x * 0.68, r.size.y * 0.30),
				r.size.x * 0.15, a.lightened(0.45))
			c.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.58,
				r.size.x, r.size.y * 0.42), b.darkened(0.25))
			var fx: float = r.position.x + r.size.x * 0.34
			var fy: float = r.position.y + r.size.y * 0.72
			var s: float = r.size.y / 200.0
			c.draw_circle(Vector2(fx, fy - 26.0 * s), 7.0 * s, b.darkened(0.6))
			c.draw_line(Vector2(fx, fy - 19.0 * s), Vector2(fx, fy), b.darkened(0.6), 6.0 * s)
			c.draw_line(Vector2(fx, fy), Vector2(fx - 9.0 * s, fy + 18.0 * s), b.darkened(0.6), 5.0 * s)
			c.draw_line(Vector2(fx, fy), Vector2(fx + 9.0 * s, fy + 18.0 * s), b.darkened(0.6), 5.0 * s)

	if framed:
		c.draw_rect(r, Color(0.10, 0.09, 0.12), false, maxf(r.size.x * 0.035, 2.0))
		c.draw_line(r.position + Vector2(4, 4),
			r.position + Vector2(r.size.x * 0.4, 4.0), Color(1, 1, 1, 0.16), 2.0)
