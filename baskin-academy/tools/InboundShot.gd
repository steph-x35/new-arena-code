extends Node2D
## DEV ONLY: grabs two frames of a throw-in — the still ball in the thrower's
## hands, then the pass in the air — so both can be eyeballed.
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . res://tools/InboundShot.tscn
var court: Node2D
var dir := "/home/user"

func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["baskin_role"] = 5
	# Use the FULL match scene: it brings the court camera with it, so the
	# throw-in is actually in frame.
	var ms: Node = load("res://src/match/MatchScene.tscn").instantiate()
	add_child(ms)
	await get_tree().process_frame
	court = ms.get_node("Court")
	Game.profile["baskin_role"] = 5
	await get_tree().create_timer(10.0).timeout
	# force a throw-in from the baseline, on OUR side of the floor
	court.possession = 0
	court.play_live = true
	court._inbound(0, Vector2.ZERO)
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	_shot("_inbound_still.png")
	# watch for the throw
	var t := 0.0
	while t < 3.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		if court.ball.live and court.ball.holder == null:
			break
	await get_tree().create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	_shot("_inbound_throw.png")
	print("INBOUNDSHOT: done")
	get_tree().quit()

func _shot(nm: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir + "/" + nm)
	print("saved ", nm)
