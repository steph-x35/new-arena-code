extends RefCounted
class_name DunkStyle
## THE dunk catalogue. One file, used by every court in the game: the street
## solo court (outdoor), the team facility solo session, the 5v5 scrimmage and
## 1v1 all play the SAME slams, so a windmill looks like a windmill everywhere.
##
## Why it is shared: the pose is sampled ONCE here as a handful of numbers
## expressed in body-heights, and two consumers read it --
##   1. the avatar renderer (src/ui/Avatar.gd) that draws the body, and
##   2. the ball carry (Player.carry_ball_offset / SoloCourt) that keeps the
##      ball glued to the hand for the whole flight.
## If those two ever disagreed the ball would float off the palm, which is
## exactly how a slam ends up reading as "the ball just vanished".
##
## `t` runs 0 -> 1: 0 is the gather with the feet still on the floor, 1 is the
## instant the ball goes through the iron.

const TWO_HAND := "two_hand"
const WINDMILL := "windmill"
const SPIN360 := "spin360"
const TOMAHAWK := "tomahawk"
const CRADLE := "cradle"
const REVERSE := "reverse"

const STYLES := [TWO_HAND, WINDMILL, SPIN360, TOMAHAWK, CRADLE, REVERSE]

const LABELS := {
	TWO_HAND: "SLAM",
	WINDMILL: "WINDMILL",
	SPIN360: "360 SLAM",
	TOMAHAWK: "TOMAHAWK",
	CRADLE: "CRADLE",
	REVERSE: "REVERSE",
}

## Shoulder height above the feet, in body-heights: the anchor the arm swings
## from. Same 0.80 the avatar renderer draws the shoulders at.
const SHOULDER := 0.80
## Reach of the outstretched strong arm above the feet.
## 0.80 (shoulder) + 0.40 (arm) = the 1.20 that Court._dunk_air() solves the
## jump against, so the hand lands exactly on the iron.
const ARM := 0.40
const REACH := SHOULDER + ARM

static func pick(r := -1.0) -> String:
	## Weighted: the bread-and-butter slam is common, the flashy ones are the
	## reward for getting to the rim.
	var v: float = randf() if r < 0.0 else clampf(r, 0.0, 0.9999)
	if v < 0.20:
		return TWO_HAND
	elif v < 0.40:
		return WINDMILL
	elif v < 0.58:
		return SPIN360
	elif v < 0.76:
		return TOMAHAWK
	elif v < 0.89:
		return CRADLE
	return REVERSE

static func label(style: String) -> String:
	return String(LABELS.get(style, "SLAM"))

static func rise_time(style: String) -> float:
	## Seconds from the gather to the slam. The flashier the move, the longer
	## the flight -- a 360 has to have time to actually turn. Every court uses
	## this number, so the animation and the collision are never out of step.
	match style:
		WINDMILL:
			return 0.82
		SPIN360:
			return 0.88
		TOMAHAWK:
			return 0.78
		CRADLE:
			return 0.84
		REVERSE:
			return 0.80
		_:
			return 0.70

static func sample(style: String, t: float) -> Dictionary:
	## The pose at `t`, every length in body-heights (1.0 = the drawn height of
	## the player) so a 2.10 m centre and a small guard slam identically.
	##
	## Keys:
	##   arm_ang    angle of the strong arm: 0 = straight up, + = forward/down,
	##              - = behind. sin/cos of it place the hand, so a 360 sweep of
	##              the angle IS a windmill.
	##   arm_len    arm reach in body-heights.
	##   hand_extra extra hand offset (x forward-positive, y upward).
	##   ball_extra extra ball offset relative to the hand.
	##   lift       extra rise of the whole figure (body-heights).
	##   crouch     knee load before take-off.
	##   tuck       knee tuck at the top of the jump.
	##   spin       0 = front, 0.5 = back. Drives the 360 and the reverse.
	##   both       both hands on the ball (two-hand slam).
	##   lean       sideways body lean.
	var p := clampf(t, 0.0, 1.0)
	# Shared timeline. `load` is the dip into the jump, `move` is the trick
	# itself, `slam` is the throw-down at the iron. They overlap on purpose:
	# a dunk is one continuous motion, not three animations stapled together.
	var move := smoothstep(0.20, 0.80, p)
	var slam := smoothstep(0.72, 1.0, p)
	var load := 1.0 - smoothstep(0.0, 0.30, p)

	var out := {
		"style": style,
		"t": p,
		"arm_ang": 0.16,
		"arm_len": 0.40,
		"hand_extra": Vector2.ZERO,
		"ball_extra": Vector2.ZERO,
		"lift": 0.0,
		"crouch": 0.0,
		"tuck": 0.0,
		"spin": 0.0,
		"both": false,
		"lean": 0.0,
		"off_arm": 0.15,
	}

	match style:
		TWO_HAND:
			# Cocked behind the head with both hands, then hammered straight
			# down. The classic: two hands, no nonsense.
			out["both"] = true
			out["off_arm"] = 1.0
			out["arm_ang"] = lerpf(-0.55, 0.16, slam)
			out["hand_extra"] = Vector2(0.10, 0.10) * (1.0 - slam)
			out["ball_extra"] = Vector2(0.0, 0.05)
			out["crouch"] = 0.06 * load
			out["tuck"] = 0.55 * move

		WINDMILL:
			# The ball travels a full circle around the shoulder: cocked behind
			# the hip, swept down and forward, then up over the head into the
			# rim. 4.7 rad of arm sweep is what sells it.
			out["arm_ang"] = lerpf(-4.71, 0.16, move)
			out["off_arm"] = 0.40
			out["ball_extra"] = Vector2(0.03, 0.06)
			out["crouch"] = 0.07 * load
			out["tuck"] = 0.60 * move
			out["lean"] = 0.05 * sin(move * PI)

		SPIN360:
			# Half a turn in the air: the figure turns away from the camera and
			# back, the ball held high on the far side, then slammed.
			out["spin"] = move
			out["off_arm"] = 0.80
			out["arm_ang"] = lerpf(-0.35, 0.16, slam)
			out["hand_extra"] = Vector2(-0.06, 0.06) * (1.0 - slam)
			out["ball_extra"] = Vector2(0.0, 0.07)
			out["crouch"] = 0.06 * load
			out["tuck"] = 0.70 * move
			out["lift"] = 0.05 * sin(move * PI)

		TOMAHAWK:
			# Cocked hard behind the head -- ball behind the ear -- then thrown
			# down through the rim with the body arched.
			out["arm_ang"] = lerpf(-0.95, 0.16, slam)
			out["off_arm"] = 0.55
			out["hand_extra"] = Vector2(-0.16, 0.12) * (1.0 - slam)
			out["ball_extra"] = Vector2(-0.04, 0.05)
			out["crouch"] = 0.07 * load
			out["tuck"] = 0.50 * move
			out["lean"] = -0.05 * sin(move * PI)

		CRADLE:
			# The ball is cradled down between the legs at the peak, then
			# whipped up and in. Reads as a scoop under the defence.
			out["arm_ang"] = lerpf(-2.95, 0.20, slam)
			out["off_arm"] = 0.30
			out["hand_extra"] = Vector2(0.06, -0.28) * (1.0 - slam)
			out["ball_extra"] = Vector2(0.02, 0.02)
			out["crouch"] = 0.08 * load
			out["tuck"] = 0.75 * move

		REVERSE:
			# Turned away from the rim at the top, ball taken up on the far
			# side of the head, dropped in backwards.
			out["spin"] = 0.55 * slam
			out["off_arm"] = 0.80
			out["arm_ang"] = lerpf(0.5, 0.10, slam)
			out["hand_extra"] = Vector2(-0.24, 0.10) * slam
			out["ball_extra"] = Vector2(-0.05, 0.06)
			out["crouch"] = 0.06 * load
			out["tuck"] = 0.65 * move
			out["lift"] = 0.04 * sin(move * PI)

	# Knees come up a little on every jump; the finish pose is a full
	# extension, so the load/tuck must be gone by the slam.
	var ext: float = 1.0 - slam
	for k in ["crouch", "tuck"]:
		out[k] = float(out[k]) * ext
	return out

static func hand_local(s: Dictionary) -> Vector2:
	## Where the strong hand is, relative to the FEET, in body-heights.
	## x is forward-positive (the renderer mirrors it by the facing), y is up.
	## Both the avatar and the ball carry read this, so the ball can never
	## drift off the palm.
	var a: float = float(s.get("arm_ang", 0.0))
	var r: float = float(s.get("arm_len", ARM))
	var e: Vector2 = s.get("hand_extra", Vector2.ZERO)
	return Vector2(sin(a) * r + e.x, SHOULDER + cos(a) * r + e.y)

static func ball_local(s: Dictionary) -> Vector2:
	## Where the ball sits, relative to the feet, in body-heights.
	var be: Vector2 = s.get("ball_extra", Vector2.ZERO)
	var hl: Vector2 = hand_local(s)
	return Vector2(hl.x + be.x, hl.y + be.y)
