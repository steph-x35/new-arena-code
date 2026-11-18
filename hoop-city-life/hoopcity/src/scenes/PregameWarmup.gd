extends "res://src/scenes/SoloCourt.gd"
## A separate, non-scoring shootaround. The real match is created only after
## the player presses PLAY, so neither clock nor box score can run here.

var warmup_time := 0.0
var starting := false
var user_helper_pos := RIM + Vector2(110.0, 45.0)
var user_helper_moving := false
var user_helper_face := -1.0
var user_helper_step := 0.0
const USER_HELPER_HOME := RIM + Vector2(110.0, 45.0)

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
	_show_warmup_banner(root)
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

func _show_warmup_banner(root: Control) -> void:
	# Relative anchors work across the expanded landscape viewport. Short,
	# separately sized lines keep the message within the card on phones.
	var banner := PanelContainer.new()
	banner.name = "WarmupBanner"
	banner.anchor_left = 0.17
	banner.anchor_right = 0.83
	banner.anchor_top = 0.0
	banner.anchor_bottom = 0.0
	banner.offset_top = 112.0
	banner.offset_bottom = 218.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.09, 0.15, 0.96)
	style.border_color = Color(1.0, 0.65, 0.26)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	banner.add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 2)
	banner.add_child(content)
	var title := Label.new()
	title.text = "RISCALDAMENTO" if Loc.lang == "it" else "SHOOTAROUND"
	title.name = "WarmupTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.40))
	title.clip_text = true
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Tira liberamente · premi GIOCA quando vuoi" if Loc.lang == "it" else "Shoot freely · press PLAY when ready"
	subtitle.name = "WarmupSubtitle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 19)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.clip_text = true
	content.add_child(subtitle)
	root.add_child(banner)
	banner.modulate.a = 0.0
	banner.offset_top -= 20.0
	banner.offset_bottom -= 20.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(banner, "offset_top", 112.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "offset_bottom", 218.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	tw.set_parallel(false)
	tw.tween_interval(2.7)
	tw.tween_property(banner, "modulate:a", 0.0, 0.5)
	tw.tween_callback(banner.queue_free)

func _spawn_npcs() -> void:
	# Exactly five players per team: four teammates plus the user, and five
	# opponents. Assistants are separate and wear neutral clothes.
	var specs := [
		{"team": 0, "state": "wait", "pos": Vector2(420,-190)},
		{"team": 0, "state": "wait", "pos": Vector2(590,170)},
		{"team": 1, "state": "wait", "pos": Vector2(-430,-190)},
		{"team": 1, "state": "wait", "pos": Vector2(-590,170)},
		{"team": 0, "state": "stretch", "pos": Vector2(200,260)},
		{"team": 1, "state": "roller", "pos": Vector2(-280,-205)},
		{"team": 0, "state": "roller", "pos": Vector2(310,300)},
		{"team": 1, "state": "stretch", "pos": Vector2(-360,-275)},
		{"team": 1, "state": "wait", "pos": Vector2(-360,60)},
	]
	for i in specs.size():
		var spec: Dictionary = specs[i]
		var team: int = int(spec["team"])
		var kit: Color = Game.team_colour(team)
		var look := Avatar.colours(false, kit)
		look["kit"] = true
		look["num"] = str(10 + i * 3)
		look["hst"] = i % 6
		look["skin"] = [Color(0.76,0.57,0.43), Color(0.45,0.29,0.22), Color(0.88,0.70,0.55)][i % 3]
		look["hair"] = Game.HAIR_COLORS[i % Game.HAIR_COLORS.size()]
		var rim: Vector2 = RIM if team == 0 else LEFT_RIM
		var end_sign: float = 1.0 if team == 0 else -1.0
		var helper_home: Vector2 = rim + Vector2(end_sign * 105.0, -150.0 + float(i % 3) * 115.0)
		npcs.append({"pos": spec["pos"], "home": spec["pos"], "team": team, "look": look,
			"state": spec["state"], "t": -float(i) * 0.65, "face": end_sign,
			"helper": helper_home, "helper_home": helper_home,
			"helper_moving": false, "helper_face": -end_sign, "helper_step": 0.0,
			"ball_ground": rim + Vector2(-end_sign * 75.0, -60.0 if i % 2 == 0 else 60.0)})

func _update_npcs(delta: float) -> void:
	warmup_time += delta
	# Follow the user's actual loose ball, pick it up at floor level, then
	# pass it back. Walking to the ball yourself still works normally.
	var user_before: Vector2 = user_helper_pos
	if solo_loose and ball_live and _pick_ok and ball_h < 45.0 and not ball_recall:
		var d: Vector2 = ball_pos - user_helper_pos
		if d.length() < 16.0:
			_recall_ball()
		else:
			user_helper_pos += d.normalized() * minf(d.length(), 240.0 * delta)
	else:
		user_helper_pos = user_helper_pos.move_toward(USER_HELPER_HOME, 170.0 * delta)
	var user_delta: Vector2 = user_helper_pos - user_before
	user_helper_moving = user_delta.length() > 0.01
	if user_helper_moving:
		user_helper_step += user_delta.length() * 0.095
		if absf(user_delta.x) > 0.01: user_helper_face = signf(user_delta.x)
	for n in npcs:
		if n["state"] in ["stretch", "roller"]: continue
		var helper_before: Vector2 = n["helper"]
		n["t"] = float(n["t"]) + delta
		var state := String(n["state"])
		if state == "wait":
			n["helper"] = Vector2(n["helper"]).move_toward(Vector2(n["helper_home"]), 150.0 * delta)
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
		var helper_delta: Vector2 = Vector2(n["helper"]) - helper_before
		n["helper_moving"] = helper_delta.length() > 0.01
		if bool(n["helper_moving"]):
			n["helper_step"] = float(n["helper_step"]) + helper_delta.length() * 0.095
			if absf(helper_delta.x) > 0.01: n["helper_face"] = signf(helper_delta.x)

func _draw_npcs() -> void:
	for n in npcs:
		var pos: Vector2 = _screen(n["pos"])
		var h := 60.0
		var state := String(n["state"])
		var team := int(n["team"])
		var rim: Vector2 = RIM if team == 0 else LEFT_RIM
		var face: float = float(n["face"])
		if state in ["roller", "stretch"]:
			_draw_seated_warmup(pos, face, n["look"], state == "roller", float(team) * 0.8)
		else:
			var kind := Avatar.SHOOT if state == "shoot" else (Avatar.DRIBBLE if state == "wait" else Avatar.IDLE)
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
			var moving: bool = bool(n["helper_moving"])
			var helper_pose := Avatar.RUN if moving else Avatar.IDLE
			Avatar.draw_body(self, helper_pos, 54.0, float(n["helper_face"]), Avatar.pose(helper_pose, float(n["helper_step"]), 0.0, "", moving), helper_col, false)

	# Dedicated assistant for the user's own ball, initially on the baseline.
	var user_help: Vector2 = _screen(user_helper_pos)
	var help_col := Avatar.colours(false, Color(0.20, 0.24, 0.28))
	help_col["shorts"] = Color(0.12, 0.14, 0.17)
	Avatar.draw_body(self, user_help, 54.0, user_helper_face, Avatar.pose(Avatar.RUN if user_helper_moving else Avatar.IDLE, user_helper_step, 0.0, "", user_helper_moving), help_col, false)

func _draw_seated_warmup(pos: Vector2, facing: float, look: Dictionary, roller: bool, phase: float) -> void:
	# Side view with hips and both feet anchored to the parquet. The stretch
	# reaches towards the toes; the roller slides under the legs, not in air.
	var cycle: float = sin(warmup_time * (1.25 if roller else 0.9) + phase)
	var skin: Color = look["skin"]
	var jersey: Color = look["jersey"]
	var shorts: Color = look["shorts"]
	var shoes: Color = look["shoes"]
	var sway: float = 5.0 * cycle if roller else 0.0
	var hip := pos + Vector2(sway, -8)
	var toe := pos + Vector2(facing * 42.0, -2)
	var knee := hip.lerp(toe, 0.53) + Vector2(0, -3)
	var bend: float = (cycle + 1.0) * 0.5
	var shoulder := hip + Vector2(facing * (3.0 + (10.0 * bend if not roller else 2.0)), -32.0 + (4.0 * bend if not roller else 0.0))
	var head := shoulder + Vector2(facing * 2.0, -12.0)
	# Floor shadow and, for the roller, the cylinder supporting the calves.
	draw_line(pos + Vector2(-18, 3), pos + Vector2(facing * 47.0, 3), Color(0, 0, 0, 0.22), 5.0)
	if roller:
		var wheel := hip.lerp(knee, 0.70) + Vector2(0, 5)
		draw_line(wheel + Vector2(-7, 0), wheel + Vector2(7, 0), Color(0.16, 0.22, 0.29), 9.0)
		draw_line(wheel + Vector2(-4, -1), wheel + Vector2(4, -1), Color(0.42, 0.54, 0.61), 2.0)
	# Two slightly offset legs read as extended legs, both touching the floor.
	for offset in [-2.0, 2.0]:
		var off := Vector2(0, offset)
		draw_line(hip + off, knee + off, shorts, 8.0)
		draw_line(knee + off, toe + off, skin, 6.0)
		draw_line(toe + off, toe + off + Vector2(facing * 8.0, 0), shoes, 5.0)
	draw_line(hip, shoulder, jersey, 16.0)
	var hand: Vector2 = hip + Vector2(-facing * 13.0, 7.0) if roller else knee.lerp(toe, 0.20 + bend * 0.55) + Vector2(0, -7)
	var elbow: Vector2 = shoulder.lerp(hand, 0.5) + Vector2(-facing * 3.0, 3.0)
	draw_line(shoulder, elbow, skin, 5.0)
	draw_line(elbow, hand, skin, 5.0)
	draw_circle(head, 7.5, skin)
	draw_arc(head + Vector2(0, -2), 7.5, PI, TAU, 10, Color(look["hair"]), 4.0)
	draw_circle(head + Vector2(facing * 3.0, -0.5), 1.0, Color(0.08, 0.08, 0.10))
