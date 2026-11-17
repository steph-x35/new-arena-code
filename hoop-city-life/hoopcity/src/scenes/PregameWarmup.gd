extends "res://src/scenes/SoloCourt.gd"
## A separate, non-scoring shootaround. The real match is created only after
## the player presses PLAY, so neither clock nor box score can run here.

var warmup_time := 0.0
var starting := false

func _ready() -> void:
	pregame_warmup = true
	super._ready()
	court_art.crowd_on = true
	court_art.show_cheer = true
	court_art.request_rebake()
	if btn_hc: btn_hc.hide()
	if btn_hc_big: btn_hc_big.hide()
	if talk_button: talk_button.hide()
	if stop_helper_button: stop_helper_button.hide()
	var root: Control = hud_layer.get_child(0)
	# Replace the solo court's exit and challenge controls, not the shooting pad.
	for child in root.get_children():
		if child is Button and child.text == "< Leave": child.hide()
	var play := Button.new()
	play.name = "PlayMatch"
	play.text = "GIOCA  ›" if Loc.lang == "it" else "PLAY  ›"
	play.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	play.position = Vector2(-230, 24)
	play.size = Vector2(210, 64)
	play.add_theme_font_size_override("font_size", 24)
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0.13, 0.56, 0.40)
	skin.border_color = Color(0.67, 0.94, 0.75)
	skin.set_border_width_all(2)
	skin.set_corner_radius_all(10)
	play.add_theme_stylebox_override("normal", skin)
	play.pressed.connect(_start_match)
	root.add_child(play)
	lbl_top.text = "RISCALDAMENTO  ·  %s  vs  %s" % [Season.my_team(), String(Game.profile.get("next_opponent", ""))] if Loc.lang == "it" else "SHOOTAROUND  ·  %s  vs  %s" % [Season.my_team(), String(Game.profile.get("next_opponent", ""))]
	Sfx.stop_music()
	Sfx.start_crowd()

func _exit_tree() -> void:
	Sfx.stop_crowd()
	super._exit_tree()

func _leave() -> void:
	# Back cancels the pregame instead of silently starting a fixture.
	if starting: return
	SceneRouter.goto(SceneRouter.pregame_return_path)

func _start_match() -> void:
	if starting: return
	starting = true
	SceneRouter.goto("res://src/match/MatchScene.tscn")

func _update_talk_button() -> void:
	pass

func _spawn_npcs() -> void:
	# Two independent balls per side, plus a stretch and a foam roller. These
	# actors are decorative and never join the match or touch the user's ball.
	var points := [Vector2(420,-190), Vector2(590,170), Vector2(-430,-190), Vector2(-590,170), Vector2(155,-115), Vector2(-155,115)]
	for i in points.size():
		var team := 0 if i < 2 or i == 4 else 1
		var kit: Color = Game.team_colour(team)
		var look := Avatar.colours(false, kit)
		look["kit"] = true
		look["num"] = str(10 + i * 3)
		look["hst"] = i % 6
		look["skin"] = [Color(0.76,0.57,0.43), Color(0.45,0.29,0.22), Color(0.88,0.70,0.55)][i % 3]
		look["hair"] = Game.HAIR_COLORS[i % Game.HAIR_COLORS.size()]
		npcs.append({"pos": points[i], "home": points[i], "team": team, "look": look,
			"state": "wait" if i < 4 else ("stretch" if i == 4 else "roller"),
			"t": -float(i) * 0.65, "face": 1.0 if team == 0 else -1.0,
			"helper": (RIM if team == 0 else LEFT_RIM) + Vector2(-90.0 if team == 0 else 90.0, -90.0 if i % 2 == 0 else 90.0),
			"ball_ground": (RIM if team == 0 else LEFT_RIM) + Vector2(-75.0 if team == 0 else 75.0, -60.0 if i % 2 == 0 else 60.0)})

func _update_npcs(delta: float) -> void:
	warmup_time += delta
	for n in npcs:
		if n["state"] in ["stretch", "roller"]: continue
		n["t"] = float(n["t"]) + delta
		var state := String(n["state"])
		if state == "wait" and float(n["t"]) >= 1.5:
			n["state"] = "shoot"
			n["t"] = 0.0
		elif state == "shoot" and float(n["t"]) >= 1.0:
			court_art.net_bump(1 if int(n["team"]) == 0 else 0, 0.65)
			n["state"] = "fall"
			n["t"] = 0.0
		elif state == "fall" and float(n["t"]) >= 0.9:
			n["state"] = "collect"
			n["t"] = 0.0
		elif state == "collect":
			var helper: Vector2 = n["helper"]
			var target: Vector2 = n["ball_ground"]
			var d := target - helper
			if d.length() <= 4.0:
				n["helper"] = target
				n["state"] = "pass"
				n["t"] = 0.0
			else:
				n["helper"] = helper + d.normalized() * minf(145.0 * delta, d.length())
		elif state == "pass" and float(n["t"]) >= 0.65:
			n["state"] = "wait"
			n["t"] = -0.5

func _draw_npcs() -> void:
	for n in npcs:
		var pos: Vector2 = _screen(n["pos"])
		var h := 60.0
		var state := String(n["state"])
		var team := int(n["team"])
		var rim: Vector2 = RIM if team == 0 else LEFT_RIM
		var face: float = float(n["face"])
		if state == "roller":
			# A low, gently moving figure supported by the visible foam cylinder.
			var roll := sin(warmup_time * 1.3) * 7.0
			draw_line(pos + Vector2(-16 + roll, -4), pos + Vector2(16 + roll, -4), Color(0.26,0.34,0.43), 11.0)
			var xf := Transform2D(0.0, Vector2.ONE, 0.0, pos) * Transform2D(-0.24, Vector2(1.0, 0.58)) * Transform2D(0.0, Vector2.ONE, 0.0, -pos)
			Avatar.draw_body(self, pos + Vector2(roll, -5), h, face, Avatar.pose(Avatar.IDLE, warmup_time), n["look"], false, false, false, BALL_R, xf)
		elif state == "stretch":
			var pose := Avatar.pose(Avatar.DEFEND, warmup_time, 0.55 + 0.25 * sin(warmup_time * 1.4))
			Avatar.draw_body(self, pos, h, face, pose, n["look"], false)
		else:
			var kind := Avatar.SHOOT if state == "shoot" else Avatar.DRIBBLE
			Avatar.draw_body(self, pos, h, face, Avatar.pose(kind, warmup_time * 4.2, 0.8), n["look"], state == "wait")
			if state == "shoot":
				var t := clampf(float(n["t"]), 0.0, 1.0)
				var bp := (pos + Vector2(face * 15, -40)).lerp(_screen(rim) - Vector2(0, RIM_HEIGHT), t)
				bp.y -= sin(PI * t) * 135.0
				_draw_ball_at(bp, BALL_R)
			elif state == "fall":
				var t := clampf(float(n["t"]) / 0.9, 0.0, 1.0)
				var ground: Vector2 = _screen(n["ball_ground"]) - Vector2(0, BALL_R)
				var bp := (_screen(rim) - Vector2(0, RIM_HEIGHT)).lerp(ground, minf(t / 0.68, 1.0))
				bp.y -= sin(clampf((t - 0.68) / 0.32, 0.0, 1.0) * PI) * 22.0
				_draw_ball_at(bp, BALL_R)
			elif state == "collect":
				_draw_ball_at(_screen(n["ball_ground"]) - Vector2(0, BALL_R), BALL_R)
			elif state == "pass":
				var t := clampf(float(n["t"]) / 0.65, 0.0, 1.0)
				var bp := (_screen(n["helper"]) - Vector2(0, 35)).lerp(pos - Vector2(0, 35), t)
				bp.y -= sin(PI * t) * 25.0
				_draw_ball_at(bp, BALL_R)
			# Each side has attendants in neutral clothes, separate from the
			# players and the user's own live ball.
			var helper_pos: Vector2 = _screen(n["helper"])
			var helper_col := Avatar.colours(false, Color(0.20, 0.24, 0.28))
			helper_col["shorts"] = Color(0.12, 0.14, 0.17)
			helper_col["hst"] = (team + 1) % 6
			var helper_pose := Avatar.RUN if state == "collect" else Avatar.IDLE
			Avatar.draw_body(self, helper_pos, 54.0, -face, Avatar.pose(helper_pose, warmup_time * 4.0, 0.0, "", state == "collect"), helper_col, false)
