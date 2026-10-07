extends CharacterBody2D
class_name BallPlayer
## One on-court athlete. Human-controlled or AI-driven (see brain.gd state machine).
## Movement uses real inertia: force-based accel, direction-change friction penalty,
## and a stamina model that feeds back into speed and shooting.

signal turnover(by: BallPlayer)

@export var team := 0                 # 0 = user team, 1 = opponent
@export var is_user := false
@export var jersey_num := 7
@export var display_name := "Player"

# --- ratings 1..99 (copied in from Game profile or generated for NPCs) ---
var ratings := {
	"close": 55, "mid": 52, "three": 48, "handle": 58, "pass": 55,
	"speed": 62, "accel": 60, "stamina": 60, "defense": 50,
	"steal": 48, "block": 40, "rebound": 45,
}
var badges: Array = []
var height_f := 1.0
var mass_f := 1.0

# --- dynamic state ---
var stamina := 100.0
var facing := 1.0
var dribble_intensity := 1.0
var anim_t := 0.0                     # free-running clock for run/dribble cycles
var stance := false                   # defensive stance
var sprinting := false
var guarding := false                 # user-only: auto-stay in front of the handler
var has_ball := false
var gender := 0                 # 0 = M, 1 = F (drives the hair cut + crowd art)
var fouls := 0                  # personal fouls, the "L" ones included
var pts_total := 0                    # points this player scored (box/card)
var role := 5                         # baskin role 1..5 (1 = pivot)
var variant := ""                     # 1S / 2T / 2R or ""
var wheelchair := false               # wheels: slower, 10 s pivot clock
var pivot_clock := 0.0                # roles 1-2: seconds left to shoot
var period_makes := 0                 # baskets made this period
var period_shots := 0                 # shots taken this period
var pivot_attempts := 0               # role 1: attempts this possession (3/2 pts)
var _dribble_phase := 0.0
var _dribble_scale := 1.0
var dribble_t := 0.0                  # seconds dribbling this possession
var received_in_side_area := false    # role 3 scoring modifier
var own_miss_rebound := false          # pivot: grabbed his own miss — pass out, no re-shoot
var no_pivot_return := false           # just fed by the pivot: move it on first
var tutor: BallPlayer = null            # the mate who just handed the pivot the ball
var area_loiter_t := 0.0               # seconds spent inside a small side area (roles 3-5)
var stun := 0.0                       # contact / crossover recovery lock
var shot_charge := -1.0               # >=0 while holding the shot button
var shot_ideal := 0.6
const MAX_CHARGE := 1.4               # hard ceiling; see _physics_process safety
var move_input := Vector2.ZERO
var _prev_dir := Vector2.RIGHT
var _squeak_t := 0.0
var entering := false               # walking ON from the bench (sub animation)
var leaving := false                # walking OFF to the bench
var bench_target := Vector2.ZERO    # where the sub walk is heading
var last_dir := Vector2.RIGHT
var cooldown_steal := 0.0
var cooldown_move := 0.0
var possession_time := 0.0
var _press_t := 0.0                   # >0 mentre sei marcato addosso (palleggio basso)
var _drib_cache: Dictionary = {}      # offset del palleggio, uno per tick
var _drib_at := -999.0
var skid_t := 0.0                     # >0 mentre strisci in frenata
var _brake_t := 0.0                   # durata della strisciata in corso
var _move_hand_from := 1.0       # animation starts in the hand that actually held the ball
var move_t := 0.0                     # >0 while a crossover/stepback animates
var move_kind := ""                   # crossover / stepback / behind / hand_switch / hesi
var hand_side := 1.0                  # which hand the ball is in (flips on a move)
const FOLLOW_U := 0.34              # durata del follow-through del tiro
const MOVE_DUR := 0.45                # seconds a dribble move plays out on screen

# --- vertical game: jump / block / dunk -----------------------------------
## `air` is height ABOVE the floor in pixels; the sprite is offset by it so a
## jump reads visually without leaving the 2D plane the sim runs on.
var air := 0.0
var air_v := 0.0
var jumping := false
var block_window := 0.0        # >0 = contesting, can swat a shot
var dunking := false
var hanging := false           # holding the rim after a dunk
var hang_t := 0.0
var dunk_held := false         # true while the dunk button is held
var hang_saw_hold := false     # saw the button held AFTER we grabbed the rim
var dunk_charge := 0.0
var shot_anim := 0.0           # follow-through timer after a released shot
var fake_t := 0.0              # pump-fake timer
var fake_locked := false       # finta in partita = palla raccolta al petto
var travel_warn := 0.0         # input di corsa sostenuto mentre fake_locked
var steal_t := 0.0             # reaching-in animation
# AI shooting wind-up: a human gathers with shot_charge; an AI shooter gathers
# over `ai_windup_total` seconds so the release is TELEGRAPHED (SHOOT pose),
# giving the defence time to close out and jump. Without this AI jumpers were
# instant and could never be read or blocked.
var ai_windup_t := -1.0
var ai_windup_total := 0.6
var ai_windup_err := 0.0
# Set when this defender bit on a pump fake: once he lands he is frozen for a
# beat, so the shooter can drive or rise into the now-open look.
var bite_recovery := 0.0
var hang_off := Vector2.ZERO   # which side of the rim we grabbed
var dunk_style := ""           # DunkStyle: windmill / spin360 / tomahawk ...
var dunk_t := 0.0              # 0..1 progress through the slam (DunkStyle timeline)
var dunk_rise := 0.70          # seconds of that timeline, straight from DunkStyle
var landing := 0.0
var squash := 0.0          # jump stretch / landing compression (feel polish)             # brief recovery after coming down
var dust_t := 0.0              # >0 while landing puffs are expanding
var dust_big := false          # a slam landing: a real THUD under the feet
var _air_was_dunk := false     # this jump ended with a dunk
var shoe_col := Color(0.90, 0.90, 0.92)
var skin_col := Color(0.72, 0.53, 0.38)
var hair_col := Color(0.16, 0.13, 0.12)
var hair_style_v := 0          # taglio PROPRIO (gli NPC non copiano il profilo)

const GRAV := 2600.0
const JUMP_V := 900.0
const DUNK_RANGE_FT := 6.5

var court: Node2D

const BASE_SPEED := 265.0   # matches the solo court's walk pace
const BASE_ACCEL := 2100.0

func _ready() -> void:
	court = get_parent()
	z_index = 10
	add_to_group("players")
	add_to_group("team_%d" % team)

func setup_from_profile() -> void:
	ratings = Game.profile["attrs"].duplicate()
	badges = Game.profile["badges"].duplicate()
	height_f = Game.height_factor()
	mass_f = Game.mass_factor()
	display_name = Game.profile["name"]
	jersey_num = Game.profile["jersey"]
	hand_side = Game.shooting_hand()

func _baskin_speed() -> float:
	var f := 1.0
	if wheelchair:
		f *= 0.80
	match role:
		1:
			f *= 0.78
		2:
			f *= 0.88
		3:
			f *= 0.94
	return f

func max_speed() -> float:
	# The sprint button is gone for good, and the user moves at exactly the
	# solo court's pace on every court: a flat 300 px/s, with no attribute,
	# stamina or ball-carriage scaling -- the same number the shoot-around and
	# the street court use, so a scrimmage never feels like a different speed.
	if is_user:
		return 185.0 * _baskin_speed()
	var s: float = BASE_SPEED * (0.72 + float(ratings["speed"]) / 99.0 * 0.55)
	s *= lerpf(0.70, 1.0, stamina01())          # tired legs are slow legs
	if stance: s *= 0.74
	if has_ball: s *= 0.94
	# NPC opponents and team-mates run slower so the scrimmage is readable.
	s *= 0.60
	if court != null and court.one_on_one:
		s *= 0.88
	return s * lerpf(1.0, 0.94, clampf(height_f - 1.0, 0.0, 1.0)) * _baskin_speed()

func accel_rate() -> float:
	var a: float = BASE_ACCEL * (0.6 + float(ratings["accel"]) / 99.0 * 0.8) * mass_f
	if has_badge("quick_first_step") and velocity.length() < 40.0:
		a *= 1.12
	return a * lerpf(0.75, 1.0, stamina01())

func stamina01() -> float:
	return clampf(stamina / 100.0, 0.0, 1.0)

func has_badge(b: String) -> bool:
	return b in badges

func is_tutor() -> bool:
	return court != null and court.has_method("tutor_of") and court.tutor_of(team) == self

func _physics_process(delta: float) -> void:
	# While walking to/from the bench the Court moves this node directly:
	# no input, no brain, no court clamping (the bench is out of bounds).
	if entering or leaving:
		anim_t += delta
		return
	# Animation clock: runs faster the faster he moves, so the leg cycle and
	# the dribble bounce match the actual speed on screen.
	anim_t += delta * (5.2 + velocity.length() * 0.028)
	_update_dribble_cycle(delta)
	if has_ball and velocity.length() > 60.0:
		dribble_t += delta   # baskin: roles 2-3 must dribble before shooting
	fake_t = maxf(0.0, fake_t - delta)
	steal_t = maxf(0.0, steal_t - delta)
	dust_t = maxf(0.0, dust_t - delta)
	stun = maxf(0.0, stun - delta)
	cooldown_steal = maxf(0.0, cooldown_steal - delta)
	cooldown_move = maxf(0.0, cooldown_move - delta)
	_skid_cd = maxf(0.0, _skid_cd - delta)
	# A pass is on its way to me: I turn to meet it, so it arrives in the hands
	# in front of the chest instead of behind the hip. (The AI only: the user's
	# facing is his own business.) This is what makes the catch read as a
	# magnet rather than the ball landing on a man who is looking elsewhere.
	if court != null and court.ball != null and not is_user:
		var inc: Ball = court.ball
		if inc.live and inc.pass_target == self \
		and absf(inc.global_position.x - global_position.x) > 8.0:
			facing = signf(inc.global_position.x - global_position.x)
	if court == null or not court.play_live:
		fake_locked = false   # fine possessione: il lock dei passi svanisce
	move_t = maxf(0.0, move_t - delta)
	_update_stamina(delta)

	_update_air(delta)

	# Feet off the floor (or hanging on the rim) = no ground movement, with one
	# exception: your own jumper keeps partial air control, so you can drift
	# and step while shooting like on the solo courts (players asked for it).
	var grounded: bool = air <= 0.01 and not hanging
	var wish := Vector2.ZERO
	if stun <= 0.0 and not hanging and landing <= 0.0:
		if grounded:
			wish = move_input
		elif is_user and shot_anim > 0.0:
			wish = move_input * 0.55
	# Frozen before tip-off (the 3-second countdown) and after the whistle --
	# except during YOUR inbound wait: everyone but the inbounder keeps moving.
	if court != null and not court.play_live:
		if not (court.restarting and not court.ft_active and not court._inbound_preparing and self != court.ball_handler()):
			wish = Vector2.ZERO
	# DEFENSE: with GUARD held you take the man the game gives you -- the
	# ball-handler when you may legally take him, otherwise your own man, and
	# when you have nobody legal you help (between the ball and our basket)
	# instead of walking into an "L" foul.
	if guarding and is_user and not has_ball:
		if court == null:
			guarding = false
		else:
			var tgt: BallPlayer = court.guard_target
			if court.ill_mark == self:
				# ADDOSSO A UN UOMO CHE NON PUOI MARCARE (anello rosso): l'assist
				# continua a portarti sul TUO uomo, ma il joystick conta davvero.
				# Passivo -> ti allontani e non succede niente; se insisti
				# addosso a questo, dopo 0.30 s arriva il fallo "L".
				stance = true
				if tgt != null and tgt.team != team:
					var hoop2: Vector2 = court.attack_hoop_for(tgt)
					var gp2: Vector2 = tgt.global_position \
						+ (hoop2 - tgt.global_position).normalized() * 46.0
					var gd2: Vector2 = gp2 - global_position
					var steer2: Vector2 = gd2.normalized() if gd2.length() > 9.0 else Vector2.ZERO
					wish = (steer2 + move_input * 1.1).normalized() \
						if move_input.length() > 0.15 else steer2
			elif tgt != null and tgt.team != team:
				var own_hoop: Vector2 = court.attack_hoop_for(tgt)
				var gp: Vector2 = tgt.global_position \
					+ (own_hoop - tgt.global_position).normalized() * 46.0
				var gd: Vector2 = gp - global_position
				wish = gd.normalized() if gd.length() > 9.0 else Vector2.ZERO
				stance = gd.length() < 95.0
			elif court.ball != null and court.ball.holder != null \
					and court.ball.holder.team != team:
				# NESSUN UOMO LEGALE: aiuto, senza addosso a nessuno.
				var mine: Vector2 = court.hoop_for(team)
				var bp: Vector2 = court.ball.global_position
				var help: Vector2 = mine.lerp(bp, 0.58)
				var hd: Vector2 = help - global_position
				wish = hd.normalized() if hd.length() > 24.0 else Vector2.ZERO
				stance = hd.length() < 140.0
			else:
				guarding = false
	# REGOLA DEI PASSI: con la palla raccolta dopo la finta muoversi
	# vietato. Un input deciso (>0.35) tenuto ~0.2 s viene letto come partenza:
	# annuncio "Traveling" e palla agli avversari, come il shot clock.
	if fake_locked and is_user and stun <= 0.0 and landing <= 0.0:
		if wish.length() > 0.35:
			travel_warn += delta
			if travel_warn > 0.22:
				fake_locked = false
				travel_warn = 0.0
				if court != null:
					court.travel_violation(self)
		else:
			travel_warn = maxf(0.0, travel_warn - delta * 2.0)
		wish = Vector2.ZERO
	if wish.length() > 1.0: wish = wish.normalized()

	var target := wish * max_speed()
	var a := accel_rate()
	# hard direction changes cost more: this is what creates real momentum/inertia
	if wish.length() > 0.1 and velocity.length() > 30.0:
		var dot := wish.normalized().dot(velocity.normalized())
		if dot < 0.2:
			a *= lerpf(0.45, 1.0, clampf((dot + 1.0) / 1.2, 0.0, 1.0))
	# FRENATA: chi corre e si ferma di colpo STRISCIA sul parquet (e alza
	# polvere), invece di inchiodarsi come se avesse le radici. Piu' veloce
	# eri, piu' la strisciata si vede.
	var braking: bool = wish.length() < 0.05 and velocity.length() > 115.0 \
		and shot_charge < 0.0 and not stance
	if braking:
		# La strisciata dura POCHI decimi: il corpo scivola sul parquet per un
		# attimo (e alza polvere), poi pianta e si ferma come prima. Farla
		# durare di piu' rendeva l'IA imprecisa negli arrivi: cosi' si vede il
		# gesto senza cambiare il gioco.
		_brake_t += delta
		skid_t = 0.22
		if _brake_t < 0.14:
			a = minf(a, 900.0)
			if _skid_cd <= 0.0:
				_skid_cd = 0.5
				dust_big = false
				dust_t = maxf(dust_t, 0.30)
				Sfx.squeak()
		else:
			a *= 1.6
			skid_t = maxf(0.0, skid_t - delta)
	else:
		_brake_t = 0.0
		a *= 1.6   # deceleration/friction is faster than acceleration
		skid_t = maxf(0.0, skid_t - delta)
	velocity = velocity.move_toward(target, a * delta)

	move_and_slide()
	if court: court.clamp_to_court(self)
	# Sneaker squeak on hard cuts at speed -- parquet life.
	_squeak_t -= delta
	var _spd := velocity.length()
	var _dir := velocity.normalized() if _spd > 40.0 else _prev_dir
	if _spd > 100.0 and _squeak_t <= 0.0 and _dir.dot(_prev_dir) < 0.80:
		_squeak_t = randf_range(0.35, 0.7)
		Sfx.squeak()
	if _spd > 40.0:
		_prev_dir = _dir

	if wish.length() > 0.1:
		last_dir = wish
		if absf(wish.x) > 0.15: facing = signf(wish.x)

	dribble_intensity = 1.0 if has_ball else clampf(velocity.length() / 200.0, 0.4, 1.4)

	if has_ball:
		possession_time += delta
		guarding = false
		_check_pressure(delta)
		_update_press(delta)
	else:
		possession_time = 0.0
		# Senza palla non sei "marcato addosso": il timer deve scadere, non
		# restare appeso al valore dell'ultima azione.
		_press_t = maxf(0.0, _press_t - delta)
	if shot_charge >= 0.0:
		shot_charge += delta
		# SAFETY: if the finger's release event was lost (multi-touch on Android
		# drops it often), never let the charge hang forever. Auto-fire as a very
		# late shot instead of soft-locking the player with a stuck meter.
		if shot_charge > MAX_CHARGE:
			do_shot_release()
	_update_ai_windup(delta)
	shot_anim = maxf(0.0, shot_anim - delta)
	queue_redraw()

func _update_ai_windup(delta: float) -> void:
	if ai_windup_t < 0.0:
		return
	if not has_ball:
		# Stripped mid-gather (steal, foul, loose ball): drop the shot.
		ai_windup_t = -1.0
		return
	ai_windup_t += delta
	if ai_windup_t >= ai_windup_total:
		var err: float = ai_windup_err
		ai_windup_t = -1.0
		if court != null and has_ball:
			Sfx.play("shot_release", -7.0, randf_range(0.96, 1.05))
			court.attempt_shot(self, err)

## Begin a telegraphed AI jumper. `total` is the gather duration in seconds
## (longer shots gather a touch longer); `err` is the pre-rolled release error.
func begin_ai_shot(err: float, total: float) -> void:
	ai_windup_err = err
	ai_windup_total = clampf(total, 0.38, 0.9)
	ai_windup_t = 0.0
	velocity *= 0.35

func cancel_ai_shot() -> void:
	ai_windup_t = -1.0

## True while this holder is gathering a shot (human charge or AI wind-up) or
## selling a pump fake -- the three things a defender reacts to.
func is_gathering() -> bool:
	return has_ball and (shot_charge >= 0.0 or ai_windup_t >= 0.0 or fake_t > 0.0)

## 0..1+ progress through the gather, 1.0 at the release point.
func gather_progress() -> float:
	if shot_charge >= 0.0:
		return clampf(shot_charge / maxf(shot_ideal, 0.01), 0.0, 1.3)
	if ai_windup_t >= 0.0:
		return clampf(ai_windup_t / maxf(ai_windup_total, 0.01), 0.0, 1.0)
	return 0.0

## Quick shot fake: sells a SHOOT gather without releasing. A defender who bites
## jumps and lands stuck for a beat, opening the drive or the real jumper.
func do_pump_fake() -> bool:
	if not has_ball or cooldown_move > 0.0 or ai_windup_t >= 0.0:
		return false
	shot_charge = -1.0
	fake_t = 0.32
	cooldown_move = 0.35
	velocity *= 0.5
	stamina = maxf(0.0, stamina - 1.5)
	# In PARTITA la finta raccoglie la palla al petto: da quel momento il
	# movimento e' un'infrazione di passi (palla all'avversario). Puoi solo
	# passare o tirare. Solo nei court liberi resti libero di ripartire.
	if is_user and court != null and court.play_live:
		fake_locked = true
		travel_warn = 0.0
	return true

func _update_air(delta: float) -> void:
	landing = maxf(0.0, landing - delta)
	block_window = maxf(0.0, block_window - delta)

	if hanging:
		# Hang on the rim for as long as the button is held (capped so a player
		# cannot park there all possession).
		hang_t += delta
		if is_user:
			if dunk_held:
				hang_saw_hold = true
			elif hang_saw_hold:
				release_rim()
				return
		if hang_t > 1.40:
			release_rim()
			return
		if not is_user and hang_t > 0.55:
			release_rim()
		return

	if dunking:
		# A slam is SCRIPTED, not ballistic: the rise is timed against the
		# DunkStyle animation, so the hand reaches the iron exactly when the
		# pose says it does -- on every court, at any framerate. Without this
		# the jump arc and the animation drifted apart and the slam played out
		# under the rim instead of at it.
		dunk_t = minf(dunk_t + delta / maxf(dunk_rise, 0.05), 1.0)
		air = _dunk_air() * sin(dunk_t * PI * 0.5)
		air_v = 0.0
		if dunk_t >= 1.0:
			# The ball is through the iron: hand back to the normal air model.
			# Without this the slam never ENDED -- `dunking` stayed true, this
			# branch kept resetting `air` every frame, so the player hung in the
			# air forever and could never jump, shoot or dunk again (the AI then
			# stood under the rim until the shot clock ran out).
			dunking = false
		return

	if not jumping:
		return

	air_v -= GRAV * delta
	squash = move_toward(squash, 0.0, delta * 0.85)
	var air_was: float = air
	air += air_v * delta
	if air <= 0.0:
		air = 0.0
		air_v = 0.0
		if jumping:
			# A slam landing is heavier: bigger, longer dust + a rumble.
			dust_big = _air_was_dunk
			dust_t = 0.8 if dust_big else 0.45
			if dust_big and court != null:
				Events.shake.emit(0.4)
				Sfx.play("dunk", -6.0, 0.8)
		_air_was_dunk = false
		jumping = false
		dunking = false
		# Heavier players take longer to gather after landing.
		landing = 0.14 * mass_f
		if air_was > 46.0:
			Sfx.squeak()   # hard stop on landing: parquet life
		if air_was > 20.0:
			squash = -0.13   # landing compression: body widens, height drops
		velocity *= 0.35
		# Bit on a pump fake: grounded and flat-footed while the real shot goes
		# up or the handler drives past.
		if bite_recovery > 0.0:
			stun = maxf(stun, bite_recovery)
			stance = false
			bite_recovery = 0.0
			Sfx.play("body", -9.0)

func jump_height() -> float:
	## Vertical scales with athleticism and drops as you tire.
	var ath: float = (float(ratings["block"]) + float(ratings["rebound"]) + float(ratings["accel"])) / 3.0
	return JUMP_V * (0.78 + ath / 99.0 * 0.42) * lerpf(0.80, 1.0, stamina01()) / maxf(mass_f, 0.75)

func can_dunk() -> bool:
	if court == null or not has_ball:
		return false
	if role != 5:
		return false   # baskin: only role 5 dunks
	if not court.one_on_one and period_shots >= 3:
		return false   # role-5 shot limit covers dunks too
	var ft: float = court.px_to_ft(global_position.distance_to(court.attack_hoop_for(self)))
	if ft > DUNK_RANGE_FT:
		return false
	# A dunk needs legs, not a scouting report. The old gate (athleticism *
	# height > 40) silently switched slams OFF for most created players and
	# most of the roster, which is why a scrimmage or a 1v1 never showed one.
	# What limits dunking now is what limits it in real life: getting all the
	# way to the rim with something left in the tank.
	return stamina01() > 0.15

func do_jump(for_block := false, lunge := 230.0) -> void:
	if wheelchair:
		return   # the chair stays on the floor
	if jumping or hanging or landing > 0.0 or stun > 0.0:
		return
	jumping = true
	squash = 0.11
	air_v = jump_height()
	if for_block:
		# The contest window is generous on the way up, gone on the way down:
		# mistimed jumps should be punished, not forgiven.
		block_window = 0.55
		stamina = maxf(0.0, stamina - 4.5)
		# Lunge AT the ball-handler, so STOPPATA visibly attacks the shot
		# instead of hopping on the spot. If he is out of reach the jump still
		# raises a hand in his face, which is what a contest IS. AI close-outs
		# use a shorter lunge so they don't teleport into the shooter's jersey.
		if court != null:
			var h: BallPlayer = court.ball_handler()
			if h != null and h.team != team:
				var to: Vector2 = h.global_position - global_position
				if to.length() > 1.0 and to.length() < 170.0:
					velocity += to.normalized() * lunge
					if absf(to.x) > 1.0:
						facing = signf(to.x)

func do_dunk(forced_style := "") -> void:
	if not can_dunk() or jumping or hanging:
		return
	dunking = true
	jumping = true
	# The catalogue lives in ONE shared file so the arena scrimmage, the 1v1
	# and the street court all play the same slams. `forced_style` lets the
	# showcase/test harness replay one specific slam.
	dunk_style = forced_style if forced_style != "" else DunkStyle.pick()
	dunk_rise = DunkStyle.rise_time(dunk_style)
	dunk_t = 0.0
	# Rise just past the reach so the HAND clears the iron -- a real dunk, not
	# a float. The rim is 3.05 m; you must jump and get your hand above it.
	air_v = sqrt(2.0 * GRAV * (_dunk_air() + _body_h() * 0.30))
	stamina = maxf(0.0, stamina - 8.0)
	# Drive AT the rim rather than jumping straight up on the spot: the dunk
	# now visibly attacks the basket from underneath, which is what a dunk
	# actually looks like.
	if court:
		var rim: Vector2 = court.attack_hoop_for(self)
		var to_rim: Vector2 = rim - global_position
		if to_rim.length() > 4.0:
			facing = signf(to_rim.x) if absf(to_rim.x) > 1.0 else facing
		velocity = Vector2.ZERO
		court.on_dunk_started(self)

var _skid_cd := 0.0

## Marca di pattinata: due righe scure ai piedi, per la mezza secondo che dura
## la frenata. Disegnata sotto il corpo, come le tracce sul parquet.
func _draw_skid(foot: Vector2) -> void:
	if skid_t <= 0.0:
		return
	var k: float = clampf(skid_t / 0.22, 0.0, 1.0)
	var col := Color(0.28, 0.22, 0.16, 0.30 * k)
	for s in [-1.0, 1.0]:
		draw_line(foot + Vector2(s * 7.0, -1.0),
			foot + Vector2(s * 7.0 - facing * 26.0 * k, -1.0), col, 2.4)

func ball_anchor() -> Vector2:
	## Where the ball sits in this man's hands: in front of the chest, on the
	## side he is looking at. Passes home here and a dead ball rests here, so
	## the catch is seamless -- no pop, no snap, no bounce on the floor.
	return global_position + Vector2(facing * _body_h() * 0.30, 0.0)

## Quanto inclinare il corpo (frazione dell'altezza, -1..1): chi accelera si
## porta avanti, chi frena si raddrizza e si appoggia indietro.
func lean_frac() -> float:
	if stance or hanging or dunking or air > 6.0:
		return 0.0
	var v: float = velocity.length()
	if v < 40.0:
		return 0.0
	var dir: float = signf(velocity.x) if absf(velocity.x) > 4.0 else facing
	var push: float = clampf(v / maxf(max_speed(), 1.0), 0.0, 1.0)
	if skid_t > 0.0:
		dir = -dir
		push *= 0.8
	return dir * push * 0.055

func _body_h() -> float:
	## The drawn height of this player, in the same px the rim uses. Same
	## figure as the solo court, so the match player reads identically.
	return 64.0 * height_f

func _dunk_air() -> float:
	## Feet lift for a dunk: exactly enough that the outstretched hand lands ON
	## the rim. DunkStyle.REACH (1.20 body-heights) is the same number the
	## renderer places the hand with, so the slam reads at the iron and not
	## above it or under it.
	return maxf(court.RIM_HEIGHT - _body_h() * DunkStyle.REACH, 0.0)

func grab_rim() -> void:
	hanging = true
	hang_t = 0.0
	hang_saw_hold = dunk_held
	air_v = 0.0
	velocity = Vector2.ZERO
	if court != null:
		air = _dunk_air()
		global_position = court.dunk_hang_pos(self)
		hang_off = global_position - court.attack_hoop_for(self)

func release_rim() -> void:
	if not hanging:
		return
	hanging = false
	jumping = true
	air_v = -60.0
	# The drop off the rim is the landing that kicks up the dust: remember it,
	# the puff is fired when the feet actually hit the floor.
	_air_was_dunk = true

func _update_stamina(delta: float) -> void:
	# The old model only breathed when you were PERFECTLY still, so in a 1v1 --
	# where nobody ever stops -- everyone ran to zero in the first minute and
	# stayed there. With no wind left, nobody could dunk, and the slams that
	# should be the reward for getting to the rim never happened.
	# Now: running is what empties the tank, walking it back up is a rest, and
	# how fast either happens is the player's own stamina rating.
	var drain := 0.0
	var moving: float = clampf(velocity.length() / maxf(max_speed(), 1.0), 0.0, 1.0)
	# No sprint button anywhere: running is running, one pace. Moving costs
	# very little on its own -- you are jogging around a basketball court, not
	# running a marathon -- so what actually empties the tank is the HARD stuff:
	# jumping, slamming, moves, shots (charged where they happen). That is the
	# bargain real legs make, and it keeps a 1v1 playable for the whole quarter.
	if moving > 0.15:
		drain = 2.4 * moving
	if stance:
		drain += 2.6
	drain *= lerpf(1.25, 0.75, ratings["stamina"] / 99.0)
	# Jogging back up the floor is a rest, not a sprint: even at full pace you
	# get SOME wind back, which is what stops a long 1v1 from leaving both
	# players permanently empty (and permanently unable to dunk).
	var recov := 6.2 * lerpf(0.7, 1.4, ratings["stamina"] / 99.0) * (1.0 - moving * 0.75)
	stamina = clampf(stamina - drain * delta + recov * delta, 0.0, 100.0)

# ------------------------------------------------------------------ ball ops
func _check_pressure(delta: float) -> void:
	# Grace window after gaining possession, so inbounds/rebounds are not instant giveaways.
	if possession_time < 1.15:
		return
	for d in get_tree().get_nodes_in_group("team_%d" % (1 - team)):
		var dist := global_position.distance_to(d.global_position)
		if dist < 28.0 and d.stance:
			var per_sec: float = (1.0 - ratings["handle"] / 130.0) * 0.018
			per_sec *= lerpf(1.3, 0.5, dist / 40.0)
			# Driving to the weak hand is riskier.
			per_sec /= maxf(off_hand_penalty(), 0.5)
			if randf() < per_sec * delta:
				lose_ball(d)
				return

## Sei "marcato addosso"? Serve al palleggio: sotto pressione la palla va
## bassa e il ritmo si stringe (e' cosi' che si protegge), lontano dagli
## avversari si palleggia piu' alto. Aggiornato qui e non a ogni frame di
## disegno, cosi' il palleggio non trema.
func _update_press(delta: float) -> void:
	var near := 9999.0
	for d in get_tree().get_nodes_in_group("team_%d" % (1 - team)):
		near = minf(near, global_position.distance_to(d.global_position))
	if near < 96.0:
		_press_t = 0.30
	else:
		_press_t = maxf(0.0, _press_t - delta)

func lose_ball(to: BallPlayer) -> void:
	has_ball = false
	stun = 0.35
	turnover.emit(self)
	if court: court.on_turnover(self, to)

func do_shot_release() -> void:
	if not has_ball or shot_charge < 0.0: return
	# At the free-throw line the release is its own thing: one point, no
	# defender, no block, and the sequence keeps running between shots.
	if court != null and court.ft_active and court.ft_shooter == self:
		court.free_throw_release(self, shot_charge - shot_ideal)
		shot_charge = -1.0
		shot_anim = FOLLOW_U
		return
	var err: float = shot_charge - shot_ideal
	# Long shots have tighter release windows; rescale the raw error into the
	# standard window so the meter's shrunken green band matches what the sim
	# actually scores.
	if court != null:
		var ft: float = court.px_to_ft(global_position.distance_to(court.attack_hoop_for(self)))
		var w: Dictionary = ShotSystem.shot_windows(ft,
			court != null and court.user_heat)
		err *= ShotSystem.PERFECT_WINDOW / maxf(float(w["perfect"]), 0.001)
	Sfx.play("shot_release", -7.0, randf_range(0.96, 1.05))
	court.attempt_shot(self, err)
	shot_charge = -1.0
	# Play the same follow-through as the solo court: a short rise, the arm
	# extending, then settling -- so a scrimmage jumper looks like a jumper.
	shot_anim = FOLLOW_U

func do_pass(to: BallPlayer) -> void:
	if not has_ball or to == null: return
	fake_locked = false   # passare o tirare e' sempre lecito dopo la finta
	# A pass the RULES refuse (feeding the pivot from outside the area, the
	# give-back to the tutor, ...) must leave the ball in his hands. Clearing
	# has_ball first left the ball attached to a player who no longer owned
	# it: ball_handler() then saw nobody, every try_grab was refused (holder
	# != null) and the possession died on the shot clock (GHOST HOLDER).
	if court != null and not court.pass_allowed(self, to):
		return
	has_ball = false
	court.do_pass(self, to)

func off_hand_penalty() -> float:
	## Driving to your weak side is harder. Right-handers are slightly worse
	## going left and vice versa, so the hand you pick in the creator is a real
	## (small) gameplay trait rather than a cosmetic label.
	if absf(move_input.x) < 0.2:
		return 1.0
	var strong: float = Game.shooting_hand() if is_user else 1.0
	return 0.94 if signf(move_input.x) != strong else 1.02

func do_move(kind: String) -> bool:
	## crossover / stepback / behind-the-back / hand switch / hesitation --
	## a short burst, a visible ball-handling animation, and a defender shake
	## chance. Returns false when the move could not be attempted.
	if not has_ball:
		return false
	# DOPPIO PALLEGGIO: dopo la finta la palla e' RACCOLTA al petto. Rimetterla
	# a terra per palleggiare e' infrazione (palla agli avversari): da palla
	# raccolta puoi solo passare o tirare. Il controllo sta PRIMA del cooldown,
	# cosi' il tentativo di palleggiare dopo una finta si paga subito.
	if fake_locked and court != null and court.play_live:
		fake_locked = false
		travel_warn = 0.0
		court.double_dribble_violation(self)
		return false
	if cooldown_move > 0.0:
		return false
	cooldown_move = 0.32
	stamina = maxf(0.0, stamina - 6.0)
	move_t = MOVE_DUR
	move_kind = kind
	_move_hand_from = hand_side
	_drib_cache.clear()
	# Le scarpe STRIDANO sui cambi di direzione netti (trick/crossover/spin).
	Sfx.squeak()
	var success: float = clampf(ratings["handle"] / 110.0, 0.2, 0.92)
	match kind:
		"crossover":
			# plant and drive the other way, flipping the ball to the other hand
			velocity += Vector2(-facing, 0) * 190.0
			facing = -facing
			hand_side = -hand_side
		"spin":
			# SPIN MOVE 360: esplosione in avanti, il corpo gira (yaw visivo
			# gestito nel draw), la palla avvolge il giocatore.
			velocity += Vector2(facing, 0) * 215.0
			hand_side = -hand_side
			stamina = maxf(0.0, stamina - 2.0)
		"behind":
			# behind-the-back: same lane change, ball hidden behind the body
			velocity += Vector2(facing, 0) * 150.0
			facing = -facing
			hand_side = -hand_side
		"hand_switch":
			# cambio mano: settle and swap hands without changing direction
			velocity *= 0.70
			hand_side = -hand_side
		"stepback":
			# Same hop as the street court: plant and jump BACK from the rim.
			var away := Vector2(-facing, 0.0)
			if court != null:
				var hoop: Vector2 = court.attack_hoop_for(self)
				var d: Vector2 = global_position - hoop
				if d.length() > 8.0:
					away = d.normalized()
			velocity = away * 320.0
			global_position += away * 28.0
		"hesi":
			velocity *= 0.25
		"between":
			# TRA LE GAMBE: la palla passa sotto, il corpo si abbassa,
			# la mano cambia lato senza cambiare direzione.
			velocity *= 0.55
			hand_side = -hand_side
	Sfx.play("crossover", -6.0, randf_range(0.94, 1.08))
	for d in get_tree().get_nodes_in_group("team_%d" % (1 - team)):
		if global_position.distance_to(d.global_position) < 70.0 and randf() < success:
			d.stun = lerpf(0.18, 0.55, success)   # "shook"
			Events.toast.emit("Shook!")
			Events.popup.emit("ANKLES!", global_position, Color(0.8, 0.9, 1.0), false)
	return true

## Where the ball sits relative to my feet while I dribble, so the match ball
## (drawn by the Ball entity) visibly follows the move: it swings side to side
## on a crossover, dips behind me on a behind-the-back, swaps hands on a cambio
## mano, pulls back on a stepback, and pauses on a hesi.
## Numeri della posa di tiro, in frazioni dell'altezza: `arm` (0 = palla alla
## tasca, 1 = braccio esteso) e `dip` (carico delle gambe). UNA fonte: la posa
## disegnata e la palla che il tiratore tiene in mano leggono gli stessi numeri,
## quindi la palla sale con il braccio invece di restare a palleggiare.
func shot_pose_vals() -> Dictionary:
	var arm := 0.10        # 0.10 = palla al petto (la "tasca"), 0.90 = rilascio
	var dip := 0.02        # carico delle gambe: si scende mentre il metro sale
	if fake_t > 0.0:
		arm = 0.42         # la finta: palla su, pronta, gambe quasi dritte
		dip = 0.03
	elif shot_anim > 0.0:
		var f: float = 1.0 - clampf(shot_anim / FOLLOW_U, 0.0, 1.0)
		arm = lerpf(0.95, 0.45, smoothstep(0.0, 1.0, f))
		dip = 0.0          # a rilascio avvenuto le gambe sono ESTESE
	elif shot_charge >= 0.0:
		var q: float = clampf(shot_charge / maxf(shot_ideal, 0.01), 0.0, 1.0)
		arm = lerpf(0.02, 0.10, clampf(shot_charge / 0.14, 0.0, 1.0)) + 0.80 * q
		dip = 0.02 + 0.12 * q
	elif ai_windup_t >= 0.0:
		var q2: float = clampf(gather_progress(), 0.0, 1.0)
		arm = lerpf(0.02, 0.10, clampf(ai_windup_t / 0.14, 0.0, 1.0)) + 0.80 * q2
		dip = 0.02 + 0.12 * q2
	return {"arm": arm, "dip": dip}

func carry_ball_offset() -> Dictionary:
	## The ball RIDES THE HAND for the whole slam. Read by Ball._physics_process
	## (same contract as dribble_ball_offset). Without this the ball stayed at
	## the dribbler's hip while the body flew to the rim, so the dunk looked
	## like the player jumping alone and the ball being switched off.
	## Positions come from the very same DunkStyle sample the body is drawn
	## from, so the ball cannot drift off the palm.
	# TIRO: la palla sta nella "tasca" del tiratore e sale con il braccio fino
	# al rilascio. Prima restava a palleggiare all'anca mentre il corpo era in
	# posa di tiro: era il difetto che faceva sembrare finto ogni tiro.
	if not (dunking and not hanging):
		if has_ball and (shot_charge >= 0.0 or ai_windup_t >= 0.0 or fake_t > 0.0):
			var sv: Dictionary = shot_pose_vals()
			var arm: float = float(sv["arm"])
			var dip: float = float(sv["dip"])
			var hb0: float = _body_h()
			var hs0: float = 1.0 if (hand_side if absf(hand_side) > 0.1 else 1.0) >= 0.0 else -1.0
			var crouch0: float = dip * hb0
			var lift0: float = arm * hb0 * 0.13
			var sh_y0: float = -lift0 - hb0 * 0.80 + crouch0 * 0.6
			var hand_y: float = sh_y0 + hb0 * 0.04 - hb0 * 0.44 * arm
			return {"active": true, "x": hs0 * hb0 * 0.20, "h": air - hand_y}
		return {"active": false}
	var s: Dictionary = DunkStyle.sample(dunk_style, clampf(dunk_t, 0.0, 1.0))
	var bl: Vector2 = DunkStyle.ball_local(s)
	var hb: float = _body_h()
	var sdir: float = 1.0 if facing >= 0.0 else -1.0
	return {"active": true, "x": bl.x * hb * sdir, "h": air + bl.y * hb}

## Quanto e' "stretto" il palleggio adesso: marcato addosso = palla bassa e
## ritmo rapido (si protegge), libero = palla alta e ritmo tranquillo, in corsa
## il ritmo sale con la velocita'. Questi due numeri sono usati sia dal
## disegno del palmo (Avatar) sia dalla palla vera: una sola verita'.
func _update_dribble_cycle(delta: float) -> void:
	# Integrate the rate: multiplying the entire animation clock by a new
	# speed/pressure factor made the ball jump to an unrelated bounce phase.
	var speed := clampf(velocity.length() / 300.0, 0.0, 1.0)
	var rate := lerpf(5.2, 8.2, speed)
	var target_scale := 0.86 if velocity.length() > 250.0 else 1.0
	if _press_t > 0.0:
		rate *= 1.22
		target_scale = 0.48
	_dribble_phase = fposmod(_dribble_phase + delta * rate, PI / 1.15)
	_dribble_scale = lerpf(_dribble_scale, target_scale, 1.0 - exp(-16.0 * delta))

func drib_hint() -> Vector2:
	var hb: float = 64.0 * height_f
	var off: Dictionary = dribble_ball_offset()
	return Vector2(float(off["x"]) / hb, float(off["h"]) / hb)

## L'offset del palleggio, calcolato UNA volta per tick: la palla in partita e
## il palmo disegnato leggono lo stesso numero, quindi la mano sta sulla palla
## nello stesso fotogramma (non "quasi").
func dribble_ball_offset() -> Dictionary:
	if _drib_at == anim_t and _drib_cache.size() == 2:
		return _drib_cache
	_drib_cache = _dribble_ball_offset_raw()
	_drib_at = anim_t
	return _drib_cache

func _dribble_ball_offset_raw() -> Dictionary:
	# UNA SOLA FONTE: questo offset e' anche quello che il disegno del palmo
	# usa (vedi drib_hint -> Avatar "ball_off"), quindi mano e palla non
	# possono piu' andare fuori tempo.
	var hs: float = hand_side if absf(hand_side) > 0.1 else 1.0
	var hb: float = 64.0 * height_f
	# FINTA: palla TENUTA in mano davanti al petto, come nel court libero —
	# niente palleggio durante la finta.
	if fake_t > 0.0 or fake_locked:
		var fh: float = air + hb * (0.42 if fake_t > 0.12 else 0.55)
		return {"x": hs * hb * 0.20, "h": fh}
	# RIMBALZO VERO + SITUAZIONE: la palla scende fino al pavimento e risale
	# (parabola), con l'altezza che dipende da quanto sei marcato e dalla corsa.
	var bounce: float = Avatar.drib_frac(_dribble_phase)
	# La palla scende BESIDE THE FOOT, non a mezza larghezza di corpo di lato:
	# da li' la mano ci arriva con il gomito piegato (prima stava cosi' larga
	# che il braccio sembrava un bastone).
	var side := hs * hb * 0.19
	# Altezza VERA: il palleggio di controllo arriva alla vita (circa meta'
	# del corpo), non al petto. Prima arrivava a 0.55 dell'altezza e sembrava
	# che il giocatore tenesse la palla in mano.
	var hh := bounce * hb * 0.40 * _dribble_scale + Court.BALL_R
	if move_t > 0.0:
		if move_kind in ["crossover", "behind", "hand_switch", "between"]:
			# Logical possession changes hand immediately in do_move(), but the
			# visual ball must travel FROM the old hand TO that new hand.
			side = _move_hand_from * hb * 0.19
		var f: float = 1.0 - move_t / MOVE_DUR     # 0..1 progress
		var low: float = sin(f * PI)
		# Da dove riparte la palla quando il move finisce: un incrocio o un
		# dietro-schiena partono da palla BASSA (altrimenti si vedrebbe un
		# salto quando il palleggio normale riprende).
		var frm: float = hb * 0.20
		match move_kind:
			"crossover":
				# INCROCIO BASSO: la palla passa sotto il ginocchio, con un
				# filo di overshoot sulla mano nuova, esattamente come un
				# incrocio vero (alto si ruba).
				side = lerpf(side, -side, smoothstep(0.0, 1.0, f)) * (1.0 + 0.18 * low)
				hh = lerpf(frm, hb * 0.28, low)     # sotto il ginocchio
			"behind":
				side = lerpf(side, -side, smoothstep(0.0, 1.0, f))
				hh = lerpf(frm, hb * 0.26, low)
			"hand_switch":
				# Passaggio da una mano all'altra: si fa davanti al corpo,
				# all'altezza della vita, non a mezz'aria.
				side = lerpf(side, -side, smoothstep(0.0, 1.0, f)) * (1.0 + 0.12 * low)
				hh = lerpf(frm, hb * 0.32, low)
			"stepback":
				# Il passo indietro si fa con la palla RACCOLTA in mano (il
				# palleggio si ferma sul piede perno), poi riparte bassa.
				side *= 0.7
				hh = lerpf(hb * 0.44, hb * 0.20, clampf((f - 0.45) / 0.55, 0.0, 1.0))
			"hesi":
				# ESITAZIONE: un istante con la palla in mano (la pausa che
				# congela il difensore), poi via bassa e veloce.
				hh = lerpf(hb * 0.44, Court.BALL_R + 8.0, clampf(f / 0.55, 0.0, 1.0))
			"spin":
				# la palla AVVOLGE il corpo: giro completo attorno al giocatore
				side = hs * sin(f * TAU) * hb * 0.46
				hh = 24.0 + low * 22.0
			"between":
				# sotto la gamba: la palla scende quasi a terra al centro
				# del corpo e risale sull'altra mano.
				side = lerpf(side, -side, smoothstep(0.15, 0.85, f))
				side *= (1.0 - 0.85 * low)   # il tragitto passa vicino a x=0
				hh = lerpf(frm, hb * 0.22, low)     # fra le gambe, bassa
	return {"x": side, "h": hh}

## An off-ball cut: a short burst in the direction you are pushing, used to
## lose your marker and get open. This is what TRICK does when you have no
## ball, so the button is never inert.
func do_cut() -> void:
	if cooldown_move > 0.0 or stamina < 6.0:
		return
	cooldown_move = 0.55
	stamina -= 5.0
	var dir: Vector2 = move_input
	if dir.length() < 0.15:
		# standing still: cut toward the basket you are attacking
		dir = (court.attack_hoop_for(self) - global_position).normalized()
	velocity += dir.normalized() * 260.0
	if absf(dir.x) > 0.2:
		facing = signf(dir.x)

## Drive hard toward a point -- the loose ball, or the man holding it.
func chase(target: Vector2) -> void:
	var dir: Vector2 = target - global_position
	if dir.length() < 1.0:
		return
	velocity += dir.normalized() * 220.0
	if absf(dir.x) > 1.0:
		facing = signf(dir.x)

func try_steal() -> void:
	if cooldown_steal > 0.0: return
	cooldown_steal = 1.15
	steal_t = 0.38
	var bh: BallPlayer = court.ball_handler()
	if bh == null or bh.team == team: return
	var to: Vector2 = bh.global_position - global_position
	if to.length() > 1.0:
		velocity += to.normalized() * 160.0
		if absf(to.x) > 1.0:
			facing = signf(to.x)
	var dist := to.length()
	if dist > 70.0: return
	var chance: float = (ratings["steal"] / 99.0) * 0.16 * lerpf(1.05, 0.35, dist / 70.0)
	chance *= lerpf(1.10, 0.40, bh.ratings["handle"] / 99.0)
	if has_badge("pickpocket"): chance *= 1.12
	if randf() < chance:
		bh.has_ball = false
		court.give_ball(self)
		Sfx.play("steal", -1.0)
		Sfx.cheer(false)
		Events.toast.emit("STEAL!")
		Events.popup.emit("STEAL!", global_position, Color(0.45, 0.85, 1.0), false)
		if is_user: court.stat_add("stl", 1)
	else:
		var foul_risk := 0.05 * (1.0 if not has_badge("pickpocket") else 0.7)
		if randf() < foul_risk:
			court.call_foul(self, bh)

func contest_value_against(shooter_pos: Vector2) -> float:
	## 0..1 how much this defender bothers a shot from shooter_pos.
	var d := global_position.distance_to(shooter_pos)
	if d > 130.0: return 0.0
	var c := 1.0 - d / 130.0
	c *= lerpf(0.6, 1.15, ratings["defense"] / 99.0)
	c *= lerpf(0.85, 1.15, height_f)
	if stance: c *= 1.12
	# A defender caught mid-jump on the STOPPATA button contests harder: the
	# whole point of the block is the timing.
	if block_window > 0.0:
		c *= 1.35
	return clampf(c, 0.0, 1.0)

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	# Kit colours chosen before tip-off. Team 0 is you, team 1 the opponent.
	var col: Color = Game.team_colour(team)
	# The match simulation stays top-down; the tilt is applied here, at draw
	# time, so the AI and collisions never have to know about the camera.
	# Players further from the camera are drawn smaller and higher up.
	var ch: float = Court.COURT_H
	var proj: Vector2 = CourtStage.m_project(position, ch)
	var dscale: float = CourtStage.m_scale(position.y, ch)
	draw_set_transform(proj - position, 0.0, Vector2(1.0 - squash * 0.5, 1.0 + squash) * dscale)
	var h := 64.0 * height_f
	if wheelchair:
		h *= 0.80   # the seated figure rides lower, inside the chair
	# Pass aim: a blue disc on the floor under the teammate the joystick
	# is pointing at.
	if court != null and court.aimed == self:
		draw_set_transform(proj - position, 0.0, Vector2(1.0, 0.55) * dscale)
		draw_circle(Vector2.ZERO, 38.0, Color(0.20, 0.55, 1.0, 0.42))
		draw_arc(Vector2.ZERO, 38.0, 0.0, TAU, 28, Color(0.45, 0.75, 1.0, 0.9), 3.0)
		draw_set_transform(proj - position, 0.0, Vector2(1.0 - squash * 0.5, 1.0 + squash) * dscale)
	# CHI PUOI MARCARE: un anello ai piedi dell'uomo che il tasto DIFENDI ti
	# manda a prendere (VERDE, come il tasto), e uno ROSSO su quello che non
	# puoi marcare: cosi' il fallo "L" non arriva mai per sbaglio.
	if court != null and court.guard_target == self:
		# VERDE come il tasto DIFENDI: "questo e' l'uomo che il tasto ti manda
		# a prendere". L'azzurro era indistinguibile dall'anello della
		# posizione difensiva (stance), che sta li' accanto.
		draw_set_transform(proj - position, 0.0, Vector2(1.0, 0.55) * dscale)
		draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 26, Color(0.38, 0.95, 0.48, 0.90), 3.5)
		draw_arc(Vector2.ZERO, 25.0, 0.0, TAU, 24, Color(0.38, 0.95, 0.48, 0.40), 2.0)
		draw_set_transform(proj - position, 0.0, Vector2(1.0 - squash * 0.5, 1.0 + squash) * dscale)
	elif court != null and court.ill_mark == self:
		draw_set_transform(proj - position, 0.0, Vector2(1.0, 0.55) * dscale)
		var pl: float = 0.55 + 0.45 * absf(sin(anim_t * 4.0))
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 26, Color(1.0, 0.35, 0.28, 0.55 + 0.4 * pl), 4.0)
		draw_set_transform(proj - position, 0.0, Vector2(1.0 - squash * 0.5, 1.0 + squash) * dscale)

	# Pick the pose from what the player is actually doing. The SHARED avatar
	# draws it, so this is the same figure as the city, the gym and the creator
	# -- only the scale changes.
	var kind := Avatar.IDLE
	var amount := 0.0
	var phase: float = anim_t
	# Where the feet are drawn. During a hang this is overridden so the
	# outstretched hands land exactly ON the rim -- the REACH pose adds no
	# extra lift of its own, so the player reads as dangling from the iron
	# instead of floating above it.
	var air_draw := air
	# Dunk pose, sampled from the shared catalogue. Empty for everything else.
	var slam: Dictionary = {}
	var rim_drop_v := 0.0
	var sp: Dictionary = shot_pose_vals()
	if fake_t > 0.0:
		kind = Avatar.SHOOT
		amount = float(sp["arm"])
	elif shot_anim > 0.0:
		# FOLLOW-THROUGH: il braccio e' gia' ESTESO quando la palla parte, poi
		# si distende e ricade. Prima era al contrario (si abbassava subito e
		# risaliva: il tiro sembrava un saluto). Lo stacco si vede salire e
		# scendere, e a terra ci si arriva prima dell'ultimo frame.
		var f: float = 1.0 - clampf(shot_anim / FOLLOW_U, 0.0, 1.0)
		kind = Avatar.SHOOT
		amount = float(sp["arm"])
		# Lo stacco: sale subito dopo il rilascio e atterra prima della fine.
		air_draw += h * 0.30 * sin(clampf(f / 0.62, 0.0, 1.0) * PI)
	elif hanging:
		kind = Avatar.DUNK
		amount = 1.0
		# Feet placed so the outstretched hand lands ON the iron: the same
		# DunkStyle.REACH the pose and the ball carry are built from.
		air_draw = maxf(court.RIM_HEIGHT - h * DunkStyle.REACH, 0.0)
		slam = DunkStyle.sample(dunk_style, 1.0)
		# APPESO COME IN HOOP CITY LIFE: il corpo sta PIU' BASSO (le spalle
		# sotto il bordo, la testa fuori dal canestro) e la mano dello slam
		# risale al LABBRO PIEGATO mentre il ferro cede sotto il peso.
		var bend_now: float = clampf(hang_t * 4.0, 0.0, 1.0)
		rim_drop_v = 12.0 * bend_now - 34.0
		air_draw = maxf(air_draw - 34.0, 40.0)
	elif dunking:
		kind = Avatar.DUNK
		amount = clampf(dunk_t, 0.0, 1.0)
		slam = DunkStyle.sample(dunk_style, dunk_t)
	elif block_window > 0.0 or air > 4.0:
		kind = Avatar.REACH
		amount = clampf(air / 150.0, 0.0, 1.0)
	elif steal_t > 0.0:
		kind = Avatar.STEAL
		amount = 1.0
	elif shot_charge >= 0.0:
		# CARICAMENTO: la palla va nella tasca e le gambe CARICANO (il
		# baricentro scende mentre il metro si riempie), poi al rilascio si
		# esplode in alto. Prima era il contrario: braccia gia' in alto e
		# corpo che si abbassava, cioe' un tiro al rallentatore.
		kind = Avatar.SHOOT
		amount = float(sp["arm"])
	elif ai_windup_t >= 0.0:
		# Same telegraphed gather as the human charge -- the visible tell a
		# defender reads to time the close-out and the jump.
		kind = Avatar.SHOOT
		amount = float(sp["arm"])
	elif velocity.length() < 14.0:
		if has_ball:
			kind = Avatar.DRIBBLE
		elif stance:
			kind = Avatar.DEFEND
		else:
			kind = Avatar.IDLE
	elif has_ball:
		kind = Avatar.DRIBBLE
	else:
		kind = Avatar.RUN

	# A live dribble move (crossover, stepback, behind-the-back, cambio mano,
	# hesi) plays a fast dribble with the trick's body language and ball path.
	var trick := ""
	if move_t > 0.0 and has_ball and not (hanging or dunking):
		kind = Avatar.DRIBBLE
		phase = anim_t * 1.9
		trick = move_kind
	if wheelchair and kind == Avatar.RUN:
		kind = Avatar.DRIBBLE if has_ball else Avatar.IDLE   # seated: no run cycle

	# Read slightly bigger when attacking the rim or rising into a jumper, so
	# the shot reads as the focus of the action.
	# Same drawn height as the street court (no extra scale-up).

	var cols: Dictionary = Avatar.colours(is_user, col)
	cols["kit"] = true
	cols["num"] = str(jersey_num)
	cols["trim"] = Color(0.95, 0.95, 0.97) if team == 0 else Color(0.92, 0.78, 0.22)
	if is_user:
		cols["jersey"] = Game.team_colour(team)
		cols["shorts"] = Game.team_colour(team).darkened(0.35)
	else:
		cols["skin"] = skin_col
		cols["hair"] = hair_col
		cols["shoes"] = shoe_col
		cols["jersey"] = col
		cols["shorts"] = col.darkened(0.40)
		cols["muscle"] = 0.0
	cols["hst"] = hair_style_v if not is_user else Game.hair_style()
	if is_user:
		# Il fisico cresce con le sessioni di panca/squat: spalle e braccia
		# piu' grosse anche in partita, coerenti con la palestra.
		cols["muscle"] = float(Game.profile.get("muscle", 0.0))
	# The real ball is the Court's Ball entity (it bounces at the handler's
	# side and flies on shots), so the avatar never draws its own copy -- that
	# second little ball is what looked glued to every hand.
	var walking: bool = (velocity.length() > 14.0 or move_input.length() > 0.12) and not wheelchair
	var dunk_trick := dunk_style if (dunking or hanging) else trick
	var po: Dictionary = Avatar.pose(kind, phase, amount, dunk_trick, walking)
	po["hand"] = hand_side
	# Il palmo disegnato usa ESATTAMENTE la posizione della palla vera (stessi
	# numeri), quindi la mano sta sulla palla anche durante i move.
	if has_ball and not (hanging or dunking):
		po["ball_off"] = drib_hint()
		if absf(po["ball_off"].x) > 0.02:
			po["hand"] = signf(po["ball_off"].x)
	# Inclinazione del corpo: in accelerazione si va "in avanti", in frenata
	# indietro. E' una frazione dell'altezza disegnata.
	po["lean_f"] = lean_frac()
	# In scivolata difensiva il corpo pende dalla parte verso cui scivola, e il
	# rimbalzo si prende con TUTTE E DUE le mani.
	po["shot_arm"] = float(sp["arm"])
	po["shot_dip"] = float(sp["dip"])
	po["slide"] = clampf(velocity.x / maxf(max_speed(), 1.0), -1.0, 1.0)
	po["rebound"] = air > 6.0 and block_window <= 0.0 and not dunking and not hanging
	if move_t > 0.0 and move_kind == "spin":
		# giro 360: il torso mostra le spalle a meta' mossa (Avatar gestisce
		# back/yaw) e ritorna frontale alla fine.
		po["yaw"] = clampf(sin((1.0 - move_t / MOVE_DUR) * PI) * 1.7, 0.0, 1.0)
	if fake_t > 0.0:
		po["fake"] = true
	if not slam.is_empty():
		# The slam drives the pose, including the turn: a spin360/reverse flips
		# the body from the sample's `spin`, not from a flag.
		po["dunk"] = slam
	# RUOLO 1 = PIVOT IN CARROZZINA (regolamento baskin): la figura si
	# disegna sulla sedia a rotelle, non in piedi.
	if role == 1:
		po["chair"] = true
	if hanging:
		po["rim_drop"] = rim_drop_v
	if hanging and slam.is_empty():
		po["hang"] = true
		if hang_off.y < -12.0:
			po["back"] = true
		var hoop: Vector2 = court.attack_hoop_for(self) if court else Vector2.ZERO
		var end_sign: float = 1.0 if hoop.x >= 0.0 else -1.0
		if end_sign * hang_off.x > 8.0:
			po["back"] = true
	# Stick UP (toward the far sideline) = seen from behind, every court.
	if move_input.y < -0.22 and not hanging:
		po["back"] = true
	# Hang: slightly bigger figure + a long shadow on the floor so he reads
	# as dangling in front of the glass, not standing on it.
	var feet := Vector2(0, -air_draw)
	if hanging:
		# appeso: oscillazione dx/sx (pendolo attorno al ferro)
		feet.x = sin(Time.get_ticks_msec() * 0.003) * 12.0
	if wheelchair:
		feet = Vector2(0, -15.0 - air_draw)   # up on the footrest, not on the floor
	# OMBRA REALE (richiesta utente): durante la schiacciata sta A TERRA,
	# scorre al centro della semicirconferenza sotto il ferro e DIVENTA
	# PIU' GRANDE mentre sali. Mai in aria con il corpo.
	var air_norm: float = clampf(air_draw / 240.0, 0.0, 1.2)
	if dunking and court != null:
		var rim_g: Vector2 = court.attack_hoop_for(self)
		var sh_pos: Vector2 = global_position.lerp(rim_g, clampf(dunk_t * 0.85, 0.0, 1.0)) - global_position
		var shs2: float = 1.2 + clampf(air_norm, 0.0, 1.0) * 0.45
		draw_colored_polygon(PackedVector2Array([
			sh_pos + Vector2(-h * 0.20 * shs2, 8.0), sh_pos + Vector2(h * 0.20 * shs2, 8.0),
			sh_pos + Vector2(h * 0.09, 17.0), sh_pos + Vector2(-h * 0.09, 17.0)]),
			Color(0, 0, 0, 0.40))
	elif hanging and court != null:
		h *= 1.08
		var rim_g2: Vector2 = court.attack_hoop_for(self)
		var sh2: Vector2 = rim_g2 - global_position
		var shs: float = 2.0
		draw_colored_polygon(PackedVector2Array([
			sh2 + Vector2(-h * 0.22 * shs, 8.0), sh2 + Vector2(h * 0.22 * shs, 8.0),
			sh2 + Vector2(h * 0.10, 18.0), sh2 + Vector2(-h * 0.10, 18.0)]),
			Color(0, 0, 0, 0.42))
	elif air_draw > 12.0:
		var shs3: float = 1.0 + air_norm * 0.6
		draw_colored_polygon(PackedVector2Array([
			Vector2(-h * 0.20 * shs3, 8.0), Vector2(h * 0.20 * shs3, 8.0),
			Vector2(h * 0.09, 17.0), Vector2(-h * 0.09, 17.0)]),
			Color(0, 0, 0, 0.36))
	# The caller's court transform is handed to the avatar so a spinning slam
	# can compose its own turn on top of the projection.
	_draw_skid(feet)
	Avatar.draw_body(self, feet, h, facing, po, cols, false, air_draw < 12.0 and not dunking, is_user,
		-1.0, Transform2D(0.0, Vector2(1.0 - squash * 0.5, 1.0 + squash) * dscale, 0.0, proj - position))
	# BASKIN role badge: the teaching core, always above every head.
	if court != null and not court.one_on_one:
		var blab := "R%d" % role
		if variant != "":
			blab += " " + variant
		var bcol := Color(0.45, 0.90, 1.0) if team == 0 else Color(1.0, 0.75, 0.35)
		draw_string(ThemeDB.fallback_font, Vector2(-48.0, -h - 18.0 - air_draw), blab,
			HORIZONTAL_ALIGNMENT_CENTER, 96.0, 15, bcol)
	if wheelchair:
		_draw_wheelchair()

	# A small chevron over the user's head keeps him identifiable now that he
	# wears the same jersey as his team-mates.
	# P&R hold: label the screener so the play is readable.
	for c in get_children():
		if c.get("role") == "screener" and c.get("pnr_hold"):
			var ly: float = -h - 14.0 - air_draw
			draw_string(ThemeDB.fallback_font, Vector2(-28.0, ly), "SCREEN",
				HORIZONTAL_ALIGNMENT_CENTER, 56.0, 16, Color(1.0, 0.92, 0.25))
			break

	if is_user:
		var my: float = -h - 8.0 - air_draw
		draw_colored_polygon(PackedVector2Array([
			Vector2(-7.0, my), Vector2(7.0, my), Vector2(0.0, my - 8.0)]),
			Color(1.0, 0.85, 0.25))

	# Landing dust: a flat puff that sweeps out sideways as it fades. After a
	# slam it is a full THUD: a wide ground ring plus a ring of grains.
	if dust_t > 0.0:
		var dur: float = 0.8 if dust_big else 0.45
		var k: float = 1.0 - dust_t / dur
		var da: float = (1.0 - k) * (0.62 if dust_big else 0.5)
		var spread: float = lerpf(12.0, 130.0 if dust_big else 52.0, k)
		draw_set_transform(proj - position, 0.0, Vector2(1.0, 0.55) * dscale)
		if dust_big:
			# the shock ring on the floor, right under the feet
			draw_arc(Vector2.ZERO, lerpf(10.0, 96.0, k), 0.0, TAU, 26,
				Color(0.88, 0.85, 0.75, da * 0.85), lerpf(6.0, 1.5, k))
			var grains: int = 14
			for i in grains:
				var a1: float = TAU * float(i) / float(grains) + 0.3
				var rr: float = spread * (0.55 + 0.45 * float((i * 7) % 5) / 4.0)
				draw_circle(Vector2(cos(a1) * rr, sin(a1) * rr * 0.45 - 4.0),
					lerpf(6.0, 1.6, k), Color(0.86, 0.83, 0.73, da))
		else:
			for i in 6:
				var a0: float = -PI * 0.15 - i * 0.22
				var side := -1.0 if i % 2 == 0 else 1.0
				var px: float = side * spread * (0.4 + 0.6 * float((i + 1) % 3) / 2.0)
				var py: float = -6.0 - (i % 2) * 5.0
				draw_circle(Vector2(px, py), lerpf(7.0, 2.5, k), Color(0.85, 0.82, 0.72, da))
		draw_set_transform(proj - position, 0.0, Vector2(1.0 - squash * 0.5, 1.0 + squash) * dscale)
	# stance indicator
	if stance:
		draw_arc(Vector2.ZERO, 26, 0, TAU, 24, Color(0.3, 0.9, 1.0, 0.5), 2.0)
	# Two small bars tracking the user under his feet: stamina (in-match wind)
	# and energy (the day's reserves). A ring above the head was easy to lose
	# against the crowd, and it never showed energy at all.
	if is_user:
		var bw := 46.0
		var bx := -bw * 0.5
		# stamina
		draw_rect(Rect2(bx, 12.0, bw, 5.0), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(bx, 12.0, bw * stamina01(), 5.0),
			Color(0.30, 0.95, 0.40) if stamina > 35.0 else Color(0.95, 0.45, 0.20))
		draw_rect(Rect2(bx, 12.0, bw, 5.0), Color(0, 0, 0, 0.35), false, 1.0)
		# energy
		var e01: float = clampf(float(Game.profile.get("energy", 100.0)) / 100.0, 0.0, 1.0)
		draw_rect(Rect2(bx, 19.0, bw, 4.0), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(bx, 19.0, bw * e01, 4.0), Color(0.35, 0.65, 1.0))
		draw_rect(Rect2(bx, 19.0, bw, 4.0), Color(0, 0, 0, 0.35), false, 1.0)

func _ellipse(c: Vector2, r: Vector2) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		p.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return p

## Sports wheelchair, side view: big wheels with spokes and push-rims, a
## front caster, seat, backrest and footrest. The avatar sits in it (raised
## feet, no run cycle, no jumps — see _draw and do_jump).
func _draw_wheelchair() -> void:
	var tire := Color(0.08, 0.08, 0.10)
	var spoke := Color(0.72, 0.74, 0.78)
	var frame := Color(0.85, 0.30, 0.12)
	var f: float = 1.0 if facing >= 0.0 else -1.0
	# seat + backrest behind the body
	draw_rect(Rect2(-14.0, -24.0, 28.0, 5.0), Color(0.12, 0.12, 0.15))
	draw_rect(Rect2(-14.0, -24.0, 28.0, 5.0), frame, false, 1.5)
	draw_line(Vector2(-f * 13.0, -24.0), Vector2(-f * 16.0, -40.0), frame, 3.0)
	# footrest ahead
	draw_line(Vector2(f * 10.0, -14.0), Vector2(f * 24.0, -6.0), tire, 2.5)
	# far wheel (peeking past the near one) + near wheel
	var spin: float = anim_t * 0.4 if velocity.length() > 30.0 else 0.0
	for w in [{"c": Vector2(-3.0, -3.0), "r": 17.0, "d": true},
			{"c": Vector2(3.0, -1.0), "r": 19.0, "d": false}]:
		var wc: Vector2 = w["c"]
		var wr: float = w["r"]
		var tc: Color = tire if not w["d"] else Color(0.16, 0.16, 0.19)
		draw_arc(wc, wr, 0.0, TAU, 28, tc, 4.5)
		draw_arc(wc, wr - 6.5, 0.0, TAU, 24, spoke if not w["d"] else Color(spoke, 0.5), 2.0)
		for s in 6:
			var a := TAU * float(s) / 6.0 + spin
			draw_line(wc, wc + Vector2(cos(a), sin(a)) * (wr - 1.5),
				Color(spoke, 0.55 if not w["d"] else 0.30), 1.2)
		draw_circle(wc, 3.0, tc)
	# front caster
	draw_arc(Vector2(f * 24.0, 4.0), 4.5, 0.0, TAU, 10, tire, 2.5)
	draw_circle(Vector2(f * 24.0, 4.0), 1.5, spoke)
