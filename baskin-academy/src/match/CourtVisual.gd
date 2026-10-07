extends Node2D
## Procedural arena art: FIBA-proportioned floor, shared hoops, tiered crowd
## and overhead lighting. Replace by dropping a sprite in and deleting _draw().

var W: float = Court.COURT_W
var H: float = Court.COURT_H
var RIM: float = Court.RIM_HEIGHT

## Crowd is generated ONCE. The old version called randf() inside _draw(), so
## all 260 spectators teleported every single frame.
var crowd: Array = []
var t := 0.0
## "arena" (wood + stands) or "street" (asphalt + trees + graffiti). The court
## itself is identical either way -- this only changes the surroundings.
var env := "arena"
## Floor finish indoors: "maple" (league) or "blue" (championship look).
## Chosen on the pre-match screen, remembered in the profile.
var floor_style := "maple"

## Net reaction per hoop (0 = left, 1 = right), driven by Events.shot_taken.
var net_wobble := [0.0, 0.0, 0.0, 0.0]
var rim_shake := [0.0, 0.0, 0.0, 0.0]    # canestro che vibra (schiacciata/ferro)
var board_shake := [0.0, 0.0, 0.0, 0.0]  # il TABELLONE insegue il ferro in ritardo
var rim_bend := [0.0, 0.0]          # ferro sinistro/destro piegato dal peso
var rim_bend_v := [0.0, 0.0]
var crowd_hype := 0.0
var fx_kind := ""
var fx_t := 0.0
var fx_at := Vector2.ZERO
var fx_rh := -1.0     # altezza del ferro per l'fx (canestro basso del ruolo 1)
var _idle := 0.0
## v1.9: link to the match so benches/table/crowd fill follow the game state.
var court: Node = null
# live jumbotron state: score screens + made-basket flash
var jumbo_flash := 0.0
var jumbo_pts := 2
var _js_last := Vector2i(-1, -1)
var _js_clock := -1
var ball_x := 0.0                 # where the ball is: spectators track it
var crowd_on := false             # ONLY real league matches put people in the bowl
var flash_t := 0.0                # photographer flash sparkle timer
var flash_i := 0
var _bv := -1                     # last bench_version we drew
# --- broadcast pass: jumbotron marquee + club-coloured floor ---
# The marquee rides above the score strip: live messages (slams, threes,
# hype between quarters) in gold, rotating fake ads in grey the rest of the
# time. floor_tint (a = mix amount) nudges the maple toward the club colour
# of whoever owns the building tonight.
const ADS := ["BASKIN ACADEMY", "CITY FM 89.1", "HC SPORT", "BAR LOCANDA", "TIDE COLA"]
var marquee := ""
var marquee_t := 0.0
var _ad_i := 0
var _ad_t := 7.0
var floor_tint := Color(0.0, 0.0, 0.0, 0.0)

func jumbo_say(txt: String, secs := 3.2) -> void:
	marquee = txt
	marquee_t = secs
	queue_redraw()

func _tint(c: Color) -> Color:
	return c.lerp(Color(floor_tint.r, floor_tint.g, floor_tint.b), floor_tint.a) if floor_tint.a > 0.0 else c

## Cheerleaders: a row dances under the far stands all game; between quarters
## they run ONTO the court for a routine (see CheerSquad below).
var show_cheer := false
var cheer_on_court := false
var cheer: Node2D = null
## Rim height above the floor line, in this court's drawing space. Defaults
## to the match's realistic 3.05 m. The gym drills draw their players much
## bigger, so they raise this to keep the rim 1.6x a man's height there too.
var rim_height: float = Court.RIM_HEIGHT

## The floor, the markings and the empty stands never change once the match
## starts, so they are rasterised ONCE into a child that is never redrawn.
## Only the crowd bobbing and the nets swinging need per-frame work. Before
## this split every frame repainted ~1600 primitives -- the whole floor plus
## 785 spectators -- which is what made the match, the street court and the
## gym drills all stutter.
var static_layer: Node2D
## The centre-circle crest (the team/home logo) painted on the floor. Loaded
## once, drawn into the static layer, so it never costs a frame afterwards.
var logo: Texture2D = null

var crowd_layer: Node2D = null
var _courtside: Array = []
var photogs: Array = []
# The whole bowl (stands + frozen crowd + floor + lines) rasterised ONCE into
# a texture: per frame it costs a single textured quad instead of thousands
# of re-submitted primitives, which is what melted phones in the old builds.
var _static_tex: ImageTexture = null
var _static_rect := Rect2()
var _baking := false
var _rebake_pending := false

func _ready() -> void:
	z_index = -10
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep filling/animating while dialogs pause the tree
	_build_crowd()
	crowd_layer = CrowdLayer.new()
	crowd_layer.vis = self
	# Above the baked static layer (z -1) or the bowl raster hides the people;
	# still far below the players, which live outside CourtVisual's z (-10).
	crowd_layer.z_index = 0
	add_child(crowd_layer)
	logo = load("res://assets/center_logo.png") as Texture2D
	static_layer = CourtStatic.new()
	static_layer.owner_visual = self
	static_layer.z_index = -1
	static_layer.z_as_relative = true
	add_child(static_layer)
	static_layer.queue_redraw()
	request_rebake()
	# The cheer squad repaints itself every frame (it is small: a dozen
	# dancers), so the heavy court stays rasterised while they keep moving.
	cheer = CheerSquad.new()
	cheer.vis = self
	cheer.z_index = 1
	add_child(cheer)
	Events.shot_taken.connect(_on_shot)
	set_process(true)
	queue_redraw()

func _on_shot(_quality: String, made: bool, _pts: int) -> void:
	# Crowd reacts to a make. The NET only moves when the ball actually
	# touches iron / mesh (Court.check_ball_collisions -> net_bump).
	if made:
		crowd_hype = 1.0
		if crowd_on and randf() < 0.75:
			flash_i = randi() % maxi(1, photogs.size())
			flash_t = 0.34

## A rim clang or a board rattle from a MISSED shot, so the basket reacts to
## iron the same way it reacts to a swish. `idx` is 0 (left hoop) or 1 (right).
func rim_fx(kind: String, at: Vector2, rh := -1.0) -> void:
	fx_kind = kind
	fx_t = 1.35
	fx_at = at
	fx_rh = rh
	queue_redraw()

func net_bump(idx: int, amt: float) -> void:
	var i := clampi(idx, 0, 3)
	net_wobble[i] = maxf(net_wobble[i], amt)
	queue_redraw()

## IL CANESTRO VIBRA. Una scossa che si spegne in circa un secondo: la
## schiacciata la vuole al massimo (il ferro trema mentre sei appeso), il
## ferro sfiorato un filo.
func rim_quake(idx: int, amt: float) -> void:
	var i := clampi(idx, 0, 3)
	rim_shake[i] = maxf(rim_shake[i], amt)
	queue_redraw()

## Scostamento del canestro in questo istante (x,y in px). Zero quando e'
## fermo, cosi' il disegno non cambia di una virgola nel gioco normale.
func quake_off(idx: int) -> Vector2:
	var i := clampi(idx, 0, 3)
	var a: float = rim_shake[i]
	if a <= 0.0:
		return Vector2.ZERO
	return Vector2(sin(t * 37.0) * 5.0 * a, cos(t * 29.0) * 3.2 * a)

## IL TABELLONE ARRIVA DOPO. La scossa parte dal ferro e attraversa la
## struttura: il pannello insegue rim_shake con un filo di ritardo (molla
## lenta), cosi' all'impatto si vede prima il ferro e poi il tabellone.
func board_quake_off(idx: int) -> Vector2:
	var i := clampi(idx, 0, 3)
	var a: float = board_shake[i]
	if a <= 0.0:
		return Vector2.ZERO
	return Vector2(sin(t * 31.0) * 5.0 * a, cos(t * 25.0) * 3.2 * a)

func _process(delta: float) -> void:
	## Only re-rasterise when something is actually animating. Redrawing 350
	## spectators every frame tanked the sim and would burn phone battery.
	fx_t = maxf(0.0, fx_t - delta * 1.6)
	var live: bool = net_wobble[0] > 0.0 or net_wobble[1] > 0.0 or net_wobble[2] > 0.0 or net_wobble[3] > 0.0 or rim_shake[0] > 0.0 or rim_shake[1] > 0.0 or rim_shake[2] > 0.0 or rim_shake[3] > 0.0 or board_shake[0] > 0.01 or board_shake[1] > 0.01 or board_shake[2] > 0.01 or board_shake[3] > 0.01 or crowd_hype > 0.0 or fx_t > 0.0
	# Marquee housekeeping: live messages age out, ads rotate slowly. A change
	# on the strip schedules one redraw through the idle path below.
	if marquee_t > 0.0:
		marquee_t = maxf(0.0, marquee_t - delta)
		live = true
	_ad_t -= delta
	if _ad_t <= 0.0:
		_ad_t = 9.0
		_ad_i += 1
		if marquee_t <= 0.0:
			live = true
	t += delta
	for i in net_wobble.size():
		net_wobble[i] = HoopArt.decay(net_wobble[i], delta)
		rim_shake[i] = maxf(0.0, rim_shake[i] - delta * 1.15)
		board_shake[i] = lerpf(board_shake[i], rim_shake[i], clampf(delta * 14.0, 0.0, 1.0))
	# PIEGA DEL FERRO: target 1 se qualcuno è appeso a quel canestro.
	for i in 2:
		var target := 0.0
		if court != null:
			var pls: Array = court.get("players")
			for pl in pls:
				if pl.get("hanging"):
					var pos: Vector2 = pl.get("global_position")
					var hoops_v: Array = court.get("hoops")
					if hoops_v.size() == 2:
						var i_near := 0 if pos.distance_to(hoops_v[0]) < pos.distance_to(hoops_v[1]) else 1
						if i_near == i:
							target = 1.0
		# molla: carica con il peso, rimbalza quando molli
		rim_bend_v[i] += (target - rim_bend[i]) * 26.0 * delta
		rim_bend_v[i] *= maxf(0.0, 1.0 - 7.0 * delta)
		rim_bend[i] = clampf(rim_bend[i] + rim_bend_v[i] * delta, -0.25, 1.0)
		if absf(rim_bend[i]) > 0.003 or absf(rim_bend_v[i]) > 0.003:
			live = true
	crowd_hype = maxf(0.0, crowd_hype - delta * 0.8)
	flash_t = maxf(0.0, flash_t - delta)
	if live or flash_t > 0.0:
		queue_redraw()
		return
	if false:
		queue_redraw()
		return
	# Idle crowd sway is decorative: 8 fps is plenty and saves the frame budget
	# for the actual game.
	_idle += delta
	if _idle >= 0.125:
		_idle = 0.0
		queue_redraw()

	if court != null and env != "street":
		var sc := Vector2i(int(court.score[0]), int(court.score[1]))
		if sc != _js_last:
			if _js_last.x >= 0 or _js_last.y >= 0:
				jumbo_pts = maxi(2, (sc.x + sc.y) - (_js_last.x + _js_last.y))
				jumbo_flash = 1.0
			_js_last = sc
			queue_redraw()
		var ci := int(court.game_clock)
		if ci != _js_clock:
			_js_clock = ci
			queue_redraw()
		if jumbo_flash > 0.0:
			jumbo_flash = maxf(0.0, jumbo_flash - delta * 1.5)
			queue_redraw()

func _build_crowd() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260913
	# Stands ONLY at the back, starting WELL behind the bench row and
	# climbing away: rows of real chairs receding in perspective, spectators
	# seated or on their feet, mixed like a real crowd. Baked once (static).
	for row in 8:
		var sc: float = 0.92 - row * 0.040
		var y: float = -(H * 0.5 + 150.0 + row * 30.0)
		var step: float = 50.0 * sc
		var x: float = -W * 0.5 - 40.0 + rng.randf_range(0.0, step * 0.5)
		while x < W * 0.5 + 40.0:
			crowd.append({
				"p": Vector2(x, y),
				"c": Color.from_hsv(rng.randf(), rng.randf_range(0.30, 0.62),
					rng.randf_range(0.34, 0.78)),
				"skin": SKINS[rng.randi() % SKINS.size()],
				"hair": HAIRS[rng.randi() % HAIRS.size()],
				"sc": sc,
				"stand": rng.randf() < 0.16,
				"ph": rng.randf() * TAU,
				"sw": rng.randf_range(0.6, 1.6)})
			x += step + rng.randf_range(-3.0, 4.0)
	_courtside.clear()
	for s2 in [-1.0, 1.0]:
		for col in [52.0, 82.0]:
			var cx: float = s2 * (W * 0.5 + col)
			var cy: float = -H * 0.5 + 55.0
			while cy < H * 0.5 - 45.0:
				_courtside.append({
					"p": Vector2(cx, cy),
					"dir": -s2,
					"c": Color.from_hsv(rng.randf(), rng.randf_range(0.30, 0.60),
						rng.randf_range(0.34, 0.75)),
					"skin": SKINS[rng.randi() % SKINS.size()],
					"hair": HAIRS[rng.randi() % HAIRS.size()],
					"sc": 0.92})
				cy += 78.0 + rng.randf_range(-6.0, 6.0)
	photogs.clear()
	for gp in [Vector2(-(W * 0.5 + 108.0), -H * 0.30),
			Vector2(-(W * 0.5 + 108.0), H * 0.24),
			Vector2(W * 0.5 + 108.0, -H * 0.06)]:
		photogs.append({"p": gp, "dir": -signf(gp.x)})

func apply_env(e: String) -> void:
	env = e
	floor_style = String(Game.profile.get("floor_style", "maple"))
	if static_layer != null:
		static_layer.queue_redraw()
	request_rebake()
	queue_redraw()

## Bounds of everything the static layer paints, in local court coords.
func _static_bounds() -> Rect2:
	return Rect2(-W * 0.5 - 130, -H * 0.5 - 430, W + 260, H + 760)

## Ask for the bowl to be rasterised into `_static_tex` (one frame of a
## throwaway SubViewport, then a CPU readback). Falls back to vector drawing
## where readback is impossible (headless dummy renderer).
func request_rebake() -> void:
	# The floor finish is a pre-match choice stored in the profile; re-read it
	# on every rebake so the picker and the court can never disagree.
	floor_style = String(Game.profile.get("floor_style", "maple"))
	if env == "street":
		_static_tex = null
		if static_layer != null:
			static_layer.queue_redraw()
		return
	if _baking:
		_rebake_pending = true
		return
	_bake_static()

func _bake_static() -> void:
	_baking = true
	var b := _static_bounds()
	var sv := SubViewport.new()
	sv.size = Vector2i(int(b.size.x), int(b.size.y))
	sv.disable_3d = true
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sv)
	var bk := StaticBaker.new()
	bk.vis = self
	bk.position = -b.position
	sv.add_child(bk)
	bk.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	var tex: Texture2D = sv.get_texture()
	var img: Image = tex.get_image() if tex != null else null
	sv.queue_free()
	var ok := false
	if img != null and img.get_width() > 8 and img.get_height() > 8:
		# content check: parquet in the middle must be brighter than the bowl
		var corner := img.get_pixel(4, 4).get_luminance()
		var mid := img.get_pixel(int(img.get_width() * 0.5), int(img.get_height() * 0.62)).get_luminance()
		ok = mid > corner + 0.05
	if ok:
		_static_tex = ImageTexture.create_from_image(img)
		_static_rect = b
	else:
		_static_tex = null
	if static_layer != null:
		static_layer.queue_redraw()
	_baking = false
	if _rebake_pending:
		_rebake_pending = false
		_bake_static()

## Per-frame layer: ONLY the things that actually move.
## Floor lives on static_layer. Drawing it again here used draw_set_transform
## for the centre logo, which leaked and swallowed the hoops — shoot-around
## looked like a frozen parquet photo.
func _draw_jumbo() -> void:
	# Live score board hanging over centre court: team screens with the real
	# score, quarter + clock strip, and a flashing ring on every made basket
	# (bigger star for threes). Vector-drawn: a dozen calls per frame.
	if env == "street" or court == null:
		return
	var jp: Vector2 = _p(Vector2(0.0, -(H * 0.5 + 400.0)))
	var jy: float = jp.y
	for cx in [-70.0, 70.0]:
		draw_line(Vector2(cx, jy - 70.0), Vector2(cx * 0.55, jy), Color(0.30, 0.31, 0.36), 2.5)
	draw_rect(Rect2(-120.0, jy, 240.0, 74.0), Color(0.10, 0.11, 0.14))
	draw_rect(Rect2(-112.0, jy + 6.0, 224.0, 62.0), Color(0.04, 0.045, 0.06))
	# The two team screens glow in the clubs' real colours, not a default
	# blue/red: the jumbotron belongs to tonight's matchup.
	draw_rect(Rect2(-108.0, jy + 12.0, 88.0, 50.0), Game.team_colour(0).darkened(0.45))
	draw_rect(Rect2(20.0, jy + 12.0, 88.0, 50.0), Game.team_colour(1).darkened(0.45))
	draw_rect(Rect2(-20.0, jy + 12.0, 40.0, 50.0), Color(0.09, 0.09, 0.12))
	# Marquee strip above the board: gold while a live message is up, then
	# back to the rotating house ads.
	draw_rect(Rect2(-120.0, jy - 18.0, 240.0, 15.0), Color(0.04, 0.045, 0.06))
	var fnt: Font = ThemeDB.fallback_font
	var live_msg: bool = marquee_t > 0.0 and marquee != ""
	var mtxt: String = marquee if live_msg else String(ADS[_ad_i % ADS.size()])
	var mcol := Color(1.0, 0.86, 0.48) if live_msg else Color(0.62, 0.64, 0.70, 0.85)
	draw_string(fnt, Vector2(-120.0, jy - 6.5), mtxt,
		HORIZONTAL_ALIGNMENT_CENTER, 240.0, 10, mcol)
	draw_string(fnt, Vector2(-108.0, jy + 49.0), str(court.score[0]),
		HORIZONTAL_ALIGNMENT_CENTER, 88.0, 30, Color(1, 1, 1))
	draw_string(fnt, Vector2(20.0, jy + 49.0), str(court.score[1]),
		HORIZONTAL_ALIGNMENT_CENTER, 88.0, 30, Color(1, 1, 1))
	var ci2 := maxi(_js_clock, 0)
	draw_string(fnt, Vector2(-20.0, jy + 30.0), "T" + str(court.quarter),
		HORIZONTAL_ALIGNMENT_CENTER, 40.0, 12, Color(0.95, 0.78, 0.38))
	draw_string(fnt, Vector2(-20.0, jy + 52.0), "%02d:%02d" % [ci2 / 60, ci2 % 60],
		HORIZONTAL_ALIGNMENT_CENTER, 40.0, 12, Color(1.0, 0.86, 0.48))
	if jumbo_flash > 0.0:
		var a := clampf(jumbo_flash, 0.0, 1.0)
		draw_rect(Rect2(-112.0, jy + 6.0, 224.0, 62.0), Color(1, 0.9, 0.6, a * 0.45))
		draw_arc(Vector2(0.0, jy + 37.0), 34.0 + (1.0 - a) * 110.0, 0.0, TAU, 28,
			Color(1.0, 0.75, 0.3, a * 0.8), 3.0)
		if jumbo_pts >= 3:
			for k in 8:
				var ang: float = k * TAU / 8.0
				draw_line(Vector2(0.0, jy + 37.0) + Vector2(cos(ang), sin(ang)) * 20.0,
					Vector2(0.0, jy + 37.0) + Vector2(cos(ang), sin(ang)) * (46.0 + (1.0 - a) * 60.0),
					Color(1.0, 0.82, 0.35, a * 0.85), 3.0)

func _draw() -> void:
	if env != "street" and flash_t > 0.0 and photogs.size() > 0:
		var pg: Dictionary = photogs[flash_i % photogs.size()]
		var fp: Vector2 = _p(pg["p"]) + Vector2(pg["dir"] * 10.0, -25.0)
		var a: float = clampf(flash_t / 0.34, 0.0, 1.0)
		# loud press flash: white core, halo and a six-point star
		_c().draw_circle(fp, 18.0, Color(1, 1, 0.85, a * 0.30))
		_c().draw_circle(fp, 9.0, Color(1, 1, 0.95, a))
		for k in 6:
			var ang: float = PI * 0.25 + k * PI / 3.0
			_c().draw_line(fp + Vector2(cos(ang), sin(ang)) * 8.0,
				fp + Vector2(cos(ang), sin(ang)) * 22.0, Color(1, 1, 0.88, a * 0.9), 3.0)
	if env == "street":
		_draw_street_floods()
	# The board hangs BEHIND the iron: paint it first so the far side
	# basket is never covered by the jumbotron.
	_draw_jumbo()
	for s in [-1.0, 1.0]:
		var hx: float = s * (W * 0.5 - Court.FIBA_HOOP_INSET)
		# Pole at the centre of the short baseline. The BOARD is sheared to
		# follow that end line; the whole assembly sits slightly ABOVE the
		# floor so the height of the iron reads.
		var rim_floor: Vector2 = _p(Vector2(hx, 0.0))
		var baseline: Vector2 = _p(Vector2(s * W * 0.5, 0.0))
		var far: Vector2 = _p(Vector2(s * W * 0.5, -H * 0.5))
		var near: Vector2 = _p(Vector2(s * W * 0.5, H * 0.5))
		var lean: float = (near.x - far.x) / maxf(near.y - far.y, 1.0)
		var idx: int = 0 if s < 0.0 else 1
		var base_dx: float = absf(baseline.x - rim_floor.x)
		var q: Vector2 = quake_off(idx)
		# il tabellone riceve la sua scossa in RITARDO rispetto al ferro
		var qb: Vector2 = board_quake_off(idx)
		HoopArt.draw_hoop_unified(self, Vector2(rim_floor.x + q.x, rim_floor.y - rim_height + q.y),
			22.0, rim_floor.y + 6.0, -s, net_wobble[idx], t, lean, maxf(base_dx, 64.0),
			qb - q, clampf(rim_bend[idx], 0.0, 1.0))
	# BASKIN side baskets are drawn by NetFront, ON TOP of the players: the
	# rim must read as being in front of the pivot standing behind it (and it
	# fades while a body passes it).
	_draw_rim_fx()

func _draw_rim_fx() -> void:
	if fx_t <= 0.0 or fx_kind == "":
		return
	var _fh: float = fx_rh if fx_rh > 0.0 else (court.rim_height_of(fx_at) if (court != null and court.has_method("rim_height_of")) else rim_height)
	var p: Vector2 = _p(fx_at) + Vector2(0.0, -_fh)
	var a: float = fx_t
	match fx_kind:
		"swish":
			draw_circle(p, 16.0 + (1.0 - a) * 10.0, Color(0.25, 1.0, 0.40, a * 0.35))
			draw_arc(p, 28.0 + (1.0 - a) * 36.0, 0, TAU, 36, Color(0.30, 1.0, 0.45, a), 7.0)
			draw_arc(p, 14.0 + (1.0 - a) * 18.0, 0, TAU, 28, Color(0.85, 1.0, 0.55, a * 0.95), 4.0)
		"rattle":
			# Più grande e più caldo di "iron": doppio anello bianco-arancio
			# che si espande + scintille radiali. Il momento firma deve
			# vedersi anche dall'angolo telecamera dietro il tiro.
			draw_arc(p, 20.0 + (1.0 - a) * 30.0, 0, TAU, 32, Color(1, 1, 1, a), 8.0)
			draw_arc(p, 40.0 + (1.0 - a) * 55.0, 0, TAU, 36, Color(1.0, 0.62, 0.12, a * 0.9), 5.0)
			for i in 12:
				var ang2: float = TAU * float(i) / 12.0 + t * 5.0
				var q2: Vector2 = p + Vector2(cos(ang2), sin(ang2)) * (26.0 + (1.0 - a) * 42.0)
				draw_line(p, q2, Color(1.0, 0.85, 0.30, a), 4.0)
				draw_circle(q2, 5.0, Color(1, 1, 1, a))
		"iron":
			for i in 10:
				var ang: float = TAU * float(i) / 10.0 + t * 3.0
				var q: Vector2 = p + Vector2(cos(ang), sin(ang)) * (18.0 + (1.0 - a) * 28.0)
				draw_line(p, q, Color(1.0, 0.55, 0.12, a), 3.2)
				draw_circle(q, 4.0, Color(1.0, 0.85, 0.25, a))
			draw_arc(p, 28.0, 0, TAU, 24, Color(1.0, 0.70, 0.20, a * 0.9), 4.0)
		"miss":
			draw_arc(p, 32.0 + (1.0 - a) * 22.0, 0, TAU, 24, Color(1.0, 0.35, 0.28, a * 0.8), 4.0)

# --------------------------------------------------------------- projection
## Everything the court draws goes through these. The simulation stays flat
## and top-down; only the picture is tilted, so AI and physics are untouched.
func _p(v: Vector2) -> Vector2:
	return CourtStage.m_project(v, H)

func _pline(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	# Straight lines in court space stay straight under this projection only
	# along x; across y the lift is linear too, so two points are enough.
	_c().draw_line(_p(a), _p(b), col, w)

func _prect(r: Rect2, col: Color, w: float) -> void:
	var a := r.position
	var b := Vector2(r.end.x, r.position.y)
	var c := r.end
	var d := Vector2(r.position.x, r.end.y)
	for pair in [[a, b], [b, c], [c, d], [d, a]]:
		_pline(pair[0], pair[1], col, w)

func _pfill(r: Rect2, col: Color) -> void:
	_c().draw_colored_polygon(PackedVector2Array([
		_p(r.position), _p(Vector2(r.end.x, r.position.y)),
		_p(r.end), _p(Vector2(r.position.x, r.end.y))]), col)

func _parc(centre: Vector2, radius: float, a0: float, a1: float,
		steps: int, col: Color, w: float) -> void:
	var prev := Vector2.ZERO
	for i in steps + 1:
		var a: float = a0 + (a1 - a0) * (float(i) / float(steps))
		var pt: Vector2 = _p(centre + Vector2(cos(a) * radius, sin(a) * radius))
		if i > 0:
			_c().draw_line(prev, pt, col, w)
		prev = pt

## A painted stencil character on the floor (the sector values): a single
## digit, so the fallback font is fine and no extra resource is loaded.
func _pchar(txt: String, world: Vector2, col: Color, size := 16) -> void:
	var w := size * 1.2
	_c().draw_string(ThemeDB.fallback_font, _p(world) + Vector2(-w * 0.5, -size * 0.3),
		txt, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)

# ------------------------------------------------------------------ floor
func _draw_floor() -> void:
	# Light maple indoors, asphalt outdoors -- same floor, same markings.
	# Indoors the maple leans a few percent toward the home club's colour
	# (floor_tint set by MatchScene), so every building reads its own way.
	var wood: bool = env != "street"
	var blue: bool = wood and floor_style == "blue"
	var base := Color(0.86, 0.68, 0.42) if wood else Color(0.44, 0.46, 0.50)
	var plank_col := Color(0.83, 0.64, 0.39) if wood else Color(0.42, 0.44, 0.48)
	var seam := Color(0.55, 0.36, 0.18, 0.30)
	var seam_x := Color(0.55, 0.36, 0.18, 0.22)
	var paint := Color(0.35, 0.22, 0.55, 0.85) if wood else Color(0.20, 0.42, 0.38, 0.75)
	var paint2 := Color(0.62, 0.40, 0.22, 0.35)
	var surround := Color(0.30, 0.22, 0.16)
	if blue:
		# Championship blue: cool boards, navy lane, white lines still pop.
		base = Color(0.16, 0.28, 0.47)
		plank_col = Color(0.14, 0.25, 0.43)
		seam = Color(0.07, 0.14, 0.28, 0.45)
		seam_x = Color(0.07, 0.14, 0.28, 0.35)
		paint = Color(0.10, 0.20, 0.40, 0.90)
		paint2 = Color(0.20, 0.34, 0.55, 0.40)
		surround = Color(0.09, 0.13, 0.22)
	elif wood:
		base = _tint(base)
		plank_col = _tint(plank_col)
	_pfill(Rect2(-W * 0.5, -H * 0.5, W, H), base)
	# Painted lane: from the BASELINE to the free-throw line (FIBA 5.80 m).
	for s2 in [-1.0, 1.0]:
		var bx: float = s2 * W * 0.5
		var ftx: float = bx - s2 * Court.FIBA_KEY_LEN
		_pfill(Rect2(minf(bx, ftx), -Court.FIBA_PAINT_W * 0.5,
			Court.FIBA_KEY_LEN, Court.FIBA_PAINT_W), paint)
	# Parquet: alternating plank blocks with seams, matching the tone of the
	# perspective court so the venue reads as the same building.
	var plank := 26.0
	var rows: int = int(H / plank) + 1
	for i in range(rows):
		var y: float = -H * 0.5 + i * plank
		if i % 2 == 0:
			_pfill(Rect2(-W * 0.5, y, W, plank), plank_col)
		_pline(Vector2(-W * 0.5, y), Vector2(W * 0.5, y), seam, 1.5)
	var cols: int = int(W / 150.0) + 1
	for i in range(cols):
		var x: float = -W * 0.5 + i * 150.0
		_pline(Vector2(x, -H * 0.5), Vector2(x, H * 0.5), seam_x, 1.5)
	for s in [-1.0, 1.0]:
		var bx: float = s * W * 0.5
		var ftx: float = bx - s * Court.FIBA_KEY_LEN
		_pfill(Rect2(minf(bx, ftx), -Court.FIBA_PAINT_W * 0.5, Court.FIBA_KEY_LEN,
			Court.FIBA_PAINT_W), paint2)
	_prect(Rect2(-W * 0.5 - 60, -H * 0.5 - 40, W + 120, H + 80), surround, 34.0)

# ------------------------------------------------------------------ markings
func _draw_lines() -> void:
	var line := Color(0.97, 0.97, 0.95, 0.92)
	var lw := 4.0
	_prect(Rect2(-W * 0.5, -H * 0.5, W, H), line, lw)
	_pline(Vector2(0, -H * 0.5), Vector2(0, H * 0.5), line, lw)
	_parc(Vector2.ZERO, Court.FIBA_CENTRE_R, 0, TAU, 64, line, lw)

	for s in [-1.0, 1.0]:
		var hx: float = s * (W * 0.5 - Court.FIBA_HOOP_INSET)
		var base_x: float = s * W * 0.5
		var corner_y: float = H * 0.5 - Court.FIBA_CORNER_INSET

		# FIBA three-point line: two straights off the baseline joined by the
		# 6.75 m arc. A plain circle (the old art) is not a FIBA line.
		var dx: float = sqrt(maxf(Court.FIBA_ARC_R * Court.FIBA_ARC_R
			- corner_y * corner_y, 1.0))
		var arc_end_x: float = hx - s * dx
		for sy in [-1.0, 1.0]:
			_pline(Vector2(base_x, sy * corner_y), Vector2(arc_end_x, sy * corner_y),
				line, lw)
		var a0: float = atan2(-corner_y, -s * dx)
		var a1: float = atan2(corner_y, -s * dx)
		var d: float = a1 - a0
		while d > PI: d -= TAU
		while d < -PI: d += TAU
		var prev := Vector2.ZERO
		for i in 65:
			var a: float = a0 + d * (float(i) / 64.0)
			var p := _p(Vector2(hx + cos(a) * Court.FIBA_ARC_R, sin(a) * Court.FIBA_ARC_R))
			if i > 0:
				_c().draw_line(prev, p, line, lw)
			prev = p

		# Lane from the BASELINE (under the hoop) to the free-throw line.
		var key_len: float = Court.FIBA_KEY_LEN
		var px: float = base_x - s * key_len
		_prect(Rect2(minf(base_x, px), -Court.FIBA_PAINT_W * 0.5, key_len,
			Court.FIBA_PAINT_W), line, lw)
		# The solid half bulges away from the basket; the half inside the key
		# is dashed.
		var out0: float = PI * 0.5 if s > 0.0 else -PI * 0.5
		var out1: float = PI * 1.5 if s > 0.0 else PI * 0.5
		_parc(Vector2(px, 0), Court.FIBA_PAINT_W * 0.5, out0, out1, 32, line, lw)
		for i in 8:
			var b0: float = out1 + i * (PI / 8.0) + 0.06
			_parc(Vector2(px, 0), Court.FIBA_PAINT_W * 0.5, b0,
				b0 + (PI / 8.0) - 0.12, 6, line, lw * 0.7)
		# lane hash marks along the rectangle from the baseline
		for i in 4:
			var lx: float = base_x - s * (80.0 + i * 62.0)
			for sy2 in [-1.0, 1.0]:
				_pline(Vector2(lx, sy2 * Court.FIBA_PAINT_W * 0.5),
					Vector2(lx, sy2 * (Court.FIBA_PAINT_W * 0.5 + 12.0)), line, 3.0)
		# no-charge arc
		_parc(Vector2(hx, 0), Court.FIBA_RESTRICTED, out0, out1, 24,
			Color(0.97, 0.97, 0.95, 0.75), 3.0)
	# BASKIN side areas (Rev.19): the 3 m semicircle is split into FIVE
	# sectors (200/150/70/150/200 cm along the arc); the DASHED arc 0,7 m
	# beyond it (3,70 m) is the line the 2R and the role-3 free throws shoot
	# from. Painted spot values tell a first-timer what each sector pays.
	for shy in [-1.0, 1.0]:
		var hc := Vector2(0.0, shy * H * 0.5)
		var a0: float = 0.0 if shy < 0.0 else PI
		# White like every other line on the floor (it used to be orange and
		# blue, which made the areas read as a different court).
		_parc(hc, Court.SIDE_AREA_R, a0, a0 + PI, 40, line, 4.0)
		# The dashed 3,70 m arc: 2R shots and role-3 free throws come from
		# behind THIS line, not the continuous one.
		for i in 14:
			_parc(hc, Court.SIDE_DASH_R, a0 + i * (PI / 14.0) + 0.05,
				a0 + (i + 1) * (PI / 14.0) - 0.05, 4, Color(0.97, 0.97, 0.95, 0.82), 2.5)
		# FIVE sectors (Rev.19 fig. 2): sui campi veri i settori sono segnalati
		# da TRATTI di nastro che attraversano la linea, non da raggi che
		# partono da meta' campo. Quattro tacche radiali ai confini
		# (200/350/420/570 cm dei 770 cm di semicerchio).
		for cm in [200.0, 350.0, 420.0, 570.0]:
			var sa: float = a0 + (cm / 770.0) * PI
			var dir := Vector2(cos(sa), sin(sa))
			_pline(hc + dir * (Court.SIDE_AREA_R - 16.0),
				hc + dir * (Court.SIDE_AREA_R + 12.0),
				Color(0.97, 0.97, 0.95, 0.85), 3.0)
		# Solo il "2" del settore centrale dipinto a pavimento: i 3 laterali
		# affollavano l'area (feedback playtest); il valore lo dice il chip.
		var in_dir := Vector2(0.0, -shy)
		_pchar("2", hc + in_dir * 92.0, Color(0.97, 0.97, 0.95, 0.5), 17)

## Everything that never moves, drawn a single time.
class CourtStatic extends Node2D:
	var owner_visual: Node2D
	func _ready() -> void:
		queue_redraw()
	func _draw() -> void:
		if owner_visual == null:
			return
		if owner_visual._static_tex != null:
			# the baked bowl: one textured quad per frame
			draw_texture_rect(owner_visual._static_tex, owner_visual._static_rect, false)
			return
		owner_visual.draw_static_into(self)

## Throwaway painter used to rasterise the static bowl into a viewport.
class StaticBaker extends Node2D:
	var vis: Node2D = null
	func _draw() -> void:
		if vis != null:
			vis.draw_static_into(self)

## The cheerleaders. A row of them dances under the far stands throughout the
## match; when the CourtVisual's `cheer_on_court` is set (between quarters)
## they move onto the court for a bigger routine. Drawn here, in a node that
## repaints only itself, so the static court never has to re-rasterise for
## their sake.
class CheerSquad extends Node2D:
	var vis: Node2D = null
	var t := 0.0
	var _acc := 0.0
	var palette := [Color(0.90, 0.30, 0.34), Color(0.95, 0.95, 0.97),
		Color(0.22, 0.45, 0.80)]

	func _process(delta: float) -> void:
		if vis == null or not vis.show_cheer:
			return
		t += delta
		_acc += delta
		if _acc >= 0.066:
			_acc = 0.0
			queue_redraw()

	func _draw() -> void:
		if vis == null or not vis.show_cheer:
			return
		var h: float = vis.H
		# Under the far stands: a row of small dancers on the apron between
		# the stand rail and the far sideline, spread across the court.
		# Apron in FRONT of the bench row: dancers read as a foreground row
		# with the seated reserves behind them.
		var rail_y: float = -(h * 0.5 + 14.0)
		var side_x := -620.0
		var i := 0
		var wf: float = lerpf(0.76, 1.16, CourtStage.m_depth(rail_y, h))
		while side_x < 620.0:
			# project the feet onto the apron: raw coords made them float
			var base: Vector2 = vis._p(Vector2(side_x, rail_y))
			draw_rect(Rect2(base.x - 14.0 * wf, base.y - 2.0, 28.0 * wf, 6.0 * wf),
				Color(0, 0, 0, 0.30))
			_dancer(base, 40.0 * wf, t + i * 0.9, palette[i % 3])
			side_x += 140.0
			i += 1
		# On the court, between quarters: a bigger, more energetic routine at
		# centre court. Sized up with the players (the match players are now
		# 56 px tall), so the squad reads as part of the same world.
		if vis.cheer_on_court:
			for k in 6:
				var wp: Vector2 = Vector2(-200.0 + (k % 3) * 200.0, 40.0 + (k / 3) * 70.0)
				var base: Vector2 = vis._p(wp)
				var wf2: float = lerpf(0.76, 1.16, CourtStage.m_depth(wp.y, h))
				draw_rect(Rect2(base.x - 18.0 * wf2, base.y - 2.0, 36.0 * wf2, 7.0 * wf2),
					Color(0, 0, 0, 0.30))
				_dancer(base, 52.0 * wf2, t * 1.6 + k * 1.1, palette[k % 3])

	## One dancer: kicking legs, a swaying skirt, two pom-poms pumping in
	## opposite phase. `ph` is her personal clock, `out` her outfit colour.
	func _dancer(p: Vector2, h: float, ph: float, out: Color) -> void:
		var bob: float = absf(sin(ph * 2.2)) * h * 0.10
		var sway: float = sin(ph * 1.1) * h * 0.10
		var hip := p + Vector2(sway, -h * 0.42 + bob)
		# legs, kicking alternately
		for s in [-1.0, 1.0]:
			var kick: float = sin(ph * 2.2 + (0.0 if s < 0 else PI)) * h * 0.22
			var foot := hip + Vector2(s * h * 0.14 + kick * 0.4, h * 0.30 - maxf(kick, 0.0) * 0.4)
			draw_line(hip, foot, Color(0.72, 0.60, 0.55), h * 0.07)
			draw_line(foot + Vector2(0, -h * 0.05), foot + Vector2(s * h * 0.10, 0),
				Color(0.95, 0.95, 0.97), h * 0.06)
		# skirt
		var sk := PackedVector2Array([
			hip + Vector2(-h * 0.20, 0), hip + Vector2(h * 0.20, 0),
			hip + Vector2(h * 0.26, h * 0.12), hip + Vector2(-h * 0.26, h * 0.12)])
		draw_colored_polygon(sk, out)
		# torso
		var sh := hip + Vector2(sway * 0.6, -h * 0.26)
		draw_line(hip, sh, out, h * 0.11)
		# arms + pom-poms, pumping out of phase
		for s in [-1.0, 1.0]:
			var up: float = sin(ph * 2.2 + (0.0 if s < 0 else PI))
			var hand := sh + Vector2(s * h * 0.26, -h * 0.10 - up * h * 0.20)
			draw_line(sh, hand, Color(0.72, 0.60, 0.55), h * 0.06)
			draw_circle(hand, h * 0.10, out.lerp(Color.WHITE, 0.5))
			draw_circle(hand, h * 0.05, Color(1, 1, 1, 0.85))
		# head + ponytail
		var head := sh + Vector2(0, -h * 0.16)
		draw_circle(head, h * 0.12, Color(0.72, 0.53, 0.38))
		draw_circle(head + Vector2(-h * 0.06, -h * 0.05), h * 0.13, Color(0.12, 0.09, 0.08))
		draw_line(head, head + Vector2(-h * 0.16, h * 0.05 + sin(ph * 2.2) * h * 0.06),
			Color(0.12, 0.09, 0.08), h * 0.05)

## Paint the unchanging court into `c`. Called once by the static layer.
func draw_static_into(c: CanvasItem) -> void:
	_target = c
	if env == "street":
		CourtStage._full_street_backdrop(c, maxf(W * 1.6, 2800.0), H, 0.0)
	else:
		_draw_stands()
		if crowd_on:
			_draw_crowd_static()
			_draw_courtside()
			_draw_photogs()
		_draw_hanging_decor()
		_draw_bench_furniture()
	_draw_floor()
	_draw_lines()
	_draw_center_logo(c)
	_draw_light_pools()
	_target = null

## The centre-circle crest: the logo texture, laid flat on the floor inside
## the centre circle and squashed with the court's own foreshortening.
func _draw_center_logo(c: CanvasItem) -> void:
	if logo == null:
		return
	var lw: float = logo.get_width()
	var lh: float = logo.get_height()
	if lw <= 0.0 or lh <= 0.0:
		return
	var centre: Vector2 = CourtStage.m_project(Vector2.ZERO, H)
	var edge: Vector2 = CourtStage.m_project(Vector2(Court.FIBA_CENTRE_R, 0.0), H)
	var target_w: float = absf(edge.x - centre.x) * 2.0 * 0.72
	if target_w < 8.0 or lw < 1.0:
		return
	var target_h: float = target_w * (lh / lw) * CourtStage.M_SQUASH
	c.draw_texture_rect(logo,
		Rect2(centre.x - target_w * 0.5, centre.y - target_h * 0.55, target_w, target_h),
		false)

## Where the current primitive should go: the static layer while it is being
## built, otherwise this node.
var _target: CanvasItem = null

func _c() -> CanvasItem:
	return _target if _target != null else self

# ------------------------------------------------------------------ crowd
## Spectators, FROZEN: baked into the static layer once per match setup.
## Redrawing ~300 NPCs every frame (or even at 8 fps) was the single biggest
## frame cost on phones; a still crowd reads exactly the same from the seat.
func _draw_crowd_static() -> void:
	if env == "street":
		return
	for sp in crowd:
		var base: Vector2 = _p(sp["p"])
		var sc: float = sp["sc"]
		var lean: float = sin(sp["ph"]) * 0.7 * sc
		if sp["stand"]:
			_npc_standing(base, sp["c"], sp["skin"], sp["hair"], sc * 0.92, lean, false)
		else:
			_npc_seated(base, sp["c"], sp["skin"], sp["hair"], sc, lean,
				sin(sp["ph"] * 3.1) > 0.92)

## Jumbotron + speaker clusters: drawn AFTER the crowd so they hang in front
## of the upper bowl, inside the broadcast band.
func _draw_hanging_decor() -> void:
	if env == "street":
		return
	# hanging speaker clusters over both ends of the bowl
	for s3 in [-1.0, 1.0]:
		var spp: Vector2 = _p(Vector2(s3 * W * 0.36, -(H * 0.5 + 315.0)))
		_c().draw_line(Vector2(spp.x, spp.y - 70.0), Vector2(spp.x, spp.y + 6.0), Color(0.30, 0.31, 0.36), 2.5)
		_c().draw_colored_polygon(PackedVector2Array([
			Vector2(spp.x - 34.0, spp.y + 6.0), Vector2(spp.x + 34.0, spp.y + 6.0),
			Vector2(spp.x + 26.0, spp.y + 58.0), Vector2(spp.x - 26.0, spp.y + 58.0)]),
			Color(0.12, 0.13, 0.16))
		for li in 3:
			_c().draw_circle(Vector2(spp.x, spp.y + 18.0 + li * 14.0), 6.0, Color(0.05, 0.05, 0.07))

## Courtside seats behind both baselines: fans watching from the short sides.
func _draw_courtside() -> void:
	if env == "street":
		return
	for sp in _courtside:
		var base: Vector2 = _p(sp["p"])
		_npc_side(base, sp["c"], sp["skin"], sp["hair"], sp["sc"], sp["dir"])

## A few photographers crouched behind the baselines, cameras on the match.
func _draw_photogs() -> void:
	if env == "street":
		return
	for pg in photogs:
		var sp: Vector2 = _p(pg["p"])
		var dir: float = pg["dir"]
		var sc := 0.95
		# crouched legs
		_c().draw_line(sp + Vector2(0, -10.0 * sc), sp + Vector2(-dir * 6.0 * sc, 0), Color(0.16, 0.17, 0.22), 3.4 * sc)
		_c().draw_line(sp + Vector2(0, -10.0 * sc), sp + Vector2(dir * 5.0 * sc, 0), Color(0.16, 0.17, 0.22), 3.4 * sc)
		# leaning torso + head behind the camera
		var sh: Vector2 = sp + Vector2(dir * 7.0 * sc, -20.0 * sc)
		_c().draw_line(sp + Vector2(0, -10.0 * sc), sh, Color(0.20, 0.22, 0.30), 5.0 * sc)
		_c().draw_circle(sh + Vector2(dir * 3.0 * sc, -4.0 * sc), 4.6 * sc, Color(0.72, 0.53, 0.38))
		# camera body + lens aimed at the court
		_c().draw_rect(Rect2(sh.x + dir * 5.0 * sc - 3.5 * sc, sh.y - 7.5 * sc, 7.0 * sc, 5.0 * sc), Color(0.10, 0.10, 0.12))
		_c().draw_circle(sh + Vector2(dir * 10.0 * sc, -5.0 * sc), 2.0 * sc, Color(0.35, 0.38, 0.45))

## Side-view seated fan (courtside rows): faces `dir` toward the court.
func _npc_side(sp: Vector2, cloth: Color, skin: Color, hair: Color,
		sc: float, dir: float) -> void:
	_c().draw_rect(Rect2(sp.x - dir * 9.0 * sc - 6.0 * sc, sp.y - 9.0 * sc, 12.0 * sc, 9.0 * sc),
		Color(0.185, 0.20, 0.27))
	_c().draw_line(sp + Vector2(-dir * 2.0 * sc, -10.0 * sc), sp + Vector2(dir * 9.0 * sc, -10.0 * sc), cloth.darkened(0.35), 4.0 * sc)
	_c().draw_line(sp + Vector2(dir * 9.0 * sc, -10.0 * sc), sp + Vector2(dir * 9.0 * sc, 0), Color(0.16, 0.17, 0.22), 3.0 * sc)
	_c().draw_line(sp + Vector2(-dir * 2.0 * sc, -10.0 * sc), sp + Vector2(-dir * 3.0 * sc, -24.0 * sc), cloth, 5.0 * sc)
	_c().draw_line(sp + Vector2(-dir * 3.0 * sc, -21.0 * sc), sp + Vector2(dir * 6.0 * sc, -15.0 * sc), skin, 2.4 * sc)
	_c().draw_circle(sp + Vector2(-dir * 3.5 * sc, -29.0 * sc), 5.0 * sc, skin)
	_c().draw_circle(sp + Vector2(-dir * 5.0 * sc, -30.5 * sc), 4.4 * sc, hair)

func _draw_stands() -> void:
	# Arena shell: dark bowl wrapping the whole floor.
	_c().draw_rect(Rect2(-W * 0.5 - 130, -H * 0.5 - 430, W + 260, H + 760),
		Color(0.08, 0.09, 0.12))
	# tiered seating decks, FAR side only: eight receding rows of chairs,
	# starting well behind the benches and climbing up like a real bowl
	for row in 8:
		var y: float = -(H * 0.5 + 150.0 + row * 30.0)
		var col: Color = Color(0.10, 0.11, 0.16).lerp(Color(0.045, 0.05, 0.075), row / 8.0)
		_c().draw_colored_polygon(PackedVector2Array([
			_p(Vector2(-W * 0.5 - 60, y)), _p(Vector2(W * 0.5 + 60, y)),
			_p(Vector2(W * 0.5 + 60, y + 30.0)), _p(Vector2(-W * 0.5 - 60, y + 30.0))]), col)
	# concourse walkway between the dasher wall and the first stand row:
	# reads as empty floor, so the benches never sit "inside" the crowd
	_c().draw_colored_polygon(PackedVector2Array([
		_p(Vector2(-W * 0.5 - 60, -(H * 0.5 + 94.0))), _p(Vector2(W * 0.5 + 60, -(H * 0.5 + 94.0))),
		_p(Vector2(W * 0.5 + 60, -(H * 0.5 + 150.0))), _p(Vector2(-W * 0.5 - 60, -(H * 0.5 + 150.0)))]),
		Color(0.07, 0.075, 0.10))
	# dasher wall separating the bench apron from the first stand row
	_c().draw_colored_polygon(PackedVector2Array([
		_p(Vector2(-W * 0.5 - 60, -(H * 0.5 + 66.0))), _p(Vector2(W * 0.5 + 60, -(H * 0.5 + 66.0))),
		_p(Vector2(W * 0.5 + 60, -(H * 0.5 + 94.0))), _p(Vector2(-W * 0.5 - 60, -(H * 0.5 + 94.0)))]),
		Color(0.13, 0.14, 0.19))
	_c().draw_line(_p(Vector2(-W * 0.5 - 60, -(H * 0.5 + 66.0))),
		_p(Vector2(W * 0.5 + 60, -(H * 0.5 + 66.0))), Color(0.95, 0.62, 0.20, 0.55), 3.0)
	# the chairs themselves (empty seats read as furniture, not noise)
	for sp in crowd:
		var p: Vector2 = sp["p"]
		var sc: float = sp["sc"]
		var pr: Vector2 = _p(p)
		var wf: float = lerpf(0.76, 1.16, CourtStage.m_depth(p.y, H))
		var cw: float = 15.0 * sc * wf
		_c().draw_rect(Rect2(pr.x - cw * 0.5, pr.y - 1.0, cw, 7.0 * sc),
			Color(0.185, 0.20, 0.27))
		_c().draw_rect(Rect2(pr.x - cw * 0.5, pr.y - 9.0 * sc, cw, 8.0 * sc),
			Color(0.135, 0.15, 0.21))
	# low rail capping the dasher wall, plus one at the concourse edge
	_c().draw_colored_polygon(PackedVector2Array([
		_p(Vector2(-W * 0.5 - 60, -(H * 0.5 + 94.0))), _p(Vector2(W * 0.5 + 60, -(H * 0.5 + 94.0))),
		_p(Vector2(W * 0.5 + 60, -(H * 0.5 + 99.0))), _p(Vector2(-W * 0.5 - 60, -(H * 0.5 + 99.0)))]),
		Color(0.16, 0.17, 0.23))
	_c().draw_colored_polygon(PackedVector2Array([
		_p(Vector2(-W * 0.5 - 60, -(H * 0.5 + 148.0))), _p(Vector2(W * 0.5 + 60, -(H * 0.5 + 148.0))),
		_p(Vector2(W * 0.5 + 60, -(H * 0.5 + 153.0))), _p(Vector2(-W * 0.5 - 60, -(H * 0.5 + 153.0)))]),
		Color(0.16, 0.17, 0.23))
	# end-zone blocks behind each basket
	for s2 in [-1.0, 1.0]:
		var ex: float = s2 * (W * 0.5 + 60.0)
		_c().draw_rect(Rect2(minf(ex, ex + s2 * 70.0), -H * 0.5 - 40, 70.0, H + 80),
			Color(0.09, 0.10, 0.15))
	# NEAR side: broadcast ad wall instead of a second bowl
	_c().draw_colored_polygon(PackedVector2Array([
		_p(Vector2(-W * 0.5 - 60, H * 0.5 + 24.0)), _p(Vector2(W * 0.5 + 60, H * 0.5 + 24.0)),
		_p(Vector2(W * 0.5 + 60, H * 0.5 + 58.0)), _p(Vector2(-W * 0.5 - 60, H * 0.5 + 58.0))]),
		Color(0.10, 0.11, 0.15))
	for i in 14:
		var ax: float = -W * 0.5 - 40.0 + i * (W + 80.0) / 14.0
		var bw2: float = (W + 80.0) / 14.0 - 8.0
		_c().draw_colored_polygon(PackedVector2Array([
			_p(Vector2(ax, H * 0.5 + 28.0)), _p(Vector2(ax + bw2, H * 0.5 + 28.0)),
			_p(Vector2(ax + bw2, H * 0.5 + 54.0)), _p(Vector2(ax, H * 0.5 + 54.0))]),
			Color(0.949, 0.420, 0.114, 0.30) if i % 2 == 0 else Color(0.85, 0.86, 0.90, 0.22))
	# upper deck: a far ring of seats hugging the top of the frame, with its
	# own sparse crowd when the arena is open -- real arenas climb upward.
	_c().draw_rect(Rect2(-W * 0.5 - 130, -H * 0.5 - 430, W + 260, 62.0),
		Color(0.055, 0.06, 0.09))
	if crowd_on:
		var ux: float = -W * 0.5 - 100.0
		while ux < W * 0.5 + 100.0:
			var hsh: float = absf(sin(ux * 12.9898) * 43758.5453)
			if fmod(hsh, 1.0) < 0.70:
				var rowy: float = -H * 0.5 - 418.0 + fmod(hsh * 3.7, 2.0) * 22.0
				_c().draw_circle(Vector2(ux, rowy), 3.6,
					Color.from_hsv(fmod(hsh * 7.13, 1.0), 0.42, 0.50))
				_c().draw_circle(Vector2(ux, rowy - 4.5), 2.5, Color(0.72, 0.58, 0.47))
			ux += 24.0
	_c().draw_rect(Rect2(-W * 0.5 - 130, -H * 0.5 - 372, W + 260, 6.0),
		Color(0.16, 0.17, 0.23))
	# roof girders and hanging lights, so the arena has a ceiling
	for i in 9:
		var gx: float = lerpf(-W * 0.5, W * 0.5, float(i) / 8.0)
		_c().draw_line(Vector2(gx, -H * 0.5 - 300), Vector2(gx, H * 0.5 + 300),
			Color(1, 1, 1, 0.030), 6.0)
	for i in 6:
		var lx: float = lerpf(-W * 0.4, W * 0.4, float(i) / 5.0)
		for ly in [-H * 0.5 - 405.0, H * 0.5 + 150.0]:
			_c().draw_rect(Rect2(lx - 40, ly - 10, 80, 20), Color(0.20, 0.21, 0.27))
			_c().draw_circle(Vector2(lx, ly), 9.0, Color(1.0, 0.97, 0.85, 0.85))

# ------------------------------------------------------------------ lighting
func _draw_light_pools() -> void:
	if env == "street":
		return
	for i in 4:
		var x: float = lerpf(-W * 0.35, W * 0.35, i / 3.0)
		for k in 5:
			_c().draw_circle(Vector2(x, 0), 210.0 + k * 90.0, Color(1.0, 0.97, 0.85, 0.022))
		_c().draw_rect(Rect2(x - 54, -H * 0.5 - 300, 108, 18), Color(0.14, 0.15, 0.19))
		for k in 3:
			_c().draw_circle(Vector2(x - 34 + k * 34, -H * 0.5 - 291), 7.0, Color(1.0, 0.96, 0.80))

func _draw_street_floods() -> void:
	## A handful of park floodlights so the outdoor court stays playable at night.
	var night: float = 0.0
	var tday: float = Game.day_t() * 24.0 if Game != null else 12.0
	if tday < 6.5 or tday > 19.5:
		night = 1.0
	elif tday < 8.0:
		night = 1.0 - (tday - 6.5) / 1.5
	elif tday > 18.0:
		night = (tday - 18.0) / 1.5
	if night < 0.08:
		return
	var poles := [
		Vector2(-W * 0.42, -H * 0.48), Vector2(W * 0.42, -H * 0.48),
		Vector2(-W * 0.18, H * 0.48), Vector2(W * 0.18, H * 0.48),
	]
	for p in poles:
		var s: Vector2 = CourtStage.m_project(p, H)
		_c().draw_line(s, s + Vector2(0, -210), Color(0.28, 0.28, 0.30), 7.0)
		_c().draw_line(s + Vector2(0, -210), s + Vector2(36, -200), Color(0.28, 0.28, 0.30), 5.0)
		_c().draw_circle(s + Vector2(36, -196), 12.0, Color(1.0, 0.95, 0.72, 0.95 * night))
		for k in 7:
			_c().draw_circle(s + Vector2(10, 20), 80.0 + k * 48.0,
				Color(1.0, 0.90, 0.55, 0.045 * night))



# ------------------------------------------------- scorer's table & benches
const SKINS := [Color(0.72, 0.53, 0.38), Color(0.55, 0.36, 0.26),
	Color(0.86, 0.69, 0.52), Color(0.40, 0.27, 0.19), Color(0.94, 0.79, 0.64)]
const HAIRS := [Color(0.12, 0.09, 0.08), Color(0.30, 0.20, 0.12),
	Color(0.05, 0.05, 0.06), Color(0.45, 0.30, 0.15), Color(0.75, 0.72, 0.68)]

## A solid box in court space: top face + front + sides, so benches and the
## scorer's table read as parallelepipeds sitting on the floor.
func _box3(x0: float, x1: float, y0: float, y1: float, hgt: float,
		col_top: Color, col_front: Color, col_side: Color) -> void:
	var a := _p(Vector2(x0, y0)); var b := _p(Vector2(x1, y0))
	var c2 := _p(Vector2(x1, y1)); var d := _p(Vector2(x0, y1))
	var at := a - Vector2(0, hgt); var bt := b - Vector2(0, hgt)
	var ct := c2 - Vector2(0, hgt); var dt := d - Vector2(0, hgt)
	_c().draw_colored_polygon(PackedVector2Array([a, d, dt, at]), col_side)
	_c().draw_colored_polygon(PackedVector2Array([b, c2, ct, bt]), col_side)
	_c().draw_colored_polygon(PackedVector2Array([d, c2, ct, dt]), col_front)
	_c().draw_colored_polygon(PackedVector2Array([at, bt, ct, dt]), col_top)

## Scorer's table + team benches as solid furniture; the people (officials,
## seated reserves, standing coaches) only exist in real fixtures.
func _draw_bench_furniture() -> void:
	if env == "street":
		return
	var ty: float = -(H * 0.5 + 44.0)
	for sd in [-1.0, 1.0]:
		var x0: float = -600.0 if sd < 0.0 else 200.0
		_box3(x0, x0 + 400.0, ty - 12.0, ty + 12.0, 15.0,
			Color(0.32, 0.34, 0.42), Color(0.19, 0.21, 0.28), Color(0.14, 0.15, 0.21))
	_box3(-130.0, 130.0, ty - 14.0, ty + 14.0, 28.0,
		Color(0.88, 0.89, 0.93), Color(0.55, 0.16, 0.20), Color(0.42, 0.12, 0.16))

## All the PEOPLE around the court: officials, seated reserves, coaches and
## the whole bowl. Drawn on a throttled layer (~8 fps) -- 300 NPCs at 60 fps
## was the single biggest frame cost on phones.
func _draw_bench_people() -> void:
	if env == "street":
		return
	var ty: float = -(H * 0.5 + 44.0)
	if court == null or not bool(court.is_fixture):
		return
	for oi in 3:
		var ox: float = -80.0 + oi * 80.0
		_npc_seated(_p(Vector2(ox, ty - 34.0)), Color(0.30, 0.32, 0.40),
			SKINS[oi], HAIRS[oi], 0.95,
			clampf((ball_x - ox) * 0.010, -2.5, 2.5), false)
	for entry in court.bench_seats_vis:
		var wpos: Vector2 = entry["pos"]
		var kind: String = String(entry["kind"])
		var seed_i: int = int(entry.get("seed", 0)) % SKINS.size()
		var sp2: Vector2 = _p(wpos)
		var lean: float = clampf((ball_x - wpos.x) * 0.010, -2.5, 2.5)
		var seat_team: int = int(entry.get("team", -1))
		var team_cheer: bool = seat_team >= 0 and seat_team < court.bench_cheer.size() \
			and float(court.bench_cheer[seat_team]) > 0.0
		if kind == "coach":
			_npc_standing(sp2, Color(0.13, 0.15, 0.22), SKINS[seed_i], HAIRS[seed_i],
				1.0, lean, crowd_hype > 0.50 or team_cheer)
		else:
			# seated ON the bench box, lifted by its height. When their team
			# scores, the whole bench is UP on its feet: arms in the air and a
			# little hop, while the other bench stays seated.
			var hop: float = 0.0
			if team_cheer:
				hop = 7.0 * absf(sin(Time.get_ticks_msec() / 95.0))
			_npc_seated(sp2 + Vector2(0.0, -15.0 - hop), entry["col"], SKINS[seed_i],
				HAIRS[(seed_i + 2) % HAIRS.size()], 1.0, lean,
				crowd_hype > 0.75 or team_cheer)

## Seated spectator/player NPC: head with hair, torso, bent legs, arms on the
## knees (or in the air when the crowd erupts). Leans toward the ball.
func _npc_seated(sp: Vector2, cloth: Color, skin: Color, hair: Color,
		sc: float, lean: float, arms_up: bool) -> void:
	if sc > 0.8:
		_c().draw_rect(Rect2(sp.x - 6.0 * sc, sp.y - 5.0 * sc, 5.0 * sc, 9.0 * sc), skin.darkened(0.18))
		_c().draw_rect(Rect2(sp.x + 1.0 * sc, sp.y - 5.0 * sc, 5.0 * sc, 9.0 * sc), skin.darkened(0.18))
		_c().draw_rect(Rect2(sp.x - 7.0 * sc, sp.y + 3.0 * sc, 6.5 * sc, 3.5 * sc), Color(0.90, 0.90, 0.92))
		_c().draw_rect(Rect2(sp.x + 0.5 * sc, sp.y + 3.0 * sc, 6.5 * sc, 3.5 * sc), Color(0.90, 0.90, 0.92))
	else:
		_c().draw_rect(Rect2(sp.x - 6.0 * sc, sp.y - 5.0 * sc, 12.0 * sc, 12.0 * sc), skin.darkened(0.30))
	_c().draw_rect(Rect2(sp.x - 7.0 * sc, sp.y - 10.0 * sc, 14.0 * sc, 6.0 * sc), cloth.darkened(0.35))
	_c().draw_rect(Rect2(sp.x - 6.5 * sc, sp.y - 24.0 * sc, 13.0 * sc, 15.0 * sc), cloth)
	if arms_up and sc > 0.8:
		_c().draw_line(Vector2(sp.x - 6.0 * sc, sp.y - 21.0 * sc),
			Vector2(sp.x - 11.0 * sc, sp.y - 33.0 * sc), cloth, 3.0 * sc)
		_c().draw_line(Vector2(sp.x + 6.0 * sc, sp.y - 21.0 * sc),
			Vector2(sp.x + 11.0 * sc, sp.y - 33.0 * sc), cloth, 3.0 * sc)
	elif sc > 0.8:
		_c().draw_line(Vector2(sp.x - 6.0 * sc, sp.y - 21.0 * sc),
			Vector2(sp.x - 6.0 * sc + lean, sp.y - 10.0 * sc), skin, 2.6 * sc)
		_c().draw_line(Vector2(sp.x + 6.0 * sc, sp.y - 21.0 * sc),
			Vector2(sp.x + 6.0 * sc + lean, sp.y - 10.0 * sc), skin, 2.6 * sc)
	var hd: Vector2 = Vector2(sp.x + lean, sp.y - 29.0 * sc)
	_c().draw_circle(hd, 5.2 * sc, skin)
	# hair as a CAP on top (not a full cover): the face looks at the court
	_c().draw_arc(hd, 5.0 * sc, PI, TAU, 10, hair, 3.6 * sc)
	if sc > 0.8:
		_c().draw_circle(hd + Vector2(-1.9 * sc, -0.4 * sc), 0.85 * sc, Color(0.14, 0.12, 0.11))
		_c().draw_circle(hd + Vector2(1.9 * sc, -0.4 * sc), 0.85 * sc, Color(0.14, 0.12, 0.11))

## Standing NPC (coaches, fans on their feet): full figure, arms up on hype.
func _npc_standing(sp: Vector2, cloth: Color, skin: Color, hair: Color,
		sc: float, lean: float, arms_up: bool) -> void:
	_c().draw_rect(Rect2(sp.x - 5.0 * sc, sp.y - 13.0 * sc, 4.2 * sc, 14.0 * sc), Color(0.16, 0.17, 0.22))
	_c().draw_rect(Rect2(sp.x + 0.8 * sc, sp.y - 13.0 * sc, 4.2 * sc, 14.0 * sc), Color(0.16, 0.17, 0.22))
	_c().draw_rect(Rect2(sp.x - 6.5 * sc, sp.y - 30.0 * sc, 13.0 * sc, 18.0 * sc), cloth)
	if arms_up:
		_c().draw_line(Vector2(sp.x - 6.0 * sc, sp.y - 27.0 * sc),
			Vector2(sp.x - 12.0 * sc, sp.y - 40.0 * sc), cloth, 3.0 * sc)
		_c().draw_line(Vector2(sp.x + 6.0 * sc, sp.y - 27.0 * sc),
			Vector2(sp.x + 12.0 * sc, sp.y - 40.0 * sc), cloth, 3.0 * sc)
		_c().draw_circle(Vector2(sp.x - 12.0 * sc, sp.y - 41.0 * sc), 2.2 * sc, skin)
		_c().draw_circle(Vector2(sp.x + 12.0 * sc, sp.y - 41.0 * sc), 2.2 * sc, skin)
	else:
		_c().draw_line(Vector2(sp.x - 6.0 * sc, sp.y - 27.0 * sc),
			Vector2(sp.x - 7.0 * sc + lean, sp.y - 15.0 * sc), cloth, 2.8 * sc)
		_c().draw_line(Vector2(sp.x + 6.0 * sc, sp.y - 27.0 * sc),
			Vector2(sp.x + 7.0 * sc + lean, sp.y - 15.0 * sc), cloth, 2.8 * sc)
	var hd: Vector2 = Vector2(sp.x + lean, sp.y - 35.0 * sc)
	_c().draw_circle(hd, 5.4 * sc, skin)
	_c().draw_arc(hd, 5.2 * sc, PI, TAU, 10, hair, 3.8 * sc)
	if sc > 0.8:
		_c().draw_circle(hd + Vector2(-2.0 * sc, -0.4 * sc), 0.9 * sc, Color(0.14, 0.12, 0.11))
		_c().draw_circle(hd + Vector2(2.0 * sc, -0.4 * sc), 0.9 * sc, Color(0.14, 0.12, 0.11))


## Crowd + bench people repaint at ~8 fps: spectators move slowly, and this
## cuts the per-frame primitive count by an order of magnitude on phones.
class CrowdLayer extends Node2D:
	var vis: Node2D = null
	var _acc := 0.0

	func _process(delta: float) -> void:
		_acc += delta
		if _acc >= 0.12:
			_acc = 0.0
			queue_redraw()

	func _draw() -> void:
		if vis == null:
			return
		vis._target = self
		vis._draw_bench_people()
		vis._target = null

func side_hoop_layout(pos: Vector2, widx: int) -> Dictionary:
	# Geometry of a baskin side basket, shared with NetFront (which paints it
	# in front of the players). Returns the projected foot + rim centres.
	var f: Vector2 = _p(pos)
	var rim := Vector2(f.x, f.y - Court.SIDE_RIM_HIGH)
	return {"foot": f, "rim": rim, "wob": net_wobble[widx] if widx < net_wobble.size() else 0.0, "t": t}

func _draw_side_hoop(pos: Vector2, widx: int) -> void:
	# Il canestro laterale ha UNA SOLA fonte (NetFront.draw_side_basket), che
	# sa anche rigirarlo quando e' quello vicino alla telecamera. Questo
	# disegno di base resta come delega: cosi' non puo' piu' disegnare una
	# vista frontale su un canestro che va visto da dietro.
	var wob: float = net_wobble[widx] if widx < net_wobble.size() else 0.0
	NetFront.draw_side_basket(self, pos, 1.0, wob, t, quake_off(widx),
		board_quake_off(widx) - quake_off(widx))

