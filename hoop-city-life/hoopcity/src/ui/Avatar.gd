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
## PARITA' PALLEGgio: ultima posizione palla-mano disegnata (spazio LOCALE
## del chiamante, y negativo = altezza). La Ball del match la legge per
## stare esattamente nella mano, come nel court solo.
static var last_palm := Vector2.ZERO
static var palm_valid := false
## Palm della mano forte PER OGNI chi disegna (chiave instance id): la
## Ball del match legge SOLO quella del suo holder.
static var palms := {}
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
	var w: Dictionary = _items().wear(id)
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
	var w: Dictionary = _items().wear(id)
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
			crouch = 0.0
			lean = 0.0
		DEFEND:
			crouch = h * 0.03
			arm_up = 0.22
			lean = 0.0
		STEAL:
			# One of HIS arms reaches for the ball — no extra floating limb.
			crouch = h * 0.10
			arm_up = 0.0
			arm_swing = 0.0
		SHOOT:
			# amount 0..1: 0 = gathered low, 1 = full extension on release
			crouch = (1.0 - amt) * h * 0.11
			lift = amt * h * 0.13
			arm_up = amt
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
			arm_up = 1.0
			lift = amt * h * 0.5
			if bool(p.get("hang", false)):
				lift = 0.0
				crouch = h * 0.04

	# FADEAWAY: schienata indietro durante il rilascio (post fade o combo
	# TIRA+stick indietro). lean_back 0..1 -> arco visibile sul torso.
	if p.has("lean_back"):
		lean = -facing * float(p.get("lean_back", 0.0)) * h * 0.30

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
		var hipp := Vector2(base.x + sx * hip_w * 0.55 + lean, hip_y)
		var lift_leg: float = maxf(gait, 0.0) * h * 0.10
		var knee := Vector2(hipp.x + sx * hip_w * 0.22 + gait * h * 0.10 * facing,
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
		var up: float = arm_up if strong else arm_up * 0.75
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
			# Hand rides the ball: bounce and palm stay glued.
			var br0: float = h * 0.105 if ball_r < 0.0 else ball_r
			var bounce: float = absf(sin(ph * 1.15))
			hand = Vector2(base.x + hd * h * 0.30, floor_y - bounce * h * 0.55 - br0)
			elbow = Vector2(lerpf(sh_p.x, hand.x, 0.42) + sx * h * 0.05,
				lerpf(sh_p.y, hand.y, 0.40) + h * 0.03)
		elif bool(p.get("hang", false)):
			# APPESO AL FERRO: braccia DRETTE e FISSE alla lunghezza naturale
			# del disegno, le due mani vicine sopra la testa. Il dondolio lo
			# fa la scena ruotando TUTTO il corpo rigido attorno alle mani
			# (pendolo): le braccia non si allungano MAI.
			var grip: float = h * 0.15
			hand = Vector2(base.x + sx * grip * 0.5 + lean * 0.3, sh_y - h * 0.76)
			elbow = Vector2(lerpf(sh_p.x, hand.x, 0.55), lerpf(sh_p.y, hand.y, 0.52))
		elif up > 0.01:
			elbow = Vector2(sh_p.x + sx * h * 0.10, sh_y - h * 0.10 * up + h * 0.10 * (1.0 - up))
			hand = Vector2(sh_p.x + sx * h * 0.06, sh_y - h * 0.42 * up)
		else:
			elbow = Vector2(sh_p.x + sx * h * 0.09 + arm_swing * sx * 0.5,
				lerpf(sh_y, hip_y, 0.75))
			hand = Vector2(elbow.x + sx * h * 0.04 + arm_swing * sx * 0.6,
				hip_y + h * 0.06)
		c.draw_line(sh_p, elbow, skin, lw * 0.85)
		c.draw_line(elbow, hand, skin, lw * 0.78)
		var gw: Dictionary = gear.get("wrist_tape", {})
		if bool(gw.get("on", false)) and sx == float(gw.get("side", 1)):
			c.draw_circle(hand, lw * 0.9, _gear_col(gw, Color(0.95, 0.95, 0.95)))
		if strong:
			ball_pos = hand
			has_ball_pos = true
			# registra la mano SEMPRE (anche senza palla disegnata: la Ball
			# del match la legge per stare nella mano come nel court solo)
			last_palm = hand
			palm_valid = true
			palms[c.get_instance_id()] = hand

	# --- neck, head, hair, and a real face: two eyes, a nose and a mouth.
	# LOWGFX: su dispositivi lenti il viso dettagliato e i decori capelli
	# sono i primi a saltare (a distanza di gioco non si vedono).
	var lowgfx: bool = bool(Settings.get_v("lowgfx", false))
	c.draw_line(Vector2(base.x + lean + twist, sh_y),
		Vector2(base.x + lean + twist, head_y + head_r * 0.5), skin, lw * 0.7)
	var head_c := Vector2(base.x + lean + twist + sdir * head_r * 0.30 * turn, head_y)
	c.draw_circle(head_c, head_r, skin)
	var st: int = int(cols.get("hst", -1))
	if st < 0:
		var gg = _game()
		st = gg.hair_style() if gg != null else 0
	if lowgfx and st > 1:
		st = 1   # taglio semplificato (rasato) in modalita performance
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
				var dx: float = head_r * (0.85 - 0.34 * i)
				var sway: float = head_r * 0.10 * ((i % 2) * 2 - 1)
				c.draw_line(Vector2(head_c.x + dx, head_c.y + head_r * 0.45),
					Vector2(head_c.x + dx + sway, head_c.y + head_r * 1.95), hair, head_r * 0.22)
			# radice piena sopra la testa
			c.draw_circle(head_c + Vector2(0, -head_r * 0.55), head_r * 0.72, hair)
		_:   # normale
			if back:
				# Seen from behind: hair covers the skull, no face.
				c.draw_circle(head_c, head_r * 0.98, hair)
				c.draw_arc(head_c, head_r, 0, TAU, 20, hair.darkened(0.15), head_r * 0.18)
			else:
				c.draw_arc(head_c, head_r, PI, TAU, 16, hair, head_r * 0.62)
	if (not back) and head_r > 4.0 and not lowgfx:
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
			bp = Vector2(base.x + hd * h * 0.30,
				floor_y - absf(sin(ph * 1.15)) * h * 0.55 - br)
		IDLE:
			# standing with the ball held at the hip
			bp = Vector2(base.x + hd * h * 0.28, hip_y - h * 0.02)
	if spun:
		# Come back out of the turn BEFORE drawing the ball: a ball is round.
		# Left inside the squash a 360 made it vanish edge-on, which is exactly
		# the frame you want to be looking at.
		c.draw_set_transform_matrix(xform)
	last_palm = bp
	palm_valid = true
	palms[c.get_instance_id()] = bp
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


## HEAT CHECK: lingue di fuoco disegnate a 3 strati (base arancio, pancia
## gialla, nucleo bianco-caldo sulla centrale) che ondeggiano e sfarfallano.
## UNA sola implementazione per tutto il gioco: solo e partita identici.
static func draw_flames(c: CanvasItem, base: Vector2, t: float) -> void:
	for i in 3:
		var ph: float = t * 7.0 + float(i) * 2.4
		var fx: float = base.x + (float(i) - 1.0) * 5.0 + sin(ph) * 1.8
		var fh: float = 7.0 + (sin(ph * 1.7) * 0.5 + 0.5) * 7.0
		var fw: float = 3.4 - float(i) * 0.5
		var sway: float = sin(ph * 1.3) * 1.2
		c.draw_circle(Vector2(fx, base.y - fh * 0.35), fw, Color(1.0, 0.42, 0.06, 0.78))
		c.draw_circle(Vector2(fx + sway, base.y - fh * 0.72), fw * 0.60, Color(1.0, 0.68, 0.08, 0.88))
		c.draw_circle(Vector2(fx + sway * 1.4, base.y - fh * 1.02), fw * 0.30, Color(1.0, 0.92, 0.50, 0.95))
		if i == 1:
			c.draw_circle(Vector2(fx + sway * 0.5, base.y - fh * 1.22), fw * 0.16, Color(1.0, 0.98, 0.80, 0.95))

## JSON-safe gear colour: "#rrggbb" string in the profile, fallback otherwise.
static func _gear_col(g: Dictionary, fallback: Color) -> Color:
	var hs: String = String(g.get("col", ""))
	if hs.is_valid_html_color():
		return Color(hs)
	return fallback

## Fiamme per la palla NBA JAM: SCIA DI FUOCO orientata contro il verso del
## moto (segue la parabola: in salita punta in basso, in discesa in alto),
## stile cometa. `sv` = velocità apparente dello schermo; se è ~0 (palla in
## mano) piccole fiammelle radiali. Contenuta: non copre il gioco.
static func draw_ball_flames(c: CanvasItem, center: Vector2, r: float, t: float,
		sv := Vector2.ZERO) -> void:
	# alone caldo discreto attorno alla palla
	c.draw_circle(center, r * 1.30, Color(1.0, 0.50, 0.12, 0.16))
	var sp: float = sv.length()
	if sp < 40.0:
		# palla tenuta in mano: tre fiammelle dolci sopra il pallone
		for i in 3:
			var ph: float = t * 8.0 + float(i) * 2.1
			var fx: float = center.x + (float(i) - 1.0) * r * 0.42 + sin(ph) * 1.5
			var fh: float = r * (0.55 + (sin(ph * 1.7) * 0.5 + 0.5) * 0.5)
			c.draw_circle(Vector2(fx, center.y - r - fh * 0.4), r * 0.16, Color(1.0, 0.42, 0.06, 0.8))
			c.draw_circle(Vector2(fx, center.y - r - fh * 0.75), r * 0.09, Color(1.0, 0.75, 0.18, 0.85))
		return
	# SCIA: il fuoco scivola ALL'INDIETRO rispetto al moto (parabola vera)
	var ang: float = (-sv / sp).angle()
	c.draw_set_transform(center, ang, Vector2.ONE)
	for i in 4:
		var ph: float = t * 10.0 + float(i) * 1.3
		var d: float = r * (0.55 + float(i) * 0.42)      # quanto dietro
		var sway: float = sin(ph + float(i)) * r * 0.12   # serpentello della scia
		var fw: float = r * maxf(0.46 - float(i) * 0.085, 0.14)
		var ln: float = r * (0.55 + (sin(ph * 1.6) * 0.5 + 0.5) * 0.35)
		var base := Vector2(d, sway)
		# lingua di fuoco: goccia allungata che si restringe all'indietro
		c.draw_circle(base, fw, Color(1.0, 0.34, 0.05, 0.72))
		c.draw_circle(base + Vector2(ln * 0.45, sway * 0.4), fw * 0.62, Color(1.0, 0.60, 0.10, 0.8))
		c.draw_circle(base + Vector2(ln * 0.85, sway * 0.7), fw * 0.32, Color(1.0, 0.88, 0.30, 0.85))
	# scintille che si staccano lungo la scia
	for k in 3:
		var ph2: float = t * 6.0 + float(k) * 2.0
		c.draw_circle(Vector2(r * (0.7 + float(k) * 0.55), sin(ph2) * r * 0.28),
			1.4 + 1.2 * absf(sin(ph2)), Color(1.0, 0.85, 0.30, 0.75))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
