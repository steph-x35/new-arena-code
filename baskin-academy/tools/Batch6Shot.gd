extends Node2D
## DEV ONLY. Batch-6 eyeball shots:
##   _b6_pivot_behind.png  the pivot standing BEHIND the side basket, basket in
##                         front of him and faded so his body shows through
##   _b6_basket_front.png  a body right in front of the basket, glass faded
##   _b6_change_ends.png   the "CHANGE ENDS" moment at the start of Q3
##   _b6_dust.png          the dust kicked up under the feet after a slam
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . res://tools/Batch6Shot.tscn
var court: Node2D
var dir := "/home/user"

func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["baskin_role"] = 5
	var ms: Node = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	await get_tree().process_frame
	court = ms.get_node("Court")
	await get_tree().create_timer(10.0).timeout

	# ---------------------------------------------------- pivot behind the basket
	# Team 1 owns the near side area in this setup: their own pivot moors
	# BEHIND the iron (pivot_home, patch L), so park him there and look.
	var piv: BallPlayer = _area(1)
	var h: Vector2 = court.side_hoops[1]
	court.play_live = true
	court.restarting = false
	court.ft_active = false
	court.inbound_wait = 0.0
	court.shot_clock = 20.0
	court.give_ball(_role(0, 5))
	await _pin(piv, h + Vector2(0.0, -26.0), 26)
	print("DIAG behind: team=", piv.team, " role=", piv.role, " at ",
		piv.global_position.round(), " (wanted ", (h + Vector2(0.0, -26.0)).round(), ")",
		" dist_to_rim=", snappedf(piv.global_position.distance_to(h), 1.0))
	await RenderingServer.frame_post_draw
	_shot("_b6_pivot_behind.png", _rim(h))

	# ---------------------------------------------------- a body in front of it
	var mate: BallPlayer = _front(1, piv)
	await _pin(mate, h + Vector2(0.0, 46.0), 20)
	print("DIAG front: team=", mate.team, " role=", mate.role, " at ",
		mate.global_position.round())
	await RenderingServer.frame_post_draw
	_shot("_b6_basket_front.png", _rim(h))

	# ---------------------------------------------------- half time: ends change
	court.quarter = 2
	court.game_clock = 0.0
	court._end_quarter()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_shot("_b6_change_ends.png")

	# ---------------------------------------------------- the slam, then the dust
	court.restarting = false
	court.ft_active = false
	court.inbound_wait = 0.0
	court.play_live = true
	var sl: BallPlayer = _role(0, 5)
	var hb: Vector2 = court.attack_hoop_for(sl)
	court.give_ball(sl)
	sl.global_position = hb + Vector2(-90.0 if hb.x > 0.0 else 90.0, 0.0)
	sl.air = 90.0
	sl.hanging = true
	sl.dunking = true
	sl.release_rim()
	var t := 0.0
	while t < 3.0 and sl.dust_t < 0.35:
		await get_tree().process_frame
		t += get_process_delta_time()
	await RenderingServer.frame_post_draw
	_shot("_b6_dust.png", CourtStage.m_project(sl.global_position, Court.COURT_H))
	# ---------------------------------------------------- the pass in the air
	court.restarting = false
	court.ft_active = false
	court.inbound_wait = 0.0
	court.play_live = true
	court.shot_clock = 20.0
	var pa: BallPlayer = _role(0, 4)
	var pb: BallPlayer = _role(0, 5)
	for p in court.players:
		if p.team == 1:
			p.global_position = Vector2(-900.0, 420.0)
	pa.global_position = Vector2(-420.0, 120.0)
	pb.global_position = Vector2(140.0, 120.0)
	pa.velocity = Vector2.ZERO
	pb.velocity = Vector2.ZERO
	court.give_ball(pa)
	for p in court.players:
		if p != pa:
			p.has_ball = false
	pb.move_input = Vector2(1.0, 0.0)          # the receiver runs AWAY from the pass
	pb.velocity = Vector2(240.0, 0.0)
	pa.do_pass(pb)
	var shot := 0
	t = 0.0
	while t < 2.0 and shot < 3:
		await get_tree().process_frame
		t += get_process_delta_time()
		pb.move_input = Vector2(1.0, 0.0)
		if court.ball.holder == null and court.ball.live:
			var d: float = court.ball.global_position.distance_to(pb.ball_anchor())
			if d < 330.0 and shot == 0:
				shot = 1
				await RenderingServer.frame_post_draw
				_shot("_b6_pass_1.png", CourtStage.m_project((pa.global_position + pb.global_position) * 0.5, Court.COURT_H))
			elif d < 150.0 and shot == 1:
				shot = 2
				await RenderingServer.frame_post_draw
				_shot("_b6_pass_2.png", CourtStage.m_project(pb.global_position, Court.COURT_H))
		if pb.has_ball and shot == 2:
			shot = 3
			await get_tree().create_timer(0.25).timeout
			await RenderingServer.frame_post_draw
			_shot("_b6_pass_3.png", CourtStage.m_project(pb.global_position, Court.COURT_H))
	print("BATCH6SHOT: done  dust_t=", snappedf(sl.dust_t, 2.0), " pass shots=", shot)
	get_tree().quit()

## Hold a man on a spot for `n` rendered frames, then hand control back.
func _pin(p: BallPlayer, at: Vector2, n: int) -> void:
	for i in n:
		p.global_position = at
		p.velocity = Vector2.ZERO
		await get_tree().process_frame

func _area(team: int) -> BallPlayer:
	## The man of `team` who already lives in the near side area: the game
	## leashes players to their own area, so only one of them may stand there.
	var want: Vector2 = court.side_hoops[1]
	var best: BallPlayer = null
	var bd := 1e9
	for p in court.players:
		if p.team != team:
			continue
		var d: float = p.global_position.distance_to(want)
		if d < bd:
			bd = d
			best = p
	return best

func _front(team: int, not_this: BallPlayer) -> BallPlayer:
	## Another man of the same team, in the same area: he is NOT the pivot.
	for p in court.players:
		if p.team == team and p != not_this and p.role != not_this.role:
			return p
	for p in court.players:
		if p.team == team and p != not_this:
			return p
	return null

func _role(team: int, r: int) -> BallPlayer:
	for p in court.players:
		if p.team == team and p.role == r:
			return p
	return null

## Full frame + a 2x zoomed crop around `focus` (a point in the CourtVisual's
## own space, as returned by side_hoop_layout).
func _shot(nm: String, focus: Variant = null) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir + "/" + nm)
	print("saved ", nm, " ", img.get_size())
	if focus == null:
		return
	var scr: Vector2 = _screen(focus)
	var w := 470
	var h := 330
	var r := Rect2i(int(scr.x - w * 0.5), int(scr.y - h * 0.5), w, h)
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	var z := img.get_region(r)
	z.resize(z.get_width() * 2, z.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	z.save_png(dir + "/" + nm.replace(".png", "_z.png"))
	print("  zoom at ", scr.round())

func _screen(local_pt: Vector2) -> Vector2:
	var vis: Node2D = court.get_parent().get_node("CourtVisual") if court.get_parent() != null else null
	var world: Vector2 = local_pt if vis == null else vis.to_global(local_pt)
	var ms: Node = court.get_parent()
	var cam: Camera2D = ms.get_node("Camera2D")
	return (world - cam.global_position) * cam.zoom + get_viewport_rect().size * 0.5

func _rim(focus_world: Vector2) -> Vector2:
	var vis: Node2D = court.get_node_or_null("../CourtVisual")
	if vis == null:
		return focus_world
	var lay: Dictionary = vis.side_hoop_layout(focus_world, 0)
	return (lay["rim"] as Vector2) if lay.has("rim") else focus_world
