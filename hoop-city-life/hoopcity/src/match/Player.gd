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
var dribble_clock := 0.0              # ritmo del palleggio: COSTANTE, non scala con la corsa
var stance := false                   # defensive stance
var sprinting := false
var guarding := false                 # user-only: auto-stay in front of the handler
var has_ball := false
var pts_total := 0                    # points this player scored (box/card)
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
var move_t := 0.0                     # >0 while a crossover/stepback animates
var move_kind := ""                   # crossover / stepback / behind / hand_switch / hesi
var hand_side := 1.0                  # which hand the ball is in (flips on a move)
const MOVE_DUR := 0.45                # seconds a dribble move plays out on screen

# --- vertical game: jump / block / dunk -----------------------------------
## `air` is height ABOVE the floor in pixels; the sprite is offset by it so a
## jump reads visually without leaving the 2D plane the sim runs on.
var air := 0.0
var air_v := 0.0
var jumping := false
var block_window := 0.0        # >0 = contesting, can swat a shot
var dunking := false
var posting := false              # POST UP: spalle al canestro, gioca col dosbo
var hanging := false           # holding the rim after a dunk
var hang_t := 0.0
var dunk_held := false         # true while the dunk button is held
var hang_saw_hold := false     # saw the button held AFTER we grabbed the rim
var dunk_charge := 0.0
var shot_anim := 0.0           # follow-through timer after a released shot
var fade_t := 0.0              # animazione FADEAWAY: schienata indietro
var euro_t := 0.0              # EUROSTEP a due tempi: 1 laterale, 2 verso il ferro
var euro_finish := false       # al secondo tempo: chiude a schiacciata o layup
var combo_pullup := false      # combo TRICK->TIRA entro mezzo secondo
var stepback_t := 0.0          # finestra STEPBACK 3 dopo lo stepback
var dribble_phase := 0.0       # orologio palleggio: 4.2 costante COME IL SOLO
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
var dust_big := false          # atterraggio da dunk: polvere vera e tonfo
var slam_fall := false         # la caduta che segue una schiacciata
var _low := false              # lowgfx: niente dettagli costosi
var shoe_col := Color(0.90, 0.90, 0.92)
var skin_col := Color(0.72, 0.53, 0.38)
var hair_col := Color(0.16, 0.13, 0.12)
var hair_style_v := 0          # taglio PROPRIO (gli NPC non copiano il profilo)

const GRAV := 2600.0
const JUMP_V := 900.0
const DUNK_RANGE_FT := 6.5

var court: Node2D

const BASE_SPEED := 300.0   # matches the solo court's walk pace
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

func max_speed() -> float:
	# The sprint button is gone for good, and the user moves at exactly the
	# solo court's pace on every court: a flat 300 px/s, with no attribute,
	# stamina or ball-carriage scaling -- the same number the shoot-around and
	# the street court use, so a scrimmage never feels like a different speed.
	if is_user:
		return 205.0
	# Velocita' base alzata (+5% su tutti, stesso moltiplicatore AI/utente:
	# nessuna squilibratura, solo meno "pendenza" dopo la rimessa).
	var s: float = BASE_SPEED * (0.76 + float(ratings["speed"]) / 99.0 * 0.55)
	s *= lerpf(0.70, 1.0, stamina01())          # tired legs are slow legs
	if stance: s *= 0.74
	if has_ball: s *= 0.94
	# NPC opponents and team-mates run slower so the scrimmage is readable.
	s *= 0.60
	if court != null and court.one_on_one:
		s *= 0.88
	return s * lerpf(1.0, 0.94, clampf(height_f - 1.0, 0.0, 1.0))

func accel_rate() -> float:
	var a: float = BASE_ACCEL * (0.6 + float(ratings["accel"]) / 99.0 * 0.8) * mass_f
	if has_badge("quick_first_step") and velocity.length() < 40.0:
		a *= 1.12
	return a * lerpf(0.75, 1.0, stamina01())

func stamina01() -> float:
	return clampf(stamina / 100.0, 0.0, 1.0)

func has_badge(b: String) -> bool:
	return b in badges

func _physics_process(delta: float) -> void:
	# While walking to/from the bench the Court moves this node directly:
	# no input, no brain, no court clamping (the bench is out of bounds).
	if entering or leaving:
		anim_t += delta
		return
	# Animation clock: runs faster the faster he moves, so the leg cycle and
	# the dribble bounce match the actual speed on screen.
	anim_t += delta * (5.2 + velocity.length() * 0.028)
	# PARITA' COURT SOLO: stesso ritmo del palleggio (un rimbalzo ogni
	# ~0.42s come il thud del libero), non piu' 'rilassato'.
	dribble_clock += delta * 1.246
	# PARITA' SOLO: la posa DRIBBLE (braccio che spinge la palla) gira
	# allo stesso identico ritmo del court libero, fermo E in corsa.
	dribble_phase += delta * 4.2
	fake_t = maxf(0.0, fake_t - delta)
	steal_t = maxf(0.0, steal_t - delta)
	dust_t = maxf(0.0, dust_t - delta)
	stun = maxf(0.0, stun - delta)
	cooldown_steal = maxf(0.0, cooldown_steal - delta)
	cooldown_move = maxf(0.0, cooldown_move - delta)
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
	# except during 5v5 inbound wait: everyone but the inbounder keeps moving.
	if court != null and not court.play_live:
		var _inbound_phase: bool = not court.one_on_one and (court.inbound_wait > 0.0 or court.restarting)
		if not (_inbound_phase and self != court.ball_handler()):
			wish = Vector2.ZERO
	# DEFENSE: with GUARD held, glue to the ball-handler and stay between him
	# and the basket. The user can then jump to block or reach in to steal.
	if guarding and is_user and not has_ball:
		var h: BallPlayer = court.ball_handler() if court != null else null
		if h != null and h.team != team:
			var own_hoop: Vector2 = court.hoop_for(1 - team)
			var gp: Vector2 = h.global_position + (own_hoop - h.global_position).normalized() * 46.0
			var gd: Vector2 = gp - global_position
			wish = gd.normalized() if gd.length() > 9.0 else Vector2.ZERO
			stance = gd.length() < 95.0
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
	if posting:
		target *= 0.6   # back-down: spingi il difensore col peso, si va piano
	var a := accel_rate()
	# hard direction changes cost more: this is what creates real momentum/inertia
	if wish.length() > 0.1 and velocity.length() > 30.0:
		var dot := wish.normalized().dot(velocity.normalized())
		if dot < 0.2:
			a *= lerpf(0.45, 1.0, clampf((dot + 1.0) / 1.2, 0.0, 1.0))
	if wish.length() < 0.05:
		a *= 1.6   # deceleration/friction is faster than acceleration
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

	# POST UP: mentre sei di spalle al canestro il facing resta SUL FERRO
	# contrario (spalle), qualunque direzione di stick; se ti allontani
	# troppo la post svanisce da sola.
	if posting and has_ball and court != null and stun <= 0.0 and landing <= 0.0:
		var post_hx: float = court.hoop_for(team).x - global_position.x
		if absf(post_hx) > 1.0:
			facing = -signf(post_hx)
		if court.px_to_ft(global_position.distance_to(court.hoop_for(team))) > 16.0:
			posting = false

	dribble_intensity = 1.0 if has_ball else clampf(velocity.length() / 200.0, 0.4, 1.4)

	if has_ball:
		possession_time += delta
		guarding = false
		_check_pressure(delta)
	else:
		possession_time = 0.0
		posting = false   # senza palla non esiste post up
	if shot_charge >= 0.0:
		shot_charge += delta
		# SAFETY: if the finger's release event was lost (multi-touch on Android
		# drops it often), never let the charge hang forever. Auto-fire as a very
		# late shot instead of soft-locking the player with a stuck meter.
		if shot_charge > MAX_CHARGE:
			do_shot_release()
	_update_ai_windup(delta)
	shot_anim = maxf(0.0, shot_anim - delta)
	fade_t = maxf(0.0, fade_t - delta)
	stepback_t = maxf(0.0, stepback_t - delta)
	# EUROSTEP: il SECONDO TEMPO parte a metà mossa (0.30s) e il finish
	# scatta a fine sequenza SE hai ancora la palla.
	if euro_t > 0.0:
		var was_second: bool = euro_t > 0.30
		euro_t = maxf(0.0, euro_t - delta)
		if was_second and euro_t <= 0.30 and court != null:
			var hd: Vector2 = (court.hoop_for(team) - global_position).normalized()
			velocity += hd * 250.0
			Sfx.squeak()
		if euro_t <= 0.0 and euro_finish:
			euro_finish = false
			if has_ball and court != null and not shot_charge_active():
				var dft2: float = court.px_to_ft(global_position.distance_to(court.hoop_for(team)))
				if dft2 < 9.0 and can_dunk():
					do_dunk()
				elif has_ball:
					court.attempt_shot(self, randf_range(0.0, 0.55))
					shot_anim = 0.26
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
		# Atterraggio da DUNK: polvere grande, tonfo piu sordo e
		# compressione forte del corpo. slam_fall viene impostato da do_dunk
		# e sopravvive anche all'appoggio sul ferro.
		var was_dunk: bool = slam_fall
		dust_big = was_dunk
		if jumping or was_dunk:
			dust_t = 0.70 if was_dunk else 0.45
		jumping = false
		dunking = false
		slam_fall = false
		# Heavier players take longer to gather after landing.
		landing = 0.14 * mass_f
		if was_dunk:
			Sfx.play("body", -6.0, randf_range(0.90, 1.0))   # tonfo della caduta
		if air_was > 46.0:
			Sfx.squeak()   # hard stop on landing: parquet life
		if air_was > 20.0:
			squash = -0.18 if was_dunk else -0.13   # compression: body widens
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
	var ft: float = court.px_to_ft(global_position.distance_to(court.hoop_for(team)))
	if ft > DUNK_RANGE_FT:
		return false
	# A dunk needs legs, not a scouting report. The old gate (athleticism *
	# height > 40) silently switched slams OFF for most created players and
	# most of the roster, which is why a scrimmage or a 1v1 never showed one.
	# What limits dunking now is what limits it in real life: getting all the
	# way to the rim with something left in the tank.
	return stamina01() > 0.15

func do_jump(for_block := false, lunge := 230.0) -> void:
	if jumping or hanging or landing > 0.0 or stun > 0.0:
		return
	jumping = true
	squash = 0.11
	air_v = jump_height()
	if for_block:
		# The contest window is generous on the way up, gone on the way down:
		# mistimed jumps should be punished, not forgiven. 1.15s perche'
		# deve coprire SIA il rilascio del tiro (meter lento) SIA tutta la
		# risalita del dunk: chi salta al gather arriva al ferro ancora
		# "in finestra" e la stenzata al ferro diventa possibile.
		block_window = 1.15
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
	slam_fall = true   # l'atterraggio che verra' e' da TONFO
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
		var rim: Vector2 = court.hoop_for(team)
		var to_rim: Vector2 = rim - global_position
		if to_rim.length() > 4.0:
			facing = signf(to_rim.x) if absf(to_rim.x) > 1.0 else facing
		velocity = Vector2.ZERO
		court.on_dunk_started(self)

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
		hang_off = global_position - court.hoop_for(team)

func release_rim() -> void:
	if not hanging:
		return
	hanging = false
	jumping = true
	air_v = -60.0

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

func shot_charge_active() -> bool:
	return shot_charge >= 0.0

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
		shot_anim = 0.26
		return
	var err: float = shot_charge - shot_ideal
	# Long shots have tighter release windows; rescale the raw error into the
	# standard window so the meter's shrunken green band matches what the sim
	# actually scores.
	if court != null:
		var ft: float = court.px_to_ft(global_position.distance_to(court.hoop_for(team)))
		var w: Dictionary = ShotSystem.shot_windows(ft, court != null and court.user_heat)
		err *= ShotSystem.PERFECT_WINDOW / maxf(float(w["perfect"]), 0.001)
	# FADEAWAY: rilascio andando VIA dal ferro (post hop o combo stick
	# indietro): l'animazione della schienata parte col follow-through.
	if court != null:
		var fade_hd: Vector2 = court.hoop_for(team) - global_position
		if fade_hd.length() > 40.0 and (velocity.dot(fade_hd.normalized()) < -60.0 \
				or (is_user and move_input.dot(fade_hd.normalized()) < -0.45)):
			fade_t = 0.75
	Sfx.play("shot_release", -7.0, randf_range(0.96, 1.05))
	posting = false   # il tiro (fade compreso) chiude sempre la post
	court.attempt_shot(self, err)
	shot_charge = -1.0
	# Play the same follow-through as the solo court: a short rise, the arm
	# extending, then settling -- so a scrimmage jumper looks like a jumper.
	shot_anim = 0.26

func do_pass(to: BallPlayer) -> void:
	if not has_ball or to == null: return
	fake_locked = false   # passare o tirare e' sempre lecito dopo la finta
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
	if cooldown_move > 0.0 or not has_ball:
		return false
	cooldown_move = 0.32
	stamina = maxf(0.0, stamina - 6.0)
	move_t = MOVE_DUR
	move_kind = kind
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
			stepback_t = 0.9   # apri la finestra dello STEPBACK 3
			# Same hop as the street court: plant and jump BACK from the rim.
			var away := Vector2(-facing, 0.0)
			if court != null:
				var hoop: Vector2 = court.hoop_for(team)
				var d: Vector2 = global_position - hoop
				if d.length() > 8.0:
					away = d.normalized()
			velocity = away * 320.0
			global_position += away * 28.0
		"hesi":
			velocity *= 0.25
		"euro":
			# EUROSTEP A DUE TEMPI CON FINISH: primo tempo scatto laterale
			# attorno al difensore, secondo tempo (a 0.30s) esplosione verso
			# il ferro, poi chiusura automatica a schiacciata o layup.
			var hoop_dir: Vector2 = Vector2.ZERO
			if court != null:
				hoop_dir = (court.hoop_for(team) - global_position).normalized()
			var side_dir: Vector2 = Vector2(-hoop_dir.y, hoop_dir.x)
			if side_dir.dot(Vector2(facing, 0)) < 0.0:
				side_dir = -side_dir
			velocity += side_dir * 300.0 + hoop_dir * 70.0
			hand_side = -hand_side
			euro_t = 0.52
			euro_finish = true
		"dropstep":
			# POST MOVE (spalle al canestro): scatto attorno al difensore
			# verso il ferro, cambio mano e via in layup.
			var hr: Vector2 = Vector2.ZERO
			if court != null:
				hr = (court.hoop_for(team) - global_position).normalized()
			var sd: Vector2 = Vector2(-hr.y, hr.x)
			if sd.dot(Vector2(facing, 0)) < 0.0:
				sd = -sd
			velocity += sd * 290.0 + hr * 120.0
			hand_side = -hand_side
			# Il drop step e' l'USCITA dal post: ti gira verso il ferro.
			posting = false
			if absf(hr.x) > 0.2:
				facing = signf(hr.x)
		"between":
			# TRA LE GAMBE: la palla passa sotto, il corpo si abbassa,
			# la mano cambia lato senza cambiare direzione.
			velocity *= 0.55
			hand_side = -hand_side
	Sfx.play("crossover", -6.0, randf_range(0.94, 1.08))
	for d in get_tree().get_nodes_in_group("team_%d" % (1 - team)):
		if global_position.distance_to(d.global_position) < 70.0 and randf() < success:
			var stun_t: float = lerpf(0.18, 0.55, success)   # "shook"
			# I difensori AI con skill alta recuperano l'equilibrio quasi
			# subito: il trick non puo' piu' regalare la schiacciata franca.
			for c in d.get_children():
				if "skill" in c:
					stun_t *= lerpf(1.0, 0.32, clampf(float(c.skill), 0.0, 1.0))
					break
			d.stun = stun_t
			Events.toast.emit("Shook!")
			Events.popup.emit("ANKLES!", global_position, Color(0.8, 0.9, 1.0), false)
	return true

## Where the ball sits relative to my feet while I dribble, so the match ball
## (drawn by the Ball entity) visibly follows the move: it swings side to side
## on a crossover, dips behind me on a behind-the-back, swaps hands on a cambio
## mano, pulls back on a stepback, and pauses on a hesi.
func carry_ball_offset() -> Dictionary:
	## The ball RIDES THE HAND for the whole slam. Read by Ball._physics_process
	## (same contract as dribble_ball_offset). Without this the ball stayed at
	## the dribbler's hip while the body flew to the rim, so the dunk looked
	## like the player jumping alone and the ball being switched off.
	## Positions come from the very same DunkStyle sample the body is drawn
	## from, so the ball cannot drift off the palm.
	if not (dunking and not hanging):
		return {"active": false}
	var s: Dictionary = DunkStyle.sample(dunk_style, clampf(dunk_t, 0.0, 1.0))
	var bl: Vector2 = DunkStyle.ball_local(s)
	var hb: float = _body_h()
	var sdir: float = 1.0 if facing >= 0.0 else -1.0
	return {"active": true, "x": bl.x * hb * sdir, "h": air + bl.y * hb}

func dribble_ball_offset() -> Dictionary:
	# Same bounce the avatar palm uses (anim_t * 1.6), so the ball sits IN the hand.
	var hs: float = hand_side if absf(hand_side) > 0.1 else 1.0
	var hb: float = 64.0 * height_f
	# FINTA: palla TENUTA in mano davanti al petto, come nel court libero —
	# niente palleggio durante la finta.
	if fake_t > 0.0 or fake_locked:
		var fh: float = air + hb * (0.42 if fake_t > 0.12 else 0.55)
		return {"x": hs * hb * 0.20, "h": fh}
	# Bounce SINCRONO con il braccio dell'avatar: stesso phase che la
	# mano usa (durante un trick il braccio accelera a anim_t*1.9: anche
	# la palla accelera. Prima restava sul proprio orologio lento).
	var _arm_ph: float = anim_t * 1.9 if move_t > 0.0 else dribble_phase
	var bounce: float = absf(sin(_arm_ph * 1.15))
	var side := hs * hb * 0.34
	var hh := bounce * hb * 0.55 + Court.BALL_R
	if move_t > 0.0:
		var f: float = 1.0 - move_t / MOVE_DUR     # 0..1 progress
		var low: float = sin(f * PI)
		match move_kind:
			"crossover":
				# scambio di mano con overshoot: la palla scatta oltre la gamba
				side = lerpf(side, -side, smoothstep(0.0, 1.0, f)) * (1.0 + 0.18 * low)
				hh = 27.0 + low * 40.0
			"behind":
				side = lerpf(side, -side, smoothstep(0.0, 1.0, f))
				hh = 14.0 + low * 26.0
			"hand_switch":
				side = lerpf(side, -side, smoothstep(0.0, 1.0, f)) * (1.0 + 0.12 * low)
				hh = 22.0 + low * 34.0
			"stepback":
				side *= 0.7
				hh = 19.0 + low * 31.0
			"hesi":
				hh = 16.0
			"spin":
				# la palla AVVOLGE il corpo: giro completo attorno al giocatore
				side = hs * sin(f * TAU) * hb * 0.46
				hh = 24.0 + low * 22.0
			"between":
				# sotto la gamba: la palla scende quasi a terra al centro
				# del corpo e risale sull'altra mano.
				side = lerpf(side, -side, smoothstep(0.15, 0.85, f))
				side *= (1.0 - 0.85 * low)   # il tragitto passa vicino a x=0
				hh = Court.BALL_R + 2.0 + (1.0 - low) * 34.0
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
		dir = (court.hoop_for(team) - global_position).normalized()
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
		if is_user:
			Sfx.haptic(35)
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
	# Pass aim: a blue disc on the floor under the teammate the joystick
	# is pointing at.
	if court != null and court.aimed == self:
		draw_set_transform(proj - position, 0.0, Vector2(1.0, 0.55) * dscale)
		draw_circle(Vector2.ZERO, 38.0, Color(0.20, 0.55, 1.0, 0.42))
		draw_arc(Vector2.ZERO, 38.0, 0.0, TAU, 28, Color(0.45, 0.75, 1.0, 0.9), 3.0)
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
	if fake_t > 0.0:
		kind = Avatar.SHOOT
		amount = 0.35 * (fake_t / 0.32)
	elif shot_anim > 0.0:
		# Follow-through: a short rise, the arm extending up, then settling --
		# the same release animation as the solo court's shot-around.
		var f: float = 1.0 - clampf(shot_anim / 0.26, 0.0, 1.0)
		kind = Avatar.SHOOT
		amount = 0.25 + f * 0.75
		air_draw += sin(f * PI) * h * 0.30
	elif hanging:
		kind = Avatar.DUNK
		amount = 1.0
		# Feet placed so the outstretched hand lands ON the iron: the same
		# DunkStyle.REACH the pose and the ball carry are built from.
		air_draw = maxf(court.RIM_HEIGHT - h * DunkStyle.REACH, 0.0)
		slam = DunkStyle.sample(dunk_style, 1.0)
		# GIOCATORE ABBASSATO (come street): le spalle SOTTO il bordo del
		# ferro, la testa fuori dal canestro, la mano dello slam risale al
		# labbro piegato (rim_drop = labbro sceso - abbassamento corpo).
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
		kind = Avatar.SHOOT
		# Sinks into the gather as the meter fills.
		amount = 1.0 - clampf(shot_charge / maxf(shot_ideal, 0.01), 0.0, 1.0) * 0.8
	elif ai_windup_t >= 0.0:
		# Same telegraphed gather as the human charge -- the visible tell a
		# defender reads to time the close-out and the jump.
		kind = Avatar.SHOOT
		amount = 1.0 - clampf(gather_progress(), 0.0, 1.0) * 0.8
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
	elif kind == Avatar.DRIBBLE:
		# PARITA' COURT SOLO: fermo e in corsa il braccio del palleggio
		# usa l'orologio 4.2 del libero (prima scalava con la velocita').
		phase = dribble_phase

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
	var walking: bool = velocity.length() > 14.0 or move_input.length() > 0.12
	var dunk_trick := dunk_style if (dunking or hanging) else trick
	var po: Dictionary = Avatar.pose(kind, phase, amount, dunk_trick, walking)
	po["hand"] = hand_side
	if fade_t > 0.0:
		po["lean_back"] = clampf(fade_t / 0.75, 0.0, 1.0)
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
	if hanging:
		po["rim_drop"] = rim_drop_v
	if hanging and slam.is_empty():
		po["hang"] = true
		if hang_off.y < -12.0:
			po["back"] = true
		var hoop: Vector2 = court.hoop_for(team) if court else Vector2.ZERO
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
	# OMBRA REALE (richiesta utente): durante la schiacciata sta A TERRA,
	# scorre al centro della semicirconferenza sotto il ferro e DIVENTA
	# PIU' GRANDE mentre sali. Mai in aria con il corpo.
	var air_norm: float = clampf(air_draw / 240.0, 0.0, 1.2)
	if dunking and court != null:
		var rim_g: Vector2 = court.hoop_for(team)
		var sh_pos: Vector2 = global_position.lerp(rim_g, clampf(dunk_t * 0.85, 0.0, 1.0)) - global_position
		var shs2: float = 1.2 + clampf(air_norm, 0.0, 1.0) * 0.45
		draw_colored_polygon(PackedVector2Array([
			sh_pos + Vector2(-h * 0.20 * shs2, 8.0), sh_pos + Vector2(h * 0.20 * shs2, 8.0),
			sh_pos + Vector2(h * 0.09, 17.0), sh_pos + Vector2(-h * 0.09, 17.0)]),
			Color(0, 0, 0, 0.40))
	elif hanging and court != null:
		h *= 1.08
		var rim_g2: Vector2 = court.hoop_for(team)
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
	_low = bool(Settings.get_v("lowgfx", false))
	Avatar.draw_body(self, feet, h, facing, po, cols, false, air_draw < 12.0 and not dunking, is_user,
		-1.0, Transform2D(0.0, Vector2(1.0 - squash * 0.5, 1.0 + squash) * dscale, 0.0, proj - position))
	# HEAT CHECK: lingue di fuoco sopra la testa (stesse del court solo)
	if court != null and court.user_heat and is_user and not bool(Settings.get_v("lowgfx", false)):
		Avatar.draw_flames(self, feet + Vector2(0.0, -h * 1.16), Time.get_ticks_msec() / 1000.0)

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

	# Landing dust: a flat puff that sweeps out sideways as it fades.
	if dust_t > 0.0:
		var dur: float = 0.70 if dust_big else 0.45
		var k: float = clampf(1.0 - dust_t / dur, 0.0, 1.0)
		var da: float = (1.0 - k) * (0.65 if dust_big else 0.5)
		var spread: float = lerpf(16.0, 78.0, k) if dust_big else lerpf(12.0, 52.0, k)
		draw_set_transform(proj - position, 0.0, Vector2(1.0, 0.55) * dscale)
		var n: int = (5 if dust_big else 3) if _low else (10 if dust_big else 6)
		for i in n:
			var side := -1.0 if i % 2 == 0 else 1.0
			var px: float = side * spread * (0.4 + 0.6 * float((i + 1) % 3) / 2.0)
			var py: float = -6.0 - (i % 2) * (7.0 if dust_big else 5.0)
			var r: float = lerpf(9.0, 2.5, k) if dust_big else lerpf(7.0, 2.5, k)
			draw_circle(Vector2(px, py), r, Color(0.85, 0.80, 0.68, da))
		draw_set_transform(proj - position, 0.0, Vector2(1.0 - squash * 0.5, 1.0 + squash) * dscale)
	# stance indicator
	if stance and not _low:
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
