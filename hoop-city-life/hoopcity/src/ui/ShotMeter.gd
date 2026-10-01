extends Control
class_name ShotMeter
## Shot meter drawn as an arc directly above the SHOOT button.
##
## Design notes: the player is looking at their right thumb, so the feedback has
## to live there. The green PERFECT band is drawn to scale from the real
## ShotSystem windows, so what you see is exactly what the sim scores -- no
## cosmetic lying. After release the meter freezes for a beat and flashes the
## verdict, which is how you learn the timing.

var charge := 0.0          # seconds held
var ideal := 0.6           # ideal release point in seconds
var max_charge := 1.4
## Per-shot release windows in seconds. 0 means "use the standard ShotSystem
## windows"; a shooter sets these smaller for long shots so the green band
## shrinks exactly as the real scoring windows do.
var perfect_window := 0.0
var good_window := 0.0

var frozen := false
var freeze_t := 0.0
var verdict := ""
var verdict_col := Color.WHITE
## 0..1 defender pressure while charging -- tints the meter red and labels
## the look, so the timing bar tells the same contest story the sim rolls.
var contest := 0.0

func _r() -> float:
	return maxf(minf(size.x, size.y) * 0.38, 22.0)

func _process(delta: float) -> void:
	if frozen:
		freeze_t -= delta
		if freeze_t <= 0.0:
			frozen = false
			visible = false
	queue_redraw()

func show_release(name: String, made_col: Color) -> void:
	frozen = true
	freeze_t = 0.75
	verdict = name
	verdict_col = made_col
	if name == "PERFECT":
		Sfx.haptic(22)

func _center() -> Vector2:
	return Vector2(size.x * 0.5, size.y)

func _ang(t: float) -> float:
	# map 0..max_charge onto a 200-degree arc opening upward
	return PI * 1.11 + (t / max_charge) * (PI * 0.78)

func _draw() -> void:
	var c := _center()
	var R: float = _r()
	var W: float = maxf(R * 0.22, 5.0)
	# track
	draw_arc(c, R, _ang(0.0), _ang(max_charge), 64, Color(0, 0, 0, 0.45), W)
	draw_arc(c, R, _ang(0.0), _ang(max_charge), 64, Color(1, 1, 1, 0.10), W)

	# RED everywhere, YELLOW band, GREEN band on top -- the three zones the
	# shot rules are written against, drawn to scale from the real windows so
	# what you see is exactly what is scored. Under pressure the track glows
	# red so a contested gather reads before the release.
	var track_col := Color(0.62, 0.18, 0.16, 0.55)
	if contest > 0.33:
		track_col = Color(0.95, 0.25, 0.2, 0.55 + 0.3 * sin(Time.get_ticks_msec() / 90.0))
	draw_arc(c, R, _ang(0.0), _ang(max_charge), 48, track_col, W)
	var gw: float = good_window if good_window > 0.0 else ShotSystem.GOOD_WINDOW
	var pw: float = perfect_window if perfect_window > 0.0 else ShotSystem.PERFECT_WINDOW
	draw_arc(c, R, _ang(maxf(ideal - gw, 0.0)), _ang(minf(ideal + gw, max_charge)), 32,
		Color(0.90, 0.78, 0.22, 0.90), W)
	draw_arc(c, R, _ang(maxf(ideal - pw, 0.0)), _ang(minf(ideal + pw, max_charge)), 16,
		Color(0.30, 0.95, 0.36, 1.0), W)

	# filled portion
	var t: float = clampf(charge, 0.0, max_charge)
	var fill := Color(1.0, 0.78, 0.25)
	if absf(charge - ideal) <= pw: fill = Color(0.55, 1.0, 0.55)
	elif absf(charge - ideal) <= gw: fill = Color(0.75, 0.95, 0.6)
	elif charge > ideal + gw: fill = Color(1.0, 0.42, 0.35)
	if t > 0.005:
		draw_arc(c, R, _ang(0.0), _ang(t), 48, fill, maxf(W * 0.55, 3.0))

	# the needle
	var a := _ang(t)
	var dir := Vector2(cos(a), sin(a))
	draw_line(c + dir * (R - W), c + dir * (R + W), Color.WHITE, maxf(W * 0.2, 2.0))
	draw_circle(c + dir * R, maxf(W * 0.35, 3.0), Color.WHITE)

	# over-charge warning: you are about to auto-fire
	if charge > max_charge * 0.88 and not frozen:
		draw_arc(c, R + W, _ang(0.0), _ang(max_charge), 48,
			Color(1.0, 0.3, 0.25, 0.35 + 0.35 * sin(Time.get_ticks_msec() / 60.0)), maxf(W * 0.2, 2.0))

	# No words on the meter, ever: "WIDE OPEN / CONTESTED" headlines covered
	# the arc and annoyed players on every court. Contest is now a silent
	# coloured pip under the arc centre (green = free, red = smothered).
	if frozen and verdict != "":
		draw_circle(c + Vector2(0.0, R * 0.62), 5.0, verdict_col)
	elif charge >= 0.0:
		var lcol := Color(0.5, 1, 0.55)
		if contest > 0.66:
			lcol = Color(1, 0.35, 0.3)
		elif contest > 0.33:
			lcol = Color(1, 0.75, 0.3)
		draw_circle(c + Vector2(0.0, -R * 0.40), 4.0, lcol)
