extends Node2D
func _ready() -> void:
	await get_tree().process_frame
	Game.profile = Game.default_profile()
	Game.profile["next_match_mode"] = "1v1"
	Game.profile["next_opponent"] = "Riverton"
	var ms := preload("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	for i in 900:
		await get_tree().process_frame
		if ms.court.awaiting_check: break
	ms.court.confirm_check()
	for i in 5:
		await get_tree().process_frame
	var u = ms.court.user
	var c = ms.court
	c.give_ball(u)
	for i in 10:
		await get_tree().process_frame
	# S1: nel trick la palla accelera COL braccio (bounce su anim_t*1.9)
	u.cooldown_move = 0.0
	u.do_move("crossover")
	var arm_ph: float = u.anim_t * 1.9 * 1.15
	await get_tree().process_frame
	var expect: float = absf(sin(u.anim_t * 1.9 * 1.15)) * 64.0 * u.height_f * 0.55 + Court.BALL_R
	var off: Dictionary = u.dribble_ball_offset()
	var dy: float = absf(float(off["h"]) - expect)
	print("S1 trick_sync=", dy < 12.0, " (h=", int(float(off["h"])), " vs arm=~", int(expect), ")")
	for i in 40:
		await get_tree().process_frame
	# S2: fuori trick la palla resta sul palmo (verticale identica)
	var pmy: float = -Vector2(Avatar.palms.get(u.get_instance_id(), Vector2.ZERO)).y
	var dy2: float = absf(c.ball.h - maxf(pmy, 4.0))
	print("S2 palm_sync=", dy2 < 6.0)
	# S3: tiro senza errori anche senza scia (rimossa nel 109)
	u.shot_charge = 0.5
	u.shot_ideal = 0.5
	c.attempt_shot(u, 0.0)
	for i in 8:
		await get_tree().process_frame
	print("S3 volo_ok=", c.ball != null)
	print("V226_OK=", dy < 12.0 and dy2 < 6.0 and c.ball != null)
	get_tree().quit()
