extends Node
## The broadcast commentator. Pure presentation: listens to the match event
## bus and says short, varied, localised lines at the right moments — runs,
## slams, deep threes, lead changes, cold stretches, clutch time. It never
## touches the simulation, and it is rate-limited so it never floods the
## screen: one voice, well timed, like a real telecast.

const GAP := 7.0          # minimum seconds between two ordinary lines
const GAP_HOT := 4.0      # big plays get a shorter gap

var court: Node = null
var hook: Callable = Callable()   # MatchScene displays the line
var _h := 0
var _a := 0
var _lead := 0                    # 0 = level/unknown, 1 = home up, 2 = away up
var _last := -99.0
var _cold_t := 0.0
var _cold_said := false
var _clutch_said := false

func setup(c: Node, say: Callable) -> void:
	court = c
	hook = say
	_h = int(court.score[0])
	_a = int(court.score[1])
	Events.score_changed.connect(_on_score)
	Events.shot_taken.connect(_on_shot)
	Events.quarter_ended.connect(_on_quarter)
	Events.run_update.connect(_on_run)

func _process(delta: float) -> void:
	if court == null or hook == Callable() or court.finished:
		return
	# Cold stretch: the user's side stuck in a long dry spell. Momentum is
	# positive when things go our way, so a deep negative plateau is the
	# "we cannot buy a bucket" stretch worth naming.
	var m: float = float(court.momentum)
	if m <= -0.55:
		_cold_t += delta
		if _cold_t >= 6.0 and not _cold_said:
			_cold_said = true
			_pick("comm.cold.", 2)
	else:
		_cold_t = 0.0
		if m > -0.2:
			_cold_said = false
	# Clutch time: a close game inside the last half minute of the fourth.
	if bool(court.is_fixture) and not bool(court.one_on_one) \
	and int(court.quarter) >= int(court.QUARTERS) \
	and float(court.game_clock) <= 30.0 \
	and absi(int(court.score[0]) - int(court.score[1])) <= 4 \
	and not _clutch_said:
		_clutch_said = true
		_line("comm.clutch", GAP_HOT)

func _can(gap: float) -> bool:
	var t := Time.get_ticks_msec() / 1000.0
	if t - _last < gap:
		return false
	_last = t
	return true

func _line(key: String, gap := GAP) -> void:
	if hook == Callable() or not _can(gap):
		return
	hook.call(Loc.t(key))

## Variants are indexed keys: comm.dunk.0 .. comm.dunk.(n-1).
func _pick(base: String, n: int, gap := GAP) -> void:
	if hook == Callable() or not _can(gap):
		return
	hook.call(Loc.t(base + str(randi() % n)))

func _on_score(h: int, a: int) -> void:
	if court == null:
		return
	# Lead changes are the heartbeat of a close game — call them late only,
	# when the game is old enough for a swing to matter.
	if h != a and bool(court.is_fixture) and int(court.quarter) >= 3:
		var lead := 1 if h > a else 2
		if _lead != 0 and lead != _lead:
			_pick("comm.lead.", 2, GAP_HOT)
		_lead = lead

func _on_shot(quality: String, made: bool, pts: int) -> void:
	if made and quality.begins_with("DUNK"):
		_pick("comm.dunk.", 3, GAP_HOT)
	elif made and pts >= 3:
		_pick("comm.three.", 3, GAP_HOT)

func _on_quarter(_q: int) -> void:
	_pick("comm.qend.", 2, 1.0)

func _on_run(info: Dictionary) -> void:
	if not bool(info.get("live", false)):
		return
	var tname: String = Game.club_my_team() if int(info.get("team", 0)) == 0 \
		else String(Game.profile.get("next_opponent", ""))
	if hook == Callable() or not _can(GAP_HOT):
		return
	hook.call(Loc.t("comm.run") % [tname, int(info.get("pts", 0))])
