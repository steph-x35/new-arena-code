extends Node2D
## A single uninterrupted team practice after the 2v2. The existing court,
## players and coach remain in the same scene for plays and the shooting line.

const PLAYS := [
	{"name": "Dai e vai", "start": Vector2(290, -40), "mate": Vector2(440, -235), "target": Vector2(650, -95), "receiver": 2},
	{"name": "Taglio centrale", "start": Vector2(245, 190), "mate": Vector2(390, -205), "target": Vector2(600, 30), "receiver": 3},
	{"name": "Pick and roll", "start": Vector2(265, 20), "mate": Vector2(460, 205), "target": Vector2(540, -105), "receiver": 2},
	{"name": "Passa e sostituisci", "start": Vector2(310, -200), "mate": Vector2(405, 180), "target": Vector2(390, 275), "receiver": 4},
	{"name": "Taglio lato debole", "start": Vector2(260, 205), "mate": Vector2(395, -220), "target": Vector2(650, 140), "receiver": 3},
]

var game: Node2D
var court: Court
var user: BallPlayer
var attack: Array[BallPlayer] = []
var defense: Array[BallPlayer] = []
var mode := "choose"
var play_step := ""
var current_play := 0
var completed := 0
var destination := Vector2.ZERO
var passer: BallPlayer
var receiver: BallPlayer
var pass_from: BallPlayer
var pass_to: BallPlayer
var pass_active := false
var shot_queue: Array[BallPlayer] = []
var shot_round := 0
var ft_state := ""
var ft_time := 0.0
var ft_charge := 0.0
var ft_made := false
var ft_shots := 0
var ft_start := Vector2.ZERO
var ft_end := Vector2.ZERO
var clock := 0.0
var ui: CanvasLayer
var root: Control
var title: Label
var detail: Label
var selector: VBoxContainer
var joystick: VirtualJoystick
var action: TouchButton
var finish: Button
var marker := Vector2.ZERO

func setup(scene: Node2D) -> void:
	game = scene
	court = scene.court
	user = court.user

func _ready() -> void:
	z_index = 45
	Game.profile["team_practice_stage"] = "plays"
	game.set_process(false)
	game.hud.visible = false
	game.joystick.set_process_input(false)
	court.set_process(false)
	court.set_physics_process(false)
	court.finished = false
	court.play_live = true
	court.restarting = false
	court.ball.dunk_drop = 0.0
	court.ball.live = false
	# Add the rest of the squad to the four already on court. Team 1 is the
	# practice defence, not an opposing club or a crowd.
	for team in [0, 1]:
		var existing: Array = court.players.filter(func(p): return p.team == team)
		for i in range(existing.size(), 5):
			var player := BallPlayer.new()
			player.team = team
			court.add_child(player)
			court._randomize_npc(player, team, i)
			court.players.append(player)
	for p in court.players:
		p.set_meta("practice_kit", true)
		if p.team == 0: attack.append(p)
		else: defense.append(p)
		if p != user:
			p.set_physics_process(false)
			for child in p.get_children():
				if child is AIBrain: child.set_physics_process(false)
	court.user.set_physics_process(true)
	court.ball.set_physics_process(true)
	_build_ui()
	_position_plays()
	_show_choices()

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 30
	add_child(ui)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var left := Control.new()
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.anchor_right = 0.42
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)
	joystick = VirtualJoystick.new()
	joystick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	joystick.sensitivity = float(Settings.get_v("joystick_sensitivity", 1.0))
	joystick.moved.connect(func(v):
		if mode == "play": user.move_input = v)
	left.add_child(joystick)
	joystick.set_process_input(false)
	title = Label.new()
	title.position = Vector2(24, 18)
	title.add_theme_font_size_override("font_size", 27)
	root.add_child(title)
	detail = Label.new()
	detail.position = Vector2(24, 54)
	detail.add_theme_font_size_override("font_size", 20)
	root.add_child(detail)
	selector = VBoxContainer.new()
	selector.position = Vector2(24, 94)
	selector.add_theme_constant_override("separation", 5)
	root.add_child(selector)
	action = TouchButton.new()
	action.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action.position = Vector2(-194, -150)
	action.custom_minimum_size = Vector2(128, 128)
	action.size = Vector2(128, 128)
	action.hold_mode = true
	action.pressed_down.connect(_action_down)
	action.released.connect(_action_up)
	root.add_child(action)
	finish = Button.new()
	finish.text = "FINE ALLENAMENTO"
	finish.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	finish.position = Vector2(-230, 18)
	finish.custom_minimum_size = Vector2(210, 50)
	finish.pressed.connect(_finish_practice)
	finish.visible = false
	root.add_child(finish)
	var quit := Button.new()
	quit.text = "LASCIA"
	quit.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quit.position = Vector2(-130, 76)
	quit.custom_minimum_size = Vector2(110, 45)
	quit.pressed.connect(_confirm_quit)
	root.add_child(quit)

func _position_plays() -> void:
	var a := [Vector2(290, -40), Vector2(440, -235), Vector2(555, 190), Vector2(325, 270), Vector2(610, -265)]
	var d := [Vector2(360, 0), Vector2(490, -170), Vector2(590, 135), Vector2(380, 235), Vector2(640, -205)]
	for i in 5:
		attack[i].global_position = a[i]
		defense[i].global_position = d[i]
		for p in [attack[i], defense[i]]:
			p.velocity = Vector2.ZERO
			p.move_input = Vector2.ZERO
			p.has_ball = false
			p.stance = p.team == 1
	court.give_ball(user)

func _show_choices() -> void:
	mode = "choose"
	play_step = ""
	user.move_input = Vector2.ZERO
	joystick.set_process_input(false)
	action.visible = false
	action.set_process_input(false)
	selector.visible = true
	for child in selector.get_children(): child.queue_free()
	title.text = "ALLENAMENTO · SCHEMI 5v5"
	detail.text = "Scegli uno schema, poi vai alla fila dei liberi."
	for i in PLAYS.size():
		var index: int = i
		var b := Button.new()
		b.text = "%d  %s" % [i + 1, PLAYS[i]["name"]]
		b.custom_minimum_size = Vector2(270, 48)
		b.pressed.connect(func(): _start_play(index))
		selector.add_child(b)
	var ft := Button.new()
	ft.text = "FILA TIRI LIBERI"
	ft.custom_minimum_size = Vector2(270, 48)
	ft.disabled = completed == 0
	ft.pressed.connect(_start_free_throws)
	selector.add_child(ft)

func _start_play(index: int) -> void:
	current_play = index
	var route: Dictionary = PLAYS[index]
	_position_plays()
	user.global_position = route["start"]
	passer = attack[1]
	passer.global_position = route["mate"]
	receiver = attack[int(route["receiver"])]
	destination = route["target"]
	mode = "play"
	play_step = "pass"
	selector.visible = false
	joystick.set_process_input(true)
	action.text = "PASSA"
	action.icon = Art.icon_for("PASS")
	action.visible = true
	action.set_process_input(true)
	title.text = "5v5 · " + String(route["name"])
	detail.text = "Passa al compagno."

func _action_down() -> void:
	if mode == "play" and not pass_active and user.has_ball:
		if play_step == "pass":
			_start_pass(user, passer)
			play_step = "passing_out"
			detail.text = "Il compagno riceve..."
		elif play_step == "pass_again":
			_start_pass(user, receiver)
			play_step = "passing_final"
			detail.text = "Passaggio finale..."
	elif mode == "ft" and ft_state == "user_ready":
		ft_charge = 0.0
		ft_state = "charging"

func _action_up() -> void:
	if mode == "ft" and ft_state == "charging":
		_shoot_free_throw(absf(ft_charge - 0.55) < 0.20)

func _start_pass(from: BallPlayer, to: BallPlayer) -> void:
	pass_active = true
	pass_from = from
	pass_to = to
	from.has_ball = false
	court.ball.pass_to(from.global_position, to.global_position, 850.0, from, to)
	Sfx.play("pass", -8.0)

func _step_pass() -> void:
	if not pass_active or court.ball._pass_time < court.ball._pass_duration: return
	pass_active = false
	court.give_ball(pass_to)
	if play_step == "passing_out":
		play_step = "cut"
		detail.text = "Taglia verso il cerchio verde."
	elif play_step == "returning":
		play_step = "pass_again"
		detail.text = "Passa al compagno indicato."
	elif play_step == "passing_final":
		completed += 1
		Events.toast.emit("SCHEMA COMPLETATO")
		_show_choices()

func _start_free_throws() -> void:
	mode = "ft"
	Game.profile["team_practice_stage"] = "freethrow"
	selector.visible = false
	joystick.set_process_input(false)
	user.set_physics_process(false)
	user.move_input = Vector2.ZERO
	court.ball.set_physics_process(false)
	court.ball.live = false
	court.ball.shot_result_pending = false
	court.ball.dunk_drop = 0.0
	shot_queue = attack.duplicate()
	shot_round = 0
	ft_shots = 0
	finish.visible = false
	action.text = "TIRA"
	action.icon = Art.icon_for("SHOOT")
	ft_state = "walking"
	title.text = "TIRI LIBERI · UN TIRO A TESTA"
	detail.text = "Raggiungi la linea con la squadra."

func _shoot_free_throw(made: bool) -> void:
	ft_made = made
	ft_state = "flight"
	ft_time = 0.0
	var shooter: BallPlayer = shot_queue[0]
	ft_start = shooter.global_position
	ft_end = court.hoop_for(0) + (Vector2.ZERO if made else Vector2(-52, 12))
	shooter.has_ball = false
	shooter.shot_anim = 0.26
	court.ball.holder = null
	court.ball.visible = true
	Sfx.play("shot_release", -7.0)
	action.visible = false
	action.set_process_input(false)

func _physics_process(delta: float) -> void:
	clock += delta
	if mode == "play":
		_step_pass()
		# Five defenders shadow their assignments without breaking the drill's
		# scripted passes; they move as the offence cuts and changes sides.
		for i in 5:
			var mark: BallPlayer = attack[i]
			var guard_spot: Vector2 = mark.global_position + (court.hoop_for(0) - mark.global_position).normalized() * 62.0
			_move_npc(defense[i], guard_spot, delta)
			defense[i].stance = true
		if play_step == "cut" and user.global_position.distance_to(destination) < 42.0:
			play_step = "returning"
			detail.text = "Ricevi il passaggio di ritorno."
			_start_pass(passer, user)
		# The named pick-and-roll includes a real teammate approaching the
		# defender, planting, then cutting toward the hoop after the user moves.
		if current_play == 2:
			var screener: BallPlayer = attack[2]
			var goal := Vector2(390, -55) if play_step in ["pass", "passing_out", "cut"] else Vector2(680, 20)
			_move_npc(screener, goal, delta)
	elif mode == "ft":
		_step_free_throws(delta)
	# Camera and animation are continuous: no scene change or match intro.
	var projected: Vector2 = CourtStage.m_project(user.global_position, Court.COURT_H)
	game.cam.global_position = game.cam.global_position.lerp(Vector2(projected.x, -88), minf(delta * 4.0, 1.0))
	game.cam.zoom = Vector2.ONE * 0.97
	for p in court.players:
		if p != user or mode == "ft":
			p.anim_t += delta * (5.2 if p.velocity.length() > 1.0 else 1.0)
			p.dribble_phase += delta * 4.2
			p.shot_anim = maxf(0.0, p.shot_anim - delta)
			p.queue_redraw()
	queue_redraw()

func _move_npc(p: BallPlayer, target: Vector2, delta: float) -> bool:
	var diff: Vector2 = target - p.global_position
	if diff.length() < 3.0:
		p.global_position = target
		p.velocity = Vector2.ZERO
		return true
	p.velocity = diff.normalized() * 165.0
	p.global_position += diff.normalized() * minf(diff.length(), 165.0 * delta)
	if absf(diff.x) > 3.0: p.facing = signf(diff.x)
	return false

func _step_free_throws(delta: float) -> void:
	var line := Vector2(court.hoop_for(0).x - Court.FT_PX, 0)
	var all_ready := true
	for i in shot_queue.size():
		var p: BallPlayer = shot_queue[i]
		var spot: Vector2 = line + Vector2(-float(i) * 95.0, 0.0)
		if not _move_npc(p, spot, delta): all_ready = false
	# Other teammates keep the gym alive: two talk, one walks and two shoot
	# at the far basket independently of the free-throw line.
	for i in defense.size():
		var ambient: BallPlayer = defense[i]
		var pos: Vector2 = [Vector2(-330, -265), Vector2(-370, -260), Vector2(-180, 200), Vector2(-620, 150), Vector2(-500, -100)][i]
		if i == 2: pos.x += sin(clock * 0.65) * 130.0
		_move_npc(ambient, pos, delta)
		ambient.stance = false
	if ft_state == "walking" and all_ready:
		var shooter: BallPlayer = shot_queue[0]
		for p in attack: p.has_ball = false
		court.ball.holder = shooter
		shooter.has_ball = true
		ft_time = 0.0
		if shooter == user:
			ft_state = "user_ready"
			detail.text = "Il tuo turno: tieni premuto TIRA e rilascia."
			action.visible = true
			action.set_process_input(true)
		else:
			ft_state = "npc_ready"
			detail.text = "%s tira · aspetta il tuo turno" % shooter.display_name
	if ft_state in ["user_ready", "npc_ready", "charging"]:
		var shooter: BallPlayer = shot_queue[0]
		court.ball.global_position = shooter.global_position + Vector2(14, 0)
		court.ball.h = 47.0
		court.ball.queue_redraw()
	if ft_state == "charging":
		ft_charge += delta
		detail.text = "Rilascia vicino a 0,55 s: %.2f" % ft_charge
		if ft_charge >= 1.2: _shoot_free_throw(false)
	elif ft_state == "npc_ready":
		ft_time += delta
		if ft_time > 1.0: _shoot_free_throw(randf() < 0.65)
	elif ft_state == "flight":
		ft_time += delta
		var t: float = clampf(ft_time / 1.05, 0.0, 1.0)
		court.ball.global_position = ft_start.lerp(ft_end, t)
		court.ball.h = lerpf(55.0, Court.RIM_HEIGHT, t) + sin(PI * t) * 180.0
		court.ball.queue_redraw()
		if t >= 1.0:
			if ft_made:
				Sfx.play("swish", -4.0)
			else:
				Sfx.play("rim", -4.0)
			var vis = game.get_node_or_null("CourtVisual")
			if vis != null: vis.net_bump(1, 0.8)
			ft_state = "drop"
			ft_time = 0.0
	elif ft_state == "drop":
		ft_time += delta
		court.ball.h = maxf(Court.RIM_HEIGHT * (1.0 - ft_time / 0.55), 0.0)
		court.ball.queue_redraw()
		if ft_time >= 0.55:
			var last: BallPlayer = shot_queue.pop_front()
			shot_queue.append(last)
			ft_shots += 1
			ft_state = "walking"
			if ft_shots >= attack.size():
				finish.visible = true
				detail.text = "Giro completato. Continua o termina l'allenamento."

func _draw() -> void:
	if mode == "play" and play_step == "cut":
		var target: Vector2 = CourtStage.m_project(destination, Court.COURT_H)
		var origin: Vector2 = CourtStage.m_project(user.global_position, Court.COURT_H)
		draw_arc(target, 32, 0, TAU, 32, Color(0.3, 1, 0.5, 0.9), 4)
		draw_line(origin, target, Color(0.4, 1, 0.5, 0.55), 3)
	elif mode == "play" and play_step == "pass_again":
		var target: Vector2 = CourtStage.m_project(receiver.global_position, Court.COURT_H)
		draw_arc(target, 34, 0, TAU, 32, Color(0.35, 0.75, 1.0, 0.85), 4)
	elif mode == "ft":
		# Two independent balls at the far hoop sell the live gym, without
		# interfering with the queued free throw or its scoring.
		for i in [3, 4]:
			var phase: float = fmod(clock * 0.35 + float(i) * 0.4, 1.0)
			var from: Vector2 = defense[i].global_position
			var to := Vector2(-Court.COURT_W * 0.5 + Court.FIBA_HOOP_INSET, 0)
			var point: Vector2 = CourtStage.m_project(from.lerp(to, phase), Court.COURT_H)
			point.y -= lerpf(50.0, Court.RIM_HEIGHT, phase) + sin(phase * PI) * 130.0
			draw_circle(point, Court.BALL_R, Color(0.95, 0.55, 0.15))

func _finish_practice() -> void:
	if ft_shots < attack.size(): return
	Season.attend_practice(true)
	Game.profile.erase("team_practice_day")
	Game.profile.erase("team_practice_stage")
	Game.profile["next_match_mode"] = "full"
	SceneRouter.goto("res://src/scenes/TeamCourt.tscn")

func _confirm_quit() -> void:
	var panel := GamePanel.new().build("Lasciare allenamento?", Vector2(700, 350))
	root.add_child(panel)
	panel.add_text("Se esci ora, l'allenamento non sarà completato.", 22)
	panel.add_button("Esci", func():
		Game.profile.erase("team_practice_day")
		Game.profile.erase("team_practice_stage")
		Game.profile["next_match_mode"] = "full"
		SceneRouter.goto("res://src/scenes/TeamCourt.tscn"))
	panel.add_button("Continua", func(): panel.close())
