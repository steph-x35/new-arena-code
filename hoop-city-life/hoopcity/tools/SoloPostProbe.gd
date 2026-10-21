extends Node2D
func _ready() -> void:
	await get_tree().process_frame
	Game.profile = Game.default_profile()
	var solo = load("res://src/scenes/SoloCourt.tscn").instantiate()
	add_child(solo)
	for i in 20:
		await get_tree().process_frame
	# S1: entri in post -> spalle al ferro
	solo.player_pos = Vector2(-500, 40)  # ferro a destra (RIM.x > 0)
	solo.facing = 1.0
	solo._post_tap()
	var s1: bool = solo.posting and solo.facing == -signf(solo.RIM.x - solo.player_pos.x)
	print("S1 post_on=", s1, " btn=", solo.btn_post != null and solo.btn_post.text == "POST")
	# S2: cammini a destra -> il facing resta spalle
	for i in 12:
		await get_tree().process_frame
	var s2: bool = solo.posting and solo.facing == -signf(solo.RIM.x - solo.player_pos.x)
	print("S2 spalle_in_movimento=", s2)
	# S3: TRICK da post = DROP STEP (esce dal post, gira al ferro)
	var d0: Vector2 = solo.player_pos
	solo._do_trick()
	var moved: float = solo.player_pos.distance_to(d0)
	var s3: bool = (not solo.posting) and moved > 60.0 \
		and solo.facing == signf(solo.RIM.x - solo.player_pos.x)
	print("S3 dropstep=", s3, " moved=", int(moved))
	# S4: shoot da post lontano -> FADEAWAY (hop + etichetta)
	solo.player_pos = solo.RIM + Vector2(-420, 30)
	solo._post_tap()
	solo._shoot_down()
	solo.charge = solo.ideal
	solo._shoot_up()
	var s4: bool = solo._family_tag == "FADEAWAY!" and not solo.posting
	print("S4 fade=", s4, " tag=", solo._family_tag)
	# S5: shoot da post vicino -> HOOK (palla morta, altrimenti il tap
	# sulla post viene rifiutato: stessa regola del gioco)
	solo.ball_live = false
	solo.shot_anim = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	solo.player_pos = solo.RIM + Vector2(-120, 20)
	solo._post_tap()
	print("S5b posting=", solo.posting, " ball_live=", solo.ball_live, " shot_anim=", solo.shot_anim, " dunk=", solo.dunk_phase)
	print("S5d guards: shot_anim=", solo.shot_anim, " dunk_phase='", solo.dunk_phase, "' ball_live=", solo.ball_live, " over=", solo.session_over, " posting=", solo.posting)
	solo._shoot_down()
	print("S5c charging=", solo.charging, " can_dunk=", solo.can_dunk(), " dist_ft=", solo._distance_ft())
	solo.charge = solo.ideal
	solo._shoot_up()
	var s5: bool = solo._family_tag == "HOOK!"
	print("S5 hook=", s5, " tag=", solo._family_tag, " dist=", int(solo._distance_ft()))
	print("SOLO_POST_OK=", s1 and s2 and s3 and s4 and s5)
	get_tree().quit()
