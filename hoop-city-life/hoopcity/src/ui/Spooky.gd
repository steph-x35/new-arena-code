extends Object
class_name Spooky
## HALLOWEEN (v2.49.3): zucche, ragnatele e pipistrelli, disegnati come tutto
## il resto -- vettori, zero immagini nuove. Un solo posto che decide SE e'
## Halloween, un solo posto che sa disegnare una zucca: la citta' e il
## campetto chiamano queste tre funzioni e basta.
##
## Quando compare: dal 18 ottobre al 5 novembre, dall'orologio VERO del
## telefono (non dal calendario di gioco: la carriera puo' essere a giugno e
## fuori piove). Nelle Impostazioni c'e' l'interruttore per spegnerlo o
## accenderlo a mano in qualsiasi momento.

const FROM_MONTH := 10
const FROM_DAY := 18
const TO_MONTH := 11
const TO_DAY := 5

static var _cached_frame := -1       # l'interruttore si legge 1 volta a frame
static var _cached := false


## Vero se oggi, sul calendario del telefono, e' periodo di Halloween.
static func in_season() -> bool:
	var d: Dictionary = Time.get_date_dict_from_system()
	var m: int = int(d.get("month", 1))
	var day: int = int(d.get("day", 1))
	if m == FROM_MONTH:
		return day >= FROM_DAY
	if m == TO_MONTH:
		return day <= TO_DAY
	return false


## L'interruttore vero: se lo hai mai toccato vale la tua scelta, altrimenti
## decide il calendario.
static func active() -> bool:
	var f: int = Engine.get_process_frames()
	if f != _cached_frame:
		_cached_frame = f
		var v = Settings.get_v("halloween", null)
		_cached = in_season() if v == null else bool(v)
	return _cached


## Butta via la cache: da chiamare quando l'interruttore cambia.
static func refresh() -> void:
	_cached_frame = -1


## ZUCCA INTAGLIATA. `base` e' il punto d'appoggio a terra (il centro in
## basso), `r` il raggio del corpo. `lit` accende la faccia (di notte), `glow`
## 0..1 e' quanto e' buio intorno: sopra 0.02 disegna l'alone caldo.
static func draw_pumpkin(c: CanvasItem, base: Vector2, r: float,
		lit := true, glow := 0.0) -> void:
	if r < 1.5:
		return
	var ctr: Vector2 = base - Vector2(0.0, r * 0.72)
	# ALONE: tre cerchi caldi, solo acceso e solo di notte
	if lit and glow > 0.02:
		for k in 3:
			c.draw_circle(ctr + Vector2(0.0, r * 0.10), r * (1.45 + 0.75 * k),
				Color(1.0, 0.58, 0.14, 0.085 * glow))
	# CORPO: tre lobi sovrapposti -- il centrale piu' chiaro, i laterali piu'
	# scuri, cosi' la zucca ha le costole senza una sola riga disegnata.
	var mid := Color(0.93, 0.45, 0.09)
	var side := Color(0.80, 0.33, 0.05)
	var under := Color(0.55, 0.20, 0.03, 0.55)
	c.draw_colored_polygon(PackedVector2Array([
		ctr + Vector2(-r * 0.98, r * 0.62), ctr + Vector2(r * 0.98, r * 0.62),
		ctr + Vector2(r * 0.62, r * 0.80), ctr + Vector2(-r * 0.62, r * 0.80)]), under)
	c.draw_circle(ctr + Vector2(-r * 0.44, 0.0), r * 0.62, side)
	c.draw_circle(ctr + Vector2(r * 0.44, 0.0), r * 0.62, side)
	c.draw_circle(ctr, r * 0.74, mid)
	# PICCIOLO verde storto
	c.draw_line(ctr + Vector2(0.0, -r * 0.68), ctr + Vector2(r * 0.13, -r * 1.02),
		Color(0.36, 0.46, 0.16), maxf(r * 0.17, 1.4))
	# FACCIA INTAGLIATA: due occhi triangolari e una bocca a zig-zag
	var face: Color = Color(1.0, 0.87, 0.42) if lit else Color(0.11, 0.05, 0.02)
	for sx in [-1.0, 1.0]:
		var ex: float = ctr.x + sx * r * 0.28
		var ey: float = ctr.y - r * 0.16
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(ex - r * 0.16, ey + r * 0.15),
			Vector2(ex + r * 0.16, ey + r * 0.15),
			Vector2(ex, ey - r * 0.18)]), face)
	var mw: float = r * 0.66
	var my: float = ctr.y + r * 0.30
	var grin := PackedVector2Array()
	for i in 5:
		var fx: float = ctr.x - mw * 0.5 + mw * float(i) / 4.0
		grin.append(Vector2(fx, my + (r * 0.07 if i % 2 == 0 else -r * 0.07)))
	c.draw_polyline(grin, face, maxf(r * 0.12, 1.4))


## RAGNATELA in un angolo. `corner` e' lo spigolo, `sx`/`sy` dicono verso
## quale dentro lo schermo si apre (+1 = verso destra / verso il basso).
static func draw_cobweb(c: CanvasItem, corner: Vector2, size: float,
		sx := 1.0, sy := 1.0, alpha := 0.30) -> void:
	if size < 2.0:
		return
	var col := Color(0.95, 0.95, 0.98, alpha)
	for i in 4:
		var a: float = PI * 0.5 * float(i) / 3.0
		c.draw_line(corner, corner + Vector2(cos(a) * sx, sin(a) * sy) * size, col, 1.2)
	for k in 3:
		var rr: float = size * (0.34 + 0.23 * float(k))
		var arc := PackedVector2Array()
		for i in 7:
			var a2: float = PI * 0.5 * float(i) / 6.0
			arc.append(corner + Vector2(cos(a2) * sx, sin(a2) * sy) * rr)
		c.draw_polyline(arc, Color(col, alpha * 0.75), 1.0)


## PIPISTRELLO: due ali che battono, sfasate col tempo. `s` e' l'apertura
## alare. Costa pochi comandi, quindi possono volare anche in gruppo.
static func draw_bat(c: CanvasItem, p: Vector2, s: float, t: float) -> void:
	if s < 1.0:
		return
	var flap: float = 0.5 + 0.5 * sin(t * 6.5 + p.x * 0.013)
	var body := Color(0.10, 0.09, 0.13, 0.92)
	var dy: float = -s * 0.16 - s * 0.34 * flap
	for sx in [-1.0, 1.0]:
		c.draw_colored_polygon(PackedVector2Array([
			p + Vector2(sx * s * 0.06, s * 0.02),
			p + Vector2(sx * s * 0.48, dy + s * 0.10),
			p + Vector2(sx * s * 0.98, dy + s * 0.34),
			p + Vector2(sx * s * 0.62, s * 0.06),
			p + Vector2(sx * s * 0.26, s * 0.12)]), body)
	c.draw_circle(p, s * 0.16, body)
	c.draw_line(p + Vector2(-s * 0.09, -s * 0.10), p + Vector2(-s * 0.14, -s * 0.26), body, 1.4)
	c.draw_line(p + Vector2(s * 0.09, -s * 0.10), p + Vector2(s * 0.14, -s * 0.26), body, 1.4)
