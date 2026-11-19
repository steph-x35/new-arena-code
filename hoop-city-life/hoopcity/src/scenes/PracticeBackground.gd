extends Node2D
## Six team-mates share the gym during the 2v2. Their balls and movement are
## independent of the live match ball, so they cannot steal or score in it.
var court: Court
var actors: Array[BallPlayer] = []
var balls := []
var elapsed := 0.0

func setup(c: Court) -> void:
	court = c

func _ready() -> void:
	z_index = 40
	var shirts := [Color(0.28, 0.43, 0.70), Color(0.65, 0.25, 0.22), Color(0.28, 0.58, 0.42), Color(0.62, 0.53, 0.32)]
	shirts.shuffle()
	for i in 6:
		var p := BallPlayer.new()
		p.team = 0
		court.add_child(p)
		court._randomize_npc(p, 0, i + 3)
		p.jersey_num = 21 + i * 3
		p.set_meta("practice_colour", shirts[i % shirts.size()])
		p.set_physics_process(false)
		p.remove_from_group("players")
		p.remove_from_group("team_0")
		p.global_position = [Vector2(-500, -160), Vector2(-410, 170), Vector2(-230, -300), Vector2(-190, -280), Vector2(-280, 265), Vector2(-370, 300)][i]
		actors.append(p)
		if i < 2:
			balls.append({"state": "ready", "time": -float(i) * 1.7, "pos": p.global_position, "h": 48.0})

func _physics_process(delta: float) -> void:
	elapsed += delta
	var hoop := Vector2(-Court.COURT_W * 0.5 + Court.FIBA_HOOP_INSET, 0)
	for i in 2:
		var p: BallPlayer = actors[i]
		var b: Dictionary = balls[i]
		var spot := Vector2(-512.0 if i == 0 else -400.0, -90.0 if i == 0 else 170.0)
		match String(b["state"]):
			"ready":
				if _move(p, spot, delta):
					b["time"] = float(b["time"]) + delta
					if float(b["time"]) >= 1.0:
						b["state"] = "flight"
						b["time"] = 0.0
						b["from"] = p.global_position
						b["land"] = hoop + Vector2(70.0, 40.0 if i == 0 else -55.0)
						p.shot_anim = 0.5
				b["pos"] = p.global_position + Vector2(-12, 0)
				b["h"] = 48.0
			"flight":
				b["time"] = float(b["time"]) + delta
				var t := clampf(float(b["time"]) / 0.9, 0.0, 1.0)
				b["pos"] = Vector2(b["from"]).lerp(hoop, t)
				b["h"] = lerpf(48.0, Court.RIM_HEIGHT, t) + sin(PI * t) * 150.0
				if t >= 1.0:
					b["state"] = "drop"
					b["time"] = 0.0
			"drop":
				b["time"] = float(b["time"]) + delta
				var t := clampf(float(b["time"]) / 0.45, 0.0, 1.0)
				b["pos"] = hoop.lerp(b["land"], t)
				b["h"] = Court.RIM_HEIGHT * (1.0 - t)
				if t >= 1.0: b["state"] = "retrieve"
			"retrieve":
				if _move(p, b["land"], delta):
					b["state"] = "ready"
					b["time"] = -0.6
	for p in actors:
		p.anim_t += delta * (5.0 if p.velocity.length() > 1.0 else 1.0)
		p.shot_anim = maxf(p.shot_anim - delta, 0.0)
		p.queue_redraw()
	queue_redraw()

func _move(p: BallPlayer, target: Vector2, delta: float) -> bool:
	var d := target - p.global_position
	if d.length() < 3.0:
		p.velocity = Vector2.ZERO
		return true
	p.velocity = d.normalized() * 165.0
	p.global_position += d.normalized() * minf(d.length(), delta * 165.0)
	p.facing = signf(d.x) if absf(d.x) > 3.0 else p.facing
	return false

func _draw() -> void:
	for b in balls:
		var pos: Vector2 = CourtStage.m_project(b["pos"], Court.COURT_H)
		pos.y -= float(b["h"])
		draw_circle(pos, Court.BALL_R, Color(0.95, 0.55, 0.15))

func clear_players() -> void:
	for p in actors:
		if is_instance_valid(p): p.queue_free()
	actors.clear()
	queue_free()

func _exit_tree() -> void:
	for p in actors:
		if is_instance_valid(p): p.queue_free()
