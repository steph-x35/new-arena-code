## OBIETTIVI DI PARTITA — sorteggio individuale dura, ricompensa in XP.
## Prima del fischio MatchScene ne sceglie uno; il ticker in alto mostra i
## numeri live e nel post-game l'esito paga XP extra (vedi _on_finished).
## Tutto qui e' PURO (nessun autoload): si puo' testare headless.
class_name MatchGoals

static func pick(one_on_one: bool, last_id := "") -> Dictionary:
	var pool: Array
	if one_on_one:
		# 1v1 al 11: obiettivi calibrati sul formato street, tutti duri.
		pool = [
			{"id": "1_opp5", "tpl": "Win keeping the opponent under %d points", "args": [6], "stat": "opp_lt", "t": 6, "xp": 45, "live": "OPP < 6  %d"},
			{"id": "1_three", "tpl": "Make %d+ three-pointers", "args": [3], "stat": "tpm", "t": 3, "xp": 50, "live": "3PM %d/%d"},
			{"id": "1_blk", "tpl": "Block %d+ shots", "args": [1], "stat": "blk", "t": 1, "xp": 40, "live": "BLK %d/%d"},
			{"id": "1_stl", "tpl": "Steal the ball %d+ times", "args": [2], "stat": "stl", "t": 2, "xp": 45, "live": "STL %d/%d"},
			{"id": "1_pts11", "tpl": "Win scoring %d+ points", "args": [11], "stat": "pts", "t": 11, "xp": 55, "live": "PTS %d/%d"},
		]
	else:
		# 5v5: tagli da statistica di alto livello, non da gara ordinaria.
		pool = [
			{"id": "5_pts18", "tpl": "Score %d+ points", "args": [18], "stat": "pts", "t": 18, "xp": 50, "live": "PTS %d/%d"},
			{"id": "5_ast5", "tpl": "Dish out %d+ assists", "args": [5], "stat": "ast", "t": 5, "xp": 45, "live": "AST %d/%d"},
			{"id": "5_reb10", "tpl": "Grab %d+ rebounds", "args": [10], "stat": "reb", "t": 10, "xp": 45, "live": "REB %d/%d"},
			{"id": "5_stl3", "tpl": "Steal the ball %d+ times", "args": [3], "stat": "stl", "t": 3, "xp": 45, "live": "STL %d/%d"},
			{"id": "5_blk3", "tpl": "Block %d+ shots", "args": [3], "stat": "blk", "t": 3, "xp": 50, "live": "BLK %d/%d"},
			{"id": "5_tpm4", "tpl": "Make %d+ three-pointers", "args": [4], "stat": "tpm", "t": 4, "xp": 50, "live": "3PM %d/%d"},
			{"id": "5_fg", "tpl": "Shoot %d%%+ FG with %d+ attempts", "args": [55, 10], "stat": "fg", "t": 55, "xp": 50, "live": "FG %d%%"},
			{"id": "5_dd", "tpl": "Double-double (%d+%d pts/reb)", "args": [10, 10], "stat": "dd", "t": 10, "xp": 60, "live": "DD %d+%d"},
			{"id": "5_tov0", "tpl": "Finish with %d turnovers", "args": [0], "stat": "tov", "t": 0, "xp": 40, "live": "TO %d"},
		]
	var cands: Array = pool.filter(func(g): return String(g["id"]) != last_id)
	return cands[randi() % cands.size()]

static func fmt(g: Dictionary) -> String:
	return String(g["tpl"]) % _nums(g["args"])

static func _nums(a: Array) -> Array:
	var out: Array = []
	for v in a:
		out.append(int(v))
	return out

## Riga del ticker live: "PTS 12/18", "OPP < 6  4", "FG 58%" ...
static func live_text(g: Dictionary, box: Dictionary, my: int, opp: int) -> String:
	match String(g["stat"]):
		"opp_lt":
			return String(g["live"]) % maxi(0, opp)
		"fg":
			var fga: int = int(box.get("fga", 0))
			var pct: int = 0 if fga == 0 else int(round(100.0 * float(box.get("fgm", 0)) / float(fga)))
			return String(g["live"]) % pct
		"dd":
			return String(g["live"]) % [int(box.get("pts", 0)), int(box.get("reb", 0))]
		"tov":
			return String(g["live"]) % int(box.get("tov", 0))
		_:
			return String(g["live"]) % [int(box.get(String(g["stat"]), 0)), int(g["t"])]

## Verdetto finale (e completamento live per gli obiettivi che non dipendono
## dalla sconfitta: "opp_lt" si giudica solo a fine partita).
static func is_done(g: Dictionary, box: Dictionary, my: int, opp: int, won: bool) -> bool:
	match String(g["stat"]):
		"pts", "ast", "reb", "stl", "blk", "tpm":
			return int(box.get(String(g["stat"]), 0)) >= int(g["t"])
		"fg":
			var fga: int = int(box.get("fga", 0))
			return fga >= 10 and 100.0 * float(box.get("fgm", 0)) / float(fga) >= float(g["t"])
		"dd":
			return int(box.get("pts", 0)) >= int(g["t"]) and int(box.get("reb", 0)) >= int(g["t"])
		"tov":
			return int(box.get("tov", 0)) <= int(g["t"])
		"opp_lt":
			return won and opp < int(g["t"])
	return false
