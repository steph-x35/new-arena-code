extends Node2D
## TEMP: quarter opening = baseline inbound.

var court: Node2D
var fails := 0

func check(nm: String, cond: bool) -> void:
	print(("  ok: " if cond else "  FAIL: ") + nm)
	if not cond:
		fails += 1

func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["quarter_seconds"] = 120.0
	court = preload("res://src/match/Court.gd").new()
	add_child(court)
	await get_tree().process_frame
	court.play_live = true
	await get_tree().create_timer(7.0).timeout   # Q1 jump ball plays out first
	court._end_quarter()
	check("flag set", court.get("_qb_inbound") == true)
	check("ball parked", court.ball.holder == null and not court.ball.visible)
	check("consumed", court.consume_quarter_opening() == true)
	check("consumed once", court.consume_quarter_opening() == false)
	court._qb_inbound = true
	court.consume_quarter_opening()
	court.ball.global_position = Vector2.ZERO   # palla al centro: fondo campo
	court.start_quarter_inbound()
	await get_tree().create_timer(0.3).timeout
	var ib: BallPlayer = court.get("_inbounder")
	check("baseline inbound", ib != null and absf(ib.global_position.x) > Court.COURT_W * 0.5)
	check("inbounder not pivot", ib != null and ib.role != 1)
	await get_tree().create_timer(4.5).timeout
	check("live again", court.play_live and court.ball.holder != null)
	print("QPROBE: ", "ALL OK" if fails == 0 else "FAILURES=%d" % fails)
	get_tree().quit()
