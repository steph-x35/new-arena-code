extends Node2D
## A pedestrian strolling the pavement. Pure ambience.
##
## Drawn through the SHARED Avatar so the townsfolk read as the same art style
## as the player -- but with the player's own hat/glasses turned OFF and random
## skin, hair and clothes, so the street is full of other people rather than a
## crowd of clones of you.
##
## Performance: the city already had lag problems, so a pedestrian does no work
## when it is off screen, and it repaints only while it is actually moving.

var dir := 1.0
var speed := 55.0
var cols := {}
var h_scale := 1.0
var night := 0.0
var t := 0.0
var _last_x := 0.0                  # repaint only when he has really moved

const PAVEMENT_TOP := 252.0
const PAVEMENT_BOT := 316.0

func setup(x: float, d: float) -> void:
	dir = d
	position = Vector2(x, randf_range(PAVEMENT_TOP, PAVEMENT_BOT))
	speed = randf_range(34.0, 80.0)
	h_scale = randf_range(0.88, 1.12)
	z_index = 6
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var jersey := Color.from_hsv(rng.randf(), rng.randf_range(0.30, 0.65),
		rng.randf_range(0.45, 0.80))
	var skins := [Color(0.72, 0.53, 0.38), Color(0.55, 0.36, 0.26),
		Color(0.86, 0.69, 0.52), Color(0.40, 0.27, 0.19), Color(0.94, 0.79, 0.64)]
	var hairs := [Color(0.12, 0.09, 0.08), Color(0.30, 0.20, 0.12),
		Color(0.10, 0.10, 0.12), Color(0.55, 0.42, 0.24), Color(0.75, 0.70, 0.66)]
	cols = Avatar.colours(false, jersey)
	cols["hst"] = [0, 0, 0, 1, 2, 3, 4, 5].pick_random()   # ogni passante il suo taglio
	cols["muscle"] = randf_range(0.0, 0.35)
	cols["skin"] = skins[rng.randi_range(0, skins.size() - 1)]
	cols["hair"] = hairs[rng.randi_range(0, hairs.size() - 1)]
	cols["shorts"] = jersey.darkened(0.5)
	cols["shoes"] = Items.random_wear_col("shoes")

func set_night(v: float) -> void:
	# Same step quantisation as the cars: repaint only on whole light steps.
	var step := roundf(v / 0.15) * 0.15
	if absf(step - night) < 0.001:
		return
	night = step
	queue_redraw()

func _process(delta: float) -> void:
	t += delta * (6.0 + speed * 0.02)
	position.x += dir * speed * delta
	if position.x > 2460.0:
		position.x = 2460.0
		dir = -1.0
	if position.x < -1680.0:
		position.x = -1680.0
		dir = 1.0
	# Cull work off screen: no repaint while the pedestrian is far from the
	# camera, which keeps a dozen walkers from costing anything most frames.
	var cam := get_viewport().get_camera_2d()
	if cam != null and absf(global_position.x - cam.global_position.x) > 1500.0:
		visible = false
		return
	visible = true
	# Repaint only when he has actually walked a couple of pixels: the shared
	# avatar is the same cost as the player's, and nine of them re-drawing at
	# 60 fps was the other half of the street stutter.
	queue_redraw()

func _draw() -> void:
	var h := 62.0 * h_scale
	# Night dims the figure like everything else on the street.
	var dim := Color(1, 1, 1).lerp(Color(0.60, 0.64, 0.78), night)
	var c := {}
	for k in cols:
		# Solo i Color si attenuano col night tint: muscle (float) e hst
		# (int) venivano moltiplicati uguali e diventavano Color, cosi'
		# draw_body trovava float(Color) e spammava un errore a frame.
		if cols[k] is Color:
			c[k] = cols[k] * dim
		else:
			c[k] = cols[k]
	Avatar.draw_body(self, Vector2.ZERO, h, dir,
		Avatar.pose(Avatar.RUN, t), c, false, true, false)
