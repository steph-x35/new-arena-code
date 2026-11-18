extends Node2D
## DEV ONLY. Verifica la transizione del fallo: il velo cala, il campo si
## riordina al coperto e il velo si alza — sia per il TIRO LIBERO sia per la
## RIMESSA che nasce da un fallo (normale, in attacco, o "L").
##
##   godot --headless --path . res://tools/FTTransitionProbe.tscn
##
## Stampa "FT PROBE OK=true" solo se passa tutto: la CI cerca quel token, cosi'
## una probe che muore in silenzio fa la run ROSSA invece di passare per difetto.

var fails := 0
var checks := 0
var court: Node2D
var _captions: Array = []      # chiave della scritta di ogni rimessa


func check(nm: String, cond: bool) -> void:
	checks += 1
	if cond:
		print("  ok: ", nm)
	else:
		fails += 1
		print("  FAIL: ", nm)


func by_role(team: int, role: int) -> BallPlayer:
	for p in court.players:
		if p.team == team and int(p.role) == role:
			return p
	return null


func _capture(_duration: float) -> void:
	_captions.append(String(court.inbound_caption_key))


## Riporta il campo a palla viva e libera da qualunque transizione in volo.
func _clear_state() -> void:
	court._ft_epoch += 1
	court._ft_watch = 0.0
	court._inbound_epoch += 1
	court.ft_active = false
	court._ft_ready = false
	court.ft_shooter = null
	court.restarting = false
	court.play_live = true
	court.inbound_wait = 0.0
	court._inbound_preparing = false
	court._inbounder = null


func _ready() -> void:
	Game.profile["next_match_mode"] = "full"
	Game.profile["quarter_seconds"] = 120.0
	Game.profile["baskin_role"] = 5
	court = preload("res://src/match/Court.gd").new()
	add_child(court)
	await get_tree().process_frame
	court.jump_pending = false
	court.restarting = false
	court.play_live = true
	court.inbound_transition.connect(_capture)

	var sh: BallPlayer = by_role(0, 5)
	var df: BallPlayer = by_role(1, 5)
	check("shooter and defender found", sh != null and df != null)

	# ---------------------------------------------------------------- TIRO LIBERO
	var ft_events: Array = []
	court.free_throw_transition.connect(func(n): ft_events.append(int(n)))
	sh.global_position = Vector2(0, 0)
	df.global_position = Vector2(40, 0)

	court.call_foul(df, sh, 2)
	# 1. la palla e' morta SUBITO: nessun ritardo di gioco mentre il velo cala
	check("foul: free throws armed in the same frame",
		court.ft_active and court.ft_shooter == sh and court.ft_total == 2)
	# 2. la transizione e' partita e porta il numero di tiri
	check("foul: the transition announces 2 free throws",
		ft_events.size() == 1 and ft_events[0] == 2)
	# 3. nessuno si e' ancora mosso: il riordino avviene sotto il velo
	check("foul: nobody teleports in front of the camera",
		sh.global_position.distance_to(Vector2(0, 0)) < 1.0)
	# 4. e nessuno puo' tirare mentre lo schermo e' coperto
	check("foul: not ready while the veil is down", not court._ft_ready)
	court.free_throw_release(sh, 0.0)
	check("foul: a release during the veil is swallowed", not court.ball.live)

	# 5. a velo pieno la fila e' sistemata, ma il tiro non e' ancora armato
	await get_tree().create_timer(court.FT_FADE_IN + 0.06).timeout
	check("line-up arranged under the veil",
		sh.global_position.distance_to(Vector2(0, 0)) > 1.0)
	check("line-up sits on the free-throw line",
		absf(sh.global_position.distance_to(court.hoop_for(0)) - court.FT_PX) < 3.0)
	check("still not armed while the veil is full", not court._ft_ready)

	# 6. a velo alzato si tira
	await get_tree().create_timer(court.FT_HOLD + 0.20).timeout
	check("armed once the veil is up", court._ft_ready)
	court.free_throw_release(sh, 0.0)
	check("a release after the veil leaves the hand", court.ball.live)

	# ------------------------------------------------------------ FALLO 3 PUNTI
	_clear_state()
	sh.global_position = Vector2(0, 0)
	court.call_foul(df, sh, 3)
	check("three-point foul sends three free throws", court.ft_total == 3)

	# ------------------------------------------------- RIMESSA DA FALLO (pre-bonus)
	_clear_state()
	court.team_fouls = [0, 0]
	_captions.clear()
	court.call_foul(df, sh, 0)
	check("foul before the bonus restarts with a throw-in",
		court.restarting and not court.ft_active and not court.play_live)
	check("that throw-in says it came from a foul",
		_captions.size() == 1 and _captions[0] == "match.foul.transition")

	# ------------------------------------------------------- FALLO IN ATTACCO
	_clear_state()
	await get_tree().process_frame
	court.team_fouls = [0, 0]
	var before: int = _captions.size()
	court.call_charge(sh, df)
	check("offensive foul restarts with a throw-in too",
		court.restarting and not court.play_live and not court.ft_active)
	check("the offensive foul throw-in names the foul",
		_captions.size() == before + 1 and _captions[-1] == "match.foul.transition")

	# -------------------------------------------------- FALLO "L" (difesa illecita)
	_clear_state()
	await get_tree().process_frame
	var ft_before: int = ft_events.size()
	court.illegal_defense(df, sh)
	check("illegal defence still sends two free throws",
		court.ft_active and court.ft_total == 2)
	check("illegal defence triggers the free-throw transition",
		ft_events.size() == ft_before + 1)

	# ------------------------------------------------------------------- ESITO
	print("FT PROBE: %d checks, %d fails" % [checks, fails])
	print("FT PROBE OK=", "true" if fails == 0 else "false")
	get_tree().quit()
