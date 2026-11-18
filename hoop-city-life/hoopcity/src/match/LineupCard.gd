extends Control
## Broadcast lineup drawn with the real five on-court players, not stock art.
var squad: Array = []
var club := ""
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, w, h), Color(0.025, 0.04, 0.065, 0.68))
	var top := h * 0.12
	draw_rect(Rect2(w * 0.045, top, w * 0.91, h * 0.105), Color(0.07, 0.17, 0.27, 0.97))
	draw_rect(Rect2(w * 0.045, top + h * 0.105 - 4, w * 0.91, 4), Color(0.96, 0.65, 0.25))
	var heading := ("QUINTETTO  ·  " if Loc.lang == "it" else "STARTING FIVE  ·  ") + club.to_upper()
	draw_string(font, Vector2(w * 0.07, top + h * 0.068), heading, HORIZONTAL_ALIGNMENT_LEFT, w * 0.85, int(clampf(h * 0.052, 20, 36)), Color.WHITE)
	var gap := w * 0.014
	var card_w := (w * 0.91 - gap * 4.0) / 5.0
	var y := top + h * 0.13
	for i in mini(squad.size(), 5):
		var p: BallPlayer = squad[i]
		var x := w * 0.045 + float(i) * (card_w + gap)
		var alpha := clampf((elapsed - float(i) * 0.12) * 4.0, 0.0, 1.0)
		var accent: Color = Game.team_colour(p.team)
		draw_rect(Rect2(x, y, card_w, h * 0.48), Color(0.10, 0.15, 0.22, 0.96 * alpha))
		draw_rect(Rect2(x, y, card_w, 5), Color(accent.r, accent.g, accent.b, alpha))
		var cols := Avatar.colours(p.is_user, accent)
		cols["kit"] = true
		cols["jersey"] = accent
		cols["shorts"] = accent.darkened(0.35)
		cols["num"] = str(p.jersey_num)
		if not p.is_user:
			cols["skin"] = p.skin_col
			cols["hair"] = p.hair_col
			cols["hst"] = p.hair_style_v
		else: cols["hst"] = Game.hair_style()
		var feet := Vector2(x + card_w * 0.5, y + h * 0.33)
		Avatar.draw_body(self, feet, minf(h * 0.28, card_w * 0.85), 1.0, Avatar.pose(Avatar.IDLE, elapsed), cols, false, false, p.is_user)
		draw_rect(Rect2(x, y + h * 0.35, card_w, h * 0.13), Color(0.025, 0.035, 0.055, 0.96 * alpha))
		var nm: String = Season.short_player_name(p.display_name).to_upper()
		draw_string(font, Vector2(x + 6, y + h * 0.405), nm, HORIZONTAL_ALIGNMENT_CENTER, card_w - 12, int(clampf(card_w * 0.11, 14, 24)), Color(1,1,1,alpha))
		draw_string(font, Vector2(x + 6, y + h * 0.455), ("TU  ·  " if p.is_user else "") + "#" + str(p.jersey_num), HORIZONTAL_ALIGNMENT_CENTER, card_w - 12, int(clampf(card_w * 0.09, 12, 19)), Color(1.0,0.75,0.38,alpha))
	draw_string(font, Vector2(w * 0.05, h * 0.87), "HOOP CITY  ·  TIP-OFF", HORIZONTAL_ALIGNMENT_CENTER, w * 0.90, int(clampf(h * 0.04, 16, 24)), Color(1, 1, 1, 0.7))
