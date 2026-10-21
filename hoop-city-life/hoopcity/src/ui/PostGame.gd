extends Control
## End-of-game broadcast card: FINAL score with both club names, quarter
## splits, the headline run, top scorer per team — then your line and grade.
## Every key from the match is optional: a 1v1 has no quarters, an old save
## has no tops/run, and the card degrades gracefully.

var result: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# The card itself: dark slab, broadcast-orange border, centred.
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -390
	card.offset_right = 390
	card.offset_top = -330
	card.offset_bottom = 330
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.05, 0.058, 0.085, 0.96)
	cs.set_corner_radius_all(20)
	cs.set_border_width_all(2)
	cs.border_color = Color(0.949, 0.420, 0.114, 0.5)
	cs.content_margin_left = 34
	cs.content_margin_right = 34
	cs.content_margin_top = 22
	cs.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", cs)
	add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)

	# Header: FINAL · arena
	_l(v, "%s  ·  %s" % [Loc.t("bc.final"), String(result.get("arena", ""))],
		22, Color(1.0, 0.82, 0.30))

	# Score row: chip + club + big score + club + chip.
	var sc: Array = result.get("score", [0, 0])
	var opp: String = String(result.get("opp", ""))
	var srow := HBoxContainer.new()
	srow.alignment = BoxContainer.ALIGNMENT_CENTER
	srow.add_theme_constant_override("separation", 14)
	v.add_child(srow)
	_chip(srow, Game.team_colour(0))
	_l(srow, Season.short_name(Season.my_team()), 30, Color(0.965, 0.949, 0.906, 0.8))
	_l(srow, "%d - %d" % [sc[0], sc[1]], 58,
		Color(0.55, 1.0, 0.55) if result.get("won") else Color(1.0, 0.5, 0.4))
	_l(srow, Season.short_name(opp), 30, Color(0.965, 0.949, 0.906, 0.8))
	_chip(srow, Game.team_colour(1))

	# Esito dell'obiettivo di partita: verde con XP extra se chiuso.
	if result.has("goal") and not (result["goal"] as Dictionary).is_empty():
		var g: Dictionary = result["goal"]
		var gdone: bool = bool(result.get("goal_done", false))
		var gtxt: String = "%s  ·  %s" % [Loc.tx("MATCH GOAL"), MatchGoals.fmt(g)]
		if gdone:
			gtxt += "   +%d XP" % int(g["xp"])
		_l(v, gtxt, 21, Color(0.55, 1.0, 0.55) if gdone else Color(1.0, 0.5, 0.4))

	# Quarter splits, when the game had quarters.
	if result.has("q") and (result["q"] as Array).size() > 0:
		var parts: PackedStringArray = []
		for qp in result["q"]:
			parts.append("%d-%d" % [qp[0], qp[1]])
		_l(v, "%s   %s" % [Loc.t("bc.quarters"), "  ".join(parts)],
			22, Color(0.965, 0.949, 0.906, 0.65))

	# Headline run.
	if result.has("run"):
		var run: Dictionary = result["run"]
		var rname: String = Season.my_team() if int(run.get("team", 0)) == 0 else opp
		_l(v, Loc.t("bc.run") % [int(run.get("pts", 0)), rname, int(run.get("q", 1))],
			22, Color(1.0, 0.86, 0.48))

	# Top scorer per team.
	var tops: Array = result.get("tops", [])
	if tops.size() == 2 and not (tops[0] as Dictionary).is_empty() \
	and not (tops[1] as Dictionary).is_empty():
		_l(v, Loc.t("bc.top") % [String(tops[0]["name"]), int(tops[0]["pts"]),
			String(tops[1]["name"]), int(tops[1]["pts"])],
			20, Color(0.965, 0.949, 0.906, 0.75))

	_l(v, "", 8, Color.WHITE)
	_l(v, Loc.t("post.win") if result.get("won") else Loc.t("post.loss"),
		44, Color(0.55, 1.0, 0.55) if result.get("won") else Color(1.0, 0.5, 0.4))
	var perf := clampf((result.get("pts",0)*1.0 + result.get("ast",0)*1.6 + result.get("reb",0)*1.2
		+ result.get("stl",0)*2.0 + result.get("blk",0)*2.0 - result.get("tov",0)*1.8) / 45.0, 0.0, 1.2)
	_l(v, Loc.t("post.grade") % Career.grade_from_score(perf), 36, Color(0.965, 0.949, 0.906))
	_l(v, "%d PTS   %d AST   %d REB   %d STL   %d BLK   %d TO" % [
		result.get("pts",0), result.get("ast",0), result.get("reb",0),
		result.get("stl",0), result.get("blk",0), result.get("tov",0)],
		26, Color(0.965, 0.949, 0.906, 0.9))
	var fga: int = result.get("fga", 0)
	_l(v, "FG %d/%d (%d%%)   3PT %d/%d" % [result.get("fgm",0), fga,
		int(100.0 * result.get("fgm",0) / maxf(fga, 1)), result.get("tpm",0), result.get("tpa",0)],
		24, Color(0.965, 0.949, 0.906, 0.75))

	var b := Button.new()
	b.text = Loc.t("post.city")
	b.custom_minimum_size = Vector2(520, 96)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(func(): SceneRouter.goto("res://src/scenes/CityScene.tscn"))
	v.add_child(b)

	var p := Button.new()
	p.text = Loc.t("post.phone")
	p.custom_minimum_size = Vector2(520, 84)
	p.add_theme_font_size_override("font_size", 22)
	p.pressed.connect(func(): SceneRouter.open_phone())
	v.add_child(p)

func _l(parent: Node, t: String, size: int, col: Color) -> void:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)

func _chip(parent: Node, col: Color) -> void:
	var chip := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = col
	style.set_corner_radius_all(5)
	chip.add_theme_stylebox_override("panel", style)
	chip.custom_minimum_size = Vector2(14, 40)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(chip)
