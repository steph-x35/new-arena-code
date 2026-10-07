extends RefCounted
class_name Avatar
## THE single way a player is drawn, everywhere: city, apartment, gym drills,
## solo court, match, creator preview.
##
## Before this, five different files each drew their own stick figure with
## their own proportions, so your character visibly changed style every time
## you walked into a building. Skin, hair, outfit, height and handedness now
## come from one place and one set of proportions.

## Pose names. Everything a scene needs to say about what the body is doing.
const IDLE := "idle"
const RUN := "run"
const DRIBBLE := "dribble"
const SHOOT := "shoot"
const DUNK := "dunk"
const DEFEND := "defend"
const STEAL := "steal"
const REACH := "reach"      # arms up: contest, block, hanging on the rim

## Autoloads are NOT visible as bare identifiers inside static functions of a
## class_name script, so resolve them explicitly. Without this the whole file
## fails to compile and every draw_body() call silently disappears.
static var _game_cache: Node = null
static var _items_cache: Node = null

static func _game() -> Node:
	# Autoloads never change instance, so cache them: draw_body runs for the
	# player, every pedestrian and every match player every frame, and each
	# one used to re-walk the scene tree several times per draw.
	if _game_cache == null or not is_instance_valid(_game_cache):
		var loop := Engine.get_main_loop()
		if loop is SceneTree:
			_game_cache = (loop as SceneTree).root.get_node_or_null("Game")
	return _game_cache

static func _items() -> Node:
	if _items_cache == null or not is_instance_valid(_items_cache):
		var loop := Engine.get_main_loop()
		if loop is SceneTree:
			_items_cache = (loop as SceneTree).root.get_node_or_null("Items")
	return _items_cache

## Build a pose dictionary. `h` is body height in px; everything else scales
## off it so one figure works at 46 px in a match and 300 px in the creator.
## `trick` ("" or crossover/stepback/behind/hand_switch/hesi) adds the body
## language of a dribble move on top of the DRIBBLE pose.
## Quanto e' in alto la palla in un palleggio, 0 = a terra, 1 = in mano.
## Curva PARABOLICA (una palla che rimbalza non segue un seno troncato: tocca
## il pavimento, sale, si ferma un istante in mano e ricade). Un'unica fonte
## per il palmo disegnato E per la palla vera in partita: cosi' la mano e la
## palla non possono piu' andare fuori tempo (prima usavano due orologi
## diversi, ed era il motivo per cui il palleggio sembrava finto).
static func drib_frac(ph: float, rate := 1.0) -> float:
	var u: float = fposmod(ph * 1.15 * rate, PI) / PI
	return 4.0 * u * (1.0 - u)

## Gomito di un braccio a DUE segmenti (spalla -> gomito -> mano) che deve
## arrivare a `hand`: il gomito si piega SEMPRE (mai una linea dritta, che era
## il difetto "braccio allungato"), e piega dal lato `side`. Se la mano e'
## troppo lontana l'arto si distende, ma i chiamanti la tengono a portata.
static func arm_elbow(sh: Vector2, hand: Vector2, ul: float, fl: float,
		side: float) -> Vector2:
	var v: Vector2 = hand - sh
	var d: float = maxf(v.length(), 1.0)
	var u: Vector2 = v / d
	var reach: float = clampf(d, absf(ul - fl) + 1.0, ul + fl - 1.0)
	var cosb: float = clampf((ul * ul + reach * reach - fl * fl) / (2.0 * ul * reach),
		-1.0, 1.0)
	var b: float = acos(cosb) * (1.0 if side >= 0.0 else -1.0)
	var cs: float = cos(b)
	var sn: float = sin(b)
	var ru := Vector2(u.x * cs - u.y * sn, u.x * sn + u.y * cs)
	return sh + ru * ul

## Rounded continuous contour for the dribbling arm. It passes through the
## projected elbow at t=.5, keeps the shoulder/palm endpoints and has no sharp joint.
static func drib_elbow_at(sh: Vector2, hand: Vector2, h: float, side: float) -> Vector2:
	# The 2D view compresses the forearm: let the elbow hang down/outward,
	# never swing above the shoulder or fold across the jersey at the top.
	return sh.lerp(hand, 0.60) + Vector2(side * h * 0.11, h * 0.09)

static func drib_arm_curve(sh: Vector2, elbow: Vector2, hand: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var control := elbow * 2.0 - (sh + hand) * 0.5
	for i in 17:
		var t := float(i) / 16.0
		points.append(sh * (1.0 - t) * (1.0 - t) + control * 2.0 * t * (1.0 - t) + hand * t * t)
	return points

## Fin dove arriva la mano del palleggiatore, in frazioni dell'altezza: sotto
## questa quota il braccio sarebbe steso. La stessa quota la usano il disegno
## della mano e il test, cosi' il palleggio non puo' piu' "allungarsi".
static func drib_hand_min() -> float:
	return 0.30

## Segmenti del braccio (spalla-gomito, gomito-mano) in frazioni dell'altezza.
static func arm_len() -> Vector2:
	return Vector2(0.22, 0.24)

## Ginocchia piegate del palleggiatore (frazione dell'altezza): un palleggiatore
## sta SEMPRE un filo accovacciato, ed e' anche quello che permette alla mano di
## scendere fino al pallone senza che il braccio si stiri.
static func drib_crouch() -> float:
	return 0.09

## DOVE STA LA MANO DEL PALLEGGIATORE: sopra la palla (stessa x), con il palmo
## appoggiato sul pallone quando questo e' in alto, e mai piu' in basso della
## quota che il braccio raggiunge (drib_hand_min) quando la palla scende. Una sola fonte per il disegno e per i
## test: se cambia la posa, cambiano insieme.
static func drib_hand_at(base_x: float, floor_y: float, h: float, off: Vector2,
		br: float, hd: float, ball_r_known: bool) -> Vector2:
	var br0: float = br if ball_r_known else h * 0.105
	# Quota PIU' BASSA che il braccio raggiunge (y cresce verso il pavimento,
	# quindi il limite e' un MIN: piu' in basso di cosi' il braccio si stira).
	var hand_lo: float = floor_y - h * drib_hand_min()
	if off != Vector2.ZERO:
		return Vector2(base_x + off.x * h,
			minf(floor_y - off.y * h - br0 * 1.35, hand_lo))
	# senza il dato della partita (anteprime, altri contesti): stesso ritmo
	return Vector2(base_x + hd * h * 0.19, hand_lo)

## Numeri della posizione difensiva, in frazioni dell'altezza del corpo: la
## STESSA fonte per il disegno e per i test (cosi' non si testano fantasmi).
static func def_stance(walk := false) -> Dictionary:
	return {"crouch": 0.075 if walk else 0.055,
		"arms_out": 0.62 if walk else 0.5, "wide": 1.0}

static func pose(kind := IDLE, phase := 0.0, amount := 0.0,
		trick := "", walk := false) -> Dictionary:
	return {"kind": kind, "phase": phase, "amount": clampf(amount, 0.0, 1.0),
		"trick": trick, "walk": walk}

static func colours(is_user := true, team_col := Color(0.16, 0.45, 0.85)) -> Dictionary:
	## Outfit for the player, plain kit for everyone else.
	if not is_user:
		return {"skin": Color(0.72, 0.53, 0.38), "hair": Color(0.16, 0.13, 0.12),
			"jersey": team_col, "shorts": team_col.darkened(0.45),
			"shoes": Color(0.90, 0.90, 0.92)}
	var jid: String = String(_game().profile.get("outfit", {}).get("jersey", "plain_tee"))
	var kit_on: bool = jid in ["game_kit", "game_kit_away", "retro_jersey"]
	return {"skin": _game().skin_color(), "hair": _game().hair_color(),
		"jersey": _wear("jersey", Color(0.22, 0.24, 0.28)),
		"shorts": _wear("shorts", Color(0.20, 0.22, 0.30)),
		"shoes": _wear("shoes", Color(0.90, 0.90, 0.92)),
		"num": str(int(_game().profile.get("jersey", 7))),
		"kit": kit_on, "trim": Color(0.95, 0.95, 0.97)}

static func _wear(slot: String, fallback: Color) -> Color:
	var outfit: Dictionary = _game().profile.get("outfit", {})
	var id: String = String(outfit.get(slot, ""))
	if id == "":
		return fallback
	var it = _items()
	if it == null:
		return fallback
	var w: Dictionary = it.wear(id)
	if w.is_empty() or not w.has("col"):
		return fallback
	return Color(w["col"])

## ------------------------------------------------------------------ accessories
## Hats and glasses are real wardrobe slots, but nothing ever DREW them, so a
## bought cap or pair of shades changed nothing on screen. These helpers draw
## whatever is equipped so the look follows the player everywhere.

static func outfit_id(slot: String) -> String:
	return String(_game().profile.get("outfit", {}).get(slot, ""))

static func accessory_col(slot: String) -> Color:
	## Transparent = nothing equipped in this slot.
	var id: String = outfit_id(slot)
	if id == "":
		return Color(0, 0, 0, 0)
	var it = _items()
	if it == null:
		return Color(0, 0, 0, 0)
	var w: Dictionary = it.wear(id)
	if w.is_empty() or not w.has("col"):
		return Color(0, 0, 0, 0)
	return Color(w["col"])

## Draw the equipped hat and glasses on a head already drawn at `head` with
## radius `r`. `dir` is the facing (-1 left, +1 right, 0 = straight on);
## `front` selects the two-lens glasses (face toward camera) vs one lens
## (profile). Called after the head so the hat covers the hair.
static func draw_accessories(c: CanvasItem, head: Vector2, r: float,
		dir := 1.0, front := true) -> void:
	# Draw even on the small match figures (their heads are ~6 px, so the old
	# 7 px threshold silently dropped the hat and glasses on the court).
	if r < 3.0:
		return
	var hat_id: String = outfit_id("hat")
	var hat_col: Color = accessory_col("hat")
	if not hat_id.is_empty() and hat_col.a > 0.0:
		draw_hat(c, head, r, dir, hat_col, hat_id)
	var gl_col: Color = accessory_col("glasses")
	if gl_col.a > 0.0:
		draw_glasses(c, head, r, front, gl_col, dir)

static func draw_hat(c: CanvasItem, head: Vector2, r: float, dir: float,
		col: Color, id: String) -> void:
	var lw: float = maxf(r * 0.10, 1.0)
	if id.begins_with("beanie"):
		# Full crown hugging the head + a folded band, no brim.
		var half: float = r * 1.10
		var pts := PackedVector2Array()
		for i in 21:
			var a: float = PI + PI * float(i) / 20.0
			pts.append(head + Vector2(cos(a) * half, sin(a) * half))
		c.draw_colored_polygon(pts, col)
		c.draw_rect(Rect2(head.x - half, head.y - r * 0.30, half * 2.0, r * 0.30),
			col.darkened(0.22))
		return
	if id.begins_with("visor"):
		# A band around the brow and a peak, no crown.
		c.draw_rect(Rect2(head.x - r * 1.06, head.y - r * 0.30, r * 2.12, r * 0.30), col)
		var x0: float = head.x + (dir if absf(dir) > 0.05 else 0.0) * r * 0.4
		var bw: float = r * 1.2
		c.draw_rect(Rect2(minf(x0, x0 + bw), head.y - r * 0.30, bw, r * 0.16),
			col.darkened(0.15))
		return
	# Ball cap: a filled crown over the top of the head + a brim toward `dir`.
	var half: float = r * 1.12
	var crown := PackedVector2Array()
	for i in 21:
		var a: float = PI + PI * float(i) / 20.0
		crown.append(head + Vector2(cos(a) * half, sin(a) * half))
	c.draw_colored_polygon(crown, col)
	c.draw_arc(head, half, PI, TAU, 22, col.darkened(0.25), lw)
	if absf(dir) < 0.05:
		# Straight on: a short peak toward the camera.
		c.draw_rect(Rect2(head.x - r * 0.95, head.y - r * 0.30, r * 1.9, r * 0.16),
			col.darkened(0.2))
	else:
		var y0: float = head.y - r * 0.28
		var x0: float = head.x + dir * r * 0.55
		var bw: float = dir * r * 1.15
		c.draw_rect(Rect2(minf(x0, x0 + bw), y0, absf(bw), r * 0.14), col.darkened(0.2))

static func draw_glasses(c: CanvasItem, head: Vector2, r: float, front: bool,
		col: Color, dir := 1.0) -> void:
	var lw: float = maxf(r * 0.10, 1.2)
	var eye_y: float = r * 0.08
	var side: float = 1.0 if dir >= 0.0 else -1.0
	if front:
		for sx in [-1.0, 1.0]:
			var lc := head + Vector2(sx * r * 0.36, eye_y)
			var lr := r * 0.32
			c.draw_arc(lc, lr, 0, TAU, 20, col, lw)
			c.draw_circle(lc, lr * 0.78, Color(col.r, col.g, col.b, 0.40))
		c.draw_line(head + Vector2(-r * 0.08, eye_y), head + Vector2(r * 0.08, eye_y),
			col, lw)
		# temples back along the head so they sit ON the face
		c.draw_line(head + Vector2(-r * 0.66, eye_y), head + Vector2(-r * 1.05, eye_y - r * 0.12), col, lw)
		c.draw_line(head + Vector2(r * 0.66, eye_y), head + Vector2(r * 1.05, eye_y - r * 0.12), col, lw)
	else:
		var lc := head + Vector2(side * r * 0.38, eye_y)
		c.draw_arc(lc, r * 0.32, 0, TAU, 20, col, lw)
		c.draw_circle(lc, r * 0.24, Color(col.r, col.g, col.b, 0.40))
		c.draw_line(lc + Vector2(-side * r * 0.32, 0.0),
			head + Vector2(-side * r * 0.95, eye_y - r * 0.18), col, lw)

## Draw the figure with its feet at `base`, standing `h` px tall.
##   facing : -1 left, +1 right
##   p      : a dictionary from pose()
##   cols   : a dictionary from colours()
##   ball   : draw the ball in his hands / at his side
static func draw_body(c: CanvasItem, base: Vector2, h: float, facing: float,
		p: Dictionary, cols: Dictionary, ball := true, shadow := true,
		acc := false, ball_r := -1.0, xform := Transform2D()) -> void:
	var kind: String = String(p.get("kind", IDLE))
	var ph: float = float(p.get("phase", 0.0))
	var amt: float = float(p.get("amount", 0.0))
	var trick: String = String(p.get("trick", ""))
	var walking: bool = bool(p.get("walk", false)) or kind == RUN
	var hd: float = float(p.get("hand", 0.0))
	if absf(hd) < 0.1:
		hd = _game().shooting_hand()

	# --- dunk pose (DunkStyle.sample). Empty for every other animation, so the
	#     old path below is untouched when this is not a slam.
	var dk: Dictionary = p.get("dunk", {})
	var slam_pose: bool = kind == DUNK and not dk.is_empty()
	var both_hands: bool = slam_pose and bool(dk.get("both", false))
	# A 360 (and the reverse) turn the body away from the camera. In 2D the
	# turn is sold by squashing the figure horizontally as it comes edge-on:
	# width = cos(yaw), and once cos goes negative he is facing away.
	var spun := false
	var back_forced := false
	if slam_pose:
		var spin: float = float(dk.get("spin", 0.0))
		if spin > 0.001:
			var sc: float = cos(spin * TAU)
			back_forced = sc < -0.20
			# Never squash him into a sliver: at 90 degrees the figure is a
			# little narrower, and the turn is sold mostly by the back view
			# (hair, no face) rather than by an unreadable edge-on blob.
			var w: float = 0.62 + 0.38 * absf(sc)
			# `xform` is the caller's own transform (court projection + depth
			# scale); the turn is composed on top of it.
			# The turn is composed ON TOP of the caller's transform (court
			# projection + depth scale), so it composes as a matrix.
			c.draw_set_transform_matrix(xform * Transform2D(0.0, Vector2(w, 1.0), 0.0, base))
			base = Vector2.ZERO
			spun = true

	var skin: Color = cols["skin"]
	var jersey: Color = cols["jersey"]
	var shorts: Color = cols["shorts"]
	var shoes: Color = cols["shoes"]
	# Rehab Lab gear, worn on the body while equipped: colour and side (DX/SX)
	# are chosen at the shop and stored JSON-safe in the profile.
	var gear: Dictionary = _game().profile.get("gear", {}) if acc else {}
	var hair: Color = cols["hair"]

	# --- proportions, all relative to h so every scene matches.
	# Weight widens the frame: a 118 kg centre is visibly thicker than a 80 kg
	# guard even when they are drawn at the same height.
	var kg: float = float(_game().profile.get("weight_kg", 90))
	var bulk: float = clampf((kg - 68.0) / 67.0, 0.0, 1.0)
	# I muscoli costruiti in palestra si sommano alla mole nativa: spalle e
	# braccia crescono davvero dopo le sessioni coi pesi.
	bulk = clampf(bulk + clampf(float(cols.get("muscle", 0.0)), 0.0, 1.0) * 0.55, 0.0, 1.0)
	var lw: float = h * lerpf(0.075, 0.105, bulk)   # limb thickness
	var head_r: float = h * 0.115
	var sh_w: float = h * lerpf(0.128, 0.175, bulk) # half shoulder width
	var hip_w: float = sh_w * 0.82

	# --- pose deltas
	var crouch := 0.0        # knees bent, body lowered
	var lift := 0.0          # off the floor
	var swing := 0.0         # leg cycle
	var arm_swing := 0.0     # arm cycle (walking swings the arms too)
	var arm_up := 0.0        # 0 = down, 1 = fully extended overhead
	var arms_out := 0.0      # braccia aperte di lato (posizione difensiva)
	var wide := 0.0          # stance larga (gambe divaricate)
	var off_hand := 0.0      # quanto la mano debole accompagna la palla
	var both_up := false     # tutte e due le mani in alto (rimbalzo)
	var lean := 0.0
	var leg_tuck := 0.0      # knees pulled up (dunk sample)

	match kind:
		RUN:
			swing = sin(ph) * h * 0.22
			arm_swing = sin(ph + PI) * h * 0.16
			lean = 0.0
			crouch = 0.0
		DRIBBLE:
			if walking:
				swing = sin(ph) * h * 0.16
				arm_swing = sin(ph + PI) * h * 0.08
			else:
				swing = 0.0
				arm_swing = 0.0
			# GAMBE PIEGATE: da qui la spalla scende quanto basta perche' la
			# mano arrivi sulla palla con il gomito piegato (drib_crouch).
			crouch = h * drib_crouch()
			lean = 0.0
		DEFEND:
			# POSIZIONE DIFENSIVA: baricentro basso, gambe larghe, braccia
			# aperte. In scivolata il corpo pende dalla parte del movimento
			# (si spinge col piede opposto), da fermo sta centrato.
			# I numeri vengono da def_stance: una sola fonte per disegno e test.
			var dst: Dictionary = def_stance(walking)
			crouch = h * float(dst["crouch"])
			arm_up = 0.0
			arms_out = float(dst["arms_out"])
			wide = float(dst["wide"])
			lean = float(p.get("slide", 0.0)) * h * 0.045
		STEAL:
			# One of HIS arms reaches for the ball — no extra floating limb.
			crouch = h * 0.10
			arm_up = 0.0
			arm_swing = 0.0
		SHOOT:
			# amount 0..1: 0 = palla alla tasca, 1 = braccio esteso. Il carico
			# delle gambe (`shot_dip`) e' indipendente dal braccio: cosi' il
			# tiratore puo' TENERE la palla in tasca mentre le gambe caricano,
			# che e' esattamente cosa fa un tiratore prima di staccare.
			var sa: float = float(p.get("shot_arm", amt))
			var sd: float = float(p.get("shot_dip", 0.0))
			crouch = sd * h
			lift = sa * h * 0.13
			arm_up = sa
			if sa > 0.02:
				off_hand = clampf(1.0 - smoothstep(0.72, 0.95, sa), 0.0, 1.0)
		DUNK:
			if slam_pose:
				# Everything comes from DunkStyle -- the same numbers the ball
				# carry reads, so the ball can never drift off the palm. The
				# body's rise is NOT added here: the engine owns the jump (the
				# match drives `air`, the street court drives its own lift), and
				# stacking a second rise on top is what used to make the slam
				# look like it happened somewhere above the rim.
				lift = float(dk.get("lift", 0.0)) * h
				crouch = float(dk.get("crouch", 0.0)) * h
				leg_tuck = float(dk.get("tuck", 0.0)) * h * 0.22
				# The off arm does what THIS slam needs: both hands up on a
				# two-hand slam, tucked in on a windmill. No more random
				# raised arm standing next to the ball.
				arm_up = float(dk.get("off_arm", 0.15))
			else:
				lift = amt * h * 0.55
				arm_up = 1.0
				if trick == "windmill":
					arm_up = 0.55 + 0.45 * absf(sin(ph * 2.2 + amt * TAU))
					lean = facing * h * 0.04 * sin(amt * PI)
				elif trick == "between":
					arm_up = amt
					crouch = (1.0 - amt) * h * 0.08
				elif trick == "spin360":
					lean = facing * h * 0.06 * sin(amt * TAU)
				elif trick == "tomahawk":
					arm_up = 1.0
					lift = amt * h * 0.62
		REACH:
			# RIMBALZO: due mani in alto, aperte, per prendere la palla al
			# punto piu' alto (una sola mano sembrava un saluto).
			arm_up = 1.0
			both_up = bool(p.get("rebound", false))
			lift = amt * h * 0.5
			if bool(p.get("hang", false)):
				lift = 0.0
				crouch = h * 0.04

	# A pump fake stays PLANTED: only the hands rise, no hop (players asked).
	if bool(p.get("fake", false)):
		lift = 0.0
		crouch = h * 0.02

	# --- dribble-move body language: the arms pump and the body shifts the
	#     way the move actually feels (stepback leans away, behind-the-back
	#     drops low, the hand switches whip the arms across).
	if trick != "":
		arm_swing *= 1.7
		match trick:
			"stepback":
				lean = -facing * h * 0.05
				crouch += h * 0.03
			"behind":
				lean = -facing * h * 0.03
				crouch += h * 0.04
			"hand_switch":
				lean = 0.0
				arm_swing *= 1.25
			"crossover":
				lean = facing * h * 0.02
			"spin":
				# torso caricato contro il giro, gambe basse: si vede la rotazione
				lean = -facing * h * 0.05
				crouch += h * 0.06
			"between":
				# busto abbassato sulla gamba: si legge il passaggio sotto
				crouch += h * 0.055

	# The upper body twists toward the direction of travel, so the figure reads
	# as turning to face where it is going instead of just leaning.
	var back: bool = bool(p.get("back", false))
	var yaw: float = float(p.get("yaw", 0.0))
	if yaw > 0.25 and yaw < 0.75:
		back = true
	if back_forced:
		back = true
	# Body stays PLUMB. Only the head/face looks left or right.
	lean = 0.0
	# In corsa il corpo si inclina nella direzione del movimento (quanto lo
	# decide la partita: `lean_f` e' una frazione dell'altezza, -1..1). Fermo
	# resta dritto: nessuna posa da supereroe.
	lean = float(p.get("lean_f", 0.0)) * h
	# A slam arches the body on purpose (windmill leans into the swing, the
	# tomahawk arches back), so the plumb rule is lifted for the dunk sample.
	if slam_pose:
		lean = float(dk.get("lean", 0.0)) * h * facing
	var turn: float = 0.0 if back else clampf(absf(facing), 0.0, 1.0)
	var sdir: float = 1.0 if facing >= 0.0 else -1.0
	var twist: float = 0.0

	var floor_y: float = base.y - lift
	var hip_y: float = floor_y - h * 0.46 + crouch
	var sh_y: float = floor_y - h * 0.80 + crouch * 0.6
	var head_y: float = floor_y - h * 0.90 - head_r * 0.35 + crouch * 0.5

	# --- shadow stays on the ground and shrinks as he rises
	if shadow:
		var s: float = clampf(1.0 - lift / (h * 1.2), 0.30, 1.0)
		c.draw_colored_polygon(_ellipse(Vector2(base.x, base.y + h * 0.04),
			Vector2(h * 0.26 * s, h * 0.075 * s)), Color(0, 0, 0, 0.28 * s))

	# --- legs: opposite stride ONLY while walking. Standing still = planted.
	var tuck: float = (lift / maxf(h, 1.0)) * h * 0.16 + leg_tuck
	var stepping: bool = walking and (kind == RUN or kind == DRIBBLE)
	for sx in [-1.0, 1.0]:
		var gait: float = 0.0
		if stepping:
			gait = sin(ph) if sx < 0.0 else sin(ph + PI)
		var hipp := Vector2(base.x + sx * hip_w * (0.55 + 0.55 * wide) + lean, hip_y)
		var lift_leg: float = maxf(gait, 0.0) * h * 0.10
		var knee := Vector2(hipp.x + sx * hip_w * (0.22 + 0.42 * wide) + gait * h * 0.10 * facing,
			lerpf(hip_y, floor_y, 0.52) - tuck - lift_leg)
		var foot := Vector2(knee.x + gait * h * 0.14 * facing,
			floor_y - h * 0.02 - tuck * 1.2 - lift_leg * 0.55)
		var leg_col: Color = skin
		var gt: Dictionary = gear.get("compression", {})
		if bool(gt.get("on", false)):
			leg_col = _gear_col(gt, Color(0.16, 0.18, 0.26))
		c.draw_line(hipp, knee, leg_col, lw)
		c.draw_line(knee, foot, leg_col, lw * 0.92)
		var gk: Dictionary = gear.get("knee_sleeve", {})
		if bool(gk.get("on", false)) and sx == float(gk.get("side", 1)):
			c.draw_line(hipp.lerp(knee, 0.70), knee.lerp(foot, 0.20),
				_gear_col(gk, Color(0.35, 0.35, 0.38)), lw * 1.35)
		var ga: Dictionary = gear.get("ankle_brace", {})
		if bool(ga.get("on", false)) and sx == float(ga.get("side", 1)):
			c.draw_line(knee.lerp(foot, 0.78), foot,
				_gear_col(ga, Color(0.90, 0.90, 0.92)), lw * 1.25)
		c.draw_rect(Rect2(foot.x - h * 0.08, foot.y - h * 0.02,
			h * 0.16, h * 0.06), shoes)
		# sole / toe so shoes read as sneakers, not a colour blob
		c.draw_rect(Rect2(foot.x - h * 0.08, foot.y + h * 0.03,
			h * 0.16, h * 0.018), shoes.lightened(0.35))
	# shorts over the hips
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(base.x - hip_w * 1.05 + lean, hip_y - h * 0.03),
		Vector2(base.x + hip_w * 1.05 + lean, hip_y - h * 0.03),
		Vector2(base.x + hip_w * 0.95 + lean, hip_y + h * 0.11),
		Vector2(base.x - hip_w * 0.95 + lean, hip_y + h * 0.11)]), shorts)

	# --- torso (shoulders twist with the facing so the whole body turns)
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(base.x - sh_w + lean + twist, sh_y), Vector2(base.x + sh_w + lean + twist, sh_y),
		Vector2(base.x + hip_w + lean, hip_y), Vector2(base.x - hip_w + lean, hip_y)]),
		jersey)
	if bool(cols.get("kit", false)):
		var trim: Color = cols.get("trim", Color(0.95, 0.95, 0.97))
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(base.x + lean + twist, sh_y + h * 0.02),
			Vector2(base.x - sh_w * 0.35 + lean + twist, sh_y),
			Vector2(base.x + sh_w * 0.35 + lean + twist, sh_y)]), trim)
		c.draw_line(Vector2(base.x - sh_w * 0.85 + lean + twist, sh_y + h * 0.04),
			Vector2(base.x - hip_w * 0.9 + lean, hip_y - h * 0.02), trim, maxf(h * 0.04, 1.5))
		c.draw_line(Vector2(base.x + sh_w * 0.85 + lean + twist, sh_y + h * 0.04),
			Vector2(base.x + hip_w * 0.9 + lean, hip_y - h * 0.02), trim, maxf(h * 0.04, 1.5))
		var num: String = String(cols.get("num", ""))
		if num != "" and h > 28.0:
			var fnt := ThemeDB.fallback_font
			var fs: int = int(h * 0.22)
			var tw: float = fnt.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			c.draw_string(fnt, Vector2(base.x - tw * 0.5 + lean, (sh_y + hip_y) * 0.5 + fs * 0.35),
				num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, trim)

	# --- arms. The strong side holds/releases the ball.
	var ball_pos := Vector2.ZERO
	var has_ball_pos := false
	for sx in [-1.0, 1.0]:
		var strong: bool = signf(sx) == signf(hd)
		var sh_p := Vector2(base.x + sx * sh_w * 0.92 + lean + twist, sh_y + h * 0.04)
		var elbow: Vector2
		var hand: Vector2
		var up: float = arm_up if (strong or both_up) else arm_up * 0.75
		if bool(p.get("hang_one", false)) and not strong:
			up = 0.0    # slam a una mano -> appeso con UNA: l'altro pende
		if not strong and off_hand > 0.01:
			# Mano di appoggio: sta sullo stesso lato della mano forte, un filo
			# piu' in basso, come quando si accompagna la palla.
			var ex: float = sdir * h * 0.20
			var ey: float = sh_y + h * 0.04 - h * 0.44 * maxf(arm_up, 0.01)
			hand = Vector2(base.x + ex - sdir * h * 0.09, ey + h * 0.06 * off_hand)
			elbow = Vector2(lerpf(sh_p.x, hand.x, 0.45), lerpf(sh_p.y, hand.y, 0.42) + h * 0.02)
			c.draw_line(sh_p, elbow, skin, lw * 0.85)
			c.draw_line(elbow, hand, skin, lw * 0.78)
			continue
		if slam_pose and (strong or both_hands):
			# The slam: the hand is PLACED by the DunkStyle angle, so a
			# windmill is a real 4.7 rad sweep of the arm and not a flag the
			# renderer ignores. A two-hand slam puts the off hand up as well.
			var hl: Vector2 = DunkStyle.hand_local(dk)
			# Both hands (two-hand slam): the off hand comes in just behind the
			# strong one and both stay on the strong side, so the arms frame the
			# ball instead of crossing the face.
			var ax: float = hl.x if strong else hl.x - 0.11
			hand = Vector2(base.x + ax * h * sdir,
				floor_y - hl.y * h + float(p.get("rim_drop", 0.0)))
			elbow = Vector2(lerpf(sh_p.x, hand.x, 0.5) + sdir * h * 0.06,
				lerpf(sh_p.y, hand.y, 0.5) + h * 0.02)
		elif kind == STEAL and strong:
			# Reach with the character's own strong-side arm.
			hand = Vector2(base.x + sx * h * 0.55 + lean, hip_y - h * 0.18)
			elbow = Vector2(lerpf(sh_p.x, hand.x, 0.45), lerpf(sh_p.y, hand.y, 0.40))
		elif kind == DRIBBLE and strong:
			# LA MANO STA SOPRA LA PALLA, sempre: stessa x della palla, palmo
			# appoggiato sul pallone. Quando la palla e' a terra la mano NON la
			# segue fino in fondo (sarebbe un braccio steso): si ferma dove
			# arriva il braccio e la palla rimbalza SOTTO di lei.
			var br0: float = h * 0.105 if ball_r < 0.0 else ball_r
			var off: Vector2 = p.get("ball_off", Vector2.ZERO)
			hand = drib_hand_at(base.x, floor_y, h, off, br0, hd, ball_r >= 0.0)
			elbow = drib_elbow_at(sh_p, hand, h, sx)
		elif arms_out > 0.01 and strong:
			# POSIZIONE DIFENSIVA: braccio di lato, palmo aperto verso
			# l'attaccante, gomito morbido.
			hand = Vector2(base.x + sx * h * (0.26 + 0.10 * arms_out) + lean,
				sh_y + h * (0.22 - 0.16 * arms_out))
			elbow = Vector2(lerpf(sh_p.x, hand.x, 0.42), lerpf(sh_p.y, hand.y, 0.40) - h * 0.04)
		elif bool(p.get("hang", false)) and not bool(p.get("hang_one", false)):
			# APPESO A DUE MANI: le mani CONVERGONO sul tubo del ferro, una
			# appena davanti all'altra (vera presa a due mani sull'anello).
			var gwx: float = h * 0.030 if sx > 0.0 else -h * 0.020
			hand = Vector2(base.x + gwx + lean * 0.3, sh_y - h * 0.42)
			elbow = Vector2(lerpf(sh_p.x, hand.x, 0.52), lerpf(sh_p.y, hand.y, 0.52))
		elif up > 0.01:
			elbow = Vector2(sh_p.x + sx * h * 0.10, sh_y - h * 0.10 * up + h * 0.10 * (1.0 - up))
			hand = Vector2(sh_p.x + sx * h * 0.06, sh_y - h * 0.44 * up)
		else:
			elbow = Vector2(sh_p.x + sx * h * 0.09 + arm_swing * sx * 0.5,
				lerpf(sh_y, hip_y, 0.75))
			hand = Vector2(elbow.x + sx * h * 0.04 + arm_swing * sx * 0.6,
				hip_y + h * 0.06)
		if kind == DRIBBLE and strong:
			var curve := drib_arm_curve(sh_p, elbow, hand)
			c.draw_polyline(curve, skin, lw * 0.83, true)
			c.draw_circle(sh_p, lw * 0.415, skin)
			c.draw_circle(hand, lw * 0.415, skin)
		else:
			c.draw_line(sh_p, elbow, skin, lw * 0.85)
			c.draw_line(elbow, hand, skin, lw * 0.78)
		var gw: Dictionary = gear.get("wrist_tape", {})
		if bool(gw.get("on", false)) and sx == float(gw.get("side", 1)):
			c.draw_circle(hand, lw * 0.9, _gear_col(gw, Color(0.95, 0.95, 0.95)))
		if strong:
			ball_pos = hand
			has_ball_pos = true

	# --- neck, head, hair, and a real face: two eyes, a nose and a mouth.
	c.draw_line(Vector2(base.x + lean + twist, sh_y),
		Vector2(base.x + lean + twist, head_y + head_r * 0.5), skin, lw * 0.7)
	var head_c := Vector2(base.x + lean + twist + sdir * head_r * 0.30 * turn, head_y)
	c.draw_circle(head_c, head_r, skin)
	var st: int = int(cols.get("hst", -1))
	if st < 0:
		var gg = _game()
		st = gg.hair_style() if gg != null else 0
	match st:
		1:   # rasato: alone sottilissimo
			c.draw_arc(head_c, head_r * 0.99, 0, TAU, 20, hair, maxf(1.0, head_r * 0.10))
		2:   # afro: volume pieno tutto intorno
			c.draw_circle(head_c, head_r * 1.38, hair)
			c.draw_arc(head_c, head_r * 1.38, 0, TAU, 24, hair.darkened(0.18), head_r * 0.10)
		3:   # trecce: ciuffi che scendono sul collo
			c.draw_arc(head_c, head_r * 1.06, PI * 0.95, TAU + PI * 0.05, 18, hair, head_r * 0.30)
			for i in 4:
				var bx: float = head_c.x - head_r * 0.75 + head_r * 0.5 * i
				c.draw_line(Vector2(bx, head_c.y + head_r * 0.55),
					Vector2(bx, head_c.y + head_r * (1.25 + 0.08 * (i % 2))), hair, head_r * 0.16)
		4:   # ricci: corona di gobbe
			c.draw_arc(head_c, head_r * 1.10, PI, TAU, 16, hair, head_r * 0.34)
			for i in 5:
				var ang: float = PI + PI * (float(i) / 4.0)
				c.draw_circle(head_c + Vector2(cos(ang), sin(ang)) * head_r * 1.05,
					head_r * 0.26, hair)
		5:   # dreadlocks lunghi: ciuffi compatti fino alle spalle, da dietro
			# e di lato, con la riga in cima al capo
			c.draw_arc(head_c, head_r * 1.04, PI * 0.9, TAU + PI * 0.1, 18, hair, head_r * 0.30)
			for i in 6:
				# ciuffi solo ai LATI: davanti al viso non deve passare nulla
				var side_i: float = 1.0 if i < 3 else -1.0
				var dx: float = head_r * side_i * (0.62 + 0.16 * float(i % 3))
				var sway: float = head_r * 0.12 * (1.0 if i % 2 == 0 else -1.0)
				c.draw_line(Vector2(head_c.x + dx, head_c.y + head_r * 0.10),
					Vector2(head_c.x + dx + sway, head_c.y + head_r * 1.85), hair, head_r * 0.24)
			# radice piena sopra la testa
			c.draw_circle(head_c + Vector2(0, -head_r * 0.55), head_r * 0.72, hair)
		6:   # coda: cap e coda legata dietro la nuca, elastico e punta
			c.draw_arc(head_c, head_r * 1.05, PI * 1.0, TAU, 18, hair, head_r * 0.60)
			if back:
				c.draw_circle(head_c, head_r * 0.99, hair)
				c.draw_arc(head_c, head_r * 1.0, 0, TAU, 20, hair.darkened(0.15), head_r * 0.18)
			var tail_x: float = head_c.x - sdir * head_r * 0.92
			c.draw_circle(Vector2(tail_x, head_c.y - head_r * 0.12), head_r * 0.30, hair.darkened(0.08))
			var tail_tip := Vector2(tail_x - sdir * head_r * 0.34, head_c.y + head_r * 2.05)
			c.draw_line(Vector2(tail_x, head_c.y + head_r * 0.10), tail_tip, hair, head_r * 0.40)
			c.draw_circle(tail_tip, head_r * 0.24, hair)
			c.draw_circle(Vector2(tail_x, head_c.y - head_r * 0.05), head_r * 0.14, hair.darkened(0.35))
		7:   # lunghi: ciocche ai lati che scendono oltre le spalle
			for sx2 in [-1.0, 1.0]:
				# due ciocche sovrapposte per lato: una tenda, non un bastone
				c.draw_line(Vector2(head_c.x + sx2 * head_r * 0.74, head_c.y - head_r * 0.45),
					Vector2(head_c.x + sx2 * head_r * 0.86, head_c.y + head_r * 1.85),
					hair, head_r * 0.62)
				c.draw_line(Vector2(head_c.x + sx2 * head_r * 0.98, head_c.y - head_r * 0.35),
					Vector2(head_c.x + sx2 * head_r * 1.06, head_c.y + head_r * 1.45),
					hair.darkened(0.12), head_r * 0.52)
			c.draw_arc(head_c, head_r * 1.08, PI * 1.0, TAU, 18, hair, head_r * 0.62)
			if back:
				c.draw_circle(head_c, head_r * 1.0, hair)
				c.draw_arc(head_c, head_r * 1.02, 0, TAU, 20, hair.darkened(0.15), head_r * 0.2)
		_:   # normale
			if back:
				# Seen from behind: hair covers the skull, no face.
				c.draw_circle(head_c, head_r * 0.98, hair)
				c.draw_arc(head_c, head_r, 0, TAU, 20, hair.darkened(0.15), head_r * 0.18)
			else:
				c.draw_arc(head_c, head_r, PI, TAU, 16, hair, head_r * 0.62)
	if (not back) and head_r > 4.0:
		var eye_r: float = maxf(head_r * 0.11, 1.0)
		var eye_dy: float = head_r * 0.06
		var eye_col := Color(0.10, 0.09, 0.12)
		if turn > 0.5:
			# profile: a single eye on the leading side of the head
			c.draw_circle(head_c + Vector2(sdir * head_r * 0.38, eye_dy), eye_r, eye_col)
		else:
			for sx in [-1.0, 1.0]:
				c.draw_circle(head_c + Vector2(sx * head_r * 0.32, eye_dy), eye_r, eye_col)
		# nose -- a little wedge that points the way he is facing
		var nose_y: float = head_y + head_r * 0.20
		if turn > 0.5:
			c.draw_colored_polygon(PackedVector2Array([
				Vector2(head_c.x + sdir * head_r * 0.42, nose_y - head_r * 0.12),
				Vector2(head_c.x + sdir * head_r * 0.42, nose_y + head_r * 0.12),
				Vector2(head_c.x + sdir * head_r * 0.62, nose_y)]),
				skin.darkened(0.28))
		else:
			c.draw_line(Vector2(head_c.x, nose_y - head_r * 0.10),
				Vector2(head_c.x, nose_y + head_r * 0.08),
				skin.darkened(0.35), maxf(1.0, head_r * 0.10))
		# mouth -- a short, friendly line below the nose
		var mouth_y: float = head_y + head_r * 0.48
		var mx: float = head_c.x + sdir * head_r * (0.34 if turn > 0.5 else 0.0)
		c.draw_line(Vector2(mx - head_r * 0.18, mouth_y), Vector2(mx + head_r * 0.18, mouth_y),
			Color(0.30, 0.13, 0.13), maxf(1.0, head_r * 0.08))

	# --- equipped hat & glasses, over the hair and eyes
	if acc:
		draw_accessories(c, head_c, head_r, facing, turn < 0.5)

	# --- ball. One consistent radius everywhere (a caller may pin it so the
	#     dribble and the shot use the SAME size).
	if not ball or not has_ball_pos:
		if spun:
			c.draw_set_transform_matrix(xform)
		return
	var br: float = h * 0.105 if ball_r < 0.0 else ball_r
	var bp: Vector2 = ball_pos
	match kind:
		DRIBBLE:
			# Same point the palm already occupies.
			bp = ball_pos
		SHOOT:
			# cocked above the shoulder, released as amount -> 1
			bp = Vector2(ball_pos.x + hd * br * 0.4, ball_pos.y - br * 0.9)
		DUNK:
			if slam_pose:
				# Same sample the ball carry reads: the ball sits exactly where
				# the drawn hand is, for the whole flight.
				var be: Vector2 = dk.get("ball_extra", Vector2.ZERO)
				bp = Vector2(ball_pos.x + be.x * h * sdir, ball_pos.y - be.y * h)
			else:
				bp = Vector2(ball_pos.x + hd * br * 0.5, ball_pos.y - br * 0.6)
		RUN:
			# dribbling on the move: the ball bounces, never glued to the hand
			var offr: Vector2 = p.get("ball_off", Vector2.ZERO)
			if offr != Vector2.ZERO:
				bp = Vector2(base.x + offr.x * h, floor_y - offr.y * h)
			else:
				bp = Vector2(base.x + hd * h * 0.30,
					floor_y - drib_frac(ph) * h * 0.55 - br)
		IDLE:
			# standing with the ball held at the hip
			bp = Vector2(base.x + hd * h * 0.28, hip_y - h * 0.02)
	if spun:
		# Come back out of the turn BEFORE drawing the ball: a ball is round.
		# Left inside the squash a 360 made it vanish edge-on, which is exactly
		# the frame you want to be looking at.
		c.draw_set_transform_matrix(xform)
	c.draw_circle(bp, br, Color(0.95, 0.55, 0.15))
	c.draw_arc(bp, br, 0, TAU, 16, Color(0.35, 0.18, 0.07), maxf(br * 0.14, 1.0))
	c.draw_line(bp + Vector2(-br, 0), bp + Vector2(br, 0),
		Color(0.35, 0.18, 0.07), maxf(br * 0.11, 1.0))

static func _ellipse(c: Vector2, r: Vector2) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 18:
		var a: float = TAU * i / 18.0
		p.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return p


## JSON-safe gear colour: "#rrggbb" string in the profile, fallback otherwise.
static func _gear_col(g: Dictionary, fallback: Color) -> Color:
	var hs: String = String(g.get("col", ""))
	if hs.is_valid_html_color():
		return Color(hs)
	return fallback
