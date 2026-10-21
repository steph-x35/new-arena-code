extends Node2D
## Il pet che ti segue in città. Prima viveva solo nell'appartamento (bonus
## da nutrito): adesso il primo pet posseduto ti accompagna nelle passeggiate,
## scodinzola quando cammini e ti aspetta se ti fermi. Disegnato a mano come
## tutto il resto del gioco: zero asset esterni.

var target: Node2D          # il CityPlayer da seguire
var species := "dog"        # dog | cat | rabbit | bird | turtle | altro = batuffolo
var facing := 1.0
var t := 0.0                # orologio per code e ali
var bob := 0.0              # fase dell'andatura (saltello)

const FOLLOW_DIST := 52.0   # sotto questa distanza si ferma e scodinzola
const FLY_HEIGHT := 46.0    # solo bird: vola sopra la spalla

func _process(delta: float) -> void:
	if target == null:
		return
	t += delta
	var to_t: Vector2 = target.position - position
	var d: float = to_t.length()
	if species == "bird":
		# il volatile vola: punto una posizione sopra la spalla del padrone
		var hover: Vector2 = target.position + Vector2(-34.0 * facing, -FLY_HEIGHT)
		position = position.lerp(hover, 3.5 * delta)
		if absf(target.position.x - position.x) > 3.0:
			facing = 1.0 if target.position.x > position.x else -1.0
	elif d > 640.0:
		# tropeo lontano (porta di un palazzo): riappare accanto al padrone
		position = target.position + Vector2(-44.0, 22.0)
	elif d > FOLLOW_DIST:
		var sp: float = clampf(170.0 + (d - FOLLOW_DIST) * 2.4, 170.0, 470.0)
		if species == "turtle":
			sp *= 0.62
		position += to_t.normalized() * sp * delta
		facing = 1.0 if to_t.x > 0.0 else -1.0
		bob = fmod(bob + delta * (7.0 if species != "turtle" else 3.0), TAU)
	else:
		# accanto al padrone: si ferma, respira e scodinzola
		bob = lerpf(bob, 0.0, 5.0 * delta)
		if absf(target.position.x - position.x) > 4.0:
			facing = 1.0 if target.position.x > position.x else -1.0
	z_index = 8          # stesso piano del giocatore: passa sopra i marciapiedi
	queue_redraw()

func _draw() -> void:
	var hop: float = absf(sin(bob)) * (3.0 if species != "turtle" else 0.8)
	var f: float = facing
	if species == "bird":
		_draw_bird(f)
	elif species == "cat":
		_draw_cat(Vector2(0, -hop), f)
	elif species == "rabbit":
		_draw_rabbit(Vector2(0, -hop * 1.6), f)
	elif species == "turtle":
		_draw_turtle(Vector2(0, 0), f)
	elif species == "dog":
		_draw_dog(Vector2(0, -hop), f)
	else:
		_draw_fluff(Vector2(0, -hop * 0.5), f)

func _draw_dog(p: Vector2, f: float) -> void:
	var body := Color(0.72, 0.50, 0.30)
	var dark := Color(0.52, 0.34, 0.18)
	# coda che scodinzola sempre, più forte quando cammini
	var wag: float = sin(t * (10.0 if bob > 0.05 else 4.0)) * 0.5
	var tail_base := p + Vector2(-13.0 * f, -10.0)
	draw_line(tail_base, tail_base + Vector2(-9.0 * f, -6.0 + wag * 8.0), dark, 3.0)
	# ZAMPINE che camminano: quando si muove, le gambe oscillano avanti e
	# indietro in alternanza (trotto); da fermo restano dritte
	var moving := bob > 0.05
	for j in 2:
		var lx := -7.0 if j == 0 else 7.0
		var swing := 0.0
		if moving:
			swing = sin(bob + PI * float(j)) * 4.5
		draw_line(p + Vector2(lx * f, 4.0),
			p + Vector2(lx * f + swing * f, 11.0 - absf(swing) * 0.2), dark, 2.6)
	# corpo e testa
	draw_circle(p + Vector2(1.0 * f, 0.0), 8.5, body)
	draw_circle(p + Vector2(11.0 * f, -6.0), 5.5, body)
	# orecchio e muso
	draw_circle(p + Vector2(9.0 * f, -10.5), 2.6, dark)
	draw_circle(p + Vector2(15.5 * f, -4.5), 1.8, dark)
	draw_circle(p + Vector2(13.0 * f, -7.2), 0.9, Color(0.1, 0.1, 0.12))
	# linguetta quando corre
	if bob > 0.05:
		draw_line(p + Vector2(16.0 * f, -3.0), p + Vector2(18.5 * f, 0.0), Color(0.95, 0.45, 0.5), 1.6)

func _draw_cat(p: Vector2, f: float) -> void:
	var body := Color(0.55, 0.56, 0.60)
	var dark := Color(0.35, 0.36, 0.40)
	# coda dritta con la punta che ondeggia
	var tip: float = sin(t * 3.2) * 3.0
	draw_line(p + Vector2(-12.0 * f, -4.0), p + Vector2(-18.0 * f, -14.0 + tip), dark, 2.6)
	for lx in [-6.0, 6.0]:
		var j2 := 0 if lx < 0.0 else 1
		var swing2 := sin(bob + PI * float(j2)) * 4.0 if bob > 0.05 else 0.0
		draw_line(p + Vector2(lx * f, 4.0), p + Vector2(lx * f + swing2 * f, 10.0 - absf(swing2) * 0.2), dark, 2.4)
	draw_circle(p + Vector2(0.0, 0.0), 7.5, body)
	draw_circle(p + Vector2(10.0 * f, -6.0), 5.0, body)
	# orecchie a triangolo
	var ear := PackedVector2Array([p + Vector2(7.0 * f, -10.0), p + Vector2(9.0 * f, -14.0), p + Vector2(11.0 * f, -10.0)])
	draw_colored_polygon(ear, body)
	ear = PackedVector2Array([p + Vector2(11.0 * f, -10.0), p + Vector2(13.0 * f, -14.0), p + Vector2(15.0 * f, -10.0)])
	draw_colored_polygon(ear, body)
	draw_circle(p + Vector2(12.0 * f, -6.6), 0.9, Color(0.1, 0.1, 0.12))

func _draw_rabbit(p: Vector2, f: float) -> void:
	var body := Color(0.94, 0.93, 0.90)
	var dark := Color(0.75, 0.74, 0.72)
	draw_circle(p + Vector2(0.0, 0.0), 7.0, body)
	draw_circle(p + Vector2(8.0 * f, -6.0), 4.6, body)
	# orecchie lunghe
	draw_line(p + Vector2(6.5 * f, -9.0), p + Vector2(6.0 * f, -17.0), body, 3.2)
	draw_line(p + Vector2(9.5 * f, -9.0), p + Vector2(10.0 * f, -16.0), body, 3.2)
	draw_circle(p + Vector2(9.6 * f, -6.8), 0.9, Color(0.15, 0.12, 0.12))
	# codina
	draw_circle(p + Vector2(-8.0 * f, -1.0), 2.6, dark)

func _draw_turtle(p: Vector2, f: float) -> void:
	var shell := Color(0.30, 0.62, 0.30)
	var skin := Color(0.55, 0.78, 0.45)
	draw_circle(p + Vector2(0.0, -2.0), 8.0, shell)
	draw_circle(p + Vector2(0.0, -2.0), 5.0, Color(0.22, 0.48, 0.24))
	draw_circle(p + Vector2(10.0 * f, -3.0), 3.4, skin)
	draw_circle(p + Vector2(13.2 * f, -4.0), 1.2, skin)
	# zampe tozze
	draw_circle(p + Vector2(-5.0 * f, 7.0), 2.4, skin)
	draw_circle(p + Vector2(5.0 * f, 7.0), 2.4, skin)

func _draw_bird(f: float) -> void:
	var body := Color(0.35, 0.65, 0.90)
	# ali che battono
	var flap: float = sin(t * 14.0) * 5.0
	draw_line(Vector2(-2.0 * f, -2.0), Vector2(-10.0 * f, -2.0 - flap), Color(0.25, 0.50, 0.75), 2.6)
	draw_circle(Vector2(0.0, 0.0), 5.0, body)
	draw_circle(Vector2(5.0 * f, -2.0), 3.0, body)
	draw_circle(Vector2(6.6 * f, -2.6), 0.8, Color(0.1, 0.1, 0.12))
	draw_line(Vector2(8.0 * f, -1.6), Vector2(10.5 * f, -1.0), Color(1.0, 0.75, 0.2), 1.6)

func _draw_fluff(p: Vector2, f: float) -> void:
	# hamster, snake &co in città: una pallina di pelo con gli occhi
	var body := Color(0.85, 0.72, 0.55)
	draw_circle(p, 6.0, body)
	draw_circle(p + Vector2(2.2 * f, -1.6), 0.8, Color(0.12, 0.10, 0.10))
	draw_circle(p + Vector2(-1.2 * f, -1.6), 0.8, Color(0.12, 0.10, 0.10))
	draw_circle(p + Vector2(-6.0 * f, 0.0), 2.2, Color(0.75, 0.60, 0.45))
